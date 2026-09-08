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

local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local Kill = window:AddTab("Kill")

local playerWhitelist = {}
local targetPlayerNames = {}
local selectedFollowTarget = nil
_G.FollowToTarget = false
local autoGoodKarma = false
local autoBadKarma = false
local autoEquipPunch = false
local autoPunchNoAnim = false
local RemoveAnimActive = false

Kill:AddLabel("Misc")

local spyTargetDropdown = Kill:AddDropdown("👀 Select View Target", function(name)
    targetPlayerName = name
end)

for _, player in ipairs(Players:GetPlayers()) do
    if player ~= LocalPlayer then
        spyTargetDropdown:Add(player.Name)
    end
end

Players.PlayerAdded:Connect(function(player)
    if player ~= LocalPlayer then
        spyTargetDropdown:Add(player.Name)
    end
end)

Players.PlayerRemoving:Connect(function(player)
    if player ~= LocalPlayer then
        spyTargetDropdown:Clear()
        for _, plr in ipairs(Players:GetPlayers()) do
            if plr ~= LocalPlayer then
                spyTargetDropdown:Add(plr.Name)
            end
        end
    end
end)

Kill:AddSwitch("👀 View Player", function(bool)
    spying = bool
    if not spying then
        local cam = workspace.CurrentCamera
        cam.CameraSubject = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Humanoid") or LocalPlayer
        return
    end
    task.spawn(function()
        while spying do
            local target = Players:FindFirstChild(targetPlayerName)
            if target and target ~= LocalPlayer then
                local humanoid = target.Character and target.Character:FindFirstChild("Humanoid")
                if humanoid then
                    workspace.CurrentCamera.CameraSubject = humanoid
                end
            end
            task.wait(0.1)
        end
    end)
end)

local followDropdown = Kill:AddDropdown("👤 Select Follow Target", function(name)
    selectedFollowTarget = name
    _G.FollowToTarget = true
    
    task.spawn(function()
        while _G.FollowToTarget and selectedFollowTarget == name do
            local t = game.Players:FindFirstChild(selectedFollowTarget)
            local myChar = LocalPlayer.Character
            local myHRP = myChar and myChar:FindFirstChild("HumanoidRootPart")
            
            if t and t.Character and t.Character:FindFirstChild("HumanoidRootPart") and myHRP then
                myHRP.CFrame = t.Character.HumanoidRootPart.CFrame * CFrame.new(0, 0, 2.5)
            end
            task.wait()
        end
    end)
end)

Kill:AddButton("⛔ Stop Follow", function()
    _G.FollowToTarget = false
    selectedFollowTarget = nil
end)

local function updateFollowDropdown(p)
    if p ~= LocalPlayer then
        followDropdown:Add(p.Name)
    end
end

for _, p in ipairs(game.Players:GetPlayers()) do updateFollowDropdown(p) end
game.Players.PlayerAdded:Connect(updateFollowDropdown)

Kill:AddLabel("----------------------------")
Kill:AddLabel("🥊 Combat Tweaks")

local blockedAnimations = {
    ["rbxassetid://3638729053"] = true,
    ["rbxassetid://3638767427"] = true,
}

local function setupAnimationBlocking()
    local char = LocalPlayer.Character
    if not char or not char:FindFirstChild("Humanoid") then return end

    local humanoid = char:FindFirstChild("Humanoid")

    for _, track in pairs(humanoid:GetPlayingAnimationTracks()) do
        if track.Animation then
            local animId = track.Animation.AnimationId
            local animName = track.Name:lower()

            if blockedAnimations[animId] or animName:match("punch") or animName:match("attack") or animName:match("right") then
                track:Stop()
            end
        end
    end

    if not _G.AnimBlockConnection then
        _G.AnimBlockConnection = humanoid.AnimationPlayed:Connect(function(track)
            if track.Animation then
                local animId = track.Animation.AnimationId
                local animName = track.Name:lower()

                if blockedAnimations[animId] or animName:match("punch") or animName:match("attack") or animName:match("right") then
                    track:Stop()
                end
            end
        end)
    end
end

