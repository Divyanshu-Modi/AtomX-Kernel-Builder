# SPDX-License-Identifier: GPL-3.0
# Copyright (c) 2021, Divyanshu-Modi <divyan.m05@gmail.com>
#bin/#!/bin/bash

# COMPILER
	COMPILER="$1"

# Kernel Version API
	export KERNEL_VERSION_LONG=$(make kernelversion)
	export KERNEL_VERSION_SHORT=$(make kernelversion | cut -c 1-3)

# User config
	USER=OGIndian
	HOST=$(uname -n)
	VERSION=3.0

# CLANG
	CLANG_PATH=$HOME/clang
	CLANG_ARM64=aarch64-linux-gnu-
	CLANG_COMPAT=arm-linux-gnueabi-

# GCC
	GCC_PATH=$HOME/gcc-arm64
	GCC_COMPAT=$HOME/gcc-arm32/bin/arm-eabi-

# Device config
	NAME='Redmi Note 6 Pro'
	DEVICE=tulip
	CAM_LIB=

	KERNEL_DIR=$HOME/Kernel
	ZIP_DIR=$HOME/Repack
	AKSH=$ZIP_DIR/anykernel.sh
	cd $KERNEL_DIR
	mkdir $COMPILER

# Defconfig
	DFCF=AtomX-$DEVICE${CAM_LIB}_defconfig
	CONFIG=$KERNEL_DIR/arch/arm64/configs/$DFCF

# Set variables
	if [[ "$COMPILER" == "CLANG" ]]; then
		CC=clang
		HOSTCC=clang
		HOSTCXX=clang++
		C_PATH=$CLANG_PATH
		CC_COMPAT=$CLANG_COMPAT
		ETXRA_FLAGS="CROSS_COMPILE=$CLANG_ARM64"
	elif [[ "$COMPILER" == "GCC" ]]; then
		HOSTCC=gcc
		C_PATH=$GCC_PATH
		CC=aarch64-elf-gcc
		HOSTCXX=aarch64-elf-g++
		CC_COMPAT=$GCC_COMPAT
		ETXRA_FLAGS="LD_LIBRARY_PATH=$GCC_PATH/lib:$LD_LIBRARY_PATH"
	fi

# Compile
	muke() {
		make O=$COMPILER $CFLAG ARCH=arm64 \
		    $FLAG                          \
			CC=$CC                         \
			LLVM=1                         \
			${ETXRA_FLAGS}                 \
			HOSTLD=ld.lld                  \
			HOSTCC=$HOSTCC                 \
			HOSTCXX=$HOSTCXX               \
			PATH=$C_PATH/bin:$PATH         \
			KBUILD_BUILD_USER=$USER        \
			KBUILD_BUILD_HOST=$HOST        \
			CROSS_COMPILE_COMPAT=$CC_COMPAT
	}

	BUILD_START=$(date +"%s")

	if [[ "$COMPILER" == "CLANG" ]]; then
		sed -i '/CONFIG_JUMP_LABEL/ a CONFIG_LTO_CLANG=y' $CONFIG
		sed -i '/CONFIG_LTO_CLANG/ a # CONFIG_THINLTO is not set' $CONFIG
	elif [[ "$COMPILER" == "GCC" ]]; then
		sed -i '/CONFIG_JUMP_LABEL/ a CONFIG_LTO_GCC=y' $CONFIG
		sed -i '/CONFIG_JUMP_LABEL/ a CONFIG_OPTIMIZE_INLINING=y' $CONFIG
	fi

	CFLAG=$DFCF
	muke

	if [[ "$COMPILER" == "CLANG" ]]; then
		sed -i '/CONFIG_LTO_CLANG=y/d' $CONFIG
		sed -i '/# CONFIG_THINLTO is not set/d' $CONFIG
	elif [[ "$COMPILER" == "GCC" ]]; then
		sed -i '/CONFIG_LTO_GCC=y/d' $CONFIG
		sed -i '/CONFIG_OPTIMIZE_INLINING=y/d' $CONFIG
	fi

	CFLAG=-j$(nproc)
	muke

	if [[ -f $KERNEL_DIR/$COMPILER/arch/arm64/boot/Image.gz-dtb ]]; then
		if [[ "$CAM_LIB" == "" ]]; then
			CAM=OLD-CAM
		else
			CAM=$CAM_LIB
		fi

		source $COMPILER/.config
		FINAL_ZIP="$DEVICE$CAM_LIB$CONFIG_LOCALVERSION-${COMPILER}_LTO-`date +"%H%M"`"
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
		telegram-send --format html "\
		**************Atom-X-Kernel**************
		Compiler: <code>$CONFIG_CC_VERSION_TEXT</code>
		Linux Version: <code>$KERNEL_VERSION_LONG</code>
		Builder Version: <code>$VERSION</code>
		Maintainer: <code>$USER</code>
		Device: <code>$NAME</code>
		Codename: <code>$DEVICE</code>
		Camlib: <code>$CAM</code>
		Build Date: <code>$(date +"%Y-%m-%d %H:%M")</code>
		Build Duration: <code>$(($DIFF / 60)).$(($DIFF % 60)) mins</code>
		Changelog: <a href='$SOURCE'> Here </a>"
		export CONTINUE_BUILD="yes"
	else
		telegram-send "Error⚠️ Compilaton failed: Kernel Image missing"
		export CONTINUE_BUILD="no"
		exit 1
	fi
