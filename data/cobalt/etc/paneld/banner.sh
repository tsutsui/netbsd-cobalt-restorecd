#!/bin/sh

AWK=/usr/bin/awk
GREP=/usr/bin/grep
SED=/usr/bin/sed
TAIL=/usr/bin/tail

DIG=/usr/bin/dig
HOSTNAME=/bin/hostname
IFCONFIG=/sbin/ifconfig
ETC_IFCONFIG=/etc/ifconfig.tlp0

HOST=`/bin/hostname`

if [ -f $ETC_IFCONFIG ]; then
	ADDR=`$AWK '{ print $2 }' $ETC_IFCONFIG`
else
	ADDR=`$IFCONFIG tlp0 | $GREP 'inet ' | $AWK '{ print $2 }' | $SED 's,/[0-9]*,,'`
fi

if [ "$HOST" != "" ]; then
	if [ "$ADDR" = "" ]; then
		ADDR=0.0.0.0
	fi
else
	if [ "$ADDR" != "" ]; then
		HOST=`$DIG +short -x $ADDR`
	fi

	if [ "$HOST" = "" ]; then
		HOST=unknown.host
	fi

	if [ "$ADDR" = "" ]; then
		ADDR=0.0.0.0
	fi
fi

echo "restorecd ready"
echo "[$ADDR]"

exit 0
