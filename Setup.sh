#!/bin/bash

###############################   MISC   ###################################

	gut() {
		gh repo clone $1 $3 -- --depth=1 -b $2
	}

############################################################################

######################## Setup Telegram API ################################
	if [[ ! $(which telegram-send) ]]; then
		pip3 -q install telegram-send
	fi
	sed -i s/demo1/"${BOT_API_KEY}"/g telegram-send.conf
	sed -i s/demo2/"${CHAT_ID}"/g telegram-send.conf
	mkdir "$HOME"/.config
	mv telegram-send.conf "$HOME"/.config/telegram-send.conf

############################################################################

############################## Setup Toolchains ############################
	toolchains_setup() {
		if [[ ! -d /usr/$1 ]]; then
			exit
		else
			ln -s /usr/"$1" "$2"
		fi
	}

	mkdir toolchains
	toolchains_setup gcc64 toolchains/gcc-arm64 https://github.com/mvaisakh/gcc-arm64 gcc-master
	toolchains_setup gcc32 toolchains/gcc-arm https://github.com/mvaisakh/gcc-arm gcc-master
	#toolchains_setup clang toolchains/clang https://gitlab.com/dakkshesh07/neutron-clang Neutron-16
############################################################################

############################## Setup AnyKernel #############################

	gut Atom-X-Devs/AnyKernel3 main AnyKernel3

############################################################################

############################## Setup Kernel ################################

	gut Atom-X-Devs/android_kernel_xiaomi_sm7325 codelinaro Kernel

############################################################################

############################ Setup Scripts #################################

	#mv AtomX.sh Kernel/AtomX.sh
	#cd Kernel || exit
	#bash AtomX.sh --compiler=clang --device=lisa
	exit 0

############################################################################
