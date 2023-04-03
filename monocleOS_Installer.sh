#!/bin/bash

# monocleOS_Installer.sh
# Copyright (C) 2020  Zack Didcott

# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.

# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.

# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <https://www.gnu.org/licenses/>.

# == Variables ==

# Installer
keyring=1

# Partitioning
if [ -z "$1" ]; then
    installDisk="/dev/sdX" # THIS DRIVE WILL BE WIPED
else
    installDisk="$1"
fi

# Bootloader
[ -d /sys/firmware/efi ] && bootloader="efi" || bootloader="mbr"  # Must be 'efi' or 'mbr'
# For EFI.
# Normally x86_64, but in some cases 64-bit CPUs have a 32-bit UEFI (i.e. ASUS T100TA)
# In this case, grub-silent will need to be compiled accordingly
bootloaderArch="x86_64"
# For EFI. Currently uses PreLoader with MS Windows' Keys
# GRUB must be enrolled on first boot when enabled
secureBoot=0

# Only 'gpt' and 'msdos' are supported
if [[ $bootloader == "efi" ]]; then
    diskType="gpt"
elif [[ $bootloader == "mbr" ]]; then
    diskType="msdos"
fi

diskSize="`fdisk -l | grep "Disk $installDisk" | awk '{print $3}'`"
# Find Unit of fdisk. Assumes GiB or TiB
diskSizeUnit="`fdisk -l | grep "Disk $installDisk" | awk '{print $4}' | cut -c 1`"
# Convert to GiB if TiB
if [[ $diskSizeUnit == 'T' ]]; then
    diskSize=$(( $diskSize * 1024 ))
fi

# LUKS
luksMap="Root"
luksKey="/tmp/luksKey"

# FS
bootLabel="Boot"
rootLabel="System"
swapLabel="Swap"
homeLabel="Home"

# LVM
VG="monocleOS"
rootLV="System"
rootSize=25
swapLV="Swap"
swapSize=`cat /proc/meminfo | grep "MemTotal" | awk '{print $2}'`  # in kB
homeLV="Home"

# Paths
rootPath="/dev/$VG/$rootLV"
swapPath="/dev/$VG/$swapLV"
homePath="/dev/$VG/$homeLV"

# Mounts
rootMount="/mnt"

# Packages
pkgfile='packages.txt'
packages="aisleriot alsa-utils apparmor arc-gtk-theme arc-icon-theme arch-install-scripts avahi awesome-terminal-fonts base base-devel clamav clamtk cups dunst epiphany evolution feh ffmpegthumbnailer file-roller foomatic-db foomatic-db-engine foomatic-db-gutenprint-ppds foomatic-db-nonfree-ppds foomatic-db-ppds four-in-a-row fuse2 gedit ghostscript git gnome-calculator gnome-calendar gnome-chess gnome-keyring gnome-mahjongg gnome-mines gnome-screensaver gnome-screenshot gnome-sudoku gnome-system-monitor gnome-terminal gnuchess gpicview grub-silent gsfonts gtk-engine-murrine gutenprint gvfs-mtp hunspell hunspell-en_GB i3-gaps iagno kernel-modules-hook libreoffice-fresh libsecret linux linux-firmware mkinitcpio networkmanager nm-connection-editor noto-fonts noto-fonts-cjk noto-fonts-emoji nss-mdns mousetweaks ntp onboard p7zip pavucontrol picom preload playerctl plymouth polybar pulseaudio pulseaudio-alsa qt5-styleplugins quadrapassel reflector sudo system-config-printer thunar thunar-archive-plugin thunar-media-tags-plugin thunar-sendto-clamtk thunar-volman ttf-dejavu ttf-font-awesome ttf-liberation ttf-material-icons-git tumbler vlc wine winetricks xcursor-breeze xorg xorg-drivers xorg-xinit xss-lock xzoom yay zenity"

if [[ $bootloader == "efi" ]]; then
    packages="$packages efibootmgr"
fi

