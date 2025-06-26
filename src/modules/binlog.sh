#!/bin/bash

function binlog_get_current_master_binlog()
{
	BUFF=`mktemp /tmp/myfreerman.XXXXXX`
	ERR=`mktemp /tmp/myfreerman.XXXXXX`
	mysql --socket="$SERVER_SOCKET" $TARGET_CRED_OPT_NOPWD -e 'show master status\G' | grep -vwi warning >$BUFF 2>$ERR
	RC=$?
	write_file_out $ERR
	rm $ERR
	#check if output is not empty
	SIZE=`stat -c %s $BUFF`
	if [ $SIZE -eq 0 ]; then
		return 1
	fi
	[ $RC -eq 0 ] || { rm $BUFF; return 1; }
	LONG_SEQ=`grep -wi file $BUFF | awk '{ print $2; }' | cut -d . -f 2`
	POS=`grep -wi position $BUFF | awk '{ print $2; }'`
	rm $BUFF
	SHORT_SEQ=`expr $LONG_SEQ + 0`
	echo "$SHORT_SEQ:$POS"
}

function binlog_do_list_events()
{
	_list_events_validate_params || return 1

	lock_binlog_lock || return 1

	OUTPUT=`mktemp /tmp/myfreerman.XXXXXX`
	if [ -n "$BINLOG_FILE" ]; then
		if [ $DETAILED -eq 1 ]; then
			_list_one_binlog_events_detailed "$BINLOG_FILE" "" "$OUTPUT" || return 1
		else
			_list_one_binlog_events "$BINLOG_FILE" "" "$OUTPUT" || return 1
		fi
	else
		_list_local_events "$START_TIME" $OUTPUT
		if [ $? -eq 1 ]; then
			return 1
		fi
		if [ $? -ne 100 ]; then
			_list_backup_events "$START_TIME" $OUTPUT || return 1
		fi
	fi
	sort $OUTPUT
	rm $OUTPUT
}

function binlog_do_list_transactions()
{
	_list_transactions_validate_params || return 1

	RETCODE=$?
	if [ $RETCODE -eq 1 ]; then
		return 1
	fi
	if [ $USE_RELAY -eq 1 ]; then
		_list_relay_transactions || return 1
	else
		_list_backup_transactions || return 1
		_list_local_transactions || return 1
	fi
}

