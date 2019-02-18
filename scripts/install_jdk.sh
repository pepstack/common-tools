#!/bin/sh
#
# @file: install_jdk.sh
#   安装 java 环境
#
# 用法:
#   $ sudo ./install_jdk.sh --prefix=/usr/java --jdkpkg=../jdkpkgs/jdk-8u152-linux-x64.tar.gz
#
# @author: zhangliang@ztgame.com
#
# @create: 2018-05-22
#
# @update: 2018-05-23 10:38:01
#
#######################################################################
# will cause error on macosx
_file=$(readlink -f $0)

_cdir=$(dirname $_file)
_name=$(basename $_file)
_ver=0.0.1

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
#-----------------------------------------------------------------------
# FUNCTION: usage
# DESCRIPTION:  Display usage information.
#-----------------------------------------------------------------------
usage() {
    cat << EOT

Usage :  ${_name} --prefix=PATH --jdkpkg=TARBALL
  为 Linux 安装 java 环境.

Options:
  -h, --help                  显示帮助
  -V, --version               显示版本

  --prefix=PATH               指定安装的路径，例如：/usr/local/java
  --jdkpkg=TARBALL            指定安装的tar包，例如：jdk-8u152-linux-x64.tar.gz

返回值:
  0      成功
  非 0   失败

例子:
  $ sudo ${_name} --prefix=/usr/local/java --jdkpkg=./jdk-8u152-linux-x64.tar.gz

报告错误: 350137278@qq.com
EOT
}   # ----------  end of function usage  ----------

if [ $# -eq 0 ]; then usage; exit 1; fi

prefix="/usr/local/java"
jdkpkg="./jdk-8u152-linux-x64.tar.gz"

# parse options:
RET=`getopt -o Vh --long version,help,prefix:,jdkpkg:, \
    -n ' * ERROR' -- "$@"`

if [ $? != 0 ] ; then echoerror "$_name exited with doing nothing." >&2 ; exit 1 ; fi

# Note the quotes around $RET: they are essential!
eval set -- "$RET"

# set option values
while true; do
    case "$1" in
        -V | --version) echoinfo "$(basename $0) -- version: $_ver"; exit 1;;
        -h | --help ) usage; exit 1;;

        --prefix ) prefix="$2"; shift 2 ;;
        --jdkpkg ) jdkpkg="$2"; shift 2 ;;

        -- ) shift; break ;;
        * ) break ;;
    esac
done

# check user if root
uname=`id -un`
echoinfo "当前登录为：$uname"

# 路径是否存在
if [ ! -d "$prefix" ]; then
    echowarn "path not found. create: $prefix"
    mkdir -p "$prefix"
fi

abs_jdkpkg=$(real_path $(dirname $jdkpkg))'/'$(basename $jdkpkg)

# 文件是否存在
if [ ! -f "$abs_jdkpkg" ]; then
    echoerror "jdkpkg not found: $abs_jdkpkg"
    exit 1
fi


function alternatives_bin() {
    local binfile=$1
    local binname=$(basename $binfile)

    ln -sf "$binfile" "/etc/alternatives/$binname"
    ln -sf "/etc/alternatives/$binname" "/usr/bin/$binname"
    ln -sf "/etc/alternatives/$binname" "/bin/$binname"
}


function install_jdk() {
    local javadir=$1
    local pkgfile=$2
    local pkgname=$(basename $pkgfile)

    # 不要直接修改：/etc/profile
    # 增加一个配置文件：/etc/profile.d/jdkenv.sh
    local profile=/etc/profile.d/jdkenv.sh

    local priority=300

    echoinfo "正在安装 $pkgname 到目录：$javadir ..."

    local tmpdir=$(mktemp -d /tmp/jdk-untar.XXXXXX)

    echoinfo "解压到临时文件夹：$tmpdir"

    tar -zxf $pkgfile -C $tmpdir

    local jdkname=
    local jdkfile=

    local filelist=`ls $tmpdir`
    for filename in $filelist; do
        if [ -d $tmpdir"/"$filename ]; then
            jdkname=$filename
            jdkfile=$tmpdir"/"$jdkname
            break
        fi
    done

    if [ -z "$jdkfile" ]; then
        echoerror "jdk untar directory not found!"
        exit -1
    fi

    local javahome=$javadir"/"$jdkname
    echoinfo "JAVA_HOME="$javahome

    if [ -d $javahome ]; then
        echowarn "删除已安装的jdk：$javahome"
        rm -rf "$javahome"
    fi

    echoinfo "移动安装文件到目录：$javadir"
    mv $jdkfile $javadir

    echoinfo "删除临时目录：$tmpdir"
    rm -rf "$tmpdir"

    if [ ! -d $javahome ]; then
        echoerror "安装 java 失败. 未发现 JAVA_HOME：$javahome"
        exit -1
    fi

    echoinfo "安装成功。开始配置 java 环境：$profile"

    # 增加行
    echo "export JAVA_HOME=$javahome" > $profile
    echo "export JRE_HOME=\$JAVA_HOME/jre" >> $profile
    echo "export CLASSPATH=.:\$JAVA_HOME/lib:\$JAVA_HOME/lib/dt.jar:\$JAVA_HOME/lib/tools.jar:\$JRE_HOME/lib" >> $profile
    echo "export PATH=\$PATH:\$JAVA_HOME/bin:\$JAVA_HOME/jre/bin" >> $profile

    echoinfo "更新配置：$profile"
    source $profile

    # update-alternatives是dpkg的实用工具，用来维护系统命令的符号链接，以决定系统
    # 默认使用什么命令。最明显的场景，比如同时安装了OpenJDK和JDK，那么在命令行上
    # 使用java时就可以通过这个命令来进行切换。
    #
    # 设置当前使用的 java alternatives
    alternatives_bin "$javahome/bin/java"
    alternatives_bin "$javahome/bin/javac"
    alternatives_bin "$javahome/bin/jar"
    alternatives_bin "$javahome/bin/javadoc"
    alternatives_bin "$javahome/bin/javah"
    alternatives_bin "$javahome/bin/javap"
    alternatives_bin "$javahome/bin/jarsigner"

    local ret=`java -version`

    echo $ret
}

install_jdk "$prefix" "$abs_jdkpkg"

#TODO: 检查 java 环境是否正确

exit 0
