--[[
    Syniox UI v2
    Modern Roblox UI library - API compatible with the original Syniox GUI.

    Ozellikler:
      - Modern koyu tema, gradient baslik ve animasyonlu sekmeler
      - Alttan ve sag alttan boyutlandirma (Wind UI tarzi resize cizgisi)
      - Minimize / maximize / kapat, surukleme ve cift tikla buyutme
      - Bildirimler, geri yukleme dock'u, ripple ve yumusak gecisler
      - Label, Button, Switch, TextBox, Slider, Keybind, Dropdown,
        ColorPicker, HorizontalAlignment ve Folder destegi

    Quick start (URL):
        local Syniox = loadstring(game:HttpGet("..."))()
        local Window = Syniox:AddWindow("Syniox", { author = "you" })
        local Tab = Window:AddTab("Main")
        Tab:AddButton("Click me", function() print("hi") end)

    If you paste this file directly into an executor tab, wrap it once:
        local Syniox = (function()
            -- paste the entire file here (keep `return library`)
        end)()

        local Window = Syniox:AddWindow("Syniox", { author = "you" })

    Do NOT paste the library twice: `return library` must stay the last
    statement of the wrapped function, otherwise Luau raises
    "Expected <eof>, got 'local'".

    Toggle key: RightShift (edit CONFIG.toggle_key below)
]]

local CONFIG = {
    main_color = Color3.fromRGB(99, 132, 255),
    accent2 = Color3.fromRGB(168, 110, 255),
    min_size = Vector2.new(420, 300),
    default_size = Vector2.new(520, 380),
    toggle_key = Enum.KeyCode.RightShift,
    can_resize = true,
    font = Enum.Font.GothamMedium,
    font_bold = Enum.Font.GothamBold,
    font_code = Enum.Font.Code,
}

local COLORS = {
    bg = Color3.fromRGB(15, 17, 24),
    bg2 = Color3.fromRGB(17, 20, 28),
    surface = Color3.fromRGB(21, 24, 33),
    surface2 = Color3.fromRGB(27, 31, 42),
    surface3 = Color3.fromRGB(34, 39, 52),
    text = Color3.fromRGB(237, 240, 247),
    textDim = Color3.fromRGB(154, 162, 180),
    textMuted = Color3.fromRGB(110, 118, 136),
    danger = Color3.fromRGB(255, 95, 122),
    success = Color3.fromRGB(61, 214, 140),
    warning = Color3.fromRGB(255, 196, 87),
    white = Color3.new(1, 1, 1),
    black = Color3.new(0, 0, 0),
}

local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Players = game:GetService("Players")
local TextService = game:GetService("TextService")
local LocalPlayer = Players.LocalPlayer

local function new(className, properties, parent)
    local object = Instance.new(className)
    for key, value in pairs(properties or {}) do
        object[key] = value
    end
    if parent then
        object.Parent = parent
    end
    return object
end

local function tween(object, duration, properties, style, direction)
    if not object or not object.Parent then
        return nil
    end
    local info = TweenInfo.new(
        duration or 0.15,
        style or Enum.EasingStyle.Quad,
        direction or Enum.EasingDirection.Out
    )
    local animation = TweenService:Create(object, info, properties)
    animation:Play()
    return animation
end

local function corner(parent, radius)
    return new("UICorner", { CornerRadius = UDim.new(0, radius or 8) }, parent)
end

local function stroke(parent, color, transparency, thickness)
    return new("UIStroke", {
        Color = color or COLORS.white,
        Transparency = transparency or 0.9,
        Thickness = thickness or 1,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
    }, parent)
end

local function padding(parent, left, right, top, bottom)
    return new("UIPadding", {
        PaddingLeft = UDim.new(0, left or 0),
        PaddingRight = UDim.new(0, right or 0),
        PaddingTop = UDim.new(0, top or 0),
        PaddingBottom = UDim.new(0, bottom or 0),
    }, parent)
end

local function mix(first, second, alpha)
    return Color3.new(
        first.R + (second.R - first.R) * alpha,
        first.G + (second.G - first.G) * alpha,
        first.B + (second.B - first.B) * alpha
    )
end

local function applyPaint(object, paint, rotation)
    local old = object:FindFirstChild("SynioxGradient")
    if old then
        old:Destroy()
    end

    if typeof(paint) == "Color3" then
        object.BackgroundColor3 = paint
        object.BackgroundTransparency = 0
        return nil
    end

    if typeof(paint) ~= "table" or #paint == 0 then
        return nil
    end

    if #paint == 1 then
        object.BackgroundColor3 = paint[1]
        object.BackgroundTransparency = 0
        return nil
    end

    local keypoints
    if #paint == 2 then
        keypoints = {
            ColorSequenceKeypoint.new(0, paint[1]),
            ColorSequenceKeypoint.new(1, paint[2]),
        }
    else
        keypoints = {
            ColorSequenceKeypoint.new(0, paint[1]),
            ColorSequenceKeypoint.new(0.5, paint[2]),
            ColorSequenceKeypoint.new(1, paint[3]),
        }
    end

    object.BackgroundColor3 = COLORS.white
    return new("UIGradient", {
        Name = "SynioxGradient",
        Rotation = rotation or 0,
        Color = ColorSequence.new(keypoints),
    }, object)
end

local function textWidth(text, size, font)
    local ok, bounds = pcall(function()
        return TextService:GetTextSize(text, size, font, Vector2.new(10000, 100))
    end)
    if ok and bounds then
        return bounds.X
    end
    return #tostring(text) * size * 0.55
end

local function parseHexColor(value)
    value = tostring(value or ""):gsub("%s+", ""):gsub("#", "")
    if #value == 3 then
        value = value:sub(1, 1):rep(2)
            .. value:sub(2, 2):rep(2)
            .. value:sub(3, 3):rep(2)
    end
    if #value ~= 6 then
        return nil
    end
    local red = tonumber(value:sub(1, 2), 16)
    local green = tonumber(value:sub(3, 4), 16)
    local blue = tonumber(value:sub(5, 6), 16)
    if not red or not green or not blue then
        return nil
    end
    return Color3.fromRGB(red, green, blue)
end

local function toVector2(value)
    if typeof(value) == "Vector2" then
        return value
    end
    if typeof(value) == "UDim2" then
        return Vector2.new(value.X.Offset, value.Y.Offset)
    end
    if type(value) == "table" and tonumber(value.X) and tonumber(value.Y) then
        return Vector2.new(tonumber(value.X), tonumber(value.Y))
    end
    return nil
end

local function getViewport()
    local camera = workspace.CurrentCamera
    if camera then
        return camera.ViewportSize
    end
    return Vector2.new(1280, 720)
end

local function isInside(object, position)
    if not object or not object.Parent then
        return false
    end
    local absolutePosition = object.AbsolutePosition
    local absoluteSize = object.AbsoluteSize
    return position.X >= absolutePosition.X
        and position.X <= absolutePosition.X + absoluteSize.X
        and position.Y >= absolutePosition.Y
        and position.Y <= absolutePosition.Y + absoluteSize.Y
end

local function getGuiParent()
    local parent
    if gethui then
        local ok, hidden = pcall(gethui)
        if ok and hidden then
            parent = hidden
        end
    end
    if not parent then
        local ok, core = pcall(function()
            return game:GetService("CoreGui")
        end)
        if ok and core then
            parent = core
        end
    end
    if not parent then
        parent = LocalPlayer:WaitForChild("PlayerGui")
    end
    return parent
end

local guiParent = getGuiParent()
pcall(function()
    local old = guiParent:FindFirstChild("imgui")
    if old then
        old:Destroy()
    end
end)
pcall(function()
    local core = game:GetService("CoreGui")
    local old = core:FindFirstChild("imgui")
    if old then
        old:Destroy()
    end
end)

local screenGui = new("ScreenGui", {
    Name = "imgui",
    ResetOnSpawn = false,
    IgnoreGuiInset = true,
    ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
    DisplayOrder = 999999,
})
local parentOk = pcall(function()
    screenGui.Parent = guiParent
end)
if not parentOk or not screenGui.Parent then
    screenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")
end

local windowsContainer = new("Frame", {
    Name = "Windows",
    Size = UDim2.new(1, 0, 1, 0),
    BackgroundTransparency = 1,
    ZIndex = 1,
}, screenGui)

local notificationContainer = new("Frame", {
    Name = "Notifications",
    AnchorPoint = Vector2.new(1, 0),
    Position = UDim2.new(1, -16, 0, 16),
    Size = UDim2.new(0, 320, 0, 0),
    AutomaticSize = Enum.AutomaticSize.Y,
    BackgroundTransparency = 1,
    ZIndex = 10000,
}, screenGui)
new("UIListLayout", {
    Padding = UDim.new(0, 8),
    SortOrder = Enum.SortOrder.LayoutOrder,
    HorizontalAlignment = Enum.HorizontalAlignment.Right,
    VerticalAlignment = Enum.VerticalAlignment.Top,
}, notificationContainer)

local dock = new("TextButton", {
    Name = "RestoreDock",
    Position = UDim2.new(0, 16, 0, 16),
    Size = UDim2.new(0, 46, 0, 46),
    BackgroundColor3 = COLORS.white,
    BorderSizePixel = 0,
    Text = "",
    AutoButtonColor = false,
    Visible = false,
    ZIndex = 10001,
}, screenGui)
corner(dock, 14)
stroke(dock, COLORS.white, 0.82, 1)
applyPaint(dock, { CONFIG.main_color, CONFIG.accent2 }, 45)
local dockScale = new("UIScale", { Scale = 0.6 }, dock)
new("TextLabel", {
    Size = UDim2.new(1, 0, 1, 0),
    BackgroundTransparency = 1,
    Text = "S",
    Font = CONFIG.font_bold,
    TextSize = 18,
    TextColor3 = COLORS.white,
    ZIndex = 2,
}, dock)

local connections = {}
local function connect(signal, callback)
    local connection = signal:Connect(callback)
    table.insert(connections, connection)
    return connection
end

local library = {}
local windows = {}
local bindingActive = false
local topZ = 100

local function focusWindow(windowData)
    topZ = topZ + 10
    windowData.root.ZIndex = topZ
end

