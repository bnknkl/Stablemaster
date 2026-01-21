-- Stablemaster: Pack Panel UI (Modern Style)
Stablemaster.Debug("UI/PackPanel.lua loading...")

local STYLE = StablemasterUI.Style

function StablemasterUI.SetupPackPanel(packPanel)
    -- Pack panel header
    local packTitle = StablemasterUI.CreateHeaderText(packPanel, "Mount Packs")
    packTitle:SetPoint("TOP", packPanel, "TOP", 0, -STYLE.padding)

    -- Button container for Create and Import
    local buttonContainer = CreateFrame("Frame", nil, packPanel)
    buttonContainer:SetPoint("TOP", packTitle, "BOTTOM", 0, -STYLE.padding)
    buttonContainer:SetSize(280, STYLE.buttonHeight + 4)

    -- Create New Pack button
    local createPackButton = StablemasterUI.CreateButton(buttonContainer, 130, STYLE.buttonHeight + 4, "Create New Pack")
    createPackButton:SetPoint("LEFT", buttonContainer, "LEFT", 0, 0)

    -- Import Pack button
    local importPackButton = StablemasterUI.CreateButton(buttonContainer, 130, STYLE.buttonHeight + 4, "Import Pack")
    importPackButton:SetPoint("LEFT", createPackButton, "RIGHT", 8, 0)

    -- Create pack list
    local packList = StablemasterUI.CreatePackList(packPanel)

    -- Store reference to dialog
    local packDialog = nil

    createPackButton:SetScript("OnClick", function()
        if not packDialog then
            packDialog = StablemasterUI.CreatePackDialog()
        end
        packDialog:Show()
    end)

    importPackButton:SetScript("OnClick", function()
        StablemasterUI.ShowImportDialog()
    end)

    -- Refresh function for pack list with escape handling
    local function refreshPacks()
        if packList then
            -- Clean up any temporary expanded frame (stored on packPanel, not content)
            if packPanel.tempExpandedFrame then
                packPanel.tempExpandedFrame:Hide()
                packPanel.tempExpandedFrame:SetParent(nil)
                packPanel.tempExpandedFrame = nil
            end

            -- Make sure the pack list is visible again
            packList:Show()

            local content = packList.content

            -- Get current packs
            local packs = Stablemaster.ListPacks()

            -- Clear existing frames
            local packFrames = packList.packFrames
            for i, frame in ipairs(packFrames) do
                if frame then
                    frame:Hide()
                    frame:SetParent(nil)
                end
            end
            packFrames = {}
            packList.packFrames = packFrames

            -- Create new frames
            for i, pack in ipairs(packs) do
                local frame = StablemasterUI.CreatePackFrame(content, pack)
                frame:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -(i-1) * 70)
                packFrames[i] = frame
                frame:Show()
            end

            -- Update content height
            local contentHeight = math.max(#packs * 70, 1)
            content:SetHeight(contentHeight)

            -- Reset scroll position
            local scrollFrame = content:GetParent()
            if scrollFrame and scrollFrame.SetVerticalScroll then
                scrollFrame:SetVerticalScroll(0)
            end
        end
    end

    -- Store references
    packPanel.createPackButton = createPackButton
    packPanel.packList = packList
    packPanel.refreshPacks = refreshPacks

    -- Also store a test function to verify the reference works
    packPanel.testFunction = function()
        Stablemaster.Debug("Test function called successfully")
        refreshPacks()
    end
end

function StablemasterUI.CreatePackList(parent)
    -- Create scroll frame for packs
    local scrollFrame = CreateFrame("ScrollFrame", nil, parent, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", parent, "TOPLEFT", STYLE.padding, -65)
    scrollFrame:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -26, STYLE.padding)

    -- Style the scrollbar
    if scrollFrame.ScrollBar then
        local scrollBar = scrollFrame.ScrollBar
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

    -- Create content frame
    local content = CreateFrame("Frame", nil, scrollFrame)
    content:SetSize(340, 1)
    scrollFrame:SetScrollChild(content)

    -- Store references
    scrollFrame.content = content
    scrollFrame.packFrames = {}

    return scrollFrame
end

function StablemasterUI.CreatePackFrame(parent, pack)
    local frame = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    frame:SetSize(340, 65)
    StablemasterUI.CreateBackdrop(frame, 0.4)

    -- Expansion state
    frame.isExpanded = false
    frame.mountFrames = {}

    -- Expand/collapse icon
    local expandIcon = frame:CreateTexture(nil, "OVERLAY")
    expandIcon:SetSize(12, 12)
    expandIcon:SetPoint("LEFT", frame, "LEFT", STYLE.padding, 8)
    expandIcon:SetTexture("Interface\\Buttons\\UI-PlusButton-Up")
    expandIcon:SetVertexColor(unpack(STYLE.textDim))
    frame.expandIcon = expandIcon

    -- Pack name
    local name = StablemasterUI.CreateText(frame, STYLE.fontSizeHeader, STYLE.textHeader)
    name:SetPoint("TOPLEFT", expandIcon, "TOPRIGHT", 6, 2)
    name:SetText(pack.name)
    frame.nameText = name

    -- Pack info (mount count, description, and rule count)
    local info = StablemasterUI.CreateText(frame, STYLE.fontSizeSmall, STYLE.textDim)
    info:SetPoint("TOPLEFT", name, "BOTTOMLEFT", 0, -2)
    info:SetPoint("RIGHT", frame, "RIGHT", -100, 0)

    local mountCount = #pack.mounts
    local infoText = mountCount .. " mount" .. (mountCount == 1 and "" or "s")
    if pack.description and pack.description ~= "" then
        infoText = infoText .. " - " .. pack.description
    end

    -- Count different rule types and add detailed indicator
    if pack.conditions and #pack.conditions > 0 then
        local ruleTypeCounts = {}

        for _, rule in ipairs(pack.conditions) do
            local ruleType = rule.type
            ruleTypeCounts[ruleType] = (ruleTypeCounts[ruleType] or 0) + 1
        end

        local ruleDetails = {}
        local ruleColors = {
            zone = STYLE.ruleZone,
            transmog = STYLE.ruleTransmog,
            custom_transmog = STYLE.ruleTransmog,
            class = STYLE.ruleClass,
            race = STYLE.ruleRace,
        }
        local ruleNames = {
            zone = "zone",
            transmog = "transmog",
            custom_transmog = "custom",
            class = "class",
            race = "race",
        }

        for ruleType, count in pairs(ruleTypeCounts) do
            local color = ruleColors[ruleType] or STYLE.text
            local typeName = ruleNames[ruleType] or ruleType
            local colorHex = string.format("|cff%02x%02x%02x", color[1]*255, color[2]*255, color[3]*255)
            table.insert(ruleDetails, colorHex .. count .. " " .. typeName .. "|r")
        end

        if #ruleDetails > 0 then
            infoText = infoText .. " | " .. table.concat(ruleDetails, ", ")
        end
    end

    info:SetText(infoText)
    frame.infoText = info

    -- Status indicator (shows shared/character status on top line, fallback below)
    local statusText = StablemasterUI.CreateText(frame, STYLE.fontSizeSmall, STYLE.textDim, "RIGHT")
    statusText:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -STYLE.padding, -STYLE.padding)

    local fallbackText = StablemasterUI.CreateText(frame, STYLE.fontSizeSmall, STYLE.textDim, "RIGHT")
    fallbackText:SetPoint("TOPRIGHT", statusText, "BOTTOMRIGHT", 0, -2)

    local function updateStatusDisplay()
        -- Show shared/character status
        if pack.isShared then
            local c = STYLE.shared
            statusText:SetText(string.format("|cff%02x%02x%02xShared|r", c[1]*255, c[2]*255, c[3]*255))
        else
            local c = STYLE.character
            statusText:SetText(string.format("|cff%02x%02x%02xCharacter-specific|r", c[1]*255, c[2]*255, c[3]*255))
        end

        -- Show fallback status on second line if applicable
        if pack.isFallback then
            local c = STYLE.fallback
            fallbackText:SetText(string.format("|cff%02x%02x%02xFallback|r", c[1]*255, c[2]*255, c[3]*255))
            fallbackText:Show()
        else
            fallbackText:SetText("")
            fallbackText:Hide()
        end
    end
    updateStatusDisplay()
    frame.updateStatusDisplay = updateStatusDisplay

    -- Add transmog apply button if pack has transmog rules
    local hasTransmogRule = false
    local transmogSetID = nil
    if pack.conditions then
        for _, rule in ipairs(pack.conditions) do
            if rule.type == "transmog" then
                hasTransmogRule = true
                transmogSetID = rule.setID
                break
            end
        end
    end

    if hasTransmogRule and transmogSetID then
        local applyTransmogBtn = StablemasterUI.CreateButton(frame, 70, 18, "Apply Set")
        applyTransmogBtn:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -STYLE.padding, -STYLE.padding)

        applyTransmogBtn:SetScript("OnEnter", function(self)
            self:SetBackdropBorderColor(unpack(STYLE.accent))
            self.text:SetTextColor(unpack(STYLE.accent))
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText("Apply Transmog Set", 1, 1, 1, 1, true)
            if C_Transmog.IsAtTransmogNPC() then
                GameTooltip:AddLine("Apply this pack's transmog set.", 1, 1, 0.8, true)
                local setInfo = Stablemaster.GetTransmogSetInfo(transmogSetID)
                if setInfo then
                    GameTooltip:AddLine("Set: " .. setInfo.name, 0.8, 0.8, 1, true)
                end
            else
                GameTooltip:AddLine("Must be at a transmog vendor.", 1, 0.5, 0.5, true)
            end
            GameTooltip:Show()
        end)
        applyTransmogBtn:SetScript("OnLeave", function(self)
            self:SetBackdropBorderColor(unpack(STYLE.borderColor))
            self.text:SetTextColor(unpack(STYLE.text))
            GameTooltip:Hide()
        end)

        applyTransmogBtn:SetScript("OnClick", function()
            if not C_Transmog.IsAtTransmogNPC() then
                Stablemaster.Print("Must be at a transmog vendor to apply sets")
                return
            end
            local success, message = Stablemaster.ApplyTransmogSet(transmogSetID)
            Stablemaster.Print(message)
        end)

        frame.applyTransmogBtn = applyTransmogBtn
    end

    -- Hover effects
    frame:EnableMouse(true)
    StablemasterUI.ApplyRowHover(frame, {STYLE.bgColor[1], STYLE.bgColor[2], STYLE.bgColor[3], 0.4})

    frame.onEnter = function(self)
        expandIcon:SetVertexColor(unpack(STYLE.accent))

        if StablemasterUI.IsMountBeingDragged() then
            name:SetTextColor(unpack(STYLE.active))
        else
            GameTooltip:SetOwner(self, "ANCHOR_CURSOR")
            GameTooltip:SetText(pack.name, 1, 1, 1)
            if pack.description and pack.description ~= "" then
                GameTooltip:AddLine(pack.description, 1, 1, 0.8, true)
            end
            GameTooltip:AddLine(" ", 1, 1, 1)
            GameTooltip:AddLine("Left-click: Expand/collapse", 0.7, 0.7, 0.7)
            GameTooltip:AddLine("Right-click: Pack options", 0.7, 0.7, 0.7)
            GameTooltip:Show()
        end
    end

    frame.onLeave = function(self)
        expandIcon:SetVertexColor(unpack(STYLE.textDim))
        name:SetTextColor(unpack(STYLE.textHeader))
        GameTooltip:Hide()
    end

    -- Click handler
    frame:SetScript("OnMouseUp", function(self, button)
        if button == "LeftButton" then
            StablemasterUI.TogglePackExpansion(self, pack)
        elseif button == "RightButton" then
            local x, y = GetCursorPosition()
            local scale = UIParent:GetEffectiveScale()
            StablemasterUI.ShowPackContextMenu(pack, x / scale, y / scale)
        end
    end)

    frame.pack = pack
    return frame
