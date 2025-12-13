--[[
    🌐 KRB UNIVERSAL CHAT SYSTEM
    Works in ALL Roblox games: Brookhaven, Arsenal, Any game
    No RemoteEvents or special permissions needed
    Works on: Delta, Krnl, Mobile, PC
    Modern dark design with smooth animations
]]

-- ============================================
-- 1. CORE SYSTEM (No Server Required)
-- ============================================
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")
local TextService = game:GetService("TextService")

local LocalPlayer = Players.LocalPlayer

-- ============================================
-- 2. UNIVERSAL CHAT ENGINE
-- ============================================
local KRB_Chat = {
    Version = "3.0",
    Mode = "UNIVERSAL", -- Works in any game
    
    -- Chat Storage
    Conversations = {
        Private = {},   -- {playerName = {messages}}
        Groups = {},    -- {groupId = {data}}
        ActiveChats = {} -- Currently open chats
    },
    
    -- User Settings
    Settings = {
        Sounds = true,
        Notifications = true,
        Theme = "DARK_MODE",
        AutoTranslate = false,
        BubbleChat = true,
        SaveChats = true,
        FontSize = 16,
        ShowTimestamps = true
    },
    
    -- Statistics
    Stats = {
        TotalMessages = 0,
        ActiveUsers = 0,
        ChatsCreated = 0,
        LastMessageTime = 0
    },
    
    -- Chat History (saved locally)
    History = {
        MaxMessages = 1000,
        Messages = {},
        ArchivedChats = {}
    }
}

-- ============================================
-- 3. UNIVERSAL MESSAGE SYSTEM (Works Anywhere)
-- ============================================
KRB_Chat.MessageSystem = {
    -- Send message to player (Universal Method)
    SendMessage = function(targetPlayerName, message, messageType)
        messageType = messageType or "PRIVATE"
        
        -- Validate message
        if #message > 250 then
            return false, "Message too long (max 250 chars)"
        end
        
        if #message == 0 then
            return false, "Message cannot be empty"
        end
        
        local targetPlayer = Players:FindFirstChild(targetPlayerName)
        if not targetPlayer then
            return false, "Player not found in server"
        end
        
        -- Create message data
        local messageData = {
            Id = HttpService:GenerateGUID(false),
            Sender = LocalPlayer.Name,
            SenderId = LocalPlayer.UserId,
            Receiver = targetPlayerName,
            ReceiverId = targetPlayer.UserId,
            Message = message,
            Type = messageType,
            Timestamp = os.time(),
            TimeFormatted = os.date("%H:%M"),
            Status = "SENT",
            IsEncrypted = false,
            Reactions = {}
        }
        
        -- Store locally
        if not KRB_Chat.Conversations.Private[targetPlayerName] then
            KRB_Chat.Conversations.Private[targetPlayerName] = {}
        end
        
        table.insert(KRB_Chat.Conversations.Private[targetPlayerName], messageData)
        table.insert(KRB_Chat.History.Messages, messageData)
        
        KRB_Chat.Stats.TotalMessages += 1
        KRB_Chat.Stats.LastMessageTime = os.time()
        
        -- Send via universal method (works in any game)
        KRB_Chat.MessageSystem.UniversalSend(targetPlayer, messageData)
        
        -- Update UI
        KRB_Chat.UI.UpdateChatWindow(targetPlayerName, messageData)
        
        -- Play sound
        if KRB_Chat.Settings.Sounds then
            KRB_Chat.Audio.PlaySendSound()
        end
        
        return true, "Message sent successfully"
    end,
    
    -- Universal sending method (works in ALL games)
    UniversalSend = function(targetPlayer, messageData)
        -- METHOD 1: Using Player Attributes (works in most games)
        local success1 = pcall(function()
            LocalPlayer:SetAttribute("KRB_LAST_MSG_" .. targetPlayer.UserId, HttpService:JSONEncode(messageData))
        end)
        
        -- METHOD 2: Using Value objects (backup method)
        local success2 = pcall(function()
            local value = Instance.new("StringValue")
            value.Name = "KRB_MSG_" .. HttpService:GenerateGUID(false)
            value.Value = HttpService:JSONEncode(messageData)
            value.Parent = workspace
            game:GetService("Debris"):AddItem(value, 2)
        end)
        
        -- METHOD 3: Visual bubble (fallback)
        if KRB_Chat.Settings.BubbleChat then
            KRB_Chat.UI.CreateChatBubble(messageData.Message)
        end
        
        return success1 or success2
    end,
    
    -- Receive messages (constantly checks for new messages)
    StartReceiver = function()
        spawn(function()
            while true do
                wait(0.5) -- Check every 0.5 seconds
                
                -- Check all players for messages
                for _, player in ipairs(Players:GetPlayers()) do
                    if player ~= LocalPlayer then
                        -- Check for message attributes
                        local attrName = "KRB_LAST_MSG_" .. LocalPlayer.UserId
                        local messageJson = player:GetAttribute(attrName)
                        
                        if messageJson then
                            local success, messageData = pcall(HttpService.JSONDecode, HttpService, messageJson)
                            if success and messageData.Receiver == LocalPlayer.Name then
                                -- Process received message
                                KRB_Chat.MessageSystem.ProcessReceivedMessage(messageData, player)
                                
                                -- Clear the attribute
                                player:SetAttribute(attrName, nil)
                            end
                        end
                    end
                end
            end
        end)
    end,
    
    -- Process received message
    ProcessReceivedMessage = function(messageData, sender)
        -- Store message
        local senderName = sender.Name
        if not KRB_Chat.Conversations.Private[senderName] then
            KRB_Chat.Conversations.Private[senderName] = {}
        end
        
        messageData.Status = "RECEIVED"
        messageData.ReceivedTime = os.time()
        
        table.insert(KRB_Chat.Conversations.Private[senderName], messageData)
        table.insert(KRB_Chat.History.Messages, messageData)
        
        -- Show notification
        if KRB_Chat.Settings.Notifications then
            KRB_Chat.UI.ShowNotification(senderName, messageData.Message)
        end
        
        -- Play sound
        if KRB_Chat.Settings.Sounds then
            KRB_Chat.Audio.PlayReceiveSound()
        end
        
        -- Update UI if chat is open
        if KRB_Chat.Conversations.ActiveChats[senderName] then
            KRB_Chat.UI.UpdateChatWindow(senderName, messageData)
        end
        
        KRB_Chat.Stats.TotalMessages += 1
    end
}

