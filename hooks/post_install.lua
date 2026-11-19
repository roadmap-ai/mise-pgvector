--- Unpacks the bottle into lib/<pg major>/ and share/<pg major>/extension/ and installs bin/pgvector-link.
function PLUGIN:PostInstall(ctx)
    local path = ctx.sdkInfo[PLUGIN.name].path
    local cmd = string.format("bash %q %q %q", RUNTIME.pluginDirPath .. "/share/unpack.sh", path, RUNTIME.pluginDirPath)
    local status = os.execute(cmd)
    if status ~= 0 and status ~= true then
        error("pgvector: unpacking failed (" .. cmd .. ")")
    end
end