end

function StablemasterUI.UpdatePackList(scrollFrame)
    Stablemaster.Debug("UpdatePackList starting...")

    local content = scrollFrame.content
    local packFrames = scrollFrame.packFrames

    local packs = Stablemaster.ListPacks()

    for i, pack in ipairs(packs) do
        local frame = packFrames[i]
        if not frame then
            frame = StablemasterUI.CreatePackFrame(content, pack)
            frame:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -(i-1) * 70)
            packFrames[i] = frame
        else
            frame.pack = pack
        end
        frame:Show()
    end

    for i = #packs + 1, #packFrames do
        packFrames[i]:Hide()
    end

    local contentHeight = math.max(#packs * 70, 1)
    content:SetHeight(contentHeight)
end

-- Pack Expansion Functions
function StablemasterUI.TogglePackExpansion(packFrame, pack)
    local packPanel = _G.StablemasterMainFrame and _G.StablemasterMainFrame.packPanel
    local isCurrentlyExpanded = packPanel and packPanel.tempExpandedFrame and packPanel.tempExpandedFrame:IsShown()

    if isCurrentlyExpanded then
        if packPanel then
            if packPanel.tempExpandedFrame then
                packPanel.tempExpandedFrame:Hide()
                packPanel.tempExpandedFrame:SetParent(nil)
                packPanel.tempExpandedFrame = nil
            end
            if packPanel.packList then
                packPanel.packList:Show()
            end
        end
    else
        if _G.StablemasterMainFrame and _G.StablemasterMainFrame.packPanel then
            local packList = packPanel.packList

            if packList then
                packList:Hide()
            end

            if packPanel.tempExpandedFrame then
                packPanel.tempExpandedFrame:Hide()
                packPanel.tempExpandedFrame:SetParent(nil)
            end

            local availableWidth = 340
            local availableHeight = packPanel:GetHeight() - 80

            -- Create scroll frame with modern style
            local expandedScrollFrame = CreateFrame("ScrollFrame", nil, packPanel, "UIPanelScrollFrameTemplate")
            expandedScrollFrame:SetPoint("TOPLEFT", packPanel, "TOPLEFT", STYLE.padding, -65)
            expandedScrollFrame:SetSize(availableWidth, availableHeight)

            -- Style scrollbar
            if expandedScrollFrame.ScrollBar then
                local scrollBar = expandedScrollFrame.ScrollBar
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

            -- Create content frame with modern style
            local expandedContent = CreateFrame("Frame", nil, expandedScrollFrame, "BackdropTemplate")
            expandedContent:SetSize(availableWidth - 30, 100)
            expandedScrollFrame:SetScrollChild(expandedContent)
            StablemasterUI.CreateBackdrop(expandedContent, 0.6)

            expandedContent.isExpanded = true
            expandedContent.mountFrames = {}
            expandedContent.pack = pack

            -- Minus button
            local minusButton = expandedContent:CreateTexture(nil, "OVERLAY")
            minusButton:SetSize(12, 12)
            minusButton:SetPoint("TOPLEFT", expandedContent, "TOPLEFT", STYLE.padding, -STYLE.padding)
            minusButton:SetTexture("Interface\\Buttons\\UI-MinusButton-Up")
            minusButton:SetVertexColor(unpack(STYLE.accent))
            expandedContent.minusButton = minusButton

            -- Pack title
            local name = StablemasterUI.CreateText(expandedContent, STYLE.fontSizeHeader, STYLE.textHeader)
            name:SetPoint("TOPLEFT", minusButton, "TOPRIGHT", 6, 2)
            name:SetText(pack.name)
            expandedContent.nameText = name

            -- Pack info
            local info = StablemasterUI.CreateText(expandedContent, STYLE.fontSizeSmall, STYLE.textDim)
            info:SetPoint("TOPLEFT", name, "BOTTOMLEFT", 0, -2)
            info:SetPoint("RIGHT", expandedContent, "RIGHT", -STYLE.padding, 0)

            local mountCount = #pack.mounts
            local infoText = mountCount .. " mount" .. (mountCount == 1 and "" or "s")
            if pack.description and pack.description ~= "" then
                infoText = infoText .. " - " .. pack.description
            end
            if pack.conditions and #pack.conditions > 0 then
                infoText = infoText .. " | " .. #pack.conditions .. " rule" .. (#pack.conditions == 1 and "" or "s")
            end
            info:SetText(infoText)
            expandedContent.infoText = info

            -- Tip text
            local tipText = StablemasterUI.CreateText(expandedContent, STYLE.fontSizeSmall, STYLE.textDim)
            tipText:SetPoint("TOPLEFT", info, "BOTTOMLEFT", 0, -2)
            tipText:SetText("Ctrl+Click to remove mount")

            -- Click handler
            expandedContent:EnableMouse(true)
            expandedContent:SetScript("OnMouseUp", function(self, button)
                if button == "LeftButton" then
                    StablemasterUI.TogglePackExpansion(self, pack)
                elseif button == "RightButton" then
                    local x, y = GetCursorPosition()
                    local scale = UIParent:GetEffectiveScale()
                    StablemasterUI.ShowPackContextMenu(pack, x / scale, y / scale)
                end
            end)

            expandedContent:Show()
            expandedScrollFrame:Show()

            -- Add mounts
            if #pack.mounts > 0 then
                local sortedMounts = {}
                for _, mountID in ipairs(pack.mounts) do
                    local mountName = C_MountJournal.GetMountInfoByID(mountID)
                    table.insert(sortedMounts, {
                        id = mountID,
                        name = mountName or "Unknown Mount"
                    })
                end

                table.sort(sortedMounts, function(a, b)
                    return a.name < b.name
                end)

                local yOffset = -55
                for i, mountData in ipairs(sortedMounts) do
                    local mountFrame = CreateFrame("Frame", nil, expandedContent, "BackdropTemplate")
                    mountFrame:SetSize(290, 28)
                    mountFrame:SetPoint("TOPLEFT", expandedContent, "TOPLEFT", STYLE.padding, yOffset)
                    StablemasterUI.CreateBackdrop(mountFrame, 0.3)

                    local mountName, spellID, icon = C_MountJournal.GetMountInfoByID(mountData.id)

                    -- Mount icon
                    local mountIcon = mountFrame:CreateTexture(nil, "ARTWORK")
                    mountIcon:SetSize(22, 22)
                    mountIcon:SetPoint("LEFT", mountFrame, "LEFT", 4, 0)
                    mountIcon:SetTexture(icon)

                    -- Mount name
                    local mountNameText = StablemasterUI.CreateText(mountFrame, STYLE.fontSizeNormal, STYLE.text)
                    mountNameText:SetPoint("LEFT", mountIcon, "RIGHT", 6, 0)
                    mountNameText:SetText(mountData.name)

                    -- Click and hover
                    mountFrame:EnableMouse(true)
                    local isHovering = false

                    local function updateHoverState()
                        if isHovering then
                            if IsControlKeyDown() then
                                mountFrame:SetBackdropColor(STYLE.error[1]*0.3, STYLE.error[2]*0.3, STYLE.error[3]*0.3, 0.8)
                                mountFrame:SetBackdropBorderColor(unpack(STYLE.error))
                                mountNameText:SetTextColor(unpack(STYLE.error))
                            else
                                mountFrame:SetBackdropBorderColor(unpack(STYLE.accent))
                                mountNameText:SetTextColor(unpack(STYLE.accent))
                            end
                        else
                            mountFrame:SetBackdropColor(STYLE.bgColor[1], STYLE.bgColor[2], STYLE.bgColor[3], 0.3)
                            mountFrame:SetBackdropBorderColor(unpack(STYLE.borderColor))
                            mountNameText:SetTextColor(unpack(STYLE.text))
                        end
                    end

                    mountFrame:SetScript("OnEnter", function(self)
                        isHovering = true
                        updateHoverState()
                    end)

                    mountFrame:SetScript("OnLeave", function(self)
                        isHovering = false
                        updateHoverState()
                    end)

                    mountFrame:SetScript("OnUpdate", function(self)
                        if isHovering then
                            updateHoverState()
                        end
                    end)

                    mountFrame:SetScript("OnMouseUp", function(self, button)
                        if button == "LeftButton" and IsControlKeyDown() then
                            local success, message = Stablemaster.RemoveMountFromPack(pack.name, mountData.id)
                            if success then
                                Stablemaster.VerbosePrint("Removed " .. mountData.name .. " from pack " .. pack.name)
                                StablemasterUI.TogglePackExpansion(expandedContent, pack)
                                StablemasterUI.TogglePackExpansion(expandedContent, pack)
                            else
                                Stablemaster.Print("Error: " .. message)
                            end
                        end
                    end)

                    mountFrame:Show()
                    expandedContent.mountFrames[i] = mountFrame
                    yOffset = yOffset - 30
                end

                local contentHeight = 55 + (#sortedMounts * 30) + STYLE.padding
                expandedContent:SetHeight(contentHeight)
            else
                local noMountsText = StablemasterUI.CreateText(expandedContent, STYLE.fontSizeNormal, STYLE.textDim)
                noMountsText:SetPoint("TOPLEFT", tipText, "BOTTOMLEFT", STYLE.padding, -4)
                noMountsText:SetText("No mounts in this pack")
                expandedContent:SetHeight(95)
            end

            packPanel.tempExpandedFrame = expandedScrollFrame

            if StablemasterDB and StablemasterDB.settings and StablemasterDB.settings.debugMode then
                Stablemaster.Debug("Created scrollable expansion with " .. #pack.mounts .. " mounts")
            end
        end
    end
end

function StablemasterUI.ExpandPackFrame(packFrame, pack)
    packFrame.isExpanded = true

    local baseHeight = 65
    local newHeight

    if #pack.mounts > 0 then
        local mountsHeight = #pack.mounts * 30 + STYLE.padding
        newHeight = baseHeight + mountsHeight
    else
        newHeight = 85
    end

    packFrame:SetHeight(newHeight)
    packFrame.expandIcon:SetTexture("Interface\\Buttons\\UI-MinusButton-Up")

    if #pack.mounts > 0 then
        for i, mountID in ipairs(pack.mounts) do
            local mountFrame = StablemasterUI.CreatePackMountFrame(packFrame, mountID, i)
            packFrame.mountFrames[i] = mountFrame
        end
    else
        local noMountsText = StablemasterUI.CreateText(packFrame, STYLE.fontSizeNormal, STYLE.textDim)
        noMountsText:SetPoint("TOPLEFT", packFrame.infoText, "BOTTOMLEFT", STYLE.padding, -4)
        noMountsText:SetText("No mounts in this pack")
        packFrame.noMountsText = noMountsText
    end
end

function StablemasterUI.CollapsePackFrame(packFrame)
    packFrame.isExpanded = false
    packFrame.expandIcon:SetTexture("Interface\\Buttons\\UI-PlusButton-Up")

    for _, mountFrame in ipairs(packFrame.mountFrames) do
        mountFrame:Hide()
        mountFrame:SetParent(nil)
    end
    packFrame.mountFrames = {}

    if packFrame.noMountsText then
        packFrame.noMountsText:Hide()
        packFrame.noMountsText = nil
    end

    packFrame:SetHeight(65)
end

function StablemasterUI.CreatePackMountFrame(packFrame, mountID, index)
    local mountFrame = CreateFrame("Frame", nil, packFrame, "BackdropTemplate")
    mountFrame:SetSize(290, 28)
    StablemasterUI.CreateBackdrop(mountFrame, 0.3)

    if index == 1 then
        mountFrame:SetPoint("TOPLEFT", packFrame.infoText, "BOTTOMLEFT", STYLE.padding, -4)
    else
        local prevFrame = packFrame.mountFrames[index - 1]
        mountFrame:SetPoint("TOPLEFT", prevFrame, "BOTTOMLEFT", 0, -2)
    end

    local name, spellID, icon = C_MountJournal.GetMountInfoByID(mountID)

    local mountIcon = mountFrame:CreateTexture(nil, "ARTWORK")
    mountIcon:SetSize(22, 22)
    mountIcon:SetPoint("LEFT", mountFrame, "LEFT", 4, 0)
    mountIcon:SetTexture(icon)

    local mountName = StablemasterUI.CreateText(mountFrame, STYLE.fontSizeNormal, STYLE.text)
    mountName:SetPoint("LEFT", mountIcon, "RIGHT", 6, 0)
    mountName:SetPoint("RIGHT", mountFrame, "RIGHT", -24, 0)
    mountName:SetText(name or "Unknown Mount")

    -- Remove button
    local removeButton = StablemasterUI.CreateCloseButton(mountFrame)
    removeButton:SetSize(16, 16)
    removeButton:SetPoint("RIGHT", mountFrame, "RIGHT", -4, 0)

    removeButton:SetScript("OnEnter", function(self)
        self:SetBackdropBorderColor(unpack(STYLE.error))
        self.x:SetTextColor(unpack(STYLE.error))
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Remove from pack", 1, 1, 1)
        GameTooltip:Show()
    end)

    removeButton:SetScript("OnLeave", function(self)
        self:SetBackdropBorderColor(unpack(STYLE.borderColor))
        self.x:SetTextColor(unpack(STYLE.textDim))
        GameTooltip:Hide()
    end)

    removeButton:SetScript("OnClick", function(self)
        Stablemaster.Debug("Remove button clicked for mount ID: " .. mountID)

        local success, message = Stablemaster.RemoveMountFromPack(packFrame.pack.name, mountID)
        Stablemaster.VerbosePrint(message)

        if success then
            Stablemaster.Debug("Mount removed successfully, updating UI in-place")

            local updatedPack = Stablemaster.GetPack(packFrame.pack.name)
            if updatedPack then
                Stablemaster.Debug("Updated pack has " .. #updatedPack.mounts .. " mounts remaining")

                packFrame.pack = updatedPack

                mountFrame:Hide()
                mountFrame:SetParent(nil)

                for i, frame in ipairs(packFrame.mountFrames) do
                    if frame == mountFrame then
                        table.remove(packFrame.mountFrames, i)
                        Stablemaster.Debug("Removed mount frame from list, " .. #packFrame.mountFrames .. " frames remaining")
                        break
                    end
                end

                for i, frame in ipairs(packFrame.mountFrames) do
                    frame:ClearAllPoints()
                    if i == 1 then
                        frame:SetPoint("TOPLEFT", packFrame.infoText, "BOTTOMLEFT", STYLE.padding, -4)
                    else
                        frame:SetPoint("TOPLEFT", packFrame.mountFrames[i-1], "BOTTOMLEFT", 0, -2)
                    end
                end

                local baseHeight = 65
                local newHeight
                if #updatedPack.mounts > 0 then
                    local mountsHeight = #updatedPack.mounts * 30 + STYLE.padding
                    newHeight = baseHeight + mountsHeight
                    Stablemaster.Debug("Calculated new height: " .. newHeight)
                end
            end
        end
    end)

    -- Hover and tooltip
    mountFrame:EnableMouse(true)
    mountFrame:SetScript("OnEnter", function(self)
        self:SetBackdropBorderColor(unpack(STYLE.accent))
        mountName:SetTextColor(unpack(STYLE.accent))
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        if spellID then
            GameTooltip:SetMountBySpellID(spellID)
        else
            GameTooltip:SetText(name or "Unknown Mount", 1, 1, 1)
        end
        GameTooltip:Show()

        local mountData = { id = mountID, name = name, spellID = spellID }
        StablemasterUI.ShowMountModelFlyout(mountData)
    end)

    mountFrame:SetScript("OnLeave", function(self)
        self:SetBackdropBorderColor(unpack(STYLE.borderColor))
        mountName:SetTextColor(unpack(STYLE.text))
        GameTooltip:Hide()
        C_Timer.After(0.5, function()
            if self:IsMouseOver() then
                return
            end
            local shouldHide = true
            if _G.StablemasterMountModelFlyout and _G.StablemasterMountModelFlyout.isMouseOver then
                shouldHide = false
            end
            if _G.StablemasterMountDebugFlyout and _G.StablemasterMountDebugFlyout.isMouseOver then
                shouldHide = false
            end
            if shouldHide then
                StablemasterUI.HideMountModelFlyout()
            end
        end)
    end)

    return mountFrame
end

-- Pack Visibility Functions
function StablemasterUI.HideOtherPackFrames(expandedFrame)
    if _G.StablemasterMainFrame and _G.StablemasterMainFrame.packPanel and _G.StablemasterMainFrame.packPanel.packList then
        local packFrames = _G.StablemasterMainFrame.packPanel.packList.packFrames
        for _, frame in ipairs(packFrames) do
            if frame ~= expandedFrame then
                frame:Hide()
            end
        end
    end
end

function StablemasterUI.ShowAllPackFrames()
    if _G.StablemasterMainFrame and _G.StablemasterMainFrame.packPanel and _G.StablemasterMainFrame.packPanel.packList then
        local packFrames = _G.StablemasterMainFrame.packPanel.packList.packFrames
        for _, frame in ipairs(packFrames) do
            frame:Show()
        end
    end
end

function StablemasterUI.MovePackToTop(expandedFrame)
    expandedFrame:ClearAllPoints()
    if _G.StablemasterMainFrame and _G.StablemasterMainFrame.packPanel and _G.StablemasterMainFrame.packPanel.packList then
        local content = _G.StablemasterMainFrame.packPanel.packList.content
        expandedFrame:SetPoint("TOPLEFT", content, "TOPLEFT", 0, 0)
    end
end

-- Helper function for delete confirmation
function StablemasterUI.ShowDeleteConfirmation(pack)
    local deleteConfirmDialog = StablemasterUI.CreateDeleteConfirmationDialog()
    deleteConfirmDialog.targetPack = pack
    deleteConfirmDialog.packNameText:SetText('"' .. pack.name .. '"')
    deleteConfirmDialog:Show()
end

-- Helper function for duplicate confirmation
function StablemasterUI.ShowDuplicateDialog(pack)
    local duplicateDialog = StablemasterUI.CreateDuplicatePackDialog()
    duplicateDialog.sourcePack = pack
    duplicateDialog:Show()
end

-- Helper function to check if a mount is being dragged
function StablemasterUI.IsMountBeingDragged()
    if _G.StablemasterMainFrame and _G.StablemasterMainFrame.mountPanel and _G.StablemasterMainFrame.mountPanel.mountList then
        local buttons = _G.StablemasterMainFrame.mountPanel.mountList.buttons
        for _, button in ipairs(buttons) do
            if button.isDragging then
                return true
            end
        end
    end
    return false
end

Stablemaster.Debug("UI/PackPanel.lua loaded")
