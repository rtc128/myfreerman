#!/bin/bash

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

function check_no_blob()
{
	CMD="select count(1) from information_schema.columns where table_schema = '$DATABASE' and table_name = '$TABLE_NAME' and column_type = 'blob'"
	COUNT=`mysql -N $TARGET_CRED_OPT --socket="$SERVER_SOCKET" -e "$CMD"` || return 1
	if [ $COUNT -gt 0 ]; then
		write_out "Table with BLOB column is unsupported"
		return 1
	fi
}

function exec_sqls()
{
	write_out "Running flashback script"
	for F in `ls -r $SQL_DIR`; do
		FF=$SQL_DIR/$F
		cat $FF >&5 || return 1
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

function lock()
{
	exec 5> >(mysql --socket="$SERVER_SOCKET" $TARGET_CRED_OPT)
	CMD="start transaction;"
	echo "$CMD" >&5 || return 1
	CMD="set foreign_key_checks = off;"
	echo "$CMD" >&5 || return 1
	CMD="lock tables $FQ_TABLE_NAME write;"
	echo "$CMD" >&5 || return 1
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
#get data type: first workd inside the comment
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
	mysqlbinlog --defaults-file="$SERVER_CONFIG" -vvv --base64-output=DECODE-ROWS --database=$DATABASE --result-file=$SQL --start-datetime="$REQ_TIMESTAMP" $PLAIN 2>$ERR
	RC=$?
	rm $PLAIN
	grep -vwi warning $ERR >$FERR
	rm $ERR
	write_file_out $FERR
	rm $FERR
	[ $RC -eq 0 ] || { rm $SQL; return 1; }
	revert_sql_cmds || { rm -f $SQL; return 1; }
	rm -f $SQL
}

function revert_insert()
{
	CMD="delete from $FQ_TABLE_NAME where"
	TMP_COL_COUNT=`wc -l $EVENT | cut -d \  -f 1`
	NAME_LIST="("
	for I in `seq 1 $COL_COUNT`; do
		COL_NAME=`head -n $I $COL_FILE | tail -n 1`
		NAME_LIST="${NAME_LIST}${COL_NAME}"
		if [ $I -lt $COL_COUNT ]; then
			NAME_LIST="${NAME_LIST}, "
		fi
	done
	NAME_LIST="${NAME_LIST})"

	VAL_LIST="("
	for LINE in `seq 3 $COL_COUNT`; do
		parse_one_row_val
	done
	CMD="$CMD $NAME_LIST;"
	echo $CMD
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
		CMD="update $FQ_TABLE_NAME set"
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
		revert_sql_cmds_th $I &
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

function run()
{
	check_no_blob || return 1
	get_pk || return 1
	lock || { rm $PK_LIST; return 1; }
	backup binlog || { rm $PK_LIST; return 1; }
	FIRST_BINLOG=`get_first_binlog` || { rm $PK_LIST; return 1; }
	if [ -z "$FIRST_BINLOG" ]; then
		write_out "Unavailable timestamp"
		{ rm $PK_LIST; return 1; }
	fi
	COL_FILE=`mktemp /tmp/myfreerman.XXXXXX`
	mysql -N --socket="$SERVER_SOCKET" $TARGET_CRED_OPT -e "desc $FQ_TABLE_NAME" | sed -e 's/\t.*//' >$COL_FILE || { rm $COL_FILE$ PK_LIST; return 1; }
	COL_COUNT=`wc -l $COL_FILE | cut -d \  -f 1`
	SQL_DIR=`mktemp -d /tmp/myfreerman.XXXXXX` || { rm $COL_FILE $PK_LIST; return 1; }
	read_binlogs || { rm $COL_FILE; rm -fr $PK_LIST $SQL_DIR; return 1; }
	exec_sqls 
	RC=$?
	rm $COL_FILE $PK_LIST
	rm -fr $SQL_DIR
	return $RC
}

function write_sql()
{
	F=`printf %07d.sql $EVENT_NUM`
	FF=$SQL_DIR/$F
	echo "$CMD;" >>$FF
}

run $*
exit $?
