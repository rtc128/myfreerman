R = $(shell cat RELEASE)

.PHONY: rpm
rpm:
	mkdir -p ~/rpmbuild/BUILDROOT
	mkdir -p ~/rpmbuild/SOURCES
	mkdir -p ~/rpmbuild/SPECS
	gzip -c9 src/man/myfreerman.1 >myfreerman.1.gz
	gzip -c9 src/man/myfreerman.conf.8 >myfreerman.conf.8.gz
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
	rm -fr /tmp/myfreerman-$(R)

.PHONY: install
install:
	cp src/myfreerman /usr/bin
	gzip -c src/man/myfreerman.1 >/usr/share/man/man1/myfreerman.1.gz
	gzip -c src/man/myfreerman.conf.8 >/usr/share/man/man8/myfreerman.conf.8.gz
	mkdir -p /usr/lib/myfreerman/modules
	cp src/modules/* /usr/lib/myfreerman/modules