local function updateDock()
    local anyHidden = false
    for _, windowData in ipairs(windows) do
        if not windowData.root.Visible then
            anyHidden = true
            break
        end
    end

    if anyHidden then
        if not dock.Visible then
            dock.Visible = true
            dockScale.Scale = 0.6
            tween(dockScale, 0.25, { Scale = 1 }, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
        end
    elseif dock.Visible then
        tween(dockScale, 0.18, { Scale = 0.6 })
        task.delay(0.18, function()
            local stillHidden = false
            for _, windowData in ipairs(windows) do
                if not windowData.root.Visible then
                    stillHidden = true
                    break
                end
            end
            if not stillHidden then
                dock.Visible = false
            end
        end)
    end
end

local function restoreAllWindows()
    for _, windowData in ipairs(windows) do
        if not windowData.root.Visible then
            windowData.api:Show()
        end
    end
end

local function toggleGui()
    if not screenGui.Enabled then
        screenGui.Enabled = true
        return
    end

    local anyVisible = false
    for _, windowData in ipairs(windows) do
        if windowData.root.Visible then
            anyVisible = true
            break
        end
    end

    if not anyVisible then
        restoreAllWindows()
        screenGui.Enabled = true
    else
        screenGui.Enabled = false
    end
end

dock.MouseEnter:Connect(function()
    tween(dockScale, 0.15, { Scale = 1.08 }, Enum.EasingStyle.Quint)
end)
dock.MouseLeave:Connect(function()
    tween(dockScale, 0.15, { Scale = 1 }, Enum.EasingStyle.Quint)
end)
dock.MouseButton1Down:Connect(function()
    tween(dockScale, 0.1, { Scale = 0.92 })
end)
dock.MouseButton1Up:Connect(function()
    tween(dockScale, 0.15, { Scale = 1.08 })
end)
dock.MouseButton1Click:Connect(restoreAllWindows)

connect(UserInputService.InputBegan, function(input, gameProcessed)
    if gameProcessed then
        return
    end
    if bindingActive then
        return
    end
    local toggleKey = CONFIG.toggle_key
    if typeof(toggleKey) ~= "EnumItem" or toggleKey.EnumType ~= Enum.KeyCode then
        return
    end
    if input.KeyCode == toggleKey then
        toggleGui()
    end
end)

connect(UserInputService.InputBegan, function(input)
    if input.UserInputType ~= Enum.UserInputType.MouseButton1
        and input.UserInputType ~= Enum.UserInputType.Touch then
        return
    end
    local position = Vector2.new(input.Position.X, input.Position.Y)
    local best
    local bestZ
    for _, windowData in ipairs(windows) do
        if windowData.root.Visible and isInside(windowData.root, position) then
            if not bestZ or windowData.root.ZIndex > bestZ then
                best = windowData
                bestZ = windowData.root.ZIndex
            end
        end
    end
    if best then
        focusWindow(best)
    end
end)

local function ripple(parent, screenX, screenY, color)
    local x = screenX - parent.AbsolutePosition.X
    local y = screenY - parent.AbsolutePosition.Y
    local diameter = math.max(parent.AbsoluteSize.X, parent.AbsoluteSize.Y) * 1.8
    local circle = new("Frame", {
        Name = "Ripple",
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.new(0, x, 0, y),
        Size = UDim2.new(0, 0, 0, 0),
        BackgroundColor3 = color or COLORS.white,
        BackgroundTransparency = 0.82,
        BorderSizePixel = 0,
        ZIndex = 50,
    }, parent)
    corner(circle, 999)
    tween(circle, 0.45, {
        Size = UDim2.new(0, diameter, 0, diameter),
        BackgroundTransparency = 1,
    })
    task.delay(0.5, function()
        if circle and circle.Parent then
            circle:Destroy()
        end
    end)
end

local function makeButton(text, callback, parent, compact)
    text = tostring(text or "Button")
    callback = type(callback) == "function" and callback or function() end

    local button = new("TextButton", {
        Name = "Button",
        Size = compact and UDim2.new(0, 0, 0, 34) or UDim2.new(1, 0, 0, 34),
        BackgroundColor3 = COLORS.surface2,
        BackgroundTransparency = 0.05,
        AutoButtonColor = false,
        Text = "",
        ClipsDescendants = true,
        TextXAlignment = Enum.TextXAlignment.Left,
    }, parent)
    corner(button, 8)
    local buttonStroke = stroke(button, COLORS.white, 0.93, 1)
    local buttonScale = new("UIScale", { Scale = 1 }, button)

    if compact then
        button.Text = text
        button.Font = CONFIG.font
        button.TextSize = 12
        button.TextColor3 = COLORS.text
        button.TextXAlignment = Enum.TextXAlignment.Center
        button.TextYAlignment = Enum.TextYAlignment.Center
        button.AutomaticSize = Enum.AutomaticSize.X
        padding(button, 14, 14, 0, 0)
    else
        new("Frame", {
            Name = "Accent",
            Size = UDim2.new(0, 3, 0, 14),
            Position = UDim2.new(0, 0, 0.5, -7),
            BackgroundColor3 = CONFIG.main_color,
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            ZIndex = 2,
        }, button)
        corner(button:FindFirstChild("Accent"), 2)
        new("TextLabel", {
            Name = "Label",
            Size = UDim2.new(1, -40, 1, 0),
            Position = UDim2.new(0, 14, 0, 0),
            BackgroundTransparency = 1,
            Text = text,
            Font = CONFIG.font,
            TextSize = 13,
            TextColor3 = COLORS.text,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextYAlignment = Enum.TextYAlignment.Center,
            TextTruncate = Enum.TextTruncate.AtEnd,
            ZIndex = 3,
        }, button)
        new("TextLabel", {
            Name = "Chevron",
            Size = UDim2.new(0, 20, 1, 0),
            Position = UDim2.new(1, -26, 0, 0),
            BackgroundTransparency = 1,
            Text = ">",
            Font = CONFIG.font_bold,
            TextSize = 16,
            TextColor3 = COLORS.textMuted,
            TextXAlignment = Enum.TextXAlignment.Center,
            TextYAlignment = Enum.TextYAlignment.Center,
            ZIndex = 3,
        }, button)
    end

    button.MouseEnter:Connect(function()
        tween(button, 0.14, { BackgroundColor3 = COLORS.surface3 })
        tween(buttonStroke, 0.14, { Transparency = 0.8 })
        local accent = button:FindFirstChild("Accent")
        if accent then
            tween(accent, 0.14, { BackgroundTransparency = 0.25 })
        end
        local chevron = button:FindFirstChild("Chevron")
        if chevron then
            tween(chevron, 0.14, {
                TextColor3 = COLORS.text,
                Position = UDim2.new(1, -22, 0, 0),
            })
        end
    end)

    button.MouseLeave:Connect(function()
        tween(button, 0.14, { BackgroundColor3 = COLORS.surface2 })
        tween(buttonStroke, 0.14, { Transparency = 0.93 })
        local accent = button:FindFirstChild("Accent")
        if accent then
            tween(accent, 0.14, { BackgroundTransparency = 1 })
        end
        local chevron = button:FindFirstChild("Chevron")
        if chevron then
            tween(chevron, 0.14, {
                TextColor3 = COLORS.textMuted,
                Position = UDim2.new(1, -26, 0, 0),
            })
        end
        tween(buttonScale, 0.15, { Scale = 1 })
    end)

    button.MouseButton1Down:Connect(function()
        tween(buttonScale, 0.1, { Scale = 0.985 })
    end)
    button.MouseButton1Up:Connect(function()
        tween(buttonScale, 0.15, { Scale = 1 })
    end)
    button.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            ripple(button, input.Position.X, input.Position.Y, CONFIG.main_color)
        end
    end)
    button.MouseButton1Click:Connect(function()
        local ok, err = pcall(callback)
        if not ok then
            warn("[Syniox UI] Button callback error: " .. tostring(err))
        end
    end)

    return button
end

local function makeSwitch(text, callback, parent)
    callback = type(callback) == "function" and callback or function() end

    local row = new("TextButton", {
        Name = "Switch",
        Size = UDim2.new(1, 0, 0, 38),
        BackgroundTransparency = 1,
        Text = "",
        AutoButtonColor = false,
        ClipsDescendants = true,
    }, parent)

    local label = new("TextLabel", {
        Name = "Title",
        Size = UDim2.new(1, -70, 1, 0),
        Position = UDim2.new(0, 2, 0, 0),
        BackgroundTransparency = 1,
        Text = tostring(text or "Switch"),
        Font = CONFIG.font,
        TextSize = 13,
        TextColor3 = COLORS.text,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Center,
        TextTruncate = Enum.TextTruncate.AtEnd,
        ZIndex = 2,
    }, row)

    local track = new("Frame", {
        Name = "Track",
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -2, 0.5, 0),
        Size = UDim2.new(0, 40, 0, 22),
        BackgroundColor3 = COLORS.surface3,
        BorderSizePixel = 0,
        ClipsDescendants = true,
        ZIndex = 2,
    }, row)
    corner(track, 11)
    local trackStroke = stroke(track, COLORS.white, 0.9, 1)

    local knob = new("Frame", {
        Name = "Knob",
        AnchorPoint = Vector2.new(0, 0.5),
        Position = UDim2.new(0, 3, 0.5, 0),
        Size = UDim2.new(0, 16, 0, 16),
        BackgroundColor3 = COLORS.textDim,
        BorderSizePixel = 0,
        ZIndex = 3,
    }, track)
    corner(knob, 8)
    local knobScale = new("UIScale", { Scale = 1 }, knob)

    local state = false

    local function render(animate)
        if animate then
            if state then
                tween(track, 0.18, { BackgroundColor3 = CONFIG.main_color })
                tween(trackStroke, 0.18, { Color = CONFIG.main_color, Transparency = 0.45 })
                tween(knob, 0.18, {
                    Position = UDim2.new(1, -19, 0.5, 0),
                    BackgroundColor3 = COLORS.white,
                }, Enum.EasingStyle.Quint)
            else
                tween(track, 0.18, { BackgroundColor3 = COLORS.surface3 })
                tween(trackStroke, 0.18, { Color = COLORS.white, Transparency = 0.9 })
                tween(knob, 0.18, {
                    Position = UDim2.new(0, 3, 0.5, 0),
                    BackgroundColor3 = COLORS.textDim,
                }, Enum.EasingStyle.Quint)
            end
        else
            if state then
                track.BackgroundColor3 = CONFIG.main_color
                trackStroke.Color = CONFIG.main_color
                trackStroke.Transparency = 0.45
                knob.Position = UDim2.new(1, -19, 0.5, 0)
                knob.BackgroundColor3 = COLORS.white
            else
                track.BackgroundColor3 = COLORS.surface3
                trackStroke.Color = COLORS.white
                trackStroke.Transparency = 0.9
                knob.Position = UDim2.new(0, 3, 0.5, 0)
                knob.BackgroundColor3 = COLORS.textDim
            end
        end
    end

    local api = {}
    function api:Set(value)
        state = value == true
        render(true)
        pcall(callback, state)
    end
    function api:Get()
        return state
    end

    row.MouseEnter:Connect(function()
        tween(label, 0.15, { TextColor3 = COLORS.white })
        if not state then
            tween(trackStroke, 0.15, { Transparency = 0.75 })
        end
    end)
    row.MouseLeave:Connect(function()
        tween(label, 0.15, { TextColor3 = COLORS.text })
        if not state then
            tween(trackStroke, 0.15, { Transparency = 0.9 })
        end
        tween(knobScale, 0.15, { Scale = 1 })
    end)
    row.MouseButton1Down:Connect(function()
        tween(knobScale, 0.1, { Scale = 1.15 })
    end)
    row.MouseButton1Up:Connect(function()
        tween(knobScale, 0.15, { Scale = 1 })
    end)
    row.MouseButton1Click:Connect(function()
        state = not state
        render(true)
        pcall(callback, state)
    end)

    render(false)
    return api, row
end

local function makeTextBox(placeholder, callback, options, parent)
    options = type(options) == "table" and options or {}
    callback = type(callback) == "function" and callback or function() end

    local box = new("TextBox", {
        Name = "TextBox",
        Size = UDim2.new(1, 0, 0, 36),
        BackgroundColor3 = COLORS.surface2,
        BackgroundTransparency = 0.05,
        Text = options.default and tostring(options.default) or "",
        PlaceholderText = tostring(placeholder or "Type here..."),
        PlaceholderColor3 = COLORS.textMuted,
        TextColor3 = COLORS.text,
        Font = CONFIG.font,
        TextSize = 13,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Center,
        ClearTextOnFocus = false,
        ClipsDescendants = true,
    }, parent)
    corner(box, 8)
    padding(box, 12, 12, 0, 0)
    local boxStroke = stroke(box, COLORS.white, 0.93, 1)

    box.Focused:Connect(function()
        tween(box, 0.15, { BackgroundColor3 = COLORS.surface3 })
        tween(boxStroke, 0.15, { Color = CONFIG.main_color, Transparency = 0.35 })
    end)
    box.FocusLost:Connect(function()
        tween(box, 0.15, { BackgroundColor3 = COLORS.surface2 })
        tween(boxStroke, 0.15, { Color = COLORS.white, Transparency = 0.93 })
        if #box.Text > 0 then
            pcall(callback, box.Text)
            if options.clear then
                box.Text = ""
            end
        end
    end)

    return box
