#!/usr/bin/python
#-*- coding: UTF-8 -*-
#
# @file: xstp_capi_gen.py
#
#   生成 XSTP 协议的 C 接口的源代码
#   XSTP - eXtensible Secure Transfer Protocol
# @version:
# @create:
# @update: 2019-05-10
#
########################################################################
from __future__ import print_function
import os, sys, stat, signal, shutil, inspect, commands, time, datetime

import yaml, codecs

import optparse, ConfigParser

# http://docs.jinkan.org/docs/jinja2/
# http://docs.jinkan.org/docs/jinja2/templates.html
from jinja2 import Environment, PackageLoader, FileSystemLoader

########################################################################
# application specific
APPFILE = os.path.realpath(sys.argv[0])
APPHOME = os.path.dirname(APPFILE)
APPNAME,_ = os.path.splitext(os.path.basename(APPFILE))
APPVER = "1.0.0"
APPHELP = "generate XSTP C API source files"


########################################################################
# import your local modules
import utils.utility as util
import utils.evntlog as elog

########################################################################
Datatypes = {
    "j": ("sb2", 2, "kvpairs_add_16s", "int16_t"),
    "v": ("ub2", 2, "kvpairs_add_16u", "uint16_t"),
    "i": ("sb4", 4, "kvpairs_add_32s", "int32_t"),
    "u": ("ub4", 4, "kvpairs_add_32u", "uint32_t"),
    "I": ("sb8", 8, "kvpairs_add_64s", "int64_t"),
    "U": ("ub8", 8, "kvpairs_add_64u", "uint64_t"),
    "c": ("char", 1, "kvpairs_add_char", "char"),
    "b": ("ub1", 1, "kvpairs_add_byte", "unsigned char"),
    "s": ("char", 1, "kvpairs_add_str", "const char *"),
    "f": ("double", 8, "kvpairs_add_64f", "double"),
    "B": ("tpl_bin", 1, "kvpairs_add_bin", "void *"),
}


########################################################################
def render_memb(memb, membDict, protoCmd, protoAct):
    chType = membDict['Type']    
    (membtype, membsize, addfunc, valtype) = Datatypes[ chType ]
    memblens = str(membDict.get('Length', '0'))

    build = ""

    if memblens.isdigit():
        if chType == 's':
            membdesc = "%s  %s[%d]" % (membtype, memb, int(memblens) + 1)
            build = '%s(pairs, "%s", R->Content.%s.%s, strnlen(R->Content.%s.%s, %s));' % (addfunc, memb, protoCmd, memb, protoCmd, memb, memblens)
        else:
            membnum = int(memblens) / membsize
            if membnum > 1:
                # 类型数组
                membdesc = "%s  %s[%d]" % (membtype, memb, membnum)
                build = '%s(pairs, "%s", R->Content.%s.%s, %d);' % (addfunc, memb, protoCmd, memb, membnum)
            else:
                # 类型单个
                membdesc = "%s  %s" % (membtype, memb)
                build = '%s(pairs, "%s", &R->Content.%s.%s, 1);' % (addfunc, memb, protoCmd, memb)
        pass
    else:
        if chType == 's':
            membdesc = "%s  %s[%s + 1]" % (membtype, memb, memblens)
            build = '%s(pairs, "%s", R->Content.%s.%s, strnlen(R->Content.%s.%s, %s));' % (addfunc, memb, protoCmd, memb, protoCmd, memb, memblens)
        else:
            membnum = int(memblens) / membsize
            if membnum > 1:
                # 类型数组
                membdesc = "%s  %s[%d]" % (membtype, memb, membnum)
                build = '%s(pairs, "%s", R->Content.%s.%s, %d);' % (addfunc, memb, protoCmd, memb, membnum)
            else:
                # 类型单个
                membdesc = "%s  %s" % (membtype, memb)
                build = '%s(pairs, "%s", &R->Content.%s.%s, 1);' % (addfunc, memb, protoCmd, memb)
        pass

    membDict['render'] = {
        'membtype': membtype,
        'membsize': membsize,
        'membdesc': membdesc,
        protoAct: {
            "build": build
        }
    }


########################################################################
def output_file(fout, modcfg):
    unicode_output = modcfg['unicode_output']
    util.write_file_utf8(fout, unicode_output.encode('utf-8'))
    pass


def read_content(pathfile):
    content = ""
    fd = None
    try:
        fd = util.open_file(pathfile, mode='r+b', encoding='utf-8')
        for line in fd.readlines():
            content += line.encode('utf-8')
    finally:
        if fd:
            fd.close()
        pass
    return content

