local Players = game:GetService("Players")
local player = Players.LocalPlayer
local VirtualInputManager = game:GetService("VirtualInputManager")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local muscleEvent = player:WaitForChild("muscleEvent")
local leaderstats = player:WaitForChild("leaderstats")
local rebirthsStat = leaderstats:WaitForChild("Rebirths")
local rEvents = ReplicatedStorage:WaitForChild("rEvents")

_G.Players = game:GetService("Players")
_G.player = _G.Players.LocalPlayer
_G.VirtualInputManager = game:GetService("VirtualInputManager")
_G.ReplicatedStorage = game:GetService("ReplicatedStorage")
_G.muscleEvent = _G.player:WaitForChild("muscleEvent")
_G.leaderstats = _G.player:WaitForChild("leaderstats")
_G.rebirthsStat = _G.leaderstats:WaitForChild("Rebirths")
_G.rEvents = _G.ReplicatedStorage:WaitForChild("rEvents")


local library = loadstring(game:HttpGet("https://raw.githubusercontent.com/SynioxStudios/Syn-Paid-Ui/refs/heads/main/SynioxGui.txt"))()
_G.library = library 

local player = game.Players.LocalPlayer
_G.player = player 

local displayName = player.DisplayName
_G.displayName = displayName 

local window = library:AddWindow("Syniox Private | Muscle Legends || HI - ".. displayName, {
    title_bar = {
        Color3.fromRGB(180, 0, 255),
        Color3.fromRGB(60, 0, 100),
        Color3.fromRGB(0, 0, 0)
    }, 
    title_bar_transparency = 0.1, 
    background = {
        Color3.fromRGB(10, 5, 15),
        Color3.fromRGB(15, 10, 25),
        Color3.fromRGB(0, 0, 0)
    }, 
    background_transparency = 0.1, 
    main_color = Color3.fromRGB(104, 34, 139),
    min_size = Vector2.new(450, 300), 
    can_resize = true 
})
_G.window = window

local rebirthTab = window:AddTab("Fast Rebirth")

local petsFolder = player:WaitForChild("petsFolder")

local function formatNumber(num)
    if num >= 1e15 then return string.format("%.2fQa", num/1e15) end
    if num >= 1e12 then return string.format("%.2fT", num/1e12) end
    if num >= 1e9 then return string.format("%.2fB", num/1e9) end
    if num >= 1e6 then return string.format("%.2fM", num/1e6) end
    if num >= 1e3 then return string.format("%.2fK", num/1e3) end
    return string.format("%.0f", num)
end

local isRunning = false
local startTime = 0
local totalElapsed = 0
local initialRebirths = rebirthsStat.Value

local serverLabel = rebirthTab:AddLabel("📊 Stats:")
serverLabel.TextSize = 17
local timeLabel = rebirthTab:AddLabel("0d 0h 0m 0s - Inactive")
local paceLabel = rebirthTab:AddLabel("Rebirth Pace: /Hour | /Day | /Week")
local averagePaceLabel = rebirthTab:AddLabel("Average Rebirth Pace: /Hour | /Day | /Week")

paceLabel.TextSize = 15
averagePaceLabel.TextSize = 15
timeLabel.TextSize = 15
timeLabel.TextColor3 = Color3.fromRGB(255, 50, 50)

local rebirthsStatsLabel = rebirthTab:AddLabel("Rebirths: "..formatNumber(rebirthsStat.Value).." | Gained: 0")
rebirthsStatsLabel.TextSize = 15

local lastRebirthTime = tick()
local lastRebirthValue = rebirthsStat.Value

local function updateRebirthsLabel()
    local gained = rebirthsStat.Value - initialRebirths
    rebirthsStatsLabel.Text = string.format("Rebirths: %s | Gained: %s",
        formatNumber(rebirthsStat.Value),
        formatNumber(gained))
end

local function updateUI()
    local currentTime = tick()
    local elapsed = isRunning and (currentTime - startTime + totalElapsed) or totalElapsed

    local days = math.floor(elapsed / 86400)
    local hours = math.floor((elapsed % 86400) / 3600)
    local minutes = math.floor((elapsed % 3600) / 60)
    local seconds = math.floor(elapsed % 60)

    local statusText = isRunning and "Rebirthing" or (elapsed > 0 and "Rebirthing Paused" or "Fast Reb Inactive")
    timeLabel.Text = string.format("%dd %dh %dm %ds - %s", days, hours, minutes, seconds, statusText)

    if isRunning then
        timeLabel.TextColor3 = Color3.fromRGB(50, 255, 50)
    elseif elapsed > 0 then
        timeLabel.TextColor3 = Color3.fromRGB(255, 165, 0)
    else
        timeLabel.TextColor3 = Color3.fromRGB(255, 50, 50)
    end
end

