#!/bin/bash

# Set variable, setup packages and generate data
source ./setvars.sh
git clone https://github.com/SudarsunKannan/leveldb
./createdata.sh

# TO-DO: fork memtier_benchmark
# Download memtier_benchmark
git clone https://github.com/RedisLabs/memtier_benchmark.git


INSTALL_SYSTEM_LIBS(){
sudo apt-get install -y git
sudo apt-get install -y software-properties-common
sudo apt-get install -y python3-software-properties
sudo apt-get install -y python-software-properties
sudo apt-get install -y unzip
sudo apt-get install -y python-setuptools python-dev build-essential
sudo easy_install pip
sudo apt-get install -y numactl
sudo apt-get install -y libsqlite3-dev
sudo apt-get install -y libnuma-dev
sudo apt-get install -y cmake
sudo apt-get install -y build-essential
sudo apt-get install -y maven
sudo apt-get install -y fio
sudo apt-get install -y libbfio-dev
sudo apt-get install -y libboost-dev
sudo apt-get install -y libboost-thread-dev
sudo apt-get install -y libboost-system-dev
sudo apt-get install -y libboost-program-options-dev
sudo apt-get install -y libconfig-dev
sudo apt-get install -y uthash-dev
sudo apt-get install -y cscope
sudo apt-get install -y msr-tools
sudo apt-get install -y msrtool
sudo pip install psutil
#sudo pip install thrift_compiler
#INSTALL_JAVA
sudo apt-get -y install build-essential
sudo apt-get -y install libssl-dev
sudo apt-get -y install autoconf
sudo apt-get -y install automake
sudo apt-get -y install libevent-dev
sudo apt-get -y install pkg-config
sudo apt-get -y install zlib1g-dev
sudo apt-get -y install linux-tools-common linux-tools-generic linux-tools-$(uname -r)
}

DOWNLOAD_VTUNE(){
    wget https://apt.repos.intel.com/intel-gpg-keys/GPG-PUB-KEY-INTEL-SW-PRODUCTS.PUB
    sudo apt-key add GPG-PUB-KEY-INTEL-SW-PRODUCTS.PUB
    rm GPG-PUB-KEY-INTEL-SW-PRODUCTS.PUB
    echo "deb https://apt.repos.intel.com/oneapi all main" | sudo tee /etc/apt/sources.list.d/oneAPI.list
    sudo apt update
    sudo apt-get -y install intel-oneapi-vtune
}

INSTALL_SYSTEM_LIBS
DOWNLOAD_VTUNE

