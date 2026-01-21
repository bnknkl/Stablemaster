Stablemaster.Debug("MountJournalHook.lua loading...")

local MountJournalHook = {}
local STYLE = StablemasterUI.Style

-- Check if a mount exists in a specific pack
local function IsMountInPack(mountID, packName)
    local pack = Stablemaster.GetPackByName(packName)
    if not pack then return false end
    
    -- TODO: this is probably slow for large packs, maybe use a lookup table?
    for _, existingMountID in ipairs(pack.mounts) do
        if existingMountID == mountID then
            return true
        end
    end
    return false
end

local function GetPacksForDropdown(mountID)
    local packs = {}
    
    -- Show shared packs first
    if StablemasterDB.sharedPacks then
        for _, pack in ipairs(StablemasterDB.sharedPacks) do
            local isInPack = IsMountInPack(mountID, pack.name)
            table.insert(packs, {
                name = pack.name,
                isShared = true,
                text = pack.name .. " (Account)",
                isInPack = isInPack
            })
        end
    end
    
    -- Add character-specific packs after shared packs
    local charPacks = Stablemaster.GetCharacterPacks()
    for _, pack in ipairs(charPacks) do
        local mountInPack = IsMountInPack(mountID, pack.name)  
        table.insert(packs, {
            name = pack.name,
            isShared = false,
            text = pack.name .. " (Character)",
            isInPack = mountInPack
        })
    end
    
    return packs
end

-- Add mount to pack with message output
local function AddMountToPackFromContext(packName, mountID)
    local success, message = Stablemaster.AddMountToPack(packName, mountID)
    if success then
        Stablemaster.Print("[+] " .. message)
    else
        Stablemaster.Print("[-] " .. message)
    end
    -- TODO: maybe refresh the context menu after adding? right now you have to close and reopen to see the X
end

local function RemoveMountFromPackContext(packName, mountID)
    local success, message = Stablemaster.RemoveMountFromPack(packName, mountID)
    if success then
        Stablemaster.Print("[-] " .. message)
    else
        Stablemaster.Print("[!] " .. message)
    end
end

-- Create custom context menu for mount journal
local function CreateStablemasterContextMenu(self, level, menuList)
    if level == 1 then
        local mountID = self.mountID
        if not mountID then return end
        
        local name, spellID, icon, active, isUsable, sourceType, isFavorite = C_MountJournal.GetMountInfoByID(mountID)
        if not name then return end
        
        UIDropDownMenu_AddButton({
            text = "Mount",
            notCheckable = true,
            func = function()
                C_MountJournal.SummonByID(mountID)
                CloseDropDownMenus()
            end,
        }, level)
        
        if isFavorite then
            UIDropDownMenu_AddButton({
                text = "Remove Favorite",
                notCheckable = true,
                func = function()
                    C_MountJournal.SetIsFavorite(mountID, false)
                    CloseDropDownMenus()
                end,
            }, level)
        else
            UIDropDownMenu_AddButton({
                text = "Set Favorite",
                notCheckable = true,
                func = function()
                    C_MountJournal.SetIsFavorite(mountID, true)
                    CloseDropDownMenus()
                end,
            }, level)
        end
        
        local packs = GetPacksForDropdown(mountID)
        UIDropDownMenu_AddSeparator(level)
        
        if #packs > 0 then
            UIDropDownMenu_AddButton({
                text = "|cFF00FF96Add to Stablemaster Pack|r",
                hasArrow = true,
                notCheckable = true,
                menuList = "STABLEMASTER_PACKS",
            }, level)
        else
            UIDropDownMenu_AddButton({
                text = "|cFF00C0FFCreate new pack...|r",
                notCheckable = true,
                func = function()
                    CloseDropDownMenus()
                    MountJournalHook.ShowCreatePackDialog(mountID)
                end,
                tooltipTitle = "Create New Pack",
                tooltipText = "Create a new pack and add this mount to it",
            }, level)
        end
        
    elseif menuList == "STABLEMASTER_PACKS" then
        local mountID = UIDROPDOWNMENU_INIT_MENU.mountID
        local packs = GetPacksForDropdown(mountID)
        
        if #packs == 0 then
            UIDropDownMenu_AddButton({
                text = "|cFFFF6B6BNo packs available|r",
                notCheckable = true,
                disabled = true,
            }, level)
            UIDropDownMenu_AddButton({
                text = "Use /stablemaster ui to create packs",
                notCheckable = true,
                disabled = true,
            }, level)
        else
            for _, pack in ipairs(packs) do
                local displayText = pack.text
                local func = nil
                local tooltipTitle = ""
                local tooltipText = ""
                
                if pack.isInPack then
                    displayText = "|cFFFF4444X|r |cFF808080" .. pack.text .. "|r"
                    func = function()
                        RemoveMountFromPackContext(pack.name, mountID)
                        CloseDropDownMenus()
                    end
                    tooltipTitle = "Remove from Pack"
                    tooltipText = "Click the X to remove this mount from " .. pack.text
                else
                    displayText = pack.text
                    func = function()
                        AddMountToPackFromContext(pack.name, mountID)
                        CloseDropDownMenus()
                    end
                    tooltipTitle = "Add to Pack"
                    tooltipText = "Click to add this mount to " .. pack.text
                end
                
                UIDropDownMenu_AddButton({
                    text = displayText,
                    notCheckable = true,
                    func = func,
                    tooltipTitle = tooltipTitle,
                    tooltipText = tooltipText,
                }, level)
            end
            
            UIDropDownMenu_AddSeparator(level)
            
            UIDropDownMenu_AddButton({
                text = "|cFF00C0FFCreate new pack...|r",
                notCheckable = true,
                func = function()
                    CloseDropDownMenus()
                    MountJournalHook.ShowCreatePackDialog(mountID)
                end,
                tooltipTitle = "Create New Pack",
                tooltipText = "Create a new pack and add this mount to it",
            }, level)
        end
    end
