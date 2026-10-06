-- Roblox_CoolUI.lua
-- One-file Roblox admin utility UI.
-- Intended for your own Roblox experience / admin tooling.
-- Place as a LocalScript in StarterPlayerScripts or StarterGui.
-- Client-side features work immediately. Server-authoritative actions require your own RemoteEvent.

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Lighting = game:GetService("Lighting")
local StarterGui = game:GetService("StarterGui")
local TeleportService = game:GetService("TeleportService")

local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera

local CONFIG = {
    ToggleKey = Enum.KeyCode.RightShift,
    DefaultWalkSpeed = 16,
    DefaultJumpPower = 50,
    MaxSpeed = 200,
    MaxJump = 200,
}

local State = {
    Open = true,
    Flying = false,
    Noclip = false,
    InfiniteJump = false,
    SpeedEnabled = false,
    JumpEnabled = false,
    FullBright = false,
    ESP = false,
    Tracers = false,
    Names = false,
    AntiAFK = false,
    FOV = 70,
    FlySpeed = 70,
    SelectedPlayer = nil,
    FlyConnection = nil,
    NoclipConnection = nil,
    ESPObjects = {},
    OriginalLighting = {},
    OriginalWalkSpeed = CONFIG.DefaultWalkSpeed,
    OriginalJumpPower = CONFIG.DefaultJumpPower,
}

local Character, Humanoid, Root
local function refreshCharacter()
    Character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
    Humanoid = Character:FindFirstChildOfClass("Humanoid")
    Root = Character:FindFirstChild("HumanoidRootPart")
    if Humanoid then
        State.OriginalWalkSpeed = Humanoid.WalkSpeed
        State.OriginalJumpPower = Humanoid.JumpPower
    end
end
refreshCharacter()

LocalPlayer.CharacterAdded:Connect(function()
    task.wait(0.5)
    refreshCharacter()
    if State.Flying then
        State.Flying = false
        task.wait()
        toggleFly(true)
    end
end)

-- Helpers
local function notify(title, text, duration)
    pcall(function()
        StarterGui:SetCore("SendNotification", {
            Title = title,
            Text = text,
            Duration = duration or 3
        })
    end)
end

local function getPlayerByName(text)
    if not text or text == "" then return nil end
    text = string.lower(text)
    for _, p in ipairs(Players:GetPlayers()) do
        if string.sub(string.lower(p.Name), 1, #text) == text
        or string.sub(string.lower(p.DisplayName), 1, #text) == text then
            return p
        end
    end
    return nil
end

local function teleportToPlayer(player)
    if not Root or not player or not player.Character then return end
    local target = player.Character:FindFirstChild("HumanoidRootPart")
    if target then
        Root.CFrame = target.CFrame + Vector3.new(0, 3, 0)
    end
end

local function teleportToMouse()
    if not Root then return end
    local mouse = LocalPlayer:GetMouse()
    local hit = mouse.Hit
    if hit then
        Root.CFrame = CFrame.new(hit.Position + Vector3.new(0, 3, 0))
    end
end

-- Flight
function toggleFly(forceOn)
    if not Root then return end
    if forceOn then
        State.Flying = true
    else
        State.Flying = not State.Flying
    end

    if State.Flying then
        if State.FlyConnection then State.FlyConnection:Disconnect() end
        State.FlyConnection = RunService.RenderStepped:Connect(function()
            if not State.Flying or not Root or not Camera then return end

            local move = Vector3.zero
            local cf = Camera.CFrame

            if UserInputService:IsKeyDown(Enum.KeyCode.W) then move += cf.LookVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.S) then move -= cf.LookVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.A) then move -= cf.RightVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.D) then move += cf.RightVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.Space) then move += Vector3.yAxis end
            if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then move -= Vector3.yAxis end

            if move.Magnitude > 0 then
                Root.AssemblyLinearVelocity = move.Unit * State.FlySpeed
            else
                Root.AssemblyLinearVelocity = Vector3.zero
            end
            Root.CFrame = CFrame.lookAt(Root.Position, Root.Position + cf.LookVector)
        end)
        notify("Admin UI", "Fly enabled")
    else
        if State.FlyConnection then
            State.FlyConnection:Disconnect()
            State.FlyConnection = nil
        end
        if Root then Root.AssemblyLinearVelocity = Vector3.zero end
        notify("Admin UI", "Fly disabled")
    end
