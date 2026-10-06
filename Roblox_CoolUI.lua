-- Roblox_CoolUI.lua
-- Standalone client-side CoolUI for Roblox executor/Delta.
-- No Config.lua, no server Script, no fake RemoteEvents.
-- Server-authoritative actions (kick/ban/kill/edit other players) are intentionally omitted.

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Lighting = game:GetService("Lighting")
local StarterGui = game:GetService("StarterGui")
local TeleportService = game:GetService("TeleportService")

local LocalPlayer = Players.LocalPlayer
if not LocalPlayer then
    return
end

local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")
local Camera = workspace.CurrentCamera

local CONFIG = {
    ToggleKey = Enum.KeyCode.RightShift,
    DefaultWalkSpeed = 16,
    DefaultJumpPower = 50,
    DefaultFOV = 70,
    DefaultFlySpeed = 70,
    MinWalkSpeed = 0,
    MaxWalkSpeed = 200,
    MinJumpPower = 0,
    MaxJumpPower = 200,
    MinFlySpeed = 10,
    MaxFlySpeed = 200,
    MinFOV = 40,
    MaxFOV = 120,
}

local State = {
    Minimized = false,
    Flying = false,
    Noclip = false,
    InfiniteJump = false,
    SpeedEnabled = false,
    JumpEnabled = false,
    FullBright = false,
    ESP = false,
    AntiAFK = false,

    WalkSpeed = CONFIG.DefaultWalkSpeed,
    JumpPower = CONFIG.DefaultJumpPower,
    FlySpeed = CONFIG.DefaultFlySpeed,
    FOV = CONFIG.DefaultFOV,

    SelectedPlayer = nil,
    SavedCFrame = nil,
    PreviousCFrame = nil,
    LastForwardCFrame = nil,

    Character = nil,
    Humanoid = nil,
    Root = nil,
    OriginalAutoRotate = true,

    FlyConnection = nil,
    NoclipConnection = nil,
    InfiniteJumpConnection = nil,
    CharacterConnection = nil,
    CameraConnection = nil,
    PlayerAddedConnection = nil,
    PlayerRemovingConnection = nil,
    ActivityConnections = {},
    ESPObjects = {},
    NoclipOriginal = {},
    OriginalLighting = {},

    MobileFlyUp = false,
    MobileFlyDown = false,
}

local Connections = {}

local function disconnect(connection)
    if connection then
        pcall(function() connection:Disconnect() end)
    end
end

local function bind(name, connection)
    disconnect(Connections[name])
    Connections[name] = connection
    return connection
end

local function notify(title, text, duration)
    pcall(function()
        StarterGui:SetCore("SendNotification", {
            Title = tostring(title),
            Text = tostring(text),
            Duration = duration or 3,
        })
    end)
end

local function getCamera()
    Camera = workspace.CurrentCamera or Camera
    return Camera
end

local function refreshCharacter()
    local character = LocalPlayer.Character
    State.Character = character
    State.Humanoid = nil
    State.Root = nil

    if not character then
        return nil, nil, nil
    end

    local humanoid = character:FindFirstChildOfClass("Humanoid")
    local root = character:FindFirstChild("HumanoidRootPart")

    if not humanoid then
        humanoid = character:WaitForChild("Humanoid", 3)
    end
    if not root then
        root = character:WaitForChild("HumanoidRootPart", 3)
    end

    State.Humanoid = humanoid
    State.Root = root

    if humanoid then
        State.OriginalAutoRotate = humanoid.AutoRotate
        if not State.SpeedEnabled then
            State.WalkSpeed = humanoid.WalkSpeed
        end
        if not State.JumpEnabled then
            State.JumpPower = humanoid.JumpPower
        end
    end

    return character, humanoid, root
end

refreshCharacter()

local function getCharacterParts()
    local character = State.Character
    local humanoid = State.Humanoid
    local root = State.Root

    if not character or not character.Parent then
        refreshCharacter()
        character, humanoid, root = State.Character, State.Humanoid, State.Root
    end

    if humanoid and not humanoid.Parent then
        refreshCharacter()
        character, humanoid, root = State.Character, State.Humanoid, State.Root
    end

    if character and not root then
        root = character:FindFirstChild("HumanoidRootPart")
        State.Root = root
    end

    return character, humanoid, root
end