########################################################################
def render_members(dictcfg):
    protos, consts = (dictcfg['Protocols'], dictcfg['Constants'])

    for proto, protoCfg in protos.items():
        Request = protoCfg.get('Request', {})
        for memb, membDict in Request.items():
            render_memb(memb, membDict, protoCfg['Command'], "Request")

        Response = protoCfg.get('Response', {})
        for memb, membDict in Response.items():
            render_memb(memb, membDict, protoCfg['Command'], "Response")
    pass


def render_file(srcfile, dstfile, modcfg, verbose = True):
    (module, module_ver, dictcfg, j2env) = (modcfg['module'], modcfg['module_ver'], modcfg['dictcfg'], modcfg['j2env'])

    dstpath = os.path.dirname(dstfile)
    dstname = os.path.basename(dstfile).replace("%module%", module)
    outdstfile = os.path.join(dstpath, dstname)

    j2tmpl = j2env.get_template(os.path.basename(srcfile))

    render_members(dictcfg)

    # 模板渲染
    modcfg['unicode_output'] = j2tmpl.render(
        license_header = modcfg['license_header'],
        module     = module,
        dictcfg    = dictcfg,
    )

    util.create_output_file(outdstfile, output_file, modcfg, False)
    pass


########################################################################
def copy_module(srcfile, dstfile, modcfg, verbose):
    _, ext = os.path.splitext(os.path.basename(srcfile))

    if ext == ".template":
        # 需要模板处理
        dst, _ = os.path.splitext(dstfile)
        if verbose:
            util.info2("render file: %s -> %s" % (srcfile, dst))
        render_file(srcfile, dst, modcfg, verbose)
    else:
        # 不需要模板处理, 直接复制
        if verbose:
            util.info("copy file: %s -> %s" % (srcfile, dstfile))
        shutil.copyfile(srcfile, dstfile)
    pass

########################################################################
# 处理模板文件
def generate(parser, dictcfg, templateRoot, j2env, options):
    # 不可更改 !
    module = 'xstp'

    module_ver = "%s-%s" % (module, dictcfg['Version'])

    module_prefix = os.path.join(os.path.dirname(APPHOME), options.output, module_ver)

    util.info2("template root: %s" % templateRoot)
    util.info2("create module: %s" % module_prefix)

    if util.dir_exists(module_prefix):
        util.warn("module already exists: %s" % module_prefix)
        if not options.force:
            util.warn("using '--force' to ovewrite it");
            sys.exit(0)
        pass

    try:
        shutil.rmtree(module_prefix)
    except:
        pass

    license_header = read_content(os.path.join(APPHOME, dictcfg['License']))

    dictcfg['Update'] = util.nowtime()

    dictcfg['Datatypes'] = Datatypes

    modcfg = {
        'module': module,
        'module_ver': module_ver,
        'dictcfg': dictcfg,
        'license_header': license_header,
        'j2env': j2env
    }

    # 复制目录树, 同时处理模板文件
    util.copydirtree(templateRoot, module_prefix, None, True, copy_module, modcfg)
    pass


########################################################################
# 主函数仅仅处理日志和检查配置项
#
def main(parser, appConfig):
    import utils.logger as logger
    (options, args) = parser.parse_args(args=None, values=None)
    loggerConfig = {
        'logging_config': options.log_config,
        'file': APPNAME + '.log',
        'name': options.logger
    }
    logger_dictConfig = logger.set_logger(loggerConfig, options.log_path, options.log_level)

    # 设置模板环境
    tmplProjectDir = options.input

    templatesDir = os.path.join(tmplProjectDir, "templates")
    j2env = Environment(loader=FileSystemLoader(templatesDir))

    # 处理每个配置文件
    num = 0
    flist = os.listdir(tmplProjectDir)
    for name in flist:
        _, extname = os.path.splitext(name)
        if extname == ".yaml":
            configYaml = os.path.join(tmplProjectDir, name)

            if not os.path.isdir(configYaml):
                # 载入　yaml 配置文件
                fd = open(configYaml)
                dictcfg = yaml.load(fd.read())
                fd.close()
        
                num += 1
                util.info("[%d] processing config: %s" % (num, configYaml))
                generate(parser, dictcfg, templatesDir, j2env, options)

    util.info("success: total %d config file(s) processed." % num)    
    pass


########################################################################
# Usage:
#    $ %prog
#  or
#    $ %prog --force
#
if __name__ == "__main__":
    parser, group, optparse, profile = util.init_parser_group(
        apphome = APPHOME,
        appname = APPNAME,
        appver = APPVER,
        apphelp = APPHELP,
        usage = "%prog [Options]",
        group_options = os.path.join(APPHOME, "options/xstp_options.yaml")
    )

    print(profile)

    # 应用程序的本地缺省配置
    appConfig = {
        "project_rootdir": os.path.dirname(APPHOME)
    }

    # 主函数
    main(parser, appConfig)
    sys.exit(0)
