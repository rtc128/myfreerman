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

	OUTPUT=`mktemp /tmp/myfreerman.XXXXXX`
	_list_local_transactions "$START_TIME" $OUTPUT
	if [ $? -eq 1 ]; then
		return 1
	fi
	if [ $? -ne 100 ]; then
		_list_backup_transactions "$START_TIME" $OUTPUT || return 1
	fi
	sort $OUTPUT
	rm $OUTPUT
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
			BINLOG=`mktemp /tmp/myfreerman.XXXXXX`
			gunzip -c "$FPATH" >$BINLOG || { rm $BINLOG; return 1; }
			_list_one_binlog_transactions "${BINLOG}" "$MIN_DATE" "$OUTPUT"
			RC=$?
			rm $BINLOG
			if [ $RC -eq 100 ]; then
				break
			fi
			continue
		fi
		#if it is plain binlog, just call function
		if file "$FPATH" | grep -wi "mysql" >/dev/null; then
			_list_one_binlog_transactions "${FPATH}" "$MIN_DATE" "$OUTPUT"
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
		END_TIME=`expand_timestamp $END_TIME`
		END_TIME="${END_TIME/_/ }"
		[ -n "$END_TIME" ] || return 1
	fi

	#if start timestamp is informed (and not minutes), expand it
	if [ -n "$START_TIME" -a -z "$MINUTES" ]; then
		START_TIME=`expand_timestamp $START_TIME`
		[ -n "$START_TIME" ] || return 1
		START_TIME="${START_TIME/_/ }"
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
		_list_one_binlog_transactions "${FULL_NAME}" "$START_TIME" "$OUTPUT"
		if [ $? -eq 100 ]; then
			rm $BINLOG_LIST
			return 100
		fi
	done
	rm $BINLOG_LIST
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
	FULL_PATH="$1"
	START_TIME="$2"
	OUTPUT="$3"

	#if binlog does not exist, just ignore it because probably binlogs were flushed
	if ! [ -f "$FULL_PATH" ]; then
		return
	fi

	#sequence is the last 6 chars in binlog path
	SEQ=${FULL_PATH:(-6)}

	local SQL=`mktemp /tmp/myfreerman.XXXXXX`

	if [ -n "$START_TIME" ]; then
		#list only marks
		if [ -n "$END_TIME" ]; then
			mysqlbinlog --defaults-file="$SERVER_CONFIG" -v --start-datetime="$START_TIME" --stop-datetime="$END_TIME" --result-file=$SQL "$FULL_PATH"
		else
			mysqlbinlog --defaults-file="$SERVER_CONFIG" -v --start-datetime="$START_TIME" --result-file=$SQL "$FULL_PATH"
		fi
	else
		mysqlbinlog --defaults-file="$SERVER_CONFIG" -v --result-file=$SQL "$FULL_PATH"
	fi

	local LINE_LIST=`mktemp /tmp/myfreerman.XXXXXX`
	grep -n '^BEGIN$' $SQL | cut -d : -f 1 >$LINE_LIST
	TOTAL_LINES=`wc -l $LINE_LIST | cut -d \  -f 1`

	#if mark list is empty, inform we are already before min date
	if [ $TOTAL_LINES -eq 0 ]; then
		rm $LINE_LIST
		return 100
	fi

	TH_LINE_COUNT=$((TOTAL_LINES/PROCESS_THREADS))
	#if not exact division, add one line for each thread
	if [ $(expr $TOTAL_LINES % $PROCESS_THREADS) != "0" ]; then
		((TH_LINE_COUNT++))
	fi

	START_LINE=1
	for I in `seq 1 $PROCESS_THREADS`; do
		_list_one_binlog_transactions_th $LINE_LIST $SQL $START_LINE $TH_LINE_COUNT "$OUTPUT" &
		START_LINE=$((START_LINE+TH_LINE_COUNT))
	done
	wait

	if [ "$DEBUG" != "1" ]; then
		rm $LINE_LIST
		rm $SQL
	fi
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

function _list_one_binlog_transactions_th()
{
	local LINE_LIST=$1
	local SQL=$2
	local TH_START_LINE=$3
	local TH_LINE_COUNT=$4
	local OUTPUT=$5

	local INS_COUNT
	local UPD_COUNT
	local DEL_COUNT
	local TOTAL
	
	local LINES_TOTAL_LINES=`wc -l $LINE_LIST | awk '{ print $1; }'`
	local SQL_TOTAL_LINES=`wc -l $SQL | awk '{ print $1; }'`
	local LINES_START_LINE=$TH_START_LINE

	for I in `seq 1 $TH_LINE_COUNT`; do
		#if our first line is greater than total number of lines of the file, just ignore it
		if [ $LINES_START_LINE -gt $LINES_TOTAL_LINES ]; then
			return
		fi

		SQL_CUR_LINE=`head -n $LINES_START_LINE $LINE_LIST | tail -n 1`
		TCOUNT=`expr $SQL_TOTAL_LINES - $SQL_CUR_LINE + 1`
		COMMIT_LINE=`tail -n $TCOUNT $SQL | grep -nwi -m 1 ^commit | cut -d : -f 1`

		#timestamp is in the last line with "at" before the line with "BEGIN"
		TIMESTAMP=`head -n $SQL_CUR_LINE $SQL | tail -n 6 | grep -A 1 -w at | tail -n 1 | cut -d \  -f 2`
		#TIMESTAMP=`head -n $SQL_CUR_LINE $SQL | tail -n 4 | head -n 1 | cut -d \  -f 2`

		TXN=`mktemp /tmp/myfreerman.XXXXXX`
		tail -n $TCOUNT $SQL | head -n $COMMIT_LINE >$TXN

		INS_COUNT=0
		UPD_COUNT=0
		DEL_COUNT=0

		#for each line
		while IFS= read -r LINE; do
			#INSERT?
			if [[ "$LINE" =~ "### INSERT ".* ]]; then
				((INS_COUNT++))
			fi
			#UPDATE?
			if [[ "$LINE" =~ "### UPDATE ".* ]]; then
				((UPD_COUNT++))
			fi
			#DELETE?
			if [[ "$LINE" =~ "### DELETE ".* ]]; then
				((DEL_COUNT++))
			fi
		done <$TXN
		if [ "$DEBUG" != "1" ]; then
			rm $TXN
		fi

		TOTAL=$((INS_COUNT+UPD_COUNT+DEL_COUNT))
		printf "%-12s %-7s %-7s %-7s %-7s\n" $TIMESTAMP $INS_COUNT $UPD_COUNT $DEL_COUNT $TOTAL >>"$OUTPUT"
		((LINES_START_LINE++))
	done
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
	#one of START TIME or MINUTES must be informed
	if [ -z "$START_TIME" -a -z "$MINUTES" ]; then
		write_out "At least 'start time' or 'minutes' must be informed"
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
		END_TIME=`expand_timestamp $END_TIME`
		END_TIME="${END_TIME/_/ }"
		[ -n "$END_TIME" ] || return 1
	fi

	#if start timestamp is informed (and not minutes), expand it
	if [ -n "$START_TIME" -a -z "$MINUTES" ]; then
		START_TIME=`expand_timestamp $START_TIME`
		[ -n "$START_TIME" ] || return 1
		START_TIME="${START_TIME/_/ }"
	fi
}

function _mount_end_time_option()
{
	if [ -n "$END_TIME" ]; then
		echo --stop-datetime=\"$END_TIME\"
	fi
}