if [[ $secureBoot == 1 ]]; then
    packages="$packages preloader-signed"
fi

# Kernel & Drivers
kparams=""
kmodules=""
cpu=`lscpu`
if (echo $cpu | grep -iq 'amd'); then
    packages="$packages amd-ucode"
fi
if (echo $cpu | grep -iq 'intel'); then
    packages="$packages intel-ucode"
fi
# All xorg-drivers are installed explicitly
gpu=`lspci | grep -i 'vga'`
if (echo $gpu | grep -iq 'nvidia'); then
    packages="$packages nvidia nvidia-utils lib32-nvidia-utils"
    kparams="$kparams nvidia-drm.modeset=1"
    kmodules="$kmodules nvidia nvidia_modeset nvidia_uvm nvidia_drm"

    # For nouveau, uncomment the following, and comment the above
    # packages="$packages mesa lib32-mesa libva-mesa-driver lib32-libva-mesa-driver mesa-vdpau lib32-mesa-vdpau xf86-video-nouveau"
    # kmodules="$kmodules nouveau"
fi
if (echo $gpu | grep -iq 'amd') || (echo $gpu | grep -iqw 'ati'); then
    packages="$packages mesa lib32-mesa libva-mesa-driver lib32-libva-mesa-driver mesa-vdpau lib32-mesa-vdpau vulkan-radeon lib32-vulkan-radeon xf86-video-ati xf86-video-amdgpu"
    kmodules="$kmodules amdgpu radeon"
fi
if (echo $gpu | grep -iq 'intel'); then
    packages="$packages mesa lib32-mesa intel-media-driver libva-intel-driver vulkan-intel lib32-vulkan-intel xf86-video-intel"
    kmodules="$kmodules i915"
fi

# Installation Files
pkgtar="monocleOS.tar.gz"
chnglog="CHANGELOG"
precompiled="Precompiled_Packages"
if [ -d "$precompiled" ]; then
    installPrecompiled=1
else
    installPrecompiled=0
fi

# Configuration
installer="yay"
region="Europe"
city="London"
locale="en_GB.UTF-8"
vconsole="uk"
xkeymap="gb"
paperSize="a4"
hostname="monocleOS-$(cat /dev/urandom | tr -dc '0-9A-Z' | fold -w 4 | head -n 1)"
password="`cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 32 | head -n 1`"
issue="Welcome to monocleOS!"
battery=`ls -1 /sys/class/power_supply/ | grep -i 'BAT'`
backlight=`ls -1 /sys/class/backlight/ | head -n 1`

echo "Installing monocleOS to $installDisk (`date +'%H:%M:%S'`)"
startTime=$SECONDS

# == Preliminary Checks ==
if [[ $EUID -ne 0 ]]; then
    echo "This script must be run as root."
    exit 1
fi
if [ ! -e $pkgtar ]; then
    echo "$pkgtar does not exist."
    exit 1
fi
if [ -n "$installDisk" ]; then
    if (( ( $(($swapSize / 1048576)) + $rootSize + 5) > $diskSize )); then
        echo "Sum of partition sizes are greater than size of disk. Aborting..."
        exit 1
    else
        rootSize=$rootSize'G'
        swapSize=$swapSize'K'
    fi
fi
if [[ $keyring == 1 ]]; then
    pacman -Sy --noconfirm archlinux-keyring
fi

# Set Paths for Install, if installDisk is set
if [ -n "$installDisk" ]; then
    if [[ $bootloader == "efi" ]]; then
        efiPath=$installDisk"1"
        bootPath=$installDisk"2"
        luksPath=$installDisk"3"
    elif [[ $bootloader == "mbr" ]]; then
        bootPath=$installDisk"1"
        luksPath=$installDisk"2"
    else
        echo "'bootloader' must be 'efi' or 'mbr'."
        exit 1
    fi
fi

# == Installation ==

