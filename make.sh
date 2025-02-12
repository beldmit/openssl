#!/bin/bash
set -e

./Configure --prefix=/usr --openssldir=/etc/pki/tls enable-ec_nistp_64_gcc_128 \
--system-ciphers-file=/etc/crypto-policies/back-ends/opensslcnf.config zlib \
enable-camellia enable-seed enable-rfc3779 enable-sctp enable-sslkeylog \
enable-cms enable-md2 enable-rc5 enable-ktls enable-fips -D_GNU_SOURCE no-mdc2 \
no-ec2m no-sm2 no-sm4 no-atexit enable-buildtest-c++ shared linux-x86_64 -O2 \
-fexceptions -g -grecord-gcc-switches -pipe -Wall -Wno-complain-wrong-lang \
-Werror=format-security -Wp,-U_FORTIFY_SOURCE,-D_FORTIFY_SOURCE=3 \
-Wp,-D_GLIBCXX_ASSERTIONS -specs=/usr/lib/rpm/redhat/redhat-hardened-cc1 \
-fstack-protector-strong -specs=/usr/lib/rpm/redhat/redhat-annobin-cc1 -m64 \
-march=x86-64-v2 -mtune=generic -fasynchronous-unwind-tables \
-fstack-clash-protection -fcf-protection -mtls-dialect=gnu2 -Wa,--noexecstack \
-Wa,--generate-missing-build-notes=yes -DPURIFY -Wl,-z,relro -Wl,--as-needed \
-Wl,-z,pack-relative-relocs -Wl,-z,now \
'-DDEVRANDOM="\"/dev/urandom\""' -DOPENSSL_PEDANTIC_ZEROIZATION '-DREDHAT_FIPS_VENDOR="\"Red Hat Enterprise Linux OpenSSL FIPS Provider\""' '-DREDHAT_FIPS_VERSION="\"3.5.5-502eba1f3c5fa24f\""' \
-Wl,--allow-multiple-definition

make -j8

# Verify fips-hmacify.sh actually modifies fips.so
FIPS_BEFORE=$(sha256sum providers/fips.so | cut -d' ' -f1)
./fips-hmacify.sh
FIPS_AFTER=$(sha256sum providers/fips.so | cut -d' ' -f1)

if [ "$FIPS_BEFORE" = "$FIPS_AFTER" ]; then
    echo "ERROR: fips-hmacify.sh did not modify providers/fips.so"
    exit 1
fi

echo "FIPS module successfully modified: $FIPS_BEFORE -> $FIPS_AFTER"

OPENSSL_ENABLE_MD5_VERIFY= OPENSSL_ENABLE_SHA1_SIGNATURES= OPENSSL_SYSTEM_CIPHERS_OVERRIDE=xyz_nonexistent_file make test HARNESS_JOBS=8
