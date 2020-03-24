#!/bin/sh
# this stuff is hard coded
# real life we would have a disk set up with data so we don't have to do this
# or we do this a smarter/better way
echo "--------- DISK HACK ---------"
DISK=$(sudo lsblk|grep 100|awk '{print $1}')
sudo mkfs.ext4 -m 0 -E lazy_itable_init=0,lazy_journal_init=0,discard /dev/$DISK
sudo mkdir -p /data
sudo mount -o discard,defaults /dev/$DISK /data
echo ""
echo "----------- DISKS -----------"
echo "running 'df -h'"
df -h
echo ""
echo "-----------------------------"
echo "partitions you care about"
echo ""
df -h |grep sd
