-- Stablemaster: Utility Functions

-- Initialize global addon namespaces early
Stablemaster   = Stablemaster   or {}
StablemasterUI = StablemasterUI or {}

-- Get character-specific key for database
local function GetCharacterKey()
    local name = UnitName("player")
    local realm = GetRealmName()
    return name .. "-" .. realm
end

-- Enhanced database initialization with character-specific data
StablemasterDB = StablemasterDB or {}

-- Migrate old data structure if needed
local function MigrateOldData()
    -- If we have old-style packs directly in StablemasterDB, migrate them
    if StablemasterDB.packs and type(StablemasterDB.packs) == "table" and #StablemasterDB.packs > 0 then
        Stablemaster.Debug("Migrating old pack data to character-specific format...")
        
        -- Ensure characters table exists
        StablemasterDB.characters = StablemasterDB.characters or {}
        
        -- Get current character key
        local charKey = UnitName("player") .. "-" .. GetRealmName()
        
        -- Move old packs to current character
        StablemasterDB.characters[charKey] = {
            packs = StablemasterDB.packs,
            created = time(),
            migrated = true
        }
        
        -- Remove old packs array
        StablemasterDB.packs = nil
        
        Stablemaster.Debug("Migrated " .. #StablemasterDB.characters[charKey].packs .. " packs to character: " .. charKey)
    end
end

-- Initialize database structure
-- Ensure StablemasterDB exists first
if not StablemasterDB then
    StablemasterDB = {}
end

if not StablemasterDB.characters then
    StablemasterDB.characters = {}
end

if not StablemasterDB.sharedPacks then
    StablemasterDB.sharedPacks = {}
end

if not StablemasterDB.settings then
    StablemasterDB.settings = {
        debugMode = false,
        verboseMode = false,
        preferFlyingMounts = true,
        packOverlapMode = "union",
        minimapIconAngle = 220, -- Default position angle in degrees
        rulePriorities = {
            outfit = 100,   -- Outfit rules (Midnight 12.0+)
            holiday = 80,   -- Holiday rules
            transmog = 100, -- Legacy transmog rules (deprecated)
            class = 75,
            race = 60,
            zone = 50,
            time = 40,      -- Time of day rules
            season = 35,    -- Season rules
        }
    }
end

-- Ensure minimapIconAngle exists in existing databases
if StablemasterDB.settings.minimapIconAngle == nil then
    StablemasterDB.settings.minimapIconAngle = 220
end

-- Ensure rulePriorities has all entries (for databases created before these were added)
if StablemasterDB.settings.rulePriorities then
    if StablemasterDB.settings.rulePriorities.class == nil then
        StablemasterDB.settings.rulePriorities.class = 75
    end
    if StablemasterDB.settings.rulePriorities.race == nil then
        StablemasterDB.settings.rulePriorities.race = 60
    end
    if StablemasterDB.settings.rulePriorities.outfit == nil then
        StablemasterDB.settings.rulePriorities.outfit = 100
    end
    if StablemasterDB.settings.rulePriorities.time == nil then
        StablemasterDB.settings.rulePriorities.time = 40
    end
    if StablemasterDB.settings.rulePriorities.holiday == nil then
        StablemasterDB.settings.rulePriorities.holiday = 80
    end
    if StablemasterDB.settings.rulePriorities.season == nil then
        StablemasterDB.settings.rulePriorities.season = 35
    end
end

-- Initialize character-specific data
local function InitializeCharacterData()
    -- Migrate old data first if needed
    MigrateOldData()
    
    local charKey = GetCharacterKey()
    if not StablemasterDB.characters[charKey] then
        StablemasterDB.characters[charKey] = {
            packs = {},
            created = time()
        }
        Stablemaster.Debug("Initialized data for character: " .. charKey)
    end
end

-- Get current character's pack data (character-specific only)
function Stablemaster.GetCharacterPacks()
    InitializeCharacterData()
    local charKey = GetCharacterKey()
    return StablemasterDB.characters[charKey].packs
end

-- Set current character's pack data (character-specific only)
function Stablemaster.SetCharacterPacks(packs)
    InitializeCharacterData()
    local charKey = GetCharacterKey()
    StablemasterDB.characters[charKey].packs = packs
end

-- Get all packs available to current character (shared + character-specific)
function Stablemaster.GetAllAvailablePacks()
    InitializeCharacterData()
    local allPacks = {}
    
    -- Add shared packs first (higher priority)
    if StablemasterDB.sharedPacks then
        for _, pack in ipairs(StablemasterDB.sharedPacks) do
            pack.isShared = true -- Mark as shared
            table.insert(allPacks, pack)
        end
    end
    
    -- Add character-specific packs
    local charPacks = Stablemaster.GetCharacterPacks()
    for _, pack in ipairs(charPacks) do
        pack.isShared = false -- Mark as character-specific
        table.insert(allPacks, pack)
    end
    
    return allPacks
end

-- Toggle a pack's shared status
function Stablemaster.TogglePackShared(packName)
    local pack = nil
    local wasShared = false
    local sourceIndex = nil
    
    -- First check if it's currently in character-specific packs
    local charPacks = Stablemaster.GetCharacterPacks()
    for i, p in ipairs(charPacks) do
        if p.name == packName then
            pack = p
            sourceIndex = i
            wasShared = false
            break
        end
    end
    
    -- If not found, check shared packs
    if not pack and StablemasterDB.sharedPacks then
        for i, p in ipairs(StablemasterDB.sharedPacks) do
            if p.name == packName then
                pack = p
                sourceIndex = i
                wasShared = true
                break
            end
        end
    end
    
    if not pack then
        return false, "Pack '" .. packName .. "' not found"
    end
    
    if wasShared then
        -- Move from shared to character-specific
        table.remove(StablemasterDB.sharedPacks, sourceIndex)
        pack.isShared = false
        table.insert(charPacks, pack)
        Stablemaster.SetCharacterPacks(charPacks)
        return true, "Pack '" .. packName .. "' is now character-specific"
    else
        -- Move from character-specific to shared
        table.remove(charPacks, sourceIndex)
        Stablemaster.SetCharacterPacks(charPacks)
        pack.isShared = true
        
        -- Ensure StablemasterDB and shared packs table exist
        if not StablemasterDB then
            StablemasterDB = {}
        end
        if not StablemasterDB.sharedPacks then
            StablemasterDB.sharedPacks = {}
        end
        
        -- Debug output
        Stablemaster.Debug("Moving pack '" .. packName .. "' to shared storage")
        Stablemaster.Debug("StablemasterDB.sharedPacks type: " .. type(StablemasterDB.sharedPacks))
        
        table.insert(StablemasterDB.sharedPacks, pack)
        return true, "Pack '" .. packName .. "' is now shared account-wide"
    end
end

-- Get a pack by name (searches shared first, then character-specific)
function Stablemaster.GetPackByName(packName)
    -- Check shared packs first
    if StablemasterDB.sharedPacks then
        for _, pack in ipairs(StablemasterDB.sharedPacks) do
            if pack.name == packName then
                pack.isShared = true
                return pack
            end
        end
    end
    
    -- Check character-specific packs
    local charPacks = Stablemaster.GetCharacterPacks()
    for _, pack in ipairs(charPacks) do
        if pack.name == packName then
            pack.isShared = false
            return pack
        end
    end
    
    return nil
end

-- Debug (dev-only, respects /stablemaster debug-on|off)
function Stablemaster.Debug(msg)
    if StablemasterDB and StablemasterDB.settings and StablemasterDB.settings.debugMode then
        DEFAULT_CHAT_FRAME:AddMessage("|cff66cfffStablemaster|r [debug]: " .. tostring(msg))
    end
end

-- Branded chat output (player-facing)
do
    local PREFIX = "|cff66cfffStablemaster|r"
    function Stablemaster.Print(...)
        local parts = {}
        for i = 1, select("#", ...) do
            parts[#parts+1] = tostring(select(i, ...))
        end
        DEFAULT_CHAT_FRAME:AddMessage(PREFIX .. ": " .. table.concat(parts, " "))
    end
end

function Stablemaster.VerbosePrint(...)
    -- Debug the verbose check
    local verboseEnabled = StablemasterDB and StablemasterDB.settings and StablemasterDB.settings.verboseMode
    Stablemaster.Debug("VerbosePrint called - verboseMode: " .. tostring(verboseEnabled))
    
    if verboseEnabled then
        local parts = {}
        for i = 1, select("#", ...) do
            parts[#parts+1] = tostring(select(i, ...))
        end
        DEFAULT_CHAT_FRAME:AddMessage("|cff66cfffStablemaster|r: " .. table.concat(parts, " "))
    else
        Stablemaster.Debug("VerbosePrint suppressed (verbose mode off)")
    end
end

-- String trim helper (Lua has no string.trim)
function Stablemaster.Trim(s)
    if type(s) ~= "string" then return "" end
    return (s:gsub("^%s*(.-)%s*$", "%1"))
end

-- Small helpers
function Stablemaster.TableRemoveByIndex(t, idx)
    if type(t) == "table" and idx and t[idx] then
        table.remove(t, idx)
        return true
    end
    return false
end

-- ============================================================================
-- Base64 Encoding/Decoding for Import/Export
-- ============================================================================

local b64chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"

local function Base64Encode(data)
    local result = {}
    local padding = ""

    -- Pad with zeros if needed
    local mod = #data % 3
    if mod > 0 then
        padding = string.rep("=", 3 - mod)
        data = data .. string.rep("\0", 3 - mod)
    end

    for i = 1, #data, 3 do
        local b1, b2, b3 = data:byte(i, i + 2)
        local n = b1 * 65536 + b2 * 256 + b3

        local c1 = math.floor(n / 262144) % 64
        local c2 = math.floor(n / 4096) % 64
        local c3 = math.floor(n / 64) % 64
        local c4 = n % 64

        result[#result + 1] = b64chars:sub(c1 + 1, c1 + 1)
        result[#result + 1] = b64chars:sub(c2 + 1, c2 + 1)
        result[#result + 1] = b64chars:sub(c3 + 1, c3 + 1)
        result[#result + 1] = b64chars:sub(c4 + 1, c4 + 1)
    end

    local encoded = table.concat(result)
    if #padding > 0 then
        encoded = encoded:sub(1, #encoded - #padding) .. padding
    end

    return encoded
end

local function Base64Decode(data)
    -- Remove any whitespace
    data = data:gsub("%s", "")

    -- Check for valid base64
    if not data:match("^[A-Za-z0-9+/]+=*$") then
        return nil, "Invalid base64 characters"
    end

    local result = {}
    local padding = data:match("(=*)$")
    data = data:gsub("=", "A") -- Replace padding with A (which is 0)

    for i = 1, #data, 4 do
        local c1 = b64chars:find(data:sub(i, i)) - 1
        local c2 = b64chars:find(data:sub(i + 1, i + 1)) - 1
        local c3 = b64chars:find(data:sub(i + 2, i + 2)) - 1
        local c4 = b64chars:find(data:sub(i + 3, i + 3)) - 1

        if not (c1 and c2 and c3 and c4) then
            return nil, "Invalid base64 data"
        end

        local n = c1 * 262144 + c2 * 4096 + c3 * 64 + c4

        result[#result + 1] = string.char(math.floor(n / 65536) % 256)
        result[#result + 1] = string.char(math.floor(n / 256) % 256)
        result[#result + 1] = string.char(n % 256)
    end

    local decoded = table.concat(result)
    -- Remove padding bytes
    if #padding > 0 then
        decoded = decoded:sub(1, #decoded - #padding)
    end

    return decoded
end

-- ============================================================================
-- Pack Serialization for Import/Export
-- ============================================================================

local EXPORT_VERSION = 1
local EXPORT_PREFIX = "STABLEMASTER"

-- Serialize a Lua value to a string (simple serializer for our use case)
local function SerializeValue(val, depth)
    depth = depth or 0
    if depth > 10 then return "nil" end -- Prevent infinite recursion

    local t = type(val)
    if t == "nil" then
        return "nil"
    elseif t == "boolean" then
        return val and "true" or "false"
    elseif t == "number" then
        return tostring(val)
    elseif t == "string" then
        -- Escape special characters
        return string.format("%q", val)
    elseif t == "table" then
        local parts = {}
        -- Handle array part
        local arrayLen = #val
        for i = 1, arrayLen do
            parts[#parts + 1] = SerializeValue(val[i], depth + 1)
        end
        -- Handle hash part
        for k, v in pairs(val) do
            if type(k) == "number" and k >= 1 and k <= arrayLen and math.floor(k) == k then
                -- Skip, already handled in array part
            else
                local keyStr
                if type(k) == "string" then
                    if k:match("^[%a_][%w_]*$") then
                        keyStr = k
                    else
                        keyStr = "[" .. string.format("%q", k) .. "]"
                    end
                else
                    keyStr = "[" .. SerializeValue(k, depth + 1) .. "]"
                end
                parts[#parts + 1] = keyStr .. "=" .. SerializeValue(v, depth + 1)
            end
        end
        return "{" .. table.concat(parts, ",") .. "}"
    else
        return "nil" -- Unsupported type
    end
end

-- Deserialize a string back to a Lua value
local function DeserializeValue(str)
    -- Safety check - only allow specific patterns
    if not str or str == "" then
        return nil, "Empty data"
    end

    -- Create a restricted environment for loading
    local func, err = loadstring("return " .. str)
    if not func then
        return nil, "Invalid data format: " .. (err or "unknown error")
    end

    -- Run in empty environment for safety
    setfenv(func, {})

    local success, result = pcall(func)
    if not success then
        return nil, "Failed to parse data: " .. tostring(result)
    end

    return result
end

-- Export a pack to a string
function Stablemaster.ExportPack(packName)
    local pack = Stablemaster.GetPackByName(packName)
    if not pack then
        return nil, "Pack '" .. packName .. "' not found"
    end

    -- Filter out transmog/outfit rules (they don't transfer between characters)
    local conditions = {}
    for _, rule in ipairs(pack.conditions or {}) do
        if rule.type ~= "outfit" and rule.type ~= "transmog" and rule.type ~= "custom_transmog" then
            table.insert(conditions, rule)
        end
    end

    local exportData = {
        name = pack.name,
        description = pack.description or "",
        mounts = pack.mounts or {},
        conditions = conditions,
    }

    -- Serialize and encode
    local serialized = SerializeValue(exportData)
    local encoded = Base64Encode(serialized)

    -- Build export string with prefix and version
    local exportString = EXPORT_PREFIX .. ":" .. EXPORT_VERSION .. ":" .. encoded

    return exportString
end

-- Import a pack from a string
function Stablemaster.ImportPack(importString, isShared)
    if not importString or importString == "" then
        return nil, "Import string is empty"
    end

    -- Trim whitespace
    importString = Stablemaster.Trim(importString)

    -- Parse the import string
    local prefix, version, data = importString:match("^([^:]+):(%d+):(.+)$")

    if not prefix or prefix ~= EXPORT_PREFIX then
        return nil, "Invalid import string (missing or wrong prefix)"
    end

    version = tonumber(version)
    if not version or version > EXPORT_VERSION then
        return nil, "Unsupported export version (v" .. tostring(version) .. ")"
    end

    -- Decode base64
    local decoded, decodeErr = Base64Decode(data)
    if not decoded then
        return nil, "Failed to decode: " .. (decodeErr or "unknown error")
    end

    -- Deserialize
    local packData, deserializeErr = DeserializeValue(decoded)
    if not packData then
        return nil, "Failed to parse: " .. (deserializeErr or "unknown error")
    end

    -- Validate required fields
    if type(packData) ~= "table" then
        return nil, "Invalid pack data format"
    end

    if not packData.name or packData.name == "" then
        return nil, "Pack data missing name"
    end

    -- Check for duplicate name
    local existingPack = Stablemaster.GetPackByName(packData.name)
    local finalName = packData.name
    if existingPack then
        -- Generate unique name
        local counter = 2
        while Stablemaster.GetPackByName(finalName .. " (" .. counter .. ")") do
            counter = counter + 1
        end
        finalName = finalName .. " (" .. counter .. ")"
    end

    -- Create the new pack
    local newPack = {
        name = finalName,
        description = packData.description or "",
        mounts = packData.mounts or {},
        conditions = packData.conditions or {},
        isShared = isShared,
        isFallback = false,
    }

    -- Validate mounts exist (optional - just filter out invalid ones)
    local validMounts = {}
    for _, mountID in ipairs(newPack.mounts) do
        if type(mountID) == "number" then
            local name = C_MountJournal.GetMountInfoByID(mountID)
            if name then
                table.insert(validMounts, mountID)
            end
        end
    end
    newPack.mounts = validMounts

    -- Add to appropriate pack list
    if isShared then
        table.insert(StablemasterDB.sharedPacks, newPack)
    else
        local charPacks = Stablemaster.GetCharacterPacks()
        table.insert(charPacks, newPack)
        Stablemaster.SetCharacterPacks(charPacks)
    end

    local renamedMsg = ""
    if finalName ~= packData.name then
        renamedMsg = " (renamed from '" .. packData.name .. "')"
    end

    return newPack, "Successfully imported pack '" .. finalName .. "'" .. renamedMsg
end

Stablemaster.Debug("Utils.lua loaded")