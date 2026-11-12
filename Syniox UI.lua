--[[
    ============================================================
    Syniox UI - v4  (Fluent x Elerium)
    ============================================================
    A modern Fluent-styled surface blended with the classic
    Elerium/Syniox identity: acrylic-like gradient + noise body,
    gradient title bar, left navigation pane with accent
    indicator, inline dropdowns/color picker, spring-like
    hover motion, bottom resize line.

    USAGE (loaded via URL):
        local Syniox = loadstring(game:HttpGet("..."))()
        local Window = Syniox:AddWindow("Syniox", { author = "you" })
        local Tab = Window:AddTab("Main")
        Tab:AddButton("Click me", function() print("hi") end)

    USAGE (pasted directly into an executor tab):
        local Syniox = (function()
            -- paste the ENTIRE file here (including `return library`)
        end)()
        local Window = Syniox:AddWindow("Syniox", { author = "you" })

    NOTE: Do not paste the library twice! `return library` must be
    the last statement of a block, otherwise you get:
        "Expected <eof>, got 'local'"

    Toggle key: RightShift (CONFIG.toggle_key)
]]

-- ============================================================
-- Services
-- ============================================================
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local TextService = game:GetService("TextService")
local RunService = game:GetService("RunService")

local LocalPlayer = Players.LocalPlayer

-- ============================================================
-- Small utilities
-- ============================================================
local function call(fn, ...)
    if type(fn) == "function" then
        local ok, err = pcall(fn, ...)
        if not ok then
            warn("[Syniox] callback error: " .. tostring(err))
        end
    end
end

local connections = {}

