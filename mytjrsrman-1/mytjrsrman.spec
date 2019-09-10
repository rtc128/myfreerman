Name:           mytjrsrman
Version:        1
Release:        1.2.7
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
* Mon Sep 02 2019 Rodrigo Tassinari 1.2.6
	- Purge each binlog just after backing it up, and not the whole list together at the end of the process

* Thu Aug 22 2019 Rodrigo Tassinari 1.2.5
	- Required that backup directory alread exists.
	- Required that aux database directory alread exists, when needed for restore.

* Tue Aug 14 2019 Rodrigo Tassinari 1.2.4
  - Minor fixes in manpages
