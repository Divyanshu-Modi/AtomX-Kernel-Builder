#bin/#!/bin/bash

pacman -Syu --noconfirm --needed git bc inetutils zip libxml2 python3 \
                                 jre-openjdk jdk-openjdk flex bison libc++ python-pip

git clone --depth=1 https://github.com/mvaisakh/gcc-arm64 -b  gcc-new $HOME/gcc-arm64
git clone --depth=1 https://github.com/mvaisakh/gcc-arm -b gcc-new $HOME/gcc-arm32
git clone --depth=1 https://github.com/Divyanshu-Modi/AnyKernel3 $HOME/Repack
git clone --depth=1 https://github.com/Divyanshu-Modi/Atom-X-Kernel -b main $HOME/Kernel
pip3 install telegram-send

sed -i s/demo1/${BOT_API_KEY}/g telegram-send.conf
sed -i s/demo2/${CHAT_ID}/g telegram-send.conf
mkdir $HOME/.config
mv telegram-send.conf $HOME/.config/telegram-send.conf
mv build.sh $HOME/Kernel/build.sh
bash $HOME/Kernel/build.sh