end

local function makeSlider(text, callback, options, parent)
    options = type(options) == "table" and options or {}
    callback = type(callback) == "function" and callback or function() end

    local minValue = tonumber(options.min) or 0
    local maxValue = tonumber(options.max) or 100
    if maxValue <= minValue then
        maxValue = minValue + 1
    end
    local step = tonumber(options.step)
    local readonly = options.readonly == true

    local row = new("Frame", {
        Name = "Slider",
        Size = UDim2.new(1, 0, 0, 46),
        BackgroundTransparency = 1,
    }, parent)

    new("TextLabel", {
        Name = "Title",
        Size = UDim2.new(1, -60, 0, 18),
        BackgroundTransparency = 1,
        Text = tostring(text or "Slider"),
        Font = CONFIG.font,
        TextSize = 13,
        TextColor3 = COLORS.text,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Center,
        TextTruncate = Enum.TextTruncate.AtEnd,
    }, row)

    local valueLabel = new("TextLabel", {
        Name = "Value",
        AnchorPoint = Vector2.new(1, 0),
        Position = UDim2.new(1, -2, 0, 0),
        Size = UDim2.new(0, 60, 0, 18),
        BackgroundTransparency = 1,
        Text = "",
        Font = CONFIG.font,
        TextSize = 12,
        TextColor3 = COLORS.textDim,
        TextXAlignment = Enum.TextXAlignment.Right,
        TextYAlignment = Enum.TextYAlignment.Center,
    }, row)

    local track = new("Frame", {
        Name = "Track",
        Position = UDim2.new(0, 7, 0, 30),
        Size = UDim2.new(1, -14, 0, 6),
        BackgroundColor3 = COLORS.surface3,
        BorderSizePixel = 0,
        ClipsDescendants = false,
    }, row)
    corner(track, 3)
    local trackStroke = stroke(track, COLORS.white, 0.92, 1)

    local fill = new("Frame", {
        Name = "Indicator",
        Size = UDim2.new(0, 0, 1, 0),
        BackgroundColor3 = COLORS.white,
        BorderSizePixel = 0,
        ZIndex = 2,
    }, track)
    corner(fill, 3)
    applyPaint(fill, { CONFIG.main_color, CONFIG.accent2 }, 0)

    local thumb = new("Frame", {
        Name = "Thumb",
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.new(0, 0, 0.5, 0),
        Size = UDim2.new(0, 14, 0, 14),
        BackgroundColor3 = COLORS.white,
        BorderSizePixel = 0,
        ZIndex = 3,
    }, track)
    corner(thumb, 7)
    local thumbStroke = stroke(thumb, CONFIG.main_color, 0.3, 2)
    local thumbScale = new("UIScale", { Scale = 1 }, thumb)

    local hitbox = new("TextButton", {
        Name = "Hitbox",
        Position = UDim2.new(0, 0, 0, 23),
        Size = UDim2.new(1, 0, 0, 20),
        BackgroundTransparency = 1,
        Text = "",
        AutoButtonColor = false,
        ZIndex = 4,
    }, row)

    local value = minValue
    local dragging = false

    local function formatValue(number)
        if type(options.format) == "function" then
            local ok, result = pcall(options.format, number)
            if ok and result ~= nil then
                return tostring(result)
            end
        end
        if math.abs(number - math.floor(number + 0.5)) < 0.0001 then
            return tostring(math.floor(number + 0.5))
        end
        return string.format("%.2f", number)
    end

    local function setValue(nextValue, fireCallback, animate)
        nextValue = tonumber(nextValue) or minValue
        nextValue = math.clamp(nextValue, minValue, maxValue)
        if step and step > 0 then
            nextValue = minValue + math.floor((nextValue - minValue) / step + 0.5) * step
            nextValue = math.clamp(nextValue, minValue, maxValue)
        end
        value = nextValue

        local percent = (value - minValue) / (maxValue - minValue)
        if animate then
            tween(fill, 0.12, { Size = UDim2.new(percent, 0, 1, 0) })
            tween(thumb, 0.12, { Position = UDim2.new(percent, 0, 0.5, 0) })
        else
            fill.Size = UDim2.new(percent, 0, 1, 0)
            thumb.Position = UDim2.new(percent, 0, 0.5, 0)
        end
        valueLabel.Text = formatValue(value)

        if fireCallback then
            pcall(callback, value)
        end
    end

    local function updateFromPosition(position)
        local percent = math.clamp(
            (position.X - track.AbsolutePosition.X) / math.max(track.AbsoluteSize.X, 1),
            0,
            1
        )
        setValue(minValue + (maxValue - minValue) * percent, true, false)
    end

    hitbox.InputBegan:Connect(function(input)
        if readonly then
            return
        end
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            updateFromPosition(input.Position)
            tween(thumbScale, 0.12, { Scale = 1.25 })
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                    tween(thumbScale, 0.15, { Scale = 1 })
                end
            end)
        end
    end)
    hitbox.MouseEnter:Connect(function()
        tween(thumbScale, 0.15, { Scale = 1.15 })
        tween(trackStroke, 0.15, { Color = CONFIG.main_color, Transparency = 0.65 })
    end)
    hitbox.MouseLeave:Connect(function()
        if not dragging then
            tween(thumbScale, 0.15, { Scale = 1 })
            tween(trackStroke, 0.15, { Color = COLORS.white, Transparency = 0.92 })
        end
    end)

    connect(UserInputService.InputChanged, function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement
            or input.UserInputType == Enum.UserInputType.Touch) then
            updateFromPosition(input.Position)
        end
    end)

    local api = {}
    function api:Set(nextValue)
        setValue(nextValue, true, true)
    end
    function api:Get()
        return value
    end

    setValue(options.default or minValue, not options.silent, false)
    return api, row
end