local function getPlayerByName(text)
    if not text or text == "" then
        return nil
    end

    local needle = string.lower(string.gsub(text, "^%s*(.-)%s*$", "%1"))
    if needle == "" then
        return nil
    end

    for _, player in ipairs(Players:GetPlayers()) do
        if string.sub(string.lower(player.Name), 1, #needle) == needle
            or string.sub(string.lower(player.DisplayName), 1, #needle) == needle then
            return player
        end
    end

    return nil
end

local function getTargetRoot(player)
    if not player or player == LocalPlayer then
        return nil
    end

    local character = player.Character
    if not character then
        return nil
    end

    return character:FindFirstChild("HumanoidRootPart")
end

local function safeTeleport(cframe)
    local _, humanoid, root = getCharacterParts()
    if not root or not cframe then
        notify("Teleport", "Character is not ready.")
        return false
    end

    State.PreviousCFrame = root.CFrame
    root.CFrame = cframe
    if humanoid then
        humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
    end
    return true
end

local function teleportToPlayer(player)
    local targetRoot = getTargetRoot(player)
    if not targetRoot then
        notify("Teleport", "Target player has no character.")
        return false
    end

    return safeTeleport(targetRoot.CFrame + Vector3.new(0, 3, 0))
end

local function savePosition()
    local _, _, root = getCharacterParts()
    if root then
        State.SavedCFrame = root.CFrame
        notify("Teleport", "Position saved.")
        return true
    end
    notify("Teleport", "Character is not ready.")
    return false
end

local function teleportBack()
    if not State.SavedCFrame then
        notify("Teleport", "No saved position.")
        return false
    end
    return safeTeleport(State.SavedCFrame)
end

local function teleportForward()
    local _, _, root = getCharacterParts()
    if not root then
        notify("Teleport", "Character is not ready.")
        return false
    end

    State.PreviousCFrame = root.CFrame
    local destination = root.CFrame + root.CFrame.LookVector * 12
    return safeTeleport(destination)
end

local function teleportToSpawn()
    local _, _, root = getCharacterParts()
    if not root then
        notify("Teleport", "Character is not ready.")
        return false
    end

    local spawnLocation = workspace:FindFirstChildWhichIsA("SpawnLocation", true)
    if spawnLocation then
        return safeTeleport(spawnLocation.CFrame + Vector3.new(0, 4, 0))
    end

    notify("Teleport", "No SpawnLocation found in workspace.")
    return false
end

local function teleportToMouse()
    local _, _, root = getCharacterParts()
    if not root then
        notify("Teleport", "Character is not ready.")
        return false
    end

    local mouse = LocalPlayer:GetMouse()
    local hit = mouse and mouse.Hit
    if hit then
        return safeTeleport(CFrame.new(hit.Position + Vector3.new(0, 3, 0)))
    end

    notify("Teleport", "Mouse target is unavailable.")
    return false
end

-- Fly ------------------------------------------------------------------------

local function stopFly(silent)
    State.Flying = false
    State.MobileFlyUp = false
    State.MobileFlyDown = false

    disconnect(State.FlyConnection)
    State.FlyConnection = nil

    local _, humanoid, root = getCharacterParts()
    if humanoid then
        humanoid.AutoRotate = State.OriginalAutoRotate ~= false
        pcall(function()
            humanoid.PlatformStand = false
        end)
        pcall(function()
            humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
        end)
    end

    if root then
        root.AssemblyLinearVelocity = Vector3.zero
        root.AssemblyAngularVelocity = Vector3.zero
    end

    if not silent then
        notify("Fly", "Disabled")
    end
end

local function startFly(silent)
    local _, humanoid, root = getCharacterParts()
    if not humanoid or not root then
        notify("Fly", "Character is not ready.")
        return false
    end

    disconnect(State.FlyConnection)

    State.Flying = true
    State.OriginalAutoRotate = humanoid.AutoRotate
    humanoid.AutoRotate = false
    pcall(function()
        humanoid.PlatformStand = false
    end)

    State.FlyConnection = RunService.RenderStepped:Connect(function()
        if not State.Flying then
            return
        end

        local characterNow, humanoidNow, rootNow = getCharacterParts()
        local cameraNow = getCamera()

        if not characterNow or not humanoidNow or not rootNow or not cameraNow then
            return
        end

        if humanoidNow.Health <= 0 then
            return
        end

        -- Humanoid.MoveDirection is camera-relative and also receives the
        -- mobile thumbstick direction, so one movement path works on PC/mobile.
        local move = humanoidNow.MoveDirection
        local horizontal = Vector3.new(move.X, 0, move.Z)

        local vertical = 0
        if UserInputService:IsKeyDown(Enum.KeyCode.Space) or State.MobileFlyUp then
            vertical += 1
        end
        if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl)
            or UserInputService:IsKeyDown(Enum.KeyCode.LeftShift)
            or State.MobileFlyDown then
            vertical -= 1
        end

        local desired = horizontal
        if vertical ~= 0 then
            desired += Vector3.yAxis * vertical
        end

        if desired.Magnitude > 0.01 then
            rootNow.AssemblyLinearVelocity = desired.Unit * math.max(1, State.FlySpeed)
        else
            -- Keep the character suspended instead of letting gravity take over.
            rootNow.AssemblyLinearVelocity = Vector3.zero
        end

        -- Face the camera direction without forcing vertical pitch into the body.
        local look = cameraNow.CFrame.LookVector
        local flatLook = Vector3.new(look.X, 0, look.Z)
        if flatLook.Magnitude > 0.01 then
            rootNow.CFrame = CFrame.lookAt(rootNow.Position, rootNow.Position + flatLook.Unit)
        end
    end)

    if not silent then
        notify("Fly", "Enabled — joystick moves, ▲/▼ controls altitude.")
    end
    return true
end

local function toggleFly(value)
    if value then
        return startFly(false)
    end
    stopFly(false)
    return true
end

-- Noclip ---------------------------------------------------------------------

local function restoreNoclip()
    disconnect(State.NoclipConnection)
    State.NoclipConnection = nil

    for part, original in pairs(State.NoclipOriginal) do
        if part and part.Parent and part:IsA("BasePart") then
            pcall(function()
                part.CanCollide = original
            end)
        end
    end
    State.NoclipOriginal = {}
end

local function startNoclip()
    restoreNoclip()

    local character = State.Character
    if not character then
        refreshCharacter()
        character = State.Character
    end

    if not character then
        notify("Noclip", "Character is not ready.")
        return false
    end

    State.Noclip = true

    State.NoclipConnection = RunService.Stepped:Connect(function()
        if not State.Noclip then
            return
        end

        local currentCharacter = State.Character
        if not currentCharacter or not currentCharacter.Parent then
            return
        end

        for _, part in ipairs(currentCharacter:GetDescendants()) do
            if part:IsA("BasePart") then
                if State.NoclipOriginal[part] == nil then
                    State.NoclipOriginal[part] = part.CanCollide
                end
                if part.CanCollide then
                    part.CanCollide = false
                end
            end
        end
    end)

    notify("Noclip", "Enabled")
    return true
end

local function stopNoclip()
    State.Noclip = false
    restoreNoclip()
    notify("Noclip", "Disabled — original collisions restored.")
end

local function toggleNoclip(value)
    if value then
        return startNoclip()
    end
    stopNoclip()
    return true
end

-- Movement -------------------------------------------------------------------

local function applyMovement()
    local _, humanoid = getCharacterParts()
    if not humanoid then
        return
    end

    if State.SpeedEnabled then
        humanoid.WalkSpeed = State.WalkSpeed
    else
        humanoid.WalkSpeed = State.WalkSpeed
    end

    if State.JumpEnabled then
        humanoid.UseJumpPower = true
        humanoid.JumpPower = State.JumpPower
    else
        humanoid.UseJumpPower = true
        humanoid.JumpPower = State.JumpPower
    end
end

local function setWalkSpeed(value)
    local n = tonumber(value)
    if not n then
        notify("WalkSpeed", "Enter a number.")
        return false
    end

    State.WalkSpeed = math.clamp(n, CONFIG.MinWalkSpeed, CONFIG.MaxWalkSpeed)
    State.SpeedEnabled = true
    applyMovement()
    return true
end

local function setJumpPower(value)
    local n = tonumber(value)
    if not n then
        notify("JumpPower", "Enter a number.")
        return false
    end

    State.JumpPower = math.clamp(n, CONFIG.MinJumpPower, CONFIG.MaxJumpPower)
    State.JumpEnabled = true
    applyMovement()
    return true
end

local function setFOV(value)
    local n = tonumber(value)
    if not n then
        notify("FOV", "Enter a number.")
        return false
    end

    State.FOV = math.clamp(n, CONFIG.MinFOV, CONFIG.MaxFOV)
    local camera = getCamera()
    if camera then
        camera.FieldOfView = State.FOV
    end
    return true
end

local function resetMovement()
    if State.Flying then
        stopFly(true)
    end
    if State.Noclip then
        State.Noclip = false
        restoreNoclip()
    end

    State.SpeedEnabled = false
    State.JumpEnabled = false

    local _, humanoid, root = getCharacterParts()
    if humanoid then
        humanoid.WalkSpeed = CONFIG.DefaultWalkSpeed
        humanoid.UseJumpPower = true
        humanoid.JumpPower = CONFIG.DefaultJumpPower
        humanoid.AutoRotate = true
    end
    if root then
        root.AssemblyLinearVelocity = Vector3.zero
    end

    State.WalkSpeed = CONFIG.DefaultWalkSpeed
    State.JumpPower = CONFIG.DefaultJumpPower
    notify("Movement", "Movement reset.")
end

-- Infinite jump --------------------------------------------------------------

local function stopInfiniteJump()
    State.InfiniteJump = false
    disconnect(State.InfiniteJumpConnection)
    State.InfiniteJumpConnection = nil
end

local function startInfiniteJump()
    disconnect(State.InfiniteJumpConnection)

    State.InfiniteJump = true
    State.InfiniteJumpConnection = UserInputService.JumpRequest:Connect(function()
        if not State.InfiniteJump then
            return
        end

        local _, humanoid = getCharacterParts()
        if humanoid and humanoid.Health > 0 then
            humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
        end
    end)
end

local function toggleInfiniteJump(value)
    if value then
        startInfiniteJump()
        notify("Infinite Jump", "Enabled")
    else
        stopInfiniteJump()
        notify("Infinite Jump", "Disabled")
    end
end

-- Visuals --------------------------------------------------------------------

local function clearESP()
    for _, obj in ipairs(State.ESPObjects) do
        if obj and obj.Parent then
            pcall(function() obj:Destroy() end)
        end
    end
    State.ESPObjects = {}
end

local function addESP(player)
    if not State.ESP or player == LocalPlayer then
        return
    end

    local character = player.Character
    if not character then
        return
    end

    local head = character:FindFirstChild("Head")
    if not head then
        return
    end

    local billboard = Instance.new("BillboardGui")
    billboard.Name = "CoolUI_ESP"
    billboard.Size = UDim2.fromOffset(190, 42)
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
    if not State.ESP then
        return
    end

    for _, player in ipairs(Players:GetPlayers()) do
        addESP(player)
    end
end

local function setFullBright(enabled)
    if enabled then
        State.OriginalLighting = {
            Brightness = Lighting.Brightness,
            ClockTime = Lighting.ClockTime,
            FogEnd = Lighting.FogEnd,
            GlobalShadows = Lighting.GlobalShadows,
        }

        State.FullBright = true
        Lighting.Brightness = 3
        Lighting.ClockTime = 14
        Lighting.FogEnd = 100000
        Lighting.GlobalShadows = false
    else
        State.FullBright = false
        Lighting.Brightness = State.OriginalLighting.Brightness or 2
        Lighting.ClockTime = State.OriginalLighting.ClockTime or 14
        Lighting.FogEnd = State.OriginalLighting.FogEnd or 100000
        if State.OriginalLighting.GlobalShadows ~= nil then
            Lighting.GlobalShadows = State.OriginalLighting.GlobalShadows
        end
    end
end

-- Camera ---------------------------------------------------------------------

local function setFirstPerson()
    pcall(function()
        LocalPlayer.CameraMode = Enum.CameraMode.LockFirstPerson
    end)
end

local function setThirdPerson()
    pcall(function()
        LocalPlayer.CameraMode = Enum.CameraMode.Classic
    end)
end

local function resetCamera()
    local camera = getCamera()
    if camera then
        camera.FieldOfView = CONFIG.DefaultFOV
        State.FOV = CONFIG.DefaultFOV
    end
    local _, humanoid = getCharacterParts()
    if camera and humanoid then
        camera.CameraSubject = humanoid
    end
    setThirdPerson()
end

-- UI -------------------------------------------------------------------------

local existingGui = PlayerGui:FindFirstChild("Roblox_CoolUI")
if existingGui then
    pcall(function() existingGui:Destroy() end)
end

local gui = Instance.new("ScreenGui")
gui.Name = "Roblox_CoolUI"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.DisplayOrder = 999
gui.Parent = PlayerGui

local main = Instance.new("Frame")
main.Name = "Main"
main.AnchorPoint = Vector2.new(0.5, 0.5)
main.Position = UDim2.fromScale(0.5, 0.5)
main.Size = UDim2.fromOffset(760, 560)
main.BackgroundColor3 = Color3.fromRGB(17, 18, 24)
main.BorderSizePixel = 0
main.ClipsDescendants = true
main.Parent = gui

local mainCorner = Instance.new("UICorner")
mainCorner.CornerRadius = UDim.new(0, 14)
mainCorner.Parent = main

local mainStroke = Instance.new("UIStroke")
mainStroke.Color = Color3.fromRGB(80, 90, 120)
mainStroke.Transparency = 0.35
mainStroke.Parent = main

local uiScale = Instance.new("UIScale")
uiScale.Parent = main

local top = Instance.new("Frame")
top.Name = "TopBar"
top.Size = UDim2.new(1, 0, 0, 58)
top.BackgroundColor3 = Color3.fromRGB(25, 27, 36)
top.BorderSizePixel = 0
top.Parent = main

local topCorner = Instance.new("UICorner")
topCorner.CornerRadius = UDim.new(0, 14)
topCorner.Parent = top

local topFill = Instance.new("Frame")
topFill.Size = UDim2.new(1, 0, 0, 20)
topFill.Position = UDim2.new(0, 0, 1, -20)
topFill.BackgroundColor3 = top.BackgroundColor3
topFill.BorderSizePixel = 0
topFill.Parent = top

local title = Instance.new("TextLabel")
title.BackgroundTransparency = 1
title.Position = UDim2.fromOffset(17, 6)
title.Size = UDim2.new(1, -150, 0, 26)
title.Text = "ROBLOX COOL UI"
title.TextColor3 = Color3.fromRGB(255, 255, 255)
title.TextXAlignment = Enum.TextXAlignment.Left
title.Font = Enum.Font.GothamBold
title.TextSize = 19
title.Parent = top

local subtitle = Instance.new("TextLabel")
subtitle.BackgroundTransparency = 1
subtitle.Position = UDim2.fromOffset(18, 32)
subtitle.Size = UDim2.new(1, -155, 0, 18)
subtitle.Text = "Client Utility Panel  •  RightShift"
subtitle.TextColor3 = Color3.fromRGB(145, 150, 165)
subtitle.TextXAlignment = Enum.TextXAlignment.Left
subtitle.Font = Enum.Font.Gotham
subtitle.TextSize = 11
subtitle.Parent = top

local minimize = Instance.new("TextButton")
minimize.Name = "Minimize"
minimize.Size = UDim2.fromOffset(38, 34)
minimize.Position = UDim2.new(1, -94, 0, 11)
minimize.Text = "—"
minimize.TextSize = 21
minimize.Font = Enum.Font.GothamBold
minimize.TextColor3 = Color3.fromRGB(255, 255, 255)
minimize.BackgroundColor3 = Color3.fromRGB(65, 70, 88)
minimize.BorderSizePixel = 0
minimize.AutoButtonColor = false
minimize.Parent = top

local minimizeCorner = Instance.new("UICorner")
minimizeCorner.CornerRadius = UDim.new(0, 9)
minimizeCorner.Parent = minimize

local close = Instance.new("TextButton")
close.Name = "Close"
close.Size = UDim2.fromOffset(38, 34)
close.Position = UDim2.new(1, -49, 0, 11)
close.Text = "×"
close.TextSize = 24
close.Font = Enum.Font.GothamBold
close.TextColor3 = Color3.fromRGB(255, 255, 255)
close.BackgroundColor3 = Color3.fromRGB(190, 60, 75)
close.BorderSizePixel = 0
close.AutoButtonColor = false
close.Parent = top

local closeCorner = Instance.new("UICorner")
closeCorner.CornerRadius = UDim.new(0, 9)
closeCorner.Parent = close

local sidebar = Instance.new("Frame")
sidebar.Name = "Sidebar"
sidebar.Position = UDim2.fromOffset(9, 68)
sidebar.Size = UDim2.new(0, 170, 1, -77)
sidebar.BackgroundColor3 = Color3.fromRGB(21, 22, 30)
sidebar.BorderSizePixel = 0
sidebar.Parent = main

local sidebarCorner = Instance.new("UICorner")
sidebarCorner.CornerRadius = UDim.new(0, 10)
sidebarCorner.Parent = sidebar

local sideList = Instance.new("UIListLayout")
sideList.Padding = UDim.new(0, 6)
sideList.SortOrder = Enum.SortOrder.LayoutOrder
sideList.Parent = sidebar

local sidePad = Instance.new("UIPadding")
sidePad.PaddingTop = UDim.new(0, 8)
sidePad.PaddingLeft = UDim.new(0, 8)
sidePad.PaddingRight = UDim.new(0, 8)
sidePad.PaddingBottom = UDim.new(0, 8)
sidePad.Parent = sidebar

local content = Instance.new("ScrollingFrame")
content.Name = "Content"
content.Position = UDim2.new(0, 188, 0, 68)
content.Size = UDim2.new(1, -197, 1, -77)
content.BackgroundTransparency = 1
content.BorderSizePixel = 0
content.ScrollBarThickness = 5
content.ScrollBarImageTransparency = 0.2
content.CanvasSize = UDim2.new()
content.AutomaticCanvasSize = Enum.AutomaticSize.Y
content.ScrollingDirection = Enum.ScrollingDirection.Y
content.Parent = main

local contentList = Instance.new("UIListLayout")
contentList.Padding = UDim.new(0, 8)
contentList.SortOrder = Enum.SortOrder.LayoutOrder
contentList.Parent = content

local contentPad = Instance.new("UIPadding")
contentPad.PaddingTop = UDim.new(0, 2)
contentPad.PaddingBottom = UDim.new(0, 10)
contentPad.PaddingLeft = UDim.new(0, 2)
contentPad.PaddingRight = UDim.new(0, 8)
contentPad.Parent = content

local search = Instance.new("TextBox")
search.Name = "Search"
search.Size = UDim2.new(1, 0, 0, 38)
search.BackgroundColor3 = Color3.fromRGB(29, 31, 40)
search.BorderSizePixel = 0
search.PlaceholderText = "Search commands..."
search.PlaceholderColor3 = Color3.fromRGB(115, 120, 135)
search.Text = ""
search.TextColor3 = Color3.fromRGB(240, 240, 245)
search.Font = Enum.Font.Gotham
search.TextSize = 13
search.ClearTextOnFocus = false
search.LayoutOrder = -100
search.Parent = content

local searchCorner = Instance.new("UICorner")
searchCorner.CornerRadius = UDim.new(0, 9)
searchCorner.Parent = search

local restore = Instance.new("TextButton")
restore.Name = "RestoreButton"
restore.Size = UDim2.fromOffset(58, 58)
restore.AnchorPoint = Vector2.new(1, 1)
restore.Position = UDim2.new(1, -18, 1, -18)
restore.Text = "≡"
restore.TextSize = 25
restore.Font = Enum.Font.GothamBold
restore.TextColor3 = Color3.fromRGB(255, 255, 255)
restore.BackgroundColor3 = Color3.fromRGB(45, 75, 120)
restore.BorderSizePixel = 0
restore.AutoButtonColor = false
restore.Visible = false
restore.Parent = gui

local restoreCorner = Instance.new("UICorner")
restoreCorner.CornerRadius = UDim.new(0, 16)
restoreCorner.Parent = restore

local restoreStroke = Instance.new("UIStroke")
restoreStroke.Color = Color3.fromRGB(110, 170, 255)
restoreStroke.Transparency = 0.3
restoreStroke.Parent = restore

local mobileFly = Instance.new("Frame")
mobileFly.Name = "MobileFlyControls"
mobileFly.AnchorPoint = Vector2.new(1, 1)
mobileFly.Size = UDim2.fromOffset(164, 124)
mobileFly.Position = UDim2.new(1, -14, 1, -16)
mobileFly.BackgroundTransparency = 1
mobileFly.Visible = false
mobileFly.Parent = gui

local function mobileHoldButton(text, position, downCallback, upCallback)
    local b = Instance.new("TextButton")
    b.Size = UDim2.fromOffset(68, 50)
    b.Position = position
    b.Text = text
    b.TextSize = 18
    b.Font = Enum.Font.GothamBold
    b.TextColor3 = Color3.fromRGB(255, 255, 255)
    b.BackgroundColor3 = Color3.fromRGB(45, 48, 62)
    b.BorderSizePixel = 0
    b.AutoButtonColor = false
    b.Parent = mobileFly

    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, 13)
    c.Parent = b

    b.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Touch
            or input.UserInputType == Enum.UserInputType.MouseButton1 then
            downCallback()
            b.BackgroundColor3 = Color3.fromRGB(65, 85, 120)
        end
    end)

    b.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Touch
            or input.UserInputType == Enum.UserInputType.MouseButton1 then
            upCallback()
            b.BackgroundColor3 = Color3.fromRGB(45, 48, 62)
        end
    end)

    return b