end

-- Noclip
local function toggleNoclip()
    State.Noclip = not State.Noclip
    if State.Noclip then
        if State.NoclipConnection then State.NoclipConnection:Disconnect() end
        State.NoclipConnection = RunService.Stepped:Connect(function()
            if Character then
                for _, part in ipairs(Character:GetDescendants()) do
                    if part:IsA("BasePart") then
                        part.CanCollide = false
                    end
                end
            end
        end)
        notify("Admin UI", "Noclip enabled")
    else
        if State.NoclipConnection then State.NoclipConnection:Disconnect() end
        State.NoclipConnection = nil
        if Character then
            for _, part in ipairs(Character:GetDescendants()) do
                if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
                    part.CanCollide = true
                end
            end
        end
        notify("Admin UI", "Noclip disabled")
    end
end

-- ESP
local function clearESP()
    for _, obj in pairs(State.ESPObjects) do
        if obj and obj.Parent then obj:Destroy() end
    end
    State.ESPObjects = {}
end

local function addESP(player)
    if player == LocalPlayer or not player.Character then return end
    local head = player.Character:FindFirstChild("Head")
    if not head then return end

    local billboard = Instance.new("BillboardGui")
    billboard.Name = "CoolUI_ESP"
    billboard.Size = UDim2.fromOffset(180, 45)
    billboard.StudsOffset = Vector3.new(0, 2.8, 0)
    billboard.AlwaysOnTop = true
    billboard.Adornee = head
    billboard.Parent = head

    local label = Instance.new("TextLabel")
    label.BackgroundTransparency = 1
    label.Size = UDim2.fromScale(1, 1)
    label.Text = player.DisplayName .. "  @" .. player.Name
    label.TextColor3 = Color3.fromRGB(255, 255, 255)
    label.TextStrokeTransparency = 0.25
    label.TextScaled = true
    label.Font = Enum.Font.GothamBold
    label.Parent = billboard

    table.insert(State.ESPObjects, billboard)
end

local function rebuildESP()
    clearESP()
    if not State.ESP then return end
    for _, p in ipairs(Players:GetPlayers()) do
        addESP(p)
    end
end

Players.PlayerAdded:Connect(function(p)
    p.CharacterAdded:Connect(function()
        task.wait(1)
        if State.ESP then addESP(p) end
    end)
end)

Players.PlayerRemoving:Connect(function()
    if State.ESP then rebuildESP() end
end)

-- Build UI
local gui = Instance.new("ScreenGui")
gui.Name = "Roblox_CoolUI"
gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = LocalPlayer:WaitForChild("PlayerGui")

local main = Instance.new("Frame")
main.Name = "Main"
main.Size = UDim2.fromOffset(650, 470)
main.Position = UDim2.new(0.5, -325, 0.5, -235)
main.BackgroundColor3 = Color3.fromRGB(17, 18, 24)
main.BorderSizePixel = 0
main.Parent = gui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 14)
corner.Parent = main

local stroke = Instance.new("UIStroke")
stroke.Color = Color3.fromRGB(80, 90, 120)
stroke.Transparency = 0.35
stroke.Parent = main

local top = Instance.new("Frame")
top.Size = UDim2.new(1, 0, 0, 55)
top.BackgroundColor3 = Color3.fromRGB(25, 27, 36)
top.BorderSizePixel = 0
top.Parent = main

local topCorner = Instance.new("UICorner")
topCorner.CornerRadius = UDim.new(0, 14)
topCorner.Parent = top

local title = Instance.new("TextLabel")
title.BackgroundTransparency = 1
title.Position = UDim2.fromOffset(18, 6)
title.Size = UDim2.fromOffset(420, 26)
title.Text = "ROBLOX COOL UI"
title.TextColor3 = Color3.fromRGB(255,255,255)
title.TextXAlignment = Enum.TextXAlignment.Left
title.Font = Enum.Font.GothamBold
title.TextSize = 20
title.Parent = top