local function overrideToolActivation()
    local function processTool(tool)
        if tool and (tool.Name == "Punch" or tool.Name:match("Attack") or tool.Name:match("Right")) then
            if not tool:GetAttribute("ActivatedOverride") then
                tool:SetAttribute("ActivatedOverride", true)

                local connection = tool.Activated:Connect(function()
                    task.wait(0.05)

                    local char = LocalPlayer.Character
                    if char and char:FindFirstChild("Humanoid") then
                        for _, track in pairs(char.Humanoid:GetPlayingAnimationTracks()) do
                            if track.Animation then
                                local animId = track.Animation.AnimationId
                                local animName = track.Name:lower()

                                if blockedAnimations[animId] or animName:match("punch") or animName:match("attack") or animName:match("right") then
                                    track:Stop()
                                end
                            end
                        end
                    end
                end)

                if not _G.ToolConnections then
                    _G.ToolConnections = {}
                end
                _G.ToolConnections[tool] = connection
            end
        end
    end

    for _, tool in pairs(LocalPlayer.Backpack:GetChildren()) do
        processTool(tool)
    end

    local char = LocalPlayer.Character
    if char then
        for _, tool in pairs(char:GetChildren()) do
            if tool:IsA("Tool") then
                processTool(tool)
            end
        end
    end

    if not _G.BackpackAddedConnection then
        _G.BackpackAddedConnection = LocalPlayer.Backpack.ChildAdded:Connect(function(child)
            if child:IsA("Tool") then
                task.wait(0.1)
                processTool(child)
            end
        end)
    end

    if not _G.CharacterToolAddedConnection and char then
        _G.CharacterToolAddedConnection = char.ChildAdded:Connect(function(child)
            if child:IsA("Tool") then
                task.wait(0.1)
                processTool(child)
            end
        end)
    end
end

local function RecoveryPunch()
    if _G.AnimBlockConnection then _G.AnimBlockConnection:Disconnect() _G.AnimBlockConnection = nil end
    if _G.AnimMonitorConnection then _G.AnimMonitorConnection:Disconnect() _G.AnimMonitorConnection = nil end
    if _G.BackpackAddedConnection then _G.BackpackAddedConnection:Disconnect() _G.BackpackAddedConnection = nil end
    if _G.CharacterToolAddedConnection then _G.CharacterToolAddedConnection:Disconnect() _G.CharacterToolAddedConnection = nil end
    if _G.CharacterAddedConnection then _G.CharacterAddedConnection:Disconnect() _G.CharacterAddedConnection = nil end
    if _G.ToolConnections then
        for _, conn in pairs(_G.ToolConnections) do
            if conn then conn:Disconnect() end
        end
        _G.ToolConnections = nil
    end
end

Kill:AddSwitch("🚫 Remove Punch Anim", function(state)
    _G.RemoveAnimActive = state
    if state then
        setupAnimationBlocking()
        overrideToolActivation()

        if not _G.AnimMonitorConnection then
            _G.AnimMonitorConnection = game:GetService("RunService").Heartbeat:Connect(function()
                if tick() % 0.5 < 0.01 then
                    local char = LocalPlayer.Character
                    if char and char:FindFirstChild("Humanoid") then
                        for _, track in pairs(char.Humanoid:GetPlayingAnimationTracks()) do
                            if track.Animation then
                                local animId = track.Animation.AnimationId
                                local animName = track.Name:lower()

                                if blockedAnimations[animId] or animName:match("punch") or animName:match("attack") or animName:match("right") then
                                    track:Stop()
                                end
                            end
                        end
                    end
                end
            end)
        end

        if not _G.CharacterAddedConnection then
            _G.CharacterAddedConnection = LocalPlayer.CharacterAdded:Connect(function(newChar)
                task.wait(1)
                if _G.RemoveAnimActive then
                    setupAnimationBlocking()
                    overrideToolActivation()

                    if _G.CharacterToolAddedConnection then _G.CharacterToolAddedConnection:Disconnect() end
                    _G.CharacterToolAddedConnection = newChar.ChildAdded:Connect(function(child)
                        if child:IsA("Tool") then
                            task.wait(0.1)
                            processTool(child)
                        end
                    end)
                end
            end)
        end
    else
        RecoveryPunch()
    end
end)

Kill:AddSwitch("Auto Equip Punch", function(state)
    autoEquipPunch = state
    task.spawn(function()
        while autoEquipPunch do
            local punch = LocalPlayer.Backpack:FindFirstChild("Punch")
            if punch then
                punch.Parent = LocalPlayer.Character
            end
            task.wait(0.1)
        end
    end)
end)

