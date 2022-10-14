#!/bin/bash

#########################    CONFIGURATION    ##############################

# User details
KBUILD_USER="AtomX"
KBUILD_HOST="Drone"

############################################################################

########################    DIRECTOR PATHS   ###############################

# Kernel Directory
KERNEL_DIR=$(pwd)

# Propriatary Directory (default paths may not work!)
PRO_PATH="$KERNEL_DIR/.."

# Anykernel Directories
AK3_DIR="$PRO_PATH/AnyKernel3"
AKVDR="$AK3_DIR/modules/vendor/lib/modules"

# Toolchain Directory
TLDR="$PRO_PATH/toolchains"

# Device Tree Blob Directory
DTB_PATH="$KERNEL_DIR/work/arch/arm64/boot/dts/vendor/qcom"

############################################################################

###############################   MISC   #################################

# functions
error() {
	telegram-send "Error⚠️: $*"
	exit 1
}

success() {
	telegram-send "Success: $*"
}

inform() {
	telegram-send --format html "$@"
}

muke() {
	if [[ -z $COMPILER || -z $COMPILER32 ]]; then
		error "Compiler is missing"
	fi
	if ! make $@ ${MAKE_ARGS[@]} $FLAG; then
		error "make failed"
	fi
}

usage() {
	inform " ./AtomX.sh <arg>
		--compiler   sets the compiler to be used
		--device     sets the device for kernel build
		--silence    Silence shell output of Kbuild"
	exit 2
}

############################################################################

compiler_setup() {
############################  COMPILER SETUP  ##############################
	# default to clang
	CC='clang'
	C_PATH="$TLDR/$CC"
	LLVM_PATH="$C_PATH/bin"
	if [[ $COMPILER == gcc ]]; then
		# Just override the existing declarations
		CC='aarch64-elf-gcc'
		C_PATH="$TLDR/gcc-arm64"
	fi

	C_NAME=$("$LLVM_PATH"/$CC --version | head -n 1 | perl -pe 's/\(http.*?\)//gs')
	if [[ $COMPILER32 == "gcc" ]]; then
		MAKE_ARGS+=("CC_COMPAT=$TLDR/gcc-arm/bin/arm-eabi-gcc" "CROSS_COMPILE_COMPAT=$TLDR/gcc-arm/bin/arm-eabi-")
		C_NAME_32=$($(echo "${MAKE_ARGS[@]}" | sed s/' '/'\n'/g | grep CC_COMPAT | cut -c 11-) --version | head -n 1)
	else
		MAKE_ARGS+=("CROSS_COMPILE_COMPAT=arm-linux-gnueabi-")
		C_NAME_32="$C_NAME"
	fi

	MAKE_ARGS+=("O=work"
		"ARCH=arm64"
		"LLVM=$LLVM_PATH"
		"HOSTLD=ld.lld" "CC=$CC"
		"PATH=$C_PATH/bin:$PATH"
		"KBUILD_BUILD_USER=$KBUILD_USER"
		"KBUILD_BUILD_HOST=$KBUILD_HOST"
		"CROSS_COMPILE=aarch64-linux-gnu-"
		"LD_LIBRARY_PATH=$C_PATH/lib:$LD_LIBRARY_PATH")
############################################################################
}

kernel_builder() {
##################################  BUILD  #################################
	if [[ -z $CODENAME ]]; then
		error 'Codename not present connot proceed'
		exit 1
	fi
	if [[ $BUILD == "clean" ]]; then
		inform "Cleaning work directory, please wait...."
		muke -s clean mrproper distclean
	fi

	# Build Start
	BUILD_START=$(date +"%s")

	# Make .config
	muke "vendor/${CODENAME}-${SUFFIX}_defconfig"

	source work/.config
	MOD_NAME="$(muke kernelrelease -s)"
	KERNEL_VERSION=$(echo "$MOD_NAME" | cut -c -7)

	inform "
		*************Build Triggered*************
		Date: <code>$(date +"%Y-%m-%d %H:%M")</code>
		Build Number: <code>$DRONE_BUILD_NUMBER</code>
		Linux Version: <code>$KERNEL_VERSION</code>
		Kernel Name: <code>$MOD_NAME</code>
		Device: <code>$DEVICENAME</code>
		Codename: <code>$CODENAME</code>
		Compiler: <code>$C_NAME</code>
		Compiler_32: <code>$C_NAME_32</code>
	"

	# Compile
	muke -j$(nproc)

	if [[ $CONFIG_MODULES == "y" ]]; then
		muke -j$(nproc)        \
			'modules_install'    \
			INSTALL_MOD_STRIP=1  \
			INSTALL_MOD_PATH="modules"
	fi

	# Build End
	BUILD_END=$(date +"%s")

	DIFF=$(($BUILD_END - $BUILD_START))

	zipper
############################################################################
}

