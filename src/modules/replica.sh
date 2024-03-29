function replica_check_is_replica()
{
	TARGET_CRED_OPT=`mount_target_credentials_opt` || return 1
	BUFF=`mktemp /tmp/myfreerman.XXXXXX`
	mysql --socket="$SERVER_SOCKET" $TARGET_CRED_OPT -e "show replica status\G" >$BUFF || return 1
	COUNT=`cat $BUFF | wc -l`
	rm $BUFF
	if [ $COUNT -lt 2 ]; then
		write_out "Local instance is not a replica"
		return 1
	fi
}

#wait until it's 0 seconds behind master
function replica_wait_for_sync()
{
	local ELAPSED_TIME=0
	local MAX_TIMEOUT=10
	local LAST_GTID=`replica_query_last_transaction`

	DELAY=`replica_query_delay` || return 1
	while [ $DELAY -ne 0 ]; do
		if [ $ELAPSED_TIME -gt $MAX_TIMEOUT ]; then
			write_out "Timeout reached waiting for replica to be fully in sync"
			return 1
		fi
		((ELAPSED_TIME++))
		sleep 1
		DELAY=`replica_query_delay` || return 1
	done
}

function replica_wait_for_transaction()
{
	local ELAPSED_TIME=0
	local MAX_TIMEOUT=10
	local EXPECTED_GTID=$1
	local LAST_GTID=`replica_query_last_transaction`

	sleep 5
	while [ "$LAST_GTID" != "$EXPECTED_GTID" ]; do
		if [ $ELAPSED_TIME -gt $MAX_TIMEOUT ]; then
			return 1
		fi
		((ELAPSED_TIME++))
		sleep 1
		LAST_GTID=`replica_query_last_transaction`
	done
}

function replica_query_delay()
{
	TARGET_CRED_OPT=`mount_target_credentials_opt` || return 1
	BUFF=`mktemp /tmp/myfreerman.XXXXXX`
	mysql --socket="$SERVER_SOCKET" $TARGET_CRED_OPT -e "show replica status\G" >$BUFF || return 1
	grep -i seconds_behind $BUFF | awk '{print $NF}'
	rm $BUFF
}

function replica_query_last_transaction()
{
	TARGET_CRED_OPT=`mount_target_credentials_opt` || return 1
	BUFF=`mktemp /tmp/myfreerman.XXXXXX`
	mysql --socket="$SERVER_SOCKET" $TARGET_CRED_OPT -e "show replica status\G" >$BUFF || return 1
	grep -i executed_gtid_set $BUFF | awk '{print $NF}'
	rm $BUFF
}

function replica_query_master_location()
{
	TARGET_CRED_OPT=`mount_target_credentials_opt` || return 1
	BUFF=`mktemp /tmp/myfreerman.XXXXXX`
	mysql --socket="$SERVER_SOCKET" $TARGET_CRED_OPT -e "show replica status\G" >$BUFF || return 1
	HOST=`grep -i source_host: $BUFF | awk '{print $NF}'`
	USER=`grep -i source_user: $BUFF | awk '{print $NF}'`
	PORT=`grep -i source_port: $BUFF | awk '{print $NF}'`
	rm $BUFF
	echo "$HOST $PORT $USER"
}
