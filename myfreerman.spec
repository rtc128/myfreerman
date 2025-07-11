Name:           myfreerman
Version:			 2.5.26
Release:        1
Summary:        Wrapper for MySQL Enterprise Backup that adds binlog compression and PITR

BuildArch:      noarch
License:			 GPL
Source0:			 myfreerman.tar.gz
Requires:		 crudini >= 0.3, bc, rclone, expect

%description
MyFreeRMan uses MEB to create/restore backups of MySQL databases.
It adds support for:
- Server repostiry initialization
- Compression of binlog backups
- Restore only a schema / only a list of tables
- Automated recovery (also PITR)
- Binlog retention in master-slave cluster
- Table flashback

%prep
%setup -q
%build
%install
install -m 0755 -d $RPM_BUILD_ROOT/var/lib/myfreerman
install -m 0755 -d $RPM_BUILD_ROOT/var/log/myfreerman
install -m 0755 -d $RPM_BUILD_ROOT/usr/bin
install -m 0755 -d $RPM_BUILD_ROOT/usr/share/man/man1
install -m 0755 -d $RPM_BUILD_ROOT/usr/share/man/man8
install -m 0755 -d $RPM_BUILD_ROOT/usr/share/myfreerman
install -m 0755 -d $RPM_BUILD_ROOT/usr/lib/myfreerman/modules
install -m 0755 src/myfreerman $RPM_BUILD_ROOT/usr/bin/myfreerman
install -m 0644 myfreerman.1.gz $RPM_BUILD_ROOT/usr/share/man/man1
install -m 0644 myfreerman.conf.8.gz $RPM_BUILD_ROOT/usr/share/man/man8
install -m 0755 src/modules/binlog.sh $RPM_BUILD_ROOT/usr/lib/myfreerman/modules
install -m 0755 src/modules/catalog.sh $RPM_BUILD_ROOT/usr/lib/myfreerman/modules
install -m 0755 src/modules/flashback.sh $RPM_BUILD_ROOT/usr/lib/myfreerman/modules
install -m 0755 src/modules/fs.sh $RPM_BUILD_ROOT/usr/lib/myfreerman/modules
install -m 0755 src/modules/lock.sh $RPM_BUILD_ROOT/usr/lib/myfreerman/modules
install -m 0755 src/modules/replica.sh $RPM_BUILD_ROOT/usr/lib/myfreerman/modules
install -m 0755 src/modules/sessions.sh $RPM_BUILD_ROOT/usr/lib/myfreerman/modules

%files
/usr/bin/myfreerman
/usr/share/man/man1/myfreerman.1.gz
/usr/share/man/man8/myfreerman.conf.8.gz
/usr/lib/myfreerman/
/usr/share/myfreerman/
/var/lib/myfreerman/
/var/log/myfreerman/

%changelog

* Thu Jul 10 2025 Rodrigo Tassinari 2.5.26
- Fixed version mismatch in package

* Thu Jun 26 2025 Rodrigo Tassinari 2.5.25
- Fix in LIST (EVENTS, TRANSACTIONS) command line parsing

* Thu Jun 26 2025 Rodrigo Tassinari 2.5.24
- FLASHBACK TABLE: for a replica, just generate flashback script

* Wed May 7 2025 Rodrigo Tassinari 2.5.23
- Fix in DROP DATABASE where there are many binlog files
- Better logs in INIT DATABASE

* Tue Apr 22 2025 Rodrigo Tassinari 2.5.22
- Removed depends on Mysql Enterprise packages

* Wed Jan 8 2025 Rodrigo Tassinari 2.5.21
- When building a replica, configure server to read next binlog - trying to fix inconsistencies

* Thu Jul 4 2024 Rodrigo Tassinari 2.5.20
- Support listing transactions in current relay log

* Wed Apr 3 2024 Rodrigo Tassinari 2.5.19
- When initializing a replica, create directory for slow log

* Wed Apr 3 2024 Rodrigo Tassinari 2.5.18
- When initializing a replica, create directory for innodb temporary tablespaces

* Tue Mar 12 2024 Rodrigo Tassinari 2.5.17
- New option to disable redo log apply in full backup

* Fri Mar 8 2024 Rodrigo Tassinari 2.5.16
- PROMOTE: fix in task that kills all sessions in master

