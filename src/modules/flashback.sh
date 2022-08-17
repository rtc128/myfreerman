#!/bin/bash

set -e
function check_create_new_table()
{
	[ "$TABLE_NAME" != "$NEW_TABLE_NAME" ] || return 0
	write_out "Creating new table"
	CMD="create table $FQ_NEW_TABLE_NAME as select * from $FQ_TABLE_NAME limit 0;"
	echo "$CMD" >&5 || return 1
}

function check_del_col_count()
{
	#get number of cols in event, and compare to cur number of cols in table
	LINE_NUM=`grep -n -m 2 "^### DELETE FROM" $EVENT | tail -n 1 | cut -d : -f 1`
	if [ $LINE_NUM -eq 1 ]; then
		EV_LINE_COUNT=`wc -l $EVENT | cut -d \  -f 1`
		EV_COL_COUNT=$((EV_LINE_COUNT-2))
	else
		EV_COL_COUNT=$((LINE_NUM-3))
	fi
	if [ $EV_COL_COUNT -ne $COL_COUNT ]; then
		write_out "Table structure was modified - flashback not supported"
		return 1
	fi
}

function check_ins_col_count()
{
	#get number of cols in event, and compare to cur number of cols in table
	LINE_NUM=`grep -n -m 2 "^### INSERT " $EVENT | tail -n 1 | cut -d : -f 1`
	if [ $LINE_NUM -eq 1 ]; then
		EV_LINE_COUNT=`wc -l $EVENT | cut -d \  -f 1`
		EV_COL_COUNT=$((EV_LINE_COUNT-2))
	else
		EV_COL_COUNT=$((LINE_NUM-3))
	fi
	if [ $EV_COL_COUNT -ne $COL_COUNT ]; then
		write_out "Table structure was modified - flashback not supported"
		return 1
	fi
}

function check_populate_new_table()
{
	#if dest is another table, copy official table data to dest
	[ "$TABLE_NAME" != "$NEW_TABLE_NAME" ] || return 0
	write_out "Copying table contents"
	CMD="insert into $FQ_NEW_TABLE_NAME select * from $FQ_TABLE_NAME;"
	echo "$CMD" >&5 || return 1

	write_out "Unlocking tables"
	CMD="unlock tables;"
	echo "$CMD" >&5 || return 1

	if [ "$DEBUG" == "1" ]; then
		echo "New table:" >&2
		mysql --socket="$SERVER_SOCKET" -N $TARGET_CRED_OPT -e "select * from $FQ_NEW_TABLE_NAME" >&2
	fi
}

function initialize()
{
	write_out "Connecting to mysql"
	exec 5> >(mysql --socket="$SERVER_SOCKET" $TARGET_CRED_OPT)

	write_out "Starting transaction"
	CMD="start transaction;"
	#echo "$CMD" >&5 || return 1

	write_out "Disabling FK checks"
	CMD="set foreign_key_checks = off;"
	echo "$CMD" >&5 || return 1
}

function lock_tables()
{
	write_out "Locking tables"
	#if not using new table, lock only requested table, allowing us to write
	#if using new table, lock requested table with READ only, and new table with WRITE
	if [ "$NEW_TABLE_NAME" == "$TABLE_NAME" ]; then
		TABLE_LIST="$FQ_TABLE_NAME write"
	else
		TABLE_LIST="$FQ_TABLE_NAME read, $FQ_NEW_TABLE_NAME write"
	fi
	CMD="lock tables $TABLE_LIST;"
	echo "$CMD" >&5 || return 1
}

function check_upd_col_count()
{
	#get number of cols in event, and compare to cur number of cols in table
	TMP_EV_COL_COUNT=`grep -n -m 1 "^### SET" $EVENT | cut -d : -f 1`
	EV_COL_COUNT=$((TMP_EV_COL_COUNT-3))
	if [ $EV_COL_COUNT -ne $COL_COUNT ]; then
		write_out "Table structure was modified - flashback not supported"
		return 1
	fi
}

