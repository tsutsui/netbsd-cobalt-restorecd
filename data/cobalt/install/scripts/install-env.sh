#!/bin/sh

SH=/bin/sh
RM=/bin/rm
CP=/bin/cp
LS=/bin/ls
LN=/bin/ln
TAR=/usr/bin/tar
CAT=/bin/cat
GZIP=/usr/bin/gzip
CHMOD=/bin/chmod
FDISK=/sbin/fdisk
SYSCTL=/sbin/sysctl
REBOOT=/sbin/reboot
NEWFS=/sbin/newfs
NEWFS_EXT2FS=/sbin/newfs_ext2fs
DISKLABEL=/sbin/disklabel
MOUNT=/sbin/mount
UMOUNT=/sbin/umount
MKDIR=/bin/mkdir
MKNOD=/sbin/mknod
PAX=/bin/pax
SED=/usr/bin/sed
TOUCH=/usr/bin/touch

INSTALL_SH=/tmp/install.sh
INSTALL_CORE=/install/scripts/install-core.sh

RAQ_KERNELS="vmlinux.gz vmlinux-nfsroot.gz vmlinux_RAQ.gz vmlinux_raq-2800.gz"

VAR_TARBALLS="base.tgz rescue.tgz etc.tgz"
INST_TARBALLS="modules.tgz base.tgz rescue.tgz comp.tgz etc.tgz man.tgz misc.tgz text.tgz"

DISK=/dev/wd0

ALTROOT_DEV=/dev/wd0e
ALTROOT_RDEV=/dev/rwd0e
ROOT_DEV=/dev/wd0a
ROOT_RDEV=/dev/rwd0a
SWAP_DEV=/dev/wd0b
VAR_DEV=/dev/wd0f
VAR_RDEV=/dev/rwd0f
TMP_DEV=/dev/wd0g
TMP_RDEV=/dev/rwd0g

MOUNT_FFS_OPT="-o async"

LINUX_PART=131
LINUX_SWAP=130
NETBSD_PART=169

PTAB=/tmp/ptab
INSTPTAB=/tmp/inst.ptab
