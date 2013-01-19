#!/bin/sh

ROUTE=/sbin/route
MYGATE=/etc/mygate
IFCONFIG=/sbin/ifconfig
ETC_IFCONFIG=/etc/ifconfig.$1

change_gateway()
{
	if [ -f $MYGATE ]; then
		mv $MYGATE $MYGATE.old;
	fi
	echo $1 > $MYGATE

	$ROUTE delete -net default > /dev/null
	$ROUTE add -net default $1 > /dev/null
	exit $?
}

if [ -f $ETC_IFCONFIG ]; then
	mv $ETC_IFCONFIG $ETC_IFCONFIG.old
fi

echo "inet $2 netmask $3" > $ETC_IFCONFIG

$IFCONFIG $1 delete > /dev/null
$IFCONFIG $1 inet $2 netmask $3 > /dev/null
if [ $? -ne 0 ]; then
	exit 1;
fi

if [ "$4" != "0.0.0.0" ]; then
	change_gateway $4
fi

exit 0