local function makeDropdown(text, callback, parent)
    callback = type(callback) == "function" and callback or function() end

    local row = new("Frame", {
        Name = "Dropdown",
        Size = UDim2.new(1, 0, 0, 36),
        BackgroundTransparency = 1,
        ClipsDescendants = true,
    }, parent)

    local field = new("TextButton", {
        Name = "Field",
        Size = UDim2.new(1, 0, 0, 36),
        BackgroundColor3 = COLORS.surface2,
        BackgroundTransparency = 0.05,
        Text = "",
        AutoButtonColor = false,
        ClipsDescendants = true,
        ZIndex = 2,
    }, row)
    corner(field, 8)
    local fieldStroke = stroke(field, COLORS.white, 0.93, 1)

    new("TextLabel", {
        Name = "Title",
        Size = UDim2.new(0.55, 0, 1, 0),
        Position = UDim2.new(0, 12, 0, 0),
        BackgroundTransparency = 1,
        Text = tostring(text or "Dropdown"),
        Font = CONFIG.font,
        TextSize = 13,
        TextColor3 = COLORS.text,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Center,
        TextTruncate = Enum.TextTruncate.AtEnd,
        ZIndex = 3,
    }, field)

    local valueLabel = new("TextLabel", {
        Name = "Value",
        Size = UDim2.new(0.45, -46, 1, 0),
        Position = UDim2.new(0.55, 0, 0, 0),
        BackgroundTransparency = 1,
        Text = "-",
        Font = CONFIG.font,
        TextSize = 12,
        TextColor3 = COLORS.textMuted,
        TextXAlignment = Enum.TextXAlignment.Right,
        TextYAlignment = Enum.TextYAlignment.Center,
        TextTruncate = Enum.TextTruncate.AtEnd,
        ZIndex = 3,
    }, field)

    local chevron = new("TextLabel", {
        Name = "Chevron",
        Size = UDim2.new(0, 16, 1, 0),
        Position = UDim2.new(1, -28, 0, 0),
        BackgroundTransparency = 1,
        Text = "v",
        Font = CONFIG.font_bold,
        TextSize = 10,
        TextColor3 = COLORS.textMuted,
        TextXAlignment = Enum.TextXAlignment.Center,
        TextYAlignment = Enum.TextYAlignment.Center,
        Rotation = 0,
        ZIndex = 3,
    }, field)

    local panel = new("Frame", {
        Name = "Box",
        Position = UDim2.new(0, 0, 0, 42),
        Size = UDim2.new(1, 0, 0, 0),
        BackgroundColor3 = COLORS.bg,
        BackgroundTransparency = 0.05,
        BorderSizePixel = 0,
        ClipsDescendants = true,
        ZIndex = 2,
    }, row)
    corner(panel, 8)
    stroke(panel, COLORS.white, 0.92, 1)

    local scroller = new("ScrollingFrame", {
        Name = "Objects",
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ScrollBarThickness = 4,
        ScrollBarImageColor3 = CONFIG.main_color,
        ScrollBarImageTransparency = 0.35,
        CanvasSize = UDim2.new(0, 0, 0, 0),
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        ScrollingDirection = Enum.ScrollingDirection.Y,
        ZIndex = 3,
    }, panel)
    padding(scroller, 4, 4, 4, 4)
    new("UIListLayout", {
        Padding = UDim.new(0, 2),
        SortOrder = Enum.SortOrder.LayoutOrder,
    }, scroller)

    local emptyLabel = new("TextLabel", {
        Name = "Empty",
        Size = UDim2.new(1, 0, 0, 30),
        BackgroundTransparency = 1,
        Text = "No options",
        Font = CONFIG.font,
        TextSize = 12,
        TextColor3 = COLORS.textMuted,
        TextXAlignment = Enum.TextXAlignment.Center,
        TextYAlignment = Enum.TextYAlignment.Center,
        Visible = true,
        LayoutOrder = 0,
    }, scroller)

    local api = {
        currentSelection = nil,
    }
    local optionsByName = {}
    local optionOrder = 0
    local isOpen = false
    local outsideConnection

    local function optionCount()
        local count = 0
        for _, child in ipairs(scroller:GetChildren()) do
            if child:IsA("TextButton") then
                count = count + 1
            end
        end
        return count
    end

    local function panelHeight()
        local count = optionCount()
        if count == 0 then
            return 38
        end
        return math.min(count * 32 + 8, 168)
    end

    local function updatePanelSize(animate)
        emptyLabel.Visible = optionCount() == 0
        if not isOpen then
            return
        end
        local target = panelHeight()
        if animate then
            tween(row, 0.18, { Size = UDim2.new(1, 0, 0, 42 + target) })
            tween(panel, 0.18, { Size = UDim2.new(1, 0, 0, target) })
        else
            row.Size = UDim2.new(1, 0, 0, 42 + target)
            panel.Size = UDim2.new(1, 0, 0, target)
        end
    end

    local function close()
        if not isOpen then
            return
        end
        isOpen = false
        if outsideConnection then
            outsideConnection:Disconnect()
            outsideConnection = nil
        end
        tween(chevron, 0.18, { Rotation = 0, TextColor3 = COLORS.textMuted })
        tween(field, 0.15, { BackgroundColor3 = COLORS.surface2 })
        tween(fieldStroke, 0.15, { Color = COLORS.white, Transparency = 0.93 })
        tween(row, 0.2, { Size = UDim2.new(1, 0, 0, 36) }, Enum.EasingStyle.Quint)
        tween(panel, 0.2, { Size = UDim2.new(1, 0, 0, 0) }, Enum.EasingStyle.Quint)
    end

    local function open()
        if isOpen then
            return
        end
        isOpen = true
        tween(chevron, 0.18, { Rotation = 180, TextColor3 = CONFIG.main_color })
        tween(field, 0.15, { BackgroundColor3 = COLORS.surface3 })
        tween(fieldStroke, 0.15, { Color = CONFIG.main_color, Transparency = 0.55 })
        local target = panelHeight()
        tween(row, 0.2, { Size = UDim2.new(1, 0, 0, 42 + target) }, Enum.EasingStyle.Quint)
        tween(panel, 0.2, { Size = UDim2.new(1, 0, 0, target) }, Enum.EasingStyle.Quint)

        task.delay(0.05, function()
            if not isOpen then
                return
            end
            outsideConnection = UserInputService.InputBegan:Connect(function(input)
                if input.UserInputType ~= Enum.UserInputType.MouseButton1
                    and input.UserInputType ~= Enum.UserInputType.Touch then
                    return
                end
                local position = Vector2.new(input.Position.X, input.Position.Y)
                if not isInside(field, position) and not isInside(panel, position) then
                    close()
                end
            end)
        end)
    end

    local function select(name, fireCallback)
        local option = optionsByName[name]
        if not option then
            return
        end
        api.currentSelection = name
        valueLabel.Text = name
        valueLabel.TextColor3 = COLORS.text
        for optionName, entry in pairs(optionsByName) do
            entry.selected = optionName == name
            entry:render(false)
        end
        if fireCallback then
            pcall(callback, name)
        end
    end

    function api:Add(name)
        name = tostring(name or "Option")
        if optionsByName[name] then
            return optionsByName[name].button, optionsByName[name]
        end

        optionOrder = optionOrder + 1
        local button = new("TextButton", {
            Name = "Option",
            Size = UDim2.new(1, 0, 0, 30),
            BackgroundColor3 = COLORS.white,
            BackgroundTransparency = 1,
            Text = "",
            AutoButtonColor = false,
            ClipsDescendants = true,
            LayoutOrder = optionOrder,
            ZIndex = 4,
        }, scroller)
        corner(button, 6)
        local label = new("TextLabel", {
            Name = "Label",
            Size = UDim2.new(1, -34, 1, 0),
            Position = UDim2.new(0, 10, 0, 0),
            BackgroundTransparency = 1,
            Text = name,
            Font = CONFIG.font,
            TextSize = 12,
            TextColor3 = COLORS.textDim,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextYAlignment = Enum.TextYAlignment.Center,
            TextTruncate = Enum.TextTruncate.AtEnd,
            ZIndex = 5,
        }, button)
        local check = new("TextLabel", {
            Name = "Check",
            Size = UDim2.new(0, 18, 1, 0),
            Position = UDim2.new(1, -24, 0, 0),
            BackgroundTransparency = 1,
            Text = "✓",
            Font = CONFIG.font_bold,
            TextSize = 12,
            TextColor3 = CONFIG.main_color,
            TextXAlignment = Enum.TextXAlignment.Center,
            TextYAlignment = Enum.TextYAlignment.Center,
            Visible = false,
            ZIndex = 5,
        }, button)

        local option = {
            name = name,
            button = button,
            selected = false,
        }

        function option:render(animate)
            if self.selected then
                if animate then
                    tween(button, 0.12, { BackgroundColor3 = CONFIG.main_color, BackgroundTransparency = 0.85 })
                else
                    button.BackgroundColor3 = CONFIG.main_color
                    button.BackgroundTransparency = 0.85
                end
                label.TextColor3 = COLORS.text
                check.Visible = true
            else
                if animate then
                    tween(button, 0.12, { BackgroundTransparency = 1 })
                else
                    button.BackgroundTransparency = 1
                end
                label.TextColor3 = COLORS.textDim
                check.Visible = false
            end
        end
        function option:Remove()
            api:Remove(name)
        end

        button.MouseEnter:Connect(function()
            if not option.selected then
                tween(button, 0.12, { BackgroundColor3 = COLORS.white, BackgroundTransparency = 0.94 })
                tween(label, 0.12, { TextColor3 = COLORS.text })
            end
        end)
        button.MouseLeave:Connect(function()
            if not option.selected then
                tween(button, 0.12, { BackgroundTransparency = 1 })
                tween(label, 0.12, { TextColor3 = COLORS.textDim })
            end
        end)
        button.MouseButton1Click:Connect(function()
            select(name, true)
            close()
        end)

        optionsByName[name] = option
        updatePanelSize(true)
        return button, option
    end

    function api:Remove(name)
        local option = optionsByName[name]
        if not option then
            return
        end
        optionsByName[name] = nil
        option.button:Destroy()
        if api.currentSelection == name then
            api.currentSelection = nil
            local nextName
            local nextOrder
            for optionName, entry in pairs(optionsByName) do
                local order = entry.button.LayoutOrder
                if not nextOrder or order < nextOrder then
                    nextName = optionName
                    nextOrder = order
                end
            end
            if nextName then
                select(nextName, true)
            else
                valueLabel.Text = "-"
                valueLabel.TextColor3 = COLORS.textMuted
                pcall(callback, nil)
            end
        end
        updatePanelSize(true)
    end

    function api:Set(name)
        if optionsByName[name] then
            select(name, true)
            close()
        end
    end

    function api:Get()
        return api.currentSelection
    end

    function api:Clear()
        local names = {}
        for name in pairs(optionsByName) do
            table.insert(names, name)
        end
        for _, name in ipairs(names) do
            local option = optionsByName[name]
            if option then
                option.button:Destroy()
                optionsByName[name] = nil
            end
        end
        api.currentSelection = nil
        valueLabel.Text = "-"
        valueLabel.TextColor3 = COLORS.textMuted
        updatePanelSize(true)
    end

    field.MouseEnter:Connect(function()
        if not isOpen then
            tween(field, 0.14, { BackgroundColor3 = COLORS.surface3 })
            tween(fieldStroke, 0.14, { Transparency = 0.8 })
        end
    end)
    field.MouseLeave:Connect(function()
        if not isOpen then
            tween(field, 0.14, { BackgroundColor3 = COLORS.surface2 })
            tween(fieldStroke, 0.14, { Transparency = 0.93 })
        end
    end)
    field.MouseButton1Click:Connect(function()
        if isOpen then
            close()
        else
            open()
        end
    end)

    row.Destroying:Connect(function()
        if outsideConnection then
            outsideConnection:Disconnect()
            outsideConnection = nil
        end
    end)

    return api, row
end

local KEY_NAMES = {
    RightShift = "RShift",
    LeftShift = "LShift",
    RightControl = "RightCtrl",
    LeftControl = "LeftCtrl",
    MouseButton1 = "Mouse1",
    MouseButton2 = "Mouse2",
}

local function keyName(key)
    if typeof(key) ~= "EnumItem" then
        return "None"
    end
    if key.EnumType == Enum.UserInputType then
        return KEY_NAMES[key.Name] or key.Name
    end
    return KEY_NAMES[key.Name] or key.Name
end

local function makeKeybind(text, callback, options, parent)
    options = type(options) == "table" and options or {}
    callback = type(callback) == "function" and callback or function() end

    local row = new("Frame", {
        Name = "Keybind",
        Size = UDim2.new(1, 0, 0, 36),
        BackgroundColor3 = COLORS.surface2,
        BackgroundTransparency = 0.05,
        BorderSizePixel = 0,
        ClipsDescendants = true,
    }, parent)
    corner(row, 8)
    local rowStroke = stroke(row, COLORS.white, 0.93, 1)

    new("TextLabel", {
        Name = "Title",
        Size = UDim2.new(1, -100, 1, 0),
        Position = UDim2.new(0, 12, 0, 0),
        BackgroundTransparency = 1,
        Text = tostring(text or "Keybind"),
        Font = CONFIG.font,
        TextSize = 13,
        TextColor3 = COLORS.text,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Center,
        TextTruncate = Enum.TextTruncate.AtEnd,
        ZIndex = 2,
    }, row)

    local chip = new("TextButton", {
        Name = "Input",
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -6, 0.5, 0),
        Size = UDim2.new(0, 72, 0, 22),
        BackgroundColor3 = COLORS.surface3,
        BackgroundTransparency = 0,
        Text = "",
        AutoButtonColor = false,
        ClipsDescendants = true,
        ZIndex = 3,
    }, row)
    corner(chip, 6)
    local chipStroke = stroke(chip, COLORS.white, 0.9, 1)

    local currentKey = options.standard or Enum.KeyCode.RightShift
    local listening = false
    local api = {}

    local function setKey(key, fireCallback)
        currentKey = key
        chip.Text = keyName(key)
        chip.TextColor3 = COLORS.textDim
        if fireCallback then
            pcall(callback, key)
        end
    end

    function api:SetKeybind(key)
        if typeof(key) == "EnumItem" then
            setKey(key, false)
        end
    end
    function api:Get()
        return currentKey
    end

    local function listen()
        if listening or bindingActive then
            return
        end
        listening = true
        bindingActive = true
        chip.Text = "..."
        chip.TextColor3 = CONFIG.main_color
        tween(chipStroke, 0.15, { Color = CONFIG.main_color, Transparency = 0.3 })

        local connection
        local function finish(input)
            if not listening then
                return
            end
            listening = false
            task.defer(function()
                bindingActive = false
            end)
            if connection then
                connection:Disconnect()
                connection = nil
            end
            chip.TextColor3 = COLORS.textDim
            tween(chipStroke, 0.15, { Color = COLORS.white, Transparency = 0.9 })

            if input then
                local key
                if input.KeyCode ~= Enum.KeyCode.Unknown then
                    key = input.KeyCode
                elseif input.UserInputType == Enum.UserInputType.MouseButton1
                    or input.UserInputType == Enum.UserInputType.MouseButton2 then
                    key = input.UserInputType
                end
                if key then
                    setKey(key, true)
                    return
                end
            end
            chip.Text = keyName(currentKey)
        end

        connection = UserInputService.InputBegan:Connect(function(input, gameProcessed)
            if gameProcessed then
                return
            end
            finish(input)
        end)
        table.insert(connections, connection)
        task.delay(6, function()
            finish(nil)
        end)
    end

    chip.MouseEnter:Connect(function()
        if not listening then
            tween(chip, 0.12, { BackgroundColor3 = COLORS.surface2 })
            tween(chipStroke, 0.12, { Transparency = 0.75 })
        end
    end)
    chip.MouseLeave:Connect(function()
        if not listening then
            tween(chip, 0.12, { BackgroundColor3 = COLORS.surface3 })
            tween(chipStroke, 0.12, { Transparency = 0.9 })
        end
    end)
    chip.MouseButton1Click:Connect(listen)

    connect(UserInputService.InputBegan, function(input, gameProcessed)
        if gameProcessed or bindingActive then
            return
        end
        local pressed
        if input.KeyCode ~= Enum.KeyCode.Unknown then
            pressed = input.KeyCode
        elseif input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.MouseButton2 then
            pressed = input.UserInputType
        end
        if pressed == currentKey then
            pcall(callback, currentKey)
        end
    end)

    setKey(currentKey, false)
    return api, row
end

