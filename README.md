# mise-pgvector

A [mise](https://mise.jdx.dev) tool plugin that installs **prebuilt** [pgvector](https://github.com/pgvector/pgvector)
for local Postgres. Nothing is compiled.

pgvector publishes no binaries itself, so this plugin uses Homebrew's bottles from
`ghcr.io/homebrew/core/pgvector`. They're public, keep every past version, and cover macOS and Linux. Each bottle
contains builds for several Postgres majors (0.8.4 has 17 and 18); all are kept, and `pgvector-link` picks the
one matching your Postgres.

## Usage

```toml
# mise.toml
[plugins]
pgvector = "https://github.com/roadmap-ai/mise-pgvector"

[tools]
"aqua:theseus-rs/postgresql-binaries" = "17.12.0"  # prebuilt Postgres
pgvector = "0.8.4"
```

```sh
mise install
mise exec -- pgvector-link   # link into the Postgres whose pg_config is on PATH
```

Then `CREATE EXTENSION vector;`. Postgres 17 and older only load extensions from their own install directory, which is
why the link step exists. It is idempotent.

## How it picks a build

From the bottle's OCI index on ghcr.io (anonymous pull token):

- **macOS**: matching architecture, newest bottle not newer than your macOS (falls back to the newest for newer macOS).
- **Linux**: matching architecture (`x86_64_linux` / `arm64_linux`). These are built on Ubuntu 24.04, so they need a
  similarly recent glibc. `vector.so` itself only links libc.

mise downloads the blob and verifies its sha256 (the bottle digest from the index). `PostInstall` unpacks it into
`<pg major>/lib` and `<pg major>/extension`.

Exported env: `PGVECTOR_HOME`, and `bin/` (for `pgvector-link`) on `PATH`.

## Development

```sh
mise run unit   # bottle selection (pure Lua)
mise run e2e    # sandboxed mise: Postgres 17 and 18 + this plugin, run a vector query
mise run ci     # lint + unit + e2e
```
