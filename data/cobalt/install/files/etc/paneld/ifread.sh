#!/bin/sh

ETC_MYGATE=/etc/mygate
ETC_IFCONFIG=/etc/ifconfig.$1

print_default()
{
	echo "0.0.0.0"
	exit $?
}

print_config()
{
	case $2 in
	ipaddr)
		if [ -f $ETC_IFCONFIG ]; then
			/usr/bin/awk '{ print $2 }' $ETC_IFCONFIG
			exit $?
		fi
		;;
	ipmask)
		if [ -f $ETC_IFCONFIG ]; then
			/usr/bin/awk '{ print $4 }' $ETC_IFCONFIG
			exit $?
		fi
		;;
	gw)
		if [ -f $ETC_MYGATE ]; then
			/bin/cat $ETC_MYGATE
			exit $?
		fi
		;;
	esac

	print_default
}

if [ $# -ne 2 ]; then
	print_default
fi

print_config $1 $2 $3