end

local originalMountJournalInitialize = nil

-- Initialize mount journal context menu hooks
function MountJournalHook.Initialize()
    local function SetupHook()
        if not MountJournal then
            return false
        end
        
        Stablemaster.Debug("Setting up mount journal context menu hook")
        
        if MountJournal.mountOptionsMenu then
            local menu = MountJournal.mountOptionsMenu
            if menu.initialize then
                originalMountJournalInitialize = menu.initialize
                
                menu.initialize = function(self, level, menuList)
                    CreateStablemasterContextMenu(self, level, menuList)
                end
                
                Stablemaster.Debug("Successfully hooked mount journal context menu")
                return true
            end
        end
        
        if MountJournal and MountJournal.ListScrollFrame and MountJournal.ListScrollFrame.buttons then
            for _, button in pairs(MountJournal.ListScrollFrame.buttons) do
                if button and button.SetScript then
                    local originalOnClick = button:GetScript("OnClick")
                    button:SetScript("OnClick", function(self, mouseButton, down)
                        if mouseButton == "RightButton" and not down then
                            return
                        else
                            if originalOnClick then
                                originalOnClick(self, mouseButton, down)
                            end
                        end
                    end)
                end
            end
        end
        
        if MountJournal_InitMountButton then
            local originalInitButton = MountJournal_InitMountButton
            MountJournal_InitMountButton = function(button, elementData)
                originalInitButton(button, elementData)
                
                if button and elementData and elementData.mountID then
                    button.mountID = elementData.mountID
                    
                    -- Store the original OnClick handler
                    local originalOnClick = button:GetScript("OnClick")
                    
                    button:SetScript("OnClick", function(self, mouseButton, down)
                        if mouseButton == "RightButton" and not down then
                            local mountID = self.mountID
                            if mountID then
                                CloseDropDownMenus()
                                
                                local menu = CreateFrame("Frame", "StablemasterContextMenu" .. mountID, UIParent, "UIDropDownMenuTemplate")
                                menu.mountID = mountID
                                UIDropDownMenu_Initialize(menu, CreateStablemasterContextMenu, "MENU")
                                
                                ToggleDropDownMenu(1, nil, menu, "cursor", 3, -3)
                                
                                return
                            end
                        else
                            -- For all other clicks (including left-click), use the original behavior
                            if originalOnClick then
                                originalOnClick(self, mouseButton, down)
                            end
                        end
                    end)
                    
                    if button.SetAttribute then
                        button:SetAttribute("type", nil)
                        button:SetAttribute("spell", nil)
                    end
                end
            end
            
            Stablemaster.Debug("Successfully hooked MountJournal_InitMountButton")
            return true
        end
        
        return false
    end
    
    if not SetupHook() then
        local frame = CreateFrame("Frame")
        frame:RegisterEvent("ADDON_LOADED")
        frame:SetScript("OnEvent", function(self, event, addonName)
            if addonName == "Blizzard_Collections" then
                C_Timer.After(1, function()
                    if SetupHook() then
                        frame:UnregisterEvent("ADDON_LOADED")
                    end
                end)
            end
        end)
    end
end

MountJournalHook.Initialize()

