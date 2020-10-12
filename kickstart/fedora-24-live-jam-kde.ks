#fedora-livedvd-jam-xfe.ks
# With XFCE Desktop

# Fedora Jam: For Musicians and audio enthusiasts
# Fedora Jam is a spin for anyone interested in creating 
# music 

# Maintainer: Yann Collette <ycollette.nospam@free.fr>

lang fr_FR.UTF-8
keyboard fr-latin9
timezone Europe/Paris

auth --useshadow --passalgo=sha512
selinux --enforcing
firewall --enabled --service=mdns
xconfig --startxonboot
zerombr
clearpart --all
part / --size 8192 --fstype ext4
services --enabled=NetworkManager,ModemManager --disabled=network,sshd
network --bootproto=dhcp --device=link --activate
shutdown

#enable threaded irqs
bootloader --append="threadirqs"

# add CCRMA and rpmfusion repos
repo --name=ccrma --baseurl=http://ccrma.stanford.edu/planetccrma/mirror/fedora/linux/planetccrma/$releasever/$basearch
repo --name=ccrma-core --baseurl=http://ccrma.stanford.edu/planetccrma/mirror/fedora/linux/planetcore/$releasever/$basearch

repo --name=rpmfusion --baseurl=http://download1.rpmfusion.org/free/fedora/releases/$releasever/Everything/$basearch/os/
repo --name=rpmfusion-non-free --baseurl=http://download1.rpmfusion.org/nonfree/fedora/releases/$releasever/Everything/$basearch/os/
repo --name=rpmfusion-update-testing --baseurl=http://download1.rpmfusion.org/free/fedora/updates/testing/$releasever/$basearch/
repo --name=rpmfusion-free-update --baseurl=http://download1.rpmfusion.org/free/fedora/updates/$releasever/$basearch/

repo --name=fedora --mirrorlist=http://mirrors.fedoraproject.org/mirrorlist?repo=fedora-$releasever&arch=$basearch
repo --name=updates --mirrorlist=http://mirrors.fedoraproject.org/mirrorlist?repo=updates-released-f$releasever&arch=$basearch

repo --name="CoprLinuxMAO" --baseurl=https://copr-be.cloud.fedoraproject.org/results/ycollet/linuxmao/fedora-$releasever-$basearch/

%packages
@base-x
@guest-desktop-agents
@standard
@core
@fonts
@input-methods
@multimedia
@hardware-support

# exclude input methods:
-m17n*
-scim*
-ibus*
-iok

# Explicitly specified here:
# <notting> walters: because otherwise dependency loops cause yum issues.
kernel
kernel-rt

# This was added a while ago, I think it falls into the category of
# "Diagnosis/recovery tool useful from a Live OS image".  Leaving this untouched
# for now.
memtest86+

# Without this, initramfs generation during live image creation fails: #1242586
dracut-live

# Make live images easy to shutdown and the like in libvirt
qemu-guest-agent

%end

%post

# Install language pack
yum -y langinstall French

# FIXME: it'd be better to get this installed from a package
cat > /etc/rc.d/init.d/livesys << EOF
#!/bin/bash
#
# live: Init script for live image
#
# chkconfig: 345 00 99
# description: Init script for live image.
### BEGIN INIT INFO
# X-Start-Before: display-manager
### END INIT INFO

. /etc/init.d/functions

if ! strstr "\`cat /proc/cmdline\`" rd.live.image || [ "\$1" != "start" ]; then
    exit 0
fi

if [ -e /.liveimg-configured ] ; then
    configdone=1
fi

exists() {
    which \$1 >/dev/null 2>&1 || return
    \$*
}

# Make sure we don't mangle the hardware clock on shutdown
ln -sf /dev/null /etc/systemd/system/hwclock-save.service

