function table_exists()
{
	SCHEMA=$1
	TABLE=$2
	TARGET_CRED_OPT=`mount_target_credentials_opt` || return 1
	QUERY="select count(1) from information_schema.tables where table_schema = '$SCHEMA' and table_type = 'BASE TABLE' and table_name = '$TABLE'"
	ERR=`mktemp /tmp/myfreerman.XXXXXX`
	COUNT=`mysql -N --socket="$SERVER_SOCKET" $TARGET_CRED_OPT -e "$QUERY" 2>$ERR`
	RC=$?
	write_file_out $ERR
	rm $ERR
	if [ $RC -ne 0 ]; then
		return $RC
	fi
	return $COUNT
}
