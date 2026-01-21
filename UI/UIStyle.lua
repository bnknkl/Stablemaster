-- Stablemaster: Modern UI Style System
-- Inspired by ElvUI flat design

local STYLE = {
    -- Colors
    bgColor = {0.1, 0.1, 0.1, 0.95},
    borderColor = {0.2, 0.2, 0.2, 1},
    accent = {0.4, 0.8, 0.6, 1},  -- Soft green/teal for mount theme
    accentHover = {0.5, 0.9, 0.7, 1},
    text = {0.9, 0.9, 0.9, 1},
    textDim = {0.6, 0.6, 0.6, 1},
    textHeader = {1, 0.9, 0.6, 1},  -- Warm gold for headers

    -- Status colors
    active = {0.3, 0.9, 0.3, 1},      -- Green for active/matched
    inactive = {0.5, 0.5, 0.5, 1},    -- Gray for inactive
    warning = {0.9, 0.7, 0.2, 1},     -- Gold for warnings
    error = {0.9, 0.3, 0.3, 1},       -- Red for errors

    -- Pack type colors
    shared = {0.6, 0.8, 1.0, 1},      -- Light blue for shared packs
    character = {0.9, 0.7, 0.5, 1},   -- Warm orange for character packs
    fallback = {0.8, 0.6, 0.9, 1},    -- Purple for fallback pack

    -- Rule type colors
    ruleZone = {0.5, 0.7, 1.0, 1},        -- Blue for zone rules
    ruleTransmog = {0.8, 0.5, 0.9, 1},    -- Purple for transmog rules
    ruleClass = {1.0, 0.8, 0.4, 1},       -- Gold for class rules
    ruleRace = {0.6, 0.9, 0.6, 1},        -- Green for race rules

    -- Dimensions
    borderSize = 1,
    padding = 8,
    headerHeight = 28,
    rowHeight = 24,
    buttonHeight = 22,
    iconSize = 32,
    iconSizeSmall = 20,

    -- Fonts
    font = "Fonts\\FRIZQT__.TTF",
    fontSizeSmall = 10,
    fontSizeNormal = 11,
    fontSizeHeader = 13,
    fontSizeLarge = 15,

    -- Textures
    bgTexture = "Interface\\Buttons\\WHITE8x8",

    -- Animations
    fadeTime = 0.15,
}

-- Export style to global namespace
StablemasterUI = StablemasterUI or {}
StablemasterUI.Style = STYLE

-- Helper function: Create modern flat backdrop
function StablemasterUI.CreateBackdrop(frame, alpha)
    alpha = alpha or STYLE.bgColor[4]
    frame:SetBackdrop({
        bgFile = STYLE.bgTexture,
        edgeFile = STYLE.bgTexture,
        edgeSize = STYLE.borderSize,
    })
    frame:SetBackdropColor(STYLE.bgColor[1], STYLE.bgColor[2], STYLE.bgColor[3], alpha)
    frame:SetBackdropBorderColor(unpack(STYLE.borderColor))
end

-- Helper function: Create accent-bordered backdrop (for highlighted elements)
function StablemasterUI.CreateAccentBackdrop(frame, alpha)
    alpha = alpha or STYLE.bgColor[4]
    frame:SetBackdrop({
        bgFile = STYLE.bgTexture,
        edgeFile = STYLE.bgTexture,
        edgeSize = STYLE.borderSize,
    })
    frame:SetBackdropColor(STYLE.bgColor[1], STYLE.bgColor[2], STYLE.bgColor[3], alpha)
    frame:SetBackdropBorderColor(unpack(STYLE.accent))
end

-- Helper function: Create styled text
function StablemasterUI.CreateText(parent, size, color, justify)
    size = size or STYLE.fontSizeNormal
    color = color or STYLE.text
    justify = justify or "LEFT"

    local text = parent:CreateFontString(nil, "OVERLAY")
    text:SetFont(STYLE.font, size, "")
    text:SetTextColor(unpack(color))
    text:SetJustifyH(justify)
    text:SetShadowOffset(1, -1)
    text:SetShadowColor(0, 0, 0, 0.8)

    return text
end

-- Helper function: Create styled header text
function StablemasterUI.CreateHeaderText(parent, text)
    local header = StablemasterUI.CreateText(parent, STYLE.fontSizeHeader, STYLE.textHeader, "LEFT")
    if text then
        header:SetText(text)
    end
    return header
