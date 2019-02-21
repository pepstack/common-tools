#!/usr/bin/python
#-*- coding: UTF-8 -*-
#######################################################################
import os, sys, time, fileinput, codecs, urllib, hashlib

#######################################################################
# application specific
APPFILE = os.path.realpath(sys.argv[0])
APPHOME = os.path.dirname(APPFILE)
APPNAME,_ = os.path.splitext(os.path.basename(APPFILE))
APPVER = "1.0.0"
APPHELP = "make index.html page"

#######################################################################
fix_namelen = 52

html_head = '''<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8">
  <title>Index of %s/</title>
  <style type="text/css">
    .row {
      width:100%%;
      clear:both;
    }

    .row ul {
      width: 100%%;
      min-width: 600px;
    }

    .row li {
      width: 20%%;
      float: left;
      display: block;
    }
  </style> 
</head>
<body bgcolor="white">
  <h3><font color="red">仅供内部学习使用。只允许在线阅读。严禁下载、复制、传播！</font></h3>
  <h2>Index of %s/</h2>
  <p>
    <a href="../">回到上级目录</a>
  </p>
  <!--${path_list}-->
  <div class="row">
    <pre>
'''

html_foot ='''
      <a href="#top">回到页面顶端</a>
    </pre>
  </div>
</body>
</html>
'''

div_anchor = '''      <div id="%s" style="height:0px"/>
'''

#######################################################################
def md5sum(pathfile):
    with open(pathfile, 'rb') as fh:
        m = hashlib.md5()
        while True:
            chunk = fh.read(8192)
            if not chunk:
                break
            m.update(chunk)
        return m.hexdigest()


def add_link_utf16(pf, fd, path, file):
    st = os.stat(pf)
    dt = time.strftime('%Y-%m-%d %H:%M:%S', time.localtime(st.st_mtime))
    infostr = "%d KB    %s" % (int(st.st_size /1024.0), dt)

    pathfile = os.path.join("./", path, file)

    name = file
    if len(file) > fix_namelen:
        name = file[:fix_namelen] + u"..."

    utf8path = path.encode('utf-8')
    utf8link = urllib.quote(pathfile.encode('utf-8'))
    utf8name = name.encode('utf-8')

    md5 = md5sum(pf)

    utf8fmt = '''      <a href="%s">[%s]</a>&nbsp;<a href="%s">%s</a>&nbsp;&nbsp;%s&nbsp;-&nbsp;{%s}\n'''

    for i in range(0, fix_namelen + 8 - len(utf8name)):
        infostr = "." + infostr

    utf8a = utf8fmt % (utf8path, utf8path, utf8link, utf8name, infostr, md5)

    fd.write(unicode(utf8a, 'utf-8'))
    pass


def add_path(path_list, root, path, child, fd, exts):
    files = os.listdir(child)
    files.sort(key=lambda x:x[0:20])

    utf8div = div_anchor % child

    fd.write(unicode(utf8div, 'utf-8'))

    path_list.append(child)

    for f in files:
        pf = os.path.join(path, child, f)

        if os.path.isdir(pf):
            make_index(root, pf, exts)
        else:
            title, ext = os.path.splitext(f)

            if ext.lower() in exts:
                add_link_utf16(pf.decode('utf-8'), fd, child.decode('utf-8'), f.decode('utf-8'))
                pass

    make_child_index(path_list, root, os.path.join(path, child), exts)
    pass


def add_child_link_utf16(pf, fd, file):
    st = os.stat(pf)
    dt = time.strftime('%Y-%m-%d %H:%M:%S', time.localtime(st.st_mtime))
    infostr = "%d KB    %s" % (int(st.st_size /1024.0), dt)

    pathfile = os.path.join("./", file)

    name = file
    if len(file) > fix_namelen:
        name = file[:fix_namelen] + u"..."

    utf8link = urllib.quote(pathfile.encode('utf-8'))
    utf8name = name.encode('utf-8')

    md5 = md5sum(pf)

    utf8fmt = '''      <a href="%s">%s</a>&nbsp;&nbsp;%s&nbsp;-&nbsp;{%s}\n'''

    for i in range(0, fix_namelen + 8 - len(utf8name)):
        infostr = "." + infostr

    utf8a = utf8fmt % (utf8link, utf8name, infostr, md5)

    fd.write(unicode(utf8a, 'utf-8'))
    pass


def make_child_index(path_list, root, path, exts):
    index_html = os.path.join(path, "index.html")

    print "make:", index_html

    homedir = path.replace(root, '')

    fd = codecs.open(index_html, 'w+b', 'utf-8')
    fd.write(unicode(html_head % (homedir, homedir), 'utf-8'))

    files = os.listdir(path)
    files.sort(key=lambda x:x[0:20])

    for f in files:
        pf = os.path.join(path, f)

        if os.path.isdir(pf):
            #add_path(path_list, root, path, f, fd)
            pass
        else:
            title, ext = os.path.splitext(f)
            if ext.lower() in exts:
                add_child_link_utf16(pf.decode('utf-8'), fd, f.decode('utf-8'))
                pass

    fd.write(unicode(html_foot, 'utf-8'))
    fd.close()
    pass


def make_index(root, path, exts):
    path_list = []

    index_html = os.path.join(path, "index.html")

    print "make:", index_html

    homedir = path.replace(root, '')

    fd = codecs.open(index_html, 'w+b', 'utf-8')
    fd.write(unicode(html_head % (homedir, homedir), 'utf-8'))

    files = os.listdir(path)
    files.sort(key=lambda x:x[0:20])

    for f in files:
        pf = os.path.join(path, f)

        if os.path.isdir(pf):
            add_path(path_list, root, path, f, fd, exts)
            pass

    fd.write(unicode(html_foot, 'utf-8'))
    fd.close()

    ul = '''  <div class="row">
    <ul>
'''

    for pn in path_list:
        li = '''      <li><a href="#%s">%s</a></li>
''' % (pn, pn)
        ul = ul + li

    ul = ul + '''    </ul>
  </div>'''
    
    for line in fileinput.input(index_html, inplace=True, mode='r', backup=None):
        ln = line.strip("\n")
        if ln.find("<!--${path_list}-->") != -1:
            print ul
        else:
            print ln

    pass


#######################################################################
if __name__ == "__main__":

    exts = ['.pdf', '.gz']

    for i in range(1, len(sys.argv)):
        extnames.append(sys.argv[i])

    print "create index.html for files:", exts

    make_index(os.path.dirname(APPHOME), APPHOME, exts)

    sys.exit(0)