# Partitioning
if [ -n "$installDisk" ]; then
    (
    if [[ $diskType == "msdos" ]]; then
        # Create a new empty MSDOS partition table
        echo o
    fi
    if [[ $diskType == "gpt" ]]; then
        # Create a new empty GPT partition table
        echo g
    fi
    if [[ $bootloader == "efi" ]]; then
        # EFI System
        # Size of 550MB To avoid confusion between MB & MiB and ensure not FAT16
        echo n
        echo  
        echo  
        echo +550M
        echo t
        echo 1
    fi
    # Boot partition
    # 500MiB
    echo n
    if [[ $diskType == "msdos" ]]; then
        # Primary in case of msdos
        echo p
    fi
    echo  
    echo  
    echo +500M
    # Root partition
    # Last Sector (End)
    echo n
    if [[ $diskType == "msdos" ]]; then echo p; fi
    echo  
    echo  
    echo  
    if [[ $bootloader == "mbr" ]]; then
        # Set bootable flag on boot partition as fallback
        echo a
        echo 1
    fi
    echo w  # Write changes
    ) | fdisk $installDisk
fi

# File Systems
if [ -n "$installDisk" ]; then
    # Make Keys
    dd if=/dev/urandom of=$luksKey bs=512 count=4
    # echo -n "$password" > $luksKey
    # EFI, Boot, Root
    if [[ $bootloader == "efi" ]]; then
        mkfs.fat -F32 $efiPath
    fi
    # grub fails to install for i386-pc platform if metadata_csum_seed is enabled
    mkfs.ext4 -O ^metadata_csum_seed -FL $bootLabel $bootPath
    cryptsetup -q luksFormat $luksPath --key-file=$luksKey
    luksUUID=`cryptsetup luksUUID $luksPath`
    cryptsetup open $luksPath $luksMap --key-file=$luksKey
    lvmPath="/dev/mapper/$luksMap"
    pvcreate $lvmPath
    vgcreate $VG $lvmPath
    lvcreate -L $swapSize -n $swapLV $VG
    swapPath="/dev/$VG/$swapLV"
    lvcreate -L $rootSize -n $rootLV $VG
    rootPath="/dev/$VG/$rootLV"
    lvcreate -l +100%FREE -n $homeLV $VG
    homePath="/dev/$VG/$homeLV"
    mkswap -L $swapLabel $swapPath
    mkfs.ext4 -FL $rootLabel $rootPath
    mkfs.ext4 -FL $homeLabel $homePath
    vgchange -a n $VG
    cryptsetup close $luksMap
fi

# Mount
cryptsetup open $luksPath $luksMap --key-file=$luksKey
lvmPath="/dev/mapper/$luksMap"
sleep 5
mount $rootPath $rootMount
if [ $? -eq 0 ]; then
    rootPath=$rootMount
else
    echo "Root device failed to mount. Aborting..."
    exit 1
fi
mkdir $rootMount/boot
mount $bootPath $rootMount/boot
bootPath="$rootMount/boot"
if [[ $bootloader == "efi" ]]; then
    mkdir $bootPath/esp
    mount $efiPath $bootPath/esp
    efiPath="$bootPath/esp"
fi
mkdir $rootMount/home
mount $homePath $rootMount/home
homePath="$rootMount/home"
swapon $swapPath

# Packages
pacstrap $rootPath base base-devel linux linux-firmware git

# Configuration
genfstab -U $rootMount >> $rootMount/etc/fstab
rootUUID=$(findmnt $rootMount -no UUID)
# Remove timeout for password
sed -ie "/^\UUID=$rootUUID/ s/rw,relatime/rw,relatime,x-systemd.device-timeout=0/" $rootMount/etc/fstab
# Chroot
mkdir -p $rootMount/priv
cp $luksKey $rootMount/priv/defaultKey.bin
chmod -R 000 $rootMount/priv
mkdir -p $rootMount/var/monocle/monocleOS/
cp $pkgtar $rootMount/var/monocle/monocleOS/
cp $chnglog $rootMount/var/monocle/monocleOS/
if [[ $installPrecompiled == 1 ]]; then
    cp -R $precompiled $rootMount/var/monocle/monocleOS/
