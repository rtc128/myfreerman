BINLOG_LOCKED=0

function lock_binlog_lock()
{
	LOCK_FILE="$WORKING_DIR/binlog.lock"
	MAX_WAIT_TIME_MIN=10
	SLEEP_TIME=15

	MAX_WAIT_TIME_SEC=`expr $MAX_WAIT_TIME_MIN \* 60`
	TOT_WAIT_TIME=0

	if [ -n "$LOCK_FILE" ]; then
		while [ -f "$LOCK_FILE" ]; do
			if [ $TOT_WAIT_TIME -ge $MAX_WAIT_TIME_SEC ]; then
				write_out "Timeout reached waiting for another instance"
				return 1
			fi
			write_out "Waiting for another instance to access binary logs - lock file: $LOCK_FILE"
			sleep $SLEEP_TIME
			TOT_WAIT_TIME=`expr $TOT_WAIT_TIME + $SLEEP_TIME`
		done
		touch "$LOCK_FILE" || return 1
	fi
	BINLOG_LOCKED=1
}

function lock_binlog_unlock()
{
	LOCK_FILE="$WORKING_DIR/binlog.lock"
	[ -f "$LOCK_FILE" -a $BINLOG_LOCKED -eq 1 ] && rm "$LOCK_FILE"
}
