#### libxstp

noinst_HEADERS  =  xstpapi.h

lib_LTLIBRARIES  =  libxstp.la

libxstp_la_LDFLAGS = -version-info @kt_current@:@kt_revision@:@kt_age@ \
    -lz \
    -lrt \
    -lpthread

libxstp_la_SOURCES = \
    xstpapi.c \
    tplut.c \
    ./tpl/tpl.c

DEFS  += -D_GNU_SOURCE

AM_CPPFLAGS = -I.


#### test app
noinst_PROGRAMS = test

test_SOURCES = test.c

test_LDADD = \
    $(top_srcdir)/src/xstp/.libs/libxstp.a \
    -lm \
    -lrt \
    -ldl \
    -lpthread
