#bin/#!/bin/bash

function spinner() {
    local info="$1"
    local pid=$!
    local delay=0.75
    local spinstr='|/-\'
    while kill -0 $pid 2> /dev/null; do
        local temp=${spinstr#?}
        printf " [%c]  $info" "$spinstr"
        local spinstr=$temp${spinstr%"$temp"}
        sleep $delay
        local reset="\b\b\b\b\b\b"
        for ((i=1; i<=$(echo $info | wc -c); i++)); do
            reset+="\b"
        done
        printf $reset
    done
    printf "    \b\b\b\b"
}

pacman -Syu --noconfirm --needed git bc inetutils zip libxml2 python3 \
                                 jre-openjdk jdk-openjdk flex bison libc++ python-pip

mv build.sh $HOME/build.sh
sed -i s/demo1/${BOT_API_KEY}/g telegram-send.conf
sed -i s/demo2/${CHAT_ID}/g telegram-send.conf
mv telegram-send.conf $HOME/telegram-send.conf
cd $HOME

(git clone -q --depth=1 https://github.com/mvaisakh/gcc-arm64 -b gcc-new gcc-arm64) &
spinner "Cloning Eva GCC [64]..."

(git clone -q --depth=1 https://github.com/mvaisakh/gcc-arm -b gcc-new gcc-arm32) &
spinner "Cloning Eva GCC [32]..."

(git clone -q --depth=1 https://github.com/Divyanshu-Modi/AnyKernel3 Repack) &
spinner "Cloning AnyKernel3..."

(git clone -q https://github.com/Divyanshu-Modi/Atom-X-Kernel -b main Kernel) &
spinner "Cloning Kernel Source..."

mv $HOME/build.sh $HOME/Kernel/build.sh
mkdir $HOME/.config
mv $HOME/telegram-send.conf $HOME/.config/telegram-send.conf
(pip3 -q install telegram-send) &
spinner "Installing telegram Api..."

echo building kernel
bash $HOME/Kernel/build.sh
