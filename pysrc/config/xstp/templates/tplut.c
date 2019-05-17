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
 * @file: tplut.c
 *    tpl protocol utility
 *
 * @author: master@pepstack.com
 *
 * @version: 1.0.0
 * @create: 2019-05-02
 * @update: 2019-05-03
 */
#include "tplut.h"

#include "common/crc32.h"
#include "common/md5sum.h"
#include "common/rc4.h"


/**
 * http://troydhanson.github.io/tpl/userguide.html
 * 
 * Type 	Description 	             Required argument type
 * -----------------------------------------------------------------
 *  j     16-bit signed int           int16_t* or equivalent
 *  v     16-bit unsigned int         uint16_t* or equivalent
 *  i     32-bit signed int           int32_t* or equivalent
 *  u     32-bit unsigned int         uint32_t* or equivalent
 *  I     64-bit signed int           int64_t* or equivalent
 *  U     64-bit unsigned int         uint64_t* or equivalent
 *  c     character (signed char)     char*
 *  b     byte (unsigned char)        unsigned char*
 *  s     string                      char**
 *  f     64-bit double precision     double* (varies by platform)
 *  B     raw binary buffer (arbitrary-length)
 */


static void kvpair_copy(void *_dst, const void *_src)
{
	kvpair_t *dst = (kvpair_t *)_dst, *src = (kvpair_t *)_src;

	dst->key = (src->key ? strdup(src->key) : NULL);
	dst->type = src->type;

	if (src->val) {
		dst->val = malloc(src->siz);
		if (! dst->val) {
			exitlog_oom("tplut");
		}
		dst->siz = src->siz;
		memcpy(dst->val, src->val, src->siz);
	} else {
		dst->val = NULL;
		dst->siz = 0;
	}	
}


static void kvpair_dtor(void *_elt)
{
    kvpair_t *elt = (kvpair_t *)_elt;

    if (elt->key) {
		free(elt->key);
	}

    if (elt->val) {
		free(elt->val);
	}
}

static const UT_icd ut_kvpair_icd UTARRAY_UNUSED = { sizeof(kvpair_t), NULL, kvpair_copy, kvpair_dtor };


/**
 * kvpair_t and tpl api
 */

UT_array * kvpairs_new (int capacity)
{
	UT_array *pairs;

	utarray_new(pairs, &ut_kvpair_icd);
	utarray_reserve(pairs, capacity);

	return pairs;
}


void kvpairs_free (UT_array *pairs)
{
	utarray_free(pairs);
}


void kvpairs_add (UT_array *pairs, char *key, char type, void *value, uint32_t size)
{
	kvpair_t elt = { key, type, value, size };

	utarray_push_back(pairs, &elt);
}


void kvpairs_print (UT_array *pairs)
{
	kvpair_t *p = NULL;

	while ((p = (kvpair_t *) utarray_next(pairs, p))) {
		printf("%s = %.*s\n", p->key, (int) p->siz, (char *) p->val);
	}
}


void kvpairs_to_map (UT_array *pairs, kvmap_t *map)
{
	kvpair_t *p = NULL;

	while ((p = (kvpair_t *) utarray_next(pairs, p))) {
		kvmap_add(map, p);
	}
}


tpl_node * kvpairs_pack (UT_array *pairs)
{
	tpl_node *tn;
    
    kvpair_t kv, *p;

	tn = tpl_map("A(S(sc)B)", &kv, &kv.bval);
    if (! tn) {
        exitlog_oom("tplut");
    }

	p = NULL;
	while ((p = (kvpair_t *) utarray_next(pairs, p))) {
		kv = *p;

		if (tpl_pack(tn, 1) != 0) {
            exitlog_msg(-1, "tplut", "tpl_pack failed");
        }
	}

	return tn;
}