fi
mkdir -p $rootMount/var/recovery
echo $packages > $pkgfile
cp $pkgfile $rootMount/var/recovery/
cp $pkgtar $rootMount/var/recovery/

if [[ $bootloader == "efi" ]]; then
    # Set efiPath relative to chroot
    efiPath="/boot/esp"
fi

# Preserve environment variables from install
mkdir -p $rootMount/etc
cat << EOF > $rootMount/etc/monocleOS.env
luksUUID='$luksUUID'
rootUUID='$rootUUID'
installer='$installer'
bootloader='$bootloader'
bootloaderArch='$bootloaderArch'
efiPath='$efiPath'
secureBoot='$secureBoot'
VG='$VG'
homeLabel='$homeLabel'
homeLV='$homeLV'
kmodules='$kmodules'
EOF

# Create installer script for arch-chroot
cat << EOF | arch-chroot $rootPath
#!/bin/bash

# Configuration
ln -sf /usr/share/zoneinfo/$region/$city /etc/localtime
hwclock --systohc
sed -i '/"en_US.UTF-8 UTF-8"/s/^#//g' /etc/locale.gen; sed -i '/'$locale'/s/^#//g' /etc/locale.gen
locale-gen
echo "LANG=en_US.UTF-8" > /etc/locale.conf
echo "KEYMAP=$vconsole" > /etc/vconsole.conf
echo "$hostname" > /etc/hostname
echo "127.0.0.1	localhost" >> /etc/hosts
echo "::1	localhost" >> /etc/hosts
echo "127.0.1.1	$hostname.localdomain	$hostname" >> /etc/hosts
echo "$issue" > /etc/issue
echo "" >> /etc/issue
echo "monocleOS	UUID=$luksUUID	/priv/defaultKey.bin	luks" >> /etc/crypttab.initramfs
echo '[multilib]
Include = /etc/pacman.d/mirrorlist' >> /etc/pacman.conf
pacman -Sy

# Users
useradd -rmd /var/monocle -c 'System User' monocle
chown -R monocle:monocle /var/monocle
useradd -rmd /var/recovery -c 'Recovery User' recovery
chown -R recovery:recovery /var/recovery
chmod -R 700 /var/recovery
useradd -m -c 'User' user
echo 'user:$password' | chpasswd 
echo 'Defaults>recovery targetpw
monocle ALL=(root)NOPASSWD:/usr/bin/pacman
recovery ALL=(root)NOPASSWD:/usr/bin/chpasswd, /usr/bin/pacman, /usr/bin/cryptsetup luksKillSlot /dev/disk/by-uuid/$luksUUID 0, /usr/bin/cryptsetup luksAddKey /dev/disk/by-uuid/$luksUUID --key-slot 0, /usr/bin/true
user ALL=(recovery) ALL
user ALL=(recovery)NOPASSWD:/usr/bin/monocleOS-recovery --installBase, /usr/bin/monocleOS-recovery --installExtract, /usr/bin/monocleOS-recovery --installMonocle
user ALL=(root)NOPASSWD:/usr/bin/initMonocle
user ALL=(root)NOPASSWD:/usr/bin/monocleOS --themeColour user
user ALL=(root) /usr/bin/cryptsetup luksChangeKey /dev/disk/by-uuid/$luksUUID --key-slot 0, /usr/bin/cryptsetup luksKillSlot /dev/disk/by-uuid/$luksUUID 1, /usr/bin/cryptsetup luksAddKey /dev/disk/by-uuid/$luksUUID --key-slot 1, /usr/bin/cryptsetup luksChangeKey /dev/disk/by-uuid/$luksUUID --key-slot 0 /tmp/luksKey.tmp, /usr/bin/passwd recovery, /usr/bin/monocleOS-recovery --resetFormat 0, /usr/bin/monocleOS-recovery --resetFormat 1, /usr/bin/monocleOS-recovery --resetDefaults, /usr/bin/monocleOS-recovery --resetPassword, /usr/bin/monocleOS-recovery --resetPermissions, /usr/bin/true' > /etc/sudoers.d/monocleOS
chown root:root /etc/sudoers.d/monocleOS
chmod 0440 /etc/sudoers.d/monocleOS
visudo -cf /etc/sudoers.d/monocleOS || rm /etc/sudoers.d/monocleOS
passwd -l root
passwd -l monocle
passwd -l recovery