local paceHistoryHour = {}
local paceHistoryDay = {}
local paceHistoryWeek = {}
local maxHistoryLength = 20
local rebirthCount = 0
local savedPaceHour = 0
local savedPaceDay = 0
local savedPaceWeek = 0
local savedAvgHour = 0
local savedAvgDay = 0
local savedAvgWeek = 0

local function calculatePaceOnRebirth()
    rebirthCount = rebirthCount + 1
    if rebirthCount < 2 then
        lastRebirthTime = tick()
        lastRebirthValue = rebirthsStat.Value
        return
    end

    if not isRunning then return end

    local now = tick()
    local gained = rebirthsStat.Value - lastRebirthValue

    if gained > 0 then
        local avgTimePerRebirth = (now - lastRebirthTime) / gained
        local paceHour = 3600 / avgTimePerRebirth
        local paceDay = 86400 / avgTimePerRebirth
        local paceWeek = 604800 / avgTimePerRebirth

        savedPaceHour = paceHour
        savedPaceDay = paceDay
        savedPaceWeek = paceWeek

        paceLabel.Text = string.format("Pace: %s / Hour | %s / Day | %s / Week",
            formatNumber(paceHour), formatNumber(paceDay), formatNumber(paceWeek))

        table.insert(paceHistoryHour, paceHour)
        table.insert(paceHistoryDay, paceDay)
        table.insert(paceHistoryWeek, paceWeek)

        if #paceHistoryHour > maxHistoryLength then
            table.remove(paceHistoryHour, 1)
            table.remove(paceHistoryDay, 1)
            table.remove(paceHistoryWeek, 1)
        end

        local function average(tbl)
            local sum = 0
            for _, v in ipairs(tbl) do sum = sum + v end
            return #tbl > 0 and (sum / #tbl) or 0
        end

        local avgHour = average(paceHistoryHour)
        local avgDay = average(paceHistoryDay)
        local avgWeek = average(paceHistoryWeek)

        savedAvgHour = avgHour
        savedAvgDay = avgDay
        savedAvgWeek = avgWeek

        averagePaceLabel.Text = string.format("Average Pace: %s / Hour | %s / Day | %s / Week",
            formatNumber(avgHour), formatNumber(avgDay), formatNumber(avgWeek))

        lastRebirthTime = now
        lastRebirthValue = rebirthsStat.Value
    end
end

rebirthsStat:GetPropertyChangedSignal("Value"):Connect(function()
    calculatePaceOnRebirth()
    updateRebirthsLabel()
end)

local function equipPets(reqs)
    for _, folder in pairs(petsFolder:GetChildren()) do
        if folder:IsA("Folder") then
            for _, pet in pairs(folder:GetChildren()) do
                rEvents.equipPetEvent:FireServer("unequipPet", pet)
            end
        end
    end
    task.wait(0.1)

    for petName, count in pairs(reqs) do
        local equipped = 0
        for _, folder in pairs(petsFolder:GetChildren()) do
            if folder:IsA("Folder") then
                for _, pet in pairs(folder:GetChildren()) do
                    if pet.Name == petName and equipped < count then
                        rEvents.equipPetEvent:FireServer("equipPet", pet)
                        equipped = equipped + 1
                    end
                end
            end
        end
    end
end

local function doRebirth()
    local rebirths = rebirthsStat.Value
    local strengthTarget = 5000 + (rebirths * 2550)

    local ultimatesFolder = player:FindFirstChild("ultimatesFolder")
    if ultimatesFolder then
        local goldenRebirth = ultimatesFolder:FindFirstChild("Golden Rebirth")
        if goldenRebirth then
            strengthTarget = math.floor(strengthTarget * (1 - (goldenRebirth.Value * 0.1)))
        end
    end

    while isRunning and leaderstats.Strength.Value < strengthTarget do
        local reps = player.MembershipType == Enum.MembershipType.Premium and 12 or 20
        for _ = 1, reps do
            muscleEvent:FireServer("rep")
        end
        task.wait(0.02)
    end

    if isRunning and leaderstats.Strength.Value >= strengthTarget then
        equipPets({
            ["Tribal Overlord"] = 4,
            ["Titanium Hydra"] = 1
        })
        task.wait(0.25)

        local before = rebirthsStat.Value
        repeat
            rEvents.rebirthRemote:InvokeServer("rebirthRequest")
            task.wait(0.05)
        until rebirthsStat.Value > before or not isRunning
    end
end

local function fastRebirthLoop()
    while isRunning do
        equipPets({
            ["Swift Samurai"] = 4,
            ["Omega Overlord"] = 1,
            ["Powercore Hound"] = 1,
            ["Titanium Hydra"] = 1
        })
        doRebirth()
        task.wait(0.5)
    end
end

