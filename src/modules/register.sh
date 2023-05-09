#!/bin/bash

function register_register_backup_binlog()
{
	SEQ=$1
	TARGET_CRED_OPT=`mount_target_credentials_opt` || return 1

	#if password in config, set env
	if [ -n "$DB_PASSWORD" ]; then
		export MYSQL_PWD="$DB_PASSWORD"
	fi
	SERVER_ID=`crudini --get $SERVER_CONFIG $SERVER_INI_SECTION server_id` 2>/dev/null
	#default server id is 1
	if [ -z "$SERVER_ID" ]; then
		SERVER_ID=1
	fi
	COMMAND="insert into rman.backup values (null, $SERVER_ID, now(), 'L', $SEQ)"
	#if this is a master, just insert it
	#if not, find master and insert into master
	MASTER_HOST=`mysql --socket=$SERVER_SOCKET $TARGET_CRED_OPT -e "show slave status\G" | grep Master_Host | awk '{ print $2; }'`
	if [ -z "$MASTER_HOST" ]; then
		mysql --socket=$SERVER_SOCKET $MASTER_HOST $TARGET_CRED_OPT -e "$COMMAND" || return 1
	else
		mysql --defaults-file=$SERVER_CONFIG -h $MASTER_HOST $TARGET_CRED_OPT -e "$COMMAND" || return 1
	fi
}

function register_register_backup_full()
{
	ID=$1
	TIMESTAMP=${ID/_/ }
	TARGET_CRED_OPT=`mount_target_credentials_opt` || return 1

	#if password in config, set env
	if [ -n "$DB_PASSWORD" ]; then
		export MYSQL_PWD="$DB_PASSWORD"
	fi
	SERVER_ID=`crudini --get $SERVER_CONFIG $SERVER_INI_SECTION server_id` 2>/dev/null
	#default server id is 1
	if [ -z "$SERVER_ID" ]; then
		SERVER_ID=1
	fi
	COMMAND="insert into rman.backup values (null, $SERVER_ID, '$TIMESTAMP', 'F', null)"
	#if this is a master, just insert it
	#if not, find master and insert into master
	MASTER_HOST=`mysql --socket=$SERVER_SOCKET $TARGET_CRED_OPT -e "show slave status\G" | grep Master_Host | awk '{ print $2; }'`
	if [ -z "$MASTER_HOST" ]; then
		mysql --socket=$SERVER_SOCKET $MASTER_HOST $TARGET_CRED_OPT -e "$COMMAND" || return 1
	else
		mysql --defaults-file=$SERVER_CONFIG -h $MASTER_HOST $TARGET_CRED_OPT -e "$COMMAND" || return 1
	fi
}

function register_unregister_backup_binlog()
{
	SEQ=$1
	TARGET_CRED_OPT=`mount_target_credentials_opt` || return 1

	#if password in config, set env
	if [ -n "$DB_PASSWORD" ]; then
		export MYSQL_PWD="$DB_PASSWORD"
	fi
	SERVER_ID=`crudini --get $SERVER_CONFIG $SERVER_INI_SECTION server_id` 2>/dev/null
	#default server id is 1
	if [ -z "$SERVER_ID" ]; then
		SERVER_ID=1
	fi
	COMMAND="delete from rman.backup where backup_type = 'L' and sequence = $SEQ"
	#if this is a master, just insert it
	#if not, find master and insert into master
	MASTER_HOST=`mysql --socket=$SERVER_SOCKET $TARGET_CRED_OPT -e "show slave status\G" | grep Master_Host | awk '{ print $2; }'`
	if [ -z "$MASTER_HOST" ]; then
		mysql --socket=$SERVER_SOCKET $MASTER_HOST $TARGET_CRED_OPT -e "$COMMAND" || return 1
	else
		mysql --defaults-file=$SERVER_CONFIG -h $MASTER_HOST $TARGET_CRED_OPT -e "$COMMAND" || return 1
	fi
}

function register_unregister_backup_full()
{
	ID=$1
	TIMESTAMP=${ID/_/ }
	TARGET_CRED_OPT=`mount_target_credentials_opt` || return 1

	#if password in config, set env
	if [ -n "$DB_PASSWORD" ]; then
		export MYSQL_PWD="$DB_PASSWORD"
	fi
	SERVER_ID=`crudini --get $SERVER_CONFIG $SERVER_INI_SECTION server_id` 2>/dev/null
	#default server id is 1
	if [ -z "$SERVER_ID" ]; then
		SERVER_ID=1
	fi
	COMMAND="delete from rman.backup where backup_type = 'F' and timestamp = '$TIMESTAMP'"
	#if this is a master, just insert it
	#if not, find master and insert into master
	MASTER_HOST=`mysql --socket=$SERVER_SOCKET $TARGET_CRED_OPT -e "show slave status\G" | grep Master_Host | awk '{ print $2; }'`
	if [ -z "$MASTER_HOST" ]; then
		mysql --socket=$SERVER_SOCKET $MASTER_HOST $TARGET_CRED_OPT -e "$COMMAND" || return 1
	else
		mysql --defaults-file=$SERVER_CONFIG -h $MASTER_HOST $TARGET_CRED_OPT -e "$COMMAND" || return 1
	fi
}
