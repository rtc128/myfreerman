# myfreerman - MySQL Enterprise Backup wrapper

Version: 2

Summary: Wrapper for MySQL Enterprise Backup that adds binlog compression and PITR


BuildArch: noarch

License: GPL

Source0: mytjrsrman-1.tar.gz

Requires: crudini, rclone


## Description:
Mytjrsrman uses MEB to create/restore backups of MySQL databases.

## It adds support for:
- Server repository initialization
- Compression of binlog backups
- Restore only a schema / only a list of tables
- Automated recovery (also PITR)
- Binlog retention in master-slave cluster
