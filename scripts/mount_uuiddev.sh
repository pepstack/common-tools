#!/bin/sh
#
# @file: mount_uuiddev.sh
#   !! 本文件必须以 UTF-8 witghout BOM 格式保存 !!
#   !! 此脚本会自动格式化设备，会造成设备数据丢失！慎用 !!
#
# 用法:
#   $ sudo ./mount_uuiddev.sh 设备 挂载目录 格式化分区
#
#   $ sudo ./mount_uuiddev.sh /dev/sde /data/data04 mkfs.ext4
#
# ./mount_uuiddev.sh /dev/sde /data/data01 mkfs.ext4
# ./mount_uuiddev.sh /dev/sdf /data/data02 mkfs.ext4
# ./mount_uuiddev.sh /dev/sdg /data/data03 mkfs.ext4
#
# @author: zhangliang@ztgame.com
#
# @create: 2018-05-17
#
# @update: 2018-05-22 17:22:47
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
#LANG=en_US.UTF-8;export LANG
LANG=zh_CN.UTF-8;export LANG

if [ $# != 3 ]; then
    echo "使用说明: $_name DEVDISK MNTROOT MKFS"
    echo "         DEVDISK  -  设备路径，例如：/dev/sdk"
    echo "         MNTROOT  -  挂载目录，例如：/data/data08"
    echo "         MKFS     -  格式化分区，例如：mkfs.ext4"
    exit 1;
fi

# 磁盘设备: /dev/sde, /dev/vdb

DEVDISK=$1

# sde, vdb
BLKNAME=$(basename $DEVDISK)

BLKPATH=/sys/block/$BLKNAME

# 挂载目录: /data/data01

MNTROOT=$2

# 格式化分区: mkfs.ext4

MKFS=$3


# 显示已经挂载的设备. 只有未挂载的设备才能挂载

ret=`mount -l`
echo $ret

mkfslen=${#MKFS}
mntstr="$DEVDISK on $MNTROOT type ${MKFS:5:$[mkfslen-5]} "
echo "查找挂载硬盘："$mntstr

dev_at=`substrindex "$ret" "$DEVDISK "`
mnt_at=`substrindex "$ret" "$MNTROOT "`

if [ $dev_at -ne -1 ]; then
    echo "设备已经挂载：$DEVDISK"
    exit -1
fi

if [ $mnt_at -ne -1 ]; then
    echo "目录已经被挂载：$MNTROOT"
    exit -1
fi


# 提示用户确认

read -p "挂载新硬盘: '$DEVDISK' 到目录: '$MNTROOT', 确认(yes) 取消(n) ?"

if [ "$REPLY" != "yes" ]; then
    echo "用户取消了操作！"
    exit -1
fi


# 目录必须为空才可以挂载。如果目录不存在则创建

if [ ! -d $MNTROOT ]; then
    echo "目录不存在, 创建: $MNTROOT"
    mkdir -m 755 -p $MNTROOT
elif [ "`ls -A $MNTROOT`" != "" ]; then
    echo "挂载失败：目录不为空。"
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

echo "optimal_io_size: "$optimal_io_size
echo "alignment_offset: "$alignment_offset

echo "起始扇区位置："$start_fan


# 创建新分区表类型

ret=`parted -s $DEVDISK mklabel gpt`
if [ ! $ret ]; then
    echo "创建新分区表类型: OK"
else
    echo "错误：$ret"
    exit -1
fi


# 划分整个硬盘空间为主分区

ret=`parted -s $DEVDISK mkpart primary $start_fan 100%`
if [ ! $ret ]; then
    echo "划分整个硬盘空间为主分区: OK"
else
    echo "错误：$ret"
    exit -1
fi

# 格式化分区为 ext4
read -p "是(Yes)否(n)格式化分区 ($MKFS $DEVDISK) ? "

if [ "$REPLY" != "Yes" ]; then
    echo "警告：用户禁止了格式化分区操作！"
    exit -1
fi

echo "开始格式化分区 ..."

ret=`echo y | $MKFS $DEVDISK`
echo "$ret"

#TODO: 判断是否成功

echo "格式化分区为 ext4: OK"


# 设置保留分区百分比: 1%

ret=`tune2fs -m 1 $DEVDISK`
echo "$ret"

#TODO: 判断是否成功

echo "设置保留分区百分比: OK"


# 挂载硬盘设备到目录

ret=`mount -o noatime $DEVDISK $MNTROOT`
echo "$ret"

# 判断设备挂载是否成功
ret=`mount -l`

# /dev/sde on /data/data01 type ext4
dev_mnt_at=`substrindex "$ret" "$mntstr"`
if [ $dev_mnt_at -eq -1 ]; then
    echo "挂载硬盘设备($DEVDISK)到目录($MNTROOT): 失败!"
    exit -1
fi

echo "挂载硬盘设备($DEVDISK)到目录($MNTROOT): 成功"

# 加入开机挂载系统命令中，在 /etc/fstab 中添加如下行：
#    UUID=1c4f27cc-293b-40c6-af79-77c1403c895c  /data/data09  ext4  defaults,noatime  0  0
#
devblkid=`blkid $DEVDISK`
echo "$devblkid"

uuid_start=`substrindex "$devblkid" "UUID="`
uuidstr=${devblkid:$[uuid_start+5]:38}
type_start=`substrindex "$devblkid" "TYPE="`
typestr=${devblkid:$[type_start+5]:-1}
devblkid_check="$DEVDISK: UUID=$uuidstr TYPE=$typestr"

ret=`substrindex "$devblkid" "$devblkid_check"`
if [ $ret -eq 0 ]; then
    uuidlen=${#uuidstr}
    typelen=${#typestr}

    uuidval=${uuidstr:1:$[uuidlen-2]}
    typeval=${typestr:1:$[typelen-2]}

    uuidlen=${#uuidval}

    if [ $uuidlen -eq 36 -a "$typeval" = "ext4" ]; then
        echo "UUID=$uuidval    $MNTROOT    $typeval    defaults,noatime    0  0" >> /etc/fstab
        echo "设备加入开机挂载系统命令中：OK"
    else
        echo "错误的块设备: $DEVDISK: UUID=$uuidstr TYPE=$typestr"
        echo "请手动添加块设备 ($DEVDISK) 到文件：/etc/fstab"
        exit -1
    fi
else
    echo "错误的块设备ID：$devblkid"
    exit -1
fi

exit 0
