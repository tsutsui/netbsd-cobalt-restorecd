# sample Makefile to describe "how to build restorecd"

WGET?=		/usr/pkg/bin/wget
#WGET=		/usr/bin/wget
#WGET=		/usr/local/bin/wget

RSYNC?= 	/usr/pkg/bin/rsync
#RSYNC=		/usr/bin/rsync
#RSYNC=		/usr/local/bin/rsync

TAR?=		tar
PATCH?=		patch
FTP?=		ftp
SH?=		sh
#GZIP?=		gzip
GZIP?=		pigz
MKDIR?=		mkdir
TOUCH?=		touch

# ftp/rsync server settings
#  - use appropriate mirrors mentioned in http://www.NetBSD.org/mirrors/
#  - check daily snapshot status first:
#	http://releng.NetBSD.org/cgi-bin/builds.cgi
#    and specify appropriate date directory.

#FTP_HOST?=	ftp.NetBSD.org
FTP_HOST=	ftp7.jp.NetBSD.org
#FTP_HOST=	cdn.NetBSD.org

RELEASE=9.3
RELEASE_DATE=	20220923
#DAILY_DIR?=	202209212340Z
#FTP_DIR?=	pub/NetBSD-daily/HEAD/${DAILY_DIR}
#FTP_DIR?=	pub/NetBSD-daily/netbsd-9/${DAILY_DIR}
FTP_DIR?=	pub/NetBSD/NetBSD-${RELEASE}

WGET_URL?=	ftp://${FTP_HOST}/${FTP_DIR}
# adjuct NCUTDIR by FTP_DIR where you'll get files
#WGET_NCUTDIR?=	4	# for NetBSD-daily
WGET_NCUTDIR?=	3	# for release

RSYNC_HOST?=	rsync.NetBSD.org
#RSYNC_HOST=	rsync.jp.NetBSD.org
RSYNC_PREFIX?=

#RSYNC_HOST=	rsync3.jp.NetBSD.org
#RSYNC_PREFIX=	pub/

#RSYNC_DIR?=	${RSYNC_PREFIX}NetBSD-daily/HEAD/${DAILY_DIR}
#RSYNC_DIR?=	${RSYNC_PREFIX}NetBSD-daily/netbsd-9/${DAILY_DIR}
RSYNC_DIR?=	${RSYNC_PREFIX}NetBSD/NetBSD-${RELEASE}
RSYNC_URL?=	rsync://${RSYNC_HOST}/${RSYNC_DIR}

DOWNLOADDIR=	download
SOURCESETSDIR=	${DOWNLOADDIR}/source/sets
GNUSRCSETS=	${SOURCESETSDIR}/gnusrc.tgz
SHARESRCSETS=	${SOURCESETSDIR}/sharesrc.tgz
SRCSETS=	${SOURCESETSDIR}/src.tgz
SYSSRCSETS=	${SOURCESETSDIR}/syssrc.tgz
ALLSRCSETS=	${GNUSRCSETS} ${SHARESRCSETS} ${SRCSETS} ${SYSSRCSETS}

all: restorecd restoreusb

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
	    --directory-prefix=${DOWNLOADDIR} --input-file=${FETCH_LIST} \
	    --retr-symlinks=no

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
	   paneltools/paneld/paneld.8 \
	   data/cobalt/install/files/usr/share/man/man8

RESTORECD_ISO=	cd.tmp/restorecd.iso

restorecd: ${RESTORECD_ISO}

${RESTORECD_ISO}: ${DONE_PANELD} ${DONE_COBALT_TOOLS}
	${SH} restorecd server=`pwd`/${DOWNLOADDIR} \
               client=`pwd`/${DOWNLOADDIR} \
               source=`pwd`/usr/src  \
               tooldir=`pwd`/usr/src/tooldir.cobalt media=cd -v

RESTOREUSB_IMG=	usb.tmp/restoreusb.img

restoreusb: ${RESTOREUSB_IMG}

${RESTOREUSB_IMG}: ${DONE_PANELD} ${DONE_COBALT_TOOLS}
	${SH} restorecd server=`pwd`/${DOWNLOADDIR} \
               client=`pwd`/${DOWNLOADDIR} \
               source=`pwd`/usr/src  \
               tooldir=`pwd`/usr/src/tooldir.cobalt media=usb -v

IMAGEDIR=images/${RELEASE_DATE}
RESTORECD_ISO_RELEASE= ${IMAGEDIR}/restorecd-${RELEASE}-${RELEASE_DATE}.iso.gz
RESTOREUSB_IMG_RELEASE= ${IMAGEDIR}/restoreusb-${RELEASE}-${RELEASE_DATE}.img.gz
MD5=	cksum -a md5
SHA512=	cksum -a sha512

release: ${RESTORECD_ISO} ${RESTOREUSB_IMG}
	mkdir -p ${IMAGEDIR}
	rm -f ${RESTORECD_ISO_RELEASE} ${RESTOREUSB_IMG_RELEASE}
	${GZIP} -9c ${RESTORECD_ISO} > ${RESTORECD_ISO_RELEASE}.tmp
	mv ${RESTORECD_ISO_RELEASE}.tmp ${RESTORECD_ISO_RELEASE}
	${GZIP} -9c ${RESTOREUSB_IMG} > ${RESTOREUSB_IMG_RELEASE}.tmp
	mv ${RESTOREUSB_IMG_RELEASE}.tmp ${RESTOREUSB_IMG_RELEASE}
	(cd ${IMAGEDIR} && ${MD5} *.gz > MD5)
	(cd ${IMAGEDIR} && ${SHA512} *.gz > SHA512)

clean:
	rm -f .done_*
	rm -rf cd.tmp
	rm -rf usb.tmp

distclean cleandir: clean
	rm -rf ${DOWNLOADDIR}
	rm -rf paneltools
	# XXX rm -rf complains on removing dir with 0111 permission
	rm -df usr/src/destdir.cobalt/var/spool/ftp/hidden
	rm -rf usr
