# SPDX-License-Identifier: GPL-3.0
# Copyright (c) 2021, Divyanshu-Modi <divyan.m05@gmail.com>
#bin/#!/bin/bash

	COMPILER="$1"
	USER='OGIndian'
	HOST="$(uname -n)"
	VERSION='6.0'
	DEVICENAME='Redmi Note 6 Pro'
	DEVICE='tulip'
	KERNEL_DIR="$HOME/Kernel"
	ZIP_DIR="$HOME/Repack"
	AKSH="$ZIP_DIR/anykernel.sh"
	DFCF="AtomX-${DEVICE}_defconfig"
	if [[ ! -f $KERNEL_DIR/arch/arm64/configs/$DFCF ]]; then
		DFCF="${DEVICE}-perf_defconfig"
		if [[ ! -f $KERNEL_DIR/arch/arm64/configs/$DFCF ]]; then
			DFCF="${DEVICE}_defconfig"
        fi
	fi
	CONFIG="$KERNEL_DIR/arch/arm64/configs/$DFCF"
	mkdir $COMPILER

# Set variables
	if [[ "$COMPILER" == "CLANG" ]]; then
		CC='clang'
		HOSTCC='clang'
		HOSTCXX='clang++'
		C_PATH="$HOME/clang"
		CC_64='aarch64-linux-gnu-'
		CC_COMPAT='arm-linux-gnueabi-'
	elif [[ "$COMPILER" == "GCC" ]]; then
		HOSTCC='gcc'
		CC_64='aarch64-elf-'
		CC='aarch64-elf-gcc'
		C_PATH="$HOME/gcc-arm64"
		HOSTCXX='aarch64-elf-g++'
		CC_COMPAT="$HOME/gcc-arm32/bin/arm-eabi-"
	fi

	muke() {
		make O=$COMPILER $CFLAG ARCH=arm64 \
		    $FLAG                          \
			CC=$CC                         \
			LLVM=1                         \
			LLVM_IAS=1                     \
			CROSS_COMPILE=$CC_64           \
			HOSTCC=$HOSTCC                 \
			HOSTCXX=$HOSTCXX               \
			PATH=$C_PATH/bin:$PATH         \
			KBUILD_BUILD_USER=$USER        \
			KBUILD_BUILD_HOST=$HOST        \
			CROSS_COMPILE_ARM32=$CC_COMPAT \
			CROSS_COMPILE_COMPAT=$CC_COMPAT\
			LD_LIBRARY_PATH=$C_PATH/lib:$LD_LIBRARY_PATH
	}

	BUILD_START=$(date +"%s")

	CFLAG=$DFCF
	muke
	source $COMPILER/.config
	if [[ "CONFIG_LTO_CLANG_FULL=y" ]]; then
		VARIANT=FULL_LTO
	elif [[ "CONFIG_LTO_CLANG_THIN=y" ]]; then
		VARIANT=THIN_LTO
	else
		VARIANT=NON_LTO
	fi
	telegram-send --format html "Building: <code>$VARIANT</code>"

	CFLAG=-j$(nproc)
	muke

	if [[ -f $KERNEL_DIR/$COMPILER/arch/arm64/boot/Image.gz-dtb ]]; then
		FDEVICE=${DEVICE^^}
		KNAME=$(echo "$CONFIG_LOCALVERSION" | cut -c 2-)
		FINAL_ZIP="$KNAME-$FDEVICE-`date +"%H%M"`"
		cd $ZIP_DIR
		cp $KERNEL_DIR/$COMPILER/arch/arm64/boot/Image.gz-dtb $ZIP_DIR/
		sed -i "s/demo1/$DEVICE/g" $AKSH
		if [[ "$DEVICE2" ]]; then
			sed -i "/device.name1/ a device.name2=$DEVICE2" $AKSH
		fi
		zip -r9 "$FINAL_ZIP".zip * -x README.md *placeholder zipsigner*
		java -jar zipsigner* "$FINAL_ZIP.zip" "$FINAL_ZIP-signed.zip"
		FINAL_ZIP="$FINAL_ZIP-signed.zip"
		telegram-send --file $ZIP_DIR/$FINAL_ZIP
		rm *.zip Image.gz-dtb
		sed -i "s/$DEVICE/demo1/g" $AKSH
		if [[ "$DEVICE2" ]]; then
			sed -i "/device.name2/d" $AKSH
		fi

		BUILD_END=$(date +"%s")
		DIFF=$(($BUILD_END - $BUILD_START))

		cd $KERNEL_DIR
		COMPILER_NAME="$($C_PATH/bin/$CC --version 2>/dev/null | head -n 1 | perl -pe 's/\(http.*?\)//gs' | sed -e 's/  */ /g' -e 's/[[:space:]]*$//')"

		telegram-send --disable-web-page-preview --format html "\
		**************Atom-X-Kernel**************
		Compiler: <code>$COMPILER</code>
		Compiler-name: <code>$COMPILER_NAME</code>
		Linux Version: <code>$(make kernelversion)</code>
		Builder Version: <code>$VERSION</code>
		Build Type: <code>$VARIANT</code>
		Maintainer: <code>$USER</code>
		Device: <code>$DEVICENAME</code>
		Codename: <code>$DEVICE</code>
		Camlib: <code>$CAM</code>
		Build Date: <code>$(date +"%Y-%m-%d %H:%M")</code>
		Build Duration: <code>$(($DIFF / 60)).$(($DIFF % 60)) mins</code>
		Changelog: <a href='$SOURCE'> Here </a>"
	else
		telegram-send "Error⚠️ $COMPILER failed to build"
		exit 1
	fi
