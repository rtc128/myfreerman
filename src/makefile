R = $(shell cat RELEASE)

rpm:
	rpmdev-setuptree
	gzip -c9 man/myfreerman.1 >myfreerman.1.gz
	gzip -c9 man/myfreerman.conf.8 >myfreerman.conf.8.gz
	rm -fr /tmp/myfreerman-$(R)
	cp -a . /tmp/myfreerman-$(R)
	tar -C /tmp -c -z -f /tmp/myfreerman.tar.gz myfreerman-$(R)
	mv /tmp/myfreerman.tar.gz ~/rpmbuild/SOURCES
	cp myfreerman.spec ~/rpmbuild/SPECS
	rpmbuild --define "_target_os linux" -bb ~/rpmbuild/SPECS/myfreerman.spec
	mkdir -p ~/rpm
	rm -fr ~/rpm/*
	mv ~/rpmbuild/RPMS/noarch/*.rpm ~/rpm
	rm myfreerman.1.gz myfreerman.conf.8.gz
	rpmdev-wipetree
	rm -fr /tmp/myfreerman-$(R)