end

mobileHoldButton("▲", UDim2.fromOffset(92, 0),
    function() State.MobileFlyUp = true end,
    function() State.MobileFlyUp = false end)

mobileHoldButton("▼", UDim2.fromOffset(92, 60),
    function() State.MobileFlyDown = true end,
    function() State.MobileFlyDown = false end)

local mobileHint = Instance.new("TextLabel")
mobileHint.Size = UDim2.fromOffset(88, 50)
mobileHint.Position = UDim2.fromOffset(0, 35)
mobileHint.BackgroundTransparency = 1
mobileHint.Text = "Joystick\n= move"
mobileHint.TextColor3 = Color3.fromRGB(220, 225, 235)
mobileHint.TextSize = 11
mobileHint.Font = Enum.Font.GothamMedium
mobileHint.TextWrapped = true
mobileHint.Parent = mobileFly

-- UI helpers -----------------------------------------------------------------

local function tween(instance, properties, duration)
    local ok, result = pcall(function()
        return TweenService:Create(instance, TweenInfo.new(
            duration or 0.12,
            Enum.EasingStyle.Quad,
            Enum.EasingDirection.Out
        ), properties)
    end)
    if ok and result then
        result:Play()
    end
end

local function styleButton(b)
    local normal = b.BackgroundColor3
    local hover = Color3.fromRGB(53, 57, 74)
    local pressed = Color3.fromRGB(70, 84, 112)

    b.MouseEnter:Connect(function()
        if not UserInputService.TouchEnabled then
            tween(b, {BackgroundColor3 = hover}, 0.10)
        end
    end)

    b.MouseLeave:Connect(function()
        if b:GetAttribute("ToggleOn") then
            return
        end
        tween(b, {BackgroundColor3 = normal}, 0.10)
    end)

    b.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Touch
            or input.UserInputType == Enum.UserInputType.MouseButton1 then
            tween(b, {BackgroundColor3 = pressed}, 0.06)
        end
    end)

    b.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Touch
            or input.UserInputType == Enum.UserInputType.MouseButton1 then
            if b:GetAttribute("ToggleOn") then
                tween(b, {BackgroundColor3 = Color3.fromRGB(40, 100, 75)}, 0.08)
            else
                tween(b, {BackgroundColor3 = normal}, 0.08)
            end
        end
    end)
