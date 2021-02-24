#!/bin/sh
#
# @file: mount_uuiddev.sh
#   !! 本文件必须以 UTF-8 witghout BOM 格式保存 !!
#   !! 此脚本会自动格式化设备，会造成设备数据丢失！慎用 !!
#
#  el6, el7
#
# @author: zhangliang
#
# @create: 2018-05-17
#
# @update: 2021-02-24 17:22:47
#
#######################################################################
# will cause error on macosx
_file=$(readlink -f $0)
_cdir=$(dirname $_file)
_name=$(basename $_file)
_ver=1.0

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
usage() {
    cat << EOT

    ${_name} --dev DISK --mnt PATH --mkfs TYPE

      挂载 Linux(el6,el7) 硬盘设备(xfs, ext4)脚本.

    Options:
      -h, --help           显示帮助
      -V, --version        显示版本

      --dev DISK           硬盘设备名称. 如: /dev/sdd. (可以通过命令: 'fdisk -l')
      --mnt PATH           挂载到的路径. 如: /mnt/disk001
      --mkfs TYPE          分区类型名称. 如: ext4, xfs
      --force              强制格式化.

    Examples:

      挂载硬盘 /dev/sde 到目录 /mnt/disk01 分区类型为 ext4

        $ sudo ./mount_uuiddev.sh --dev /dev/sde --mnt /mnt/disk01 --mkfs ext4


    报告错误: 350137278@qq.com
EOT
}   # ----------  end of function usage  ----------

if [ $# -eq 0 ]; then usage; exit 1; fi

# parse options:
RET=`getopt -o Vh --long version,help,force,dev:,mnt:,mkfs:, \
    -n ' * ERROR' -- "$@"`

# Note the quotes around $RET: they are essential!
eval set -- "$RET"

force="0"

while true; do
    case "$1" in
        -V | --version) echoinfo "$(basename $0) -- version: $_ver"; exit 1;;
        -h | --help ) usage; exit 1;;

        --force ) force="1"; shift 1 ;;

        --dev ) DEVDISK="$2"; shift 2 ;;
        --mnt ) MNTROOT="$2"; shift 2 ;;
        --mkfs ) MKFSTYPE="$2"; shift 2 ;;

        * ) break ;;
    esac
done

#######################################################################

if [ "$MKFSTYPE" != "xfs" -a "$MKFSTYPE" != "ext4" ]; then
    echoerror "无效的文件类型(必须是 xfs 或 ext4): ""$MKFSTYPE"
    exit -1
fi

MKFS="mkfs.$MKFSTYPE"

chk_root

if [ ! -f "/sbin/""$MKFS" ]; then
    echoerror "无效的分区类型: ""$MKFSTYPE"
    exit -1
fi


echoinfo "要挂载的磁盘设备: "$DEVDISK
echoinfo "挂载到的目标目录: "$MNTROOT
echoinfo "分区文件系统类型: "$MKFSTYPE

# sde, vdb
BLKNAME=$(basename $DEVDISK)

# 也可以通过命令获得: lsblk
BLKPATH=/sys/block/$BLKNAME

# 检查块设备是否存在

if [ ! -d "$BLKPATH" ]; then
    echoerror "指定的设备未发现: "$BLKPATH
    exit -1
fi

# 检查已经挂载的设备. 只有未挂载的设备才能挂载

mntstr="$DEVDISK on $MNTROOT type $MKFSTYPE"
echoinfo "检查是否已经挂载硬盘：""$mntstr"

foundres=$(findstrindex "$(mount -l)" "$mntstr")
if [ "$foundres" != "" ]; then
    echoerror "磁盘设备已经挂载: ""$mntstr"
    exit -1
fi

foundres=$(findstrindex "$(mount -l)" " $DEVDISK ")
if [ "$foundres" != "" ]; then
    echoerror "磁盘设备已经挂载: "$DEVDISK
    exit -1
fi

foundres=$(findstrindex "$(mount -l)" " $MNTROOT ")
if [ "$foundres" != "" ]; then
    echoerror "目录已经被挂载: "$MNTROOT
    exit -1
fi

# 提示用户确认?