function decode_blob_value()
{
	V="$1"
	RESULT="$V"
#if \x is found, change value format
	if echo "$V" | grep -m 1 \\x >/dev/null; then
		RESULT="x${V//\\x/}"
	fi
	echo "$RESULT"
}

function exec_sqls()
{
	write_out "Running flashback script"
	for F in `ls -r $SQL_DIR`; do
		FF=$SQL_DIR/$F
		cat $FF >&5 || return 1
		sleep 1
	done
	CMD="commit;"
	echo "$CMD" >&5 || return 1
}

function get_first_binlog()
{
	FIRST=1
	ISO_REQ_TIMESTAMP="${REQ_TIMESTAMP/_/ }"
	for F in `ls "$BINLOG_BACKUP_DIR"`; do
		FF="${BINLOG_BACKUP_DIR}/${F}"
		MOD_TIME="`stat -c %y \"$FF\"`"
		if [[ "$MOD_TIME" > "$ISO_REQ_TIMESTAMP" ]]; then
			if [ $FIRST -eq 1 ]; then
				return
			fi
			echo "$F"
			break
		fi
		FIRST=0
	done
}

function get_pk()
{
	PK_LIST=`mktemp /tmp/myfreerman.XXXXXX` || return 1
	OUT=`mktemp /tmp/myfreerman.XXXXXX` || return 1
	mysql --socket="$SERVER_SOCKET" -N $TARGET_CRED_OPT -e "desc $FQ_TABLE_NAME" | awk '{ print $1 " " $4; }' >$OUT
	COL_POS=0
	for KEY in `awk '{ print $2; }' $OUT`; do
		COL_POS=$((COL_POS+1))
		if [ "$KEY" == "PRI" ]; then
			echo $COL_POS >>$PK_LIST
		fi
	done
	rm $OUT
	COUNT=`wc -l $PK_LIST | awk '{ print $1; }'`
	if [ $COUNT -eq 0 ]; then
		rm $PK_LIST
		write_out "Table has no PK"
		return 1
	fi
}

function list_table_cols()
{
	mysql -N $TARGET_CRED_OPT --socket="$SERVER_SOCKET" -e "desc $FQ_TABLE_NAME" | sed -e 's/\t.*//' >$COL_FILE || return 1
}

function parse_one_event()
{
	[ -f $SQL ] || return 1
	TAIL=$((SQL_LINE_COUNT-START_LINE+1))
	#look for statement end mark
	EFF_START_LINE=`tail -n $TAIL $SQL | grep -n -m 1 '^#.*STMT_END_F$' | cut -d : -f 1`
	EFF_START_LINE=$((EFF_START_LINE+START_LINE))
	TAIL=$((SQL_LINE_COUNT-EFF_START_LINE+1))
	END_LINE=`tail -n $TAIL $SQL | grep -n -m 1 '^# at ' | cut -d : -f 1`
	EFF_END_LINE=$((EFF_START_LINE+END_LINE-2))
	HEAD=$EFF_END_LINE
	TAIL=$((EFF_END_LINE-EFF_START_LINE+1))
	head -n $HEAD $SQL | tail -n $TAIL >$EVENT
}

function parse_one_row_val()
{
	#get content
	TLINE=$((LINE+START_LINE-1))
	CONTENT="`head -n $TLINE $EVENT | tail -n 1`"
#find position of the comment in the end of the line
	POS=`echo "$CONTENT" | grep -bo -m 1 '/\*.*\*/$' | cut -d : -f 1`
	#get the comment
	COMMENT=${CONTENT:$POS}
#get data type: first world inside the comment
	DATATYPE=`echo "$COMMENT" | cut -d \  -f 2`
	BASIC_TYPE=`echo $DATATYPE | cut -d \( -f 1`

	#remove space right before comment
	POS=$((POS-1))
	#cut in this comment
	NC_CONTENT=${CONTENT:0:$POS}
	#cut value
	VAL=`echo "$NC_CONTENT" | cut -d = -f 2-`

	#handle specidic datatypes
	case $BASIC_TYPE in
		BLOB/TEXT)
			VAL="`decode_blob_value \"$VAL\"`";;
		TIMESTAMP)
			VAL="from_unixtime($VAL)";;
	esac
	echo "$VAL"
}

