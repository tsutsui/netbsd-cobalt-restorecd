WGET?=		/usr/pkg/bin/wget
#WGET?=		/usr/local/bin/wget

RSYNC?= 	/usr/pkg/bin/rsync
#RSYNC?= 	/usr/local/bin/rsync

TAR?=		tar
PATCH?=		patch
FTP?=		ftp
SH?=		sh
GZIP?=		gzip

# use appropriate mirrors mentioned in http://www.NetBSD.org/mirrors/
FTP_HOST?=	ftp.NetBSD.org
#FTP_HOST?=	ftp.jp.NetBSD.org
#FTP_HOST?=	ftp5.jp.NetBSD.org
FTP_DIR?=	pub/NetBSD/NetBSD-4.0

RSYNC_HOST?=	rsync.NetBSD.org
RSYNC_DIR?=	NetBSD/NetBSD-4.0
#RSYNC_HOST?=	rsync3.jp.NetBSD.org
#RSYNC_DIR?=	pub/NetBSD/NetBSD-4.0
RSYNC_URL?=	rsync://${RSYNC_HOST}/${RSYNC_DIR}

WGET_URL?=	ftp://${FTP_HOST}/${FTP_DIR}
# adjuct NCUTDIR by FTP_DIR where you'll get files)
WGET_NCUTDIR?=	3

SOURCESETSDIR=	download/source/sets
GNUSRCSETS=	${SOURCESETSDIR}/gnusrc.tgz
SHARESRCSETS=	${SOURCESETSDIR}/sharesrc.tgz
SRCSETS=	${SOURCESETSDIR}/src.tgz
SYSSRCSETS=	${SOURCESETSDIR}/syssrc.tgz
ALLSRCSETS=	${GNUSRCSETS} ${SHARESRCSETS} ${SRCSETS} ${SYSSRCSETS}

all: restorecd

DONE_FETCH=	.done_fetch

${DONE_FETCH}:
	${MAKE} fetch_wget
#	${MAKE} fetch_rsync
	touch ${DONE_FETCH}

fetch_rsync: ${RSYNC}
	${RSYNC} -va --files-from=restorecd-fetch.lst ${RSYNC_URL} download

fetch_wget: ${WGET}
	(cd download ; \
	    ${WGET} --base=${WGET_URL}/ --cut-dirs=${WGET_NCUTDIR} \
	    --no-host-directories --timestamping --force-directories \
	    --input-file=../restorecd-fetch.lst)

DONE_EXTRACT=	.done_extract

${DONE_EXTRACT}: ${DONE_FETCH}
	${MAKE} extract_sets
	touch ${DONE_EXTRACT}

extract_sets: ${ALLSRCSETS}
	${TAR} -zxf ${GNUSRCSETS}
	${TAR} -zxf ${SHARESRCSETS}
	${TAR} -zxf ${SRCSETS}
	${TAR} -zxf ${SYSSRCSETS}

DONE_COBALT_TOOLS=	.done_cobalt_tools

${DONE_COBALT_TOOLS}: ${DONE_EXTRACT}
	${MAKE} build_cobalt_tools
	touch ${DONE_COBALT_TOOLS}

build_cobalt_tools:
	(cd usr/src; \
	    ${SH} build.sh -m cobalt -u -U \
	    -T tooldir.cobalt -D destdir.cobalt \
	    -V OBJMACHINE=1 tools)
	(cd usr/src; \
	   tooldir.cobalt/bin/nbmake-cobalt do-distrib-dirs)
	(cd usr/src/destdir.cobalt; \
	    ${TAR} -zxf ../../../download/cobalt/binary/sets/base.tgz)
	(cd usr/src/destdir.cobalt; \
	    ${TAR} -zxf ../../../download/cobalt/binary/sets/comp.tgz)


DONE_PANELD=	.done_paneld

${DONE_PANELD}: ${DONE_COBALT_TOOLS}
	${MAKE} build_paneld
	touch ${DONE_PANELD}