-- Create pack dialog with automatic mount adding
function MountJournalHook.ShowCreatePackDialog(mountID)
    local dialog = CreateFrame("Frame", "StablemasterPackDialogFromJournal", UIParent, "BackdropTemplate")
    dialog:SetSize(400, 250)
    dialog:SetPoint("CENTER")
    dialog:SetMovable(true)
    dialog:EnableMouse(true)
    dialog:SetFrameStrata("DIALOG")
    StablemasterUI.CreateDialogBackdrop(dialog)

    -- Title bar
    local titleBar = StablemasterUI.CreateTitleBar(dialog, "Create New Pack")
    dialog.titleBar = titleBar

    local nameLabel = StablemasterUI.CreateText(dialog, STYLE.fontSizeNormal, STYLE.text)
    nameLabel:SetPoint("TOPLEFT", dialog, "TOPLEFT", STYLE.padding, -STYLE.headerHeight - STYLE.padding)
    nameLabel:SetText("Pack Name:")

    local nameInput = StablemasterUI.CreateEditBox(dialog, 200, 22)
    nameInput:SetPoint("TOPLEFT", nameLabel, "BOTTOMLEFT", 0, -5)
    nameInput:SetAutoFocus(false)
    nameInput:SetMaxLetters(30)

    local descLabel = StablemasterUI.CreateText(dialog, STYLE.fontSizeNormal, STYLE.text)
    descLabel:SetPoint("TOPLEFT", nameInput, "BOTTOMLEFT", 0, -15)
    descLabel:SetText("Description (optional):")

    local descInput = StablemasterUI.CreateEditBox(dialog, 300, 22)
    descInput:SetPoint("TOPLEFT", descLabel, "BOTTOMLEFT", 0, -5)
    descInput:SetAutoFocus(false)
    descInput:SetMaxLetters(100)

    -- Add info text about auto-adding the mount with more spacing
    local infoText = StablemasterUI.CreateText(dialog, STYLE.fontSizeSmall, {0.8, 0.8, 1, 1})
    infoText:SetPoint("TOPLEFT", descInput, "BOTTOMLEFT", 0, -20)
    infoText:SetPoint("RIGHT", dialog, "RIGHT", -STYLE.padding, 0)
    infoText:SetText("This mount will be automatically added to the new pack.")

    local createButton = StablemasterUI.CreateButton(dialog, 80, STYLE.buttonHeight, "Create")
    createButton:SetPoint("BOTTOMRIGHT", dialog, "BOTTOMRIGHT", -STYLE.padding, STYLE.padding)

    local cancelButton = StablemasterUI.CreateButton(dialog, 80, STYLE.buttonHeight, "Cancel")
    cancelButton:SetPoint("RIGHT", createButton, "LEFT", -8, 0)

    createButton:SetScript("OnClick", function()
        local packName = Stablemaster.Trim(nameInput:GetText())
        local description = Stablemaster.Trim(descInput:GetText())

        if packName == "" then
            Stablemaster.Print("Pack name cannot be empty!")
            return
        end

        local success, message = Stablemaster.CreatePack(packName, description)
        if success then
            -- Auto-add the mount to the newly created pack
            local addSuccess, addMessage = Stablemaster.AddMountToPack(packName, mountID)
            if addSuccess then
                Stablemaster.Print("[+] Created pack '" .. packName .. "' and added mount")
            else
                Stablemaster.Print("[+] Created pack '" .. packName .. "' but failed to add mount: " .. addMessage)
            end
            
            dialog:Hide()
            
            -- Refresh UI if it's open
            if _G.StablemasterMainFrame and _G.StablemasterMainFrame.packPanel and _G.StablemasterMainFrame.packPanel.refreshPacks then
                _G.StablemasterMainFrame.packPanel.refreshPacks()
            end
        else
            Stablemaster.Print("[-] " .. message)
        end
    end)

    cancelButton:SetScript("OnClick", function()
        dialog:Hide()
    end)

    nameInput:SetScript("OnEnterPressed", function()
        createButton:GetScript("OnClick")(createButton)
    end)
    descInput:SetScript("OnEnterPressed", function()
        createButton:GetScript("OnClick")(createButton)
    end)

    nameInput:SetScript("OnTabPressed", function()
        descInput:SetFocus()
    end)
    descInput:SetScript("OnTabPressed", function()
        nameInput:SetFocus()
    end)

    dialog:SetScript("OnShow", function()
        nameInput:SetText("")
        descInput:SetText("")
        nameInput:SetFocus()
    end)

    table.insert(UISpecialFrames, "StablemasterPackDialogFromJournal")
    dialog:Show()
    
    return dialog
end

-- Make it available globally
Stablemaster.MountJournalHook = MountJournalHook