end

-- Helper function: Create modern flat button
function StablemasterUI.CreateButton(parent, width, height, text)
    width = width or 80
    height = height or STYLE.buttonHeight

    local btn = CreateFrame("Button", nil, parent, "BackdropTemplate")
    btn:SetSize(width, height)

    StablemasterUI.CreateBackdrop(btn, 0.8)

    btn.text = StablemasterUI.CreateText(btn, STYLE.fontSizeNormal, STYLE.text, "CENTER")
    btn.text:SetPoint("CENTER")
    if text then
        btn.text:SetText(text)
    end

    -- Hover effect
    btn:SetScript("OnEnter", function(self)
        self:SetBackdropBorderColor(unpack(STYLE.accent))
        self.text:SetTextColor(unpack(STYLE.accent))
    end)

    btn:SetScript("OnLeave", function(self)
        self:SetBackdropBorderColor(unpack(STYLE.borderColor))
        self.text:SetTextColor(unpack(STYLE.text))
    end)

    -- Click feedback
    btn:SetScript("OnMouseDown", function(self)
        self:SetBackdropColor(STYLE.accent[1] * 0.3, STYLE.accent[2] * 0.3, STYLE.accent[3] * 0.3, 0.8)
    end)

    btn:SetScript("OnMouseUp", function(self)
        self:SetBackdropColor(STYLE.bgColor[1], STYLE.bgColor[2], STYLE.bgColor[3], 0.8)
    end)

    return btn
end

-- Helper function: Create modern checkbox
function StablemasterUI.CreateCheckbox(parent, label)
    local container = CreateFrame("Frame", nil, parent)
    container:SetSize(200, 20)

    local check = CreateFrame("CheckButton", nil, container, "BackdropTemplate")
    check:SetSize(16, 16)
    check:SetPoint("LEFT", container, "LEFT", 0, 0)

    StablemasterUI.CreateBackdrop(check, 0.6)

    -- Checkmark texture
    local checkmark = check:CreateTexture(nil, "OVERLAY")
    checkmark:SetSize(12, 12)
    checkmark:SetPoint("CENTER")
    checkmark:SetTexture("Interface\\Buttons\\UI-CheckBox-Check")
    checkmark:SetDesaturated(true)
    checkmark:SetVertexColor(unpack(STYLE.accent))
    checkmark:Hide()
    check.checkmark = checkmark

    check:SetScript("OnClick", function(self)
        if self:GetChecked() then
            self.checkmark:Show()
            self:SetBackdropBorderColor(unpack(STYLE.accent))
        else
            self.checkmark:Hide()
            self:SetBackdropBorderColor(unpack(STYLE.borderColor))
        end
        if self.onClick then
            self.onClick(self, self:GetChecked())
        end
    end)

    -- Override SetChecked to update visuals
    local origSetChecked = check.SetChecked
    check.SetChecked = function(self, checked)
        origSetChecked(self, checked)
        if checked then
            self.checkmark:Show()
            self:SetBackdropBorderColor(unpack(STYLE.accent))
        else
            self.checkmark:Hide()
            self:SetBackdropBorderColor(unpack(STYLE.borderColor))
        end
    end

    -- Label
    local labelText = StablemasterUI.CreateText(container, STYLE.fontSizeNormal, STYLE.text)
    labelText:SetPoint("LEFT", check, "RIGHT", 6, 0)
    if label then
        labelText:SetText(label)
    end
    container.label = labelText
    container.check = check

    -- Hover effect
    check:SetScript("OnEnter", function(self)
        if not self:GetChecked() then
            self:SetBackdropBorderColor(STYLE.accent[1], STYLE.accent[2], STYLE.accent[3], 0.5)
        end
    end)

    check:SetScript("OnLeave", function(self)
        if not self:GetChecked() then
            self:SetBackdropBorderColor(unpack(STYLE.borderColor))
        end
    end)

    return container
end