rebirthTab:AddLabel("")
rebirthTab:AddLabel("🔄️ Rebirth:").TextSize = 17

rebirthTab:AddSwitch("Fast Rebirth", function(state)
    isRunning = state

    if state then
        startTime = tick()
        if savedPaceHour > 0 then
            paceLabel.Text = string.format("Pace: %s / Hour | %s / Day | %s / Week",
                formatNumber(savedPaceHour), formatNumber(savedPaceDay), formatNumber(savedPaceWeek))
            averagePaceLabel.Text = string.format("Average Pace: %s / Hour | %s / Day | %s / Week",
                formatNumber(savedAvgHour), formatNumber(savedAvgDay), formatNumber(savedAvgWeek))
        end
        task.spawn(fastRebirthLoop)
    else
        totalElapsed = totalElapsed + (tick() - startTime)
        updateUI()
    end
end)

task.spawn(function()
    while true do
        updateUI()
        task.wait(0.1)
    end
end)

rebirthTab:AddButton("⚙️ Industrial Bar Lift", function()
    local character = player.Character
    if character and character:FindFirstChild("HumanoidRootPart") then
        character.HumanoidRootPart.CFrame = CFrame.new(-5492.24, 81.82, 4644.04)
        task.wait(0.5)
        local machine = findMachine("Industrial Bar Lift")
        if machine and machine:FindFirstChild("interactSeat") then
            local retryCount = 0
            repeat
                task.wait(0.2)
                pressE()
                retryCount = retryCount + 1
            until (player.Character and player.Character.Humanoid.Sit) or retryCount > 10
        end
    end
end)

rebirthTab:AddButton("🏴 Full FPS Boost", function()
    local lighting = game:GetService("Lighting")
    local players = game:GetService("Players")
    local lp = players.LocalPlayer

    lighting.Brightness = 0
    lighting.ClockTime = 0
    lighting.GlobalShadows = false
    lighting.ExposureCompensation = -10
    lighting.OutdoorAmbient = Color3.new(0, 0, 0)
    lighting.Ambient = Color3.new(0, 0, 0)
    
    for _, v in pairs(lighting:GetChildren()) do
        v:Destroy()
    end

    for _, obj in pairs(workspace:GetDescendants()) do
        if obj:IsA("BasePart") then
            obj.Color = Color3.new(0, 0, 0)
            obj.Material = Enum.Material.SmoothPlastic
        elseif obj:IsA("Texture") or obj:IsA("Decal") or obj:IsA("MeshPart") or obj:IsA("SpecialMesh") then
            obj:Destroy()
        elseif obj:IsA("ParticleEmitter") or obj:IsA("Light") or obj:IsA("Fire") or obj:IsA("Smoke") then
            obj:Destroy()
        end
    end

    if lp and lp:FindFirstChild("PlayerGui") then
        for _, gui in pairs(lp.PlayerGui:GetChildren()) do
            if gui:IsA("ScreenGui") and gui.Name ~= "TouchGui" then
                gui.Enabled = false
            end
        end
    end
end)

