#!/usr/bin/env bash
# Called by hooks/post_install.lua. Turns the downloaded Homebrew bottle into:
#   <install>/<pg major>/lib/vector.{dylib,so}
#   <install>/<pg major>/extension/vector.control, vector--*.sql
#   <install>/bin/pgvector-link
# Bottles carry builds for several Postgres majors; all are kept and
# pgvector-link picks the one matching the Postgres on PATH.
# Usage: unpack.sh <install_dir> <plugin_dir>
set -euo pipefail

install_dir="$1"
plugin_dir="$2"
cd "$install_dir"

shopt -s nullglob
blobs=(sha256:*)
if [[ ${#blobs[@]} -ne 1 ]]; then
    echo "pgvector: expected exactly one downloaded bottle in $install_dir, found: ${blobs[*]:-none}" >&2
    exit 1
fi

work="$(mktemp -d "$install_dir/.unpack.XXXXXX")"
trap 'rm -rf "$work"' EXIT
tar -xzf "${blobs[0]}" -C "$work"

found=0
for libdir in "$work"/pgvector/*/lib/postgresql@*; do
    major="${libdir##*@}"
    sharedir="$(dirname "$(dirname "$libdir")")/share/postgresql@$major/extension"
    mkdir -p "$major/lib" "$major/extension"
    cp "$libdir"/vector.* "$major/lib/"
    cp "$sharedir"/vector* "$major/extension/"
    found=1
done
if [[ $found -eq 0 ]]; then
    echo "pgvector: no lib/postgresql@<major> directories in the bottle" >&2
    exit 1
fi

mkdir -p bin
install -m 0755 "$plugin_dir/share/pgvector-link" bin/pgvector-link
rm -f "${blobs[0]}"
