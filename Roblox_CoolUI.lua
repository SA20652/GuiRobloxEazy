-- Roblox_CoolUI.lua
-- Вставь этот код в LocalScript (например, StarterPlayer > StarterPlayerScripts).
-- GUI создаётся полностью скриптом, дополнительные объекты в Studio не нужны.

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Lighting = game:GetService("Lighting")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- Удаляем старую версию GUI при повторном запуске
local oldGui = playerGui:FindFirstChild("CoolControlPanel")
if oldGui then
	oldGui:Destroy()
end

local gui = Instance.new("ScreenGui")
gui.Name = "CoolControlPanel"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.Parent = playerGui

local main = Instance.new("Frame")
main.Name = "Main"
main.Size = UDim2.fromOffset(330, 285)
main.Position = UDim2.new(0.5, -165, 0.5, -142)
main.BackgroundColor3 = Color3.fromRGB(22, 24, 32)
main.BorderSizePixel = 0
main.Parent = gui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 16)
corner.Parent = main

local stroke = Instance.new("UIStroke")
stroke.Color = Color3.fromRGB(90, 100, 140)
stroke.Thickness = 1.5
stroke.Transparency = 0.25
stroke.Parent = main

local gradient = Instance.new("UIGradient")
gradient.Color = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(31, 35, 50)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(17, 18, 25))
})
gradient.Rotation = 90
gradient.Parent = main

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, -55, 0, 42)
title.Position = UDim2.fromOffset(18, 8)
title.BackgroundTransparency = 1
title.Text = "✦ COOL CONTROL"
title.TextColor3 = Color3.fromRGB(240, 243, 255)
title.Font = Enum.Font.GothamBold
title.TextSize = 20
title.TextXAlignment = Enum.TextXAlignment.Left
title.Parent = main

local subtitle = Instance.new("TextLabel")
subtitle.Size = UDim2.new(1, -36, 0, 20)
subtitle.Position = UDim2.fromOffset(18, 42)
subtitle.BackgroundTransparency = 1
subtitle.Text = "Небольшая панель эффектов"
subtitle.TextColor3 = Color3.fromRGB(145, 150, 170)
subtitle.Font = Enum.Font.Gotham
subtitle.TextSize = 12
subtitle.TextXAlignment = Enum.TextXAlignment.Left
subtitle.Parent = main

local close = Instance.new("TextButton")
close.Size = UDim2.fromOffset(34, 34)
close.Position = UDim2.new(1, -44, 0, 10)
close.BackgroundColor3 = Color3.fromRGB(45, 48, 62)
close.Text = "×"
close.TextColor3 = Color3.fromRGB(230, 230, 240)
close.Font = Enum.Font.GothamBold
close.TextSize = 22
close.AutoButtonColor = false
close.Parent = main

local closeCorner = Instance.new("UICorner")
closeCorner.CornerRadius = UDim.new(0, 10)
closeCorner.Parent = close

local container = Instance.new("Frame")
container.Size = UDim2.new(1, -36, 0, 160)
container.Position = UDim2.fromOffset(18, 75)
container.BackgroundTransparency = 1
container.Parent = main

local layout = Instance.new("UIListLayout")
layout.Padding = UDim.new(0, 8)
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.Parent = container

local function makeButton(text, order)
	local b = Instance.new("TextButton")
	b.LayoutOrder = order
	b.Size = UDim2.new(1, 0, 0, 44)
	b.BackgroundColor3 = Color3.fromRGB(39, 42, 55)
	b.Text = text
	b.TextColor3 = Color3.fromRGB(235, 237, 245)
	b.Font = Enum.Font.GothamMedium
	b.TextSize = 14
	b.AutoButtonColor = false
	b.Parent = container

	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, 11)
	c.Parent = b

	local s = Instance.new("UIStroke")
	s.Color = Color3.fromRGB(70, 74, 95)
	s.Transparency = 0.55
	s.Parent = b

	b.MouseEnter:Connect(function()
		TweenService:Create(b, TweenInfo.new(0.15), {
			BackgroundColor3 = Color3.fromRGB(55, 59, 78)
		}):Play()
	end)

	b.MouseLeave:Connect(function()
		TweenService:Create(b, TweenInfo.new(0.15), {
			BackgroundColor3 = Color3.fromRGB(39, 42, 55)
		}):Play()
	end)

	return b
end

local themeButton = makeButton("🎨  Сменить тему", 1)
local nightButton = makeButton("🌙  Ночной режим", 2)
local pulseButton = makeButton("✨  Пульсация панели", 3)

local status = Instance.new("TextLabel")
status.Size = UDim2.new(1, -36, 0, 25)
status.Position = UDim2.new(0, 18, 1, -33)
status.BackgroundTransparency = 1
status.Text = "Готово • Панель активна"
status.TextColor3 = Color3.fromRGB(120, 220, 170)
status.Font = Enum.Font.Gotham
status.TextSize = 11
status.TextXAlignment = Enum.TextXAlignment.Left
status.Parent = main