rebirthTab:AddSwitch("⏳ Anti Afk", function(Value)
    if Value then
        _G.AntiAfkActive = true
        _G.AntiAfkLoopActive = true
        
        local vu = game:GetService("VirtualUser")
        local TweenService = game:GetService("TweenService")
        local RunService = game:GetService("RunService")
        local Stats = game:GetService("Stats")
        local player = game:GetService("Players").LocalPlayer
        local playerGui = player:WaitForChild("PlayerGui")

        _G.antiAfkConnection = player.Idled:Connect(function()
            if _G.AntiAfkActive then
                vu:CaptureController()
                vu:ClickButton2(Vector2.new())
            end
        end)

        local ScreenGui = Instance.new("ScreenGui")
        local MainFrame = Instance.new("Frame")
        local UICorner = Instance.new("UICorner")
        local UIStroke = Instance.new("UIStroke")
        local ContentFrame = Instance.new("Frame")
        local UIListLayout = Instance.new("UIListLayout")

        ScreenGui.Name = "Str_Premium_AFK"
        ScreenGui.Parent = playerGui
        ScreenGui.ResetOnSpawn = false
        ScreenGui.DisplayOrder = 5
        ScreenGui.IgnoreGuiInset = true

        MainFrame.Name = "MainFrame"
        MainFrame.Parent = ScreenGui
        MainFrame.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
        MainFrame.BackgroundTransparency = 0.2
        MainFrame.BorderSizePixel = 0
        MainFrame.Position = UDim2.new(1, 20, 0.5, -50)
        MainFrame.Size = UDim2.new(0, 140, 0, 95)
        MainFrame.Active = true
        MainFrame.Draggable = true
        
        UICorner.CornerRadius = UDim.new(0, 12)
        UICorner.Parent = MainFrame

        UIStroke.Parent = MainFrame
        UIStroke.Thickness = 1.5
        UIStroke.Color = Color3.fromRGB(40, 40, 40)
        UIStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border

        ContentFrame.Parent = MainFrame
        ContentFrame.BackgroundTransparency = 1
        ContentFrame.Size = UDim2.new(1, 0, 1, 0)
        ContentFrame.Active = false
        
        UIListLayout.Parent = ContentFrame
        UIListLayout.SortOrder = Enum.SortOrder.LayoutOrder
        UIListLayout.Padding = UDim.new(0, 2)
        UIListLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
        UIListLayout.VerticalAlignment = Enum.VerticalAlignment.Center

        local function CreateRow(icon, color)
            local lbl = Instance.new("TextLabel")
            lbl.Parent = ContentFrame
            lbl.Size = UDim2.new(1, -20, 0, 25)
            lbl.BackgroundTransparency = 1
            lbl.TextColor3 = Color3.fromRGB(255, 255, 255)
            lbl.TextSize = 13
            lbl.Font = Enum.Font.GothamMedium
            lbl.RichText = true
            lbl.Text = string.format("<font color='rgb(%d,%d,%d)'>%s</font>", color.R*255, color.G*255, color.B*255, icon)
            lbl.TextXAlignment = Enum.TextXAlignment.Left
            return lbl
        end

        local TimerLabel = CreateRow("🕒", Color3.fromRGB(255, 50, 50))
        local FPSLabel = CreateRow("🚀", Color3.fromRGB(50, 255, 100))
        local MSLabel = CreateRow("📡", Color3.fromRGB(50, 150, 255))

        TweenService:Create(MainFrame, TweenInfo.new(0.6, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
            Position = UDim2.new(1, -155, 0.5, -50)
        }):Play()

        local startTime = os.time()
        local currentFPS = 60
        
        local fpsUpdateConn
        fpsUpdateConn = RunService.RenderStepped:Connect(function(dt)
            if not _G.AntiAfkActive then 
                fpsUpdateConn:Disconnect()
                return 
            end
            currentFPS = math.floor(1/dt)
        end)

        task.spawn(function()
            while _G.AntiAfkActive and _G.AntiAfkLoopActive do
                local diff = os.time() - startTime
                TimerLabel.Text = string.format("<font color='rgb(255,50,50)'>🕒</font> %02d:%02d:%02d", math.floor(diff/3600), math.floor((diff%3600)/60), diff%60)
                
                FPSLabel.Text = string.format("<font color='rgb(50,255,100)'>🚀</font> %d FPS", currentFPS)
                
                local pingStat = Stats.Network.ServerStatsItem:FindFirstChild("Data Ping")
                local ping = pingStat and math.floor(pingStat:GetValue()) or 0
                MSLabel.Text = string.format("<font color='rgb(50,150,255)'>📡</font> %d MS", ping)
                
                task.wait(0.5)
            end
        end)

    else
        _G.AntiAfkActive = false
        _G.AntiAfkLoopActive = false
        if _G.antiAfkConnection then
            _G.antiAfkConnection:Disconnect()
            _G.antiAfkConnection = nil
        end
        
        local player = game:GetService("Players").LocalPlayer
        local playerGui = player and player:FindFirstChild("PlayerGui")
        if playerGui then
            local oldGui = playerGui:FindFirstChild("Str_Premium_AFK")
            if oldGui then
                local frame = oldGui:FindFirstChild("MainFrame")
                if frame then
                    local TweenService = game:GetService("TweenService")
                    TweenService:Create(frame, TweenInfo.new(0.4, Enum.EasingStyle.Quart, Enum.EasingDirection.In), {
                        Position = UDim2.new(1, 20, 0.5, -50)
                    }):Play()
                    task.wait(0.4)
                end
                oldGui:Destroy()
            end
        end
    end
end)

rebirthTab:AddButton("🗑️ Anti-Lag", function()
    local workspace = game:GetService("Workspace")
    
    for _, v in pairs(workspace:GetDescendants()) do
        if v:IsA("Part") or v:IsA("MeshPart") then
            if v.Transparency == 1 or v.Parent:IsA("Accessory") then
                continue
            end
            
            if v.Name == "Leaf" or v.Name == "Grass" or v.Name == "Bush" or v.Name == "SmallRock" or v.Name == "Pebble" then
                v:Destroy()
            end
        elseif v:IsA("Decal") or v:IsA("Texture") then
            v:Destroy()
        end
    end

    sethiddenproperty(game:GetService("Lighting"), "Technology", Enum.Technology.Compatibility)
    
    for _, v in pairs(game:GetService("Lighting"):GetChildren()) do
        if v:IsA("PostEffect") or v:IsA("BloomEffect") or v:IsA("BlurEffect") or v:IsA("SunRaysEffect") then
            v.Enabled = false
        end
    end

    game:GetService("StarterGui"):SetCore("SendNotification", {
        Title = "Syniox Hub",
        Text = "Map Cleared & Lag Reduced!",
        Duration = 3
    })
end)