read -p "挂载新硬盘: $DEVDISK 到目录: $MNTROOT, 确认(yes) 取消(n) ?"

if [ "$REPLY" != "yes" ]; then
    echowarn "用户取消了操作！"
    exit -1
fi


# 目录必须为空才可以挂载。如果目录不存在则创建

if [ ! -d $MNTROOT ]; then
    echowarn "目录不存在, 创建: $MNTROOT"
    mkdir -m 755 -p $MNTROOT
elif [ "`ls -A $MNTROOT`" != "" ]; then
    echoerror "挂载失败：目录不为空。"
    exit -1
fi


# 计算起始扇区的位置

optimal_io_size=$(cat $BLKPATH/queue/optimal_io_size)
alignment_offset=$(cat $BLKPATH/alignment_offset)
minimum_io_size=$(cat $BLKPATH/queue/minimum_io_size)
physical_block_size=$(cat $BLKPATH/queue/physical_block_size)

start_fan=2048

if [ "$optimal_io_size" != "0" ]; then
    start_fan=$[(optimal_io_size + alignment_offset) / 512]
fi
start_fan=$start_fan"s"

echoinfo "optimal_io_size: "$optimal_io_size
echoinfo "alignment_offset: "$alignment_offset

echoinfo "起始扇区位置："$start_fan


# 创建新分区表类型

ret=`parted -s $DEVDISK mklabel gpt`
if [ ! $ret ]; then
    echoinfo "创建新分区表类型: OK"
else
    echoerror "创建新分区错误：$ret"
    exit -1
fi


# 划分整个硬盘空间为主分区

ret=`parted -s $DEVDISK mkpart primary $start_fan 100%`
if [ ! $ret ]; then
    echoinfo "划分整个硬盘空间为主分区: OK"
else
    echoerror "划分硬盘主分区错误：$ret"
    exit -1
fi

# 格式化分区为 ext4
read -p "是(Yes)否(n)格式化分区 ($MKFS $DEVDISK) ? "

if [ "$REPLY" != "Yes" ]; then
    echowarn "警告：用户禁止了格式化分区操作！"
    exit 1
fi

echoinfo "开始格式化分区...""$MKFSTYPE"

if [ "$force" == "1" ]; then
    ret=`echo y | $MKFS -f $DEVDISK`
else
    ret=`echo y | $MKFS $DEVDISK`
fi

echo "$ret"

# TODO: 判断是否成功

echoinfo "格式化分区: OK"

if [ "$MKFSTYPE" == "xfs" ]; then
   echowarn "请使用 xfs_quota 命令手动设置磁盘配额!"
else
   echoinfo "设置保留分区百分比: 1%"
   ret=`tune2fs -m 1 $DEVDISK`
   echo "$ret"
   echoinfo "设置保留分区百分比(1%): OK"
fi


# 挂载硬盘设备到目录

ret=`mount -o noatime,nodiratime $DEVDISK $MNTROOT`
echo "$ret"

# 再次判断设备挂载是否成功
foundres=$(findstrindex "$(mount -l)" "$mntstr")
if [ "$foundres" == "" ]; then
    echoerror "磁盘设备没有挂载: ""$mntstr"
    exit -1
fi

echoinfo "挂载硬盘设备($DEVDISK)到目录($MNTROOT): 成功."

# 加入开机挂载系统命令中，在 /etc/fstab 中添加如下行：
#    UUID=1c4f27cc-293b-40c6-af79-77c1403c895c  /mnt/disk01  xfs  defaults,noatime,nodiratime  0  0

# 如果块设备已经存在, 不要格式化!
# /dev/sda: UUID="5147aced-c022-4b63-9d6d-1a0187683e9d" TYPE="xfs"

devstr=$(blkid_get_dev "$DEVDISK")
uuidstr=$(blkid_get_uuid "$DEVDISK")
typestr=$(blkid_get_uuid "$DEVDISK")


if [ "$devstr" == "" ]; then
    echoerror "没有找到块设备: ""DEVDISK"
    exit -1
fi

echowarn "如果开机自动挂载设备, 请将下行添加到文件: /etc/fstab"
echo "UUID=$uuidstr  $MNTROOT  $typestr  defaults,noatime,nodiratime  0  0"

exit 0
