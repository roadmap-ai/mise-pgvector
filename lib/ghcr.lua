-- Anonymous, read-only access to Homebrew's public bottle registry on ghcr.io.
local M = {}

local function get(url, headers)
    local http = require("http")
    local resp, err = http.get({ url = url, headers = headers })
    if err ~= nil then
        error("ghcr.io request failed (" .. url .. "): " .. err)
    end
    if resp.status_code ~= 200 then
        error("ghcr.io returned " .. resp.status_code .. " for " .. url .. ": " .. resp.body)
    end
    return require("json").decode(resp.body)
end

--- Anonymous pull token for a ghcr.io repository.
function M.token(repo)
    return get("https://ghcr.io/token?scope=repository:" .. repo .. ":pull").token
end

function M.auth(token)
    return { Authorization = "Bearer " .. token }
end

function M.tags(repo, token)
    return get("https://ghcr.io/v2/" .. repo .. "/tags/list?n=1000", M.auth(token)).tags
end

function M.index(repo, tag, token)
    local headers = M.auth(token)
    headers.Accept = "application/vnd.oci.image.index.v1+json"
    return get("https://ghcr.io/v2/" .. repo .. "/manifests/" .. tag, headers)
end

return M
