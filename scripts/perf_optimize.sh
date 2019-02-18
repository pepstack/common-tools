#!/bin/sh
#
# @file: perf_optimize.sh
#   !! 本文件必须以 UTF-8 witghout BOM 格式保存 !!
#   !! 此脚本会优化 hadoop 在 linux 系统上的性能！慎用 !!
#
# 用法（在需要的每个机器上执行）:
#   $ sudo ./perf_optimize.sh
#
# @author: zhangliang@ztgame.com
#
# @create: 2018-05-23
#
# @update: 2018-05-24 16:37:48
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

################### 时区 ###################
# 如果需要，请先更改 timezone, language

timezone=/usr/share/zoneinfo/Asia/Shanghai
language="zh_CN.UTF-8"

echoinfo "设置时区: $timezone"
rm -f /etc/localtime
ln -s $timezone /etc/localtime

echoinfo "设置语言: $language"
sed -i "/^export\s*LANG\s*=\s*/d" /etc/profile
echo "export LANG=$language" >> /etc/profile

source /etc/profile

unset timezone
unset language
################### 防火墙 ###################
echoinfo "关闭防火墙并设置开机不启动"
systemctl stop firewalld
systemctl mask firewalld


################### 内存 ###################
echoinfo "优化虚拟内存需求率"
echoinfo "检查虚拟内存需求率:"
sysctl vm.swappiness

echoinfo "降低虚拟内存需求率"
sysctl -w vm.swappiness=0

# 下面应该显示 0 才对
cat /proc/sys/vm/swappiness

echoinfo "永久降低虚拟内存需求率"
echo 'vm.swappiness=0' > /etc/sysctl.d/swappiness.conf

# 使生效
sysctl -p


#############################
mmap_cnt=65530
echoinfo "设置单进程可创建线程数: $mmap_cnt"
sysctl vm.max_map_count
sysctl -w vm.max_map_count=$mmap_cnt
cat /proc/sys/vm/max_map_count

echoinfo "永久设置 vm.max_map_count"
echo "vm.max_map_count="$mmap_cnt > /etc/sysctl.d/max_map_count.conf

# 使生效
sysctl -p

unset mmap_cnt


################### 大页面 ###################
echoinfo "解决透明大页面问题"
echoinfo "检查透明大页面问题"
cat /sys/kernel/mm/transparent_hugepage/defrag

# 应该显示为：
# [always] madvise never
#
# 相当于执行下面的命令：
# echo always > /sys/kernel/mm/transparent_hugepage/defrag
# cat /sys/kernel/mm/transparent_hugepage/defrag
# [always] madvise never

echoinfo "临时关闭透明大页面"
echo never > /sys/kernel/mm/transparent_hugepage/defrag
cat /sys/kernel/mm/transparent_hugepage/defrag

# 应该显示为：
# always madvise [never]

echo "配置开机自动生效"
# 获取匹配的行号 linenum
linenum=$(sed -n -e "/^echo never\s*>\s*\/sys\/kernel\/mm\/transparent_hugepage\/defrag\s*/=" /etc/rc.local)

if [ -z "$linenum" ]; then
    # 如果行号不存在，则添加
    echo 'echo never > /sys/kernel/mm/transparent_hugepage/defrag' >> /etc/rc.local
    chmod +x /etc/rc.d/rc.local
fi

# 打印匹配行
linestr=$(sed -n -e "/^echo never\s*>\s*\/sys\/kernel\/mm\/transparent_hugepage\/defrag\s*/p" /etc/rc.local)

# 打印匹配行号
linenum=$(sed -n -e "/^echo never\s*>\s*\/sys\/kernel\/mm\/transparent_hugepage\/defrag\s*/=" /etc/rc.local)

echoinfo "$linenum: $linestr"

unset linenum
unset linestr

################### 服务 ###################
echoinfo "关闭不需要的服务。如果仍然需要这些服务请手动开启"

service postfix stop
service cups stop
service nfslock stop
service rpcbind stop
service certmonger stop
service iptables stop

chkconfig postfix off
chkconfig cups off
chkconfig nfslock off
chkconfig rpcbind off
chkconfig certmonger off
chkconfig iptables off


################### CPU 和内存 ###################
# 总核数 = 物理CPU个数 X 每颗物理CPU的核数
# 总逻辑CPU数 = 物理CPU个数 X 每颗物理CPU的核数 X 超线程数

cpu_modle=`cat /proc/cpuinfo | grep name | cut -f2 -d: | uniq -c`
echoinfo "CPU型号信息: $cpu_modle"

cpu_num=`cat /proc/cpuinfo| grep "physical id"| sort| uniq| wc -l`
echoinfo "物理CPU个数: $cpu_num"

cores_per_cpu=`cat /proc/cpuinfo| grep "cpu cores"| uniq`
echoinfo "每个物理CPU中core的个数(即核数): $cores_per_cpu"

cpu_cores=`cat /proc/cpuinfo| grep "processor"| wc -l`
echoinfo "逻辑CPU的个数: $cpu_cores"

echoinfo "内存信息:"
cat /proc/meminfo

memMB=$(awk '($1 == "MemTotal:"){print $2/1024}' /proc/meminfo)
echoinfo "物理内存大小: $memMB MB"

unset cpu_modle
unset cpu_num
unset cores_per_cpu
unset cpu_cores


################### 进程和文件描述符 ###################
# 参考：
#   https://blog.csdn.net/oDaiLiDong/article/details/50561257
#
# 当日志出现以下情况中的一种时,需要考虑这个nproc：
#
#  1.  Cannot create GC thread. Out of system resources
#  2.  java.lang.OutOfMemoryError: unable to create new native thread
#
# 根据需要更改下面的值
# !! 以下值应该根据CPU核数 cpuCores 和物理内存大小 memMB 设置 !!
##########################################################

