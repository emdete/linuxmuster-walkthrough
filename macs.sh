#!/bin/bash -eu
# Liste aller interfaces aller VMs und deren bridge-Devices und MACs
TEMPFILE=`tempfile --suffix .xml`
echo VM No Mac Bridge
for DOMAIN in $(virsh list --all|awk '!/^( Id|---|$)/{print $2}') ; do
	virsh dumpxml $DOMAIN > $TEMPFILE
	n=1
	while true; do
		if xmlstarlet sel -t -v "//domain/devices/interface[$n]/@type" $TEMPFILE > /dev/null ; then
			MAC=$(xmlstarlet sel -t -v "//domain/devices/interface[$n]/mac/@address" $TEMPFILE || true)
			BRIDGE=$(xmlstarlet sel -t -v "//domain/devices/interface[$n]/source/@bridge" $TEMPFILE || true)
			echo $DOMAIN $n $MAC $BRIDGE
		else
			break
		fi
		n=$(expr $n + 1)
	done
done
rm $TEMPFILE
