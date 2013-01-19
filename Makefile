# sample Makefile to describe "how to build restorecd"

WGET?=		/usr/pkg/bin/wget
#WGET=		/usr/bin/wget
#WGET=		/usr/local/bin/wget

RSYNC?= 	/usr/pkg/bin/rsync
#RSYNC= 	/usr/bin/rsync
#RSYNC= 	/usr/local/bin/rsync

TAR?=		tar
PATCH?=		patch
FTP?=		ftp
SH?=		sh
GZIP?=		gzip
MKDIR?=		mkdir
TOUCH?=		touch

# ftp/rsync server settings
#  - use appropriate mirrors mentioned in http://www.NetBSD.org/mirrors/
#  - check daily snapshot status first:
#	http://releng.NetBSD.org/cgi-bin/builds.cgi
#    and specify appropriate date directory.

FTP_HOST?=	ftp.NetBSD.org
#FTP_HOST=	ftp.jp.NetBSD.org
#FTP_HOST=	ftp5.jp.NetBSD.org

DAILY_DIR?=	200811160002Z
#FTP_DIR?=	pub/NetBSD-daily/HEAD/${DAILY_DIR}
FTP_DIR?=	pub/NetBSD-daily/netbsd-5/${DAILY_DIR}
#FTP_DIR?=	pub/NetBSD/NetBSD-5.0

WGET_URL?=	ftp://${FTP_HOST}/${FTP_DIR}
# adjuct NCUTDIR by FTP_DIR where you'll get files
WGET_NCUTDIR?=	4	# for NetBSD-daily
#WGET_NCUTDIR?=	3	# for release

RSYNC_HOST?=	rsync.NetBSD.org
#RSYNC_HOST=	rsync.jp.NetBSD.org
RSYNC_PREFIX?=

#RSYNC_HOST=	rsync3.jp.NetBSD.org
#RSYNC_PREFIX=	pub/

#RSYNC_DIR?=	${RSYNC_PREFIX}NetBSD-daily/HEAD/${DAILY_DIR}
RSYNC_DIR?=	${RSYNC_PREFIX}NetBSD-daily/netbsd-5/${DAILY_DIR}
RSYNC_URL?=	rsync://${RSYNC_HOST}/${RSYNC_DIR}

DOWNLOADDIR=	download
SOURCESETSDIR=	${DOWNLOADDIR}/source/sets
GNUSRCSETS=	${SOURCESETSDIR}/gnusrc.tgz
SHARESRCSETS=	${SOURCESETSDIR}/sharesrc.tgz
SRCSETS=	${SOURCESETSDIR}/src.tgz
SYSSRCSETS=	${SOURCESETSDIR}/syssrc.tgz
ALLSRCSETS=	${GNUSRCSETS} ${SHARESRCSETS} ${SRCSETS} ${SYSSRCSETS}

all: restorecd

DONE_FETCH=	.done_fetch

${DONE_FETCH}:
	${MKDIR} -p ${DOWNLOADDIR}
	${MAKE} fetch_wget
#	${MAKE} fetch_rsync
	${TOUCH} ${DONE_FETCH}

FETCH_LIST?=	restorecd-fetch.lst

fetch_rsync: ${RSYNC}
	${RSYNC} -va --files-from=${FETCH_LIST} ${RSYNC_URL} ${DOWNLOADDIR}

fetch_wget: ${WGET}
	${WGET} --base=${WGET_URL}/ --cut-dirs=${WGET_NCUTDIR} \
	    --no-host-directories --timestamping --force-directories \
	    --directory-prefix=${DOWNLOADDIR} --input-file=${FETCH_LIST}

DONE_EXTRACT=	.done_extract

${DONE_EXTRACT}: ${DONE_FETCH}
	${MAKE} extract_sets
	${TOUCH} ${DONE_EXTRACT}

extract_sets: ${ALLSRCSETS}
	${TAR} -zxf ${GNUSRCSETS}
	${TAR} -zxf ${SHARESRCSETS}
	${TAR} -zxf ${SRCSETS}
	${TAR} -zxf ${SYSSRCSETS}