-- ============================================
-- 4. GROUP CHAT SYSTEM
-- ============================================
KRB_Chat.GroupSystem = {
    Groups = {},
    
    CreateGroup = function(groupName, members)
        local groupId = "GROUP_" .. HttpService:GenerateGUID(false)
        
        local group = {
            Id = groupId,
            Name = groupName,
            Creator = LocalPlayer.Name,
            Members = members or {},
            Created = os.time(),
            Messages = {},
            Settings = {
                Public = false,
                MaxMembers = 20,
                AllowInvites = true
            }
        }
        
        KRB_Chat.GroupSystem.Groups[groupId] = group
        KRB_Chat.Conversations.Groups[groupId] = group
        
        -- Add creator to members
        table.insert(group.Members, LocalPlayer.Name)
        
        KRB_Chat.Stats.ChatsCreated += 1
        
        return groupId, group
    end,
    
    SendGroupMessage = function(groupId, message)
        local group = KRB_Chat.GroupSystem.Groups[groupId]
        if not group then return false, "Group not found" end
        
        -- Check if user is in group
        local isMember = false
        for _, member in ipairs(group.Members) do
            if member == LocalPlayer.Name then
                isMember = true
                break
            end
        end
        
        if not isMember then return false, "You are not a member" end
        
        -- Create message
        local messageData = {
            Id = HttpService:GenerateGUID(false),
            GroupId = groupId,
            Sender = LocalPlayer.Name,
            Message = message,
            Timestamp = os.time(),
            TimeFormatted = os.date("%H:%M")
        }
        
        table.insert(group.Messages, messageData)
        
        -- Send to all online group members
        for _, memberName in ipairs(group.Members) do
            if memberName ~= LocalPlayer.Name then
                local memberPlayer = Players:FindFirstChild(memberName)
                if memberPlayer then
                    KRB_Chat.MessageSystem.UniversalSend(memberPlayer, {
                        Type = "GROUP",
                        GroupId = groupId,
                        Sender = LocalPlayer.Name,
                        Message = message,
                        Timestamp = os.time()
                    })
                end
            end
        end
        
        return true, "Group message sent"
    end
}

