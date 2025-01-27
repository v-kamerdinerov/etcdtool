NAME=etcdtool
BUILDDIR=build
SRCDIR=github.com/v-kamerdinerov/$(NAME)
VERSION:=$(shell git describe --abbrev=0 --tags)
RELEASE:=$(shell date -u +%Y%m%d%H%M)
ARCH:=$(shell uname -p)

all: build

clean:
	rm -rf ${BUILDDIR} release

build build-binary: clean
	mkdir ${BUILDDIR} || true
	go clean -modcache
	go get -d ./...
	go get -u ./...
	go build -o ${BUILDDIR}/${NAME}

darwin: build
	mkdir release || true
	mv ${BUILDDIR}/${NAME} release/${NAME}-${VERSION}-${RELEASE}.darwin.x86_64

rpm: build-docker-image
	docker run --rm --network=host -it -v "$$PWD":/go/src/$(SRCDIR) -w /go/src/$(SRCDIR) centos-golang make build-rpm

binary: build-docker-image
	docker run --rm --network=host -it -v "$$PWD":/go/src/$(SRCDIR) -w /go/src/$(SRCDIR) centos-golang make build-binary
	mkdir release || true
	mv ${BUILDDIR}/${NAME} release/${NAME}-${VERSION}-${RELEASE}.linux.${ARCH}

set-version:
	sed -i .tmp "s/const Version =.*/const Version = \"${VERSION}\"/" version.go
	rm -f version.go.tmp

release: clean set-version darwin rpm binary

build-rpm: build
	mkdir -p ${BUILDDIR}/{BUILD,BUILDROOT,RPMS,SOURCES,SPECS,SRPMS}
	cp ${BUILDDIR}/${NAME} ${BUILDDIR}/SOURCES
	sed -e "s/%NAME%/${NAME}/g" -e "s/%VERSION%/${VERSION}/g" -e "s/%RELEASE%/${RELEASE}/g" \
		${NAME}.spec >${BUILDDIR}/SPECS/${NAME}.spec
	rpmbuild -vv -bb --target="${ARCH}" --clean --define "_topdir $$(pwd)/${BUILDDIR}" ${BUILDDIR}/SPECS/${NAME}.spec
	mkdir release || true
	mv ${BUILDDIR}/RPMS/${ARCH}/*.rpm release

build-docker-image:
	docker build --network=host -t centos-golang -f docker_builder/Dockerfile .
