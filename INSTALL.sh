#!/bin/bash
logFile="monocleOS_Install.log"
touch $logFile
if [ -z "$1" ]; then
	echo "$@ - Usage: ./INSTALL.sh /path/to/disk"
	exit 1
else
	installDisk="$1"
fi
sudo ./monocleOS_Installer.sh $installDisk > $logFile 2>&1 &
tail -f $logFile
