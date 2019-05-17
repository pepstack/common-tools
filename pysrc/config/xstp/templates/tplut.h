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
 * @file: tplut.h
 *    tpl protocol utility
 *
 * @author: master@pepstack.com
 *
 * @version: 1.0.0
 * @create: 2019-05-02
 * @update: 2019-05-03
 */
#ifndef TPLUT_H_INCLUDED
#define TPLUT_H_INCLUDED

#if defined(__cplusplus)
extern "C"
{
#endif

#include <stdio.h>
#include <stdlib.h>

#include "uthash/utarray.h"
#include "uthash/uthash.h"

/* http://troydhanson.github.io/tpl/userguide.html */
#include "tpl/tpl.h"

/**
 * Platform-Specific
 *   https://linux.die.net/man/3/htobe64
 */
#include <pthread.h>
#include <stdint.h>
#include <sys/time.h>

/**
 * 退出程序并写入日志: /var/log/messages
 */
#include "exitlog.h"


#if defined(__linux__)
#  include <endian.h>
#elif defined(__FreeBSD__) || defined(__NetBSD__)
#  include <sys/endian.h>
#elif defined(__OpenBSD__)
#  include <sys/types.h>
#  define be16toh(x) betoh16(x)
#  define be32toh(x) betoh32(x)
#  define be64toh(x) betoh64(x)
#endif


#ifdef __GNUC__
#  define GNUC_PACKED    __attribute__((packed))
#else
#  define GNUC_PACKED
#endif

#ifdef __arm
#  define ARM_PACKED    __packed
#else
#  define ARM_PACKED
#endif

#define TPLUT_SOK        0
#define TPLUT_SUCCESS    TPLUT_SOK
#define TPLUT_ERROR    (-1)

#define TPLUT_EKEY     (-2)
#define TPLUT_ETYPE    (-3)
#define TPLUT_ESIZE    (-4)


typedef struct kvpair_t * kvmap_t;


typedef struct ub16_digit_t
{
    union {
        unsigned char digit[16];
        struct {
            uint64_t digit_a;
            uint64_t digit_b;
        };        
    };
} ub16_digit_t;


/**
 * S(sc)B
 * 
 * A(S(sc)B)
 */
typedef struct kvpair_t
{
    /* we'll use this field as the key */
	char *key;

    char type;

	union {
		struct {
			void *val;
			uint32_t siz;
		};

		tpl_bin bval;
	};

    /* makes this structure hashable */
	UT_hash_handle hh;
} kvpair_t;


/**
 * help functions
 */
extern uint64_t htobef64 (double dvalue);

extern double bef64toh (uint64_t ulvalue);

extern uint64_t nowtime_msec (void);

extern void md5digit (const void *chunk, ssize_t size, uint32_t seed, ub16_digit_t *outout);

extern void tplbin_free (tpl_bin *B);


/**
 * kvpair_t and tpl api
 */

extern UT_array * kvpairs_new (int capacity);

extern void kvpairs_free (UT_array *pairs);

extern void kvpairs_add (UT_array *pairs, char *key, char type, void *value, uint32_t size);

extern void kvpairs_print (UT_array *pairs);

extern tpl_node * kvpairs_pack (UT_array *pairs);

extern uint32_t dump_bin (tpl_node *tn, tpl_bin *outbin);

extern tpl_node * load_bin (tpl_bin *inbin);

extern UT_array * kvpairs_unpack (tpl_bin *tbin, int capacity);

/**
 * for input pack
 */
extern void kvpairs_add_16s (UT_array *pairs, char *key, int16_t *val, uint32_t num);
extern void kvpairs_add_16u (UT_array *pairs, char *key, uint16_t *val, uint32_t num);
extern void kvpairs_add_32s (UT_array *pairs, char *key, int32_t *val, uint32_t num);
extern void kvpairs_add_32u (UT_array *pairs, char *key, uint32_t *val, uint32_t num);
extern void kvpairs_add_64s (UT_array *pairs, char *key, int64_t *val, uint32_t num);
extern void kvpairs_add_64u (UT_array *pairs, char *key, uint64_t *val, uint32_t num);
extern void kvpairs_add_64f (UT_array *pairs, char *key, double *val, uint32_t num);
extern void kvpairs_add_char (UT_array *pairs, char *key, char *val, uint32_t num);
extern void kvpairs_add_byte (UT_array *pairs, char *key, unsigned char *val, uint32_t num);
extern void kvpairs_add_str (UT_array *pairs, char *key, const char *str, uint32_t len);
extern void kvpairs_add_bin (UT_array *pairs, char *key, void *val, uint32_t size);

/**
 * for output unpack
 */
extern int kvmap_get_16s (kvmap_t *map, const char *key, int16_t *val);
extern int kvmap_get_16u (kvmap_t *map, const char *key, uint16_t *val);
extern int kvmap_get_32s (kvmap_t *map, const char *key, int32_t *val);
extern int kvmap_get_32u (kvmap_t *map, const char *key, uint32_t *val);
extern int kvmap_get_64s (kvmap_t *map, const char *key, int64_t *val);
extern int kvmap_get_64u (kvmap_t *map, const char *key, uint64_t *val);
extern int kvmap_get_64f (kvmap_t *map, const char *key, double *val);

extern int kvmap_get_str (kvmap_t *map, const char *key, char *iobuf, ssize_t *bufsz);

extern int kvmap_get_char (kvmap_t *map, const char *key, char *val);
extern int kvmap_get_byte (kvmap_t *map, const char *key, unsigned char *val);
extern int kvmap_get_bin_ref (kvmap_t *map, const char *key, tpl_bin *binref);
extern int kvmap_get_bin_cpy (kvmap_t *map, const char *key, void *addr, size_t size);

/**
 * kvmap_t api
 */
extern void kvmap_init (kvmap_t *map);

extern void kvmap_uninit (kvmap_t *map);

extern void kvpairs_to_map (UT_array *pairs, kvmap_t *map);

extern void kvmap_add (kvmap_t * map, kvpair_t * kv);

extern kvpair_t * kvmap_find (kvmap_t * map, const char * key);

extern void kvmap_delete (kvmap_t * map, kvpair_t *kv);

extern void kvmap_clear (kvmap_t * map);


#if defined(__cplusplus)
}
#endif

#endif /* TPLUT_H_INCLUDED */

