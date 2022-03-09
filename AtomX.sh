#########################    CONFIGURATION    ##############################

# User details
KBUILD_USER="AtomX"
KBUILD_HOST=$(uname -n)

# Verbose mode (verbose build: 0 | silent build: 1) 
# (default: 0 | modes: 0, 1)
SILENCE='0'

# Do modules (Perform modules post compile process: 1 | No modules: 0)
# (default: 0 | modes: 0, 1)
MODULES='1'

# Build type (Fresh build: clean | incremental build: dirty)
# (default: dirty | modes: clean, dirty)
BUILD='clean'

# Compiler
# (default: clang | modes: clang, gcc) 
COMPILER='clang'

#  DEVICES CONFIG  #

# Device Name
# Eg: (For lisa: Xiaomi 11 lite 5G NE) 
DEVICENAME='Xiaomi 11 lite 5G NE'

# Device Codename
# Eg: (For lisa: Xiaomi 11 lite 5G NE) 
CODENAME='lisa'

# Defconfig Suffix
# Eg: (For perf defconfig: perf, For QGKI defconfig: qgki) 
SUFFIX='qgki'

# Target Image
# Eg: (image: Image, Image.gz, Image.gz-dtb) 
TARGET='Image'

############################################################################

########################    DIRECTOR PATHS   ###############################

# Kernel directory
KERNEL_DIR=`pwd`

# PATH (default paths may not work!)
PRO_PATH="$KERNEL_DIR/.."

# Anykernel directories
AK3_DIR="$PRO_PATH/AnyKernel3"
AKSH="$AK3_DIR/anykernel.sh"
AKVDR="$AK3_DIR/modules/vendor/lib/modules"

# Toolchain directory
TLDR="$PRO_PATH/toolchains"

# DTS path
DTS_PATH="$KERNEL_DIR/work/arch/arm64/boot/dts/vendor/qcom"

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
	telegram-send "Inform: $@"
}

muke() {
	if [[ "$SILENCE" == "1" ]]; then
		KERN_MAKE_ARGS="-s $KERN_MAKE_ARGS"
	fi

	make $@ $KERN_MAKE_ARGS
}

############################################################################

compiler_setup() {
############################  COMPILER SETUP  ##############################
	case $COMPILER in
		clang)
			CC='clang'
			HOSTCC="$CC"
			HOSTCXX="$CC++"
			CC_64='aarch64-linux-gnu-'
			C_PATH="$TLDR/clang"
		;;
		gcc)
			HOSTCC='gcc'
			CC_64='aarch64-elf-'
			CC='aarch64-elf-gcc'
			HOSTCXX='aarch64-elf-g++'
			C_PATH="$TLDR/gcc-arm64"
		;;
	esac
	CC_32="$TLDR/gcc-arm/bin/arm-eabi-"
	CC_COMPAT="$TLDR/gcc-arm/bin/arm-eabi-gcc"

	KERN_MAKE_ARGS="O=work ARCH=arm64    \
		CC=$CC                           \
		LLVM=1                           \
		LLVM_IAS=1                       \
		HOSTLD=ld.lld                    \
		HOSTCC=$HOSTCC                   \
		HOSTCXX=$HOSTCXX                 \
		CROSS_COMPILE=$CC_64             \
		CC_COMPAT=$CC_COMPAT             \
		DTC_EXT=$(which dtc)             \
		PATH=$C_PATH/bin:$PATH           \
		CROSS_COMPILE_COMPAT=$CC_32      \
		KBUILD_BUILD_USER=$KBUILD_USER   \
		KBUILD_BUILD_HOST=$KBUILD_HOST   \
		LD_LIBRARY_PATH=$C_PATH/lib:$LD_LIBRARY_PATH"
############################################################################
}

build() {
##################################  BUILD  #################################
	case $BUILD in
		clean)
			rm -rf work || mkdir work
		;;
		*)
			muke clean mrproper distclean
		;;
	esac

	DFCF="vendor/${CODENAME}-${SUFFIX}_defconfig"
	DFCF="lisa_defconfig"

	inform "Build Started"

	# Build Start
	BUILD_START=$(date +"%s")

	# Make .config
	muke $DFCF

	inform "Building Kernel - Stage 1"

	# Compile
	muke -j$(nproc)

	if [[ "$MODULES" == "1" ]]; then
		inform "Building Kernel Modules - Stage 2"

		muke -j$(nproc) 'modules_install' \
						INSTALL_MOD_STRIP=1 \
						INSTALL_MOD_PATH="modules"
	fi

	# Build End
	BUILD_END=$(date +"%s")

	DIFF=$(($BUILD_END - $BUILD_START))

	if [[ -f $KERNEL_DIR/work/arch/arm64/boot/$TARGET ]]; then
		zip_ak
	else
		error 'Kernel image not found'
	fi
############################################################################
}

zip_ak() {
####################################  ZIP  #################################
	if [[ ! -d $AK3_DIR ]]; then
		error 'Anykernel not present cannot zip'
	fi

	cp $KERNEL_DIR/work/arch/arm64/boot/$TARGET $AK3_DIR
	if [[ "$MODULES" == "1" ]]; then
		inform "Building Kernel Zip - Stage 3"

		MOD_NAME="$(cat work/include/generated/utsrelease.h | cut -c 21- | tr -d '"')"
		MOD_PATH="work/modules/lib/modules/$MOD_NAME"

		cp $(find $MOD_PATH -name '*.ko') $AKVDR
		cp $MOD_PATH/modules.{alias,dep,softdep} $AKVDR
		cp $MOD_PATH/modules.order $AKVDR/modules.load
		sed -i 's/\(kernel\/[^: ]*\/\)\([^: ]*\.ko\)/\/vendor\/lib\/modules\/\2/g' $AKVDR/modules.dep
		sed -i 's/.*\///g' $AKVDR/modules.load
		cp $DTS_PATH/*.dtb $AK3_DIR/dtb
		cp $DTS_PATH/*.img $AK3_DIR/
	fi

	cd $AK3_DIR

	make zip

	inform "Pushing zip to telegram"
	telegram-send --file *-signed.zip

	make clean

	cd $KERNEL_DIR

	success "build completed in $(($DIFF / 60)).$(($DIFF % 60)) mins"

############################################################################
}

# Remove testing of System.map as test always fails to check for file
# DO NOT MODIFY!!!!
sed -i '13d;14d;15d;16d;17d' $KERNEL_DIR/scripts/depmod.sh

compiler_setup
build