local function makeColorPicker(title, callback, parent)
    callback = type(callback) == "function" and callback or function() end

    local card = new("Frame", {
        Name = "ColorPicker",
        Size = UDim2.new(1, 0, 0, 196),
        BackgroundColor3 = COLORS.surface2,
        BackgroundTransparency = 0.15,
        BorderSizePixel = 0,
        ClipsDescendants = true,
    }, parent)
    corner(card, 10)
    stroke(card, COLORS.white, 0.93, 1)

    new("TextLabel", {
        Name = "Title",
        Size = UDim2.new(1, -60, 0, 18),
        Position = UDim2.new(0, 12, 0, 10),
        BackgroundTransparency = 1,
        Text = tostring(title or "Color"),
        Font = CONFIG.font,
        TextSize = 13,
        TextColor3 = COLORS.text,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Center,
        TextTruncate = Enum.TextTruncate.AtEnd,
    }, card)

    local preview = new("Frame", {
        Name = "Sample",
        AnchorPoint = Vector2.new(1, 0),
        Position = UDim2.new(1, -12, 0, 8),
        Size = UDim2.new(0, 24, 0, 24),
        BackgroundColor3 = COLORS.white,
        BorderSizePixel = 0,
    }, card)
    corner(preview, 7)
    stroke(preview, COLORS.white, 0.8, 1)

    local sv = new("Frame", {
        Name = "Palette",
        Position = UDim2.new(0, 12, 0, 42),
        Size = UDim2.new(1, -24, 0, 92),
        BackgroundColor3 = Color3.fromHSV(0, 1, 1),
        BorderSizePixel = 0,
        ClipsDescendants = true,
    }, card)
    corner(sv, 8)
    stroke(sv, COLORS.white, 0.88, 1)

    local saturationOverlay = new("Frame", {
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundColor3 = COLORS.white,
        BorderSizePixel = 0,
    }, sv)
    new("UIGradient", {
        Color = ColorSequence.new(COLORS.white, COLORS.white),
        Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 0),
            NumberSequenceKeypoint.new(1, 1),
        }),
        Rotation = 0,
    }, saturationOverlay)

    local valueOverlay = new("Frame", {
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundColor3 = COLORS.black,
        BorderSizePixel = 0,
    }, sv)
    new("UIGradient", {
        Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 1),
            NumberSequenceKeypoint.new(1, 0),
        }),
        Rotation = 90,
    }, valueOverlay)

    local svIndicatorShadow = new("Frame", {
        Name = "IndicatorShadow",
        AnchorPoint = Vector2.new(0.5, 0.5),
        Size = UDim2.new(0, 16, 0, 16),
        BackgroundTransparency = 1,
        ZIndex = 5,
    }, sv)
    corner(svIndicatorShadow, 8)
    stroke(svIndicatorShadow, COLORS.black, 0.45, 2)

    local svIndicator = new("Frame", {
        Name = "Indicator",
        AnchorPoint = Vector2.new(0.5, 0.5),
        Size = UDim2.new(0, 12, 0, 12),
        BackgroundTransparency = 1,
        ZIndex = 6,
    }, sv)
    corner(svIndicator, 6)
    stroke(svIndicator, COLORS.white, 0, 2)

    local hue = new("Frame", {
        Name = "Saturation",
        Position = UDim2.new(0, 12, 0, 146),
        Size = UDim2.new(1, -24, 0, 10),
        BackgroundColor3 = COLORS.white,
        BorderSizePixel = 0,
        ClipsDescendants = true,
    }, card)
    corner(hue, 5)
    stroke(hue, COLORS.white, 0.88, 1)
    new("UIGradient", {
        Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, Color3.fromHSV(0, 1, 1)),
            ColorSequenceKeypoint.new(1 / 6, Color3.fromHSV(1 / 6, 1, 1)),
            ColorSequenceKeypoint.new(2 / 6, Color3.fromHSV(2 / 6, 1, 1)),
            ColorSequenceKeypoint.new(3 / 6, Color3.fromHSV(3 / 6, 1, 1)),
            ColorSequenceKeypoint.new(4 / 6, Color3.fromHSV(4 / 6, 1, 1)),
            ColorSequenceKeypoint.new(5 / 6, Color3.fromHSV(5 / 6, 1, 1)),
            ColorSequenceKeypoint.new(1, Color3.fromHSV(1, 1, 1)),
        }),
        Rotation = 0,
    }, hue)

    local hueIndicatorShadow = new("Frame", {
        Name = "IndicatorShadow",
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.new(0, 0, 0.5, 0),
        Size = UDim2.new(0, 16, 0, 16),
        BackgroundTransparency = 1,
        ZIndex = 5,
    }, hue)
    corner(hueIndicatorShadow, 8)
    stroke(hueIndicatorShadow, COLORS.black, 0.45, 2)

    local hueIndicator = new("Frame", {
        Name = "Indicator",
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.new(0, 0, 0.5, 0),
        Size = UDim2.new(0, 12, 0, 12),
        BackgroundTransparency = 1,
        ZIndex = 6,
    }, hue)
    corner(hueIndicator, 6)
    stroke(hueIndicator, COLORS.white, 0, 2)

    local hexBox = new("TextBox", {
        Name = "Hex",
        Position = UDim2.new(0, 12, 0, 164),
        Size = UDim2.new(0, 96, 0, 24),
        BackgroundColor3 = COLORS.bg,
        BackgroundTransparency = 0.1,
        Text = "#FFFFFF",
        Font = CONFIG.font_code,
        TextSize = 12,
        TextColor3 = COLORS.text,
        TextXAlignment = Enum.TextXAlignment.Center,
        TextYAlignment = Enum.TextYAlignment.Center,
        ClearTextOnFocus = false,
    }, card)
    corner(hexBox, 6)
    stroke(hexBox, COLORS.white, 0.9, 1)

    local svHitbox = new("TextButton", {
        Name = "Hitbox",
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundTransparency = 1,
        Text = "",
        AutoButtonColor = false,
        ZIndex = 10,
    }, sv)
    local hueHitbox = new("TextButton", {
        Name = "Hitbox",
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundTransparency = 1,
        Text = "",
        AutoButtonColor = false,
        ZIndex = 10,
    }, hue)

    local hueValue = 0
    local saturationValue = 1
    local brightnessValue = 1
    local currentColor = Color3.fromHSV(hueValue, saturationValue, brightnessValue)
    local draggingSv = false
    local draggingHue = false
    local api = {}

    local function render(fireCallback)
        currentColor = Color3.fromHSV(hueValue, saturationValue, brightnessValue)
        sv.BackgroundColor3 = Color3.fromHSV(hueValue, 1, 1)
        preview.BackgroundColor3 = currentColor
        svIndicator.Position = UDim2.new(saturationValue, 0, 1 - brightnessValue, 0)
        svIndicatorShadow.Position = svIndicator.Position
        hueIndicator.Position = UDim2.new(hueValue, 0, 0.5, 0)
        hueIndicatorShadow.Position = hueIndicator.Position
        hexBox.Text = "#" .. currentColor:ToHex()
        if fireCallback then
            pcall(callback, currentColor)
        end
    end

    local function updateSv(position)
        saturationValue = math.clamp(
            (position.X - sv.AbsolutePosition.X) / math.max(sv.AbsoluteSize.X, 1),
            0,
            1
        )
        brightnessValue = 1 - math.clamp(
            (position.Y - sv.AbsolutePosition.Y) / math.max(sv.AbsoluteSize.Y, 1),
            0,
            1
        )
        render(true)
    end

    local function updateHue(position)
        hueValue = math.clamp(
            (position.X - hue.AbsolutePosition.X) / math.max(hue.AbsoluteSize.X, 1),
            0,
            1
        )
        render(true)
    end

    svHitbox.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            draggingSv = true
            updateSv(input.Position)
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    draggingSv = false
                end
            end)
        end
    end)
    hueHitbox.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            draggingHue = true
            updateHue(input.Position)
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    draggingHue = false
                end
            end)
        end
    end)

    connect(UserInputService.InputChanged, function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement
            or input.UserInputType == Enum.UserInputType.Touch then
            if draggingSv then
                updateSv(input.Position)
            elseif draggingHue then
                updateHue(input.Position)
            end
        end
    end)

    hexBox.FocusLost:Connect(function()
        local parsed = parseHexColor(hexBox.Text)
        if parsed then
            hueValue, saturationValue, brightnessValue = Color3.toHSV(parsed)
            render(true)
        else
            render(false)
        end
    end)
    hexBox.Focused:Connect(function()
        hexBox.Text = "#" .. currentColor:ToHex()
    end)

    function api:Set(color)
        if typeof(color) ~= "Color3" then
            return
        end
        hueValue, saturationValue, brightnessValue = Color3.toHSV(color)
        render(true)
    end
    function api:Get()
        return currentColor
    end

    render(false)
    return api, card
end

local createContainer

createContainer = function(parentFrame)
    local api = {}
    local order = 0

    local function add(instance)
        order = order + 1
        instance.LayoutOrder = order
        instance.Parent = parentFrame
        return instance
    end

    function api:AddLabel(text)
        local label = new("TextLabel", {
            Name = "Label",
            Size = UDim2.new(1, 0, 0, 18),
            BackgroundTransparency = 1,
            Text = tostring(text or ""),
            Font = CONFIG.font,
            TextSize = 12,
            TextColor3 = COLORS.textDim,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextYAlignment = Enum.TextYAlignment.Center,
            TextTruncate = Enum.TextTruncate.AtEnd,
        }, parentFrame)
        return add(label)
    end

    function api:AddButton(text, callback)
        local button = makeButton(text, callback, parentFrame, false)
        return add(button)
    end

    function api:AddSwitch(text, callback)
        local switchApi, row = makeSwitch(text, callback, parentFrame)
        add(row)
        return switchApi, row
    end

    function api:AddTextBox(placeholder, callback, options)
        local box = makeTextBox(placeholder, callback, options, parentFrame)
        return add(box)
    end

    function api:AddSlider(text, callback, options)
        local sliderApi, row = makeSlider(text, callback, options, parentFrame)
        add(row)
        return sliderApi, row
    end

    function api:AddKeybind(text, callback, options)
        local keybindApi, row = makeKeybind(text, callback, options, parentFrame)
        add(row)
        return keybindApi, row
    end

    function api:AddDropdown(text, callback)
        local dropdownApi, row = makeDropdown(text, callback, parentFrame)
        add(row)
        return dropdownApi, row
    end

    function api:AddColorPicker(first, second)
        local title
        local callback
        if type(first) == "string" then
            title = first
            callback = second
        else
            title = "Color"
            callback = first
        end
        callback = type(callback) == "function" and callback or function() end
        local colorApi, card = makeColorPicker(title, callback, parentFrame)
        add(card)
        return colorApi, card
    end

    function api:AddHorizontalAlignment()
        local holder = new("Frame", {
            Name = "HorizontalAlignment",
            Size = UDim2.new(1, 0, 0, 34),
            BackgroundTransparency = 1,
        }, parentFrame)
        add(holder)
        new("UIListLayout", {
            FillDirection = Enum.FillDirection.Horizontal,
            SortOrder = Enum.SortOrder.LayoutOrder,
            Padding = UDim.new(0, 6),
            VerticalAlignment = Enum.VerticalAlignment.Center,
            HorizontalAlignment = Enum.HorizontalAlignment.Left,
        }, holder)

        local proxy = {}
        function proxy:AddButton(text, callback)
            local button = makeButton(text, callback, holder, true)
            button.LayoutOrder = #holder:GetChildren()
            return button
        end
        return proxy, holder
    end

    function api:AddFolder(name)
        name = tostring(name or "Folder")

        local folder = new("Frame", {
            Name = "Folder",
            Size = UDim2.new(1, 0, 0, 38),
            BackgroundColor3 = COLORS.surface2,
            BackgroundTransparency = 0.55,
            BorderSizePixel = 0,
            ClipsDescendants = true,
        }, parentFrame)
        corner(folder, 10)
        stroke(folder, COLORS.white, 0.94, 1)

        local header = new("TextButton", {
            Name = "Button",
            Size = UDim2.new(1, 0, 0, 38),
            BackgroundTransparency = 1,
            Text = "",
            AutoButtonColor = false,
            ClipsDescendants = true,
            ZIndex = 2,
        }, folder)

        local chevron = new("TextLabel", {
            Name = "Toggle",
            Size = UDim2.new(0, 12, 0, 12),
            Position = UDim2.new(0, 13, 0.5, -6),
            BackgroundTransparency = 1,
            Text = ">",
            Font = CONFIG.font_bold,
            TextSize = 11,
            TextColor3 = COLORS.textMuted,
            TextXAlignment = Enum.TextXAlignment.Center,
            TextYAlignment = Enum.TextYAlignment.Center,
            Rotation = 0,
            ZIndex = 3,
        }, header)

        new("TextLabel", {
            Name = "Title",
            Size = UDim2.new(1, -44, 1, 0),
            Position = UDim2.new(0, 32, 0, 0),
            BackgroundTransparency = 1,
            Text = name,
            Font = CONFIG.font,
            TextSize = 13,
            TextColor3 = COLORS.text,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextYAlignment = Enum.TextYAlignment.Center,
            TextTruncate = Enum.TextTruncate.AtEnd,
            ZIndex = 3,
        }, header)

        local body = new("Frame", {
            Name = "Objects",
            Position = UDim2.new(0, 0, 0, 38),
            Size = UDim2.new(1, 0, 0, 0),
            BackgroundTransparency = 1,
            ClipsDescendants = true,
            Visible = false,
            ZIndex = 2,
        }, folder)
        padding(body, 10, 10, 0, 10)
        local bodyLayout = new("UIListLayout", {
            Padding = UDim.new(0, 8),
            SortOrder = Enum.SortOrder.LayoutOrder,
        }, body)

        local open = false
        local bodyApi = createContainer(body)

        local function contentHeight()
            return bodyLayout.AbsoluteContentSize.Y + 10
        end

        local function updateHeight(animate)
            local target = open and contentHeight() or 0
            if animate then
                tween(body, 0.18, { Size = UDim2.new(1, 0, 0, target) })
                tween(folder, 0.18, { Size = UDim2.new(1, 0, 0, 38 + target) })
            else
                body.Size = UDim2.new(1, 0, 0, target)
                folder.Size = UDim2.new(1, 0, 0, 38 + target)
            end
        end

        bodyLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
            if open then
                updateHeight(false)
            end
        end)

        header.MouseEnter:Connect(function()
            tween(header, 0.14, { BackgroundColor3 = COLORS.white, BackgroundTransparency = 0.96 })
            tween(chevron, 0.14, { TextColor3 = COLORS.text })
        end)
        header.MouseLeave:Connect(function()
            tween(header, 0.14, { BackgroundTransparency = 1 })
            tween(chevron, 0.14, { TextColor3 = open and CONFIG.main_color or COLORS.textMuted })
        end)
        header.MouseButton1Click:Connect(function()
            open = not open
            if open then
                body.Visible = true
                tween(chevron, 0.18, {
                    Rotation = 90,
                    TextColor3 = CONFIG.main_color,
                }, Enum.EasingStyle.Quint)
                task.defer(function()
                    if open then
                        updateHeight(true)
                    end
                end)
            else
                tween(chevron, 0.18, {
                    Rotation = 0,
                    TextColor3 = COLORS.textMuted,
                }, Enum.EasingStyle.Quint)
                updateHeight(true)
                task.delay(0.2, function()
                    if not open then
                        body.Visible = false
                    end
                end)
            end
        end)

        add(folder)
        return bodyApi, folder
    end

    return api
