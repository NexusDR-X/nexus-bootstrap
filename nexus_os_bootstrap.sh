#!/usr/bin/env bash
# This script prepares the stock "Raspberry Pi OS with desktop" Bullseye image from 
# https://www.raspberrypi.org/software/operating-systems/ for use with the 
# Nexus DR-X hat and Fe-Pi audio hat.
#
# After installing the "Raspberry Pi OS with desktop" image, make sure the Pi has
# access to the Internet, then open Terminal and run this command:
#
#	bash <(curl -sL https:\/\/raw.githubusercontent.com\/node-red\/linux-installers\/master\/deb\/update-nodejs-and-nodered
#
#
#
#

function bootAndRunAgain () {
	if [[ -s $AUTOSTART ]] 
	then
		sudo sed -i "/@pcmanfm .*/a @lxterminal -e 'bash <(curl -sL https:\/\/raw.githubusercontent.com\/node-red\/linux-installers\/master\/deb\/update-nodejs-and-nodered)'" $AUTOSTART
	fi
	shutdown -r now
}

function checkInternet() {
	# Check for Internet connectivity
	if ! ping -q -w 1 -c 1 github.com > /dev/null 2>&1
	then
		echo "No internet connection detected. Connect this Pi to the Internet and run this script again." >&
		exit 1
	fi
}

SCRIPT="$(basename $0)"
AUTOSTART="/etc/xdg/lxsession/LXDE-pi/autostart"
if [[ -s $AUTOSTART ]] 
then
	# Remove any existing reference to this script from $AUTOSTART
	sudo sed -i "/@lxterminal .*$SCRIPT/d" $AUTOSTART
fi

#######################################################################
# Expand the filesystem if it is < 10 GB 
PARTSIZE=$( df | sed -n '/root/{s/  */ /gp}' | cut -d ' ' -f2 )
THRESHOLD=$((10 * 1024 * 1024))
if (( $PARTSIZE < $THRESHOLD ))
then
	echo >&2 "Expanding root filesystem..."
	sudo raspi-config --expand-rootfs
	echo >&2 "Done. Rebooting. This script will autostart and continue setup after bootup."
	sleep 5
	bootAndRunAgain
fi

#######################################################################
# Change password
echo >&2 "Changing password to 'changeme'..."
echo 'pi:changeme' | sudo chpasswd
echo >&2 "Done."

#######################################################################
# Enable source packages
echo >&2 "Enabling sources..."
for F in /etc/apt/sources.list /etc/apt/sources.list.d/raspi.list
do
	sudo sed -i -e 's/^#deb-src/deb-src/' $F
done
echo >&2 "Done."

#######################################################################
# Enable Interfaces
for I in do_i2c do_serial do_ssh do_vnc
do
	echo >&2 "Enabling ${I##*_}..."
	sudo raspi-config nonint $I 0
	echo >&2 "Done."
done

#######################################################################
# Change terminal Settings
echo >&2 "Configuring lxterminal settings..."
CONFIG="$HOME/.config/lxterminal/lxterminal.conf"
FONT="Monospace 14"
SCROLLBACK=10000
GEOMETRY_COLUMNS=100
GEOMETRY_ROWS=30
sed -i -e "s/^fontname=.*/fontname=$FONT/" \
		-e "s/^scrollback=.*/scrollback=$SCROLLBACK/" \
		-e "s/^geometry_columns=$GEOMETRY_COLUMNS/" \
		-e "s/^geometry_rows=$GEOMETRY_ROWS/" "$CONFIG"
echo >&2 "Done."

#######################################################################
# Disable NFS Clients
echo >&2 "Disabling nfs-client..."
sudo systemctl disable nfs-client.target
echo >&2 "Done."

#######################################################################
# Update installed packages
echo >&2 "Updating installed packages..."
sudo apt-get -y clean
# Check Internet availability
checkInternet
sudo apt-get update
sudo apt-get -y autoremove
sudo apt-get -y upgrade	
sudo apt-get -y dist-upgrade
echo >&2 "Done."

#######################################################################
# Install additional packages
echo >&2 "Installing additional packages..."
sudo apt-get -y install vim tcpdump lsof gpm telnet minicom links exfat-utils \
		yad dosfstools xscreensaver build-essential autoconf automake libtool cmake \
		extra-xdg-menus bc dnsutils libgtk-3-bin jq xdotool moreutils build-essential \
		aptitude hdparm 
echo >&2 "Done."

#######################################################################
# Firewall
#echo >&2 "Installing iptables-persistent..."
#sudo apt-get install iptables-persistent
#echo >&2 "Done."

#######################################################################
# Move /tmp and /var/log to RAM
echo >&2 "Moving /tmp and /var/log to RAM..."
if ! grep -q -e "^tmpfs.*/tmp" /etc/fstab
then
	echo -e "tmpfs\t/tmp\ttmpfs\tdefaults,noatime,mode=1777,size=50m\t0\t0" | sudo tee --append /etc/fstab 1>/dev/null
fi
if ! grep -q -e "^tmpfs.*/var/log" /etc/fstab
then
	echo -e "tmpfs\t/var/log\ttmpfs\tdefaults,noatime,mode=0755,size=50m\t0\t0" | sudo tee --append /etc/fstab 1>/dev/null