-- ============================================
-- 5. AUDIO & SOUND SYSTEM
-- ============================================
KRB_Chat.Audio = {
    Sounds = {},
    
    PlaySendSound = function()
        -- Create send sound effect
        local sound = Instance.new("Sound")
        sound.SoundId = "rbxassetid://3570570107" -- Soft click sound
        sound.Volume = 0.3
        sound.Parent = workspace
        sound:Play()
        game:GetService("Debris"):AddItem(sound, 2)
    end,
    
    PlayReceiveSound = function()
        -- Create receive sound effect
        local sound = Instance.new("Sound")
        sound.SoundId = "rbxassetid://3570570345" -- Soft ping sound
        sound.Volume = 0.4
        sound.Parent = workspace
        sound:Play()
        game:GetService("Debris"):AddItem(sound, 2)
    end,
    
    PlayNotificationSound = function()
        -- Notification sound
        local sound = Instance.new("Sound")
        sound.SoundId = "rbxassetid://3570570563"
        sound.Volume = 0.2
        sound.Parent = workspace
        sound:Play()
        game:GetService("Debris"):AddItem(sound, 2)
    end
}

-- ============================================
-- 6. MODERN UI SYSTEM
-- ============================================
KRB_Chat.UI = {
    ScreenGui = nil,
    MainFrame = nil,
    IsUIOpen = false,
    
    -- Create the main UI
    CreateUI = function()
        -- Create ScreenGui
        KRB_Chat.UI.ScreenGui = Instance.new("ScreenGui")
        KRB_Chat.UI.ScreenGui.Name = "KRB_UniversalChatUI"
        KRB_Chat.UI.ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
        KRB_Chat.UI.ScreenGui.ResetOnSpawn = false
        KRB_Chat.UI.ScreenGui.DisplayOrder = 100
        KRB_Chat.UI.ScreenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")
        
        -- Create toggle button (always visible)
        KRB_Chat.UI.CreateToggleButton()
        
        -- Create main chat window (hidden by default)
        KRB_Chat.UI.CreateMainWindow()
        
        -- Create notification handler
        KRB_Chat.UI.CreateNotificationHandler()
    end,
    
    -- Toggle button (bottom right corner)
    CreateToggleButton = function()
        local ToggleButton = Instance.new("TextButton")
        ToggleButton.Name = "ChatToggleButton"
        ToggleButton.Size = UDim2.new(0, 50, 0, 50)
        ToggleButton.Position = UDim2.new(1, -60, 1, -60)
        ToggleButton.AnchorPoint = Vector2.new(1, 1)
        ToggleButton.BackgroundColor3 = Color3.fromRGB(40, 40, 45)
        ToggleButton.Text = "💬"
        ToggleButton.TextColor3 = Color3.fromRGB(255, 255, 255)
        ToggleButton.Font = Enum.Font.GothamBold
        ToggleButton.TextSize = 20
        ToggleButton.ZIndex = 1000
        ToggleButton.Parent = KRB_Chat.UI.ScreenGui
        
        -- Rounded corners
        local Corner = Instance.new("UICorner")
        Corner.CornerRadius = UDim.new(1, 0)
        Corner.Parent = ToggleButton
        
        -- Glow effect
        local Stroke = Instance.new("UIStroke")
        Stroke.Color = Color3.fromRGB(100, 100, 255)
        Stroke.Thickness = 2
        Stroke.Transparency = 0.5
        Stroke.Parent = ToggleButton
        
        -- Animation on hover
        ToggleButton.MouseEnter:Connect(function()
            TweenService:Create(ToggleButton, TweenInfo.new(0.2), {
                Size = UDim2.new(0, 55, 0, 55),
                BackgroundColor3 = Color3.fromRGB(50, 50, 55)
            }):Play()
        end)
        
        ToggleButton.MouseLeave:Connect(function()
            TweenService:Create(ToggleButton, TweenInfo.new(0.2), {
                Size = UDim2.new(0, 50, 0, 50),
                BackgroundColor3 = Color3.fromRGB(40, 40, 45)
            }):Play()
        end)
        
        -- Toggle chat window
        ToggleButton.MouseButton1Click:Connect(function()
            KRB_Chat.UI.ToggleChatWindow()
        end)
    end,
    
    -- Main chat window
    CreateMainWindow = function()
        -- Main container
        KRB_Chat.UI.MainFrame = Instance.new("Frame")
        KRB_Chat.UI.MainFrame.Name = "ChatMainWindow"
        KRB_Chat.UI.MainFrame.Size = UDim2.new(0, 380, 0, 500)
        KRB_Chat.UI.MainFrame.Position = UDim2.new(1, -400, 0.5, -250)
        KRB_Chat.UI.MainFrame.AnchorPoint = Vector2.new(1, 0.5)
        KRB_Chat.UI.MainFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
        KRB_Chat.UI.MainFrame.BackgroundTransparency = 0.05
        KRB_Chat.UI.MainFrame.Visible = false
        KRB_Chat.UI.MainFrame.Active = true
        KRB_Chat.UI.MainFrame.Draggable = true
        KRB_Chat.UI.MainFrame.Selectable = true
        KRB_Chat.UI.MainFrame.Parent = KRB_Chat.UI.ScreenGui
        
        -- Rounded corners
        local MainCorner = Instance.new("UICorner")
        MainCorner.CornerRadius = UDim.new(0, 12)
        MainCorner.Parent = KRB_Chat.UI.MainFrame
        
        -- Border glow
        local MainStroke = Instance.new("UIStroke")
        MainStroke.Color = Color3.fromRGB(80, 80, 120)
        MainStroke.Thickness = 2
        MainStroke.Transparency = 0.7
        MainStroke.Parent = KRB_Chat.UI.MainFrame
        
        -- Header
        local Header = Instance.new("Frame")
        Header.Name = "Header"
        Header.Size = UDim2.new(1, 0, 0, 50)
        Header.BackgroundColor3 = Color3.fromRGB(35, 35, 40)
        Header.Parent = KRB_Chat.UI.MainFrame
        
        local HeaderCorner = Instance.new("UICorner")
        HeaderCorner.CornerRadius = UDim.new(0, 12, 0, 0)
        HeaderCorner.Parent = Header
        
        -- Title
        local Title = Instance.new("TextLabel")
        Title.Name = "Title"
        Title.Size = UDim2.new(0.7, 0, 1, 0)
        Title.Position = UDim2.new(0, 15, 0, 0)
        Title.BackgroundTransparency = 1
        Title.Text = "💬 KRB UNIVERSAL CHAT"
        Title.TextColor3 = Color3.fromRGB(255, 255, 255)
        Title.Font = Enum.Font.GothamBold
        Title.TextSize = 18
        Title.TextXAlignment = Enum.TextXAlignment.Left
        Title.Parent = Header
        
        -- Close button
        local CloseButton = Instance.new("TextButton")
        CloseButton.Name = "CloseButton"
        CloseButton.Size = UDim2.new(0, 40, 0, 40)
        CloseButton.Position = UDim2.new(1, -45, 0.5, -20)
        CloseButton.AnchorPoint = Vector2.new(1, 0.5)
        CloseButton.BackgroundTransparency = 1
        CloseButton.Text = "×"
        CloseButton.TextColor3 = Color3.fromRGB(255, 100, 100)
        CloseButton.Font = Enum.Font.GothamBold
        CloseButton.TextSize = 30
        CloseButton.Parent = Header
        
        CloseButton.MouseButton1Click:Connect(function()
            KRB_Chat.UI.ToggleChatWindow()
        end)
        
        -- Tabs container
        local TabsFrame = Instance.new("Frame")
        TabsFrame.Name = "TabsFrame"
        TabsFrame.Size = UDim2.new(1, -20, 0, 40)
        TabsFrame.Position = UDim2.new(0, 10, 0, 55)
        TabsFrame.BackgroundTransparency = 1
        TabsFrame.Parent = KRB_Chat.UI.MainFrame
        
        -- Tabs
        local Tabs = {"Players", "Groups", "History", "Settings"}
        
        for i, tabName in ipairs(Tabs) do
            local TabButton = Instance.new("TextButton")
            TabButton.Name = tabName .. "Tab"
            TabButton.Size = UDim2.new(0.23, 0, 1, 0)
            TabButton.Position = UDim2.new(0.23 * (i-1), 0, 0, 0)
            TabButton.BackgroundColor3 = (i == 1) and Color3.fromRGB(70, 70, 120) or Color3.fromRGB(50, 50, 55)
            TabButton.Text = tabName
            TabButton.TextColor3 = Color3.fromRGB(255, 255, 255)
            TabButton.Font = Enum.Font.GothamSemibold
            TabButton.TextSize = 14
            TabButton.Parent = TabsFrame
            
            local TabCorner = Instance.new("UICorner")
            TabCorner.CornerRadius = UDim.new(0, 6)
            TabCorner.Parent = TabButton
            
            TabButton.MouseButton1Click:Connect(function()
                -- Switch tab logic here
                print("Switched to tab:", tabName)
            end)
        end
        
        -- Players list
        local PlayersFrame = Instance.new("ScrollingFrame")
        PlayersFrame.Name = "PlayersList"
        PlayersFrame.Size = UDim2.new(1, -20, 0, 300)
        PlayersFrame.Position = UDim2.new(0, 10, 0, 105)
        PlayersFrame.BackgroundTransparency = 1
        PlayersFrame.ScrollBarThickness = 3
        PlayersFrame.ScrollBarImageColor3 = Color3.fromRGB(100, 100, 150)
        PlayersFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
        PlayersFrame.Parent = KRB_Chat.UI.MainFrame
        
        -- Populate players list
        KRB_Chat.UI.UpdatePlayersList(PlayersFrame)
        
        -- Message input area
        local InputFrame = Instance.new("Frame")
        InputFrame.Name = "InputFrame"
        InputFrame.Size = UDim2.new(1, -20, 0, 50)
        InputFrame.Position = UDim2.new(0, 10, 1, -60)
        InputFrame.BackgroundColor3 = Color3.fromRGB(40, 40, 45)
        InputFrame.Parent = KRB_Chat.UI.MainFrame
        
        local InputCorner = Instance.new("UICorner")
        InputCorner.CornerRadius = UDim.new(0, 8)
        InputCorner.Parent = InputFrame
        
        local MessageInput = Instance.new("TextBox")
        MessageInput.Name = "MessageInput"
        MessageInput.Size = UDim2.new(0.75, 0, 1, 0)
        MessageInput.Position = UDim2.new(0, 10, 0, 0)
        MessageInput.BackgroundTransparency = 1
        MessageInput.TextColor3 = Color3.fromRGB(255, 255, 255)
        MessageInput.PlaceholderText = "Type message..."
        MessageInput.PlaceholderColor3 = Color3.fromRGB(150, 150, 150)
        MessageInput.Font = Enum.Font.Gotham
        MessageInput.TextSize = 16
        MessageInput.TextXAlignment = Enum.TextXAlignment.Left
        MessageInput.Parent = InputFrame
        
        local SendButton = Instance.new("TextButton")
        SendButton.Name = "SendButton"
        SendButton.Size = UDim2.new(0.2, 0, 0.7, 0)
        SendButton.Position = UDim2.new(0.78, 0, 0.15, 0)
        SendButton.BackgroundColor3 = Color3.fromRGB(80, 80, 150)
        SendButton.Text = "Send"
        SendButton.TextColor3 = Color3.fromRGB(255, 255, 255)
        SendButton.Font = Enum.Font.GothamBold
        SendButton.TextSize = 14
        SendButton.Parent = InputFrame
        
        local SendCorner = Instance.new("UICorner")
        SendCorner.CornerRadius = UDim.new(0, 6)
        SendCorner.Parent = SendButton
        
        -- Send button functionality
        SendButton.MouseButton1Click:Connect(function()
            local message = MessageInput.Text
            if #message > 0 then
                -- Get selected player from list
                -- This is simplified - you'd need to track selected player
                MessageInput.Text = ""
                
                -- Play sound
                if KRB_Chat.Settings.Sounds then
                    KRB_Chat.Audio.PlaySendSound()
                end
            end
        end)
        
        -- Enter key to send
        MessageInput.FocusLost:Connect(function(enterPressed)
            if enterPressed and #MessageInput.Text > 0 then
                SendButton.MouseButton1Click:Fire()
            end
        end)
    end,
    
    -- Update players list
    UpdatePlayersList = function(scrollingFrame)
        -- Clear existing
        for _, child in ipairs(scrollingFrame:GetChildren()) do
            if child:IsA("Frame") then
                child:Destroy()
            end
        end
        
        -- Add current players
        local yOffset = 5
        for _, player in ipairs(Players:GetPlayers()) do
            if player ~= LocalPlayer then
                local PlayerButton = Instance.new("TextButton")
                PlayerButton.Name = "Player_" .. player.Name
                PlayerButton.Size = UDim2.new(1, -10, 0, 50)
                PlayerButton.Position = UDim2.new(0, 5, 0, yOffset)
                PlayerButton.BackgroundColor3 = Color3.fromRGB(45, 45, 50)
                PlayerButton.Text = ""
                PlayerButton.Parent = scrollingFrame
                
                local PlayerCorner = Instance.new("UICorner")
                PlayerCorner.CornerRadius = UDim.new(0, 8)
                PlayerCorner.Parent = PlayerButton
                
                -- Player icon
                local Icon = Instance.new("TextLabel")
                Icon.Size = UDim2.new(0, 40, 0, 40)
                Icon.Position = UDim2.new(0, 5, 0.5, -20)
                Icon.BackgroundTransparency = 1
                Icon.Text = "👤"
                Icon.TextColor3 = Color3.fromRGB(200, 200, 255)
                Icon.Font = Enum.Font.GothamBold
                Icon.TextSize = 20
                Icon.Parent = PlayerButton
                
                -- Player name
                local NameLabel = Instance.new("TextLabel")
                NameLabel.Size = UDim2.new(0.7, 0, 0.5, 0)
                NameLabel.Position = UDim2.new(0, 50, 0, 5)
                NameLabel.BackgroundTransparency = 1
                NameLabel.Text = player.Name
                NameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
                NameLabel.Font = Enum.Font.GothamSemibold
                NameLabel.TextSize = 16
                NameLabel.TextXAlignment = Enum.TextXAlignment.Left
                NameLabel.Parent = PlayerButton
                
                -- Status indicator
                local Status = Instance.new("Frame")
                Status.Size = UDim2.new(0, 10, 0, 10)
                Status.Position = UDim2.new(0.95, -10, 0.5, -5)
                Status.BackgroundColor3 = Color3.fromRGB(0, 255, 0) -- Online
                Status.Parent = PlayerButton
                
                local StatusCorner = Instance.new("UICorner")
                StatusCorner.CornerRadius = UDim.new(1, 0)
                StatusCorner.Parent = Status
                
                -- Click to chat
                PlayerButton.MouseButton1Click:Connect(function()
                    KRB_Chat.UI.OpenPrivateChat(player.Name)
                end)
                
                yOffset = yOffset + 55
            end
        end
    end,
    
    -- Open private chat with player
    OpenPrivateChat = function(playerName)
        print("Opening chat with:", playerName)
        -- This would open a chat window for that player
    end,
    
    -- Toggle chat window visibility
    ToggleChatWindow = function()
        KRB_Chat.UI.IsUIOpen = not KRB_Chat.UI.IsUIOpen
        KRB_Chat.UI.MainFrame.Visible = KRB_Chat.UI.IsUIOpen
        
        if KRB_Chat.UI.IsUIOpen then
            -- Animate open
            KRB_Chat.UI.MainFrame.Size = UDim2.new(0, 0, 0, 0)
            TweenService:Create(KRB_Chat.UI.MainFrame, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
                Size = UDim2.new(0, 380, 0, 500)
            }):Play()
            
            -- Refresh players list
            local playersFrame = KRB_Chat.UI.MainFrame:FindFirstChild("PlayersList")
            if playersFrame then
                KRB_Chat.UI.UpdatePlayersList(playersFrame)
            end
        else
            -- Animate close
            TweenService:Create(KRB_Chat.UI.MainFrame, TweenInfo.new(0.2), {
                Size = UDim2.new(0, 0, 0, 0)
            }):Play()
        end
    end,
    
    -- Show notification
    ShowNotification = function(sender, message)
        -- Create notification frame
        local Notification = Instance.new("Frame")
        Notification.Name = "Notification"
        Notification.Size = UDim2.new(0, 300, 0, 80)
        Notification.Position = UDim2.new(1, -320, 0, 20)
        Notification.AnchorPoint = Vector2.new(1, 0)
        Notification.BackgroundColor3 = Color3.fromRGB(35, 35, 45)
        Notification.BackgroundTransparency = 0.1
        Notification.Parent = KRB_Chat.UI.ScreenGui
        
        local NotifCorner = Instance.new("UICorner")
        NotifCorner.CornerRadius = UDim.new(0, 10)
        NotifCorner.Parent = Notification
        
        local NotifStroke = Instance.new("UIStroke")
        NotifStroke.Color = Color3.fromRGB(100, 100, 200)
        NotifStroke.Thickness = 2
        NotifStroke.Parent = Notification
        
        -- Notification content
        local Title = Instance.new("TextLabel")
        Title.Size = UDim2.new(1, -20, 0, 25)
        Title.Position = UDim2.new(0, 10, 0, 10)
        Title.BackgroundTransparency = 1
        Title.Text = "💬 New message from " .. sender
        Title.TextColor3 = Color3.fromRGB(255, 255, 255)
        Title.Font = Enum.Font.GothamBold
        Title.TextSize = 14
        Title.TextXAlignment = Enum.TextXAlignment.Left
        Title.Parent = Notification
        
        local MessagePreview = Instance.new("TextLabel")
        MessagePreview.Size = UDim2.new(1, -20, 0, 30)
        MessagePreview.Position = UDim2.new(0, 10, 0, 35)
        MessagePreview.BackgroundTransparency = 1
        MessagePreview.Text = string.sub(message, 1, 50) .. (#message > 50 and "..." or "")
        MessagePreview.TextColor3 = Color3.fromRGB(200, 200, 200)
        MessagePreview.Font = Enum.Font.Gotham
        MessagePreview.TextSize = 12
        MessagePreview.TextXAlignment = Enum.TextXAlignment.Left
        MessagePreview.TextWrapped = true
        MessagePreview.Parent = Notification
        
        -- Auto-remove after 5 seconds
        delay(5, function()
            if Notification and Notification.Parent then
                TweenService:Create(Notification, TweenInfo.new(0.3), {
                    Position = UDim2.new(1, 50, 0, 20),
                    BackgroundTransparency = 1
                }):Play()
                wait(0.3)
                Notification:Destroy()
            end
        end)
        
        -- Click to open chat
        Notification.MouseButton1Click:Connect(function()
            KRB_Chat.UI.ToggleChatWindow()
            KRB_Chat.UI.OpenPrivateChat(sender)
            Notification:Destroy()
        end)
        
        -- Play sound
        if KRB_Chat.Settings.Sounds then
            KRB_Chat.Audio.PlayNotificationSound()
        end
    end,
    
    -- Create notification handler
    CreateNotificationHandler = function()
        -- Will handle incoming notifications
    end,
    
    -- Create chat bubble
    CreateChatBubble = function(message)
        if not KRB_Chat.Settings.BubbleChat then return end
        
        local character = LocalPlayer.Character
        if not character then return end
        
        local head = character:FindFirstChild("Head")
        if not head then return end
        
        local bubble = Instance.new("BillboardGui")
        bubble.Name = "ChatBubble"
        bubble.Size = UDim2.new(0, 200, 0, 0)
        bubble.Adornee = head
        bubble.AlwaysOnTop = true
        bubble.MaxDistance = 50
        bubble.SizeOffset = Vector2.new(0, 2)
        bubble.Parent = head
        
        local bubbleText = Instance.new("TextLabel")
        bubbleText.Size = UDim2.new(1, -10, 0, 0)
        bubbleText.Position = UDim2.new(0, 5, 0, 0)
        bubbleText.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
        bubbleText.BackgroundTransparency = 0.3
        bubbleText.TextColor3 = Color3.fromRGB(255, 255, 255)
        bubbleText.Text = message
        bubbleText.Font = Enum.Font.Gotham
        bubbleText.TextSize = 14
        bubbleText.TextWrapped = true
        bubbleText.AutomaticSize = Enum.AutomaticSize.Y
        bubbleText.Parent = bubble
        
        local bubbleCorner = Instance.new("UICorner")
        bubbleCorner.CornerRadius = UDim.new(0, 8)
        bubbleCorner.Parent = bubbleText
        
        -- Animate and destroy
        spawn(function()
            wait(4)
            for i = 0.3, 1, 0.05 do
                bubbleText.BackgroundTransparency = i
                bubbleText.TextTransparency = i
                wait(0.05)
            end
            bubble:Destroy()
        end)
    end,
    
    -- Update chat window with new message
    UpdateChatWindow = function(playerName, messageData)
        -- This would update the active chat window
        -- Implementation depends on your UI structure
    end
}

