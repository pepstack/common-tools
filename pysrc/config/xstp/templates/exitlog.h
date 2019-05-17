/***********************************************************************
* Copyright (c) 2008-2080 syna-tech.com, pepstack.com, 350137278@qq.com
*
* ALL RIGHTS RESERVED.
* 
* Redistribution and use in source and binary forms, with or without
* modification, are permitted provided that the following conditions
* are met:
* 
*   Redistributions of source code must retain the above copyright
*    notice, this list of conditions and the following disclaimer.
* 
* THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
* "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
* LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
* A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
* OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
* SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
* LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
* DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
* THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
* (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
* OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
***********************************************************************/
/**
 * @file: exitlog.h
 *    exit after log marcos
 *
 * @author: master@pepstack.com
 *
 * @version: 1.0.0
 * @create: 2019-05-02
 * @update: 2019-05-03
 */
#ifndef EXITLOG_H_INCLUDED
#define EXITLOG_H_INCLUDED

#if defined(__cplusplus)
extern "C"
{
#endif

#include <stdio.h>
#include <stdlib.h>

/**
 * Platform-Specific
 *   https://linux.die.net/man/3/htobe64
 */
#include <sys/time.h>
#include <syslog.h>


/* output to file: /var/log/messages */
#define exitlog_msg(errcode, ident, message, args...) do {\
    char __messagebuf[256]; \
    snprintf(__messagebuf, sizeof(__messagebuf), message, ##args); \
    openlog(ident, LOG_PID | LOG_NDELAY | LOG_NOWAIT | LOG_PERROR, 0); \
    syslog(LOG_USER | LOG_CRIT, "%s %s (%s:%d) FATAL <%s> %s.\n", \
        __DATE__, __TIME__, __FILE__, __LINE__, __FUNCTION__, __messagebuf); \
    closelog(); \
    exit(errcode); \
} while(0)


#define exitlog_oom(ident)  exitlog_msg(-1, ident, "out of memory")

#define exitlog_oom_check(p, ident)  if (!p) exitlog_msg(-1, ident, "out of memory")


#if defined(__cplusplus)
}
#endif

#endif /* EXITLOG_H_INCLUDED */

