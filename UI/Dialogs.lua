-- Stablemaster: Dialog UI Components (Modern Style)
Stablemaster.Debug("UI/Dialogs.lua loading...")

local STYLE = StablemasterUI.Style

-- Pack Creation Dialog
function StablemasterUI.CreatePackDialog()
    local dialog = CreateFrame("Frame", "StablemasterPackDialog", UIParent, "BackdropTemplate")
    dialog:SetSize(400, 200)
    dialog:SetPoint("CENTER")
    dialog:SetMovable(true)
    dialog:EnableMouse(true)
    dialog:SetFrameStrata("DIALOG")
    StablemasterUI.CreateDialogBackdrop(dialog)

    -- Title bar
    local titleBar = StablemasterUI.CreateTitleBar(dialog, "Create New Pack")
    dialog.titleBar = titleBar

    local nameLabel = StablemasterUI.CreateText(dialog, STYLE.fontSizeNormal, STYLE.textDim)
    nameLabel:SetPoint("TOPLEFT", dialog, "TOPLEFT", STYLE.padding, -STYLE.headerHeight - STYLE.padding)
    nameLabel:SetText("Pack Name:")

    local nameInput = StablemasterUI.CreateEditBox(dialog, 250, 24)
    nameInput:SetPoint("TOPLEFT", nameLabel, "BOTTOMLEFT", 0, -4)
    nameInput:SetMaxLetters(30)

    local descLabel = StablemasterUI.CreateText(dialog, STYLE.fontSizeNormal, STYLE.textDim)
    descLabel:SetPoint("TOPLEFT", nameInput, "BOTTOMLEFT", 0, -12)
    descLabel:SetText("Description (optional):")

    local descInput = StablemasterUI.CreateEditBox(dialog, 350, 24)
    descInput:SetPoint("TOPLEFT", descLabel, "BOTTOMLEFT", 0, -4)
    descInput:SetMaxLetters(100)

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
        Stablemaster.VerbosePrint(message)

        if success then
            dialog:Hide()
            if _G.StablemasterMainFrame and _G.StablemasterMainFrame.packPanel and _G.StablemasterMainFrame.packPanel.refreshPacks then
                _G.StablemasterMainFrame.packPanel.refreshPacks()
            end
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

    dialog:Hide()
    table.insert(UISpecialFrames, "StablemasterPackDialog")
    return dialog
end

-- Delete Confirmation Dialog
function StablemasterUI.CreateDeleteConfirmationDialog()
    local dialog = CreateFrame("Frame", "StablemasterDeleteDialog", UIParent, "BackdropTemplate")
    dialog:SetSize(350, 150)
    dialog:SetPoint("CENTER")
    dialog:SetMovable(true)
    dialog:EnableMouse(true)
    dialog:SetFrameStrata("DIALOG")
    StablemasterUI.CreateDialogBackdrop(dialog)

    -- Title bar
    local titleBar = StablemasterUI.CreateTitleBar(dialog, "Delete Pack")
    dialog.titleBar = titleBar

    local warningText = StablemasterUI.CreateText(dialog, STYLE.fontSizeNormal, STYLE.warning, "CENTER")
    warningText:SetPoint("TOP", dialog, "TOP", 0, -STYLE.headerHeight - STYLE.padding * 2)
    warningText:SetPoint("LEFT", dialog, "LEFT", STYLE.padding, 0)
    warningText:SetPoint("RIGHT", dialog, "RIGHT", -STYLE.padding, 0)
    warningText:SetText("Are you sure you want to delete this pack?")

    local packNameText = StablemasterUI.CreateText(dialog, STYLE.fontSizeHeader, STYLE.textHeader, "CENTER")
    packNameText:SetPoint("TOP", warningText, "BOTTOM", 0, -8)
    dialog.packNameText = packNameText

    local deleteButton = StablemasterUI.CreateButton(dialog, 80, STYLE.buttonHeight, "Delete")
    deleteButton:SetPoint("BOTTOMRIGHT", dialog, "BOTTOMRIGHT", -STYLE.padding, STYLE.padding)
    -- Style delete button with error color on hover
    deleteButton:SetScript("OnEnter", function(self)
        self:SetBackdropBorderColor(unpack(STYLE.error))
        self.text:SetTextColor(unpack(STYLE.error))
    end)
    deleteButton:SetScript("OnLeave", function(self)
        self:SetBackdropBorderColor(unpack(STYLE.borderColor))
        self.text:SetTextColor(unpack(STYLE.text))
    end)

    local cancelButton = StablemasterUI.CreateButton(dialog, 80, STYLE.buttonHeight, "Cancel")
    cancelButton:SetPoint("RIGHT", deleteButton, "LEFT", -8, 0)

    dialog.targetPack = nil

    deleteButton:SetScript("OnClick", function()
        if dialog.targetPack then
            local success, message = Stablemaster.DeletePack(dialog.targetPack.name)
            Stablemaster.VerbosePrint(message)
            if success then
                dialog:Hide()
                if _G.StablemasterMainFrame and _G.StablemasterMainFrame.packPanel and _G.StablemasterMainFrame.packPanel.refreshPacks then
                    _G.StablemasterMainFrame.packPanel.refreshPacks()
                end
            end
        end
    end)

    cancelButton:SetScript("OnClick", function()
        dialog:Hide()
    end)

    dialog:Hide()
    table.insert(UISpecialFrames, "StablemasterDeleteDialog")
    return dialog
