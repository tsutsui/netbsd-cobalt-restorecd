
disk_avail=$DLSIZE
# disk_align=`expr $DLSIZE / $BCYL`
disk_align=`expr $DLSEC \* $DLHEAD`
disk_reserved=63

# 10Mb
e2fs_size=10485760

two_gigs=2147483648
ten_gigs=10737418240
five_megs=524288000

slice_size=0
part_start=0

sector_size=512

#
# printmsg <category> <msg>
#	Print a message on console and on Cobalt LCD screen.
printmsg()
{
	_category="$1"
	_message="$2"

	echo ""
	echo " ------------------------------------------------"
	echo "  $_category: $_message"
	echo " ------------------------------------------------"
	echo ""

	_panel=/dev/lcdpanel0
	[ -c $_panel ] &&
		printf "%-16s%-16s" "$_category" "  $_message" > $_panel
}

align_size()
{
	sz=`expr "$1" / "$disk_align" \* "$disk_align"`

	if [ $1 -gt $sz ]; then
		align=`expr "$sz" + "$disk_align"`
	else
		align=$sz
	fi

	if [ $align -le 0 ]; then
		printmsg "PANIC" "Requested partition size <= 0."
		exit 1
	fi

	export align
}

get_slice_size()
{
	sz=`expr $1 / "$sector_size"`

	align_size $sz

	size=$align
	export size
}

update_avail()
{
	disk_avail=`expr $disk_avail - $1`
	part_start=`expr $part_start + $1`

	if [ $disk_avail -le 0 ]; then
		printmsg "PANIC" "Disk is too small."
		exit 1
	fi
}

# setup small ext2 partition
create_altroot()
{
	printmsg "Disk Setup" "Add Ext2 slice"

	get_slice_size $e2fs_size
	altrootsize=`expr $size - $disk_reserved`

	$FDISK -0 -f -u -b $DLCYL/$DLHEAD/$DLSEC \
	    -s $LINUX_PART/$disk_reserved/$altrootsize $DISK

	update_avail $size

	echo " e: $altrootsize $disk_reserved Linux Ext2 0 0" >> $PTAB
}

# create swap partition
create_swap()
{
	printmsg "Disk Setup" "Enable swap"

	req_size=`$SYSCTL -n hw.physmem`
	req_size=`expr $req_size \* 2`

	get_slice_size $req_size
	$FDISK -1 -f -u -b $DLCYL/$DLHEAD/$DLSEC \
	    -s $LINUX_SWAP/$part_start/$size $DISK

	echo " b: $size $part_start swap" >> $PTAB

	update_avail $size
}

# create NetBSD partition
create_42bsd()
{
	printmsg "Disk Setup" "Add BSD slice"

	$FDISK -2 -f -u -b $DLCYL/$DLHEAD/$DLSEC \
	    -s $NETBSD_PART/$part_start/$disk_avail $DISK

	echo " c: $disk_avail $part_start unused 0 0" >> $PTAB
	echo " d: $DLSIZE 0 unused 0 0" >> $PTAB

	bsd_size=$disk_avail
	export bsd_size
}

# create /var slice
create_var_slice()
{
	# try to take 20% of the available disk space (10% if disk size < 2G)
	get_slice_size $two_gigs
	if [ $DLSIZE -le $size ]; then
		div=10
	else
		div=5
	fi

	varsz=`expr $bsd_size / $div`

	# if it's more than 2G, stick to 2G
	get_slice_size $two_gigs
	if [ $varsz -gt $size ]; then
		varsz=$size
	fi

	align_size $varsz
	varsz=$align

	echo " f: $varsz $part_start 4.2BSD 1024 8192 64" >> $PTAB

	update_avail $varsz
}

# create /tmp slice
create_tmp_slice()
{
	# try to take 5% of the available disk space
	tmpsz=`expr $bsd_size / 10`

	# if it's more than 500m, stick to 500m
	get_slice_size $five_megs

	if [ $tmpsz -gt $size ]; then
		tmpsz=$size
	fi

	align_size $tmpsz
	tmpsz=$align

	echo " g: $tmpsz $part_start 4.2BSD 1024 8192 64" >> $PTAB

	update_avail $tmpsz
}

# create / slice
create_root_slice()
{
	# the rest is for the installation
	echo " a: $disk_avail $part_start 4.2BSD 1024 8192 64" >> $PTAB
}