function read_binlogs()
{
	LSEQ=`echo $FIRST_BINLOG | cut -d . -f 2`
	SEQ=`expr $LSEQ + 0`
	write_out "Reading binary log #$SEQ"
	read_one_binlog $FIRST_BINLOG || return 1
	SEQ=`expr $SEQ + 1`
	LSEQ=`printf %06d $SEQ`
	F="binlog.${LSEQ}.gz"
	FF="$BINLOG_BACKUP_DIR/$F"
	while [ -f "$FF" ]; do
		#if we have a binlog seq to stop, check it
		if [ -n "$CUR_BINLOG_FULL" ]; then
			LONG_SEQ=`echo $F | cut -d . -f 2`
			SHORT_SEQ=`expr $LONG_SEQ + 0`
			if [ $CUR_BINLOG_SEQ -lt $SHORT_SEQ ]; then
				break
			fi
		fi

		write_out "Reading binary log #$SEQ"
		read_one_binlog $F || return 1
		SEQ=`expr $SEQ + 1`
		LSEQ=`printf %06d $SEQ`
		F="binlog.${LSEQ}.gz"
		FF="$BINLOG_BACKUP_DIR/$F"
	done
}

function read_one_binlog()
{
	local F
	F=$1
	PLAIN=`mktemp /tmp/myfreerman.XXXXXX` || return 1
	FF="$BINLOG_BACKUP_DIR/$F"
	ERR=`mktemp /tmp/myfreerman.XXXXXX` || return 1
	gunzip -c "$FF" >$PLAIN 2>$ERR
	RC=$?
	write_file_out $ERR
	rm $ERR
	[ $RC -eq 0 ] || return 1

	ERR=`mktemp /tmp/myfreerman.XXXXXX` || return 1
	FERR=`mktemp /tmp/myfreerman.XXXXXX` || return 1
	SQL=`mktemp /tmp/myfreerman.XXXXXX` || return 1

	#if we have a binlog seq/pos to stop, request it
	STOP_OPT=
	if [ -n "$CUR_BINLOG_FULL" ]; then
		LONG_SEQ=`echo $F | cut -d . -f 2`
		SHORT_SEQ=`expr $LONG_SEQ + 0`
		if [ $CUR_BINLOG_SEQ -eq $SHORT_SEQ ]; then
			STOP_OPT=--stop-position=$CUR_BINLOG_POS
		fi
	fi

	mysqlbinlog --defaults-file="$SERVER_CONFIG" -vvv --base64-output=DECODE-ROWS --database=$DATABASE --result-file=$SQL --start-datetime="$REQ_TIMESTAMP" $STOP_OPT $PLAIN 2>$ERR
	RC=$?
	rm $PLAIN
	grep -vwi warning $ERR >$FERR
	rm $ERR
	write_file_out $FERR
	rm $FERR
	[ $RC -eq 0 ] || { rm $SQL; return 1; }
	revert_sql_cmds || { rm -f $SQL; return 1; }
	jobs
	rm -f $SQL
}

function revert_delete()
{
	check_del_col_count || return 1
	EVENT_LINE_COUNT=`wc -l $EVENT | cut -d \  -f 1`

	START_LINE=3
	while [ $START_LINE -lt $EVENT_LINE_COUNT ]; do
		CMD="insert into $FQ_NEW_TABLE_NAME"
		FIRST=1
		VAL_LIST=
		for LINE in `seq 1 $COL_COUNT`; do
			VAL=`parse_one_row_val`
			if [ $FIRST -eq 0 ]; then
				VAL_LIST="${VAL_LIST}, "
			fi
			VAL_LIST="${VAL_LIST}${VAL}"
			FIRST=0
		done

		CMD="$CMD values ($VAL_LIST)"
		write_sql

		START_LINE=$((START_LINE+2+COL_COUNT))
	done
}

