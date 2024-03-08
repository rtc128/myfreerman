function sessions_kill_all_master()
{
	QUERY="select id from information_schema.processlist where id <> connection_id() and command in ('sleep', 'query')"
	LIST=`mysql -h $MASTER_HOST -P $MASTER_PORT -e "$QUERY"` || return 1
	BUFF=`mktemp /tmp/myfreerman.XXXXXX`
	for ID in $LIST; do
		echo "kill connection $ID" >>$BUFF
	done
	mysql -f <$BUFF >/dev/null 2>&1
	rm $BUFF
}
