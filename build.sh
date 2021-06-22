#bin/#!/bin/bash
# SPDX-License-Identifier: GPL-2.0
# Copyright (c) 2021, Divyanshu-Modi <divyan.m05@gmail.com>

#USER
    KERNEL_DIR=$HOME/Kernel
    cd $KERNEL_DIR
    USER=OGIndian
    HOST=Nucleus

#GCC
    GCC_PATH=$HOME/gcc-arm64
    GCC_ARM32=$HOME/gcc-arm32/bin/arm-eabi-

#DEVICE
    DEVICE=tulip
    BUILD=clean
    CAM_LIB=

#PATHS
    ZIP_DIR=$HOME/Repack
    AKSH=$ZIP_DIR/anykernel.sh
    KERNEL=AtomX-$DEVICE${CAM_LIB}_defconfig
    CONFIG=$KERNEL_DIR/arch/arm64/configs/$KERNEL
    mkdir out
    OUT=$KERNEL_DIR/out
    mkdir work

# BUILD-START
    telegram-send " Starting Compilation for $DEVICE$CAM_LIB"
    BUILD_START=$(date +"%s")

    sed -i '/CONFIG_LTO_NONE=y/d' $CONFIG
    sed -i 's/# CONFIG_LTO_GCC is not set/CONFIG_LTO_GCC=y/g' $CONFIG
    sed -i 's/# CONFIG_OPTIMIZE_INLINING is not set/CONFIG_OPTIMIZE_INLINING=y/g' $CONFIG
    make O=work $KERNEL
    make O=work -j${nproc}            \
      PATH=$GCC_PATH/bin:$PATH        \
      KBUILD_BUILD_USER=$USER         \
      KBUILD_BUILD_HOST=$HOST         \
      CC=aarch64-elf-gcc              \
      HOSTCXX=aarch64-elf-g++         \
      HOSTLD=ld.lld                   \
      AS=llvm-as                      \
      AR=llvm-ar                      \
      NM=llvm-nm                      \
      OBJCOPY=llvm-objcopy            \
      OBJDUMP=llvm-objdump            \
      STRIP=llvm-strip                \
      CROSS_COMPILE_COMPAT=$GCC_ARM32 \
      LD_LIBRARY_PATH=$GCC_PATH/lib:$LD_LIBRARY_PATH

if [[ -f $KERNEL_DIR/work/arch/arm64/boot/Image.gz-dtb ]]; then
    FINAL_ZIP="$DEVICE$CAM_LIB-AtomX-EAS-GCC_LTO-`date +"%Y%m%d-%H%M"`"
    cd $ZIP_DIR
    cp $KERNEL_DIR/work/arch/arm64/boot/Image.gz-dtb $ZIP_DIR/
    sed -i s/demo1/$DEVICE/g $AKSH
    zip -r9 "$FINAL_ZIP".zip * -x README.md *placeholder zipsigner-3.0.jar $LOGO
    java -jar zipsigner-3.0.jar "$FINAL_ZIP".zip "$FINAL_ZIP"-signed.zip
    cp "$FINAL_ZIP"-signed.zip $OUT
    cd $KERNEL_DIR
    rm  $ZIP_DIR/*.zip
    rm $ZIP_DIR/Image.gz-dtb
    sed -i s/$DEVICE/demo1/g $AKSH

# BUILD-END
    BUILD_END=$(date +"%s")
    DIFF=$(($BUILD_END - $BUILD_START))
    telegram-send "Compiled for $DEVICE$CAM_LIB in $(($DIFF / 60)).$(($DIFF % 60)) minute(s)."
    changelog=$(git log HEAD~10..HEAD --pretty='format:%C(auto) -> %s')
    final=\
"Build Date: $(date)
""
"*******Changelog*******"
""
$changelog"
    telegram-send --file $OUT/*.zip
    telegram-send "$final"
else
    telegram-send "Error! Compilaton failed: Kernel Image missing"
    exit
fi