uint32_t dump_bin (tpl_node *tn, tpl_bin *tb)
{
    uint32_t sz = 0;

	if (tpl_dump(tn, TPL_GETSIZE, &sz) == 0) {
        if (tb->addr) {
            if (tb->sz < sz) {
                /* required size of buf */
                return sz;
            } else {
                if (tpl_dump(tn, TPL_MEM | TPL_PREALLOCD, tb->addr, sz) == 0) {
                    tb->sz = sz;

                    /* success */
                    return 0;
                }
            }
        } else {
            tb->addr = malloc(sz);
            if (! tb->addr) {
                exitlog_oom("tplut");
            }

            if (tpl_dump(tn, TPL_MEM | TPL_PREALLOCD, tb->addr, sz) == 0) {
                tb->sz = sz;

                /* success */
                return 0;
            }

            free(tb->addr);
            tb->addr = 0;
        }
    }

    /* tpl_dump error */
	return (-1);
}


tpl_node * load_bin (tpl_bin *tbin)
{
	tpl_node *tn;
    
    kvpair_t kv;

	tn = tpl_map("A(S(sc)B)", &kv, &kv.bval);
    if (! tn) {
        exitlog_oom("tplut");
    }

	if (tpl_load(tn, TPL_MEM /* | TPL_EXCESS_OK */, tbin->addr, tbin->sz) != 0) {
		tpl_free(tn);
		return NULL;
	}

	return tn;
}


UT_array * kvpairs_unpack (tpl_bin *tbin, int capacity)
{
	UT_array *pairs;

	tpl_node *tn;
    kvpair_t kv;

	pairs = kvpairs_new(capacity);

	tn = tpl_map("A(S(sc)B)", &kv, &kv.bval);
    if (! tn) {
		kvpairs_free(pairs);
        exitlog_oom("tplut");
        return NULL;
    }

	if (tpl_load(tn, TPL_MEM /* | TPL_EXCESS_OK */, tbin->addr, tbin->sz) != 0) {
		tpl_free(tn);
		kvpairs_free(pairs);
		return NULL;
	}
	
	while (tpl_unpack(tn, 1) > 0) {
		kvpairs_add(pairs, kv.key, kv.type, kv.val, kv.siz);
		kvpair_dtor((void*) &kv);
	}

	tpl_free(tn);

	return pairs;
}


uint64_t htobef64 (double dvalue)
{
    uint64_t val = 0UL;
    memcpy(&val, &dvalue, sizeof dvalue);
    return htobe64(val);
}


double bef64toh (uint64_t val)
{
    double dvalue = 0.0;
    uint64_t buf = be64toh(val);
    memcpy(&dvalue, &buf, sizeof dvalue);
    return dvalue;
}


uint64_t nowtime_msec (void)
{
    uint64_t ms = 0UL;

    struct timeval now;

    if (gettimeofday(&now, NULL) == 0) {
        ms = (now.tv_sec * 1000 + now.tv_usec / 1000);
    } else {
        perror("gettimeofday");
        exit(-1);
    }

    return ms;
}


/**
 * md5sum.h
 */
void md5digit (const void *source, ssize_t length, uint32_t seed, ub16_digit_t *outout)
{
    md5sum_t ctx;
    md5sum_init(&ctx, seed);
    md5sum_updt(&ctx, source, length);
    md5sum_done(&ctx, (uint8_t *) outout->digit);
}


void tplbin_free (tpl_bin *B)
{
    void * pv = B->addr;

    if (pv) {
        B->addr = 0;
        B->sz = 0;

        free(pv);
    }
}


/**
 * kvmap_t api
 */

void kvmap_init (kvmap_t * map)
{
	*map = NULL;
}


void kvmap_uninit (kvmap_t * map)
{
	HASH_CLEAR(hh, *map);
	*map = NULL;
}


void kvmap_add (kvmap_t * map, kvpair_t * kv)
{
    HASH_ADD_STR(*map, key, kv);
}


kvpair_t * kvmap_find (kvmap_t * map, const char * key)
{
    kvpair_t *kv = 0;

    HASH_FIND_STR(*map, key, kv);

    return kv;
}


void kvmap_delete (kvmap_t * map, kvpair_t *kv)
{
    HASH_DEL(*map, kv);
}


