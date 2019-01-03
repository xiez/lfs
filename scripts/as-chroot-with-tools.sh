#!/bin/bash
set -e
echo "Continue with chroot environment.."
export MAKEFLAGS='-j 4'

# 6.5 Creating Directories
mkdir -pv /{bin,boot,etc/{opt,sysconfig},home,lib/firmware,mnt,opt}
mkdir -pv /{media/{floppy,cdrom},sbin,srv,var}
install -dv -m 0750 /root
install -dv -m 1777 /tmp /var/tmp
mkdir -pv /usr/{,local/}{bin,include,lib,sbin,src}
mkdir -pv /usr/{,local/}share/{color,dict,doc,info,locale,man}
mkdir -pv /usr/{,local/}share/{misc,terminfo,zoneinfo}
mkdir -pv /usr/libexec
mkdir -pv /usr/{,local/}share/man/man{1..8}

case $(uname -m) in
  x86_64) mkdir -v /lib64 ;;
esac

mkdir -v /var/{log,mail,spool}
ln -sv /run /var/run
ln -sv /run/lock /var/lock
mkdir -pv /var/{opt,cache,lib/{color,misc,locate},local}

# 6.6 Creating Essential Files and Symlinks
ln -sv /tools/bin/{bash,cat,dd,echo,ln,pwd,rm,stty} /bin
ln -sv /tools/bin/{install,perl} /usr/bin
ln -sv /tools/lib/libgcc_s.so{,.1} /usr/lib
ln -sv /tools/lib/libstdc++.{a,so{,.6}} /usr/lib
for lib in blkid lzma mount uuid
do
  ln -sv /tools/lib/lib$lib.{a,so*} /usr/lib
done
ln -svf /tools/include/blkid    /usr/include
ln -svf /tools/include/libmount /usr/include
ln -svf /tools/include/uuid     /usr/include
install -vdm755 /usr/lib/pkgconfig
for pc in blkid mount uuid
do
    sed 's@tools@usr@g' /tools/lib/pkgconfig/${pc}.pc \
        > /usr/lib/pkgconfig/${pc}.pc
done
ln -sv bash /bin/sh

ln -sv /proc/self/mounts /etc/mtab

cat > /etc/passwd <<"EOF"
root:x:0:0:root:/root:/bin/bash
bin:x:1:1:bin:/dev/null:/bin/false
daemon:x:6:6:Daemon User:/dev/null:/bin/false
messagebus:x:18:18:D-Bus Message Daemon User:/var/run/dbus:/bin/false
nobody:x:99:99:Unprivileged User:/dev/null:/bin/false
EOF

cat > /etc/group <<"EOF"
root:x:0:
bin:x:1:daemon
sys:x:2:
kmem:x:3:
tape:x:4:
tty:x:5:
daemon:x:6:
floppy:x:7:
disk:x:8:
lp:x:9:
dialout:x:10:
audio:x:11:
video:x:12:
utmp:x:13:
usb:x:14:
cdrom:x:15:
adm:x:16:
messagebus:x:18:
systemd-journal:x:23:
input:x:24:
mail:x:34:
nogroup:x:99:
users:x:999:
EOF

# exec /tools/bin/bash --login +h

touch /var/log/{btmp,lastlog,faillog,wtmp}
chgrp -v utmp /var/log/lastlog
chmod -v 664 /var/log/lastlog
chmod -v 600 /var/log/btmp

# 6.7 Linux API Headers
tar -xf /sources/linux-*.tar.xz -C /tmp/ \
  && mv /tmp/linux-* /tmp/linux \
  && pushd /tmp/linux