* Fri Mar 8 2024 Rodrigo Tassinari 2.5.15
- Fixes in PROMOTE command.
- PROMOTE: allow setting password in env var
- INIT REPLICA: allow setting password in env var

* Tue Mar 5 2024 Rodrigo Tassinari 2.5.14
- Fix in PROMOTE command

* Fri Dec 15 2023 Rodrigo Tassinari 2.5.13
- New option in transaction listing: show summary only

* Tue Nov 21 2023 Rodrigo Tassinari 2.5.12
- Minor fix in replica creation

* Thu Oct 26 2023 Rodrigo Tassinari 2.5.11
- Use Expect to create new database instance

* Tue Sep 26 2023 Rodrigo Tassinari 2.5.10
- New option to keep binary logs

* Fri Sep 22 2023 Rodrigo Tassinari 2.5.9
- Critical fix in binlog purging

* Fri Sep 22 2023 Rodrigo Tassinari 2.5.8
- New command: METADATA

* Thu Sep 21 2023 Rodrigo Tassinari 2.5.7
- "SLAVE" titles/features changed to "REPLICA"
- Added option to ignore recovery (apply binlogs) in restoration
- RCLONE enabled is now default option for restoration

* Mon Aug 7 2023 Rodrigo Tassinari 2.5.6
- When promoting master, change also EVENT_SCHEDULER config

* Fri Aug 4 2023 Rodrigo Tassinari 2.5.5
- Better PROMOTE steps

* Wed Aug 2 2023 Rodrigo Tassinari 2.5.4
- Minor fix in PROMOTE again

* Wed Aug 2 2023 Rodrigo Tassinari 2.5.3
- Minor fix in PROMOTE

* Mon Jul 31 2023 Rodrigo Tassinari 2.5.2
- Fix in PROMOTE: check if binlogs are enabled

* Mon Jul 31 2023 Rodrigo Tassinari 2.5.1
- Fix in package

* Mon Jul 31 2023 Rodrigo Tassinari 2.5.0
- New command: PROMOTE

* Fri Jul 21 2023 Rodrigo Tassinari 2.4.8
- New configs: BACKUP_PROCESS_THREADS, BACKUP_LIMIT_MEMORY

* Fri Jul 14 2023 Rodrigo Tassinari 2.4.7
- Use PROCESS_THREADS config in backup log apply phase

* Wed Jun 28 2023 Rodrigo Tassinari 2.4.6
- Added missing module

* Wed Jun 28 2023 Rodrigo Tassinari 2.4.5
- Fix in critical error in RESTORE and INIT SLAVE

* Mon Jun 19 2023 Rodrigo Tassinari 2.4.4
- Fix in backup listing after removing catalog

* Mon Jun 19 2023 Rodrigo Tassinari 2.4.3
- Removed catalog in database

* Wed May 10 2023 Rodrigo Tassinari 2.4.2
- Remove expired temporary directories

* Tue May 9 2023 Rodrigo Tassinari 2.4.1
- Fix no module packaging
- Better man page

* Tue May 9 2023 Rodrigo Tassinari 2.4.0
- Register backups in target database

* Thu Apr 13 2023 Rodrigo Tassinari 2.3.3
- DROP DATABASE: fix - leave untouched internal EXT40-FS data

* Thu Feb 9 2023 Rodrigo Tassinari 2.3.2
- INIT DATABASE: removed warning in authentication
- RESTORE CONFIG: do not print end report
- RESTORE with -o: do not require BACKUP_DIR config

* Fri Feb 3 2023 Rodrigo Tassinari 2.3.1
- Support for REDO LOG new format when restoring using RCLONE

* Wed Feb 1 2023 Rodrigo Tassinari 2.3.0
- Added support for restoration using RCLONE

* Fri Nov 11 2022 Rodrigo Tassinari 2.2.13
- For restoration, 'innodb force recovery' must be disabled

* Tue Nov 8 2022 Rodrigo Tassinari 2.2.12
- When dropping a database, clear temp area

* Mon Oct 31 2022 Rodrigo Tassinari 2.2.11
- Fixed error in RPM packages

* Mon Oct 31 2022 Rodrigo Tassinari 2.2.10
- New algorithm in LIST TRANSACTIONS - for better performance

* Wed Oct 26 2022 Rodrigo Tassinari 2.2.9
- Minor fix in debugging system

