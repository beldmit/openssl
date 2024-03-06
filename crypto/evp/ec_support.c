/*
 * Copyright 2020-2022 The OpenSSL Project Authors. All Rights Reserved.
 *
 * Licensed under the Apache License 2.0 (the "License").  You may not use
 * this file except in compliance with the License.  You can obtain a copy
 * in the file LICENSE in the source distribution or at
 * https://www.openssl.org/source/license.html
 */

#include <string.h>
#include <openssl/ec.h>
#include "crypto/ec.h"
#include "internal/nelem.h"

typedef struct ec_name2nid_st {
    const char *name;
    int nid;
} EC_NAME2NID;

static const EC_NAME2NID curve_list[] = {
    /* prime field curves */
    /* secg curves */
    {"secp224r1", NID_secp224r1 },
    {"secp256k1", NID_secp256k1 },
    {"secp384r1", NID_secp384r1 },
    {"secp521r1", NID_secp521r1 },
    /* X9.62 curves */
    {"prime256v1", NID_X9_62_prime256v1 },
    /* characteristic two field curves */
    /* NIST/SECG curves */
    /* brainpool curves */
    {"brainpoolP256r1", NID_brainpoolP256r1 },
    {"brainpoolP256t1", NID_brainpoolP256t1 },
    {"brainpoolP320r1", NID_brainpoolP320r1 },
    {"brainpoolP320t1", NID_brainpoolP320t1 },
    {"brainpoolP384r1", NID_brainpoolP384r1 },
    {"brainpoolP384t1", NID_brainpoolP384t1 },
    {"brainpoolP512r1", NID_brainpoolP512r1 },
    {"brainpoolP512t1", NID_brainpoolP512t1 },
};

const char *OSSL_EC_curve_nid2name(int nid)
{
    size_t i;

    if (nid <= 0)
        return NULL;

    for (i = 0; i < OSSL_NELEM(curve_list); i++) {
        if (curve_list[i].nid == nid)
            return curve_list[i].name;
    }
    return NULL;
}

int ossl_ec_curve_name2nid(const char *name)
{
    size_t i;
    int nid;

    if (name != NULL) {
        if ((nid = ossl_ec_curve_nist2nid_int(name)) != NID_undef)
            return nid;

        for (i = 0; i < OSSL_NELEM(curve_list); i++) {
            if (OPENSSL_strcasecmp(curve_list[i].name, name) == 0)
                return curve_list[i].nid;
        }
    }

    return NID_undef;
}

/* Functions to translate between common NIST curve names and NIDs */

static const EC_NAME2NID nist_curves[] = {
    {"P-224", NID_secp224r1},
    {"P-256", NID_X9_62_prime256v1},
    {"P-384", NID_secp384r1},
    {"P-521", NID_secp521r1}
};

const char *ossl_ec_curve_nid2nist_int(int nid)
{
    size_t i;
    for (i = 0; i < OSSL_NELEM(nist_curves); i++) {
        if (nist_curves[i].nid == nid)
            return nist_curves[i].name;
    }
    return NULL;
}

int ossl_ec_curve_nist2nid_int(const char *name)
{
    size_t i;
    for (i = 0; i < OSSL_NELEM(nist_curves); i++) {
        if (strcmp(nist_curves[i].name, name) == 0)
            return nist_curves[i].nid;
    }
    return NID_undef;
}
