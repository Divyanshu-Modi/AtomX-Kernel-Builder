#bin/#!/bin/bash

# Device config
	DEVICE=tulip
	BUILD=clean
	NAME='Redmi Note 6 Pro'
	CAM_LIB=

# User config
	USER=OGIndian
	HOST=$(uname -n)
	VERSION=2.0

# Path
	KERNEL_DIR=$HOME/Kernel
	GCC_PATH=$HOME/gcc-arm64
	GCC_ARM32=$HOME/gcc-arm32/bin/arm-eabi-
	ZIP_DIR=$HOME/Repack
	AKSH=$ZIP_DIR/anykernel.sh
	OUT=$KERNEL_DIR/out
	cd $KERNEL_DIR

# Defconfig
	DFCF=AtomX-$DEVICE${CAM_LIB}_defconfig
	CONFIG=$KERNEL_DIR/arch/arm64/configs/$DFCF

muke() {
	make O=work $CFLAG ARCH=arm64         \
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

	BUILD_START=$(date +"%s")

	sed -i '/CONFIG_JUMP_LABEL/ a CONFIG_LTO_GCC=y' $CONFIG
	sed -i '/CONFIG_JUMP_LABEL/ a CONFIG_OPTIMIZE_INLINING=y' $CONFIG
	CFLAG=$DFCF
	muke

	CFLAG=-j$(nproc)
	muke

if [[ -f $KERNEL_DIR/work/arch/arm64/boot/Image.gz-dtb ]]; then
	FINAL_ZIP="$DEVICE$CAM_LIB-AtomX-EAS-GCC_LTO-`date +"%H%M"`"
	cd $ZIP_DIR
	cp $KERNEL_DIR/work/arch/arm64/boot/Image.gz-dtb $ZIP_DIR/
	sed -i s/demo1/$DEVICE/g $AKSH
	if [[ "$DEVICE2" ]]; then
		sed -i /device.name1/ a device.name2=$DEVICE2 $AKSH
	fi
	zip -qr9 ${FINAL_ZIP}.zip * -x README.md *placeholder zipsigner*
	java -jar zipsigner* ${FINAL_ZIP}.zip ${FINAL_ZIP}-signed.zip
	mkdir out
	cp ${FINAL_ZIP}-signed.zip $OUT
	cd $KERNEL_DIR
	rm $ZIP_DIR/*.zip $ZIP_DIR/Image.gz-dtb

	BUILD_END=$(date +"%s")

	DIFF=$(($BUILD_END - $BUILD_START))

	if [[ "$CAM_LIB" == "" ]]; then
		CAM=OLD-CAM
	else
		CAM=$CAM_LIB
	fi
	
	msg_content="
	***************Atom-X-Kernel***************
	Compiler: <code>$CONFIG_CC_VERSION_TEXT</code>
	Linux Version: <code>$(make kernelversion)</code>
	Builder Version: <code>$VERSION</code>
	Maintainer: <code>$USER</code>
	Device: <code>$NAME</code>
	Codename: <code>$DEVICE</code>
	Camlib: <code>$CAM</code>
	Build Date: <code>$(date +"%Y-%m-%d %H:%M")</code>
	Build Duration: <code>$(($DIFF / 60)).$(($DIFF % 60)) mins</code>
	Changelog: <a href='$SOURCE'> Here </a>
	"
	source work/.config
	telegram-send --format html "$msg_content"
	telegram-send --file $OUT/"${FINAL_ZIP}-signed.zip"

	exit
else
	telegram-send "Error⚠️ Compilaton failed: Kernel Image missing"

	exit 1
fi