Kill:AddSwitch("🥊 Auto Punch [No Animation]", function(state)
    autoPunchNoAnim = state
    task.spawn(function()
        while autoPunchNoAnim do
            local punch = LocalPlayer.Backpack:FindFirstChild("Punch") or (LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Punch"))
            if punch then
                if punch.Parent ~= LocalPlayer.Character then
                    punch.Parent = LocalPlayer.Character
                end
                pcall(function()
                    punch:Activate()
                end)
            else
                autoPunchNoAnim = false
            end
            task.wait(0.01)
        end
    end)
end)

Kill:AddSwitch("🧨 Auto Punch", function(state)
    _G.fastHitActive = state
    if state then
        task.spawn(function()
            while _G.fastHitActive do
                local punch = LocalPlayer.Backpack:FindFirstChild("Punch")
                if punch then
                    punch.Parent = LocalPlayer.Character
                    if punch:FindFirstChild("attackTime") then
                        punch.attackTime.Value = 0
                    end
                end
                task.wait(0.1)
            end
        end)
        task.spawn(function()
            while _G.fastHitActive do
                local punch = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Punch")
                if punch then
                    punch:Activate()
                end
                task.wait(0.1)
            end
        end)
    else
        local punch = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Punch")
        if punch then
            punch.Parent = LocalPlayer.Backpack
        end
    end
end)

Kill:AddSwitch("⚡ Fast Punch", function(state)
    _G.autoPunchActive = state
    if state then
        task.spawn(function()
            while _G.autoPunchActive do
                local punch = LocalPlayer.Backpack:FindFirstChild("Punch")
                if punch then
                    punch.Parent = LocalPlayer.Character
                    if punch:FindFirstChild("attackTime") then
                        punch.attackTime.Value = 0
                    end
                end
                task.wait(0.02)
            end
        end)
        task.spawn(function()
            while _G.autoPunchActive do
                local punch = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Punch")
                if punch then
                    punch:Activate()
                end
                task.wait(0.02)
            end
        end)
    else
        local punch = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Punch")
        if punch then
            punch.Parent = LocalPlayer.Backpack
        end
    end
end)

Kill:AddSwitch("💥 Fast Ground Slam", function(state)
    _G.autoGroundSlamActive = state
    if state then
        task.spawn(function()
            while _G.autoGroundSlamActive do
                local slam = LocalPlayer.Backpack:FindFirstChild("Ground Slam")
                if slam then
                    slam.Parent = LocalPlayer.Character
                    if slam:FindFirstChild("attackTime") then
                        slam.attackTime.Value = 0
                    end
                end
                task.wait(0.02)
            end
        end)
        task.spawn(function()
            while _G.autoGroundSlamActive do
                local slam = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Ground Slam")
                if slam then
                    slam:Activate()
                end
                task.wait(0.02)
            end
        end)
    else
        local slam = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Ground Slam")
        if slam then
            slam.Parent = LocalPlayer.Backpack
        end
    end
end)

Kill:AddSwitch("🦵 Fast Stomp", function(state)
    _G.autoStompActive = state
    if state then
        task.spawn(function()
            while _G.autoStompActive do
                local stomp = LocalPlayer.Backpack:FindFirstChild("Stomp")
                if stomp then
                    stomp.Parent = LocalPlayer.Character
                    if stomp:FindFirstChild("attackTime") then
                        stomp.attackTime.Value = 0
                    end
                end
                task.wait(0.2)
            end
        end)
        task.spawn(function()
            while _G.autoStompActive do
                local stomp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Stomp")
                if stomp then
                    stomp:Activate()
                end
                task.wait(0.30)
            end
        end)
    else
        local stomp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Stomp")
        if stomp then
            stomp.Parent = LocalPlayer.Backpack
        end
    end
end)

Kill:AddLabel("--------------------")
Kill:AddLabel("✨ Whitelist")

local whitelistShow = Kill:AddLabel("Whitelisted: None")

local function updateWhitelistLabel()
    local str = ""
    for name, _ in pairs(playerWhitelist) do str = str .. name .. ", " end
    whitelistShow.Text = str ~= "" and "Whitelisted: " .. str:sub(1, #str - 2) or "Whitelisted: None"
end

local whitelistDropdown = Kill:AddDropdown("Whitelist Player", function(name)
    if name then playerWhitelist[name] = true updateWhitelistLabel() end
end)

for _, plr in ipairs(game:GetService("Players"):GetPlayers()) do
    if plr ~= game.Players.LocalPlayer then
        whitelistDropdown:Add(plr.Name)
    end
end

game:GetService("Players").PlayerAdded:Connect(function(plr)
    if plr ~= game.Players.LocalPlayer then
        whitelistDropdown:Add(plr.Name)
    end
end)

Kill:AddButton("🧹 Clear Whitelist", function()
    playerWhitelist = {} updateWhitelistLabel()
end)

Kill:AddSwitch("🛡️ Auto Whitelist Friends", function(state)
    _G.WhFriends = state
    if state then
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= LocalPlayer and LocalPlayer:IsFriendsWith(p.UserId) then playerWhitelist[p.Name] = true end
        end
        updateWhitelistLabel()
    end
end)

Kill:AddSwitch("⚔️ Auto Kill All (Ignore Whitelist)", function(bool)
    _G.AutoKill = bool
    task.spawn(function()
        while _G.AutoKill do
            local char = LocalPlayer.Character
            local punch = LocalPlayer.Backpack:FindFirstChild("Punch") or (char and char:FindFirstChild("Punch"))
            local myRoot = char and char:FindFirstChild("HumanoidRootPart")
            
            if char and punch and myRoot then
                if punch.Parent ~= char then
                    punch.Parent = char
                end
                
                for _, target in ipairs(Players:GetPlayers()) do
                    if target ~= LocalPlayer and not playerWhitelist[target.Name] then
                        local tChar = target.Character
                        local root = tChar and tChar:FindFirstChild("HumanoidRootPart")
                        local humanoid = tChar and tChar:FindFirstChild("Humanoid")
                        
                        if root and humanoid and humanoid.Health > 0 then
                            pcall(function()
                                local oldCFrame = myRoot.CFrame
                                myRoot.CFrame = root.CFrame * CFrame.new(0, 0, 1)
                                punch:Activate()
                                task.wait(0.01)
                                myRoot.CFrame = oldCFrame
                            end)
                        end
                    end
                end
            end
            task.wait(0.05)
        end
    end)
end)

Kill:AddSwitch("😇 Auto Good Karma", function(bool)
    _G.GoodKarma = bool
    if bool then
        task.spawn(function()
            while _G.GoodKarma do
                local char = LocalPlayer.Character
                local punch = LocalPlayer.Backpack:FindFirstChild("Punch") or (char and char:FindFirstChild("Punch"))
                local myRoot = char and char:FindFirstChild("HumanoidRootPart")
                
                if char and punch and myRoot and char:FindFirstChild("Humanoid") and char.Humanoid.Health > 0 then
                    if punch.Parent ~= char then
                        punch.Parent = char
                    end
                    
                    for _, target in ipairs(Players:GetPlayers()) do
                        if target ~= LocalPlayer then
                            local evil = target:FindFirstChild("evilKarma")
                            local good = target:FindFirstChild("goodKarma")
                            
                            if evil and good and evil.Value > good.Value then
                                local tChar = target.Character
                                if tChar and tChar:FindFirstChild("Humanoid") and tChar.Humanoid.Health > 0 then
                                    local root = tChar:FindFirstChild("HumanoidRootPart")
                                    if root then
                                        pcall(function()
                                            local oldCFrame = myRoot.CFrame
                                            myRoot.CFrame = root.CFrame * CFrame.new(0, 0, 1)
                                            punch:Activate()
                                            task.wait(0.01)
                                            myRoot.CFrame = oldCFrame
                                        end)
                                    end
                                end
                            end
                        end
                    end
                end
                task.wait(0.1)
            end
        end)
    end
end)

Kill:AddSwitch("😈 Auto Bad Karma", function(bool)
    _G.BadKarma = bool
    if bool then
        task.spawn(function()
            while _G.BadKarma do
                local char = LocalPlayer.Character
                local punch = LocalPlayer.Backpack:FindFirstChild("Punch") or (char and char:FindFirstChild("Punch"))
                local myRoot = char and char:FindFirstChild("HumanoidRootPart")
                
                if char and punch and myRoot and char:FindFirstChild("Humanoid") and char.Humanoid.Health > 0 then
                    if punch.Parent ~= char then
                        punch.Parent = char
                    end
                    
                    for _, target in ipairs(Players:GetPlayers()) do
                        if target ~= LocalPlayer then
                            let evil = target:FindFirstChild("evilKarma")
                            local good = target:FindFirstChild("goodKarma")
                            
                            if evil and good and good.Value > evil.Value then
                                local tChar = target.Character
                                if tChar and tChar:FindFirstChild("Humanoid") and tChar.Humanoid.Health > 0 then
                                    local root = tChar:FindFirstChild("HumanoidRootPart")
                                    if root then
                                        pcall(function()
                                            local oldCFrame = myRoot.CFrame
                                            myRoot.CFrame = root.CFrame * CFrame.new(0, 0, 1)
                                            punch:Activate()
                                            task.wait(0.01)
                                            myRoot.CFrame = oldCFrame
                                        end)
                                    end
                                end
                            end
                        end
                    end
                end
                task.wait(0.1)
            end
        end)
    end
end)

Kill:AddLabel("----------------------------")
Kill:AddLabel("🎯 Target Kill")

local blacklistShow = Kill:AddLabel("Targets: None")

local function updateBlacklistLabel()
    local str = ""
    for _, name in ipairs(targetPlayerNames) do str = str .. name .. ", " end
    blacklistShow.Text = str ~= "" and "Targets: " .. str:sub(1, #str - 2) or "Targets: None"
end