local ProteinEggLabel = rebirthTab:AddLabel("Protein Eggs Owned: 0")
ProteinEggLabel.TextSize = 14

task.spawn(function()
	while true do
		local proteinEggCount = 0
		local tropicalShakeCount = 0
		local backpack = player:FindFirstChild("Backpack")
		if backpack then
			for _, item in ipairs(backpack:GetChildren()) do
				if item.Name == "Protein Egg" then 
					proteinEggCount = proteinEggCount + 1
				elseif item.Name == "Tropical Shake" then 
					tropicalShakeCount = tropicalShakeCount + 1 
				end
			end
		end
		ProteinEggLabel.Text = "Protein Eggs: " .. proteinEggCount
		task.wait(7.5)
	end
end)

local ProteinEggBoostLabel = rebirthTab:AddLabel("Protein Egg Boost: 00:00")
ProteinEggBoostLabel.TextSize = 14

local function formatTime(seconds)
    local m = math.floor(seconds / 60)
    local s = seconds % 60
    return string.format("%02d:%02d", m, s)
end

task.spawn(function()
    while true do
        local boostTimersFolder = game.Players.LocalPlayer:FindFirstChild("boostTimersFolder")
        if boostTimersFolder then
            local boost = boostTimersFolder:FindFirstChild("Protein Egg")
            if boost and boost:IsA("IntValue") then
                local seconds = boost.Value
                ProteinEggBoostLabel.Text = "Protein Egg Timer: " .. formatTime(seconds)
            else
                ProteinEggBoostLabel.Text = "Protein Egg Timer: 00:00"
            end
        else
            ProteinEggBoostLabel.Text = "Protein Egg Timer: 00:00"
        end
        task.wait(0.5)
    end
end)

local function useEggs()
    local boost = game.Players.LocalPlayer.boostTimersFolder:FindFirstChild("Protein Egg")
    if boost and boost:IsA("IntValue") then
        local seconds = boost.Value
        if seconds >= 5 then
            return
        end
    end
    
    local tool = player.Character:FindFirstChild("Protein Egg") or player.Backpack:FindFirstChild("Protein Egg")
    if tool then
        muscleEvent:FireServer("proteinEgg", tool)
    end
end

local running1 = false

task.spawn(function()
    while true do
        if running1 then
            useEggs()
            task.wait(1800)
        else
            task.wait(1)
        end
    end
end)

local autoEggSwitch = rebirthTab:AddSwitch("Auto Eat Egg 30 Min", function(state)
    running1 = state
    if state then
        useEggs()
    end
end)

_G.StrTab = _G.window:AddTab("Fast Strength")

function _G.formatNumber(num)
    if num >= 1e15 then return string.format("%.2fQa", num/1e15) end
    if num >= 1e12 then return string.format("%.2fT", num/1e12) end
    if num >= 1e9 then return string.format("%.2fB", num/1e9) end
    if num >= 1e6 then return string.format("%.2fM", num/1e6) end
    if num >= 1e3 then return string.format("%.2fK", num/1e3) end
    return string.format("%.0f", num)
end

_G.strengthStat = _G.leaderstats:WaitForChild("Strength")
_G.durabilityStat = _G.player:FindFirstChild("Durability") or _G.leaderstats:FindFirstChild("Durability")
if not _G.durabilityStat then
    _G.durabilityStat = Instance.new("IntValue")
    _G.durabilityStat.Name = "Durability"
    _G.durabilityStat.Parent = _G.player
    _G.durabilityStat.Value = 0
end

_G.StrTab:AddLabel("📊 Stats:").TextSize = 17
_G.stopwatchLabel = _G.StrTab:AddLabel("0d 0h 0m 0s - Fast Rep Inactive")
_G.stopwatchLabel.TextSize = 15
_G.stopwatchLabel.TextColor3 = Color3.fromRGB(255, 50, 50)

_G.projectedStrengthLabel = _G.StrTab:AddLabel("Strength: /Hour | /Day | /Week")
_G.projectedStrengthLabel.TextSize = 15
_G.averageStrengthLabel = _G.StrTab:AddLabel("Average: /Hour | /Day | /Week")
_G.averageStrengthLabel.TextSize = 15
_G.projectedDurabilityLabel = _G.StrTab:AddLabel("Dura: /Hour | /Day | /Week")
_G.projectedDurabilityLabel.TextSize = 15
_G.averageDurabilityLabel = _G.StrTab:AddLabel("Average: /Hour | /Day | /Week")
_G.averageDurabilityLabel.TextSize = 15
_G.StrTab:AddLabel("")

