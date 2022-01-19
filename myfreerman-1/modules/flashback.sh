#!/bin/bash

function check_no_blob()
{
	CMD="select count(1) from information_schema.columns where table_schema = '$DATABASE' and table_name = '$TABLE_NAME' and column_type = 'blob'"
	COUNT=`mysql -N --socket="$SERVER_SOCKET" -e "$CMD"` || return 1
	if [ $COUNT -gt 0 ]; then
		write_out "Table with BLOB column is unsupported"
		return 1
	fi
}

function exec_sqls()
{
	for F in `ls -R $SQL_DIR`; do
		FF=$SQL_DIR/$F
		CMD="`cat $FF`"
		echo "$CMD;" >&5 || return 1
	done
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

function list_table_cols()
{
	mysql -N --socket="$SERVER_SOCKET" -e "desc $FQ_TABLE_NAME" | sed -e 's/\t.*//' >$COL_FILE || return 1
	cat $COL_FILE
}

function lock()
{
	exec 5> >(mysql -vvv --socket="$SERVER_SOCKET")
	CMD="lock tables $FQ_TABLE_NAME write;"
	echo "$CMD" >&5 || return 1
}

function parse_one_event()
{
	TAIL=$((LINE_COUNT-START_LINE-3))
	TMP_END_LINE=`tail -n $TAIL $SQL | grep -n -m 1 '^# at ' | cut -d : -f 1`
	END_LINE=$((TMP_END_LINE+START_LINE+2))
	HEAD=$END_LINE
	TAIL=$((END_LINE-START_LINE-2))
	head -n $HEAD $SQL | tail -n $TAIL >$EVENT
	#cat $EVENT
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
	revert_sql_cmds
	rm $SQL
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
	CMD="update $FQ_TABLE_NAME set "
	TMP_COL_COUNT=`wc -l $EVENT | cut -d \  -f 1`
	for I in `seq 1 $COL_COUNT`; do
		COL_NAME=`head -n $I $COL_FILE | tail -n 1`
		NAME_LIST="${NAME_LIST}${COL_NAME}"
		if [ $I -lt $COL_COUNT ]; then
			NAME_LIST="${NAME_LIST}, "
		fi
	done

	#mount WHERE
	START_LINE=3
	for LINE in `seq 1 $COL_COUNT`; do
		VAL=`parse_one_row_val`
		WHERE_LIST="${WHERE_LIST}${VAL}"
		if [ $LINE -lt $COL_COUNT ]; then
			WHERE_LIST="${WHERE_LIST}, "
		fi
	done

	#mount SET
	START_LINE=$((COL_COUNT+4))
	for LINE in `seq 1 $COL_COUNT`; do
		VAL=`parse_one_row_val`
		SET_LIST="${SET_LIST}${VAL}"
		if [ $LINE -lt $COL_COUNT ]; then
			SET_LIST="${SET_LIST}, "
		fi
	done

	CMD="$CMD ($NAME_LIST) = ($SET_LIST) where ($NAME_LIST) = ($WHERE_LIST)"
	write_sql
}

function revert_update2()
{
	CMD="update $FQ_TABLE_NAME set"
	TMP_COL_COUNT=`wc -l $EVENT | cut -d \  -f 1`
	for I in `seq 1 $COL_COUNT`; do
		COL_NAME=`head -n $I $COL_FILE | tail -n 1`
		NAME_LIST="${NAME_LIST}${COL_NAME}"
		if [ $I -lt $COL_COUNT ]; then
			NAME_LIST="${NAME_LIST}, "
		fi
	done

	#mount SET
	START_LINE=3
	for LINE in `seq 1 $COL_COUNT`; do
		COL_NAME=`head -n $LINE $COL_FILE | tail -n 1`
		VAL=`parse_one_row_val`
		SET_COL="$COL_NAME = $VAL"
		SET_LIST="${SET_LIST}${SET_COL}"
		if [ $LINE -lt $COL_COUNT ]; then
			SET_LIST="${SET_LIST}, "
		fi
	done

	#mount WHERE
	START_LINE=$((COL_COUNT+4))
	for LINE in `seq 1 $COL_COUNT`; do
		VAL=`parse_one_row_val`
		WHERE_LIST="${WHERE_LIST}${VAL}"
		if [ $LINE -lt $COL_COUNT ]; then
			WHERE_LIST="${WHERE_LIST}, "
		fi
	done

	CMD="$CMD $SET_LIST where ($NAME_LIST) = ($WHERE_LIST)"
	write_sql
}

function revert_sql_cmds()
{
#look for table map with required table
	STR="table_map: \`$DATABASE\`\.\`$TABLE_NAME\`"
	LINE_LIST=`mktemp /tmp/myfreerman.XXXXXX` || return 1
	#cat $SQL
	grep -ni "$STR" $SQL | cut -d : -f 1 >$LINE_LIST
	LINE_COUNT=`wc -l $SQL | cut -d \  -f 1`
	for START_LINE in `cat $LINE_LIST`; do
		cp $SQL /tmp/binlog.sql
		EVENT=`mktemp /tmp/myfreerman.XXXXXX` || return 1
		parse_one_event || return 1
		cat $EVENT
		OP=`head -n 1 $EVENT | cut -d \  -f 2`
		case $OP in
			UPDATE)
				revert_update2;;
			*)
				write_out "Unsupported command found in binlog: $OP"
				rm $LINE_LIST
				return 1;;
		esac
	done
	rm $LINE_LIST
}

function run()
{
	check_no_blob || return 1
	lock || return 1
	backup binlog || return 1
	FIRST_BINLOG=`get_first_binlog` || return 1
	if [ -z "$FIRST_BINLOG" ]; then
		exec 5>&-
		write_out "Unavailable timestamp"
		return 1
	fi
	COL_FILE=`mktemp /tmp/myfreerman.XXXXXX`
	mysql -N --socket="$SERVER_SOCKET" -e "desc $FQ_TABLE_NAME" | sed -e 's/\t.*//' >$COL_FILE || return 1
	COL_COUNT=`wc -l $COL_FILE | cut -d \  -f 1`
	SQL_DIR=`mktemp -d /tmp/myfreerman.XXXXXX` || { rm $COL_FILE; return 1; }
	read_binlogs || { rm $COL_FILE; rm -fr $SQL_DIR; exec 5>&-; return 1; }
	exec_sqls 
	RC=$?
	rm $COL_FILE
	rm -fr $SQL_DIR
	exec 5>&-
	return $RC
}

function write_sql()
{
	COUNT=`ls $SQL_DIR | wc -l`
	N=$((COUNT+1))
	F=`printf %07d.sql $N`
	FF=$SQL_DIR/$F
	echo "$CMD" >$FF
}

run $*
exit $?
