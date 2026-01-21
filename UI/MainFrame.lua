-- Stablemaster: Main UI Frame (Modern Style)
Stablemaster.Debug("UI/MainFrame.lua loading...")

local STYLE = StablemasterUI.Style
local mainFrame = nil

-- Create a modern filter menu
local filterMenu = nil

local function CreateFilterMenu(parent, currentFilters, onFilterChange)
    if filterMenu then
        return filterMenu
    end

    local menu = CreateFrame("Frame", "StablemasterFilterMenu", UIParent, "BackdropTemplate")
    menu:SetSize(175, 140)
    menu:SetFrameStrata("FULLSCREEN_DIALOG")
    StablemasterUI.CreateBackdrop(menu)
    menu:Hide()

    local yOffset = -STYLE.padding

    -- Show unowned checkbox
    local showUnownedCheck = StablemasterUI.CreateCheckbox(menu, "Show unowned mounts")
    showUnownedCheck:SetPoint("TOPLEFT", menu, "TOPLEFT", STYLE.padding, yOffset)
    showUnownedCheck.check.onClick = function(self, checked)
        currentFilters.showUnowned = checked
        onFilterChange()
    end
    menu.showUnownedCheck = showUnownedCheck
    yOffset = yOffset - 22

    -- Hide unusable checkbox
    local hideUnusableCheck = StablemasterUI.CreateCheckbox(menu, "Hide unusable mounts")
    hideUnusableCheck:SetPoint("TOPLEFT", menu, "TOPLEFT", STYLE.padding, yOffset)
    hideUnusableCheck.check.onClick = function(self, checked)
        currentFilters.hideUnusable = checked
        onFilterChange()
    end
    menu.hideUnusableCheck = hideUnusableCheck
    yOffset = yOffset - 22

    -- Flying only checkbox
    local flyingOnlyCheck = StablemasterUI.CreateCheckbox(menu, "Flying mounts only")
    flyingOnlyCheck:SetPoint("TOPLEFT", menu, "TOPLEFT", STYLE.padding, yOffset)
    flyingOnlyCheck.check.onClick = function(self, checked)
        currentFilters.flyingOnly = checked
        onFilterChange()
    end
    menu.flyingOnlyCheck = flyingOnlyCheck
    yOffset = yOffset - 28

    -- Divider
    local divider = StablemasterUI.CreateDivider(menu, 160)
    divider:SetPoint("TOP", menu, "TOP", 0, yOffset)
    yOffset = yOffset - 8

    -- Source filter label
    local sourceLabel = StablemasterUI.CreateText(menu, STYLE.fontSizeSmall, STYLE.textDim)
    sourceLabel:SetPoint("TOPLEFT", menu, "TOPLEFT", STYLE.padding, yOffset)
    sourceLabel:SetText("Source Filter:")
    yOffset = yOffset - 18

    -- Favorites only checkbox
    local favoritesCheck = StablemasterUI.CreateCheckbox(menu, "Favorites only")
    favoritesCheck:SetPoint("TOPLEFT", menu, "TOPLEFT", STYLE.padding, yOffset)
    favoritesCheck.check.onClick = function(self, checked)
        currentFilters.sourceFilter = checked and "favorites" or "all"
        onFilterChange()
    end
    menu.favoritesCheck = favoritesCheck

    -- Update function to sync checkboxes with current filter state
    menu.UpdateCheckboxes = function(self)
        self.showUnownedCheck.check:SetChecked(currentFilters.showUnowned)
        self.hideUnusableCheck.check:SetChecked(currentFilters.hideUnusable)
        self.flyingOnlyCheck.check:SetChecked(currentFilters.flyingOnly)
        self.favoritesCheck.check:SetChecked(currentFilters.sourceFilter == "favorites")
    end

    filterMenu = menu
    return menu
end

