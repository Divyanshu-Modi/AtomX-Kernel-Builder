#bin/#!/bin/bash

  apt-get -y update \
  && apt-get -y upgrade \
  && apt-get -y install \
  git libxml2 python3-pip \
  default-jre

mv build.sh $HOME/build.sh
sed -i s/demo1/${BOT_API_KEY}/g telegram-send.conf
sed -i s/demo2/${CHAT_ID}/g telegram-send.conf
mv telegram-send.conf $HOME/telegram-send.conf
cd $HOME

echo Cloning Toolchain
git clone --depth=1 https://github.com/mvaisakh/gcc-arm64 gcc-arm64
git clone --depth=1 https://github.com/mvaisakh/gcc-arm gcc-arm32

echo Cloning AnyKernel3
git clone --depth=1 https://github.com/Divyanshu-Modi/AnyKernel3 Repack

echo Cloning Sources
git clone https://github.com/Divyanshu-Modi/Atom-X-Kernel -b main Kernel

mv $HOME/build.sh $HOME/Kernel/build.sh
echo Script Installed Successfully

echo Installing telegram Api
pip3 install telegram-send
mkdir $HOME/.config
mv $HOME/telegram-send.conf $HOME/.config/telegram-send.conf

echo building kernel GCC
bash $HOME/Kernel/build.sh