DONE_COBALT_TOOLS=	.done_cobalt_tools

${DONE_COBALT_TOOLS}: ${DONE_EXTRACT}
	${MAKE} build_cobalt_tools
	${TOUCH} ${DONE_COBALT_TOOLS}

build_cobalt_tools:
	(cd usr/src; \
	    ${SH} build.sh -m cobalt -u -U \
	    -T tooldir.cobalt -D destdir.cobalt \
	    -V OBJMACHINE=1 tools)
	(cd usr/src; \
	   tooldir.cobalt/bin/nbmake-cobalt do-distrib-dirs)
	(cd usr/src/destdir.cobalt; \
	    ${TAR} -zxf ../../../${DOWNLOADDIR}/cobalt/binary/sets/base.tgz)
	(cd usr/src/destdir.cobalt; \
	    ${TAR} -zxf ../../../${DOWNLOADDIR}/cobalt/binary/sets/comp.tgz)


DONE_PANELD=	.done_paneld

${DONE_PANELD}: ${DONE_COBALT_TOOLS}
	${MAKE} build_paneld
	${TOUCH} ${DONE_PANELD}

build_paneld:
	${TAR} -zxf paneld/paneld.tar.gz
	${PATCH} -d paneltools -p0 < paneld/paneld_banner_refresh.diff
	${PATCH} -p0 < paneld/paneld-20081030.diff
	(cd paneltools/paneld && \
	    ../../usr/src/tooldir.cobalt/bin/nbmake-cobalt OBJMACHINE=1 obj && \
	    ../../usr/src/tooldir.cobalt/bin/nbmake-cobalt dependall)
	usr/src/tooldir.cobalt/bin/mipsel--netbsd-install -c -r -m 555 \
	    paneltools/paneld/obj.cobalt/paneld \
	    data/cobalt/install/files/usr/sbin
	usr/src/tooldir.cobalt/bin/mipsel--netbsd-install -c -r -m 555 \
	    paneltools/paneld/obj.cobalt/paneld \
	    data/cobalt/usr/sbin
	usr/src/tooldir.cobalt/bin/mipsel--netbsd-install -c -r -m 444 \
	    paneltools/paneld/paneld.conf.5 \
	    data/cobalt/install/files/usr/share/man/man5
	usr/src/tooldir.cobalt/bin/mipsel--netbsd-install -c -r -m 444 \
	    paneltools/paneld/obj.cobalt/paneld.conf.cat5 \
	    data/cobalt/install/files/usr/share/man/cat5/paneld.conf.0
	usr/src/tooldir.cobalt/bin/mipsel--netbsd-install -c -r -m 444 \
	   paneltools/paneld/paneld.8 \
	   data/cobalt/install/files/usr/share/man/man8
	usr/src/tooldir.cobalt/bin/mipsel--netbsd-install -c -r -m 444 \
	    paneltools/paneld/obj.cobalt/paneld.cat8 \
	    data/cobalt/install/files/usr/share/man/cat8/paneld.0

RESTORECD_ISO=	cd.tmp/restorecd.iso

restorecd: ${RESTORECD_ISO}

${RESTORECD_ISO}: ${DONE_PANELD} ${DONE_COBALT_TOOLS}
	${SH} restorecd server=`pwd`/${DOWNLOADDIR} \
               client=`pwd`/${DOWNLOADDIR} \
               source=`pwd`/usr/src  \
               makefs=`pwd`/usr/src/tooldir.cobalt/bin/nbmakefs -v

clean:
	rm -f .done_*
	rm -rf cd.tmp

distclean cleandir: clean
	rm -rf ${DOWNLOADDIR}
	rm -rf paneltools
	# XXX rm -rf complains on removing dir with 0111 permission
	rm -df usr/src/destdir.cobalt/var/spool/ftp/hidden
	rm -rf usr