# remove all partition tables
clear_disk()
{
	printmsg "Disk Setup" "Reset disk"

	$FDISK -0 -f -u -b $DLCYL/$DLHEAD/$DLSEC -s 0/0/0 $DISK
	$FDISK -1 -f -u -b $DLCYL/$DLHEAD/$DLSEC -s 0/0/0 $DISK
	$FDISK -2 -f -u -b $DLCYL/$DLHEAD/$DLSEC -s 0/0/0 $DISK
	$FDISK -3 -f -u -b $DLCYL/$DLHEAD/$DLSEC -s 0/0/0 $DISK
}

install_disklabel()
{
	$DISKLABEL $DISK | $SED '/^..:/d' >$INSTPTAB
	$CAT $PTAB >> $INSTPTAB

	$DISKLABEL -R -r $DISK $INSTPTAB
}

init_filesystems()
{
	printmsg "Disk Setup" "Format boot"
	$NEWFS_EXT2FS -O 0 $ALTROOT_RDEV

	printmsg "Disk Setup" "Format /var"
	$NEWFS $VAR_RDEV

	printmsg "Disk Setup" "Format /tmp"
	$NEWFS $TMP_RDEV

	printmsg "Disk Setup" "Format root"
	$NEWFS $ROOT_RDEV
}

install_boot()
{
	printmsg "System install" "Setup /boot"

	bootfs=/mnt/ext2

	$MKDIR $bootfs
	$MOUNT $ALTROOT_DEV $bootfs

	$MKDIR $bootfs/boot
	$MKDIR $bootfs/usr $bootfs/usr/games

	# Copy boot loader and the kernels as a backup measure
	$GZIP -9c /mnt/usr/mdec/boot > $bootfs/boot/boot.gz
	$CP /cobalt/binary/kernel/netbsd-INSTALL.gz $bootfs/boot
	$LN $bootfs/boot/netbsd-INSTALL.gz $bootfs/usr/games/.doug

	cd $bootfs/boot
	for i in $RAQ_KERNELS; do
		$LN -s boot.gz $i
	done

	cd /
	$UMOUNT $bootfs
}

install_files()
{
	printmsg "System install" "Prepare..."

	$MOUNT $MOUNT_FFS_OPT $ROOT_DEV /mnt

	$MKDIR /mnt/var
	$MOUNT $MOUNT_FFS_OPT $VAR_DEV /mnt/var

	$MKDIR /mnt/tmp
	$MOUNT $MOUNT_FFS_OPT $TMP_DEV /mnt/tmp

	cd /mnt
	for _set in $INST_TARBALLS; do
		printmsg "System install" "$_set"
		$GZIP -cd /cobalt/binary/sets/$_set | $TAR xpf -
	done

	printmsg "System install" "Unpack kernel"
	$GZIP -cd /cobalt/binary/kernel/netbsd-GENERIC.gz > /mnt/netbsd

	install_boot

	printmsg "System install" "Create /dev/*"
	if [ -d /mnt/dev ]; then
		cd /mnt/dev && ./MAKEDEV all
	else
		printmsg "WARNING" "No /mnt/dev"
	fi

	printmsg "System install" "Fix /etc/*"

	# Backup original files
	curdir=`pwd`
	cd /install/files/etc
	for i in *; do
		if [ -f /mnt/etc/$i ]; then
			mv /mnt/etc/$i /mnt/etc/$i.orig
		fi
	done
	cd $curdir

	# Copy everything needed to complete the installation
	( cd /install/files && tar cpf - * ) | ( cd /mnt && tar xpf - )

	cd /

	printmsg "System install" "Finalizing..."

	$MKDIR /mnt/kern /mnt/proc

	# Fix permissions
	$CHMOD 755 /mnt/var
	$CHMOD 1777 /mnt/tmp

	$UMOUNT /mnt/tmp
	$UMOUNT /mnt/var
	$UMOUNT /mnt
}

do_reboot()
{
	printmsg "Installed OK" "Rebooting..."
	$REBOOT
}

install()
{
	# installation entry point
	$RM -f $PTAB
	$TOUCH $PTAB

	# Create LCD device
	cd /dev && ./MAKEDEV lcdpanel

	# 1. Create partition table.
	clear_disk
	create_altroot
	create_swap
	create_42bsd

	# 2. Create slices within 4.2BSD partition.
	create_var_slice
	create_tmp_slice
	create_root_slice

	# 3. Install the disklabel and initialize filesystems.
	install_disklabel
	init_filesystems

	# 4. Install kernel(s) and files.
	install_files

	# 5. Finalize the installation and reboot.
	do_reboot
}

install