zipper() {
####################################  ZIP  #################################
	TARGET="$(muke image_name -s)"
	if [[ ! -f $KERNEL_DIR/work/$TARGET ]]; then
		error 'Kernel image not found'
	fi
	if [[ ! -d $AK3_DIR ]]; then
		error 'Anykernel not present cannot zip'
	fi
	if [[ ! -d "$KERNEL_DIR/out" ]]; then
		mkdir "$KERNEL_DIR"/out
	fi

	# Making sure everything is ok before making zip
	cd "$AK3_DIR" || exit
	make clean
	cd "$KERNEL_DIR" || exit

	cp "$KERNEL_DIR"/work/"$TARGET" "$AK3_DIR"
	cp "$DTB_PATH"/*.dtb "$AK3_DIR"/dtb
	cp "$DTB_PATH"/*.img "$AK3_DIR"/

	if [[ $CONFIG_MODULES == "y" ]]; then
		MOD_PATH="work/modules/lib/modules/$MOD_NAME"

		sed -i 's/\(kernel\/[^: ]*\/\)\([^: ]*\.ko\)/\/vendor\/lib\/modules\/\2/g' "$MOD_PATH"/modules.dep
		sed -i 's/.*\///g' "$MOD_PATH"/modules.order

		# shellcheck disable=SC2046
		# cp breaks with advised follow up
		cp $(find "$MOD_PATH" -name '*.ko') "$AKVDR"/
		cp "$MOD_PATH"/modules.{alias,dep,softdep} "$AKVDR"/
		cp "$MOD_PATH"/modules.order "$AKVDR"/modules.load
	fi

	LAST_COMMIT=$(git show -s --format=%s)
	LAST_HASH=$(git rev-parse --short HEAD)

	cd "$AK3_DIR" || exit

	make zip VERSION="$(echo "$CONFIG_LOCALVERSION" | cut -c 8-)" CUSTOM="$LAST_HASH"

	inform "
		*************AtomX-Kernel*************
		Linux Version: <code>$KERNEL_VERSION</code>
		Kernel Name: <code>$MOD_NAME</code>
		CI: <code>$KBUILD_HOST</code>
		Core count: <code>$(nproc)</code>
		Compiler: <code>$C_NAME</code>
		Compiler_32: <code>$C_NAME_32</code>
		Device: <code>$DEVICENAME</code>
		Codename: <code>$CODENAME</code>
		Build Date: <code>$(date +"%Y-%m-%d %H:%M")</code>

		-----------last commit details-----------
		Last commit (name): <code>$LAST_COMMIT</code>

		Last commit (hash): <code>$LAST_HASH</code>
	"

	telegram-send --file *-signed.zip

	make clean

	cd "$KERNEL_DIR" || exit

	success "build completed in $((DIFF / 60)).$((DIFF % 60)) mins"

############################################################################
}

###############################  COMMAND_MODE  ##############################
if [[ -z $* ]]; then
	usage
fi
if [[ $* =~ "--silence" ]]; then
	MAKE_ARGS+=("-s")
fi
for arg in "$@"; do
	case "${arg}" in
		"--compiler="*)
			COMPILER=${arg#*=}
			COMPILER=${COMPILER,,}
			if [[ -z $COMPILER ]]; then
				usage
				break
			fi
			;&
		"--compiler32="*)
			COMPILER32=${arg#*=}
			COMPILER32=${COMPILER32,,}
			if [[ -z $COMPILER32 ]]; then
				COMPILER32="clang"
			fi
			compiler_setup
			;;
		"--device="*)
			CODE_NAME=${arg#*=}
			case $CODE_NAME in
				lisa)
					DEVICENAME='Xiaomi 11 lite 5G NE'
					CODENAME='lisa'
					SUFFIX='qgki'
					;;
				*)
					error 'device not supported'
				;;
			esac
		;;
		"--clean")
			BUILD='clean'
			;;
		*)
			usage
		;;
	esac
done
############################################################################

# Remove testing of System.map as test always fails to check for file
# DO NOT MODIFY!!!!
sed -i '13d;14d;15d;16d;17d' "$KERNEL_DIR"/scripts/depmod.sh

kernel_builder