local function on(signal, fn)
    if signal == nil then
        return nil
    end
    local conn = signal:Connect(fn)
    connections[#connections + 1] = conn
    return conn
end

local function disconnectAll()
    for index = #connections, 1, -1 do
        local conn = connections[index]
        pcall(function()
            conn:Disconnect()
        end)
        connections[index] = nil
    end
end

-- Side-table storage (safe on real Roblox Instances)
local instanceData = setmetatable({}, { __mode = "k" })

local function dset(obj, key, value)
    if obj == nil then
        return
    end
    local bag = instanceData[obj]
    if bag == nil then
        bag = {}
        instanceData[obj] = bag
    end
    bag[key] = value
end

local function dget(obj, key)
    if obj == nil then
        return nil
    end
    local bag = instanceData[obj]
    if bag then
        return bag[key]
    end
    return nil
end

local function nextOrder(parent)
    local order = (dget(parent, "_synioxOrder") or 0) + 1
    dset(parent, "_synioxOrder", order)
    return order
end

local function tween(obj, props, duration, style)
    local info = TweenInfo.new(
        duration or 0.16,
        style or Enum.EasingStyle.Quad,
        Enum.EasingDirection.Out
    )
    local anim = TweenService:Create(obj, info, props)
    anim:Play()
    return anim
end

local function mousePos()
    local m = UserInputService:GetMouseLocation()
    local dx, dy = 0, 0
    local ok, inset = pcall(function()
        return game:GetService("GuiService"):GetGuiInset()
    end)
    if ok and inset then
        dx, dy = inset.X, inset.Y
    end
    return Vector2.new(m.X - dx, m.Y - dy)
end

local function viewportSize()
    local cam = workspace and workspace.CurrentCamera
    if cam and cam.ViewportSize then
        local vs = cam.ViewportSize
        if vs.X > 0 and vs.Y > 0 then
            return vs
        end
    end
    return Vector2.new(1280, 720)
end

local function isPrimaryInput(input)
    return input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch
end

local function textWidth(text, size)
    local ok, bounds = pcall(function()
        return TextService:GetTextSize(
            tostring(text or ""),
            size or 13,
            Enum.Font.Gotham,
            Vector2.new(100000, 100000)
        )
    end)
    if ok and bounds then
        return bounds.X
    end
    return #(tostring(text or "")) * (size or 13) * 0.55
end

local function lighten(color, amount)
    return Color3.new(
        color.R + (1 - color.R) * amount,
        color.G + (1 - color.G) * amount,
        color.B + (1 - color.B) * amount
    )
end

local function darken(color, amount)
    return Color3.new(
        color.R * (1 - amount),
        color.G * (1 - amount),
        color.B * (1 - amount)
    )
end

local function fmtNumber(v)
    if v == math.floor(v) then
        return tostring(math.floor(v))
    end
    return string.format("%.1f", v)
end

local function colorToHex(color)
    return string.format(
        "#%02X%02X%02X",
        math.floor(color.R * 255 + 0.5),
        math.floor(color.G * 255 + 0.5),
        math.floor(color.B * 255 + 0.5)
    )
end

local function hexToColor(text)
    if type(text) ~= "string" then
        return nil
    end
    local hex = text:gsub("#", ""):gsub("%s", "")
    if #hex == 3 then
        hex = hex:sub(1, 1):rep(2) .. hex:sub(2, 2):rep(2) .. hex:sub(3, 3):rep(2)
    end
    if #hex ~= 6 then
        return nil
    end
    local r, g, b = hex:match("^(%x%x)(%x%x)(%x%x)$")
    if not r then
        return nil
    end
    return Color3.fromRGB(tonumber(r, 16), tonumber(g, 16), tonumber(b, 16))
end

local function colorList(value, fallback)
    if typeof(value) == "Color3" then
        return { value }
    end
    if typeof(value) == "table" then
        local out = {}
        for i = 1, 3 do
            local c = value[i]
            if typeof(c) == "Color3" then
                out[#out + 1] = c
            end
        end
        if #out > 0 then
            return out
        end
    end
    return fallback
end

local function gradient(colors)
    if #colors == 1 then
        return nil
    end
    local seq = {}
    for i, c in ipairs(colors) do
        seq[#seq + 1] = ColorSequenceKeypoint.new((i - 1) / (#colors - 1), c)
    end
    return ColorSequence.new(seq)
end

-- ============================================================
-- Theme / assets
-- ============================================================
local ASSET = {
    shadow = "rbxassetid://8992230677",
    noiseA = "rbxassetid://9968344105",
    noiseB = "rbxassetid://9968344227",
    close = "rbxassetid://9886659671",
    minimize = "rbxassetid://9886659276",
    arrow = "https://www.roblox.com/Thumbs/Asset.ashx?width=420&height=420&assetId=4744658743",
    folderArrow = "https://www.roblox.com/Thumbs/Asset.ashx?width=420&height=420&assetId=4731371541",
    toggleIcon = "https://www.roblox.com/Thumbs/Asset.ashx?width=420&height=420&assetId=129903125132641",
    paletteSquare = "rbxassetid://698052001",
    valueGradient = "rbxassetid://3641079629",
}

local FONT = Enum.Font.Gotham
local FONT_BOLD = Enum.Font.GothamBold
local FONT_SEMI = Enum.Font.GothamSemibold

local COLOR = {
    text = Color3.fromRGB(240, 240, 240),
    subtext = Color3.fromRGB(170, 170, 170),
    faint = Color3.fromRGB(120, 120, 120),
    white = Color3.new(1, 1, 1),
    black = Color3.new(0, 0, 0),
    surface = Color3.fromRGB(255, 255, 255),
    panel = Color3.fromRGB(26, 27, 31),
    input = Color3.fromRGB(30, 31, 35),
}

local DEFAULTS = {
    main_color = Color3.fromRGB(41, 74, 122),
    minW = 480,
    minH = 320,
    toggle_key = Enum.KeyCode.RightShift,
}

local TITLE_H = 30

local bindingFlag = { binding = false }

-- ============================================================
-- ScreenGui
-- ============================================================
local gui = Instance.new("ScreenGui")
gui.Name = "Syniox_UI"
gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

pcall(function()
    if type(protectgui) == "function" then
        protectgui(gui)
    end
end)
pcall(function()
    if syn and type(syn.protect_gui) == "function" then
        syn.protect_gui(gui)
    end
end)

do
    local placed = false
    pcall(function()
        if type(gethui) == "function" then
            gui.Parent = gethui()
            placed = gui.Parent ~= nil
        end
    end)
    if not placed then
        pcall(function()
            gui.Parent = game:GetService("CoreGui")
            placed = gui.Parent ~= nil
        end)
    end
    if not placed then
        gui.Parent = LocalPlayer:WaitForChild("PlayerGui")
    end
end

local windowsFrame = Instance.new("Frame")
windowsFrame.Name = "Windows"
windowsFrame.BackgroundTransparency = 1
windowsFrame.Size = UDim2.fromScale(1, 1)
windowsFrame.ZIndex = 1
windowsFrame.Parent = gui

-- ============================================================
-- Notifications (bottom-right, slide in)
-- ============================================================
local notifHolder = Instance.new("Frame")
notifHolder.Name = "Notifications"
notifHolder.AnchorPoint = Vector2.new(1, 1)
notifHolder.Position = UDim2.new(1, -20, 1, -20)
notifHolder.Size = UDim2.new(0, 310, 1, -40)
notifHolder.BackgroundTransparency = 1
notifHolder.ZIndex = 500
notifHolder.Parent = gui

local notifLayout = Instance.new("UIListLayout")
notifLayout.Parent = notifHolder
notifLayout.SortOrder = Enum.SortOrder.LayoutOrder
notifLayout.VerticalAlignment = Enum.VerticalAlignment.Bottom
notifLayout.Padding = UDim.new(0, 10)

local notifications = {}

local function closeNotification(entry)
    if entry.closed then
        return
    end
    entry.closed = true
    if entry.slide then
        tween(entry.slide, { Position = UDim2.new(1, 60, 0, 0), BackgroundTransparency = 1 }, 0.25)
    end
    task.delay(0.26, function()
        pcall(function()
            entry.card:Destroy()
        end)
    end)
    for i, item in ipairs(notifications) do
        if item == entry then
            table.remove(notifications, i)
            break
        end
    end
end

local function notify(options)
    if type(options) ~= "table" then
        options = { Title = tostring(options or "") }
    end
    local title = tostring(options.Title or options.title or "Syniox")
    local content = tostring(options.Content or options.content or "")
    local duration = options.Duration or options.duration

    local entry = { closed = false, order = #notifications + 1 }

    -- layout-managed holder (UIListLayout owns its Position)
    local holder = Instance.new("Frame")
    holder.Name = "NotificationHolder"
    holder.Size = UDim2.new(1, 0, 0, content ~= "" and 64 or 44)
    holder.BackgroundTransparency = 1
    holder.ZIndex = 501
    holder.Parent = notifHolder
    entry.card = holder

    local card = Instance.new("Frame")
    card.Name = "Card"
    card.Size = UDim2.fromScale(1, 1)
    card.BackgroundColor3 = COLOR.panel
    card.BackgroundTransparency = 0.06
    card.BorderSizePixel = 0
    card.ZIndex = 501
    card.Parent = holder

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = card

    local stroke = Instance.new("UIStroke")
    stroke.Color = COLOR.white
    stroke.Transparency = 0.86
    stroke.Thickness = 1
    stroke.Parent = card

    local accentBar = Instance.new("Frame")
    accentBar.Size = UDim2.new(0, 3, 1, -16)
    accentBar.Position = UDim2.new(0, 6, 0, 8)
    accentBar.BackgroundColor3 = COLOR.white
    accentBar.BackgroundTransparency = 0.25
    accentBar.BorderSizePixel = 0
    accentBar.ZIndex = 502
    accentBar.Parent = card
    local barCorner = Instance.new("UICorner")
    barCorner.CornerRadius = UDim.new(1, 0)
    barCorner.Parent = accentBar
    dset(accentBar, "_isAccent", true)

    local titleLabel = Instance.new("TextLabel")
    titleLabel.BackgroundTransparency = 1
    titleLabel.Position = UDim2.new(0, 18, 0, 8)
    titleLabel.Size = UDim2.new(1, -48, 0, 14)
    titleLabel.Font = FONT_SEMI
    titleLabel.Text = title
    titleLabel.TextColor3 = COLOR.text
    titleLabel.TextSize = 13
    titleLabel.TextXAlignment = Enum.TextXAlignment.Left
    titleLabel.TextTruncate = Enum.TextTruncate.AtEnd
    titleLabel.ZIndex = 502
    titleLabel.Parent = card

    local contentLabel = Instance.new("TextLabel")
    contentLabel.BackgroundTransparency = 1
    contentLabel.Position = UDim2.new(0, 18, 0, 26)
    contentLabel.Size = UDim2.new(1, -36, 0, 30)
    contentLabel.Font = FONT
    contentLabel.Text = content
    contentLabel.TextColor3 = COLOR.subtext
    contentLabel.TextSize = 12
    contentLabel.TextWrapped = true
    contentLabel.TextXAlignment = Enum.TextXAlignment.Left
    contentLabel.TextYAlignment = Enum.TextYAlignment.Top
    contentLabel.Visible = content ~= ""
    contentLabel.ZIndex = 502
    contentLabel.Parent = card

    local closeBtn = Instance.new("TextButton")
    closeBtn.Name = "Close"
    closeBtn.BackgroundTransparency = 1
    closeBtn.Position = UDim2.new(1, -26, 0, 6)
    closeBtn.Size = UDim2.new(0, 20, 0, 20)
    closeBtn.Font = FONT
    closeBtn.Text = "X"
    closeBtn.TextColor3 = COLOR.subtext
    closeBtn.TextSize = 12
    closeBtn.AutoButtonColor = false
    closeBtn.ZIndex = 503
    closeBtn.Parent = card
    on(closeBtn.MouseEnter, function()
        tween(closeBtn, { TextColor3 = COLOR.text }, 0.1)
    end)
    on(closeBtn.MouseLeave, function()
        tween(closeBtn, { TextColor3 = COLOR.subtext }, 0.1)
    end)
    on(closeBtn.MouseButton1Click, function()
        closeNotification(entry)
    end)

    card.Position = UDim2.new(1, 60, 0, 0)
    tween(card, { Position = UDim2.new(0, 0, 0, 0) }, 0.3, Enum.EasingStyle.Back)
    entry.slide = card

    table.insert(notifications, entry)

    if duration == nil then
        duration = 4
    end
    if type(duration) == "number" and duration > 0 then
        task.delay(duration, function()
            closeNotification(entry)
        end)
    end

    return { Close = function()
        closeNotification(entry)
    end }
end

local function clearNotifications()
    for i = #notifications, 1, -1 do
        local entry = notifications[i]
        entry.closed = true
        pcall(function()
            entry.card:Destroy()
        end)
        notifications[i] = nil
    end
end

-- ============================================================
-- Watermark (bottom-left)
-- ============================================================
local watermark = Instance.new("TextLabel")
watermark.Name = "Watermark"
watermark.AnchorPoint = Vector2.new(0, 1)
watermark.Position = UDim2.new(0, 16, 1, -16)
watermark.Size = UDim2.new(0, 0, 0, 24)
watermark.AutomaticSize = Enum.AutomaticSize.X
watermark.BackgroundColor3 = COLOR.panel
watermark.BackgroundTransparency = 0.12
watermark.Font = FONT_SEMI
watermark.Text = ""
watermark.TextColor3 = COLOR.text
watermark.TextSize = 12
watermark.Visible = false
watermark.ZIndex = 400
watermark.Parent = gui
do
    local pad = Instance.new("UIPadding")
    pad.PaddingLeft = UDim.new(0, 10)
    pad.PaddingRight = UDim.new(0, 10)
    pad.Parent = watermark
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 6)
    corner.Parent = watermark
    local stroke = Instance.new("UIStroke")
    stroke.Color = COLOR.white
    stroke.Transparency = 0.88
    stroke.Parent = watermark
end

-- ============================================================
-- Element factory
-- ============================================================
-- Resolves the nearest ScrollingFrame above a container so inline
-- panels (dropdown / color picker) can scroll themselves into view
-- even when they live inside a folder.
local function findScroller(obj)
    local node = obj
    local depth = 0
    while node ~= nil and depth < 16 do
        local ok, isScroll = pcall(function()
            return node:IsA("ScrollingFrame")
        end)
        if ok and isScroll then
            return node
        end
        node = node.Parent
        depth = depth + 1
    end
    return nil
end

local function finish(obj, searchText, parentObj)
    dset(obj, "_searchText", string.lower(tostring(searchText or "")))
    local scroller = findScroller(parentObj or obj)
    if scroller then
        dset(obj, "_scroller", scroller)
    end
end

-- theme: { accent = Color3 }
-- getParent: function returning the container instance
local function createElementApi(getParent, theme)
    local api = {}
    local accent = theme.accent
    local accentLight = lighten(accent, 0.35)

    local CARD_BG = accent
    local CARD_IDLE = 0.88
    local CARD_HOVER = 0.80

    local function cardStroke(obj)
        local stroke = Instance.new("UIStroke")
        stroke.Color = COLOR.white
        stroke.Transparency = 0.88
        stroke.Thickness = 1
        stroke.Parent = obj
        return stroke
    end

    local function round(obj, radius)
        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0, radius)
        corner.Parent = obj
        return corner
    end

    local function bindCardHover(obj, idle, hover)
        on(obj.MouseEnter, function()
            tween(obj, { BackgroundTransparency = hover }, 0.12)
        end)
        on(obj.MouseLeave, function()
            tween(obj, { BackgroundTransparency = idle }, 0.12)
        end)
    end

    local function makeCard(name, height)
        local row = Instance.new("Frame")
        row.Name = name
        row.BackgroundColor3 = CARD_BG
        row.BackgroundTransparency = CARD_IDLE
        row.BorderSizePixel = 0
        row.Size = UDim2.new(1, 0, 0, height)
        row.LayoutOrder = nextOrder(getParent())
        row.ZIndex = 2
        round(row, 4)
        cardStroke(row)
        return row
    end

    local function makeButtonCard(name, height)
        local row = Instance.new("TextButton")
        row.Name = name
        row.BackgroundColor3 = CARD_BG
        row.BackgroundTransparency = CARD_IDLE
        row.BorderSizePixel = 0
        row.Size = UDim2.new(1, 0, 0, height)
        row.LayoutOrder = nextOrder(getParent())
        row.ZIndex = 2
        row.Text = ""
        row.AutoButtonColor = false
        round(row, 4)
        cardStroke(row)
        return row
    end

    local function makeTitle(text, parent, y, height)
        local label = Instance.new("TextLabel")
        label.BackgroundTransparency = 1
        label.Position = UDim2.new(0, 10, 0, y)
        label.Size = UDim2.new(1, -20, 0, height)
        label.Font = FONT
        label.Text = text
        label.TextColor3 = COLOR.text
        label.TextSize = 13
        label.TextXAlignment = Enum.TextXAlignment.Left
        label.ZIndex = 3
        label.Parent = parent
        return label
    end

    -- --------------------------------------------------------
    -- Label / Section / Divider / Paragraph
    -- --------------------------------------------------------
    function api:AddLabel(text)
        local p = getParent()
        local label = Instance.new("TextLabel")
        label.Name = "Label"
        label.BackgroundTransparency = 1
        label.Size = UDim2.new(1, 0, 0, 18)
        label.AutomaticSize = Enum.AutomaticSize.Y
        label.Font = FONT
        label.Text = tostring(text or "")
        label.TextColor3 = COLOR.text
        label.TextSize = 13
        label.TextWrapped = true
        label.TextXAlignment = Enum.TextXAlignment.Left
        label.LayoutOrder = nextOrder(p)
        label.ZIndex = 2
        label.Parent = p
        finish(label, text, p)
        return label
    end

    function api:AddSection(title)
        local p = getParent()
        local section = Instance.new("Frame")
        section.Name = "Section"
        section.BackgroundTransparency = 1
        section.Size = UDim2.new(1, 0, 0, 30)
        section.LayoutOrder = nextOrder(p)
        section.ZIndex = 2
        section.Parent = p

        local label = Instance.new("TextLabel")
        label.BackgroundTransparency = 1
        label.Position = UDim2.new(0, 2, 0, 2)
        label.Size = UDim2.new(1, -4, 0, 18)
        label.Font = FONT_BOLD
        label.Text = tostring(title or "Section")
        label.TextColor3 = COLOR.text
        label.TextSize = 16
        label.TextXAlignment = Enum.TextXAlignment.Left
        label.ZIndex = 3
        label.Parent = section

        local line = Instance.new("Frame")
        line.BackgroundTransparency = 1
        line.Position = UDim2.new(0, 2, 0, 25)
        line.Size = UDim2.new(1, -4, 0, 2)
        line.BackgroundColor3 = accent
        line.BorderSizePixel = 0
        line.ZIndex = 3
        line.Parent = section
        round(line, 1)

        finish(section, title, p)
        return section
    end

    function api:AddDivider()
        local p = getParent()
        local divider = Instance.new("Frame")
        divider.Name = "Divider"
        divider.BackgroundTransparency = 1
        divider.Size = UDim2.new(1, 0, 0, 9)
        divider.LayoutOrder = nextOrder(p)
        divider.ZIndex = 2
        divider.Parent = p

        local line = Instance.new("Frame")
        line.AnchorPoint = Vector2.new(0, 0.5)
        line.Position = UDim2.new(0, 0, 0.5, 0)
        line.Size = UDim2.new(1, 0, 0, 1)
        line.BackgroundColor3 = COLOR.white
        line.BackgroundTransparency = 0.9
        line.BorderSizePixel = 0
        line.ZIndex = 3
        line.Parent = divider

        finish(divider, "", p)
        return divider
    end

    function api:AddParagraph(title, body)
        local p = getParent()
        local row = Instance.new("Frame")
        row.Name = "Paragraph"
        row.BackgroundColor3 = CARD_BG
        row.BackgroundTransparency = CARD_IDLE
        row.BorderSizePixel = 0
        row.Size = UDim2.new(1, 0, 0, 56)
        row.AutomaticSize = Enum.AutomaticSize.Y
        row.LayoutOrder = nextOrder(p)
        row.ZIndex = 2
        row.Parent = p
        round(row, 4)
        cardStroke(row)

        local titleLabel = Instance.new("TextLabel")
        titleLabel.BackgroundTransparency = 1
        titleLabel.Position = UDim2.new(0, 10, 0, 8)
        titleLabel.Size = UDim2.new(1, -20, 0, 14)
        titleLabel.Font = FONT_SEMI
        titleLabel.Text = tostring(title or "")
        titleLabel.TextColor3 = COLOR.text
        titleLabel.TextSize = 13
        titleLabel.TextXAlignment = Enum.TextXAlignment.Left
        titleLabel.ZIndex = 3
        titleLabel.Parent = row

        local bodyLabel = Instance.new("TextLabel")
        bodyLabel.BackgroundTransparency = 1
        bodyLabel.Position = UDim2.new(0, 10, 0, 25)
        bodyLabel.Size = UDim2.new(1, -20, 0, 24)
        bodyLabel.AutomaticSize = Enum.AutomaticSize.Y
        bodyLabel.Font = FONT
        bodyLabel.Text = tostring(body or "")
        bodyLabel.TextColor3 = COLOR.subtext
        bodyLabel.TextSize = 12
        bodyLabel.TextWrapped = true
        bodyLabel.TextXAlignment = Enum.TextXAlignment.Left
        bodyLabel.TextYAlignment = Enum.TextYAlignment.Top
        bodyLabel.ZIndex = 3
        bodyLabel.Parent = row

        finish(row, title, p)
        return row
    end

    -- --------------------------------------------------------
    -- Button
    -- --------------------------------------------------------
    function api:AddButton(name, callback)
        name = tostring(name or "Button")
        local p = getParent()

        local row = Instance.new("TextButton")
        row.Name = "Button"
        row.BackgroundColor3 = accent
        row.BackgroundTransparency = 0.82
        row.BorderSizePixel = 0
        row.Size = UDim2.new(1, 0, 0, 34)
        row.LayoutOrder = nextOrder(p)
        row.ZIndex = 2
        row.Text = ""
        row.AutoButtonColor = false
        row.Parent = p
        round(row, 4)

        local stroke = Instance.new("UIStroke")
        stroke.Color = lighten(accent, 0.25)
        stroke.Transparency = 0.55
        stroke.Thickness = 1
        stroke.Parent = row

        local label = Instance.new("TextLabel")
        label.BackgroundTransparency = 1
        label.Size = UDim2.fromScale(1, 1)
        label.Font = FONT_SEMI
        label.Text = name
        label.TextColor3 = COLOR.text
        label.TextSize = 13
        label.ZIndex = 3
        label.Parent = row

        on(row.MouseEnter, function()
            tween(row, { BackgroundTransparency = 0.72 }, 0.12)
        end)
        on(row.MouseLeave, function()
            tween(row, { BackgroundTransparency = 0.82 }, 0.12)
        end)
        on(row.MouseButton1Down, function()
            tween(row, { BackgroundTransparency = 0.65 }, 0.08)
        end)
        on(row.MouseButton1Up, function()
            tween(row, { BackgroundTransparency = 0.72 }, 0.08)
        end)
        on(row.MouseButton1Click, function()
            call(callback)
        end)

        finish(row, name, p)
        return row
    end

    -- --------------------------------------------------------
    -- Switch
    -- --------------------------------------------------------
    function api:AddSwitch(name, callback)
        name = tostring(name or "Switch")
        local p = getParent()

        local row = Instance.new("TextButton")
        row.Name = "Switch"
        row.BackgroundColor3 = CARD_BG
        row.BackgroundTransparency = CARD_IDLE
        row.BorderSizePixel = 0
        row.Size = UDim2.new(1, 0, 0, 40)
        row.LayoutOrder = nextOrder(p)
        row.ZIndex = 2
        row.Text = ""
        row.AutoButtonColor = false
        row.Parent = p
        round(row, 4)
        cardStroke(row)
        bindCardHover(row, CARD_IDLE, CARD_HOVER)

        local titleLabel = makeTitle(name, row, 0, 40)
        titleLabel.ZIndex = 3

        local pill = Instance.new("Frame")
        pill.Name = "Pill"
        pill.AnchorPoint = Vector2.new(1, 0.5)
        pill.Position = UDim2.new(1, -10, 0.5, 0)
        pill.Size = UDim2.new(0, 40, 0, 20)
        pill.BackgroundColor3 = COLOR.white
        pill.BackgroundTransparency = 0.92
        pill.BorderSizePixel = 0
        pill.ZIndex = 3
        pill.Parent = row
        round(pill, 10)

        local pillStroke = Instance.new("UIStroke")
        pillStroke.Color = COLOR.white
        pillStroke.Transparency = 0.82
        pillStroke.Thickness = 1
        pillStroke.Parent = pill

        local knob = Instance.new("Frame")
        knob.Name = "Knob"
        knob.AnchorPoint = Vector2.new(0, 0.5)
        knob.Position = UDim2.new(0, 2, 0.5, 0)
        knob.Size = UDim2.new(0, 16, 0, 16)
        knob.BackgroundColor3 = COLOR.white
        knob.BorderSizePixel = 0
        knob.ZIndex = 4
        knob.Parent = pill
        round(knob, 8)

        local state = false

        local function render()
            if state then
                tween(pill, { BackgroundColor3 = accent, BackgroundTransparency = 0.05 }, 0.15)
                tween(knob, { Position = UDim2.new(0, 22, 0.5, 0) }, 0.15, Enum.EasingStyle.Back)
                pillStroke.Color = accent
                pillStroke.Transparency = 0.4
            else
                tween(pill, { BackgroundColor3 = COLOR.white, BackgroundTransparency = 0.92 }, 0.15)
                tween(knob, { Position = UDim2.new(0, 2, 0.5, 0) }, 0.15, Enum.EasingStyle.Back)
                pillStroke.Color = COLOR.white
                pillStroke.Transparency = 0.82
            end
        end

        on(row.MouseButton1Click, function()
            state = not state
            render()
            call(callback, state)
        end)

        local handle = {}
        function handle:Set(value)
            state = value == true
            render()
            call(callback, state)
        end
        function handle:Get()
            return state
        end

        finish(row, name, p)
        return handle, row
    end

    -- --------------------------------------------------------
    -- TextBox
    -- --------------------------------------------------------
    function api:AddTextBox(name, callback, opts)
        if type(callback) == "table" and opts == nil then
            opts = callback
            callback = nil
        end
        name = tostring(name or "TextBox")
        opts = typeof(opts) == "table" and opts or {}
        local p = getParent()

        local row = makeCard("TextBox", 48)
        row.Parent = p

        local titleLabel = makeTitle(name, row, 6, 14)
        titleLabel.TextColor3 = COLOR.subtext
        titleLabel.TextSize = 12

        local box = Instance.new("Frame")
        box.Name = "Box"
        box.Position = UDim2.new(0, 8, 0, 22)
        box.Size = UDim2.new(1, -16, 0, 20)
        box.BackgroundColor3 = COLOR.input
        box.BackgroundTransparency = 0.08
        box.BorderSizePixel = 0
        box.ZIndex = 3
        box.Parent = row
        round(box, 4)
        local boxStroke = Instance.new("UIStroke")
        boxStroke.Color = COLOR.white
        boxStroke.Transparency = 0.9
        boxStroke.Parent = box

        local input = Instance.new("TextBox")
        input.Name = "TextBox"
        input.BackgroundTransparency = 1
        input.Position = UDim2.new(0, 8, 0, 0)
        input.Size = UDim2.new(1, -16, 1, 0)
        input.Font = FONT
        input.Text = tostring(opts.default or "")
        input.PlaceholderText = tostring(opts.placeholder or name)
        input.PlaceholderColor3 = COLOR.faint
        input.TextColor3 = COLOR.text
        input.TextSize = 13
        input.TextXAlignment = Enum.TextXAlignment.Left
        input.ClearTextOnFocus = false
        input.ZIndex = 4
        input.Parent = box

        on(box.MouseEnter, function()
            tween(boxStroke, { Transparency = 0.6 }, 0.12)
        end)
        on(box.MouseLeave, function()
            if input:IsFocused() then
                return
            end
            tween(boxStroke, { Transparency = 0.9 }, 0.12)
        end)
        on(input.Focused, function()
            tween(boxStroke, { Color = accent, Transparency = 0.35 }, 0.12)
        end)
        on(input.FocusLost, function(enterPressed)
            tween(boxStroke, { Color = COLOR.white, Transparency = 0.9 }, 0.12)
            if not enterPressed then
                return
            end
            call(callback, input.Text)
            if opts.clear == true then
                input.Text = ""
            end
        end)

        finish(row, name, p)
        return input, row
    end

    -- --------------------------------------------------------
    -- Slider
    -- --------------------------------------------------------
    function api:AddSlider(name, callback, opts)
        name = tostring(name or "Slider")
        opts = typeof(opts) == "table" and opts or {}
        local p = getParent()

        local minV = tonumber(opts.min) or 0
        local maxV = tonumber(opts.max) or 100
        if maxV < minV then
            minV, maxV = maxV, minV
        end
        local step = tonumber(opts.step) or 1
        if step < 0 then
            step = 1
        end
        local readonly = opts.readonly == true
        local formatFn = opts.format

        local function roundStep(v)
            if step <= 0 then
                return math.clamp(v, minV, maxV)
            end
            local rounded = minV + math.floor((v - minV) / step + 0.5) * step
            return math.clamp(rounded, minV, maxV)
        end

        local row = makeCard("Slider", 44)
        row.Parent = p

        local titleLabel = makeTitle(name, row, 6, 14)
        titleLabel.ZIndex = 3

        local valueLabel = Instance.new("TextLabel")
        valueLabel.AnchorPoint = Vector2.new(1, 0)
        valueLabel.Position = UDim2.new(1, -10, 0, 6)
        valueLabel.Size = UDim2.new(0, 60, 0, 14)
        valueLabel.BackgroundTransparency = 1
        valueLabel.Font = FONT_SEMI
        valueLabel.Text = ""
        valueLabel.TextColor3 = accentLight
        valueLabel.TextSize = 12
        valueLabel.TextXAlignment = Enum.TextXAlignment.Right
        valueLabel.ZIndex = 3
        valueLabel.Parent = row

        local rail = Instance.new("Frame")
        rail.Name = "Rail"
        rail.Position = UDim2.new(0, 10, 0, 28)
        rail.Size = UDim2.new(1, -20, 0, 6)
        rail.BackgroundColor3 = COLOR.white
        rail.BackgroundTransparency = 0.9
        rail.BorderSizePixel = 0
        rail.ZIndex = 3
        rail.Active = not readonly
        rail.Parent = row
        round(rail, 3)

        local fill = Instance.new("Frame")
        fill.Name = "Fill"
        fill.Size = UDim2.new(0, 0, 1, 0)
        fill.BackgroundColor3 = accent
        fill.BorderSizePixel = 0
        fill.ZIndex = 4
        fill.Parent = rail
        round(fill, 3)

        local knob = Instance.new("Frame")
        knob.Name = "Knob"
        knob.AnchorPoint = Vector2.new(0.5, 0.5)
        knob.Position = UDim2.new(0, 0, 0.5, 0)
        knob.Size = UDim2.new(0, 12, 0, 12)
        knob.BackgroundColor3 = COLOR.white
        knob.BorderSizePixel = 0
        knob.ZIndex = 5
        knob.Parent = rail
        round(knob, 6)
        local knobStroke = Instance.new("UIStroke")
        knobStroke.Color = accent
        knobStroke.Thickness = 1.5
        knobStroke.Parent = knob

        local value = roundStep(tonumber(opts.default) or minV)
        local dragging = false

        local function display(v)
            if type(formatFn) == "function" then
                local ok, res = pcall(formatFn, v)
                if ok and res ~= nil then
                    return tostring(res)
                end
            end
            return fmtNumber(v)
        end

        local function render(anim)
            local alpha = 0
            if maxV > minV then
                alpha = (value - minV) / (maxV - minV)
            end
            alpha = math.clamp(alpha, 0, 1)
            if anim then
                tween(fill, { Size = UDim2.new(alpha, 0, 1, 0) }, 0.12)
                tween(knob, { Position = UDim2.new(alpha, 0, 0.5, 0) }, 0.12)
            else
                fill.Size = UDim2.new(alpha, 0, 1, 0)
                knob.Position = UDim2.new(alpha, 0, 0.5, 0)
            end
            valueLabel.Text = display(value)
        end

        local function setFromMouse(anim)
            local m = mousePos()
            local abs = rail.AbsolutePosition
            local size = rail.AbsoluteSize
            if size.X <= 0 then
                return
            end
            local alpha = math.clamp((m.X - abs.X) / size.X, 0, 1)
            local nextValue = roundStep(minV + alpha * (maxV - minV))
            if nextValue ~= value then
                value = nextValue
                call(callback, value)
            end
            render(anim)
        end

        if not readonly then
            on(rail.InputBegan, function(input)
                if isPrimaryInput(input) then
                    dragging = true
                    setFromMouse(true)
                end
            end)
            on(UserInputService.InputChanged, function(input)
                if not dragging then
                    return
                end
                if input.UserInputType ~= Enum.UserInputType.MouseMovement
                    and input.UserInputType ~= Enum.UserInputType.Touch then
                    return
                end
                setFromMouse(false)
            end)
            on(UserInputService.InputEnded, function(input)
                if isPrimaryInput(input) then
                    dragging = false
                end
            end)
        end

        render(false)

        local handle = {}
        function handle:Set(v)
            value = roundStep(tonumber(v) or value)
            render(true)
            call(callback, value)
        end
        function handle:Get()
            return value
        end

        finish(row, name, p)
        return handle, row
    end

    -- --------------------------------------------------------
    -- Keybind
    -- --------------------------------------------------------
    function api:AddKeybind(name, callback, opts)
        name = tostring(name or "Keybind")
        opts = typeof(opts) == "table" and opts or {}
        local p = getParent()

        local row = makeCard("Keybind", 40)
        row.Parent = p

        local titleLabel = makeTitle(name, row, 0, 40)
        titleLabel.ZIndex = 3

        local chip = Instance.new("TextButton")
        chip.Name = "Input"
        chip.AnchorPoint = Vector2.new(1, 0.5)
        chip.Position = UDim2.new(1, -10, 0.5, 0)
        chip.Size = UDim2.new(0, 76, 0, 22)
        chip.BackgroundColor3 = COLOR.input
        chip.BackgroundTransparency = 0.08
        chip.Font = FONT
        chip.Text = ""
        chip.AutoButtonColor = false
        chip.ZIndex = 3
        chip.Parent = row
        round(chip, 4)
        local chipStroke = Instance.new("UIStroke")
        chipStroke.Color = COLOR.white
        chipStroke.Transparency = 0.86
        chipStroke.Parent = chip

        local keyLabel = Instance.new("TextLabel")
        keyLabel.Name = "KeyName"
        keyLabel.BackgroundTransparency = 1
        keyLabel.Size = UDim2.fromScale(1, 1)
        keyLabel.Font = FONT_SEMI
        keyLabel.Text = "..."
        keyLabel.TextColor3 = COLOR.subtext
        keyLabel.TextSize = 12
        keyLabel.ZIndex = 4
        keyLabel.Parent = chip

        local currentKey = opts.default
        local waiting = false
        local conn = nil

        local function keyName(key)
            if not key then
                return "None"
            end
            return tostring(key):gsub("KeyCode%.", "")
        end

        local function renderKey()
            if waiting then
                keyLabel.Text = "..."
                keyLabel.TextColor3 = COLOR.text
                chipStroke.Color = accent
                chipStroke.Transparency = 0.3
            else
                keyLabel.Text = keyName(currentKey)
                keyLabel.TextColor3 = COLOR.subtext
                chipStroke.Color = COLOR.white
                chipStroke.Transparency = 0.86
            end
        end

        local function stopListening()
            waiting = false
            if conn then
                pcall(function()
                    conn:Disconnect()
                end)
                conn = nil
            end
            bindingFlag.binding = false
            renderKey()
        end

        local function startListening()
            if waiting then
                return
            end
            waiting = true
            bindingFlag.binding = true
            renderKey()
            conn = on(UserInputService.InputBegan, function(input, gameProcessed)
                if gameProcessed then
                    return
                end
                local key = input.KeyCode
                if key == Enum.KeyCode.Unknown then
                    return
                end
                currentKey = key
                stopListening()
                call(callback, key)
            end)
        end

        on(chip.MouseButton1Click, function()
            if waiting then
                stopListening()
            else
                startListening()
            end
        end)
        on(chip.MouseEnter, function()
            if not waiting then
                tween(chipStroke, { Transparency = 0.55 }, 0.12)
            end
        end)
        on(chip.MouseLeave, function()
            if not waiting then
                tween(chipStroke, { Transparency = 0.86 }, 0.12)
            end
        end)
        renderKey()

        local handle = {}
        function handle:Set(key)
            currentKey = key
            stopListening()
        end
        function handle:Get()
            return currentKey
        end

        finish(row, name, p)
        return handle, row
    end

    -- --------------------------------------------------------
    -- Dropdown (inline expanding list)
    -- --------------------------------------------------------
    function api:AddDropdown(name, callback, opts)
        if type(callback) == "table" and opts == nil then
            opts = callback
            callback = nil
        end
        name = tostring(name or "Dropdown")
        opts = typeof(opts) == "table" and opts or {}
        local p = getParent()

        local items = {}
        if type(opts.options) == "table" then
            for _, v in ipairs(opts.options) do
                items[#items + 1] = tostring(v)
            end
        end

        local CLOSED_H = 55

        local row = Instance.new("Frame")
        row.Name = "Dropdown"
        row.BackgroundColor3 = CARD_BG
        row.BackgroundTransparency = CARD_IDLE
        row.BorderSizePixel = 0
        row.Size = UDim2.new(1, 0, 0, CLOSED_H)
        row.LayoutOrder = nextOrder(p)
        row.ZIndex = 2
        row.Parent = p
        round(row, 4)
        cardStroke(row)
        bindCardHover(row, CARD_IDLE, CARD_HOVER)

        local titleLabel = makeTitle(name, row, 6, 14)
        titleLabel.ZIndex = 3

        local box = Instance.new("TextButton")
        box.Name = "Box"
        box.Position = UDim2.new(0, 8, 0, 24)
        box.Size = UDim2.new(1, -16, 0, 24)
        box.BackgroundColor3 = COLOR.input
        box.BackgroundTransparency = 0.08
        box.Text = ""
        box.AutoButtonColor = false
        box.ZIndex = 3
        box.Parent = row
        round(box, 4)
        local boxStroke = Instance.new("UIStroke")
        boxStroke.Color = COLOR.white
        boxStroke.Transparency = 0.88
        boxStroke.Parent = box

        local selectedLabel = Instance.new("TextLabel")
        selectedLabel.Name = "Selected"
        selectedLabel.BackgroundTransparency = 1
        selectedLabel.Position = UDim2.new(0, 8, 0, 0)
        selectedLabel.Size = UDim2.new(1, -30, 1, 0)
        selectedLabel.Font = FONT
        selectedLabel.Text = "Select..."
        selectedLabel.TextColor3 = COLOR.faint
        selectedLabel.TextSize = 12
        selectedLabel.TextXAlignment = Enum.TextXAlignment.Left
        selectedLabel.TextTruncate = Enum.TextTruncate.AtEnd
        selectedLabel.ZIndex = 4
        selectedLabel.Parent = box

        local arrow = Instance.new("ImageLabel")
        arrow.Name = "Arrow"
        arrow.AnchorPoint = Vector2.new(1, 0.5)
        arrow.Position = UDim2.new(1, -8, 0.5, 0)
        arrow.Size = UDim2.new(0, 12, 0, 12)
        arrow.BackgroundTransparency = 1
        arrow.Image = ASSET.arrow
        arrow.ImageColor3 = COLOR.subtext
        arrow.ZIndex = 4
        arrow.Parent = box

        local listFrame = Instance.new("ScrollingFrame")
        listFrame.Name = "List"
        listFrame.Position = UDim2.new(0, 8, 0, 52)
        listFrame.Size = UDim2.new(1, -16, 0, 0)
        listFrame.BackgroundColor3 = COLOR.panel
        listFrame.BackgroundTransparency = 0.05
        listFrame.BorderSizePixel = 0
        listFrame.ScrollBarThickness = 3
        listFrame.ScrollBarImageColor3 = accentLight
        listFrame.ScrollBarImageTransparency = 0.5
        listFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
        listFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
        listFrame.Visible = false
        listFrame.ZIndex = 6
        listFrame.ClipsDescendants = true
        listFrame.Parent = row
        round(listFrame, 4)
        local listStroke = Instance.new("UIStroke")
        listStroke.Color = COLOR.white
        listStroke.Transparency = 0.9
        listStroke.Parent = listFrame

        local listLayout = Instance.new("UIListLayout")
        listLayout.Parent = listFrame
        listLayout.SortOrder = Enum.SortOrder.LayoutOrder
        listLayout.Padding = UDim.new(0, 2)
        local listPad = Instance.new("UIPadding")
        listPad.PaddingTop = UDim.new(0, 4)
        listPad.PaddingBottom = UDim.new(0, 4)
        listPad.PaddingLeft = UDim.new(0, 4)
        listPad.PaddingRight = UDim.new(0, 4)
        listPad.Parent = listFrame

        local selected = nil
        local open = false
        local optionButtons = {}
        local scroller = nil

        local function scrollIntoView()
            if not scroller then
                return
            end
            local viewH = scroller.AbsoluteSize.Y
            if viewH <= 0 then
                return
            end
            local top = row.AbsolutePosition.Y - scroller.AbsolutePosition.Y
            local bottom = top + row.AbsoluteSize.Y
            if bottom > viewH then
                scroller.CanvasPosition = Vector2.new(0, math.max(0, bottom - viewH + 8))
            elseif top < 0 then
                scroller.CanvasPosition = Vector2.new(0, math.max(0, top + scroller.CanvasPosition.Y - 8))
            end
        end

        local function closeList()
            if not open then
                return
            end
            open = false
            listFrame.Visible = false
            listFrame.Size = UDim2.new(1, -16, 0, 0)
            row.Size = UDim2.new(1, 0, 0, CLOSED_H)
            tween(arrow, { Rotation = 0 }, 0.15)
        end

        local function openList()
            if open then
                closeList()
                return
            end
            open = true
            local listH = math.clamp(#items * 24 + 8, 40, 152)
            listFrame.Visible = true
            listFrame.Size = UDim2.new(1, -16, 0, listH)
            row.Size = UDim2.new(1, 0, 0, 52 + listH + 8)
            tween(arrow, { Rotation = 180 }, 0.15)
            scrollIntoView()
        end

        -- re-sizes an already open list after items change
        local function refreshList()
            if not open then
                return
            end
            local listH = math.clamp(#items * 24 + 8, 40, 152)
            listFrame.Size = UDim2.new(1, -16, 0, listH)
            row.Size = UDim2.new(1, 0, 0, 52 + listH + 8)
            scrollIntoView()
        end

        local function selectValue(value, fire)
            selected = value
            if value ~= nil then
                selectedLabel.Text = tostring(value)
                selectedLabel.TextColor3 = COLOR.text
            else
                selectedLabel.Text = "Select..."
                selectedLabel.TextColor3 = COLOR.faint
            end
            if fire then
                call(callback, value)
            end
            closeList()
        end

        local function rebuild()
            for _, b in ipairs(optionButtons) do
                pcall(function()
                    b:Destroy()
                end)
            end
            optionButtons = {}
            for _, item in ipairs(items) do
                local opt = Instance.new("TextButton")
                opt.Name = "Option"
                opt.BackgroundColor3 = accent
                opt.BackgroundTransparency = 1
                opt.Font = FONT
                opt.Text = item
                opt.TextColor3 = COLOR.subtext
                opt.TextSize = 12
                opt.TextXAlignment = Enum.TextXAlignment.Left
                opt.AutoButtonColor = false
                opt.Size = UDim2.new(1, -4, 0, 20)
                opt.LayoutOrder = nextOrder(listFrame)
                opt.ZIndex = 7
                opt.Parent = listFrame
                round(opt, 3)
                on(opt.MouseEnter, function()
                    tween(opt, { BackgroundTransparency = 0.85 }, 0.1)
                    opt.TextColor3 = COLOR.text
                end)
                on(opt.MouseLeave, function()
                    tween(opt, { BackgroundTransparency = 1 }, 0.1)
                    if selected == nil or tostring(selected) ~= item then
                        opt.TextColor3 = COLOR.subtext
                    end
                end)
                on(opt.MouseButton1Click, function()
                    selectValue(item, true)
                end)
                optionButtons[#optionButtons + 1] = opt
            end
        end

        on(box.MouseButton1Click, function()
            openList()
        end)
        on(box.MouseEnter, function()
            tween(boxStroke, { Color = accent, Transparency = 0.5 }, 0.12)
        end)
        on(box.MouseLeave, function()
            tween(boxStroke, { Color = COLOR.white, Transparency = 0.88 }, 0.12)
        end)

        rebuild()

        local handle = {}
        function handle:Add(value)
            items[#items + 1] = tostring(value)
            rebuild()
            if open then
                refreshList()
            end
        end
        function handle:Set(value)
            selectValue(value, true)
        end
        function handle.Get(_, value)
            if value ~= nil then
                return tostring(value) == tostring(selected)
            end
            return selected
        end
        function handle:Remove(value)
            for i, v in ipairs(items) do
                if v == tostring(value) then
                    table.remove(items, i)
                    break
                end
            end
            if selected ~= nil and tostring(selected) == tostring(value) then
                selected = nil
                selectedLabel.Text = "Select..."
                selectedLabel.TextColor3 = COLOR.faint
            end
            rebuild()
            if open then
                refreshList()
            end
        end
        function handle:Clear()
            items = {}
            selected = nil
            selectedLabel.Text = "Select..."
            selectedLabel.TextColor3 = COLOR.faint
            rebuild()
            closeList()
        end

        finish(row, name, p)
        scroller = dget(row, "_scroller")
        return handle, row
    end

    -- --------------------------------------------------------
    -- Color picker (inline panel)
    -- --------------------------------------------------------
    function api:AddColorPicker(name, callback, opts)
        if type(callback) == "table" and opts == nil then
            opts = callback
            callback = nil
        end
        name = tostring(name or "Color")
        opts = typeof(opts) == "table" and opts or {}
        local p = getParent()

        local current = opts.default
        if typeof(current) ~= "Color3" then
            current = Color3.new(1, 1, 1)
        end
        local h, s, v = current:ToHSV()

        local row = Instance.new("Frame")
        row.Name = "ColorPicker"
        row.BackgroundColor3 = CARD_BG
        row.BackgroundTransparency = CARD_IDLE
        row.BorderSizePixel = 0
        row.Size = UDim2.new(1, 0, 0, 40)
        row.LayoutOrder = nextOrder(p)
        row.ZIndex = 2
        row.Parent = p
        round(row, 4)
        cardStroke(row)
        bindCardHover(row, CARD_IDLE, CARD_HOVER)

        local titleLabel = makeTitle(name, row, 0, 40)
        titleLabel.ZIndex = 3

        local swatch = Instance.new("TextButton")
        swatch.Name = "Swatch"
        swatch.AnchorPoint = Vector2.new(1, 0.5)
        swatch.Position = UDim2.new(1, -10, 0.5, 0)
        swatch.Size = UDim2.new(0, 30, 0, 18)
        swatch.BackgroundColor3 = current
        swatch.Text = ""
        swatch.AutoButtonColor = false
        swatch.ZIndex = 3
        swatch.Parent = row
        round(swatch, 4)
        local swatchStroke = Instance.new("UIStroke")
        swatchStroke.Color = COLOR.black
        swatchStroke.Transparency = 0.5
        swatchStroke.Parent = swatch

        local PANEL_H = 156

        local panel = Instance.new("Frame")
        panel.Name = "Panel"
        panel.Position = UDim2.new(0, 8, 0, 44)
        panel.Size = UDim2.new(1, -16, 0, PANEL_H)
        panel.BackgroundColor3 = COLOR.panel
        panel.BackgroundTransparency = 0.03
        panel.BorderSizePixel = 0
        panel.Visible = false
        panel.ZIndex = 8
        panel.Parent = row
        round(panel, 6)
        local panelStroke = Instance.new("UIStroke")
        panelStroke.Color = accent
        panelStroke.Transparency = 0.55
        panelStroke.Parent = panel

        -- palette square: X = hue, Y = saturation (pre-rendered, never tinted)
        local palette = Instance.new("ImageLabel")
        palette.Name = "Palette"
        palette.Position = UDim2.new(0, 8, 0, 8)
        palette.Size = UDim2.new(1, -44, 0, 104)
        palette.Image = ASSET.paletteSquare
        palette.ScaleType = Enum.ScaleType.Stretch
        palette.Active = true
        palette.ZIndex = 9
        palette.Parent = panel
        round(palette, 4)

        -- value strip: vertical, tinted with the pure current hue
        local valueStrip = Instance.new("ImageLabel")
        valueStrip.Name = "Saturation"
        valueStrip.AnchorPoint = Vector2.new(1, 0)
        valueStrip.Position = UDim2.new(1, -8, 0, 8)
        valueStrip.Size = UDim2.new(0, 12, 0, 104)
        valueStrip.Image = ASSET.valueGradient
        valueStrip.ImageColor3 = Color3.fromHSV(h, 1, 1)
        valueStrip.ScaleType = Enum.ScaleType.Stretch
        valueStrip.Active = true
        valueStrip.ZIndex = 9
        valueStrip.Parent = panel
        round(valueStrip, 4)

        -- hex input
        local hexBox = Instance.new("TextBox")
        hexBox.Name = "Hex"
        hexBox.Position = UDim2.new(0, 8, 0, 122)
        hexBox.Size = UDim2.new(1, -16, 0, 24)
        hexBox.BackgroundColor3 = COLOR.input
        hexBox.BackgroundTransparency = 0.08
        hexBox.Font = FONT
        hexBox.Text = colorToHex(current)
        hexBox.TextColor3 = COLOR.text
        hexBox.TextSize = 12
        hexBox.ClearTextOnFocus = false
        hexBox.ZIndex = 9
        hexBox.Parent = panel
        round(hexBox, 4)
        local hexStroke = Instance.new("UIStroke")
        hexStroke.Color = COLOR.white
        hexStroke.Transparency = 0.88
        hexStroke.Parent = hexBox

        -- palette marker: hue on X, saturation on Y (top = full saturation)
        local satDot = Instance.new("Frame")
        satDot.Name = "Indicator"
        satDot.AnchorPoint = Vector2.new(0.5, 0.5)
        satDot.Position = UDim2.new(h, 0, 1 - s, 0)
        satDot.Size = UDim2.new(0, 10, 0, 10)
        satDot.BackgroundColor3 = COLOR.white
        satDot.BorderSizePixel = 0
        satDot.ZIndex = 10
        satDot.Visible = false
        satDot.Parent = palette
        round(satDot, 5)
        local satDotStroke = Instance.new("UIStroke")
        satDotStroke.Color = COLOR.black
        satDotStroke.Transparency = 0.25
        satDotStroke.Thickness = 2
        satDotStroke.Parent = satDot

        -- value marker: horizontal bar riding the vertical strip
        local hueDot = Instance.new("Frame")
        hueDot.Name = "Indicator"
        hueDot.AnchorPoint = Vector2.new(0.5, 0.5)
        hueDot.Position = UDim2.new(0.5, 0, 1 - v, 0)
        hueDot.Size = UDim2.new(0, 18, 0, 4)
        hueDot.BackgroundColor3 = COLOR.white
        hueDot.BorderSizePixel = 0
        hueDot.ZIndex = 10
        hueDot.Visible = false
        hueDot.Parent = valueStrip
        round(hueDot, 2)
        local hueDotStroke = Instance.new("UIStroke")
        hueDotStroke.Color = COLOR.black
        hueDotStroke.Transparency = 0.25
        hueDotStroke.Parent = hueDot

        local panelOpen = false

        local function applyColor(fire)
            current = Color3.fromHSV(h, s, v)
            swatch.BackgroundColor3 = current
            valueStrip.ImageColor3 = Color3.fromHSV(h, 1, 1)
            hexBox.Text = colorToHex(current)
            if fire then
                call(callback, current)
            end
        end

        local function renderDots()
            satDot.Position = UDim2.new(h, 0, 1 - s, 0)
            hueDot.Position = UDim2.new(0.5, 0, 1 - v, 0)
        end

        local function closePanel()
            panelOpen = false
            panel.Visible = false
            row.Size = UDim2.new(1, 0, 0, 40)
            satDot.Visible = false
            hueDot.Visible = false
        end

        local function openPanel()
            if panelOpen then
                closePanel()
                return
            end
            panelOpen = true
            h, s, v = current:ToHSV()
            renderDots()
            satDot.Visible = true
            hueDot.Visible = true
            panel.Visible = true
            row.Size = UDim2.new(1, 0, 0, 44 + PANEL_H + 8)
            local scroller = dget(row, "_scroller")
            if scroller then
                local viewH = scroller.AbsoluteSize.Y
                local top = row.AbsolutePosition.Y - scroller.AbsolutePosition.Y
                if viewH > 0 and top + row.AbsoluteSize.Y > viewH then
                    scroller.CanvasPosition = Vector2.new(
                        0,
                        math.max(0, top + row.AbsoluteSize.Y - viewH + 8)
                    )
                end
            end
        end

        local paletteDragging = false
        local stripDragging = false

        local function paletteFromMouse()
            local m = mousePos()
            local ap = palette.AbsolutePosition
            local asz = palette.AbsoluteSize
            if asz.X <= 0 or asz.Y <= 0 then
                return
            end
            h = math.clamp((m.X - ap.X) / asz.X, 0, 1)
            s = 1 - math.clamp((m.Y - ap.Y) / asz.Y, 0, 1)
            renderDots()
            applyColor(true)
        end

        local function stripFromMouse()
            local m = mousePos()
            local ap = valueStrip.AbsolutePosition
            local asz = valueStrip.AbsoluteSize
            if asz.Y <= 0 then
                return
            end
            v = 1 - math.clamp((m.Y - ap.Y) / asz.Y, 0, 1)
            renderDots()
            applyColor(true)
        end

        on(swatch.MouseButton1Click, function()
            openPanel()
        end)
        on(palette.InputBegan, function(input)
            if isPrimaryInput(input) then
                paletteDragging = true
                paletteFromMouse()
            end
        end)
        on(valueStrip.InputBegan, function(input)
            if isPrimaryInput(input) then
                stripDragging = true
                stripFromMouse()
            end
        end)
        on(UserInputService.InputChanged, function(input)
            if input.UserInputType ~= Enum.UserInputType.MouseMovement
                and input.UserInputType ~= Enum.UserInputType.Touch then
                return
            end
            if paletteDragging then
                paletteFromMouse()
            elseif stripDragging then
                stripFromMouse()
            end
        end)
        on(UserInputService.InputEnded, function(input)
            if isPrimaryInput(input) then
                paletteDragging = false
                stripDragging = false
            end
        end)
        on(hexBox.FocusLost, function(enterPressed)
            if not enterPressed then
                return
            end
            local parsed = hexToColor(hexBox.Text)
            if parsed then
                current = parsed
                h, s, v = current:ToHSV()
                renderDots()
                applyColor(true)
            else
                hexBox.Text = colorToHex(current)
            end
        end)

        local handle = {}
        function handle:Set(color)
            if typeof(color) == "Color3" then
                current = color
                h, s, v = current:ToHSV()
                renderDots()
                applyColor(false)
            end
        end
        function handle:Get()
            return current
        end

        finish(row, name, p)
        return handle, row
    end

    -- --------------------------------------------------------
    -- Horizontal alignment
    -- --------------------------------------------------------
    function api:AddHorizontalAlignment()
        local p = getParent()
        local row = Instance.new("Frame")
        row.Name = "Horizontal"
        row.BackgroundTransparency = 1
        row.Size = UDim2.new(1, 0, 0, 0)
        row.AutomaticSize = Enum.AutomaticSize.Y
        row.LayoutOrder = nextOrder(p)
        row.ZIndex = 2
        local layout = Instance.new("UIListLayout")
        layout.Parent = row
        layout.FillDirection = Enum.FillDirection.Horizontal
        layout.SortOrder = Enum.SortOrder.LayoutOrder
        layout.Padding = UDim.new(0, 6)
        row.Parent = p

        local sub = createElementApi(function()
            return row
        end, theme)
        finish(row, "", p)
        return sub, row
    end

    -- --------------------------------------------------------
    -- Folder
    -- --------------------------------------------------------
    function api:AddFolder(name)
        name = tostring(name or "Folder")
        local p = getParent()

        local row = Instance.new("Frame")
        row.Name = "Folder"
        row.BackgroundTransparency = 1
        row.Size = UDim2.new(1, 0, 0, 24)
        row.LayoutOrder = nextOrder(p)
        row.ZIndex = 2
        dset(row, "_isFolder", true)
        dset(row, "_open", false)

        local button = Instance.new("TextButton")
        button.Name = "Button"
        button.BackgroundColor3 = accent
        button.BackgroundTransparency = 0.9
        button.BorderSizePixel = 0
        button.Text = ""
        button.AutoButtonColor = false
        button.Size = UDim2.new(1, 0, 0, 24)
        button.ZIndex = 3
        button.Parent = row
        round(button, 4)
        local buttonStroke = Instance.new("UIStroke")
        buttonStroke.Color = COLOR.white
        buttonStroke.Transparency = 0.9
        buttonStroke.Parent = button

        on(button.MouseEnter, function()
            tween(button, { BackgroundTransparency = 0.82 }, 0.12)
        end)
        on(button.MouseLeave, function()
            tween(button, { BackgroundTransparency = 0.9 }, 0.12)
        end)

        local arrow = Instance.new("ImageLabel")
        arrow.Name = "Toggle"
        arrow.Position = UDim2.new(0, 6, 0.5, 0)
        arrow.AnchorPoint = Vector2.new(0, 0.5)
        arrow.Size = UDim2.new(0, 12, 0, 12)
        arrow.BackgroundTransparency = 1
        arrow.Image = ASSET.folderArrow
        arrow.ImageColor3 = accentLight
        arrow.ZIndex = 4
        arrow.Parent = button

        local titleLabel = Instance.new("TextLabel")
        titleLabel.Name = "Title"
        titleLabel.BackgroundTransparency = 1
        titleLabel.Position = UDim2.new(0, 24, 0, 0)
        titleLabel.Size = UDim2.new(1, -30, 1, 0)
        titleLabel.Font = FONT_SEMI
        titleLabel.Text = name
        titleLabel.TextColor3 = COLOR.text
        titleLabel.TextSize = 13
        titleLabel.TextXAlignment = Enum.TextXAlignment.Left
        titleLabel.TextTruncate = Enum.TextTruncate.AtEnd
        titleLabel.ZIndex = 4
        titleLabel.Parent = button

        local objects = Instance.new("Frame")
        objects.Name = "Objects"
        objects.BackgroundTransparency = 1
        objects.Size = UDim2.new(1, -12, 0, 0)
        objects.Position = UDim2.new(0, 12, 0, 26)
        objects.Visible = false
        objects.ZIndex = 2
        objects.Parent = row
        local objectsLayout = Instance.new("UIListLayout")
        objectsLayout.Parent = objects
        objectsLayout.SortOrder = Enum.SortOrder.LayoutOrder
        objectsLayout.Padding = UDim.new(0, 5)

        local function recompute()
            local content = objectsLayout.AbsoluteContentSize.Y
            if objects.Visible then
                row.Size = UDim2.new(1, 0, 0, 26 + content + 6)
            else
                row.Size = UDim2.new(1, 0, 0, 24)
            end
            local parent = row.Parent
            if parent then
                local fn = dget(parent, "_recompute")
                if fn then
                    fn()
                end
            end
        end
        dset(row, "_recompute", recompute)
        dset(objects, "_recompute", recompute)
        on(objectsLayout:GetPropertyChangedSignal("AbsoluteContentSize"), recompute)

        local function openFolder()
            if dget(row, "_open") then
                return
            end
            dset(row, "_open", true)
            objects.Visible = true
            tween(arrow, { Rotation = 90 }, 0.15)
            recompute()
        end

        local function closeFolder()
            if not dget(row, "_open") then
                return
            end
            dset(row, "_open", false)
            objects.Visible = false
            tween(arrow, { Rotation = 0 }, 0.15)
            recompute()
        end

        dset(row, "_forceOpen", openFolder)
        dset(row, "_forceClose", closeFolder)

        row.Parent = p
        on(button.MouseButton1Click, function()
            if dget(row, "_open") then
                closeFolder()
            else
                openFolder()
            end
        end)

        local subEnv = createElementApi(function()
            return objects
        end, theme)

        local handle = {}
        for key, value in pairs(subEnv) do
            handle[key] = value
        end
        handle.Open = openFolder
        handle.Close = closeFolder
        handle.GetFrame = function()
            return row
        end

        finish(row, name, p)
        return handle, row
    end

    return api
end

-- ============================================================
-- Library
-- ============================================================
local library = {}
local windows = {}
local windowCount = 0
local toggleKey = DEFAULTS.toggle_key
local createElementApiRef = createElementApi

-- ============================================================
-- Window
-- ============================================================
function library:AddWindow(title, cfg)
    title = tostring(title or "Syniox")
    cfg = typeof(cfg) == "table" and cfg or {}
    windowCount = windowCount + 1

    local accent = typeof(cfg.main_color) == "Color3" and cfg.main_color or DEFAULTS.main_color
    local theme = { accent = accent }

    local titleColors = colorList(cfg.title_bar, { accent, darken(accent, 0.45), darken(accent, 0.75) })
    local titleTransparency = tonumber(cfg.title_bar_transparency) or 0
    local bgColors = colorList(cfg.background, {
        Color3.fromRGB(24, 24, 28),
        Color3.fromRGB(18, 18, 22),
        Color3.fromRGB(14, 14, 17),
    })
    local bgTransparency = tonumber(cfg.background_transparency) or 0.05
    local canResize = cfg.can_resize ~= false
    local author = cfg.author

    -- size / min size ------------------------------------------------
    local w, h
    if typeof(cfg.size) == "UDim2" then
        w, h = cfg.size.X.Offset, cfg.size.Y.Offset
    elseif typeof(cfg.size) == "Vector2" then
        w, h = cfg.size.X, cfg.size.Y
    end
    local minW, minH
    if typeof(cfg.min_size) == "Vector2" then
        minW, minH = cfg.min_size.X, cfg.min_size.Y
    elseif typeof(cfg.min_size) == "UDim2" then
        minW, minH = cfg.min_size.X.Offset, cfg.min_size.Y.Offset
    end
    minW = tonumber(minW) or DEFAULTS.minW
    minH = tonumber(minH) or DEFAULTS.minH
    w = tonumber(w) or minW
    h = tonumber(h) or minH
    w = math.max(w, minW)
    h = math.max(h, minH)

    -- position --------------------------------------------------------
    local vp = viewportSize()
    local x, y
    if typeof(cfg.position) == "UDim2" then
        x = vp.X * cfg.position.X.Scale + cfg.position.X.Offset
        y = vp.Y * cfg.position.Y.Scale + cfg.position.Y.Offset
    elseif cfg.center then
        x = (vp.X - w) / 2
        y = (vp.Y - h) / 2
    else
        x = 70 + (windowCount - 1) * 30
        y = 60 + (windowCount - 1) * 24
    end

    local W = {
        x = x, y = y, w = w, h = h,
        minW = minW, minH = minH,
        minimized = false, prevH = h, closed = false,
    }

    local api = {}
    local root = Instance.new("Frame")
    root.Name = "Window"
    root.BackgroundTransparency = 1
    root.BorderSizePixel = 0
    root.ZIndex = 1
    root.Active = true
    root.Parent = windowsFrame

    -- soft drop shadow (Fluent style)
    local shadow = Instance.new("ImageLabel")
    shadow.Name = "Shadow"
    shadow.AnchorPoint = Vector2.new(0.5, 0.5)
    shadow.Position = UDim2.new(0.5, 0, 0.5, 6)
    shadow.Size = UDim2.new(1, 110, 1, 104)
    shadow.BackgroundTransparency = 1
    shadow.Image = ASSET.shadow
    shadow.ImageColor3 = COLOR.black
    shadow.ImageTransparency = 0.55
    shadow.ScaleType = Enum.ScaleType.Stretch
    shadow.ZIndex = 1
    shadow.Parent = root

    -- body ------------------------------------------------------------
    local body = Instance.new("Frame")
    body.Name = "Body"
    body.Size = UDim2.fromScale(1, 1)
    body.BackgroundColor3 = COLOR.white
    body.BackgroundTransparency = bgTransparency
    body.BorderSizePixel = 0
    body.ClipsDescendants = true
    body.ZIndex = 2
    body.Parent = root
    do
        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0, 10)
        corner.Parent = body

        local bgGrad = gradient(bgColors)
        if bgGrad then
            local g = Instance.new("UIGradient")
            g.Color = bgGrad
            g.Rotation = 90
            g.Parent = body
        else
            body.BackgroundColor3 = bgColors[1]
        end

        -- grain / noise layers
        local noiseA = Instance.new("ImageLabel")
        noiseA.Name = "NoiseA"
        noiseA.Size = UDim2.fromScale(1, 1)
        noiseA.BackgroundTransparency = 1
        noiseA.Image = ASSET.noiseA
        noiseA.ImageTransparency = 0.94
        noiseA.ScaleType = Enum.ScaleType.Tile
        noiseA.TileSize = UDim2.new(0, 128, 0, 128)
        noiseA.ZIndex = 2
        noiseA.Parent = body

        local noiseB = Instance.new("ImageLabel")
        noiseB.Name = "NoiseB"
        noiseB.Size = UDim2.fromScale(1, 1)
        noiseB.BackgroundTransparency = 1
        noiseB.Image = ASSET.noiseB
        noiseB.ImageTransparency = 0.96
        noiseB.ScaleType = Enum.ScaleType.Tile
        noiseB.TileSize = UDim2.new(0, 128, 0, 128)
        noiseB.ZIndex = 2
        noiseB.Parent = body

        local stroke = Instance.new("UIStroke")
        stroke.Color = COLOR.white
        stroke.Transparency = 0.82
        stroke.Thickness = 1
        stroke.Parent = body
    end

    -- title bar --------------------------------------------------------
    local bar = Instance.new("Frame")
    bar.Name = "TitleBar"
    bar.BackgroundColor3 = COLOR.white
    bar.BackgroundTransparency = titleTransparency
    bar.BorderSizePixel = 0
    bar.Size = UDim2.new(1, 0, 0, TITLE_H)
    bar.Active = true
    bar.ZIndex = 3
    bar.Parent = body
    do
        local grad = gradient(titleColors)
        if grad then
            local g = Instance.new("UIGradient")
            g.Color = grad
            g.Rotation = 0
            g.Parent = bar
        else
            bar.BackgroundColor3 = titleColors[1]
        end
        local line = Instance.new("Frame")
        line.Name = "Line"
        line.AnchorPoint = Vector2.new(0, 1)
        line.Position = UDim2.new(0, 0, 1, 0)
        line.Size = UDim2.new(1, 0, 0, 1)
        line.BackgroundColor3 = COLOR.white
        line.BackgroundTransparency = 0.85
        line.BorderSizePixel = 0
        line.ZIndex = 4
        line.Parent = bar
    end

    -- true while the pointer sits on a title bar button, so a click
    -- on minimize/close never starts a window drag
    local overButton = false

    local toggleIcon = Instance.new("ImageButton")
    toggleIcon.Name = "Toggle"
    toggleIcon.Position = UDim2.new(0, 7, 0.5, 0)
    toggleIcon.AnchorPoint = Vector2.new(0, 0.5)
    toggleIcon.Size = UDim2.new(0, 18, 0, 18)
    toggleIcon.BackgroundTransparency = 1
    toggleIcon.Image = ASSET.toggleIcon
    toggleIcon.ImageColor3 = COLOR.white
    toggleIcon.AutoButtonColor = false
    toggleIcon.ZIndex = 4
    toggleIcon.Parent = bar
    on(toggleIcon.MouseEnter, function()
        overButton = true
    end)
    on(toggleIcon.MouseLeave, function()
        overButton = false
    end)

    local titleLabel = Instance.new("TextLabel")
    titleLabel.Name = "Title"
    titleLabel.BackgroundTransparency = 1
    titleLabel.Position = UDim2.new(0, 32, 0, 0)
    titleLabel.Size = UDim2.new(1, -140, 1, 0)
    titleLabel.Font = FONT_BOLD
    titleLabel.Text = title
    titleLabel.TextColor3 = COLOR.white
    titleLabel.TextSize = 14
    titleLabel.TextXAlignment = Enum.TextXAlignment.Left
    titleLabel.TextTruncate = Enum.TextTruncate.AtEnd
    titleLabel.ZIndex = 4
    titleLabel.Parent = bar

    local authorLabel = Instance.new("TextLabel")
    authorLabel.Name = "Author"
    authorLabel.BackgroundTransparency = 1
    authorLabel.AnchorPoint = Vector2.new(1, 0.5)
    authorLabel.Position = UDim2.new(1, -76, 0.5, 0)
    authorLabel.Size = UDim2.new(0, 160, 1, 0)
    authorLabel.Font = FONT
    authorLabel.Text = author ~= nil and tostring(author) or ""
    authorLabel.TextColor3 = COLOR.white
    authorLabel.TextTransparency = 0.35
    authorLabel.TextSize = 12
    authorLabel.TextXAlignment = Enum.TextXAlignment.Right
    authorLabel.TextTruncate = Enum.TextTruncate.AtEnd
    authorLabel.Visible = author ~= nil
    authorLabel.ZIndex = 4
    authorLabel.Parent = bar

    local function makeBarButton(name, image, xPos)
        local btn = Instance.new("ImageButton")
        btn.Name = name
        btn.AnchorPoint = Vector2.new(1, 0.5)
        btn.Position = xPos
        btn.Size = UDim2.new(0, 24, 0, 24)
        btn.BackgroundColor3 = COLOR.white
        btn.BackgroundTransparency = 1
        btn.Image = image
        btn.ImageColor3 = COLOR.white
        btn.AutoButtonColor = false
        btn.ZIndex = 4
        btn.Parent = bar
        on(btn.MouseEnter, function()
            overButton = true
            tween(btn, { BackgroundTransparency = 0.82 }, 0.12)
        end)
        on(btn.MouseLeave, function()
            overButton = false
            tween(btn, { BackgroundTransparency = 1 }, 0.12)
        end)
        return btn
    end

    local minBtn = makeBarButton("Minimize", ASSET.minimize, UDim2.new(1, -56, 0.5, 0))
    local closeBtn = makeBarButton("Close", ASSET.close, UDim2.new(1, -28, 0.5, 0))

    -- navigation pane --------------------------------------------------
    local nav = Instance.new("Frame")
    nav.Name = "Nav"
    nav.BackgroundColor3 = COLOR.white
    nav.BackgroundTransparency = 0.94
    nav.BorderSizePixel = 0
    nav.Position = UDim2.new(0, 8, 0, TITLE_H + 8)
    nav.Size = UDim2.new(0, 148, 1, -(TITLE_H + 16))
    nav.ZIndex = 3
    nav.Parent = body
    do
        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0, 6)
        corner.Parent = nav
        local stroke = Instance.new("UIStroke")
        stroke.Color = COLOR.white
        stroke.Transparency = 0.92
        stroke.Parent = nav
    end

    local searchBox = Instance.new("TextBox")
    searchBox.Name = "Search"
    searchBox.Position = UDim2.new(0, 6, 0, 6)
    searchBox.Size = UDim2.new(1, -12, 0, 24)
    searchBox.BackgroundColor3 = COLOR.input
    searchBox.BackgroundTransparency = 0.1
    searchBox.Font = FONT
    searchBox.Text = ""
    searchBox.PlaceholderText = "Search"
    searchBox.PlaceholderColor3 = COLOR.faint
    searchBox.TextColor3 = COLOR.text
    searchBox.TextSize = 12
    searchBox.ClearTextOnFocus = false
    searchBox.ZIndex = 4
    searchBox.Parent = nav
    do
        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0, 6)
        corner.Parent = searchBox
        local stroke = Instance.new("UIStroke")
        stroke.Color = COLOR.white
        stroke.Transparency = 0.9
        stroke.Parent = searchBox
    end

    local navScroller = Instance.new("ScrollingFrame")
    navScroller.Name = "Tabs"
    navScroller.Position = UDim2.new(0, 4, 0, 36)
    navScroller.Size = UDim2.new(1, -8, 1, -42)
    navScroller.BackgroundTransparency = 1
    navScroller.BorderSizePixel = 0
    navScroller.ScrollBarThickness = 3
    navScroller.ScrollBarImageColor3 = COLOR.white
    navScroller.ScrollBarImageTransparency = 0.8
    navScroller.CanvasSize = UDim2.new(0, 0, 0, 0)
    navScroller.ZIndex = 4
    navScroller.ClipsDescendants = true
    navScroller.Parent = nav
    local navLayout = Instance.new("UIListLayout")
    navLayout.Parent = navScroller
    navLayout.SortOrder = Enum.SortOrder.LayoutOrder
    navLayout.Padding = UDim.new(0, 4)

    -- content holder ---------------------------------------------------
    local contentHolder = Instance.new("Frame")
    contentHolder.Name = "Content"
    contentHolder.BackgroundTransparency = 1
    contentHolder.Position = UDim2.new(0, 164, 0, TITLE_H + 8)
    contentHolder.Size = UDim2.new(1, -172, 1, -(TITLE_H + 16))
    contentHolder.ZIndex = 3
    contentHolder.ClipsDescendants = true
    contentHolder.Parent = body

    -- bottom resize line (Fluent/Wind style) ---------------------------
    local lineHit = Instance.new("TextButton")
    lineHit.Name = "ResizeLine"
    lineHit.AnchorPoint = Vector2.new(0.5, 1)
    lineHit.Position = UDim2.new(0.5, 0, 1, 0)
    lineHit.Size = UDim2.new(0, 190, 0, 8)
    lineHit.BackgroundTransparency = 1
    lineHit.Text = ""
    lineHit.AutoButtonColor = false
    lineHit.ZIndex = 6
    lineHit.Active = canResize
    lineHit.Parent = root

    local lineVisual = Instance.new("Frame")
    lineVisual.Name = "Line"
    lineVisual.AnchorPoint = Vector2.new(0.5, 1)
    lineVisual.Position = UDim2.new(0.5, 0, 1, -2)
    lineVisual.Size = UDim2.new(0, 190, 0, 4)
    lineVisual.BackgroundColor3 = COLOR.white
    lineVisual.BackgroundTransparency = 0.72
    lineVisual.BorderSizePixel = 0
    lineVisual.ZIndex = 7
    lineVisual.Parent = lineHit
    do
        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(1, 0)
        corner.Parent = lineVisual
    end

    -- corner grip -------------------------------------------------------
    local resizer = Instance.new("TextButton")
    resizer.Name = "Resizer"
    resizer.AnchorPoint = Vector2.new(1, 1)
    resizer.Position = UDim2.new(1, -2, 1, -2)
    resizer.Size = UDim2.new(0, 16, 0, 16)
    resizer.BackgroundTransparency = 1
    resizer.Text = ""
    resizer.AutoButtonColor = false
    resizer.ZIndex = 6
    resizer.Active = canResize
    resizer.Parent = root

    local grip = Instance.new("Frame")
    grip.Name = "Grip"
    grip.AnchorPoint = Vector2.new(1, 1)
    grip.Position = UDim2.new(1, -4, 1, -4)
    grip.Size = UDim2.new(0, 8, 0, 8)
    grip.BackgroundColor3 = COLOR.white
    grip.BackgroundTransparency = 0.7
    grip.BorderSizePixel = 0
    grip.Rotation = 45
    grip.ZIndex = 7
    grip.Parent = resizer

    -- layout helpers ----------------------------------------------------
    local function applyBounds(animateSize)
        W.w = math.max(W.w, W.minW)
        local floorH = W.minimized and TITLE_H or W.minH
        W.h = math.max(W.h, floorH)
        local vp2 = viewportSize()
        W.x = math.clamp(W.x, -W.w + 140, vp2.X - 140)
        W.y = math.clamp(W.y, 0, math.max(0, vp2.Y - TITLE_H))
        root.Position = UDim2.fromOffset(math.floor(W.x), math.floor(W.y))
        local target = UDim2.fromOffset(math.floor(W.w), math.floor(W.h))
        if animateSize then
            tween(root, { Size = target }, 0.22)
        else
            root.Size = target
        end
        if W.minimized or not canResize then
            lineHit.Active = false
            resizer.Active = false
            lineVisual.Visible = false
            grip.Visible = false
        else
            lineHit.Active = true
            resizer.Active = true
            lineVisual.Visible = true
            grip.Visible = true
        end
    end

    local function minimize()
        if W.minimized then
            return
        end
        W.minimized = true
        W.prevH = W.h
        W.h = TITLE_H
        applyBounds(true)
    end

    local function maximize()
        if not W.minimized then
            return
        end
        W.minimized = false
        W.h = math.max(W.prevH, W.minH)
        applyBounds(true)
    end

    local function closeWindow()
        W.closed = true
        api._closed = true
        root.Visible = false
    end

    local function showWindow()
        W.closed = false
        api._closed = false
        root.Visible = true
    end

    -- dragging ----------------------------------------------------------
    local dragging = false
    local dragStart
    local dragOrigin
    local lastBarClick = 0

    on(bar.InputBegan, function(input)
        if not isPrimaryInput(input) then
            return
        end
        if overButton then
            return
        end
        local m = mousePos()
        dragging = true
        dragStart = m
        dragOrigin = { x = W.x, y = W.y }
        local now = os.clock()
        if now - lastBarClick < 0.3 then
            -- double click: center
            local vp2 = viewportSize()
            W.x = (vp2.X - W.w) / 2
            W.y = (vp2.Y - W.h) / 2
            applyBounds()
            dragging = false
        end
        lastBarClick = now
    end)

    on(UserInputService.InputChanged, function(input)
        if not dragging then
            return
        end
        if input.UserInputType ~= Enum.UserInputType.MouseMovement
            and input.UserInputType ~= Enum.UserInputType.Touch then
            return
        end
        local m = mousePos()
        W.x = dragOrigin.x + (m.X - dragStart.X)
        W.y = dragOrigin.y + (m.Y - dragStart.Y)
        applyBounds()
    end)

    on(UserInputService.InputEnded, function(input)
        if isPrimaryInput(input) then
            dragging = false
        end
    end)

    -- corner resize -----------------------------------------------------
    local resizing = false
    local resizeStart
    local resizeOrigin

    on(resizer.InputBegan, function(input)
        if not canResize or W.minimized or not isPrimaryInput(input) then
            return
        end
        resizing = true
        resizeStart = mousePos()
        resizeOrigin = { w = W.w, h = W.h }
    end)

    -- bottom line: symmetric resize -------------------------------------
    local lineResizing = false
    local lineStart
    local lineOrigin

    on(lineHit.InputBegan, function(input)
        if not canResize or W.minimized or not isPrimaryInput(input) then
            return
        end
        lineResizing = true
        lineStart = mousePos()
        lineOrigin = { w = W.w, x = W.x }
    end)

    on(lineHit.MouseEnter, function()
        tween(lineVisual, { BackgroundTransparency = 0.35, Size = UDim2.new(0, 220, 0, 4) }, 0.15)
    end)
    on(lineHit.MouseLeave, function()
        if not lineResizing then
            tween(lineVisual, { BackgroundTransparency = 0.72, Size = UDim2.new(0, 190, 0, 4) }, 0.15)
        end
    end)

    on(UserInputService.InputChanged, function(input)
        if input.UserInputType ~= Enum.UserInputType.MouseMovement
            and input.UserInputType ~= Enum.UserInputType.Touch then
            return
        end
        local m = mousePos()
        if resizing then
            W.w = resizeOrigin.w + (m.X - resizeStart.X)
            W.h = resizeOrigin.h + (m.Y - resizeStart.Y)
            applyBounds()
        elseif lineResizing then
            local delta = m.X - lineStart.X
            W.w = lineOrigin.w + delta * 2
            W.x = lineOrigin.x - delta
            applyBounds()
        end
    end)

    on(UserInputService.InputEnded, function(input)
        if isPrimaryInput(input) then
            resizing = false
            lineResizing = false
        end
    end)

    -- window buttons -----------------------------------------------------
    on(minBtn.MouseButton1Click, function()
        if W.minimized then
            maximize()
        else
            minimize()
        end
    end)
    on(closeBtn.MouseButton1Click, function()
        closeWindow()
    end)
    on(toggleIcon.MouseButton1Click, function()
        if W.minimized then
            maximize()
        else
            minimize()
        end
    end)

    -- ============================================================
    -- Tabs
    -- ============================================================
    local tabs = {}
    local tabCount = 0
    local activeTab = nil
    local searchQuery = ""

    local function folderObjects(folderFrame)
        return folderFrame:FindFirstChild("Objects")
    end

    local function matchesQuery(row, query)
        local text = dget(row, "_searchText")
        if text == nil then
            return true
        end
        if query == "" then
            return true
        end
        return string.find(text, query, 1, true) ~= nil
    end

    local function applySearch()
        if not activeTab then
            return
        end
        local scroller = activeTab._scroller or activeTab.scroller
        if not scroller then
            return
        end
        local query = searchQuery
        for _, row in ipairs(scroller:GetChildren()) do
            if row:IsA("GuiObject") and dget(row, "_searchText") ~= nil then
                if query == "" then
                    row.Visible = true
                    if dget(row, "_isFolder") then
                        local objects = folderObjects(row)
                        if objects then
                            for _, child in ipairs(objects:GetChildren()) do
                                if child:IsA("GuiObject") and dget(child, "_searchText") ~= nil then
                                    child.Visible = true
                                end
                            end
                        end
                        if dget(row, "_searchForced") then
                            dset(row, "_searchForced", false)
                            local closeFn = dget(row, "_forceClose")
                            if closeFn then
                                closeFn()
                            end
                        end
                    end
                else
                    if dget(row, "_isFolder") then
                        local objects = folderObjects(row)
                        local childHit = false
                        if objects then
                            for _, child in ipairs(objects:GetChildren()) do
                                if child:IsA("GuiObject") and dget(child, "_searchText") ~= nil then
                                    local hit = matchesQuery(child, query)
                                    child.Visible = hit
                                    if hit then
                                        childHit = true
                                    end
                                end
                            end
                        end
                        local rowHit = matchesQuery(row, query)
                        row.Visible = rowHit or childHit
                        if childHit and not rowHit then
                            local openFn = dget(row, "_forceOpen")
                            if openFn and not dget(row, "_open") then
                                dset(row, "_searchForced", true)
                                openFn()
                            end
                        elseif dget(row, "_searchForced") and not childHit then
                            dset(row, "_searchForced", false)
                            local closeFn = dget(row, "_forceClose")
                            if closeFn then
                                closeFn()
                            end
                        end
                    else
                        row.Visible = matchesQuery(row, query)
                    end
                end
            end
        end
    end

    on(searchBox:GetPropertyChangedSignal("Text"), function()
        searchQuery = string.lower(searchBox.Text or "")
        applySearch()
    end)

    local windowApi = {}

    function windowApi:AddTab(tabName)
        tabName = tostring(tabName or "New Tab")
        tabCount = tabCount + 1
        local index = tabCount

        -- nav button
        local navBtn = Instance.new("TextButton")
        navBtn.Name = "Tab_" .. tabName
        navBtn.BackgroundColor3 = accent
        navBtn.BackgroundTransparency = 1
        navBtn.BorderSizePixel = 0
        navBtn.Font = FONT_SEMI
        navBtn.Text = tabName
        navBtn.TextColor3 = COLOR.subtext
        navBtn.TextSize = 12
        navBtn.TextXAlignment = Enum.TextXAlignment.Left
        navBtn.AutoButtonColor = false
        navBtn.Size = UDim2.new(1, -4, 0, 32)
        navBtn.LayoutOrder = index
        navBtn.ZIndex = 5
        navBtn.Parent = navScroller
        do
            local corner = Instance.new("UICorner")
            corner.CornerRadius = UDim.new(0, 6)
            corner.Parent = navBtn
        end

        local indicator = Instance.new("Frame")
        indicator.Name = "Indicator"
        indicator.AnchorPoint = Vector2.new(0, 0.5)
        indicator.Position = UDim2.new(0, 3, 0.5, 0)
        indicator.Size = UDim2.new(0, 3, 0, 14)
        indicator.BackgroundColor3 = accentLight
        indicator.BorderSizePixel = 0
        indicator.Visible = false
        indicator.ZIndex = 6
        indicator.Parent = navBtn
        do
            local corner = Instance.new("UICorner")
            corner.CornerRadius = UDim.new(1, 0)
            corner.Parent = indicator
        end

        -- content scroller
        local scroller = Instance.new("ScrollingFrame")
        scroller.Name = "Content"
        scroller.BackgroundTransparency = 1
        scroller.BorderSizePixel = 0
        scroller.Size = UDim2.fromScale(1, 1)
        scroller.ScrollBarThickness = 3
        scroller.ScrollBarImageColor3 = accentLight
        scroller.ScrollBarImageTransparency = 0.55
        scroller.CanvasSize = UDim2.new(0, 0, 0, 0)
        scroller.AutomaticCanvasSize = Enum.AutomaticSize.Y
        scroller.Visible = false
        scroller.ZIndex = 3
        scroller.ClipsDescendants = true
        scroller.Parent = contentHolder
        local contentLayout = Instance.new("UIListLayout")
        contentLayout.Parent = scroller
        contentLayout.SortOrder = Enum.SortOrder.LayoutOrder
        contentLayout.Padding = UDim.new(0, 6)
        local contentPad = Instance.new("UIPadding")
        contentPad.PaddingTop = UDim.new(0, 4)
        contentPad.PaddingBottom = UDim.new(0, 12)
        contentPad.PaddingLeft = UDim.new(0, 2)
        contentPad.PaddingRight = UDim.new(0, 8)
        contentPad.Parent = scroller

        local tabObj = {
            Name = tabName,
            _scroller = scroller,
            scroller = scroller,
            _index = index,
        }

        local function setSelected(selected)
            if selected then
                tween(navBtn, { BackgroundTransparency = 0.82 }, 0.15)
                navBtn.TextColor3 = COLOR.text
                navBtn.Font = FONT_BOLD
                indicator.Visible = true
            else
                tween(navBtn, { BackgroundTransparency = 1 }, 0.15)
                navBtn.TextColor3 = COLOR.subtext
                navBtn.Font = FONT_SEMI
                indicator.Visible = false
            end
        end

        function tabObj.Show(_)
            for _, other in ipairs(tabs) do
                other.scroller.Visible = false
                other._setSelected(false)
            end
            scroller.Visible = true
            setSelected(true)
            activeTab = tabObj
            applySearch()
        end

        tabObj._setSelected = setSelected
        tabObj._navButton = navBtn

        -- element api bound to this tab's scroller
        local elements = createElementApiRef(function()
            return scroller
        end, theme)
        for key, value in pairs(elements) do
            tabObj[key] = value
        end

        dset(scroller, "_recompute", function()
            -- content size handled by AutomaticCanvasSize
        end)

        on(navBtn.MouseButton1Click, function()
            tabObj.Show()
        end)
        on(navBtn.MouseEnter, function()
            if activeTab ~= tabObj then
                tween(navBtn, { BackgroundTransparency = 0.9 }, 0.12)
            end
        end)
        on(navBtn.MouseLeave, function()
            if activeTab ~= tabObj then
                tween(navBtn, { BackgroundTransparency = 1 }, 0.12)
            end
        end)

        navScroller.CanvasSize = UDim2.new(0, 0, 0, tabCount * 36 + 4)

        tabs[#tabs + 1] = tabObj

        if index == 1 then
            tabObj.Show()
        end

        return tabObj, scroller
    end

    -- ============================================================
    -- Window api
    -- ============================================================
    api.Minimize = minimize
    api.Maximize = maximize
    api.Close = closeWindow
    api.Show = showWindow

    function api.Search(a, b)
        local query = b ~= nil and b or a
        if type(query) ~= "string" then
            query = ""
        end
        searchQuery = string.lower(query)
        applySearch()
    end

    api._frame = root
    api._W = W
    api._cfg = cfg
    api._applyBounds = function()
        applyBounds()
    end
    api._theme = theme
    api.AddTab = function(a, b)
        local name = b ~= nil and b or a
        if type(name) == "table" then
            name = nil
        end
        return windowApi:AddTab(name)
    end
    api._closed = false

    windows[#windows + 1] = api
    applyBounds()

    return api, root
end

-- ============================================================
-- Library methods
-- ============================================================
function library:FormatWindows(padding)
    padding = tonumber(padding) or 16
    local vp = viewportSize()
    local visible = {}
    for _, api in ipairs(windows) do
        if not api._closed then
            visible[#visible + 1] = api
        end
    end
    if #visible == 0 then
        return
    end
    local cols = math.max(1, math.floor((vp.X - padding) / (480 + padding)))
    if cols > #visible then
        cols = #visible
    end
    local rows = math.ceil(#visible / cols)
    local cellW = math.floor((vp.X - padding * (cols + 1)) / cols)
    local cellH = math.floor((vp.Y - padding * (rows + 1)) / rows)
    for index, api in ipairs(visible) do
        local col = (index - 1) % cols
        local rowIdx = math.floor((index - 1) / cols)
        local W = api._W
        W.w = math.max(W.w, 320)
        W.h = math.max(W.h, 240)
        if cellW - 10 > W.w then
            W.w = cellW - 10
        end
        if cellH - 10 > W.h then
            W.h = cellH - 10
        end
        W.x = padding + col * (cellW + padding)
        W.y = padding + rowIdx * (cellH + padding)
        api._applyBounds()
    end
end

function library:Toggle()
    for _, api in ipairs(windows) do
        if api._frame.Visible then
            if api._W.minimized then
                api.Maximize()
            else
                api.Minimize()
            end
        end
    end
end

function library:SetToggleKey(key)
    if key ~= nil then
        toggleKey = key
    end
end

function library:Notify(options)
    return notify(options)
end

function library:ClearNotifications()
    clearNotifications()
end

function library:ShowWatermark(text)
    if text == false or text == nil then
        watermark.Visible = false
        return
    end
    watermark.Text = tostring(text)
    watermark.Visible = true
end

function library:GetGui()
    return gui
end

function library:Destroy()
    disconnectAll()
    clearNotifications()
    pcall(function()
        gui:Destroy()
    end)
end

-- global toggle key
on(UserInputService.InputBegan, function(input, gameProcessed)
    if gameProcessed then
        return
    end
    if bindingFlag.binding then
        return
    end
    if input.KeyCode == toggleKey then
        library:Toggle()
    end
end)

return library