void kvmap_clear (kvmap_t * map)
{
    HASH_CLEAR(hh, *map);
}


void kvpairs_add_16s (UT_array *pairs, char *key, int16_t *val, uint32_t num)
{
    if (num == 1) {
        uint16_t buf = htobe16(*val);
        kvpairs_add(pairs, key, 'j', &buf, sizeof buf);
    } else {
        uint32_t i;
        uint16_t *pbuf = (uint16_t *) malloc(sizeof(*val) * num);
        exitlog_oom_check(pbuf, "tplut");

        for (i = 0; i < num; i++) {
            pbuf[i] = htobe16(val[i]);
        }

        kvpairs_add(pairs, key, 'j', pbuf, sizeof(pbuf[0]) * num);
    }
}


void kvpairs_add_16u (UT_array *pairs, char *key, uint16_t *val, uint32_t num)
{
    if (num == 1) {
        uint16_t buf = htobe16(*val);
        kvpairs_add(pairs, key, 'v', &buf, sizeof buf);
    } else {
        uint32_t i;
        uint16_t *pbuf = (uint16_t *) malloc(sizeof(*val) * num);
        exitlog_oom_check(pbuf, "tplut");

        for (i = 0; i < num; i++) {
            pbuf[i] = htobe16(val[i]);
        }

        kvpairs_add(pairs, key, 'v', pbuf, sizeof(pbuf[0]) * num);
    }
}


void kvpairs_add_32s (UT_array *pairs, char *key, int32_t *val, uint32_t num)
{
    if (num == 1) {
        uint32_t buf = htobe32(*val);
        kvpairs_add(pairs, key, 'i', &buf, sizeof buf);
    } else {
        uint32_t i;
        uint32_t *pbuf = (uint32_t *) malloc(sizeof(*val) * num);
        exitlog_oom_check(pbuf, "tplut");

        for (i = 0; i < num; i++) {
            pbuf[i] = htobe32(val[i]);
        }

        kvpairs_add(pairs, key, 'i', pbuf, sizeof(pbuf[0]) * num);
    }
}


void kvpairs_add_32u (UT_array *pairs, char *key, uint32_t *val, uint32_t num)
{
    if (num == 1) {
        uint32_t buf = htobe32(*val);
        kvpairs_add(pairs, key, 'u', &buf, sizeof buf);
    } else {
        uint32_t i;
        uint32_t *pbuf = (uint32_t *) malloc(sizeof(*val) * num);
        exitlog_oom_check(pbuf, "tplut");

        for (i = 0; i < num; i++) {
            pbuf[i] = htobe32(val[i]);
        }

        kvpairs_add(pairs, key, 'u', pbuf, sizeof(pbuf[0]) * num);
    }
}


void kvpairs_add_64s (UT_array *pairs, char *key, int64_t *val, uint32_t num)
{
    if (num == 1) {
        uint64_t buf = htobe64(*val);
        kvpairs_add(pairs, key, 'I', &buf, sizeof buf);
    } else {
        uint32_t i; 
        uint64_t *pbuf = (uint64_t *) malloc(sizeof(*val) * num);
        exitlog_oom_check(pbuf, "tplut");

        for (i = 0; i < num; i++) {
            pbuf[i] = htobe64(val[i]);
        }

        kvpairs_add(pairs, key, 'I', pbuf, sizeof(pbuf[0]) * num);
    }
}


void kvpairs_add_64u (UT_array *pairs, char *key, uint64_t *val, uint32_t num)
{
    if (num == 1) {
        uint64_t buf = htobe64(*val);
        kvpairs_add(pairs, key, 'U', &buf, sizeof buf);
    } else {
        uint32_t i; 
        uint64_t *pbuf = (uint64_t *) malloc(sizeof(*val) * num);
        exitlog_oom_check(pbuf, "tplut");

        for (i = 0; i < num; i++) {
            pbuf[i] = htobe64(val[i]);
        }

        kvpairs_add(pairs, key, 'U', pbuf, sizeof(pbuf[0]) * num);
    }
}


