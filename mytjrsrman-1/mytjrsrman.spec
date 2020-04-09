Name:           mytjrsrman
Version:        1
Release:        1.4.14
Summary:        Wrapper for MySQL Enterprise Backup that adds binlog compression and PITR

BuildArch:      noarch
License:			GPL
Source0:			mytjrsrman-1.tar.gz
Requires:		crudini >= 0.3

%description
Mytjrsrman uses MEB to create/restore backups of MySQL databases.
It adds support for:
- Server repostiry initialization
- Compression of binlog backups
- Restore only a schema / only a list of tables
- Automated recovery (also PITR)
- Binlog retention in master-slave cluster

%prep
%setup -q
%build
%install
install -m 0755 -d $RPM_BUILD_ROOT/usr/bin
install -m 0755 -d $RPM_BUILD_ROOT/usr/share/man/man1
install -m 0755 -d $RPM_BUILD_ROOT/usr/share/man/man8
install -m 0755 mytjrsrman $RPM_BUILD_ROOT/usr/bin/mytjrsrman
install -m 0644 mytjrsrman.1.gz $RPM_BUILD_ROOT/usr/share/man/man1
install -m 0644 mytjrsrman.conf.8.gz $RPM_BUILD_ROOT/usr/share/man/man8

%files
/usr/bin/mytjrsrman
/usr/share/man/man1/mytjrsrman.1.gz
/usr/share/man/man8/mytjrsrman.conf.8.gz

%changelog

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
- In full backup, copy server and mytjrsrman configs
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
- Save mysqlbackup logs syncly in mytjrsrman log, and do not use a buffer anymore

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