build_paneld:
	(cd download; ${FTP} \
	    http://only.mawhrin.net/~cdi/netbsd/cobalt/paneld.tar.gz)
	(cd download; \
	    ${FTP} http://www.sigbus.net/paneld_banner_refresh.diff)
	${TAR} -zxf download/paneld.tar.gz
	${PATCH} -d paneltools -p < download/paneld_banner_refresh.diff
	${PATCH} -p < patch/paneld-20071105.diff
	(cd paneltools/paneld && \
	    ../../usr/src/tooldir.cobalt/bin/nbmake-cobalt OBJMACHINE=1 obj && \
	    ../../usr/src/tooldir.cobalt/bin/nbmake-cobalt dependall)
	usr/src/tooldir.cobalt/bin/mipsel--netbsd-install -c -r -m 555 \
	    paneltools/paneld/obj.cobalt/paneld \
	    data/cobalt/install/files/usr/sbin
	usr/src/tooldir.cobalt/bin/mipsel--netbsd-install -c -r -m 444 \
	    paneltools/paneld/paneld.conf.5 \
	    data/cobalt/install/files/usr/share/man/man5
	mkdir -p data/cobalt/install/files/usr/share/man/cat5
	usr/src/tooldir.cobalt/bin/mipsel--netbsd-install -c -r -m 444 \
	    paneltools/paneld/obj.cobalt/paneld.conf.cat5 \
	    data/cobalt/install/files/usr/share/man/cat5/paneld.conf.0
	usr/src/tooldir.cobalt/bin/mipsel--netbsd-install -c -r -m 444 \
	   paneltools/paneld/paneld.8 \
	   data/cobalt/install/files/usr/share/man/man8
	mkdir -p data/cobalt/install/files/usr/share/man/cat8
	usr/src/tooldir.cobalt/bin/mipsel--netbsd-install -c -r -m 444 \
	    paneltools/paneld/obj.cobalt/paneld.cat8 \
	    data/cobalt/install/files/usr/share/man/cat8/paneld.0

DONE_NEWFS_EXT2FS=	.done_newfs_ext2fs

${DONE_NEWFS_EXT2FS}: ${DONE_COBALT_TOOLS}
	${MAKE} build_newfs_ext2fs
	touch ${DONE_NEWFS_EXT2FS}

build_newfs_ext2fs:
	${TAR} -zxf patch/newfs_ext2fs-4.0.tar.gz
	(cd usr/src/sbin/newfs_ext2fs && \
	    ../../../../usr/src/tooldir.cobalt/bin/nbmake-cobalt \
	    OBJMACHINE=1 obj && \
	    ../../../../usr/src/tooldir.cobalt/bin/nbmake-cobalt dependall )
	usr/src/tooldir.cobalt/bin/mipsel--netbsd-install -c -r -m 555 \
	   usr/src/sbin/newfs_ext2fs/obj.cobalt/newfs_ext2fs \
	   data/cobalt/sbin
	usr/src/tooldir.cobalt/bin/mipsel--netbsd-install -c -r -m 555 \
	   usr/src/sbin/newfs_ext2fs/obj.cobalt/newfs_ext2fs \
	   data/cobalt/install/files/sbin
	usr/src/tooldir.cobalt/bin/mipsel--netbsd-install -c -r -m 444 \
	   usr/src/sbin/newfs_ext2fs/newfs_ext2fs.8 \
	   data/cobalt/install/files/usr/share/man/man8
	usr/src/tooldir.cobalt/bin/mipsel--netbsd-install -c -r -m 444 \
	   usr/src/sbin/newfs_ext2fs/obj.cobalt/newfs_ext2fs.cat8 \
	   data/cobalt/install/files/usr/share/man/cat8/newfs_ext2fs.0

DONE_FDISK=	.done_fdisk

${DONE_FDISK}: ${DONE_COBALT_TOOLS}
	${MAKE} build_fdisk
	touch ${DONE_FDISK}

build_fdisk:
	${PATCH} -p < patch/fdisk.c-r1.114.diff
	(cd usr/src/sbin/fdisk && \
	    ../../../../usr/src/tooldir.cobalt/bin/nbmake-cobalt \
	    OBJMACHINE=1 obj && \
	    ../../../../usr/src/tooldir.cobalt/bin/nbmake-cobalt dependall )
	usr/src/tooldir.cobalt/bin/mipsel--netbsd-install -c -r -m 555 \
	   usr/src/sbin/fdisk/obj.cobalt/fdisk data/cobalt/sbin
	usr/src/tooldir.cobalt/bin/mipsel--netbsd-install -c -r -m 555 \
	   usr/src/sbin/fdisk/obj.cobalt/fdisk data/cobalt/install/files/sbin

DONE_COBALT_KERNELS=	.done_cobalt_kernels

${DONE_COBALT_KERNELS}: ${DONE_COBALT_TOOLS}
	${MAKE} build_cobalt_kernels
	touch ${DONE_COBALT_KERNELS}

build_cobalt_kernels:
	(cd usr/src; ${PATCH} -p < ../../patch/cobalt-netbsd-4-20080312.diff)
	(cd usr/src; \
	    ${SH} build.sh -m cobalt -u -U \
	    -T tooldir.cobalt -D destdir.cobalt \
	    -V OBJMACHINE=1 kernel=GENERIC)
	gzip -9c usr/src/sys/arch/cobalt/compile/obj.cobalt/GENERIC/netbsd > \
	    binary/cobalt/netbsd-GENERIC.gz
	(cd usr/src; \
	    ${SH} build.sh -m cobalt -u -U -T tooldir.cobalt -D destdir.cobalt \
	    -V OBJMACHINE=1 kernel=INSTALL)
	gzip -9c usr/src/sys/arch/cobalt/compile/obj.cobalt/INSTALL/netbsd > \
	    binary/cobalt/netbsd-INSTALL.gz
	(cd usr/src/sys/arch/cobalt/stand/boot && \
	    ../../../../../tooldir.cobalt/bin/nbmake-cobalt \
	    OBJMACHINE=1 obj && \
	    ../../../../../tooldir.cobalt/bin/nbmake-cobalt dependall )
	cp usr/src/sys/arch/cobalt/stand/boot/obj.cobalt/boot.gz binary/cobalt/


DONE_COBALT_BINARIES=	.done_cobalt_binaries

${DONE_COBALT_BINARIES}: ${DONE_PANELD} ${DONE_NEWFS_EXT2FS} ${DONE_FDISK}
	touch ${DONE_COBALT_BINARIES}


DONE_COBALT_SETS=	.done_cobalt_sets

${DONE_COBALT_SETS}: ${DONE_COBALT_BINARIES} ${DONE_COBALT_KERNELS}
	${MAKE} build_cobalt_sets
	touch ${DONE_COBALT_SETS}

build_cobalt_sets:
	cp binary/cobalt/netbsd-GENERIC.gz download/cobalt/binary/kernel
	cp binary/cobalt/netbsd-INSTALL.gz download/cobalt/binary/kernel
	mkdir -p usr/mdec
	${GZIP} -dc binary/cobalt/boot.gz > usr/mdec/boot
	gunzip download/cobalt/binary/sets/base.tgz
	${TAR} -rf download/cobalt/binary/sets/base.tar ./usr/mdec/boot
	${GZIP} download/cobalt/binary/sets/base.tar && \
	mv download/cobalt/binary/sets/base.tar.gz \
	    download/cobalt/binary/sets/base.tgz

DONE_I386_TOOLS=	.done_i386_tools

${DONE_I386_TOOLS}:
	${MAKE} build_i386_tools
	touch	${DONE_I386_TOOLS}

build_i386_tools:
	(cd usr/src; \
	    ${SH} build.sh -m i386 -u -U -T tooldir.i386 -V OBJMACHINE=1 tools)

RESTORECD_ISO=	cd.tmp/restorecd.iso

restorecd: ${RESTORECD_ISO}

${RESTORECD_ISO}: ${DONE_COBALT_SETS} ${DONE_I386_TOOLS}
	${SH} restorecd server=`pwd`/download \
               client=`pwd`/download \
               source=`pwd`/usr/src  \
               tooldir=`pwd`/usr/src/tooldir.i386 -v

clean:
	rm -f .done_*
	rm -rf cd.tmp

distclean: clean
	(cd download && rm -rf *)
	# XXX rm -rf complains on removing dir with 0111 permission
	rm -df usr/src/destdir.cobalt/var/spool/ftp/hidden
	rm -rf usr