-- Helper function: Create modern radio button
function StablemasterUI.CreateRadioButton(parent, label)
    local container = CreateFrame("Frame", nil, parent)
    container:SetSize(200, 20)

    local radio = CreateFrame("CheckButton", nil, container, "BackdropTemplate")
    radio:SetSize(16, 16)
    radio:SetPoint("LEFT", container, "LEFT", 0, 0)

    -- Round appearance via backdrop
    radio:SetBackdrop({
        bgFile = STYLE.bgTexture,
        edgeFile = STYLE.bgTexture,
        edgeSize = STYLE.borderSize,
    })
    radio:SetBackdropColor(STYLE.bgColor[1], STYLE.bgColor[2], STYLE.bgColor[3], 0.6)
    radio:SetBackdropBorderColor(unpack(STYLE.borderColor))

    -- Inner dot for selected state
    local dot = radio:CreateTexture(nil, "OVERLAY")
    dot:SetSize(8, 8)
    dot:SetPoint("CENTER")
    dot:SetTexture(STYLE.bgTexture)
    dot:SetVertexColor(unpack(STYLE.accent))
    dot:Hide()
    radio.dot = dot

    -- Override SetChecked
    local origSetChecked = radio.SetChecked
    radio.SetChecked = function(self, checked)
        origSetChecked(self, checked)
        if checked then
            self.dot:Show()
            self:SetBackdropBorderColor(unpack(STYLE.accent))
        else
            self.dot:Hide()
            self:SetBackdropBorderColor(unpack(STYLE.borderColor))
        end
    end

    -- Label
    local labelText = StablemasterUI.CreateText(container, STYLE.fontSizeNormal, STYLE.text)
    labelText:SetPoint("LEFT", radio, "RIGHT", 6, 0)
    if label then
        labelText:SetText(label)
    end
    container.label = labelText
    container.radio = radio

    return container
end

-- Helper function: Create modern scroll frame
function StablemasterUI.CreateScrollFrame(parent)
    local scrollFrame = CreateFrame("ScrollFrame", nil, parent, "UIPanelScrollFrameTemplate")

    -- Style the scrollbar
    if scrollFrame.ScrollBar then
        local scrollBar = scrollFrame.ScrollBar

        -- Hide default textures
        if scrollBar.ScrollUpButton then
            scrollBar.ScrollUpButton:SetAlpha(0)
            scrollBar.ScrollUpButton:EnableMouse(false)
        end
        if scrollBar.ScrollDownButton then
            scrollBar.ScrollDownButton:SetAlpha(0)
            scrollBar.ScrollDownButton:EnableMouse(false)
        end

        -- Style the thumb
        if scrollBar.ThumbTexture then
            scrollBar.ThumbTexture:SetTexture(STYLE.bgTexture)
            scrollBar.ThumbTexture:SetVertexColor(unpack(STYLE.accent))
            scrollBar.ThumbTexture:SetSize(6, 40)
        end
    end

    return scrollFrame
end

-- Helper function: Create modern input box
function StablemasterUI.CreateEditBox(parent, width, height)
    width = width or 150
    height = height or 24

    local editBox = CreateFrame("EditBox", nil, parent, "BackdropTemplate")
    editBox:SetSize(width, height)
    editBox:SetFont(STYLE.font, STYLE.fontSizeNormal, "")
    editBox:SetTextColor(unpack(STYLE.text))
    editBox:SetAutoFocus(false)
    editBox:SetTextInsets(6, 6, 0, 0)

    StablemasterUI.CreateBackdrop(editBox, 0.6)

    -- Focus effect
    editBox:SetScript("OnEditFocusGained", function(self)
        self:SetBackdropBorderColor(unpack(STYLE.accent))
    end)

    editBox:SetScript("OnEditFocusLost", function(self)
        self:SetBackdropBorderColor(unpack(STYLE.borderColor))
    end)

    editBox:SetScript("OnEscapePressed", function(self)
        self:ClearFocus()
    end)

    return editBox
end

-- Helper function: Create section divider
function StablemasterUI.CreateDivider(parent, width)
    local divider = parent:CreateTexture(nil, "OVERLAY")
    divider:SetTexture(STYLE.bgTexture)
    divider:SetVertexColor(STYLE.borderColor[1], STYLE.borderColor[2], STYLE.borderColor[3], 0.5)
    divider:SetHeight(1)
    if width then
        divider:SetWidth(width)
    end
    return divider
end

