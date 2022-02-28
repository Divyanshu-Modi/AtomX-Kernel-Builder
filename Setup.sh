#bin/#!/bin/bash

###############################   MISC   ###################################

	gut() {
		git clone --depth=1 -q $@
	}

	inform() {
		telegram-send "setup: $@"
	}

############################################################################

######################## Setup Telegram API ################################

	pip install telegram-send
	sed -i s/demo1/${BOT_API_KEY}/g telegram-send.conf
	sed -i s/demo2/${CHAT_ID}/g telegram-send.conf
	mkdir $HOME/.config
	mv telegram-send.conf $HOME/.config/telegram-send.conf

############################################################################

############################## Setup Toolchains ############################

	inform 'Cloning toolchains'
	mkdir toolchains
	gut https://github.com/mvaisakh/gcc-arm -b gcc-master toolchains/gcc-arm
	gut https://gitlab.com/dakkshesh07/neutron-clang toolchains/clang

############################################################################

############################## Setup AnyKernel #############################

	inform 'Cloning AK3'
	gut https://github.com/Atom-X-Devs/AnyKernel3 -b main AnyKernel3

############################################################################

############################## Setup Kernel ################################

	inform 'Cloning Kernel'
	gut https://github.com/Atom-X-Devs/android_kernel_xiaomi_sm7325 -b kernel.lnx.5.4.r1-rel Kernel

############################################################################

############################ Setup Scripts #################################

	mv AtomX.sh Kernel/AtomX.sh
	cd Kernel
	bash AtomX.sh

############################################################################