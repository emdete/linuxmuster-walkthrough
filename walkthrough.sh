#!/bin/bash -e
# http://docs.linuxmuster.net/de/v7/appendix/install-on-kvm/index.html
# http://docs.linuxmuster.net/de/v7/getting-started/setup.html#erstkonfiguration-am-server
# https://github.com/linuxmuster/linuxmuster-base7/wiki/Ersteinrichtung-der-Appliances#serveropsidocker
# https://wiki.debian.org/BridgeNetworkConnections
#
# Vorraussetzung ist ein Debian-basiertes Host-System, auf dem dieses Script
# gestartet wird. Das Script sollte, wenn es mehrfach gestartet wird immer im
# selben Verzeichnis laufen, da es dann die Images nicht neu laed. Die Images
# brauchen ca 9GB, das bionic Image 7.3GB (ich lasse das Script auf einem
# minimalen Debian-System mit 30GB fuer das rootfs laufen).
#
# Das installierte System basiert auf libvirt und Freunde (qemu, virtinst,
# kvm), das in der Linuxmuster-Dokumentation "KVM" genannt wird.
#
# Das Script loescht Artefakte von vorhergehenden Versuchen. Es sollte nicht
# auf Systemen laufen, die bereits irgendwelche relevanten Daten, Konfigurationen
# oder VMs enthalten.
#
# Das Script installiert ein Image für die Clients. Wenn auf dem Host eine
# Datei lmn-bionic-<CLOOP_VERSION>.zip gefunden wird, wird diese auf den
# LM-Server kopiert und installiert. Andernfalls installiert das Script per
# Befehl `linuxmuster-client download -c bionic` auf dem Server das Image
# direkt (was zur Zeit noch nicht funktioniert). Desweiteren importiert das
# Script ein dump aus einer alten Installation, wenn eine Datei
# "sophomorix-dump.tgz" vorhanden ist.
#
# Die Version, die von LM heruntergeladen wird:
RELEASE=20190724
# Das Ziel der Installation, in dieser Partition werden die LVs erzeugt:
TARGET=/dev/sda2
# Jeden Schritt, den das Script tut per <Enter> bestätigen lassen:
STEP=n
# Das Netwerk des Hostsystems einrichten:
HOST_NETWORK=n
HOST_LINK_RED=eth0
HOST_LINK_SERVER=eth1
HOST_LINK_DMZ=eth2
#ip -br link | awk '$3 ~ /[:0-9a-f]+/ && $1 != "lo" {print $1, $3}'
# LDAP Namen:
LDAP_PLANET=earth
LDAP_COUNTRY=de
LDAP_STATE=NI
LDAP_LOCATION=Wald
LDAP_SCHOOLNAME=Hasenschule
LDAP_DOMAIN=lampe
# Client Konfiguration, eine Beispielinstallation für einen Client wird vorgenommen
CLIENT_MAC=00:00:00:00:00:00
CLOOP_VERSION=0320
# Obige Einstellungen koennen in walkthrough.rc ueberschrieben werden:
if [ -f walkthrough.rc ] ; then
	. ./walkthrough.rc
fi
# Nun gehts los:
export LANG=C
unset VISUAL SELECTED_EDITOR EDITOR
___comment_and_ask() {
	echo -n "--- $(date -Ins) $*"
	if [ "$STEP" == 'y' ] ; then
		echo -n "? (Y/n) "
		read a
		if [ "$a" == 'n' ] ; then
			exit 3
		fi
	else
		echo
	fi
}
# Diese Pakete sind auf dem virtualisierungsserver nötig:
HOSTPACKAGES="virt-manager libvirt-clients virtinst lvm2 qemu-kvm libvirt-daemon-system expect xmlstarlet bridge-utils sshpass"
# bridge-utils sind deprecated (`ip` kann dasselbe) aber ifupdown benoetigt die tools, wenn man darueber bridges konfiguriert
# Dies Script kann nur als 'root' laufen
if [ $(id -u) -ne 0 ] ; then
	echo "--- Bitte als 'root' laufen lassen"
	exit 3
fi
___comment_and_ask "Vorbereitung des Hosts, die Pakete '$HOSTPACKAGES' werden für die Virtualisierung installiert, LMv7 release $RELEASE wird auf $TARGET installiert."
if [ ! -f .ssh/id_rsa.pub ] ; then
	ssh-keygen -N '' -f ~/.ssh/id_rsa
