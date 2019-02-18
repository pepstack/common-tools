#!/bin/sh
#
# @file: set_hostname.sh
#   !! 本文件必须以 UTF-8 witghout BOM 格式保存 !!
#   !! 此脚本会更改 linux 系统的主机名！慎用 !!
#
# 用法:
#   $ sudo ./set_hostname.sh  HOSTNAME
#
#   $ sudo ./set_hostname.sh  ha01.ztgame.com
#
# @author: zhangliang@ztgame.com
#
# @create: 2018-05-21
#
# @update: 2018-05-21 18:08:52
#
#######################################################################
# will cause error on macosx
_file=$(readlink -f $0)

_cdir=$(dirname $_file)

_name=$(basename $_file)


. $_cdir/common.sh

# Set characters encodeing
#   LANG=en_US.UTF-8;export LANG
LANG=zh_CN.UTF-8;export LANG

# https://blog.csdn.net/drbinzhao/article/details/8281645
# Treat unset variables as an error
set -o nounset

# Treat any error as exit
set -o errexit

#######################################################################
LANG=zh_CN.UTF-8;export LANG

if [ $# != 1 ]; then
    echo "使用说明: $_name HOSTNAME"
    echo "         HOSTNAME  -  主机名，如：ha01.yourdomain.com"
    exit 1;
fi

HOSTNAME=$1

echo $HOSTNAME > /etc/hostname

hostname $HOSTNAME

# 删除行
sed -i '/^HOSTNAME=.*/d' /etc/sysconfig/network

# 增加行
echo "HOSTNAME=$HOSTNAME" >> /etc/sysconfig/network

# TODO: 检查
hostname
cat /etc/hostname
cat /etc/sysconfig/network | grep -i "HOSTNAME=$HOSTNAME"

exit 0
