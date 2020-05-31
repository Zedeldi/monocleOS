<p align="center">
  <img src="../assets/logo.png?raw=true" alt="Logo"/>
</p>


# monocleOS

A simplistic, easy-to-use operating system, based on Arch Linux.

## Contents

1. [Dedication](#dedication)
2. [Features](#features)
3. [Design](#design)
4. [Installation](#installation)
    1. [TL;DR](#tldr)
5. [Technical Specifications](#technical-specifications)
    1. [Partitioning](#partitioning)
    2. [Users](#users)
    3. [Desktop](#desktop)
    4. [Bootloader](#bootloader)
    5. [Services](#services)
    6. [Recovery](#recovery)
6. [Other Quirks](#other-quirks)
7. [Limitations](#limitations)
    1. [Security Considerations](#security-considerations)
    2. [Known Bugs](#known-bugs)
    3. [Reporting Bugs](#reporting-bugs)
8. [Todo](#todo)
9. [License](#license)
10. [Credits](#credits)
11. [Donate](#donate)

## Dedication

For those people who want a free OS that works out of the box, does not track you, and contains zero adverts, popups, or annoying 'your PC needs to reboot' messages. monocleOS comes preinstalled with a few applications to let you do what you want, without getting in the way.

This project was made specifically with the elderly in mind, but anyone is welcome to use it; monocleOS started as a hobby to help my grandparents become part of the ever-growing online world. However, as such - a hobby, expect a few hiccups. Please feel free to contribute any code or ideas. :smiley:

## Features

- Clean & minimal, theme-able UI
- Preinstalled applications, such as [Epiphany](https://wiki.gnome.org/Apps/Web/), [LibreOffice](https://www.libreoffice.org/) and [VLC](https://www.videolan.org/vlc/) - no bloatware whatsoever
- Automatic, unobtrusive updates
- LUKS encryption by design
- Built entirely upon trusted open-source software

## Design

Here are some example screenshots of monocleOS in action:

![Launcher](../assets/launcher.png?raw=true "xlunch launcher") ![Launcher menu](../assets/menu.png?raw=true "Launcher menu")
![Lock screen](../assets/gnome-screensaver.png?raw=true "Lock screen") ![Web browser](../assets/epiphany.png?raw=true "Epiphany web browser with detailed status bar")
![LibreOffice](../assets/libreoffice_with_onboard.png?raw=true "LibreOffice with onboard") ![i3](../assets/i3_example.png?raw=true "Example of i3's layout scheme")

## Installation

To install monocleOS, you will need an existing GNU/Linux OS with arch-install-scripts installed, in order to bootstrap the base Arch system, along with some fairly standard programs. The complete list is as follows:
- arch-install-scripts
- fdisk
- cryptsetup
- lvm2
- dosfstools
- e2fsprogs
- pciutils
- util-linux
- tar
- and of course bash

Conveniently, these package names are the same among most major GNU/Linux distributions.

The latest Arch install image will suffice: <https://www.archlinux.org/download/>

You will need to be able to access the installer's files from somewhere within the installation media, e.g. a live CD. These could be added to the image, mounted from an external drive, etc. If installing on a VM, the best option would be to create an ISO of the files and mount it as a disc. Alternatively, you could clone this repository once booted into the installation media, with `git clone https://github.com/Zedeldi/monocleOS.git`. Further, unless you have a local copy of the required packages, you will need a internet connection.

Currently, the installer expects the monocleOS package to be found at monocleOS.tar.gz. This is copied to /var/monocle/monocleOS/, extracted, then built & installed with makepkg. To meet this requirement, add the contents of the pkg directory to the specified tar.gz archive, in the location referenced by the installer script. Note: if you want to use an already built package, just remove the `tar -xzvf` line, and change `makepkg -si` to be `pacman -U /path/to/package`.

Various changes can be applied at this stage, by modifying the files within the package directory, before creating the archive - e.g. changing initial setup, adding i3 shortcuts, backgrounds, etc.

Precompiled packages can be dumped in the specified folder (by default, 'Precompiled\_Packages'), and they will be installed alongside everything else. It reduces install time, by eliminating the need for compilation of AUR packages. This could also serve as a method of making drop-in changes to the system during installation. Note: if a more recent version of a package is found, pacman/yay will install it, *increasing* installation time. Add any additional repo/AUR packages to the 'packages' variable in monocleOS\_Installer.sh

You can invoke the installer with `INSTALL.sh /dev/SDX`, or by changing the installDisk variable in monocleOS\_Installer.sh and running that directly. All data on /dev/SDX will be very quickly wiped. Make sure you have checked and double checked the drive letter. The installer will check that there is enough space on the disk. If this is undesired, especially if you're using a virtual dynamic disk, remove the free space check lines in monocleOS\_Installer.sh, and specify the partition sizes explicitly, with their suffix (e.g. rootSize=25G).

If there are any changes you would like to make to the system, do it before rebooting. You will need to unlock the LUKS partition with the generated keyfile (by default found at /tmp/luksKey), and mount the required partitions. There is no way of getting unrestricted root access while booted into monocleOS, or at least that's the plan... If this is undesired, set a password for root and enable TTY switching (see [below](#other-quirks)), or modify sudoers to allow user elevated privileges.

### TL;DR

1. Download & boot [Arch installation media](https://www.archlinux.org/download/)
2. Install git: `pacman -Sy git`
3. Clone this repo: `git clone https://github.com/Zedeldi/monocleOS.git /tmp/monocleOS`
4. Create package archive: `cd /tmp/monocleOS/pkg; tar -czvf ../monocleOS.tar.gz *`
5. Start installation: `cd ../; ./INSTALL.sh /dev/sdX`, where /dev/sdX is the block device to install monocleOS

## Technical Specifications

monocleOS is, in essence, a preconfigured rice setup of Arch, with a one-click installer. It may not suit the average power user, but should be useful for those who want something that 'just works'™.

### Partitioning

monocleOS uses a LVM on LUKS approach for its partitioning layout. In the case of an MBR system, an MSDOS partition table is used; conversely, for UEFI, GPT is used.
The default filesystems and sizes are as follows - this can be configured in the installer:

- ESP, in case of UEFI system - FAT32, 550MB
- Boot - ext4, 500MB
- LUKS
  - LVM
    - Swap - size of total RAM
    - Root - ext4, 25G
    - Home - ext4, the rest

During installation, a random keyfile is generated for LUKS, and embedded into the unencrypted initramfs for the first boot. The user then creates a password, which replaces this keyfile. Note: the user's password, and the LUKS encryption key are the same; they are always handled together.

### Users

Users are configured to 'sandbox' various processes, such as the user's, updates and recovery operations. Each user has sudo access for specific purposes, as defined in sudoers.d. See the note above regarding the user's password.

### Desktop

The launcher, xlunch, can be found here: <https://github.com/Tomas-M/xlunch>. Compiled binaries are provided within the monocleOS package. The source code for these can be found in `pkg/src/xlunch_data/src/`. The only differences between xlunch & xlunch_menu is the window title, in order to allow i3 to differentiate between them - making the menu launcher 'float'.

Polybar is used for the status bar at the top of the screen. This provides a consistent UI, where an 'exit' button, and menu-based application launcher can always be found.

i3-gaps is used as the window manager, as it provides an ideal, one-app-at-a-time interface, perfect for simple tasks.
- The 'float' button can be used to create a layered window environment.
- i3's layout can be changed from Polybar too.
- Basic i3 keybindings are used, to close apps, lock the X session, and start various applications.

See [credits](#credits).

### Bootloader

Currently, monocleOS uses grub-silent, in order to supress various messages that GRUB produces. Secure boot is supported through preloader-signed for EFI systems, though GRUB must be enrolled on the first boot. In the case of a 32-bit UEFI system, grub-silent will need to be compiled accordingly by setting the architecture within its PKGBUILD.

### Services

Enabled systemd services:
- NetworkManager
- ntpd
- avahi-daemon
- org.cups.cupsd
- automatic-update.timer
- linux-modules-cleanup
- clamav-freshclam
- clamav-daemon
- clamav-scan.timer
- apparmor
- preload

From the user's .xinitrc and i3 configuration, the following are executed:
- picom
- gnome-screensaver
- xss-lock
- dunst
- tips-service
- i3
  - polybar
  - xlunch

### Recovery

Currently, the options for recovery are somewhat limited, but sufficient. A recovery user is created, which the user can switch to, with the correct 'recovery key' - namely, the recovery user's password. Note: 'recovery' is only permitted to perform specific actions as root - see Users. This recovery key is also added as a key to the LUKS partition.

Through elevated privileges, the user's password can then be changed, and further the LUKS partition password. For this reason, the generated recovery key must be kept safe.

Additional options include a factory reset, and reinstallation of system packages. These can be done without the recovery key, although factory resetting requires the user's password instead.

#### Chroot

If the LUKS password is known, one can gain access to the install by booting up an external OS and opening the LUKS partition using `cryptsetup open /dev/sdXY`. Then, after mounting /dev/monocleOS/System, you can chroot into it, change a password, and perform system maintenance.

## Other Quirks

TTY switching with Ctrl+Alt+{1-6} is locked from Xorg, to prevent unwanted, unexpected TTY switching. This can be disabled by removing /etc/X11/xorg.conf.d/50-lockdown.conf.

The root account is locked; you will need to create a password from an external boot device (see [chroot](#chroot)) or during [installation](#installation).

Wine is installed by default, and can be used from Settings > Advanced. This is very dependency heavy, however, due to the required 32-bit libraries. If you are unlikely to need this, it may be worth removing this functionality.

## Limitations

Arch is famously known for its bleeding-edge updates. While this does increase the roll-out of security patches, which is essential for older computer users, it also increases the risk of new bugs - hence a limitation. If someone is willing to create a Debian-based, etc. build of monocleOS, they are more than welcome to! The main processes that should need to changed is bootstrapping the base OS, and references to packages and package management. Admittedly, the predominant reason for the use of Arch was my familiarity with its setup.

### Security Considerations

Due to the automatic login setup (in order to avoid entering the LUKS password, then the user's password), if an attacker could kill the user's xorg process, an unlocked session would be handed to them. A complete solution to this would be a customised getty-like service, which handles the user's login session. DontZap is set in /etc/X11/xorg.conf.d/50-lockdown.conf to prevent killing Xorg with Ctrl+Alt+Bksp.

Block encryption only protects data while it is locked, e.g. physical theft; while the machine is powered on, data is protected by access permissions and enforced by AppArmor. EncFS could be of use for the user's /home folders, such as Documents. Additional profiles for user applications should be written for AppArmor - this is on the [todo](#todo) list.

Furthermore, during a factory reset, the LUKS master key is never actually changed... only keyslots to unlock the device. Ideally, the LUKS parititon should be completely reformatted, but due to the parititoning scheme used, this cannot happen while online, as the root partition resides here. If the recovery environment was a separate OS, e.g. installed on a separate partition, then a complete reinstall could occur, even from a chroot. As a workaround for this issue, users have the option to `shred` files within /home. Alternatively, the partitioning configuration could be changed to have /home on a separate LUKS device, though this would incur additional overheads.

The user is allowed to execute any command as recovery, but recovery can only execute certain programs, such as `chpasswd`, `pacman`, and `true`, as root. However, this means that, with the recovery key, a malicious person could install *any* package or change *any* password as root through privilege escalation. This could be mitigated by restricting sudo permissions further to more limited actions, e.g. only allow the install of packages which are in a predefined list. On the other hand, this is to a no greater extent when compared with other operating systems; if an attacker has the user's (often with root/administrator rights) password, then they can change pretty much anything. Keep all passwords and recovery keys safe!

### Known Bugs

Occasionally, on the first boot, Plymouth does not display the splash screen correctly, but rather its fallback. I believe this is due to missing graphics modules from the initramfs, which are added on the next `mkinitcpio` in `initMonocle`, but I am not too sure.

The layout of Polybar and xlunch does not work amazingly well on monitor resolutions less than or equal to 800x600, without manual configuration - such as reducing vertical icon spacing in Settings. This could be configured on first boot by checking the output of xrandr and configuring accordingly.

### Reporting Bugs

If you find more ~~bad coding~~ mishaps, please let me know, and I'll try to figure something out when I'm bored. Any suggestions are welcome! Attach as many relevant logs, screenshots, etc. as possible - Note: when installing, the `INSTALL.sh` script will output to `monocleOS_Install.log`.

## Todo

- Make a graphical installer, possibly using whiptail to minimise dependencies & size
- ~~Add support for detecting devices and installing specific drivers, e.g. `if $(lspci | grep -iq 'nvidia'); then pacman -S nvidia; fi`~~
  - ~~Add kernel modules, e.g. `MODULES=(nvidia nvidia_modeset nvidia_uvm nvidia_drm)`, to mkinitcpio.conf for early KMS~~
- Improve support for tablets and touchscreen devices, e.g. on-screen keyboard. See <https://wiki.archlinux.org/index.php/Tablet_PC>, <https://github.com/ssmolkin1/i3touchmenu> & <https://launchpad.net/onboard>
- AppArmor profiles

## License

monocleOS is licensed under the [GNU GPL v3](https://www.gnu.org/licenses/gpl-3.0-standalone.html), ensuring the freedom to distribute, modify, and inspect its source code, with the conditions that all significant changes must be specified, the original be included/referenced, and all derivatives must also be licensed by the GPL v3, protecting the same freedoms of other users. Due to the nature of this project, install instructions must always be provided to prevent '[tivoization](http://en.wikipedia.org/wiki/Tivoization)'.

I am not responsible for any damages, data loss or thermonuclear war caused by this software. (How did you even start thermonuclear war with this?!)

This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

[![GPL v3 Logo](../assets/GPLv3_Logo.png?raw=true)](https://www.gnu.org/licenses/gpl-3.0-standalone.html)

Please note that packages used within monocleOS (not contained within this repository) may use their own licenses; you agree to those terms separately by installing the packages referenced at installation. Their sources or upstream URLs can be found on the [Arch official repos](https://www.archlinux.org/packages/) or within their respective PKGBUILD. See [below](#credits) for the most important contributors, and where to find them.

## Credits

This project could not exist without the following open-source applications (thank you!):

Arch Linux = <https://www.archlinux.org/>

GNU = <https://www.gnu.org/>

Linux = <https://www.kernel.org/>, <https://www.linuxfoundation.org/>

GNOME Project = <https://www.gnome.org/>

LibreOffice = <https://www.libreoffice.org/>

VLC = <https://www.videolan.org/vlc/>

Launcher = <https://github.com/Tomas-M/xlunch>

WM = <https://i3wm.org/>, <https://github.com/i3/i3>, (i3-gaps fork: <https://github.com/Airblader/i3>)

Status bar = <https://polybar.github.io/>, <https://github.com/polybar/polybar>

Notifications = <https://dunst-project.org/>, <https://github.com/dunst-project/dunst>

Boot animation = <https://www.freedesktop.org/wiki/Software/Plymouth/>, <https://gitlab.freedesktop.org/plymouth/plymouth>

Theme:
- Wallpapers = <https://github.com/GNOME/gnome-backgrounds>
- GTK = <https://github.com/arc-design/arc-theme>
- Icons = <https://github.com/numixproject/numix-icon-theme-circle>
- Plymouth = <https://github.com/numixproject/numix-plymouth-theme>

Please see the 'packages' variable in monocleOS_Installer.sh or '/var/recovery/packages.txt' for a complete list.

## Donate

If you found monocleOS useful, and would like to make a donation, you're an awesome person. Please consider donating to the [above projects](#credits) first, as without them, monocleOS would not be possble. Donations to [Cancer Research UK](https://www.cancerresearchuk.org/) would be greatly treasured personally, as this charity holds a special place in my heart. Thank you!

My bitcoin address is: [bc1q5aygkqypxuw7cjg062tnh56sd0mxt0zd5md536](bitcoin://bc1q5aygkqypxuw7cjg062tnh56sd0mxt0zd5md536)

[![Bitcoin](../assets/bitcoin.png?raw=true)](bitcoin://bc1q5aygkqypxuw7cjg062tnh56sd0mxt0zd5md536)

“We make a living by what we get. We make a life by what we give.” ― Winston Churchill