function StablemasterUI.CreateSettingsPanel(parent)
    local settingsPanel = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    settingsPanel:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", STYLE.padding, STYLE.padding + 18)
    settingsPanel:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -STYLE.padding, STYLE.padding + 18)
    settingsPanel:SetHeight(90)
    StablemasterUI.CreateBackdrop(settingsPanel, 0.6)

    -- Settings header
    local settingsTitle = StablemasterUI.CreateHeaderText(settingsPanel, "Settings")
    settingsTitle:SetPoint("TOPLEFT", settingsPanel, "TOPLEFT", STYLE.padding, -STYLE.padding)

    -- Left column: Pack Overlap Mode
    local overlapLabel = StablemasterUI.CreateText(settingsPanel, STYLE.fontSizeSmall, STYLE.textDim)
    overlapLabel:SetPoint("TOPLEFT", settingsTitle, "BOTTOMLEFT", 0, -6)
    overlapLabel:SetText("When multiple packs match, choose a mount from:")

    local unionRadio = StablemasterUI.CreateRadioButton(settingsPanel, "Any matching pack")
    unionRadio:SetPoint("TOPLEFT", overlapLabel, "BOTTOMLEFT", 0, -2)
    unionRadio:SetSize(160, 18)

    local intersectionRadio = StablemasterUI.CreateRadioButton(settingsPanel, "Mounts common to all matching packs")
    intersectionRadio:SetPoint("TOPLEFT", unionRadio, "BOTTOMLEFT", 0, 0)
    intersectionRadio:SetSize(160, 18)

    -- Radio button behavior
    local function UpdateOverlapMode(mode)
        StablemasterDB.settings.packOverlapMode = mode
        unionRadio.radio:SetChecked(mode == "union")
        intersectionRadio.radio:SetChecked(mode == "intersection")

        -- Re-evaluate active packs
        C_Timer.After(0.1, Stablemaster.SelectActivePack)
    end

    unionRadio.radio:SetScript("OnClick", function() UpdateOverlapMode("union") end)
    intersectionRadio.radio:SetScript("OnClick", function() UpdateOverlapMode("intersection") end)

    -- Right column: Other options (aligned with left column radio buttons)
    local flyingCheck = StablemasterUI.CreateCheckbox(settingsPanel, "Prefer flying mounts")
    flyingCheck:SetPoint("LEFT", unionRadio, "LEFT", 280, 0)
    flyingCheck:SetSize(150, 18)

    flyingCheck.check.onClick = function(self, checked)
        StablemasterDB.settings.preferFlyingMounts = checked
    end

    local verboseCheck = StablemasterUI.CreateCheckbox(settingsPanel, "Show summon messages")
    verboseCheck:SetPoint("LEFT", intersectionRadio, "LEFT", 280, 0)
    verboseCheck:SetSize(160, 18)

    verboseCheck.check.onClick = function(self, checked)
        StablemasterDB.settings.verboseMode = checked
    end

    -- Initialize settings
    settingsPanel:SetScript("OnShow", function()
        local overlapMode = StablemasterDB.settings.packOverlapMode or "union"
        UpdateOverlapMode(overlapMode)
        flyingCheck.check:SetChecked(StablemasterDB.settings.preferFlyingMounts)
        verboseCheck.check:SetChecked(StablemasterDB.settings.verboseMode)
    end)

    return settingsPanel
end

