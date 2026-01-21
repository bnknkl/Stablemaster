-- Stablemaster: Rules Dialog (Modern Style)
Stablemaster.Debug("UI/RulesDialog.lua loading...")

local STYLE = StablemasterUI.Style
local rulesDialog -- singleton-ish

-- Ensure pack.conditions exists
local function EnsureConditions(pack)
    pack.conditions = pack.conditions or {}
end

local function UpdateZoneDisplay(dlg)
    if not dlg.zoneText then return end
    
    -- Try multiple methods to get the current zone
    local currentMapID = C_Map.GetBestMapForUnit("player")
    local zoneName = nil
    
    -- First try the standard API
    if currentMapID then
        local mapInfo = C_Map.GetMapInfo(currentMapID)
        if mapInfo and mapInfo.name then
            zoneName = mapInfo.name
            Stablemaster.Debug("Zone detected via GetBestMapForUnit: " .. zoneName)
        else
            Stablemaster.Debug("Got map ID " .. currentMapID .. " but no map info available")
        end
    end
    
    -- Fallback methods for when the main API fails (common after UI reload)
    if not zoneName then
        -- Try GetRealZoneText
        local realZone = GetRealZoneText()
        if realZone and realZone ~= "" then
            zoneName = realZone
            Stablemaster.Debug("Zone detected via GetRealZoneText: " .. zoneName)
        end
    end
    
    if not zoneName then
        -- Try GetZoneText as another fallback
        local zoneText = GetZoneText()
        if zoneText and zoneText ~= "" then
            zoneName = zoneText
            Stablemaster.Debug("Zone detected via GetZoneText: " .. zoneName)
        end
    end
    
    if not zoneName then
        -- Try GetSubZoneText as a last resort
        local subZone = GetSubZoneText()
        if subZone and subZone ~= "" then
            zoneName = subZone .. " (subzone)"
            Stablemaster.Debug("Zone detected via GetSubZoneText: " .. zoneName)
        end
    end
    
    -- If we found a zone name, display it
    if zoneName then
        dlg.zoneText:SetText(zoneName)
        return
    end
    
    -- If no zone detected, show "Unknown" and start retry process
    dlg.zoneText:SetText("Unknown")
    Stablemaster.Debug("Zone display set to Unknown - no zone info available via any method")
    
    -- More aggressive retry strategy for cases where zone isn't immediately available (like after UI reload)
    local retryAttempts = 0
    local maxRetries = 10
    local retryTimer
    
    local function RetryZoneDetection()
        retryAttempts = retryAttempts + 1
        if retryAttempts > maxRetries or not dlg:IsShown() then
            if retryTimer then
                retryTimer:Cancel()
            end
            Stablemaster.Debug("Zone detection gave up after " .. retryAttempts .. " attempts")
            return
        end
        
        -- Try all methods again
        local foundZone = nil
        
        local retryMapID = C_Map.GetBestMapForUnit("player")
        if retryMapID then
            local retryMapInfo = C_Map.GetMapInfo(retryMapID)
            if retryMapInfo and retryMapInfo.name then
                foundZone = retryMapInfo.name
                Stablemaster.Debug("Zone found on retry " .. retryAttempts .. " via GetBestMapForUnit: " .. foundZone)
            end
        end
        
        if not foundZone then
            local realZone = GetRealZoneText()
            if realZone and realZone ~= "" then
                foundZone = realZone
                Stablemaster.Debug("Zone found on retry " .. retryAttempts .. " via GetRealZoneText: " .. foundZone)
            end
        end
        
        if not foundZone then
            local zoneText = GetZoneText()
            if zoneText and zoneText ~= "" then
                foundZone = zoneText
                Stablemaster.Debug("Zone found on retry " .. retryAttempts .. " via GetZoneText: " .. foundZone)
            end
        end
        
        if foundZone then
            dlg.zoneText:SetText(foundZone)
            if retryTimer then
                retryTimer:Cancel()
            end
            return
        else
            Stablemaster.Debug("Retry " .. retryAttempts .. ": Still no zone info available")
        end
    end
    
    -- Start with immediate retry, then every 1 second for up to 10 seconds
    C_Timer.After(0.5, RetryZoneDetection)
    retryTimer = C_Timer.NewTicker(1, RetryZoneDetection)
end

