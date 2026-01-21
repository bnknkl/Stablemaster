Stablemaster.Debug("Core.lua loading...")

Stablemaster.runtime = Stablemaster.runtime or {
    activePackName = nil,
    selectedPacks = {},
}

-- Version - update this when you change the .toc version
Stablemaster.version = "1.0.0"

function Stablemaster.CreatePack(name, description)
    if not name or name == "" then
        return false, "Pack name cannot be empty"
    end

    Stablemaster.Debug("CreatePack called with name: " .. name)

    local existingPack = Stablemaster.GetPackByName(name)
    if existingPack then
        local location = existingPack.isShared and "shared" or "character-specific"
        return false, "Pack '" .. name .. "' already exists (" .. location .. ")"
    end
    
    -- TODO: should probably validate the description length too

    local newPack = {
        name = name,
        description = description or "",
        mounts = {},
        conditions = {},
        created = time(),
        isShared = false, -- New packs default to character-specific
        isFallback = false, -- New packs default to not being fallback
    }

    -- Add to character-specific storage by default
    local charPacks = Stablemaster.GetCharacterPacks()
    table.insert(charPacks, newPack)
    Stablemaster.SetCharacterPacks(charPacks)
    Stablemaster.VerbosePrint("Character pack added. Total character packs: " .. #charPacks)
    return true, "Pack '" .. name .. "' created successfully"
end

function Stablemaster.DeletePack(name)
    -- First try character-specific packs
    local charPacks = Stablemaster.GetCharacterPacks()
    for i, pack in ipairs(charPacks) do
        if pack.name == name then
            table.remove(charPacks, i)
            Stablemaster.SetCharacterPacks(charPacks)
            Stablemaster.Debug("Deleted character-specific pack: " .. name)
            return true, "Pack '" .. name .. "' deleted"
        end
    end
    
    -- Then try shared packs
    if StablemasterDB.sharedPacks then
        for i, pack in ipairs(StablemasterDB.sharedPacks) do
            if pack.name == name then
                table.remove(StablemasterDB.sharedPacks, i)
                Stablemaster.Debug("Deleted shared pack: " .. name)
                return true, "Shared pack '" .. name .. "' deleted"
            end
        end
    end
    
    return false, "Pack '" .. name .. "' not found"
end

function Stablemaster.DuplicatePack(sourceName, newName, newDescription)
    if not sourceName or sourceName == "" then
        return false, "Source pack name cannot be empty"
    end
    
    if not newName or newName == "" then
        return false, "New pack name cannot be empty"
    end
    
    Stablemaster.Debug("DuplicatePack called - source: " .. sourceName .. ", new: " .. newName)
    
    -- Check if new name already exists
    local existingPack = Stablemaster.GetPackByName(newName)
    if existingPack then
        local location = existingPack.isShared and "shared" or "character-specific"
        return false, "Pack '" .. newName .. "' already exists (" .. location .. ")"
    end
    
    -- Find source pack to duplicate
    local sourcePack = Stablemaster.GetPackByName(sourceName)
    if not sourcePack then
        return false, "Source pack '" .. sourceName .. "' not found"
    end
    
    -- Create deep copy of the source pack
    local duplicatedPack = {
        name = newName,
        description = newDescription or (sourcePack.description .. " (Copy)"),
        mounts = {},
        conditions = {},
        created = time(),
        isShared = false, -- New duplicated packs default to character-specific
        isFallback = false, -- New duplicated packs cannot be fallback (only one fallback allowed)
    }
    
    -- Deep copy mounts
    if sourcePack.mounts then
        for _, mountID in ipairs(sourcePack.mounts) do
            table.insert(duplicatedPack.mounts, mountID)
        end
    end
    
    -- Deep copy conditions
    if sourcePack.conditions then
        for _, condition in ipairs(sourcePack.conditions) do
            local newCondition = {}
            for key, value in pairs(condition) do
                if type(value) == "table" then
                    -- Deep copy nested tables (like transmog data)
                    newCondition[key] = {}
                    for k, v in pairs(value) do
                        newCondition[key][k] = v
                    end
                else
                    newCondition[key] = value
                end
            end
            table.insert(duplicatedPack.conditions, newCondition)
        end
    end
    
    -- Add duplicated pack to character-specific storage by default
    local charPacks = Stablemaster.GetCharacterPacks()
    table.insert(charPacks, duplicatedPack)
    Stablemaster.SetCharacterPacks(charPacks)

    Stablemaster.VerbosePrint("Pack '" .. sourceName .. "' duplicated as '" .. newName .. "' (" .. #duplicatedPack.mounts .. " mounts, " .. #duplicatedPack.conditions .. " conditions)")
    return true, "Pack '" .. sourceName .. "' duplicated as '" .. newName .. "'"
end

function Stablemaster.GetPack(name)
    return Stablemaster.GetPackByName(name)
end

function Stablemaster.ListPacks()
    return Stablemaster.GetAllAvailablePacks()
end

-- Toggle fallback status for a pack
function Stablemaster.TogglePackFallback(packName)
    local pack = Stablemaster.GetPackByName(packName)
    if not pack then
        return false, "Pack '" .. packName .. "' not found"
    end
    
    local allPacks = Stablemaster.GetAllAvailablePacks()
    
    if pack.isFallback then
        -- Remove fallback status
        pack.isFallback = false
        return true, "Pack '" .. packName .. "' is no longer the fallback pack"
    else
        -- Clear fallback from any other pack first (only one fallback allowed)
        for _, otherPack in ipairs(allPacks) do
            if otherPack.isFallback and otherPack.name ~= packName then
                otherPack.isFallback = false
                Stablemaster.Debug("Removed fallback status from pack: " .. otherPack.name)
            end
        end
        
        -- Set this pack as fallback
        pack.isFallback = true
        return true, "Pack '" .. packName .. "' is now the fallback pack"
    end
end

-- Get the current fallback pack
function Stablemaster.GetFallbackPack()
    local allPacks = Stablemaster.GetAllAvailablePacks()
    for _, pack in ipairs(allPacks) do
        if pack.isFallback then
            return pack
        end
    end
    return nil
end

function Stablemaster.AddMountToPack(packName, mountID)
    local pack = Stablemaster.GetPack(packName)
    if not pack then
        return false, "Pack '" .. packName .. "' not found"
    end

    local name, spellID, icon, active, isUsable, sourceType, isFavorite, isFactionSpecific, faction, shouldHideOnChar, isCollected =
        C_MountJournal.GetMountInfoByID(mountID)
    if not name then
        return false, "Mount ID " .. mountID .. " not found"
    end
    if not isCollected then
        return false, "You don't own the mount: " .. name
    end

    -- check if already exists
    for _, existingMountID in ipairs(pack.mounts) do  -- inconsistent variable naming
        if existingMountID == mountID then
            return false, "Mount '" .. name .. "' is already in pack '" .. packName .. "'"
        end
    end

    table.insert(pack.mounts, mountID)
    Stablemaster.VerbosePrint("Added mount " .. name .. " to pack " .. packName)
    return true, "Added '" .. name .. "' to pack '" .. packName .. "'"
    -- TODO: should we sort the mounts somehow? alphabetical maybe?
end

function Stablemaster.RemoveMountFromPack(packName, mountID)
    local pack = Stablemaster.GetPack(packName)
    if not pack then
        return false, "Pack '" .. packName .. "' not found"
    end

    for i, existingID in ipairs(pack.mounts) do
        if existingID == mountID then
            table.remove(pack.mounts, i)
            local name = C_MountJournal.GetMountInfoByID(mountID)
            Stablemaster.VerbosePrint("Removed mount " .. (name or "Unknown") .. " from pack " .. packName)
            return true, "Removed mount from pack '" .. packName .. "'"
        end
    end

    return false, "Mount not found in pack '" .. packName .. "'"
end

function Stablemaster.GetOwnedMounts()
    local ownedMounts = {}
    local allMountIDs = C_MountJournal.GetMountIDs()

    for _, mountID in ipairs(allMountIDs) do
        local name, spellID, icon, active, isUsable, sourceType, isFavorite, isFactionSpecific, faction, shouldHideOnChar, isCollected =
            C_MountJournal.GetMountInfoByID(mountID)
        if isCollected and name then
            table.insert(ownedMounts, {
                id = mountID,
                name = name,
                icon = icon,
                isUsable = isUsable,
            })
        end
    end

    table.sort(ownedMounts, function(a, b) return a.name < b.name end)
    return ownedMounts
end

-- Get current best map for player
local function GetPlayerMapID()
    return C_Map.GetBestMapForUnit("player")
end

-- Database initialization in Utils.lua should be updated, but we'll handle the setting here
-- Ensure the setting exists
local function EnsureFlyingPreferenceSetting()
    StablemasterDB.settings = StablemasterDB.settings or {}
    if StablemasterDB.settings.preferFlyingMounts == nil then
        StablemasterDB.settings.preferFlyingMounts = true -- Default to enabled
    end
end

-- Check if player can fly in current zone
local function CanFlyInCurrentZone()
    return IsFlyableArea()
end

-- Check if a mount is a flying mount using the proper API
local function IsFlyingMount(mountID)
    -- Use the GetMountInfoExtraByID API to get the actual mount type
    local creatureDisplayInfoID, description, source, isSelfMount, mountTypeID, uiModelSceneID, animID, spellVisualKitID, disablePlayerMountPreview = C_MountJournal.GetMountInfoExtraByID(mountID)
    
    if not mountTypeID then
        -- Fallback to name-based detection if API fails
        local name = C_MountJournal.GetMountInfoByID(mountID)
        if name and StablemasterDB.settings.debugMode then
            Stablemaster.Debug("No mountTypeID for " .. name .. ", using name fallback")
        end
        return IsFlyingMountByName(mountID)
    end
    
    -- Debug: Log the actual mount type ID
    if StablemasterDB.settings.debugMode then
        local name = C_MountJournal.GetMountInfoByID(mountID)
        Stablemaster.Debug("Mount " .. (name or "Unknown") .. " has mountTypeID: " .. tostring(mountTypeID))
    end
    
    -- Mount type IDs for flying mounts (discovered through testing)
    local flyingTypeIDs = {
        247, 248, 424, -- Initial guesses
        402, -- Algarian Stormrider
        -- We'll add more as we discover them from debug output
    }
    
    for _, flyingType in ipairs(flyingTypeIDs) do
        if mountTypeID == flyingType then
            return true
        end
    end
    
    return false
end

-- Fallback name-based detection (simplified version of our previous method)
local function IsFlyingMountByName(mountID)
    local name = C_MountJournal.GetMountInfoByID(mountID)
    if not name then
        return false
    end
    
    local lowerName = string.lower(name)
    
    -- Most reliable patterns only
    local flyingPatterns = {
        "dragon", "drake", "wyrm", "proto%-drake",
        "gryphon", "griffin", "hippogryph", 
        "phoenix", "wind rider", "windrider",
        "flying", "flight", "carpet", "disc",
        "azure", "bronze", "twilight", "netherwing"
    }
    
    for _, pattern in ipairs(flyingPatterns) do
        if string.find(lowerName, pattern) then
            if StablemasterDB.settings.debugMode then
                Stablemaster.Debug("Mount " .. name .. " detected as flying by name pattern: " .. pattern)
            end
            return true
        end
    end
    
    return false
end

-- ============================================================
-- OUTFIT SYSTEM (Midnight 12.0+)
-- Uses C_TransmogOutfitInfo API
-- ============================================================

-- Get the currently active outfit ID
function Stablemaster.GetCurrentOutfitID()
    if C_TransmogOutfitInfo and C_TransmogOutfitInfo.GetActiveOutfitID then
        local outfitID = C_TransmogOutfitInfo.GetActiveOutfitID()
        -- ID of 0 means no outfit is active (just wearing gear)
        if outfitID and outfitID > 0 then
            Stablemaster.Debug("Active outfit ID: " .. outfitID)
            return outfitID
        end
    end
    return nil
end

-- Get info about a specific outfit by ID
function Stablemaster.GetOutfitInfo(outfitID)
    if not outfitID then return nil end
    if C_TransmogOutfitInfo and C_TransmogOutfitInfo.GetOutfitInfo then
        local outfitInfo = C_TransmogOutfitInfo.GetOutfitInfo(outfitID)
        if outfitInfo then
            return {
                outfitID = outfitID,
                name = outfitInfo.name,
                icon = outfitInfo.icon
            }
        end
    end
    return nil
end

-- Get all available outfits for the current character
function Stablemaster.GetAllOutfits()
    local results = {}
    if C_TransmogOutfitInfo and C_TransmogOutfitInfo.GetOutfitsInfo then
        local outfits = C_TransmogOutfitInfo.GetOutfitsInfo()
        if outfits then
            Stablemaster.Debug("GetOutfitsInfo returned " .. #outfits .. " outfits")
            for _, outfit in ipairs(outfits) do
                table.insert(results, {
                    outfitID = outfit.outfitID,
                    name = outfit.name,
                    icon = outfit.icon
                })
            end
        end
    else
        Stablemaster.Debug("C_TransmogOutfitInfo.GetOutfitsInfo not available")
    end
    return results
end

-- ============================================================
-- TIME OF DAY SYSTEM
-- Uses in-game server time via GetGameTime()
-- ============================================================

-- Get current server hour (0-23)
function Stablemaster.GetCurrentHour()
    local hour, minute = GetGameTime()
    return hour
end

-- Check if current time is within a range (handles overnight ranges like 22-6)
function Stablemaster.IsTimeInRange(startHour, endHour)
    local currentHour = Stablemaster.GetCurrentHour()

    if startHour <= endHour then
        -- Normal range (e.g., 6-18 for daytime)
        return currentHour >= startHour and currentHour < endHour
    else
        -- Overnight range (e.g., 18-6 for nighttime)
        return currentHour >= startHour or currentHour < endHour
    end
end

-- Predefined time ranges for easy selection
Stablemaster.TimeRanges = {
    { name = "Dawn", startHour = 5, endHour = 8 },
    { name = "Morning", startHour = 8, endHour = 12 },
    { name = "Afternoon", startHour = 12, endHour = 17 },
    { name = "Evening", startHour = 17, endHour = 21 },
    { name = "Night", startHour = 21, endHour = 5 },
    { name = "Daytime", startHour = 6, endHour = 18 },
    { name = "Nighttime", startHour = 18, endHour = 6 },
}

-- ============================================================
-- SEASON SYSTEM
-- Uses real-world date to determine current season
-- ============================================================

-- Season definitions (by month)
Stablemaster.Seasons = {
    { name = "Winter", months = {12, 1, 2} },
    { name = "Spring", months = {3, 4, 5} },
    { name = "Summer", months = {6, 7, 8} },
    { name = "Fall", months = {9, 10, 11} },
}

-- Get current real-world month (1-12)
function Stablemaster.GetCurrentMonth()
    local currentTime = C_DateAndTime.GetCurrentCalendarTime()
    if currentTime then
        return currentTime.month
    end
    -- Fallback to lua date
    return tonumber(date("%m"))
end

-- Get current season name
function Stablemaster.GetCurrentSeason()
    local month = Stablemaster.GetCurrentMonth()
    for _, season in ipairs(Stablemaster.Seasons) do
        for _, m in ipairs(season.months) do
            if m == month then
                return season.name
            end
        end
    end
    return nil
end

-- Check if a season is currently active
function Stablemaster.IsSeasonActive(seasonName)
    return Stablemaster.GetCurrentSeason() == seasonName
end

-- ============================================================
-- HOLIDAY SYSTEM
-- Uses C_Calendar API to detect active holidays
-- ============================================================

-- Known WoW holidays with their texture IDs for identification
Stablemaster.KnownHolidays = {
    { name = "Lunar Festival", textureID = 235469 },
    { name = "Love is in the Air", textureID = 235468 },
    { name = "Noblegarden", textureID = 235471 },
    { name = "Children's Week", textureID = 235465 },
    { name = "Midsummer Fire Festival", textureID = 235470 },
    { name = "Brewfest", textureID = 235440 },
    { name = "Hallow's End", textureID = 235460 },
    { name = "Pilgrim's Bounty", textureID = 250719 },
    { name = "Winter Veil", textureID = 235482 },
    { name = "Pirates' Day", textureID = 235472 },
    { name = "Day of the Dead", textureID = 235461 },
    { name = "Darkmoon Faire", textureID = 235448 },
}

-- Get currently active holidays
function Stablemaster.GetActiveHolidays()
    local activeHolidays = {}

    -- Get current date
    local currentCalendarTime = C_DateAndTime.GetCurrentCalendarTime()
    if not currentCalendarTime then return activeHolidays end

    local month = currentCalendarTime.month
    local day = currentCalendarTime.monthDay
    local year = currentCalendarTime.year

    -- Set the calendar to current month to read events
    C_Calendar.SetAbsMonth(month, year)

    -- Get number of events for today
    local numEvents = C_Calendar.GetNumDayEvents(0, day)

    for i = 1, numEvents do
        local event = C_Calendar.GetDayEvent(0, day, i)
        if event then
            -- Check if this is a holiday event (ongoing/active)
            local isActive = false

            -- Event types: 0 = Raid, 1 = Dungeon, 2 = PvP, etc.
            -- Holiday events are typically type 0 but have specific textures
            if event.iconTexture then
                -- Check against known holiday textures
                for _, holiday in ipairs(Stablemaster.KnownHolidays) do
                    if event.iconTexture == holiday.textureID then
                        table.insert(activeHolidays, {
                            name = holiday.name,
                            textureID = holiday.textureID,
                            eventTitle = event.title
                        })
                        isActive = true
                        break
                    end
                end

                -- If not in our known list but looks like a holiday, add it by title
                if not isActive and event.title then
                    -- Check if title matches any known holiday name
                    for _, holiday in ipairs(Stablemaster.KnownHolidays) do
                        if event.title:find(holiday.name) then
                            table.insert(activeHolidays, {
                                name = holiday.name,
                                textureID = event.iconTexture,
                                eventTitle = event.title
                            })
                            break
                        end
                    end
                end
            end
        end
    end

    Stablemaster.Debug("GetActiveHolidays found " .. #activeHolidays .. " active holidays")
    return activeHolidays
end

-- Check if a specific holiday is currently active
function Stablemaster.IsHolidayActive(holidayName)
    local activeHolidays = Stablemaster.GetActiveHolidays()
    for _, holiday in ipairs(activeHolidays) do
        if holiday.name == holidayName then
            return true
        end
    end
    return false
end

-- Enhanced rule matching with priority support
local function DoesRuleMatch(rule)
    if not rule or not rule.type then 
        return false, 0 
    end
    
    local priority = rule.priority or StablemasterDB.settings.rulePriorities[rule.type] or 0
    
    if rule.type == "zone" then
        if not rule.mapID then return false, 0 end
        
        -- Try multiple methods to get current map ID
        local currentMapID = GetPlayerMapID()
        
        -- Fallback methods if GetPlayerMapID() fails
        if not currentMapID then
            -- Try getting from best map for unit
            local mapID = C_Map.GetBestMapForUnit("player")
            if mapID then
                currentMapID = mapID
            end
        end
        
        if not currentMapID then
            -- Last resort: try getting from current zone text
            local zoneText = GetZoneText()
            if zoneText and zoneText ~= "" then
                -- Store unknown zones and retry later
                Stablemaster.Debug("Zone detection failed after teleport, zone text: " .. zoneText)
                C_Timer.After(2, function()
                    Stablemaster.Debug("Retrying pack evaluation after zone detection delay")
                    Stablemaster.SelectActivePack()
                end)
            end
            return false, 0
        end

        if currentMapID == rule.mapID then
            return true, priority + 50 -- Exact match bonus
        end

        if rule.includeParents then
            local info = C_Map.GetMapInfo(currentMapID)
            while info and info.parentMapID and info.parentMapID > 0 do
                if info.parentMapID == rule.mapID then
                    return true, priority -- Parent match, base priority
                end
                info = C_Map.GetMapInfo(info.parentMapID)
            end
        end
        
        return false, 0
        
    elseif rule.type == "transmog" then
        -- DEPRECATED in 12.0+ - Use outfit rules instead
        -- Old transmog rules are preserved in data but no longer match
        Stablemaster.Debug("Legacy transmog rule encountered (setID: " .. tostring(rule.setID) .. ") - use outfit rules instead")
        return false, 0

    elseif rule.type == "custom_transmog" then
        -- DEPRECATED in 12.0+ - Use outfit rules instead
        -- Old custom transmog rules are preserved in data but no longer match
        Stablemaster.Debug("Legacy custom_transmog rule encountered - use outfit rules instead")
        return false, 0

    elseif rule.type == "outfit" then
        -- Outfit matching (Midnight 12.0+) - supports both single and multi-outfit formats
        local currentOutfitID = Stablemaster.GetCurrentOutfitID()
        if not currentOutfitID then return false, 0 end

        -- New multi-outfit format
        if rule.outfitIDs and #rule.outfitIDs > 0 then
            for i, outfitID in ipairs(rule.outfitIDs) do
                if currentOutfitID == outfitID then
                    local outfitName = (rule.outfitNames and rule.outfitNames[i]) or ("Outfit #" .. outfitID)
                    Stablemaster.Debug("Outfit rule matched: outfit " .. outfitID .. " (name: " .. outfitName .. ")")
                    return true, priority
                end
            end
            return false, 0
        end

        -- Legacy single-outfit format (backward compatibility)
        if rule.outfitID then
            if currentOutfitID == rule.outfitID then
                Stablemaster.Debug("Outfit rule matched: outfit " .. rule.outfitID .. " (name: " .. (rule.outfitName or "unknown") .. ")")
                return true, priority
            end
        end

        return false, 0

    elseif rule.type == "class" then
        -- Use fallback priority if not in settings (for older databases)
        if not priority or priority == 0 then
            priority = 75
        end

        if not rule.classIDs or #rule.classIDs == 0 then
            Stablemaster.Debug("Class rule has no classIDs")
            return false, 0
        end

        local _, _, playerClassID = UnitClass("player")
        Stablemaster.Debug("Player classID: " .. tostring(playerClassID) .. ", rule classIDs: " .. table.concat(rule.classIDs, ", "))
        if not playerClassID then return false, 0 end

        -- Check if player's class is in the list
        local classMatches = false
        for _, classID in ipairs(rule.classIDs) do
            if classID == playerClassID then
                classMatches = true
                break
            end
        end

        if not classMatches then
            Stablemaster.Debug("Class rule: player class " .. playerClassID .. " not in rule classes")
            return false, 0
        end

        -- If specIDs are specified, check if current spec matches
        if rule.specIDs and #rule.specIDs > 0 then
            local currentSpecIndex = GetSpecialization()
            if not currentSpecIndex then return false, 0 end

            local currentSpecID = GetSpecializationInfo(currentSpecIndex)
            if not currentSpecID then return false, 0 end

            Stablemaster.Debug("Player specID: " .. tostring(currentSpecID) .. ", rule specIDs: " .. table.concat(rule.specIDs, ", "))

            for _, specID in ipairs(rule.specIDs) do
                if specID == currentSpecID then
                    Stablemaster.Debug("Class rule matched with spec!")
                    return true, priority + 25 -- Spec match bonus
                end
            end
            Stablemaster.Debug("Class rule: class matched but spec didn't")
            return false, 0 -- Class matched but spec didn't
        end

        -- Class matched, no spec restriction
        Stablemaster.Debug("Class rule matched (any spec)!")
        return true, priority

    elseif rule.type == "race" then
        -- Use fallback priority if not in settings (for older databases)
        if not priority or priority == 0 then
            priority = 60
        end

        if not rule.raceIDs or #rule.raceIDs == 0 then
            Stablemaster.Debug("Race rule has no raceIDs")
            return false, 0
        end

        local _, _, playerRaceID = UnitRace("player")
        Stablemaster.Debug("Player raceID: " .. tostring(playerRaceID) .. ", rule raceIDs: " .. table.concat(rule.raceIDs, ", "))
        if not playerRaceID then return false, 0 end

        for _, raceID in ipairs(rule.raceIDs) do
            if raceID == playerRaceID then
                Stablemaster.Debug("Race rule matched!")
                return true, priority
            end
        end
        Stablemaster.Debug("Race rule: player race " .. playerRaceID .. " not in rule races")
        return false, 0

    elseif rule.type == "time" then
        -- Time of day matching
        if not priority or priority == 0 then
            priority = 40
        end

        local currentHour = Stablemaster.GetCurrentHour()

        -- New multi-select format with timeNames array
        if rule.timeNames and #rule.timeNames > 0 then
            for _, timeName in ipairs(rule.timeNames) do
                -- Look up the time range for this preset
                for _, preset in ipairs(Stablemaster.TimeRanges) do
                    if preset.name == timeName then
                        local isInRange = Stablemaster.IsTimeInRange(preset.startHour, preset.endHour)
                        Stablemaster.Debug("Time rule: current hour " .. currentHour .. ", checking " .. timeName .. " (" .. preset.startHour .. "-" .. preset.endHour .. "), match: " .. tostring(isInRange))
                        if isInRange then
                            return true, priority
                        end
                        break
                    end
                end
            end
            return false, 0
        end

        -- Legacy single time range format
        if not rule.startHour or not rule.endHour then
            Stablemaster.Debug("Time rule missing startHour or endHour")
            return false, 0
        end

        local isInRange = Stablemaster.IsTimeInRange(rule.startHour, rule.endHour)

        Stablemaster.Debug("Time rule: current hour " .. currentHour .. ", range " .. rule.startHour .. "-" .. rule.endHour .. ", match: " .. tostring(isInRange))

        if isInRange then
            return true, priority
        end
        return false, 0

    elseif rule.type == "holiday" then
        -- Holiday matching
        if not priority or priority == 0 then
            priority = 80
        end

        if not rule.holidayNames or #rule.holidayNames == 0 then
            Stablemaster.Debug("Holiday rule has no holidayNames")
            return false, 0
        end

        local activeHolidays = Stablemaster.GetActiveHolidays()
        for _, holidayName in ipairs(rule.holidayNames) do
            for _, activeHoliday in ipairs(activeHolidays) do
                if activeHoliday.name == holidayName then
                    Stablemaster.Debug("Holiday rule matched: " .. holidayName)
                    return true, priority
                end
            end
        end
        Stablemaster.Debug("Holiday rule: no matching active holidays")
        return false, 0

    elseif rule.type == "season" then
        -- Season matching
        if not priority or priority == 0 then
            priority = 35
        end

        if not rule.seasonNames or #rule.seasonNames == 0 then
            Stablemaster.Debug("Season rule has no seasonNames")
            return false, 0
        end

        local currentSeason = Stablemaster.GetCurrentSeason()
        for _, seasonName in ipairs(rule.seasonNames) do
            if seasonName == currentSeason then
                Stablemaster.Debug("Season rule matched: " .. seasonName)
                return true, priority
            end
        end
        Stablemaster.Debug("Season rule: current season " .. tostring(currentSeason) .. " not in rule")
        return false, 0
    end

    return false, 0
end

-- Score a pack against current context with detailed breakdown
local function ScorePackAgainstContext(pack)
    if not pack or not pack.conditions or #pack.conditions == 0 then
        return 0, {}
    end
    
    local totalScore = 0
    local matchedRules = {}
    
    -- Group rules by type for proper logic handling
    local zoneRules = {}
    local outfitRules = {}
    local transmogRules = {}
    local customTransmogRules = {}
    local classRules = {}
    local raceRules = {}
    local timeRules = {}
    local holidayRules = {}
    local seasonRules = {}

    for i, rule in ipairs(pack.conditions) do
        Stablemaster.Debug("Pack '" .. pack.name .. "' rule " .. i .. ": type=" .. tostring(rule.type))
        if rule.type == "zone" then
            table.insert(zoneRules, {rule = rule, index = i})
        elseif rule.type == "outfit" then
            table.insert(outfitRules, {rule = rule, index = i})
        elseif rule.type == "transmog" then
            table.insert(transmogRules, {rule = rule, index = i})
        elseif rule.type == "custom_transmog" then
            table.insert(customTransmogRules, {rule = rule, index = i})
        elseif rule.type == "class" then
            table.insert(classRules, {rule = rule, index = i})
        elseif rule.type == "race" then
            table.insert(raceRules, {rule = rule, index = i})
        elseif rule.type == "time" then
            table.insert(timeRules, {rule = rule, index = i})
        elseif rule.type == "holiday" then
            table.insert(holidayRules, {rule = rule, index = i})
        elseif rule.type == "season" then
            table.insert(seasonRules, {rule = rule, index = i})
        else
            Stablemaster.Debug("Unknown rule type: " .. tostring(rule.type))
        end
    end

    Stablemaster.Debug("Pack '" .. pack.name .. "' has " .. #classRules .. " class rules, " .. #raceRules .. " race rules")
    
    -- Zone rules: OR logic (any zone match qualifies)
    local zoneMatched = false
    if #zoneRules > 0 then
        for _, ruleData in ipairs(zoneRules) do
            local matched, score = DoesRuleMatch(ruleData.rule)
            if matched then
                zoneMatched = true
                totalScore = totalScore + score
                table.insert(matchedRules, {
                    type = ruleData.rule.type,
                    score = score,
                    index = ruleData.index
                })
                -- Continue checking other zones for potential higher scores
            end
        end
        
        -- If we have zone rules but none matched, pack doesn't qualify
        if not zoneMatched then
            return 0, {}
        end
    end
    
    -- Transmog rules: AND logic (all must match)
    if #transmogRules > 0 then
        for _, ruleData in ipairs(transmogRules) do
            local matched, score = DoesRuleMatch(ruleData.rule)
            if matched then
                totalScore = totalScore + score
                table.insert(matchedRules, {
                    type = ruleData.rule.type,
                    score = score,
                    index = ruleData.index
                })
            else
                -- If any transmog rule doesn't match, pack doesn't qualify
                return 0, {}
            end
        end
    end
    
    -- Custom transmog rules: AND logic (all must match) - DEPRECATED in 12.0+
    if #customTransmogRules > 0 then
        for _, ruleData in ipairs(customTransmogRules) do
            local matched, score = DoesRuleMatch(ruleData.rule)
            if matched then
                totalScore = totalScore + score
                table.insert(matchedRules, {
                    type = ruleData.rule.type,
                    score = score,
                    index = ruleData.index
                })
            else
                -- If any custom transmog rule doesn't match, pack doesn't qualify
                return 0, {}
            end
        end
    end

    -- Outfit rules: OR logic (any outfit match qualifies) - New in 12.0+
    local outfitMatched = false
    if #outfitRules > 0 then
        for _, ruleData in ipairs(outfitRules) do
            local matched, score = DoesRuleMatch(ruleData.rule)
            if matched then
                outfitMatched = true
                totalScore = totalScore + score
                table.insert(matchedRules, {
                    type = ruleData.rule.type,
                    score = score,
                    index = ruleData.index
                })
            end
        end

        -- If we have outfit rules but none matched, pack doesn't qualify
        if not outfitMatched then
            return 0, {}
        end
    end

    -- Class rules: OR logic (any class/spec rule match qualifies)
    local classMatched = false
    if #classRules > 0 then
        for _, ruleData in ipairs(classRules) do
            local matched, score = DoesRuleMatch(ruleData.rule)
            if matched then
                classMatched = true
                totalScore = totalScore + score
                table.insert(matchedRules, {
                    type = ruleData.rule.type,
                    score = score,
                    index = ruleData.index
                })
            end
        end

        -- If we have class rules but none matched, pack doesn't qualify
        if not classMatched then
            return 0, {}
        end
    end

    -- Race rules: OR logic (any race rule match qualifies)
    local raceMatched = false
    if #raceRules > 0 then
        for _, ruleData in ipairs(raceRules) do
            local matched, score = DoesRuleMatch(ruleData.rule)
            if matched then
                raceMatched = true
                totalScore = totalScore + score
                table.insert(matchedRules, {
                    type = ruleData.rule.type,
                    score = score,
                    index = ruleData.index
                })
            end
        end

        -- If we have race rules but none matched, pack doesn't qualify
        if not raceMatched then
            Stablemaster.Debug("Pack '" .. pack.name .. "': race rules exist but none matched, returning 0")
            return 0, {}
        end
    end

    -- Time rules: OR logic (any time rule match qualifies)
    local timeMatched = false
    if #timeRules > 0 then
        for _, ruleData in ipairs(timeRules) do
            local matched, score = DoesRuleMatch(ruleData.rule)
            if matched then
                timeMatched = true
                totalScore = totalScore + score
                table.insert(matchedRules, {
                    type = ruleData.rule.type,
                    score = score,
                    index = ruleData.index
                })
            end
        end

        -- If we have time rules but none matched, pack doesn't qualify
        if not timeMatched then
            Stablemaster.Debug("Pack '" .. pack.name .. "': time rules exist but none matched, returning 0")
            return 0, {}
        end
    end

    -- Holiday rules: OR logic (any holiday rule match qualifies)
    local holidayMatched = false
    if #holidayRules > 0 then
        for _, ruleData in ipairs(holidayRules) do
            local matched, score = DoesRuleMatch(ruleData.rule)
            if matched then
                holidayMatched = true
                totalScore = totalScore + score
                table.insert(matchedRules, {
                    type = ruleData.rule.type,
                    score = score,
                    index = ruleData.index
                })
            end
        end

        -- If we have holiday rules but none matched, pack doesn't qualify
        if not holidayMatched then
            Stablemaster.Debug("Pack '" .. pack.name .. "': holiday rules exist but none matched, returning 0")
            return 0, {}
        end
    end

    -- Season rules: OR logic (any season rule match qualifies)
    local seasonMatched = false
    if #seasonRules > 0 then
        for _, ruleData in ipairs(seasonRules) do
            local matched, score = DoesRuleMatch(ruleData.rule)
            if matched then
                seasonMatched = true
                totalScore = totalScore + score
                table.insert(matchedRules, {
                    type = ruleData.rule.type,
                    score = score,
                    index = ruleData.index
                })
            end
        end

        -- If we have season rules but none matched, pack doesn't qualify
        if not seasonMatched then
            Stablemaster.Debug("Pack '" .. pack.name .. "': season rules exist but none matched, returning 0")
            return 0, {}
        end
    end

    Stablemaster.Debug("Pack '" .. pack.name .. "': final score = " .. totalScore .. ", matched rules = " .. #matchedRules)
    return totalScore, matchedRules
end

-- Get all matching packs with their scores
local function GetMatchingPacks()
    local packs = Stablemaster.ListPacks()
    local matchingPacks = {}

    Stablemaster.Debug("GetMatchingPacks: checking " .. #packs .. " packs")

    for _, pack in ipairs(packs) do
        local score, matchedRules = ScorePackAgainstContext(pack)
        Stablemaster.Debug("GetMatchingPacks: pack '" .. pack.name .. "' scored " .. score)
        if score > 0 then
            table.insert(matchingPacks, {
                pack = pack,
                score = score,
                matchedRules = matchedRules
            })
        end
    end
    
    -- Sort by score (highest first)
    table.sort(matchingPacks, function(a, b) return a.score > b.score end)
    
    return matchingPacks
end

function Stablemaster.SelectActivePack()
    local matchingPacks = GetMatchingPacks()
    
    if #matchingPacks == 0 then
        -- Check for deactivated packs before clearing
        local oldActiveNames = Stablemaster.runtime.activePackNames or {}
        for name in pairs(oldActiveNames) do
            Stablemaster.VerbosePrint("Pack '" .. name .. "' deactivated")
        end
        Stablemaster.runtime.activePackNames = {}

        if Stablemaster.runtime.activePackName ~= nil then
            Stablemaster.runtime.activePackName = nil
            Stablemaster.runtime.selectedPacks = {}
            Stablemaster.Debug("No matching packs - cleared active pack")

            -- Update minimap icon
            if Stablemaster.MinimapIcon then
                Stablemaster.MinimapIcon.UpdateIcon()
            end
        end
        return
    end
    
    local selectedPacks = {}
    local overlapMode = StablemasterDB.settings.packOverlapMode or "union"

    if overlapMode == "intersection" then
        -- Use all matching packs (intersection will happen in mount selection)
        selectedPacks = matchingPacks
    else
        -- Union mode (default) - use all matching packs
        selectedPacks = matchingPacks
    end
    
    -- Build set of new active pack names
    local newActiveNames = {}
    for _, sp in ipairs(selectedPacks) do
        newActiveNames[sp.pack.name] = true
    end

    -- Build set of previous active pack names
    local oldActiveNames = Stablemaster.runtime.activePackNames or {}

    -- Check for deactivated packs (were active, now not)
    for name in pairs(oldActiveNames) do
        if not newActiveNames[name] then
            Stablemaster.VerbosePrint("Pack '" .. name .. "' deactivated")
        end
    end

    -- Check for activated packs (now active, weren't before)
    for name in pairs(newActiveNames) do
        if not oldActiveNames[name] then
            Stablemaster.VerbosePrint("Pack '" .. name .. "' activated")
        end
    end

    -- Store the new active names for next comparison
    Stablemaster.runtime.activePackNames = newActiveNames

    -- Store the selection results
    Stablemaster.runtime.selectedPacks = selectedPacks

    -- For backward compatibility, set activePackName to the primary pack
    local newActiveName = selectedPacks[1] and selectedPacks[1].pack.name or nil

    if newActiveName ~= Stablemaster.runtime.activePackName then
        Stablemaster.runtime.activePackName = newActiveName

        -- Update minimap icon when active pack changes
        if Stablemaster.MinimapIcon then
            Stablemaster.MinimapIcon.UpdateIcon()
        end
    end
end

-- Get a random favorite mount, optionally preferring flying mounts
local function GetRandomFavoriteMount()
    EnsureFlyingPreferenceSetting()
    
    local allFavorites = {}
    local flyingFavorites = {}
    local allMountIDs = C_MountJournal.GetMountIDs()
    
    for _, mountID in ipairs(allMountIDs) do
        local name, spellID, icon, active, isUsable, sourceType, isFavorite, isFactionSpecific, faction, shouldHideOnChar, isCollected =
            C_MountJournal.GetMountInfoByID(mountID)
        if isCollected and isUsable and isFavorite then
            table.insert(allFavorites, mountID)
            
            if IsFlyingMount(mountID) then
                table.insert(flyingFavorites, mountID)
            end
        end
    end
    
    -- If flying preference is enabled and we can fly, prefer flying mounts
    if StablemasterDB.settings.preferFlyingMounts and CanFlyInCurrentZone() and #flyingFavorites > 0 then
        local randomIndex = math.random(1, #flyingFavorites)
        Stablemaster.Debug("Selected flying favorite mount (found " .. #flyingFavorites .. " flying favorites out of " .. #allFavorites .. " total)")
        return flyingFavorites[randomIndex]
    end
    
    -- Fallback to any favorite
    if #allFavorites > 0 then
        local randomIndex = math.random(1, #allFavorites)
        if StablemasterDB.settings.preferFlyingMounts and CanFlyInCurrentZone() then
            Stablemaster.Debug("No flying favorites found, using any favorite (had " .. #flyingFavorites .. " flying out of " .. #allFavorites .. " total)")
        else
            Stablemaster.Debug("Selected any favorite mount (flying preference disabled or can't fly here)")
        end
        return allFavorites[randomIndex]
    end
    
    return nil
end

-- Get a random mount from active pack, optionally preferring flying mounts
local function GetRandomMountFromActivePackWithFlyingPreference()
    local name = Stablemaster.runtime.activePackName
    if not name then 
        Stablemaster.Debug("No active pack name")
        return nil 
    end
    
    local pack = Stablemaster.GetPack(name)
    if not pack then 
        Stablemaster.Debug("Active pack '" .. name .. "' not found")
        return nil 
    end
    
    if not pack.mounts or #pack.mounts == 0 then 
        Stablemaster.Debug("Active pack '" .. name .. "' has no mounts")
        return nil 
    end
    
    EnsureFlyingPreferenceSetting()
    
    -- Get all usable mounts from pack
    local usableMounts = {}
    local flyingMounts = {}
    
    for _, mountID in ipairs(pack.mounts) do
        local name, spellID, icon, active, isUsable = C_MountJournal.GetMountInfoByID(mountID)
        if isUsable then
            table.insert(usableMounts, mountID)
            if IsFlyingMount(mountID) then
                table.insert(flyingMounts, mountID)
            end
        end
    end
    
    if #usableMounts == 0 then
        Stablemaster.Debug("No usable mounts in active pack")
        return nil
    end
    
    -- If flying preference is enabled and we can fly, prefer flying mounts
    if StablemasterDB.settings.preferFlyingMounts and CanFlyInCurrentZone() and #flyingMounts > 0 then
        local idx = math.random(1, #flyingMounts)
        local mountID = flyingMounts[idx]
        Stablemaster.Debug("Selected flying mount ID " .. mountID .. " from active pack '" .. name .. "' (found " .. #flyingMounts .. " flying out of " .. #usableMounts .. " usable)")
        return mountID
    end
    
    -- Fallback to any usable mount from pack
    local idx = math.random(1, #usableMounts)
    local mountID = usableMounts[idx]
    if StablemasterDB.settings.preferFlyingMounts and CanFlyInCurrentZone() then
        Stablemaster.Debug("No flying mounts in pack, selected any mount ID " .. mountID .. " from active pack '" .. name .. "' (had " .. #flyingMounts .. " flying out of " .. #usableMounts .. " usable)")
    else
        Stablemaster.Debug("Selected mount ID " .. mountID .. " from active pack '" .. name .. "' (flying preference disabled or can't fly here)")
    end
    return mountID
end

-- Enhanced mount selection with intersection support
local function GetRandomMountFromSelectedPacks()
    local selectedPacks = Stablemaster.runtime.selectedPacks or {}
    
    if #selectedPacks == 0 then
        return nil
    end
    
    if #selectedPacks == 1 then
        -- Single pack - use existing logic
        return GetRandomMountFromActivePackWithFlyingPreference()
    end
    
    -- Multiple packs - handle based on overlap mode
    local overlapMode = StablemasterDB.settings.packOverlapMode or "union"
    local combinedMounts = {}

    if overlapMode == "intersection" then
        -- Find intersection - mounts that exist in ALL packs
        local firstPack = selectedPacks[1].pack
        
        -- Start with mounts from first pack
        for _, mountID in ipairs(firstPack.mounts) do
            local inAllPacks = true
            
            -- Check if this mount exists in ALL other packs
            for i = 2, #selectedPacks do
                local otherPack = selectedPacks[i].pack
                local foundInOther = false
                for _, otherMountID in ipairs(otherPack.mounts) do
                    if otherMountID == mountID then
                        foundInOther = true
                        break
                    end
                end
                if not foundInOther then
                    inAllPacks = false
                    break
                end
            end
            
            if inAllPacks then
                table.insert(combinedMounts, mountID)
            end
        end
        
        if #combinedMounts == 0 then
            Stablemaster.Debug("No mounts in intersection of all packs")
            return nil
        end
        
    elseif overlapMode == "union" then
        -- Find union - mounts that exist in ANY pack (no duplicates)
        local seenMounts = {}
        
        for _, packData in ipairs(selectedPacks) do
            for _, mountID in ipairs(packData.pack.mounts) do
                if not seenMounts[mountID] then
                    seenMounts[mountID] = true
                    table.insert(combinedMounts, mountID)
                end
            end
        end
        
        if #combinedMounts == 0 then
            Stablemaster.Debug("No mounts in union of all packs")
            return nil
        end
    end
    
    -- Apply flying preference to combined mounts
    EnsureFlyingPreferenceSetting()
    local usableMounts = {}
    local flyingMounts = {}
    
    for _, mountID in ipairs(combinedMounts) do
        local name, spellID, icon, active, isUsable = C_MountJournal.GetMountInfoByID(mountID)
        if isUsable then
            table.insert(usableMounts, mountID)
            if IsFlyingMount(mountID) then
                table.insert(flyingMounts, mountID)
            end
        end
    end
    
    if #usableMounts == 0 then
        return nil
    end
    
    -- Prefer flying if enabled and available
    if StablemasterDB.settings.preferFlyingMounts and CanFlyInCurrentZone() and #flyingMounts > 0 then
        local idx = math.random(1, #flyingMounts)
        return flyingMounts[idx]
    end
    
    -- Fallback to any usable mount from intersection
    local idx = math.random(1, #usableMounts)
    return usableMounts[idx]
end

-- Get a random mount from the fallback pack, optionally preferring flying mounts
local function GetRandomMountFromFallbackPack()
    local fallbackPack = Stablemaster.GetFallbackPack()
    if not fallbackPack then
        Stablemaster.Debug("No fallback pack set")
        return nil
    end
    
    if not fallbackPack.mounts or #fallbackPack.mounts == 0 then
        Stablemaster.Debug("Fallback pack '" .. fallbackPack.name .. "' has no mounts")
        return nil
    end
    
    EnsureFlyingPreferenceSetting()
    
    -- Get all usable mounts from fallback pack
    local usableMounts = {}
    local flyingMounts = {}
    
    for _, mountID in ipairs(fallbackPack.mounts) do
        local name, spellID, icon, active, isUsable = C_MountJournal.GetMountInfoByID(mountID)
        if isUsable then
            table.insert(usableMounts, mountID)
            if IsFlyingMount(mountID) then
                table.insert(flyingMounts, mountID)
            end
        end
    end
    
    if #usableMounts == 0 then
        Stablemaster.Debug("No usable mounts in fallback pack")
        return nil
    end
    
    -- If flying preference is enabled and we can fly, prefer flying mounts
    if StablemasterDB.settings.preferFlyingMounts and CanFlyInCurrentZone() and #flyingMounts > 0 then
        local idx = math.random(1, #flyingMounts)
        local mountID = flyingMounts[idx]
        Stablemaster.Debug("Selected flying mount ID " .. mountID .. " from fallback pack '" .. fallbackPack.name .. "' (found " .. #flyingMounts .. " flying out of " .. #usableMounts .. " usable)")
        return mountID
    end
    
    -- Fallback to any usable mount from fallback pack
    local idx = math.random(1, #usableMounts)
    local mountID = usableMounts[idx]
    if StablemasterDB.settings.preferFlyingMounts and CanFlyInCurrentZone() then
        Stablemaster.Debug("No flying mounts in fallback pack, selected any mount ID " .. mountID .. " from fallback pack '" .. fallbackPack.name .. "' (had " .. #flyingMounts .. " flying out of " .. #usableMounts .. " usable)")
    else
        Stablemaster.Debug("Selected mount ID " .. mountID .. " from fallback pack '" .. fallbackPack.name .. "' (flying preference disabled or can't fly here)")
    end
    return mountID
end

function Stablemaster.MountActive()
    Stablemaster.Debug("MountActive called")

    -- If already mounted, dismount instead
    if IsMounted() then
        Stablemaster.Debug("Already mounted, dismounting")
        Dismount()
        Stablemaster.VerbosePrint("Dismounting")
        return true
    end

    local mountID = GetRandomMountFromSelectedPacks()
    local source = "rule-based packs"
    local packInfo = ""  -- this gets set later
    
    if mountID then
        -- We got a mount from rule-based selection
        local selectedPacks = Stablemaster.runtime.selectedPacks or {}
        if #selectedPacks > 1 then
            local overlapMode = StablemasterDB.settings.packOverlapMode or "union"
            if overlapMode == "intersection" then
                packInfo = " from intersection of " .. #selectedPacks .. " packs"
            else
                packInfo = " from " .. #selectedPacks .. " packs"
            end
        elseif #selectedPacks == 1 then
            packInfo = " from " .. selectedPacks[1].pack.name
        end
    else
        -- Try fallback pack if no rule-based selection
        Stablemaster.Debug("No mount from rule-based selection, trying fallback pack")
        mountID = GetRandomMountFromFallbackPack()
        
        if mountID then
            local fallbackPack = Stablemaster.GetFallbackPack()
            source = "fallback pack"
            packInfo = " from fallback pack '" .. fallbackPack.name .. "'"
        else
            -- Final fallback to WoW's random favorite mount system
            Stablemaster.Debug("No fallback pack or no mounts in fallback pack, using WoW's random favorite mount")
            C_MountJournal.SummonByID(0)
            Stablemaster.Print("Summoned random favorite mount (using WoW's selection)")
            return true
        end
    end
    
    -- Summon the selected mount
    local name = C_MountJournal.GetMountInfoByID(mountID)
    Stablemaster.Debug("Summoning mount: " .. (name or "Unknown") .. packInfo)
    Stablemaster.VerbosePrint("Summoning " .. (name or "Unknown"))
    C_MountJournal.SummonByID(mountID)
    return true
end

-- Global wrapper for the keybind and macros
function Stablemaster_MountKeybind()
    -- Must be called from a hardware event (key press / macro)
    Stablemaster.MountActive()
end

-- Helper to get a random mount from the active pack (future use for a macro/keybind)
function Stablemaster.GetRandomMountFromActivePack()
    local name = Stablemaster.runtime.activePackName
    if not name then 
        Stablemaster.Debug("No active pack name")
        return nil 
    end
    
    local pack = Stablemaster.GetPack(name)
    if not pack then 
        Stablemaster.Debug("Active pack '" .. name .. "' not found")
        return nil 
    end
    
    if not pack.mounts or #pack.mounts == 0 then 
        Stablemaster.Debug("Active pack '" .. name .. "' has no mounts")
        return nil 
    end
    
    local idx = math.random(1, #pack.mounts)
    local mountID = pack.mounts[idx]
    Stablemaster.Debug("Selected mount ID " .. mountID .. " from active pack '" .. name .. "'")
    return mountID
end

-- Event handler for outfit changes (Midnight 12.0+)
local function OnOutfitChanged()
    Stablemaster.Debug("Outfit change detected, re-evaluating packs")
    -- Re-evaluate active packs after a short delay
    C_Timer.After(0.3, function()
        Stablemaster.SelectActivePack()
    end)
end

-- Hook into outfit change events
local outfitEventFrame = CreateFrame("Frame")
outfitEventFrame:RegisterEvent("TRANSMOGRIFY_UPDATE")
outfitEventFrame:RegisterEvent("TRANSMOGRIFY_SUCCESS")
outfitEventFrame:RegisterEvent("UNIT_MODEL_CHANGED")
outfitEventFrame:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
outfitEventFrame:SetScript("OnEvent", function(self, event, arg1, ...)
    -- For UNIT_MODEL_CHANGED, only care about player
    if event == "UNIT_MODEL_CHANGED" and arg1 ~= "player" then
        return
    end

    Stablemaster.Debug("Outfit event fired: " .. event)
    OnOutfitChanged()
end)

-- Slash command handler
-- Parse command line arguments, handling quoted strings
local function ParseArgs(msg)
    local args = {}
    local i = 1
    local len = #msg
    
    while i <= len do
        -- Skip whitespace
        while i <= len and msg:sub(i, i):match("%s") do
            i = i + 1
        end
        
        if i > len then break end
        
        local startPos = i
        local arg = ""
        
        if msg:sub(i, i) == '"' then
            -- Quoted string
            i = i + 1 -- Skip opening quote
            while i <= len do
                local char = msg:sub(i, i)
                if char == '"' then
                    i = i + 1 -- Skip closing quote
                    break
                elseif char == '\\' and i < len then
                    -- Handle escaped characters
                    i = i + 1
                    arg = arg .. msg:sub(i, i)
                else
                    arg = arg .. char
                end
                i = i + 1
            end
        else
            -- Unquoted string
            while i <= len and not msg:sub(i, i):match("%s") do
                arg = arg .. msg:sub(i, i)
                i = i + 1
            end
        end
        
        if arg ~= "" then
            table.insert(args, arg)
        end
    end
    
    return args
end

local function SlashHandler(msg)
    local args = ParseArgs(msg or "")
    local command = string.lower(args[1] or "")

    if command == "debug-on" then
        StablemasterDB.settings.debugMode = true
        Stablemaster.Print("Debug mode: ON")

    elseif command == "debug-off" then
        StablemasterDB.settings.debugMode = false
        Stablemaster.Print("Debug mode: OFF")

    elseif command == "flying-on" then
        EnsureFlyingPreferenceSetting()
        StablemasterDB.settings.preferFlyingMounts = true
        Stablemaster.Print("Flying mount preference: ON")

    elseif command == "flying-off" then
        EnsureFlyingPreferenceSetting()
        StablemasterDB.settings.preferFlyingMounts = false
        Stablemaster.Print("Flying mount preference: OFF")

    elseif command == "overlap-intersection" then
        StablemasterDB.settings.packOverlapMode = "intersection"
        Stablemaster.Print("Pack overlap mode: Intersection (mounts common to all matching packs)")
        C_Timer.After(0.1, Stablemaster.SelectActivePack)

    elseif command == "overlap-union" then
        StablemasterDB.settings.packOverlapMode = "union"
        Stablemaster.Print("Pack overlap mode: Union (mounts from any matching pack)")
        C_Timer.After(0.1, Stablemaster.SelectActivePack)

    elseif command == "outfit" then
        local currentOutfitID = Stablemaster.GetCurrentOutfitID()
        if currentOutfitID then
            local outfitInfo = Stablemaster.GetOutfitInfo(currentOutfitID)
            local outfitName = outfitInfo and outfitInfo.name or ("Outfit #" .. currentOutfitID)
            Stablemaster.Print("Current outfit: " .. outfitName .. " (ID: " .. currentOutfitID .. ")")
        else
            Stablemaster.Print("No active outfit detected")
        end

    elseif command == "packs-status" then
        local matchingPacks = GetMatchingPacks()
        if #matchingPacks == 0 then
            Stablemaster.Print("No packs match current conditions")
        else
            Stablemaster.Print("Matching packs:")
            for i, packData in ipairs(matchingPacks) do
                local ruleTypes = {}
                for _, rule in ipairs(packData.matchedRules) do
                    table.insert(ruleTypes, rule.type)
                end
                Stablemaster.Print("  " .. i .. ". " .. packData.pack.name .. " (score: " .. packData.score .. ", rules: " .. table.concat(ruleTypes, ", ") .. ")")
            end
            
            local overlapMode = StablemasterDB.settings.packOverlapMode or "union"
            local selectedPacks = Stablemaster.runtime.selectedPacks or {}

            if #selectedPacks > 0 then
                local packNames = {}
                for _, sp in ipairs(selectedPacks) do
                    table.insert(packNames, sp.pack.name)
                end
                local modeText = overlapMode == "intersection" and "intersection" or "union"
                Stablemaster.Print("Active packs (" .. modeText .. "): " .. table.concat(packNames, ", "))
            end
        end

    elseif command == "characters" then
        if not StablemasterDB.characters or not next(StablemasterDB.characters) then
            Stablemaster.Print("No character data found.")
        else
            Stablemaster.Print("Stablemaster data across characters:")
            for charKey, charData in pairs(StablemasterDB.characters) do
                local packCount = charData.packs and #charData.packs or 0
                Stablemaster.Print("- " .. charKey .. ": " .. packCount .. " pack" .. (packCount == 1 and "" or "s"))
            end
        end

    elseif command == "status" then
        EnsureFlyingPreferenceSetting()
        local charPacks = Stablemaster.GetCharacterPacks()
        local sharedPacks = StablemasterDB.sharedPacks or {}
        local allPacks = Stablemaster.GetAllAvailablePacks()
        local charKey = UnitName("player") .. "-" .. GetRealmName()
        Stablemaster.Print("Status:")
        Stablemaster.Print("- Character: " .. charKey)
        Stablemaster.Print("- Character-specific packs: " .. #charPacks)
        Stablemaster.Print("- Account-wide packs: " .. #sharedPacks)
        Stablemaster.Print("- Total available packs: " .. #allPacks)
        Stablemaster.Print("- Verbose mode: " .. (StablemasterDB.settings.verboseMode and "ON" or "OFF"))
        Stablemaster.Print("- Debug mode: " .. (StablemasterDB.settings.debugMode and "ON" or "OFF"))
        Stablemaster.Print("- Flying preference: " .. (StablemasterDB.settings.preferFlyingMounts and "ON" or "OFF"))
        Stablemaster.Print("- Overlap mode: " .. (StablemasterDB.settings.packOverlapMode or "union"))
        Stablemaster.Print("- Active pack: " .. (Stablemaster.runtime.activePackName or "None"))
        local fallbackPack = Stablemaster.GetFallbackPack()
        Stablemaster.Print("- Fallback pack: " .. (fallbackPack and fallbackPack.name or "None"))
        Stablemaster.Print("- Can fly here: " .. (CanFlyInCurrentZone() and "YES" or "NO"))

    elseif command == "test" then
        local allMountIDs = C_MountJournal.GetMountIDs()
        local ownedCount = 0
        for _, mountID in ipairs(allMountIDs) do
            local _, _, _, _, _, _, _, _, _, _, isCollected = C_MountJournal.GetMountInfoByID(mountID)
            if isCollected then ownedCount = ownedCount + 1 end
        end
        Stablemaster.Print("Total mounts in game: " .. #allMountIDs)
        Stablemaster.Print("Mounts you own: " .. ownedCount)
        Stablemaster.Debug("Mount API test successful")

    elseif command == "create" then
        if not args[2] then
            Stablemaster.Print("Usage: /stablemaster create <pack_name> [description]")
            return
        end
        local packName = args[2]
        local description = table.concat(args, " ", 3)
        local success, message = Stablemaster.CreatePack(packName, description)
        Stablemaster.Print(message)

    elseif command == "delete" then
        if not args[2] then
            Stablemaster.Print("Usage: /stablemaster delete <pack_name>")
            return
        end
        local success, message = Stablemaster.DeletePack(args[2])
        Stablemaster.Print(message)

    elseif command == "list" then
        local allPacks = Stablemaster.GetAllAvailablePacks()
        if #allPacks == 0 then
            Stablemaster.Print("No packs created yet. Use /stablemaster create <n> to make one!")
        else
            Stablemaster.Print("Your mount packs:")
            for _, pack in ipairs(allPacks) do
                local mountCount = #pack.mounts
                local shareStatus = pack.isShared and " |cff88ff88[Account-Wide]|r" or " |cffffff88[Character]|r"
                local fallbackStatus = pack.isFallback and " |cffff9900[Fallback]|r" or ""
                Stablemaster.Print("- " .. pack.name .. " (" .. mountCount .. " mounts)" .. shareStatus .. fallbackStatus)
                if pack.description ~= "" then
                    Stablemaster.Print("  " .. pack.description)
                end
            end
        end

    elseif command == "show" then
        if not args[2] then
            Stablemaster.Print("Usage: /stablemaster show <pack_name>")
            return
        end
        local pack = Stablemaster.GetPack(args[2])
        if not pack then
            Stablemaster.Print("Pack '" .. args[2] .. "' not found")
            return
        end

        Stablemaster.Print("Pack: " .. pack.name)
        if pack.description ~= "" then
            Stablemaster.Print("Description: " .. pack.description)
        end
        if #pack.mounts == 0 then
            Stablemaster.Print("No mounts in this pack yet")
        else
            Stablemaster.Print("Mounts (" .. #pack.mounts .. "):")
            for _, mountID in ipairs(pack.mounts) do
                local name = C_MountJournal.GetMountInfoByID(mountID)
                Stablemaster.Print("  - " .. (name or "Unknown mount"))
            end
        end

    elseif command == "add" then
        if not args[2] or not args[3] then
            Stablemaster.Print("Usage: /stablemaster add <pack_name> <mount_id>")
            Stablemaster.Print("Use /stablemaster mounts to see your mount IDs")
            return
        end
        local packName = args[2]
        local mountID = tonumber(args[3])
        if not mountID then
            Stablemaster.Print("Mount ID must be a number")
            return
        end
        local success, message = Stablemaster.AddMountToPack(packName, mountID)
        Stablemaster.Print(message)

    elseif command == "remove" then
        if not args[2] or not args[3] then
            Stablemaster.Print("Usage: /stablemaster remove <pack_name> <mount_id>")
            return
        end
        local packName = args[2]
        local mountID = tonumber(args[3])
        if not mountID then
            Stablemaster.Print("Mount ID must be a number")
            return
        end
        local success, message = Stablemaster.RemoveMountFromPack(packName, mountID)
        Stablemaster.Print(message)

    elseif command == "mounts" then
        local ownedMounts = Stablemaster.GetOwnedMounts()
        Stablemaster.Print("Your mounts (showing first 10):")
        for i = 1, math.min(10, #ownedMounts) do
            local mount = ownedMounts[i]
            Stablemaster.Print("ID " .. mount.id .. ": " .. mount.name)
        end
        if #ownedMounts > 10 then
            Stablemaster.Print("... and " .. (#ownedMounts - 10) .. " more. Use /stablemaster findmount <n> to search")
        end

    elseif command == "findmount" then
        if not args[2] then
            Stablemaster.Print("Usage: /stablemaster findmount <search_term>")
            return
        end
        local searchTerm = string.lower(table.concat(args, " ", 2))
        local ownedMounts = Stablemaster.GetOwnedMounts()
        local matches = {}
        for _, mount in ipairs(ownedMounts) do
            if string.find(string.lower(mount.name), searchTerm) then
                table.insert(matches, mount)
            end
        end
        if #matches == 0 then
            Stablemaster.Print("No mounts found matching: " .. searchTerm)
        else
            Stablemaster.Print("Found " .. #matches .. " mount(s) matching '" .. searchTerm .. "':")
            for _, mount in ipairs(matches) do
                Stablemaster.Print("ID " .. mount.id .. ": " .. mount.name)
            end
        end

    elseif command == "ui" or command == "" then
        StablemasterUI.ToggleMainFrame()

        -- Clear and hide the chat edit box after handling the slash command
        C_Timer.After(0, function()
            local active = ChatEdit_GetActiveWindow and ChatEdit_GetActiveWindow()
            if active then
                -- Escape clears text and hides the edit box
                ChatEdit_OnEscapePressed(active)
            end
        end)
    
    elseif command == "mount" then
        if not Stablemaster.MountActive() then
            Stablemaster.Print("Try creating a pack or favoriting a mount first.")
        end

    elseif command == "debug-mount-types" then
        StablemasterUI.DebugMountTypes()

    elseif command == "debug-faction-mounts" then
        StablemasterUI.DebugFactionMounts()

    elseif command == "debug-zone" then
        Stablemaster.Print("Zone Detection Debug:")
        
        local mapID1 = GetPlayerMapID()
        local mapID2 = C_Map.GetBestMapForUnit("player")
        local zoneText = GetZoneText()
        local subzoneText = GetSubZoneText()
        local realZoneText = GetRealZoneText()
        
        Stablemaster.Print("GetPlayerMapID(): " .. (mapID1 or "nil"))
        Stablemaster.Print("GetBestMapForUnit(): " .. (mapID2 or "nil"))
        Stablemaster.Print("Zone Text: " .. (zoneText or "nil"))
        Stablemaster.Print("Subzone Text: " .. (subzoneText or "nil"))
        Stablemaster.Print("Real Zone Text: " .. (realZoneText or "nil"))
        
        local finalMapID = mapID1 or mapID2
        if finalMapID then
            local mapInfo = C_Map.GetMapInfo(finalMapID)
            if mapInfo then
                Stablemaster.Print("Map ID " .. finalMapID .. ": " .. (mapInfo.name or "Unknown"))
                Stablemaster.Print("Map Type: " .. (mapInfo.mapType or "Unknown"))
                
                -- Show parent hierarchy
                local parent = mapInfo
                local level = 0
                while parent and parent.parentMapID and parent.parentMapID > 0 and level < 5 do
                    parent = C_Map.GetMapInfo(parent.parentMapID)
                    if parent then
                        level = level + 1
                        Stablemaster.Print("Parent " .. level .. ": " .. parent.parentMapID .. " (" .. (parent.name or "Unknown") .. ")")
                    end
                end
            else
                Stablemaster.Print("Could not get map info for ID " .. finalMapID)
            end
        else
            Stablemaster.Print("No valid map ID detected")
        end
        
    elseif command == "debug-pack" then
        local packName = args[2]
        if not packName then
            Stablemaster.Print("Usage: /stablemaster debug-pack <pack_name>")
            return
        end

        local pack = Stablemaster.GetPackByName(packName)
        if not pack then
            Stablemaster.Print("Pack '" .. packName .. "' not found")
            return
        end

        Stablemaster.Print("Pack '" .. packName .. "' debug info:")
        Stablemaster.Print("- isShared: " .. tostring(pack.isShared))
        Stablemaster.Print("- isFallback: " .. tostring(pack.isFallback))
        Stablemaster.Print("- Mounts: " .. #(pack.mounts or {}))
        Stablemaster.Print("- Conditions: " .. #(pack.conditions or {}))

        if pack.conditions then
            for i, rule in ipairs(pack.conditions) do
                Stablemaster.Print("  Rule " .. i .. ":")
                Stablemaster.Print("    type: " .. tostring(rule.type))
                if rule.type == "class" then
                    Stablemaster.Print("    classIDs: " .. (rule.classIDs and table.concat(rule.classIDs, ", ") or "nil"))
                    Stablemaster.Print("    specIDs: " .. (rule.specIDs and table.concat(rule.specIDs, ", ") or "nil"))
                elseif rule.type == "race" then
                    Stablemaster.Print("    raceIDs: " .. (rule.raceIDs and table.concat(rule.raceIDs, ", ") or "nil"))
                elseif rule.type == "zone" then
                    Stablemaster.Print("    mapID: " .. tostring(rule.mapID))
                end
            end
        end

        -- Also show current player info
        local _, _, playerClassID = UnitClass("player")
        local _, _, playerRaceID = UnitRace("player")
        Stablemaster.Print("Your classID: " .. tostring(playerClassID))
        Stablemaster.Print("Your raceID: " .. tostring(playerRaceID))

    elseif command == "debug-outfit" then
        Stablemaster.Print("=== Outfit Debug ===")

        -- Current outfit
        local currentOutfitID = Stablemaster.GetCurrentOutfitID()
        if currentOutfitID then
            local outfitInfo = Stablemaster.GetOutfitInfo(currentOutfitID)
            local outfitName = outfitInfo and outfitInfo.name or "Unknown"
            Stablemaster.Print("Current outfit: " .. outfitName .. " (ID: " .. currentOutfitID .. ")")
        else
            Stablemaster.Print("Current outfit: None active")
        end

        -- All saved outfits
        local outfits = Stablemaster.GetAllOutfits()
        Stablemaster.Print("Saved outfits: " .. #outfits)

        -- Packs with outfit rules
        local allPacks = Stablemaster.GetAllAvailablePacks()
        local outfitPackCount = 0
        for _, pack in ipairs(allPacks) do
            if pack.conditions then
                for _, rule in ipairs(pack.conditions) do
                    if rule.type == "outfit" then
                        outfitPackCount = outfitPackCount + 1
                        local ruleOutfitInfo = Stablemaster.GetOutfitInfo(rule.outfitID)
                        local ruleOutfitName = ruleOutfitInfo and ruleOutfitInfo.name or rule.outfitName or "Unknown"
                        local isActive = (currentOutfitID == rule.outfitID) and " <-- ACTIVE" or ""
                        Stablemaster.Print("  Pack '" .. pack.name .. "' -> " .. ruleOutfitName .. isActive)
                    end
                end
            end
        end
        if outfitPackCount == 0 then
            Stablemaster.Print("  No packs with outfit rules")
        end

    elseif command == "outfit-menu" then
        -- Test the outfit context menu with the current outfit
        if Stablemaster.OutfitHook and Stablemaster.OutfitHook.ShowCurrentOutfitMenu then
            Stablemaster.OutfitHook.ShowCurrentOutfitMenu()
        else
            Stablemaster.Print("Outfit hook not available")
        end

    elseif command == "debug-wardrobe" then
        if Stablemaster.OutfitHook and Stablemaster.OutfitHook.DebugWardrobeUI then
            Stablemaster.OutfitHook.DebugWardrobeUI()
        else
            Stablemaster.Print("Outfit hook not available")
        end

    elseif command == "test-parse" then
        Stablemaster.Print("Parsed arguments:")
        for i, arg in ipairs(args) do
            Stablemaster.Print(i .. ": '" .. arg .. "'")
        end
    
    elseif command == "share" then
        if not args[2] then
            Stablemaster.Print("Usage: /stablemaster share <pack_name>")
            return
        end
        local success, message = Stablemaster.TogglePackShared(args[2])
        Stablemaster.Print(message)
    
    elseif command == "fallback" then
        if not args[2] then
            Stablemaster.Print("Usage: /stablemaster fallback <pack_name>")
            Stablemaster.Print("Toggle a pack as the fallback pack (used when no rules match)")
            return
        end
        local success, message = Stablemaster.TogglePackFallback(args[2])
        Stablemaster.Print(message)
    
    elseif command == "debug-db" then
        Stablemaster.Print("Database Debug Info:")
        Stablemaster.Print("StablemasterDB type: " .. type(StablemasterDB))
        if StablemasterDB then
            Stablemaster.Print("StablemasterDB.sharedPacks type: " .. type(StablemasterDB.sharedPacks))
            if StablemasterDB.sharedPacks then
                Stablemaster.Print("Shared packs count: " .. #StablemasterDB.sharedPacks)
            else
                Stablemaster.Print("StablemasterDB.sharedPacks is nil!")
            end
        else
            Stablemaster.Print("StablemasterDB is nil!")
        end
    
    elseif command == "verbose-on" then
        StablemasterDB.settings.verboseMode = true
        Stablemaster.Print("Verbose mode: ON")

    elseif command == "verbose-off" then
        StablemasterDB.settings.verboseMode = false
        Stablemaster.Print("Verbose mode: OFF")
    
    elseif command == "test-scroll" then
        if not _G.StablemasterMainFrame then
            Stablemaster.Print("Open Stablemaster UI first")
            return
        end
        
        local packPanel = _G.StablemasterMainFrame.packPanel
        if not packPanel then
            Stablemaster.Print("Pack panel not found")
            return
        end
        
        -- Create a simple red test frame at the very top
        local testFrame = CreateFrame("Frame", nil, packPanel)
        testFrame:SetSize(300, 50)
        testFrame:SetPoint("TOPLEFT", packPanel, "TOPLEFT", 20, -80) -- Same position as the scroll frame
        
        local bg = testFrame:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints(testFrame)
        bg:SetColorTexture(1, 0, 0, 0.8) -- Bright red
        
        local text = testFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        text:SetPoint("CENTER", testFrame, "CENTER", 0, 0)
        text:SetText("TEST FRAME - TOP OF PACK PANEL")
        text:SetTextColor(1, 1, 1, 1)
        
        testFrame:Show()
        
        Stablemaster.Print("Created red test frame at top of pack panel")
        
        -- Auto-hide after 5 seconds
        C_Timer.After(5, function()
            testFrame:Hide()
            testFrame:SetParent(nil)
        end)

    else
        Stablemaster.Print("Stablemaster Commands:")
        Stablemaster.Print("/stablemaster (or /stablemaster ui) - Open main window")
        Stablemaster.Print("/stablemaster create <n> [description] - Create a new pack")
        Stablemaster.Print("/stablemaster delete <n> - Delete a pack")
        Stablemaster.Print("/stablemaster share <n> - Toggle pack between character-specific and account-wide")
        Stablemaster.Print("/stablemaster fallback <n> - Toggle pack as fallback (used when no rules match)")
        Stablemaster.Print("/stablemaster list - Show all packs for this character")
        Stablemaster.Print("/stablemaster characters - Show pack count across all characters")
        Stablemaster.Print("/stablemaster show <n> - Show mounts in a pack")
        Stablemaster.Print("/stablemaster add <pack> <mount_id> - Add mount to pack")
        Stablemaster.Print("/stablemaster remove <pack> <mount_id> - Remove mount from pack")
        Stablemaster.Print("/stablemaster mounts - Show your first 10 mounts")
        Stablemaster.Print("/stablemaster findmount <search> - Search for mounts")
        Stablemaster.Print("/stablemaster status - Show addon status")
        Stablemaster.Print("/stablemaster packs-status - Show matching packs and scores")
        Stablemaster.Print("/stablemaster debug-outfit - Show current outfit and outfit rules info")
        Stablemaster.Print("/stablemaster outfit-menu - Show context menu for current outfit")
        Stablemaster.Print("/stablemaster debug-zone - Show detailed zone detection information")
        Stablemaster.Print("/stablemaster overlap-intersection/union - Set pack overlap mode")
        Stablemaster.Print("/stablemaster flying-on/off - Toggle flying mount preference")
        Stablemaster.Print("/stablemaster verbose-on/off - Toggle verbose output")

        -- Only show debug commands if debug mode is enabled
        if StablemasterDB.settings.debugMode then
            Stablemaster.Print("---")
            Stablemaster.Print("Debug Commands (debug mode enabled):")
            Stablemaster.Print("/stablemaster debug-on/off - Toggle debug mode")
            Stablemaster.Print("/stablemaster debug-mount-types - Analyze mount type IDs")
            Stablemaster.Print("/stablemaster debug-faction-mounts - Analyze faction filtering")
        end
    end
end

-- Event frame setup
local eventFrame = CreateFrame("Frame")

local function OnEvent(self, event, ...)
    if event == "ADDON_LOADED" then
        local addonName = ...
        if addonName == "Stablemaster" then
            Stablemaster.Debug("Stablemaster loaded successfully!")
            Stablemaster.Print("v" .. Stablemaster.version .. " loaded. Type /stablemaster or /sm to start building packs!")

            -- Initialize pack evaluation with retries for zone detection
            local function InitializePackEvaluation(attempt)
                attempt = attempt or 1
                C_Timer.After(1 + attempt, function()
                    local mapID = GetPlayerMapID() or C_Map.GetBestMapForUnit("player")
                    if mapID then
                        Stablemaster.Debug("Zone detection initialized successfully on attempt " .. attempt)
                        Stablemaster.SelectActivePack()
                    elseif attempt < 5 then
                        Stablemaster.Debug("Zone detection failed on attempt " .. attempt .. ", retrying...")
                        InitializePackEvaluation(attempt + 1)
                    else
                        Stablemaster.Debug("Zone detection failed after 5 attempts, will retry on events")
                    end
                end)
            end

            InitializePackEvaluation()

            -- Initialize minimap icon
            if Stablemaster.MinimapIcon then
                Stablemaster.MinimapIcon.Initialize()
            end
        end
    elseif event == "PLAYER_ENTERING_WORLD" or
           event == "ZONE_CHANGED" or
           event == "ZONE_CHANGED_NEW_AREA" then
        -- Evaluate active pack on relevant context changes
        C_Timer.After(0.2, Stablemaster.SelectActivePack)
    elseif event == "ZONE_CHANGED_INDOORS" then
        -- Handle indoor zone changes (like entering buildings/instances)
        C_Timer.After(0.5, Stablemaster.SelectActivePack)
    elseif event == "NEW_WMO_CHUNK" then
        -- Handle entering new world model chunks (can indicate zone changes)
        C_Timer.After(1, Stablemaster.SelectActivePack)
    elseif event == "PLAYER_EQUIPMENT_CHANGED" then
        -- Re-evaluate packs when equipment changes (outfit may have changed)
        C_Timer.After(0.5, Stablemaster.SelectActivePack)
    end
end

eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:RegisterEvent("ZONE_CHANGED")
eventFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
eventFrame:RegisterEvent("ZONE_CHANGED_INDOORS")
eventFrame:RegisterEvent("NEW_WMO_CHUNK")
eventFrame:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
eventFrame:SetScript("OnEvent", OnEvent)

-- Register slash commands
SLASH_STABLEMASTER1 = "/stablemaster"
SLASH_STABLEMASTER2 = "/sm"
SlashCmdList["STABLEMASTER"] = SlashHandler

Stablemaster.Debug("Core.lua loaded")