local subtitle = Instance.new("TextLabel")
subtitle.BackgroundTransparency = 1
subtitle.Position = UDim2.fromOffset(19, 31)
subtitle.Size = UDim2.fromOffset(430, 18)
subtitle.Text = "Admin Utility Panel  •  RightShift to toggle"
subtitle.TextColor3 = Color3.fromRGB(145,150,165)
subtitle.TextXAlignment = Enum.TextXAlignment.Left
subtitle.Font = Enum.Font.Gotham
subtitle.TextSize = 11
subtitle.Parent = top

local close = Instance.new("TextButton")
close.Size = UDim2.fromOffset(40, 34)
close.Position = UDim2.new(1, -50, 0, 10)
close.Text = "×"
close.TextSize = 25
close.Font = Enum.Font.GothamBold
close.TextColor3 = Color3.fromRGB(255,255,255)
close.BackgroundColor3 = Color3.fromRGB(190,60,75)
close.BorderSizePixel = 0
close.Parent = top
Instance.new("UICorner", close).CornerRadius = UDim.new(0, 9)

local sidebar = Instance.new("Frame")
sidebar.Position = UDim2.fromOffset(10, 65)
sidebar.Size = UDim2.fromOffset(145, 395)
sidebar.BackgroundColor3 = Color3.fromRGB(21,22,30)
sidebar.BorderSizePixel = 0
sidebar.Parent = main
Instance.new("UICorner", sidebar).CornerRadius = UDim.new(0, 10)

local content = Instance.new("ScrollingFrame")
content.Position = UDim2.fromOffset(165, 65)
content.Size = UDim2.new(1, -175, 1, -75)
content.BackgroundTransparency = 1
content.BorderSizePixel = 0
content.ScrollBarThickness = 5
content.CanvasSize = UDim2.new()
content.AutomaticCanvasSize = Enum.AutomaticSize.Y
content.Parent = main

local list = Instance.new("UIListLayout")
list.Padding = UDim.new(0, 8)
list.Parent = content

local pad = Instance.new("UIPadding")
pad.PaddingTop = UDim.new(0, 3)
pad.PaddingBottom = UDim.new(0, 8)
pad.PaddingLeft = UDim.new(0, 3)
pad.PaddingRight = UDim.new(0, 8)
pad.Parent = content

local function clearContent()
    for _, child in ipairs(content:GetChildren()) do
        if not child:IsA("UIListLayout") and not child:IsA("UIPadding") then
            child:Destroy()
        end
    end
end

local function button(text, callback, enabled)
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(1, 0, 0, 42)
    b.BackgroundColor3 = enabled and Color3.fromRGB(45, 48, 62) or Color3.fromRGB(31, 33, 42)
    b.BorderSizePixel = 0
    b.Text = text
    b.TextColor3 = Color3.fromRGB(235,238,245)
    b.TextSize = 13
    b.Font = Enum.Font.GothamMedium
    b.AutoButtonColor = true
    b.Parent = content
    Instance.new("UICorner", b).CornerRadius = UDim.new(0, 9)
    b.MouseButton1Click:Connect(function()
        callback(b)
    end)
    return b
end

local function section(text)
    local l = Instance.new("TextLabel")
    l.Size = UDim2.new(1, 0, 0, 25)
    l.BackgroundTransparency = 1
    l.Text = "  " .. text
    l.TextColor3 = Color3.fromRGB(110,170,255)
    l.TextXAlignment = Enum.TextXAlignment.Left
    l.Font = Enum.Font.GothamBold
    l.TextSize = 13
    l.Parent = content
end

local function textbox(placeholder)
    local t = Instance.new("TextBox")
    t.Size = UDim2.new(1, 0, 0, 40)
    t.BackgroundColor3 = Color3.fromRGB(29,31,40)
    t.BorderSizePixel = 0
    t.PlaceholderText = placeholder
    t.Text = ""
    t.TextColor3 = Color3.fromRGB(240,240,245)
    t.PlaceholderColor3 = Color3.fromRGB(115,120,135)
    t.Font = Enum.Font.Gotham
    t.TextSize = 13
    t.ClearTextOnFocus = false
    t.Parent = content
    Instance.new("UICorner", t).CornerRadius = UDim.new(0, 9)
    return t
end

local function toggle(text, getter, setter)
    local b
    local function update()
        local on = getter()
        b.Text = text .. (on and "  [ON]" or "  [OFF]")
        b.BackgroundColor3 = on and Color3.fromRGB(40,100,75) or Color3.fromRGB(31,33,42)
    end
    b = button(text, function()
        setter(not getter())
        update()
    end)
    update()
    return b
