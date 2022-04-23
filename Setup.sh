#bin/#!/bin/bash

###############################   MISC   ###################################

	gut() {
		git clone --depth=1 -q $@
	}

############################################################################

######################## Setup Telegram API ################################
	if [[ ! $(which telegram-send) ]]; then
		pip -q install telegram-send
	fi
	sed -i s/demo1/${BOT_API_KEY}/g telegram-send.conf
	sed -i s/demo2/${CHAT_ID}/g telegram-send.conf
	mkdir $HOME/.config
	mv telegram-send.conf $HOME/.config/telegram-send.conf

############################################################################

############################## Setup Toolchains ############################

	mkdir toolchains
	if [[ ! -d /usr/gcc64 ]]; then
		gut https://github.com/mvaisakh/gcc-arm64 -b gcc-master toolchains/gcc-arm
	else
		ln -s /usr/gcc64 toolchains/gcc-arm64
	fi
	if [[ ! -d /usr/gcc32 ]]; then
		gut https://github.com/mvaisakh/gcc-arm -b gcc-master toolchains/gcc-arm
	else
		ln -s /usr/gcc32 toolchains/gcc-arm
	fi
	if [[ ! -d /usr/clang ]]; then
		gut https://gitlab.com/dakkshesh07/neutron-clang toolchains/clang
	else
		ln -s /usr/clang toolchains/clang
	fi
############################################################################

############################## Setup AnyKernel #############################

	gut https://github.com/Atom-X-Devs/AnyKernel3 -b main AnyKernel3

############################################################################

############################## Setup Kernel ################################

	gut https://github.com/Atom-X-Devs/android_kernel_xiaomi_sm7325 -b kernel.lnx.5.4.r1-rel Kernel

############################################################################

############################ Setup Scripts #################################

	mv AtomX.sh Kernel/AtomX.sh
	cd Kernel
	bash AtomX.sh --compiler=clang --device=lisa

############################################################################