fi
echo >&2 "Done."


#######################################################################
# Set default text editor (uncomment one of these)
echo >&2 "Setting default command line editor..."
#sudo update-alternatives --set editor /usr/bin/nano
sudo update-alternatives --set editor /usr/bin/vim.basic
echo >&2 "Done."

#######################################################################
# Enable hardware watchdog
echo >&2 "Configuring and enabling hardware watchdog timer..."
sudo apt-get -y install watchdog
sudo sed -i -e "s/^#max-load-1.*/max-load-1 = 24/" \
				-e "s/^#max-load-5.*/max-load-5 = 18" \
				-e "s/^#watchdog-device.*/watchdog-device = \/dev\/watchdog/" /etc/watchdog.conf
if ! grep -q "^watchdog-timeout"
then
	echo "watchdog-timeout = 15" | sudo tee --append /etc/watchdog.conf 1>/dev/null
fi
sudo systemctl enable watchdog
sudo systemctl start watchdog.service
echo >&2 "Done."

#######################################################################
# Enable HDMI monitor attachment anytime
echo >&2 "Allowing hotplug of HDMI monitor..."
sudo sed -i -e "s/^#hdmi_force_hotplug.*/hdmi_force_hotplug=1/" /boot/config.txt
echo >&2 "Done."

#######################################################################
# Disable KMS driver so that VNC will work (too slow otehrwise)
# See: https://forums.raspberrypi.com/viewtopic.php?t=323294
echo >&2 "Disable DRM VC4 V3D KMS driver so VNC will work..."
sudo sed -i -e "s/^dtoverlay=vc4-kms-v3d$/dtoverlay=vc4-kms-v3d/" /boot/config.txt
echo >&2 "Done."

#######################################################################
# Real Time Clock
echo >&2 "Enabling Real Time Clock module..."
if ! grep -q "^dtoverlay=i2c-rtc,ds3231" /boot/config.txt
then
	echo -e "# Enable ds3231 Real Time Clock (RTC)\ndtoverlay=i2c-rtc,ds3231"  | sudo tee --append /boot/config.txt 1>/dev/null
fi
echo >&2 "Done."

#######################################################################
# Fe-Pi Audio Card
echo >&2 "Enabling Fe-Pi Audio Hat..."
if ! grep -q "^dtoverlay=fe-pi-audio" /boot/config.txt
then
	echo -e "# Enable Fe-Pi audio card\ndtoverlay=fe-pi-audio"  | sudo tee --append /boot/config.txt 1>/dev/null
fi
echo >&2 "Done."

#######################################################################
# Modify Log Management
echo >&2 "Modifying syslog configuration..."
sed -n "/#### RULES ####/q;p" /etc/rsyslog.conf > /tmp/rsyslog.conf
cat >> /tmp/rsyslog.conf <<EOF
#### RULES ####
###############

#
# First some standard log files.  Log by facility.
#
auth,authpriv.*			/var/log/auth.log
*.*;auth,authpriv,mail.none	-/var/log/syslog
#cron.*				/var/log/cron.log
daemon.*			-/var/log/daemon.log
kern.*				-/var/log/kern.log
kern.debug			stop
lpr.*				-/var/log/lpr.log
mail.*				-/var/log/mail.log
user.*				-/var/log/user.log

#
# Logging for the mail system.  Split it up so that
# it is easy to write scripts to parse these files.
#
mail.warn			/var/log/mail.err

#
# Some "catch-all" log files.
#
*.=info;*.=notice;*.=warn;\
	auth,authpriv.none;\
	cron,daemon.none;\
	mail,news.none		-/var/log/messages

#
# Emergencies are sent to everybody logged in.
#
*.emerg				:omusrmsg:*
EOF
sudo cp -f /etc/rsyslog.conf /etc/rsyslog.conf.original
sudo cp -f /tmp/rsyslog.conf /etc/rsyslog.conf
sudo rm -f /var/log/debug*
sudo cp -f /etc/logrotate.conf /etc/logrotate.conf.original
sudo sed -i -e "s/^#compress.*/compress/" /etc/logrotate.conf
sudo sed -i "/^compress/a compresscmd \/bin\/bzip2\nuncompresscmd \/bin\/bunzip2\ncompressoptions -9\ncompressext .bz2" /etc/logrotate.conf

cat > /tmp/rsyslog.pre <<EOF
rotate 3
daily
missingok
notifempty
compress
compresscmd /bin/bzip2
uncompresscmd /bin/bunzip2
compressoptions -9
compressext .bz2

EOF
cat /tmp/rsyslog.pre /etc/logrotate.d/rsyslog > /tmp/rsyslog
sudo cp -f /tmp/rsyslog /etc/logrotate.d/rsyslog
sudo systemctl restart rsyslog
echo >&2 "Done."

#######################################################################
# Disable the special key keyboard mapping tool
echo >&2 "Disabling special key keyboard mapping tool service..."
sudo update-rc.d -f triggerhappy remove
sudo systemctl disable triggerhappy.service
sudo systemctl disable triggerhappy.socket
echo >&2 "Done."