end

-- Categories
local categories = {"PLAYER", "MOVEMENT", "VISUALS", "PLAYERS", "WORLD", "TOOLS", "SETTINGS"}
local activeCategory = "PLAYER"

local function render(category)
    activeCategory = category
    clearContent()

    if category == "PLAYER" then
        section("PLAYER CONTROLS")
        toggle("Fly", function() return State.Flying end, toggleFly)
        toggle("Noclip", function() return State.Noclip end, toggleNoclip)
        toggle("Infinite Jump", function() return State.InfiniteJump end, function(v)
            State.InfiniteJump = v
        end)
        toggle("Speed Boost", function() return State.SpeedEnabled end, function(v)
            State.SpeedEnabled = v
            if Humanoid then Humanoid.WalkSpeed = v and 60 or State.OriginalWalkSpeed end
        end)
        toggle("High Jump", function() return State.JumpEnabled end, function(v)
            State.JumpEnabled = v
            if Humanoid then Humanoid.JumpPower = v and 100 or State.OriginalJumpPower end
        end)
        button("Reset Movement", function()
            State.Flying = false
            State.Noclip = false
            State.SpeedEnabled = false
            State.JumpEnabled = false
            if Humanoid then
                Humanoid.WalkSpeed = State.OriginalWalkSpeed
                Humanoid.JumpPower = State.OriginalJumpPower
            end
            if Root then Root.AssemblyLinearVelocity = Vector3.zero end
            notify("Admin UI", "Movement reset")
            render(category)
        end)

    elseif category == "MOVEMENT" then
        section("MOVEMENT TOOLS")
        local speedBox = textbox("Fly speed (10 - 200)")
        speedBox.FocusLost:Connect(function()
            local n = tonumber(speedBox.Text)
            if n then State.FlySpeed = math.clamp(n, 10, CONFIG.MaxSpeed) end
        end)
        button("Set WalkSpeed: 16", function()
            if Humanoid then Humanoid.WalkSpeed = 16 end
        end)
        button("Set WalkSpeed: 50", function()
            if Humanoid then Humanoid.WalkSpeed = 50 end
        end)
        button("Set WalkSpeed: 100", function()
            if Humanoid then Humanoid.WalkSpeed = 100 end
        end)
        button("Set JumpPower: 50", function()
            if Humanoid then Humanoid.JumpPower = 50 end
        end)
        button("Set JumpPower: 100", function()
            if Humanoid then Humanoid.JumpPower = 100 end
        end)
        button("Teleport to Mouse", teleportToMouse)
        button("Reset Character", function()
            if Humanoid then Humanoid.Health = 0 end
        end)

    elseif category == "VISUALS" then
        section("VISUAL FEATURES")
        toggle("Player ESP", function() return State.ESP end, function(v)
            State.ESP = v
            rebuildESP()
        end)
        toggle("Full Bright", function() return State.FullBright end, function(v)
            State.FullBright = v
            if v then
                State.OriginalLighting.Brightness = Lighting.Brightness
                State.OriginalLighting.ClockTime = Lighting.ClockTime
                State.OriginalLighting.FogEnd = Lighting.FogEnd
                Lighting.Brightness = 3
                Lighting.ClockTime = 14
                Lighting.FogEnd = 100000
            else
                Lighting.Brightness = State.OriginalLighting.Brightness or 2
                Lighting.ClockTime = State.OriginalLighting.ClockTime or 14
                Lighting.FogEnd = State.OriginalLighting.FogEnd or 100000
            end
        end)
        local fov = textbox("FOV (40 - 120)")
        fov.FocusLost:Connect(function()
            local n = tonumber(fov.Text)
            if n then
                State.FOV = math.clamp(n, 40, 120)
                Camera.FieldOfView = State.FOV
            end
        end)
        button("FOV 70", function() State.FOV = 70; Camera.FieldOfView = 70 end)
        button("FOV 90", function() State.FOV = 90; Camera.FieldOfView = 90 end)
        button("FOV 110", function() State.FOV = 110; Camera.FieldOfView = 110 end)
        button("Hide Character UI", function()
            for _, p in ipairs(LocalPlayer.PlayerGui:GetChildren()) do
                if p ~= gui and p:IsA("ScreenGui") then p.Enabled = false end
            end
        end)
        button("Show Character UI", function()
            for _, p in ipairs(LocalPlayer.PlayerGui:GetChildren()) do
                if p ~= gui and p:IsA("ScreenGui") then p.Enabled = true end
            end
        end)

    elseif category == "PLAYERS" then
        section("PLAYER TARGETING")
        local targetBox = textbox("Player name / display name")
        button("Select Player", function()
            local p = getPlayerByName(targetBox.Text)
            State.SelectedPlayer = p
            if p then notify("Selected", p.Name) else notify("Admin UI", "Player not found") end
        end)
        button("Teleport To Selected", function()
            if State.SelectedPlayer then teleportToPlayer(State.SelectedPlayer) end
        end)
        button("Bring Selected", function()
            if State.SelectedPlayer and State.SelectedPlayer.Character and Root then
                local targetRoot = State.SelectedPlayer.Character:FindFirstChild("HumanoidRootPart")
                if targetRoot then
                    targetRoot.CFrame = Root.CFrame + Vector3.new(3, 0, 0)
                end
            end
        end)
        button("View Selected", function()
            if State.SelectedPlayer and State.SelectedPlayer.Character then
                local h = State.SelectedPlayer.Character:FindFirstChildOfClass("Humanoid")
                if h then Camera.CameraSubject = h end
            end
        end)
        button("Return Camera", function()
            if Humanoid then Camera.CameraSubject = Humanoid end
        end)
        section("QUICK PLAYER LIST")
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= LocalPlayer then
                button(p.DisplayName .. "  @" .. p.Name, function()
                    State.SelectedPlayer = p
                    teleportToPlayer(p)
                end)
            end
        end

    elseif category == "WORLD" then
        section("WORLD / ENVIRONMENT")
        button("Day", function() Lighting.ClockTime = 14 end)
        button("Night", function() Lighting.ClockTime = 0 end)
        button("Sunset", function() Lighting.ClockTime = 18 end)
        button("Clear Fog", function() Lighting.FogEnd = 100000 end)
        button("Low Gravity Feel", function()
            if Root then Root.AssemblyLinearVelocity += Vector3.new(0, 50, 0) end
        end)
        button("Spawn Personal Platform", function()
            if not Root then return end
            local part = Instance.new("Part")
            part.Name = "CoolUI_Platform"
            part.Size = Vector3.new(10, 1, 10)
            part.Anchored = true
            part.CFrame = Root.CFrame * CFrame.new(0, -4, 0)
            part.Parent = workspace
            task.delay(20, function()
                if part and part.Parent then part:Destroy() end
            end)
        end)

    elseif category == "TOOLS" then
        section("UTILITY TOOLS")
        toggle("Anti AFK", function() return State.AntiAFK end, function(v)
            State.AntiAFK = v
        end)
        button("Teleport To Spawn", function()
            local spawn = workspace:FindFirstChildWhichIsA("SpawnLocation", true)
            if spawn and Root then Root.CFrame = spawn.CFrame + Vector3.new(0, 4, 0) end
        end)
        button("Respawn", function()
            if Humanoid then Humanoid.Health = 0 end
        end)
        button("Sit / Stand", function()
            if Humanoid then Humanoid.Sit = not Humanoid.Sit end
        end)
        button("Reset Camera", function()
            Camera.FieldOfView = 70
            if Humanoid then Camera.CameraSubject = Humanoid end
        end)
        button("Copy Place ID to Clipboard", function()
            if setclipboard then
                pcall(setclipboard, tostring(game.PlaceId))
                notify("Admin UI", "Place ID copied")
            else
                notify("Place ID", tostring(game.PlaceId))
            end
        end)
        button("Rejoin Server", function()
            pcall(function()
                TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, LocalPlayer)
            end)
        end)

    elseif category == "SETTINGS" then
        section("UI SETTINGS")
        button("Toggle UI", function()
            State.Open = not State.Open
            main.Visible = State.Open
        end)
        button("Center UI", function()
            main.Position = UDim2.new(0.5, -325, 0.5, -235)
        end)
        button("Small UI", function()
            main.Size = UDim2.fromOffset(560, 420)
            main.Position = UDim2.new(0.5, -280, 0.5, -210)
        end)
        button("Large UI", function()
            main.Size = UDim2.fromOffset(760, 540)
            main.Position = UDim2.new(0.5, -380, 0.5, -270)
        end)
        button("Reset UI Size", function()
            main.Size = UDim2.fromOffset(650, 470)
            main.Position = UDim2.new(0.5, -325, 0.5, -235)
        end)
        section("INFO")
        button("Show Place Info", function()
            notify("Place", game.Name .. "  |  ID: " .. game.PlaceId, 5)
        end)
        button("Show Player Info", function()
            notify("Player", LocalPlayer.DisplayName .. "  @" .. LocalPlayer.Name, 5)
        end)
    end
