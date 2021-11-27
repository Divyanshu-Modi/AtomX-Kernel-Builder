#bin/#!/bin/bash
# SPDX-License-Identifier: GPL-3.0
# Made by Divyanshu-Modi
# Revision: 18-09-2021 V1

	VERSION='8.0'
	COMPILER=""

# USER
	USER='OGIndian'
	HOST='AtomX-Drone'

# DEVICE CONFIG
	DEVICE=$1
	case $DEVICE in
		tulip)
			DEVICENAME='Redmi Note 6 Pro'
			DEVICE='tulip'
			DEVICE2='tulix'
		;;
		whyred)
			DEVICENAME='Redmi Note 5 (Pro)'
			DEVICE='whyred'
		;;
		wayne)
			DEVICENAME='Mi A2 / 6X'
			DEVICE='wayne'
			DEVICE2='jasmine_sprout'
		;;
		lavender)
			DEVICENAME='Redmi Note 7'
			DEVICE='lavender'
		;;
		*)
			DEVICENAME='Unknown'
		;;
	esac

# PATH
	KERNEL_DIR="$HOME/Kernel"
	ZIP_DIR="$HOME/Repack"
	AKSH="$ZIP_DIR/anykernel.sh"

# DEFCONFIG
	DFCF="vendor/${DEVICE}-perf_defconfig"
	CONFIG="$KERNEL_DIR/arch/arm64/configs/$DFCF"

# Set variables
	case $COMPILER in
		gcc)
			COMPILER='gcc'
			HOSTCC='gcc'
			CC_64='aarch64-elf-'
			CC='aarch64-elf-gcc'
			CC_COMPAT='arm-eabi-'
			HOSTCXX='aarch64-elf-g++'
			C_PATH="$HOME/gcc-arm64/bin:$HOME/gcc-arm32/"
		;;
		*)
			COMPILER='clang'
			CC='clang'
			HOSTCC="$CC"
			HOSTCXX="$CC++"
			CC_64='aarch64-linux-gnu-'
			CC_COMPAT='arm-linux-gnueabi-'
			C_PATH="$HOME/clang"
		;;
	esac

	muke() {
		make O=$COMPILER $CFLAG ARCH=arm64 \
		    $FLAG                          \
			CC=$CC                         \
			LLVM=1                         \
			LLVM_IAS=1                     \
			HOSTCC=$HOSTCC                 \
			HOSTCXX=$HOSTCXX               \
			CROSS_COMPILE=$CC_64           \
			PATH=$C_PATH/bin:$PATH         \
			KBUILD_BUILD_USER=$USER        \
			KBUILD_BUILD_HOST=$HOST        \
			CROSS_COMPILE_COMPAT=$CC_COMPAT\
			LD_LIBRARY_PATH=$C_PATH/lib:$LD_LIBRARY_PATH
	}

	sed -i '/CONFIG_LLVM_POLLY=y/ a CONFIG_LTO_CLANG_FULL=y' $CONFIG

	CFLAG=$DFCF
	muke

	source $COMPILER/.config
	if [[ "$CONFIG_LTO_CLANG_FULL" == "y" ]]; then
		VARIANT='FULL_LTO'
	elif [[ "$CONFIG_LTO_CLANG_THIN" == "y" ]]; then
		VARIANT='THIN_LTO'
	else
		VARIANT='NON_LTO'
	fi
	telegram-send --format html "Building: <code>$VARIANT</code>"

	BUILD_START=$(date +"%s")

	CFLAG=-j$(nproc)
	muke

	BUILD_END=$(date +"%s")

	if [[ -f $KERNEL_DIR/$COMPILER/arch/arm64/boot/Image.gz-dtb ]]; then
		FDEVICE=${DEVICE^^}
		KNAME=$(echo "$CONFIG_LOCALVERSION" | cut -c 2-)
		KV=$(cat $KERNEL_DIR/$COMPILER/include/generated/utsrelease.h | cut -c 21- | tr -d '"')

		cp $KERNEL_DIR/$COMPILER/arch/arm64/boot/Image.gz-dtb $ZIP_DIR/

		sed -i "s/demo1/$DEVICE/g" $AKSH
		if [[ "$DEVICE2" ]]; then
			sed -i "/device.name1/ a device.name2=$DEVICE2" $AKSH
		fi

		cd $ZIP_DIR

		FINAL_ZIP="$KNAME-$FDEVICE-$VARIANT-`date +"%H%M"`"

		zip -r9 "$FINAL_ZIP".zip * -x README.md *placeholder zipsigner*

		java -jar zipsigner* "$FINAL_ZIP.zip" "$FINAL_ZIP-signed.zip"

		FINAL_ZIP="$FINAL_ZIP-signed.zip"

		telegram-send --file $FINAL_ZIP --timeout 40.0

		rm *.zip Image.gz-dtb

		cd $KERNEL_DIR

		sed -i "s/$DEVICE/demo1/g" $AKSH
		if [[ "$DEVICE2" ]]; then
			sed -i "/device.name2/d" $AKSH
		fi

		DIFF=$(($BUILD_END - $BUILD_START))
		COMPILER_NAME="$(cat $KERNEL_DIR/$COMPILER/include/generated/compile.h | sed -n 7p | cut -c 24- | tr -d '"'))"
		HEAD="$(git log --oneline -n1 --decorate=auto)"

		wget https://telegra.ph/file/0441c7d01fab1a8abe5ed.jpg
		mv *.jpg banner.jpg
		telegram-send --image banner.jpg
		telegram-send --disable-web-page-preview --format html "\
		**************Atom-X-Kernel**************
		Compiler: <code>$COMPILER</code>
		Compiler-name: <code>$COMPILER_NAME</code>
		Linux Version: <code>$KV</code>
		Builder Version: <code>$VERSION</code>
		Build Type: <code>$VARIANT</code>
		Maintainer: <code>$USER</code>
		Device: <code>$DEVICENAME</code>
		Codename: <code>$DEVICE</code>
		Build Date: <code>$(date +"%Y-%m-%d %H:%M")</code>
		Build Duration: <code>$(($DIFF / 60)).$(($DIFF % 60)) mins</code>
		Commit Head: <code>$HEAD</code>
		Changelog: <a href='$SOURCE'> Here </a>"
	else
		telegram-send "Error⚠️ $COMPILER failed to build"
		exit 1
	fi