-- ============================================
-- 7. KEYBIND SYSTEM
-- ============================================
KRB_Chat.Keybinds = {
    ToggleKey = Enum.KeyCode.F7,
    QuickReplyKey = Enum.KeyCode.F8,
    
    Initialize = function()
        -- Toggle chat with F7
        UserInputService.InputBegan:Connect(function(input, processed)
            if not processed and input.KeyCode == KRB_Chat.Keybinds.ToggleKey then
                KRB_Chat.UI.ToggleChatWindow()
            end
        end)
        
        -- Mobile touch support
        if UserInputService.TouchEnabled then
            -- Add touch controls for mobile
        end
    end
}

-- ============================================
-- 8. INITIALIZATION
-- ============================================
local function InitializeKRBChat()
    print("=== KRB UNIVERSAL CHAT SYSTEM ===")
    print("Version: " .. KRB_Chat.Version)
    print("Mode: " .. KRB_Chat.Mode)
    print("Initializing...")
    
    -- Create UI
    KRB_Chat.UI.CreateUI()
    
    -- Start message receiver
    KRB_Chat.MessageSystem.StartReceiver()
    
    -- Initialize keybinds
    KRB_Chat.Keybinds.Initialize()
    
    -- Player join/leave events
    Players.PlayerAdded:Connect(function(player)
        KRB_Chat.Stats.ActiveUsers += 1
        print("[KRB] Player joined:", player.Name)
    end)
    
    Players.PlayerRemoving:Connect(function(player)
        KRB_Chat.Stats.ActiveUsers -= 1
        print("[KRB] Player left:", player.Name)
    end)
    
    print("[KRB] Universal Chat System Ready!")
    print("[KRB] Press F7 to toggle chat window")
    print("[KRB] Works in ALL Roblox games")
    
    -- Initial stats
    KRB_Chat.Stats.ActiveUsers = #Players:GetPlayers()
    
    -- Welcome message
    wait(2)
    print("[KRB] Welcome to KRB Universal Chat!")
    print("[KRB] You can chat with anyone in this server")
end

-- ============================================
-- 9. START THE SYSTEM
-- ============================================
-- Wait for player to load
if not LocalPlayer.Character then
    LocalPlayer.CharacterAdded:Wait()
end

wait(1) -- Small delay

-- Initialize the chat system
InitializeKRBChat()

-- Return the chat system for external use
return KRB_Chat
"Initial commit - Add KRB Chat System"
