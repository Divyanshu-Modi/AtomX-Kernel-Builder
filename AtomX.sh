#########################  COMPILER CONFIG ##################################

# User details
KBUILD_USER="$USER"
KBUILD_HOST=$(uname -n)

# Compiler
# (default: clang | modes: clang, gcc) 
COMPILER='clang'

############################################################################

##########################  DEVICES CONFIG  ################################

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

# Do modules (Perform modules post compile process: 1 | No modules: 0)
# (default: 0 | modes: 0, 1) 
MODULES='1'

############################################################################

########################    DIRECTOR PATHS   ###############################

# Kernel directory
KERNEL_DIR=`pwd`

# PATH (default paths may not work!)
PRO_PATH="$KERNEL_DIR/../"

# Anykernel directories
AK3_DIR="$PRO_PATH/AnyKernel3"
AKSH="$AK3_DIR/anykernel.sh"
AKVDR="$AK3_DIR/modules/vendor/lib/modules"

# Toolchain directory
TLDR="$PRO_PATH/toolchains"

############################################################################

###############################   STATUS   #################################

# functions
error() {
	telegram-send "Error⚠️: $1"
	exit 1
}

success() {
	telegram-send "Success: $1"
	exit 0
}

inform() {
	telegram-send "$1"
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

muke() {
	CFLAG=$1
	FLAG=$2

	make O=work $CFLAG ARCH=arm64 $FLAG  \
		CC=$CC                           \
		LLVM=1                           \
		LLVM_IAS=1                       \
		HOSTLD=ld.lld                    \
		HOSTCC=$HOSTCC                   \
		HOSTCXX=$HOSTCXX                 \
		CROSS_COMPILE=$CC_64             \
		CC_COMPAT=$CC_COMPAT             \
		DTC_EXT=/usr/bin/dtc             \
		PATH=$C_PATH/bin:$PATH           \
		CROSS_COMPILE_COMPAT=$CC_32      \
		KBUILD_BUILD_USER=$KBUILD_USER   \
		KBUILD_BUILD_HOST=$KBUILD_HOST   \
		LD_LIBRARY_PATH=$C_PATH/lib:$LD_LIBRARY_PATH
}

############################################################################
}

build() {
##################################  BUILD  #################################
rm -rf work || mkdir work

DFCF="vendor/${CODENAME}-${SUFFIX}_defconfig"

# Build Start
inform "                Build Started                "

BUILD_START=$(date +"%s")

# Make .config
muke $DFCF

inform "                Building Kernel Image                "

# Compile
muke -j$(nproc)

if [[ "$MODULES" == "1" ]]; then
	inform "                Building Kernel Modules                "
	muke -j$(nproc) 'modules_prepare'

	muke -j$(nproc) "modules INSTALL_MOD_PATH="$KERNEL_DIR"/out/modules"

	muke -j$(nproc) "modules_install INSTALL_MOD_PATH="$KERNEL_DIR"/out/modules"
fi

# Build End
BUILD_END=$(date +"%s")

if [[ -f $KERNEL_DIR/work/arch/arm64/boot/$TARGET ]]; then
   zip_ak
else
   error 'Kernel image not found'
fi
############################################################################
}

build_dtb() {
##########################   DTBO BUILDER   #################################
if [[ "$1" == "dtbo.img" ]]; then
   inform "                 Building dtbo.img                "
else
   inform "                 Building dtb.img                "
fi

python2 scripts/mkdtboimg.py create          \
	$AK3_DIR/$1                               \
	--page_size=4096                          \
	$KERNEL_DIR/work/arch/arm64/boot/dts/vendor/qcom/$2
############################################################################
}

zip_ak() {
####################################  ZIP  #################################
	if [[ ! -d $AK3_DIR ]]; then
	   error 'Anykernel not present cannot zip'
	fi

	source work/.config

	FDEVICE=${CODENAME^^}
	KNAME=$(echo "$CONFIG_LOCALVERSION" | cut -c 2-)
	KV=$(cat $KERNEL_DIR/work/include/generated/utsrelease.h | cut -c 21- | tr -d '"')

	inform "                Cloning Image                "
	cp $KERNEL_DIR/work/arch/arm64/boot/$TARGET $AK3_DIR
	if [[ "$MODULES" == "1" ]]; then
		inform "                Cloning Modules                "
		cp $(find out/modules/lib/modules/5.4* -name '*.ko') $AKVDR
		cp out/modules/lib/modules/5.4*/modules.{alias,dep,softdep} $AKVDR
		cp out/modules/lib/modules/5.4*/modules.order $AKVDR/modules.load
		sed -i 's/\(kernel\/[^: ]*\/\)\([^: ]*\.ko\)/\/vendor\/lib\/modules\/\2/g' $AKVDR/modules.dep
		sed -i 's/.*\///g' $AKVDR/modules.load
		cp $KERNEL_DIR/work/arch/arm64/boot/dts/vendor/qcom/*.dtb $AK3_DIR/dtb
#		build_dtb 'dtb/dtb.img' *.dtb
		build_dtb 'dtbo.img' *.dtbo
	else
		if [[ ! -d "$KERNEL_DIR/out" ]]; then
			mkdir $KERNEL_DIR/out
		fi
	fi

	sed -i "s/demo1/$CODENAME/g" $AKSH
	if [[ "$CODENAME2" != "" ]]; then
		sed -i "/device.name1/ a device.name2=$CODENAME2" $AKSH
	fi

	cd $AK3_DIR

	FINAL_ZIP="$KNAME-$FDEVICE-`date +"%H%M"`"

	inform "                Zipping started                "
	zip -r9 "$FINAL_ZIP".zip * -x README.md *placeholder zipsigner*

	inform "                 Signing Zip                "
	java -jar zipsigner* "$FINAL_ZIP.zip" "$FINAL_ZIP-signed.zip"

	FINAL_ZIP="$FINAL_ZIP-signed.zip"

	cp $FINAL_ZIP $KERNEL_DIR/out
	telegram-send --file $KERNEL_DIR/out/$FINAL_ZIP

	if [[ "$MODULES" == "1" ]]; then
		rm modules/vendor/lib/modules/modules.{alias,dep,softdep,load}
		TARGET="modules/vendor/lib/modules/*.ko\
				dtbo.img\
				dtb/dtb.img\
				$TARGET"
	fi
	rm *.zip $TARGET

	cd $KERNEL_DIR

	sed -i "s/$CODENAME/demo1/g" $AKSH
	if [[ "$CODENAME2" != "" ]]; then
		sed -i "/device.name2/d" $AKSH
	fi

	DIFF=$(($BUILD_END - $BUILD_START))

	success "build completed in $(($DIFF / 60)).$(($DIFF % 60)) mins"

############################################################################
}

compiler_setup
build