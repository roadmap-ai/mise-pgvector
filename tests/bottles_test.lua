-- Unit tests for lib/bottles.lua. Run with: lua tests/bottles_test.lua
package.path = "./lib/?.lua;" .. package.path
local bottles = require("bottles")

local failures, passed = 0, 0
local function test(name, fn)
    local ok, err = pcall(fn)
    if ok then
        passed = passed + 1
    else
        failures = failures + 1
        print("FAIL " .. name .. ": " .. tostring(err))
    end
end
local function eq(actual, expected)
    if actual ~= expected then
        error(string.format("expected %q, got %q", tostring(expected), tostring(actual)), 2)
    end
end
local function contains(haystack, needle)
    if not tostring(haystack):find(needle, 1, true) then
        error(string.format("expected %q to contain %q", tostring(haystack), needle), 2)
    end
end

-- Shaped like the real ghcr.io/homebrew/core/pgvector:0.8.4 OCI index.
local function index()
    local function m(ref, os, arch, os_version)
        return {
            digest = "sha256:manifest-" .. ref,
            platform = { os = os, architecture = arch, ["os.version"] = os_version },
            annotations = {
                ["org.opencontainers.image.ref.name"] = ref,
                ["sh.brew.bottle.digest"] = "blob-" .. ref,
            },
        }
    end
    return {
        manifests = {
            m("0.8.4.arm64_linux", "linux", "arm64", "Ubuntu 24.04.4"),
            m("0.8.4.arm64_sequoia", "darwin", "arm64", "macOS 15.7"),
            m("0.8.4.arm64_sonoma", "darwin", "arm64", "macOS 14.8"),
            m("0.8.4.arm64_tahoe", "darwin", "arm64", "macOS 26"),
            m("0.8.4.sonoma", "darwin", "amd64", "macOS 14.8"),
            m("0.8.4.x86_64_linux", "linux", "amd64", "Ubuntu 24.04.4"),
        },
    }
end

test("macOS picks the bottle for the running macOS release", function()
    eq(
        bottles.select(index(), { os = "darwin", arch = "arm64", macos_version = "26.5.1" }).sha256,
        "blob-0.8.4.arm64_tahoe"
    )
    eq(
        bottles.select(index(), { os = "darwin", arch = "arm64", macos_version = "15.3" }).sha256,
        "blob-0.8.4.arm64_sequoia"
    )
    eq(
        bottles.select(index(), { os = "darwin", arch = "arm64", macos_version = "14.0" }).sha256,
        "blob-0.8.4.arm64_sonoma"
    )
end)

test("macOS newer than every bottle falls back to the newest", function()
    eq(
        bottles.select(index(), { os = "darwin", arch = "arm64", macos_version = "27.0" }).sha256,
        "blob-0.8.4.arm64_tahoe"
    )
end)

test("macOS older than every bottle is an error", function()
    local b, err = bottles.select(index(), { os = "darwin", arch = "arm64", macos_version = "13.6" })
    eq(b, nil)
    contains(err, "macOS 13")
end)

test("Intel macOS uses the amd64 bottle", function()
    eq(bottles.select(index(), { os = "darwin", arch = "amd64", macos_version = "15.1" }).sha256, "blob-0.8.4.sonoma")
end)

test("Linux picks by architecture", function()
    eq(bottles.select(index(), { os = "linux", arch = "amd64" }).sha256, "blob-0.8.4.x86_64_linux")
    eq(bottles.select(index(), { os = "linux", arch = "arm64" }).sha256, "blob-0.8.4.arm64_linux")
end)

test("unsupported platform is an error", function()
    local b, err = bottles.select(index(), { os = "windows", arch = "amd64" })
    eq(b, nil)
    contains(err, "windows")
end)

test("blob URL is built from the bottle digest", function()
    eq(bottles.blob_url("abc"), "https://ghcr.io/v2/homebrew/core/pgvector/blobs/sha256:abc")
end)

test("versions keep plain releases only, newest first", function()
    local v = bottles.versions({ "0.4.1", "0.5.1", "0.5.1-1", "0.5.1_2", "0.8.10", "0.8.4", "0.8.7" })
    eq(#v, 5)
    eq(v[1], "0.8.10")
    eq(v[2], "0.8.7")
    eq(v[3], "0.8.4")
    eq(v[5], "0.4.1")
end)

print(string.format("%d passed, %d failed", passed, failures))
os.exit(failures == 0 and 0 or 1)
