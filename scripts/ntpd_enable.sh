#!/bin/sh
#
# @file: ntpd_enable.sh
#   用于局域网内服务器的时间同步
#
#  [0.cn.pool.ntp.org, 0.asia.pool.ntp.org, 2.asia.pool.ntp.org]
#    其中 0.cn 是中国服务器池，后面两个是亚洲的服务器池。 最新列表见：
#        http://www.pool.ntp.org/zone/cn
#
#
#          master ----(/etc/ntp.cnf)---->  0.cn.pool.ntp.org
#           /|\                            0.asia.pool.ntp.org
#          / | \                           2.asia.pool.ntp.org
#         /  |  \
#        /   |   \
#   slave1   |  slaveN...
#            |
#          slave2
#
#
# 用法:
#   $ sudo ./ntpd_enable.sh SERVER
#
# @author: zhangliang@ztgame.com
#
# @create: 2018-05-24
#
# @update: 2018-05-25 11:15:53
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
# 参考:
#     http://www.cnblogs.com/greenerycn/archive/2011/03/13/linux_ntp_server.html
#   * http://www.cnblogs.com/kerrycode/archive/2015/08/20/4744804.html
#     https://blog.csdn.net/xiaolongwang2010/article/details/8772855
#   * http://www.blogjava.net/spray/archive/2008/07/10/213964.html
#
# 配置文件说明: /etc/ntp.conf
#
#    # 设置此服务器同上层服务器做时间同步的IP地址, prefer 意味着首选IP地址
#    server    0.cn.pool.ntp.org        prefer
#    server    0.asia.pool.ntp.org
#    server    2.asia.pool.ntp.org
#
#    # 记录上次的NTP server与上层NTP server联接所花费的时间
#    driftfile  /var/lib/ntp/drift
#    broadcastdelay  0.008
#
#    # 指定阶层编号为10，降低其优先度。让NTP Server和其自身保持同步，
#    #   如果在 ntp.conf 中定义的 server 都不可用时，将使用 local 时间作为
#    #   ntp 服务提供给ntp客户端。
#    server 127.127.1.0
#    fudge 127.127.1.1 stratum 10
#
#    # 设置 ntp 日志的 path
#    statsdir /var/log/ntp/
#
#    # 设置ntp日志文件
#    logfile /var/log/ntp/ntp.log
#
# 查看本机和上层服务器的时间同步结果
# # watch ntpq -p
#######################################################################

if [ $# != 1 ]; then
    echo "使用说明: $_name NTPD_SERVER"
    echo "         NTPD_SERVER  -  ntpd 主机名(不可以是 ip 地址)，如：ha01.yourdomain.com"
    exit 1;
fi

NTPD_SERVER="$1"
THIS_HOST=`hostname`

# TODO: 需要检查是否已经安装 ntpdate
# rpm -qa|grep ntpdate
# 显示这个说明已经安装 ntpdate-4.2.6p5-22.el7.centos.x86_64
# 目前默认已经安装

# 这是中国国家授时中心的IP
# server 210.72.145.44

function ntp_master_config() {
    echoinfo "配置 ntpd 服务器: $1"

    # 注意：chrony和ntpd类似firewalld和iptables，不能共存，
    # 同时只能存在一个服务运行。故启用ntpd需要禁用chrony。systemctl disable|mask chronyd
    echowarn "停止服务: chronyd"

    systemctl stop chronyd
    systemctl mask chronyd

    systemctl enable ntpd
    systemctl start ntpd

    # 设置时间
    # date -s "2018-05-24 18:29:30"
    # clock -w

    echo "success"
}


function ntp_slave_config() {
    ntpmaster="$1"

    echoinfo "配置 ntpd 客户机指向服务器: $ntpmaster"

    # 注意：chrony和ntpd类似firewalld和iptables，不能共存，
    # 同时只能存在一个服务运行。故启用ntpd需要禁用chrony。
    echowarn "停止服务: chronyd"

    systemctl stop chronyd
    # systemctl disable chronyd
    systemctl mask chronyd

    # 对于 slave 而言，不需要启动 ntpd 服务。但是需要启用定时任务与服务器同步时间
    echoinfo "启用服务: ntpd"
    systemctl enable ntpd
    systemctl start ntpd

    # 当我们要增加全局性的计划任务时，一种方式是直接修改/etc/crontab。
    # 但是，一般不建议这样做，/etc/cron.d目录就是为了解决这种问题而创建的。
    # 例如，增加一项定时的备份任务，我们可以这样处理：在/etc/cron.d目录下
    # 新建文件 python-backup，内容如下：
    #     # m h dom mon dow user command
    #     26 16 * * * root tar zcvf /var/backups/home.tar.gz /home/amonest/python
    #
    # cron 进程执行时，就会自动扫描该目录下的所有文件，按照文件中的时间设定执行后面的命令。
    # cron 执行时，要依次读取3个地方的配置文件：
    #    1) /etc/crontab
    #    2) /etc/cron.d
    #    3) 每个用户的配置文件: 通过 crontab -e 添加
    #
    # 下面每 30 分钟同步一次时间的脚本(文件名必须是字母数字下划线减号):
    # /etc/cron.d/ntpdate-update
    #
    # # *  *  *  *  * user-name  command to be executed
    # */30 * * * * root /usr/sbin/ntpdate ha01.ztgame.com && /usr/sbin/hwclock --systohc > /dev/null 2>&1
    #
    # 增加新的任务文件不需要重启 crontab 服务！
    ntptmpfile=`mktemp /tmp/ntpdate-30min.XXXXXX`
    echo "# *  *  *  *  * user-name  command to be executed" > $ntptmpfile
    echo "*/30 * * * * root /usr/sbin/ntpdate ha01.ztgame.com && /usr/sbin/hwclock --systohc > /dev/null 2>&1" >> $ntptmpfile
    mv $ntptmpfile /etc/cron.d/ntpdate-30min
    chmod 644 /etc/cron.d/ntpdate-30min

    # 初始化与服务器同步时间
    ntpdate "$ntpmaster" && hwclock -w

    echo "success"
}


###########################################################
# 根据主机名判断是否是 ntp server

if [ "$THIS_HOST" = "$NTPD_SERVER" ]; then
    ntp_master_config "$NTPD_SERVER"
else
    ntp_slave_config "$NTPD_SERVER"
fi

exit 0