* Fri Oct 21 2022 Rodrigo Tassinari 2.2.8
- LIST TRANSACTIONS: new option to set defautl schema in list

* Wed Oct 19 2022 Rodrigo Tassinari 2.2.7
- Fix in LIST TRANSACTIONS: it was not listing all binlogs

* Wed Oct 19 2022 Rodrigo Tassinari 2.2.6
- Fix in LIST TRANSACTIONS (timestamp)

* Tue Oct 18 2022 Rodrigo Tassinari 2.2.5
- Create a default working dir

* Fri Oct 14 2022 Rodrigo Tassinari 2.2.4
- Fix in RPM package

* Thu Oct 13 2022 Rodrigo Tassinari 2.2.3
- LIST TRANSACTIONS: a few fixes

* Thu Oct 6 2022 Rodrigo Tassinari 2.2.2
- Minor fix in LIST TRANSACTIONS

* Wed Oct 5 2022 Rodrigo Tassinari 2.2.1
- Transaction listing: show details per table

* Tue Oct 4 2022 Rodrigo Tassinari 2.2.0
- New option to list transactions executed

* Thu Sep 1 2022 Rodrigo Tassinari 2.1.11
- Allow multi-thread flashback again

* Fri Aug 19 2022 Rodrigo Tassinari 2.1.9
- Minor fix in flashback

* Thu Aug 18 2022 Rodrigo Tassinari 2.1.8
- Fix in module loader

* Thu Aug 18 2022 Rodrigo Tassinari 2.1.7
- Removed multi-thread support in FLASHBACK TABLE, because it was causing a bug

* Wed Aug 17 2022 Rodrigo Tassinari 2.1.6
- Fix in table locking, in FLASHBACK

* Fri Jun 10 2022 Rodrigo Tassinari 2.1.3
- Added support for INSERT commands in flashback

* Fri Apr 22 2022 Rodrigo Tassinari 2.1.2
- Added support for flashbacks in tables with BLOB columns

* Tue Apr 19 2022 Rodrigo Tassinari 2.1.1
- Added support for DELETE in flashback

* Mon Dec 13 2021 Rodrigo Tassinari 1.8.9
- In binlog backup, remove orphan tmp files
- In binlog backup, crosscheck sequences and remove sequences that are from the future
 
* Mon Nov 22 2021 Rodrigo Tassinari 1.8.8
- In RECOVER SLAVE, reset slave before applying binlogs

* Mon Nov 22 2021 Rodrigo Tassinari 1.8.7
- In full backup, don't copy binlogs

* Wed Nov 17 2021 Rodrigo Tassinari 1.8.6
- New config parameter: disable_buffer_pool_dump
- Minor fix in config validation

* Thu Nov 4 2021 Rodrigo Tassinari 1.8.5
- Fix in recovery: if there is a new full backup when binlog applying is started, wrong binlog reference was being picked
- Minor fix in event listing

* Wed Oct 27 2021 Rodrigo Tassinari 1.8.4
- Better accuracy in binlog event size calculation

* Tue Oct 26 2021 Rodrigo Tassinari 1.8.3
- When applying binlogs, also print client reported errors in log
- For recovery, start server with event scheduler disabled

* Wed Oct 20 2021 Rodrigo Tassinari 1.8.2
- In INIT SLAVE, apply all binlogs available at the end of restoration, and not only until the beginning of restoration

* Mon Oct 04 2021 Rodrigo Tassinari 1.8.1
- Binlog event listing: new filter options; use less disk space

* Thu Sep 30 2021 Rodrigo Tassinari 1.8.0
- New command: RECOVER SLAVE

* Thu Sep 30 2021 Rodrigo Tassinari 1.7.6
- Minor fixes in LIST EVENTS command

* Wed Sep 29 2021 Rodrigo Tassinari 1.7.5
- New report format in binlog event listing

* Wed Sep 29 2021 Rodrigo Tassinari 1.7.4
- Allow multiple threads when listing DML events in binlogs

* Wed Sep 29 2021 Rodrigo Tassinari 1.7.3
- Critical fix in full backup

* Wed Sep 29 2021 Rodrigo Tassinari 1.7.2
- Fix in backup full: use default value (6) for process-threads

* Tue Sep 28 2021 Rodrigo Tassinari 1.7.1
- Faster binlog events listing

