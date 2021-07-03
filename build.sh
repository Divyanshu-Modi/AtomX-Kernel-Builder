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
    SILENCE=1
    DEVICE=tulip
    BUILD=clean
    CAM_LIB=

#PATHS
    ZIP_DIR=$HOME/Repack
    AKSH=$ZIP_DIR/anykernel.sh
    DFCF=AtomX-$DEVICE${CAM_LIB}_defconfig
    CONFIG=$KERNEL_DIR/arch/arm64/configs/$DFCF
    mkdir out
    OUT=$KERNEL_DIR/out
    mkdir work

    telegram-send " Starting Compilation for $DEVICE$CAM_LIB"
    BUILD_START=$(date +"%s")

if [[ "$SILENCE" == "1" ]]; then
    FLAG=-s
else
    FLAG=
fi
muke() {
    make O=work $CFLAG ARCH=arm64 $FLAG \
      LLVM=1                            \
      HOSTCC=gcc                        \
      HOSTLD=ld.lld                     \
      CC=aarch64-elf-gcc                \
      HOSTCXX=aarch64-elf-g++           \
      KBUILD_BUILD_USER=$USER           \
      KBUILD_BUILD_HOST=$HOST           \
      PATH=$GCC_PATH/bin:$PATH          \
      CROSS_COMPILE_COMPAT=$GCC_ARM32   \
      LD_LIBRARY_PATH=$GCC_PATH/lib:$LD_LIBRARY_PATH
}

    sed -i '/CONFIG_JUMP_LABEL/ a CONFIG_LTO_GCC=y' $CONFIG
    sed -i '/CONFIG_JUMP_LABEL/ a CONFIG_OPTIMIZE_INLINING=y' $CONFIG
    CFLAG=$DFCF
    muke

    CFLAG=-j$(nproc)
    muke

if [[ -f $KERNEL_DIR/work/arch/arm64/boot/Image.gz-dtb ]]; then
    FINAL_ZIP="$DEVICE$CAM_LIB-AtomX-EAS-GCC_LTO-`date +"%Y%m%d-%H%M"`"
    cd $ZIP_DIR
    cp $KERNEL_DIR/work/arch/arm64/boot/Image.gz-dtb $ZIP_DIR/
    sed -i s/demo1/$DEVICE/g $AKSH
    if [[ "$DEVICE2" ]]; then
        sed -i /device.name1/ a device.name2=$DEVICE2 $AKSH
    fi
    zip -qr9 "$FINAL_ZIP".zip * -x README.md *placeholder zipsigner*
    java -jar zipsigner* "$FINAL_ZIP".zip "$FINAL_ZIP"-signed.zip
    cp "$FINAL_ZIP"-signed.zip $OUT
    cd $KERNEL_DIR
    rm $ZIP_DIR/*.zip $ZIP_DIR/Image.gz-dtb
    BUILD_END=$(date +"%s")
    DIFF=$(($BUILD_END - $BUILD_START))
    telegram-send "Compiled for $DEVICE$CAM_LIB in $(($DIFF / 60)).$(($DIFF % 60)) mins."
    final=\
"Build Date: $(date)
""
"*******Changelog*******"
""
$(git log HEAD~10..HEAD --pretty='format:%C(auto) -> %s')"
    telegram-send --file $OUT/*.zip
    telegram-send "$final"
    exit
else
    telegram-send "Error! Compilaton failed: Kernel Image missing"
    exit 1
fi
