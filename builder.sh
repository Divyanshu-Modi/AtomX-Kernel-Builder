#bin/#!/bin/bash

	dir_get() {
		git clone --depth=1 --progress -q $1 $2
	}

	dir_get https://gitlab.com/ElectroPerf/atom-x-clang $HOME/clang
	dir_get https://github.com/Divyanshu-Modi/AnyKernel3 $HOME/Repack
	dir_get https://github.com/Atom-X-Devs/android_kernel_xiaomi_sdm660 $HOME/Kernel
	pip3 -q install telegram-send

	mkdir $HOME/.config
	mv telegram-send.conf $HOME/.config/telegram-send.conf
	sed -i s/demo1/${BOT_API_KEY}/g $HOME/.config/telegram-send.conf
	sed -i s/demo2/${CHAT_ID}/g $HOME/.config/telegram-send.conf
	mv build.sh $HOME/Kernel/build.sh

	cd $HOME/Kernel && bash build.sh tulip

	exit
