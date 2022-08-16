function binlog_get_current_master_binlog()
{
	BUFF=`mktemp /tmp/myfreerman.XXXXXX`
	ERR=`mktemp /tmp/myfreerman.XXXXXX`
	mysql --socket="$SERVER_SOCKET" $TARGET_CRED_OPT -e 'show master status\G' | grep -vwi warning >$BUFF 2>$ERR
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
