#!/bin/bash
# @file: process.sh
#   a shell framework for multi processes.
#
# @refer:
#   http://lawrence-zxc.github.io/2012/06/16/shell-thread
#
# @author:
#
# @create: 2018-12-19
#
# @update: 2018-12-19
#
########################################################################
_file=$(readlink -f $0)
_cdir=$(dirname $_file)
_name=$(basename $_file)

. $_cdir/common.sh

# Treat unset variables as an error
set -o nounset

# Treat any error as exit
set -o errexit

# Set characters encodeing
#   LANG=en_US.UTF-8;export LANG
LANG=zh_CN.UTF-8;export LANG

########################################################################
# 此处定义一个函数，作为一个线程(子进程)
# 实际要由调用者实现此函数 !!
function run() {
    local pid="$1"

    # 定义子进程的具体操作
    echowarn "[process:$pid] should never run to this! not implemented."
}


function process_run() {
    # 定义用于并发的进程数量,即此处定义线程数
    local SUB_PROCESS_NUM="$1"

    # 创建一个命名管道fifo
    tmpfile="/tmp/$$.fifo"
    mkfifo $tmpfile

    # 将fd6指向fifo类型
    exec 6<>$tmpfile
    rm -f $tmpfile

    # 事实上就是在fd6中放置了$SUB_PROCESS_NUM个回车符
    for((i=1;i<=$SUB_PROCESS_NUM;i++));
    do 
        echoinfo "[$i] process start...";
    done >&6

    # 3次循环，可以理解为 30 个主机，或其他
    for ((i=1; i<=$SUB_PROCESS_NUM; i++));
    do
        # 一个read -u6命令执行一次，就从fd6中减去一个回车符，然后向下执行，
        # fd6中没有回车符的时候，就停在这了，从而实现了线程数量控制
        # 此处 read line 与 read -u6 命令一样
        read line

        echo "$line"

        # (run; echo "sub job $i finished.") >&6 &
        {   # 此处子进程开始执行，被放到后台
            run $i && { # 此处可以用来判断子进程的逻辑
                echoinfo "[$i] process finished!"
            } || {
                echoerror "[$i] process failed!!"
            }

            # 当进程结束以后，再向fd6中加上一个回车符，即补上了read -u6减去的那个
            echo >&6
        } &
    done <&6

    # 等待所有的后台子进程结束
    wait

    # 关闭 fd6
    exec 6>&-
}