void kvpairs_add_64f (UT_array *pairs, char *key, double *val, uint32_t num)
{
    if (num == 1) {
        uint64_t buf = htobef64(*val);
        kvpairs_add(pairs, key, 'f', &buf, sizeof buf);
    } else {
        uint32_t i; 
        uint64_t *pbuf = (uint64_t *) malloc(sizeof(*val) * num);
        exitlog_oom_check(pbuf, "tplut");

        for (i = 0; i < num; i++) {
            pbuf[i] = htobef64(val[i]);
        }

        kvpairs_add(pairs, key, 'f', pbuf, sizeof(pbuf[0]) * num);
    }
}


void kvpairs_add_char (UT_array *pairs, char *key, char *val, uint32_t num)
{
    kvpairs_add(pairs, key, 'c', val, sizeof(*val) * num);
}


void kvpairs_add_byte (UT_array *pairs, char *key, unsigned char *val, uint32_t num)
{
    kvpairs_add(pairs, key, 'b', val, sizeof(*val) * num);
}


void kvpairs_add_str (UT_array *pairs, char *key, const char *str, uint32_t len)
{
    kvpairs_add(pairs, key, 's', (void *)str, len + 1);
}


void kvpairs_add_bin (UT_array *pairs, char *key, void *addr, uint32_t size)
{
    kvpairs_add(pairs, key, 'B', addr, size);
}


int kvmap_get_16s (kvmap_t *map, const char *key, int16_t *val)
{
    kvpair_t *kv = kvmap_find(map, key);
    if (! kv) {
        return TPLUT_EKEY;
    }
    if (kv->type != 'j') {
        return TPLUT_ETYPE;
    }
    if (kv->siz != sizeof(int16_t)) {
        return TPLUT_ESIZE;        
    }

    *val = (int16_t) be16toh(*((uint16_t *) kv->val));
    return TPLUT_SOK;
}


int kvmap_get_16u (kvmap_t *map, const char *key, uint16_t *val)
{
    kvpair_t *kv = kvmap_find(map, key);
    if (! kv) {
        return TPLUT_EKEY;
    }
    if (kv->type != 'v') {
        return TPLUT_ETYPE;
    }
    if (kv->siz != sizeof(uint16_t)) {
        return TPLUT_ESIZE;        
    }

    *val = be16toh(*((uint16_t *) kv->val));
    return TPLUT_SOK;
}


int kvmap_get_32s (kvmap_t *map, const char *key, int32_t *val)
{
    kvpair_t *kv = kvmap_find(map, key);
    if (! kv) {
        return TPLUT_EKEY;
    }
    if (kv->type != 'i') {
        return TPLUT_ETYPE;
    }
    if (kv->siz != sizeof(int32_t)) {
        return TPLUT_ESIZE;        
    }

    *val = (int32_t) be32toh(*((uint32_t *) kv->val));
    return TPLUT_SOK;
}


int kvmap_get_32u (kvmap_t *map, const char *key, uint32_t *val)
{
    kvpair_t *kv = kvmap_find(map, key);
    if (! kv) {
        return TPLUT_EKEY;
    }
    if (kv->type != 'u') {
        return TPLUT_ETYPE;
    }
    if (kv->siz != sizeof(uint32_t)) {
        return TPLUT_ESIZE;        
    }

    *val = be32toh(*((uint32_t *) kv->val));
    return TPLUT_SOK;
}


int kvmap_get_64s (kvmap_t *map, const char *key, int64_t *val)
{
    kvpair_t *kv = kvmap_find(map, key);
    if (! kv) {
        return TPLUT_EKEY;
    }
    if (kv->type != 'I') {
        return TPLUT_ETYPE;
    }
    if (kv->siz != sizeof(int64_t)) {
        return TPLUT_ESIZE;        
    }

    *val = (int64_t) be64toh(*((uint64_t *) kv->val));
    return TPLUT_SOK;
}