livedir="LiveOS"
for arg in \`cat /proc/cmdline\` ; do
  if [ "\${arg##rd.live.dir=}" != "\${arg}" ]; then
    livedir=\${arg##rd.live.dir=}
    return
  fi
  if [ "\${arg##live_dir=}" != "\${arg}" ]; then
    livedir=\${arg##live_dir=}
    return
  fi
done

# enable swaps unless requested otherwise
swaps=\`blkid -t TYPE=swap -o device\`
if ! strstr "\`cat /proc/cmdline\`" noswap && [ -n "\$swaps" ] ; then
  for s in \$swaps ; do
    action "Enabling swap partition \$s" swapon \$s
  done
fi
if ! strstr "\`cat /proc/cmdline\`" noswap && [ -f /run/initramfs/live/\${livedir}/swap.img ] ; then
  action "Enabling swap file" swapon /run/initramfs/live/\${livedir}/swap.img
fi

mountPersistentHome() {
  # support label/uuid
  if [ "\${homedev##LABEL=}" != "\${homedev}" -o "\${homedev##UUID=}" != "\${homedev}" ]; then
    homedev=\`/sbin/blkid -o device -t "\$homedev"\`
  fi

  # if we're given a file rather than a blockdev, loopback it
  if [ "\${homedev##mtd}" != "\${homedev}" ]; then
    # mtd devs don't have a block device but get magic-mounted with -t jffs2
    mountopts="-t jffs2"
  elif [ ! -b "\$homedev" ]; then
    loopdev=\`losetup -f\`
    if [ "\${homedev##/run/initramfs/live}" != "\${homedev}" ]; then
      action "Remounting live store r/w" mount -o remount,rw /run/initramfs/live
    fi
    losetup \$loopdev \$homedev
    homedev=\$loopdev
  fi

  # if it's encrypted, we need to unlock it
  if [ "\$(/sbin/blkid -s TYPE -o value \$homedev 2>/dev/null)" = "crypto_LUKS" ]; then
    echo
    echo "Setting up encrypted /home device"
    plymouth ask-for-password --command="cryptsetup luksOpen \$homedev EncHome"
    homedev=/dev/mapper/EncHome
  fi

  # and finally do the mount
  mount \$mountopts \$homedev /home
  # if we have /home under what's passed for persistent home, then
  # we should make that the real /home.  useful for mtd device on olpc
  if [ -d /home/home ]; then mount --bind /home/home /home ; fi
  [ -x /sbin/restorecon ] && /sbin/restorecon /home
  if [ -d /home/lescuizines ]; then USERADDARGS="-M" ; fi
}

findPersistentHome() {
  for arg in \`cat /proc/cmdline\` ; do
    if [ "\${arg##persistenthome=}" != "\${arg}" ]; then
      homedev=\${arg##persistenthome=}
      return
    fi
  done
}

if strstr "\`cat /proc/cmdline\`" persistenthome= ; then
  findPersistentHome
elif [ -e /run/initramfs/live/\${livedir}/home.img ]; then
  homedev=/run/initramfs/live/\${livedir}/home.img
fi

# if we have a persistent /home, then we want to go ahead and mount it
if ! strstr "\`cat /proc/cmdline\`" nopersistenthome && [ -n "\$homedev" ] ; then
  action "Mounting persistent /home" mountPersistentHome
fi

if [ -n "\$configdone" ]; then
  exit 0
fi

# add fedora user with no passwd
action "Adding live user" useradd \$USERADDARGS -c "Live System User" lescuizines
passwd -d lescuizines > /dev/null
usermod -aG wheel lescuizines > /dev/null
usermod -aG jackuser lescuizines > /dev/null
usermod -aG root lescuizines > /dev/null

# Remove root password lock
passwd -d root > /dev/null

# turn off firstboot for livecd boots
systemctl --no-reload disable firstboot-text.service 2> /dev/null || :
systemctl --no-reload disable firstboot-graphical.service 2> /dev/null || :
systemctl stop firstboot-text.service 2> /dev/null || :
systemctl stop firstboot-graphical.service 2> /dev/null || :

# don't use prelink on a running live image
sed -i 's/PRELINKING=yes/PRELINKING=no/' /etc/sysconfig/prelink &>/dev/null || :

# turn off mdmonitor by default
systemctl --no-reload disable mdmonitor.service 2> /dev/null || :
systemctl --no-reload disable mdmonitor-takeover.service 2> /dev/null || :
systemctl stop mdmonitor.service 2> /dev/null || :
systemctl stop mdmonitor-takeover.service 2> /dev/null || :

# don't enable the gnome-settings-daemon packagekit plugin
gsettings set org.gnome.software download-updates 'false' || :

# don't start cron/at as they tend to spawn things which are
# disk intensive that are painful on a live image
systemctl --no-reload disable crond.service 2> /dev/null || :
systemctl --no-reload disable atd.service 2> /dev/null || :
systemctl stop crond.service 2> /dev/null || :
systemctl stop atd.service 2> /dev/null || :

# Don't sync the system clock when running live (RHBZ #1018162)
sed -i 's/rtcsync//' /etc/chrony.conf

# Mark things as configured
touch /.liveimg-configured

# add static hostname to work around xauth bug
# https://bugzilla.redhat.com/show_bug.cgi?id=679486
echo "localhost" > /etc/hostname

EOF

# bah, hal starts way too late
cat > /etc/rc.d/init.d/livesys-late << EOF
#!/bin/bash
#
# live: Late init script for live image
#
# chkconfig: 345 99 01
# description: Late init script for live image.

. /etc/init.d/functions

if ! strstr "\`cat /proc/cmdline\`" rd.live.image || [ "\$1" != "start" ] || [ -e /.liveimg-late-configured ] ; then
    exit 0
fi

exists() {
    which \$1 >/dev/null 2>&1 || return
    \$*
}

touch /.liveimg-late-configured

# read some variables out of /proc/cmdline
for o in \`cat /proc/cmdline\` ; do
    case \$o in
    ks=*)
        ks="--kickstart=\${o#ks=}"
        ;;
    xdriver=*)
        xdriver="\${o#xdriver=}"
        ;;
    esac
done

# if liveinst or textinst is given, start anaconda
if strstr "\`cat /proc/cmdline\`" liveinst ; then
   plymouth --quit
   /usr/sbin/liveinst \$ks
fi
if strstr "\`cat /proc/cmdline\`" textinst ; then
   plymouth --quit
   /usr/sbin/liveinst --text \$ks
fi

# configure X, allowing user to override xdriver
cat > /etc/X11/xorg.conf <<FOE
Section "InputDevice"
    Identifier "Keyboard0"
    Driver "kbd"
    Option "XkbLayout" "fr-latin9"
EndSection
FOE

if [ -n "\$xdriver" ]; then
   cat > /etc/X11/xorg.conf.d/00-xdriver.conf <<FOE
Section "Device"
	Identifier	"Videocard0"
	Driver	"\$xdriver"
EndSection
FOE
fi

EOF

chmod 755 /etc/rc.d/init.d/livesys
/sbin/restorecon /etc/rc.d/init.d/livesys
/sbin/chkconfig --add livesys

chmod 755 /etc/rc.d/init.d/livesys-late
/sbin/restorecon /etc/rc.d/init.d/livesys-late
/sbin/chkconfig --add livesys-late

# enable tmpfs for /tmp
systemctl enable tmp.mount

# As livecd-creator is still yum based, we only get yum's yumdb during the
# image compose. Migrate this over to dnf so that dnf and PackageKit can keep
# track where packages came from.
if [ ! -d /var/lib/dnf ]; then
  mkdir -p /var/lib/dnf
  mv /var/lib/yum/yumdb /var/lib/dnf/
  rm -rf /var/lib/yum/
fi

# make it so that we don't do writing to the overlay for things which
# are just tmpdirs/caches
# note https://bugzilla.redhat.com/show_bug.cgi?id=1135475
cat >> /etc/fstab << EOF
vartmp   /var/tmp    tmpfs   defaults   0  0
varcacheyum /var/cache/yum  tmpfs   mode=0755,context=system_u:object_r:rpm_var_cache_t:s0   0   0
EOF

# work around for poor key import UI in PackageKit
rm -f /var/lib/rpm/__db*
releasever=$(rpm -q --qf '%{version}\n' --whatprovides system-release)
basearch=$(uname -i)
rpm --import /etc/pki/rpm-gpg/RPM-GPG-KEY-fedora-$releasever-$basearch
echo "Packages within this LiveCD"
rpm -qa
# Note that running rpm recreates the rpm db files which aren't needed or wanted
rm -f /var/lib/rpm/__db*

# go ahead and pre-make the man -k cache (#455968)
/usr/bin/mandb

# save a little bit of space at least...
rm -f /boot/initramfs*
# make sure there aren't core files lying around
rm -f /core*

# remove random seed, the newly installed instance should make it's own
rm -f /var/lib/systemd/random-seed

# convince readahead not to collect
# FIXME: for systemd

# forcibly regenerate fontconfig cache (so long as this live image has
# fontconfig) - see #1169979
if [ -x /usr/bin/fc-cache ] ; then
   fc-cache -f
fi

echo 'File created by kickstart. See systemd-update-done.service(8).' \
    | tee /etc/.updated >/var/.updated

# Drop the rescue kernel and initramfs, we don't need them on the live media itself.
# See bug 1317709
rm -f /boot/*-rescue*

%end


%post --nochroot
cp $INSTALL_ROOT/usr/share/licenses/*-release/* $LIVE_ROOT/

# only works on x86, x86_64
if [ "$(uname -i)" = "i386" -o "$(uname -i)" = "x86_64" ]; then
  if [ ! -d $LIVE_ROOT/LiveOS ]; then mkdir -p $LIVE_ROOT/LiveOS ; fi
  cp /usr/bin/livecd-iso-to-disk $LIVE_ROOT/LiveOS
fi
%end

#################################
# List packages to be installed #
#################################

#enable threaded irqs
bootloader --append="threadirqs"

%packages

# save some space
-mpage
-sox
-hplip
-numactl
-isdn4k-utils
-autofs
# smartcards won't really work on the livecd.
-coolkey
-wget

# scanning takes quite a bit of space :/
-xsane
-xsane-gimp
-sane-backends

# XFCE
@xfce-desktop
@xfce-apps
@xfce-extra-plugins
@xfce-media
@xfce-office

# unlock default keyring. FIXME: Should probably be done in comps
gnome-keyring-pam

# save some space
-autofs
-acpid
-gimp-help
-desktop-backgrounds-basic
-realmd                     # only seems to be used in GNOME
-PackageKit*                # we switched to yumex, so we don't need this
-aspell-*                   # dictionaries are big
-gnumeric
-foomatic-db-ppds
-foomatic
-stix-fonts
-ibus-typing-booster
-xfce4-sensors-plugin

# drop some system-config things
#-system-config-boot
-system-config-network
-system-config-rootpassword
#-system-config-services
-policycoreutils-gui

# alsa
alsa-firmware
alsa-tools
alsa-utils
alsamixergui
alsa-plugins-jack
alsa-plugins-pulseaudio
alsa-plugins-usbstream
alsa-plugins-samplerate
alsa-plugins-upmix
alsa-plugins-vdownmix
a2jmidid
aj-snapshot

# jack 
jack-audio-connection-kit
qjackctl
jackctlmmc
Carla
Cadence

# ffado
ffado

# pulse
pulseaudio-module-jack
pavucontrol

# midi
qsynth
fluidsynth
fluid-soundfont-gm
fluidsynth-dssi
timidity++
qmidiarp
vmpk

# synthesis
hydrogen
hydrogen-drumkits
bristol
yoshimi
swami
synthv1
samplv1
drumkv1
ams
aeolus
minicomputer
phasex

# guitar
guitarix
tuxguitar
sooperlooper

# recodring and DAW
audacity
ardour4
ardour4-audiobackend-alsa
ardour4-audiobackend-jack
ardour4-audiobackend-dummy
seq24
qtractor
non-daw
non-mixer
non-sequencer
non-session-manager
muse
rosegarden4
mixxx
milkytracker

# audio-plugins
calf
dssi
jack-rack
ladspa
helm
DISTRHO-Ports
mv-6pm

# ladpsa plugins
ladspa-amb-plugins
ladspa-autotalent-plugins
ladspa-blop-plugins
ladspa-cmt-plugins
ladspa-fil-plugins
ladspa-mcp-plugins
ladspa-rev-plugins
ladspa-swh-plugins
ladspa-tap-plugins
ladspa-vco-plugins
ladspa-vocoder-plugins
ladspa-wasp-plugins

# lv2 plugins
lv2
lv2-avw-plugins
lv2-fil-plugins
lv2-invada-plugins
lv2-kn0ck0ut
lv2-ll-plugins
lv2-swh-plugins
lv2-vocoder-plugins
lv2-zynadd-plugins
lv2dynparam
lv2-abGate
lv2-c++-tools 
lv2-samplv1
lv2-synthv1
lv2-drumkv1
lv2-triceratops
lv2-newtonator
lv2-x42-plugins
lv2-fomp-plugins
lv2-sorcer
lv2-fabla
lv2-artyfx-plugins
lv2-EQ10Q-plugins
#YC: temporary missing lv2-linuxsampler-plugins
lv2-mdaEPiano
lv2-mdala-plugins

# dssi
nekobee-dssi
whysynth-dssi
xsynth-dssi
hexter-dssi

# Zita tools
zita-at1
zita-rev1
#YC: temporary missing zita-ajbridge
zita-alsa-pcmi
zita-convolver
zita-lrx
zita-njbridge
zita-resampler

# writing & publishing
vim
nano
mscore
lilypond

# audio utilities
jamin
lash
jack_capture
jaaa
jmeters
qastools
arpage
realTimeConfigQuickScan
rtirq
ladish
japa
radium-compressor
solfege
# YC: temporary missing linuxsampler
# YC: temporary missing qsampler
projectM-jack
projectM-pulseaudio

protrekkr
oxefmsynth
stretchplayer
sfarkxtc
lenmus
GrandOrgue
picoloop
jm2cv
rakarrack

#language
chuck
miniaudicle
supercollider
#FC24 supercollider-mathlib
#FC24 supercollider-quarks
supercollider-sc3-plugins
supercollider-vim
#FC24 supercollider-cruciallib
sonic-pi
#YC: temporary missing pd-extended
lmms
faust
faust-tools

# fedora jam theming (to be customized)
fedora-jam-backgrounds

# Misc. Utils
screen
multimedia-menus
kernel-tools
xterm

# Include Mozilla Firefox and Thunderbird
firefox
thunderbird

##########
##Remove##
##########

## These are packages that are pulled for one reason or another but are safe to remove.
-@input-methods              ## Not necessary can be installed later.
-@dial-up                    ## Not even old computers use dialup anymore.
-system-config-firewall-base ## Doesn't seem to do anything
-gfs2-utils                  ## Part of kernel debug
-kernel-debug-modules-extra  ## Part of kernel debug
-kernel-debug                ## Dont need the debug kernel upon install
-aspell-*                    ## Dictionaries are big and take up space
-hunspell-*                  ## Dictionaries
-man-pages-*                 ## Dictionaries
-words                       ## Dictionaries
-krb5-auth-dialog            ## Legacy and cmdline things we don't want
-krb5-workstation            ## Legacy
-pam_krb5                    ## Legacy
-quota                       ## Legacy
-minicom                     ## Legacy
-dos2unix                    ## Legacy
-finger                      ## Legacy
-ftp                         ## Legacy
-jwhois                      ## Legacy
-mtr                         ## Legacy
-pinfo                       ## Legacy
-rsh                         ## Legacy
-telnet                      ## Legacy
-nfs-utils                   ## Legacy
-ypbind                      ## Legacy
-yp-tools                    ## Legacy
-rpcbind                     ## Legacy
-acpid                       ## Legacy
-ntsysv                      ## Legacy
-rmt                         ## Legacy
-talk                        ## Legacy
-lftp                        ## Legacy
-tcpdump                     ## Legacy
-dump                        ## Legacy
-@printing                   ## We don't want printer support out of the box.
-fprintd-pam                 ## We don't want printer support out of the box.
-fprintd                     ## We don't want printer support out of the box.
-libfprint                   ## We don't want printer support out of the box.
# FC24 -python-cups                 ## We don't want printer support out of the box.
-system-config-printer-libs  ## We don't want printer support out of the box.
-gnu-free-fonts-common       ## Fonts take up space
-gnu-free-mono-fonts         ## Fonts take up space
-gnu-free-sans-fonts         ## Fonts take up space
-gnu-free-serif-fonts        ## Fonts take up space
-ibus-typing-booster         ## Tab completion in libreoffice and the likes Unneeded
-libtranslit                 ## Tab
-libtranslit-m17n            ## Tab

# Not really useful
-fedora-jam-backgrounds-kde
-tigervnc-server-minimal
-abiword
-xfburn
-lyx-fonts
-goffice
-midori

%end

%post --nochroot

mkdir -p $INSTALL_ROOT/home/lescuizines/SoundFonts
mkdir -p $INSTALL_ROOT/home/lescuizines/GuitarPro

cp /home/collette/SoundFonts/63mg\ The\ Xioad\ Bank.sf2        $INSTALL_ROOT/home/lescuizines/SoundFonts
cp /home/collette/SoundFonts/SF2/Bass/336-Squierbass.sf2       $INSTALL_ROOT/home/lescuizines/SoundFonts
cp /home/collette/SoundFonts/SF2/Guitar/Guitar\ Distortion.SF2 $INSTALL_ROOT/home/lescuizines/SoundFonts

cp -r /home/collette/TuxGuitar/GuitarPro/Cake            $INSTALL_ROOT/home/lescuizines/GuitarPro/Cake
cp -r /home/collette/TuxGuitar/GuitarPro/ChuckBerry      $INSTALL_ROOT/home/lescuizines/GuitarPro/ChuckBerry
cp /home/collette/SoundFonts/Logo-Bloc-Cuizines-Noir.png $INSTALL_ROOT/usr/share/backgrounds/images/

%end

%post

if [ ! -d /home/lescuizines/Desktop ]; then
  mkdir -p /home/lescuizines/Desktop
fi

# Rewrite limits.conf for jack use
cat > /etc/security/limits.d/95-jack.conf <<EOF
# Default limits for users of jack-audio-connection-kit

@jackuser - rtprio 90
@jackuser - nice -10
@jackuser - memlock unlimited
EOF

# xfce configuration

# This is a huge file and things work ok without it
rm -f /usr/share/icons/HighContrast/icon-theme.cache

# create /etc/sysconfig/desktop (needed for installation)

cat > /etc/sysconfig/desktop <<EOF
PREFERRED=/usr/bin/startxfce4
DISPLAYMANAGER=/usr/sbin/lightdm
EOF

cat >> /etc/rc.d/init.d/livesys << EOF

mkdir -p /home/lescuizines/.config/xfce4

cat > /home/lescuizines/.config/xfce4/helpers.rc << FOE
MailReader=thunderbird
FileManager=Thunar
WebBrowser=firefox
FOE

# disable screensaver locking (#674410)
cat >> /home/lescuizines/.xscreensaver << FOE
mode:           off
lock:           False
dpmsEnabled:    False
FOE

# deactivate xfconf-migration (#683161)
rm -f /etc/xdg/autostart/xfconf-migration-4.6.desktop || :

# deactivate xfce4-panel first-run dialog (#693569)
mkdir -p /home/lescuizines/.config/xfce4/xfconf/xfce-perchannel-xml
cp /etc/xdg/xfce4/panel/default.xml /home/lescuizines/.config/xfce4/xfconf/xfce-perchannel-xml/xfce4-panel.xml

# Set french keyboard for xfce
cat >> /home/lescuizines/.config/xfce4/xfconf/xfce-perchannel-xml/keyboard-layout.xml << FOE
<?xml version="1.0" encoding="UTF-8"?>

<channel name="keyboard-layout" version="1.0">
  <property name="Default" type="empty">
    <property name="XkbDisable" type="bool" value="false"/>
    <property name="XkbLayout" type="string" value="fr"/>
    <property name="XkbVariant" type="string" value=""/>
  </property>
</channel>
FOE

# Set the background image for the main desktop
# <property name="image-path" type="string" value="/usr/share/backgrounds/xfce/xfce-blue.jpg"/>
# <property name="last-single-image" type="string" value="/usr/share/backgrounds/xfce/xfce-blue.jpg"/>

cat >> /home/lescuizines/.config/xfce4/xfconf/xfce-perchannel-xml/xfce4-desktop.xml << FOE
<?xml version="1.0" encoding="UTF-8"?>

<channel name="xfce4-desktop" version="1.0">
  <property name="backdrop" type="empty">
    <property name="screen0" type="empty">
      <property name="monitor0" type="empty">Logo-Bloc-Cuizines-Noir.png
        <property name="image-path" type="string" value="/usr/share/backgrounds/images/Logo-Bloc-Cuizines-Noir.png"/>
        <property name="last-image" type="string" value="/usr/share/backgrounds/images/default.png"/>
        <property name="last-single-image" type="string" value="/usr/share/backgrounds/images/Logo-Bloc-Cuizines-Noir.png"/>
      </property>
    </property>
  </property>
</channel>
FOE

# set up lightdm autologin
sed -i 's/^#autologin-user=.*/autologin-user=lescuizines/' /etc/lightdm/lightdm.conf
sed -i 's/^#autologin-user-timeout=.*/autologin-user-timeout=0/' /etc/lightdm/lightdm.conf
#sed -i 's/^#show-language-selector=.*/show-language-selector=true/' /etc/lightdm/lightdm-gtk-greeter.conf

# set Xfce as default session, otherwise login will fail
sed -i 's/^#user-session=.*/user-session=xfce/' /etc/lightdm/lightdm.conf

# Show harddisk install on the desktop
sed -i -e 's/NoDisplay=true/NoDisplay=false/' /usr/share/applications/liveinst.desktop

if [ ! -d /home/lescuizines/Desktop ]; then
  mkdir /home/lescuizines/Desktop
fi

cp /usr/share/applications/liveinst.desktop /home/lescuizines/Desktop

# and mark it as executable (new Xfce security feature)
chmod +x /home/lescuizines/Desktop/liveinst.desktop

# this goes at the end after all other changes. 
chown -R lescuizines:lescuizines /home/lescuizines
restorecon -R /home/lescuizines

EOF

# Install applications on the Desktop

cat >> /etc/rc.d/init.d/livesys << EOF

# Copy some applications on desktop
cp /usr/share/applications/qjackctl.desktop       /home/lescuizines/Desktop
cp /usr/share/applications/guitarix.desktop       /home/lescuizines/Desktop
cp /usr/share/applications/qsynth.desktop         /home/lescuizines/Desktop
cp /usr/share/applications/yoshimi.desktop        /home/lescuizines/Desktop
cp /usr/share/applications/sooperlooper.desktop   /home/lescuizines/Desktop
cp /usr/share/applications/lmms.desktop           /home/lescuizines/Desktop
cp /usr/share/applications/mscore.desktop         /home/lescuizines/Desktop
cp /usr/share/applications/qtractor.desktop       /home/lescuizines/Desktop
cp /usr/share/applications/audacity.desktop       /home/lescuizines/Desktop
cp /usr/share/applications/tuxguitar.desktop      /home/lescuizines/Desktop
cp /usr/share/applications/xfce4-terminal.desktop /home/lescuizines/Desktop
cp /usr/share/applications/carla.desktop          /home/lescuizines/Desktop
cp /usr/share/applications/cadence.desktop        /home/lescuizines/Desktop
cp /usr/share/applications/ardour4.desktop        /home/lescuizines/Desktop

chmod +x /home/lescuizines/Desktop/*.desktop

# make sure to set the right permissions and selinux contexts
chown -R lescuizines:lescuizines /home/lescuizines/
restorecon -R /home/lescuizines/

EOF

%end