function revert_insert()
{
	check_ins_col_count || return 1
	EVENT_LINE_COUNT=`wc -l $EVENT | cut -d \  -f 1`
	START_LINE=3
	while [ $START_LINE -lt $EVENT_LINE_COUNT ]; do
		CMD="delete from $FQ_NEW_TABLE_NAME where"

		#mount col list (only pk members)
		WHERE_NAME_LIST=
		FIRST=1
		for I in `seq 1 $COL_COUNT`; do
			if ! grep -w $I $PK_LIST >/dev/null; then
				continue
			fi
			COL_NAME=`head -n $I $COL_FILE | tail -n 1`
			if [ $FIRST -eq 0 ]; then
				WHERE_NAME_LIST="${WHERE_NAME_LIST}, "
			fi
			WHERE_NAME_LIST="${WHERE_NAME_LIST}${COL_NAME}"
			FIRST=0
		done

		#mount WHERE (only pk members)
		#START_LINE=$((START_LINE+1+COL_COUNT))
		FIRST=1
		WHERE_VAL_LIST=
		for LINE in `seq 1 $COL_COUNT`; do
			if ! grep -w $LINE $PK_LIST >/dev/null; then
				continue
			fi
			VAL=`parse_one_row_val`
			if [ $FIRST -eq 0 ]; then
				WHERE_VAL_LIST="${WHERE_VAL_LIST}, "
			fi
			WHERE_VAL_LIST="${WHERE_VAL_LIST}${VAL}"
			FIRST=0
		done

		CMD="$CMD ($WHERE_NAME_LIST) = ($WHERE_VAL_LIST)"
		write_sql

		START_LINE=$((START_LINE+2+COL_COUNT))
	done
}

function revert_update()
{
	check_upd_col_count || return 1
	EVENT_LINE_COUNT=`wc -l $EVENT | cut -d \  -f 1`

	#col name list for WHERE (only pk members)
	FIRST=1
	WHERE_NAME_LIST=
	for I in `seq 1 $COL_COUNT`; do
		if ! grep -w $I $PK_LIST >/dev/null; then
			continue
		fi
		COL_NAME=`head -n $I $COL_FILE | tail -n 1`
		if [ $FIRST -eq 0 ]; then
			WHERE_NAME_LIST="${WHERE_NAME_LIST}, "
		fi
		WHERE_NAME_LIST="${WHERE_NAME_LIST}${COL_NAME}"
		FIRST=0
	done

	START_LINE=3
	while [ $START_LINE -lt $EVENT_LINE_COUNT ]; do
		CMD="update $FQ_NEW_TABLE_NAME set"
		SET_LIST=
		#mount SET (all cols)
		for LINE in `seq 1 $COL_COUNT`; do
			COL_NAME=`head -n $LINE $COL_FILE | tail -n 1`
			VAL=`parse_one_row_val`
			SET_COL="$COL_NAME = $VAL"
			SET_LIST="${SET_LIST}${SET_COL}"
			if [ $LINE -lt $COL_COUNT ]; then
				SET_LIST="${SET_LIST}, "
			fi
		done

		#mount WHERE (only pk members)
		START_LINE=$((START_LINE+1+COL_COUNT))
		FIRST=1
		WHERE_VAL_LIST=
		for LINE in `seq 1 $COL_COUNT`; do
			if ! grep -w $LINE $PK_LIST >/dev/null; then
				continue
			fi
			VAL=`parse_one_row_val`
			if [ $FIRST -eq 0 ]; then
				WHERE_VAL_LIST="${WHERE_VAL_LIST}, "
			fi
			WHERE_VAL_LIST="${WHERE_VAL_LIST}${VAL}"
			FIRST=0
		done

		CMD="$CMD $SET_LIST where ($WHERE_NAME_LIST) = ($WHERE_VAL_LIST)"
		write_sql

		START_LINE=$((START_LINE+2+COL_COUNT))
	done
}