# 可打开的文件描述符的最大数(硬限制)
open_files_hard="$memMB"

# 可打开的文件描述符的最大数(软限制)
open_files_soft="$memMB"

# 单用户可用的最大进程数量(软限制)
user_proc_soft=514563

# 单个用户可用的最大进程数量(硬限制)
user_proc_hard=196608


echoinfo "hard nproc： 设置单个用户可用的最大进程数量(硬限制): $user_proc_hard"
# 196608
echoinfo "原有配置:"
cat /proc/sys/kernel/pid_max
echo "$user_proc_hard" > /proc/sys/kernel/pid_max
echoinfo "新的配置:"
cat /proc/sys/kernel/pid_max

# 如果存在则删除
sed -i "/^kernel.pid_max\s*=.*/d" /etc/sysctl.conf

# 增加配置项
echo "kernel.pid_max=$user_proc_hard" >> /etc/sysctl.conf

# 使配置生效
sysctl kernel.pid_max


# 永久更改
################### /etc/security/limits.conf
limitsfile=/etc/security/limits.conf
echoinfo "$limitsfile"

if [ -f "$limitsfile" ]; then
    echoinfo "更改配置文件: $limitsfile"

    \cp "$limitsfile" "$limitsfile".bak

    sed -i "/^\s*\*\s*hard\s*nofile\s*\d*/d" $limitsfile
    sed -i "/^\s*\*\s*soft\s*nofile\s*\d*/d" $limitsfile
    sed -i "/^\s*\*\s*hard\s*nproc\s*\d*/d" $limitsfile
    sed -i "/^\s*\*\s*soft\s*nproc\s*\d*/d" $limitsfile

    echo "*       hard    nofile    $open_files_hard" >> $limitsfile
    echo "*       soft    nofile    $open_files_soft" >> $limitsfile
    echo "*       hard    nproc     $user_proc_hard" >> $limitsfile
    echo "*       soft    nproc     $user_proc_soft" >> $limitsfile

    cat $limitsfile
else
    echoerror "文件未发现: $limitsfile"
fi

unset limitsfile


################### /etc/security/limits.d/20-nproc.conf
# 对于 linux 内核 > 2.6 (el7)

limitsnproc=/etc/security/limits.d/20-nproc.conf

if [ -f "$limitsnproc" ]; then
    echoinfo "更改配置文件: $limitsnproc"

    \cp "$limitsnproc" "$limitsnproc".bak

    # 首先删除
    sed -i "/^\s*\*\s*hard\s*nproc\s*\d*/d" $limitsnproc
    sed -i "/^\s*\*\s*soft\s*nproc\s*\d*/d" $limitsnproc
    sed -i "/^root\s*soft\s*nproc\s*unlimited/d" $limitsnproc

    # 然后添加
    echo "*       hard    nproc     $user_proc_hard" >> $limitsnproc
    echo "*       soft    nproc     $user_proc_soft" >> $limitsnproc
    echo "root    soft    nproc     unlimited" >> $limitsnproc

    cat $limitsnproc
else
    echowarn "文件未发现: $limitsnproc"
fi

unset limitsnproc


################### /etc/security/limits.d/90-nproc.conf
# 仅对于 linux 内核 2.6.x (el6)

limitsnproc=/etc/security/limits.d/90-nproc.conf

if [ -f "$limitsnproc" ]; then
    echoinfo "更改配置文件: $limitsnproc"

    \cp "$limitsnproc" "$limitsnproc".bak

    # 首先删除
    sed -i "/^\s*\*\s*hard\s*nproc\s*\d*/d" $limitsnproc
    sed -i "/^\s*\*\s*soft\s*nproc\s*\d*/d" $limitsnproc
    sed -i "/^root\s*soft\s*nproc\s*unlimited/d" $limitsnproc

    # 然后添加
    echo "*       hard    nproc     $user_proc_hard" >> $limitsnproc
    echo "*       soft    nproc     $user_proc_soft" >> $limitsnproc
    echo "root    soft    nproc     unlimited" >> $limitsnproc

    cat $limitsnproc
else
    echowarn "文件未发现: $limitsnproc"
fi

unset limitsnproc


echoinfo "hard nofile：设置可打开的文件描述符的最大数(硬限制): $open_files_hard"
ulimit -Hn "$open_files_hard"

echoinfo "soft nofile：设置可打开的文件描述符的最大数(软限制): $open_files_soft"
# ulimit -a| grep -i "open files"
ulimit -Sn "$open_files_soft"

echoinfo "soft nproc: 设置单个用户可用的最大进程数量(软限制): $user_proc_soft"
# ulimit -a | grep -i "max user processes"
# 514563
ulimit -u "$user_proc_soft"

echoinfo "查看进程和文件描述符限制，根据需要更改下面的值"
ulimit -a

unset memMB

unset open_files_hard
unset open_files_soft
unset user_proc_soft
unset user_proc_hard

################### 显示其他帮助 ###################

echoinfo "所有用户的进程数:                    # ps h -Led -o user | sort | uniq -c | sort -n"
echoinfo "用户(如：hdfs)的进程数:              # ps -o nlwp,pid,lwp,args -u hdfs | sort -n"
echoinfo "程序(程序名，如：java)的线程/进程数: # pstree -p `ps -e | grep java | awk '{print $1}'` | wc -l"
echoinfo "程序(进程号，如：3660)的线程/进程数: # pstree -p 3660 | wc -l"
echoinfo "整个系统已用的线程或进程数:          # pstree -p | wc -l"

exit 0