-- Build the visible list of rules inside the dialog
local function RebuildRulesList(container, pack)
    Stablemaster.Debug("RebuildRulesList called for pack: " .. (pack.name or "unknown"))
    
    -- clear
    if container.ruleRows then
        for _, row in ipairs(container.ruleRows) do
            row:Hide()
            row:SetParent(nil)
        end
    end
    container.ruleRows = {}

    EnsureConditions(pack)
    Stablemaster.Debug("Pack has " .. #pack.conditions .. " conditions")
    
    local y = -10
    for i, rule in ipairs(pack.conditions) do
        local row = CreateFrame("Frame", nil, container)
        -- Increase height for custom transmog rules that have two lines of text
        local isTwoLineRule = (rule.type == "custom_transmog") or (rule.type == "class" and rule.specIDs and #rule.specIDs > 0)
        local rowHeight = isTwoLineRule and 35 or 22
        row:SetSize(360, rowHeight)
        row:SetPoint("TOPLEFT", container, "TOPLEFT", 0, y)

        local text = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        text:SetPoint("LEFT", row, "LEFT", 0, 0)

        if rule.type == "zone" then
            local mi = C_Map.GetMapInfo(rule.mapID)
            local zoneName = mi and mi.name or ("MapID " .. tostring(rule.mapID))
            text:SetText(string.format("Zone: %s%s", zoneName, rule.includeParents and " (match parents)" or ""))
        elseif rule.type == "transmog" then
            local setInfo = Stablemaster.GetTransmogSetInfo(rule.setID)
            local setName = setInfo and setInfo.name or ("SetID " .. tostring(rule.setID))
            text:SetText("Transmog: " .. setName)
            
            -- Add "Apply Set" button for transmog rules
            local applyBtn = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
            applyBtn:SetSize(80, 18)
            applyBtn:SetPoint("RIGHT", row, "RIGHT", -5, 0)
            applyBtn:SetText("Apply Set")
            
            -- Tooltip for apply button
            applyBtn:SetScript("OnEnter", function(self)
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetText("Apply Transmog Set", 1, 1, 1, 1, true)
                if C_Transmog.IsAtTransmogNPC() then
                    GameTooltip:AddLine("Click to apply this transmog set immediately.", 1, 1, 0.8, true)
                    GameTooltip:AddLine("Set: " .. setName, 0.8, 0.8, 1, true)
                else
                    GameTooltip:AddLine("Must be at a transmog vendor to apply sets.", 1, 0.5, 0.5, true)
                end
                GameTooltip:Show()
            end)
            applyBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
            
            -- Enable/disable based on vendor status
            applyBtn:SetEnabled(C_Transmog.IsAtTransmogNPC())
            
            -- Apply button click handler
            applyBtn:SetScript("OnClick", function()
                if not C_Transmog.IsAtTransmogNPC() then
                    Stablemaster.Print("Must be at a transmog vendor to apply sets")
                    return
                end
                
                local success, message = Stablemaster.ApplyTransmogSet(rule.setID)
                Stablemaster.Print(message)
            end)
            
        elseif rule.type == "custom_transmog" then
            local transmogName = rule.transmogName or "Custom Transmog"
            local strictness = rule.strictness or 6
            local weaponsText = rule.includeWeapons and " +Weapons" or ""
            text:SetText(string.format("Custom Transmog: %s\n(Strictness: %d%s)", transmogName, strictness, weaponsText))
        elseif rule.type == "class" then
            local classNames = {}
            for _, classID in ipairs(rule.classIDs or {}) do
                local className = GetClassInfo(classID)
                if className then
                    table.insert(classNames, className)
                end
            end
            local classText = #classNames > 0 and table.concat(classNames, ", ") or "None"

            if rule.specIDs and #rule.specIDs > 0 then
                local specNames = {}
                for _, specID in ipairs(rule.specIDs) do
                    local _, specName = GetSpecializationInfoByID(specID)
                    if specName then
                        table.insert(specNames, specName)
                    end
                end
                local specText = #specNames > 0 and table.concat(specNames, ", ") or "Any"
                text:SetText(string.format("Class: %s\n(Specs: %s)", classText, specText))
            else
                text:SetText("Class: " .. classText .. " (Any spec)")
            end
        elseif rule.type == "race" then
            local raceNames = {}
            local seenNames = {}
            for _, raceID in ipairs(rule.raceIDs or {}) do
                local raceInfo = C_CreatureInfo.GetRaceInfo(raceID)
                if raceInfo and not seenNames[raceInfo.raceName] then
                    seenNames[raceInfo.raceName] = true
                    table.insert(raceNames, raceInfo.raceName)
                end
            end
            local raceText = #raceNames > 0 and table.concat(raceNames, ", ") or "None"
            text:SetText("Race: " .. raceText)
        elseif rule.type == "outfit" then
            -- Outfit rule (Midnight 12.0+) - supports both single and multi-outfit formats
            local outfitNames = {}

            if rule.outfitIDs then
                -- New multi-outfit format
                for i, outfitID in ipairs(rule.outfitIDs) do
                    -- Try to get current name (in case outfit was renamed)
                    local outfitInfo = Stablemaster.GetOutfitInfo(outfitID)
                    if outfitInfo and outfitInfo.name then
                        table.insert(outfitNames, outfitInfo.name)
                    elseif rule.outfitNames and rule.outfitNames[i] then
                        table.insert(outfitNames, rule.outfitNames[i])
                    else
                        table.insert(outfitNames, "Outfit #" .. outfitID)
                    end
                end
            elseif rule.outfitID then
                -- Legacy single-outfit format (backward compatibility)
                local outfitInfo = Stablemaster.GetOutfitInfo(rule.outfitID)
                if outfitInfo and outfitInfo.name then
                    table.insert(outfitNames, outfitInfo.name)
                elseif rule.outfitName then
                    table.insert(outfitNames, rule.outfitName)
                else
                    table.insert(outfitNames, "Outfit #" .. rule.outfitID)
                end
            end

            local displayText = #outfitNames > 0 and table.concat(outfitNames, ", ") or "No outfits"
            text:SetText("Outfit: " .. displayText)
        elseif rule.type == "time" then
            -- Time of day rule
            -- New multi-select format
            if rule.timeNames and #rule.timeNames > 0 then
                local displayText = table.concat(rule.timeNames, ", ")
                text:SetText("Time: " .. displayText)
            else
                -- Legacy single time format
                local timeName = rule.timeName or ""
                local startHour = rule.startHour or 0
                local endHour = rule.endHour or 0

                -- Format hours nicely
                local function formatHour(h)
                    if h == 0 then return "12 AM"
                    elseif h < 12 then return h .. " AM"
                    elseif h == 12 then return "12 PM"
                    else return (h - 12) .. " PM"
                    end
                end

                if timeName ~= "" then
                    text:SetText("Time: " .. timeName .. " (" .. formatHour(startHour) .. " - " .. formatHour(endHour) .. ")")
                else
                    text:SetText("Time: " .. formatHour(startHour) .. " - " .. formatHour(endHour))
                end
            end
        elseif rule.type == "holiday" then
            -- Holiday rule
            local holidayNames = rule.holidayNames or {}
            local displayText = #holidayNames > 0 and table.concat(holidayNames, ", ") or "No holidays"
            text:SetText("Holiday: " .. displayText)
        elseif rule.type == "season" then
            -- Season rule
            local seasonNames = rule.seasonNames or {}
            local displayText = #seasonNames > 0 and table.concat(seasonNames, ", ") or "No seasons"
            text:SetText("Season: " .. displayText)
        else
            text:SetText("Unknown rule type")
        end

        -- Add strictness slider and weapon checkbox for custom transmog rules
        local strictnessSlider, weaponCheckbox
        if rule.type == "custom_transmog" then
            -- Weapon inclusion checkbox
            weaponCheckbox = CreateFrame("CheckButton", nil, row, "UICheckButtonTemplate")
            weaponCheckbox:SetSize(16, 16)
            weaponCheckbox:SetPoint("RIGHT", row, "RIGHT", -130, 0)
            weaponCheckbox:SetChecked(rule.includeWeapons or false)
            
            -- Weapon checkbox tooltip
            weaponCheckbox:SetScript("OnEnter", function(self)
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetText("Include Weapons", 1, 1, 1, 1, true)
                GameTooltip:AddLine("Check to include weapon appearances in transmog matching.", 1, 1, 0.8, true)
                GameTooltip:AddLine("Uncheck to match armor only (weapons ignored).", 1, 1, 0.8, true)
                GameTooltip:Show()
            end)
            weaponCheckbox:SetScript("OnLeave", function() GameTooltip:Hide() end)
            
            -- Update rule when checkbox changes
            weaponCheckbox:SetScript("OnClick", function(self)
                rule.includeWeapons = self:GetChecked()
                
                -- Adjust slider max value based on weapon inclusion
                local newMax = rule.includeWeapons and 13 or 11
                strictnessSlider:SetMinMaxValues(1, newMax)
                
                -- Adjust strictness if it's now too high
                if rule.strictness > newMax then
                    rule.strictness = newMax
                    strictnessSlider:SetValue(newMax)
                end
                
                -- Update display text
                local transmogName = rule.transmogName or "Custom Transmog"
                local strictness = rule.strictness or 6
                local weaponsText = rule.includeWeapons and " +Weapons" or ""
                text:SetText(string.format("Custom Transmog: %s\n(Strictness: %d%s)", transmogName, strictness, weaponsText))
                -- Re-evaluate packs
                C_Timer.After(0.1, Stablemaster.SelectActivePack)
            end)
            
            strictnessSlider = CreateFrame("Slider", nil, row, "OptionsSliderTemplate")
            strictnessSlider:SetSize(80, 20)
            strictnessSlider:SetPoint("RIGHT", row, "RIGHT", -50, 0)
            strictnessSlider:SetMinMaxValues(1, rule.includeWeapons and 13 or 11)
            strictnessSlider:SetValue(rule.strictness or 6)
            strictnessSlider:SetValueStep(1)
            strictnessSlider:SetObeyStepOnDrag(true)
            
            -- Add tooltip explaining strictness
            strictnessSlider:SetScript("OnEnter", function(self)
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetText("Transmog Strictness", 1, 1, 1, 1, true)
                local maxSlots = rule.includeWeapons and 13 or 11
                local slotType = rule.includeWeapons and "armor + weapon pieces" or "armor pieces"
                GameTooltip:AddLine("How many " .. slotType .. " must match for this rule to activate:", 1, 1, 0.8, true)
                GameTooltip:AddLine(" ")
                if rule.includeWeapons then
                    GameTooltip:AddLine("1-4: Very loose (any few pieces)", 0.8, 1, 0.8)
                    GameTooltip:AddLine("5-8: Moderate (most pieces)", 1, 1, 0.8)
                    GameTooltip:AddLine("9-11: Strict (almost all pieces)", 1, 0.8, 0.8)
                    GameTooltip:AddLine("12-13: Perfect (all/nearly all pieces)", 1, 0.6, 0.6)
                else
                    GameTooltip:AddLine("1-3: Very loose (any few pieces)", 0.8, 1, 0.8)
                    GameTooltip:AddLine("4-6: Moderate (most pieces)", 1, 1, 0.8)
                    GameTooltip:AddLine("7-9: Strict (almost all pieces)", 1, 0.8, 0.8)
                    GameTooltip:AddLine("10-11: Perfect (all/nearly all pieces)", 1, 0.6, 0.6)
                end
                GameTooltip:AddLine(" ")
                GameTooltip:AddLine("Current: " .. math.floor(self:GetValue()) .. " pieces must match", 1, 1, 1)
                GameTooltip:Show()
            end)
            strictnessSlider:SetScript("OnLeave", function() GameTooltip:Hide() end)
            
            -- Update the rule when slider changes
            strictnessSlider:SetScript("OnValueChanged", function(self, value)
                local newStrictness = math.floor(value)
                rule.strictness = newStrictness
                -- Update the display text
                local transmogName = rule.transmogName or "Custom Transmog"
                local weaponsText = rule.includeWeapons and " +Weapons" or ""
                text:SetText(string.format("Custom Transmog: %s\n(Strictness: %d%s)", transmogName, newStrictness, weaponsText))
                -- Re-evaluate packs
                C_Timer.After(0.1, Stablemaster.SelectActivePack)
                
                -- Update tooltip if it's showing
                if GameTooltip:IsOwned(self) then
                    GameTooltip:SetText("Transmog Strictness", 1, 1, 1, 1, true)
                    local slotType = rule.includeWeapons and "armor + weapon pieces" or "armor pieces"
                    GameTooltip:AddLine("How many " .. slotType .. " must match for this rule to activate:", 1, 1, 0.8, true)
                    GameTooltip:AddLine(" ")
                    if rule.includeWeapons then
                        GameTooltip:AddLine("1-4: Very loose (any few pieces)", 0.8, 1, 0.8)
                        GameTooltip:AddLine("5-8: Moderate (most pieces)", 1, 1, 0.8)
                        GameTooltip:AddLine("9-11: Strict (almost all pieces)", 1, 0.8, 0.8)
                        GameTooltip:AddLine("12-13: Perfect (all/nearly all pieces)", 1, 0.6, 0.6)
                    else
                        GameTooltip:AddLine("1-3: Very loose (any few pieces)", 0.8, 1, 0.8)
                        GameTooltip:AddLine("4-6: Moderate (most pieces)", 1, 1, 0.8)
                        GameTooltip:AddLine("7-9: Strict (almost all pieces)", 1, 0.8, 0.8)
                        GameTooltip:AddLine("10-11: Perfect (all/nearly all pieces)", 1, 0.6, 0.6)
                    end
                    GameTooltip:AddLine(" ")
                    GameTooltip:AddLine("Current: " .. newStrictness .. " pieces must match", 1, 1, 1)
                    GameTooltip:Show()
                end
            end)
        end

        local del = CreateFrame("Button", nil, row, "BackdropTemplate")
        del:SetSize(18, 18)
        del:SetPoint("RIGHT", row, "RIGHT", (strictnessSlider and weaponCheckbox) and -155 or -4, 0)
        StablemasterUI.CreateBackdrop(del, 0.4)

        local delText = del:CreateFontString(nil, "OVERLAY")
        delText:SetFont(STANDARD_TEXT_FONT, 11, "OUTLINE")
        delText:SetPoint("CENTER", 0, 0)
        delText:SetText("×")
        delText:SetTextColor(1, 0.4, 0.4, 1)

        del:SetScript("OnEnter", function(self)
            self:SetBackdropBorderColor(1, 0.4, 0.4, 1)
            delText:SetTextColor(1, 0.6, 0.6, 1)
        end)
        del:SetScript("OnLeave", function(self)
            self:SetBackdropBorderColor(unpack(STYLE.borderColor))
            delText:SetTextColor(1, 0.4, 0.4, 1)
        end)
        del:SetScript("OnClick", function()
            if Stablemaster.TableRemoveByIndex(pack.conditions, i) then
                Stablemaster.VerbosePrint("Removed rule.")
                RebuildRulesList(container, pack)
                -- Re-evaluate active packs since rules changed
                C_Timer.After(0.1, Stablemaster.SelectActivePack)
                -- Refresh the pack panel to show updated rule count
                if _G.StablemasterMainFrame and _G.StablemasterMainFrame.packPanel and _G.StablemasterMainFrame.packPanel.refreshPacks then
                    _G.StablemasterMainFrame.packPanel.refreshPacks()
                end
            end
        end)

        container.ruleRows[#container.ruleRows+1] = row
        row:Show() -- Explicitly show the row
        Stablemaster.Debug("Created rule row " .. i .. ": " .. text:GetText())
        -- Use different spacing based on row height
        y = y - (rowHeight + 2)
    end

    -- Update content height and manage scrollbar visibility
    local totalHeight = 20 -- Base padding
    for _, rule in ipairs(pack.conditions) do
        local isTwoLine = (rule.type == "custom_transmog") or (rule.type == "class" and rule.specIDs and #rule.specIDs > 0)
        local ruleHeight = isTwoLine and 37 or 26 -- Row height + spacing
        totalHeight = totalHeight + ruleHeight
    end
    local contentHeight = math.max(totalHeight, 1)
    container:SetHeight(contentHeight)
    
    -- Get the scroll frame (container's parent)
    local scrollFrame = container:GetParent()
    if scrollFrame and scrollFrame.ScrollBar then
        local scrollFrameHeight = scrollFrame:GetHeight()
        
        -- Show/hide scrollbar based on whether content exceeds visible area
        if contentHeight > scrollFrameHeight then
            scrollFrame.ScrollBar:Show()
        else
            scrollFrame.ScrollBar:Hide()
            -- Reset scroll position when scrollbar is hidden
            scrollFrame:SetVerticalScroll(0)
        end
    end
    
    Stablemaster.Debug("RebuildRulesList completed, created " .. #container.ruleRows .. " rule rows")
    
    -- Force a UI update to ensure everything renders
    if container.GetParent and container:GetParent() then
        local parent = container:GetParent()
        if parent.GetParent and parent:GetParent() then
            local grandparent = parent:GetParent()
            if grandparent.Show then
                -- Force the dialog to refresh its layout
                C_Timer.After(0.01, function()
                    container:Show()
                    if scrollFrame then scrollFrame:Show() end
                end)
            end
        end
    end
end

-- Public API
function StablemasterUI.ShowRulesDialog(pack)
    Stablemaster.Debug("ShowRulesDialog called for pack: " .. (pack and pack.name or "nil"))
    
    if not rulesDialog then
        Stablemaster.Debug("Creating new rules dialog")
        local dlg = CreateFrame("Frame", "StablemasterRulesDialog", UIParent, "BackdropTemplate")
        dlg:SetSize(420, 400)
        dlg:SetPoint("CENTER")
        dlg:SetMovable(true)
        dlg:EnableMouse(true)
        dlg:SetFrameStrata("DIALOG")
        StablemasterUI.CreateDialogBackdrop(dlg)

        -- Title bar
        local titleBar = StablemasterUI.CreateTitleBar(dlg, "Assign Rules")
        dlg.titleBar = titleBar

        table.insert(UISpecialFrames, "StablemasterRulesDialog")

        -- Header: pack name
        dlg.packNameText = StablemasterUI.CreateText(dlg, STYLE.fontSizeHeader, STYLE.textHeader)
        dlg.packNameText:SetPoint("TOPLEFT", dlg, "TOPLEFT", STYLE.padding, -STYLE.headerHeight - STYLE.padding)

        -- Current zone display
        local zoneLabel = StablemasterUI.CreateText(dlg, STYLE.fontSizeNormal, STYLE.textDim)
        zoneLabel:SetPoint("TOPLEFT", dlg.packNameText, "BOTTOMLEFT", 0, -12)
        zoneLabel:SetText("Current Zone:")

        local zoneText = StablemasterUI.CreateText(dlg, STYLE.fontSizeNormal, STYLE.accent)
        zoneText:SetPoint("LEFT", zoneLabel, "RIGHT", 8, 0)
        zoneText:SetText("Unknown")
        dlg.zoneText = zoneText

        -- "Match parent zones" checkbox (used by zone rules)
        local parentCheckContainer = StablemasterUI.CreateCheckbox(dlg, "Include parent zones when adding zone rules")
        parentCheckContainer:SetPoint("TOPLEFT", zoneLabel, "BOTTOMLEFT", 0, -8)
        local parentCheck = parentCheckContainer.check
        dlg.parentCheck = parentCheck

        -- Add Rule dropdown button
        local addRuleBtn = StablemasterUI.CreateButton(dlg, 100, STYLE.buttonHeight, "Add Rule")
        addRuleBtn:SetPoint("TOPLEFT", parentCheckContainer, "BOTTOMLEFT", 0, -12)

        -- Create dropdown menu frame
        local dropdownMenu = CreateFrame("Frame", "StablemasterAddRuleMenu", dlg, "UIDropDownMenuTemplate")

        local function InitializeDropdownMenu(self, level, menuList)
            local info = UIDropDownMenu_CreateInfo()

            if level == 1 then
                -- Location category
                info.text = "|cFF00FF96Location|r"
                info.isTitle = true
                info.notCheckable = true
                UIDropDownMenu_AddButton(info, level)

                info.isTitle = false
                info.disabled = false

                info.text = "Current Zone"
                info.notCheckable = true
                info.func = function()
                    if not dlg.targetPack then return end
                    local mapID = C_Map.GetBestMapForUnit("player")
                    if not mapID then
                        Stablemaster.Print("Could not determine current zone.")
                        return
                    end
                    EnsureConditions(dlg.targetPack)
                    table.insert(dlg.targetPack.conditions, {
                        type = "zone",
                        mapID = mapID,
                        includeParents = dlg.parentCheck:GetChecked() and true or false,
                    })
                    Stablemaster.VerbosePrint("Added zone rule.")
                    RebuildRulesList(dlg.rulesList, dlg.targetPack)
                    C_Timer.After(0.1, Stablemaster.SelectActivePack)
                    if _G.StablemasterMainFrame and _G.StablemasterMainFrame.packPanel and _G.StablemasterMainFrame.packPanel.refreshPacks then
                        _G.StablemasterMainFrame.packPanel.refreshPacks()
                    end
                    CloseDropDownMenus()
                end
                UIDropDownMenu_AddButton(info, level)

                info.text = "Browse Zones..."
                info.func = function()
                    CloseDropDownMenus()
                    if dlg.zonePicker then
                        dlg.zonePicker:Show()
                    else
                        dlg.zonePicker = StablemasterUI.CreateZonePicker(dlg)
                        dlg.zonePicker:Show()
                    end
                end
                UIDropDownMenu_AddButton(info, level)

                -- Separator
                info.text = ""
                info.isTitle = true
                info.notCheckable = true
                UIDropDownMenu_AddButton(info, level)

                -- Character category
                info.text = "|cFF00FF96Character|r"
                info.isTitle = true
                UIDropDownMenu_AddButton(info, level)

                info.isTitle = false
                info.disabled = false

                info.text = "Class / Spec..."
                info.func = function()
                    CloseDropDownMenus()
                    if dlg.classPicker then
                        dlg.classPicker:Show()
                    else
                        dlg.classPicker = StablemasterUI.CreateClassPicker(dlg)
                        dlg.classPicker:Show()
                    end
                end
                UIDropDownMenu_AddButton(info, level)

                info.text = "Race..."
                info.func = function()
                    CloseDropDownMenus()
                    if dlg.racePicker then
                        dlg.racePicker:Show()
                    else
                        dlg.racePicker = StablemasterUI.CreateRacePicker(dlg)
                        dlg.racePicker:Show()
                    end
                end
                UIDropDownMenu_AddButton(info, level)

                -- Separator
                info.text = ""
                info.isTitle = true
                UIDropDownMenu_AddButton(info, level)

                -- Appearance category
                info.text = "|cFF00FF96Appearance|r"
                info.isTitle = true
                UIDropDownMenu_AddButton(info, level)

                info.isTitle = false
                info.disabled = false

                info.text = "Outfit..."
                info.func = function()
                    CloseDropDownMenus()
                    if dlg.outfitPicker then
                        dlg.outfitPicker:Show()
                    else
                        dlg.outfitPicker = StablemasterUI.CreateOutfitPicker(dlg)
                        dlg.outfitPicker:Show()
                    end
                end
                UIDropDownMenu_AddButton(info, level)

                -- Separator
                info.text = ""
                info.isTitle = true
                UIDropDownMenu_AddButton(info, level)

                -- Time category
                info.text = "|cFF00FF96Times|r"
                info.isTitle = true
                UIDropDownMenu_AddButton(info, level)

                info.isTitle = false
                info.disabled = false

                info.text = "Time of Day..."
                info.func = function()
                    CloseDropDownMenus()
                    if dlg.timePicker then
                        dlg.timePicker:Show()
                    else
                        dlg.timePicker = StablemasterUI.CreateTimePicker(dlg)
                        dlg.timePicker:Show()
                    end
                end
                UIDropDownMenu_AddButton(info, level)

                info.text = "Holiday..."
                info.func = function()
                    CloseDropDownMenus()
                    if dlg.holidayPicker then
                        dlg.holidayPicker:Show()
                    else
                        dlg.holidayPicker = StablemasterUI.CreateHolidayPicker(dlg)
                        dlg.holidayPicker:Show()
                    end
                end
                UIDropDownMenu_AddButton(info, level)

                info.text = "Season..."
                info.func = function()
                    CloseDropDownMenus()
                    if dlg.seasonPicker then
                        dlg.seasonPicker:Show()
                    else
                        dlg.seasonPicker = StablemasterUI.CreateSeasonPicker(dlg)
                        dlg.seasonPicker:Show()
                    end
                end
                UIDropDownMenu_AddButton(info, level)
            end
        end

        UIDropDownMenu_Initialize(dropdownMenu, InitializeDropdownMenu, "MENU")

        addRuleBtn:SetScript("OnClick", function(self)
            ToggleDropDownMenu(1, nil, dropdownMenu, self, 0, 0)
        end)

        -- Rules list container
        local listLabel = StablemasterUI.CreateText(dlg, STYLE.fontSizeNormal, STYLE.textDim)
        listLabel:SetPoint("TOPLEFT", addRuleBtn, "BOTTOMLEFT", 0, -16)
        listLabel:SetText("Rules for this pack:")

        local rulesScroll = CreateFrame("ScrollFrame", nil, dlg, "UIPanelScrollFrameTemplate")
        rulesScroll:SetPoint("TOPLEFT", listLabel, "BOTTOMLEFT", 0, -6)
        rulesScroll:SetPoint("BOTTOMRIGHT", dlg, "BOTTOMRIGHT", -26, STYLE.padding)

        -- Style the scrollbar
        if rulesScroll.ScrollBar then
            local scrollBar = rulesScroll.ScrollBar
            if scrollBar.ScrollUpButton then
                scrollBar.ScrollUpButton:SetAlpha(0)
                scrollBar.ScrollUpButton:EnableMouse(false)
            end
            if scrollBar.ScrollDownButton then
                scrollBar.ScrollDownButton:SetAlpha(0)
                scrollBar.ScrollDownButton:EnableMouse(false)
            end
            if scrollBar.ThumbTexture then
                scrollBar.ThumbTexture:SetTexture(STYLE.bgTexture)
                scrollBar.ThumbTexture:SetVertexColor(unpack(STYLE.accent))
                scrollBar.ThumbTexture:SetSize(6, 40)
            end
        end

        local rulesContent = CreateFrame("Frame", nil, rulesScroll)
        rulesContent:SetSize(360, 1)
        rulesScroll:SetScrollChild(rulesContent)
        dlg.rulesList = rulesContent

        -- Initially hide the scrollbar
        if rulesScroll.ScrollBar then
            rulesScroll.ScrollBar:Hide()
        end

        -- Zone change event handler for immediate updates
        local function OnZoneChanged()
            if dlg:IsShown() then
                UpdateZoneDisplay(dlg)
            end
        end
        
        -- OnShow: refresh current zone and transmog info and list
        dlg:SetScript("OnShow", function(self)
            Stablemaster.Debug("Rules dialog OnShow called")
            
            -- Update zone display using the robust zone detection
            UpdateZoneDisplay(self)
            
            -- Additional zone update attempts for UI reload scenarios
            C_Timer.After(1, function()
                if self:IsShown() then
                    UpdateZoneDisplay(self)
                end
            end)
            C_Timer.After(3, function()
                if self:IsShown() then
                    UpdateZoneDisplay(self)
                end
            end)

            if self.targetPack then
                Stablemaster.Debug("Target pack found: " .. self.targetPack.name)
                self.packNameText:SetText(self.targetPack.name)
                RebuildRulesList(self.rulesList, self.targetPack)
            else
                Stablemaster.Debug("No target pack found!")
            end
            
            -- Register for zone change events when dialog is shown
            if not self.zoneEventFrame then
                self.zoneEventFrame = CreateFrame("Frame")
                self.zoneEventFrame:SetScript("OnEvent", function(frame, event, ...)
                    OnZoneChanged()
                end)
            end
            
            -- Register zone change events
            self.zoneEventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
            self.zoneEventFrame:RegisterEvent("ZONE_CHANGED")
            self.zoneEventFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
            self.zoneEventFrame:RegisterEvent("ZONE_CHANGED_INDOORS")
            
            -- Set up periodic zone updates while dialog is open (as fallback)
            if not self.zoneUpdateTimer then
                self.zoneUpdateTimer = C_Timer.NewTicker(5, function()
                    if self:IsShown() then
                        UpdateZoneDisplay(self)
                    end
                end)
            end
        end)
        
        -- OnHide: clean up the zone update timer and event handlers
        dlg:SetScript("OnHide", function(self)
            if self.zoneUpdateTimer then
                self.zoneUpdateTimer:Cancel()
                self.zoneUpdateTimer = nil
            end
            
            -- Unregister zone change events when dialog is hidden
            if self.zoneEventFrame then
                self.zoneEventFrame:UnregisterEvent("PLAYER_ENTERING_WORLD")
                self.zoneEventFrame:UnregisterEvent("ZONE_CHANGED")
                self.zoneEventFrame:UnregisterEvent("ZONE_CHANGED_NEW_AREA")
                self.zoneEventFrame:UnregisterEvent("ZONE_CHANGED_INDOORS")
            end
        end)

        rulesDialog = dlg
    end

    Stablemaster.Debug("Setting target pack and showing dialog")
    rulesDialog.targetPack = pack

    -- Move to end of UISpecialFrames so ESC closes this dialog first
    for i, name in ipairs(UISpecialFrames) do
        if name == "StablemasterRulesDialog" then
            table.remove(UISpecialFrames, i)
            break
        end
    end
    table.insert(UISpecialFrames, "StablemasterRulesDialog")

    rulesDialog:Show()
    
    -- Force initial zone detection and rules list update if this is the first time showing
    -- (OnShow might not fire on initial creation, and we need zone detection before RebuildRulesList)
    if pack then
        C_Timer.After(0.01, function()
            if rulesDialog.targetPack and rulesDialog:IsShown() then
                Stablemaster.Debug("Forcing initial zone detection and RebuildRulesList")
                -- Run zone detection first
                UpdateZoneDisplay(rulesDialog)
                -- Then rebuild the rules list
                RebuildRulesList(rulesDialog.rulesList, rulesDialog.targetPack)
            end
        end)
        
        -- Additional update after a longer delay to handle cases where zone info takes time to become available
        C_Timer.After(1, function()
            if rulesDialog.targetPack and rulesDialog:IsShown() then
                Stablemaster.Debug("Secondary zone detection update")
                UpdateZoneDisplay(rulesDialog)
            end
        end)
    end
end

-- Zone Picker Dialog
function StablemasterUI.CreateZonePicker(parentDialog)
    local picker = CreateFrame("Frame", "StablemasterZonePicker", UIParent, "BackdropTemplate")
    picker:SetSize(450, 400)
    picker:SetPoint("CENTER", parentDialog, "CENTER", 50, 0)
    picker:SetMovable(true)
    picker:EnableMouse(true)
    picker:EnableKeyboard(true)
    picker:SetFrameStrata("FULLSCREEN_DIALOG")
    picker:SetFrameLevel(parentDialog:GetFrameLevel() + 1)
    StablemasterUI.CreateDialogBackdrop(picker)

    -- Intercept ESC to close just this dialog
    picker:SetScript("OnKeyDown", function(self, key)
        if key == "ESCAPE" then
            self:Hide()
            self:SetPropagateKeyboardInput(false)
        else
            self:SetPropagateKeyboardInput(true)
        end
    end)

    -- Title bar
    local titleBar = StablemasterUI.CreateTitleBar(picker, "Select Zone")
    picker.titleBar = titleBar

    -- Search box
    local searchLabel = StablemasterUI.CreateText(picker, STYLE.fontSizeNormal, STYLE.textDim)
    searchLabel:SetPoint("TOPLEFT", picker, "TOPLEFT", STYLE.padding, -STYLE.headerHeight - STYLE.padding)
    searchLabel:SetText("Search:")

    local searchBox = StablemasterUI.CreateEditBox(picker, 200, 24)
    searchBox:SetPoint("LEFT", searchLabel, "RIGHT", 10, 0)
    searchBox:SetMaxLetters(50)

    -- Zone list scroll frame
    local zoneScroll = CreateFrame("ScrollFrame", nil, picker, "UIPanelScrollFrameTemplate")
    zoneScroll:SetPoint("TOPLEFT", searchLabel, "BOTTOMLEFT", 0, -10)
    zoneScroll:SetPoint("BOTTOMRIGHT", picker, "BOTTOMRIGHT", -26, 45)

    local zoneContent = CreateFrame("Frame", nil, zoneScroll)
    zoneContent:SetSize(380, 1)
    zoneScroll:SetScrollChild(zoneContent)

    -- Add Zone button
    local addBtn = StablemasterUI.CreateButton(picker, 80, STYLE.buttonHeight, "Add Zone")
    addBtn:SetPoint("BOTTOMRIGHT", picker, "BOTTOMRIGHT", -STYLE.padding, STYLE.padding)
    addBtn:SetEnabled(false)

    -- Cancel button
    local cancelBtn = StablemasterUI.CreateButton(picker, 80, STYLE.buttonHeight, "Cancel")
    cancelBtn:SetPoint("RIGHT", addBtn, "LEFT", -8, 0)
    cancelBtn:SetScript("OnClick", function() picker:Hide() end)

    -- Store state
    picker.selectedMapID = nil
    picker.zoneButtons = {}

    -- Function to populate zone list
    local function PopulateZoneList(searchText)
        -- Clear existing buttons
        for _, btn in ipairs(picker.zoneButtons) do
            btn:Hide()
            btn:SetParent(nil)
        end
        picker.zoneButtons = {}

        -- Store expanded state
        picker.expandedContinents = picker.expandedContinents or {}

        -- Get continent data with nested zones
        local continentData = {}
        
        -- Try multiple approaches to get all continents
        local potentialContinents = {}
        
        -- Method 1: Get from Cosmic map (946)
        local cosmicChildren = C_Map.GetMapChildrenInfo(946, Enum.UIMapType.Continent)
        if cosmicChildren then
            for _, continent in ipairs(cosmicChildren) do
                potentialContinents[continent.mapID] = continent
            end
        end
        
        -- Method 2: Try other potential parent maps
        local otherParents = {946, 947} -- Cosmic and any other top-level maps
        for _, parentID in ipairs(otherParents) do
            local children = C_Map.GetMapChildrenInfo(parentID, Enum.UIMapType.Continent)
            if children then
                for _, continent in ipairs(children) do
                    potentialContinents[continent.mapID] = continent
                end
            end
        end
        
        -- Method 3: Add known major continents manually (comprehensive list)
        local knownContinents = {
            {mapID = 12, name = "Kalimdor"}, -- Classic Kalimdor
            {mapID = 13, name = "Eastern Kingdoms"}, -- Classic EK
            {mapID = 101, name = "Outland"}, -- BC
            {mapID = 113, name = "Northrend"}, -- Wrath
            {mapID = 424, name = "Pandaria"}, -- MoP
            {mapID = 572, name = "Draenor"}, -- WoD
            {mapID = 619, name = "Broken Isles"}, -- Legion
            {mapID = 875, name = "Zandalar"}, -- BfA Horde
            {mapID = 876, name = "Kul Tiras"}, -- BfA Alliance
            {mapID = 1550, name = "The Shadowlands"}, -- Shadowlands
            {mapID = 1978, name = "Dragon Isles"}, -- Dragonflight
            {mapID = 2274, name = "Khaz Algar"}, -- The War Within
        }
        
        for _, continent in ipairs(knownContinents) do
            -- Verify the continent exists and get the actual name from the API
            local mapInfo = C_Map.GetMapInfo(continent.mapID)
            if mapInfo then
                potentialContinents[continent.mapID] = {
                    mapID = continent.mapID,
                    name = mapInfo.name -- Use the real name from the API
                }
            end
        end
        
        -- Method 4: Try to discover unknown continents by scanning a range
        -- This helps catch new continents that aren't in our hard-coded list
        local scanRanges = {
            {1, 50}, -- Classic range
            {100, 200}, -- BC range  
            {400, 500}, -- MoP range
            {550, 650}, -- WoD/Legion range
            {850, 950}, -- BfA range
            {1500, 1600}, -- Shadowlands range
            {1950, 2050}, -- Dragonflight range
            {2200, 2500}, -- War Within range (expanded for newer zones)
        }
        
        for _, range in ipairs(scanRanges) do
            for mapID = range[1], range[2] do
                local mapInfo = C_Map.GetMapInfo(mapID)
                if mapInfo and mapInfo.mapType == Enum.UIMapType.Continent then
                    potentialContinents[mapID] = {
                        mapID = mapID,
                        name = mapInfo.name
                    }
                end
            end
        end
        
        -- Build continent data with zones
        local continentsByName = {} -- Track by name to avoid duplicates
        
        for _, continent in pairs(potentialContinents) do
            -- Skip if we already have a continent with this exact name
            if continentsByName[continent.name] then
                local existing = continentsByName[continent.name]
                -- Keep the one with more zones, or lower ID if zone count is equal
                local existingZoneCount = #(existing.zones or {})
                
                -- Get zone count for this continent
                local zones = {}
                local standardZones = C_Map.GetMapChildrenInfo(continent.mapID, Enum.UIMapType.Zone)
                if standardZones then
                    zones = standardZones
                end
                
                -- For newer continents, also scan manually
                if continent.mapID >= 2200 then
                    local startRange = continent.mapID + 1
                    local endRange = continent.mapID + 300
                    
                    for zoneID = startRange, endRange do
                        local zoneInfo = C_Map.GetMapInfo(zoneID)
                        if zoneInfo and zoneInfo.mapType == Enum.UIMapType.Zone then
                            local parentInfo = zoneInfo.parentMapID and C_Map.GetMapInfo(zoneInfo.parentMapID)
                            if parentInfo and parentInfo.mapID == continent.mapID then
                                local alreadyExists = false
                                for _, existingZone in ipairs(zones) do
                                    if existingZone.mapID == zoneID then
                                        alreadyExists = true
                                        break
                                    end
                                end
                                if not alreadyExists then
                                    zones[#zones + 1] = {
                                        mapID = zoneID,
                                        name = zoneInfo.name
                                    }
                                end
                            end
                        end
                    end
                end
                
                local thisZoneCount = #zones
                
                -- Replace existing if this one has more zones, or same zones but lower ID
                if thisZoneCount > existingZoneCount or 
                   (thisZoneCount == existingZoneCount and continent.mapID < existing.mapID) then
                    continentsByName[continent.name] = {
                        mapID = continent.mapID,
                        name = continent.name,
                        type = "Continent",
                        zones = zones
                    }
                end
                -- Skip processing this duplicate (don't add to continentData)
            else
                -- This is a new continent name, process normally
                local zones = {}
                
                -- Method 1: Standard zone query
                local standardZones = C_Map.GetMapChildrenInfo(continent.mapID, Enum.UIMapType.Zone)
                if standardZones then
                    for _, zone in ipairs(standardZones) do
                        zones[#zones + 1] = zone
                    end
                end
                
                -- Method 2: For newer continents, scan for zones in nearby ID ranges
                if continent.mapID >= 2200 then -- War Within and future expansions
                    local startRange = continent.mapID + 1
                    local endRange = continent.mapID + 300 -- Scan 300 IDs after the continent
                    
                    for zoneID = startRange, endRange do
                        local zoneInfo = C_Map.GetMapInfo(zoneID)
                        if zoneInfo and zoneInfo.mapType == Enum.UIMapType.Zone then
                            -- Check if this zone's parent is our continent
                            local parentInfo = zoneInfo.parentMapID and C_Map.GetMapInfo(zoneInfo.parentMapID)
                            if parentInfo and parentInfo.mapID == continent.mapID then
                                -- Add this zone if we don't already have it
                                local alreadyExists = false
                                for _, existingZone in ipairs(zones) do
                                    if existingZone.mapID == zoneID then
                                        alreadyExists = true
                                        break
                                    end
                                end
                                if not alreadyExists then
                                    zones[#zones + 1] = {
                                        mapID = zoneID,
                                        name = zoneInfo.name
                                    }
                                end
                            end
                        end
                    end
                end
                
                continentsByName[continent.name] = {
                    mapID = continent.mapID,
                    name = continent.name,
                    type = "Continent",
                    zones = zones
                }
            end
        end
        
        -- Convert back to array
        local continentData = {}
        for _, continent in pairs(continentsByName) do
            table.insert(continentData, continent)
        end

        -- Sort continents by name
        table.sort(continentData, function(a, b) return a.name < b.name end)

        -- Build display list based on search and expansion state
        local displayItems = {}
        searchText = searchText and string.lower(searchText) or ""

        for _, continent in ipairs(continentData) do
            local continentMatches = (searchText == "" or string.find(string.lower(continent.name), searchText))
            local hasMatchingZones = false
            
            -- Check if any zones match search
            local matchingZones = {}
            for _, zone in ipairs(continent.zones) do
                if searchText == "" or string.find(string.lower(zone.name), searchText) then
                    hasMatchingZones = true
                    table.insert(matchingZones, zone)
                end
            end
            
            -- Sort matching zones
            table.sort(matchingZones, function(a, b) return a.name < b.name end)
            
            -- Add continent if it matches or has matching zones
            if continentMatches or hasMatchingZones then
                table.insert(displayItems, {
                    mapID = continent.mapID,
                    name = continent.name,
                    type = "Continent",
                    level = 0,
                    isExpanded = picker.expandedContinents[continent.mapID]
                })
                
                -- Add zones if continent is expanded or we're searching
                if picker.expandedContinents[continent.mapID] or searchText ~= "" then
                    for _, zone in ipairs(matchingZones) do
                        table.insert(displayItems, {
                            mapID = zone.mapID,
                            name = zone.name,
                            type = "Zone",
                            level = 1,
                            parentID = continent.mapID
                        })
                    end
                end
            end
        end

        -- Create buttons for display items
        for i, item in ipairs(displayItems) do
            local btn = CreateFrame("Button", nil, zoneContent, "BackdropTemplate")
            btn:SetSize(360, 25)
            btn:SetPoint("TOPLEFT", zoneContent, "TOPLEFT", 0, -(i-1) * 27)
            StablemasterUI.CreateBackdrop(btn, 0.6)

            -- Indent based on level
            local indent = item.level * 20

            -- Expand/collapse icon for continents
            local expandIcon = nil
            if item.type == "Continent" then
                expandIcon = btn:CreateTexture(nil, "OVERLAY")
                expandIcon:SetSize(12, 12)
                expandIcon:SetPoint("LEFT", btn, "LEFT", indent + 4, 0)
                if item.isExpanded then
                    expandIcon:SetTexture("Interface\\Buttons\\UI-MinusButton-Up")
                else
                    expandIcon:SetTexture("Interface\\Buttons\\UI-PlusButton-Up")
                end
                btn.expandIcon = expandIcon
                indent = indent + 16 -- Make room for the icon
            end

            local text = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            text:SetPoint("LEFT", btn, "LEFT", indent + 8, 0)
            text:SetPoint("RIGHT", btn, "RIGHT", -30, 0)
            text:SetJustifyH("LEFT")
            
            -- Different display for continents vs zones
            if item.type == "Continent" then
                text:SetText(item.name .. " (Continent)")
                text:SetTextColor(1, 1, 0.6, 1) -- Yellow for continents
            else
                text:SetText(item.name)
                text:SetTextColor(1, 1, 1, 1) -- White for zones
            end

            -- ID display
            local idText = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            idText:SetPoint("RIGHT", btn, "RIGHT", -8, 0)
            idText:SetText(tostring(item.mapID))
            idText:SetTextColor(0.6, 0.6, 0.6, 1)

            -- Store item data
            btn.itemData = item

            -- Click handler - BOTH continents and zones are now selectable
            btn:SetScript("OnClick", function()
                -- Clear previous selection
                if picker.selectedButton then
                    picker.selectedButton:SetBackdropColor(0.1, 0.1, 0.1, 0.8)
                end
                
                -- Select this item (continent or zone)
                picker.selectedMapID = item.mapID
                picker.selectedButton = btn
                btn:SetBackdropColor(0.2, 0.4, 0.2, 0.8) -- Green selection
                addBtn:SetEnabled(true)
            end)

            -- Right-click for continents expands/collapses (alternative to left-click selection)
            if item.type == "Continent" then
                btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
                btn:SetScript("OnClick", function(self, mouseButton)
                    if mouseButton == "RightButton" then
                        -- Right-click: Toggle expansion
                        picker.expandedContinents[item.mapID] = not picker.expandedContinents[item.mapID]
                        PopulateZoneList(searchBox:GetText())
                    else
                        -- Left-click: Select continent
                        if picker.selectedButton then
                            picker.selectedButton:SetBackdropColor(0.1, 0.1, 0.1, 0.8)
                        end
                        picker.selectedMapID = item.mapID
                        picker.selectedButton = btn
                        btn:SetBackdropColor(0.2, 0.4, 0.2, 0.8) -- Green selection
                        addBtn:SetEnabled(true)
                    end
                end)
            end

            -- Hover effects
            btn:SetScript("OnEnter", function(self)
                if self ~= picker.selectedButton then
                    if item.type == "Continent" then
                        self:SetBackdropColor(0.15, 0.15, 0.2, 0.8) -- Slightly different hover for continents
                    else
                        self:SetBackdropColor(0.2, 0.2, 0.2, 0.8)
                    end
                end
                
                -- Show tooltip for continents explaining the click behavior
                if item.type == "Continent" then
                    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                    GameTooltip:SetText("Left-click: Select entire continent")
                    GameTooltip:AddLine("Right-click: Expand/collapse zones", 0.8, 0.8, 0.8)
                    GameTooltip:Show()
                end
            end)
            btn:SetScript("OnLeave", function(self)
                if self ~= picker.selectedButton then
                    self:SetBackdropColor(0.1, 0.1, 0.1, 0.8)
                end
                GameTooltip:Hide()
            end)

            picker.zoneButtons[i] = btn
        end

        -- Update content height
        local contentHeight = math.max(#displayItems * 27, 1)
        zoneContent:SetHeight(contentHeight)

        -- Manage scrollbar
        if zoneScroll.ScrollBar then
            if contentHeight > zoneScroll:GetHeight() then
                zoneScroll.ScrollBar:Show()
            else
                zoneScroll.ScrollBar:Hide()
                zoneScroll:SetVerticalScroll(0)
            end
        end
    end

    -- Search functionality
    searchBox:SetScript("OnTextChanged", function(self)
        PopulateZoneList(self:GetText())
    end)

    -- Add button functionality
    addBtn:SetScript("OnClick", function()
        if picker.selectedMapID and parentDialog.targetPack then
            EnsureConditions(parentDialog.targetPack)
            table.insert(parentDialog.targetPack.conditions, {
                type = "zone",
                mapID = picker.selectedMapID,
                includeParents = parentDialog.parentCheck:GetChecked() and true or false,
            })
            
            local mapInfo = C_Map.GetMapInfo(picker.selectedMapID)
            local zoneName = mapInfo and mapInfo.name or ("MapID " .. picker.selectedMapID)
            Stablemaster.VerbosePrint("Added zone rule: " .. zoneName)
            
            RebuildRulesList(parentDialog.rulesList, parentDialog.targetPack)
            C_Timer.After(0.1, Stablemaster.SelectActivePack)
            -- Refresh the pack panel to show updated rule count
            if _G.StablemasterMainFrame and _G.StablemasterMainFrame.packPanel and _G.StablemasterMainFrame.packPanel.refreshPacks then
                _G.StablemasterMainFrame.packPanel.refreshPacks()
            end
            picker:Hide()
        end
    end)

    -- OnShow: populate list and reset selection
    picker:SetScript("OnShow", function(self)
        -- Move to end of UISpecialFrames so ESC closes this dialog first
        for i, name in ipairs(UISpecialFrames) do
            if name == "StablemasterZonePicker" then
                table.remove(UISpecialFrames, i)
                break
            end
        end
        table.insert(UISpecialFrames, "StablemasterZonePicker")

        self.selectedMapID = nil
        self.selectedButton = nil
        addBtn:SetEnabled(false)
        searchBox:SetText("")
        PopulateZoneList("")
    end)

    picker:Hide()
    table.insert(UISpecialFrames, "StablemasterZonePicker")
    return picker
end

-- Transmog Set Picker Dialog
function StablemasterUI.CreateTransmogPicker(parentDialog)
    local picker = CreateFrame("Frame", "StablemasterTransmogPicker", UIParent, "BackdropTemplate")
    picker:SetSize(500, 450)
    picker:SetPoint("CENTER", parentDialog, "CENTER", 60, 0)
    picker:SetMovable(true)
    picker:EnableMouse(true)
    picker:EnableKeyboard(true)
    picker:SetFrameStrata("FULLSCREEN_DIALOG")
    picker:SetFrameLevel(parentDialog:GetFrameLevel() + 1)
    StablemasterUI.CreateDialogBackdrop(picker)

    -- Intercept ESC to close just this dialog
    picker:SetScript("OnKeyDown", function(self, key)
        if key == "ESCAPE" then
            self:Hide()
            self:SetPropagateKeyboardInput(false)
        else
            self:SetPropagateKeyboardInput(true)
        end
    end)

    -- Title bar
    local titleBar = StablemasterUI.CreateTitleBar(picker, "Select Transmog Set")
    picker.titleBar = titleBar

    -- Search box
    local searchLabel = StablemasterUI.CreateText(picker, STYLE.fontSizeNormal, STYLE.text)
    searchLabel:SetPoint("TOPLEFT", picker, "TOPLEFT", STYLE.padding, -STYLE.headerHeight - STYLE.padding)
    searchLabel:SetText("Search:")

    local searchBox = StablemasterUI.CreateEditBox(picker, 200, 22)
    searchBox:SetPoint("LEFT", searchLabel, "RIGHT", 10, 0)
    searchBox:SetMaxLetters(50)

    -- Filter dropdown for expansions
    local filterLabel = StablemasterUI.CreateText(picker, STYLE.fontSizeNormal, STYLE.text)
    filterLabel:SetPoint("LEFT", searchBox, "RIGHT", 20, 0)
    filterLabel:SetText("Expansion:")

    local expansionFilter = CreateFrame("Frame", nil, picker, "UIDropDownMenuTemplate")
    expansionFilter:SetPoint("LEFT", filterLabel, "RIGHT", 5, -2)
    expansionFilter:SetSize(120, 20)

    -- Collection filter
    local collectedCheck = CreateFrame("CheckButton", nil, picker, "UICheckButtonTemplate")
    collectedCheck:SetPoint("TOPLEFT", searchLabel, "BOTTOMLEFT", 0, -10)
    collectedCheck.text = collectedCheck:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    collectedCheck.text:SetPoint("LEFT", collectedCheck, "RIGHT", 5, 0)
    collectedCheck.text:SetText("Show only collected sets")
    collectedCheck:SetChecked(true) -- Default to collected only

    -- Transmog set list
    local setScroll = CreateFrame("ScrollFrame", nil, picker, "UIPanelScrollFrameTemplate")
    setScroll:SetPoint("TOPLEFT", collectedCheck, "BOTTOMLEFT", 0, -15)
    setScroll:SetPoint("BOTTOMRIGHT", picker, "BOTTOMRIGHT", -50, 50)

    local setContent = CreateFrame("Frame", nil, setScroll)
    setContent:SetSize(430, 1)
    setScroll:SetScrollChild(setContent)

    -- Add Set button
    local addBtn = StablemasterUI.CreateButton(picker, 80, STYLE.buttonHeight, "Add Set")
    addBtn:SetPoint("BOTTOMRIGHT", picker, "BOTTOMRIGHT", -STYLE.padding, STYLE.padding)
    addBtn:SetEnabled(false)

    -- Apply Set button
    local applyBtn = StablemasterUI.CreateButton(picker, 80, STYLE.buttonHeight, "Apply Set")
    applyBtn:SetPoint("RIGHT", addBtn, "LEFT", -8, 0)
    applyBtn:SetEnabled(false)
    
    -- Tooltip for apply button
    applyBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Apply Transmog Set", 1, 1, 1, 1, true)
        if picker.selectedSetID then
            local setInfo = Stablemaster.GetTransmogSetInfo(picker.selectedSetID)
            local setName = setInfo and setInfo.name or ("Set " .. picker.selectedSetID)
            if C_Transmog.IsAtTransmogNPC() then
                GameTooltip:AddLine("Apply '" .. setName .. "' immediately.", 1, 1, 0.8, true)
            else
                GameTooltip:AddLine("Must be at a transmog vendor.", 1, 0.5, 0.5, true)
                GameTooltip:AddLine("Set: " .. setName, 0.8, 0.8, 1, true)
            end
        else
            GameTooltip:AddLine("Select a set first.", 0.8, 0.8, 0.8, true)
        end
        GameTooltip:Show()
    end)
    applyBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
    
    -- Apply button click handler
    applyBtn:SetScript("OnClick", function()
        if not picker.selectedSetID then
            Stablemaster.Print("Please select a transmog set first")
            return
        end
        
        if not C_Transmog.IsAtTransmogNPC() then
            Stablemaster.Print("Must be at a transmog vendor to apply sets")
            return
        end
        
        local success, message = Stablemaster.ApplyTransmogSet(picker.selectedSetID)
        Stablemaster.Print(message)
        
        if success then
            picker:Hide()
        end
    end)

    -- Cancel button
    local cancelBtn = StablemasterUI.CreateButton(picker, 80, STYLE.buttonHeight, "Cancel")
    cancelBtn:SetPoint("RIGHT", applyBtn, "LEFT", -8, 0)
    cancelBtn:SetScript("OnClick", function() picker:Hide() end)

    -- Store state
    picker.selectedSetID = nil
    picker.setButtons = {}

    -- Expansion names for filter
    local expansionNames = {
        [0] = "Classic",
        [1] = "Burning Crusade", 
        [2] = "Wrath of the Lich King",
        [3] = "Cataclysm",
        [4] = "Mists of Pandaria",
        [5] = "Warlords of Draenor",
        [6] = "Legion",
        [7] = "Battle for Azeroth",
        [8] = "Shadowlands",
        [9] = "Dragonflight",
        [10] = "The War Within"
    }

    -- Initialize expansion filter dropdown
    local function InitializeExpansionDropdown(self, level)
        local info = UIDropDownMenu_CreateInfo()
        if level == 1 then
            info.text = "All Expansions"
            info.value = -1
            info.func = function()
                UIDropDownMenu_SetSelectedValue(expansionFilter, -1)
                PopulateSetList()
            end
            info.checked = UIDropDownMenu_GetSelectedValue(expansionFilter) == -1
            UIDropDownMenu_AddButton(info)

            -- Add expansion options
            for expID = 0, 10 do
                if expansionNames[expID] then
                    info.text = expansionNames[expID]
                    info.value = expID
                    info.func = function()
                        UIDropDownMenu_SetSelectedValue(expansionFilter, expID)
                        PopulateSetList()
                    end
                    info.checked = UIDropDownMenu_GetSelectedValue(expansionFilter) == expID
                    UIDropDownMenu_AddButton(info)
                end
            end
        end
    end

    UIDropDownMenu_Initialize(expansionFilter, InitializeExpansionDropdown)
    UIDropDownMenu_SetSelectedValue(expansionFilter, -1)
    UIDropDownMenu_SetText(expansionFilter, "All")
    UIDropDownMenu_SetWidth(expansionFilter, 100)

    -- Function to populate transmog set list
    function PopulateSetList()
        -- Clear existing buttons
        for _, btn in ipairs(picker.setButtons) do
            btn:Hide()
            btn:SetParent(nil)
        end
        picker.setButtons = {}

        -- Get filter values
        local searchText = string.lower(searchBox:GetText() or "")
        local selectedExpansion = UIDropDownMenu_GetSelectedValue(expansionFilter) or -1
        local collectedOnly = collectedCheck:GetChecked()

        -- Get all transmog sets
        local allSets = Stablemaster.GetAllTransmogSets()
        local filteredSets = {}

        for _, setData in ipairs(allSets) do
            local include = true

            -- Apply filters
            if searchText ~= "" and not string.find(string.lower(setData.name), searchText) then
                include = false
            end

            if selectedExpansion >= 0 and setData.expansionID ~= selectedExpansion then
                include = false
            end

            if collectedOnly and not setData.collected then
                include = false
            end

            if include then
                table.insert(filteredSets, setData)
            end
        end

        -- Create buttons for filtered sets
        for i, setData in ipairs(filteredSets) do
            local btn = CreateFrame("Button", nil, setContent, "BackdropTemplate")
            btn:SetSize(410, 30)
            btn:SetPoint("TOPLEFT", setContent, "TOPLEFT", 0, -(i-1) * 32)
            StablemasterUI.CreateBackdrop(btn, 0.6)

            -- Set name
            local nameText = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            nameText:SetPoint("LEFT", btn, "LEFT", 8, 0)
            nameText:SetPoint("RIGHT", btn, "RIGHT", -120, 0)
            nameText:SetJustifyH("LEFT")
            nameText:SetText(setData.name)
            
            if setData.collected then
                nameText:SetTextColor(1, 1, 1, 1)
            else
                nameText:SetTextColor(0.6, 0.6, 0.6, 1)
            end

            -- Expansion name
            local expText = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            expText:SetPoint("RIGHT", btn, "RIGHT", -40, 0)
            expText:SetText(expansionNames[setData.expansionID] or "Unknown")
            expText:SetTextColor(0.8, 0.8, 0.8, 1)

            -- Set ID
            local idText = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            idText:SetPoint("RIGHT", btn, "RIGHT", -8, 0)
            idText:SetText(tostring(setData.setID))
            idText:SetTextColor(0.6, 0.6, 0.6, 1)

            -- Store set data
            btn.setData = setData

            -- Click handler
            btn:SetScript("OnClick", function()
                -- Clear previous selection
                if picker.selectedButton then
                    picker.selectedButton:SetBackdropColor(0.1, 0.1, 0.1, 0.8)
                end

                -- Select this set
                picker.selectedSetID = setData.setID
                picker.selectedButton = btn
                btn:SetBackdropColor(0.2, 0.4, 0.2, 0.8)
                addBtn:SetEnabled(true)
                applyBtn:SetEnabled(true)
            end)

            -- Hover effects
            btn:SetScript("OnEnter", function(self)
                if self ~= picker.selectedButton then
                    self:SetBackdropColor(0.2, 0.2, 0.2, 0.8)
                end
                
                -- Show set preview in tooltip
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetText(setData.name, 1, 1, 1)
                if expansionNames[setData.expansionID] then
                    GameTooltip:AddLine(expansionNames[setData.expansionID], 0.8, 0.8, 0.8)
                end
                GameTooltip:AddLine("Set ID: " .. setData.setID, 0.6, 0.6, 0.6)
                if setData.collected then
                    GameTooltip:AddLine("Collected", 0.5, 1, 0.5)
                else
                    GameTooltip:AddLine("Not collected", 1, 0.5, 0.5)
                end
                GameTooltip:Show()
            end)

            btn:SetScript("OnLeave", function(self)
                if self ~= picker.selectedButton then
                    self:SetBackdropColor(0.1, 0.1, 0.1, 0.8)
                end
                GameTooltip:Hide()
            end)

            picker.setButtons[i] = btn
        end

        -- Update content height
        local contentHeight = math.max(#filteredSets * 32, 1)
        setContent:SetHeight(contentHeight)

        -- Manage scrollbar
        if setScroll.ScrollBar then
            if contentHeight > setScroll:GetHeight() then
                setScroll.ScrollBar:Show()
            else
                setScroll.ScrollBar:Hide()
                setScroll:SetVerticalScroll(0)
            end
        end
    end

    -- Search functionality
    searchBox:SetScript("OnTextChanged", function(self)
        PopulateSetList()
    end)

    -- Collection filter
    collectedCheck:SetScript("OnClick", function(self)
        PopulateSetList()
    end)

    -- Add button functionality
    addBtn:SetScript("OnClick", function()
        if picker.selectedSetID and parentDialog.targetPack then
            EnsureConditions(parentDialog.targetPack)
            table.insert(parentDialog.targetPack.conditions, {
                type = "transmog",
                setID = picker.selectedSetID,
                priority = StablemasterDB.settings.rulePriorities.transmog or 100,
            })

            local setInfo = Stablemaster.GetTransmogSetInfo(picker.selectedSetID)
            local setName = setInfo and setInfo.name or ("Set " .. picker.selectedSetID)
            Stablemaster.VerbosePrint("Added transmog rule: " .. setName)

            RebuildRulesList(parentDialog.rulesList, parentDialog.targetPack)
            C_Timer.After(0.1, Stablemaster.SelectActivePack)
            
            -- Refresh pack panel
            if _G.StablemasterMainFrame and _G.StablemasterMainFrame.packPanel and _G.StablemasterMainFrame.packPanel.refreshPacks then
                _G.StablemasterMainFrame.packPanel.refreshPacks()
            end
            
            picker:Hide()
        end
    end)

    -- OnShow: populate list and reset selection
    picker:SetScript("OnShow", function(self)
        -- Move to end of UISpecialFrames so ESC closes this dialog first
        for i, name in ipairs(UISpecialFrames) do
            if name == "StablemasterTransmogPicker" then
                table.remove(UISpecialFrames, i)
                break
            end
        end
        table.insert(UISpecialFrames, "StablemasterTransmogPicker")

        self.selectedSetID = nil
        self.selectedButton = nil
        addBtn:SetEnabled(false)
        applyBtn:SetEnabled(false)
        searchBox:SetText("")
        PopulateSetList()
    end)

    picker:Hide()
    table.insert(UISpecialFrames, "StablemasterTransmogPicker")
    return picker
end

-- Class/Spec Picker Dialog
function StablemasterUI.CreateClassPicker(parentDialog)
    local picker = CreateFrame("Frame", "StablemasterClassPicker", UIParent, "BackdropTemplate")
    picker:SetSize(450, 500)
    picker:SetPoint("CENTER", parentDialog, "CENTER", 50, 0)
    picker:SetMovable(true)
    picker:EnableMouse(true)
    picker:EnableKeyboard(true)
    picker:SetFrameStrata("FULLSCREEN_DIALOG")
    picker:SetFrameLevel(parentDialog:GetFrameLevel() + 1)
    StablemasterUI.CreateDialogBackdrop(picker)

    -- Intercept ESC to close just this dialog
    picker:SetScript("OnKeyDown", function(self, key)
        if key == "ESCAPE" then
            self:Hide()
            self:SetPropagateKeyboardInput(false)
        else
            self:SetPropagateKeyboardInput(true)
        end
    end)

    -- Title bar
    local titleBar = StablemasterUI.CreateTitleBar(picker, "Select Classes & Specializations")
    picker.titleBar = titleBar

    -- Instructions
    local instructionText = StablemasterUI.CreateText(picker, STYLE.fontSizeSmall, STYLE.textDim)
    instructionText:SetPoint("TOPLEFT", picker, "TOPLEFT", STYLE.padding, -STYLE.headerHeight - STYLE.padding)
    instructionText:SetText("Select classes. Click [+] to choose specific specs (optional).")

    -- Scroll frame for class list
    local classScroll = CreateFrame("ScrollFrame", nil, picker, "UIPanelScrollFrameTemplate")
    classScroll:SetPoint("TOPLEFT", instructionText, "BOTTOMLEFT", 0, -10)
    classScroll:SetPoint("BOTTOMRIGHT", picker, "BOTTOMRIGHT", -26, 45)

    local classContent = CreateFrame("Frame", nil, classScroll)
    classContent:SetSize(380, 1)
    classScroll:SetScrollChild(classContent)

    -- Add Rule button
    local addBtn = StablemasterUI.CreateButton(picker, 80, STYLE.buttonHeight, "Add Rule")
    addBtn:SetPoint("BOTTOMRIGHT", picker, "BOTTOMRIGHT", -STYLE.padding, STYLE.padding)
    addBtn:SetEnabled(false)

    -- Cancel button
    local cancelBtn = StablemasterUI.CreateButton(picker, 80, STYLE.buttonHeight, "Cancel")
    cancelBtn:SetPoint("RIGHT", addBtn, "LEFT", -8, 0)
    cancelBtn:SetScript("OnClick", function() picker:Hide() end)

    -- Store state
    picker.selectedClasses = {} -- { [classID] = true }
    picker.selectedSpecs = {}   -- { [specID] = true }
    picker.expandedClasses = {} -- { [classID] = true }
    picker.classRows = {}

    -- Class data (all playable classes with their IDs)
    local classData = {}
    for classID = 1, 13 do -- WoW class IDs 1-13 (skipping 14 which doesn't exist)
        local className, classToken = GetClassInfo(classID)
        if className then
            local specs = {}
            for specIndex = 1, GetNumSpecializationsForClassID(classID) do
                local specID, specName = GetSpecializationInfoForClassID(classID, specIndex)
                if specID and specName then
                    table.insert(specs, {specID = specID, name = specName})
                end
            end
            table.insert(classData, {
                classID = classID,
                name = className,
                token = classToken,
                specs = specs
            })
        end
    end

    -- Sort by class name
    table.sort(classData, function(a, b) return a.name < b.name end)

    -- Function to populate class list
    local function PopulateClassList()
        -- Clear existing rows
        for _, row in ipairs(picker.classRows) do
            row:Hide()
            row:SetParent(nil)
        end
        picker.classRows = {}

        local y = -5
        for _, classInfo in ipairs(classData) do
            -- Class row
            local classRow = CreateFrame("Frame", nil, classContent, "BackdropTemplate")
            classRow:SetSize(360, 28)
            classRow:SetPoint("TOPLEFT", classContent, "TOPLEFT", 0, y)
            StablemasterUI.CreateBackdrop(classRow, 0.6)

            -- Class checkbox (modern style)
            local classCheck = CreateFrame("CheckButton", nil, classRow, "BackdropTemplate")
            classCheck:SetSize(16, 16)
            classCheck:SetPoint("LEFT", classRow, "LEFT", 8, 0)
            StablemasterUI.CreateBackdrop(classCheck, 0.6)

            local classCheckmark = classCheck:CreateTexture(nil, "OVERLAY")
            classCheckmark:SetSize(12, 12)
            classCheckmark:SetPoint("CENTER")
            classCheckmark:SetTexture("Interface\\Buttons\\UI-CheckBox-Check")
            classCheckmark:SetDesaturated(true)
            classCheckmark:SetVertexColor(unpack(STYLE.accent))
            classCheckmark:Hide()
            classCheck.checkmark = classCheckmark

            local function UpdateClassCheckVisuals(self)
                if self:GetChecked() then
                    self.checkmark:Show()
                    self:SetBackdropBorderColor(unpack(STYLE.accent))
                else
                    self.checkmark:Hide()
                    self:SetBackdropBorderColor(unpack(STYLE.borderColor))
                end
            end
            classCheck:SetChecked(picker.selectedClasses[classInfo.classID] or false)
            UpdateClassCheckVisuals(classCheck)

            -- Expand button for specs (modern style)
            local expandBtn = CreateFrame("Button", nil, classRow, "BackdropTemplate")
            expandBtn:SetSize(16, 16)
            expandBtn:SetPoint("LEFT", classCheck, "RIGHT", 6, 0)
            StablemasterUI.CreateBackdrop(expandBtn, 0.4)

            local expandText = expandBtn:CreateFontString(nil, "OVERLAY")
            expandText:SetFont(STANDARD_TEXT_FONT, 12, "OUTLINE")
            expandText:SetPoint("CENTER", 0, 1)
            expandText:SetTextColor(unpack(STYLE.accent))
            if picker.expandedClasses[classInfo.classID] then
                expandText:SetText("-")
            else
                expandText:SetText("+")
            end
            expandBtn.expandText = expandText

            -- Class name with class color
            local classColor = RAID_CLASS_COLORS[classInfo.token] or {r=1, g=1, b=1}
            local classText = StablemasterUI.CreateText(classRow, STYLE.fontSizeNormal, {classColor.r, classColor.g, classColor.b, 1})
            classText:SetPoint("LEFT", expandBtn, "RIGHT", 8, 0)
            classText:SetText(classInfo.name)

            -- Checkbox handler
            classCheck:SetScript("OnClick", function(self)
                UpdateClassCheckVisuals(self)
                picker.selectedClasses[classInfo.classID] = self:GetChecked() or nil
                -- If unchecking, also clear spec selections for this class
                if not self:GetChecked() then
                    for _, spec in ipairs(classInfo.specs) do
                        picker.selectedSpecs[spec.specID] = nil
                    end
                end
                -- Update add button state
                local hasSelection = false
                for _ in pairs(picker.selectedClasses) do
                    hasSelection = true
                    break
                end
                addBtn:SetEnabled(hasSelection)
                PopulateClassList() -- Refresh to update spec display
            end)

            -- Expand button handler
            expandBtn:SetScript("OnClick", function()
                picker.expandedClasses[classInfo.classID] = not picker.expandedClasses[classInfo.classID]
                PopulateClassList()
            end)

            -- Expand button hover effect
            expandBtn:SetScript("OnEnter", function(self)
                self:SetBackdropBorderColor(unpack(STYLE.accent))
            end)
            expandBtn:SetScript("OnLeave", function(self)
                self:SetBackdropBorderColor(unpack(STYLE.borderColor))
            end)

            table.insert(picker.classRows, classRow)
            y = y - 30

            -- Show specs if expanded
            if picker.expandedClasses[classInfo.classID] then
                for _, spec in ipairs(classInfo.specs) do
                    local specRow = CreateFrame("Frame", nil, classContent, "BackdropTemplate")
                    specRow:SetSize(340, 24)
                    specRow:SetPoint("TOPLEFT", classContent, "TOPLEFT", 20, y)
                    StablemasterUI.CreateBackdrop(specRow, 0.4)

                    -- Spec checkbox (modern style)
                    local specCheck = CreateFrame("CheckButton", nil, specRow, "BackdropTemplate")
                    specCheck:SetSize(14, 14)
                    specCheck:SetPoint("LEFT", specRow, "LEFT", 8, 0)
                    StablemasterUI.CreateBackdrop(specCheck, 0.6)

                    local specCheckmark = specCheck:CreateTexture(nil, "OVERLAY")
                    specCheckmark:SetSize(10, 10)
                    specCheckmark:SetPoint("CENTER")
                    specCheckmark:SetTexture("Interface\\Buttons\\UI-CheckBox-Check")
                    specCheckmark:SetDesaturated(true)
                    specCheckmark:SetVertexColor(unpack(STYLE.accent))
                    specCheckmark:Hide()
                    specCheck.checkmark = specCheckmark

                    local function UpdateSpecCheckVisuals(self)
                        if self:GetChecked() then
                            self.checkmark:Show()
                            self:SetBackdropBorderColor(unpack(STYLE.accent))
                        else
                            self.checkmark:Hide()
                            self:SetBackdropBorderColor(unpack(STYLE.borderColor))
                        end
                    end
                    specCheck:SetChecked(picker.selectedSpecs[spec.specID] or false)
                    UpdateSpecCheckVisuals(specCheck)

                    -- Spec name
                    local specText = StablemasterUI.CreateText(specRow, STYLE.fontSizeSmall, STYLE.text)
                    specText:SetPoint("LEFT", specCheck, "RIGHT", 8, 0)
                    specText:SetText(spec.name)

                    -- Spec checkbox handler
                    specCheck:SetScript("OnClick", function(self)
                        UpdateSpecCheckVisuals(self)
                        picker.selectedSpecs[spec.specID] = self:GetChecked() or nil
                        -- If selecting a spec, ensure the class is also selected
                        if self:GetChecked() then
                            picker.selectedClasses[classInfo.classID] = true
                            addBtn:SetEnabled(true)
                            PopulateClassList() -- Refresh to update class checkbox
                        end
                    end)

                    table.insert(picker.classRows, specRow)
                    y = y - 26
                end
            end
        end

        -- Update content height
        local contentHeight = math.max(-y + 10, 1)
        classContent:SetHeight(contentHeight)

        -- Manage scrollbar
        if classScroll.ScrollBar then
            if contentHeight > classScroll:GetHeight() then
                classScroll.ScrollBar:Show()
            else
                classScroll.ScrollBar:Hide()
                classScroll:SetVerticalScroll(0)
            end
        end
    end

    -- Add button functionality
    addBtn:SetScript("OnClick", function()
        if not parentDialog.targetPack then return end

        -- Build classIDs and specIDs arrays
        local classIDs = {}
        local specIDs = {}

        for classID in pairs(picker.selectedClasses) do
            table.insert(classIDs, classID)
        end
        for specID in pairs(picker.selectedSpecs) do
            table.insert(specIDs, specID)
        end

        if #classIDs == 0 then
            Stablemaster.Print("Please select at least one class.")
            return
        end

        -- Add the rule
        EnsureConditions(parentDialog.targetPack)
        table.insert(parentDialog.targetPack.conditions, {
            type = "class",
            classIDs = classIDs,
            specIDs = #specIDs > 0 and specIDs or nil,
        })

        -- Build description for message
        local classNames = {}
        for _, classID in ipairs(classIDs) do
            local className = GetClassInfo(classID)
            if className then
                table.insert(classNames, className)
            end
        end

        if #specIDs > 0 then
            local specNames = {}
            for _, specID in ipairs(specIDs) do
                local _, specName = GetSpecializationInfoByID(specID)
                if specName then
                    table.insert(specNames, specName)
                end
            end
            Stablemaster.VerbosePrint("Added class rule: " .. table.concat(classNames, ", ") .. " (Specs: " .. table.concat(specNames, ", ") .. ")")
        else
            Stablemaster.VerbosePrint("Added class rule: " .. table.concat(classNames, ", ") .. " (Any spec)")
        end

        RebuildRulesList(parentDialog.rulesList, parentDialog.targetPack)
        C_Timer.After(0.1, Stablemaster.SelectActivePack)

        -- Refresh pack panel
        if _G.StablemasterMainFrame and _G.StablemasterMainFrame.packPanel and _G.StablemasterMainFrame.packPanel.refreshPacks then
            _G.StablemasterMainFrame.packPanel.refreshPacks()
        end

        picker:Hide()
    end)

    -- OnShow: reset state and populate list
    picker:SetScript("OnShow", function(self)
        -- Move to end of UISpecialFrames so ESC closes this dialog first
        for i, name in ipairs(UISpecialFrames) do
            if name == "StablemasterClassPicker" then
                table.remove(UISpecialFrames, i)
                break
            end
        end
        table.insert(UISpecialFrames, "StablemasterClassPicker")

        self.selectedClasses = {}
        self.selectedSpecs = {}
        self.expandedClasses = {}
        addBtn:SetEnabled(false)
        PopulateClassList()
    end)

    picker:Hide()
    table.insert(UISpecialFrames, "StablemasterClassPicker")
    return picker
end

-- Race Picker Dialog
function StablemasterUI.CreateRacePicker(parentDialog)
    local picker = CreateFrame("Frame", "StablemasterRacePicker", UIParent, "BackdropTemplate")
    picker:SetSize(400, 450)
    picker:SetPoint("CENTER", parentDialog, "CENTER", 50, 0)
    picker:SetMovable(true)
    picker:EnableMouse(true)
    picker:EnableKeyboard(true)
    picker:SetFrameStrata("FULLSCREEN_DIALOG")
    picker:SetFrameLevel(parentDialog:GetFrameLevel() + 1)
    StablemasterUI.CreateDialogBackdrop(picker)

    -- Intercept ESC to close just this dialog
    picker:SetScript("OnKeyDown", function(self, key)
        if key == "ESCAPE" then
            self:Hide()
            self:SetPropagateKeyboardInput(false)
        else
            self:SetPropagateKeyboardInput(true)
        end
    end)

    -- Title bar
    local titleBar = StablemasterUI.CreateTitleBar(picker, "Select Races")
    picker.titleBar = titleBar

    -- Instructions
    local instructionText = StablemasterUI.CreateText(picker, STYLE.fontSizeSmall, STYLE.textDim)
    instructionText:SetPoint("TOPLEFT", picker, "TOPLEFT", STYLE.padding, -STYLE.headerHeight - STYLE.padding)
    instructionText:SetText("Select one or more races for this rule.")

    -- Scroll frame for race list
    local raceScroll = CreateFrame("ScrollFrame", nil, picker, "UIPanelScrollFrameTemplate")
    raceScroll:SetPoint("TOPLEFT", instructionText, "BOTTOMLEFT", 0, -10)
    raceScroll:SetPoint("BOTTOMRIGHT", picker, "BOTTOMRIGHT", -50, 50)

    local raceContent = CreateFrame("Frame", nil, raceScroll)
    raceContent:SetSize(330, 1)
    raceScroll:SetScrollChild(raceContent)

    -- Add Rule button
    local addBtn = StablemasterUI.CreateButton(picker, 80, STYLE.buttonHeight, "Add Rule")
    addBtn:SetPoint("BOTTOMRIGHT", picker, "BOTTOMRIGHT", -STYLE.padding, STYLE.padding)
    addBtn:SetEnabled(false)

    -- Cancel button
    local cancelBtn = StablemasterUI.CreateButton(picker, 80, STYLE.buttonHeight, "Cancel")
    cancelBtn:SetPoint("RIGHT", addBtn, "LEFT", -8, 0)
    cancelBtn:SetScript("OnClick", function() picker:Hide() end)

    -- Store state
    picker.selectedRaces = {} -- { [raceID] = true }
    picker.raceRows = {}

    -- Get all playable races
    local raceData = {}

    -- Alliance races
    local allianceRaces = {1, 3, 4, 7, 11, 22, 25, 29, 30, 32, 34, 37} -- Human, Dwarf, Night Elf, Gnome, Draenei, Worgen, Pandaren (Alliance), Void Elf, Lightforged, Kul Tiran, Dark Iron, Mechagnome
    -- Horde races
    local hordeRaces = {2, 5, 6, 8, 9, 10, 26, 27, 28, 31, 35, 36} -- Orc, Undead, Tauren, Troll, Goblin, Blood Elf, Pandaren (Horde), Nightborne, Highmountain, Zandalari, Mag'har, Vulpera

    -- Neutral races - grouped by race name (each covers both factions)
    -- Note: Haranir IDs are placeholders - update when Midnight releases
    local neutralRaces = {
        { name = "Dracthyr", raceIDs = {52, 70} },   -- Alliance, Horde
        { name = "Earthen", raceIDs = {85} },        -- Both factions use same ID
        { name = "Haranir", raceIDs = {86, 87} },    -- Placeholder IDs
    }

    local function addRacesFromList(raceList, faction)
        for _, raceID in ipairs(raceList) do
            local raceInfo = C_CreatureInfo.GetRaceInfo(raceID)
            if raceInfo then
                table.insert(raceData, {
                    raceID = raceID,
                    raceIDs = {raceID}, -- Single ID for faction-specific races
                    name = raceInfo.raceName,
                    faction = faction
                })
            end
        end
    end

    local function addNeutralRaces()
        for _, neutralRace in ipairs(neutralRaces) do
            -- Check if at least one of the race IDs exists in the game
            local validIDs = {}
            for _, raceID in ipairs(neutralRace.raceIDs) do
                local raceInfo = C_CreatureInfo.GetRaceInfo(raceID)
                if raceInfo then
                    table.insert(validIDs, raceID)
                end
            end
            -- Only add if we found at least one valid ID
            if #validIDs > 0 then
                table.insert(raceData, {
                    raceID = validIDs[1], -- Primary ID for display
                    raceIDs = validIDs,   -- All valid IDs for this race
                    name = neutralRace.name,
                    faction = "Neutral"
                })
            end
        end
    end

    addRacesFromList(allianceRaces, "Alliance")
    addRacesFromList(hordeRaces, "Horde")
    addNeutralRaces()

    -- Sort by faction then name
    table.sort(raceData, function(a, b)
        if a.faction ~= b.faction then
            local order = {Alliance = 1, Horde = 2, Neutral = 3}
            return (order[a.faction] or 4) < (order[b.faction] or 4)
        end
        return a.name < b.name
    end)

    -- Function to populate race list
    local function PopulateRaceList()
        -- Clear existing rows
        for _, row in ipairs(picker.raceRows) do
            row:Hide()
            row:SetParent(nil)
        end
        picker.raceRows = {}

        local y = -5
        local currentFaction = nil

        for _, raceInfo in ipairs(raceData) do
            -- Add faction header if changed
            if raceInfo.faction ~= currentFaction then
                currentFaction = raceInfo.faction

                local headerRow = CreateFrame("Frame", nil, raceContent)
                headerRow:SetSize(330, 22)
                headerRow:SetPoint("TOPLEFT", raceContent, "TOPLEFT", 0, y)

                local headerText = headerRow:CreateFontString(nil, "OVERLAY", "GameFontNormal")
                headerText:SetPoint("LEFT", headerRow, "LEFT", 5, 0)
                headerText:SetText(currentFaction)

                -- Faction color
                if currentFaction == "Alliance" then
                    headerText:SetTextColor(0.4, 0.6, 1, 1)
                elseif currentFaction == "Horde" then
                    headerText:SetTextColor(1, 0.4, 0.4, 1)
                else
                    headerText:SetTextColor(0.8, 0.8, 0.4, 1)
                end

                table.insert(picker.raceRows, headerRow)
                y = y - 24
            end

            -- Race row
            local raceRow = CreateFrame("Frame", nil, raceContent, "BackdropTemplate")
            raceRow:SetSize(320, 26)
            raceRow:SetPoint("TOPLEFT", raceContent, "TOPLEFT", 10, y)
            StablemasterUI.CreateBackdrop(raceRow, 0.6)

            -- Race checkbox (modern style)
            local raceCheck = CreateFrame("CheckButton", nil, raceRow, "BackdropTemplate")
            raceCheck:SetSize(16, 16)
            raceCheck:SetPoint("LEFT", raceRow, "LEFT", 8, 0)
            StablemasterUI.CreateBackdrop(raceCheck, 0.6)

            local raceCheckmark = raceCheck:CreateTexture(nil, "OVERLAY")
            raceCheckmark:SetSize(12, 12)
            raceCheckmark:SetPoint("CENTER")
            raceCheckmark:SetTexture("Interface\\Buttons\\UI-CheckBox-Check")
            raceCheckmark:SetDesaturated(true)
            raceCheckmark:SetVertexColor(unpack(STYLE.accent))
            raceCheckmark:Hide()
            raceCheck.checkmark = raceCheckmark

            local function UpdateRaceCheckVisuals(self)
                if self:GetChecked() then
                    self.checkmark:Show()
                    self:SetBackdropBorderColor(unpack(STYLE.accent))
                else
                    self.checkmark:Hide()
                    self:SetBackdropBorderColor(unpack(STYLE.borderColor))
                end
            end
            raceCheck:SetChecked(picker.selectedRaces[raceInfo.raceID] or false)
            UpdateRaceCheckVisuals(raceCheck)

            -- Race name
            local raceText = StablemasterUI.CreateText(raceRow, STYLE.fontSizeNormal, STYLE.text)
            raceText:SetPoint("LEFT", raceCheck, "RIGHT", 8, 0)
            raceText:SetText(raceInfo.name)

            -- Checkbox handler
            raceCheck:SetScript("OnClick", function(self)
                UpdateRaceCheckVisuals(self)
                -- Store the full raceIDs array (for neutral races with multiple IDs)
                picker.selectedRaces[raceInfo.raceID] = self:GetChecked() and raceInfo.raceIDs or nil
                -- Update add button state
                local hasSelection = false
                for _ in pairs(picker.selectedRaces) do
                    hasSelection = true
                    break
                end
                addBtn:SetEnabled(hasSelection)
            end)

            table.insert(picker.raceRows, raceRow)
            y = y - 28
        end

        -- Update content height
        local contentHeight = math.max(-y + 10, 1)
        raceContent:SetHeight(contentHeight)

        -- Manage scrollbar
        if raceScroll.ScrollBar then
            if contentHeight > raceScroll:GetHeight() then
                raceScroll.ScrollBar:Show()
            else
                raceScroll.ScrollBar:Hide()
                raceScroll:SetVerticalScroll(0)
            end
        end
    end

    -- Add button functionality
    addBtn:SetScript("OnClick", function()
        if not parentDialog.targetPack then return end

        -- Build raceIDs array (flatten all selected race ID arrays)
        local raceIDs = {}
        for _, raceIDsArray in pairs(picker.selectedRaces) do
            for _, raceID in ipairs(raceIDsArray) do
                table.insert(raceIDs, raceID)
            end
        end

        if #raceIDs == 0 then
            Stablemaster.Print("Please select at least one race.")
            return
        end

        -- Add the rule
        EnsureConditions(parentDialog.targetPack)
        table.insert(parentDialog.targetPack.conditions, {
            type = "race",
            raceIDs = raceIDs,
        })

        -- Build description for message (deduplicate names for neutral races)
        local raceNames = {}
        local seenNames = {}
        for _, raceID in ipairs(raceIDs) do
            local raceInfo = C_CreatureInfo.GetRaceInfo(raceID)
            if raceInfo and not seenNames[raceInfo.raceName] then
                seenNames[raceInfo.raceName] = true
                table.insert(raceNames, raceInfo.raceName)
            end
        end

        Stablemaster.VerbosePrint("Added race rule: " .. table.concat(raceNames, ", "))

        RebuildRulesList(parentDialog.rulesList, parentDialog.targetPack)
        C_Timer.After(0.1, Stablemaster.SelectActivePack)

        -- Refresh pack panel
        if _G.StablemasterMainFrame and _G.StablemasterMainFrame.packPanel and _G.StablemasterMainFrame.packPanel.refreshPacks then
            _G.StablemasterMainFrame.packPanel.refreshPacks()
        end

        picker:Hide()
    end)

    -- OnShow: reset state and populate list
    picker:SetScript("OnShow", function(self)
        -- Move to end of UISpecialFrames so ESC closes this dialog first
        for i, name in ipairs(UISpecialFrames) do
            if name == "StablemasterRacePicker" then
                table.remove(UISpecialFrames, i)
                break
            end
        end
        table.insert(UISpecialFrames, "StablemasterRacePicker")

        self.selectedRaces = {}
        addBtn:SetEnabled(false)
        PopulateRaceList()
    end)

    picker:Hide()
    table.insert(UISpecialFrames, "StablemasterRacePicker")
    return picker
end

-- Outfit Picker Dialog (Midnight 12.0+) - Multi-select
function StablemasterUI.CreateOutfitPicker(parentDialog)
    local picker = CreateFrame("Frame", "StablemasterOutfitPicker", UIParent, "BackdropTemplate")
    picker:SetSize(400, 350)
    picker:SetPoint("CENTER", parentDialog, "CENTER", 50, 0)
    picker:SetMovable(true)
    picker:EnableMouse(true)
    picker:EnableKeyboard(true)
    picker:SetFrameStrata("FULLSCREEN_DIALOG")
    picker:SetFrameLevel(parentDialog:GetFrameLevel() + 1)
    StablemasterUI.CreateDialogBackdrop(picker)

    -- Intercept ESC to close just this dialog
    picker:SetScript("OnKeyDown", function(self, key)
        if key == "ESCAPE" then
            self:Hide()
            self:SetPropagateKeyboardInput(false)
        else
            self:SetPropagateKeyboardInput(true)
        end
    end)

    -- Title bar
    local titleBar = StablemasterUI.CreateTitleBar(picker, "Select Outfits")
    picker.titleBar = titleBar

    -- Instructions
    local instructionText = StablemasterUI.CreateText(picker, STYLE.fontSizeSmall, STYLE.textDim)
    instructionText:SetPoint("TOPLEFT", picker, "TOPLEFT", STYLE.padding, -STYLE.headerHeight - STYLE.padding)
    instructionText:SetText("Select one or more outfits to link to this pack.")

    -- Info about current outfit
    local currentOutfitLabel = StablemasterUI.CreateText(picker, STYLE.fontSizeSmall, STYLE.text)
    currentOutfitLabel:SetPoint("TOPLEFT", instructionText, "BOTTOMLEFT", 0, -8)
    currentOutfitLabel:SetText("Current active outfit:")

    local currentOutfitName = StablemasterUI.CreateText(picker, STYLE.fontSizeSmall, STYLE.accent)
    currentOutfitName:SetPoint("LEFT", currentOutfitLabel, "RIGHT", 8, 0)
    picker.currentOutfitName = currentOutfitName

    -- Scroll frame for outfit list
    local outfitScroll = CreateFrame("ScrollFrame", nil, picker, "UIPanelScrollFrameTemplate")
    outfitScroll:SetPoint("TOPLEFT", currentOutfitLabel, "BOTTOMLEFT", 0, -15)
    outfitScroll:SetPoint("BOTTOMRIGHT", picker, "BOTTOMRIGHT", -50, 50)

    local outfitContent = CreateFrame("Frame", nil, outfitScroll)
    outfitContent:SetSize(330, 1)
    outfitScroll:SetScrollChild(outfitContent)

    -- Add Rule button
    local addBtn = StablemasterUI.CreateButton(picker, 80, STYLE.buttonHeight, "Add Rule")
    addBtn:SetPoint("BOTTOMRIGHT", picker, "BOTTOMRIGHT", -STYLE.padding, STYLE.padding)
    addBtn:SetEnabled(false)

    -- Cancel button
    local cancelBtn = StablemasterUI.CreateButton(picker, 80, STYLE.buttonHeight, "Cancel")
    cancelBtn:SetPoint("RIGHT", addBtn, "LEFT", -8, 0)
    cancelBtn:SetScript("OnClick", function() picker:Hide() end)

    -- Store state - multi-select: { [outfitID] = outfitName }
    picker.selectedOutfits = {}
    picker.outfitRows = {}

    -- Function to update add button state
    local function UpdateAddButtonState()
        local hasSelection = false
        for _ in pairs(picker.selectedOutfits) do
            hasSelection = true
            break
        end
        addBtn:SetEnabled(hasSelection)
    end

    -- Function to populate outfit list
    local function PopulateOutfitList()
        -- Clear existing rows
        for _, row in ipairs(picker.outfitRows) do
            row:Hide()
            row:SetParent(nil)
        end
        picker.outfitRows = {}

        -- Get all outfits
        local outfits = Stablemaster.GetAllOutfits()

        -- Update current outfit display
        local currentOutfitID = Stablemaster.GetCurrentOutfitID()
        if currentOutfitID then
            local currentInfo = Stablemaster.GetOutfitInfo(currentOutfitID)
            picker.currentOutfitName:SetText(currentInfo and currentInfo.name or ("Outfit #" .. currentOutfitID))
        else
            picker.currentOutfitName:SetText("(None)")
        end

        if not outfits or #outfits == 0 then
            -- Show message when no outfits exist
            local noOutfitsText = outfitContent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            noOutfitsText:SetPoint("CENTER", outfitContent, "CENTER", 0, 0)
            noOutfitsText:SetText("No saved outfits found.\n\nCreate outfits in the WoW Appearance tab\nto use outfit-based pack rules.")
            noOutfitsText:SetTextColor(0.7, 0.7, 0.7, 1)
            noOutfitsText:SetJustifyH("CENTER")

            local noOutfitsRow = CreateFrame("Frame", nil, outfitContent)
            noOutfitsRow:SetSize(330, 60)
            noOutfitsRow:SetPoint("TOPLEFT", outfitContent, "TOPLEFT", 0, -10)
            table.insert(picker.outfitRows, noOutfitsRow)

            outfitContent:SetHeight(80)
            return
        end

        local y = -5
        for i, outfit in ipairs(outfits) do
            local outfitRow = CreateFrame("Frame", nil, outfitContent, "BackdropTemplate")
            outfitRow:SetSize(330, 28)
            outfitRow:SetPoint("TOPLEFT", outfitContent, "TOPLEFT", 0, y)
            StablemasterUI.CreateBackdrop(outfitRow, 0.6)

            -- Checkbox
            local outfitCheck = CreateFrame("CheckButton", nil, outfitRow, "BackdropTemplate")
            outfitCheck:SetSize(16, 16)
            outfitCheck:SetPoint("LEFT", outfitRow, "LEFT", 8, 0)
            StablemasterUI.CreateBackdrop(outfitCheck, 0.6)

            local checkmark = outfitCheck:CreateTexture(nil, "OVERLAY")
            checkmark:SetSize(12, 12)
            checkmark:SetPoint("CENTER")
            checkmark:SetTexture("Interface\\Buttons\\UI-CheckBox-Check")
            checkmark:SetDesaturated(true)
            checkmark:SetVertexColor(unpack(STYLE.accent))
            checkmark:Hide()
            outfitCheck.checkmark = checkmark

            local function UpdateCheckVisuals(self)
                if self:GetChecked() then
                    self.checkmark:Show()
                    self:SetBackdropBorderColor(unpack(STYLE.accent))
                else
                    self.checkmark:Hide()
                    self:SetBackdropBorderColor(unpack(STYLE.borderColor))
                end
            end

            outfitCheck:SetChecked(picker.selectedOutfits[outfit.outfitID] ~= nil)
            UpdateCheckVisuals(outfitCheck)

            -- Outfit name
            local outfitText = StablemasterUI.CreateText(outfitRow, STYLE.fontSizeNormal, STYLE.text)
            outfitText:SetPoint("LEFT", outfitCheck, "RIGHT", 8, 0)
            outfitText:SetText(outfit.name or ("Outfit #" .. outfit.outfitID))

            -- Outfit ID (smaller, dimmed)
            local idText = outfitRow:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            idText:SetPoint("RIGHT", outfitRow, "RIGHT", -12, 0)
            idText:SetText("#" .. outfit.outfitID)
            idText:SetTextColor(0.5, 0.5, 0.5, 1)

            -- Mark current outfit
            if currentOutfitID and outfit.outfitID == currentOutfitID then
                local currentMark = outfitRow:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
                currentMark:SetPoint("RIGHT", idText, "LEFT", -8, 0)
                currentMark:SetText("(active)")
                currentMark:SetTextColor(0.4, 1, 0.4, 1)
            end

            -- Store outfit data
            outfitCheck.outfitID = outfit.outfitID
            outfitCheck.outfitName = outfit.name or ("Outfit #" .. outfit.outfitID)

            -- Checkbox handler
            outfitCheck:SetScript("OnClick", function(self)
                UpdateCheckVisuals(self)
                if self:GetChecked() then
                    picker.selectedOutfits[self.outfitID] = self.outfitName
                else
                    picker.selectedOutfits[self.outfitID] = nil
                end
                UpdateAddButtonState()
            end)

            -- Make the whole row clickable to toggle checkbox
            outfitRow:EnableMouse(true)
            outfitRow:SetScript("OnMouseDown", function()
                outfitCheck:Click()
            end)

            -- Hover effects
            outfitRow:SetScript("OnEnter", function(self)
                self:SetBackdropColor(0.2, 0.2, 0.2, 0.8)
            end)
            outfitRow:SetScript("OnLeave", function(self)
                self:SetBackdropColor(0.1, 0.1, 0.1, 0.8)
            end)

            table.insert(picker.outfitRows, outfitRow)
            y = y - 30
        end

        -- Update content height
        local contentHeight = math.max(-y + 10, 1)
        outfitContent:SetHeight(contentHeight)

        -- Manage scrollbar
        if outfitScroll.ScrollBar then
            if contentHeight > outfitScroll:GetHeight() then
                outfitScroll.ScrollBar:Show()
            else
                outfitScroll.ScrollBar:Hide()
                outfitScroll:SetVerticalScroll(0)
            end
        end
    end

    -- Add button functionality
    addBtn:SetScript("OnClick", function()
        if not parentDialog.targetPack then return end

        -- Collect selected outfits
        local outfitIDs = {}
        local outfitNames = {}
        for outfitID, outfitName in pairs(picker.selectedOutfits) do
            table.insert(outfitIDs, outfitID)
            table.insert(outfitNames, outfitName)
        end

        if #outfitIDs == 0 then
            Stablemaster.Print("Please select at least one outfit.")
            return
        end

        -- Add the rule with arrays
        EnsureConditions(parentDialog.targetPack)
        table.insert(parentDialog.targetPack.conditions, {
            type = "outfit",
            outfitIDs = outfitIDs,
            outfitNames = outfitNames,
            priority = StablemasterDB.settings.rulePriorities.outfit or 100,
        })

        local displayNames = table.concat(outfitNames, ", ")
        Stablemaster.VerbosePrint("Added outfit rule: " .. displayNames)

        RebuildRulesList(parentDialog.rulesList, parentDialog.targetPack)
        C_Timer.After(0.1, Stablemaster.SelectActivePack)

        -- Refresh pack panel
        if _G.StablemasterMainFrame and _G.StablemasterMainFrame.packPanel and _G.StablemasterMainFrame.packPanel.refreshPacks then
            _G.StablemasterMainFrame.packPanel.refreshPacks()
        end

        picker:Hide()
    end)

    -- OnShow: reset state and populate list
    picker:SetScript("OnShow", function(self)
        -- Move to end of UISpecialFrames so ESC closes this dialog first
        for i, name in ipairs(UISpecialFrames) do
            if name == "StablemasterOutfitPicker" then
                table.remove(UISpecialFrames, i)
                break
            end
        end
        table.insert(UISpecialFrames, "StablemasterOutfitPicker")

        self.selectedOutfits = {}
        addBtn:SetEnabled(false)
        PopulateOutfitList()
    end)

    picker:Hide()
    table.insert(UISpecialFrames, "StablemasterOutfitPicker")
    return picker
end

-- Time Picker Dialog
function StablemasterUI.CreateTimePicker(parentDialog)
    local picker = CreateFrame("Frame", "StablemasterTimePicker", UIParent, "BackdropTemplate")
    picker:SetSize(350, 340)
    picker:SetPoint("CENTER", parentDialog, "CENTER", 50, 0)
    picker:SetMovable(true)
    picker:EnableMouse(true)
    picker:EnableKeyboard(true)
    picker:SetFrameStrata("FULLSCREEN_DIALOG")
    picker:SetFrameLevel(parentDialog:GetFrameLevel() + 1)
    StablemasterUI.CreateDialogBackdrop(picker)

    -- Intercept ESC to close just this dialog
    picker:SetScript("OnKeyDown", function(self, key)
        if key == "ESCAPE" then
            self:Hide()
            self:SetPropagateKeyboardInput(false)
        else
            self:SetPropagateKeyboardInput(true)
        end
    end)

    -- Title bar
    local titleBar = StablemasterUI.CreateTitleBar(picker, "Select Time Ranges")
    picker.titleBar = titleBar

    -- Instructions
    local instructionText = StablemasterUI.CreateText(picker, STYLE.fontSizeSmall, STYLE.textDim)
    instructionText:SetPoint("TOPLEFT", picker, "TOPLEFT", STYLE.padding, -STYLE.headerHeight - STYLE.padding)
    instructionText:SetText("Select one or more time ranges for this rule.")

    -- Current time display
    local currentTimeLabel = StablemasterUI.CreateText(picker, STYLE.fontSizeSmall, STYLE.text)
    currentTimeLabel:SetPoint("TOPLEFT", instructionText, "BOTTOMLEFT", 0, -8)
    currentTimeLabel:SetText("Current server time:")

    local currentTimeText = StablemasterUI.CreateText(picker, STYLE.fontSizeSmall, STYLE.accent)
    currentTimeText:SetPoint("LEFT", currentTimeLabel, "RIGHT", 8, 0)
    picker.currentTimeText = currentTimeText

    -- Add Rule button
    local addBtn = StablemasterUI.CreateButton(picker, 80, STYLE.buttonHeight, "Add Rule")
    addBtn:SetPoint("BOTTOMRIGHT", picker, "BOTTOMRIGHT", -STYLE.padding, STYLE.padding)
    addBtn:SetEnabled(false)

    -- Cancel button
    local cancelBtn = StablemasterUI.CreateButton(picker, 80, STYLE.buttonHeight, "Cancel")
    cancelBtn:SetPoint("RIGHT", addBtn, "LEFT", -8, 0)
    cancelBtn:SetScript("OnClick", function() picker:Hide() end)

    -- Store state - multi-select
    picker.selectedTimes = {} -- { [timeName] = true }
    picker.timeRows = {}

    -- Function to update add button state
    local function UpdateAddButtonState()
        local hasSelection = false
        for _ in pairs(picker.selectedTimes) do
            hasSelection = true
            break
        end
        addBtn:SetEnabled(hasSelection)
    end

    -- Time range container
    local timeContainer = CreateFrame("Frame", nil, picker)
    timeContainer:SetPoint("TOPLEFT", currentTimeLabel, "BOTTOMLEFT", 0, -15)
    timeContainer:SetSize(310, 220)

    -- Format hour for display
    local function formatHour(h)
        if h == 0 then return "12 AM"
        elseif h < 12 then return h .. " AM"
        elseif h == 12 then return "12 PM"
        else return (h - 12) .. " PM"
        end
    end

    -- Get which time ranges are currently active
    local function getCurrentTimeRanges()
        local currentHour = Stablemaster.GetCurrentHour()
        local active = {}
        for _, preset in ipairs(Stablemaster.TimeRanges) do
            if Stablemaster.IsTimeInRange(preset.startHour, preset.endHour) then
                active[preset.name] = true
            end
        end
        return active
    end

    -- Populate time ranges
    local y = 0
    for i, preset in ipairs(Stablemaster.TimeRanges) do
        local timeRow = CreateFrame("Frame", nil, timeContainer, "BackdropTemplate")
        timeRow:SetSize(310, 28)
        timeRow:SetPoint("TOPLEFT", timeContainer, "TOPLEFT", 0, -y)
        StablemasterUI.CreateBackdrop(timeRow, 0.6)

        -- Checkbox
        local timeCheck = CreateFrame("CheckButton", nil, timeRow, "BackdropTemplate")
        timeCheck:SetSize(16, 16)
        timeCheck:SetPoint("LEFT", timeRow, "LEFT", 8, 0)
        StablemasterUI.CreateBackdrop(timeCheck, 0.6)

        local checkmark = timeCheck:CreateTexture(nil, "OVERLAY")
        checkmark:SetSize(12, 12)
        checkmark:SetPoint("CENTER")
        checkmark:SetTexture("Interface\\Buttons\\UI-CheckBox-Check")
        checkmark:SetDesaturated(true)
        checkmark:SetVertexColor(unpack(STYLE.accent))
        checkmark:Hide()
        timeCheck.checkmark = checkmark

        local function UpdateCheckVisuals(self)
            if self:GetChecked() then
                self.checkmark:Show()
                self:SetBackdropBorderColor(unpack(STYLE.accent))
            else
                self.checkmark:Hide()
                self:SetBackdropBorderColor(unpack(STYLE.borderColor))
            end
        end

        timeCheck:SetChecked(picker.selectedTimes[preset.name] or false)
        UpdateCheckVisuals(timeCheck)

        -- Time name
        local timeText = StablemasterUI.CreateText(timeRow, STYLE.fontSizeNormal, STYLE.text)
        timeText:SetPoint("LEFT", timeCheck, "RIGHT", 8, 0)
        timeText:SetText(preset.name)

        -- Hour range hint
        local hourHint = formatHour(preset.startHour) .. " - " .. formatHour(preset.endHour)
        local hintText = timeRow:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        hintText:SetPoint("RIGHT", timeRow, "RIGHT", -12, 0)
        hintText:SetText(hourHint)
        hintText:SetTextColor(0.5, 0.5, 0.5, 1)

        timeCheck.timeName = preset.name
        timeRow.timeCheck = timeCheck
        timeRow.nowMark = nil

        -- Checkbox handler
        timeCheck:SetScript("OnClick", function(self)
            UpdateCheckVisuals(self)
            if self:GetChecked() then
                picker.selectedTimes[self.timeName] = true
            else
                picker.selectedTimes[self.timeName] = nil
            end
            UpdateAddButtonState()
        end)

        -- Make whole row clickable
        timeRow:EnableMouse(true)
        timeRow:SetScript("OnMouseDown", function()
            timeCheck:Click()
        end)

        timeRow:SetScript("OnEnter", function(self)
            self:SetBackdropColor(0.2, 0.2, 0.2, 0.8)
        end)
        timeRow:SetScript("OnLeave", function(self)
            self:SetBackdropColor(0.1, 0.1, 0.1, 0.8)
        end)

        table.insert(picker.timeRows, timeRow)
        y = y + 30
    end

    -- Add button functionality
    addBtn:SetScript("OnClick", function()
        if not parentDialog.targetPack then return end

        local timeNames = {}
        for name in pairs(picker.selectedTimes) do
            table.insert(timeNames, name)
        end

        if #timeNames == 0 then
            Stablemaster.Print("Please select at least one time range.")
            return
        end

        EnsureConditions(parentDialog.targetPack)
        table.insert(parentDialog.targetPack.conditions, {
            type = "time",
            timeNames = timeNames,
            priority = StablemasterDB.settings.rulePriorities.time or 40,
        })

        local displayNames = table.concat(timeNames, ", ")
        Stablemaster.VerbosePrint("Added time rule: " .. displayNames)

        RebuildRulesList(parentDialog.rulesList, parentDialog.targetPack)
        C_Timer.After(0.1, Stablemaster.SelectActivePack)

        if _G.StablemasterMainFrame and _G.StablemasterMainFrame.packPanel and _G.StablemasterMainFrame.packPanel.refreshPacks then
            _G.StablemasterMainFrame.packPanel.refreshPacks()
        end

        picker:Hide()
    end)

    -- OnShow: update current time and reset checkboxes
    picker:SetScript("OnShow", function(self)
        for i, name in ipairs(UISpecialFrames) do
            if name == "StablemasterTimePicker" then
                table.remove(UISpecialFrames, i)
                break
            end
        end
        table.insert(UISpecialFrames, "StablemasterTimePicker")

        -- Update current time display
        local hour, minute = GetGameTime()
        local ampm = hour >= 12 and "PM" or "AM"
        local displayHour = hour % 12
        if displayHour == 0 then displayHour = 12 end
        self.currentTimeText:SetText(string.format("%d:%02d %s", displayHour, minute, ampm))

        -- Reset selection
        self.selectedTimes = {}
        addBtn:SetEnabled(false)

        -- Get currently active time ranges
        local activeRanges = getCurrentTimeRanges()

        -- Reset all checkboxes and show "(now)" indicators
        for _, row in ipairs(self.timeRows) do
            local check = row.timeCheck
            check:SetChecked(false)
            check.checkmark:Hide()
            check:SetBackdropBorderColor(unpack(STYLE.borderColor))

            -- Remove old "(now)" mark if any
            if row.nowMark then
                row.nowMark:Hide()
                row.nowMark = nil
            end

            -- Add "(now)" if this time range is currently active
            if activeRanges[check.timeName] then
                local nowMark = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
                nowMark:SetPoint("RIGHT", row, "RIGHT", -90, 0)
                nowMark:SetText("(now)")
                nowMark:SetTextColor(0.4, 1, 0.4, 1)
                row.nowMark = nowMark
            end
        end
    end)

    picker:Hide()
    table.insert(UISpecialFrames, "StablemasterTimePicker")
    return picker
end

-- Holiday Picker Dialog
function StablemasterUI.CreateHolidayPicker(parentDialog)
    local picker = CreateFrame("Frame", "StablemasterHolidayPicker", UIParent, "BackdropTemplate")
    picker:SetSize(400, 400)
    picker:SetPoint("CENTER", parentDialog, "CENTER", 50, 0)
    picker:SetMovable(true)
    picker:EnableMouse(true)
    picker:EnableKeyboard(true)
    picker:SetFrameStrata("FULLSCREEN_DIALOG")
    picker:SetFrameLevel(parentDialog:GetFrameLevel() + 1)
    StablemasterUI.CreateDialogBackdrop(picker)

    -- Intercept ESC to close just this dialog
    picker:SetScript("OnKeyDown", function(self, key)
        if key == "ESCAPE" then
            self:Hide()
            self:SetPropagateKeyboardInput(false)
        else
            self:SetPropagateKeyboardInput(true)
        end
    end)

    -- Title bar
    local titleBar = StablemasterUI.CreateTitleBar(picker, "Select Holidays")
    picker.titleBar = titleBar

    -- Instructions
    local instructionText = StablemasterUI.CreateText(picker, STYLE.fontSizeSmall, STYLE.textDim)
    instructionText:SetPoint("TOPLEFT", picker, "TOPLEFT", STYLE.padding, -STYLE.headerHeight - STYLE.padding)
    instructionText:SetText("Select one or more holidays for this rule.")

    -- Active holidays display
    local activeLabel = StablemasterUI.CreateText(picker, STYLE.fontSizeSmall, STYLE.text)
    activeLabel:SetPoint("TOPLEFT", instructionText, "BOTTOMLEFT", 0, -8)
    activeLabel:SetText("Currently active:")

    local activeHolidaysText = StablemasterUI.CreateText(picker, STYLE.fontSizeSmall, STYLE.accent)
    activeHolidaysText:SetPoint("LEFT", activeLabel, "RIGHT", 8, 0)
    picker.activeHolidaysText = activeHolidaysText

    -- Scroll frame for holiday list
    local holidayScroll = CreateFrame("ScrollFrame", nil, picker, "UIPanelScrollFrameTemplate")
    holidayScroll:SetPoint("TOPLEFT", activeLabel, "BOTTOMLEFT", 0, -15)
    holidayScroll:SetPoint("BOTTOMRIGHT", picker, "BOTTOMRIGHT", -50, 50)

    local holidayContent = CreateFrame("Frame", nil, holidayScroll)
    holidayContent:SetSize(330, 1)
    holidayScroll:SetScrollChild(holidayContent)

    -- Add Rule button
    local addBtn = StablemasterUI.CreateButton(picker, 80, STYLE.buttonHeight, "Add Rule")
    addBtn:SetPoint("BOTTOMRIGHT", picker, "BOTTOMRIGHT", -STYLE.padding, STYLE.padding)
    addBtn:SetEnabled(false)

    -- Cancel button
    local cancelBtn = StablemasterUI.CreateButton(picker, 80, STYLE.buttonHeight, "Cancel")
    cancelBtn:SetPoint("RIGHT", addBtn, "LEFT", -8, 0)
    cancelBtn:SetScript("OnClick", function() picker:Hide() end)

    -- Store state - multi-select
    picker.selectedHolidays = {} -- { [holidayName] = true }
    picker.holidayRows = {}

    -- Function to update add button state
    local function UpdateAddButtonState()
        local hasSelection = false
        for _ in pairs(picker.selectedHolidays) do
            hasSelection = true
            break
        end
        addBtn:SetEnabled(hasSelection)
    end

    -- Function to populate holiday list
    local function PopulateHolidayList()
        -- Clear existing rows
        for _, row in ipairs(picker.holidayRows) do
            row:Hide()
            row:SetParent(nil)
        end
        picker.holidayRows = {}

        -- Get active holidays
        local activeHolidays = Stablemaster.GetActiveHolidays()
        local activeNames = {}
        for _, h in ipairs(activeHolidays) do
            activeNames[h.name] = true
        end

        -- Update active holidays display
        if #activeHolidays > 0 then
            local names = {}
            for _, h in ipairs(activeHolidays) do
                table.insert(names, h.name)
            end
            picker.activeHolidaysText:SetText(table.concat(names, ", "))
        else
            picker.activeHolidaysText:SetText("(None)")
        end

        local y = -5
        for _, holiday in ipairs(Stablemaster.KnownHolidays) do
            local holidayRow = CreateFrame("Frame", nil, holidayContent, "BackdropTemplate")
            holidayRow:SetSize(330, 28)
            holidayRow:SetPoint("TOPLEFT", holidayContent, "TOPLEFT", 0, y)
            StablemasterUI.CreateBackdrop(holidayRow, 0.6)

            -- Checkbox
            local holidayCheck = CreateFrame("CheckButton", nil, holidayRow, "BackdropTemplate")
            holidayCheck:SetSize(16, 16)
            holidayCheck:SetPoint("LEFT", holidayRow, "LEFT", 8, 0)
            StablemasterUI.CreateBackdrop(holidayCheck, 0.6)

            local checkmark = holidayCheck:CreateTexture(nil, "OVERLAY")
            checkmark:SetSize(12, 12)
            checkmark:SetPoint("CENTER")
            checkmark:SetTexture("Interface\\Buttons\\UI-CheckBox-Check")
            checkmark:SetDesaturated(true)
            checkmark:SetVertexColor(unpack(STYLE.accent))
            checkmark:Hide()
            holidayCheck.checkmark = checkmark

            local function UpdateCheckVisuals(self)
                if self:GetChecked() then
                    self.checkmark:Show()
                    self:SetBackdropBorderColor(unpack(STYLE.accent))
                else
                    self.checkmark:Hide()
                    self:SetBackdropBorderColor(unpack(STYLE.borderColor))
                end
            end

            holidayCheck:SetChecked(picker.selectedHolidays[holiday.name] or false)
            UpdateCheckVisuals(holidayCheck)

            -- Holiday name
            local holidayText = StablemasterUI.CreateText(holidayRow, STYLE.fontSizeNormal, STYLE.text)
            holidayText:SetPoint("LEFT", holidayCheck, "RIGHT", 8, 0)
            holidayText:SetText(holiday.name)

            -- Mark if active
            if activeNames[holiday.name] then
                local activeMark = holidayRow:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
                activeMark:SetPoint("RIGHT", holidayRow, "RIGHT", -12, 0)
                activeMark:SetText("(active now)")
                activeMark:SetTextColor(0.4, 1, 0.4, 1)
            end

            holidayCheck.holidayName = holiday.name

            -- Checkbox handler
            holidayCheck:SetScript("OnClick", function(self)
                UpdateCheckVisuals(self)
                if self:GetChecked() then
                    picker.selectedHolidays[self.holidayName] = true
                else
                    picker.selectedHolidays[self.holidayName] = nil
                end
                UpdateAddButtonState()
            end)

            -- Make whole row clickable
            holidayRow:EnableMouse(true)
            holidayRow:SetScript("OnMouseDown", function()
                holidayCheck:Click()
            end)

            holidayRow:SetScript("OnEnter", function(self)
                self:SetBackdropColor(0.2, 0.2, 0.2, 0.8)
            end)
            holidayRow:SetScript("OnLeave", function(self)
                self:SetBackdropColor(0.1, 0.1, 0.1, 0.8)
            end)

            table.insert(picker.holidayRows, holidayRow)
            y = y - 30
        end

        -- Update content height
        local contentHeight = math.max(-y + 10, 1)
        holidayContent:SetHeight(contentHeight)

        if holidayScroll.ScrollBar then
            if contentHeight > holidayScroll:GetHeight() then
                holidayScroll.ScrollBar:Show()
            else
                holidayScroll.ScrollBar:Hide()
                holidayScroll:SetVerticalScroll(0)
            end
        end
    end

    -- Add button functionality
    addBtn:SetScript("OnClick", function()
        if not parentDialog.targetPack then return end

        local holidayNames = {}
        for name in pairs(picker.selectedHolidays) do
            table.insert(holidayNames, name)
        end

        if #holidayNames == 0 then
            Stablemaster.Print("Please select at least one holiday.")
            return
        end

        EnsureConditions(parentDialog.targetPack)
        table.insert(parentDialog.targetPack.conditions, {
            type = "holiday",
            holidayNames = holidayNames,
            priority = StablemasterDB.settings.rulePriorities.holiday or 80,
        })

        local displayNames = table.concat(holidayNames, ", ")
        Stablemaster.VerbosePrint("Added holiday rule: " .. displayNames)

        RebuildRulesList(parentDialog.rulesList, parentDialog.targetPack)
        C_Timer.After(0.1, Stablemaster.SelectActivePack)

        if _G.StablemasterMainFrame and _G.StablemasterMainFrame.packPanel and _G.StablemasterMainFrame.packPanel.refreshPacks then
            _G.StablemasterMainFrame.packPanel.refreshPacks()
        end

        picker:Hide()
    end)

    -- OnShow: reset state and populate list
    picker:SetScript("OnShow", function(self)
        for i, name in ipairs(UISpecialFrames) do
            if name == "StablemasterHolidayPicker" then
                table.remove(UISpecialFrames, i)
                break
            end
        end
        table.insert(UISpecialFrames, "StablemasterHolidayPicker")

        self.selectedHolidays = {}
        addBtn:SetEnabled(false)
        PopulateHolidayList()
    end)

    picker:Hide()
    table.insert(UISpecialFrames, "StablemasterHolidayPicker")
    return picker
end

-- Season Picker Dialog
function StablemasterUI.CreateSeasonPicker(parentDialog)
    local picker = CreateFrame("Frame", "StablemasterSeasonPicker", UIParent, "BackdropTemplate")
    picker:SetSize(320, 280)
    picker:SetPoint("CENTER", parentDialog, "CENTER", 50, 0)
    picker:SetMovable(true)
    picker:EnableMouse(true)
    picker:EnableKeyboard(true)
    picker:SetFrameStrata("FULLSCREEN_DIALOG")
    picker:SetFrameLevel(parentDialog:GetFrameLevel() + 1)
    StablemasterUI.CreateDialogBackdrop(picker)

    -- Intercept ESC to close just this dialog
    picker:SetScript("OnKeyDown", function(self, key)
        if key == "ESCAPE" then
            self:Hide()
            self:SetPropagateKeyboardInput(false)
        else
            self:SetPropagateKeyboardInput(true)
        end
    end)

    -- Title bar
    local titleBar = StablemasterUI.CreateTitleBar(picker, "Select Seasons")
    picker.titleBar = titleBar

    -- Instructions
    local instructionText = StablemasterUI.CreateText(picker, STYLE.fontSizeSmall, STYLE.textDim)
    instructionText:SetPoint("TOPLEFT", picker, "TOPLEFT", STYLE.padding, -STYLE.headerHeight - STYLE.padding)
    instructionText:SetText("Select one or more seasons for this rule.")

    -- Current season display
    local currentLabel = StablemasterUI.CreateText(picker, STYLE.fontSizeSmall, STYLE.text)
    currentLabel:SetPoint("TOPLEFT", instructionText, "BOTTOMLEFT", 0, -8)
    currentLabel:SetText("Current season:")

    local currentSeasonText = StablemasterUI.CreateText(picker, STYLE.fontSizeSmall, STYLE.accent)
    currentSeasonText:SetPoint("LEFT", currentLabel, "RIGHT", 8, 0)
    picker.currentSeasonText = currentSeasonText

    -- Add Rule button
    local addBtn = StablemasterUI.CreateButton(picker, 80, STYLE.buttonHeight, "Add Rule")
    addBtn:SetPoint("BOTTOMRIGHT", picker, "BOTTOMRIGHT", -STYLE.padding, STYLE.padding)
    addBtn:SetEnabled(false)

    -- Cancel button
    local cancelBtn = StablemasterUI.CreateButton(picker, 80, STYLE.buttonHeight, "Cancel")
    cancelBtn:SetPoint("RIGHT", addBtn, "LEFT", -8, 0)
    cancelBtn:SetScript("OnClick", function() picker:Hide() end)

    -- Store state - multi-select
    picker.selectedSeasons = {} -- { [seasonName] = true }
    picker.seasonRows = {}

    -- Function to update add button state
    local function UpdateAddButtonState()
        local hasSelection = false
        for _ in pairs(picker.selectedSeasons) do
            hasSelection = true
            break
        end
        addBtn:SetEnabled(hasSelection)
    end

    -- Season list container
    local seasonContainer = CreateFrame("Frame", nil, picker)
    seasonContainer:SetPoint("TOPLEFT", currentLabel, "BOTTOMLEFT", 0, -15)
    seasonContainer:SetSize(280, 130)

    -- Populate seasons
    local currentSeason = Stablemaster.GetCurrentSeason()
    picker.currentSeasonText:SetText(currentSeason or "(Unknown)")

    local y = 0
    for i, season in ipairs(Stablemaster.Seasons) do
        local seasonRow = CreateFrame("Frame", nil, seasonContainer, "BackdropTemplate")
        seasonRow:SetSize(280, 28)
        seasonRow:SetPoint("TOPLEFT", seasonContainer, "TOPLEFT", 0, -y)
        StablemasterUI.CreateBackdrop(seasonRow, 0.6)

        -- Checkbox
        local seasonCheck = CreateFrame("CheckButton", nil, seasonRow, "BackdropTemplate")
        seasonCheck:SetSize(16, 16)
        seasonCheck:SetPoint("LEFT", seasonRow, "LEFT", 8, 0)
        StablemasterUI.CreateBackdrop(seasonCheck, 0.6)

        local checkmark = seasonCheck:CreateTexture(nil, "OVERLAY")
        checkmark:SetSize(12, 12)
        checkmark:SetPoint("CENTER")
        checkmark:SetTexture("Interface\\Buttons\\UI-CheckBox-Check")
        checkmark:SetDesaturated(true)
        checkmark:SetVertexColor(unpack(STYLE.accent))
        checkmark:Hide()
        seasonCheck.checkmark = checkmark

        local function UpdateCheckVisuals(self)
            if self:GetChecked() then
                self.checkmark:Show()
                self:SetBackdropBorderColor(unpack(STYLE.accent))
            else
                self.checkmark:Hide()
                self:SetBackdropBorderColor(unpack(STYLE.borderColor))
            end
        end

        seasonCheck:SetChecked(picker.selectedSeasons[season.name] or false)
        UpdateCheckVisuals(seasonCheck)

        -- Season name
        local seasonText = StablemasterUI.CreateText(seasonRow, STYLE.fontSizeNormal, STYLE.text)
        seasonText:SetPoint("LEFT", seasonCheck, "RIGHT", 8, 0)
        seasonText:SetText(season.name)

        -- Month range hint
        local monthNames = {"Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"}
        local monthHint = monthNames[season.months[1]] .. " - " .. monthNames[season.months[3]]
        local hintText = seasonRow:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        hintText:SetPoint("RIGHT", seasonRow, "RIGHT", -12, 0)
        hintText:SetText(monthHint)
        hintText:SetTextColor(0.5, 0.5, 0.5, 1)

        -- Mark if current
        if season.name == currentSeason then
            local currentMark = seasonRow:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            currentMark:SetPoint("RIGHT", hintText, "LEFT", -8, 0)
            currentMark:SetText("(now)")
            currentMark:SetTextColor(0.4, 1, 0.4, 1)
        end

        seasonCheck.seasonName = season.name

        -- Checkbox handler
        seasonCheck:SetScript("OnClick", function(self)
            UpdateCheckVisuals(self)
            if self:GetChecked() then
                picker.selectedSeasons[self.seasonName] = true
            else
                picker.selectedSeasons[self.seasonName] = nil
            end
            UpdateAddButtonState()
        end)

        -- Make whole row clickable
        seasonRow:EnableMouse(true)
        seasonRow:SetScript("OnMouseDown", function()
            seasonCheck:Click()
        end)

        seasonRow:SetScript("OnEnter", function(self)
            self:SetBackdropColor(0.2, 0.2, 0.2, 0.8)
        end)
        seasonRow:SetScript("OnLeave", function(self)
            self:SetBackdropColor(0.1, 0.1, 0.1, 0.8)
        end)

        table.insert(picker.seasonRows, seasonRow)
        y = y + 30
    end

    -- Add button functionality
    addBtn:SetScript("OnClick", function()
        if not parentDialog.targetPack then return end

        local seasonNames = {}
        for name in pairs(picker.selectedSeasons) do
            table.insert(seasonNames, name)
        end

        if #seasonNames == 0 then
            Stablemaster.Print("Please select at least one season.")
            return
        end

        EnsureConditions(parentDialog.targetPack)
        table.insert(parentDialog.targetPack.conditions, {
            type = "season",
            seasonNames = seasonNames,
            priority = StablemasterDB.settings.rulePriorities.season or 35,
        })

        local displayNames = table.concat(seasonNames, ", ")
        Stablemaster.VerbosePrint("Added season rule: " .. displayNames)

        RebuildRulesList(parentDialog.rulesList, parentDialog.targetPack)
        C_Timer.After(0.1, Stablemaster.SelectActivePack)

        if _G.StablemasterMainFrame and _G.StablemasterMainFrame.packPanel and _G.StablemasterMainFrame.packPanel.refreshPacks then
            _G.StablemasterMainFrame.packPanel.refreshPacks()
        end

        picker:Hide()
    end)

    -- OnShow: reset state
    picker:SetScript("OnShow", function(self)
        for i, name in ipairs(UISpecialFrames) do
            if name == "StablemasterSeasonPicker" then
                table.remove(UISpecialFrames, i)
                break
            end
        end
        table.insert(UISpecialFrames, "StablemasterSeasonPicker")

        -- Update current season
        local cs = Stablemaster.GetCurrentSeason()
        self.currentSeasonText:SetText(cs or "(Unknown)")

        -- Reset selections
        self.selectedSeasons = {}
        for _, row in ipairs(self.seasonRows) do
            local check = row:GetChildren()
            if check and check.SetChecked then
                check:SetChecked(false)
                if check.checkmark then check.checkmark:Hide() end
                check:SetBackdropBorderColor(unpack(STYLE.borderColor))
            end
        end
        addBtn:SetEnabled(false)
    end)

    picker:Hide()
    table.insert(UISpecialFrames, "StablemasterSeasonPicker")
    return picker
end

Stablemaster.Debug("UI/RulesDialog.lua loaded")