_G.strengthLabel = _G.StrTab:AddLabel("Strength: " .. _G.formatNumber(_G.strengthStat.Value) .. " | Gained: 0")
_G.strengthLabel.TextSize = 15
_G.durabilityLabel = _G.StrTab:AddLabel("Durability: " .. _G.formatNumber(_G.durabilityStat.Value) .. " | Gained: 0")
_G.durabilityLabel.TextSize = 15

_G.startTime = 0
_G.pausedElapsedTime = 0

_G.runFastRep = false
_G.trackingStarted = false

_G.strengthHistory = {}
_G.durabilityHistory = {}
_G.calculationInterval = 10

_G.initialStrength = _G.strengthStat.Value
_G.initialDurability = _G.durabilityStat.Value

_G.savedStrengthPerHour = 0
_G.savedStrengthPerDay = 0
_G.savedStrengthPerWeek = 0
_G.savedDurabilityPerHour = 0
_G.savedDurabilityPerDay = 0
_G.savedDurabilityPerWeek = 0

_G.savedAvgStrengthPerHour = 0
_G.savedAvgStrengthPerDay = 0
_G.savedAvgStrengthPerWeek = 0
_G.savedAvgDurabilityPerHour = 0
_G.savedAvgDurabilityPerDay = 0
_G.savedAvgDurabilityPerWeek = 0

