--[[
    ============================================================
    Syniox UI  (v3 - Syniox tasarim dili)
    ============================================================
    Ozellikler:
      - Orijinal Syniox gorunumu: Bodoni font, lacivert baslik,
        dilimlenmis yuvarlak kutular, kirmizi scrollbar,
        ripple efekti, aktif sekme parcaciklari
      - Wind UI tarzi ALT YENIDEN BOYUTLANDIRMA CIZGISI
      - Bildirimler (Notify), arama kutusu, kapat butonu,
        bolum/boluc/paragraf elemanlari, watermark
      - Sekme alti kayan cizgi, pencere golgesi, hover animasyonlari,
        cift tikla ortala, bildirim yiginlamasi

    KULLANIM (URL ile):
        local Syniox = loadstring(game:HttpGet("..."))()
        local Window = Syniox:AddWindow("Syniox", { author = "you" })
        local Tab = Window:AddTab("Main")
        Tab:AddButton("Click me", function() print("hi") end)

    KULLANIM (dosyayi executor sekmesine yapistirirsan):
        local Syniox = (function()
            -- dosyanin TAMAMI buraya (return library dahil)
        end)()
        local Window = Syniox:AddWindow("Syniox", { author = "you" })

    DIKKAT: Kutuphaneyi iki kez yapistirma! `return library`
    bir bloğun son ifadesi olmak zorundadir, aksi halde
    "Expected <eof>, got 'local" hatasi alirsin.

    Toggle tusu: RightShift (CONFIG.toggle_key)
]]

local CONFIG = {
    main_color = Color3.fromRGB(41, 74, 122),
    accent2 = Color3.fromRGB(84, 130, 190),
    min_size = Vector2.new(400, 300),
    default_size = Vector2.new(520, 380),
    toggle_key = Enum.KeyCode.RightShift,
    can_resize = true,
    tween_time = 0.12,
}