# Packages
# Installation
sudo -iu monocle
cd
git clone https://aur.archlinux.org/$installer.git
cd $installer
makepkg -si --noconfirm
if [[ $installPrecompiled == 1 ]]; then
    cd /var/monocle/monocleOS/$precompiled
    for package in *.pkg.tar.*; do
        $installer -U --noconfirm \$package
    done
fi
cd
$installer -S --needed --noconfirm $packages
cd monocleOS
tar -xzvf $pkgtar
makepkg -si --noconfirm
exit

# Configuration
localectl set-x11-keymap $xkeymap
echo "$paperSize" > /etc/papersize
cp /etc/monocleOS/nsswitch.conf /etc/nsswitch.conf
plymouth-set-default-theme monocleOS
sed -i 's/BACKLIGHT_PLACEHOLDER/'$backlight'/g' /etc/monocleOS/polybar.conf.skel
sed -i 's/BATTERY_PLACEHOLDER/'$battery'/g' /etc/monocleOS/polybar.conf.skel
echo MODULES=\($kmodules\) | tee /etc/mkinitcpio.conf > /dev/null
echo FILES=\(/priv/defaultKey.bin\) | tee -a /etc/mkinitcpio.conf > /dev/null
echo HOOKS=\(base systemd plymouth keyboard autodetect sd-vconsole modconf block sd-encrypt lvm2 filesystems fsck shutdown\) | tee -a /etc/mkinitcpio.conf > /dev/null
if (echo $kmodules | grep -iq 'nvidia'); then mv /etc/pacman.d/hooks/nvidia.hook.disabled /etc/pacman.d/hooks/nvidia.hook; fi
mkinitcpio -P
sed -i 's/KPARAMS_PLACEHOLDER/'$kparams'/g' /etc/default/grub.monocleOS
cp /etc/default/grub.monocleOS /etc/default/grub
if [[ $bootloader == "efi" ]]; then
    grub-install --target=$bootloaderArch-efi --efi-directory=$efiPath --bootloader-id=GRUB
    if [[ $secureBoot == 1 ]]; then
        cp /usr/share/preloader-signed/PreLoader.efi $efiPath/EFI/Boot/
        cp /usr/share/preloader-signed/HashTool.efi $efiPath/EFI/Boot/
        cp $efiPath/EFI/GRUB/grubx64.efi $efiPath/EFI/Boot/loader.efi
        efibootmgr --verbose --disk $installDisk --part 1 --create --label 'monocleOS Signed' --loader /EFI/Boot/PreLoader.efi
        cp /usr/share/preloader-signed/PreLoader.efi $efiPath/EFI/Boot/bootx64.efi
    else
        efibootmgr --verbose --disk $installDisk --part 1 --create --label 'monocleOS' --loader /EFI/GRUB/grubx64.efi
    fi
elif [[ $bootloader == "mbr" ]]; then
    grub-install --target=i386-pc $installDisk
    grub-install --target=i386-pc --force $installDisk'1'
fi
grub-mkconfig -o /boot/grub/grub.cfg

# Services
systemctl enable NetworkManager
systemctl enable ntpd
systemctl enable avahi-daemon
systemctl enable cups
usermod -aG cups user
systemctl enable automatic-update.timer
systemctl enable linux-modules-cleanup
systemctl enable clamav-freshclam
systemctl enable clamav-daemon
systemctl enable clamav-scan.timer
systemctl enable apparmor
systemctl enable preload