end

local function clearContent()
    for _, child in ipairs(content:GetChildren()) do
        if child ~= search and not child:IsA("UIListLayout") and not child:IsA("UIPadding") then
            child:Destroy()
        end
    end
end

local function section(text)
    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, 0, 0, 25)
    label.BackgroundTransparency = 1
    label.Text = "  " .. text
    label.TextColor3 = Color3.fromRGB(110, 170, 255)
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Font = Enum.Font.GothamBold
    label.TextSize = 13
    label:SetAttribute("SearchText", string.lower(text))
    label.Parent = content
    return label
end

local function button(text, callback, commandName)
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(1, 0, 0, 44)
    b.BackgroundColor3 = Color3.fromRGB(45, 48, 62)
    b.BorderSizePixel = 0
    b.Text = text
    b.TextColor3 = Color3.fromRGB(235, 238, 245)
    b.TextSize = 13
    b.Font = Enum.Font.GothamMedium
    b.TextWrapped = true
    b.AutoButtonColor = false
    b:SetAttribute("SearchText", string.lower((commandName or text) .. " " .. text))
    b.Parent = content

    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, 9)
    c.Parent = b

    styleButton(b)

    b.Activated:Connect(function()
        local ok, err = pcall(callback, b)
        if not ok then
            warn("[Roblox_CoolUI] Button error:", err)
            notify("CoolUI", "Action failed. Check executor output.")
        end
    end)

    return b
