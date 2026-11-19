--- Puts pgvector-link on PATH and exposes the install location.
function PLUGIN:EnvKeys(ctx)
    return {
        { key = "PATH", value = ctx.path .. "/bin" },
        { key = "PGVECTOR_HOME", value = ctx.path },
    }
end
