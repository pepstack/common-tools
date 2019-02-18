#!/bin/sh
#
# @file: ntp_slave_config.sh
#
#   用于局域网内与服务器时间同步的从节点配置脚本。
#   此脚本只能在从节点上运行。如果在主节点上运行会导致错误！
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
#   $ sudo ./ntp_slave_config.sh master
#
# @author: zhangliang@ztgame.com
#
# @create: 2018-05-24
#
# @update: 2018-05-25 14:18:11
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
    echo "使用说明: $_name NTPMASTER"
    echo "        NTPMASTER  -  运行 ntpd 服务的主机名(不可以是 ip 地址)，如：ntpserver.yourdomain.com"
    exit 1;
fi


function ntpdate_check() {
    echoinfo "检查是否已经安装 ntpdate"
    local output=`rpm -qa ntpdate`

    if [ -z "$output" ]; then
        echoerror "ntpdate not installed"
        exit -1
    else
        # ntpdate-4.2.6p5-22.el7.centos.x86_64
        local ret=`substrindex "$output" "ntpdate-"`

        if [ $ret -eq 0 ]; then
            echoinfo "已经安装: $output"
        else
            echoerror "$output"
            exit -1
        fi
    fi
}



function ntp_slave_config() {
    local ntpmaster="$1"

    echoinfo "配置 ntpd 客户机指向服务器: $ntpmaster"

    # 注意：chrony和ntpd类似firewalld和iptables，不能共存，
    # 同时只能存在一个服务运行。故启用ntpd需要禁用chrony。
    echowarn "停止服务: chronyd"

    systemctl stop chronyd
    # systemctl disable chronyd
    systemctl mask chronyd

    # slave 要运行 ntpd 服务，并指向 master
    echowarn "停止服务: ntpd"
    systemctl stop ntpd

    # 删除原有指向，增加新指向 master
    sed -i '/^server /d' /etc/ntp.conf
    echo "server $ntpmaster prefer" >> /etc/ntp.conf

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
    echoinfo "增加系统任务（不需要重启 crontab 服务！）：/etc/cron.d/ntpdate-30min"
    local ntptmpfile=`mktemp /tmp/ntpdate-30min.XXXXXX`
    local credt=`now_datetime`
    echo "# file: ntpdate-30min" > $ntptmpfile
    echo "# create: $credt" >> $ntptmpfile
    echo "# *  *  *  *  * user-name  command to be executed" >> $ntptmpfile
    echo "*/30 * * * * root /usr/sbin/ntpdate ha01.ztgame.com && /usr/sbin/hwclock --systohc > /dev/null 2>&1" >> $ntptmpfile
    mv $ntptmpfile /etc/cron.d/ntpdate-30min
    chmod 644 /etc/cron.d/ntpdate-30min

    cat /etc/cron.d/ntpdate-30min

    echoinfo "初始化与服务器同步时间 ..."
    ntpdate "$ntpmaster" && hwclock -w

    echowarn "启用服务: ntpd"
    systemctl enable ntpd
    systemctl start ntpd
    systemctl status ntpd

    date
}


###########################################################
ntpdate_check

ntp_slave_config "$1"

echoinfo "客户机设置成功"

curdt=`now_datetime`

echo -e "请使用命令初始化时间:\n    $ sudo date -s \""$curdt"\" && hwclock -w"

unset curdt

exit 0