end

local function textbox(placeholder, initial)
    local t = Instance.new("TextBox")
    t.Size = UDim2.new(1, 0, 0, 42)
    t.BackgroundColor3 = Color3.fromRGB(29, 31, 40)
    t.BorderSizePixel = 0
    t.PlaceholderText = placeholder
    t.Text = initial or ""
    t.TextColor3 = Color3.fromRGB(240, 240, 245)
    t.PlaceholderColor3 = Color3.fromRGB(115, 120, 135)
    t.Font = Enum.Font.Gotham
    t.TextSize = 13
    t.ClearTextOnFocus = false
    t.TextWrapped = false
    t.Parent = content

    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, 9)
    c.Parent = t

    return t
end

local function toggle(text, getter, setter)
    local b

    local function update()
        local on = getter()
        b.Text = text .. (on and "   [ON]" or "   [OFF]")
        b:SetAttribute("ToggleOn", on)

        local color = on
            and Color3.fromRGB(40, 100, 75)
            or Color3.fromRGB(31, 33, 42)

        tween(b, {BackgroundColor3 = color}, 0.10)
    end

    b = button(text, function()
        local ok, result = pcall(setter, not getter())
        if not ok then
            warn("[Roblox_CoolUI] Toggle error:", result)
        end
        update()
    end, text)

    update()
    return b
end

local function numericBox(labelText, value, minValue, maxValue, apply)
    section(labelText)
    local box = textbox(
        tostring(minValue) .. " - " .. tostring(maxValue),
        tostring(value)
    )

    box.FocusLost:Connect(function()
        local n = tonumber(box.Text)
        if not n then
            box.Text = tostring(value)
            notify(labelText, "Invalid number.")
            return
        end

        n = math.clamp(n, minValue, maxValue)
        box.Text = tostring(n)
        apply(n)
    end)

    return box
end

local function setMinimized(value)
    State.Minimized = value

    if value then
        tween(main, {Size = UDim2.fromOffset(300, 230)}, 0.18)
        task.delay(0.18, function()
            if State.Minimized then
                main.Visible = false
                restore.Visible = true
                restore.Size = UDim2.fromOffset(10, 10)
                tween(restore, {Size = UDim2.fromOffset(58, 58)}, 0.18)
            end
        end)
    else
        restore.Visible = false
        main.Visible = true
        task.defer(function()
            updateResponsiveSize()
            tween(main, {BackgroundTransparency = 0}, 0.12)
        end)
    end

    mobileFly.Visible = (not value) and State.Flying and UserInputService.TouchEnabled
end

-- Responsive sizing ----------------------------------------------------------

function updateResponsiveSize()
    if State.Minimized then
        return
    end

    local camera = getCamera()
    local viewport = camera and camera.ViewportSize or Vector2.new(1280, 720)

    local width = math.clamp(math.floor(viewport.X * 0.92), 285, 760)
    local height = math.clamp(math.floor(viewport.Y * 0.84), 350, 560)

    -- On very short screens keep enough room for touch buttons without
    -- allowing the window to exceed the viewport.
    if viewport.Y < 520 then
        height = math.clamp(math.floor(viewport.Y * 0.80), 300, 500)
    end

    main.Size = UDim2.fromOffset(width, height)

    local compact = viewport.X < 650
    if compact then
        sidebar.Size = UDim2.new(0, math.clamp(math.floor(width * 0.26), 76, 118), 1, -77)
        content.Position = UDim2.new(0, math.clamp(math.floor(width * 0.29), 85, 130), 0, 68)
        content.Size = UDim2.new(1, -math.clamp(math.floor(width * 0.29), 85, 130) - 9, 1, -77)
        title.TextSize = 17
        subtitle.TextSize = 10
    else
        sidebar.Size = UDim2.new(0, 170, 1, -77)
        content.Position = UDim2.new(0, 188, 0, 68)
        content.Size = UDim2.new(1, -197, 1, -77)
        title.TextSize = 19
        subtitle.TextSize = 11
    end

    for _, child in ipairs(sidebar:GetChildren()) do
        if child:IsA("TextButton") then
            child.TextSize = compact and 10 or 12
            child.Size = UDim2.new(1, 0, 0, compact and 40 or 42)
        end
    end