# User Files
sudo -iu user
mkdir /home/user/Desktop
mkdir /home/user/Documents
mkdir /home/user/Downloads
mkdir /home/user/Pictures
mkdir /home/user/Pictures/Screenshots
cp /etc/monocleOS/bash_profile.skel /home/user/.bash_profile
cp /usr/share/backgrounds/white_circle.png /home/user/.wallpaper.png
cp /etc/monocleOS/xinitrc.skel /home/user/.xinitrc
mkdir -p /home/user/.config/dunst
cp /etc/monocleOS/dunstrc.skel /home/user/.config/dunst/dunstrc
mkdir -p /home/user/.config/i3
cp /etc/monocleOS/i3.conf.skel /home/user/.config/i3/config
mkdir -p /home/user/.config/polybar
cp /etc/monocleOS/polybar.conf.skel /home/user/.config/polybar/config
mkdir -p /home/user/.icons/default
cp /etc/monocleOS/icons.default /home/user/.icons/default/index.theme 
mkdir -p /home/user/.config/gtk-3.0
cp /etc/monocleOS/gtkSettings.ini /home/user/.config/gtk-3.0/settings.ini
cp /etc/monocleOS/gtkrc /home/user/.gtkrc-2.0
cp /etc/monocleOS/Trolltech.conf /home/user/.config/Trolltech.conf
cp /etc/monocleOS/pam_environment.skel /home/user/.pam_environment
mkdir -p /home/user/.config/monocleOS
cp /usr/share/themes/Arc/gtk-2.0/gtkrc /home/user/.config/monocleOS/arc_gtk2_gtkrc
cp /usr/share/themes/Arc/gtk-3.0/gtk.gresource /home/user/.config/monocleOS/arc_gtk3_gtk_gresource
cp /usr/share/themes/Arc-Dark/gtk-2.0/gtkrc /home/user/.config/monocleOS/arc_dark_gtk2_gtkrc
cp /usr/share/themes/Arc-Dark/gtk-3.0/gtk.gresource /home/user/.config/monocleOS/arc_dark_gtk3_gtk_gresource
cp /etc/monocleOS/launcher.conf /home/user/.config/monocleOS/launcher.conf
cp /etc/monocleOS/tips-service.conf /home/user/.config/monocleOS/tips-service.conf
touch /home/user/.hushlogin
touch /home/user/.firstBoot
exit

# Themes
mkdir -p /root/.icons/default
cp /etc/monocleOS/icons.default /root/.icons/default/index.theme 
mkdir -p /root/.config/gtk-3.0
ln -sf /home/user/.config/gtk-3.0/settings.ini /root/.config/gtk-3.0/settings.ini
ln -sf /home/user/.gtkrc-2.0 /root/.gtkrc-2.0
cp /etc/monocleOS/Trolltech.conf /root/.config/Trolltech.conf
cp /etc/monocleOS/pam_environment.skel /root/.pam_environment
cp /usr/share/themes/Arc/gtk-2.0/gtkrc /usr/share/themes/Arc/gtk-2.0/gtkrc.bk
cp /usr/share/themes/Arc/gtk-3.0/gtk.gresource /usr/share/themes/Arc/gtk-3.0/gtk.gresource.bk
cp /usr/share/themes/Arc-Dark/gtk-2.0/gtkrc /usr/share/themes/Arc-Dark/gtk-2.0/gtkrc.bk
cp /usr/share/themes/Arc-Dark/gtk-3.0/gtk.gresource /usr/share/themes/Arc-Dark/gtk-3.0/gtk.gresource.bk
EOF

umount -R $rootPath
swapoff /dev/$VG/$swapLV
vgchange -a n $VG
cryptsetup close $luksMap

echo "monocleOS has been installed to $installDisk (`date +'%H:%M:%S'`)"
echo "Installation time: `TZ=UTC0 printf '%(%H:%M:%S)T\n' $(( SECONDS - startTime ))` ($(( SECONDS - startTime ))s)"