* Tue Sep 28 2021 Rodrigo Tassinari 1.7.0
- New command: LIST EVENTS

* Fri Sep 24 2021 Rodrigo Tassinari 1.6.3
- Creating aux instance for PITR of single object: when not able to start aux instance, leave the instance untouched and let the user diagnose.

* Thu Sep 23 2021 Rodrigo Tassinari 1.6.2
- READ/WRITE threads configs are now segmented (backup_read_threads; backup_write_threads; restore_read_threads; restore_write_threads)

* Mon Sep 6 2021 Rodrigo Tassinari 1.6.1
- Bug fix in binary log backup: if some log (general, slow) FS is full, it was failing

* Mon Aug 30 2021 Rodrigo Tassinari 1.6.0
- New command: APPLY BINLOG

* Thu Aug 19 2021 Rodrigo Tassinari 1.5.15
- Fixed bug in slave init

* Thu Aug 19 2021 Rodrigo Tassinari 1.5.14
- Fixed bug in restore when audit plugin is installed

* Wed Aug 18 2021 Rodrigo Tassinari 1.5.13
- When creating a slave, apply binlogs - so, any old master backup can be used
- Fixed bug in 'init database'

* Fri Jul 09 2021 Rodrigo Tassinari 1.5.12
- Allow restoring config with specific timestamp

* Wed Jun 16 2021 Rodrigo Tassinari 1.5.10
- Added support for server config restore

* Wed Jun 16 2021 Rodrigo Tassinari 1.5.9
- Bug fix in tmp data handler
- Fix in binlog backup: slave servers were retaining binary logs

* Thu Jun 10 2021 Rodrigo Tassinari 1.5.8
- Fix in restore on a server with relay logs
- New syntax for DROP DATABASE command

* Wed Jun 9 2021 Rodrigo Tassinari 1.5.7
- Fix in restore using aux instance

* Tue Jun 8 2021 Rodrigo Tassinari 1.5.6
- Fix in restore using aux instance, when there is relay log enabled

* Fri Jun 4 2021 Rodrigo Tassinari 1.5.5
- Easier command syntax for specific schema restoration

* Tue Jun 1 2021 Rodrigo Tassinari 1.5.4
- Bug fix in slave init command
- New slave init syntax

* Tue Jun 1 2021 Rodrigo Tassinari 1.5.3
- Bug fix in REMOVE command

* Tue Jun 1 2021 Rodrigo Tassinari 1.5.2
- Fixed bugs in LIST

* Fri May 28 2021 Rodrigo Tassinari 1.5.1
- Option to backup full database in another directory
- Simpler ways to inform desired timestamp in PITR

* Tue May 25 2021 Rodrigo Tassinari 1.5.0
- Expired backups now are not removed after a full backup. There's a new command, specific for this task.
- Slave init has an easier command line

* Tue May 25 2021 Rodrigo Tassinari 1.4.39
- Major fix in config file access

* Tue May 25 2021 Rodrigo Tassinari 1.4.38
- New option in PITR: restore a table with a new table name

* Thu May 20 2021 Rodrigo Tassinari 1.4.37
- Minor fix in docs
- Fix in broken 'init-slave' command

* Wed May 19 2021 Rodrigo Tassinari 1.4.36
- Option -y is now global, and not inside each command

* Fri May 14 2021 Rodrigo Tassinari 1.4.35
- Bug fix in temporary full backup

* Thu May 13 2021 Rodrigo Tassinari 1.4.34
- In full backup, create the final destination directory only when the backup is done. So, LIST command will not consider unfinished backups.
- Lock only binlog backups. So, binlog backups can be done in parallel with full backups.

* Mon May 10 2021 Rodrigo Tassinari 1.4.33
- Remove dst directory when MEB fails in full backup

* Mon Apr 19 2021 Rodrigo Tassinari 1.4.32
- New command: drop-db

* Thu Nov 26 2020 Rodrigo Tassinari 1.4.31
- Bug fix in restore

* Tue Nov 24 2020 Rodrigo Tassinari 1.4.30
- Bug fix in slave init

* Wed Nov 04 2020 Rodrigo Tassinari 1.4.29
- Support for multiple slave servers - separated by a comma

* Thu Oct 29 2020 Rodrigo Tassinari 1.4.28
- New config variable: process_threads (number of processing threads for backup)

