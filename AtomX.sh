#########################    CONFIGURATION    ##############################

# User details
KBUILD_USER="AtomX"
KBUILD_HOST="Drone"

# Build type (Fresh build: clean | incremental build: dirty)
# (default: dirty | modes: clean, dirty)
BUILD='clean'

############################################################################

########################    DIRECTOR PATHS   ###############################

# Kernel Directory
KERNEL_DIR=`pwd`

# Propriatary Directory (default paths may not work!)
PRO_PATH="$KERNEL_DIR/.."

# Anykernel Directories
AK3_DIR="$PRO_PATH/AnyKernel3"
AKSH="$AK3_DIR/anykernel.sh"
AKVDR="$AK3_DIR/modules/vendor/lib/modules"

# Toolchain Directory
TLDR="$PRO_PATH/toolchains"

# Device Tree Blob Directory
DTB_PATH="$KERNEL_DIR/work/arch/arm64/boot/dts/vendor/qcom"

############################################################################

###############################   MISC   #################################

# functions
error() {
	telegram-send "Error⚠️: $@"
	exit 1
}

success() {
	telegram-send "Success: $@"
	exit 0
}

inform() {
	telegram-send --format html "$@"
}

muke() {
	if [[ "$SILENCE" == "1" ]]; then
		MAKE_ARGS+=("-s")
	fi
	if [[ "$LOG" == "1" ]]; then
		FLAG='2>&1 | tee ../log.txt'
	fi
	make $@ ${MAKE_ARGS[@]} $FLAG
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
	MAKE_ARGS=()
	case $COMPILER in
		clang)
			CC='clang'
			C_PATH="$TLDR/clang"
		;;
		gcc)
			CC='aarch64-linux-gnu-gcc'
			C_PATH="$TLDR/gcc-arm64-gnu/bin:$TLDR/clang"
		;;
	esac
	CC_32="$TLDR/gcc-arm/bin/arm-eabi-"
	CC_COMPAT="$TLDR/gcc-arm/bin/arm-eabi-gcc"
	MAKE_ARGS+=("ARCH=arm64" "O=work" "LLVM=1" "HOSTLD=ld.lld" 
				"PATH=$C_PATH/bin:$PATH" "CC=$CC" "CC_COMPAT=$CC_COMPAT"
				"CROSS_COMPILE=aarch64-linux-gnu-" "CROSS_COMPILE_COMPAT=$CC_32"
				"KBUILD_BUILD_USER=$KBUILD_USER" "KBUILD_BUILD_HOST=$KBUILD_HOST"
				"LD_LIBRARY_PATH=$C_PATH/lib:$LD_LIBRARY_PATH")
############################################################################
}

kernel_builder() {
##################################  BUILD  #################################
	if [[ -z $CODENAME ]]; then
		error 'Codename not present connot proceed'
		exit 1
	fi

	case $BUILD in
		clean)
			rm -rf work || mkdir work
		;;
		*)
			muke clean mrproper distclean
		;;
	esac

	# Build Start
	BUILD_START=$(date +"%s")

	DFCF="vendor/${CODENAME}-${SUFFIX}_defconfig"

	# Make .config
	muke $DFCF

	source work/.config

	inform "
		*************Build Triggered*************
		Date: <code>$(date +"%Y-%m-%d %H:%M")</code>
		Build Number: <code>$DRONE_BUILD_NUMBER</code>
		Device: <code>$DEVICENAME</code>
		Codename: <code>$CODENAME</code>
		Compiler: <code>$(echo $CONFIG_CC_VERSION_TEXT | head -n 1 | perl -pe 's/\(http.*?\)//gs')</code>
		Compiler_32: <code>$($CC_COMPAT --version | head -n 1)</code>
	"

	# Compile
	muke -j$(nproc)

	if [[ "$MODULES" == "1" ]] && [[ $CONFIG_MODULES == "y" ]]; then
		muke -j$(nproc)        \
			'modules_install'    \
			INSTALL_MOD_STRIP=1  \
			INSTALL_MOD_PATH="modules"
	fi

	# Build End
	BUILD_END=$(date +"%s")

	DIFF=$(($BUILD_END - $BUILD_START))

	if [[ -f $KERNEL_DIR/work/arch/arm64/boot/$TARGET ]]; then
		zipper
	else
		error 'Kernel image not found'
	fi