make mrproper
make INSTALL_HDR_PATH=dest headers_install
find dest/include \( -name .install -o -name ..install.cmd \) -delete
cp -rv dest/include/* /usr/include

popd \
  && rm -rf /tmp/linux

# 6.8 Man pages
tar -xf /sources/man-pages-*.tar.xz -C /tmp/ \
  && mv /tmp/man-pages-* /tmp/man-pages \
  && pushd /tmp/man-pages

make install

popd \
  && rm -rf /tmp/man-pages

# 6.9 Glibc
tar -xf /sources/glibc-*.tar.xz -C /tmp/ \
 && mv /tmp/glibc-* /tmp/glibc \
 && pushd /tmp/glibc

patch -Np1 -i /sources/glibc-2.28-fhs-1.patch
ln -sfv /tools/lib/gcc /usr/lib

case $(uname -m) in
    i?86)    GCC_INCDIR=/usr/lib/gcc/$(uname -m)-pc-linux-gnu/8.2.0/include
            ln -sfv ld-linux.so.2 /lib/ld-lsb.so.3
    ;;
    x86_64) GCC_INCDIR=/usr/lib/gcc/x86_64-pc-linux-gnu/8.2.0/include
            ln -sfv ../lib/ld-linux-x86-64.so.2 /lib64
            ln -sfv ../lib/ld-linux-x86-64.so.2 /lib64/ld-lsb-x86-64.so.3
    ;;
esac

rm -f /usr/include/limits.h

mkdir -v build
cd build

CC="gcc -isystem $GCC_INCDIR -isystem /usr/include" \
../configure --prefix=/usr                          \
             --disable-werror                       \
             --enable-kernel=3.2                    \
             --enable-stack-protector=strong        \
             libc_cv_slibdir=/lib
unset GCC_INCDIR
make
if [ $LFS_TEST -eq 1 ]; then make check || true; fi

touch /etc/ld.so.conf
sed '/test-installation/s@$(PERL)@echo not running@' -i ../Makefile

make install
cp -v ../nscd/nscd.conf /etc/nscd.conf
mkdir -pv /var/cache/nscd

mkdir -pv /usr/lib/locale
localedef -i cs_CZ -f UTF-8 cs_CZ.UTF-8
localedef -i de_DE -f ISO-8859-1 de_DE
localedef -i de_DE@euro -f ISO-8859-15 de_DE@euro
localedef -i de_DE -f UTF-8 de_DE.UTF-8
localedef -i en_GB -f UTF-8 en_GB.UTF-8
localedef -i en_HK -f ISO-8859-1 en_HK
localedef -i en_PH -f ISO-8859-1 en_PH
localedef -i en_US -f ISO-8859-1 en_US
localedef -i en_US -f UTF-8 en_US.UTF-8
localedef -i es_MX -f ISO-8859-1 es_MX
localedef -i fa_IR -f UTF-8 fa_IR
localedef -i fr_FR -f ISO-8859-1 fr_FR
localedef -i fr_FR@euro -f ISO-8859-15 fr_FR@euro
localedef -i fr_FR -f UTF-8 fr_FR.UTF-8
localedef -i it_IT -f ISO-8859-1 it_IT
localedef -i it_IT -f UTF-8 it_IT.UTF-8
localedef -i ja_JP -f EUC-JP ja_JP
localedef -i ru_RU -f KOI8-R ru_RU.KOI8-R
localedef -i ru_RU -f UTF-8 ru_RU.UTF-8
localedef -i tr_TR -f UTF-8 tr_TR.UTF-8
localedef -i zh_CN -f GB18030 zh_CN.GB18030

popd
rm -rf /tmp/glibc

cat > /etc/nsswitch.conf <<"EOF"
# Begin /etc/nsswitch.conf

passwd: files
group: files
shadow: files

hosts: files dns
networks: files

protocols: files
services: files
ethers: files
rpc: files

# End /etc/nsswitch.conf
EOF

mkdir /tmp/tzdata \
  && tar -xf /sources/tzdata*.tar.gz -C /tmp/tzdata \
  && pushd /tmp/tzdata

ZONEINFO=/usr/share/zoneinfo
mkdir -pv $ZONEINFO/{posix,right}

for tz in etcetera southamerica northamerica europe africa antarctica  \
          asia australasia backward pacificnew systemv; do
    zic -L /dev/null   -d $ZONEINFO       -y "sh yearistype.sh" ${tz}
    zic -L /dev/null   -d $ZONEINFO/posix -y "sh yearistype.sh" ${tz}
    zic -L leapseconds -d $ZONEINFO/right -y "sh yearistype.sh" ${tz}
done

cp -v zone.tab zone1970.tab iso3166.tab $ZONEINFO
zic -d $ZONEINFO -p America/New_York
unset ZONEINFO

popd && \
  rm -rf /tmp/tzdata

ln -sfv /usr/share/zoneinfo/Europe/Berlin /etc/localtime

cat > /etc/ld.so.conf <<"EOF"
# Begin /etc/ld.so.conf
/usr/local/lib
/opt/lib
EOF

cat >> /etc/ld.so.conf <<"EOF"
# Add an include directory
include /etc/ld.so.conf.d/*.conf
EOF
mkdir -pv /etc/ld.so.conf.d

# 6.10 Adjusting the Toolchain
mv -v /tools/bin/{ld,ld-old}
mv -v /tools/$(uname -m)-pc-linux-gnu/bin/{ld,ld-old}
mv -v /tools/bin/{ld-new,ld}
ln -sv /tools/bin/ld /tools/$(uname -m)-pc-linux-gnu/bin/ld

gcc -dumpspecs | sed -e 's@/tools@@g'                 \
  -e '/\*startfile_prefix_spec:/{n;s@.*@/usr/lib/ @}' \
  -e '/\*cpp:/{n;s@$@ -isystem /usr/include@}' >      \
  `dirname $(gcc --print-libgcc-file-name)`/specs

echo 'int main(){}' > dummy.c
cc dummy.c -v -Wl,--verbose &> dummy.log
readelf -l a.out | grep ': /lib'
grep -o '/usr/lib.*/crt[1in].*succeeded' dummy.log
grep -B1 '^ /usr/include' dummy.log
grep 'SEARCH.*/usr/lib' dummy.log |sed 's|; |\n|g'
grep "/lib.*/libc.so.6 " dummy.log
grep found dummy.log

rm -v dummy.c a.out dummy.log

# 6.11 Zlib
tar -xf /sources/zlib-*.tar.xz -C /tmp/ \
  && mv /tmp/zlib-* /tmp/zlib \
  && pushd /tmp/zlib

./configure --prefix=/usr
make
if [ $LFS_TEST -eq 1 ]; then make check; fi
make install
mv -v /usr/lib/libz.so.* /lib
ln -sfv ../../lib/$(readlink /usr/lib/libz.so) /usr/lib/libz.so

popd \
  && rm -rf /tmp/zlib

# 6.12 File
tar -xf /sources/file-*.tar.gz -C /tmp/ \
  && mv /tmp/file-* /tmp/file \
  && pushd /tmp/file

./configure --prefix=/usr
make
if [ $LFS_TEST -eq 1 ]; then make check; fi
make install

popd \
  && rm -rf /tmp/file

# 6.13 Readline
tar -xf /sources/readline-*.tar.gz -C /tmp/ \
  && mv /tmp/readline-* /tmp/readline \
  && pushd /tmp/readline

sed -i '/MV.*old/d' Makefile.in
sed -i '/{OLDSUFF}/c:' support/shlib-install
./configure --prefix=/usr \
    --disable-static      \
    --docdir=/usr/share/doc/readline-7.0
make SHLIB_LIBS="-L/tools/lib -lncursesw"
make SHLIB_LIBS="-L/tools/lib -lncurses" install

mv -v /usr/lib/lib{readline,history}.so.* /lib
chmod -v u+w /lib/lib{readline,history}.so.*
ln -sfv ../../lib/$(readlink /usr/lib/libreadline.so) /usr/lib/libreadline.so
ln -sfv ../../lib/$(readlink /usr/lib/libhistory.so ) /usr/lib/libhistory.so

