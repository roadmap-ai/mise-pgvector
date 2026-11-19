--- Lists pgvector versions that have Homebrew bottles on ghcr.io.
function PLUGIN:Available(ctx) -- luacheck: ignore
    local bottles = require("bottles")
    local ghcr = require("ghcr")
    local result = {}
    for _, v in ipairs(bottles.versions(ghcr.tags(bottles.REPO, ghcr.token(bottles.REPO)))) do
        table.insert(result, { version = v })
    end
    return result
end
