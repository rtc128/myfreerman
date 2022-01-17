#!/bin/bash

function query_first_binlog()
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
	exec 5> >(mysql --socket="$SERVER_SOCKET")
	CMD="lock tables $FQ_TABLE_NAME write;"
	echo "$CMD" >&5 || return 1
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

function revert_sql_cmds()
{
#look for table map with required table
	STR="table_map: \`$DATABASE\`\.\`$TABLE_NAME\`"
	LINE_LIST=`mktemp /tmp/myfreerman.XXXXXX` || return 1
	grep -ni "$STR" $SQL | cut -d : -f 1 >$LINE_LIST
	cat $LINE_LIST
	rm $LINE_LIST
}

function run()
{
	COL_FILE=`mktemp /tmp/myfreerman.XXXXXX`
	list_table_cols || return 1
	rm $COL_FILE
	lock || return 1
	backup binlog || return 1
	FIRST_BINLOG=`query_first_binlog` || return 1
	if [ -z "$FIRST_BINLOG" ]; then
		exec 5>&-
		write_out "Unavailable timestamp"
		return 1
	fi
#create file for full sql
	read_binlogs
	exec 5>&-
}

run $*
exit $?