* Mon Oct 26 2020 Rodrigo Tassinari 1.4.27
- Bug fix in slave server identification

* Tue Oct 20 2020 Rodrigo Tassinari 1.4.26
- Increased timeout when starting instance

* Wed Aug 19 2020 Rodrigo Tassinari 1.4.25
- When using PITR, backup binlogs before starting retore.
- Fix in restore using aux instance (check GTID mode).

* Fri Aug 14 2020 Rodrigo Tassinari 1.4.24
- If the instance is a slave, purge all binlogs, even if configuration parameter SLAVE_SERVER is set
- Minor fixes in building slave servers

* Thu Aug 6 2020 Rodrigo Tassinari 1.4.23
Fix in init-db: create socket and pidfile directories if they don't exist

* Tue Jun 16 2020 Rodrigo Tassinari 1.4.22
- Command 'init' changed to 'init-db'
- New command: 'init-slave'

* Wed Jun 10 2020 Rodrigo Tassinari 1.4.21
- Restore option -f changed to -o (origin)

* Wed Jun 10 2020 Rodrigo Tassinari 1.4.20
- Fix in restore: binlogs were being applied forever

* Wed Jun 10 2020 Rodrigo Tassinari 1.4.19
- When restoring specific schemas/tables, also apply binlogs that are not still backed up

* Tue Jun 9 2020 Rodrigo Tassinari 1.4.18
- Restore: allow to overwrite backup directory in command line

* Tue May 12 2020 Rodrigo Tassinari 1.4.17
- Do not require configuration if not needed
- In remote listing, use default config file, and not /etc/myfreerman/%

* Tue May 5 2020 Rodrigo Tassinari 1.4.16
- Fix in binlog backup: report when slave server is running but we can't get slave status

* Tue Apr 14 2020 Rodrigo Tassinari 1.4.15
- Better feedbacks
- Better error handling when contacting slave to get last binlog sequence

* Thu Apr 9 2020 Rodrigo Tassinari 1.4.14
- Fix in LIST report

* Thu Apr 9 2020 Rodrigo Tassinari 1.4.13
- Better feedbacks

* Thu Apr 2 2020 Rodrigo Tassinari 1.4.12
- Major fix in restore

* Tue Mar 31 2020 Rodrigo Tassinari 1.4.11
- Fix in starting mysql instances

* Tue Mar 31 2020 Rodrigo Tassinari 1.4.10
- In restore, do not write log in backup folder - so backup FS can be mounted RO

* Thu Mar 26 2020 Rodrigo Tassinari 1.4.9
- New fixes in restore validation

* Thu Mar 26 2020 Rodrigo Tassinari 1.4.8
- Fix in restore validation

* Thu Mar 26 2020 Rodrigo Tassinari 1.4.7
- Minor fix in read_only variable reading

* Thu Mar 26 2020 Rodrigo Tassinari 1.4.6
- Minor fixes

* Fri Mar 20 2020 Rodrigo Tassinari 1.4.5
- Support for recovery when credentials saved in client are not compatible with restored database

* Thu Mar 19 2020 Rodrigo Tassinari 1.4.4
- Major fix in backup

* Wed Mar 18 2020 Rodrigo Tassinari 1.4.3
- Support for custom log file name
- New configuration variable: db_socket

* Mon Mar 16 2020 Rodrigo Tassinari 1.4.2
- Config is now read from Mysql's config file

* Fri Mar 13 2020 Rodrigo Tassinari 1.4.1
- Command 'init' now sets initial root password

* Wed Mar 11 2020 Rodrigo Tassinari 1.4.0
- Support for definition of a slave server: in binary log backup, only logs already applied to the slave are purged
- Support for multiple instances in the same server configuration file (systemd format using '@')

* Thu Mar 5 2020 Rodrigo Tassinari 1.3.24
- Support for relay log configuration
- Minor fixes

* Wed Mar 4 2020 Rodrigo Tassinari 1.3.23
- Possibility to disable binlog purging

* Mon Mar 2 2020 Rodrigo Tassinari 1.3.22
- Fix in PITR
- When restoring in slave mode, print out binlog position

* Fri Feb 21 2020 Rodrigo Tassinari 1.3.21
- Minor fixes

