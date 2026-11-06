#!/usr/bin/env bash
# PLAN-001 W3: once all 24 arm sessions have ended, the operator decrypts the planter's sealed
# directory, in a plain shell (no agent in the pane), so the passphrase enters no session's
# context. openssl reads it from the terminal. The script checks the encrypted file, the
# plaintext archive and manifest.tsv against the hashes committed at W1 (sequence.log, 15:46:57Z),
# then leaves the directory at $ROOT/unsealed/planter. It deletes nothing it did not create.
#   bash unseal_planter.sh
set -euo pipefail
ROOT=/home/motoko/trial-043
IN=$ROOT/sealed/planter.tar.gz.enc
DEST=$ROOT/unsealed
ENC=2e120580b412102670a3a635860872e157330db44072f7b7065fdddab3b5a5f3
TAR=f0281886ebff9821c486427b850e990983d45728cfdd20e8e8c7010a1211b911
MAN=24c2bbe26280aaf2c2b80c444ee9728cea6512086845ca91bf40fbc916fb9d2c
fail() { echo "UNSEAL FAILED: $1"; exit 1; }
if [ -e "$DEST" ]; then fail "$DEST exists"; fi
echo "1/3 checking the encrypted file against W1"
[ "$(sha256sum "$IN" | cut -d' ' -f1)" = "$ENC" ] || fail "$IN does not match W1's encrypted_sha256"
echo "2/3 decrypting: type the passphrase"
tmp=$(mktemp -d "$ROOT/.unseal.XXXXXX")
if ! openssl enc -d -aes-256-cbc -pbkdf2 -in "$IN" | gunzip > "$tmp/planter.tar"; then
  rm -rf "${tmp:?}"; fail "wrong passphrase or a damaged file. Nothing was kept; run again"
fi
if [ "$(sha256sum "$tmp/planter.tar" | cut -d' ' -f1)" != "$TAR" ]; then
  rm -rf "${tmp:?}"; fail "the archive does not match W1's plaintext hash"
fi
echo "3/3 extracting and checking manifest.tsv"
mkdir "$DEST"; tar -xf "$tmp/planter.tar" -C "$DEST"; rm -rf "${tmp:?}"
m=$(find "$DEST/planter" -maxdepth 2 -name manifest.tsv | head -1)
[ -n "$m" ] || fail "no manifest.tsv in $DEST/planter"
[ "$(sha256sum "$m" | cut -d' ' -f1)" = "$MAN" ] || fail "$m does not match W1's manifest_sha256"
echo "UNSEAL OK archive_sha256=$TAR manifest_sha256=$MAN at $m"