end

local function bindViewport()
    disconnect(Connections.Viewport)
    local camera = getCamera()
    if camera then
        Connections.Viewport = camera:GetPropertyChangedSignal("ViewportSize"):Connect(updateResponsiveSize)
    end
end

bindViewport()
bind("CurrentCamera", workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
    getCamera()
    bindViewport()
    updateResponsiveSize()
end))

-- Categories -----------------------------------------------------------------

local categories = {
    "PLAYER",
    "CHARACTER",
    "MOVEMENT",
    "VISUAL",
    "FUN",
    "TELEPORT",
    "PLAYERS",
    "UTILITY",
}

local activeCategory = "PLAYER"
local sideButtons = {}

local function applySearch()
    local query = string.lower(string.gsub(search.Text or "", "^%s*(.-)%s*$", "%1"))
    if query == "" then
        for _, child in ipairs(content:GetChildren()) do
            if child:IsA("TextButton") or child:IsA("TextLabel") or child:IsA("TextBox") then
                child.Visible = true
            end
        end
        search.Visible = true
        return
    end

    for _, child in ipairs(content:GetChildren()) do
        if child ~= search and (child:IsA("TextButton") or child:IsA("TextLabel") or child:IsA("TextBox")) then
            local searchable = child:GetAttribute("SearchText") or ""
            child.Visible = string.find(string.lower(searchable), query, 1, true) ~= nil
        end
    end
    search.Visible = true
end