-- Маленькая кнопка для повторного открытия
local openButton = Instance.new("TextButton")
openButton.Size = UDim2.fromOffset(52, 52)
openButton.Position = UDim2.new(0, 20, 0.5, -26)
openButton.BackgroundColor3 = Color3.fromRGB(31, 35, 50)
openButton.Text = "✦"
openButton.TextColor3 = Color3.fromRGB(230, 235, 255)
openButton.Font = Enum.Font.GothamBold
openButton.TextSize = 22
openButton.Visible = false
openButton.AutoButtonColor = false
openButton.Parent = gui

local openCorner = Instance.new("UICorner")
openCorner.CornerRadius = UDim.new(0, 16)
openCorner.Parent = openButton

local function setStatus(text, color)
	status.Text = text
	status.TextColor3 = color or Color3.fromRGB(120, 220, 170)
end

close.MouseButton1Click:Connect(function()
	TweenService:Create(main, TweenInfo.new(0.2), {
		Size = UDim2.fromOffset(0, 0)
	}):Play()
	task.wait(0.2)
	main.Visible = false
	openButton.Visible = true
end)

openButton.MouseButton1Click:Connect(function()
	openButton.Visible = false
	main.Visible = true
	main.Size = UDim2.fromOffset(0, 0)
	TweenService:Create(main, TweenInfo.new(0.25, Enum.EasingStyle.Back), {
		Size = UDim2.fromOffset(330, 285)
	}):Play()
end)

local themes = {
	{
		main = Color3.fromRGB(22, 24, 32),
		gradient1 = Color3.fromRGB(31, 35, 50),
		gradient2 = Color3.fromRGB(17, 18, 25),
		button = Color3.fromRGB(39, 42, 55),
		stroke = Color3.fromRGB(90, 100, 140)
	},
	{
		main = Color3.fromRGB(25, 19, 38),
		gradient1 = Color3.fromRGB(48, 29, 68),
		gradient2 = Color3.fromRGB(20, 15, 29),
		button = Color3.fromRGB(53, 38, 68),
		stroke = Color3.fromRGB(160, 105, 220)
	},
	{
		main = Color3.fromRGB(17, 31, 34),
		gradient1 = Color3.fromRGB(24, 55, 58),
		gradient2 = Color3.fromRGB(13, 22, 24),
		button = Color3.fromRGB(28, 53, 56),
		stroke = Color3.fromRGB(80, 190, 185)
	}
}

local themeIndex = 1

themeButton.MouseButton1Click:Connect(function()
	themeIndex = themeIndex % #themes + 1
	local t = themes[themeIndex]

	TweenService:Create(main, TweenInfo.new(0.25), {
		BackgroundColor3 = t.main
	}):Play()

	gradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, t.gradient1),
		ColorSequenceKeypoint.new(1, t.gradient2)
	})
	stroke.Color = t.stroke

	for _, child in ipairs(container:GetChildren()) do
		if child:IsA("TextButton") then
			child.BackgroundColor3 = t.button
		end
	end

	setStatus("Тема изменена • Вариант " .. themeIndex)
end)

local nightMode = false
local originalBrightness = Lighting.Brightness
local originalClockTime = Lighting.ClockTime

nightButton.MouseButton1Click:Connect(function()
	nightMode = not nightMode

	if nightMode then
		Lighting.Brightness = 0.7
		Lighting.ClockTime = 0
		setStatus("Ночной режим включён")
	else
		Lighting.Brightness = originalBrightness
		Lighting.ClockTime = originalClockTime
		setStatus("Ночной режим выключен")
	end
end)

local pulsing = false
pulseButton.MouseButton1Click:Connect(function()
	pulsing = not pulsing
	if pulsing then
		setStatus("Пульсация включена")
		task.spawn(function()
			while pulsing and main.Parent do
				TweenService:Create(stroke, TweenInfo.new(0.65), {
					Transparency = 0.05
				}):Play()
				task.wait(0.65)
				if not pulsing then break end
				TweenService:Create(stroke, TweenInfo.new(0.65), {
					Transparency = 0.55
				}):Play()
				task.wait(0.65)
			end
			stroke.Transparency = 0.25
		end)
	else
		setStatus("Пульсация выключена")
	end
end)

-- Перетаскивание панели мышью/тачем
local dragging = false
local dragStart
local startPos

main.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1
		or input.UserInputType == Enum.UserInputType.Touch then
		dragging = true
		dragStart = input.Position
		startPos = main.Position
	end
end)

UserInputService.InputChanged:Connect(function(input)
	if not dragging then return end

	if input.UserInputType == Enum.UserInputType.MouseMovement
		or input.UserInputType == Enum.UserInputType.Touch then

		local delta = input.Position - dragStart
		main.Position = UDim2.new(
			startPos.X.Scale,
			startPos.X.Offset + delta.X,
			startPos.Y.Scale,
			startPos.Y.Offset + delta.Y
		)
	end
end)

UserInputService.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1
		or input.UserInputType == Enum.UserInputType.Touch then
		dragging = false
	end
end)
