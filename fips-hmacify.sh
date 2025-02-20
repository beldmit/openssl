#!/bin/bash

dd if=/dev/zero bs=1 count=32 of=tmp.mac >/dev/null 2>&1
objcopy --update-section .rodata1=tmp.mac providers/fips.so providers/fips.so.zeromac
mv providers/fips.so.zeromac providers/fips.so
LD_LIBRARY_PATH=. apps/openssl dgst -binary -sha256 -mac HMAC -macopt hexkey:f4556650ac31d35461610bac4ed81b1a181b2d8a43ea2854cbae22ca74560813 < providers/fips.so > providers/fips.so.hmac
objcopy --update-section .rodata1=providers/fips.so.hmac providers/fips.so providers/fips.so.mac
mv providers/fips.so.mac providers/fips.so