fi
apt update
#apt dist-upgrade -y
apt install -y $HOSTPACKAGES
if [ "$(pvdisplay | awk '/VG Name/{print $3; exit 0}')" != "host-vg" ] ; then
	pvcreate $TARGET
	vgcreate host-vg $TARGET
fi
if [ "$HOST_NETWORK" == "n" ] ; then
	echo "--- Keine Netzwerkkonfiguration"
	# Haben wir Internet & die 3 nötigen Bridges?
	ping -c 1 linuxmuster.net
	ip -br link show dev br-red
	ip -br link show dev br-server
	ip -br link show dev br-dmz
elif [ -x /sbin/ifquery ] ; then
	/etc/init.d/networking stop
	if ! grep -q source /etc/network/interfaces ; then
		echo "source /etc/network/interfaces.d/*" >> /etc/network/interfaces
	fi
	cat > /etc/network/interfaces.d/$HOST_LINK_RED <<EOF
iface $HOST_LINK_RED inet manual
EOF
	cat > /etc/network/interfaces.d/$HOST_LINK_SERVER <<EOF
iface $HOST_LINK_SERVER inet manual
EOF
	cat > /etc/network/interfaces.d/$HOST_LINK_DMZ <<EOF
iface $HOST_LINK_DMZ inet manual
	pre-up ip link add $HOST_LINK_DMZ type dummy
EOF
	cat > /etc/network/interfaces.d/br-dmz <<EOF
iface br-dmz inet manual
	bridge_ports none
	bridge_stp no
EOF
	cat > /etc/network/interfaces.d/br-red <<EOF
iface br-red inet dhcp
	# bridges brauchen einige sekunden, bis sie funktionieren, bis da hin gehen
	# dhcp-requests ins nirvana - noch habe ich keine lösung für das problem.
	bridge_ports $HOST_LINK_RED
	bridge_stp no
EOF
	cat > /etc/network/interfaces.d/br-server <<EOF
iface br-server inet static
	address 10.0.0.2
	netmask 24
	bridge_ports $HOST_LINK_SERVER
	bridge_stp no
EOF
	# ifupdown kennt keine Abhängigkeiten, wir müssen die Reihenfolge manuell festlegen:
	cat > /etc/network/interfaces.d/iforder <<EOF
auto $HOST_LINK_RED
auto $HOST_LINK_SERVER
auto $HOST_LINK_DMZ
auto br-server
auto br-red
auto br-dmz
EOF
	/etc/init.d/networking restart
	echo -n "Waiting bridges to come up ..."
	sleep 32
	echo
elif [ -d /etc/netplan ] ; then
	cat > /etc/netplan/01-netcfg.yaml <<EOF
network:
  version: 2
  renderer: networkd
  ethernets:
    $HOST_LINK_SERVER:
      dhcp4: no
    $HOST_LINK_RED:
      dhcp4: no
    $HOST_LINK_DMZ:
      dhcp4: no
  bridges:
    br-red:
      interfaces: [$HOST_LINK_RED]
      dhcp4: yes
      addresses: [ ]
    br-server:
      interfaces: [$HOST_LINK_SERVER]
      dhcp4: no
      addresses: [ ]
    br-dmz:
      interfaces: [$HOST_LINK_DMZ]
      dhcp4: no
      addresses: [ ]
EOF
	netplan apply
else
	echo "--- Netzwerkmanagment nicht unterstuetzt"
	exit 3
fi
if [ "$(virsh net-list | awk '$1 == "default"{print $2}')" != "active" ] ; then
	virsh net-start default
fi
if [ "$(virsh net-list | awk '$1 == "default"{print $2}')" != "yes" ] ; then
	virsh net-autostart default
fi
___comment_and_ask "Loeschen alter Installationsreste (alle VMs, bekannte LVs)"
#for dom in $(virsh list --all|awk '!/^( Id|---|$)/{print $2}') ; do # Löschen aller virtueller Maschinen
for dom in lmn7-opnsense lmn7-server; do # Löschen aller virtueller Maschinen, die dies Script anlegt
	virsh destroy $dom || true
	virsh undefine $dom
