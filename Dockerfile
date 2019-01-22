FROM debian:8

RUN apt-get update && apt-get install -y\
  make\
  gawk\
  gcc\
  g++\
  valgrind\
  gdb\
  texinfo\
  vim\
  patch\
  xz-utils\
  # libs for OS
  bison\
  flex\
  libreadline-dev\
  # python and pip for running tests
  python\
  python-pip\
  bc\
  --no-install-recommends\
  && rm -rf /var/lib/apt/lists/*\
  # python package for running tests
  && pip install pexpect

RUN rm /bin/sh && ln -s /bin/bash /bin/sh

# LFS mount point
ENV LFS=/mnt/lfs

# Other LFS parameters
ENV LC_ALL=POSIX
ENV LFS_TGT=x86_64-lfs-linux-gnu
ENV PATH=/tools/bin:/bin:/usr/bin:/sbin:/usr/sbin

# ch3 create sources directory as writable and sticky
RUN mkdir -pv     $LFS/sources \
 && chmod -v a+wt $LFS/sources
WORKDIR $LFS/sources

#  ch3 wget source tarballs
RUN apt-get update && apt-get install -y wget
RUN wget http://linuxfromscratch.org/lfs/view/8.3/wget-list
RUN wget --input-file=wget-list --continue --directory-prefix=$LFS/sources

# ch4.2 create tools directory and symlink
RUN mkdir -v $LFS/tools && ln -sv $LFS/tools /

# ch4.3 create lfs user with 'lfs' password
RUN groupadd lfs                                    \
 && useradd -s /bin/bash -g lfs -m -k /dev/null lfs \
 && echo "lfs:lfs" | chpasswd
RUN adduser lfs sudo

# avoid sudo password
RUN echo "lfs ALL = NOPASSWD : ALL" >> /etc/sudoers
RUN echo 'Defaults env_keep += "LFS LC_ALL LFS_TGT PATH MAKEFLAGS FETCH_TOOLCHAIN_MODE LFS_TEST LFS_DOCS JOB_COUNT LOOP IMAGE_SIZE INITRD_TREE IMAGE"' >> /etc/sudoers

# ch4.3 give lfs user ownership of directories
RUN chown -v lfs $LFS/tools  \
 && chown -v lfs $LFS/sources

# ch4.3 login as lfs user
USER lfs

# ch4.4 settings up environment
COPY [ "config/.bash_profile", "config/.bashrc", "/home/lfs/" ]
RUN source ~/.bash_profile

# ch4.5 make flags
ENV MAKEFLAGS='-j 4'

# ch5.4 Binutils pass1
RUN tar xf binutils-*.xz -C /tmp \
 && mv /tmp/binutils-* ./binutils \
 && pushd ./binutils \
 && mkdir -v build \
 && cd build \
 && time { ../configure --prefix=/tools            \
             --with-sysroot=$LFS        \
             --with-lib-path=/tools/lib \
             --target=$LFS_TGT          \
             --disable-nls              \
             --disable-werror \
 && make \
 && mkdir -pv /tools/lib \
 && ln -sv lib /tools/lib64 \
 && make install; } \
 && popd \
 && rm -rf ./binutils

# ch5.5 gcc pass1
RUN tar -xf gcc-*.tar.xz -C /tmp/ \
  && mv /tmp/gcc-* ./gcc \
  && pushd ./gcc \
  && tar -xf $LFS/sources/mpfr-*.tar.xz \
  && mv -v mpfr-* mpfr \
  && tar -xf $LFS/sources/gmp-*.tar.xz \
  && mv -v gmp-* gmp \
  && tar -xf $LFS/sources/mpc-*.tar.gz \
  && mv -v mpc-* mpc \
  && for file in gcc/config/{linux,i386/linux{,64}}.h; do \
      cp -uv $file{,.orig}; \
      sed -e 's@/lib\(64\)\?\(32\)\?/ld@/tools&@g' -e 's@/usr@/tools@g' $file.orig > $file; \
      echo -e "#undef STANDARD_STARTFILE_PREFIX_1 \n#undef STANDARD_STARTFILE_PREFIX_2 \n#define STANDARD_STARTFILE_PREFIX_1 \"/tools/lib/\" \n#define STANDARD_STARTFILE_PREFIX_2 \"\"" >> $file; \
      touch $file.orig; \
    done \
  && case $(uname -m) in \
     x86_64) \
       sed -e '/m64=/s/lib64/lib/' -i.orig gcc/config/i386/t-linux64 \
       ;; \
    esac \
  && mkdir -v build \
  && cd build \
  && ../configure                                   \
    --target=$LFS_TGT                              \
    --prefix=/tools                                \
    --with-glibc-version=2.11                      \
    --with-sysroot=$LFS                            \
    --with-newlib                                  \
    --without-headers                              \
    --with-local-prefix=/tools                     \
    --with-native-system-header-dir=/tools/include \
    --disable-nls                                  \
    --disable-shared                               \
    --disable-multilib                             \
    --disable-decimal-float                        \
    --disable-threads                              \
    --disable-libatomic                            \
    --disable-libgomp                              \
    --disable-libmpx                               \
    --disable-libquadmath                          \
    --disable-libssp                               \
    --disable-libvtv                               \
    --disable-libstdcxx                            \
    --enable-languages=c,c++                       \
  && make \
  && make install \
  && popd \
  && rm -rf ./gcc

# ch5.6 Linux API Headers
RUN tar -xf linux-*.tar.xz -C /tmp/ \
  && mv /tmp/linux-* ./linux \
  && pushd ./linux \
  && make mrproper \
  && make INSTALL_HDR_PATH=dest headers_install \
  && cp -rv dest/include/* /tools/include \
  && popd \
  && rm -rf ./linux

# ch5.7 glibc
RUN tar -xf glibc-*.tar.xz -C /tmp/ \
  && mv /tmp/glibc-* ./glibc \
  && pushd ./glibc \
  && mkdir -v build \
  && cd build \
  && ../configure                       \
    --prefix=/tools                    \
    --host=$LFS_TGT                    \
    --build=$(../scripts/config.guess) \
    --enable-kernel=3.2                \
    --with-headers=/tools/include      \
    libc_cv_forced_unwind=yes          \
    libc_cv_c_cleanup=yes              \
  && make \
  && make install \
  && popd \
  && rm -rf ./glibc

RUN echo 'int main(){}' > dummy.c \
  && $LFS_TGT-gcc dummy.c \
  && readelf -l a.out | grep ': /tools' \
  && rm -v dummy.c a.out

# ch5.8 Libstdc++
RUN tar -xf gcc-*.tar.xz -C /tmp/ \
  && mv /tmp/gcc-* ./gcc \
  && pushd ./gcc \
  && mkdir -v build \
  && cd build \
  && ../libstdc++-v3/configure        \
     --host=$LFS_TGT                 \
     --prefix=/tools                 \
     --disable-multilib              \
     --disable-nls                   \
     --disable-libstdcxx-threads     \
     --disable-libstdcxx-pch         \
     --with-gxx-include-dir=/tools/$LFS_TGT/include/c++/8.2.0 \
  && make \
  && make install \
  && popd \
  && rm -rf ./gcc

# ch5.9 Binutils pass2
RUN tar -xf binutils-*.tar.xz -C /tmp/ \
  && mv /tmp/binutils-* ./binutils \
  && pushd ./binutils \
  && mkdir -v build \
  && cd build \
  && CC=$LFS_TGT-gcc              \
    AR=$LFS_TGT-ar               \
    RANLIB=$LFS_TGT-ranlib       \
    ../configure                 \
      --prefix=/tools            \
      --disable-nls              \
      --disable-werror           \
      --with-lib-path=/tools/lib \
      --with-sysroot             \
  && make \
  && make install \
  && make -C ld clean \
  && make -C ld LIB_PATH=/usr/lib:/lib \
  && cp -v ld/ld-new /tools/bin \
  && popd \
  && rm -rf ./binutils

# ch5.10 gcc pass2
RUN tar -xf gcc-*.tar.xz -C /tmp/ \
  && mv /tmp/gcc-* ./gcc \
  && pushd ./gcc \
  && tar -xf $LFS/sources/mpfr-*.tar.xz \
  && mv -v mpfr-* mpfr \
  && tar -xf $LFS/sources/gmp-*.tar.xz \
  && mv -v gmp-* gmp \
  && tar -xf $LFS/sources/mpc-*.tar.gz \
  && mv -v mpc-* mpc \
  && cat gcc/limitx.h gcc/glimits.h gcc/limity.h > \
      `dirname $($LFS_TGT-gcc -print-libgcc-file-name)`/include-fixed/limits.h \
  && for file in gcc/config/{linux,i386/linux{,64}}.h; do \
     cp -uv $file{,.orig}; \
     sed -e 's@/lib\(64\)\?\(32\)\?/ld@/tools&@g' -e 's@/usr@/tools@g' $file.orig > $file; \
     echo -e "#undef STANDARD_STARTFILE_PREFIX_1 \n#undef STANDARD_STARTFILE_PREFIX_2 \n#define STANDARD_STARTFILE_PREFIX_1 \"/tools/lib/\" \n#define STANDARD_STARTFILE_PREFIX_2 \"\"" >> $file; \
     touch $file.orig; \
    done \
  && case $(uname -m) in \
     x86_64) \
       sed -e '/m64=/s/lib64/lib/' -i.orig gcc/config/i386/t-linux64 \
      ;; \
    esac \
  && mkdir -v build \
  && cd build \
  && CC=$LFS_TGT-gcc        \
    CXX=$LFS_TGT-g++       \
    AR=$LFS_TGT-ar         \
    RANLIB=$LFS_TGT-ranlib \
    ../configure                                     \
      --prefix=/tools                                \
      --with-local-prefix=/tools                     \
      --with-native-system-header-dir=/tools/include \
      --enable-languages=c,c++                       \
      --disable-libstdcxx-pch                        \
      --disable-multilib                             \
      --disable-bootstrap                            \
      --disable-libgomp                              \
  && make \
  && make install \
  && ln -sv gcc /tools/bin/cc \
  && popd \
  && rm -rf ./gcc

RUN echo 'int main(){}' > dummy.c \
  && cc dummy.c \
  && readelf -l a.out | grep ': /tools' \
  && rm -v dummy.c a.out

# ch5.11 Tcl
ENV LFS_TEST=0
RUN tar -xf tcl*-src.tar.gz -C /tmp/ \
  && mv /tmp/tcl* ./tcl \
  && pushd ./tcl \
  && cd unix \
  && ./configure --prefix=/tools \
  && make \
  && if [ $LFS_TEST -eq 1 ]; then TZ=UTC make test; fi \
  && make install \
  && chmod -v u+w /tools/lib/libtcl8.6.so \
  && make install-private-headers \
  && ln -sv tclsh8.6 /tools/bin/tclsh \
  && popd \
  && rm -rf ./tcl-core

# ch5.12 Expect
RUN tar -xf expect*.tar.gz -C /tmp/ \
  && mv /tmp/expect* ./expect \
  && pushd ./expect \
  && cp -v configure{,.orig} \
  && sed 's:/usr/local/bin:/bin:' configure.orig > configure \
  && ./configure --prefix=/tools        \
      --with-tcl=/tools/lib            \
      --with-tclinclude=/tools/include \
  && make \
  && if [ $LFS_TEST -eq 1 ]; then make test; fi \
  && make SCRIPTS="" install \
  && popd \
  && rm -rf ./expect

# ch5.13 DejaGNU
RUN tar -xf dejagnu-*.tar.gz -C /tmp/ \
  && mv /tmp/dejagnu-* ./dejagnu \
  && pushd ./dejagnu \
  && ./configure --prefix=/tools \
  && make install \
  && if [ $LFS_TEST -eq 1 ]; then make check; fi \
  && popd \
  && rm -rf ./dejagnu

# ch5.14 M4
RUN tar -xf m4-*.tar.xz -C /tmp/ \
  && mv /tmp/m4-* ./m4 \
  && pushd ./m4 \
  && sed -i 's/IO_ftrylockfile/IO_EOF_SEEN/' lib/*.c \
  && echo "#define _IO_IN_BACKUP 0x100" >> lib/stdio-impl.h \
  && ./configure --prefix=/tools \
  && make \
  && if [ $LFS_TEST -eq 1 ]; then make check; fi \
  && make install \
  && popd \
  && rm -rf ./m4

# ch5.15 Ncurses
RUN tar -xf ncurses-*.tar.gz -C /tmp/ \
  && mv /tmp/ncurses-* ./ncurses \
  && pushd ./ncurses \
  && sed -i s/mawk// configure \
  && ./configure          \
      --prefix=/tools    \
      --with-shared      \
      --without-debug    \
      --without-ada      \
      --enable-widec     \
      --enable-overwrite \
  && make \
  && make install \
  && popd \
  && rm -rf ./ncurses

# ch5.16 Bash
RUN tar -xf bash-*.tar.gz -C /tmp/ \
  && mv /tmp/bash-* ./bash \
  && pushd ./bash \
  && ./configure --prefix=/tools --without-bash-malloc \
  && make \
  && if [ $LFS_TEST -eq 1 ]; then make tests; fi \
  && make install \
  && ln -sv bash /tools/bin/sh \
  && popd \
  && rm -rf ./bash

# ch5.17 Bison
RUN tar -xf bison-*.tar.xz -C /tmp/ \
  && mv /tmp/bison-* ./bison \
  && pushd ./bison \
  && ./configure --prefix=/tools \
  && make \
  && make install \
  && popd \
  && rm -rf ./bison

# ch5.18 Bzip2
RUN tar -xf bzip2-*.tar.gz -C /tmp/ \
  && mv /tmp/bzip2-* ./bzip2 \
  && pushd ./bzip2 \
  && make \
  && make PREFIX=/tools install \
  && popd \
  && rm -rf ./bzip2

# ch5.19 Coreutils
RUN tar -xf coreutils-*.tar.xz -C /tmp/ \
  && mv /tmp/coreutils-* ./coreutils \
  && pushd ./coreutils \
  && ./configure --prefix=/tools --enable-install-program=hostname \
  && make \
  && if [ $LFS_TEST -eq 1 ]; then make RUN_EXPENSIVE_TESTS=yes check || true; fi \
  && make install \
  && popd \
  && rm -rf ./coreutils

# ch5.20 Diffutils
RUN tar -xf diffutils-*.tar.xz -C /tmp/ \
  && mv /tmp/diffutils-* ./diffutils \
  && pushd ./diffutils \
  && ./configure --prefix=/tools \
  && make \
  && if [ $LFS_TEST -eq 1 ]; then make check; fi \
  && make install \
  && popd \
  && rm -rf ./diffutils

# ch5.21 File
RUN tar -xf file-*.tar.gz -C /tmp/ \
  && mv /tmp/file-* ./file \
  && pushd ./file \
  && ./configure --prefix=/tools \
  && make \
  && if [ $LFS_TEST -eq 1 ]; then make check; fi \
  && make install \
  && popd \
  && rm -rf ./file

# ch5.22 Findutils
RUN tar -xf findutils-*.tar.gz -C /tmp/ \
  && mv /tmp/findutils-* ./findutils \
  && pushd ./findutils \
  && sed -i 's/IO_ftrylockfile/IO_EOF_SEEN/' gl/lib/*.c \
  && sed -i '/unistd/a #include <sys/sysmacros.h>' gl/lib/mountlist.c \
  && echo "#define _IO_IN_BACKUP 0x100" >> gl/lib/stdio-impl.h \
  && ./configure --prefix=/tools \
  && make \
  && if [ $LFS_TEST -eq 1 ]; then make check; fi || true \
  && make install \
  && popd \
  && rm -rf ./findutils

# ch5.23 Gawk
RUN tar -xf gawk-*.tar.xz -C /tmp/ \
  && mv /tmp/gawk-* ./gawk \
  && pushd ./gawk \
  && ./configure --prefix=/tools \
  && make \
  && if [ $LFS_TEST -eq 1 ]; then make check || true; fi \
  && make install \
  && popd \
  && rm -rf ./gawk

# ch5.24 Gettext
RUN tar -xf gettext-*.tar.xz -C /tmp/ \
  && mv /tmp/gettext-* ./gettext \
  && pushd ./gettext \
  && cd gettext-tools \
  && EMACS="no" ./configure --prefix=/tools --disable-shared \
  && make -C gnulib-lib \
  && make -C intl pluralx.c \
  && make -C src msgfmt \
  && make -C src msgmerge \
  && make -C src xgettext \
  && cp -v src/{msgfmt,msgmerge,xgettext} /tools/bin \
  && popd \
  && rm -rf ./gettext

# ch5.25 Grep
RUN tar -xf grep-*.tar.xz -C /tmp/ \
  && mv /tmp/grep-* ./grep \
  && pushd ./grep \
  && ./configure --prefix=/tools \
  && make \
  && if [ $LFS_TEST -eq 1 ]; then make check; fi \
  && make install \
  && popd \
  && rm -rf ./grep

# ch5.26 Gzip
RUN tar -xf gzip-*.tar.xz -C /tmp/ \
  && mv /tmp/gzip-* ./gzip \
  && pushd ./gzip \
  && sed -i 's/IO_ftrylockfile/IO_EOF_SEEN/' lib/*.c \
  && echo "#define _IO_IN_BACKUP 0x100" >> lib/stdio-impl.h \
  && ./configure --prefix=/tools \
  && make \
  && if [ $LFS_TEST -eq 1 ]; then make check || true; fi \
  && make install \
  && popd \
  && rm -rf ./gzip

# ch5.27 Make
RUN tar -xf make-*.tar.bz2 -C /tmp/ \
 && mv /tmp/make-* ./make \
 && pushd ./make \
 && sed -i '211,217 d; 219,229 d; 232 d' glob/glob.c \
 && ./configure --prefix=/tools --without-guile \
 && make \
 && if [ $LFS_TEST -eq 1 ]; then make check; fi \
 && make install \
 && popd \
 && rm -rf ./make

# ch5.28 Patch
RUN tar -xf patch-*.tar.xz -C /tmp/ \
  && mv /tmp/patch-* ./patch \
  && pushd ./patch \
  && ./configure --prefix=/tools \
  && make \
  && if [ $LFS_TEST -eq 1 ]; then make check; fi \
  && make install \
  && popd \
  && rm -rf ./patch

# ch5.29 Perl
RUN tar -xf perl-5*.tar.xz -C /tmp/ \
  && mv /tmp/perl-* ./perl \
  && pushd ./perl \
  && sh Configure -des -Dprefix=/tools -Dlibs=-lm \
  && make \
  && cp -v perl cpan/podlators/scripts/pod2man /tools/bin \
  && mkdir -pv /tools/lib/perl5/5.28.0 \
  && cp -Rv lib/* /tools/lib/perl5/5.28.0 \
  && popd \
  && rm -rf ./perl

# ch5.30 Sed
RUN tar -xf sed-*.tar.xz -C /tmp/ \
  && mv /tmp/sed-* ./sed \
  && pushd ./sed \
  && ./configure --prefix=/tools \
  && make \
  && if [ $LFS_TEST -eq 1 ]; then make check || true; fi \
  && make install \
  && popd \
  && rm -rf ./sed

# ch5.31 Tar
RUN tar -xf tar-*.tar.xz -C /tmp/ \
 && mv /tmp/tar-* ./tar \
 && pushd ./tar \
 && ./configure --prefix=/tools \
 && make \
 && if [ $LFS_TEST -eq 1 ]; then make check; fi \
 && make install \
 && popd \
 && rm -rf ./tar

# ch5.32 Texinfo
RUN tar -xf texinfo-*.tar.xz -C /tmp/ \
  && mv /tmp/texinfo-* ./texinfo \
  && pushd ./texinfo \
  && ./configure --prefix=/tools \
  && make \
  && if [ $LFS_TEST -eq 1 ]; then make check; fi \
  && make install \
  && popd \
  && rm -rf ./texinfo

# ch5.33 Util-linux
RUN tar -xf util-linux-*.tar.xz -C /tmp/ \
  && mv /tmp/util-linux-* ./util-linux \
  && pushd ./util-linux \
  && ./configure --prefix=/tools    \
     --without-python               \
     --disable-makeinstall-chown    \
     --without-systemdsystemunitdir \
     --without-ncurses              \
     PKG_CONFIG=""                  \
  && make \
  && make install \
  && popd \
  && rm -rf ./util-linux

# ch5.34 Xz
RUN tar -xf xz-*.tar.xz -C /tmp/ \
  && mv /tmp/xz-* ./xz \
  && pushd ./xz \
  && ./configure --prefix=/tools \
  && make \
  && if [ $LFS_TEST -eq 1 ]; then make check; fi \
  && make install \
  && popd \
  && rm -rf ./xz

# ch5.35 Stripping
RUN strip --strip-debug /tools/lib/* || true \
  && /usr/bin/strip --strip-unneeded /tools/{,s}bin/* || true \
  && rm -rf /tools/{,share}/{info,man,doc} \
  && find /tools/{lib,libexec} -name \*.la -delete

# ch5.36 Changing Ownership
USER root
RUN chown -R root:root $LFS/tools


# copy scripts
COPY [ "scripts/run-all.sh", "scripts/as-chroot-with-tools.sh", "scripts/as-chroot-with-usr.sh", "$LFS/tools/" ]
RUN chmod +x $LFS/tools/*.sh

# let's the party begin
ENTRYPOINT [ "/tools/run-all.sh" ]