end

-- Duplicate Pack Dialog
function StablemasterUI.CreateDuplicatePackDialog()
    local dialog = CreateFrame("Frame", "StablemasterDuplicateDialog", UIParent, "BackdropTemplate")
    dialog:SetSize(400, 200)
    dialog:SetPoint("CENTER")
    dialog:SetMovable(true)
    dialog:EnableMouse(true)
    dialog:SetFrameStrata("DIALOG")
    StablemasterUI.CreateDialogBackdrop(dialog)

    -- Title bar
    local titleBar = StablemasterUI.CreateTitleBar(dialog, "Duplicate Pack")
    dialog.titleBar = titleBar

    local nameLabel = StablemasterUI.CreateText(dialog, STYLE.fontSizeNormal, STYLE.textDim)
    nameLabel:SetPoint("TOPLEFT", dialog, "TOPLEFT", STYLE.padding, -STYLE.headerHeight - STYLE.padding)
    nameLabel:SetText("New Pack Name:")

    local nameInput = StablemasterUI.CreateEditBox(dialog, 250, 24)
    nameInput:SetPoint("TOPLEFT", nameLabel, "BOTTOMLEFT", 0, -4)
    nameInput:SetMaxLetters(30)

    local descLabel = StablemasterUI.CreateText(dialog, STYLE.fontSizeNormal, STYLE.textDim)
    descLabel:SetPoint("TOPLEFT", nameInput, "BOTTOMLEFT", 0, -12)
    descLabel:SetText("Description (optional):")

    local descInput = StablemasterUI.CreateEditBox(dialog, 350, 24)
    descInput:SetPoint("TOPLEFT", descLabel, "BOTTOMLEFT", 0, -4)
    descInput:SetMaxLetters(100)

    local duplicateButton = StablemasterUI.CreateButton(dialog, 90, STYLE.buttonHeight, "Duplicate")
    duplicateButton:SetPoint("BOTTOMRIGHT", dialog, "BOTTOMRIGHT", -STYLE.padding, STYLE.padding)

    local cancelButton = StablemasterUI.CreateButton(dialog, 80, STYLE.buttonHeight, "Cancel")
    cancelButton:SetPoint("RIGHT", duplicateButton, "LEFT", -8, 0)

    dialog.sourcePack = nil

    duplicateButton:SetScript("OnClick", function()
        local newName = Stablemaster.Trim(nameInput:GetText())
        local description = Stablemaster.Trim(descInput:GetText())

        if newName == "" then
            Stablemaster.Print("New pack name cannot be empty!")
            return
        end

        if dialog.sourcePack then
            local success, message = Stablemaster.DuplicatePack(dialog.sourcePack.name, newName, description)
            Stablemaster.VerbosePrint(message)

            if success then
                dialog:Hide()
                if _G.StablemasterMainFrame and _G.StablemasterMainFrame.packPanel and _G.StablemasterMainFrame.packPanel.refreshPacks then
                    _G.StablemasterMainFrame.packPanel.refreshPacks()
                end
            end
        end
    end)

    cancelButton:SetScript("OnClick", function()
        dialog:Hide()
    end)

    nameInput:SetScript("OnEnterPressed", function()
        duplicateButton:GetScript("OnClick")(duplicateButton)
    end)
    descInput:SetScript("OnEnterPressed", function()
        duplicateButton:GetScript("OnClick")(duplicateButton)
    end)

    nameInput:SetScript("OnTabPressed", function()
        descInput:SetFocus()
    end)
    descInput:SetScript("OnTabPressed", function()
        nameInput:SetFocus()
    end)

    dialog:SetScript("OnShow", function()
        if dialog.sourcePack then
            nameInput:SetText(dialog.sourcePack.name .. " Copy")
            descInput:SetText((dialog.sourcePack.description or "") .. " (Copy)")
            nameInput:SetFocus()
            nameInput:HighlightText()
        end
    end)

    dialog:Hide()
    table.insert(UISpecialFrames, "StablemasterDuplicateDialog")
    return dialog