end

-- Sidebar buttons
local sideList = Instance.new("UIListLayout")
sideList.Padding = UDim.new(0, 6)
sideList.Parent = sidebar

local sidePad = Instance.new("UIPadding")
sidePad.PaddingTop = UDim.new(0, 8)
sidePad.PaddingLeft = UDim.new(0, 8)
sidePad.PaddingRight = UDim.new(0, 8)
sidePad.Parent = sidebar

for _, category in ipairs(categories) do
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(1, 0, 0, 42)
    b.BackgroundColor3 = category == "PLAYER" and Color3.fromRGB(55, 75, 110) or Color3.fromRGB(29,31,40)
    b.BorderSizePixel = 0
    b.Text = category
    b.TextColor3 = Color3.fromRGB(235,238,245)
    b.Font = Enum.Font.GothamBold
    b.TextSize = 12
    b.Parent = sidebar
    Instance.new("UICorner", b).CornerRadius = UDim.new(0, 8)

    b.MouseButton1Click:Connect(function()
        for _, child in ipairs(sidebar:GetChildren()) do
            if child:IsA("TextButton") then
                child.BackgroundColor3 = Color3.fromRGB(29,31,40)
            end
        end
        b.BackgroundColor3 = Color3.fromRGB(55,75,110)
        render(category)
    end)
