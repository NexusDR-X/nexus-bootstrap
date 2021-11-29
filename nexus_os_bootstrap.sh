#!/usr/bin/env bash
# version 1.0.2
# Author: Steve Magnuson, AG7GN
#
# This script prepares the stock "Raspberry Pi OS with desktop" Bullseye image from 
# https://www.raspberrypi.org/software/operating-systems/ for use with the 
# Nexus DR-X hat and Fe-Pi audio hat.
#
# After installing the "Raspberry Pi OS with desktop" image, make sure the Pi has
# access to the Internet, then open Terminal and run this command:
#

GIT_URL="https://github.com"
LOCAL_GIT_REPO_DIR="/usr/local/src/nexus"
NEXUS_AUDIO_GIT_URL="${GIT_URL}/NexusDR-X/nexus-audio.git"
NEXUS_BOOTSTRAP_GIT_URL="${GIT_URL}/NexusDR-X/nexus-bootstrap.git"

#function bootAndRunAgain () {
#	if [[ -s $AUTOSTART ]] 
#	then
#		sudo sed -i "/@pcmanfm .*/a @lxterminal -e 'bash <(curl -sL https:\/\/raw.githubusercontent.com\/node-red\/linux-installers\/master\/deb\/update-nodejs-and-nodered)'" $AUTOSTART
#	fi
#	shutdown -r now
#}

function CheckInternet() {
	# Check for Internet connectivity
	if ! ping -q -w 1 -c 1 github.com &>/dev/null
	then
		echo >&2 "No internet connection detected. Connect this Pi to the Internet and run this script again." 
		exit 1
	fi
}

#SCRIPT="$(basename $0)"
#AUTOSTART="/etc/xdg/lxsession/LXDE-pi/autostart"
#if [[ -s $AUTOSTART ]] 
#then
#	# Remove any existing reference to this script from $AUTOSTART
#	sudo sed -i "/@lxterminal .*$SCRIPT/d" $AUTOSTART
#fi

#######################################################################
## Expand the filesystem if it is < 10 GB 
#PARTSIZE=$( df | sed -n '/root/{s/  */ /gp}' | cut -d ' ' -f2 )
#THRESHOLD=$((10 * 1024 * 1024))
#if (( $PARTSIZE < $THRESHOLD ))
#then
#	echo >&2 "Expanding root filesystem..."
#	sudo raspi-config --expand-rootfs
#	echo >&2 "Done. Rebooting. This script will autostart and continue setup after bootup."
#	sleep 5
#	bootAndRunAgain
#fi

#######################################################################
## Change password
#echo >&2 "Changing password to 'changeme'..."
#echo 'pi:changeme' | sudo chpasswd
#echo >&2 "Done."

