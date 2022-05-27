#bin/#!/bin/bash

###############################   MISC   ###################################

	gut() {
		git clone --depth=1 -q $@
	}

############################################################################

######################## Setup Telegram API ################################
	if [[ $(which pip) ]]; then
		PIP=pip
	elif [[ $(which pip3) ]]; then
		PIP=pip3
	elif [[ ! $(which pip2) ]]; then
		PIP=pip2
	else
		exit
	fi
	if [[ ! $(which telegram-send) ]]; then
		$PIP -q install telegram-send
	fi
	sed -i s/demo1/${BOT_API_KEY}/g telegram-send.conf
	sed -i s/demo2/${CHAT_ID}/g telegram-send.conf
	mkdir $HOME/.config
	mv telegram-send.conf $HOME/.config/telegram-send.conf

############################################################################

############################## Setup Toolchains ############################

	mkdir toolchains
	if [[ ! -d /usr/gcc64 ]]; then
		gut https://github.com/mvaisakh/gcc-arm64 -b gcc-master toolchains/gcc-arm64
	else
		ln -s /usr/gcc64 toolchains/gcc-arm64
	fi
	if [[ ! -d /usr/gcc32 ]]; then
		gut https://github.com/mvaisakh/gcc-arm -b gcc-master toolchains/gcc-arm
	else
		ln -s /usr/gcc32 toolchains/gcc-arm
	fi
	if [[ ! -d /usr/clang ]]; then
		gut https://gitlab.com/ElectroPerf/atom-x-clang toolchains/clang
	else
		ln -s /usr/clang toolchains/clang
	fi
############################################################################

############################## Setup AnyKernel #############################

	gut https://github.com/Atom-X-Devs/AnyKernel3 -b main AnyKernel3

############################################################################

############################## Setup Kernel ################################

	gut https://github.com/Atom-X-Devs/android_kernel_xiaomi_sm7325 -b codelinaro Kernel

############################################################################

############################ Setup Scripts #################################

	mv AtomX.sh Kernel/AtomX.sh
	cd Kernel
#	bash AtomX.sh --compiler=clang --device=lisa --pixel_thermals
	bash AtomX.sh --compiler=clang --device=lisa

# if this is called build failed
	exit 1

############################################################################
