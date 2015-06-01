#!/bin/bash

sudo qemu-system-arm -kernel kernel-qemu -cpu arm1176 -M \
versatilepb -no-reboot -append "root=/dev/sda2 panic=1" \
-hda ../os_orig/2015-02-16-raspbian-wheezy.img -m 1024