#######################################################################
## Determine OS
eval $(cat /etc/*-release)
[[ ${VERSION_CODENAME^^} != "BUSTER" ]] && \
	{ echo >&2 "This script will only with RaspiOS \"Buster\" OS"; exit 1; }
OS_BITS=$(getconf LONG_BIT)
echo >&2 "------>  Found Buster ${OS_BITS}-bit Operating System"

#######################################################################
## Enable source packages
echo >&2 "------>  Enabling sources..."
for F in /etc/apt/sources.list /etc/apt/sources.list.d/raspi.list
do
	sudo sed -i -e 's/^#deb-src/deb-src/' $F
done
echo >&2 -e "------>  Done.\n______"

#######################################################################
## Enable Interfaces
for I in do_i2c do_serial do_ssh do_vnc
do
	echo >&2 "------>  Enabling ${I##*_}..."
	sudo raspi-config nonint $I 0
	echo >&2 -e "------>  Done.\n______"
done

#######################################################################
## Change terminal Settings
echo >&2 "------>  Configuring lxterminal settings..."
CONFIG="$HOME/.config/lxterminal/lxterminal.conf"
FONT="Monospace 14"
SCROLLBACK=10000
GEOMETRY_COLUMNS=100
GEOMETRY_ROWS=30
sed -i -e "s/^fontname=.*/fontname=$FONT/" \
		-e "s/^scrollback=.*/scrollback=$SCROLLBACK/" \
		-e "s/^geometry_columns=.*/geometry_columns=$GEOMETRY_COLUMNS/" \
		-e "s/^geometry_rows=.*/geometry_rows=$GEOMETRY_ROWS/" "$CONFIG"
echo >&2 -e "------>  Done.\n______"

#######################################################################
## Disable NFS Clients
echo >&2 -e "------>  Disabling nfs-client..."
sudo systemctl disable nfs-client.target
echo >&2 -e "------>  Done.\n______"

#######################################################################
## Update installed packages
echo >&2 "------>  Updating installed packages..."
sudo apt-get -y clean
# Check Internet availability
CheckInternet
sudo apt-get update
sudo apt-get -y autoremove
sudo apt-get -y upgrade	
sudo apt-get -y dist-upgrade
echo >&2 -e "------>  Done.\n______"

#######################################################################
## Install additional packages
echo >&2 "------>  Installing additional packages..."
sudo apt-get -y install vim tcpdump lsof gpm telnet minicom links exfat-utils \
		yad dosfstools dos2unix xscreensaver autoconf automake libtool cmake \
		extra-xdg-menus bc dnsutils libgtk-3-bin jq xdotool moreutils build-essential \
		aptitude hdparm watchdog gettext
echo >&2 -e "------>  Done.\n______"

#######################################################################
## Firewall
echo >&2 "------>  Enable nftables firewall..."
sudo systemctl enable nftables.service
sudo systemctl start nftables.service
echo >&2 -e "------>  Done.\n______"
## Insert rule preventing multicast from egressing ax25 interfaces
echo >&2 -e "------>  Prevent multicast traffic out of ax interfaces..."
WHO="$USER"
WHEN="@reboot"
#WHAT="sudo /usr/sbin/nft add rule inet filter output oifname { ax0, ax1 } ip daddr { 224.0.0.22, 224.0.0.251, 239.255.255.250 } drop"
WHAT="sudo /usr/sbin/nft add rule inet filter output oifname { ax0, ax1 } pkttype { multicast } drop"
JOB="$WHEN $WHAT"
cat <(fgrep -i -v "$WHAT" <(sudo crontab -u $WHO -l)) <(echo "$JOB") | sudo crontab -u $WHO -
echo >&2 -e "------>  Done.\n______"

#######################################################################
## Move /tmp and /var/log to RAM
echo >&2 "------>  Moving /tmp and /var/log to RAM..."
if ! grep -q -e "^tmpfs.*/tmp" /etc/fstab
then
	echo -e "tmpfs\t/tmp\ttmpfs\tdefaults,noatime,mode=1777,size=50m\t0\t0" | sudo tee --append /etc/fstab 1>/dev/null
fi
if ! grep -q -e "^tmpfs.*/var/log" /etc/fstab
then
	echo -e "tmpfs\t/var/log\ttmpfs\tdefaults,noatime,mode=0755,size=50m\t0\t0" | sudo tee --append /etc/fstab 1>/dev/null
fi
echo >&2 -e "------>  Done.\n______"

#######################################################################
## Set default text editor (uncomment one of these)
echo >&2 "------>  Setting default command line editor..."
#sudo update-alternatives --set editor /usr/bin/nano
sudo update-alternatives --set editor /usr/bin/vim.basic
echo >&2 -e "------>  Done.\n______"

#######################################################################
## Enable hardware watchdog
echo >&2 "------>  Configuring and enabling hardware watchdog timer..."
sudo cp -f /etc/watchdog.conf /etc/watchdog.conf.original
sudo sed -i -e "s/^#max-load-1[ \t].*/max-load-1 = 24/" \
				-e "s/^#max-load-5[ \t].*/max-load-5 = 18/" \
				-e "s/^#watchdog-device.*/watchdog-device = \/dev\/watchdog/" /etc/watchdog.conf
if ! grep -q "^watchdog-timeout" /etc/watchdog.conf
then
	echo "watchdog-timeout = 15" | sudo tee --append /etc/watchdog.conf 1>/dev/null
fi
sudo systemctl enable watchdog
sudo systemctl start watchdog.service
echo >&2 -e "------>  Done.\n______"

#######################################################################
## Backup /boot/config.txt
echo >&2 "------>  Backing up /boot/config.txt..."
sudo cp -f /boot/config.txt /boot/config.txt.original
echo >&2 -e "------>  Done.\n______"

#######################################################################
## Enable HDMI monitor attachment anytime
echo >&2 "------>  Allowing hotplug of HDMI monitor..."
sudo sed -i -e "s/^#hdmi_force_hotplug.*/hdmi_force_hotplug=1/" /boot/config.txt
echo >&2 -e "------>  Done.\n______"

#######################################################################
## Disable KMS driver so that VNC will work (too slow otherwise)
## See: https://forums.raspberrypi.com/viewtopic.php?t=323294
echo >&2 "------>  Disable DRM VC4 V3D KMS driver so VNC will work..."
sudo sed -i -e "s/^dtoverlay=vc4-kms-v3d.*/#dtoverlay=vc4-kms-v3d/" /boot/config.txt
echo >&2 -e "------>  Done.\n______"

#######################################################################
## Real Time Clock
echo >&2 "------>  Enabling Real Time Clock module..."
if ! grep -q "^dtoverlay=i2c-rtc,ds3231" /boot/config.txt
then
	echo -e "# Enable ds3231 Real Time Clock (RTC)\ndtoverlay=i2c-rtc,ds3231"  | sudo tee --append /boot/config.txt 1>/dev/null
fi
echo >&2 -e "------>  Done.\n______"

#######################################################################
## Disable the special key keyboard mapping tool
echo >&2 "------>  Disabling special key keyboard mapping tool service..."
sudo update-rc.d -f triggerhappy remove
sudo systemctl disable triggerhappy.service
sudo systemctl disable triggerhappy.socket
echo >&2 -e "------>  Done.\n______"

#######################################################################
## Prepare local git repository folder
echo >&2 "------>  Prepare local git repository folder..."
sudo mkdir -p "$LOCAL_GIT_REPO_DIR"
sudo  chown $USER:$USER "$LOCAL_GIT_REPO_DIR"
echo >&2 -e "------>  Done.\n______"

#######################################################################
## Fe-Pi Audio Card and PulseAudio setup
echo >&2 "------>  Enabling Fe-Pi Audio Hat..."
if ! grep -q "^dtoverlay=fe-pi-audio" /boot/config.txt
then
	echo -e "# Enable Fe-Pi audio card\ndtoverlay=fe-pi-audio"  | sudo tee --append /boot/config.txt 1>/dev/null
fi
echo >&2 -e "------>  Done.\n______"
echo >&2 "------>  Adding PulseAudio configuration for Fe-Pi Audio Hat..."
rm -rf "$LOCAL_GIT_REPO_DIR/nexus-audio"
git -C "$LOCAL_GIT_REPO_DIR" clone "$NEXUS_AUDIO_GIT_URL"
cd "$LOCAL_GIT_REPO_DIR"
nexus-audio/nexus-install
echo >&2 -e "------>  Done.\n______"

#######################################################################
## Get the nexus-bootstrap repo
echo >&2 "------>  Adding nexus-bootstrap repo..."
rm -rf "$LOCAL_GIT_REPO_DIR/nexus-bootstrap"
git -C "$LOCAL_GIT_REPO_DIR" clone "$NEXUS_BOOTSTRAP_GIT_URL"
echo >&2 -e "------>  Done.\n______"

#######################################################################
## Set up log management, shutdown button, desktop background, install 
## .vimrc
echo >&2 "------>  Set up log management, shutdown button, desktop background..."
nexus-bootstrap/nexus-install
echo >&2 -e "------>  Done.\n______"

#######################################################################
## Change hostname
echo >&2 "------>  Change hostname to nexusdr-x..."
sudo raspi-config nonint do_hostname "nexusdr-x"
echo >&2 -e "------>  Done.\n______"