done
rm -vf /var/lib/libvirt/images/lmn7-*.raw
lvremove --yes host-vg/opnsense || true
lvremove --yes host-vg/serverroot || true
lvremove --yes host-vg/serverdata || true
ssh-keygen -f "/root/.ssh/known_hosts" -R "10.0.0.254" || true
ssh-keygen -f "/root/.ssh/known_hosts" -R "10.0.0.1" || true
# virt-convert enthält einen Bug und wird mit einem Fehler beendet. Der Bug ist "reportet", sollte er aber auftreten ist hier Abhilfe:
# BUG in virt-convert: /usr/share/virt-manager/virtconv/formats.py:271 cmd = [executable, "convert", "-O", disk_format, absin, absout]
# BUG in virt-convert: /usr/share/virt-manager/virtconv/ovf.py:228 disk.path = os.path.dirname(input_file) + '/' + path
# https://www.redhat.com/archives/virt-tools-list/2019-June/msg00117.html
# Fazit: TODO: Ersetzen durch virt-install
# qemu-img greift auf einen anderen Pfad zu, der nicht exisitert. Es reicht, das erwartete Verzeichnis zu erzeugen:
# BUG in qemu-img: mkdir /sys/fs/cgroup/unified/machine in /etc/rc.local
___comment_and_ask "Erzeugen der Firewall Opnsense"
wget -Nc https://download.linuxmuster.net/ova/v7/latest/lmn7-opnsense-${RELEASE}.ova
wget -Nc https://download.linuxmuster.net/ova/v7/latest/lmn7-opnsense-${RELEASE}.ova.sha
shasum -c lmn7-opnsense-${RELEASE}.ova.sha
virt-convert lmn7-opnsense-${RELEASE}.ova
while [ $(virsh list --all | awk '$2 ~ /^lmn7-opnsense-/{print $3}') == "running" ] ; do
	virsh shutdown lmn7-opnsense-${RELEASE}.ovf
	echo "--- Warte ab, dass die Domain heruntergefahren ist..."
	sleep 5
	virsh destroy lmn7-opnsense-${RELEASE}.ovf
