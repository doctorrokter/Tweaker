#!/usr/bin/env bash
#
# build-certstore-tool.sh - boot/certstore-tool from boot/certstore-tool.c, for the phone. Run it after changing the source:
# the build in Momentics packs the result, it does not make it.

set -euo pipefail

TOOLS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BOOT_DIR="$(cd "$TOOLS_DIR/../boot" && pwd)"

: "${QNX_HOST:=E:/dev/blackberry/bbndk.win32.tools.10.3.1.12/host_10_3_1_12/win32/x86}"
: "${QNX_TARGET:=E:/dev/blackberry/bbndk.win32.libraries.10.3.1.995/target_10_3_1_995/qnx6}"
export QNX_HOST QNX_TARGET

"$QNX_HOST/usr/bin/qcc.exe" -Vgcc_ntoarmv7le -Wc,-std=gnu99 -Wall -fPIE -pie \
    -o "$BOOT_DIR/certstore-tool" "$BOOT_DIR/certstore-tool.c" -lsqlite3

echo "== $BOOT_DIR/certstore-tool"