end

-- Export Pack Dialog
function StablemasterUI.CreateExportDialog()
    local dialog = CreateFrame("Frame", "StablemasterExportDialog", UIParent, "BackdropTemplate")
    dialog:SetSize(500, 240)
    dialog:SetPoint("CENTER")
    dialog:SetMovable(true)
    dialog:EnableMouse(true)
    dialog:SetFrameStrata("DIALOG")
    StablemasterUI.CreateDialogBackdrop(dialog)

    -- Title bar
    local titleBar = StablemasterUI.CreateTitleBar(dialog, "Export Pack")
    dialog.titleBar = titleBar

    local instructionText = StablemasterUI.CreateText(dialog, STYLE.fontSizeSmall, STYLE.textDim)
    instructionText:SetPoint("TOPLEFT", dialog, "TOPLEFT", STYLE.padding, -STYLE.headerHeight - STYLE.padding)
    instructionText:SetText("Copy this text to share your pack (Ctrl+A to select all, Ctrl+C to copy):")

    -- Export text box (read-only, scrollable)
    local scrollFrame = CreateFrame("ScrollFrame", nil, dialog, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", instructionText, "BOTTOMLEFT", 0, -8)
    scrollFrame:SetPoint("BOTTOMRIGHT", dialog, "BOTTOMRIGHT", -28, 62)

    local exportBox = CreateFrame("EditBox", nil, scrollFrame)
    exportBox:SetMultiLine(true)
    exportBox:SetAutoFocus(false)
    exportBox:SetFontObject(GameFontHighlightSmall)
    exportBox:SetWidth(440)
    exportBox:SetHeight(120)
    exportBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    -- Prevent WoW keybindings from intercepting Ctrl+C etc
    exportBox:HookScript("OnKeyDown", function(self, key)
        self:SetPropagateKeyboardInput(false)
    end)
    exportBox:HookScript("OnMouseDown", function(self)
        self:SetPropagateKeyboardInput(false)
    end)
    scrollFrame:SetScrollChild(exportBox)

    -- Also handle clicks on the scroll frame area
    scrollFrame:SetScript("OnMouseDown", function(self)
        exportBox:SetFocus()
        exportBox:SetPropagateKeyboardInput(false)
    end)

    -- Background for text area
    local textBg = CreateFrame("Frame", nil, dialog, "BackdropTemplate")
    textBg:SetPoint("TOPLEFT", scrollFrame, "TOPLEFT", -4, 4)
    textBg:SetPoint("BOTTOMRIGHT", scrollFrame, "BOTTOMRIGHT", 22, -4)
    textBg:SetFrameLevel(dialog:GetFrameLevel())
    StablemasterUI.CreateBackdrop(textBg, 0.8)

    local noteText = StablemasterUI.CreateText(dialog, STYLE.fontSizeSmall, {0.6, 0.6, 0.6, 1})
    noteText:SetPoint("BOTTOMLEFT", dialog, "BOTTOMLEFT", STYLE.padding, STYLE.padding + 4)
    noteText:SetText("Note: Outfit rules are not exported.")

    local closeButton = StablemasterUI.CreateButton(dialog, 80, STYLE.buttonHeight, "Close")
    closeButton:SetPoint("BOTTOMRIGHT", dialog, "BOTTOMRIGHT", -STYLE.padding, STYLE.padding)
    closeButton:SetScript("OnClick", function() dialog:Hide() end)

    local selectAllButton = StablemasterUI.CreateButton(dialog, 80, STYLE.buttonHeight, "Select All")
    selectAllButton:SetPoint("RIGHT", closeButton, "LEFT", -8, 0)
    selectAllButton:SetScript("OnClick", function()
        exportBox:SetFocus()
        exportBox:HighlightText()
    end)

    dialog.exportBox = exportBox

    dialog:SetScript("OnShow", function()
        exportBox:SetFocus()
        exportBox:HighlightText()
    end)

    dialog:Hide()
    table.insert(UISpecialFrames, "StablemasterExportDialog")
    return dialog
end

function StablemasterUI.ShowExportDialog(pack)
    if not pack then return end

    local dialog = _G.StablemasterExportDialog or StablemasterUI.CreateExportDialog()

    local exportString, err = Stablemaster.ExportPack(pack.name)
    if exportString then
        dialog.exportBox:SetText(exportString)
        dialog.titleBar.title:SetText("Export Pack: " .. pack.name)
        -- Move to end of UISpecialFrames so ESC closes this dialog first
        for i, name in ipairs(UISpecialFrames) do
            if name == "StablemasterExportDialog" then
                table.remove(UISpecialFrames, i)
                break
            end
        end
        table.insert(UISpecialFrames, "StablemasterExportDialog")
        dialog:Show()
    else
        Stablemaster.Print("Export failed: " .. (err or "unknown error"))
    end
end

-- Import Pack Dialog
function StablemasterUI.CreateImportDialog()
    local dialog = CreateFrame("Frame", "StablemasterImportDialog", UIParent, "BackdropTemplate")
    dialog:SetSize(500, 280)
    dialog:SetPoint("CENTER")
    dialog:SetMovable(true)
    dialog:EnableMouse(true)
    dialog:SetFrameStrata("DIALOG")
    StablemasterUI.CreateDialogBackdrop(dialog)

    -- Title bar
    local titleBar = StablemasterUI.CreateTitleBar(dialog, "Import Pack")
    dialog.titleBar = titleBar

    local instructionText = StablemasterUI.CreateText(dialog, STYLE.fontSizeSmall, STYLE.textDim)
    instructionText:SetPoint("TOPLEFT", dialog, "TOPLEFT", STYLE.padding, -STYLE.headerHeight - STYLE.padding)
    instructionText:SetText("Paste a pack export string below (Ctrl+V to paste):")

    -- Import text box (editable, scrollable)
    local scrollFrame = CreateFrame("ScrollFrame", nil, dialog, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", instructionText, "BOTTOMLEFT", 0, -8)
    scrollFrame:SetPoint("RIGHT", dialog, "RIGHT", -28, 0)
    scrollFrame:SetHeight(120)

    local importBox = CreateFrame("EditBox", nil, scrollFrame)
    importBox:SetMultiLine(true)
    importBox:SetAutoFocus(false)
    importBox:SetFontObject(GameFontHighlightSmall)
    importBox:SetWidth(440)
    importBox:SetHeight(120)
    importBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    -- Prevent WoW keybindings from intercepting Ctrl+V etc
    importBox:HookScript("OnKeyDown", function(self, key)
        self:SetPropagateKeyboardInput(false)
    end)
    importBox:HookScript("OnMouseDown", function(self)
        self:SetPropagateKeyboardInput(false)
    end)
    scrollFrame:SetScrollChild(importBox)

    -- Also handle clicks on the scroll frame area
    scrollFrame:SetScript("OnMouseDown", function(self)
        importBox:SetFocus()
        importBox:SetPropagateKeyboardInput(false)
    end)

    -- Background for text area
    local textBg = CreateFrame("Frame", nil, dialog, "BackdropTemplate")
    textBg:SetPoint("TOPLEFT", scrollFrame, "TOPLEFT", -4, 4)
    textBg:SetPoint("BOTTOMRIGHT", scrollFrame, "BOTTOMRIGHT", 22, -4)
    textBg:SetFrameLevel(dialog:GetFrameLevel())
    StablemasterUI.CreateBackdrop(textBg, 0.8)

    -- Scope selection
    local scopeLabel = StablemasterUI.CreateText(dialog, STYLE.fontSizeSmall, STYLE.textDim)
    scopeLabel:SetPoint("TOPLEFT", scrollFrame, "BOTTOMLEFT", 0, -16)
    scopeLabel:SetText("Import as:")

    local charRadio = StablemasterUI.CreateRadioButton(dialog, "Character-specific")
    charRadio:SetPoint("TOPLEFT", scopeLabel, "BOTTOMLEFT", 0, -6)
    charRadio.radio:SetChecked(true)

    local accountRadio = StablemasterUI.CreateRadioButton(dialog, "Account-wide")
    accountRadio:SetPoint("TOPLEFT", charRadio, "BOTTOMLEFT", 0, -4)

    -- Radio button behavior
    charRadio.radio:SetScript("OnClick", function()
        charRadio.radio:SetChecked(true)
        accountRadio.radio:SetChecked(false)
    end)
    accountRadio.radio:SetScript("OnClick", function()
        charRadio.radio:SetChecked(false)
        accountRadio.radio:SetChecked(true)
    end)

    -- Status text for feedback
    local statusText = StablemasterUI.CreateText(dialog, STYLE.fontSizeSmall, STYLE.textDim)
    statusText:SetPoint("BOTTOMLEFT", dialog, "BOTTOMLEFT", STYLE.padding, STYLE.padding + 5)
    statusText:SetPoint("RIGHT", dialog, "CENTER", -10, 0)
    statusText:SetText("")
    dialog.statusText = statusText

    local importButton = StablemasterUI.CreateButton(dialog, 80, STYLE.buttonHeight, "Import")
    importButton:SetPoint("BOTTOMRIGHT", dialog, "BOTTOMRIGHT", -STYLE.padding, STYLE.padding)

    local cancelButton = StablemasterUI.CreateButton(dialog, 80, STYLE.buttonHeight, "Cancel")
    cancelButton:SetPoint("RIGHT", importButton, "LEFT", -8, 0)
    cancelButton:SetScript("OnClick", function() dialog:Hide() end)

    importButton:SetScript("OnClick", function()
        local importString = importBox:GetText()
        if importString == "" then
            statusText:SetText("|cffff6666Please paste a pack export string.|r")
            return
        end

        local isShared = accountRadio.radio:GetChecked()
        local newPack, message = Stablemaster.ImportPack(importString, isShared)

        if newPack then
            statusText:SetText("|cff66ff66" .. message .. "|r")
            Stablemaster.Print(message)
            dialog:Hide()
            if _G.StablemasterMainFrame and _G.StablemasterMainFrame.packPanel and _G.StablemasterMainFrame.packPanel.refreshPacks then
                _G.StablemasterMainFrame.packPanel.refreshPacks()
            end
        else
            statusText:SetText("|cffff6666" .. message .. "|r")
        end
    end)

    dialog.importBox = importBox

    dialog:SetScript("OnShow", function()
        importBox:SetText("")
        statusText:SetText("")
        charRadio.radio:SetChecked(true)
        accountRadio.radio:SetChecked(false)
        importBox:SetFocus()
    end)

    dialog:Hide()
    table.insert(UISpecialFrames, "StablemasterImportDialog")
    return dialog
end

function StablemasterUI.ShowImportDialog()
    local dialog = _G.StablemasterImportDialog or StablemasterUI.CreateImportDialog()
    -- Move to end of UISpecialFrames so ESC closes this dialog first
    for i, name in ipairs(UISpecialFrames) do
        if name == "StablemasterImportDialog" then
            table.remove(UISpecialFrames, i)
            break
        end
    end
    table.insert(UISpecialFrames, "StablemasterImportDialog")
    dialog:Show()
end

-- Context Menu System
local contextMenu = nil

function StablemasterUI.CreatePackContextMenu()
    if contextMenu then
        return contextMenu
    end

    contextMenu = CreateFrame("Frame", "StablemasterPackContextMenu", UIParent, "BackdropTemplate")
    contextMenu:SetSize(170, 148)
    contextMenu:SetFrameStrata("FULLSCREEN_DIALOG")
    StablemasterUI.CreateBackdrop(contextMenu)
    contextMenu:Hide()
    contextMenu.pack = nil

    -- Menu items
    local menuItems = {}
    local yOffset = -STYLE.padding

    local function CreateMenuItem(parent, text, onClick, isDelete)
        local item = CreateFrame("Button", nil, parent, "BackdropTemplate")
        item:SetSize(154, 22)
        item:SetPoint("TOPLEFT", parent, "TOPLEFT", STYLE.padding, yOffset)
        yOffset = yOffset - 23

        item:SetBackdrop({
            bgFile = STYLE.bgTexture,
        })
        item:SetBackdropColor(0, 0, 0, 0)

        local itemText = StablemasterUI.CreateText(item, STYLE.fontSizeNormal, STYLE.text)
        itemText:SetPoint("LEFT", item, "LEFT", 6, 0)
        itemText:SetText(text)
        item.text = itemText

        local hoverColor = isDelete and STYLE.error or STYLE.accent

        item:SetScript("OnEnter", function(self)
            self:SetBackdropColor(hoverColor[1] * 0.2, hoverColor[2] * 0.2, hoverColor[3] * 0.2, 0.8)
            self.text:SetTextColor(unpack(hoverColor))
        end)

        item:SetScript("OnLeave", function(self)
            self:SetBackdropColor(0, 0, 0, 0)
            self.text:SetTextColor(unpack(STYLE.text))
        end)

        item:SetScript("OnClick", function()
            onClick()
            contextMenu:Hide()
        end)

        return item
    end

    -- Configure Rules
    local rulesItem = CreateMenuItem(contextMenu, "Configure Rules", function()
        if contextMenu.pack then
            StablemasterUI.ShowRulesDialog(contextMenu.pack)
        end
    end)
    table.insert(menuItems, rulesItem)

    -- Toggle Account-Wide
    local shareItem = CreateMenuItem(contextMenu, "Make Account-Wide", function()
        if contextMenu.pack then
            local success, message = Stablemaster.TogglePackShared(contextMenu.pack.name)
            if success then
                Stablemaster.Print(message)
                if _G.StablemasterMainFrame and _G.StablemasterMainFrame.packPanel and _G.StablemasterMainFrame.packPanel.refreshPacks then
                    _G.StablemasterMainFrame.packPanel.refreshPacks()
                end
            else
                Stablemaster.Print("Error: " .. message)
            end
        end
    end)
    table.insert(menuItems, shareItem)

    -- Toggle Fallback
    local fallbackItem = CreateMenuItem(contextMenu, "Set as Fallback", function()
        if contextMenu.pack then
            local success, message = Stablemaster.TogglePackFallback(contextMenu.pack.name)
            if success then
                if _G.StablemasterMainFrame and _G.StablemasterMainFrame.packPanel and _G.StablemasterMainFrame.packPanel.refreshPacks then
                    _G.StablemasterMainFrame.packPanel.refreshPacks()
                end
            else
                Stablemaster.Print("Error: " .. message)
            end
        end
    end)
    table.insert(menuItems, fallbackItem)

    -- Duplicate Pack
    local duplicateItem = CreateMenuItem(contextMenu, "Duplicate Pack", function()
        if contextMenu.pack then
            StablemasterUI.ShowDuplicateDialog(contextMenu.pack)
        end
    end)
    table.insert(menuItems, duplicateItem)

    -- Export Pack
    local exportItem = CreateMenuItem(contextMenu, "Export Pack", function()
        if contextMenu.pack then
            StablemasterUI.ShowExportDialog(contextMenu.pack)
        end
    end)
    table.insert(menuItems, exportItem)

    -- Delete Pack
    local deleteItem = CreateMenuItem(contextMenu, "Delete Pack", function()
        if contextMenu.pack then
            StablemasterUI.ShowDeleteConfirmation(contextMenu.pack)
        end
    end, true)
    table.insert(menuItems, deleteItem)

    contextMenu.menuItems = menuItems
    contextMenu.shareItem = shareItem
    contextMenu.fallbackItem = fallbackItem

    -- Update menu text based on pack state
    contextMenu.UpdateMenuItems = function(self, pack)
        if not pack then return end

        self.shareItem.text:SetText(pack.isShared and "Make Character-Specific" or "Make Account-Wide")
        self.fallbackItem.text:SetText(pack.isFallback and "Remove Fallback Status" or "Set as Fallback")
    end

    -- Hide menu when clicking elsewhere
    contextMenu:SetScript("OnHide", function(self)
        self.pack = nil
    end)

    return contextMenu
end

function StablemasterUI.ShowPackContextMenu(pack, x, y)
    local menu = StablemasterUI.CreatePackContextMenu()
    menu.pack = pack
    menu.UpdateMenuItems(menu, pack)
    menu:ClearAllPoints()
    menu:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", x, y)
    menu:Show()

    -- Hide when clicking elsewhere
    local function hideMenu()
        if menu:IsShown() then
            menu:Hide()
        end
    end

    -- Set up click-away handler
    local hiddenFrame = CreateFrame("Frame", nil, UIParent)
    hiddenFrame:SetAllPoints()
    hiddenFrame:SetFrameStrata("FULLSCREEN")
    hiddenFrame:EnableMouse(true)
    hiddenFrame:SetScript("OnMouseDown", function()
        hideMenu()
        hiddenFrame:Hide()
    end)
    hiddenFrame:Show()

    menu:SetScript("OnHide", function()
        hiddenFrame:Hide()
        menu.pack = nil
    end)
end

Stablemaster.Debug("UI/Dialogs.lua loaded")