task.spawn(function()
    local lastCalcTime = tick()
    while true do
        local currentTime = tick()
        local currentStrength = _G.strengthStat.Value
        local currentDurability = _G.durabilityStat.Value

        _G.strengthLabel.Text = "Strength: " .. _G.formatNumber(currentStrength) .. " | Gained: " .. _G.formatNumber(currentStrength - _G.initialStrength)
        _G.durabilityLabel.Text = "Durability: " .. _G.formatNumber(currentDurability) .. " | Gained: " .. _G.formatNumber(currentDurability - _G.initialDurability)

        if _G.runFastRep then
            if not _G.trackingStarted then
                _G.trackingStarted = true
                _G.startTime = currentTime
                _G.strengthHistory = {}
                _G.durabilityHistory = {}
                
                if _G.savedStrengthPerHour > 0 then
                    _G.projectedStrengthLabel.Text = "Strength: " .. _G.formatNumber(_G.savedStrengthPerHour) .. "/Hour | " .. _G.formatNumber(_G.savedStrengthPerDay) .. "/Day | " .. _G.formatNumber(_G.savedStrengthPerWeek) .. "/Week"
                    _G.projectedDurabilityLabel.Text = "Dura: " .. _G.formatNumber(_G.savedDurabilityPerHour) .. "/Hour | " .. _G.formatNumber(_G.savedDurabilityPerDay) .. "/Day | " .. _G.formatNumber(_G.savedDurabilityPerWeek) .. "/Week"
                    _G.averageStrengthLabel.Text = "Average: " .. _G.formatNumber(_G.savedAvgStrengthPerHour) .. "/Hour | " .. _G.formatNumber(_G.savedAvgStrengthPerDay) .. "/Day | " .. _G.formatNumber(_G.savedAvgStrengthPerWeek) .. "/Week"
                    _G.averageDurabilityLabel.Text = "Average: " .. _G.formatNumber(_G.savedAvgDurabilityPerHour) .. "/Hour | " .. _G.formatNumber(_G.savedAvgDurabilityPerDay) .. "/Day | " .. _G.formatNumber(_G.savedAvgDurabilityPerWeek) .. "/Week"
                end
            end
            
            local elapsedTime = _G.pausedElapsedTime + (currentTime - _G.startTime)
            local days = math.floor(elapsedTime / (24 * 3600))
            local hours = math.floor((elapsedTime % (24 * 3600)) / 3600)
            local minutes = math.floor((elapsedTime % 3600) / 60)
            local seconds = math.floor(elapsedTime % 60)
            _G.stopwatchLabel.Text = string.format("%dd %dh %dm %ds - Farming", days, hours, minutes, seconds)
            _G.stopwatchLabel.TextColor3 = Color3.fromRGB(50, 255, 50)

            table.insert(_G.strengthHistory, {time = currentTime, value = currentStrength})
            table.insert(_G.durabilityHistory, {time = currentTime, value = currentDurability})

            while #_G.strengthHistory > 0 and currentTime - _G.strengthHistory[1].time > _G.calculationInterval do
                table.remove(_G.strengthHistory, 1)
            end
            while #_G.durabilityHistory > 0 and currentTime - _G.durabilityHistory[1].time > _G.calculationInterval do
                table.remove(_G.durabilityHistory, 1)
            end

            if currentTime - lastCalcTime >= _G.calculationInterval then
                lastCalcTime = currentTime

                if #_G.strengthHistory >= 2 then
                    local strengthDelta = _G.strengthHistory[#_G.strengthHistory].value - _G.strengthHistory[1].value
                    local strengthPerSecond = strengthDelta / _G.calculationInterval
                    _G.savedStrengthPerHour = strengthPerSecond * 3600
                    _G.savedStrengthPerDay = strengthPerSecond * 86400
                    _G.savedStrengthPerWeek = strengthPerSecond * 604800
                    _G.projectedStrengthLabel.Text = "Strength: " .. _G.formatNumber(_G.savedStrengthPerHour) .. "/Hour | " .. _G.formatNumber(_G.savedStrengthPerDay) .. "/Day | " .. _G.formatNumber(_G.savedStrengthPerWeek) .. "/Week"
                end

                if #_G.durabilityHistory >= 2 then
                    local durabilityDelta = _G.durabilityHistory[#_G.durabilityHistory].value - _G.durabilityHistory[1].value
                    local durabilityPerSecond = durabilityDelta / _G.calculationInterval
                    _G.savedDurabilityPerHour = durabilityPerSecond * 3600
                    _G.savedDurabilityPerDay = durabilityPerSecond * 86400
                    _G.savedDurabilityPerWeek = durabilityPerSecond * 604800
                    _G.projectedDurabilityLabel.Text = "Dura: " .. _G.formatNumber(_G.savedDurabilityPerHour) .. "/Hour | " .. _G.formatNumber(_G.savedDurabilityPerDay) .. "/Day | " .. _G.formatNumber(_G.savedDurabilityPerWeek) .. "/Week"
                end

                local totalElapsed = _G.pausedElapsedTime + (currentTime - _G.startTime)
                if totalElapsed > 0 then
                    local avgStrengthPerSecond = (currentStrength - _G.initialStrength) / totalElapsed
                    _G.savedAvgStrengthPerHour = avgStrengthPerSecond * 3600
                    _G.savedAvgStrengthPerDay = avgStrengthPerSecond * 86400
                    _G.savedAvgStrengthPerWeek = avgStrengthPerSecond * 604800
                    _G.averageStrengthLabel.Text = "Average: " .. _G.formatNumber(_G.savedAvgStrengthPerHour) .. "/Hour | " .. _G.formatNumber(_G.savedAvgStrengthPerDay) .. "/Day | " .. _G.formatNumber(_G.savedAvgStrengthPerWeek) .. "/Week"

                    local avgDurabilityPerSecond = (currentDurability - _G.initialDurability) / totalElapsed
                    _G.savedAvgDurabilityPerHour = avgDurabilityPerSecond * 3600
                    _G.savedAvgDurabilityPerDay = avgDurabilityPerSecond * 86400
                    _G.savedAvgDurabilityPerWeek = avgDurabilityPerSecond * 604800
                    _G.averageDurabilityLabel.Text = "Average: " .. _G.formatNumber(_G.savedAvgDurabilityPerHour) .. "/Hour | " .. _G.formatNumber(_G.savedAvgDurabilityPerDay) .. "/Day | " .. _G.formatNumber(_G.savedAvgDurabilityPerWeek) .. "/Week"
                end
            end
        else
            if _G.trackingStarted then
                _G.trackingStarted = false
                _G.pausedElapsedTime = _G.pausedElapsedTime + (currentTime - _G.startTime)
                local days = math.floor(_G.pausedElapsedTime / (24 * 3600))
                local hours = math.floor((_G.pausedElapsedTime % (24 * 3600)) / 3600)
                local minutes = math.floor((_G.pausedElapsedTime % 3600) / 60)
                local seconds = math.floor(_G.pausedElapsedTime % 60)
                
                if _G.pausedElapsedTime > 0 then
                    _G.stopwatchLabel.Text = string.format("%dd %dh %dm %ds - Farming Paused", days, hours, minutes, seconds)
                    _G.stopwatchLabel.TextColor3 = Color3.fromRGB(255, 165, 0)
                else
                    _G.stopwatchLabel.Text = "0d 0h 0m 0s - Fast Rep Inactive"
                    _G.stopwatchLabel.TextColor3 = Color3.fromRGB(255, 50, 50)
                end

                _G.strengthHistory = {}
                _G.durabilityHistory = {}
            end
        end

        task.wait(0.05)
    end
end)

_G.StrTab:AddLabel("")
_G.StrTab:AddLabel("⚡ Fast Farm:").TextSize = 17
_G.farmRunning = false
_G.repSpeed = 350
_G.pingControl = true

_G.networkStats = game:GetService("Stats").Network.ServerStatsItem["Data Ping"]

function _G.getCurrentPing()
    return _G.networkStats:GetValue()
end

function _G.getAdaptiveSpeed(ping)
    if ping < 80 then
        return 500
    elseif ping < 150 then
        return 300
    elseif ping < 250 then
        return 100
    else
        return 50
    end
end

_G.StrTab:AddTextBox("Rep Speed:", function(inputText)
    local speedValue = tonumber(inputText)
    if speedValue then
        _G.repSpeed = math.clamp(math.floor(speedValue), 1, 1000)
    end
end)

_G.StrTab:AddSwitch("Controlled Speed", function(isEnabled)
    _G.pingControl = isEnabled
end):Set(true)

function _G.startAutoRep()
    local lastPingUpdate = time()
    local currentPing = _G.getCurrentPing()
    while _G.farmRunning do
        if time() - lastPingUpdate > 0.5 then
            currentPing = _G.getCurrentPing()
            lastPingUpdate = time()
        end
        local repsToFire = _G.pingControl and _G.getAdaptiveSpeed(currentPing) or _G.repSpeed
        local delayBetweenBatches = math.clamp(currentPing / 2500, 0.001, 0.1)
        for repCount = 1, math.min(repsToFire, _G.repSpeed) do
            _G.muscleEvent:FireServer("rep")
            if repCount % 500 == 0 then
                task.wait(0)
            end
        end
        task.wait(delayBetweenBatches)
    end
end

_G.StrTab:AddSwitch("Fast Rep", function(isEnabled)
    _G.farmRunning = isEnabled
    if _G.farmRunning then
        _G.runFastRep = true
        task.spawn(_G.startAutoRep)
    else 
        _G.runFastRep = false
    end
end)

_G.StrTab:AddButton("⚙️ Industrial Bar Lift", function()
    local character = _G.player.Character
    if character and character:FindFirstChild("HumanoidRootPart") then
        character.HumanoidRootPart.CFrame = CFrame.new(-5492.24, 81.82, 4644.04)
        task.wait(0.5)
        local machine = _G.findMachine("Industrial Bar Lift")
        if machine and machine:FindFirstChild("interactSeat") then
            local retryCount = 0
            repeat
                task.wait(0.2)
                _G.pressE()
                retryCount = retryCount + 1
            until (_G.player.Character and _G.player.Character.Humanoid.Sit) or retryCount > 10
        end
    end
end)

_G.StrTab:AddButton("🦵 Industrial Squat", function()
    local character = _G.player.Character
    if character and character:FindFirstChild("HumanoidRootPart") then
        character.HumanoidRootPart.CFrame = CFrame.new(-5216.36, 90.17, 5420.08)
        task.wait(0.5)
        local machine = _G.findMachine("Industrial Squat")
        if machine and machine:FindFirstChild("interactSeat") then
            local retryCount = 0
            repeat
                task.wait(0.2)
                _G.pressE()
                retryCount = retryCount + 1
            until (_G.player.Character and _G.player.Character.Humanoid.Sit) or retryCount > 10
        end
    end
end)

_G.StrTab:AddButton("😺 Equip Swift Samurai", function()
    local petsFolder = player.petsFolder
    for _, folder in pairs(petsFolder:GetChildren()) do
        if folder:IsA("Folder") then
            for _, pet in pairs(folder:GetChildren()) do
                rEvents.equipPetEvent:FireServer("unequipPet", pet)
            end
        end
    end
    task.wait(0.2)

    local petsToEquip = {}
    for _, pet in pairs(player.petsFolder.Unique:GetChildren()) do
        if pet.Name == "Swift Samurai" then
            table.insert(petsToEquip, pet)
        end
    end

    for i = 1, math.min(8, #petsToEquip) do
        rEvents.equipPetEvent:FireServer("equipPet", petsToEquip[i])
        task.wait(0.1)
    end
end)

_G.StrTab:AddButton("🎈 Equip Omega Overlord", function()
    local petsFolder = player.petsFolder
    for _, folder in pairs(petsFolder:GetChildren()) do
        if folder:IsA("Folder") then
            for _, pet in pairs(folder:GetChildren()) do
                rEvents.equipPetEvent:FireServer("unequipPet", pet)
            end
        end
    end
    task.wait(0.2)

    local petsToEquip = {}
    for _, pet in pairs(player.petsFolder.Unique:GetChildren()) do
        if pet.Name == "Omega Overlord" then
            table.insert(petsToEquip, pet)
        end
    end

    for i = 1, math.min(8, #petsToEquip) do
        rEvents.equipPetEvent:FireServer("equipPet", petsToEquip[i])
        task.wait(0.1)
    end
end)

local credits = window:AddTab("Credits")

local title = credits:AddLabel("🎭 Yusuf Private Script")
title.TextColor3 = Color3.fromRGB(255, 215, 0)

local dev = credits:AddLabel("👤 Developer: Yusuf")
dev.TextColor3 = Color3.fromRGB(255, 50, 50)
