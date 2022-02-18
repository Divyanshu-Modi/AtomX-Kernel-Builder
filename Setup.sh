#bin/#!/bin/bash

############################## Setup Toolchains ############################

	mkdir toolchains
	git clone -q --depth=1 https://github.com/mvaisakh/gcc-arm -b gcc-master toolchains/gcc-arm32
	git clone -q --depth=1 https://gitlab.com/ElectroPerf/atom-x-clang toolchains/clang

############################################################################

############################## Setup AnyKernel #############################

	git clone -q --depth=1 https://github.com/Atom-X-Devs/AnyKernel3 -b lisa AnyKernel3

############################################################################

############################## Setup Kernel ################################

	git clone -q --depth=1 https://github.com/Atom-X-Devs/android_kernel_xiaomi_sm7325 Kernel

############################################################################

######################## Setup Telegram API ################################

	pip3 -q install telegram-send
	sed -i s/demo1/${BOT_API_KEY}/g telegram-send.conf
	sed -i s/demo2/${CHAT_ID}/g telegram-send.conf
	mkdir $HOME/.config
	mv telegram-send.conf $HOME/.config/telegram-send.conf

############################################################################

############################ Setup Scripts #################################

	mv AtomX.sh Kernel/AtomX.sh
	cd Kernel
	bash AtomX.sh

############################################################################