done
virsh domrename lmn7-opnsense-${RELEASE}.ovf lmn7-opnsense
SIZE=$( qemu-img info /var/lib/libvirt/images/lmn7-opnsense-${RELEASE}-disk001.raw | awk '/^virtual size: /{print $5}'|tr -d \( )
lvcreate --yes --size ${SIZE}b --name opnsense host-vg
qemu-img convert -O raw /var/lib/libvirt/images/lmn7-opnsense-${RELEASE}-disk001.raw /dev/host-vg/opnsense
rm -v /var/lib/libvirt/images/lmn7-opnsense-${RELEASE}-disk001.raw
TEMPSCRIPT=`tempfile`
TEMPFILE=`tempfile`
cat > $TEMPSCRIPT <<EOF
#!/bin/sh -e
cat \$1 |
	#<disk type='block' device='disk'>
xmlstarlet ed -d '//domain/devices/disk[1]/@type' |
xmlstarlet ed -i '//domain/devices/disk[1]' -t attr -n type -v block |
		#<source dev='/dev/host-vg/opnsense'/>
xmlstarlet ed -d '//domain/devices/disk[1]/source/@file' |
xmlstarlet ed -i '//domain/devices/disk[1]/source' -t attr -n dev -v /dev/host-vg/opnsense |
		#<target dev='vda' bus='virtio'/>
xmlstarlet ed -d '//domain/devices/disk[1]/target/@dev' |
xmlstarlet ed -i '//domain/devices/disk[1]/target' -t attr -n dev -v vda |
xmlstarlet ed -d '//domain/devices/disk[1]/target/@bus' |
xmlstarlet ed -i '//domain/devices/disk[1]/target' -t attr -n bus -v virtio |
		#<address .../> <-- löschen
xmlstarlet ed -d '//domain/devices/disk[1]/address' |
	#<interface type='bridge'>
xmlstarlet ed -d '//domain/devices/interface[1]/@type' |
xmlstarlet ed -i '//domain/devices/interface[1]' -t attr -n type -v bridge |
		#<source bridge='br-server'/>
xmlstarlet ed -d '//domain/devices/interface[1]/source/@network' |
xmlstarlet ed -d '//domain/devices/interface[1]/source/@bridge' |
xmlstarlet ed -i '//domain/devices/interface[1]/source' -t attr -n bridge -v br-server |
	#<interface type='bridge'>
xmlstarlet ed -d '//domain/devices/interface[2]/@type' |
xmlstarlet ed -i '//domain/devices/interface[2]' -t attr -n type -v bridge |
		#<source bridge='br-red'/>
xmlstarlet ed -d '//domain/devices/interface[2]/source/@network' |
xmlstarlet ed -d '//domain/devices/interface[2]/source/@bridge' |
xmlstarlet ed -i '//domain/devices/interface[2]/source' -t attr -n bridge -v br-red |
	#<interface type='bridge'>
xmlstarlet ed -d '//domain/devices/interface[3]/@type' |
xmlstarlet ed -i '//domain/devices/interface[3]' -t attr -n type -v bridge |
		#<source bridge='br-dmz'/>
xmlstarlet ed -d '//domain/devices/interface[3]/source/@network' |
xmlstarlet ed -d '//domain/devices/interface[3]/source/@bridge' |
xmlstarlet ed -i '//domain/devices/interface[3]/source' -t attr -n bridge -v br-dmz |
cat > $TEMPFILE
mv $TEMPFILE \$1
EOF
chmod +x $TEMPSCRIPT
EDITOR=$TEMPSCRIPT virsh edit lmn7-opnsense
virsh autostart lmn7-opnsense
virsh start lmn7-opnsense
sleep 1
./opnsense.expect
sshpass -p'Muster!' -v ssh-copy-id -o StrictHostKeyChecking=no 10.0.0.254
___comment_and_ask "Erzeugen des Linuxmuster-Server"
wget -Nc https://download.linuxmuster.net/ova/v7/latest/lmn7-server-${RELEASE}.ova
wget -Nc https://download.linuxmuster.net/ova/v7/latest/lmn7-server-${RELEASE}.ova.sha
shasum -c lmn7-server-${RELEASE}.ova.sha
virt-convert lmn7-server-${RELEASE}.ova
virsh shutdown lmn7-server-${RELEASE}.ovf
while [ $(virsh list --all | awk '$2 ~ /^lmn7-server-/{print $3}') == "running" ] ; do
	virsh shutdown lmn7-server-${RELEASE}.ovf
	echo "--- Warte ab, dass die Domain heruntergefahren ist..."
	sleep 5
	virsh destroy lmn7-server-${RELEASE}.ovf
done
virsh domrename lmn7-server-${RELEASE}.ovf lmn7-server
SIZE=$( qemu-img info /var/lib/libvirt/images/lmn7-server-${RELEASE}-disk001.raw | awk '/^virtual size: /{print $5}'|tr -d \( )
lvcreate --yes --size ${SIZE}b --name serverroot host-vg
qemu-img convert -O raw /var/lib/libvirt/images/lmn7-server-${RELEASE}-disk001.raw /dev/host-vg/serverroot
rm -v /var/lib/libvirt/images/lmn7-server-${RELEASE}-disk001.raw
SIZE=$( qemu-img info /var/lib/libvirt/images/lmn7-server-${RELEASE}-disk002.raw | awk '/^virtual size: /{print $5}'|tr -d \( )
lvcreate --yes --size ${SIZE}b --name serverdata host-vg
qemu-img convert -O raw /var/lib/libvirt/images/lmn7-server-${RELEASE}-disk002.raw /dev/host-vg/serverdata
rm -v /var/lib/libvirt/images/lmn7-server-${RELEASE}-disk002.raw
TEMPSCRIPT=`tempfile`
TEMPFILE=`tempfile`
cat > $TEMPSCRIPT <<EOF
#!/bin/sh -e
cat \$1 |
	#<disk type='block' device='disk'>
xmlstarlet ed -d '//domain/devices/disk[1]/@type' |
xmlstarlet ed -i '//domain/devices/disk[1]' -t attr -n type -v block |
	#<source dev='/dev/host-vg/serverroot'/>
xmlstarlet ed -d '//domain/devices/disk[1]/source/@file' |
xmlstarlet ed -i '//domain/devices/disk[1]/source' -t attr -n dev -v /dev/host-vg/serverroot |
	#<target dev='vda' bus='virtio'/>
xmlstarlet ed -d '//domain/devices/disk[1]/target/@dev' |
xmlstarlet ed -i '//domain/devices/disk[1]/target' -t attr -n dev -v vda |
xmlstarlet ed -d '//domain/devices/disk[1]/target/@bus' |
xmlstarlet ed -i '//domain/devices/disk[1]/target' -t attr -n bus -v virtio |
	#<address .../> <-- löschen
xmlstarlet ed -d '//domain/devices/disk[1]/address' |
	#<disk type='block' device='disk'>
xmlstarlet ed -d '//domain/devices/disk[2]/@type' |
xmlstarlet ed -i '//domain/devices/disk[2]' -t attr -n type -v block |
	#<source dev='/dev/host-vg/serverdata'/>
xmlstarlet ed -d '//domain/devices/disk[2]/source/@file' |
xmlstarlet ed -i '//domain/devices/disk[2]/source' -t attr -n dev -v /dev/host-vg/serverdata |
	#<target dev='vdb' bus='virtio'/>
xmlstarlet ed -d '//domain/devices/disk[2]/target/@dev' |
xmlstarlet ed -i '//domain/devices/disk[2]/target' -t attr -n dev -v vdb |
xmlstarlet ed -d '//domain/devices/disk[2]/target/@bus' |
xmlstarlet ed -i '//domain/devices/disk[2]/target' -t attr -n bus -v virtio |
	#<address .../> <-- löschen
xmlstarlet ed -d '//domain/devices/disk[2]/address' |
	#<interface type='bridge'>
xmlstarlet ed -d '//domain/devices/interface[1]/@type' |
xmlstarlet ed -i '//domain/devices/interface[1]' -t attr -n type -v bridge |
	#<source bridge='br-server'/>
xmlstarlet ed -d '//domain/devices/interface[1]/source/@network' |
xmlstarlet ed -d '//domain/devices/interface[1]/source/@bridge' |
xmlstarlet ed -i '//domain/devices/interface[1]/source' -t attr -n bridge -v br-server |
cat > $TEMPFILE
mv $TEMPFILE \$1
EOF
chmod +x $TEMPSCRIPT
EDITOR=$TEMPSCRIPT virsh edit lmn7-server
virsh autostart lmn7-server
virsh start lmn7-server
sleep 1
./server.expect "$LDAP_PLANET" "$LDAP_COUNTRY" "$LDAP_STATE" "$LDAP_LOCATION" "$LDAP_SCHOOLNAME" "$LDAP_DOMAIN"
sshpass -p'Muster!' -v ssh-copy-id -o StrictHostKeyChecking=no 10.0.0.1
___comment_and_ask "Server polieren."
ssh 10.0.0.1 "sed -i 's/location =.*/location = $LDAP_LOCATION/' /var/lib/linuxmuster/setup.ini"
ssh 10.0.0.1 "sed -i 's/state =.*/state = $LDAP_STATE/' /var/lib/linuxmuster/setup.ini"
# TODO disable motd & motd-like profile
ssh 10.0.0.1 "cat > ~/.vimrc" <<EOF
set mouse=
set nocompatible
set nowarn
set nobackup
set nojoinspaces
set hlsearch
set nu
EOF
ssh 10.0.0.1 "cat > ~/.bashrc" <<EOF
unset LS_COLORS
unalias -a
alias l=ls\ -l
alias ll=ls\ -la
. /etc/bash_completion
EOF
___comment_and_ask "Client Installation beginnen."
if [ -f lmn-bionic-$CLOOP_VERSION.zip ] ; then
	scp lmn-bionic-$CLOOP_VERSION.zip 10.0.0.1:
	ssh 10.0.0.1 "unzip -o lmn-bionic-$CLOOP_VERSION.zip"
	ssh 10.0.0.1 "rm -vf lmn-bionic-$CLOOP_VERSION/*.macct"
	ssh 10.0.0.1 "mv -v lmn-bionic-$CLOOP_VERSION/lmn-bionic.cloop* /srv/linbo/."
	ssh 10.0.0.1 "mv -v lmn-bionic-$CLOOP_VERSION/linuxmuster-client /srv/linbo/."
	ssh 10.0.0.1 "mv -v lmn-bionic-$CLOOP_VERSION/start.conf.bionic /srv/linbo/."
	ssh 10.0.0.1 "chmod 0644 /srv/linbo/lmn-bionic.cloop*"
else
	echo Das Image fehlt, es kann hier heruntergeladen werden:
	echo wget -Nc https://web.semgym-karlsruhe.de/owncloud/index.php/s/GsQy9PfDWWiSGCT/download -O lmn-bionic-$CLOOP_VERSION.zip
	exit 2
	ssh 10.0.0.1 linuxmuster-client download -c bionic
fi
# Beispielrechner eintragen mit IP .99 (ausserhalb der dynamischen Range .100-200)
ssh 10.0.0.1 "echo 'binaerwerkstatt;bw-nb01;bionic;$CLIENT_MAC;10.0.0.99;;;;classroom-studentcomputer;;1;;;;;' >> /etc/linuxmuster/sophomorix/default-school/devices.csv"
ssh 10.0.0.1 "linuxmuster-import-devices"
ssh 10.0.0.1 "sed -i 's/Server *=.*/Server = 10.0.0.1/' /srv/linbo/start.conf.bionic"
ssh 10.0.0.1 "cat > /srv/linbo/linuxmuster-client/bionic/common/etc/hosts" << EOF
# generated by walkthrough
127.0.0.1 localhost
#HOSTIP #HOSTNAME.$LDAP_DOMAIN.lan #HOSTNAME.local #HOSTNAME
#SERVERIP server.$LDAP_DOMAIN.lan server server.local server.local
EOF
ssh 10.0.0.1 "mkdir -p /srv/linbo/linuxmuster-client/bionic/common/etc/cron.d"
ssh 10.0.0.1 "echo > /srv/linbo/linuxmuster-client/bionic/common/etc/cron.d/linuxmuster-client"
ssh 10.0.0.1 "cat > /srv/linbo/linuxmuster-client/bionic/common/root/.ssh/authorized_keys < .ssh/id_rsa.pub"
ssh 10.0.0.1 "cat >> /srv/linbo/linuxmuster-client/bionic/common/root/.ssh/authorized_keys" < .ssh/authorized_keys
ssh 10.0.0.1 "cat >> /srv/linbo/linuxmuster-client/bionic/common/root/.ssh/authorized_keys" < .ssh/id_rsa.pub
ssh 10.0.0.1 "mkdir -p /srv/linbo/linuxmuster-client/bionic/common/etc/profile.d"
ssh 10.0.0.1 "cat > /srv/linbo/linuxmuster-client/bionic/common/etc/profile.d/linuxmuster-proxy.sh" <<EOF
export no_proxy=127.0.0.0/8,10.0.0.0/8,192.168.0.0/16,172.16.0.0/12,localhost,.local,.$LDAP_DOMAIN.lan
export http_proxy=http://firewall.$LDAP_DOMAIN.lan:3128
export ftp_proxy=http://firewall.$LDAP_DOMAIN.lan:3128
export https_proxy=http://firewall.$LDAP_DOMAIN.lan:3128
EOF
ssh 10.0.0.1 "mkdir -p /srv/linbo/linuxmuster-client/bionic/common/etc/apt/apt.conf.d"
ssh 10.0.0.1 "cat > /srv/linbo/linuxmuster-client/bionic/common/etc/apt/apt.conf.d/90proxy" <<EOF
Acquire::http::proxy "http://global-admin:Muster!@firewall.fsmw.lan:3128/";
Acquire::https::proxy "http://global-admin:Muster!@firewall.fsmw.lan:3128/";
EOF
ssh 10.0.0.1 "mkdir -p /srv/linbo/linuxmuster-client/bionic/common/etc/ssh"
ssh 10.0.0.1 "cat > /srv/linbo/linuxmuster-client/bionic/common/etc/ssh/sshd_config" <<EOF
AcceptEnv LANG LC_*
ChallengeResponseAuthentication no
PermitRootLogin yes
PasswordAuthentication yes
PermitTunnel no
PrintMotd no
UsePAM yes
X11Forwarding no
EOF
ssh 10.0.0.1 "mkdir -p /srv/linbo/linuxmuster-client/bionic/common/etc/systemd"
ssh 10.0.0.1 "cat > /srv/linbo/linuxmuster-client/bionic/common/etc/systemd/timesyncd.conf" <<EOF
[Time]
NTP=10.0.0.254
EOF
if [ -f lmn-bionic.cloop.postsync ] ; then
	scp lmn-bionic.cloop.postsync 10.0.0.1:/srv/linbo/
	ssh 10.0.0.1 chmod +x /srv/linbo/lmn-bionic.cloop.postsync
fi
ssh 10.0.0.1 "/etc/init.d/linbo-bittorrent restart lmn-bionic.cloop force"
ssh 10.0.0.1 "sed -i 's/^KernelOptions *=.*/KernelOptions = dhcpretry=9 quiet splash modprobe.blacklist=radeon nomodeset i915.alpha_support=1/' /srv/linbo/start.conf.bionic"
ssh 10.0.0.1 "linuxmuster-import-devices"
# Pruefen ob Daten zur Migration vorliegen
if [ -f sophomorix-dump.tgz ] ; then
	___comment_and_ask "Migration"
	scp sophomorix-dump.tgz 10.0.0.1:
	ssh 10.0.0.1 tar xvf sophomorix-dump.tgz
	ssh 10.0.0.1 apt install -y sophomorix-vampire
	ssh 10.0.0.1 sophomorix-vampire --datadir /root/sophomorix-dump --analyze
	ssh 10.0.0.1 sophomorix-vampire --datadir /root/sophomorix-dump --create-class-script
	ssh 10.0.0.1 /root/sophomorix-vampire/sophomorix-vampire-classes.sh
	ssh 10.0.0.1 samba-tool domain passwordsettings set --complexity=off
	ssh 10.0.0.1 samba-tool domain passwordsettings set --min-pwd-length=2
	ssh 10.0.0.1 sophomorix-vampire --datadir /root/sophomorix-dump --create-add-file
	ssh 10.0.0.1 cp /root/sophomorix-vampire/sophomorix.add /var/lib/sophomorix/check-result/sophomorix.add
	ssh 10.0.0.1 sophomorix-add -i
	ssh 10.0.0.1 sophomorix-add
	ssh 10.0.0.1 sophomorix-vampire --datadir /root/sophomorix-dump --import-user-password-hashes
	ssh 10.0.0.1 samba-tool domain passwordsettings set --complexity=default
	ssh 10.0.0.1 samba-tool domain passwordsettings set --min-pwd-length=default
	ssh 10.0.0.1 sophomorix-vampire --datadir /root/sophomorix-dump --create-class-adminadd-script
	ssh 10.0.0.1 /root/sophomorix-vampire/sophomorix-vampire-classes-adminadd.sh
	ssh 10.0.0.1 sophomorix-vampire --datadir /root/sophomorix-dump --create-project-script
	ssh 10.0.0.1 /root/sophomorix-vampire/sophomorix-vampire-projects.sh
	ssh 10.0.0.1 sophomorix-vampire --datadir /root/sophomorix-dump --restore-config-files
	ssh 10.0.0.1 sophomorix-vampire --datadir /root/sophomorix-dump --restore-config-files
	ssh 10.0.0.1 sed -i 's/ENCODING=.*/ENCODING=UTF-8/' /etc/linuxmuster/sophomorix/default-school/school.conf
	ssh 10.0.0.1 sed -i 's/ENCODING_FORCE=.*/ENCODING_FORCE=True/' /etc/linuxmuster/sophomorix/default-school/school.conf
	ssh 10.0.0.1 sophomorix-check
	ssh 10.0.0.1 sophomorix-add -i
	ssh 10.0.0.1 sophomorix-update
	ssh 10.0.0.1 sophomorix-kill
	ssh 10.0.0.1 linuxmuster-import-devices
	if [ -d /mnt/home ] ; then
		rsync --archive --verbose 10.16.1.1:/home 10.0.0.1:/mnt # TODO: data migration
		ssh 10.0.0.1 sophomorix-vampire --rsync-all-student-homes --path-oldserver /mnt/home/students/
		ssh 10.0.0.1 sophomorix-vampire --rsync-all-teacher-homes --path-oldserver /mnt/home/teachers/
		ssh 10.0.0.1 sophomorix-vampire --rsync-all-class-shares --path-oldserver /mnt/home/share/classes/
		ssh 10.0.0.1 sophomorix-vampire --rsync-all-project-shares --path-oldserver /mnt/home/share/projects/
		ssh 10.0.0.1 sophomorix-vampire --rsync-linbo --path-oldserver /mnt/var/linbo/
	fi
else
	echo Für die Migration alter Daten auf der alten Installation folgende
	echo Befehle abfeuern:
	echo sophomorix-dump
	echo tar cvzf sophomorix-dump.tgz sophomorix-dump
	echo und das entstandene tgz-Archiv auf den Server kopieren, wo dieses Script läuft
fi
___comment_and_ask "Client aufsetzen."
N=n
ssh 10.0.0.1 "wakeonlan $CLIENT_MAC"
while ! ssh 10.0.0.1 "echo -n | nc -q 1 10.0.0.99 2222 > /dev/null"; do sleep 1; done
for N in partition format label initcache:rsync sync:1 ; do
	echo "--- LINBO I: $N"
	ssh 10.0.0.1 "ssh -p 2222 -o BatchMode=yes -o StrictHostKeyChecking=no 10.0.0.99 /usr/bin/linbo_wrapper $N"
done
ssh 10.0.0.1 "ssh -p 2222 -o BatchMode=yes -o StrictHostKeyChecking=no 10.0.0.99 /usr/bin/linbo_wrapper start:1" &
while ! ssh 10.0.0.1 "echo -n | nc -q 1 10.0.0.99 22 > /dev/null"; do sleep 1; done
echo "--- Einrichten des Clients"
SERVER_TIME=$(ssh 10.0.0.1 "TZ=UTC date -Im")
ssh 10.0.0.1 "ssh -o StrictHostKeyChecking=no 10.0.0.99 TZ=UTC date -s $SERVER_TIME"
ssh 10.0.0.1 "ssh 10.0.0.99 rm /etc/krb5.keytab"
cat kinit.sh | ssh 10.0.0.1 "ssh 10.0.0.99 cat \> /usr/local/bin/kinit"
ssh 10.0.0.1 "ssh 10.0.0.99 chmod 0755 /usr/local/bin/kinit"
# see https://github.com/linuxmuster/linuxmuster-client-adsso/wiki
ssh 10.0.0.1 "ssh 10.0.0.99 linuxmuster-client-adsso-setup"
ssh 10.0.0.1 "ssh 10.0.0.99 rm -f /usr/local/bin/kinit"
ssh 10.0.0.1 "ssh 10.0.0.99 reboot" || true
while ! ssh 10.0.0.1 "echo -n | nc -q 1 10.0.0.99 2222 > /dev/null"; do sleep 1; done
for N in create_cloop:1 create_rsync:1 upload_cloop:1 upload_rsync:1 sync:1 ; do
	echo "--- LINBO II: $N"
	ssh 10.0.0.1 "rsync -e linbo-ssh --port=2222 /etc/rsyncd.secrets 10.0.0.99:/tmp"
	ssh 10.0.0.1 "ssh -p 2222 -o BatchMode=yes -o StrictHostKeyChecking=no 10.0.0.99 /usr/bin/linbo_wrapper $N"
done
ssh 10.0.0.1 "ssh -p 2222 -o BatchMode=yes -o StrictHostKeyChecking=no 10.0.0.99 /usr/bin/linbo_wrapper start:1" &
while ! ssh 10.0.0.1 "echo -n | nc -q 1 10.0.0.99 22 > /dev/null"; do sleep 1; done
for user in linuxadmin linuxuser; do
	ssh 10.0.0.1 ssh 10.0.0.99 sed -i \
			's/"browser.startup.homepage", "[^"]*/"browser.startup.homepage", "server.$LDAP_DOMAIN.lan/' \
			/home/$user/.mozilla/firefox/*.default/prefs.js
	ssh 10.0.0.1 ssh 10.0.0.99 sed -i \
			's/"network.proxy.no_proxies_on", "[^"]*/"network.proxy.no_proxies_on", "10.0.0.1, .$LDAP_DOMAIN.lan, server, firewall"' \
			/home/$user/.mozilla/firefox/*.default/prefs.js \
done
ssh 10.0.0.1 ssh 10.0.0.99 apt update
for p in greenfoot openjdk-8-jre\* openjdk-11-jre\* libxt-dev libxdmcp-dev libxcb1-dev libxau-dev libx11-dev libsm-dev libpthread-stubs0-dev libgcc-5-dev libgcc-7-dev libc-dev-bin libice-dev libltdl-dev mc account-plugin-\* aspell aspell-en baobab binutils binutils-common binutils-x86-64-linux-gnu snapd flatpak gnome-software-plugin-flatpak libostree-1-1 xdg-desktop-portal xdg-desktop-portal-gtk snapd-login-service; do
	ssh 10.0.0.1 ssh 10.0.0.99 "apt purge $p"
done
ssh 10.0.0.1 ssh 10.0.0.99 apt autoremove --purge
___comment_and_ask "Installation beended."
exit 0
