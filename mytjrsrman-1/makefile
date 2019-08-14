rpm:
	rpmdev-setuptree
	gzip -c9 man/mytjrsrman.1 >mytjrsrman.1.gz
	gzip -c9 man/mytjrsrman.conf.8 >mytjrsrman.conf.8.gz
	tar -C .. -c -z -f ../mytjrsrman-1.tar.gz mytjrsrman-1
	mv ../mytjrsrman-1.tar.gz ~/rpmbuild/SOURCES
	cp mytjrsrman.spec ~/rpmbuild/SPECS
	rpmbuild -ba ~/rpmbuild/SPECS/mytjrsrman.spec
	mkdir -p ~/rpm
	rm -fr ~/rpm/*
	mv ~/rpmbuild/RPMS/noarch/*.rpm ~/rpm
	rm mytjrsrman.1.gz mytjrsrman.conf.8.gz
	rpmdev-wipetree
