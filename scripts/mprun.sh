#!/bin/bash
# @file: mprun.sh
#   多进程并发执行的脚本
#
# @author:
#
########################################################################
_file=$(readlink -f $0)
_cdir=$(dirname $_file)
_name=$(basename $_file)
_ver="0.0.1"

. $_cdir/common.sh
. $_cdir/process.sh

# Treat unset variables as an error
set -o nounset

# Treat any error as exit
set -o errexit

# Set characters encodeing
#   LANG=en_US.UTF-8;export LANG
LANG=zh_CN.UTF-8;export LANG

#######################################################################
workers=10


#######################################################################
#----------------------------------------------------------------------
# FUNCTION: usage
# DESCRIPTION:  Display usage information.
#----------------------------------------------------------------------
usage() {
    cat << EOT

Usage :  ${_name} [Options]
  多进程并发执行的脚本.

Options:
  -h, --help                  显示帮助
  -V, --version               显示版本
  --workers=NUM               指定并发的工作者数目. ("$workers" 默认)

Examples:

    ${_name} --workers=3

EOT
}
# ----------  end of function usage  ----------

if [ $# -eq 0 ]; then usage; exit 1; fi

#######################################################################
# parse options:
RET=`getopt -o Vh --long version,help,workers:,\
    -n ' * ERROR' -- "$@"`

if [ $? != 0 ] ; then echoerror "$_name exited with doing nothing." >&2 ; exit 1 ; fi

# Note the quotes around $RET: they are essential!
eval set -- "$RET"

# set option values
while true; do
    case "$1" in
        -V | --version) echoinfo "$(basename $0) -- version: $_ver"; exit 1;;
        -h | --help ) usage; exit 1;;
        --workers ) workers="$2"; shift 2 ;;
        -- ) shift; break ;;
        * ) break ;;
    esac
done


#######################################################################
# 此处定义一个函数，作为一个子进程的具体执行过程
function run() {
    local pid="$1"

    local timeprefix=$(date +%Y-%m-%d_%H%M%S)

    # todo in childs
    echo "child $pid is running"
}


#######################################################################
process_run "$workers"

echowarn "${_name} stopped."
