# RTscripts (DEPRECATED/OUTDATED)
Here you will find a few scripts I wrote a few years back. I leave them here for a nostalgic purpose.
Please use all the scripts with caution. I'm a one man project at the moment... 

## Dependencies
I add a function to all scripts that checks dependencies on execution and installs them. The main thing is, that I always use the latest stable version of Debian for development and for daily use. For my single board computers I use *[Armbian](https://www.armbian.com)*


## Backup and Recovery
These scripts should help you with managing full images of your single board computer.
The goal is that you can backup your whole device including the bootloader, compressing it to the smallest possible version of an image and document it. You can then recover the backup to any sdCard or emmc storage you want. With a network share you could use a SD-card as backup device for emmc storage. You will find articles about that on my [blog](https://blog.rothirsch.tech/SBCs/scripts)

### RTbackup.sh (BETA)
Use this script to backup the SD-card of your SBC 

### RTrecovery.sh (BETA)
Recover the backups made with RTbackup.sh

### Compatibility 
\| Device | State | Image |
\| --- | --- | --- |
\| bpi-m1+ | tested  | https://www.armbian.com/banana-pi-plus/ |
\| bpi-m64 | tested  | https://www.armbian.com/bananapi-m64/ |
\| bpi-m3 | tested | https://drive.google.com/open?id=0B_YnvHgh2rwjdlN4bVFZVzd3YlE |
\| bpi-m64 | tested  | https://drive.google.com/open?id=0B_YnvHgh2rwjazlNRTRHei1NbmM |
