--- Picks the Homebrew bottle for this machine; mise downloads and checksums it.
function PLUGIN:PreInstall(ctx)
    local bottles = require("bottles")
    local ghcr = require("ghcr")

    local o = { os = RUNTIME.osType, arch = RUNTIME.archType }
    if o.os == "darwin" then
        local h = io.popen("sw_vers -productVersion 2>/dev/null")
        o.macos_version = h and h:read("*l") or nil
        if h then
            h:close()
        end
    end

    local token = ghcr.token(bottles.REPO)
    local bottle, err = bottles.select(ghcr.index(bottles.REPO, ctx.version, token), o)
    if not bottle then
        error("pgvector " .. ctx.version .. ": " .. err)
    end

    return {
        version = ctx.version,
        url = bottles.blob_url(bottle.sha256),
        sha256 = bottle.sha256,
        headers = ghcr.auth(token),
        note = bottle.ref,
    }
end
