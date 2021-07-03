#bin/#!/bin/bash

apt-get -y update && apt-get -y upgrade && apt-get -y install \
git libxml2 python3-pip default-jre flex bison

mv build.sh $HOME/build.sh
sed -i s/demo1/${BOT_API_KEY}/g telegram-send.conf
sed -i s/demo2/${CHAT_ID}/g telegram-send.conf
mv telegram-send.conf $HOME/telegram-send.conf
cd $HOME

git clone -q --depth=1 https://github.com/mvaisakh/gcc-arm64 gcc-arm64
git clone -q --depth=1 https://github.com/mvaisakh/gcc-arm gcc-arm32
echo Successfully Cloned Toolchain

git clone -q --depth=1 https://github.com/Divyanshu-Modi/AnyKernel3 Repack
echo Successfully Cloned AnyKernel3

git clone -q https://github.com/Divyanshu-Modi/Atom-X-Kernel -b main Kernel
echo Successfully Cloned Kernel Source

mv $HOME/build.sh $HOME/Kernel/build.sh
pip3 -q install telegram-send
echo Successfully Installed telegram Api
mkdir $HOME/.config
mv $HOME/telegram-send.conf $HOME/.config/telegram-send.conf

echo building kernel
bash $HOME/Kernel/build.sh
