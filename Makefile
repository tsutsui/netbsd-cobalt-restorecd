WGET?=		/usr/pkg/bin/wget
#WGET?=		/usr/local/bin/wget

RSYNC?= 	/usr/pkg/bin/rsync
#RSYNC?= 	/usr/local/bin/rsync

TAR?=		tar
PATCH?=		patch
FTP?=		ftp
SH?=		sh
GZIP?=		gzip

# - use appropriate mirrors mentioned in http://www.NetBSD.org/mirrors/
# - check daily snapshot status first:
#    http://releng.NetBSD.org/cgi-bin/builds.cgi
#   and specify appropriate date directory.

FTP_HOST?=	ftp.NetBSD.org
#FTP_HOST?=	ftp.jp.NetBSD.org
#FTP_HOST?=	ftp5.jp.NetBSD.org
FTP_DIR?=	pub/NetBSD-daily/HEAD/200810060002Z

RSYNC_HOST?=	rsync.NetBSD.org
RSYNC_DIR?=	NetBSD-daily/HEAD/200810060002Z

#RSYNC_HOST?=	rsync3.jp.NetBSD.org
#RSYNC_DIR?=	pub/NetBSD-daily/HEAD/200810060002Z

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
#	${MAKE} fetch_wget
	${MAKE} fetch_rsync
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
	${TAR} -zxpf ${GNUSRCSETS}
	${TAR} -zxpf ${SHARESRCSETS}
	${TAR} -zxpf ${SRCSETS}
	${TAR} -zxpf ${SYSSRCSETS}
	chmod +x usr/src/dist/file/install-sh	# XXX

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
	${TAR} -zxf patch/paneld.tar.gz
	${PATCH} -d paneltools -p < patch/paneld_banner_refresh.diff
	${PATCH} -p < patch/paneld-20080912.diff
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

DONE_I386_TOOLS=	.done_i386_tools

${DONE_I386_TOOLS}:
	${MAKE} build_i386_tools
	touch	${DONE_I386_TOOLS}

build_i386_tools:
	(cd usr/src; \
	    ${SH} build.sh -m i386 -u -U -T tooldir.i386 -V OBJMACHINE=1 tools)

RESTORECD_ISO=	cd.tmp/restorecd.iso

restorecd: ${RESTORECD_ISO}

${RESTORECD_ISO}: ${DONE_PANELD} ${DONE_I386_TOOLS}
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