end

local function makeWindowControl(parent, name, glyph, hoverColor, callback, textSize)
    local button = new("TextButton", {
        Name = name,
        Size = UDim2.new(0, 26, 0, 26),
        BackgroundColor3 = COLORS.white,
        BackgroundTransparency = 1,
        Text = glyph,
        Font = CONFIG.font_bold,
        TextSize = textSize or 15,
        TextColor3 = COLORS.textMuted,
        AutoButtonColor = false,
        ZIndex = 6,
    }, parent)
    corner(button, 8)
    local scale = new("UIScale", { Scale = 1 }, button)

    button.MouseEnter:Connect(function()
        tween(button, 0.13, {
            BackgroundColor3 = hoverColor or COLORS.white,
            BackgroundTransparency = 0.9,
            TextColor3 = COLORS.white,
        })
    end)
    button.MouseLeave:Connect(function()
        tween(button, 0.13, {
            BackgroundTransparency = 1,
            TextColor3 = COLORS.textMuted,
        })
    end)
    button.MouseButton1Down:Connect(function()
        tween(scale, 0.1, { Scale = 0.86 })
    end)
    button.MouseButton1Up:Connect(function()
        tween(scale, 0.15, { Scale = 1 })
    end)
    button.MouseButton1Click:Connect(function()
        pcall(callback)
    end)
    return button
end

