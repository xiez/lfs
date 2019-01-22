#!/bin/bash
set -e
echo "Running build.."

# ch6.2 Preparing Virtual Kernel File Systems
mkdir -pv $LFS/{dev,proc,sys,run}

mknod -m 600 $LFS/dev/console c 5 1
mknod -m 666 $LFS/dev/null c 1 3

mount -v --bind /dev $LFS/dev

mount -vt devpts devpts $LFS/dev/pts -o gid=5,mode=620
mount -vt proc proc $LFS/proc
mount -vt sysfs sysfs $LFS/sys
mount -vt tmpfs tmpfs $LFS/run

if [ -h $LFS/dev/shm ]; then
  mkdir -pv $LFS/$(readlink $LFS/dev/shm)
fi

# 6.4 Entering the Chroot Environment
chroot "$LFS" /tools/bin/env -i                 \
  HOME=/root         \
  TERM="$TERM" \
  PS1='(lfs chroot) \u:\w\$ ' \
  PATH=/bin:/usr/bin:/sbin:/usr/sbin:/tools/bin \
  /tools/bin/bash --login +h \
  -c "sh /tools/as-chroot-with-tools.sh"

chroot "$LFS" /tools/bin/env -i                 \
  HOME=/root         \
  TERM="$TERM" \
  PS1='(lfs chroot) \u:\w\$ ' \
  PATH=/bin:/usr/bin:/sbin:/usr/sbin  \
  /bin/bash --login +h \
  -c "sh /tools/as-chroot-with-usr.sh"

# iso image
echo "Start building bootable image.."

pushd /tmp
mkdir isolinux

wget https://www.kernel.org/pub/linux/utils/boot/syslinux/syslinux-6.03.tar.xz
tar -xf ./syslinux-*.tar.xz -C /tmp/
mv /tmp/syslinux-6.03 /tmp/syslinux
cp /tmp/syslinux/bios/core/isolinux.bin isolinux/isolinux.bin
cp /tmp/syslinux/bios/com32/elflink/ldlinux/ldlinux.c32 isolinux/ldlinux.c32
rm -rf /tmp/syslinux*

cat > isolinux/isolinux.cfg <<"EOF"
PROMT 0

DEFAULT arch

LABEL arch
    KERNEL vmlinuz
    APPEND initrd=ramdisk.img root=/dev/ram0 3
EOF


# IMAGE_SIZE=800000
# LOOP=/dev/loop1
# LOOP_DIR=$(pwd)/$LOOP
# RAMDISK=$(pwd)/ramdisk

# dd if=/dev/zero of=$RAMDISK bs=1k count=$IMAGE_SIZE
# losetup $LOOP $RAMDISK
# mke2fs -q -i 16384 -m 0 $LOOP $IMAGE_SIZE
# [ -d $LOOP_DIR ] || mkdir -pv $LOOP_DIR
# mount $LOOP $LOOP_DIR
# rm -rf $LOOP_DIR/lost+found

# pushd /mnt/lfs
# cp -dpR $(ls -A | grep -Ev "sources|tools") $LOOP_DIR
# popd






exec "$@"
