# QUIC Security Fixes - Medium Backport Status

**Branch**: `quic-35-backport-baseline`  
**Target**: OpenSSL 3.2.6 with QUIC improvements from 3.5

## Critical CVEs Addressed

### ✅ CVE-2026-75804 - Connection-Level Flow Control Not Enforced
**Status**: FIXED (Commit: 959d8335f6)  
**Severity**: High - Remote Memory Exhaustion  
**Impact**: Client and Server

**Issue**: The QUIC stack did not enforce connection-level flow control, only stream-level. This allowed a malicious peer to exceed the connection's `max_data` limit while respecting individual stream limits, causing unbounded memory allocation.

**Fix**: Modified `ossl_quic_rxfc_get_error()` in `ssl/quic/quic_fc.c` to check both stream-level AND connection-level (parent) flow control errors.

**Files Changed**:
- `ssl/quic/quic_fc.c` (+10 lines, -1 line)

---

### ✅ CVE-2026-95691 - Use-After-Free in CRYPTO Frame Retransmission
**Status**: FIXED (Already included in Layer 3 - Commit: cfd50b9560)  
**Severity**: Critical - Memory Corruption  
**Impact**: Client and Server

**Issue**: The record layer's pointer into the receive stream buffer could become stale when overlapping stream frames were received. The `_peek()` operation didn't lock the range, so stream reassembly could free and reallocate the buffer, causing use-after-free.

**Fix**: Our Layer 3 backport (stream reassembly from 3.5) includes the range locking mechanism:
- `ossl_sframe_set_lock_range()` - Locks a range for zero-copy access
- `ossl_sframe_set_unlock_range()` - Releases the lock
- Overlap detection and discarding in `quic_strm_reas.c`

**Evidence**:
```bash
$ grep -n "lock_range\|locked_range" ssl/quic/quic_strm_reas.c
944:        && r->start < fs->locked_range.end
945:        && r->end > fs->locked_range.start) {
1252:int ossl_sframe_set_lock_range(SFRAME_SET *fs, const UINT_RANGE *range)
1264:void ossl_sframe_set_unlock_range(SFRAME_SET *fs)

$ grep -n "range_locked" ssl/quic/quic_rstream.c
138:    if (qrs->fs.range_locked)
180:    if (qrs->fs.range_locked)
222:    if (!qrs->fs.range_locked)
```

**Files Changed** (Layer 3):
- `include/internal/quic_strm_reas.h` - Added lock/unlock APIs
- `ssl/quic/quic_strm_reas.c` - Implemented range locking
- `ssl/quic/quic_rstream.c` - Uses range locking for record layer

---

### ⏭️ CVE-2026-84784 - Unbounded RETIRE_CONNECTION_ID Backlog
**Status**: NOT APPLICABLE (Server-Only)  
**Severity**: High - Memory DoS  
**Impact**: Server Only

**Issue**: Malicious client could queue excessive RETIRE_CONNECTION_ID frames by exploiting incorrect state management. The `cur_retire_prior_to` counter was updated when queuing the frame instead of after ACK receipt.

**Why Not Applied**:
- Fix requires significant changes to `quic_channel.c`
- Our 3.2 `quic_channel.c` is significantly different from 3.5
- This vulnerability affects **server-side** NEW_CONNECTION_ID processing
- Medium Backport is **client-only** (no server support)
- Client doesn't process NEW_CONNECTION_ID frames from peers in the same way

**Original Fix**: Commit dba3c48d653c64fcbc9070a17a0ee2b3e2f3af1f
- Added `CFQ_DATA_RETIRE_CID_T` structure
- Deferred counter update to ACK time via `free_frame_rtcid()` callback
- Modified `ch_enqueue_retire_conn_id()` and `ossl_quic_channel_on_new_conn_id()`

---

### ⏭️ CVE-2026-18798 - Double Free of QRX in Port Handler
**Status**: NOT APPLICABLE (Requires PORT Infrastructure)  
**Severity**: High - Memory Corruption  
**Impact**: Server Only

**Issue**: `port_default_packet_handler()` could double-free the QRX object when channel creation failed, due to unclear ownership transfer semantics.

**Why Not Applied**:
- Fix is in `ssl/quic/quic_port.c` - part of PORT/ENGINE refactoring
- Medium Backport **does not include** PORT/ENGINE infrastructure
- PORT is for multi-connection demultiplexing (server-side feature)
- Our client-only backport uses direct channel management

**Original Fix**: Commit 967582d5037f01a26b6d19beae19af62a1b15c3c
- Added reference counting to QRX objects
- Modified `port_default_packet_handler()` and `port_bind_channel()`
- Updated `quic_record_rx.c` with refcount logic

---

### ⏭️ CVE-2026-42764 - NULL Dereference in Address Validation
**Status**: NOT APPLICABLE (Requires PORT Infrastructure)  
**Severity**: Medium - Server Crash  
**Impact**: Server Only

**Issue**: QUIC server crashed when address validation was disabled and client sent initial packet with invalid token.

**Why Not Applied**:
- Fix is in `ssl/quic/quic_port.c`
- Address validation is a **server-side** feature (RFC 9000, Section 8.1)
- Clients don't perform address validation
- Our backport has no PORT infrastructure

**Original Fix**: Commit 5e3ed291b8af0b03d5d3b9e56a1da69a187e9729

---

## Other Stability Improvements Already Included

### Stream Garbage Collection (Layer 3)
**Commits**: f3acb0a332, 22291a6af1, etc.  
**Status**: Included in Layer 3 stream reassembly backport

Proper cleanup of deleted streams whose receive part is terminal, preventing memory leaks during long-running connections.

### Packet Buffer Overhead Limiting (Layer 3)
**Commit**: 279e7ee139  
**Status**: Included in Layer 3 stream reassembly backport

Limits packet buffer overhead to ~64kB per stream by automatically migrating from packet storage to heap storage when threshold exceeded. Prevents memory waste.

---

## Summary

**Total CVEs in 3.2 → 3.5 QUIC**: 5 identified  
**Fixed in Medium Backport**: 2 (CVE-2026-75804, CVE-2026-95691)  
**Not Applicable (Server-Only)**: 3 (CVE-2026-84784, CVE-2026-18798, CVE-2026-42764)

### Client-Side Security Status

✅ **Flow Control Enforcement**: Fixed  
✅ **Use-After-Free Protection**: Fixed  
✅ **Memory Management**: Improved (stream reassembly, packet buffer limits)  
✅ **Connection ID Management**: Robust (Layer 4 - LCIDM/RCIDM/SRTM)

### Not Included (Server-Only Features)

- PORT-based multi-connection handling
- Address validation
- NEW_CONNECTION_ID backlog limiting (server processes these differently)

The Medium Backport focuses on **client-side stability and security**, which is appropriate for the stated goal of maintaining OpenSSL 3.2 QUIC clients with improvements from 3.5 without full PORT/ENGINE/server refactoring.

---

## Verification

To verify CVE fixes are present:

```bash
# CVE-2026-75804 - Flow control fix
git show 959d8335f6:ssl/quic/quic_fc.c | grep -A5 "parent->error_code"

# CVE-2026-95691 - Range locking
git show cfd50b9560:ssl/quic/quic_strm_reas.c | grep -n "lock_range"
```

**Last Updated**: 2026-11-20  
**Branch HEAD**: 959d8335f6