local function render(category)
    activeCategory = category
    clearContent()
    search.Text = ""

    if category == "PLAYER" then
        section("PLAYER CONTROLS")

        toggle("Infinite Jump", function() return State.InfiniteJump end, toggleInfiniteJump)

        toggle("Noclip", function() return State.Noclip end, function(v)
            toggleNoclip(v)
        end)

        toggle("Fly", function() return State.Flying end, function(v)
            toggleFly(v)
            mobileFly.Visible = v and UserInputService.TouchEnabled and not State.Minimized
        end)

        button("Heal Self", function()
            local _, humanoid = getCharacterParts()
            if humanoid then
                humanoid.Health = humanoid.MaxHealth
                notify("Player", "Healed.")
            else
                notify("Player", "Humanoid not found.")
            end
        end)

        button("Reset Character", function()
            local _, humanoid = getCharacterParts()
            if humanoid then
                humanoid.Health = 0
            end
        end)

        button("Force Jump", function()
            local _, humanoid = getCharacterParts()
            if humanoid then
                humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
            end
        end)

        button("Sit / Stand", function()
            local _, humanoid = getCharacterParts()
            if humanoid then
                humanoid.Sit = not humanoid.Sit
            end
        end)

        button("Reset Movement", resetMovement)

    elseif category == "CHARACTER" then
        section("CHARACTER SETTINGS")

        numericBox("WalkSpeed", State.WalkSpeed, CONFIG.MinWalkSpeed, CONFIG.MaxWalkSpeed, setWalkSpeed)
        numericBox("JumpPower", State.JumpPower, CONFIG.MinJumpPower, CONFIG.MaxJumpPower, setJumpPower)

        toggle("WalkSpeed Override", function() return State.SpeedEnabled end, function(v)
            State.SpeedEnabled = v
            applyMovement()
        end)

        toggle("JumpPower Override", function() return State.JumpEnabled end, function(v)
            State.JumpEnabled = v
            applyMovement()
        end)

        numericBox("HipHeight", (State.Humanoid and State.Humanoid.HipHeight) or 2, 0, 20, function(n)
            local _, humanoid = getCharacterParts()
            if humanoid then
                humanoid.HipHeight = n
            end
        end)

        button("First Person", setFirstPerson)
        button("Third Person", setThirdPerson)

    elseif category == "MOVEMENT" then
        section("MOVEMENT")

        numericBox("WalkSpeed", State.WalkSpeed, CONFIG.MinWalkSpeed, CONFIG.MaxWalkSpeed, setWalkSpeed)
        numericBox("JumpPower", State.JumpPower, CONFIG.MinJumpPower, CONFIG.MaxJumpPower, setJumpPower)
        numericBox("Fly Speed", State.FlySpeed, CONFIG.MinFlySpeed, CONFIG.MaxFlySpeed, function(n)
            State.FlySpeed = n
        end)
        numericBox("FOV", State.FOV, CONFIG.MinFOV, CONFIG.MaxFOV, setFOV)

        toggle("Fly", function() return State.Flying end, function(v)
            toggleFly(v)
            mobileFly.Visible = v and UserInputService.TouchEnabled and not State.Minimized
        end)

        toggle("Noclip", function() return State.Noclip end, function(v)
            toggleNoclip(v)
        end)

        button("Reset Movement", resetMovement)

        section("FLY CONTROLS")
        button("PC: Space = Up / Shift or Ctrl = Down", function()
            notify("Fly", "Use the camera + WASD, Space for up, Shift/Ctrl for down.")
        end)

    elseif category == "VISUAL" then
        section("VISUAL")

        toggle("Player ESP", function() return State.ESP end, function(v)
            State.ESP = v
            rebuildESP()
        end)

        toggle("Full Bright", function() return State.FullBright end, function(v)
            setFullBright(v)
        end)

        numericBox("FOV", State.FOV, CONFIG.MinFOV, CONFIG.MaxFOV, setFOV)
        button("FOV 70", function() setFOV(70) end)
        button("FOV 90", function() setFOV(90) end)
        button("FOV 110", function() setFOV(110) end)
        button("First Person", setFirstPerson)
        button("Third Person", setThirdPerson)
        button("Reset Camera", resetCamera)

        button("Hide Other ScreenGuis", function()
            for _, child in ipairs(PlayerGui:GetChildren()) do
                if child ~= gui and child:IsA("ScreenGui") then
                    child:SetAttribute("CoolUI_PreviousEnabled", child.Enabled)
                    child.Enabled = false
                end
            end
        end)

        button("Restore Other ScreenGuis", function()
            for _, child in ipairs(PlayerGui:GetChildren()) do
                if child ~= gui and child:IsA("ScreenGui") then
                    local previous = child:GetAttribute("CoolUI_PreviousEnabled")
                    child.Enabled = previous == nil and true or previous
                    child:SetAttribute("CoolUI_PreviousEnabled", nil)
                end
            end
        end)

    elseif category == "FUN" then
        section("CLIENT-SIDE FUN")

        button("Day", function() Lighting.ClockTime = 14 end)
        button("Night", function() Lighting.ClockTime = 0 end)
        button("Sunset", function() Lighting.ClockTime = 18 end)
        button("Clear Fog", function() Lighting.FogEnd = 100000 end)

        button("Low Gravity Feel", function()
            local _, _, root = getCharacterParts()
            if root then
                root.AssemblyLinearVelocity += Vector3.new(0, 50, 0)
            end
        end)

        button("Spawn Personal Platform", function()
            local _, _, root = getCharacterParts()
            if not root then
                notify("Fun", "Character is not ready.")
                return
            end

            local part = Instance.new("Part")
            part.Name = "CoolUI_Platform"
            part.Size = Vector3.new(10, 1, 10)
            part.Anchored = true
            part.CanCollide = true
            part.CFrame = root.CFrame * CFrame.new(0, -4, 0)
            part.Parent = workspace

            task.delay(20, function()
                if part and part.Parent then
                    part:Destroy()
                end
            end)

            notify("Fun", "Platform created for 20 seconds.")
        end)

        button("Local Notification Test", function()
            notify("CoolUI", "Client notification works.")
        end)

    elseif category == "TELEPORT" then
        section("CLIENT TELEPORTS")

        button("Save Position", savePosition)
        button("Teleport Back", teleportBack)
        button("Teleport Forward 12 studs", teleportForward)
        button("Teleport To Spawn", teleportToSpawn)
        button("Teleport To Mouse", teleportToMouse)

        section("SAVED STATE")
        local savedText = State.SavedCFrame and "Saved position: YES" or "Saved position: NO"
        button(savedText, function()
            if State.SavedCFrame then
                notify("Teleport", "A position is saved.")
            else
                notify("Teleport", "Nothing is saved yet.")
            end
        end)

        section("PLAYER TELEPORT")
        local targetBox = textbox("Player name / display name")
        button("Select Player", function()
            local player = getPlayerByName(targetBox.Text)
            State.SelectedPlayer = player

            if player then
                notify("Selected", player.DisplayName .. "  @" .. player.Name)
            else
                notify("Teleport", "Player not found.")
            end
        end)

        button("Teleport To Selected", function()
            if State.SelectedPlayer then
                teleportToPlayer(State.SelectedPlayer)
            else
                notify("Teleport", "Select a player first.")
            end
        end)

        button("View Selected", function()
            local player = State.SelectedPlayer
            local camera = getCamera()
            local character = player and player.Character
            local humanoid = character and character:FindFirstChildOfClass("Humanoid")

            if camera and humanoid then
                camera.CameraSubject = humanoid
                notify("Camera", "Viewing " .. player.DisplayName)
            else
                notify("Camera", "Target is unavailable.")
            end
        end)

        button("Return Camera", function()
            local camera = getCamera()
            local _, humanoid = getCharacterParts()
            if camera and humanoid then
                camera.CameraSubject = humanoid
            end
        end)

        section("CLIENT LIMIT")
        button("Bring / Server Move: NOT AVAILABLE", function()
            notify("Client Limit", "Moving another player's character requires server authority in normal Roblox networking.")
        end)

    elseif category == "PLAYERS" then
        section("PLAYER LIST")

        local selectedName = State.SelectedPlayer
            and (State.SelectedPlayer.DisplayName .. "  @" .. State.SelectedPlayer.Name)
            or "No player selected"

        button("Selected: " .. selectedName, function()
            if State.SelectedPlayer then
                notify("Selected", State.SelectedPlayer.Name)
            end
        end)

        for _, player in ipairs(Players:GetPlayers()) do
            if player ~= LocalPlayer then
                button(
                    player.DisplayName .. "  @" .. player.Name,
                    function()
                        State.SelectedPlayer = player
                        notify("Selected", player.DisplayName .. "  @" .. player.Name)
                    end,
                    player.Name .. " " .. player.DisplayName
                )
            end
        end

        section("AVAILABLE CLIENT ACTIONS")
        button("Teleport To Selected", function()
            if State.SelectedPlayer then
                teleportToPlayer(State.SelectedPlayer)
            else
                notify("Players", "Select a player first.")
            end
        end)

        button("View Selected", function()
            local player = State.SelectedPlayer
            local camera = getCamera()
            local humanoid = player and player.Character and player.Character:FindFirstChildOfClass("Humanoid")
            if camera and humanoid then
                camera.CameraSubject = humanoid
            end
        end)

        button("Server Kick / Ban / Kill: unavailable", function()
            notify("Client Limit", "These are server-authoritative actions and are not faked by this UI.")
        end)

    elseif category == "UTILITY" then
        section("UTILITY")

        toggle("Anti AFK", function() return State.AntiAFK end, function(v)
            State.AntiAFK = v
            notify("Anti AFK", v and "Enabled" or "Disabled")
        end)

        button("Respawn", function()
            local _, humanoid = getCharacterParts()
            if humanoid then
                humanoid.Health = 0
            end
        end)

        button("Sit / Stand", function()
            local _, humanoid = getCharacterParts()
            if humanoid then
                humanoid.Sit = not humanoid.Sit
            end
        end)

        button("Reset Camera", resetCamera)

        button("Copy Place ID", function()
            if setclipboard then
                local ok = pcall(setclipboard, tostring(game.PlaceId))
                if ok then
                    notify("Utility", "Place ID copied.")
                    return
                end
            end
            notify("Place ID", tostring(game.PlaceId))
        end)

        button("Rejoin Server", function()
            local ok, err = pcall(function()
                TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, LocalPlayer)
            end)
            if not ok then
                notify("Rejoin", "Teleport failed: " .. tostring(err))
            end
        end)

        button("Center UI", function()
            main.Position = UDim2.fromScale(0.5, 0.5)
        end)

        button("Close / Minimize UI", function()
            setMinimized(true)
        end)

        section("CLIENT LIMITS")
        button("Admin Commands: server required", function()
            notify("Client Limit", "Kick, ban, server-side kill and editing other players require a real server mechanism.")
        end)

        button("No fake RemoteEvents", function()
            notify("CoolUI", "This standalone file does not create fake server remotes.")
        end)
    end

    applySearch()
    updateResponsiveSize()

    for name, child in pairs(sideButtons) do
        child:SetAttribute("SidebarSelected", name == category)
        child.BackgroundColor3 = (name == category)
            and Color3.fromRGB(55, 75, 110)
            or Color3.fromRGB(29, 31, 40)
    end
end

-- Sidebar --------------------------------------------------------------------

