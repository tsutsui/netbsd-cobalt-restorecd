#!/bin/sh

. /install/scripts/install-env.sh

$RM -f $INSTALL_SH

echo "#!/bin/sh" > $INSTALL_SH
echo >> $INSTALL_SH
echo ". /install/scripts/install-env.sh" >> $INSTALL_SH
echo >> $INSTALL_SH

# XXX
$FDISK -S $DISK | $SED '/^Drive serial/d' >> $INSTALL_SH
$CAT $INSTALL_CORE >> $INSTALL_SH

$SH $INSTALL_SH
