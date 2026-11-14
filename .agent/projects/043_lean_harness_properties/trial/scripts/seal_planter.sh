#!/usr/bin/env bash
# PLAN-001 §6 and A1 item 7, W1: the operator seals the planter's directory, in a plain shell
# (no agent in the pane), so the passphrase enters no session's context. openssl reads the
# passphrase from the terminal. The script encrypts, decrypts once to check the passphrase, and
# prints the encrypted file's sha256. It deletes nothing: the operator's session does that after.
#   bash seal_planter.sh
set -euo pipefail
ROOT=/home/motoko/trial-043
OUT=$ROOT/sealed/planter.tar.gz.enc
if [ -e "$OUT" ]; then echo "refusing: $OUT exists"; exit 1; fi
stream() { tar --sort=name --mtime=@0 --owner=0 --group=0 --numeric-owner -C "$ROOT" -cf - planter; }
echo "1/3 hashing the plaintext archive (about a minute)"
plain=$(stream | sha256sum | cut -d' ' -f1)
echo "2/3 encrypting: type the passphrase, then type it again"
stream | gzip -1 | openssl enc -aes-256-cbc -pbkdf2 -salt -out "$OUT"
echo "3/3 decrypting once to check: type the passphrase a third time"
back=$(openssl enc -d -aes-256-cbc -pbkdf2 -in "$OUT" | gunzip | sha256sum | cut -d' ' -f1) || back=failed
if [ "$plain" != "$back" ]; then echo "SEAL FAILED: the check did not decrypt to the same archive. Delete $OUT and run again"; exit 1; fi
echo "SEAL OK plaintext_tar_sha256=$plain encrypted_sha256=$(sha256sum "$OUT" | cut -d' ' -f1)"