* Fri Feb 21 2020 Rodrigo Tassinari 1.3.20
- Minor fixes in timeouts
- New config to limit MEB memory use
- In full backup, copy server and myfreerman configs
- New option in restore: -s (slave mode): do not apply binlogs - all changes since full backup will be copied back from master
- New command supported: 'init'
- New option in full backup: do not backup binlogs at the same time

* Tue Jan 07 2020 Rodrigo Tassinari 1.3.19
- Adjust new log sequence in restore

* Thu Nov 14 2019 Rodrigo Tassinari 1.3.18
- Log file names fixed 

* Wed Nov 13 2019 Rodrigo Tassinari 1.3.17
- Change <binlog_dir> owner in restore

* Wed Nov 13 2019 Rodrigo Tassinari 1.3.16
- Change binlog.index owner in restore

* Wed Nov 13 2019 Rodrigo Tassinari 1.3.14
- Do not check backup consistency for now - some odd behaviors in NFS comms

* Wed Nov 13 2019 Rodrigo Tassinari 1.3.13
- Fix in remote backup listing

* Thu Nov 07 2019 Rodrigo Tassinari 1.3.12
   - Fix in changelog tabs

* Thu Nov 07 2019 Rodrigo Tassinari 1.3.11
- Fix in restore when DB has audit set up
- Backup listing can be done remotely
- Log file names now contain hostname (cluster environment logs can now be written on shared folder)

* Fri Nov 01 2019 Rodrigo Tassinari 1.3.10
- Minor fix in multi-instances envs

* Thu Oct 31 2019 Rodrigo Tassinari 1.3.9
- New config variable: READ_ONLY
- Fix in broken full backup when mysql config wasn't the default one

* Thu Oct 31 2019 Rodrigo Tassinari 1.3.8
- Fix in broken non-PITR!

* Mon Oct 28 2019 Rodrigo Tassinari 1.3.7
- Fix in MEB log saving
- Back doing binlog backup just after full backup

* Fri Oct 25 2019 Rodrigo Tassinari 1.3.6
- Minor fix in background backup

* Fri Oct 25 2019 Rodrigo Tassinari 1.3.5
- Allow database hostname config
- Better doc about PITR and backup incarnations

* Thu Oct 24 2019 Rodrigo Tassinari 1.3.4
- Restore: do not create new backup incarnation if it's not PITR
- Restore: fix in PITR: request timestamp is now respected

* Thu Oct 24 2019 Rodrigo Tassinari 1.3.3
- Minor fix in backup lists

* Wed Oct 23 2019 Rodrigo Tassinari 1.3.2
- Separate logs: a file per instance created
- Improved docs about restoration and backup incarnations.

* Tue Oct 22 2019 Rodrigo Tassinari 1.3.1
- Minor fixes in recover
- Fixed permissions in new database structure for restore

* Mon Oct 21 2019 Rodrigo Tassinari 1.3.0
- Safer restores
- After restoring, stop mysql server

* Mon Oct 07 2019 Rodrigo Tassinari 1.2.14
- Do not restore if target directory is not empty
- When changing ownership in restored area, do not set owner group, only user
- Minor fixes in reports

* Thu Oct 03 2019 Rodrigo Tassinari 1.2.13
- Save mysqlbackup logs syncly in myfreerman log, and do not use a buffer anymore

* Wed Sep 25 2019 Rodrigo Tassinari 1.2.12
- Do not abort when there is a gap in binlog sequence
- Other minor fixes

* Thu Sep 12 2019 Rodrigo Tassinari 1.2.11
- In binlog backups, only flush logs when we reach the last one

* Thu Sep 12 2019 Rodrigo Tassinari 1.2.10
- Do not check consistency only for listing

* Thu Sep 12 2019 Rodrigo Tassinari 1.2.9
- Fix in backup consistency check mutex

* Tue Sep 10 2019 Rodrigo Tassinari 1.2.8
- Automatically clear backups that started but did not finish

* Mon Sep 02 2019 Rodrigo Tassinari 1.2.6
- Purge each binlog just after backing it up, and not the whole list together at the end of the process

* Thu Aug 22 2019 Rodrigo Tassinari 1.2.5
- Required that backup directory alread exists.
- Required that aux database directory alread exists, when needed for restore.

* Wed Aug 14 2019 Rodrigo Tassinari 1.2.4
- Minor fixes in manpages