for index, category in ipairs(categories) do
    local b = Instance.new("TextButton")
    b.Name = category
    b.Size = UDim2.new(1, 0, 0, 42)
    b.LayoutOrder = index
    b.BackgroundColor3 = category == activeCategory
        and Color3.fromRGB(55, 75, 110)
        or Color3.fromRGB(29, 31, 40)
    b.BorderSizePixel = 0
    b.Text = category
    b.TextColor3 = Color3.fromRGB(235, 238, 245)
    b.Font = Enum.Font.GothamBold
    b.TextSize = 12
    b.AutoButtonColor = false
    b.Parent = sidebar

    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, 8)
    c.Parent = b

    sideButtons[category] = b
    -- Sidebar buttons use their own selected-state styling.
    b:SetAttribute("SidebarSelected", category == activeCategory)

    b.MouseEnter:Connect(function()
        if not UserInputService.TouchEnabled and not b:GetAttribute("SidebarSelected") then
            tween(b, {BackgroundColor3 = Color3.fromRGB(53, 57, 74)}, 0.10)
        end
    end)
    b.MouseLeave:Connect(function()
        if not b:GetAttribute("SidebarSelected") then
            tween(b, {BackgroundColor3 = Color3.fromRGB(29, 31, 40)}, 0.10)
        end
    end)

    b.Activated:Connect(function()
        for name, child in pairs(sideButtons) do
            child:SetAttribute("SidebarSelected", name == category)
            tween(child, {
                BackgroundColor3 = (name == category)
                    and Color3.fromRGB(55, 75, 110)
                    or Color3.fromRGB(29, 31, 40)
            }, 0.10)
        end

        render(category)
    end)
end

-- Dragging -------------------------------------------------------------------

local dragging = false
local dragStart = nil
local startPosition = nil

local function beginDrag(input)
    if input.UserInputType ~= Enum.UserInputType.MouseButton1
        and input.UserInputType ~= Enum.UserInputType.Touch then
        return
    end

    dragging = true
    dragStart = input.Position
    startPosition = main.Position
end

top.InputBegan:Connect(beginDrag)

UserInputService.InputChanged:Connect(function(input)
    if not dragging or not dragStart or not startPosition then
        return
    end

    if input.UserInputType ~= Enum.UserInputType.MouseMovement
        and input.UserInputType ~= Enum.UserInputType.Touch then
        return
    end

    local delta = input.Position - dragStart
    main.Position = UDim2.new(
        startPosition.X.Scale,
        startPosition.X.Offset + delta.X,
        startPosition.Y.Scale,
        startPosition.Y.Offset + delta.Y
    )
end)

UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
        dragging = false
    end
end)

-- UI buttons -----------------------------------------------------------------

minimize.Activated:Connect(function()
    setMinimized(true)
end)

close.Activated:Connect(function()
    -- "Close" intentionally means minimize so the UI is never permanently lost.
    setMinimized(true)
end)

restore.Activated:Connect(function()
    setMinimized(false)
end)

search:GetPropertyChangedSignal("Text"):Connect(applySearch)

UserInputService.InputBegan:Connect(function(input, processed)
    if input.KeyCode == CONFIG.ToggleKey and not processed then
        setMinimized(not State.Minimized)
    end
end)

-- Character lifecycle --------------------------------------------------------

bind("CharacterAdded", LocalPlayer.CharacterAdded:Connect(function()
    -- Remember toggles so enabled features can safely resume on respawn.
    local resumeFly = State.Flying
    local resumeNoclip = State.Noclip

    stopFly(true)
    State.Noclip = false
    restoreNoclip()

    task.defer(function()
        local _, humanoid, root = refreshCharacter()
        if humanoid then
            task.wait(0.15)
            if State.SpeedEnabled or State.JumpEnabled then
                applyMovement()
            end
        end

        if resumeFly then
            startFly(true)
        end
        if resumeNoclip then
            startNoclip()
        end

        if root and State.SavedCFrame == nil then
            State.SavedCFrame = root.CFrame
        end

        if State.ESP then
            rebuildESP()
        end
    end)
end))

-- Player lifecycle / live player list ---------------------------------------

bind("PlayerAdded", Players.PlayerAdded:Connect(function(player)
    player.CharacterAdded:Connect(function()
        if State.ESP then
            task.delay(0.4, rebuildESP)
        end
    end)

    if activeCategory == "PLAYERS" then
        task.defer(function()
            if gui.Parent then
                render("PLAYERS")
            end
        end)
    end
end))

bind("PlayerRemoving", Players.PlayerRemoving:Connect(function(player)
    if State.SelectedPlayer == player then
        State.SelectedPlayer = nil
    end

    if State.ESP then
        rebuildESP()
    end

    if activeCategory == "PLAYERS" then
        task.defer(function()
            if gui.Parent then
                render("PLAYERS")
            end
        end)
    end
end))

-- Anti-AFK -------------------------------------------------------------------

local lastActivity = os.clock()

table.insert(State.ActivityConnections, UserInputService.InputBegan:Connect(function()
    lastActivity = os.clock()
end))

table.insert(State.ActivityConnections, UserInputService.InputChanged:Connect(function()
    lastActivity = os.clock()
end))

bind("AntiAFK", RunService.Heartbeat:Connect(function()
    if not State.AntiAFK then
        return
    end

    if os.clock() - lastActivity < 55 then
        return
    end

    local _, humanoid, root = getCharacterParts()
    if humanoid and root and humanoid.Health > 0 then
        pcall(function()
            humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
        end)
        lastActivity = os.clock()
    end
end))

-- Lightweight movement enforcement only while overrides are enabled.
bind("Movement", RunService.Heartbeat:Connect(function()
    if not State.SpeedEnabled and not State.JumpEnabled then
        return
    end

    local _, humanoid = getCharacterParts()
    if not humanoid or humanoid.Health <= 0 then
        return
    end

    if State.SpeedEnabled and math.abs(humanoid.WalkSpeed - State.WalkSpeed) > 0.05 then
        humanoid.WalkSpeed = State.WalkSpeed
    end

    if State.JumpEnabled and math.abs(humanoid.JumpPower - State.JumpPower) > 0.05 then
        humanoid.UseJumpPower = true
        humanoid.JumpPower = State.JumpPower
    end
end))

-- Keep the UI inside the visible viewport when the resolution changes.
updateResponsiveSize()
render("PLAYER")

-- Mobile fly controls are only useful when touch input exists.
mobileFly.Visible = State.Flying and UserInputService.TouchEnabled

notify("Roblox CoolUI", "Loaded — RightShift opens/minimizes the UI.", 4)

-- Cleanup if the executor/game removes the GUI.
gui.AncestryChanged:Connect(function(_, parent)
    if parent then
        return
    end

    stopFly(true)
    State.Noclip = false
    restoreNoclip()
    stopInfiniteJump()
    clearESP()

    for name, connection in pairs(Connections) do
        disconnect(connection)
        Connections[name] = nil
    end

    for _, connection in ipairs(State.ActivityConnections) do
        disconnect(connection)
    end
    State.ActivityConnections = {}
end)
