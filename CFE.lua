-- CFE 🌺 All In One Chat + UI + Donations
-- Place as Script in ServerScriptService

local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- ================= SERVER =================
if RunService:IsServer() then
	local evt = ReplicatedStorage:FindFirstChild("CFE_Event")
	if not evt then
		evt = Instance.new("RemoteEvent")
		evt.Name = "CFE_Event"
		evt.Parent = ReplicatedStorage
	end

	evt.OnServerEvent:Connect(function(player, action, data)
		if action == "SendPrivate" then
			local target = Players:FindFirstChild(data.To)
			if target then
				evt:FireClient(target, "Receive", {
					From = player.Name,
					Msg = data.Msg
				})
			end
		end
	end)
	return
end

-- ================= CLIENT =================
local player = Players.LocalPlayer
local TweenService = game:GetService("TweenService")
local MarketplaceService = game:GetService("MarketplaceService")
local evt = ReplicatedStorage:WaitForChild("CFE_Event")

-- ===== GUI =====
local gui = Instance.new("ScreenGui", player.PlayerGui)
gui.Name = "CFE_GUI"
gui.ResetOnSpawn = false

local main = Instance.new("Frame", gui)
main.Size = UDim2.fromScale(0.6,0.6)
main.Position = UDim2.fromScale(0.2,0.2)
main.BackgroundColor3 = Color3.fromRGB(10,10,10)
main.BackgroundTransparency = 0.15
Instance.new("UICorner", main).CornerRadius = UDim.new(0,20)

-- ===== Sidebar =====
local side = Instance.new("Frame", main)
side.Size = UDim2.fromScale(0.22,1)
side.BackgroundColor3 = Color3.fromRGB(12,12,12)
side.BackgroundTransparency = 0.2
Instance.new("UICorner", side).CornerRadius = UDim.new(0,18)

local title = Instance.new("TextLabel", side)
title.Size = UDim2.fromScale(1,0.12)
title.BackgroundTransparency = 1
title.Text = "CFE 🌺"
title.Font = Enum.Font.GothamBold
title.TextScaled = true
title.TextColor3 = Color3.new(1,1,1)

-- ===== Buttons =====
local function sideBtn(txt, y)
	local b = Instance.new("TextButton", side)
	b.Size = UDim2.fromScale(0.9,0.1)
	b.Position = UDim2.fromScale(0.05,y)
	b.Text = txt
	b.Font = Enum.Font.Gotham
	b.TextScaled = true
	b.BackgroundColor3 = Color3.fromRGB(30,30,30)
	b.TextColor3 = Color3.new(1,1,1)
	Instance.new("UICorner", b).CornerRadius = UDim.new(0,12)
	return b
end

local chatBtn = sideBtn("💬 Chat",0.18)
local donateBtn = sideBtn("🌺 Donations",0.32)

-- ===== Chat Panel =====
local chat = Instance.new("Frame", main)
chat.Size = UDim2.fromScale(0.72,0.8)
chat.Position = UDim2.fromScale(0.25,0.1)
chat.BackgroundTransparency = 1

local playersBox = Instance.new("TextButton", chat)
playersBox.Size = UDim2.fromScale(0.4,0.15)
playersBox.Text = "Select Player"
playersBox.Font = Enum.Font.Gotham
playersBox.TextScaled = true
playersBox.BackgroundColor3 = Color3.fromRGB(25,25,25)
playersBox.TextColor3 = Color3.new(1,1,1)
Instance.new("UICorner", playersBox).CornerRadius = UDim.new(0,12)

local msgBox = Instance.new("TextBox", chat)
msgBox.Size = UDim2.fromScale(0.7,0.15)
msgBox.Position = UDim2.fromScale(0,0.25)
msgBox.PlaceholderText = "Type private message..."
msgBox.Text = ""
msgBox.Font = Enum.Font.Gotham
msgBox.TextScaled = true
msgBox.BackgroundColor3 = Color3.fromRGB(20,20,20)
msgBox.TextColor3 = Color3.new(1,1,1)
Instance.new("UICorner", msgBox).CornerRadius = UDim.new(0,12)

local send = Instance.new("TextButton", chat)
send.Size = UDim2.fromScale(0.25,0.15)
send.Position = UDim2.fromScale(0.75,0.25)
send.Text = "Send"
send.Font = Enum.Font.GothamBold
send.TextScaled = true
send.BackgroundColor3 = Color3.fromRGB(40,40,40)
send.TextColor3 = Color3.new(1,1,1)
Instance.new("UICorner", send).CornerRadius = UDim.new(0,12)

-- ===== Player List (Optimized) =====
local currentTarget
local lastUpdate = 0

local function updatePlayers()
	if tick() - lastUpdate < 5 then return end -- optimization
	lastUpdate = tick()

	for _,p in ipairs(Players:GetPlayers()) do
		if p ~= player then
			currentTarget = p.Name
			playersBox.Text = p.Name
			break
		end
	end
end

playersBox.MouseButton1Click:Connect(updatePlayers)

send.MouseButton1Click:Connect(function()
	if currentTarget and msgBox.Text ~= "" then
		evt:FireServer("SendPrivate",{To=currentTarget,Msg=msgBox.Text})
		msgBox.Text = ""
	end
end)

evt.OnClientEvent:Connect(function(action,data)
	if action=="Receive" then
		msgBox.PlaceholderText = "From "..data.From..": "..data.Msg
	end
end)

-- ===== Donations Panel =====
local donate = Instance.new("Frame", main)
donate.Size = UDim2.fromScale(0.72,0.8)
donate.Position = UDim2.fromScale(0.25,0.1)
donate.Visible = false
donate.BackgroundTransparency = 1

local dBtn = Instance.new("TextButton", donate)
dBtn.Size = UDim2.fromScale(0.6,0.18)
dBtn.Position = UDim2.fromScale(0.2,0.3)
dBtn.Text = "Donate 10 🌺"
dBtn.Font = Enum.Font.GothamBold
dBtn.TextScaled = true
dBtn.BackgroundColor3 = Color3.fromRGB(40,40,40)
dBtn.TextColor3 = Color3.new(1,1,1)
Instance.new("UICorner", dBtn).CornerRadius = UDim.new(0,14)

dBtn.MouseButton1Click:Connect(function()
	MarketplaceService:PromptProductPurchase(player,123456789) -- ProductId
end)

-- ===== Switching =====
chatBtn.MouseButton1Click:Connect(function()
	chat.Visible=true
	donate.Visible=false
end)

donateBtn.MouseButton1Click:Connect(function()
	donate.Visible=true
	chat.Visible=false
end)
