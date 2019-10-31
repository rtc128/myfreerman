Name:           mytjrsrman
Version:        1
Release:        1.3.8
Summary:        Wrapper for MySQL Enterprise Backup that adds binlog compression and PITR

BuildArch:      noarch
License:        GPL
Source0:        mytjrsrman-1.tar.gz
Requires:		crudini >= 0.3

%description
Mytjrsrman uses MEB to create/restore backups of MySQL databases.
It adds support for:
- Compression of binlog backups
- Restore only a schema / only a list of tables
- Automated PITR

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
* Thu Oct 31 2019 Rodrigo Tassinari 1.3.9
	- New config variable: READ_ONLY
	- Fix in broken full backup when mysql config wasn't the default one

* Thu Oct 31 2019 Rodrigo Tassinari 1.3.8
	- Fix in broken non-PITR!

* Mon Oct 28 2019 Rodrigo Tassinari 1.3.7
	- Fix in MEB log saving
	- Back doing binlog backup just after full backup

* Tue Oct 25 2019 Rodrigo Tassinari 1.3.6
	- Minor fix in background backup

* Tue Oct 25 2019 Rodrigo Tassinari 1.3.5
	- Allow database hostname config
	- Better doc about PITR and backup incarnations

* Tue Oct 24 2019 Rodrigo Tassinari 1.3.4
	- Restore: do not create new backup incarnation if it's not PITR
	- Restore: fix in PITR: request timestamp is now respected

* Tue Oct 24 2019 Rodrigo Tassinari 1.3.3
	- Minor fix in backup lists

* Tue Oct 23 2019 Rodrigo Tassinari 1.3.2
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

* Thu Sep 25 2019 Rodrigo Tassinari 1.2.12
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

* Tue Aug 14 2019 Rodrigo Tassinari 1.2.4
  - Minor fixes in manpages