function revert_sql_cmds()
{
	#look for table map with required table
	STR="table_map: \`$DATABASE\`\.\`$TABLE_NAME\`"
	LINE_LIST=`mktemp /tmp/myfreerman.XXXXXX` || return 1
	grep -ni "$STR" $SQL | cut -d : -f 1 >$LINE_LIST
	LINES_LINE_COUNT=`wc -l $LINE_LIST | awk '{ print $1; }'`
	SQL_LINE_COUNT=`wc -l $SQL | cut -d \  -f 1`
	for I in `seq 1 $PROCESS_THREADS`; do
		#revert_sql_cmds_th $I &
		revert_sql_cmds_th $I || { rm $LINE_LIST; return 1; }
	done
	wait
	rm $LINE_LIST
	[ -f $SQL ] || return 1
}

function revert_sql_cmds_th()
{
	THREAD_ID=$1
	EVENT=`mktemp /tmp/myfreerman.XXXXXX` || return 1
	EVENT_NUM=$THREAD_ID
	while [ $EVENT_NUM -le $LINES_LINE_COUNT ]; do
		START_LINE=`head -n $EVENT_NUM $LINE_LIST | tail -n 1`
		parse_one_event || return 1
		OP=`head -n 1 $EVENT | cut -d \  -f 2`
		case $OP in
			DELETE)
				revert_delete || { rm $SQL $EVENT; return 1; };;
			INSERT)
				revert_insert || { rm $SQL $EVENT; return 1; };;
			UPDATE)
				revert_update || { rm $SQL $EVENT; return 1; };;
			*)
				write_out "Unsupported command found in binlog: $OP"
				rm $SQL $EVENT
				return 1;;
		esac
		EVENT_NUM=$((EVENT_NUM+PROCESS_THREADS))
	done
	rm $EVENT
}

function flashback_run()
{
	initialize || return 1
	get_pk || return 1
	check_create_new_table || { rm $PK_LIST; return 1; }
	lock_tables || { rm $PK_LIST; return 1; }
	CUR_BINLOG_FULL=
	#if dest is another table, get current binlog position
	if [ "$TABLE_NAME" != "$NEW_TABLE_NAME" ]; then
		CUR_BINLOG_FULL=`binlog_get_current_master_binlog` || { rm $PK_LIST; return 1; }
		CUR_BINLOG_SEQ=`echo $CUR_BINLOG_FULL | cut -d : -f 1`
		CUR_BINLOG_POS=`echo $CUR_BINLOG_FULL | cut -d : -f 2`
	fi
	check_populate_new_table || { rm $PK_LIST; return 1; }
	OLD_REPORT_FINISHED=$REPORT_FINISHED
	REPORT_FINISHED=0
	backup binlog || { rm $PK_LIST; return 1; }
	REPORT_FINISHED=$OLD_REPORT_FINISHED
	FIRST_BINLOG=`get_first_binlog` || { rm $PK_LIST; return 1; }
	if [ -z "$FIRST_BINLOG" ]; then
		write_out "Unavailable timestamp"
		{ rm $PK_LIST; return 1; }
	fi
	COL_FILE=`mktemp /tmp/myfreerman.XXXXXX`
	mysql -N --socket="$SERVER_SOCKET" $TARGET_CRED_OPT -e "desc $FQ_TABLE_NAME" | sed -e 's/\t.*//' >$COL_FILE || { rm $COL_FILE $PK_LIST; return 1; }
	COL_COUNT=`wc -l $COL_FILE | cut -d \  -f 1`
	SQL_DIR=`mktemp -d /tmp/myfreerman.XXXXXX` || { rm $COL_FILE $PK_LIST; return 1; }
	if [ "$DEBUG" -eq "1" ]; then
		echo "SQL directory: $SQL_DIR"
	fi
	read_binlogs || { rm $COL_FILE; rm -fr $PK_LIST $SQL_DIR; return 1; }
	exec_sqls
	RC=$?
	rm $COL_FILE $PK_LIST

	if [ "$DEBUG" -ne "1" ]; then
		rm -fr $SQL_DIR
	fi
	return $RC
}

function write_sql()
{
	F=`printf %07d.sql $EVENT_NUM`
	FF=$SQL_DIR/$F
	echo "$CMD;" >>$FF
}
