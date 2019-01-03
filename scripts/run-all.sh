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

 exec "$@"