function StablemasterUI.CreateMainFrame()
    if mainFrame then
        return mainFrame
    end

    -- Main frame with modern style
    local frame = CreateFrame("Frame", "StablemasterMainFrame", UIParent, "BackdropTemplate")
    frame:SetSize(800, 600)
    frame:SetPoint("CENTER")
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:SetFrameStrata("HIGH")
    StablemasterUI.CreateBackdrop(frame)

    -- Title bar
    local titleBar = StablemasterUI.CreateTitleBar(frame, "Stablemaster")
    frame.titleBar = titleBar

    -- Create settings panel first (above version/macro text)
    local settingsPanel = StablemasterUI.CreateSettingsPanel(frame)
    frame.settingsPanel = settingsPanel

    -- Version number in bottom left corner (inside the backdrop)
    local versionText = StablemasterUI.CreateText(frame, STYLE.fontSizeSmall, STYLE.textDim)
    versionText:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", STYLE.padding, STYLE.padding + 2)
    versionText:SetText("v" .. (Stablemaster.version or "0.8"))

    -- Macro instructions in bottom right (inside the backdrop)
    local macroInstructions = StablemasterUI.CreateText(frame, STYLE.fontSizeSmall, STYLE.textDim)
    macroInstructions:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -STYLE.padding, STYLE.padding + 2)
    macroInstructions:SetText("Create a macro with |cff66cc99/stablemaster mount|r for your action bar")

    -- Left panel (mounts)
    local mountPanel = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    mountPanel:SetPoint("TOPLEFT", frame, "TOPLEFT", STYLE.padding, -STYLE.headerHeight - STYLE.padding)
    mountPanel:SetPoint("BOTTOMLEFT", settingsPanel, "TOPLEFT", 0, STYLE.padding)
    mountPanel:SetWidth(380)
    StablemasterUI.CreateBackdrop(mountPanel, 0.6)

    -- Mount panel header
    local mountTitle = StablemasterUI.CreateHeaderText(mountPanel, "Your Mounts")
    mountTitle:SetPoint("TOP", mountPanel, "TOP", 0, -STYLE.padding)

    -- Mount counter
    local mountCounter = StablemasterUI.CreateText(mountPanel, STYLE.fontSizeNormal, STYLE.accent)
    mountCounter:SetPoint("TOP", mountTitle, "BOTTOM", 0, -4)
    mountCounter:SetText("Loading...")
    mountPanel.mountCounter = mountCounter

    -- Search box
    local searchBox = StablemasterUI.CreateEditBox(mountPanel, 180, 22)
    searchBox:SetPoint("TOPLEFT", mountPanel, "TOPLEFT", STYLE.padding, -50)
    searchBox:SetText("Search...")
    searchBox:SetTextColor(unpack(STYLE.textDim))

    -- Initialize filter state
    local currentFilters = {
        showUnowned = false,
        hideUnusable = true,
        flyingOnly = false,
        sourceFilter = "all"
    }

    local mountList = StablemasterUI.CreateMountList(mountPanel)
    mountPanel.mountList = mountList
    mountPanel.currentFilters = currentFilters

    -- Store references for backward compatibility
    mountPanel.filterCheck = {GetChecked = function() return currentFilters.showUnowned end}
    mountPanel.hideUnusableCheck = {GetChecked = function() return currentFilters.hideUnusable end}
    mountPanel.flyingOnlyCheck = {GetChecked = function() return currentFilters.flyingOnly end}

    -- Filter button (modern style)
    local filterButton = StablemasterUI.CreateButton(mountPanel, 80, STYLE.buttonHeight, "Filters")
    filterButton:SetPoint("TOPRIGHT", mountPanel, "TOPRIGHT", -STYLE.padding, -50)

    -- Create filter menu
    local menu = CreateFilterMenu(mountPanel, currentFilters, function()
        StablemasterUI.UpdateMountList(mountList, currentFilters)
    end)

    filterButton:SetScript("OnClick", function(self)
        if menu:IsShown() then
            menu:Hide()
        else
            menu:UpdateCheckboxes()
            menu:ClearAllPoints()
            menu:SetPoint("TOPRIGHT", self, "BOTTOMRIGHT", 0, -2)
            menu:Show()
        end
    end)

    -- Hide menu when clicking elsewhere
    menu:SetScript("OnShow", function(self)
        local hideFrame = CreateFrame("Frame", nil, UIParent)
        hideFrame:SetAllPoints(UIParent)
        hideFrame:SetFrameStrata("FULLSCREEN")
        hideFrame:EnableMouse(true)
        hideFrame:SetScript("OnMouseDown", function()
            self:Hide()
            hideFrame:Hide()
        end)
        self:HookScript("OnHide", function()
            if hideFrame then hideFrame:Hide() end
        end)
    end)

    -- Search box functionality
    searchBox:SetScript("OnEditFocusGained", function(self)
        if self:GetText() == "Search..." then
            self:SetText("")
            self:SetTextColor(unpack(STYLE.text))
        end
    end)
    searchBox:SetScript("OnEditFocusLost", function(self)
        if self:GetText() == "" then
            self:SetText("Search...")
            self:SetTextColor(unpack(STYLE.textDim))
        end
    end)

    searchBox:SetScript("OnTextChanged", function(self)
        if self:GetText() ~= "Search..." then
            currentFilters.searchText = self:GetText()
            StablemasterUI.UpdateMountList(mountList, currentFilters)
        end
    end)

    -- Right panel (packs)
    local packPanel = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    packPanel:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -STYLE.padding, -STYLE.headerHeight - STYLE.padding)
    packPanel:SetPoint("BOTTOMRIGHT", settingsPanel, "TOPRIGHT", 0, STYLE.padding)
    packPanel:SetWidth(380)
    StablemasterUI.CreateBackdrop(packPanel, 0.6)

    StablemasterUI.SetupPackPanel(packPanel)

    frame.mountPanel = mountPanel
    frame.packPanel = packPanel

    frame:Hide()
    table.insert(UISpecialFrames, "StablemasterMainFrame")

    mainFrame = frame
    return frame
end

function StablemasterUI.ToggleMainFrame()
    local frame = StablemasterUI.CreateMainFrame()
    if frame:IsShown() then
        frame:Hide()
    else
        frame:Show()
        -- Initialize with current filters and update counter
        local currentFilters = frame.mountPanel.currentFilters
        currentFilters.searchText = ""
        StablemasterUI.UpdateMountList(frame.mountPanel.mountList, currentFilters)
        frame.packPanel.refreshPacks()

        -- Force counter update on first load
        C_Timer.After(0.1, function()
            if frame.mountPanel.mountCounter then
                StablemasterUI.UpdateMountList(frame.mountPanel.mountList, currentFilters)
            end
        end)
    end
end

Stablemaster.Debug("UI/MainFrame.lua loaded")