############################################################################
}

zipper() {
####################################  ZIP  #################################
	if [[ ! -d $AK3_DIR ]]; then
		error 'Anykernel not present cannot zip'
	fi
	if [[ ! -d "$KERNEL_DIR/out" ]]; then
		mkdir $KERNEL_DIR/out
	fi

	cp $KERNEL_DIR/work/arch/arm64/boot/$TARGET $AK3_DIR
	cp $DTB_PATH/*.dtb $AK3_DIR/dtb
	cp $DTB_PATH/*.img $AK3_DIR/
	if [[ "$MODULES" == "1" ]] && [[ $CONFIG_MODULES == "y" ]]; then
		MOD_NAME="$(cat work/include/generated/utsrelease.h | cut -c 21- | tr -d '"')"
		MOD_PATH="work/modules/lib/modules/$MOD_NAME"

		cp $(find $MOD_PATH -name '*.ko') $AKVDR
		cp $MOD_PATH/modules.{alias,dep,softdep} $AKVDR
		cp $MOD_PATH/modules.order $AKVDR/modules.load
		sed -i 's/\(kernel\/[^: ]*\/\)\([^: ]*\.ko\)/\/vendor\/lib\/modules\/\2/g' $AKVDR/modules.dep
		sed -i 's/.*\///g' $AKVDR/modules.load
	fi

	VERSION=`echo $CONFIG_LOCALVERSION | cut -c 8-`
	KERNEL_VERSION=$(make kernelversion)
	LAST_COMMIT=$(git show -s --format=%s)
	LAST_HASH=$(git rev-parse --short HEAD)

	cd $AK3_DIR

	make zip VERSION=$VERSION

	inform "
		*************AtomX-Kernel*************
		Linux Version: <code>$KERNEL_VERSION</code>
		AtomX-Version: <code>$VERSION</code>
		CI: <code>$KBUILD_HOST</code>
		Core count: <code>$(nproc)</code>
		Compiler: <code>$($C_PATH/bin/$CC --version | head -n 1 | perl -pe 's/\(http.*?\)//gs')</code>
		Compiler_32: <code>$($CC_COMPAT --version | head -n 1)</code>
		Device: <code>$DEVICENAME</code>
		Codename: <code>$CODENAME</code>
		Build Date: <code>$(date +"%Y-%m-%d %H:%M")</code>
		Build Type: <code>$BUILD_TYPE</code>

		-----------last commit details-----------
		Last commit (name): <code>$LAST_COMMIT</code>

		Last commit (hash): <code>$LAST_HASH</code>
	"

	telegram-send --file *-signed.zip

	make clean

	cd $KERNEL_DIR

	success "build completed in $(($DIFF / 60)).$(($DIFF % 60)) mins"

############################################################################
}

###############################  COMMAND_MODE  ##############################
if [[ -z $* ]]; then
	usage
fi

for arg in "$@"; do
	case "${arg}" in
		"--compiler="*)
			COMPILER=${arg#*=}
			COMPILER=${COMPILER,,}
			case $COMPILER in
				clang | gcc)
					compiler_setup
				;;
				*)
					usage
				;;
			esac
		;;
		"--device="*)
			CODE_NAME=${arg#*=}
			case $CODE_NAME in
				lisa)
					DEVICENAME='Xiaomi 11 lite 5G NE'
					CODENAME='lisa'
					SUFFIX='qgki'
					MODULES='1'
					TARGET='Image'
				;;
				*)
					error 'device not supported'
				;;
			esac
		;;
		"--silence")
			SILENCE='1'
		;;
		*)
			usage
		;;
	esac
done
############################################################################

# Remove testing of System.map as test always fails to check for file
# DO NOT MODIFY!!!!
sed -i '13d;14d;15d;16d;17d' $KERNEL_DIR/scripts/depmod.sh

kernel_builder