-- Helper function: Create modern close button
function StablemasterUI.CreateCloseButton(parent)
    local btn = CreateFrame("Button", nil, parent, "BackdropTemplate")
    btn:SetSize(20, 20)

    StablemasterUI.CreateBackdrop(btn, 0.6)

    -- X mark
    local x = btn:CreateFontString(nil, "OVERLAY")
    x:SetFont(STYLE.font, 14, "")
    x:SetPoint("CENTER", 0, 1)
    x:SetText("x")
    x:SetTextColor(unpack(STYLE.textDim))
    btn.x = x

    btn:SetScript("OnEnter", function(self)
        self:SetBackdropBorderColor(unpack(STYLE.error))
        self.x:SetTextColor(unpack(STYLE.error))
    end)

    btn:SetScript("OnLeave", function(self)
        self:SetBackdropBorderColor(unpack(STYLE.borderColor))
        self.x:SetTextColor(unpack(STYLE.textDim))
    end)

    return btn
end

-- Helper function: Create title bar for frames
function StablemasterUI.CreateTitleBar(frame, title)
    local titleBar = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    titleBar:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
    titleBar:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0)
    titleBar:SetHeight(STYLE.headerHeight)

    titleBar:SetBackdrop({
        bgFile = STYLE.bgTexture,
        edgeFile = STYLE.bgTexture,
        edgeSize = STYLE.borderSize,
    })
    titleBar:SetBackdropColor(0.15, 0.15, 0.15, 1)
    titleBar:SetBackdropBorderColor(unpack(STYLE.borderColor))

    -- Title text
    local titleText = StablemasterUI.CreateHeaderText(titleBar, title)
    titleText:SetPoint("LEFT", titleBar, "LEFT", STYLE.padding, 0)
    titleBar.title = titleText

    -- Close button
    local closeBtn = StablemasterUI.CreateCloseButton(titleBar)
    closeBtn:SetPoint("RIGHT", titleBar, "RIGHT", -4, 0)
    closeBtn:SetScript("OnClick", function()
        frame:Hide()
    end)
    titleBar.closeButton = closeBtn

    -- Make title bar draggable
    titleBar:EnableMouse(true)
    titleBar:RegisterForDrag("LeftButton")
    titleBar:SetScript("OnDragStart", function()
        frame:StartMoving()
    end)
    titleBar:SetScript("OnDragStop", function()
        frame:StopMovingOrSizing()
    end)

    return titleBar
end

-- Helper function: Apply hover highlight to a row
function StablemasterUI.ApplyRowHover(row, normalBg, hoverBg)
    normalBg = normalBg or {0, 0, 0, 0}
    hoverBg = hoverBg or {STYLE.accent[1], STYLE.accent[2], STYLE.accent[3], 0.1}

    row:SetScript("OnEnter", function(self)
        if self.SetBackdropColor then
            self:SetBackdropColor(unpack(hoverBg))
        end
        if self.onEnter then self.onEnter(self) end
    end)

    row:SetScript("OnLeave", function(self)
        if self.SetBackdropColor then
            self:SetBackdropColor(unpack(normalBg))
        end
        if self.onLeave then self.onLeave(self) end
    end)
end

-- Helper function: Create drop shadow for dialog frames
function StablemasterUI.CreateShadow(frame, size)
    size = size or 8

    -- Create shadow frame behind the main frame
    local shadow = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    shadow:SetPoint("TOPLEFT", frame, "TOPLEFT", -size, size)
    shadow:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", size, -size)
    shadow:SetFrameLevel(frame:GetFrameLevel() - 1)

    shadow:SetBackdrop({
        bgFile = STYLE.bgTexture,
        edgeFile = STYLE.bgTexture,
        edgeSize = size,
        insets = { left = size, right = size, top = size, bottom = size }
    })
    shadow:SetBackdropColor(0, 0, 0, 0.6)
    shadow:SetBackdropBorderColor(0, 0, 0, 0.4)

    frame.shadow = shadow
    return shadow
end

-- Helper function: Create dialog backdrop with shadow
function StablemasterUI.CreateDialogBackdrop(frame)
    StablemasterUI.CreateBackdrop(frame)
    StablemasterUI.CreateShadow(frame, 10)

    -- Give dialog a slightly brighter border to stand out
    frame:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)
end

Stablemaster.Debug("UI/UIStyle.lua loaded")