function library:AddWindow(title, config)
    config = type(config) == "table" and config or {}
    local windowIndex = #windows + 1

    local accent = config.main_color or CONFIG.main_color
    local accent2 = config.accent2
    if not accent2 then
        if config.main_color then
            accent2 = mix(config.main_color, Color3.fromRGB(190, 120, 255), 0.45)
        else
            accent2 = CONFIG.accent2
        end
    end

    local viewport = getViewport()

    local function resolveDimension(value)
        if typeof(value) == "UDim2" then
            return Vector2.new(
                value.X.Scale * viewport.X + value.X.Offset,
                value.Y.Scale * viewport.Y + value.Y.Offset
            )
        end
        return toVector2(value)
    end

    local minSize = resolveDimension(config.min_size) or CONFIG.min_size
    local canResize = config.can_resize
    if canResize == nil then
        canResize = CONFIG.can_resize
    end

    local initialSize = resolveDimension(config.size)
        or resolveDimension(config.min_size)
        or CONFIG.default_size
    initialSize = Vector2.new(
        math.max(initialSize.X, minSize.X),
        math.max(initialSize.Y, minSize.Y)
    )
    initialSize = Vector2.new(
        math.min(initialSize.X, math.max(viewport.X - 24, minSize.X)),
        math.min(initialSize.Y, math.max(viewport.Y - 24, minSize.Y))
    )

    local positionX
    local positionY
    local configuredPosition = resolveDimension(config.position)
    if configuredPosition then
        positionX = configuredPosition.X
        positionY = configuredPosition.Y
    elseif config.center then
        positionX = (viewport.X - initialSize.X) / 2
        positionY = (viewport.Y - initialSize.Y) / 2
    else
        positionX = 40 + ((windowIndex - 1) % 6) * 28
        positionY = 40 + ((windowIndex - 1) % 6) * 28
    end
    positionX = math.clamp(positionX, 0, math.max(0, viewport.X - initialSize.X))
    positionY = math.clamp(positionY, 0, math.max(0, viewport.Y - 48))

    local root = new("Frame", {
        Name = "Window",
        Position = UDim2.new(0, positionX, 0, positionY),
        Size = UDim2.new(0, initialSize.X, 0, initialSize.Y),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ClipsDescendants = false,
        ZIndex = topZ,
    }, windowsContainer)
    topZ = topZ + 10
    local rootScale = new("UIScale", { Scale = 0.94 }, root)

    local function makeShadow(offset, transparency, radius)
        local shadow = new("Frame", {
            Name = "Shadow",
            Position = UDim2.new(0, -offset, 0, -offset),
            Size = UDim2.new(1, offset * 2, 1, offset * 2),
            BackgroundColor3 = COLORS.black,
            BackgroundTransparency = transparency,
            BorderSizePixel = 0,
            ZIndex = 1,
        }, root)
        corner(shadow, radius)
        return shadow
    end
    makeShadow(14, 0.86, 20)
    makeShadow(8, 0.74, 16)
    makeShadow(3, 0.55, 14)

    local main = new("Frame", {
        Name = "Main",
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundColor3 = COLORS.bg,
        BorderSizePixel = 0,
        ClipsDescendants = true,
        ZIndex = 2,
    }, root)
    corner(main, 12)
    stroke(main, COLORS.white, 0.92, 1)
    applyPaint(main, config.background or { COLORS.bg, COLORS.bg2 }, 90)
    main.BackgroundTransparency = config.background_transparency or 0

    local topAccent = new("Frame", {
        Name = "TopAccent",
        Size = UDim2.new(1, 0, 0, 2),
        BackgroundColor3 = COLORS.white,
        BorderSizePixel = 0,
        ZIndex = 3,
    }, main)
    applyPaint(topAccent, { accent, accent2 }, 0)

    local titleBar = new("Frame", {
        Name = "TitleBar",
        Position = UDim2.new(0, 0, 0, 2),
        Size = UDim2.new(1, 0, 0, 46),
        BackgroundColor3 = COLORS.surface,
        BorderSizePixel = 0,
        ZIndex = 3,
    }, main)
    applyPaint(titleBar, config.title_bar or { COLORS.surface, COLORS.surface2 }, 90)
    titleBar.BackgroundTransparency = config.title_bar_transparency or 0

    new("Frame", {
        Name = "Divider",
        Position = UDim2.new(0, 0, 0, 48),
        Size = UDim2.new(1, 0, 0, 1),
        BackgroundColor3 = COLORS.white,
        BackgroundTransparency = 0.92,
        BorderSizePixel = 0,
        ZIndex = 4,
    }, main)
    local divider = main:FindFirstChild("Divider")

    local iconHolder = new("Frame", {
        Name = "Icon",
        Position = UDim2.new(0, 14, 0, 12),
        Size = UDim2.new(0, 26, 0, 26),
        BackgroundColor3 = COLORS.white,
        BorderSizePixel = 0,
        ClipsDescendants = true,
        ZIndex = 5,
    }, titleBar)
    corner(iconHolder, 8)

    if type(config.icon) == "string" and #config.icon > 0 then
        new("ImageLabel", {
            Size = UDim2.new(1, 0, 1, 0),
            BackgroundTransparency = 1,
            Image = config.icon,
            ScaleType = Enum.ScaleType.Crop,
            ZIndex = 6,
        }, iconHolder)
    else
        applyPaint(iconHolder, { accent, accent2 }, 45)
        new("TextLabel", {
            Size = UDim2.new(1, 0, 1, 0),
            BackgroundTransparency = 1,
            Text = "S",
            Font = CONFIG.font_bold,
            TextSize = 14,
            TextColor3 = COLORS.white,
            ZIndex = 6,
        }, iconHolder)
    end

    local hasAuthor = type(config.author) == "string" and #config.author > 0
    local titleLabel = new("TextLabel", {
        Name = "Title",
        Position = UDim2.new(0, 50, 0, hasAuthor and 7 or 0),
        Size = UDim2.new(1, -160, 0, hasAuthor and 18 or 46),
        BackgroundTransparency = 1,
        Text = tostring(title or "Syniox"),
        Font = CONFIG.font_bold,
        TextSize = 14,
        TextColor3 = COLORS.text,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = hasAuthor and Enum.TextYAlignment.Top or Enum.TextYAlignment.Center,
        TextTruncate = Enum.TextTruncate.AtEnd,
        ZIndex = 5,
    }, titleBar)

    if hasAuthor then
        new("TextLabel", {
            Name = "Author",
            Position = UDim2.new(0, 50, 0, 25),
            Size = UDim2.new(1, -160, 0, 14),
            BackgroundTransparency = 1,
            Text = config.author,
            Font = CONFIG.font,
            TextSize = 10,
            TextColor3 = COLORS.textMuted,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextYAlignment = Enum.TextYAlignment.Top,
            TextTruncate = Enum.TextTruncate.AtEnd,
            ZIndex = 5,
        }, titleBar)
    end

    local windowAPI = {}
    local windowData = { root = root, api = windowAPI }

    local closeButton = makeWindowControl(titleBar, "Close", "×", COLORS.danger, function()
        windowAPI:Close()
    end, 17)
    closeButton.Position = UDim2.new(1, -36, 0, 10)

    local maximizeButton = makeWindowControl(titleBar, "Maximize", "□", COLORS.white, function()
        windowAPI:Maximize()
    end, 13)
    maximizeButton.Position = UDim2.new(1, -68, 0, 10)

    local minimizeButton = makeWindowControl(titleBar, "Minimize", "-", COLORS.white, function()
        windowAPI:Minimize()
    end, 17)
    minimizeButton.Position = UDim2.new(1, -100, 0, 10)

    local dragArea = new("Frame", {
        Name = "DragArea",
        Size = UDim2.new(1, -116, 0, 46),
        BackgroundTransparency = 1,
        Active = true,
        ZIndex = 10,
    }, titleBar)

    local tabBar = new("Frame", {
        Name = "TabSelection",
        Position = UDim2.new(0, 12, 0, 56),
        Size = UDim2.new(1, -24, 0, 38),
        BackgroundColor3 = COLORS.surface,
        BackgroundTransparency = 0.35,
        BorderSizePixel = 0,
        ZIndex = 3,
    }, main)
    corner(tabBar, 10)
    stroke(tabBar, COLORS.white, 0.94, 1)

    local tabScroll = new("ScrollingFrame", {
        Name = "TabScrolling",
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ScrollBarThickness = 0,
        ScrollingDirection = Enum.ScrollingDirection.X,
        CanvasSize = UDim2.new(0, 0, 0, 0),
        AutomaticCanvasSize = Enum.AutomaticSize.X,
        ZIndex = 4,
    }, tabBar)
    padding(tabScroll, 4, 4, 4, 4)

    local tabButtons = new("Frame", {
        Name = "TabButtons",
        Size = UDim2.new(0, 0, 1, 0),
        AutomaticSize = Enum.AutomaticSize.X,
        BackgroundTransparency = 1,
        ZIndex = 4,
    }, tabScroll)
    new("UIListLayout", {
        FillDirection = Enum.FillDirection.Horizontal,
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding = UDim.new(0, 4),
        VerticalAlignment = Enum.VerticalAlignment.Center,
        HorizontalAlignment = Enum.HorizontalAlignment.Left,
    }, tabButtons)

    local content = new("Frame", {
        Name = "Tabs",
        Position = UDim2.new(0, 0, 0, 102),
        Size = UDim2.new(1, 0, 1, -118),
        BackgroundTransparency = 1,
        ClipsDescendants = true,
        ZIndex = 3,
    }, main)

    local resizeBottomHit = new("Frame", {
        Name = "ResizeBottom",
        AnchorPoint = Vector2.new(0.5, 1),
        Position = UDim2.new(0.5, 0, 1, 0),
        Size = UDim2.new(1, 0, 0, 14),
        BackgroundTransparency = 1,
        Active = true,
        ZIndex = 12,
    }, main)
    local resizeLine = new("Frame", {
        Name = "Resizer",
        AnchorPoint = Vector2.new(0.5, 1),
        Position = UDim2.new(0.5, 0, 1, -5),
        Size = UDim2.new(0, 52, 0, 3),
        BackgroundColor3 = accent,
        BackgroundTransparency = 0.55,
        BorderSizePixel = 0,
        ZIndex = 13,
    }, resizeBottomHit)
    corner(resizeLine, 2)

    local resizeCorner = new("Frame", {
        Name = "ResizeCorner",
        AnchorPoint = Vector2.new(1, 1),
        Position = UDim2.new(1, -3, 1, -3),
        Size = UDim2.new(0, 16, 0, 16),
        BackgroundTransparency = 1,
        Active = true,
        ZIndex = 12,
    }, main)
    local cornerDots = {}
    local dotPositions = { { 11, 11 }, { 7, 7 }, { 3, 3 } }
    for _, dotPosition in ipairs(dotPositions) do
        local dot = new("Frame", {
            Name = "Grip",
            Position = UDim2.new(0, dotPosition[1], 0, dotPosition[2]),
            Size = UDim2.new(0, 3, 0, 3),
            BackgroundColor3 = accent,
            BackgroundTransparency = 0.5,
            BorderSizePixel = 0,
            ZIndex = 13,
        }, resizeCorner)
        corner(dot, 2)
        table.insert(cornerDots, dot)
    end

    local minimized = false
    local maximized = false
    local savedSize
    local savedPos
    local closeToken = 0

    local function setResizeVisible(visible)
        if canResize and visible then
            resizeBottomHit.Visible = true
            resizeLine.Visible = true
            resizeCorner.Visible = true
        else
            resizeBottomHit.Visible = false
            resizeLine.Visible = false
            resizeCorner.Visible = false
        end
    end

    local resizeMode
    local resizeStart
    local resizeStartSize
    local hoveringBottom = false
    local hoveringCorner = false

    local function beginResize(mode, input)
        if not canResize or minimized or maximized then
            return
        end
        resizeMode = mode
        resizeStart = input.Position
        resizeStartSize = Vector2.new(root.AbsoluteSize.X, root.AbsoluteSize.Y)
        if mode == "bottom" then
            tween(resizeLine, 0.12, {
                BackgroundTransparency = 0.1,
                Size = UDim2.new(0, 72, 0, 4),
            })
        elseif mode == "corner" then
            for _, dot in ipairs(cornerDots) do
                tween(dot, 0.12, { BackgroundTransparency = 0.1 })
            end
        end
        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then
                resizeMode = nil
                if not hoveringBottom then
                    tween(resizeLine, 0.15, {
                        BackgroundTransparency = 0.55,
                        Size = UDim2.new(0, 52, 0, 3),
                    })
                end
                if not hoveringCorner then
                    for _, dot in ipairs(cornerDots) do
                        tween(dot, 0.15, { BackgroundTransparency = 0.5 })
                    end
                end
            end
        end)
    end

    local function updateResize(input)
        if not resizeMode then
            return
        end
        local delta = input.Position - resizeStart
        local width = resizeStartSize.X
        local height = resizeStartSize.Y
        if resizeMode == "corner" then
            width = resizeStartSize.X + delta.X
            height = resizeStartSize.Y + delta.Y
        elseif resizeMode == "bottom" then
            height = resizeStartSize.Y + delta.Y
        end
        local viewportNow = getViewport()
        width = math.clamp(width, minSize.X, math.max(minSize.X, viewportNow.X - root.Position.X.Offset))
        height = math.clamp(height, minSize.Y, math.max(minSize.Y, viewportNow.Y - root.Position.Y.Offset))
        root.Size = UDim2.new(0, width, 0, height)
    end

    connect(UserInputService.InputChanged, function(input)
        if resizeMode and (input.UserInputType == Enum.UserInputType.MouseMovement
            or input.UserInputType == Enum.UserInputType.Touch) then
            updateResize(input)
        end
    end)

    resizeBottomHit.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            beginResize("bottom", input)
        end
    end)
    resizeBottomHit.MouseEnter:Connect(function()
        hoveringBottom = true
        if resizeMode ~= "bottom" then
            tween(resizeLine, 0.15, {
                BackgroundTransparency = 0.12,
                Size = UDim2.new(0, 72, 0, 4),
            })
        end
    end)
    resizeBottomHit.MouseLeave:Connect(function()
        hoveringBottom = false
        if resizeMode ~= "bottom" then
            tween(resizeLine, 0.15, {
                BackgroundTransparency = 0.55,
                Size = UDim2.new(0, 52, 0, 3),
            })
        end
    end)

    resizeCorner.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            beginResize("corner", input)
        end
    end)
    resizeCorner.MouseEnter:Connect(function()
        hoveringCorner = true
        if resizeMode ~= "corner" then
            for _, dot in ipairs(cornerDots) do
                tween(dot, 0.15, { BackgroundTransparency = 0.12 })
            end
        end
    end)
    resizeCorner.MouseLeave:Connect(function()
        hoveringCorner = false
        if resizeMode ~= "corner" then
            for _, dot in ipairs(cornerDots) do
                tween(dot, 0.15, { BackgroundTransparency = 0.5 })
            end
        end
    end)

    local dragging = false
    local dragStart
    local dragStartPosition
    local lastClickTime = 0

    dragArea.InputBegan:Connect(function(input)
        if input.UserInputType ~= Enum.UserInputType.MouseButton1
            and input.UserInputType ~= Enum.UserInputType.Touch then
            return
        end
        local now = os.clock()
        if now - lastClickTime < 0.3 then
            lastClickTime = 0
            dragging = false
            if minimized then
                windowAPI:Minimize()
            else
                windowAPI:Maximize()
            end
            return
        end
        lastClickTime = now
        if minimized or maximized then
            return
        end
        dragging = true
        dragStart = input.Position
        dragStartPosition = root.Position
        focusWindow(windowData)
        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then
                dragging = false
            end
        end)
    end)

    connect(UserInputService.InputChanged, function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement
            or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - dragStart
            local viewportNow = getViewport()
            local nextX = dragStartPosition.X.Offset + delta.X
            local nextY = dragStartPosition.Y.Offset + delta.Y
            nextX = math.clamp(nextX, 0, math.max(0, viewportNow.X - root.AbsoluteSize.X))
            nextY = math.clamp(nextY, 0, math.max(0, viewportNow.Y - 48))
            root.Position = UDim2.new(0, nextX, 0, nextY)
        end
    end)

    local tabs = {}
    local activeTab

    local function styleTab(tab, selected, hovered)
        if selected then
            applyPaint(tab.bg, { accent, accent2 }, 45)
            tab.bg.BackgroundTransparency = 0.12
            tab.stroke.Color = accent
            tab.stroke.Transparency = 0.45
            tween(tab.label, 0.15, { TextColor3 = COLORS.white })
        else
            local gradient = tab.bg:FindFirstChild("SynioxGradient")
            if gradient then
                gradient:Destroy()
            end
            tab.bg.BackgroundColor3 = COLORS.white
            tab.bg.BackgroundTransparency = hovered and 0.94 or 1
            tab.stroke.Color = COLORS.white
            tab.stroke.Transparency = hovered and 0.9 or 1
            tween(tab.label, 0.15, {
                TextColor3 = hovered and COLORS.text or COLORS.textDim,
            })
        end
    end

    local function selectTab(tab)
        if activeTab == tab then
            return
        end
        activeTab = tab
        for _, entry in ipairs(tabs) do
            local selected = entry == tab
            entry.page.Visible = selected
            styleTab(entry, selected, false)
            if selected then
                entry.page.Position = UDim2.new(0, 0, 0, 4)
                tween(entry.page, 0.18, { Position = UDim2.new(0, 0, 0, 0) })
            end
        end
        task.delay(0.05, function()
            local targetX = tab.button.AbsolutePosition.X - tabScroll.AbsolutePosition.X
                + tabScroll.CanvasPosition.X
                - (tabScroll.AbsoluteSize.X - tab.button.AbsoluteSize.X) / 2
            local maxX = math.max(0, tabButtons.AbsoluteSize.X - tabScroll.AbsoluteSize.X + 8)
            targetX = math.clamp(targetX, 0, maxX)
            tween(tabScroll, 0.2, { CanvasPosition = Vector2.new(targetX, 0) })
        end)
    end

    local function addTab(name)
        name = tostring(name or "Tab")
        local button = new("TextButton", {
            Name = "TabButton",
            Size = UDim2.new(0, textWidth(name, 12, CONFIG.font) + 26, 1, -8),
            BackgroundTransparency = 1,
            Text = "",
            AutoButtonColor = false,
            ClipsDescendants = true,
            LayoutOrder = #tabs + 1,
            ZIndex = 5,
        }, tabButtons)
        local bg = new("Frame", {
            Name = "BG",
            Size = UDim2.new(1, 0, 1, 0),
            BackgroundColor3 = COLORS.white,
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            ZIndex = 4,
        }, button)
        corner(bg, 7)
        local tabStroke = stroke(bg, COLORS.white, 1, 1)
        local label = new("TextLabel", {
            Name = "Label",
            Size = UDim2.new(1, 0, 1, 0),
            BackgroundTransparency = 1,
            Text = name,
            Font = CONFIG.font,
            TextSize = 12,
            TextColor3 = COLORS.textDim,
            TextXAlignment = Enum.TextXAlignment.Center,
            TextYAlignment = Enum.TextYAlignment.Center,
            TextTruncate = Enum.TextTruncate.AtEnd,
            ZIndex = 5,
        }, button)

        local page = new("Frame", {
            Name = "Tab",
            Size = UDim2.new(1, 0, 1, 0),
            BackgroundTransparency = 1,
            Visible = false,
            ZIndex = 3,
        }, content)
        local scroller = new("ScrollingFrame", {
            Name = "TabScroller",
            Size = UDim2.new(1, 0, 1, 0),
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            ScrollBarThickness = 4,
            ScrollBarImageColor3 = accent,
            ScrollBarImageTransparency = 0.35,
            CanvasSize = UDim2.new(0, 0, 0, 0),
            AutomaticCanvasSize = Enum.AutomaticSize.Y,
            ScrollingDirection = Enum.ScrollingDirection.Y,
            ZIndex = 4,
        }, page)
        padding(scroller, 12, 16, 4, 12)
        new("UIListLayout", {
            Padding = UDim.new(0, 8),
            SortOrder = Enum.SortOrder.LayoutOrder,
        }, scroller)

        local tabApi = createContainer(scroller)
        local tab = {
            name = name,
            button = button,
            bg = bg,
            stroke = tabStroke,
            label = label,
            page = page,
            scroller = scroller,
            api = tabApi,
        }
        table.insert(tabs, tab)

        button.MouseButton1Click:Connect(function()
            selectTab(tab)
        end)
        button.MouseEnter:Connect(function()
            if activeTab ~= tab then
                styleTab(tab, false, true)
            end
        end)
        button.MouseLeave:Connect(function()
            if activeTab ~= tab then
                styleTab(tab, false, false)
            end
        end)

        function tabApi:Show()
            selectTab(tab)
        end

        if #tabs == 1 then
            selectTab(tab)
        end
        return tabApi, page
    end

    function windowAPI:AddTab(name)
        return addTab(name)
    end

    function windowAPI:SetTitle(text)
        titleLabel.Text = tostring(text or "")
    end

    function windowAPI:Focus()
        focusWindow(windowData)
    end

    function windowAPI:GetFrame()
        return root
    end

    function windowAPI:Show()
        closeToken = closeToken + 1
        if minimized then
            windowAPI:Minimize()
        end
        if not root.Visible then
            root.Visible = true
            rootScale.Scale = 0.92
        end
        tween(rootScale, 0.22, { Scale = 1 }, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
        focusWindow(windowData)
        updateDock()
    end

    function windowAPI:Close()
        if not root.Visible then
            return
        end
        closeToken = closeToken + 1
        local token = closeToken
        tween(rootScale, 0.16, { Scale = 0.92 })
        task.delay(0.14, function()
            if token ~= closeToken or not root.Parent then
                return
            end
            root.Visible = false
            rootScale.Scale = 1
            updateDock()
        end)
    end

    function windowAPI:Minimize()
        if maximized then
            windowAPI:Maximize()
            return
        end
        minimized = not minimized
        if minimized then
            savedSize = root.Size
            content.Visible = false
            tabBar.Visible = false
            divider.Visible = false
            setResizeVisible(false)
            minimizeButton.Text = "+"
            tween(root, 0.22, {
                Size = UDim2.new(0, root.AbsoluteSize.X, 0, 48),
            }, Enum.EasingStyle.Quint)
        else
            content.Visible = true
            tabBar.Visible = true
            divider.Visible = true
            setResizeVisible(canResize)
            minimizeButton.Text = "-"
            tween(root, 0.22, {
                Size = savedSize or UDim2.new(0, root.AbsoluteSize.X, 0, initialSize.Y),
            }, Enum.EasingStyle.Quint)
        end
    end

    function windowAPI:Maximize()
        if minimized then
            windowAPI:Minimize()
            return
        end
        if maximized then
            maximized = false
            setResizeVisible(canResize)
            tween(root, 0.3, {
                Position = savedPos or UDim2.new(0, 40, 0, 40),
                Size = savedSize or UDim2.new(0, initialSize.X, 0, initialSize.Y),
            }, Enum.EasingStyle.Quint)
        else
            savedPos = root.Position
            savedSize = root.Size
            maximized = true
            setResizeVisible(false)
            local viewportNow = getViewport()
            tween(root, 0.3, {
                Position = UDim2.new(0, 6, 0, 6),
                Size = UDim2.new(0, viewportNow.X - 12, 0, viewportNow.Y - 12),
            }, Enum.EasingStyle.Quint)
        end
    end

    table.insert(windows, windowData)
    setResizeVisible(canResize)
    rootScale.Scale = 0.94
    tween(rootScale, 0.3, { Scale = 1 }, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
    focusWindow(windowData)
    return windowAPI, root
end

local notificationIndex = 0

local function notify(config)
    if type(config) == "string" then
        config = { Title = config }
    end
    config = type(config) == "table" and config or {}
    notificationIndex = notificationIndex + 1

    local width = math.min(320, math.max(240, getViewport().X - 32))
    local duration = tonumber(config.Duration) or 5
    local closed = false

    local wrapper = new("Frame", {
        Name = "Notification",
        Size = UDim2.new(0, width, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
        ClipsDescendants = true,
        LayoutOrder = -notificationIndex,
    }, notificationContainer)

    local card = new("Frame", {
        Name = "Card",
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        Position = UDim2.new(1, 0, 0, 0),
        BackgroundColor3 = COLORS.surface,
        BackgroundTransparency = 0.02,
        BorderSizePixel = 0,
        ClipsDescendants = true,
        ZIndex = 2,
    }, wrapper)
    corner(card, 12)
    stroke(card, COLORS.white, 0.9, 1)

    local accentBar = new("Frame", {
        Name = "Accent",
        Size = UDim2.new(0, 3, 1, 0),
        BackgroundColor3 = config.Color or CONFIG.main_color,
        BorderSizePixel = 0,
        ZIndex = 3,
    }, card)
    applyPaint(accentBar, { config.Color or CONFIG.main_color, CONFIG.accent2 }, 90)

    local contentFrame = new("Frame", {
        Name = "Content",
        Size = UDim2.new(1, -28, 0, 0),
        Position = UDim2.new(0, 16, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
        ZIndex = 3,
    }, card)
    padding(contentFrame, 0, 0, 14, 16)
    new("UIListLayout", {
        Padding = UDim.new(0, 4),
        SortOrder = Enum.SortOrder.LayoutOrder,
    }, contentFrame)

    new("TextLabel", {
        Name = "Title",
        Size = UDim2.new(1, -24, 0, 18),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
        Text = tostring(config.Title or "Notification"),
        Font = CONFIG.font_bold,
        TextSize = 13,
        TextColor3 = COLORS.text,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Top,
        TextWrapped = true,
        ZIndex = 4,
    }, contentFrame)

    if config.Content then
        new("TextLabel", {
            Name = "Content",
            Size = UDim2.new(1, -20, 0, 0),
            AutomaticSize = Enum.AutomaticSize.Y,
            BackgroundTransparency = 1,
            Text = tostring(config.Content),
            Font = CONFIG.font,
            TextSize = 12,
            TextColor3 = COLORS.textDim,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextYAlignment = Enum.TextYAlignment.Top,
            TextWrapped = true,
            ZIndex = 4,
        }, contentFrame)
    end

    local closeButton = new("TextButton", {
        Name = "Close",
        Position = UDim2.new(1, -28, 0, 10),
        Size = UDim2.new(0, 22, 0, 22),
        BackgroundTransparency = 1,
        Text = "×",
        Font = CONFIG.font_bold,
        TextSize = 15,
        TextColor3 = COLORS.textMuted,
        AutoButtonColor = false,
        ZIndex = 5,
    }, card)
    corner(closeButton, 6)

    local progress
    if duration > 0 then
        local progressBackground = new("Frame", {
            Name = "ProgressBG",
            AnchorPoint = Vector2.new(0, 1),
            Position = UDim2.new(0, 0, 1, 0),
            Size = UDim2.new(1, 0, 0, 2),
            BackgroundColor3 = COLORS.white,
            BackgroundTransparency = 0.92,
            BorderSizePixel = 0,
            ZIndex = 4,
        }, card)
        progress = new("Frame", {
            Name = "Progress",
            Size = UDim2.new(1, 0, 1, 0),
            BackgroundColor3 = config.Color or CONFIG.main_color,
            BorderSizePixel = 0,
            ZIndex = 5,
        }, progressBackground)
    end

    local function close()
        if closed then
            return
        end
        closed = true
        tween(card, 0.25, {
            Position = UDim2.new(1, 0, 0, 0),
        }, Enum.EasingStyle.Quint, Enum.EasingDirection.In)
        task.delay(0.12, function()
            if not wrapper or not wrapper.Parent then
                return
            end
            local height = wrapper.AbsoluteSize.Y
            wrapper.AutomaticSize = Enum.AutomaticSize.None
            wrapper.Size = UDim2.new(0, width, 0, height)
            tween(wrapper, 0.2, {
                Size = UDim2.new(0, width, 0, 0),
            }, Enum.EasingStyle.Quint, Enum.EasingDirection.In)
        end)
        task.delay(0.45, function()
            if wrapper and wrapper.Parent then
                wrapper:Destroy()
            end
        end)
    end

    if config.CanClose == false then
        closeButton.Visible = false
    else
        closeButton.MouseEnter:Connect(function()
            tween(closeButton, 0.12, {
                BackgroundColor3 = COLORS.white,
                BackgroundTransparency = 0.9,
                TextColor3 = COLORS.white,
            })
        end)
        closeButton.MouseLeave:Connect(function()
            tween(closeButton, 0.12, {
                BackgroundTransparency = 1,
                TextColor3 = COLORS.textMuted,
            })
        end)
        closeButton.MouseButton1Click:Connect(close)
    end

    task.defer(function()
        tween(card, 0.35, {
            Position = UDim2.new(0, 0, 0, 0),
        }, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
    end)

    if duration > 0 then
        task.delay(0.35, function()
            if progress and not closed then
                tween(progress, duration, {
                    Size = UDim2.new(0, 0, 1, 0),
                }, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut)
            end
        end)
        task.delay(duration + 0.35, close)
    end

    return {
        Close = close,
        Frame = card,
        Wrapper = wrapper,
    }
end

function library:FormatWindows()
    local viewportNow = getViewport()
    local x = 40
    local y = 40
    for _, windowData in ipairs(windows) do
        if windowData.root.Visible then
            if x + windowData.root.AbsoluteSize.X > viewportNow.X - 20 then
                x = 40
                y = y + 32
            end
            windowData.root.Position = UDim2.new(0, x, 0, y)
            x = x + 32
            y = y + 32
        end
    end
end

function library:Toggle()
    toggleGui()
end

function library:Notify(config)
    return notify(config)
end

function library:ClearNotifications()
    for _, child in ipairs(notificationContainer:GetChildren()) do
        if child:IsA("Frame") then
            child:Destroy()
        end
    end
end

function library:SetToggleKey(key)
    if typeof(key) == "EnumItem" and key.EnumType == Enum.KeyCode then
        CONFIG.toggle_key = key
    end
end

function library:Destroy()
    for _, connection in ipairs(connections) do
        pcall(function()
            connection:Disconnect()
        end)
    end
    connections = {}
    if screenGui and screenGui.Parent then
        screenGui:Destroy()
    end
end

library.Gui = screenGui
library.Config = CONFIG
library.Colors = COLORS
library.Windows = windows
library.Notifications = notificationContainer

screenGui.AncestryChanged:Connect(function()
    if not screenGui.Parent then
        for _, connection in ipairs(connections) do
            pcall(function()
                connection:Disconnect()
            end)
        end
        connections = {}
    end
end)

return library