if [ $LFS_DOCS -eq 1 ]; then
    install -v -m644 doc/*.{ps,pdf,html,dvi} /usr/share/doc/readline-7.0
fi

popd \
  && rm -rf /tmp/readline

# 6.14 M4
tar -xf /sources/m4-*.tar.xz -C /tmp/ \
  && mv /tmp/m4-* /tmp/m4 \
  && pushd /tmp/m4

sed -i 's/IO_ftrylockfile/IO_EOF_SEEN/' lib/*.c
echo "#define _IO_IN_BACKUP 0x100" >> lib/stdio-impl.h
./configure --prefix=/usr
make
if [ $LFS_TEST -eq 1 ]; then make check; fi
make install

popd \
  && rm -rf /tmp/m4

# 6.15 Bc
tar -xf /sources/bc-*.tar.gz -C /tmp/ \
  && mv /tmp/bc-* /tmp/bc \
  && pushd /tmp/bc

cat > bc/fix-libmath_h <<"EOF"
#! /bin/bash
sed -e '1   s/^/{"/' \
    -e     's/$/",/' \
    -e '2,$ s/^/"/'  \
    -e   '$ d'       \
    -i libmath.h

sed -e '$ s/$/0}/' \
    -i libmath.h
EOF

ln -sv /tools/lib/libncursesw.so.6 /usr/lib/libncursesw.so.6
ln -sfv libncurses.so.6 /usr/lib/libncurses.so

sed -i -e '/flex/s/as_fn_error/: ;; # &/' configure
./configure --prefix=/usr   \
  --with-readline           \
  --mandir=/usr/share/man   \
  --infodir=/usr/share/info
make
echo "quit" | ./bc/bc -l Test/checklib.b
make install

popd \
  && rm -rf /tmp/bc

# 6.16 Binutils
tar -xf /sources/binutils-*.tar.xz -C /tmp/ \
  && mv /tmp/binutils-* /tmp/binutils \
  && pushd /tmp/binutils

expect -c "spawn ls"
mkdir -v build
cd build
../configure --prefix=/usr       \
             --enable-gold       \
             --enable-ld=default \
             --enable-plugins    \
             --enable-shared     \
             --disable-werror    \
             --enable-64-bit-bfd \
             --with-system-zlib
make tooldir=/usr
if [ $LFS_TEST -eq 1 ]; then make -k check; fi
make tooldir=/usr install

popd \
  && rm -rf /tmp/binutils

# 6.17 GMP
tar -xf /sources/gmp-*.tar.xz -C /tmp/ \
  && mv /tmp/gmp-* /tmp/gmp \
  && pushd /tmp/gmp

./configure --prefix=/usr \
    --enable-cxx          \
    --disable-static      \
    --docdir=/usr/share/doc/gmp-6.1.2
make
make html
if [ $LFS_TEST -eq 1 ]; then
    make check 2>&1 | tee gmp-check-log
    awk '/# PASS:/{total+=$3} ; END{print total}' gmp-check-log
fi
make install
make install-html

popd \
  && rm -rf /tmp/gmp

# 6.18 MPFR
tar -xf /sources/mpfr-*.tar.xz -C /tmp/ \
  && mv /tmp/mpfr-* /tmp/mpfr \
  && pushd /tmp/mpfr

./configure --prefix=/usr        \
            --disable-static     \
            --enable-thread-safe \
            --docdir=/usr/share/doc/mpfr-4.0.1
make
make html
if [ $LFS_TEST -eq 1 ]; then make check; fi
make install
make install-html

popd \
  && rm -rf /tmp/mpfr

# 6.19 MPC
tar -xf /sources/mpc-*.tar.gz -C /tmp/ \
  && mv /tmp/mpc-* /tmp/mpc \
  && pushd /tmp/mpc

./configure --prefix=/usr    \
            --disable-static \
            --docdir=/usr/share/doc/mpc-1.1.0

make
make html
if [ $LFS_TEST -eq 1 ]; then make check; fi
make install
make install-html

popd \
  && rm -rf /tmp/mpc

# 6.20 Shadow
tar -xf /sources/shadow-*.tar.xz -C /tmp/ \
  && mv /tmp/shadow-* /tmp/shadow \
  && pushd /tmp/shadow

sed -i 's/groups$(EXEEXT) //' src/Makefile.in
find man -name Makefile.in -exec sed -i 's/groups\.1 / /'   {} \;
find man -name Makefile.in -exec sed -i 's/getspnam\.3 / /' {} \;
find man -name Makefile.in -exec sed -i 's/passwd\.5 / /'   {} \;
sed -i -e 's@#ENCRYPT_METHOD DES@ENCRYPT_METHOD SHA512@' \
       -e 's@/var/spool/mail@/var/mail@' etc/login.defs
sed -i 's/1000/999/' etc/useradd

./configure --sysconfdir=/etc --with-group-name-max-length=32
make
make install
mv -v /usr/bin/passwd /bin
popd \
  && rm -rf /tmp/shadow

# 6.21 GCC
tar -xf /sources/gcc-*.tar.xz -C /tmp/ \
  && mv /tmp/gcc-* /tmp/gcc \
  && pushd /tmp/gcc

case $(uname -m) in
  x86_64)
    sed -e '/m64=/s/lib64/lib/' \
        -i.orig gcc/config/i386/t-linux64
  ;;
esac

rm -f /usr/lib/gcc
mkdir -v build
cd       build

SED=sed                               \
../configure --prefix=/usr            \
             --enable-languages=c,c++ \
             --disable-multilib       \
             --disable-bootstrap      \
             --with-system-zlib
make

if [ $LFS_TEST -eq 1 ]; then
    ulimit -s 32768
    rm ../gcc/testsuite/g++.dg/pr83239.C
    chown -Rv nobody .
    su nobody -s /bin/bash -c "PATH=$PATH make -k check"
    ../contrib/test_summary | grep -A7 Summ
fi

make install
ln -sv ../usr/bin/cpp /lib
ln -sv gcc /usr/bin/cc
install -v -dm755 /usr/lib/bfd-plugins
ln -sfv ../../libexec/gcc/$(gcc -dumpmachine)/8.2.0/liblto_plugin.so \
        /usr/lib/bfd-plugins/

# echo 'int main(){}' > dummy.c
# cc dummy.c -v -Wl,--verbose &> dummy.log
# readelf -l a.out | grep ': /lib'
# grep -o '/usr/lib.*/crt[1in].*succeeded' dummy.log
# grep -B4 '^ /usr/include' dummy.log
# grep 'SEARCH.*/usr/lib' dummy.log |sed 's|; |\n|g'
# grep "/lib.*/libc.so.6 " dummy.log
# grep found dummy.log
# rm -v dummy.c a.out dummy.log

