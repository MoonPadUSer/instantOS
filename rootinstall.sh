#!/bin/bash

######################################################
## installs all system wide programs for instantOS  ##
######################################################
source <(curl -Ls https://git.io/JerLG)
pb install
pb git

if ! [ $(whoami) = "root" ]; then
    echo "please run this as root"
    exit 1
fi

mkdir -p /opt/instantos

# add group and add users to group
ugroup() {
    groupadd "$1" &>/dev/null
    for USER in $(ls /home/ | grep -v '+'); do
        if ! sudo su "$USER" -c groups | grep -Eq " $1|$1 "; then
            sudo gpasswd -a $USER $1
        fi
    done
}

ugroup video
ugroup input

RAW="https://raw.githubusercontent.com"

# adds permanent global environment variable
addenv() {
    [ -e /etc/environment ] || touch /etc/environment
    if [ "$1" = "-f" ]; then
        local FORCE="true"
        shift 1
    fi

    if grep -q "$1=" /etc/environment; then
        if [ -z "$FORCE" ]; then
            echo "key already existing"
            return 1
        else
            sed -i "s~$1=.*~$1=$2~g" /etc/environment
        fi
    else
        echo "$1=$2" >>/etc/environment
    fi
}

addenv -f "QT_QPA_PLATFORMTHEME" "qt5ct"
addenv -f "PAGER" "less"
command -v nvim &>/dev/null && addenv -f "EDITOR" "$(which nvim)"

# needed for instantLOCK
if grep -q 'nobody' </etc/groups || grep -q 'nobody' </etc/group; then
    echo "nobody workaround not required"
else
    sudo groupadd nobody
fi

# fix java gui appearing empty on instantWM
if ! grep -q 'instantwm' </etc/profile; then
    echo "fixing java windows for instantwm in /etc/profile"
    echo '# fix instantwm java windows' >>/etc/profile
    echo 'export _JAVA_AWT_WM_NONREPARENTING=1' >>/etc/profile
else
    echo "java workaround already applied"
fi

if [ -e /etc/lightdm/lightdm.conf ] && ! grep -q 'instantwm' /etc/lightdm/lightdm.conf; then
    sudo sed -i 's/^user-session=.*/user-session=instantwm/g' /etc/lightdm/lightdm.conf
    sudo sed -i '# user-session = Session to load for users/user-session=instantwm/g' /etc/lightdm/lightdm.conf
fi

rm -rf /tmp/instantinstall
mkdir /tmp/instantinstall
cd /tmp/instantinstall

# laptop specific stuff
if acpi | grep -q '[0-9]%' &>/dev/null; then
    # fix tap to click not working with tiling wms
    if ! [ -e /etc/X11/xorg.conf.d/90-touchpad.conf ] ||
        ! cat /etc/X11/xorg.conf.d/90-touchpad.conf | grep -iq 'tapping.*"on"'; then
        curl -s "$RAW/instantOS/instantOS/master/xorg/90-touchpad.conf" >/etc/X11/xorg.conf.d/90-touchpad.conf
        # three and four finger swipes on laptop
        if ! command -v libinput-gestures &>/dev/null; then
            git clone --depth=1 https://github.com/bulletmark/libinput-gestures.git
            cd libinput-gestures
            sudo make install
            cd ..
            rm -rf libinput-gestures
        fi
    fi
else
    echo "system is on a desktop"
    # slow down mouse sensitivity a little
    [ -e /etc/X11/xorg.conf.d/95-mouse-accel.conf ] ||
        curl -s "$RAW/instantOS/instantOS/master/xorg/95-mouse-accel.conf" >/etc/X11/xorg.conf.d/95-mouse-accel.conf
fi

echo "the theme is $THEME"

cd /tmp
rm -rf instantos
