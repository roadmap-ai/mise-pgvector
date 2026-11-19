#!/usr/bin/env bash
# End-to-end: install this plugin with an isolated mise, install prebuilt
# Postgres (aqua), link pgvector into it, and run a real vector query.
#
# Env:
#   PGVECTOR_VERSION   pgvector version to test (default 0.8.4)
#   PG_VERSIONS        aqua theseus-rs/postgresql-binaries versions (default "17.12.0 18.7.0")
#   E2E_DIR            scratch dir (default ./.e2e; downloads are cached across runs)
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PGVECTOR_VERSION="${PGVECTOR_VERSION:-0.8.4}"
PG_VERSIONS="${PG_VERSIONS:-17.12.0 18.7.0}"
E2E_DIR="${E2E_DIR:-$ROOT/.e2e}"

export MISE_DATA_DIR="$E2E_DIR/data"
export MISE_CACHE_DIR="$E2E_DIR/cache"
export MISE_TRUSTED_CONFIG_PATHS="$E2E_DIR/proj"
export MISE_CEILING_PATHS="$E2E_DIR" # do not inherit this repo's mise.toml
export MISE_GLOBAL_CONFIG_FILE="$E2E_DIR/global.toml"

rm -rf "$MISE_DATA_DIR" "$E2E_DIR/proj"
mkdir -p "$MISE_DATA_DIR" "$MISE_CACHE_DIR" "$E2E_DIR/proj"
: >"$MISE_GLOBAL_CONFIG_FILE"
mise plugin link --force pgvector "$ROOT"

for pg_version in $PG_VERSIONS; do
    echo "=== Postgres $pg_version"
    cat >"$E2E_DIR/proj/mise.toml" <<EOF
[tools]
"aqua:theseus-rs/postgresql-binaries" = "$pg_version"
pgvector = "$PGVECTOR_VERSION"
EOF
    (
        cd "$E2E_DIR/proj"
        mise install
        run() { mise exec -- "$@"; }

        run pgvector-link
        run pgvector-link # idempotent

        pgdata="$E2E_DIR/pgdata-$pg_version"
        rm -rf "$pgdata"
        port="${E2E_PORT:-54339}"
        sock="$(mktemp -d)"
        run initdb -D "$pgdata" -U postgres --auth=trust >/dev/null
        run pg_ctl -D "$pgdata" -o "-p $port -k $sock -c listen_addresses=''" -l "$E2E_DIR/pg-$pg_version.log" -w start >/dev/null
        trap 'mise exec -- pg_ctl -D "$pgdata" -m fast stop >/dev/null || true; rm -rf "$sock"' EXIT

        psql() { run psql -h "$sock" -p "$port" -U postgres -v ON_ERROR_STOP=1 -qtAX "$@"; }
        psql -c "CREATE EXTENSION vector"
        installed="$(psql -c "SELECT extversion FROM pg_extension WHERE extname = 'vector'")"
        nearest="$(psql -c "SELECT v FROM (VALUES ('[1,1]'::vector), ('[5,5]'), ('[9,9]')) t(v) ORDER BY v <-> '[4,4]' LIMIT 1")"

        [[ "$installed" == "$PGVECTOR_VERSION" ]] || { echo "✗ vector $installed, expected $PGVECTOR_VERSION"; exit 1; }
        [[ "$nearest" == "[5,5]" ]] || { echo "✗ nearest neighbour '$nearest', expected '[5,5]'"; exit 1; }
        echo "✓ pgvector $installed on Postgres $pg_version: nearest neighbour $nearest"
    )
done
