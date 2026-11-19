-- Pure selection logic: picks the Homebrew pgvector bottle for a platform from
-- its ghcr.io OCI index. No I/O here so it can be unit tested with plain Lua.
local M = {}

M.REPO = "homebrew/core/pgvector"

local function os_major(manifest)
    local v = manifest.platform and manifest.platform["os.version"] or ""
    return tonumber(v:match("^macOS (%d+)"))
end

local function bottle(manifest)
    local a = manifest.annotations or {}
    return { sha256 = a["sh.brew.bottle.digest"], ref = a["org.opencontainers.image.ref.name"] }
end

local function select_macos(manifests, o)
    local current = tonumber((o.macos_version or ""):match("^(%d+)"))
    if not current then
        return nil, "could not determine the macOS version"
    end
    local best, best_major, newest, newest_major, oldest_major
    for _, m in ipairs(manifests) do
        local major = os_major(m)
        if m.platform.os == "darwin" and m.platform.architecture == o.arch and major then
            if major <= current and (not best_major or major > best_major) then
                best, best_major = m, major
            end
            if not newest_major or major > newest_major then
                newest, newest_major = m, major
            end
            if not oldest_major or major < oldest_major then
                oldest_major = major
            end
        end
    end
    if best then
        return bottle(best)
    end
    if newest and current > newest_major then
        return bottle(newest)
    end
    if oldest_major then
        return nil, string.format("no pgvector bottle for macOS %d (oldest available: macOS %d)", current, oldest_major)
    end
    return nil, "no pgvector bottle for macOS " .. o.arch
end

--- Pick the bottle for a platform.
--- @param idx table OCI image index ({manifests = {...}})
--- @param o table {os, arch, macos_version?}
--- @return table|nil bottle {sha256, ref}, string|nil err
function M.select(idx, o)
    local manifests = idx.manifests or {}
    if o.os == "darwin" then
        return select_macos(manifests, o)
    elseif o.os == "linux" then
        for _, m in ipairs(manifests) do
            if m.platform.os == "linux" and m.platform.architecture == o.arch then
                return bottle(m)
            end
        end
        return nil, "no pgvector bottle for linux/" .. o.arch
    end
    return nil, "unsupported OS: " .. tostring(o.os) .. " (supported: macOS, Linux)"
end

function M.blob_url(sha256)
    return "https://ghcr.io/v2/" .. M.REPO .. "/blobs/sha256:" .. sha256
end

local function parts(v)
    local a, b, c = v:match("^(%d+)%.(%d+)%.(%d+)$")
    return { tonumber(a), tonumber(b), tonumber(c) }
end

--- Plain x.y.z tags (Homebrew rebuild tags like 0.5.1_1 are skipped), newest first.
function M.versions(tags)
    local out = {}
    for _, t in ipairs(tags) do
        if t:match("^%d+%.%d+%.%d+$") then
            table.insert(out, t)
        end
    end
    table.sort(out, function(x, y)
        local a, b = parts(x), parts(y)
        for i = 1, 3 do
            if a[i] ~= b[i] then
                return a[i] > b[i]
            end
        end
        return false
    end)
    return out
end

return M
