#!/usr/bin/env bash
#
# make-certs.sh - Mozilla's root certificates in the form the phone's certificate store keeps them, into certs/:
#
#   certs/cert_<SHA1>.pem   one certificate
#   certs/index.txt         "<SHA1> <subject hash>" per certificate, what core/Certificates checks against
#   certs/mozilla.db        the same roots with the attributes the store keeps for each, what boot/certstore-tool imports
#
# From bb-shared/net/deps/prebuilt/cacert.pem, the list libbbnet carries. Needs openssl and python3: run it in WSL or on
# Linux, whenever that list is refreshed.

set -euo pipefail

TOOLS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$TOOLS_DIR/.." && pwd)"
BUNDLE="$PROJECT_DIR/../bb-shared/net/deps/prebuilt/cacert.pem"
OUTPUT="$PROJECT_DIR/certs"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

rm -rf "$OUTPUT"
mkdir -p "$OUTPUT"

# One file per certificate.
awk -v dir="$WORK" '
    /-----BEGIN CERTIFICATE-----/ { count += 1; file = sprintf("%s/%04d.pem", dir, count); writing = 1 }
    writing { print > file }
    /-----END CERTIFICATE-----/ { writing = 0; close(file) }
' "$BUNDLE"

: > "$OUTPUT/index.txt"
for one in "$WORK"/*.pem; do
    sha1="$(openssl x509 -in "$one" -noout -fingerprint -sha1 | sed 's/.*=//; s/://g')"
    hash="$(openssl x509 -in "$one" -noout -subject_hash)"
    openssl x509 -in "$one" -outform PEM -out "$OUTPUT/cert_$sha1.pem"
    echo "$sha1 $hash" >> "$OUTPUT/index.txt"
done

echo "== $(wc -l < "$OUTPUT/index.txt") certificates in certs/"
python3 -I "$TOOLS_DIR/make-certs-db.py" "$OUTPUT"