int kvmap_get_64u (kvmap_t *map, const char *key, uint64_t *val)
{
    kvpair_t *kv = kvmap_find(map, key);
    if (! kv) {
        return TPLUT_EKEY;
    }
    if (kv->type != 'U') {
        return TPLUT_ETYPE;
    }
    if (kv->siz != sizeof(uint64_t)) {
        return TPLUT_ESIZE;        
    }

    *val = be64toh(*((uint64_t *) kv->val));
    return TPLUT_SOK;
}


int kvmap_get_64f (kvmap_t *map, const char *key, double *val)
{
    kvpair_t *kv = kvmap_find(map, key);
    if (! kv) {
        return TPLUT_EKEY;
    }
    if (kv->type != 'f') {
        return TPLUT_ETYPE;
    }
    if (kv->siz != sizeof(double)) {
        return TPLUT_ESIZE;        
    }

    *val = bef64toh(*((uint64_t *) kv->val));
    return TPLUT_SOK;
}


int kvmap_get_str (kvmap_t *map, const char *key, char *iobuf, ssize_t *bufsz)
{
    kvpair_t *kv = kvmap_find(map, key);
    if (! kv) {
        return TPLUT_EKEY;
    }
    if (kv->type != 's') {
        return TPLUT_ETYPE;
    }
    if (kv->siz == 0 || kv->siz == -1) {
        return TPLUT_ESIZE;
    }
    if (kv->siz > *bufsz) {
        return TPLUT_ESIZE;
    }

    bcopy(kv->val, iobuf, kv->siz);
    *bufsz = (ssize_t) kv->siz;
    return TPLUT_SOK;
}


int kvmap_get_char (kvmap_t *map, const char *key, char *val)
{
    kvpair_t *kv = kvmap_find(map, key);
    if (! kv) {
        return TPLUT_EKEY;
    }
    if (kv->type != 'c') {
        return TPLUT_ETYPE;
    }
    if (kv->siz != sizeof(char)) {
        return TPLUT_ESIZE;
    }

    *val = *((char *) kv->val);
    return TPLUT_SOK;
}


int kvmap_get_byte (kvmap_t *map, const char *key, unsigned char *val)
{
    kvpair_t *kv = kvmap_find(map, key);
    if (! kv) {
        return TPLUT_EKEY;
    }
    if (kv->type != 'b') {
        return TPLUT_ETYPE;
    }
    if (kv->siz != sizeof(unsigned char)) {
        return TPLUT_ESIZE;
    }

    *val = *((unsigned char *) kv->val);
    return TPLUT_SOK;
}


int kvmap_get_bin (kvmap_t *map, const char *key, tpl_bin *binref)
{
    kvpair_t *kv = kvmap_find(map, key);
    if (! kv) {
        return TPLUT_EKEY;
    }
    if (kv->type != 'B') {
        return TPLUT_ETYPE;
    }
    if (kv->siz == -1) {
        return TPLUT_ESIZE;
    }

    *binref = kv->bval;
    return TPLUT_SOK;
}


int kvmap_get_bin_ref (kvmap_t *map, const char *key, tpl_bin *binref)
{
    kvpair_t *kv = kvmap_find(map, key);
    if (! kv) {
        return TPLUT_EKEY;
    }
    if (kv->type != 'B') {
        return TPLUT_ETYPE;
    }
    if (kv->siz == -1) {
        return TPLUT_ESIZE;
    }

    *binref = kv->bval;
    return TPLUT_SOK;
}


int kvmap_get_bin_cpy (kvmap_t *map, const char *key, void *addr, size_t size)
{
    kvpair_t *kv = kvmap_find(map, key);
    if (! kv) {
        return TPLUT_EKEY;
    }
    if (kv->type != 'B') {
        return TPLUT_ETYPE;
    }
    if ((size_t) kv->siz != size) {
        return TPLUT_ESIZE;
    }

    memcpy(addr, kv->bval.addr, size);
    return TPLUT_SOK;
}
