---
title: "chaser // how to create a bootable Windows USB from macOS"
subtitle: "Using nothing but the terminal"
author: "devsjc"
date: "2024-11-29"
tags: [sysadmin]
---

I was stuck in a bind recently: I needed to repair a broken Windows installation, and the
recommended method for doing so was via a bootable Windows USB - fine, I've created plenty of live
USBs before. But Windows USBs are easiest to create from Windows itself, and the only Windows
machine I have is the aforementioned broken one; everything else is either an Apple Silicon Mac or
some Linux distribution.

A frantic search brings up many guides saying to install some graphical tool or other, which may or
may not work on apple silicon and almost certainly will block you behind a paywall before you can
create a USB. The reason these are suggested over the standard practice of copying the installation
files onto a freshly-formatted USB is that bootable Windows USBs must be FAT32 formatted, and FAT32
has a maximum file size of 4GB - smaller than the size of one of the files within the Windows
installation media.

Luckily there is a tool, freely available on Apple Silicon via [Homebrew](https://brew.sh/), that
can split these files into smaller chunks before copying them to the USB. Here is the successful
process I eventually followed:

1. Firstly, download the Windows installation media from [Microsoft](https://www.microsoft.com/en-gb/software-download/windows10iso).
   This will be a `.iso` file.
2. Then, get a spare USB stick, greater than 8GB in size. Don't use one with anything you care
   about on it, as it will get wiped in the process! Plug it in. 
3. From your terminal, find the mount point for the USB via
   ```
   $ diskutil list
   ```
   It should be easy to tell via the size of the USB (it's likely the smallest in your machine);
   but if you're unsure, unplug the USB, run `diskutil list`, plug the USB back in, and run
   `diskutil list` again - the disk that isn't common to both outputs is the USB. In my case it
   was `/dev/disk4`.
4. Format the USB to FAT32 via
   ```
   $ diskutil eraseDisk MS-DOS "WIN10" GPT /dev/disk4
   ```
   This renames the disk to `WIN10` and completely erases it.
5. Mount both the `.iso` file and the USB stick via
   ```
   $ hdiutil mount ~/Downloads/Win10_22H2_English_x64v1.iso
   $ diskutil mount /dev/disk4
   ```
   Change the path in the first command to the relevant path to your Windows ISO, and the disk in
   the second command to the disk you found in step 3.
6. Copy all the files from the mounted ISO, except the `install.wim` file - this is the one that is
   too large for FAT32. You can do this via
   ```
   rsync -vha --exclude=sources/install.wim "/Volumes/CCCOMA_X64FRE_EN-US_DV9/" /Volumes/WIN10
   ```
   Change the paths as necessary to the mountpoints of the image and the disk, respectively.
7. Now it's time to deal with the overly large `install.wim` file. This is where the `wimlib` tool
   comes in. Install it via
   ```
   $ brew install wimlib
   ```
   Then split the file and copy the splits to the USB via
   ```
   $ wimlib-imagex split /Volumes/CCCOMA_X64FRE_EN-US_DV9/sources/install.wim /Volumes/WIN10/sources/install.swm 4000
   ```
   4000 being the maximum size of each split in MB, as determined by the limitations of FAT32.
8. Finally, unmount the ISO and the USB via
   ```
   $ hdiutil unmount /Volumes/CCCOMA_X64FRE_EN-US_DV9
   $ diskutil unmount /Volumes/WIN10
   ```

Now you've got a live Windows USB for all your installing and repairing needs! (As it happens, I
wasn't even able to repair the broken Windows installation with it in the end, but at least I
learned something useful...)