mkdir -pv /usr/share/gdb/auto-load/usr/lib
mv -v /usr/lib/*gdb.py /usr/share/gdb/auto-load/usr/lib

popd \
  && rm -rf /tmp/gcc

# 6.22 Bzip
tar -xf /sources/bzip2-*.tar.gz -C /tmp/ \
  && mv /tmp/bzip2-* /tmp/bzip2 \
  && pushd /tmp/bzip2

patch -Np1 -i /sources/bzip2-1.0.6-install_docs-1.patch
sed -i 's@\(ln -s -f \)$(PREFIX)/bin/@\1@' Makefile
sed -i 's@\(ln -s -f \)$(PREFIX)/bin/@\1@' Makefile
make -f Makefile-libbz2_so
make clean

make
make PREFIX=/usr install

cp -v bzip2-shared /bin/bzip2
cp -av libbz2.so* /lib
ln -sv ../../lib/libbz2.so.1.0 /usr/lib/libbz2.so
rm -v /usr/bin/{bunzip2,bzcat,bzip2}
ln -sv bzip2 /bin/bunzip2
ln -sv bzip2 /bin/bzcat

popd \
  && rm -rf /tmp/bzip2

# 6.23 Pkg-config
tar -xf /sources/pkg-config-*.tar.gz -C /tmp/ \
  && mv /tmp/pkg-config-* /tmp/pkg-config \
  && pushd /tmp/pkg-config

./configure --prefix=/usr \
    --with-internal-glib  \
    --disable-host-tool   \
    --docdir=/usr/share/doc/pkg-config-0.29.2
make
if [ $LFS_TEST -eq 1 ]; then make check; fi
make install

popd \
  && rm -rf /tmp/pkg-config

# 6.24 Ncurses
tar -xf /sources/ncurses-*.tar.gz -C /tmp/ \
  && mv /tmp/ncurses-* /tmp/ncurses \
  && pushd /tmp/ncurses

sed -i '/LIBTOOL_INSTALL/d' c++/Makefile.in
./configure --prefix=/usr   \
    --mandir=/usr/share/man \
    --with-shared           \
    --without-debug         \
    --without-normal        \
    --enable-pc-files       \
    --enable-widec

make
make install
mv -v /usr/lib/libncursesw.so.6* /lib
ln -sfv ../../lib/$(readlink /usr/lib/libncursesw.so) /usr/lib/libncursesw.so
for lib in ncurses form panel menu ; do
  rm -vf                      /usr/lib/lib${lib}.so
  echo "INPUT(-l${lib}w)" >   /usr/lib/lib${lib}.so
  ln -sfv ${lib}w.pc          /usr/lib/pkgconfig/${lib}.pc
done
rm -vf                     /usr/lib/libcursesw.so
echo "INPUT(-lncursesw)" > /usr/lib/libcursesw.so
ln -sfv libncurses.so      /usr/lib/libcurses.so

mkdir -v /usr/share/doc/ncurses-6.1
cp -v -R doc/* /usr/share/doc/ncurses-6.1

popd \
  && rm -rf /tmp/ncurses

# 6.25 Attr
tar -xf /sources/attr-*.tar.gz -C /tmp/ \
  && mv /tmp/attr-* /tmp/attr \
  && pushd /tmp/attr

./configure --prefix=/usr \
    --bindir=/bin \
    --disable-static \
    --sysconfdir=/etc \
    --docdir=/usr/share/doc/attr-2.4.48

make
if [ $LFS_TEST -eq 1 ]; then make -j1 tests root-tests; fi
make install

mv -v /usr/lib/libattr.so.* /lib
ln -sfv ../../lib/$(readlink /usr/lib/libattr.so) /usr/lib/libattr.so

popd \
  && rm -rf /tmp/attr

# 6.26 Acl
tar -xf /sources/acl-*.tar.gz -C /tmp/ \
  && mv /tmp/acl-* /tmp/acl \
  && pushd /tmp/acl

./configure --prefix=/usr    \
    --bindir=/bin            \
    --disable-static         \
    --libexecdir=/usr/lib    \
    --docdir=/usr/share/doc/acl-2.2.53

make
make install

mv -v /usr/lib/libacl.so.* /lib
ln -sfv ../../lib/$(readlink /usr/lib/libacl.so) /usr/lib/libacl.so

popd \
  && rm -rf /tmp/acl

# 6.27 Libcap
tar -xf /sources/libcap-*.tar.xz -C /tmp/ \
  && mv /tmp/libcap-* /tmp/libcap \
  && pushd /tmp/libcap

sed -i '/install.*STALIBNAME/d' libcap/Makefile
make
make RAISE_SETFCAP=no lib=lib prefix=/usr install
chmod -v 755 /usr/lib/libcap.so

mv -v /usr/lib/libcap.so.* /lib
ln -sfv ../../lib/$(readlink /usr/lib/libcap.so) /usr/lib/libcap.so

popd \
  && rm -rf /tmp/libcap

# 6.28 Sed
tar -xf /sources/sed-*.tar.xz -C /tmp/ \
  && mv /tmp/sed-* /tmp/sed \
  && pushd /tmp/sed

sed -i 's/usr/tools/'                 build-aux/help2man
sed -i 's/testsuite.panic-tests.sh//' Makefile.in
./configure --prefix=/usr --bindir=/bin

make
make html

if [ $LFS_TEST -eq 1 ]; then make check; fi
make install
install -d -m755           /usr/share/doc/sed-4.5
install -m644 doc/sed.html /usr/share/doc/sed-4.5

popd \
  && rm -rf /tmp/sed

# 6.29 Psmisc
tar -xf /sources/psmisc-*.tar.xz -C /tmp/ \
  && mv /tmp/psmisc-* /tmp/psmisc \
  && pushd /tmp/psmisc

./configure --prefix=/usr
make
make install
mv -v /usr/bin/fuser   /bin
mv -v /usr/bin/killall /bin

popd \
  && rm -rf /tmp/psmisc

# 6.30 Iana-Etc
tar -xf /sources/iana-etc-*.tar.bz2 -C /tmp/ \
  && mv /tmp/iana-etc-* /tmp/iana-etc \
  && pushd /tmp/iana-etc

make
make install
popd \
  && rm -rf /tmp/iana-etc

# 6.31 Bison
tar -xf /sources/bison-*.tar.xz -C /tmp/ \
  && mv /tmp/bison-* /tmp/bison \
  && pushd /tmp/bison

./configure --prefix=/usr --docdir=/usr/share/doc/bison-3.0.5
make
make install

popd \
  && rm -rf /tmp/bison

# 6.32 Flex
tar -xf /sources/flex-*.tar.gz -C /tmp/ \
  && mv /tmp/flex-* /tmp/flex \
  && pushd /tmp/flex

sed -i "/math.h/a #include <malloc.h>" src/flexdef.h
HELP2MAN=/tools/bin/true \
./configure --prefix=/usr --docdir=/usr/share/doc/flex-2.6.4

make
if [ $LFS_TEST -eq 1 ]; then make check; fi
make install

ln -sv flex /usr/bin/lex
popd \
  && rm -rf /tmp/flex

# 6.33 Grep
tar -xf /sources/grep-*.tar.xz -C /tmp/ \
  && mv /tmp/grep-* /tmp/grep \
  && pushd /tmp/grep

./configure --prefix=/usr --bindir=/bin
make
if [ $LFS_TEST -eq 1 ]; then make check; fi
make install
# cleanup
popd \
  && rm -rf /tmp/grep

# 6.34 Bash
tar -xf /sources/bash-*.tar.gz -C /tmp/ \
  && mv /tmp/bash-* /tmp/bash \
  && pushd /tmp/bash

./configure --prefix=/usr               \
    --docdir=/usr/share/doc/bash-4.4.18 \
    --without-bash-malloc               \
    --with-installed-readline

make

if [ $LFS_TEST -eq 1 ]; then
    # To prepare the tests, ensure that the nobody user can write to the sources tree
    chown -Rv nobody .
    # Now, run the tests as the nobody user:
    su nobody -s /bin/bash -c "PATH=$PATH make tests"
fi

make install
mv -vf /usr/bin/bash /bin
# exec /bin/bash --login +h

popd \
  && rm -rf /tmp/bash

# 6.35 Libtool
tar -xf /sources/libtool-*.tar.xz -C /tmp/ \
  && mv /tmp/libtool-* /tmp/libtool \
  && pushd /tmp/libtool

./configure --prefix=/usr
make

if [ $LFS_TEST -eq 1 ]; then make check  || true; fi
make install

popd \
  && rm -rf /tmp/libtool

# 6.36 GDBM
tar -xf /sources/gdbm-*.tar.gz -C /tmp/ \
  && mv /tmp/gdbm-* /tmp/gdbm \
  && pushd /tmp/gdbm

./configure --prefix=/usr   \
    --disable-static        \
    --enable-libgdbm-compat

make
if [ $LFS_TEST -eq 1 ]; then make check; fi
make install

popd \
  && rm -rf /tmp/gdbm

# 6.37 Gperf
tar -xf /sources/gperf-*.tar.gz -C /tmp/ \
  && mv /tmp/gperf-* /tmp/gperf \
  && pushd /tmp/gperf

./configure --prefix=/usr --docdir=/usr/share/doc/gperf-3.1

make
if [ $LFS_TEST -eq 1 ]; then make -j1 check; fi
make install

popd \
  && rm -rf /tmp/gperf

# 6.38 Expat
tar -xf /sources/expat-*.tar.bz2 -C /tmp/ \
  && mv /tmp/expat-* /tmp/expat \
  && pushd /tmp/expat

sed -i 's|usr/bin/env |bin/|' run.sh.in
./configure --prefix=/usr    \
            --disable-static \
            --docdir=/usr/share/doc/expat-2.2.6

make
if [ $LFS_TEST -eq 1 ]; then make check; fi
make install
install -v -m644 doc/*.{html,png,css} /usr/share/doc/expat-2.2.6

popd \
  && rm -rf /tmp/expat

# 6.39 Inetutils
tar -xf /sources/inetutils-*.tar.xz -C /tmp/ \
  && mv /tmp/inetutils-* /tmp/inetutils \
  && pushd /tmp/inetutils

./configure --prefix=/usr \
    --localstatedir=/var  \
    --disable-logger      \
    --disable-whois       \
    --disable-rcp         \
    --disable-rexec       \
    --disable-rlogin      \
    --disable-rsh         \
    --disable-servers

make
if [ $LFS_TEST -eq 1 ]; then make check || true; fi
make install
mv -v /usr/bin/{hostname,ping,ping6,traceroute} /bin
mv -v /usr/bin/ifconfig /sbin

popd \
  && rm -rf /tmp/inetutils

# 6.40 Perl
tar -xf /sources/perl-*.tar.xz -C /tmp/ \
  && mv /tmp/perl-* /tmp/perl \
  && pushd /tmp/perl

echo "127.0.0.1 localhost $(hostname)" > /etc/hosts
export BUILD_ZLIB=False
export BUILD_BZIP2=0

sh Configure -des -Dprefix=/usr   \
    -Dvendorprefix=/usr           \
    -Dman1dir=/usr/share/man/man1 \
    -Dman3dir=/usr/share/man/man3 \
    -Dpager="/usr/bin/less -isR"  \
    -Duseshrplib                  \
    -Dusethreads

make
if [ $LFS_TEST -eq 1 ]; then make -k test || true; fi
make install
unset BUILD_ZLIB BUILD_BZIP2

popd \
  && rm -rf /tmp/perl

# 6.41 XML::Parser
tar -xf /sources/XML-Parser-*.tar.gz -C /tmp/ \
  && mv /tmp/XML-Parser-* /tmp/XML-Parser \
  && pushd /tmp/XML-Parser

perl Makefile.PL

make
if [ $LFS_TEST -eq 1 ]; then make test; fi
make install
popd \
  && rm -rf /tmp/XML-Parser

# 6.42 Intitool
tar -xf /sources/intltool-*.tar.gz -C /tmp/ \
  && mv /tmp/intltool-* /tmp/intltool \
  && pushd /tmp/intltool

sed -i 's:\\\${:\\\$\\{:' intltool-update.in
./configure --prefix=/usr
make
make install
install -v -Dm644 doc/I18N-HOWTO /usr/share/doc/intltool-0.51.0/I18N-HOWTO

popd \
  && rm -rf /tmp/intltool

# 6.43 Autoconf
tar -xf /sources/autoconf-*.tar.xz -C /tmp/ \
  && mv /tmp/autoconf-* /tmp/autoconf \
  && pushd /tmp/autoconf

./configure --prefix=/usr
make
if [ $LFS_TEST -eq 1 ]; then make check || true; fi
make install

popd \
  && rm -rf /tmp/autoconf

# 6.44 Automake
tar -xf /sources/automake-*.tar.xz -C /tmp/ \
  && mv /tmp/automake-* /tmp/automake \
  && pushd /tmp/automake

./configure --prefix=/usr --docdir=/usr/share/doc/automake-1.16.1
make
if [ $LFS_TEST -eq 1 ]; then make -j4 check || true; fi
make install
popd \
  && rm -rf /tmp/automake

# 6.45 Xz
tar -xf /sources/xz-*.tar.xz -C /tmp/ \
  && mv /tmp/xz-* /tmp/xz \
  && pushd /tmp/xz

./configure --prefix=/usr      \
    --disable-static           \
    --docdir=/usr/share/doc/xz-5.2.4
make
if [ $LFS_TEST -eq 1 ]; then make check; fi
make install
mv -v /usr/bin/{lzma,unlzma,lzcat,xz,unxz,xzcat} /bin
mv -v /usr/lib/liblzma.so.* /lib
ln -svf ../../lib/$(readlink /usr/lib/liblzma.so) /usr/lib/liblzma.so

popd \
  && rm -rf /tmp/xz

# 6.46 Kmod
tar -xf /sources/kmod-*.tar.xz -C /tmp/ \
  && mv /tmp/kmod-* /tmp/kmod \
  && pushd /tmp/kmod

./configure --prefix=/usr   \
    --bindir=/bin           \
    --sysconfdir=/etc       \
    --with-rootlibdir=/lib  \
    --with-xz               \
    --with-zlib
make
make install

for target in depmod insmod lsmod modinfo modprobe rmmod; do
  ln -sfv ../bin/kmod /sbin/$target
done
ln -sfv kmod /bin/lsmod

popd \
  && rm -rf /tmp/kmod

# 6.47 Gettext
tar -xf /sources/gettext-*.tar.xz -C /tmp/ \
  && mv /tmp/gettext-* /tmp/gettext \
  && pushd /tmp/gettext

sed -i '/^TESTS =/d' gettext-runtime/tests/Makefile.in &&
sed -i 's/test-lock..EXEEXT.//' gettext-tools/gnulib-tests/Makefile.in
sed -e '/AppData/{N;N;p;s/\.appdata\./.metainfo./}' \
    -i gettext-tools/its/appdata.loc

./configure --prefix=/usr \
  --disable-static        \
  --docdir=/usr/share/doc/gettext-0.19.8.1

make
if [ $LFS_TEST -eq 1 ]; then make check; fi
make install
chmod -v 0755 /usr/lib/preloadable_libintl.so

popd \
  && rm -rf /tmp/gettext

# 6.48 Libelf
tar -xf /sources/elfutils-*.tar.bz2 -C /tmp/ \
  && mv /tmp/elfutils-* /tmp/elfutils \
  && pushd /tmp/elfutils

./configure --prefix=/usr
make
if [ $LFS_TEST -eq 1 ]; then make check || true; fi
make -C libelf install
install -vm644 config/libelf.pc /usr/lib/pkgconfig

popd \
  && rm -rf /tmp/elfutils

# 6.49 Libffi
tar -xf /sources/libffi-*.tar.gz -C /tmp/ \
  && mv /tmp/libffi-* /tmp/libffi \
  && pushd /tmp/libffi

sed -e '/^includesdir/ s/$(libdir).*$/$(includedir)/' \
    -i include/Makefile.in
sed -e '/^includedir/ s/=.*$/=@includedir@/' \
    -e 's/^Cflags: -I${includedir}/Cflags:/' \
    -i libffi.pc.in

./configure --prefix=/usr --disable-static
make
if [ $LFS_TEST -eq 1 ]; then make check || true; fi
make install

popd \
  && rm -rf /tmp/libffi

# 6.50 OpenSSL
tar -xf /sources/openssl-*.tar.gz -C /tmp/ \
  && mv /tmp/openssl-* /tmp/openssl \
  && pushd /tmp/openssl

./config --prefix=/usr         \
         --openssldir=/etc/ssl \
         --libdir=lib          \
         shared                \
         zlib-dynamic
make
if [ $LFS_TEST -eq 1 ]; then make test || true; fi
sed -i '/INSTALL_LIBS/s/libcrypto.a libssl.a//' Makefile
make MANSUFFIX=ssl install

popd \
  && rm -rf /tmp/openssl

# 6.51 Python
tar -xf /sources/Python-*.tar.xz -C /tmp/ \
  && mv /tmp/Python-* /tmp/python \
  && pushd /tmp/python

./configure --prefix=/usr       \
            --enable-shared     \
            --with-system-expat \
            --with-system-ffi   \
            --with-ensurepip=yes
make
make install
chmod -v 755 /usr/lib/libpython3.7m.so
chmod -v 755 /usr/lib/libpython3.so

popd \
  && rm -rf /tmp/python

# 6.52 Ninja
tar -xf /sources/ninja-*.tar.gz -C /tmp/ \
  && mv /tmp/ninja-* /tmp/ninja \
  && pushd /tmp/ninja

export NINJAJOBS=1
patch -Np1 -i /sources/ninja-1.8.2-add_NINJAJOBS_var-1.patch
python3 configure.py --bootstrap

if [ $LFS_TEST -eq 1 ]; then
    python3 configure.py
    ./ninja ninja_test
    ./ninja_test --gtest_filter=-SubprocessTest.SetWithLots || true
fi

install -vm755 ninja /usr/bin/
install -vDm644 misc/bash-completion /usr/share/bash-completion/completions/ninja
install -vDm644 misc/zsh-completion  /usr/share/zsh/site-functions/_ninja

popd \
  && rm -rf /tmp/ninja

# 6.53 Meson
tar -xf /sources/meson-*.tar.gz -C /tmp/ \
  && mv /tmp/meson-* /tmp/meson \
  && pushd /tmp/meson

python3 setup.py build
python3 setup.py install --root=dest
cp -rv dest/* /

popd \
  && rm -rf /tmp/meson

# 6.54 Procps-ng
tar -xf /sources/procps-ng-*.tar.xz -C /tmp/ \
  && mv /tmp/procps-ng-* /tmp/procps-ng \
  && pushd /tmp/procps-ng

./configure --prefix=/usr                   \
  --exec-prefix=                            \
  --libdir=/usr/lib                         \
  --docdir=/usr/share/doc/procps-ng-3.3.15  \
  --disable-static                          \
  --disable-kill
make

if [ $LFS_TEST -eq 1 ]; then
    sed -i -r 's|(pmap_initname)\\\$|\1|' testsuite/pmap.test/pmap.exp
    sed -i '/set tty/d'                   testsuite/pkill.test/pkill.exp
    rm testsuite/pgrep.test/pgrep.exp
    make check
fi

make install
mv -v /usr/lib/libprocps.so.* /lib
ln -sfv ../../lib/$(readlink /usr/lib/libprocps.so) /usr/lib/libprocps.so

popd \
  && rm -rf /tmp/procps-ng

# 6.55 E2fsprogs
tar -xf /sources/e2fsprogs-*.tar.gz -C /tmp/ \
  && mv /tmp/e2fsprogs-* /tmp/e2fsprogs \
  && pushd /tmp/e2fsprogs

mkdir -v build
cd build
../configure --prefix=/usr            \
    --bindir=/bin                     \
    --with-root-prefix=""             \
    --enable-elf-shlibs               \
    --disable-libblkid                \
    --disable-libuuid                 \
    --disable-uuidd                   \
    --disable-fsck
make

if [ $LFS_TEST -eq 1 ]; then
    ln -sfv /tools/lib/lib{blk,uu}id.so.1 lib
    make LD_LIBRARY_PATH=/tools/lib check || true
fi

make install
make install-libs
chmod -v u+w /usr/lib/{libcom_err,libe2p,libext2fs,libss}.a
gunzip -v /usr/share/info/libext2fs.info.gz
install-info --dir-file=/usr/share/info/dir /usr/share/info/libext2fs.info

popd \
  && rm -rf /tmp/e2fsprogs

# 6.56 Coreutils
tar -xf /sources/coreutils-*.tar.xz -C /tmp/ \
  && mv /tmp/coreutils-* /tmp/coreutils \
  && pushd /tmp/coreutils

patch -Np1 -i /sources/coreutils-8.30-i18n-1.patch
sed -i '/test.lock/s/^/#/' gnulib-tests/gnulib.mk

autoreconf -fiv
FORCE_UNSAFE_CONFIGURE=1 ./configure \
  --prefix=/usr                      \
  --enable-no-install-program=kill,uptime

FORCE_UNSAFE_CONFIGURE=1 make
make install

mv -v /usr/bin/{cat,chgrp,chmod,chown,cp,date,dd,df,echo} /bin
mv -v /usr/bin/{false,ln,ls,mkdir,mknod,mv,pwd,rm} /bin
mv -v /usr/bin/{rmdir,stty,sync,true,uname} /bin
mv -v /usr/bin/chroot /usr/sbin
mv -v /usr/share/man/man1/chroot.1 /usr/share/man/man8/chroot.8
sed -i s/\"1\"/\"8\"/1 /usr/share/man/man8/chroot.8

mv -v /usr/bin/{head,sleep,nice} /bin

popd \
  && rm -rf /tmp/coreutils

# 6.57 Check
tar -xf /sources/check-*.tar.gz -C /tmp/ \
  && mv /tmp/check-* /tmp/check \
  && pushd /tmp/check

./configure --prefix=/usr
make
if [ $LFS_TEST -eq 1 ]; then make check; fi
make install
sed -i '1 s/tools/usr/' /usr/bin/checkmk

popd \
  && rm -rf /tmp/check

# 6.58 Diffutils
tar -xf /sources/diffutils-*.tar.xz -C /tmp/ \
  && mv /tmp/diffutils-* /tmp/diffutils \
  && pushd /tmp/diffutils

./configure --prefix=/usr
make
if [ $LFS_TEST -eq 1 ]; then make check; fi
make install

popd \
  && rm -rf /tmp/diffutils

# 6.59 Gawk
tar -xf /sources/gawk-*.tar.xz -C /tmp/ \
  && mv /tmp/gawk-* /tmp/gawk \
  && pushd /tmp/gawk

sed -i 's/extras//' Makefile.in
./configure --prefix=/usr
make
if [ $LFS_TEST -eq 1 ]; then make check; fi
make install

popd \
  && rm -rf /tmp/gawk

# 6.60 Findutils
tar -xf /sources/findutils-*.tar.gz -C /tmp/ \
  && mv /tmp/findutils-* /tmp/findutils \
  && pushd /tmp/findutils

sed -i 's/test-lock..EXEEXT.//' tests/Makefile.in
sed -i 's/IO_ftrylockfile/IO_EOF_SEEN/' gl/lib/*.c
sed -i '/unistd/a #include <sys/sysmacros.h>' gl/lib/mountlist.c
echo "#define _IO_IN_BACKUP 0x100" >> gl/lib/stdio-impl.h
./configure --prefix=/usr --localstatedir=/var/lib/locate

make
if [ $LFS_TEST -eq 1 ]; then make check; fi
make install

mv -v /usr/bin/find /bin
sed -i 's|find:=${BINDIR}|find:=/bin|' /usr/bin/updatedb

popd \
  && rm -rf /tmp/findutils

# 6.61 Groff
tar -xf /sources/groff-*.tar.gz -C /tmp/ \
  && mv /tmp/groff-* /tmp/groff \
  && pushd /tmp/groff

PAGE=A4 ./configure --prefix=/usr
make -j1
make install

popd \
  && rm -rf /tmp/groff

# 6.62 GRUB
tar -xf /sources/grub-*.tar.xz -C /tmp/ \
  && mv /tmp/grub-* /tmp/grub \
  && pushd /tmp/grub

./configure --prefix=/usr \
    --sbindir=/sbin       \
    --sysconfdir=/etc     \
    --disable-efiemu      \
    --disable-werror
make
make install

popd \
  && rm -rf /tmp/grub

# 6.63 Less
tar -xf /sources/less-*.tar.gz -C /tmp/ \
  && mv /tmp/less-* /tmp/less \
  && pushd /tmp/less

./configure --prefix=/usr --sysconfdir=/etc
make
make install

popd \
  && rm -rf /tmp/less

# 6.64 Gzip
tar -xf /sources/gzip-*.tar.xz -C /tmp/ \
  && mv /tmp/gzip-* /tmp/gzip \
  && pushd /tmp/gzip

sed -i 's/IO_ftrylockfile/IO_EOF_SEEN/' lib/*.c
echo "#define _IO_IN_BACKUP 0x100" >> lib/stdio-impl.h
./configure --prefix=/usr
make
if [ $LFS_TEST -eq 1 ]; then make check || true; fi
make install
mv -v /usr/bin/gzip /bin

popd \
  && rm -rf /tmp/gzip

# 6.65 IPRoute2
tar -xf /sources/iproute2-*.tar.xz -C /tmp/ \
  && mv /tmp/iproute2-* /tmp/iproute2 \
  && pushd /tmp/iproute2

sed -i /ARPD/d Makefile
rm -fv man/man8/arpd.8
sed -i 's/m_ipt.o//' tc/Makefile
make
make DOCDIR=/usr/share/doc/iproute2-4.18.0 install

popd \
  && rm -rf /tmp/iproute2

# 6.66 Kbd
tar -xf /sources/kbd-*.tar.xz -C /tmp/ \
  && mv /tmp/kbd-* /tmp/kbd \
  && pushd /tmp/kbd

patch -Np1 -i /sources/kbd-2.0.4-backspace-1.patch
sed -i 's/\(RESIZECONS_PROGS=\)yes/\1no/g' configure
sed -i 's/resizecons.8 //' docs/man/man8/Makefile.in

PKG_CONFIG_PATH=/tools/lib/pkgconfig ./configure --prefix=/usr --disable-vlock
make
if [ $LFS_TEST -eq 1 ]; then make check; fi
make install

popd \
  && rm -rf /tmp/kbd

# 6.67 Libpipeline
tar -xf /sources/libpipeline-*.tar.gz -C /tmp/ \
  && mv /tmp/libpipeline-* /tmp/libpipeline \
  && pushd /tmp/libpipeline

./configure --prefix=/usr
make
make install

popd \
  && rm -rf /tmp/libpipeline

# 6.68 Make
tar -xf /sources/make-*.tar.bz2 -C /tmp/ \
  && mv /tmp/make-* /tmp/make \
  && pushd /tmp/make

sed -i '211,217 d; 219,229 d; 232 d' glob/glob.c
./configure --prefix=/usr
make
if [ $LFS_TEST -eq 1 ]; then make PERL5LIB=$PWD/tests/ check; fi
make install

popd \
  && rm -rf /tmp/make

# 6.69 Patch
tar -xf /sources/patch-*.tar.xz -C /tmp/ \
  && mv /tmp/patch-* /tmp/patch \
  && pushd /tmp/patch

./configure --prefix=/usr
make
if [ $LFS_TEST -eq 1 ]; then make check; fi
make install

popd \
  && rm -rf /tmp/patch

# 6.70 Sysklogd
tar -xf /sources/sysklogd-*.tar.gz -C /tmp/ \
  && mv /tmp/sysklogd-* /tmp/sysklogd \
  && pushd /tmp/sysklogd

sed -i '/Error loading kernel symbols/{n;n;d}' ksym_mod.c
sed -i 's/union wait/int/' syslogd.c
make
make BINDIR=/sbin install

cat > /etc/syslog.conf <<"EOF"
# Begin /etc/syslog.conf

auth,authpriv.* -/var/log/auth.log
*.*;auth,authpriv.none -/var/log/sys.log
daemon.* -/var/log/daemon.log
kern.* -/var/log/kern.log
mail.* -/var/log/mail.log
user.* -/var/log/user.log
*.emerg *

# End /etc/syslog.conf
EOF

popd \
  && rm -rf /tmp/sysklogd

# 6.71 Sysvinit
tar -xf /sources/sysvinit-*.tar.xz -C /tmp/ \
  && mv /tmp/sysvinit-* /tmp/sysvinit \
  && pushd /tmp/sysvinit

patch -Np1 -i /sources/sysvinit-2.90-consolidated-1.patch
make -C src
make -C src install

# 6.72 Eudev
tar -xf /sources/eudev-*.tar.gz -C /tmp/ \
  && mv /tmp/eudev-* /tmp/eudev \
  && pushd /tmp/eudev

cat > config.cache << EOF
HAVE_BLKID=1
BLKID_LIBS="-lblkid"
BLKID_CFLAGS="-I/tools/include"
EOF

./configure --prefix=/usr   \
    --bindir=/sbin          \
    --sbindir=/sbin         \
    --libdir=/usr/lib       \
    --sysconfdir=/etc       \
    --libexecdir=/lib       \
    --with-rootprefix=      \
    --with-rootlibdir=/lib  \
    --enable-manpages       \
    --disable-static        \
    --config-cache
LIBRARY_PATH=/tools/lib make

mkdir -pv /lib/udev/rules.d
mkdir -pv /etc/udev/rules.d
if [ $LFS_TEST -eq 1 ]; then make LD_LIBRARY_PATH=/tools/lib check || true; fi

make LD_LIBRARY_PATH=/tools/lib install
tar -xvf /sources/udev-lfs-20171102.tar.bz2
make -f udev-lfs-20171102/Makefile.lfs install

LD_LIBRARY_PATH=/tools/lib udevadm hwdb --update
popd \
  && rm -rf /tmp/eudev

# 6.73 Util-linux
tar -xf /sources/util-linux-*.tar.xz -C /tmp/ \
  && mv /tmp/util-linux-* /tmp/util-linux \
  && pushd /tmp/util-linux

mkdir -pv /var/lib/hwclock
rm -vf /usr/include/{blkid,libmount,uuid}
./configure ADJTIME_PATH=/var/lib/hwclock/adjtime \
    --docdir=/usr/share/doc/util-linux-2.32.1     \
    --disable-chfn-chsh                           \
    --disable-login                               \
    --disable-nologin                             \
    --disable-su                                  \
    --disable-setpriv                             \
    --disable-runuser                             \
    --disable-pylibmount                          \
    --disable-static                              \
    --without-python                              \
    --without-systemd                             \
    --without-systemdsystemunitdir
make

make install
popd \
  && rm -rf /tmp/util-linux

# 6.74 Man-DB
tar -xf /sources/man-db-*.tar.xz -C /tmp/ \
  && mv /tmp/man-db-* /tmp/man-db \
  && pushd /tmp/man-db

./configure --prefix=/usr                        \
            --docdir=/usr/share/doc/man-db-2.8.4 \
            --sysconfdir=/etc                    \
            --disable-setuid                     \
            --enable-cache-owner=bin             \
            --with-browser=/usr/bin/lynx         \
            --with-vgrind=/usr/bin/vgrind        \
            --with-grap=/usr/bin/grap            \
            --with-systemdtmpfilesdir=

make
if [ $LFS_TEST -eq 1 ]; then make check; fi
make install

popd \
  && rm -rf /tmp/man-db || true

# 6.75 Tar
tar -xf /sources/tar-*.tar.xz -C /tmp/ \
  && mv /tmp/tar-* /tmp/tar \
  && pushd /tmp/tar

FORCE_UNSAFE_CONFIGURE=1    \
  ./configure --prefix=/usr \
              --bindir=/bin
make
if [ $LFS_TEST -eq 1 ]; then make check; fi
make install
make -C doc install-html docdir=/usr/share/doc/tar-1.30

popd \
  && rm -rf /tmp/tar || true

# 6.76 Texinfo
tar -xf /sources/texinfo-*.tar.xz -C /tmp/ \
  && mv /tmp/texinfo-* /tmp/texinfo \
  && pushd /tmp/texinfo

sed -i '5481,5485 s/({/(\\{/' tp/Texinfo/Parser.pm
./configure --prefix=/usr --disable-static
make

if [ $LFS_TEST -eq 1 ]; then make check; fi
make install
make TEXMF=/usr/share/texmf install-tex
pushd /usr/share/info
rm -v dir
for f in *
  do install-info $f dir 2>/dev/null
done
popd

popd \
  && rm -rf /tmp/texinfo

# 6.77 Vim
tar -xf /sources/vim-*.tar.bz2 -C /tmp/ \
  && mv /tmp/vim* /tmp/vim \
  && pushd /tmp/vim

echo '#define SYS_VIMRC_FILE "/etc/vimrc"' >> src/feature.h
./configure --prefix=/usr
make
if [ $LFS_TEST -eq 1 ]; then make -j1 test &> vim-test.log; fi
make install

ln -sv vim /usr/bin/vi
for L in /usr/share/man/{,*/}man1/vim.1; do
    ln -sv vim.1 $(dirname $L)/vi.1
done

ln -sv ../vim/vim81/doc /usr/share/doc/vim-8.1

cat > /etc/vimrc <<"EOF"
" Begin /etc/vimrc
" Ensure defaults are set before customizing settings, not after
source $VIMRUNTIME/defaults.vim
let skip_defaults_vim=1
set nocompatible
set backspace=2
set mouse=
syntax on
if (&term == "xterm") || (&term == "putty")
  set background=dark
endif
" End /etc/vimrc
EOF
touch ~/.vimrc

popd \
  && rm -rf /tmp/vim

# 6.79 Stripping Again
# TODO

# 6.80 Cleaning
rm -rf /tmp/*









