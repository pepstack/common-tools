#!/bin/sh
#
# @file: close_firewall.sh
#   !! 本文件必须以 UTF-8 witghout BOM 格式保存 !!
#   !! 此脚本会关闭 linux 系统的所有防火墙，会造成系统安全漏洞！慎用 !!
#
# 用法:
#   $ sudo ./close_firewall.sh
#
# @author: zhangliang@ztgame.com
#
# @create: 2018-05-21
#
# @update: 2018-05-24 16:37:38
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

echoinfo "关闭 iptables 防火墙"
service iptables stop
chkconfig iptables off

echoinfo "关闭 firewalld.service"
systemctl stop firewalld.service
systemctl mask firewalld.service
systemctl status firewalld.service

echoinfo "关闭selinux"
setenforce 0

sed -i 's/^SELINUX=.*/SELINUX=disabled/' /etc/selinux/config

getenforce
cat /etc/selinux/config | grep -i "SELINUX=disabled"

exit 0