function _binlog_expand_timestamp_txn()
{
	TS=$1
	if [ ${#TS} -eq 4 ]; then
		H=${TS:0:2}
		M=${TS:2:2}
		date +%Y%m%d${H}${M}00 || return 1
		return
	fi
	if [ ${#TS} -eq 6 ]; then
		D=${TS:0:2}
		H=${TS:2:2}
		M=${TS:4:2}
		date +%Y%m${D}${H}${M}00 || return 1
		return
	fi
	if [ ${#TS} -eq 8 ]; then
		MON=${TS:0:2}
		D=${TS:2:2}
		H=${TS:4:2}
		MIN=${TS:6:2}
		date +%Y${MON}${D}${H}${MIN}00 || return 1
		return
	fi
	echo $TS
}

function _binlog_find_first_binlog_backup_by_date()
{
	local MIN_DATE="$1"

#return 0 means there's no binlog backup after the asked date
	local RESULT=0
#list files in backup
	local LIST=`ls "$BINLOG_BACKUP_DIR"` || return 1
#find the first one that was saved after the start time we want
	for F in $LIST; do
		local FULL_PATH="$BINLOG_BACKUP_DIR/$F"
		local TMP_FTIME="`stat -c %y \"$FULL_PATH\"`"
		local FTIME=`echo $TMP_FTIME | cut -d . -f 1`
		if [[ "$FTIME" > "$MIN_DATE" ]]; then
			#get binlog sequence
			local LSEQ=`echo $F | cut -d . -f 2`
#result is the sequence, but with no leading 0's
			RESULT=`expr $LSEQ + 0`
			break
		fi
	done
	echo $RESULT
}

function _list_backup_events()
{
	MIN_DATE="$1"
	OUTPUT="$2"
	#if backup binlog dir doesn't exist, list empty
	if ! [ -d "$BINLOG_BACKUP_DIR" ]; then
		return
	fi
	LIST=`ls -r "$BINLOG_BACKUP_DIR"`
	for F in $LIST; do
		FPATH="$BINLOG_BACKUP_DIR/$F"
		#if it is compressed, uncompress
		if file "$FPATH" | grep -wi "compressed" >/dev/null; then
			SEQ=`echo $F | cut -d . -f 2`
			BINLOG=`mktemp /tmp/myfreerman.XXXXXX.${SEQ}`
			gunzip -c "$FPATH" >$BINLOG || { rm $BINLOG; return 1; }
			_list_one_binlog_events "${BINLOG}" "$MIN_DATE" "$OUTPUT"
			RC=$?
			rm $BINLOG
			if [ $RC -eq 100 ]; then
				break
			fi
			continue
		fi
		#if it is plain binlog, just call function
		if file "$FPATH" | grep -wi "mysql" >/dev/null; then
			_list_one_binlog_events "${FPATH}" "$MIN_DATE" "$OUTPUT"
			if [ $? -eq 100 ]; then
				break
			fi
			continue
		fi
		#unknown type
		write_out "Not a binary log file [$FPATH]"
		return 1
	done
}

function _list_backup_transactions()
{
	local MIN_DATE="$START_TIME"

	#if backup binlog dir doesn't exist, list empty
	if ! [ -d "$BINLOG_BACKUP_DIR" ]; then
		return
	fi
	local SSEQ=`_binlog_find_first_binlog_backup_by_date "$MIN_DATE"`
	local LSEQ=`printf %06d $SSEQ`
	local FPATH="$BINLOG_BACKUP_DIR/binlog.$LSEQ.gz"
	while [ -f "$FPATH" ]; do
		local HANDLED=0
		#if it is compressed, uncompress
		if file "$FPATH" | grep -wi "compressed" >/dev/null; then
			BINLOG=`mktemp /tmp/myfreerman.XXXXXX`
			gunzip -c "$FPATH" >$BINLOG || { rm $BINLOG; return 1; }
			_list_one_binlog_transactions ${BINLOG} || return 1;
			rm $BINLOG
			HANDLED=1
		fi
		#if it is plain binlog, just call function
		if file "$FPATH" | grep -wi "mysql" >/dev/null; then
			_list_one_binlog_transactions "${FPATH}"
			HANDLED=1
		fi
		if [ $HANDLED -eq 0 ]; then
			#unknown type
			write_out "Not a binary log file [$FPATH]"
			return 1
		fi
		SSEQ=`expr $SSEQ + 1`
		LSEQ=`printf %06d $SSEQ`
		FPATH="$BINLOG_BACKUP_DIR/binlog.$LSEQ.gz"
	done
}

function _list_events_validate_params()
{
	#one of START TIME or MINUTES must be informed
	if [ -z "$START_TIME" -a -z "$MINUTES" ]; then
		write_out "At least 'start time' or 'minutes' must be informed"
		return 1
	fi

	#if binlog specified, check if it exists
	if [ -n "$BINLOG_FILE" ]; then
		if ! [ -f "$BINLOG_FILE" ]; then
			write_out "No such file [$BINLOG_FILE]"
			return 1
		fi
		#and check if it is really a binlog
		if ! file "$BINLOG_FILE" | grep -wi replication >/dev/null; then
			write_out "Not a binary log file [$BINLOG_FILE]"
			return 1
		fi
	fi

	#if minutes informed, check it
	#start time cannot be informed, end time cannot be informed
	if [ -n "$MINUTES" ]; then
		if [ $MINUTES -le 0 ]; then
			write_out "Invalid number of minutes"
			return 1
		fi
		if [ -n "$START_TIME" ]; then
			write_out "'Start time' and 'minutes' cannot be informed together"
			return 1
		fi
		if [ -n "$END_TIME" ]; then
			write_out "'End time' and 'minutes' cannot be informed together"
			return 1
		fi
		START_TIME=`date --date="-$MINUTES minutes" +"%F %T"`
	fi

	#if end timestamp is informed, start timestamp must also be
	if [ -n "$END_TIME" ]; then
		if [ -z "$START_TIME" ]; then
			write_out "When 'end time' is informed, 'start time' must also be informed"
			return 1
		fi
		END_TIME=`_binlog_expand_timestamp_txn $END_TIME`
		[ -n "$END_TIME" ] || return 1
	fi

	#if start timestamp is informed (and not minutes), expand it
	if [ -n "$START_TIME" -a -z "$MINUTES" ]; then
		START_TIME=`_binlog_expand_timestamp_txn $START_TIME`
		[ -n "$START_TIME" ] || return 1
	fi
}

function _list_local_events()
{
	START_TIME="$1"
	OUTPUT="$2"

	#check if server has binary logs
	LOG_BIN=`get_server_config log_bin` || return 1
	[ -n "$LOG_BIN" ] || return 1
	if [ $LOG_BIN -eq 0 ]; then
		write_out "Logging is disbled in server"
		return 1
	fi

	#binlog directory
	LOG_BIN_BASENAME=`mysql --socket="$SERVER_SOCKET" $TARGET_CRED_OPT_NOPWD -e "show variables like 'log_bin_basename'" | tail -n 1 | cut -f 2 -d$'\t'` || return 1
	BINLOG_DIRECTORY="`dirname \"$LOG_BIN_BASENAME\"`"

	#list binlogs
	BINLOG_LIST=`mktemp /tmp/myfreerman.XXXXXX`
	list_server_binlogs >$BINLOG_LIST || return 1

	#for each binlog, from last to first
	COUNT=`wc -l $BINLOG_LIST | cut -d \  -f 1`
	for i in `seq 1 $COUNT`; do
		NAME=`tail -n $i $BINLOG_LIST | head -n 1`
		FULL_NAME="${BINLOG_DIRECTORY}/${NAME}"
		_list_one_binlog_events "${FULL_NAME}" "$START_TIME" "$OUTPUT"
		if [ $? -eq 100 ]; then
			rm $BINLOG_LIST
			return 100
		fi
	done
	rm $BINLOG_LIST
}

function _list_local_transactions()
{
	#check if server has binary logs
	LOG_BIN=`get_server_config log_bin` || return 1
	[ -n "$LOG_BIN" ] || return 1
	if [ $LOG_BIN -eq 0 ]; then
		write_out "Logging is disabled in server"
		return 1
	fi

	#binlog directory
	LOG_BIN_BASENAME=`mysql --socket="$SERVER_SOCKET" $TARGET_CRED_OPT_NOPWD -e "show variables like 'log_bin_basename'" | tail -n 1 | cut -f 2 -d$'\t'` || return 1
	BINLOG_DIRECTORY="`dirname \"$LOG_BIN_BASENAME\"`"

	#list binlogs
	BINLOG_LIST=`mktemp /tmp/myfreerman.XXXXXX`
	LIST=`list_server_binlogs` || return 1

	for NAME in $LIST; do
		FULL_NAME="${BINLOG_DIRECTORY}/${NAME}"
		if [ -f "$FULL_NAME" ]; then
			_list_one_binlog_transactions "${FULL_NAME}"
		fi
	done
}

function _list_relay_transactions()
{
	#get current relay
	ERR_BUFF=`mktemp /tmp/myfreerman.XXXXXX`
	OUT_BUFF=`mktemp /tmp/myfreerman.XXXXXX`
	mysql --socket="$SERVER_SOCKET" $TARGET_CRED_OPT_NOPWD -e 'show replica status\G' >$OUT_BUFF 2>$ERR_BUFF
	RC=$?
	write_file_out $ERR_BUFF
	rm $ERR_BUFF
	[ $RC -eq 0 ] || { rm $OUT_BUFF; return 1; }
	LOG_FILE=`grep -wi relay_log_file $OUT_BUFF | cut -d : -f 2 | tr -d ' '`
	rm $OUT_BUFF
	[ -n "$LOG_FILE" ] || { write_out "No relay log in use"; return 0; }
	RELAY_LOG_CONF=`mysql -N --socket="$SERVER_SOCKET" $TARGET_CRED_OPT_NOPWD -e 'select @@relay_log'`

	RELAY_LOG_DIR="`dirname $RELAY_LOG_CONF`"
	if [ "$RELAY_LOG_DIR" == "." ]; then
		RELAY_LOG_DIR="$DATADIR"
	fi
	FULL_NAME="$RELAY_LOG_DIR/$LOG_FILE"
	_list_one_binlog_transactions "${FULL_NAME}" || return 1
}

function _list_one_binlog_events()
{
	FULL_PATH="$1"
	START_TIME="$2"
	OUTPUT="$3"

	#if binlog does not exist, just ignore it because probably binlogs were flushed
	if ! [ -f "$FULL_PATH" ]; then
		return
	fi

	#sequence is the last 6 chars in binlog path
	SEQ=${FULL_PATH:(-6)}

	local MARK_LIST=`mktemp /tmp/myfreerman.XXXXXX`

	if [ -n "$START_TIME" ]; then
		#list only marks
		if [ -n "$END_TIME" ]; then
			mysqlbinlog --defaults-file="$SERVER_CONFIG" --start-datetime="$START_TIME" --stop-datetime="$END_TIME" "$FULL_PATH" | grep -Ew 'Table_map|STMT_END_F' >$MARK_LIST
		else
			mysqlbinlog --defaults-file="$SERVER_CONFIG" --start-datetime="$START_TIME" "$FULL_PATH" | grep -Ew 'Table_map|STMT_END_F' >$MARK_LIST
		fi
	else
		mysqlbinlog --defaults-file="$SERVER_CONFIG" "$FULL_PATH" | grep -Ew 'Table_map|STMT_END_F' >$MARK_LIST
	fi

	TOTAL_LINES=`wc -l $MARK_LIST | cut -d \  -f 1`
	#if mark list is empty, inform we are already before min date
	if [ $TOTAL_LINES -eq 0 ]; then
		rm $MARK_LIST
		return 100
	fi

	#if thread count is greater than 50% of total lines, reduce it
	HALF_LINES=`expr $TOTAL_LINES / 2`
	if [ $PROCESS_THREADS -gt $HALF_LINES ]; then
		PROCESS_THREADS=$HALF_LINES
	fi

	THREAD_LINE_COUNT=$((TOTAL_LINES/PROCESS_THREADS+1))

	#if thread line count is odd, make it even
	MOD=$(($THREAD_LINE_COUNT%2))
	if [ $MOD -eq 1 ]; then
		THREAD_LINE_COUNT=$((THREAD_LINE_COUNT+1))
	fi

	START_LINE=1
	for I in `seq 1 $PROCESS_THREADS`; do
		_list_one_binlog_events_th "$MARK_LIST" $TOTAL_LINES $START_LINE $THREAD_LINE_COUNT "$OUTPUT" &
		START_LINE=$((START_LINE+THREAD_LINE_COUNT))
	done
	wait

	rm $MARK_LIST
}

function _list_one_binlog_transactions()
{
	local FULL_PATH="$1"
	local SQL=`mktemp /tmp/myfreerman.XXXXXX`


	local DEL
	local INS
	local FINAL_TABLE
	local FIRST_LINE
	local SQL
	local TABLE_NAME
	local TIMESTAMP
	local TH_ID
	local T_DATA
	local TABLE
	local TOTAL
	local UPD
	local INSIDE_TXN=0
	
	declare -A INS_TAB
	declare -A UPD_TAB
	declare -A DEL_TAB

	TOTAL=0
	INS_TAB=()
	UPD_TAB=()
	DEL_TAB=()

	START_TIME_OPT=
	if [  -n "$START_TIME" ]; then
		START_TIME_OPT=--start-datetime=${START_TIME}
	fi
	STOP_TIME_OPT=
	if [  -n "$STOP_TIME" ]; then
		STOP_TIME_OPT=--stop-datetime=${END_TIME}
	fi
	mysqlbinlog --defaults-file="$SERVER_CONFIG" -v $START_TIME_OPT $STOP_TIME_OPT --result-file=$SQL "$FULL_PATH" || { rm $SQL; return 1; }

	#for each line
	while IFS= read -r LINE; do
		#if not inside a txn and line has a timestamp, save it, because it could be the txn's timestamp
		if [ $INSIDE_TXN -eq 0 ]; then
			if [[ "$LINE" =~ " end_log_pos " ]]; then
				TIMESTAMP=`echo $LINE | cut -d \  -f 2`
			fi
		fi

		#check if starting a txn
		if [[ "$LINE" =~ ^"BEGIN" ]]; then
			INSIDE_TXN=1
		fi

		#INSERT?
		if [[ "$LINE" =~ "### INSERT ".* ]]; then
			((TOTAL++))
			if [ $SUMMARY -eq 0 ]; then
				#get table name
				TABLE_NAME=`echo "$LINE" | cut -d \  -f 4`
				TABLE_NAME=${TABLE_NAME//\`/}

				if [ -z "${INS_TAB[$TABLE_NAME]}" ]; then
					INS_TAB[$TABLE_NAME]=1
				else
					INS_TAB[$TABLE_NAME]=`expr ${INS_TAB[$TABLE_NAME]} + 1`
				fi

				if [ -z "${UPD_TAB[$TABLE_NAME]}" ]; then
					UPD_TAB[$TABLE_NAME]=0
				fi
				if [ -z "${DEL_TAB[$TABLE_NAME]}" ]; then
					DEL_TAB[$TABLE_NAME]=0
				fi
			fi
		fi
		#UPDATE?
		if [[ "$LINE" =~ "### UPDATE ".* ]]; then
			((TOTAL++))
			if [ $SUMMARY -eq 0 ]; then
				#get table name
				TABLE_NAME=`echo "$LINE" | cut -d \  -f 3`
				TABLE_NAME=${TABLE_NAME//\`/}

				if [ -z "${UPD_TAB[$TABLE_NAME]}" ]; then
					UPD_TAB[$TABLE_NAME]=1
				else
					UPD_TAB[$TABLE_NAME]=`expr ${UPD_TAB[$TABLE_NAME]} + 1`
				fi

				if [ -z "${INS_TAB[$TABLE_NAME]}" ]; then
					INS_TAB[$TABLE_NAME]=0
				fi
				if [ -z "${DEL_TAB[$TABLE_NAME]}" ]; then
					DEL_TAB[$TABLE_NAME]=0
				fi
			fi
		fi
		#DELETE?
		if [[ "$LINE" =~ "### DELETE ".* ]]; then
			((TOTAL++))
			if [ $SUMMARY -eq 0 ]; then
				#get table name
				TABLE_NAME=`echo "$LINE" | cut -d \  -f 4`
				TABLE_NAME=${TABLE_NAME//\`/}

				if [ -z "${DEL_TAB[$TABLE_NAME]}" ]; then
					DEL_TAB[$TABLE_NAME]=1
				else
					DEL_TAB[$TABLE_NAME]=`expr ${DEL_TAB[$TABLE_NAME]} + 1`
				fi

				if [ -z "${INS_TAB[$TABLE_NAME]}" ]; then
					INS_TAB[$TABLE_NAME]=0
				fi
				if [ -z "${UPD_TAB[$TABLE_NAME]}" ]; then
					UPD_TAB[$TABLE_NAME]=0
				fi
			fi
		fi

		#if ending txn, print that
		if [[ "$LINE" =~ ^"COMMIT" ]]; then
			if [ $SUMMARY -eq 0 ]; then
				local T_DATA=
				for TABLE in "${!INS_TAB[@]}"; do
					FINAL_TABLE=$TABLE
					#check if it is default schema
					if [ -n "$DEFAULT_SCHEMA" ]; then
						SCHEMA=`echo $TABLE | cut -d . -f 1`
						BASE_TABLE=`echo $TABLE | cut -d . -f 2`
						if [ "$DEFAULT_SCHEMA" == "$SCHEMA" ]; then
							FINAL_TABLE=$BASE_TABLE
						fi
					fi

					INS="${INS_TAB[$TABLE]}"
					UPD="${UPD_TAB[$TABLE]}"
					DEL="${DEL_TAB[$TABLE]}"
					T_DATA="${T_DATA}${FINAL_TABLE}:${INS},${UPD},${DEL};"
				done
				printf "%-10s %-8s %s\n" $TIMESTAMP $TOTAL $T_DATA
			else
				printf "%-10s %-8s\n" $TIMESTAMP $TOTAL
			fi

			INS_TAB=()
			UPD_TAB=()
			DEL_TAB=()
			TOTAL=0
			INSIDE_TXN=0
		fi
	done <$SQL
	rm $SQL
}

function _list_one_binlog_events_th()
{
	INPUT="$1"
	TOTAL_LINES=$2
	START_LINE=$3
	LINE_COUNT=$4
	OUTPUT="$5"
	
	#if our first line is greater than total number of lines of the file, just ignore it
	if [ $START_LINE -gt $TOTAL_LINES ]; then
		return
	fi
	MARK_LIST=`mktemp /tmp/myfreerman.XXXXXX`
	TAIL=$((TOTAL_LINES-START_LINE+1))
	tail -n $TAIL "$INPUT" | head -n $LINE_COUNT >$MARK_LIST

	#for each line
	while IFS= read -r LINE; do
		#if line is a table mapping, save table name and position of the end of the mapping, which is the beginning of the event
		if [[ "$LINE" =~ .*"Table_map".* ]]; then
			MAP_END_LOG_POS=`echo $LINE | cut -d \  -f 7`
			TABLE=`echo $LINE | cut -d \  -f 11 | tr -d \\\``
			continue
		fi
		#if line is STATEMENT END
		if [ -n "$TABLE" ] && [[ "$LINE" =~ .*"STMT_END_F".* ]]; then
			STMT_END_LOG_POS=`echo $LINE | cut -d \  -f 7`
			ENC_SIZE=$((STMT_END_LOG_POS-MAP_END_LOG_POS))
			SIZE=`scale=0; echo $ENC_SIZE \* 1.4 | bc -s`

			Y="20${LINE:1:2}"
			M="${LINE:3:2}"
			D="${LINE:5:2}"
			DATE="$Y-$M-$D"
			TIME="${LINE:8:8}"
			#if hour has only one digit, prepend '0'
			FIRST_DIGIT="${TIME:0:1}"
			if [ "$FIRST_DIGIT" == " " ]; then
				TIME="0${TIME:1:7}"
			fi

			#operation
			RAW_OP=`echo $LINE | cut -d \  -f 10`
			#split op name and uppercate
			L_OP=`echo $RAW_OP | cut -d _ -f 1`
			OP=${L_OP^^}
			#'WRITE' means INSET
			if [ "$OP" == "WRITE" ]; then
				OP="INSERT"
			fi

			SIZE_MB=`echo scale=1\; $SIZE / 1024 / 1024 | bc -s | sed -e 's/^\./0\./'`
			if [ "$RMAN_USE_BYTES" == "1" ]; then
				printf "%s %s %s %s %-80s %s\n" $SEQ $DATE $TIME $OP $TABLE $SIZE >>"$OUTPUT"
			else
				printf "%s %s %s %s %-80s %s\n" $SEQ $DATE $TIME $OP $TABLE $SIZE_MB >>"$OUTPUT"
			fi
			TABLE=
		fi
	done <$MARK_LIST
	rm $MARK_LIST
}


function _list_one_binlog_events_detailed()
{
	FULL_PATH="$1"
	START_TIME="$2"
	OUTPUT="$3"

	#if binlog does not exist, just ignore it because probably binlogs were flushed
	if ! [ -f "$FULL_PATH" ]; then
		return
	fi

	#sequence is the last 6 chars in binlog path
	SEQ=${FULL_PATH:(-6)}

	SQL=`mktemp /tmp/myfreerman.XXXXXX`
	ENDT_OPT=`_mount_end_time_option`
	if [ -n "$START_TIME" ]; then
		if [ -n "$END_TIME" ]; then
			mysqlbinlog --defaults-file="$SERVER_CONFIG" --start-datetime="$START_TIME" --stop-datetime="$END_TIME" --result-file=$SQL "$FULL_PATH" || { rm $SQL; return 1; }
		else
			mysqlbinlog --defaults-file="$SERVER_CONFIG" --start-datetime="$START_TIME" --result-file=$SQL "$FULL_PATH" || { rm $SQL; return 1; }
		fi
	else
		mysqlbinlog --defaults-file="$SERVER_CONFIG" --result-file=$SQL "$FULL_PATH" || { rm $SQL; return 1; }
	fi
	SQL_LINE_COUNT=`wc -l $SQL | awk '{ print $1; }'`

	START_CMD_LIST=`mktemp /tmp/myfreerman.XXXXXX`
	grep -wn ^BINLOG $SQL | cut -d : -f 1 >$START_CMD_LIST

	TOTAL_LINES=`wc -l $START_CMD_LIST | cut -d \  -f 1`
	#if start list is empty, inform we are already before min date
	if [ $TOTAL_LINES -eq 0 ]; then
		rm $MARK_LIST
		return 100
	fi

	if [ $PROCESS_THREADS -gt $TOTAL_LINES ]; then
		PROCESS_THREADS=$TOTAL_LINES
	fi

	THREAD_LINE_COUNT=$((TOTAL_LINES/PROCESS_THREADS))
	#if there's gonna be ramining lines in the end, add one
	MOD=$((TOTAL_LINES%PROCESS_THREADS))
	if [ $MOD -ne 0 ]; then
		THREAD_LINE_COUNT=$((THREAD_LINE_COUNT+1))
	fi

	START_LINE=1
	for I in `seq 1 $PROCESS_THREADS`; do
		LOCAL_LIST=`mktemp /tmp/myfreerman.XXXXXX`
		HEAD=$((START_LINE+THREAD_LINE_COUNT-1))
		TAIL=$THREAD_LINE_COUNT
		head -n $HEAD $START_CMD_LIST | tail -n $TAIL >$LOCAL_LIST
		_list_one_binlog_events_detailed_th $SQL $SQL_LINE_COUNT $LOCAL_LIST "$OUTPUT" &
		START_LINE=$((START_LINE+THREAD_LINE_COUNT))
	done
	wait

	rm $SQL $START_CMD_LIST
}

function _list_one_binlog_events_detailed_th()
{
	SQL=$1
	SQL_TOTAL_LINES=$2
	LOCAL_LIST=$3
	OUTPUT="$4"

	for LINE in `cat "$LOCAL_LIST"`; do
		TAIL=$((SQL_TOTAL_LINES-LINE+1))
		FULL_CMD=`mktemp /tmp/myfreerman.XXXXXX`
		HEAD=`tail -n $TAIL $SQL | grep -n -m 1 '\;' | cut -d : -f 1`
		tail -n $TAIL $SQL | head -n $HEAD >$FULL_CMD
		SIZE=`stat --format=%s $FULL_CMD`
		#remove LF
		SIZE=$((SIZE-1))
		rm $FULL_CMD
		if [ $SIZE -lt 500 ]; then
			continue
		fi
		if [ "$RMAN_USE_BYTES" == "1" ]; then
			echo $SIZE
		else
			echo scale=1\; $SIZE / 1024 / 1024 | bc -s | sed -e 's/^\./0\./'
		fi
	done
	rm $LOCAL_LIST
}

function _list_transactions_validate_params()
{
	#if using relay, cannot choose minutes, start time or end time
	if [ $USE_RELAY -eq 1 ]; then
		if [ -n "$START_TIME" ]; then
			write_out "When using relay log, start time can't be informed"
			return 1
		fi
		if [ -n "$END_TIME" ]; then
			write_out "When using relay log, end time can't be informed"
			return 1
		fi
		if [ -n "$MINUTES" ]; then
			write_out "When using relay log, minutes can't be informed"
			return 1
		fi
	fi

	#one of START TIME or MINUTES must be informed
	if [ $USE_RELAY -eq 0 -a -z "$START_TIME" -a -z "$MINUTES" ]; then
		write_out "When not using relay log, at least 'start time' or 'minutes' must be informed"
		return 1
	fi

	#if minutes informed, check it
	#start time cannot be informed, end time cannot be informed
	if [ -n "$MINUTES" ]; then
		if [ $MINUTES -le 0 ]; then
			write_out "Invalid number of minutes"
			return 1
		fi
		if [ -n "$START_TIME" ]; then
			write_out "'Start time' and 'minutes' cannot be used together"
			return 1
		fi
		if [ -n "$END_TIME" ]; then
			write_out "'End time' and 'minutes' cannot be used together"
			return 1
		fi
		START_TIME=`date --date="-$MINUTES minutes" +"%F %T"`
	fi

	#if end timestamp is informed, start timestamp must also be
	if [ -n "$END_TIME" ]; then
		if [ -z "$START_TIME" ]; then
			write_out "When 'end time' is informed, 'start time' must also be informed"
			return 1
		fi
		END_TIME=`_binlog_expand_timestamp_txn $END_TIME`
		[ -n "$END_TIME" ] || return 1
	fi

	#if start timestamp is informed (and not minutes), expand it
	if [ -n "$START_TIME" -a -z "$MINUTES" ]; then
		START_TIME=`_binlog_expand_timestamp_txn $START_TIME`
		[ -n "$START_TIME" ] || return 1
	fi
	if [ -z "$END_TIME" ]; then
		END_TIME=`date +"%F %T"`
	fi
}

function _mount_end_time_option()
{
	if [ -n "$END_TIME" ]; then
		echo --stop-datetime=\"$END_TIME\"
	fi
}