-- ============================================================
-- Yardimcilar
-- ============================================================
local UIS = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local TextService = game:GetService("TextService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer

local ASSET = {
    window = "rbxassetid://2851926732",
    box = "rbxassetid://2851929490",
    circle = "rbxassetid://266543268",
    palette = "rbxassetid://698052001",
    saturation = "rbxassetid://3641079629",
    arrow = "https://www.roblox.com/Thumbs/Asset.ashx?width=420&height=420&assetId=4744658743",
    folderArrow = "https://www.roblox.com/Thumbs/Asset.ashx?width=420&height=420&assetId=4731371541",
    toggleIcon = "https://www.roblox.com/Thumbs/Asset.ashx?width=420&height=420&assetId=129903125132641",
}

local COL = {
    text = Color3.fromRGB(200, 200, 200),
    dim = Color3.fromRGB(160, 160, 160),
    white = Color3.fromRGB(255, 255, 255),
    windowBg = Color3.fromRGB(21, 22, 23),
    elementBg = Color3.fromRGB(52, 53, 56),
    sliderBg = Color3.fromRGB(37, 38, 40),
    dropdownBox = Color3.fromRGB(33, 34, 36),
    inputBg = Color3.fromRGB(74, 75, 80),
    chipBg = Color3.fromRGB(45, 46, 50),
    red = Color3.fromRGB(255, 0, 0),
    black = Color3.new(0, 0, 0),
    success = Color3.fromRGB(86, 200, 130),
    error = Color3.fromRGB(235, 90, 90),
    warning = Color3.fromRGB(240, 190, 80),
}

local FONT = Enum.Font.Bodoni
local SLICE_WINDOW = Rect.new(12, 12, 12, 12)
local SLICE_BOX = Rect.new(4, 4, 4, 4)

local connections = {}

-- Instance uzerinde rawget/rawset yerine yan tablo (her yerde calisir)
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

local function on(signal, callback)
    if signal and signal.Connect then
        local ok, conn = pcall(signal.Connect, signal, callback)
        if ok and conn then
            table.insert(connections, conn)
            return conn
        end
    end
    return nil
end

local function tween(object, props, time, style, direction)
    if not object then
        return nil
    end
    time = time or CONFIG.tween_time
    local info = TweenInfo.new(time, style or Enum.EasingStyle.Quad, direction or Enum.EasingDirection.Out)
    local ok, tw = pcall(function()
        return TweenService:Create(object, info, props)
    end)
    if ok and tw then
        local okPlay, err = pcall(function()
            tw:Play()
        end)
        if okPlay then
            return tw
        end
    end
    for key, value in pairs(props) do
        pcall(function()
            object[key] = value
        end)
    end
    return nil
end

local function applyGradient(object, colors, rotation)
    if not object then
        return
    end
    local old = object:FindFirstChild("SynioxGradient")
    if old then
        old:Destroy()
    end
    if type(colors) ~= "table" or #colors == 0 then
        return
    end
    local isImage = object:IsA("ImageLabel") or object:IsA("ImageButton")
    if #colors == 1 then
        if isImage then
            object.ImageColor3 = colors[1]
        else
            object.BackgroundColor3 = colors[1]
        end
        return
    end
    local gradient = Instance.new("UIGradient")
    local keypoints = {}
    if #colors == 2 then
        keypoints = {
            ColorSequenceKeypoint.new(0, colors[1]),
            ColorSequenceKeypoint.new(1, colors[2]),
        }
    else
        keypoints = {
            ColorSequenceKeypoint.new(0, colors[1]),
            ColorSequenceKeypoint.new(0.5, colors[2]),
            ColorSequenceKeypoint.new(1, colors[3]),
        }
    end
    gradient.Color = ColorSequence.new(keypoints)
    gradient.Rotation = rotation or 0
    gradient.Name = "SynioxGradient"
    gradient.Parent = object
    if isImage then
        object.ImageColor3 = Color3.new(1, 1, 1)
    else
        object.BackgroundColor3 = Color3.new(1, 1, 1)
    end
end

local function textWidth(text, size, font)
    text = tostring(text or "")
    size = size or 14
    font = font or FONT
    local ok, bounds = pcall(function()
        return TextService:GetTextSize(text, size, font, Vector2.new(4096, 4096))
    end)
    if ok and bounds and bounds.X then
        return bounds.X
    end
    return #text * size * 0.6
end

local mouseObject do
    local ok, m = pcall(function()
        return LocalPlayer:GetMouse()
    end)
    if ok then
        mouseObject = m
    end
end

local function mousePos()
    if mouseObject then
        local okx, x = pcall(function()
            return mouseObject.X
        end)
        local oky, y = pcall(function()
            return mouseObject.Y
        end)
        if okx and oky and type(x) == "number" and type(y) == "number" then
            return Vector2.new(x, y)
        end
    end
    local ok, pos = pcall(function()
        return UIS:GetMouseLocation()
    end)
    if ok and pos then
        return Vector2.new(pos.X + 1, pos.Y - 35)
    end
    return Vector2.new(0, 0)
end

local function pointInGui(object, pos)
    if not object then
        return false
    end
    local ap = object.AbsolutePosition
    local as = object.AbsoluteSize
    return pos.X >= ap.X and pos.X <= ap.X + as.X and pos.Y >= ap.Y and pos.Y <= ap.Y + as.Y
end

local function viewportSize()
    local cam = workspace and workspace.CurrentCamera
    if cam then
        local ok, v = pcall(function()
            return cam.ViewportSize
        end)
        if ok and v and v.X and v.X > 0 then
            return v
        end
    end
    return Vector2.new(1280, 720)
end

local function call(fn, ...)
    if type(fn) == "function" then
        local ok, err = pcall(fn, ...)
        if not ok then
            warn("[Syniox UI] callback hatasi: " .. tostring(err))
        end
    end
end

local function fmtNumber(value)
    if value == math.floor(value) then
        return string.format("%d", math.floor(value))
    end
    local text = string.format("%.2f", value)
    if text:find(".", 1, true) then
        text = text:gsub("0+$", "")
        text = text:gsub("%.$", "")
    end
    return text
end

local function colorToHex(color)
    return string.format(
        "#%02X%02X%02X",
        math.floor(color.R * 255 + 0.5),
        math.floor(color.G * 255 + 0.5),
        math.floor(color.B * 255 + 0.5)
    )
end

local function hexToColor(str)
    if type(str) ~= "string" then
        return nil
    end
    str = str:gsub("#", ""):gsub("%s", "")
    if #str == 3 then
        str = str:sub(1, 1):rep(2) .. str:sub(2, 2):rep(2) .. str:sub(3, 3):rep(2)
    end
    if #str ~= 6 then
        return nil
    end
    local r, g, b = str:match("(%x%x)(%x%x)(%x%x)")
    if not r then
        return nil
    end
    return Color3.fromRGB(tonumber(r, 16), tonumber(g, 16), tonumber(b, 16))
end

-- ripple efekti (orijinal Syniox Circle prefab'i)
local function ripple(parent, x, y)
    if not parent then
        return
    end
    task.spawn(function()
        local circle = Instance.new("ImageLabel")
        circle.Name = "RippleCircle"
        circle.BackgroundTransparency = 1
        circle.Image = ASSET.circle
        circle.ImageTransparency = 0.5
        circle.AnchorPoint = Vector2.new(0.5, 0.5)
        circle.ZIndex = 900
        circle.ClipsDescendants = false
        parent.ClipsDescendants = true
        local size = math.max(parent.AbsoluteSize.X, parent.AbsoluteSize.Y) * 1.7
        local dx = x - parent.AbsolutePosition.X
        local dy = y - parent.AbsolutePosition.Y
        circle.Size = UDim2.new(0, 8, 0, 8)
        circle.Position = UDim2.new(0, dx, 0, dy)
        circle.Parent = parent
        tween(
            circle,
            {
                Size = UDim2.new(0, size, 0, size),
                Position = UDim2.new(0.5, 0, 0.5, 0),
                ImageTransparency = 1,
            },
            0.5,
            Enum.EasingStyle.Quad,
            Enum.EasingDirection.Out
        )
        task.delay(0.5, function()
            if circle then
                circle:Destroy()
            end
        end)
    end)
end

local function rippleAt(object)
    if not object then
        return
    end
    local pos = mousePos()
    ripple(object, pos.X, pos.Y)
end

local function sliceImage(className, props)
    local image = Instance.new(className or "ImageLabel")
    image.BackgroundTransparency = 1
    image.ScaleType = Enum.ScaleType.Slice
    image.SliceCenter = SLICE_BOX
    image.Image = ASSET.box
    if props then
        for key, value in pairs(props) do
            image[key] = value
        end
    end
    return image
end

local function roundify(object, radius)
    if not object then
        return
    end
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, radius or 4)
    corner.Parent = object
    return corner
end

local function uiStroke(object, color, thickness, transparency)
    if not object then
        return nil
    end
    local stroke = Instance.new("UIStroke")
    stroke.Color = color or COL.black
    stroke.Thickness = thickness or 1
    stroke.Transparency = transparency or 0.7
    stroke.Parent = object
    return stroke
end

local function makeLayout(parent, direction, padding, sortOrder)
    local layout = Instance.new("UIListLayout")
    layout.FillDirection = direction or Enum.FillDirection.Vertical
    layout.Padding = UDim.new(0, padding or 5)
    layout.SortOrder = sortOrder or Enum.SortOrder.LayoutOrder
    if direction == Enum.FillDirection.Horizontal then
        layout.VerticalAlignment = Enum.VerticalAlignment.Center
    end
    layout.Parent = parent
    return layout
end

local function nextOrder(parent)
    local order = (dget(parent, "_synioxOrder") or 0) + 1
    dset(parent, "_synioxOrder", order)
    return order
end

-- ============================================================
-- ScreenGui
-- ============================================================
local guiParent
do
    if gethui then
        local ok, hidden = pcall(gethui)
        if ok and hidden then
            guiParent = hidden
        end
    end
    if not guiParent then
        local ok, core = pcall(function()
            return game:GetService("CoreGui")
        end)
        if ok and core then
            guiParent = core
        end
    end
    if not guiParent then
        guiParent = LocalPlayer:WaitForChild("PlayerGui")
    end
end

pcall(function()
    local old = guiParent:FindFirstChild("imgui")
    if old then
        old:Destroy()
    end
end)

local gui = Instance.new("ScreenGui")
gui.Name = "imgui"
gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.DisplayOrder = 10
gui.Parent = guiParent

local windowsFrame = Instance.new("Frame")
windowsFrame.Name = "Windows"
windowsFrame.BackgroundTransparency = 1
windowsFrame.Size = UDim2.new(1, 0, 1, 0)
windowsFrame.Parent = gui

local notificationsFrame = Instance.new("Frame")
notificationsFrame.Name = "Notifications"
notificationsFrame.AnchorPoint = Vector2.new(1, 0)
notificationsFrame.Position = UDim2.new(1, -14, 0, 14)
notificationsFrame.Size = UDim2.new(0, 258, 0, 0)
notificationsFrame.AutomaticSize = Enum.AutomaticSize.Y
notificationsFrame.BackgroundTransparency = 1
notificationsFrame.ZIndex = 80
notificationsFrame.Parent = gui
makeLayout(notificationsFrame, Enum.FillDirection.Vertical, 6)

-- watermark
local watermark = Instance.new("TextLabel")
watermark.Name = "Watermark"
watermark.AnchorPoint = Vector2.new(0, 0)
watermark.Position = UDim2.new(0, 14, 0, 12)
watermark.Size = UDim2.new(0, 0, 0, 28)
watermark.AutomaticSize = Enum.AutomaticSize.X
watermark.BackgroundColor3 = Color3.fromRGB(26, 27, 30)
watermark.BackgroundTransparency = 0.15
watermark.Font = FONT
watermark.Text = ""
watermark.TextColor3 = COL.white
watermark.TextSize = 14
watermark.Visible = false
watermark.ZIndex = 80
watermark.Parent = gui
roundify(watermark, 8)
do
    local pad = Instance.new("UIPadding")
    pad.PaddingLeft = UDim.new(0, 12)
    pad.PaddingRight = UDim.new(0, 12)
    pad.Parent = watermark
end

-- ============================================================
-- Bildirimler
-- ============================================================
local notifications = {}

local NOTE_COLORS = {
    info = nil, -- main_color kullanilir
    success = COL.success,
    error = COL.error,
    warning = COL.warning,
}

local function closeNotification(entry, instant)
    if not entry or entry.closing then
        return
    end
    entry.closing = true
    for index, other in ipairs(notifications) do
        if other == entry then
            table.remove(notifications, index)
            break
        end
    end
    if instant then
        if entry.wrapper then
            entry.wrapper:Destroy()
        end
        return
    end
    tween(entry.card, { Position = UDim2.new(0, 300, 0, 0), ImageTransparency = 1 }, 0.22)
    task.delay(0.25, function()
        if entry.wrapper then
            entry.wrapper:Destroy()
        end
    end)
end

local function notify(options)
    if type(options) == "string" then
        options = { Title = options }
    end
    options = type(options) == "table" and options or {}

    local title = tostring(options.Title or options.title or "Syniox")
    local content = tostring(options.Content or options.content or options.Message or "")
    local duration = tonumber(options.Duration or options.duration)
    if duration == nil then
        duration = 4
    end
    local kind = string.lower(tostring(options.Type or options.type or "info"))
    local accent = NOTE_COLORS[kind] or CONFIG.main_color

    while #notifications >= 6 do
        closeNotification(notifications[1], true)
    end

    local wrapper = Instance.new("Frame")
    wrapper.Name = "Notification"
    wrapper.BackgroundTransparency = 1
    wrapper.Size = UDim2.new(1, 0, 0, 0)
    wrapper.AutomaticSize = Enum.AutomaticSize.Y
    wrapper.ZIndex = 80
    wrapper.Active = true

    local card = Instance.new("ImageLabel")
    card.Name = "Card"
    card.Image = ASSET.window
    card.ScaleType = Enum.ScaleType.Slice
    card.SliceCenter = SLICE_WINDOW
    card.ImageColor3 = Color3.fromRGB(28, 29, 33)
    card.ImageTransparency = 0.06
    card.Size = UDim2.new(1, 0, 0, 0)
    card.Position = UDim2.new(0, 300, 0, 0)
    card.AutomaticSize = Enum.AutomaticSize.Y
    card.ZIndex = 81
    card.Parent = wrapper

    local accentBar = Instance.new("Frame")
    accentBar.Name = "Accent"
    accentBar.BackgroundColor3 = accent
    accentBar.BorderSizePixel = 0
    accentBar.Size = UDim2.new(0, 4, 1, 0)
    accentBar.ZIndex = 83
    accentBar.Parent = card

    local titleLabel = Instance.new("TextLabel")
    titleLabel.Name = "Title"
    titleLabel.BackgroundTransparency = 1
    titleLabel.Position = UDim2.new(0, 14, 0, 5)
    titleLabel.Size = UDim2.new(1, -26, 0, 17)
    titleLabel.Font = FONT
    titleLabel.Text = title
    titleLabel.TextColor3 = COL.white
    titleLabel.TextSize = 15
    titleLabel.TextXAlignment = Enum.TextXAlignment.Left
    titleLabel.ZIndex = 83
    titleLabel.Parent = card

    local contentLabel = Instance.new("TextLabel")
    contentLabel.Name = "Content"
    contentLabel.BackgroundTransparency = 1
    contentLabel.Position = UDim2.new(0, 14, 0, 24)
    contentLabel.Size = UDim2.new(1, -26, 0, 0)
    contentLabel.AutomaticSize = Enum.AutomaticSize.Y
    contentLabel.Font = FONT
    contentLabel.Text = content
    contentLabel.TextColor3 = COL.text
    contentLabel.TextSize = 13
    contentLabel.TextWrapped = true
    contentLabel.TextXAlignment = Enum.TextXAlignment.Left
    contentLabel.TextYAlignment = Enum.TextYAlignment.Top
    contentLabel.Visible = content ~= ""
    contentLabel.ZIndex = 83
    contentLabel.Parent = card

    local pad = Instance.new("UIPadding")
    pad.PaddingBottom = UDim.new(0, 12)
    pad.Parent = card

    local track = Instance.new("Frame")
    track.Name = "Track"
    track.Position = UDim2.new(0, 14, 1, -9)
    track.Size = UDim2.new(1, -28, 0, 2)
    track.BackgroundColor3 = Color3.new(1, 1, 1)
    track.BackgroundTransparency = 0.85
    track.BorderSizePixel = 0
    track.ZIndex = 83
    track.Parent = card

    local fill = Instance.new("Frame")
    fill.Name = "Fill"
    fill.Size = UDim2.new(1, 0, 0, 2)
    fill.BackgroundColor3 = accent
    fill.BorderSizePixel = 0
    fill.ZIndex = 84
    fill.Parent = track

    wrapper.Parent = notificationsFrame

    local entry = { wrapper = wrapper, card = card, closing = false }
    table.insert(notifications, entry)

    tween(card, { Position = UDim2.new(0, 0, 0, 0) }, 0.25, Enum.EasingStyle.Quint)

    if duration > 0 then
        tween(fill, { Size = UDim2.new(0, 0, 0, 2) }, duration, Enum.EasingStyle.Linear)
        task.delay(duration, function()
            closeNotification(entry, false)
        end)
    end

    on(wrapper.InputBegan, function(input)
        if isPrimaryInput(input) then
            closeNotification(entry, false)
        end
    end)

    entry.Close = function()
        closeNotification(entry, false)
    end

    return entry
end

local function clearNotifications()
    for index = #notifications, 1, -1 do
        closeNotification(notifications[index], true)
    end
end

-- ============================================================
-- Pencereler
-- ============================================================
local library = {}
local windows = {}
local windowCount = 0
local toggleKey = CONFIG.toggle_key
local bindingFlag = { binding = false }
local createElementApi -- part3'te tanimlanacak
local allParticleConns = {}

local function stopAllParticles()
    for index = #allParticleConns, 1, -1 do
        local conn = allParticleConns[index]
        if conn then
            pcall(function()
                conn:Disconnect()
            end)
        end
        table.remove(allParticleConns, index)
    end
end

local function lighten(color, amount)
    return Color3.new(
        color.R + (1 - color.R) * amount,
        color.G + (1 - color.G) * amount,
        color.B + (1 - color.B) * amount
    )
end

local function asVector(v, defX, defY)
    if typeof(v) == "Vector2" then
        return v.X, v.Y
    end
    if typeof(v) == "UDim2" then
        return v.X.Offset, v.Y.Offset
    end
    return defX, defY
end

local function isPrimaryInput(input)
    return input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch
end

function library:AddWindow(title, config)
    title = tostring(title or "New Window")
    config = typeof(config) == "table" and config or {}
    windowCount = windowCount + 1
    local zbase = windowCount * 10

    local cfg = {}
    cfg.tween_time = tonumber(config.tween_time) or CONFIG.tween_time
    cfg.title_bar = config.title_bar or { CONFIG.main_color }
    if typeof(cfg.title_bar) == "Color3" then
        cfg.title_bar = { cfg.title_bar }
    end
    cfg.title_bar_transparency = tonumber(config.title_bar_transparency) or 0
    cfg.background = config.background or { COL.windowBg }
    if typeof(cfg.background) == "Color3" then
        cfg.background = { cfg.background }
    end
    cfg.background_transparency = tonumber(config.background_transparency) or 0.1
    if type(config.transparencies) == "table" then
        if config.transparencies.background then
            cfg.background_transparency = tonumber(config.transparencies.background) or cfg.background_transparency
        end
        if config.transparencies.title_bar then
            cfg.title_bar_transparency = tonumber(config.transparencies.title_bar) or cfg.title_bar_transparency
        end
    end
    cfg.main_color = config.main_color or cfg.title_bar[1] or CONFIG.main_color
    cfg.accent2 = config.accent2 or CONFIG.accent2
    cfg.can_resize = config.can_resize
    if cfg.can_resize == nil then
        cfg.can_resize = CONFIG.can_resize
    end
    cfg.author = config.author
    cfg.icon = config.icon
    cfg.close_button = config.close_button ~= false
    cfg.search = config.search ~= false
    cfg.center = config.center == true

    local minW, minH = asVector(config.min_size, CONFIG.min_size.X, CONFIG.min_size.Y)
    cfg.min_size = Vector2.new(minW, minH)

    local w, h
    if typeof(config.size) == "UDim2" then
        w, h = config.size.X.Offset, config.size.Y.Offset
    elseif typeof(config.size) == "Vector2" then
        w, h = config.size.X, config.size.Y
    else
        w, h = minW, minH
    end
    w = math.max(w, minW)
    h = math.max(h, minH)

    local vp = viewportSize()
    local x, y
    if typeof(config.position) == "UDim2" then
        x = config.position.X.Scale * vp.X + config.position.X.Offset
        y = config.position.Y.Scale * vp.Y + config.position.Y.Offset
    elseif cfg.center then
        x = math.floor(vp.X / 2 - w / 2)
        y = math.floor(vp.Y / 2 - h / 2)
    else
        x = 24 + (windowCount - 1) * 30
        y = 24 + (windowCount - 1) * 30
    end

    local W = { x = x, y = y, w = w, h = h, minimized = false, prevH = h, closed = false }
    local api = {}

    -- golge
    local shadow = Instance.new("ImageLabel")
    shadow.Name = "Shadow"
    shadow.Image = ASSET.window
    shadow.ScaleType = Enum.ScaleType.Slice
    shadow.SliceCenter = SLICE_WINDOW
    shadow.ImageColor3 = Color3.new(0, 0, 0)
    shadow.ImageTransparency = 0.55
    shadow.ZIndex = zbase - 5
    shadow.Parent = windowsFrame

    local function syncShadow()
        shadow.Position = UDim2.new(0, W.x - 7, 0, W.y + 8)
        shadow.Size = UDim2.new(0, W.w + 14, 0, W.h)
    end

    local frame = Instance.new("Frame")
    frame.Name = "Window_" .. title
    frame.Active = true
    frame.BackgroundTransparency = 1
    frame.ClipsDescendants = true
    frame.ZIndex = zbase
    roundify(frame, 12)
    frame.Parent = windowsFrame

    local function applyBounds()
        frame.Position = UDim2.new(0, W.x, 0, W.y)
        frame.Size = UDim2.new(0, W.w, 0, W.h)
        syncShadow()
    end
    applyBounds()

    -- arka plan
    local bg = Instance.new("ImageLabel")
    bg.Name = "Background"
    bg.Size = UDim2.new(1, 0, 1, 0)
    bg.Image = ASSET.window
    bg.ScaleType = Enum.ScaleType.Slice
    bg.SliceCenter = SLICE_WINDOW
    bg.ImageTransparency = cfg.background_transparency
    bg.ZIndex = 1
    bg.Parent = frame
    applyGradient(bg, cfg.background, 45)

    -- baslik cubugu
    local bar = Instance.new("Frame")
    bar.Name = "Bar"
    bar.Size = UDim2.new(1, 0, 0, 24)
    bar.Active = true
    bar.BorderSizePixel = 0
    bar.BackgroundTransparency = cfg.title_bar_transparency
    bar.ZIndex = 3
    roundify(bar, 5)
    bar.Parent = frame
    applyGradient(bar, cfg.title_bar, 0)

    local toggleButton = Instance.new("ImageButton")
    toggleButton.Name = "Toggle"
    toggleButton.Position = UDim2.new(0, 5, 0, 2)
    toggleButton.Size = UDim2.new(0, 20, 0, 20)
    toggleButton.BackgroundTransparency = 1
    toggleButton.Image = ASSET.toggleIcon
    toggleButton.ZIndex = 4
    toggleButton.Parent = bar

    local closeButton
    local searchBox
    local closeW = 26
    if cfg.close_button then
        closeButton = Instance.new("TextButton")
        closeButton.Name = "Close"
        closeButton.AnchorPoint = Vector2.new(1, 0)
        closeButton.Position = UDim2.new(1, -4, 0, 2)
        closeButton.Size = UDim2.new(0, 22, 0, 20)
        closeButton.BackgroundTransparency = 1
        closeButton.Font = FONT
        closeButton.Text = "×"
        closeButton.TextColor3 = COL.text
        closeButton.TextSize = 16
        closeButton.AutoButtonColor = false
        closeButton.ZIndex = 4
        closeButton.Parent = bar
    else
        closeW = 4
    end

    local authorW = 0
    if cfg.author then
        authorW = textWidth(cfg.author, 12) + 6
        local authorLabel = Instance.new("TextLabel")
        authorLabel.Name = "Author"
        authorLabel.AnchorPoint = Vector2.new(1, 0)
        authorLabel.Position = UDim2.new(1, -32, 0, 4)
        authorLabel.Size = UDim2.new(0, authorW - 6, 0, 16)
        authorLabel.BackgroundTransparency = 1
        authorLabel.Font = FONT
        authorLabel.Text = tostring(cfg.author)
        authorLabel.TextColor3 = COL.text
        authorLabel.TextSize = 12
        authorLabel.TextTransparency = 0.35
        authorLabel.TextXAlignment = Enum.TextXAlignment.Right
        authorLabel.ZIndex = 4
        authorLabel.Parent = bar
    end

    local rightW = closeW + authorW
    if cfg.search then
        local searchRight = 26 + 8
        if cfg.author then
            searchRight = 32 + (authorW - 6) + 8
        end
        rightW = searchRight + 110
        searchBox = Instance.new("TextBox")
        searchBox.Name = "Search"
        searchBox.AnchorPoint = Vector2.new(1, 0)
        searchBox.Position = UDim2.new(1, -(searchRight + 110), 0, 4)
        searchBox.Size = UDim2.new(0, 110, 0, 16)
        searchBox.BackgroundTransparency = 1
        searchBox.Font = FONT
        searchBox.Text = ""
        searchBox.PlaceholderText = "🔍 Ara..."
        searchBox.PlaceholderColor3 = Color3.fromRGB(150, 150, 150)
        searchBox.TextColor3 = COL.white
        searchBox.TextSize = 12
        searchBox.ClearTextOnFocus = false
        searchBox.ZIndex = 4
        searchBox.Parent = bar
        local searchBg = sliceImage("ImageLabel", {
            ImageColor3 = COL.chipBg,
            ImageTransparency = 0.2,
            ZIndex = 1,
        })
        searchBg.Size = UDim2.new(1, 0, 1, 0)
        searchBg.Parent = searchBox
        roundify(searchBox, 5)
    end

    local titleLabel = Instance.new("TextLabel")
    titleLabel.Name = "Title"
    titleLabel.Position = UDim2.new(0, 30, 0, 0)
    titleLabel.Size = UDim2.new(1, -(30 + rightW), 1, 0)
    titleLabel.BackgroundTransparency = 1
    titleLabel.Font = FONT
    titleLabel.Text = title
    titleLabel.TextColor3 = COL.white
    titleLabel.TextSize = 16
    titleLabel.TextXAlignment = Enum.TextXAlignment.Center
    titleLabel.ZIndex = 4
    titleLabel.Parent = bar

    if cfg.icon then
        local icon = Instance.new("ImageLabel")
        icon.Name = "Icon"
        icon.Position = UDim2.new(0, 27, 0, 4)
        icon.Size = UDim2.new(0, 16, 0, 16)
        icon.BackgroundTransparency = 1
        icon.Image = tostring(cfg.icon)
        icon.ZIndex = 4
        icon.Parent = bar
    end

    -- sekme seridi
    local strip = Instance.new("ImageLabel")
    strip.Name = "TabSelection"
    strip.Position = UDim2.new(0, 15, 0, 28)
    strip.Size = UDim2.new(1, -30, 0, 22)
    strip.Image = ASSET.box
    strip.ScaleType = Enum.ScaleType.Slice
    strip.SliceCenter = SLICE_BOX
    strip.ImageTransparency = 0.4
    strip.Visible = false
    strip.ClipsDescendants = true
    strip.ZIndex = 5
    strip.Parent = frame
    roundify(strip, 6)
    applyGradient(strip, cfg.title_bar, 45)

    local stripScroll = Instance.new("ScrollingFrame")
    stripScroll.Name = "TabScrolling"
    stripScroll.Size = UDim2.new(1, 0, 1, 0)
    stripScroll.BackgroundTransparency = 1
    stripScroll.BorderSizePixel = 0
    stripScroll.ScrollBarThickness = 0
    stripScroll.ScrollingDirection = Enum.ScrollingDirection.X
    stripScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
    stripScroll.ZIndex = 1
    stripScroll.Parent = strip

    local buttonsFrame = Instance.new("Frame")
    buttonsFrame.Name = "TabButtons"
    buttonsFrame.Size = UDim2.new(0, 0, 1, 0)
    buttonsFrame.BackgroundTransparency = 1
    buttonsFrame.ZIndex = 1
    buttonsFrame.Parent = stripScroll
    local buttonsLayout = makeLayout(buttonsFrame, Enum.FillDirection.Horizontal, 12)

    local underline = Instance.new("Frame")
    underline.Name = "Underline"
    underline.Size = UDim2.new(0, 0, 0, 2)
    underline.Position = UDim2.new(0, 0, 0, 19)
    underline.BackgroundColor3 = lighten(cfg.main_color, 0.45)
    underline.BorderSizePixel = 0
    underline.Visible = false
    underline.ZIndex = 3
    underline.Parent = strip
    roundify(underline, 1)

    -- icerik alani
    local tabsContainer = Instance.new("Frame")
    tabsContainer.Name = "Tabs"
    tabsContainer.Position = UDim2.new(0, 15, 0, 60)
    tabsContainer.Size = UDim2.new(1, -30, 1, -60)
    tabsContainer.BackgroundTransparency = 1
    tabsContainer.ClipsDescendants = true
    tabsContainer.ZIndex = 6
    tabsContainer.Parent = frame

    -- sag alt yeniden boyutlandirma
    local resizer = Instance.new("Frame")
    resizer.Name = "Resizer"
    resizer.AnchorPoint = Vector2.new(1, 1)
    resizer.Position = UDim2.new(1, -6, 1, -6)
    resizer.Size = UDim2.new(0, 22, 0, 22)
    resizer.BackgroundTransparency = 1
    resizer.Active = cfg.can_resize
    resizer.ZIndex = 7
    resizer.Parent = frame
    do
        local gripA = Instance.new("Frame")
        gripA.AnchorPoint = Vector2.new(1, 1)
        gripA.Position = UDim2.new(1, -7, 1, -7)
        gripA.Size = UDim2.new(0, 16, 0, 2)
        gripA.Rotation = -45
        gripA.BackgroundColor3 = COL.text
        gripA.BackgroundTransparency = 0.55
        gripA.BorderSizePixel = 0
        gripA.ZIndex = 7
        gripA.Parent = resizer
        roundify(gripA, 1)
        local gripB = Instance.new("Frame")
        gripB.AnchorPoint = Vector2.new(1, 1)
        gripB.Position = UDim2.new(1, -14, 1, -14)
        gripB.Size = UDim2.new(0, 9, 0, 2)
        gripB.Rotation = -45
        gripB.BackgroundColor3 = COL.text
        gripB.BackgroundTransparency = 0.55
        gripB.BorderSizePixel = 0
        gripB.ZIndex = 7
        gripB.Parent = resizer
        roundify(gripB, 1)
    end

    -- Wind UI tarzi alt yeniden boyutlandirma cizgisi
    local lineContainer = Instance.new("Frame")
    lineContainer.Name = "ResizeLine"
    lineContainer.AnchorPoint = Vector2.new(0.5, 0)
    lineContainer.Position = UDim2.new(0.5, 0, 1, -13)
    lineContainer.Size = UDim2.new(0, 210, 0, 13)
    lineContainer.BackgroundTransparency = 1
    lineContainer.ZIndex = 8
    lineContainer.Visible = cfg.can_resize and not false
    lineContainer.Parent = frame

    local lineHit = Instance.new("TextButton")
    lineHit.Name = "Hit"
    lineHit.Size = UDim2.new(1, 0, 1, 0)
    lineHit.BackgroundTransparency = 1
    lineHit.Text = ""
    lineHit.AutoButtonColor = false
    lineHit.ZIndex = 1
    lineHit.Parent = lineContainer

    local lineVisual = Instance.new("Frame")
    lineVisual.Name = "Line"
    lineVisual.AnchorPoint = Vector2.new(0.5, 0.5)
    lineVisual.Position = UDim2.new(0.5, 0, 0.5, 0)
    lineVisual.Size = UDim2.new(0, 90, 0, 3)
    lineVisual.BackgroundColor3 = Color3.new(1, 1, 1)
    lineVisual.BackgroundTransparency = 0.72
    lineVisual.BorderSizePixel = 0
    lineVisual.ZIndex = 2
    lineVisual.Parent = lineContainer
    roundify(lineVisual, 2)

    -- pencere durumu
    local function minimize()
        if W.minimized then
            return
        end
        W.minimized = true
        W.prevH = W.h
        tabsContainer.Visible = false
        resizer.Active = false
        lineContainer.Visible = false
        W.h = 26
        tween(frame, { Size = UDim2.new(0, W.w, 0, 26) }, cfg.tween_time)
        task.delay(cfg.tween_time + 0.03, syncShadow)
    end

    local function maximize()
        if not W.minimized then
            return
        end
        W.minimized = false
        tabsContainer.Visible = true
        resizer.Active = cfg.can_resize
        lineContainer.Visible = cfg.can_resize
        W.h = W.prevH
        tween(frame, { Size = UDim2.new(0, W.w, 0, W.h) }, cfg.tween_time)
        task.delay(cfg.tween_time + 0.03, syncShadow)
    end

    local function closeWindow()
        W.closed = true
        api._closed = true
        frame.Visible = false
        shadow.Visible = false
    end

    local function showWindow()
        W.closed = false
        api._closed = false
        frame.Visible = true
        shadow.Visible = true
    end

    on(toggleButton.MouseButton1Click, function()
        rippleAt(toggleButton)
        if W.minimized then
            maximize()
        else
            minimize()
        end
    end)

    if closeButton then
        on(closeButton.MouseButton1Click, function()
            rippleAt(closeButton)
            closeWindow()
        end)
        on(closeButton.MouseEnter, function()
            tween(closeButton, { TextTransparency = 0 }, 0.1)
            closeButton.TextColor3 = COL.error
        end)
        on(closeButton.MouseLeave, function()
            closeButton.TextColor3 = COL.text
        end)
    end

    -- surukleme + cift tikla ortala
    local dragging = false
    local dragStart
    local dragOrigin
    local lastBarClick = 0
    on(bar.InputBegan, function(input)
        if not isPrimaryInput(input) then
            return
        end
        local m = mousePos()
        if pointInGui(toggleButton, m) then
            return
        end
        if closeButton and pointInGui(closeButton, m) then
            return
        end
        if searchBox and pointInGui(searchBox, m) then
            return
        end
        dragging = true
        dragStart = Vector2.new(input.Position.X, input.Position.Y)
        dragOrigin = { x = W.x, y = W.y }
        local now = os.clock()
        if now - lastBarClick < 0.3 then
            lastBarClick = 0
            local vp2 = viewportSize()
            W.x = math.floor(vp2.X / 2 - W.w / 2)
            W.y = math.floor(vp2.Y / 2 - W.h / 2)
            applyBounds()
        else
            lastBarClick = now
        end
    end)
    on(UIS.InputChanged, function(input)
        if not dragging then
            return
        end
        if input.UserInputType ~= Enum.UserInputType.MouseMovement
            and input.UserInputType ~= Enum.UserInputType.Touch then
            return
        end
        local p = input.Position
        local dx = p.X - dragStart.X
        local dy = p.Y - dragStart.Y
        local vp2 = viewportSize()
        W.x = dragOrigin.x + dx
        W.y = dragOrigin.y + dy
        local minX = -(W.w - 140)
        W.x = math.clamp(W.x, minX, math.max(minX, vp2.X - 140))
        W.y = math.clamp(W.y, 0, math.max(0, vp2.Y - 30))
        applyBounds()
    end)
    on(UIS.InputEnded, function(input)
        if isPrimaryInput(input) then
            dragging = false
        end
    end)

    -- sag alt kose yeniden boyutlandirma
    local resizing = false
    on(resizer.InputBegan, function(input)
        if isPrimaryInput(input) and cfg.can_resize and not W.minimized then
            resizing = true
        end
    end)
    on(UIS.InputChanged, function(input)
        if not resizing then
            return
        end
        if input.UserInputType ~= Enum.UserInputType.MouseMovement
            and input.UserInputType ~= Enum.UserInputType.Touch then
            return
        end
        local m = mousePos()
        W.w = math.max(minW, m.X - W.x)
        W.h = math.max(minH, m.Y - W.y)
        applyBounds()
    end)
    on(UIS.InputEnded, function(input)
        if isPrimaryInput(input) then
            resizing = false
        end
    end)

    -- alt cizgi: hover + simetrik yeniden boyutlandirma
    local lineHover = false
    local lineDragging = false
    local lineStart
    local lineOrigin
    on(lineHit.MouseEnter, function()
        lineHover = true
        if not lineDragging then
            tween(lineVisual, { Size = UDim2.new(0, 190, 0, 3), BackgroundTransparency = 0.35 }, 0.15)
        end
    end)
    on(lineHit.MouseLeave, function()
        lineHover = false
        if not lineDragging then
            tween(lineVisual, { Size = UDim2.new(0, 90, 0, 3), BackgroundTransparency = 0.72 }, 0.15)
        end
    end)
    on(lineHit.InputBegan, function(input)
        if isPrimaryInput(input) and cfg.can_resize and not W.minimized then
            lineDragging = true
            local m = mousePos()
            lineStart = m
            lineOrigin = { x = W.x, y = W.y, w = W.w, h = W.h }
            tween(lineVisual, { Size = UDim2.new(0, 190, 0, 4), BackgroundTransparency = 0.2 }, 0.1)
        end
    end)
    on(UIS.InputChanged, function(input)
        if not lineDragging then
            return
        end
        if input.UserInputType ~= Enum.UserInputType.MouseMovement
            and input.UserInputType ~= Enum.UserInputType.Touch then
            return
        end
        local m = mousePos()
        local dx = m.X - lineStart.X
        local dy = m.Y - lineStart.Y
        local newW = math.max(minW, lineOrigin.w + dx * 2)
        local newX = lineOrigin.x - dx
        local newH = math.max(minH, lineOrigin.h + dy)
        local vp2 = viewportSize()
        local minX = -(newW - 140)
        newX = math.clamp(newX, minX, math.max(minX, vp2.X - 140))
        W.x = newX
        W.w = newW
        W.h = newH
        applyBounds()
    end)
    on(UIS.InputEnded, function(input)
        if isPrimaryInput(input) and lineDragging then
            lineDragging = false
            if lineHover then
                tween(lineVisual, { Size = UDim2.new(0, 190, 0, 3), BackgroundTransparency = 0.35 }, 0.15)
            else
                tween(lineVisual, { Size = UDim2.new(0, 90, 0, 3), BackgroundTransparency = 0.72 }, 0.15)
            end
        end
    end)

    -- ========================================================
    -- Sekmeler
    -- ========================================================
    local tabs = {}
    local activeTab = nil
    local particleConn = nil
    local particleClock = 0

    local function randBetween(lo, hi)
        hi = math.max(hi, lo + 1)
        return math.random(lo, hi)
    end

    local function emitParticle(button)
        if not button or not button.Parent then
            return
        end
        local size = button.AbsoluteSize
        local width = math.max(size.X, 12)
        local height = math.max(size.Y, 18)
        local particle = Instance.new("Frame")
        particle.Name = "SimpleParticle"
        particle.Size = UDim2.new(0, 2, 0, 2)
        particle.AnchorPoint = Vector2.new(0.5, 0.5)
        particle.BackgroundColor3 = Color3.new(1, 1, 1)
        particle.BorderSizePixel = 0
        particle.ZIndex = 20
        roundify(particle, 1)
        local edge = math.random(1, 4)
        local px, py
        if edge == 1 then
            px = randBetween(2, math.floor(width) - 2)
            py = 1
        elseif edge == 2 then
            px = width - 1
            py = randBetween(2, math.floor(height) - 2)
        elseif edge == 3 then
            px = randBetween(2, math.floor(width) - 2)
            py = height - 1
        else
            px = 1
            py = randBetween(2, math.floor(height) - 2)
        end
        particle.Position = UDim2.new(0, px, 0, py)
        particle.Parent = button
        local cx, cy = width / 2, height / 2
        local dx, dy = px - cx, py - cy
        local dist = math.sqrt(dx * dx + dy * dy)
        if dist < 1 then
            dist = 1
        end
        dx, dy = dx / dist, dy / dist
        tween(
            particle,
            {
                Position = UDim2.new(0, px + dx * 8, 0, py + dy * 8),
                BackgroundTransparency = 1,
            },
            0.5
        )
        task.delay(0.55, function()
            if particle then
                particle:Destroy()
            end
        end)
    end

    local function stopParticles()
        if particleConn then
            pcall(function()
                particleConn:Disconnect()
            end)
            for index = #allParticleConns, 1, -1 do
                if allParticleConns[index] == particleConn then
                    table.remove(allParticleConns, index)
                end
            end
            particleConn = nil
        end
    end

    local function startParticles(button)
        stopParticles()
        local hb = RunService.Heartbeat
        if not (hb and hb.Connect) then
            return
        end
        particleClock = 0
        particleConn = on(hb, function(dt)
            particleClock = particleClock + (tonumber(dt) or 0.016)
            if particleClock >= 0.35 then
                particleClock = 0
                emitParticle(button)
            end
        end)
        if particleConn then
            table.insert(allParticleConns, particleConn)
        end
    end

    local function updateTabCanvas()
        local total = 0
        for _, child in ipairs(buttonsFrame:GetChildren()) do
            if child:IsA("TextButton") then
                total = total + child.AbsoluteSize.X + 12
            end
        end
        total = math.max(0, total - 12)
        buttonsFrame.Size = UDim2.new(0, total, 1, 0)
        stripScroll.CanvasSize = UDim2.new(0, total, 0, 0)
    end

    local function moveUnderline(button)
        if not button then
            underline.Visible = false
            return
        end
        local offset = 0
        for _, child in ipairs(buttonsFrame:GetChildren()) do
            if child:IsA("TextButton") then
                if child == button then
                    break
                end
                offset = offset + child.AbsoluteSize.X + 12
            end
        end
        underline.Visible = true
        tween(
            underline,
            {
                Position = UDim2.new(0, offset, 0, 19),
                Size = UDim2.new(0, math.max(10, button.AbsoluteSize.X), 0, 2),
            },
            cfg.tween_time
        )
    end

    -- arama
    local searchQuery = ""

    local function folderObjects(folderFrame)
        return folderFrame:FindFirstChild("Objects")
    end

    local function matchesQuery(row, query)
        local text = dget(row, "_searchText")
        if type(text) ~= "string" then
            return false
        end
        return text:find(query, 1, true) ~= nil
    end

    local function applySearchToRow(row, query)
        if dget(row, "_isFolder") then
            local selfMatch = matchesQuery(row, query)
            local objects = folderObjects(row)
            local anyChild = false
            if objects then
                for _, child in ipairs(objects:GetChildren()) do
                    if child:IsA("GuiObject") and dget(child, "_searchText") ~= nil then
                        local childMatch = matchesQuery(child, query)
                        if childMatch then
                            anyChild = true
                        end
                        child.Visible = childMatch
                    end
                end
                if selfMatch then
                    for _, child in ipairs(objects:GetChildren()) do
                        if child:IsA("GuiObject") and dget(child, "_searchText") ~= nil then
                            child.Visible = true
                        end
                    end
                end
            end
            local show = selfMatch or anyChild
            row.Visible = show
            if show and (anyChild or selfMatch) then
                local openFn = dget(row, "_forceOpen")
                if openFn and not dget(row, "_open") then
                    dset(row, "_searchForced", true)
                    openFn()
                end
            end
        else
            row.Visible = matchesQuery(row, query)
        end
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
        if query == "" then
            for _, row in ipairs(scroller:GetChildren()) do
                if row:IsA("GuiObject") and dget(row, "_searchText") ~= nil then
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
                            if closeFn and dget(row, "_open") then
                                closeFn()
                            end
                        end
                    end
                end
            end
        else
            for _, row in ipairs(scroller:GetChildren()) do
                if row:IsA("GuiObject") and dget(row, "_searchText") ~= nil then
                    applySearchToRow(row, query)
                end
            end
        end
    end

    if searchBox then
        on(searchBox:GetPropertyChangedSignal("Text"), function()
            searchQuery = string.lower(searchBox.Text or "")
            applySearch()
        end)
    end

    local windowApi = {}

    function windowApi:AddTab(tabName)
        tabName = tostring(tabName or "New Tab")
        strip.Visible = true

        local button = Instance.new("TextButton")
        button.Name = "Tab_" .. tabName
        button.BackgroundTransparency = 1
        button.Font = FONT
        button.Text = tabName
        button.TextColor3 = COL.text
        button.TextSize = 13
        button.AutoButtonColor = false
        button.Size = UDim2.new(0, textWidth(tabName, 13) + 26, 0, 18)
        button.LayoutOrder = nextOrder(buttonsFrame)
        button.ZIndex = 2
        button.Parent = buttonsFrame
        roundify(button, 4)
        local stroke = uiStroke(button, COL.black, 1.2, 0.7)

        local tabFrame = Instance.new("Frame")
        tabFrame.Name = "Tab_" .. tabName
        tabFrame.Size = UDim2.new(1, 0, 1, 0)
        tabFrame.BackgroundTransparency = 1
        tabFrame.Visible = false
        tabFrame.ZIndex = 1
        tabFrame.Parent = tabsContainer

        local scroller = Instance.new("ScrollingFrame")
        scroller.Name = "TabScroller"
        scroller.Size = UDim2.new(1, 0, 1, 0)
        scroller.BackgroundTransparency = 1
        scroller.BorderSizePixel = 0
        scroller.ScrollBarThickness = 4
        scroller.ScrollBarImageColor3 = COL.red
        scroller.ScrollBarImageTransparency = 0.4
        scroller.CanvasSize = UDim2.new(0, 0, 0, 0)
        scroller.ZIndex = 1
        scroller.Parent = tabFrame
        local scrollerLayout = makeLayout(scroller, Enum.FillDirection.Vertical, 5)

        local function updateCanvas()
            local content = scrollerLayout.AbsoluteContentSize.Y
            scroller.CanvasSize = UDim2.new(0, 0, 0, content + 12)
        end
        updateCanvas()
        on(scrollerLayout:GetPropertyChangedSignal("AbsoluteContentSize"), updateCanvas)

        local tabApi = { _scroller = scroller }
        local tabObj = {
            name = tabName,
            button = button,
            frame = tabFrame,
            scroller = scroller,
            api = tabApi,
        }
        table.insert(tabs, tabObj)

        local function selectTab()
            if activeTab then
                activeTab.button.TextColor3 = COL.text
                local prevStroke = activeTab.button:FindFirstChildOfClass("UIStroke")
                if prevStroke then
                    tween(prevStroke, { Color = COL.black, Transparency = 0.7 }, cfg.tween_time)
                end
                activeTab.frame.Visible = false
            end
            activeTab = tabObj
            for _, other in ipairs(tabs) do
                other.frame.Visible = false
            end
            tabFrame.Visible = true
            button.TextColor3 = COL.white
            tween(stroke, { Color = cfg.main_color, Transparency = 0.15 }, cfg.tween_time)
            moveUnderline(button)
            startParticles(button)
            applySearch()
        end

        tabApi.Show = selectTab

        on(button.MouseButton1Click, function()
            selectTab()
        end)
        on(button.MouseEnter, function()
            if activeTab ~= tabObj then
                button.TextColor3 = Color3.fromRGB(230, 230, 230)
            end
        end)
        on(button.MouseLeave, function()
            if activeTab ~= tabObj then
                button.TextColor3 = COL.text
            end
        end)
        on(button.AncestryChanged, function()
            if not button.Parent and activeTab == tabObj then
                activeTab = nil
                stopParticles()
            end
        end)

        local env = {
            cfg = cfg,
            zbase = zbase,
            windowApi = windowApi,
            scroller = scroller,
            getParent = function()
                return scroller
            end,
            applySearch = applySearch,
            isSearching = function()
                return searchQuery ~= ""
            end,
        }
        tabObj.env = env

        createElementApi(env, tabApi)

        task.defer(updateTabCanvas)
        task.defer(updateCanvas)

        if not activeTab then
            selectTab()
        end

        return tabApi, tabFrame
    end

    api.Minimize = minimize
    api.Maximize = maximize
    api.Close = closeWindow
    api.Show = showWindow
    api.Toggle = function()
        if W.minimized then
            maximize()
        else
            minimize()
        end
    end
    api.SetTitle = function(newTitle)
        titleLabel.Text = tostring(newTitle)
    end
    api.GetFrame = function()
        return frame
    end
    api.Search = function(query)
        if searchBox then
            searchBox.Text = tostring(query or "")
        end
        searchQuery = string.lower(tostring(query or ""))
        applySearch()
    end
    api._frame = frame
    api._W = W
    api._cfg = cfg
    api._applyBounds = applyBounds
    api.AddTab = function(_, name)
        return windowApi:AddTab(name)
    end
    api._closed = false

    table.insert(windows, api)
    return api, frame
end

-- ============================================================
-- Elementler
-- ============================================================
createElementApi = function(env, api)
    local cfg = env.cfg

    local function currentParent()
        return env.getParent()
    end

    local function finish(obj, searchText, parentObj)
        dset(obj, "_searchText", string.lower(tostring(searchText or "")))
        if parentObj then
            local fn = dget(parentObj, "_recompute")
            if fn then
                fn()
            end
        end
        if env.isSearching and env.isSearching() and env.applySearch then
            env.applySearch()
        end
    end

    function api:AddLabel(text)
        text = tostring(text or "New Label")
        local p = currentParent()
        local label = Instance.new("TextLabel")
        label.Name = "Label"
        label.BackgroundTransparency = 1
        label.Font = FONT
        label.Text = text
        label.TextColor3 = COL.white
        label.TextSize = 16
        label.TextXAlignment = Enum.TextXAlignment.Left
        label.Size = UDim2.new(0, textWidth(text, 16) + 15, 0, 20)
        label.LayoutOrder = nextOrder(p)
        label.ZIndex = 2
        label.Parent = p
        finish(label, text, p)
        return label
    end

    function api:AddSection(title)
        title = tostring(title or "Section")
        local p = currentParent()
        local row = Instance.new("Frame")
        row.Name = "Section"
        row.BackgroundTransparency = 1
        row.Size = UDim2.new(1, 0, 0, 26)
        row.LayoutOrder = nextOrder(p)
        row.ZIndex = 2

        local label = Instance.new("TextLabel")
        label.BackgroundTransparency = 1
        label.Position = UDim2.new(0, 0, 0, 5)
        label.Size = UDim2.new(0, textWidth(title, 14) + 8, 0, 16)
        label.Font = FONT
        label.Text = title
        label.TextColor3 = lighten(cfg.main_color, 0.5)
        label.TextSize = 14
        label.TextXAlignment = Enum.TextXAlignment.Left
        label.ZIndex = 2
        label.Parent = row

        local line = Instance.new("Frame")
        line.Position = UDim2.new(0, textWidth(title, 14) + 16, 0.5, 0)
        line.Size = UDim2.new(1, -(textWidth(title, 14) + 16), 0, 1)
        line.BackgroundColor3 = cfg.main_color
        line.BackgroundTransparency = 0.45
        line.BorderSizePixel = 0
        line.ZIndex = 2
        line.Parent = row

        row.Parent = p
        finish(row, title, p)
        return row
    end

    function api:AddDivider()
        local p = currentParent()
        local row = Instance.new("Frame")
        row.Name = "Divider"
        row.BackgroundTransparency = 1
        row.Size = UDim2.new(1, 0, 0, 9)
        row.LayoutOrder = nextOrder(p)
        row.ZIndex = 2

        local line = Instance.new("Frame")
        line.Position = UDim2.new(0, 0, 0.5, 0)
        line.Size = UDim2.new(1, 0, 0, 1)
        line.BackgroundColor3 = cfg.main_color
        line.BackgroundTransparency = 0.5
        line.BorderSizePixel = 0
        line.ZIndex = 2
        line.Parent = row

        row.Parent = p
        finish(row, "", p)
        return row
    end

    function api:AddParagraph(first, second)
        local titleText, body
        if second ~= nil then
            titleText = tostring(first or "")
            body = tostring(second or "")
        else
            titleText = nil
            body = tostring(first or "")
        end
        local p = currentParent()
        local row = Instance.new("Frame")
        row.Name = "Paragraph"
        row.BackgroundTransparency = 1
        row.Size = UDim2.new(1, 0, 0, 0)
        row.AutomaticSize = Enum.AutomaticSize.Y
        row.LayoutOrder = nextOrder(p)
        row.ZIndex = 2

        local offsetY = 0
        if titleText and titleText ~= "" then
            local titleLabel = Instance.new("TextLabel")
            titleLabel.BackgroundTransparency = 1
            titleLabel.Size = UDim2.new(1, 0, 0, 17)
            titleLabel.Font = FONT
            titleLabel.Text = titleText
            titleLabel.TextColor3 = lighten(cfg.main_color, 0.5)
            titleLabel.TextSize = 14
            titleLabel.TextXAlignment = Enum.TextXAlignment.Left
            titleLabel.ZIndex = 2
            titleLabel.Parent = row
            offsetY = 19
        end

        local bodyLabel = Instance.new("TextLabel")
        bodyLabel.BackgroundTransparency = 1
        bodyLabel.Position = UDim2.new(0, 0, 0, offsetY)
        bodyLabel.Size = UDim2.new(1, 0, 0, 0)
        bodyLabel.AutomaticSize = Enum.AutomaticSize.Y
        bodyLabel.Font = FONT
        bodyLabel.Text = body
        bodyLabel.TextColor3 = COL.text
        bodyLabel.TextSize = 14
        bodyLabel.TextWrapped = true
        bodyLabel.TextXAlignment = Enum.TextXAlignment.Left
        bodyLabel.TextYAlignment = Enum.TextYAlignment.Top
        bodyLabel.ZIndex = 2
        bodyLabel.Parent = row

        row.Parent = p
        finish(row, (titleText or "") .. " " .. body, p)
        return row
    end

    function api:AddButton(text, callback)
        text = tostring(text or "Button")
        local p = currentParent()
        local button = Instance.new("TextButton")
        button.Name = "Button"
        button.BackgroundTransparency = 1
        button.Font = FONT
        button.Text = text
        button.TextColor3 = COL.white
        button.TextSize = 14
        button.AutoButtonColor = false
        button.Size = UDim2.new(0, textWidth(text, 14) + 16, 0, 20)
        button.LayoutOrder = nextOrder(p)
        button.ZIndex = 2
        roundify(button, 4)

        local bg = sliceImage("ImageLabel", {
            ImageColor3 = Color3.new(1, 1, 1),
            ImageTransparency = cfg.title_bar_transparency,
            ZIndex = 1,
        })
        bg.Size = UDim2.new(1, 0, 1, 0)
        bg.Parent = button
        applyGradient(bg, cfg.title_bar, 0)

        button.Parent = p
        on(button.MouseButton1Click, function()
            rippleAt(button)
            call(callback)
        end)
        on(button.MouseEnter, function()
            tween(bg, { ImageTransparency = math.max(0, cfg.title_bar_transparency - 0.15) }, 0.1)
        end)
        on(button.MouseLeave, function()
            tween(bg, { ImageTransparency = cfg.title_bar_transparency }, 0.1)
        end)
        finish(button, text, p)
        return button
    end

    function api:AddSwitch(text, callback)
        text = tostring(text or "Switch")
        local p = currentParent()
        local row = Instance.new("TextButton")
        row.Name = "Switch"
        row.BackgroundTransparency = 1
        row.Text = ""
        row.AutoButtonColor = false
        row.Size = UDim2.new(1, 0, 0, 20)
        row.LayoutOrder = nextOrder(p)
        row.ZIndex = 2
        roundify(row, 4)

        local box = sliceImage("ImageLabel", {
            ImageTransparency = math.min(0.95, cfg.title_bar_transparency + 0.45),
            ZIndex = 1,
        })
        box.Size = UDim2.new(0, 20, 0, 20)
        box.Parent = row
        applyGradient(box, cfg.title_bar, 0)

        local check = Instance.new("TextLabel")
        check.Name = "Check"
        check.BackgroundTransparency = 1
        check.Size = UDim2.new(1, 0, 1, 0)
        check.Font = Enum.Font.SourceSans
        check.Text = "✓"
        check.TextColor3 = COL.white
        check.TextSize = 16
        check.ZIndex = 2
        check.Visible = false
        check.Parent = box

        local title = Instance.new("TextLabel")
        title.Name = "Title"
        title.Position = UDim2.new(0, 28, 0, 0)
        title.Size = UDim2.new(1, -28, 1, 0)
        title.BackgroundTransparency = 1
        title.Font = FONT
        title.Text = text
        title.TextColor3 = COL.text
        title.TextSize = 14
        title.TextXAlignment = Enum.TextXAlignment.Left
        title.ZIndex = 2
        title.Parent = row

        local state = false
        local function render()
            check.Visible = state
            local target = cfg.title_bar_transparency
            if not state then
                target = math.min(0.95, cfg.title_bar_transparency + 0.45)
            end
            tween(box, { ImageTransparency = target }, cfg.tween_time)
        end

        row.Parent = p
        on(row.MouseButton1Click, function()
            rippleAt(row)
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
        finish(row, text, p)
        return handle, row
    end

    function api:AddTextBox(name, callback, opts)
        name = tostring(name or "TextBox")
        opts = typeof(opts) == "table" and opts or {}
        local p = currentParent()

        local holder
        local box
        if opts.placeholder then
            holder = Instance.new("Frame")
            holder.Name = "TextBoxRow"
            holder.BackgroundTransparency = 1
            holder.Size = UDim2.new(1, 0, 0, 42)
            holder.LayoutOrder = nextOrder(p)
            holder.ZIndex = 2

            local titleLabel = Instance.new("TextLabel")
            titleLabel.BackgroundTransparency = 1
            titleLabel.Size = UDim2.new(1, 0, 0, 18)
            titleLabel.Font = FONT
            titleLabel.Text = name
            titleLabel.TextColor3 = COL.text
            titleLabel.TextSize = 13
            titleLabel.TextXAlignment = Enum.TextXAlignment.Left
            titleLabel.ZIndex = 2
            titleLabel.Parent = holder

            box = Instance.new("TextBox")
            box.Position = UDim2.new(0, 0, 0, 20)
            box.Size = UDim2.new(1, 0, 0, 22)
            box.ZIndex = 2
            box.Parent = holder
            holder.Parent = p
        else
            box = Instance.new("TextBox")
            box.Size = UDim2.new(1, 0, 0, 22)
            box.LayoutOrder = nextOrder(p)
            box.ZIndex = 2
            box.Parent = p
        end

        box.Name = "TextBox"
        box.BackgroundTransparency = 1
        box.Font = FONT
        if opts.default ~= nil then
            box.Text = tostring(opts.default)
        else
            box.Text = ""
        end
        box.PlaceholderText = opts.placeholder or name
        box.PlaceholderColor3 = Color3.fromRGB(178, 178, 178)
        box.TextColor3 = COL.white
        box.TextSize = 14
        box.ClearTextOnFocus = false
        roundify(box, 4)

        local bg = sliceImage("ImageLabel", {
            ImageColor3 = COL.elementBg,
            ZIndex = 1,
        })
        bg.Size = UDim2.new(1, 0, 1, 0)
        bg.Parent = box

        on(box.FocusLost, function(enterPressed)
            if enterPressed and #box.Text > 0 then
                call(callback, box.Text)
                if opts.clear then
                    box.Text = ""
                end
            end
        end)

        finish(holder or box, opts.placeholder or name, p)
        return box
    end

    function api:AddSlider(name, callback, opts)
        name = tostring(name or "Slider")
        opts = typeof(opts) == "table" and opts or {}
        local p = currentParent()

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

        local row = Instance.new("Frame")
        row.Name = "Slider"
        row.BackgroundTransparency = 1
        row.Size = UDim2.new(1, 0, 0, 36)
        row.LayoutOrder = nextOrder(p)
        row.ZIndex = 2

        local titleLabel = Instance.new("TextLabel")
        titleLabel.BackgroundTransparency = 1
        titleLabel.Size = UDim2.new(1, -50, 0, 16)
        titleLabel.Font = FONT
        titleLabel.Text = name
        titleLabel.TextColor3 = COL.text
        titleLabel.TextSize = 13
        titleLabel.TextXAlignment = Enum.TextXAlignment.Left
        titleLabel.ZIndex = 2
        titleLabel.Parent = row

        local valueLabel = Instance.new("TextLabel")
        valueLabel.AnchorPoint = Vector2.new(1, 0)
        valueLabel.Position = UDim2.new(1, 0, 0, 0)
        valueLabel.Size = UDim2.new(0, 50, 0, 16)
        valueLabel.BackgroundTransparency = 1
        valueLabel.Font = FONT
        valueLabel.Text = ""
        valueLabel.TextColor3 = lighten(cfg.main_color, 0.5)
        valueLabel.TextSize = 13
        valueLabel.TextXAlignment = Enum.TextXAlignment.Right
        valueLabel.ZIndex = 2
        valueLabel.Parent = row

        local track = Instance.new("Frame")
        track.Name = "Track"
        track.Position = UDim2.new(0, 0, 0, 22)
        track.Size = UDim2.new(1, 0, 0, 8)
        track.ZIndex = 2
        track.Active = not readonly
        track.Parent = row
        roundify(track, 4)

        local trackBg = sliceImage("ImageLabel", {
            ImageColor3 = COL.sliderBg,
            ZIndex = 1,
        })
        trackBg.Size = UDim2.new(1, 0, 1, 0)
        trackBg.Parent = track
        roundify(trackBg, 4)

        local fill = Instance.new("Frame")
        fill.Name = "Fill"
        fill.Size = UDim2.new(0, 0, 1, 0)
        fill.BackgroundColor3 = cfg.main_color
        fill.BorderSizePixel = 0
        fill.ZIndex = 2
        fill.Parent = track
        roundify(fill, 4)

        local knob = Instance.new("Frame")
        knob.Name = "Knob"
        knob.AnchorPoint = Vector2.new(0.5, 0.5)
        knob.Position = UDim2.new(0, 0, 0.5, 0)
        knob.Size = UDim2.new(0, 12, 0, 12)
        knob.BackgroundColor3 = COL.white
        knob.BorderSizePixel = 0
        knob.ZIndex = 3
        knob.Parent = track
        roundify(knob, 6)
        uiStroke(knob, cfg.main_color, 1, 0.4)

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
            local target = {
                Size = UDim2.new(alpha, 0, 1, 0),
            }
            if anim then
                tween(fill, target, 0.1)
                tween(knob, { Position = UDim2.new(alpha, 0, 0.5, 0) }, 0.1)
            else
                fill.Size = target.Size
                knob.Position = UDim2.new(alpha, 0, 0.5, 0)
            end
            valueLabel.Text = display(value)
        end

        local function setFromMouse(anim)
            local m = mousePos()
            local abs = track.AbsolutePosition
            local size = track.AbsoluteSize
            if size.X <= 0 then
                return
            end
            local alpha = math.clamp((m.X - abs.X) / size.X, 0, 1)
            local raw = minV + alpha * (maxV - minV)
            local nextValue = roundStep(raw)
            if nextValue ~= value then
                value = nextValue
                call(callback, value)
            end
            render(anim)
        end

        row.Parent = p

        if not readonly then
            on(track.InputBegan, function(input)
                if isPrimaryInput(input) then
                    dragging = true
                    setFromMouse(true)
                end
            end)
            on(UIS.InputChanged, function(input)
                if not dragging then
                    return
                end
                if input.UserInputType ~= Enum.UserInputType.MouseMovement
                    and input.UserInputType ~= Enum.UserInputType.Touch then
                    return
                end
                setFromMouse(false)
            end)
            on(UIS.InputEnded, function(input)
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

    function api:AddKeybind(name, callback, opts)
        name = tostring(name or "Keybind")
        opts = typeof(opts) == "table" and opts or {}
        local p = currentParent()

        local row = Instance.new("Frame")
        row.Name = "Keybind"
        row.BackgroundTransparency = 1
        row.Size = UDim2.new(1, 0, 0, 22)
        row.LayoutOrder = nextOrder(p)
        row.ZIndex = 2

        local titleLabel = Instance.new("TextLabel")
        titleLabel.BackgroundTransparency = 1
        titleLabel.Size = UDim2.new(1, -80, 1, 0)
        titleLabel.Font = FONT
        titleLabel.Text = name
        titleLabel.TextColor3 = COL.text
        titleLabel.TextSize = 13
        titleLabel.TextXAlignment = Enum.TextXAlignment.Left
        titleLabel.ZIndex = 2
        titleLabel.Parent = row

        local chip = Instance.new("TextButton")
        chip.Name = "Input"
        chip.AnchorPoint = Vector2.new(1, 0.5)
        chip.Position = UDim2.new(1, 0, 0.5, 0)
        chip.Size = UDim2.new(0, 74, 0, 18)
        chip.BackgroundColor3 = COL.chipBg
        chip.BackgroundTransparency = 0.15
        chip.Font = FONT
        chip.Text = ""
        chip.TextColor3 = COL.white
        chip.TextSize = 12
        chip.AutoButtonColor = false
        chip.ZIndex = 2
        chip.Parent = row
        roundify(chip, 4)

        local keyLabel = Instance.new("TextLabel")
        keyLabel.Name = "KeyName"
        keyLabel.BackgroundTransparency = 1
        keyLabel.Size = UDim2.new(1, -8, 1, 0)
        keyLabel.Font = FONT
        keyLabel.Text = "..."
        keyLabel.TextColor3 = COL.text
        keyLabel.TextSize = 12
        keyLabel.ZIndex = 3
        keyLabel.Parent = chip

        local currentKey = opts.default
        local waiting = false

        local function keyName(key)
            if not key then
                return "None"
            end
            return tostring(key):gsub("KeyCode%.", "")
        end

        local function renderKey()
            keyLabel.Text = keyName(currentKey)
            if waiting then
                chip.BackgroundColor3 = cfg.main_color
                keyLabel.Text = "..."
            else
                chip.BackgroundColor3 = COL.chipBg
            end
        end

        local conn
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
            conn = on(UIS.InputBegan, function(input, gpe)
                if gpe then
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

        row.Parent = p
        on(chip.MouseButton1Click, function()
            rippleAt(chip)
            if waiting then
                -- tekrar tiklama: baglamayi iptal et
                stopListening()
            else
                startListening()
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

    function api:AddDropdown(name, callback, opts)
        if type(callback) == "table" and opts == nil then
            opts = callback
            callback = nil
        end
        name = tostring(name or "Dropdown")
        opts = typeof(opts) == "table" and opts or {}
        local p = currentParent()

        local items = {}
        if type(opts.options) == "table" then
            for _, v in ipairs(opts.options) do
                table.insert(items, tostring(v))
            end
        end

        local row = Instance.new("Frame")
        row.Name = "Dropdown"
        row.BackgroundTransparency = 1
        row.Size = UDim2.new(1, 0, 0, 0)
        row.AutomaticSize = Enum.AutomaticSize.Y
        row.LayoutOrder = nextOrder(p)
        row.ZIndex = 2

        local titleLabel = Instance.new("TextLabel")
        titleLabel.BackgroundTransparency = 1
        titleLabel.Size = UDim2.new(1, 0, 0, 16)
        titleLabel.Font = FONT
        titleLabel.Text = name
        titleLabel.TextColor3 = COL.text
        titleLabel.TextSize = 13
        titleLabel.TextXAlignment = Enum.TextXAlignment.Left
        titleLabel.ZIndex = 2
        titleLabel.Parent = row

        local box = Instance.new("TextButton")
        box.Name = "Box"
        box.Position = UDim2.new(0, 0, 0, 18)
        box.Size = UDim2.new(1, 0, 0, 22)
        box.BackgroundColor3 = COL.elementBg
        box.BackgroundTransparency = 0.05
        box.Font = FONT
        box.Text = ""
        box.TextColor3 = COL.white
        box.TextSize = 13
        box.AutoButtonColor = false
        box.ZIndex = 3
        box.ClipsDescendants = true
        box.Parent = row
        roundify(box, 4)

        local selectedLabel = Instance.new("TextLabel")
        selectedLabel.Name = "Selected"
        selectedLabel.BackgroundTransparency = 1
        selectedLabel.Position = UDim2.new(0, 8, 0, 0)
        selectedLabel.Size = UDim2.new(1, -30, 1, 0)
        selectedLabel.Font = FONT
        selectedLabel.Text = "Select..."
        selectedLabel.TextColor3 = COL.text
        selectedLabel.TextSize = 13
        selectedLabel.TextXAlignment = Enum.TextXAlignment.Left
        selectedLabel.ZIndex = 4
        selectedLabel.Parent = box

        local arrow = Instance.new("ImageLabel")
        arrow.Name = "Arrow"
        arrow.AnchorPoint = Vector2.new(1, 0.5)
        arrow.Position = UDim2.new(1, -8, 0.5, 0)
        arrow.Size = UDim2.new(0, 12, 0, 12)
        arrow.BackgroundTransparency = 1
        arrow.Image = ASSET.arrow
        arrow.ImageColor3 = COL.text
        arrow.ZIndex = 4
        arrow.Parent = box

        local listFrame = Instance.new("ScrollingFrame")
        listFrame.Name = "List"
        listFrame.Position = UDim2.new(0, 0, 0, 42)
        listFrame.Size = UDim2.new(1, 0, 0, 0)
        listFrame.BackgroundColor3 = COL.dropdownBox
        listFrame.BackgroundTransparency = 0.05
        listFrame.BorderSizePixel = 0
        listFrame.ScrollBarThickness = 3
        listFrame.ScrollBarImageColor3 = COL.red
        listFrame.ScrollBarImageTransparency = 0.4
        listFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
        listFrame.Visible = false
        listFrame.ZIndex = 6
        listFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
        listFrame.Parent = row
        roundify(listFrame, 4)

        local listLayout = makeLayout(listFrame, Enum.FillDirection.Vertical, 2)
        local pad = Instance.new("UIPadding")
        pad.PaddingTop = UDim.new(0, 3)
        pad.PaddingBottom = UDim.new(0, 3)
        pad.PaddingLeft = UDim.new(0, 3)
        pad.PaddingRight = UDim.new(0, 3)
        pad.Parent = listFrame

        local selected = nil
        local open = false
        local optionButtons = {}

        local function closeList()
            if not open then
                return
            end
            open = false
            listFrame.Visible = false
            listFrame.Size = UDim2.new(1, 0, 0, 0)
            row.Size = UDim2.new(1, 0, 0, 42)
            tween(arrow, { Rotation = 0 }, 0.15)
        end

        local function openList()
            if open then
                closeList()
                return
            end
            open = true
            -- kisa pencerede yukari ac
            local roomBelow = 0
            local absRow = row.AbsolutePosition
            local vp2 = viewportSize()
            roomBelow = vp2.Y - (absRow.Y + 42)
            local desired = math.min(120, math.max(46, #items * 22 + 8))
            listFrame.Visible = true
            if roomBelow < desired + 10 then
                local up = math.min(desired, math.max(46, absRow.Y - 50))
                listFrame.Position = UDim2.new(0, 0, 0, -up - 20)
                listFrame.Size = UDim2.new(1, 0, 0, up)
            else
                listFrame.Position = UDim2.new(0, 0, 0, 42)
                listFrame.Size = UDim2.new(1, 0, 0, desired)
            end
            tween(arrow, { Rotation = 180 }, 0.15)
        end

        local function selectValue(value, fire)
            selected = value
            selectedLabel.Text = value ~= nil and tostring(value) or "Select..."
            if fire then
                call(callback, value)
            end
            closeList()
        end

        local function rebuild()
            for _, b in ipairs(optionButtons) do
                b:Destroy()
            end
            optionButtons = {}
            for _, item in ipairs(items) do
                local opt = Instance.new("TextButton")
                opt.Name = "Option"
                opt.BackgroundTransparency = 1
                opt.Font = FONT
                opt.Text = item
                opt.TextColor3 = COL.text
                opt.TextSize = 13
                opt.TextXAlignment = Enum.TextXAlignment.Left
                opt.AutoButtonColor = false
                opt.Size = UDim2.new(1, -6, 0, 20)
                opt.LayoutOrder = nextOrder(listFrame)
                opt.ZIndex = 7
                opt.Parent = listFrame
                roundify(opt, 3)
                on(opt.MouseButton1Click, function()
                    rippleAt(opt)
                    selectValue(item, true)
                end)
                on(opt.MouseEnter, function()
                    tween(opt, { BackgroundTransparency = 0.8 }, 0.1)
                    opt.BackgroundColor3 = cfg.main_color
                end)
                on(opt.MouseLeave, function()
                    tween(opt, { BackgroundTransparency = 1 }, 0.1)
                end)
                table.insert(optionButtons, opt)
            end
        end

        row.Parent = p
        on(box.MouseButton1Click, function()
            rippleAt(box)
            openList()
        end)

        rebuild()

        local handle = {}
        function handle:Add(value)
            table.insert(items, tostring(value))
            rebuild()
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
            end
            rebuild()
        end
        function handle:Clear()
            items = {}
            selected = nil
            selectedLabel.Text = "Select..."
            rebuild()
            closeList()
        end
        finish(row, name, p)
        return handle, row
    end

    function api:AddColorPicker(name, callback, opts)
        if type(callback) == "table" and opts == nil then
            opts = callback
            callback = nil
        end
        name = tostring(name or "Color")
        opts = typeof(opts) == "table" and opts or {}
        local p = currentParent()

        local current = opts.default or Color3.new(1, 1, 1)
        if typeof(current) ~= "Color3" then
            current = Color3.new(1, 1, 1)
        end

        local row = Instance.new("Frame")
        row.Name = "ColorPicker"
        row.BackgroundTransparency = 1
        row.Size = UDim2.new(1, 0, 0, 24)
        row.LayoutOrder = nextOrder(p)
        row.ZIndex = 2

        local titleLabel = Instance.new("TextLabel")
        titleLabel.BackgroundTransparency = 1
        titleLabel.Size = UDim2.new(1, -34, 1, 0)
        titleLabel.Font = FONT
        titleLabel.Text = name
        titleLabel.TextColor3 = COL.text
        titleLabel.TextSize = 13
        titleLabel.TextXAlignment = Enum.TextXAlignment.Left
        titleLabel.ZIndex = 2
        titleLabel.Parent = row

        local swatch = Instance.new("TextButton")
        swatch.Name = "Swatch"
        swatch.AnchorPoint = Vector2.new(1, 0.5)
        swatch.Position = UDim2.new(1, 0, 0.5, 0)
        swatch.Size = UDim2.new(0, 26, 0, 18)
        swatch.BackgroundColor3 = current
        swatch.Text = ""
        swatch.AutoButtonColor = false
        swatch.ZIndex = 3
        swatch.Parent = row
        roundify(swatch, 4)
        uiStroke(swatch, COL.black, 1, 0.5)

        -- popup
        local popup = Instance.new("Frame")
        popup.Name = "Popup"
        popup.AnchorPoint = Vector2.new(1, 0)
        popup.Position = UDim2.new(1, 0, 1, 6)
        popup.Size = UDim2.new(0, 168, 0, 0)
        popup.BackgroundColor3 = Color3.fromRGB(28, 29, 33)
        popup.BackgroundTransparency = 0.05
        popup.Visible = false
        popup.ZIndex = 20
        popup.ClipsDescendants = true
        popup.Parent = row
        roundify(popup, 6)
        uiStroke(popup, cfg.main_color, 1, 0.5)

        local satBox = Instance.new("ImageLabel")
        satBox.Name = "Saturation"
        satBox.Position = UDim2.new(0, 8, 0, 8)
        satBox.Size = UDim2.new(1, -16, 0, 90)
        satBox.Image = ASSET.saturation
        satBox.ScaleType = Enum.ScaleType.Stretch
        satBox.ZIndex = 21
        satBox.Active = true
        satBox.Parent = popup

        local hueBar = Instance.new("ImageLabel")
        hueBar.Name = "Hue"
        hueBar.Position = UDim2.new(0, 8, 0, 104)
        hueBar.Size = UDim2.new(1, -16, 0, 12)
        hueBar.Image = ASSET.palette
        hueBar.ScaleType = Enum.ScaleType.Stretch
        hueBar.ZIndex = 21
        hueBar.Active = true
        hueBar.Parent = popup
        roundify(hueBar, 3)

        local hexBox = Instance.new("TextBox")
        hexBox.Name = "Hex"
        hexBox.Position = UDim2.new(0, 8, 0, 122)
        hexBox.Size = UDim2.new(1, -16, 0, 20)
        hexBox.BackgroundColor3 = COL.inputBg
        hexBox.BackgroundTransparency = 0.1
        hexBox.Font = FONT
        hexBox.Text = colorToHex(current)
        hexBox.TextColor3 = COL.white
        hexBox.TextSize = 12
        hexBox.ClearTextOnFocus = false
        hexBox.ZIndex = 21
        hexBox.Parent = popup
        roundify(hexBox, 4)

        local satDot = Instance.new("Frame")
        satDot.AnchorPoint = Vector2.new(0.5, 0.5)
        satDot.Size = UDim2.new(0, 8, 0, 8)
        satDot.BackgroundColor3 = Color3.new(1, 1, 1)
        satDot.BorderSizePixel = 0
        satDot.ZIndex = 22
        satDot.Visible = false
        satDot.Parent = satBox
        roundify(satDot, 4)
        uiStroke(satDot, COL.black, 1, 0.3)

        local hueDot = Instance.new("Frame")
        hueDot.AnchorPoint = Vector2.new(0.5, 0.5)
        hueDot.Position = UDim2.new(0, 0, 0.5, 0)
        hueDot.Size = UDim2.new(0, 6, 0, 16)
        hueDot.BackgroundColor3 = Color3.new(1, 1, 1)
        hueDot.BorderSizePixel = 0
        hueDot.ZIndex = 22
        hueDot.Visible = false
        hueDot.Parent = hueBar
        roundify(hueDot, 3)
        uiStroke(hueDot, COL.black, 1, 0.3)

        local h, s, v = 0, 1, 1
        local popupOpen = false

        local function applyColor(fire)
            current = Color3.fromHSV(h, s, v)
            swatch.BackgroundColor3 = current
            hexBox.Text = colorToHex(current)
            if fire then
                call(callback, current)
            end
        end

        local function renderDots()
            satDot.Position = UDim2.new(s, 0, 1 - v, 0)
            hueDot.Position = UDim2.new(h, 0, 0.5, 0)
        end

        local function closePopup()
            popupOpen = false
            popup.Visible = false
            popup.Size = UDim2.new(0, 168, 0, 0)
            satDot.Visible = false
            hueDot.Visible = false
        end

        local function openPopup()
            if popupOpen then
                closePopup()
                return
            end
            popupOpen = true
            h, s, v = current:ToHSV()
            renderDots()
            satDot.Visible = true
            hueDot.Visible = true
            popup.Visible = true
            popup.Size = UDim2.new(0, 168, 0, 150)
        end

        local satDragging = false
        local hueDragging = false

        local function satFromMouse()
            local m = mousePos()
            local ap = satBox.AbsolutePosition
            local asz = satBox.AbsoluteSize
            if asz.X <= 0 or asz.Y <= 0 then
                return
            end
            s = math.clamp((m.X - ap.X) / asz.X, 0, 1)
            v = 1 - math.clamp((m.Y - ap.Y) / asz.Y, 0, 1)
            renderDots()
            applyColor(true)
        end

        local function hueFromMouse()
            local m = mousePos()
            local ap = hueBar.AbsolutePosition
            local asz = hueBar.AbsoluteSize
            if asz.X <= 0 then
                return
            end
            h = math.clamp((m.X - ap.X) / asz.X, 0, 1)
            renderDots()
            applyColor(true)
        end

        row.Parent = p
        on(swatch.MouseButton1Click, function()
            rippleAt(swatch)
            openPopup()
        end)
        on(satBox.InputBegan, function(input)
            if isPrimaryInput(input) then
                satDragging = true
                satFromMouse()
            end
        end)
        on(hueBar.InputBegan, function(input)
            if isPrimaryInput(input) then
                hueDragging = true
                hueFromMouse()
            end
        end)
        on(UIS.InputChanged, function(input)
            if input.UserInputType ~= Enum.UserInputType.MouseMovement
                and input.UserInputType ~= Enum.UserInputType.Touch then
                return
            end
            if satDragging then
                satFromMouse()
            elseif hueDragging then
                hueFromMouse()
            end
        end)
        on(UIS.InputEnded, function(input)
            if isPrimaryInput(input) then
                satDragging = false
                hueDragging = false
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

    function api:AddHorizontalAlignment()
        local p = currentParent()
        local row = Instance.new("Frame")
        row.Name = "Horizontal"
        row.BackgroundTransparency = 1
        row.Size = UDim2.new(1, 0, 0, 0)
        row.AutomaticSize = Enum.AutomaticSize.Y
        row.LayoutOrder = nextOrder(p)
        row.ZIndex = 2
        makeLayout(row, Enum.FillDirection.Horizontal, 6)
        row.Parent = p

        local subEnv = {}
        for key, value in pairs(env) do
            subEnv[key] = value
        end
        subEnv.getParent = function()
            return row
        end
        local sub = {}
        createElementApi(subEnv, sub)
        finish(row, "", p)
        return sub, row
    end

    function api:AddFolder(name)
        name = tostring(name or "Folder")
        local p = currentParent()

        -- orijinal Syniox yapisi: dis "Folder" cercevesi, ic "Button"
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
        button.BackgroundTransparency = 1
        button.Text = "      " .. name
        button.Font = FONT
        button.TextColor3 = COL.text
        button.TextSize = 14
        button.TextXAlignment = Enum.TextXAlignment.Left
        button.AutoButtonColor = false
        button.Size = UDim2.new(1, 0, 0, 22)
        button.ZIndex = 3
        button.Parent = row
        roundify(button, 4)

        local arrow = Instance.new("ImageLabel")
        arrow.Name = "Toggle"
        arrow.Position = UDim2.new(0, 4, 0.5, 0)
        arrow.AnchorPoint = Vector2.new(0, 0.5)
        arrow.Size = UDim2.new(0, 12, 0, 12)
        arrow.BackgroundTransparency = 1
        arrow.Image = ASSET.folderArrow
        arrow.ImageColor3 = cfg.main_color
        arrow.ZIndex = 4
        arrow.Parent = button

        local objects = Instance.new("Frame")
        objects.Name = "Objects"
        objects.BackgroundTransparency = 1
        objects.Size = UDim2.new(1, -14, 0, 0)
        objects.Position = UDim2.new(0, 14, 0, 24)
        objects.Visible = false
        objects.ZIndex = 2
        objects.Parent = row
        local objectsLayout = makeLayout(objects, Enum.FillDirection.Vertical, 5)

        local function recompute()
            local content = objectsLayout.AbsoluteContentSize.Y
            if objects.Visible then
                row.Size = UDim2.new(1, 0, 0, 24 + content + 6)
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
            rippleAt(button)
            if dget(row, "_open") then
                closeFolder()
            else
                openFolder()
            end
        end)

        -- orijinal gibi: tab metodlari klasorun icindekilere proxy'lenir
        local folderApi = {}
        local subEnv = {}
        for key, value in pairs(env) do
            subEnv[key] = value
        end
        subEnv.getParent = function()
            return objects
        end
        createElementApi(subEnv, folderApi)

        local handle = {}
        for key, value in pairs(folderApi) do
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
end

-- ============================================================
-- Pencere duzeni / kutuphane
-- ============================================================
function library:FormatWindows(padding)
    padding = tonumber(padding) or 16
    local vp = viewportSize()
    local visible = {}
    for _, api in ipairs(windows) do
        if not api._closed then
            table.insert(visible, api)
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
    stopAllParticles()
    clearNotifications()
    pcall(function()
        gui:Destroy()
    end)
end

-- global toggle tusu
on(UIS.InputBegan, function(input, gameProcessed)
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