end

-- Dragging
local dragging = false
local dragStart, startPos
top.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1
    or input.UserInputType == Enum.UserInputType.Touch then
        dragging = true
        dragStart = input.Position
        startPos = main.Position
    end
end)

UserInputService.InputChanged:Connect(function(input)
    if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement
        or input.UserInputType == Enum.UserInputType.Touch) then
        local delta = input.Position - dragStart
        main.Position = UDim2.new(
            startPos.X.Scale, startPos.X.Offset + delta.X,
            startPos.Y.Scale, startPos.Y.Offset + delta.Y
        )
    end
end)

UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1
    or input.UserInputType == Enum.UserInputType.Touch then
        dragging = false
    end
end)

close.MouseButton1Click:Connect(function()
    State.Open = false
    main.Visible = false
end)

UserInputService.InputBegan:Connect(function(input, processed)
    if processed then return end

    if input.KeyCode == CONFIG.ToggleKey then
        State.Open = not State.Open
        main.Visible = State.Open
    end

    if State.InfiniteJump and input.KeyCode == Enum.KeyCode.Space then
        if Humanoid then
            Humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
        end
    end
end)

-- Anti-AFK: lightweight client heartbeat. In a real admin system,
-- prefer a server-side policy rather than trying to defeat platform systems.
local lastActivity = os.clock()
UserInputService.InputChanged:Connect(function()
    lastActivity = os.clock()
end)
UserInputService.InputBegan:Connect(function()
    lastActivity = os.clock()
end)

task.spawn(function()
    while gui.Parent do
        task.wait(20)
        if State.AntiAFK and os.clock() - lastActivity > 55 then
            if Humanoid and Root then
                Root.AssemblyLinearVelocity = Vector3.new(0, 0.1, 0)
                Humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
            end
            lastActivity = os.clock()
        end
    end
end)

-- Keep movement settings alive if enabled.
RunService.Heartbeat:Connect(function()
    if Humanoid then
        if State.SpeedEnabled and Humanoid.WalkSpeed < 60 then
            Humanoid.WalkSpeed = 60
        end
        if State.JumpEnabled and Humanoid.JumpPower < 100 then
            Humanoid.JumpPower = 100
        end
    end
end)

render("PLAYER")
notify("Roblox CoolUI", "Loaded! Press RightShift to open/close.", 4)
