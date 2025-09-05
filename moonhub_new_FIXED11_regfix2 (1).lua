if _G.__MOONHUB_INIT then return end; _G.__MOONHUB_INIT = true
local Players = game:GetService("Players")
local DEBUG = false
local function DebugNotify(title, msg)
    if DEBUG and Notify then
        pcall(function() Notify(title, msg) end)
    end
end
local __SEEN_ERR = {}
local function ReportErrorOnce(title, msg)
    local k = tostring(title)..":"..tostring(msg)
    if __SEEN_ERR[k] then return end
    __SEEN_ERR[k] = true
    if Notify then pcall(function() Notify(title, msg) end) end
end
local StarterGui = game:GetService("StarterGui")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local UserService = game:GetService("UserService")
local Stats = game:GetService("Stats")
local TweenService = game:GetService("TweenService")
local TextChatService = game:GetService("TextChatService")
local TeleportService = game:GetService("TeleportService")
local VoiceChatService = game:GetService("VoiceChatService")
local workspace = game:GetService("Workspace")

local LocalPlayer = Players.LocalPlayer
local GROUP_ID = 497686443
local API_BASE = "https://backend-6eka.onrender.com"
local MIN_ADMIN_RANK = 200
local ZERO_VECTOR = Vector3.new(0, 0, 0)
local TELEPORT_OFFSET = Vector3.new(0, 2, 0)

local WindUI = loadstring(game:HttpGet("https://github.com/Footagesus/WindUI/releases/latest/download/main.lua"))()
local function isAdmin()
    local ok, rank = pcall(function()
        return LocalPlayer:GetRankInGroup(GROUP_ID)
    end)
    return ok and rank and rank >= MIN_ADMIN_RANK
end

local function hasValidCharacter(player)
    return player and player.Character and player.Character:FindFirstChild("Humanoid")
end

local TAB_CONFIGS = {
    {title = "Farm", icon = "package"},
    {title = "PvP", icon = "sword"},
    {title = "Teleport", icon = "map-pin"},
    {title = "Misc", icon = "box"},
    {title = "Target", icon = "circle-user-round"},
    {title = "Scripts", icon = "code"},
    {title = "Skins", icon = "shirt"},
    {title = "NPC", icon = "skull"},
    {title = "Premium", icon = "gem"},
    {title = "Admin", icon = "shield"},
    {title = "Settings", icon = "settings"}
}
local farmConfig = {
    states = {
        coinFarm = false,
        dummyFarm = false,
        dummyFarmConnection = nil
    },
    constants = {
        DUMMY_HEIGHT_OFFSET = 8,
        OCCUPIED_DISTANCE = 10,
        COIN_FARM_DELAY = 0.1,
        NPC_ATTACK_DELAY = 0.01,
        DUMMY_5K_DELAY = 1
    },
    remotes = {
        coinEvent = ReplicatedStorage:WaitForChild("Events"):WaitForChild("CoinEvent"),
        attackRemote = ReplicatedStorage:WaitForChild("jdskhfsIIIllliiIIIdchgdIiIIIlIlIli")
    }
}

local pvpConfig = {
    targetPriority = "Closest",
    detectionRadius = 70,
    fireballInterval = 0.5,
    selectedPlayer = "Ninguém"
}

local pvpStates = {
    autoEat = false,
    killAura = false,
    loopKillAll = false,
    autoKillLowLevels = false,
    fireballAura = false,
    espPlayers = false
}

local pvpConstants = {
    SCREEN_CENTER_X = 0.5,
    SCREEN_CENTER_Y = 0.5,
    KEY_SLOT = Enum.KeyCode.One,
    INPUT_DELAY = 0.1,
    AUTO_EAT_DELAY = 0.1,
    FIREBALL_INTERVAL = 0.5
}

local pvpServices = {
    VirtualInputManager = game:GetService("VirtualInputManager"),
    UserInputService = game:GetService("UserInputService"),
    Stats = game:GetService("Stats")
}

local pvpRemotes = {
    skillsRemote = ReplicatedStorage:WaitForChild("SkillsRemote", 10)
}

local teleportConfig = {
    locations = {
        {Name = "🏠 Safe Zone", Position = Vector3.new(-105.29137420654297, 642.4719848632812, 514.2374877929688)},
        {Name = "🏜️ Desert", Position = Vector3.new(-672.6334838867188, 642.568603515625, 1115.691162109375)},
        {Name = "🌋 Volcano", Position = Vector3.new(120.21180725097656, 685.631103515625, 1570.7666015625)},
        {Name = "🏖️ Beach", Position = Vector3.new(-29.751022338867188, 644.6039428710938, -70.5428695678711)},
        {Name = "☁️ Cloud Arena", Position = Vector3.new(-1173.7010498046875, 1268.14404296875, 766.4228515625)}
    },
    notificationDuration = 3,
    errorDuration = 3
}

local targetConfig = {
    selectedPlayer = nil,
    feedback = nil,
    info = nil,
    velocityAsset = nil
}

local targetStates = {
    viewingTarget = false,
    focusingTarget = false,
    benxingTarget = false,
    headsittingTarget = false,
    standingTarget = false,
    backpackingTarget = false,
    doggyingTarget = false,
    sugaringTarget = false,
    draggingTarget = false
}

local scriptsConfig = {
    scripts = {
        {
            title = "📄 Infinity Yield",
            desc = "Execute the Infinity Yield script",
            url = "https://raw.githubusercontent.com/EdgeIY/infiniteyield/master/source",
            successMessage = "The Infinity Yield script has been executed successfully!"
        },
        {
            title = "📄 Moon AntiAfk",
            desc = "Execute the Moon AntiAfk script",
            url = "https://raw.githubusercontent.com/rodri0022/afkmoon/refs/heads/main/README.md",
            successMessage = "The Moon AntiAfk script has been executed!"
        },
        {
            title = "📄 Moon AntiLag",
            desc = "Execute the Moon AntiLag script",
            url = "https://raw.githubusercontent.com/nick0022/antilag/refs/heads/main/README.md",
            successMessage = "The Moon AntiLag script has been executed!"
        },
        {
            title = "📄 FE R15 Emotes and Animation",
            desc = "Execute the FE R15 Emotes and Animation script",
            url = "https://raw.githubusercontent.com/BeemTZy/Motiona/refs/heads/main/source.lua",
            successMessage = "The FE R15 Emotes and Animation script has been executed!"
        },
        {
            title = "📄 Moon FE Emotes",
            desc = "Execute the Moon Emotes script",
            url = "https://raw.githubusercontent.com/rodri0022/freeanimmoon/refs/heads/main/README.md",
            successMessage = "The Moon Emotes script has been executed!"
        },
        {
            title = "📄 Moon Troll",
            desc = "Execute the Moon Troll script",
            url = "https://raw.githubusercontent.com/nick0022/trollscript/refs/heads/main/README.md",
            successMessage = "The Moon Troll script has been executed!"
        },
        {
            title = "📄 Sirius",
            desc = "Execute the Sirius script",
            url = "https://sirius.menu/sirius",
            successMessage = "The Sirius script has been executed!"
        },
        {
            title = "📄 Keyboard",
            desc = "Execute the Keyboard script",
            url = "https://raw.githubusercontent.com/GGH52lan/GGH52lan/main/keyboard.txt",
            successMessage = "The Keyboard script has been executed!"
        },
        {
            title = "📄 Shader",
            desc = "Script to make your game beautiful.",
            url = "https://raw.githubusercontent.com/randomstring0/pshade-ultimate/refs/heads/main/src/cd.lua",
            successMessage = "The shader script has been executed!"
        }
    }
}

local skinsConfig = {
    skinSets = {
        {
            title = "🎅🏻 Christmas Skins",
            desc = "Unlock all Christmas skins",
            skins = {"XM24Fr", "XM24Fr", "XM24Bear", "XM24Eag", "XM24Br", "XM24Cr", "XM24Sq"},
            successMessage = "All Christmas skins have been successfully unlocked!"
        },
        {
            title = "🐷 Pig Skins",
            desc = "Unlock all Pig skins",
            skins = {"PIG1", "PIG2", "PIG3", "PIG4", "PIG5", "PIG6", "PIG7", "PIG8"},
            successMessage = "All Pig skins have been successfully unlocked!"
        }
    },
    secretWeapons = {
        {
            title = "⚔️ Secret Weapon",
            desc = "Unlock a secret sword skin",
            weaponId = "SSSSSSS2",
            successMessage = "Secret sword skin has been successfully unlocked!"
        },
        {
            title = "⚔️ Secret Weapon2",
            desc = "Unlock a secret sword skin",
            weaponId = "SSSSSSS4",
            successMessage = "Secret sword skin has been successfully unlocked!"
        },
        {
            title = "⚔️ Secret Weapon3",
            desc = "Unlock a secret sword skin",
            weaponId = "SSSS2",
            successMessage = "Secret sword skin has been successfully unlocked!"
        },
        {
            title = "⚔️ Secret Weapon4",
            desc = "Unlock a secret sword skin",
            weaponId = "SSSS1",
            successMessage = "Secret sword skin has been successfully unlocked!"
        }
    },
    easterEvent = {
        title = "🥚 Easter Event Skins",
        desc = "Unlock all the skins for the 2025 Easter event",
        locations = {
            A = Vector3.new(-127.946053, 642.647949, 429.429596),
            B = Vector3.new(-137.940262, 642.648254, 434.050598)
        },
        puzzleCount = 25,
        successMessage = "All Easter event skins have been unlocked!"
    }
}

local miscConfig = {
    animation = {
        enabled = false,
        nameParts = {"M", "Mo", "Moo", "Moon", "Moon ", "Moon H", "Moon Hu", "Moon Hub"},
        delay = 0.2,
        pauseDelay = 0.5
    },
    admin = {
        groupId = GROUP_ID,
        adminRank = MIN_ADMIN_RANK,
        moderatorRank = MIN_ADMIN_RANK,
        alertsEnabled = true
    },
    spectate = {
        selectedPlayer = "Ninguém",
        isSpectating = false,
        camera = workspace.CurrentCamera
    },
    voiceChat = {
        service = VoiceChatService
    },
    fling = {
        scriptUrl = "https://raw.githubusercontent.com/nick0022/walkflinng/refs/heads/main/README.md"
    },
    void = {
        voidOffset = Vector3.new(0, -500, 0),
        returnDelay = 3
    }
}

local Window = WindUI:CreateWindow({
    Title = "MoonHub Premium",
    Icon = "moon",
    Author = "d1_ofc and onlydecisions",
    Folder = "MoonHub"
})

local Tabs = {}
for _, config in ipairs(TAB_CONFIGS) do
    Tabs[config.title] = Window:Tab({Title = config.title, Icon = config.icon})
end

-- ========================================
-- FARM TAB CONTENT
-- ========================================

local Tag_RankInfo = {
    [2] = {label = "PREMIUM", color = Color3.fromRGB(0, 170, 255)},
    [1] = {label = "FREE USER", color = Color3.fromRGB(150, 150, 150)}
}
local Tag_OwnerInfo = {label = "OWNER", color = Color3.fromRGB(255, 255, 0)}
local Tag_DevInfo = {label = "DEVELOPER", color = Color3.fromRGB(255, 0, 0)}

local Tag_guiByPlayer = {}
local Tag_renderConnByPlayer = {}
local Tag_charAddedConn = {}
local Tag_charRemovingConn = {}
local Tag_infoByPlayer = {}
local Tag_lastRankByPlayer = {}

local function Tag_destroyFor(player)
    if Tag_renderConnByPlayer[player] then
        Tag_renderConnByPlayer[player]:Disconnect()
        Tag_renderConnByPlayer[player] = nil
    end
    local gui = Tag_guiByPlayer[player]
    if gui and gui.Parent then gui:Destroy() end
    Tag_guiByPlayer[player] = nil
    Tag_infoByPlayer[player] = nil
    Tag_lastRankByPlayer[player] = nil
end

local function Tag_getInfo(player)
    local ok, rank = pcall(function()
        return player:GetRankInGroup(GROUP_ID)
    end)
    if not ok then return nil, nil end
    if rank and rank >= 255 then
        return Tag_OwnerInfo, rank
    elseif rank and rank >= 254 then
        return Tag_DevInfo, rank
    end
    return Tag_RankInfo[rank], rank
end

local function Tag_attach(player, char, info)
    if not info then return end
    local head = char:WaitForChild("Head", 10)
    if not head then return end

    Tag_destroyFor(player)

    local b = Instance.new("BillboardGui")
    b.Name = "RoleTag"
    b.AlwaysOnTop = true
    b.Size = UDim2.new(2.8, 0, 0.5, 0)
    b.StudsOffset = Vector3.new(0, 4.0, 0)
    b.Adornee = head
    b.Parent = head
    Tag_guiByPlayer[player] = b
    Tag_infoByPlayer[player] = info

    local f = Instance.new("Frame")
    f.AnchorPoint = Vector2.new(0.5, 0.5)
    f.Position = UDim2.new(0.5, 0, 0.5, 0)
    f.Size = UDim2.new(1, 0, 1, 0)
    f.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
    f.BackgroundTransparency = 0.05
    f.Parent = b

    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, 25)
    c.Parent = f

    local s = Instance.new("UIStroke")
    s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    s.Thickness = 3
    s.Color = info.color
    s.Transparency = 0.1
    s.Parent = f

    local innerGlow = Instance.new("UIStroke")
    innerGlow.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    innerGlow.Thickness = 1
    innerGlow.Color = info.color
    innerGlow.Transparency = 0.4
    innerGlow.Parent = f

    local iconContainer = Instance.new("Frame")
    iconContainer.Size = UDim2.new(0.12, 0, 0.8, 0)
    iconContainer.Position = UDim2.new(0.20, 0, 0.5, 0)
    iconContainer.AnchorPoint = Vector2.new(0.5, 0.5)
    iconContainer.BackgroundTransparency = 1
    iconContainer.Parent = f

    local starIcon = Instance.new("TextLabel")
    starIcon.Size = UDim2.new(1.0, 0, 1.0, 0)
    starIcon.Position = UDim2.new(0.5, 0, 0.5, 0)
    starIcon.AnchorPoint = Vector2.new(0.5, 0.5)
    starIcon.BackgroundTransparency = 1
    starIcon.Font = Enum.Font.GothamBold
    starIcon.Text = "★"
    starIcon.TextScaled = true
    starIcon.TextColor3 = Color3.fromRGB(236, 72, 153)
    starIcon.TextStrokeTransparency = 0.3
    starIcon.TextStrokeColor3 = Color3.fromRGB(255, 255, 255)
    starIcon.ZIndex = 10
    starIcon.Parent = iconContainer

    for i = 1, 4 do
        local sparkle = Instance.new("TextLabel")
        sparkle.Size = UDim2.new(0.12, 0, 0.12, 0)
        sparkle.Position = UDim2.new(0.2 + (i * 0.15), 0, 0.2 + (i * 0.15), 0)
        sparkle.AnchorPoint = Vector2.new(0.5, 0.5)
        sparkle.BackgroundTransparency = 1
        sparkle.Font = Enum.Font.Gotham
        sparkle.Text = "•"
        sparkle.TextScaled = true
        sparkle.TextColor3 = Color3.fromRGB(255, 255, 255)
        sparkle.TextTransparency = 0.2
        sparkle.Parent = iconContainer
    end

    local textContainer = Instance.new("Frame")
    textContainer.Size = UDim2.new(0.35, 0, 0.8, 0)
    textContainer.Position = UDim2.new(0.60, 0, 0.5, 0)
    textContainer.AnchorPoint = Vector2.new(0.5, 0.5)
    textContainer.BackgroundTransparency = 1
    textContainer.Parent = f

    local t = Instance.new("TextLabel")
    t.Size = UDim2.new(1, 0, 0.6, 0)
    t.Position = UDim2.new(0.5, 0, 0.3, 0)
    t.AnchorPoint = Vector2.new(0.5, 0.5)
    t.BackgroundTransparency = 1
    t.Font = Enum.Font.GothamBold
    t.Text = info.label
    t.TextScaled = true
    t.TextColor3 = info.color
    t.TextStrokeTransparency = 0.2
    t.TextStrokeColor3 = Color3.new(0, 0, 0)
    t.Parent = textContainer

    local playerName = Instance.new("TextLabel")
    playerName.Size = UDim2.new(1, 0, 0.4, 0)
    playerName.Position = UDim2.new(0.5, 0, 0.8, 0)
    playerName.AnchorPoint = Vector2.new(0.5, 0.5)
    playerName.BackgroundTransparency = 1
    playerName.Font = Enum.Font.GothamBold
    playerName.Text = "@" .. player.Name
    playerName.TextScaled = true
    playerName.TextColor3 = Color3.fromRGB(147, 51, 234)
    playerName.TextTransparency = 0.4
    playerName.TextStrokeTransparency = 0.5
    playerName.TextStrokeColor3 = Color3.new(0, 0, 0)
    playerName.Parent = textContainer

    TweenService:Create(b, TweenInfo.new(2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {StudsOffset = Vector3.new(0, 4.2, 0)}):Play()

    local currentTween
    Tag_renderConnByPlayer[player] = RunService.RenderStepped:Connect(function()
        if not head.Parent or not b.Parent then Tag_destroyFor(player) return end
        local cam = workspace.CurrentCamera
        if not cam then return end
        local dist = (cam.CFrame.Position - head.Position).Magnitude
        local tr = dist < 25 and 0 or dist < 45 and (dist - 25) / 20 or 1
        local bg = 0.1 + tr
        
        if math.abs(f.BackgroundTransparency - bg) > 0.05 then
            if currentTween then currentTween:Cancel() end
            currentTween = TweenService:Create(f, TweenInfo.new(0.3), {BackgroundTransparency = bg})
            currentTween:Play()
            TweenService:Create(t, TweenInfo.new(0.3), {TextTransparency = tr}):Play()
            TweenService:Create(playerName, TweenInfo.new(0.3), {TextTransparency = 0.6 + tr * 0.4}):Play()
            TweenService:Create(s, TweenInfo.new(0.3), {Transparency = 0.2 + tr * 0.8}):Play()
            TweenService:Create(innerGlow, TweenInfo.new(0.3), {Transparency = 0.4 + tr * 0.6}):Play()
        end
    end)
end

local Tag_scanEnabled = true
local Tag_scanThread = nil

local function Tag_clearAllNow()
    for player, _ in pairs(Tag_guiByPlayer) do
        Tag_destroyFor(player)
    end
end

local function Tag_scanOnce()
    for _, p in ipairs(Players:GetPlayers()) do
        local info, rank = Tag_getInfo(p)
        if info and p.Character and p.Character:FindFirstChild("Head") then
            local existing = Tag_guiByPlayer[p]
            local cached = Tag_infoByPlayer[p]
            local lastRank = Tag_lastRankByPlayer and Tag_lastRankByPlayer[p]
            if (not existing) or (not cached) or cached.label ~= info.label or cached.color ~= info.color or lastRank ~= rank then
                Tag_attach(p, p.Character, info)
                if Tag_lastRankByPlayer then Tag_lastRankByPlayer[p] = rank end
            end
        else
            if Tag_guiByPlayer[p] then
                Tag_destroyFor(p)
            end
        end
    end

    for tracked, _ in pairs(Tag_guiByPlayer) do
        if tracked.Parent ~= Players then
            Tag_destroyFor(tracked)
        end
    end
end

local function Tag_startScanner()
    if Tag_scanThread then return end
    Tag_scanEnabled = true
    Tag_scanThread = task.spawn(function()
        task.wait(1)
        while Tag_scanEnabled do
            Tag_scanOnce()
            task.wait(2)
        end
        Tag_scanThread = nil
    end)
end

local function Tag_stopScanner()
    Tag_scanEnabled = false
end

Tag_startScanner()

local function http_json(method, endpoint, data)
    local ok, resOrErr = pcall(function()
        local url = API_BASE .. endpoint
        local options = {
            Url = url,
            Method = method,
            Headers = {
                ["Content-Type"] = "application/json",
                ["Accept"] = "application/json",
            },
        }
        if data ~= nil then
            options.Body = HttpService:JSONEncode(data)
        end

        local send = (syn and syn.request) or http_request or request or (fluxus and fluxus.request)
        if send then
            return send(options)
        else
            return game:GetService("HttpService"):RequestAsync(options)
        end
    end)

    if not ok then
        warn("HTTP failed: " .. tostring(resOrErr))
        return nil
    end

    local res = resOrErr
    local body = res and (res.Body or res.body) or nil
    local status = res and (res.StatusCode or res.Status or res.status_code) or 0
    if type(status) == "number" and status >= 200 and status < 300 and type(body) == "string" and #body > 0 then
        local suc, decoded = pcall(HttpService.JSONDecode, HttpService, body)
        return suc and decoded or nil
    end
    -- non-2xx or empty body
    return nil
end
        

local function sendAdminPresence()
    if not isAdmin() then return end
    
    local success, result = pcall(function()
        local data = {
            uid = tostring(LocalPlayer.UserId),
            gameId = tostring(game.PlaceId),
            serverId = tostring(game.JobId)
        }
        return http_json("POST", "/admin/presence", data)
    end)
    
    if not success then
        warn("Admin presence failed: " .. tostring(result))
    end
end

local function startMessagePoller()
    if not isAdmin() then return end
    
    task.spawn(function()
        while true do
            local success, messages = pcall(function()
                return http_json("GET", "/admin/messages", nil)
            end)
            
            if success and messages and messages.ok then
                for _, msg in ipairs(messages.messages or {}) do
                    local command = msg.command
                    local data = msg.data or {}
                    
                    if command == "announce" then
                        WindUI:Notify({
                            Title = "📢 Admin Announcement",
                            Content = data.message or "No message",
                            Duration = 5
                        })
                    elseif command == "notify" then
                        WindUI:Notify({
                            Title = "🔔 Admin Notification",
                            Content = data.message or "No message",
                            Duration = 3
                        })
                    elseif command == "disconnect" then
                        LocalPlayer:Kick("Disconnected by admin")
                    elseif command == "ban" then
                        LocalPlayer:Kick("You have been banned by admin")
                    elseif command == "unban" then
                        WindUI:Notify({
                            Title = "✅ Unbanned",
                            Content = "You have been unbanned by admin",
                            Duration = 3
                        })
                    elseif command == "bring" then
                        local targetUid = data.uid
                        if targetUid then
                            WindUI:Notify({
                                Title = "🚀 Bring Command",
                                Content = "Admin is bringing you to them",
                                Duration = 2
                            })
                        end
                    elseif command == "kill" then
                        local character = LocalPlayer.Character
                        if character and character:FindFirstChild("Humanoid") then
                            character.Humanoid.Health = 0
                        end
                    elseif command == "freeze" then
                        local character = LocalPlayer.Character
                        if character and character:FindFirstChild("HumanoidRootPart") then
                            character.HumanoidRootPart.Anchored = true
                        end
                    elseif command == "unfreeze" then
                        local character = LocalPlayer.Character
                        if character and character:FindFirstChild("HumanoidRootPart") then
                            character.HumanoidRootPart.Anchored = false
                        end
                    elseif command == "say" then
                        local message = data.message
                        if message then
                            TextChatService.TextChannels.RBXGeneral:SendAsync(message)
                        end
                    elseif command == "getgamedetails" then
                        local gameDetails = {
                            placeId = tostring(game.PlaceId),
                            jobId = tostring(game.JobId),
                            playerCount = #Players:GetPlayers(),
                            serverTime = os.time()
                        }
                        http_json("POST", "/admin/gamedetails", gameDetails)
                    elseif command == "joingame" then
                        local targetUid = data.uid
                        if targetUid then
                            WindUI:Notify({
                                Title = "🎮 Join Game",
                                Content = "Admin is joining your game",
                                Duration = 3
                            })
                        end
                    end
                end
            end
            
            task.wait(2)
        end
    end)
end

local function checkUserBan()
    local success, result = pcall(function()
        local uid = tostring(LocalPlayer.UserId)
        return http_json("GET", "/checkban?uid=" .. uid, nil)
    end)
    
    if success and result and result.banned then
        LocalPlayer:Kick("You are banned from using this script")
        return false
    end
    return true
end

local function copyGroupURL()
    local success = pcall(function()
        setclipboard("https://www.roblox.com/groups/497686443/MoonHub")
    end)
    
    if success then
        WindUI:Notify({
            Title = "📋 Group URL Copied",
            Content = "MoonHub group URL copied to clipboard",
            Duration = 2
        })
    end
end

if checkUserBan() then
    sendAdminPresence()
    startMessagePoller()
end

local function _isPremium()
    local ok, rank = pcall(function()
        return LocalPlayer:GetRankInGroup(497686443)
    end)
    return ok and rank and rank >= 2
end

local function generateDailyKey()
    local daily = ""
    pcall(function()
        local uid = tostring(LocalPlayer.UserId)
        local response = (syn and syn.request) or http_request or request
        if response then
            local r = response({
                Url = string.format("%s/get?uid=%s", API_BASE, uid),
                Method = "GET"
            })
            if r and r.StatusCode == 200 then
                local j = HttpService:JSONDecode(r.Body)
                daily = tostring(j.key or "")
            end
        end
    end)
    return daily
end

local _premium = _isPremium()
local dailyKey = generateDailyKey()

loadstring(game:HttpGet("https://raw.githubusercontent.com/deathier545/antitesting/refs/heads/main/unlockanimals"))()

local animalMap = {
    Axolotl = {id = "axolotl", anim = "axolotl_Anim"},
    BTrex = {id = "babydino", anim = "btrexAnim"},
    BabyCat = {id = "babycats", anim = "babycatAnim"},
    BabyElephant = {
        id = "baby_elephant", anim = "babyelephantAnim", gamepassPassId = 89053083,
        skinIdOverrides = {
            elephant1 = "elephant1", elephant2 = "elephant2", elephant3 = "elephant3",
            elephant4 = "elephant4", elephant5 = "elephant5", elephant6 = "elephant6",
            elephant7 = "elephant7", elephant8 = "elephant8", elephant9 = "elephant9",
            elephant10 = "elephant10", elephant11 = "elephant11", elephant12 = "elephant12",
            elephant13 = "elephant13", elephant14 = "elephant14", elephant15 = "elephant15",
            elephant16 = "elephant16", elephant17 = "elephant17", elephant18 = "elephant18",
            elephant19 = "elephant19", elephant20 = "elephant20", elephant21 = "elephant21",
            elephant22 = "elephant22", elephant23 = "elephant23", elephant24 = "gamepass24",
            elephant27 = "gamepass27", elephant28 = "gamepass28", elephant29 = "gamepass29",
            elephant30 = "gamepass30", elephant31 = "gamepass31"
        },
        animOverrides = {
            elephant24 = "babytankelephantAnim", elephant27 = "babytankelephantAnim",
            elephant28 = "babytankelephantAnim", elephant29 = "babytankelephantAnim",
            elephant30 = "babytankelephantAnim", elephant31 = "babytankelephantAnim"
        }
    },
    BabyKangaroo = {id = "baby_kangaroos", anim = "baby_kangarooAnim"},
    BabyLionRework = {
        id = "babylion_rework", anim = "babylionR_Anim", gamepassPassId = 121800750,
        skinIdOverrides = {
            lion1 = "babylion1", lion2 = "babylion2", lion3 = "babylion3", lion4 = "babylion4",
            lion5 = "babylion5", lion6 = "babylion6", lion7 = "babylion7", lion8 = "babylion8",
            lion9 = "babylion9", lion10 = "babylion10", lion11 = "babylion11", lion12 = "babylion12",
            lion13 = "babylion13", lion14 = "babylion14", lion15 = "babylion15", lion16 = "babylion16"
        },
        animOverrides = {
            gamepass17 = "babylionRWing_Anim", gamepass18 = "babylionRWing_Anim",
            gamepass21 = "babygriffin_Anim", gamepass22 = "babygriffin_Anim",
            gamepass23 = "babygriffin_Anim", gamepass24 = "babygriffin_Anim",
            gamepass25 = "babygriffin_Anim", gamepass26 = "babygriffin_Anim"
        }
    },
    BabyPenguin = {id = "baby_penguin", anim = "babypenguinAnim"},
    BabyWolf = {
        id = "baby_wolf", anim = "babywolf1Anim", gamepassPassId = 38950138,
        skinIdOverrides = {
            babywolf1 = "baby_wolf1", babywolf2 = "baby_wolf2", babywolf3 = "baby_wolf3",
            babywolf4 = "baby_wolf4", babywolf5 = "baby_wolf5", babywolf6 = "baby_wolf6",
            babywolf7 = "baby_wolf7", babywolf8 = "baby_wolf8", babywolf9 = "baby_wolf9",
            babywolf10 = "baby_wolf10", babywolf11 = "baby_wolf11", babywolf12 = "baby_wolf12",
            babywolf13 = "baby_wolf13", babywolf14 = "baby_wolf14", babywolf15 = "baby_wolf15",
            babywolf16 = "baby_wolf16", babywolf17 = "baby_wolf17", babywolf18 = "gamepass18",
            babywolf19 = "gamepass19", babywolf20 = "gamepass20", babywolf21 = "gamepass21",
            babywolf22 = "gamepass22", babywolf23 = "gamepass23", babywolf24 = "gamepass24"
        },
        animOverrides = {
            babywolf1 = "babywolf1Anim", babywolf2 = "babywolf1Anim", babywolf3 = "babywolf1Anim",
            babywolf4 = "babywolf1Anim", babywolf5 = "babywolf1Anim", babywolf6 = "babywolf1Anim",
            babywolf7 = "babywolf1Anim", babywolf8 = "babywolf1Anim", babywolf9 = "babywolf1Anim",
            babywolf10 = "babywolf1Anim", babywolf11 = "babywolf1Anim", babywolf12 = "babywolf1Anim",
            babywolf13 = "babywolf1Anim", babywolf14 = "babywolf1Anim", babywolf15 = "babywolf2Anim",
            babywolf16 = "babywolf2Anim", babywolf17 = "babywolf2Anim", babywolf18 = "babywolf3Anim",
            babywolf19 = "babywolf3Anim", babywolf20 = "babywolf3Anim", babywolf21 = "babywolf3Anim",
            babywolf22 = "babywolf3Anim", babywolf23 = "babywolf3Anim", babywolf24 = "babywolf3Anim"
        }
    },
    Bear = {id = "bears", anim = "bearAnim"},
    Capybara = {id = "capybara", anim = "capybaraAnim"},
    Cat = {id = "cats", anim = "catAnim"},
    Centaur = {id = "centaur", anim = "centaurAnim"},
    Chicken = {id = "chicken", anim = "chickenAnim"},
    Christmas2023 = {
        id = "christmas2023", anim = "newhorseAnim", gamepassPassId = 670590394,
        skinIdOverrides = {
            capybara = "capybara1", snake = "snake1", crocodile = "crocodile1", horse = "horse1",
            giraffe = "giraffe1", gamepass_horse = "gamepass_horse", gamepass_giraffe1 = "gamepass_giraffe1",
            gamepass_giraffe2 = "gamepass_giraffe2", gamepass_babywolf = "gamepass_babywolf",
            gamepass_wolf = "gamepass_wolf"
        },
        animOverrides = {
            capybara = "capybaraAnim", snake = "snakeAnim", crocodile = "crocodileAnim",
            horse = "newhorseAnim", giraffe = "giraffeAnim", gamepass_horse = "newhorseAnim",
            gamepass_giraffe1 = "christmasgiraffeAnim", gamepass_giraffe2 = "christmasgiraffeAnim",
            gamepass_babywolf = "babywolf1Anim", gamepass_wolf = "wolf1Anim"
        },
        tokenOverrides = {
            capybara = "XM23CP", snake = "XM23SN", crocodile = "XM23CR", horse = "XM23HR", giraffe = "XM23GR"
        }
    },
    Christmas2024 = {id = "christmas2024", anim = "newbear2Anim"},
    Cow = {id = "cows", anim = "cowAnim"},
    Crab = {id = "crab", anim = "crabAnim"},
    Crocodile = {id = "crocodile", anim = "crocodileAnim"},
    Dragon = {id = "dragons", anim = "dragonAnim"},
    Eagle = {id = "eagle", anim = "eagleAnim"},
    Elephant = {id = "elephant", anim = "elephantAnim"},
    Fox = {id = "fox", anim = "foxAnim"},
    Frog = {id = "frog", anim = "frogAnim"},
    Giraffe = {id = "giraffe", anim = "giraffeAnim"},
    Gorilla = {id = "gorilla", anim = "gorillaAnim"},
    Halloween2023 = {
        id = "halloween2023", anim = "newhorseAnim", gamepassPassId = 270811024,
        animOverrides = {
            horse = "newhorseAnim", capybara = "capybaraAnim", crocodile = "crocodileAnim",
            monkey = "halloweenmonkeyAnim", dragon = "dragonAnim", snake = "snakeAnim",
            gamepass_lion = "reworklion_Anim", gamepass_lioness = "reworklion_Anim",
            gamepass_babylion = "babylionR_Anim", gamepass_dragon = "dragonAnim",
            gamepass_monkey = "halloweenmonkeyAnim", gamepass_horse = "newhorseAnim"
        },
        tokenOverrides = {
            horse = "H23HR", capybara = "H23CP", crocodile = "H23CR", monkey = "H23MK",
            dragon = "H23DR", snake = "H23SN", gamepass_lion = "H23LI", gamepass_lioness = "H23LS",
            gamepass_babylion = "H23BL", gamepass_dragon = "H23GD", gamepass_monkey = "H23GM", gamepass_horse = "H23GH"
        }
    },
    Horse = {id = "horse", anim = "horseAnim"},
    Kangaroo = {id = "kangaroo", anim = "kangarooAnim"},
    Lion = {id = "lion", anim = "lionAnim"},
    Lioness = {id = "lioness", anim = "lionessAnim"},
    Monkey = {id = "monkey", anim = "monkeyAnim"},
    Ostrich = {id = "ostrich", anim = "ostrichAnim"},
    Owl = {id = "owl", anim = "owlAnim"},
    Panda = {id = "panda", anim = "pandaAnim"},
    Parrot = {id = "parrot", anim = "parrotAnim"},
    Penguin = {id = "penguin", anim = "penguinAnim"},
    Pig = {id = "pig", anim = "pigAnim"},
    Rabbit = {id = "rabbit", anim = "rabbitAnim"},
    Rhino = {id = "rhino", anim = "rhinoAnim"},
    Sheep = {id = "sheep", anim = "sheepAnim"},
    Snake = {id = "snake", anim = "snakeAnim"},
    Tiger = {id = "tiger", anim = "tigerAnim"},
    Turtle = {id = "turtle", anim = "turtleAnim"},
    Wolf = {id = "wolf", anim = "wolfAnim"},
    Zebra = {id = "zebra", anim = "zebraAnim"}
}

local function teleportToEasterLocation(position)
    local character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
    local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
    if not humanoidRootPart then return end
    
    task.wait(2)
    humanoidRootPart.CFrame = CFrame.new(position)
    task.wait(0.1)
end

local function fireEasterEvent(puzzleNumber)
    local easterEventFolder = ReplicatedStorage:WaitForChild("Easter2025", 9e9)
    if not easterEventFolder then
        warn("Pasta 'Easter2025' não encontrada em ReplicatedStorage.")
        return
    end
    
    local remoteEvent = easterEventFolder:WaitForChild("RemoteEvent", 9e9)
    if not remoteEvent then
        warn("RemoteEvent 'RemoteEvent' não encontrado dentro de 'Easter2025'.")
        return
    end

    local args = {
        [1] = {
            ["action"] = "pick_up",
            ["puzzle_name"] = "PUZ" .. tostring(puzzleNumber)
        }
    }

    remoteEvent:FireServer(table.unpack(args))
    task.wait(0.1)
end

local easterLocationA = Vector3.new(-127.946053, 642.647949, 429.429596)
local easterLocationB = Vector3.new(-137.940262, 642.648254, 434.050598)

local function unlockSecretWeapon(weaponId, weaponName)
    local args = {[1] = weaponId}
    
    local success = pcall(function()
        ReplicatedStorage:WaitForChild("Events", 9e9):WaitForChild("WeaponEvent", 9e9):FireServer(table.unpack(args))
    end)
    
    if success then
        WindUI:Notify({
            Title = "⚔️ " .. weaponName .. " Unlocked",
            Content = "Secret weapon has been successfully unlocked!",
            Duration = 3
        })
    else
        WindUI:Notify({
            Title = "❌ Error",
            Content = "Failed to unlock " .. weaponName,
            Duration = 3
        })
    end
end

local function PlayAnim(id, time, speed)
    pcall(function()
        if not LocalPlayer.Character or not LocalPlayer.Character:FindFirstChild("Humanoid") then
            return
        end
        
        LocalPlayer.Character.Animate.Disabled = false
        local hum = LocalPlayer.Character.Humanoid
        local animtrack = hum:GetPlayingAnimationTracks()
        for i, track in pairs(animtrack) do
            track:Stop()
        end
        LocalPlayer.Character.Animate.Disabled = true
        
        local Anim = Instance.new("Animation")
        Anim.AnimationId = "rbxassetid://"..id
        local loadanim = hum:LoadAnimation(Anim)
        loadanim:Play()
        if time then 
            loadanim.TimePosition = time
        end
        if speed then
            loadanim:AdjustSpeed(speed)
        end
        
        loadanim.Stopped:Connect(function()
            LocalPlayer.Character.Animate.Disabled = false
            for i, track in pairs(animtrack) do
                track:Stop()
            end
        end)
        
        _G.CurrentAnimation = loadanim
    end)
end

local function StopAnim()
    pcall(function()
        if hasValidCharacter(LocalPlayer) then
            LocalPlayer.Character.Animate.Disabled = false
            local animtrack = LocalPlayer.Character.Humanoid:GetPlayingAnimationTracks()
            for i, track in pairs(animtrack) do
                track:Stop()
            end
        end
        
        _G.CurrentAnimation = nil
    end)
end

local function GetPing()
    local ping = 0
    pcall(function()
        ping = Stats.Network.ServerStatsItem["Data Ping"]:GetValue() / 1000
    end)
    return ping or 0.2
end

local function GetPush()
    for _, tool in ipairs(LocalPlayer.Backpack:GetChildren()) do
        if tool.Name == "Push" or tool.Name == "ModdedPush" then
            return tool
        end
    end
    for _, tool in ipairs(LocalPlayer.Character:GetChildren()) do
        if tool.Name == "Push" or tool.Name == "ModdedPush" then
            return tool
        end
    end
    return nil
end

local function GetPlayer(UserDisplay)
    if UserDisplay and UserDisplay ~= "" then
        for i,v in pairs(Players:GetPlayers()) do
            if v.Name:lower():match(UserDisplay:lower()) or v.DisplayName:lower():match(UserDisplay:lower()) then
                return v
            end
        end
    end
    return nil
end

local function GetCharacter(Player)
    return Player and Player.Character or nil
end

local function GetRoot(Player)
    local char = GetCharacter(Player)
    if char and char:FindFirstChild("HumanoidRootPart") then
        return char.HumanoidRootPart
    end
    return nil
end

local function TeleportTO(posX,posY,posZ,targetPlayer,method)
    pcall(function()
        local localRoot = GetRoot(LocalPlayer)
        if not localRoot then return end

        if method == "safe" then
            task.spawn(function()
                for i = 1,30 do
                    task.wait()
                    if localRoot then
                        localRoot.Velocity = ZERO_VECTOR
                        if targetPlayer == "pos" then
                            localRoot.CFrame = CFrame.new(posX,posY,posZ)
                        else
                            local targetRoot = GetRoot(targetPlayer)
                            if targetRoot then
                                localRoot.CFrame = targetRoot.CFrame
                            end
                        end
                    end
                end
            end)
        else
            if targetPlayer == "pos" then
                localRoot.CFrame = CFrame.new(posX,posY,posZ)
            else
                local targetRoot = GetRoot(targetPlayer)
                if targetRoot then
                    localRoot.CFrame = targetRoot.CFrame
                end
            end
        end
    end)
end

local _NameCache = {}
local function _fetchUserLabel(uid)
    uid = tostring(uid)
    local c = _NameCache[uid]
    if c then return c end
    
    local okUS, infos = pcall(function()
        return UserService:GetUserInfosByUserIdsAsync({tonumber(uid)})
    end)
    
    if okUS and infos and infos[1] then
        local info = infos[1]
        local lbl = _labelFromJSON(uid, {displayName = info.DisplayName, name = info.Username})
        _NameCache[uid] = lbl
        return lbl
    end
    
    local req = (syn and syn.request) or http_request or request or (fluxus and fluxus.request)
    if req then
        local r = req({
            Url = "https://users.roblox.com/v1/users/"..uid,
            Method = "GET",
            Headers = {["Accept"]="application/json"}
        })
        if r and r.Body then
            local okJ, j = pcall(function()
                return HttpService:JSONDecode(tostring(r.Body))
            end)
            if okJ and j then
                local lbl = _labelFromJSON(uid, j)
                _NameCache[uid] = lbl
                return lbl
            end
        end
    end
    
    _NameCache[uid] = uid
    return uid
end

local function _labelFromJSON(uid, j)
    local dn = tostring((j and j.displayName) or (j and j.DisplayName) or "")
    local un = tostring((j and j.name) or (j and j.Username) or "")
    if dn ~= "" and un ~= "" then return dn.." (@"..un..")" end
    if dn ~= "" then return dn end
    if un ~= "" then return "@"..un end
    return tostring(uid)
end

local function _copyToClipboard(text)
    local success = pcall(function()
        setclipboard(text)
    end)
    return success
end

local function suppressGenericWarnings()
    local originalWarn = warn
    warn = function(...)
        local args = {...}
        local message = tostring(args[1] or "")
        
        if message:find("unused variable") or 
           message:find("undefined variable") or
           message:find("global variable") then
            return
        end
        
        originalWarn(...)
    end
end

if not table.find then
    table.find = function(t, value)
        for i, v in ipairs(t) do
            if v == value then
                return i
            end
        end
        return nil
    end
end

suppressGenericWarnings()

local npcFlingActive = false
local npcFlingThread = nil

local function WalkFling(targetPlayer, targetNPC)
    local character = LocalPlayer.Character
    if not character then return false end
    
    local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
    if not humanoidRootPart then return false end
    
    local npc = workspace.NPC:FindFirstChild(targetNPC)
    if not npc then return false end
    
    local npcRoot = npc:FindFirstChild("HumanoidRootPart")
    if not npcRoot then return false end
    
    local bodyVelocity = Instance.new("BodyVelocity")
    bodyVelocity.MaxForce = Vector3.new(4000, 4000, 4000)
    bodyVelocity.Velocity = Vector3.new(0, 0, 0)
    bodyVelocity.Parent = humanoidRootPart
    
    humanoidRootPart.CFrame = npcRoot.CFrame + Vector3.new(0, 5, 0)
    
    local direction = (npcRoot.Position - humanoidRootPart.Position).Unit
    bodyVelocity.Velocity = direction * 100
    
    task.wait(1)
    
    bodyVelocity:Destroy()
    
    return true
end

local bossFarmingEnabled = false
local bossFarmingThread = nil
local bossHealthThreads = {}

local function farmBosses()
    local character = LocalPlayer.Character
    if not character then return end
    
    local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
    if not humanoidRootPart then return end
    
    while bossFarmingEnabled do
        for _, boss in ipairs(workspace.NPC:GetChildren()) do
            if boss:FindFirstChild("Humanoid") and boss:FindFirstChild("HumanoidRootPart") then
                local bossRoot = boss.HumanoidRootPart
                local distance = (humanoidRootPart.Position - bossRoot.Position).Magnitude
                
                if distance <= 50 then
                    humanoidRootPart.CFrame = bossRoot.CFrame + Vector3.new(0, 5, 0)
                    
                    if not bossHealthThreads[boss] then
                        local hum = boss:FindFirstChild("Humanoid")
                        local lastHealth = hum.Health
                        bossHealthThreads[boss] = hum:GetPropertyChangedSignal("Health"):Connect(function()
                            if hum.Health < lastHealth then
                                task.wait(0.05)
                                hum.Health = 0
                                if boss:FindFirstChild("HumanoidRootPart") then
                                    boss.HumanoidRootPart:BreakJoints()
                                end
                            end
                            lastHealth = hum.Health
                        end)
                    end
                end
            end
        end
        
        task.wait(0.5)
    end
end

local function disarmAllBosses()
    for boss, conn in pairs(bossHealthThreads) do
        if conn then conn:Disconnect() end
    end
    bossHealthThreads = {}
end

local targetPriority = "Closest"
local detectionRadius = 70

local function getValidTargetsSorted(priority)
    local char = LocalPlayer.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if not root then return {} end

    local myPos = root.Position
    local targets = {}
    local maxDist = tonumber(detectionRadius) or 70
    
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer and p.Character then
            local hum = p.Character:FindFirstChildOfClass("Humanoid")
            local rootPart = p.Character:FindFirstChild("HumanoidRootPart")
            local shield = p.Character:FindFirstChild("SafeZoneShield")
            if hum and rootPart and hum.Health > 0 and not shield then
                local dist = (myPos - rootPart.Position).Magnitude
                if dist <= maxDist then
                    table.insert(targets, {
                        player = p,
                        character = p.Character,
                        humanoid = hum,
                        distance = dist,
                        health = hum.Health,
                    })
                end
            end
        end
    end

    local method = string.lower(tostring(priority or targetPriority or "Closest"))
    if method == "lowest health" or method == "low health" or method == "lowest" or method == "health" then
        table.sort(targets, function(a,b) return a.health < b.health end)
    else
        table.sort(targets, function(a,b) return a.distance < b.distance end)
    end
    return targets
end

local ForceWhitelist = {}
local ScriptWhitelist = {}

local function isWhitelisted(player)
    local userId = tostring(player.UserId)
    return ForceWhitelist[userId] or ScriptWhitelist[userId] or false
end

local currentKeybind = Enum.KeyCode.RightControl

local function setupKeybindListener()
    local UserInputService = game:GetService("UserInputService")
    
    UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if gameProcessed then return end
        
        if input.KeyCode == currentKeybind then
            if Window and Window.Toggle then
                Window:Toggle()
            end
        end
    end)
end

local function updateSpamDropdown()
end

local function manualUpdateAllDropdowns()
    WindUI:Notify({
        Title = "🔄 Updates",
        Content = "All dropdowns updated manually",
        Duration = 2
    })
end

local settings = {
    autoKillNPCs = false,
    bossFarming = false,
    npcFlinging = false,
    targetPriority = "Closest",
    detectionRadius = 70,
    keybind = Enum.KeyCode.RightControl
}

setupKeybindListener()

local function sendNotification(title, content, duration, icon)
    if WindUI and WindUI.Notify then
        WindUI:Notify({
            Title = title or "MoonHub",
            Content = content or "No message",
            Duration = duration or 3,
            Icon = icon or "info"
        })
    else
        StarterGui:SetCore("SendNotification", {
            Title = title or "MoonHub",
            Text = content or "No message",
            Duration = duration or 3,
            Icon = icon or "rbxasset://textures/ui/GuiImagePlaceholder.png"
        })
    end
end

local function createSmoothTween(object, properties, duration, easingStyle, easingDirection)
    local tweenInfo = TweenInfo.new(
        duration or 0.5,
        easingStyle or Enum.EasingStyle.Quad,
        easingDirection or Enum.EasingDirection.Out
    )
    
    local tween = TweenService:Create(object, tweenInfo, properties)
    tween:Play()
    return tween
end

local function updateDistanceTransparency(object, camera, maxDistance)
    local distance = (object.Position - camera.CFrame.Position).Magnitude
    local transparency = math.min(distance / (maxDistance or 100), 1)
    
    if object:IsA("GuiObject") then
        object.BackgroundTransparency = transparency
    elseif object:IsA("BasePart") then
        object.Transparency = transparency
    end
end

local function getRankColor(rank)
    if rank >= 10 then
        return Color3.fromRGB(255, 0, 0)
    elseif rank >= 5 then
        return Color3.fromRGB(255, 165, 0)
    elseif rank >= 2 then
        return Color3.fromRGB(0, 255, 0)
    else
        return Color3.fromRGB(150, 150, 150)
    end
end


local function getPlayerRoot()
    return LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
end

local function attackNPC(humanoid, damage)
    farmConfig.remotes.attackRemote:FireServer(humanoid, damage)
end

local function teleportToTarget(targetRoot, heightOffset)
    local playerRoot = getPlayerRoot()
    if playerRoot and targetRoot then
        playerRoot.CFrame = targetRoot.CFrame * CFrame.new(0, heightOffset, 0)
    end
end

local function coinFarmLoop()
    while farmConfig.states.coinFarm and task.wait(farmConfig.constants.COIN_FARM_DELAY) do
        pcall(function()
            farmConfig.remotes.coinEvent:FireServer()
        end)
    end
end

local function attackAllNPCsLoop()
    while _G.attackAllNPCToggle and task.wait(farmConfig.constants.NPC_ATTACK_DELAY) do
        pcall(function()
            local npcsWithHealth = {}
            
            for _, npc in ipairs(workspace.NPC:GetDescendants()) do
                if npc:IsA("Humanoid") and npc.Health > 0 then
                    table.insert(npcsWithHealth, {
                        humanoid = npc,
                        health = npc.Health
                    })
                end
            end
            
            table.sort(npcsWithHealth, function(a, b)
                return a.health < b.health
            end)
            
            for _, npcData in ipairs(npcsWithHealth) do
                if _G.attackAllNPCToggle then
                    attackNPC(npcData.humanoid, 1)
                end
            end
        end)
    end
end

local function dummyFarmFunction()
    if farmConfig.states.dummyFarmConnection then
        farmConfig.states.dummyFarmConnection:Disconnect()
        farmConfig.states.dummyFarmConnection = nil
    end
    
    if farmConfig.states.dummyFarm then
        farmConfig.states.dummyFarmConnection = RunService.Heartbeat:Connect(function()
            pcall(function()
                local targetDummy = workspace.MAP.dummies:GetChildren()[1]
                if targetDummy and LocalPlayer.Character then
                    local humanoid = targetDummy:FindFirstChild("Humanoid")
                    local rootPart = targetDummy:FindFirstChild("HumanoidRootPart")
                    
                    if humanoid and rootPart then
                        teleportToTarget(rootPart, farmConfig.constants.DUMMY_HEIGHT_OFFSET)
                        attackNPC(humanoid, 1)
                    end
                end
            end)
        end)
    end
end

local function dummy5kFarmLoop()
    while _G.dummyFarm5kEnabled and task.wait(farmConfig.constants.DUMMY_5K_DELAY) do
        pcall(function()
            local dummies = workspace.MAP["5k_dummies"]:GetChildren()
            local targetDummy = nil
            local shortestDistance = math.huge
            
            for _, dummy in pairs(dummies) do
                if dummy.Name == "Dummy2" then
                    if dummy:FindFirstChild("Humanoid") and dummy:FindFirstChild("HumanoidRootPart") then
                        local isOccupied = false
                        local dummyRoot = dummy.HumanoidRootPart
                        
                        for _, player in pairs(Players:GetPlayers()) do
                            if player.Character and player ~= LocalPlayer then
                                local playerRoot = player.Character:FindFirstChild("HumanoidRootPart")
                                if playerRoot and (playerRoot.Position - dummyRoot.Position).Magnitude < farmConfig.constants.OCCUPIED_DISTANCE then
                                    isOccupied = true
                                    break
                                end
                            end
                        end
                        
                        if not isOccupied then
                            local playerRoot = getPlayerRoot()
                            if playerRoot then
                                local distance = (playerRoot.Position - dummyRoot.Position).Magnitude
                                if distance < shortestDistance then
                                    shortestDistance = distance
                                    targetDummy = dummy
                                end
                            end
                        end
                    end
                end
            end
            
            if targetDummy and LocalPlayer.Character then
                local humanoid = targetDummy:FindFirstChild("Humanoid")
                local rootPart = targetDummy:FindFirstChild("HumanoidRootPart")
                
                if humanoid and rootPart then
                    teleportToTarget(rootPart, farmConfig.constants.DUMMY_HEIGHT_OFFSET)
                    attackNPC(humanoid, 1)
                end
            end
        end)
    end
end

local function sendFarmNotification(title, state, action)
    local status = state and "Activated" or "Deactivated"
    sendNotification(title .. " " .. status, action .. " has been " .. string.lower(status) .. "!", 1)
end

local function togglePlayerGuiElement(elementPath, state, text)
    local gui = LocalPlayer:FindFirstChild("PlayerGui")
    if gui then
        local element = gui
        for _, part in ipairs(elementPath) do
            element = element:FindFirstChild(part)
            if not element then return end
        end
        element.Visible = state
        if text and state then
            element.Text = text
        end
    end
end

-- FARM TAB UI CREATION
Tabs.Farm:Toggle({
    Title = "💰 Coin Farm",
    Desc = "Automatically farms coins",
    Value = false,
    Callback = function(state)
        farmConfig.states.coinFarm = state
        
        if state then
            task.spawn(coinFarmLoop)
        end
        
        sendFarmNotification("💰 Coin Farm", state, "Coin Farm")
    end
})

Tabs.Farm:Toggle({
    Title = "👹 Attack All Bosses",
    Desc = "Automatically attacks all bosses",
    Value = false,
    Callback = function(state)
        _G.attackAllNPCToggle = state
        
        if state then
            task.spawn(attackAllNPCsLoop)
        end
        
        sendFarmNotification("👹 Attack All Bosses", state, "Auto attack on all bosses")
    end
})

Tabs.Farm:Toggle({
    Title = "🧍🏻 Dummy Farm",
    Desc = "Automatically farms dummies",
    Value = false,
    Callback = function(state)
        farmConfig.states.dummyFarm = state
        dummyFarmFunction()
        
        sendFarmNotification("🧍🏻 Dummy Farm", state, "Dummy Farm")
    end
})

Tabs.Farm:Toggle({
    Title = "🧍🏻 Dummy 5k Farm",
    Desc = "Automatically farms 5k dummies",
    Value = false,
    Callback = function(state)
        _G.dummyFarm5kEnabled = state
        
        if state then
            task.spawn(dummy5kFarmLoop)
        end
        
        sendFarmNotification("🧍🏻 Dummy 5k Farm", state, "Dummy 5k Farm")
    end
})

Tabs.Farm:Toggle({
    Title = "📻 Free Radio", 
    Desc = nil,
    Value = false,
    Callback = function(state)
        togglePlayerGuiElement({"DRadio_Gui"}, state)
        sendFarmNotification("📻 Free Radio", state, "Free Radio")
    end
})

Tabs.Farm:Toggle({
    Title = "🔍 Visual 13x Exp", 
    Desc = nil,
    Value = false,
    Callback = function(state)
        togglePlayerGuiElement({"LevelBar", "gamepassText"}, state, "13x exp")
        sendFarmNotification("🔍 Visual 13x Exp", state, "13x Exp")
    end
})

local pvpStates = {
    autoEat = false,
    killAura = false,
    huntPlayers = false,
    farmLowLevels = false
}

local pvpConstants = {
    KILL_AURA_DELAY = 0.01,
    AUTO_EAT_DELAY = 1,
    HUNT_DELAY = 1,
    LOW_LEVEL_DELAY = 1,
    FIREBALL_INTERVAL = 0.5,
    TELEPORT_DISTANCE = 10,
    HUNT_TIMEOUT = 8,
    KILL_AURA_DAMAGE = 5,
    HUNT_DAMAGE = 24,
    LOW_LEVEL_DAMAGE = 24,
    DETECTION_RADIUS = 70,
    SCREEN_CENTER_X = 0.5,
    SCREEN_CENTER_Y = 0.7,
    KEY_SLOT = "One",
    INPUT_DELAY = 0.1,
    MOUSE_DELAY = 0.05
}

local pvpRemotes = {
    attackRemote = ReplicatedStorage.jdskhfsIIIllliiIIIdchgdIiIIIlIlIli,
    carryEvent = ReplicatedStorage.Events.CarryEvent,
    skillsRemote = ReplicatedStorage.SkillsInRS.RemoteEvent
}

local pvpServices = {
    VirtualInputManager = game:GetService("VirtualInputManager"),
    UserInputService = game:GetService("UserInputService"),
    Stats = game:GetService("Stats")
}

local pvpConfig = {
    targetPriority = "Closest",
    detectionRadius = 70,
    fireballInterval = 0.5,
    selectedPlayer = "Ninguém"
}

local function isPlayerValidTarget(player)
    return player ~= LocalPlayer and 
           player.Character and 
           player.Character:FindFirstChild("Humanoid") and 
           player.Character.Humanoid.Health > 0 and 
           not player.Character:FindFirstChild("SafeZoneShield")
end

local function getScreenCenter()
    local camera = workspace.CurrentCamera
    return camera.ViewportSize.X * pvpConstants.SCREEN_CENTER_X, 
           camera.ViewportSize.Y * pvpConstants.SCREEN_CENTER_Y
end

local function sendPvPNotification(title, state, action)
    local status = state and "Activated" or "Deactivated"
    sendNotification(title .. " " .. status, action .. " has been " .. string.lower(status) .. "!", 1)
end

local function autoEatLoop()
    local isMobile = pvpServices.UserInputService.TouchEnabled and not pvpServices.UserInputService.MouseEnabled
    local isPC = pvpServices.UserInputService.MouseEnabled and not pvpServices.UserInputService.TouchEnabled
    
    while pvpStates.autoEat and task.wait(pvpConstants.AUTO_EAT_DELAY) do
        pcall(function()
            local screenX, screenY = getScreenCenter()
            
            if isPC then
                pvpServices.VirtualInputManager:SendKeyEvent(true, pvpConstants.KEY_SLOT, false, game)
                task.wait(pvpConstants.INPUT_DELAY)
                pvpServices.VirtualInputManager:SendKeyEvent(false, pvpConstants.KEY_SLOT, false, game)
                task.wait(pvpConstants.INPUT_DELAY)
                
                pvpServices.VirtualInputManager:SendMouseButtonEvent(screenX, screenY, 0, true, game, 0)
                task.wait(pvpConstants.MOUSE_DELAY)
                pvpServices.VirtualInputManager:SendMouseButtonEvent(screenX, screenY, 0, false, game, 0)
            elseif isMobile then
                pvpServices.VirtualInputManager:SendTouchEvent(0, Vector2.new(screenX, screenY), Vector2.new(screenX, screenY), true, game, 0)
                task.wait(pvpConstants.INPUT_DELAY)
                pvpServices.VirtualInputManager:SendTouchEvent(0, Vector2.new(screenX, screenY), Vector2.new(screenX, screenY), false, game, 0)
                task.wait(pvpConstants.INPUT_DELAY)
                
                pvpServices.VirtualInputManager:SendTouchEvent(0, Vector2.new(screenX, screenY), Vector2.new(screenX, screenY), true, game, 0)
                task.wait(pvpConstants.MOUSE_DELAY)
                pvpServices.VirtualInputManager:SendTouchEvent(0, Vector2.new(screenX, screenY), Vector2.new(screenX, screenY), false, game, 0)
            end
        end)
    end
end

local function killAuraLoop()
    while _G.killAura and task.wait(pvpConstants.KILL_AURA_DELAY) do
        pcall(function()
            for _, player in ipairs(Players:GetPlayers()) do
                if isPlayerValidTarget(player) then
                    attackNPC(player.Character:FindFirstChildOfClass("Humanoid"), pvpConstants.KILL_AURA_DAMAGE)
                end
            end
        end)
    end
end

local function loopKillAllPlayers()
    while _G.huntPlayers and task.wait(pvpConstants.HUNT_DELAY) do
        pcall(function()
            for _, target in ipairs(Players:GetPlayers()) do
                if isPlayerValidTarget(target) then
                    local targetRoot = target.Character:FindFirstChild("HumanoidRootPart")
                    local localRoot = getPlayerRoot()
                    
                    if targetRoot and localRoot then
                        if (localRoot.Position - targetRoot.Position).Magnitude > pvpConstants.TELEPORT_DISTANCE then
                            localRoot.CFrame = targetRoot.CFrame
                        end
                        
                        local startTime = tick()
                        while target.Character and target.Character:FindFirstChild("Humanoid") and 
                              target.Character.Humanoid.Health > 1 and _G.huntPlayers do
                            
                            if tick() - startTime > pvpConstants.HUNT_TIMEOUT then
                                break
                            end
                            
                            pvpRemotes.carryEvent:FireServer(target, "request_accepted")
                            attackNPC(target.Character.Humanoid, pvpConstants.HUNT_DAMAGE)
                            task.wait()
                        end
                    end
                end
            end
        end)
    end
end

local function autoKillLowLevels()
    while _G.farmLowLevels and task.wait(pvpConstants.LOW_LEVEL_DELAY) do
        pcall(function()
            local best = nil
            for _, p in ipairs(Players:GetPlayers()) do
                if p ~= LocalPlayer and p.Character and p:FindFirstChild("leaderstats") and 
                   p.leaderstats.Level.Value < LocalPlayer.leaderstats.Level.Value and 
                   p.Character:FindFirstChild("HumanoidRootPart") and 
                   p.Character:FindFirstChild("Humanoid") and 
                   p.Character.Humanoid.Health > 1 and 
                   not p.Character:FindFirstChild("SafeZoneShield") and 
                   (not best or p.leaderstats.Level.Value < best.leaderstats.Level.Value) then 
                    best = p 
                end
            end
            
            if best and LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
                local lr, tr = LocalPlayer.Character.HumanoidRootPart, best.Character.HumanoidRootPart
                if (lr.Position - tr.Position).Magnitude > pvpConstants.TELEPORT_DISTANCE then 
                    lr.CFrame = tr.CFrame 
                end
                
                pvpRemotes.carryEvent:FireServer(best, "request_accepted")
                attackNPC(best.Character.Humanoid, pvpConstants.LOW_LEVEL_DAMAGE)
            end
        end)
    end
end

local function getValidTargetsSorted(priority)
    local root = getPlayerRoot()
    if not root then return {} end

    local myPos = root.Position
    local targets = {}
    local maxDist = tonumber(pvpConfig.detectionRadius) or pvpConstants.DETECTION_RADIUS
    
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer and p.Character then
            local hum = p.Character:FindFirstChildOfClass("Humanoid")
            local rootPart = p.Character:FindFirstChild("HumanoidRootPart")
            local shield = p.Character:FindFirstChild("SafeZoneShield")
            if hum and rootPart and hum.Health > 0 and not shield then
                local dist = (myPos - rootPart.Position).Magnitude
                if dist <= maxDist then
                    table.insert(targets, {
                        player = p,
                        character = p.Character,
                        humanoid = hum,
                        distance = dist,
                        health = hum.Health,
                    })
                end
            end
        end
    end

    local method = string.lower(tostring(priority or pvpConfig.targetPriority or "Closest"))
    if method == "lowest health" or method == "low health" or method == "lowest" or method == "health" then
        table.sort(targets, function(a,b) return a.health < b.health end)
    else
        table.sort(targets, function(a,b) return a.distance < b.distance end)
    end
    return targets
end

local function findClosestTarget()
    local targets = getValidTargetsSorted(pvpConfig.targetPriority)
    if #targets > 0 then
        return targets[1].player, targets[1].distance
    end
    return nil, nil
end

local function getPing()
    local ping = 0
    pcall(function()
        ping = pvpServices.Stats.Network.ServerStatsItem["Data Ping"]:GetValue() / 1000
    end)
    return ping or 0.2
end

local function predictPosition(target, distance)
    if not target or not target.Character or not target.Character:FindFirstChild("HumanoidRootPart") then 
        return nil 
    end
    
    local targetRoot = target.Character.HumanoidRootPart
    local velocity = targetRoot.Velocity
    local ping = getPing()
    
    local totalTimeToPredict = ping * 2
    local futurePosition = targetRoot.Position + (velocity * totalTimeToPredict)
    
    return futurePosition
end

local FireballAura = {
    isActive = false,
    lastFireTime = 0,
    fireInterval = pvpConstants.FIREBALL_INTERVAL,
    connection = nil
}

function FireballAura.start()
    if FireballAura.isActive then return end
    
    FireballAura.isActive = true
    if FireballAura.connection then
        FireballAura.connection:Disconnect()
        FireballAura.connection = nil
    end
    
    FireballAura.connection = RunService.RenderStepped:Connect(function()
        if not FireballAura.isActive or (tick() - FireballAura.lastFireTime < FireballAura.fireInterval) then return end

        local target, distance = findClosestTarget()
        if target and distance then
            local predictedPosition = predictPosition(target, distance)
            
            local args = {
                [1] = predictedPosition,
                [2] = "NewFireball",
            }

            pvpRemotes.skillsRemote:FireServer(table.unpack(args))
            FireballAura.lastFireTime = tick()
        end
    end)
    
    sendNotification("Fireball Aura", "Fireball Aura activated!", 2)
end

function FireballAura.stop()
    if not FireballAura.isActive then return end
    
    FireballAura.isActive = false
    if FireballAura.connection then
        FireballAura.connection:Disconnect()
        FireballAura.connection = nil
    end
    
    sendNotification("Fireball Aura", "Fireball Aura deactivated!", 2)
end

function FireballAura.setInterval(interval)
    local n = tonumber(interval)
    FireballAura.fireInterval = n or pvpConstants.FIREBALL_INTERVAL
end

local function createFreeTool(toolName, skillName, fireCount)
    local tool = Instance.new("Tool")
    tool.Name = toolName
    tool.RequiresHandle = false

    tool.Activated:Connect(function()
        local mouse = LocalPlayer:GetMouse()
        for i = 1, (fireCount or 1) do
            local args = {
                [1] = mouse.Hit.p,
                [2] = skillName
            }
            pvpRemotes.skillsRemote:FireServer(table.unpack(args))
            if fireCount and fireCount > 1 then
                task.wait(0.1)
            end
        end
    end)

    tool.Parent = LocalPlayer.Backpack
    
    sendNotification(toolName .. " Created", "The " .. toolName .. " has been added to your backpack!", 1)
end

local function getPlayers()
    local players = {"Ninguém"}
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then
            table.insert(players, player.Name)
        end
    end
    return players
end

-- ========================================
-- PVP TAB CONTENT
-- ========================================

-- PVP TAB UI CREATION
Tabs.PvP:Section({ Title = "⚔️ Aura" })

Tabs.PvP:Dropdown({
    Title = "🎯 Target Priority",
    Desc = "Choose how targets are prioritized",
    Values = {"Closest", "Lowest Health"},
    Multi = false,
    Default = "Closest",
    Callback = function(priority)
        pvpConfig.targetPriority = priority
        sendNotification("🎯 Priority Changed", "Target priority set to: " .. priority, 2)
    end
})

Tabs.PvP:Toggle({
    Title = "🔥 Fireball Aura",
    Desc = "Automatically fires fireballs at targets based on priority",
    Value = false,
    Callback = function(state)
        if state then
            FireballAura.start()
        else
            FireballAura.stop()
        end
    end
})

Tabs.PvP:Slider({
    Title = "🔥 Fireball Interval",
    Desc = "Adjust how frequently fireballs are fired (in seconds)",
    Value = {
        Min = 0.1,
        Max = 2.0,
        Default = 0.5
    },
    Callback = function(value)
        FireballAura.setInterval(tonumber(value))
        sendNotification("🔥 Fireball Interval", "Fireball interval set to " .. value .. " seconds", 2)
    end
})

Tabs.PvP:Slider({
    Title = "🎯 Detection Radius",
    Desc = "Adjust how far away targets can be detected",
    Value = {
        Min = 20,
        Max = 200,
        Default = 70
    },
    Callback = function(value)
        pvpConfig.detectionRadius = tonumber(value) or pvpConfig.detectionRadius
        sendNotification("🎯 Detection Radius", "Detection radius set to " .. tostring(value) .. " studs", 2)
    end
})

Tabs.PvP:Toggle({
    Title = "⚔️ Kill Aura",
    Desc = "Enables or disables the Kill Aura function",
    Value = false,
    Callback = function(state)
        _G.killAura = state
        if state then
            task.spawn(killAuraLoop)
        end
        sendPvPNotification("⚔️ Kill Aura", state, "Kill Aura")
    end
})

Tabs.PvP:Section({ Title = "🔧 Other" })

Tabs.PvP:Toggle({
    Title = "🐟 Auto Eat (PC & Mobile)",
    Desc = "Automatically detects device type and uses appropriate input method for eating",
    Value = false,
    Callback = function(state)
        pvpStates.autoEat = state
        if state then
            task.spawn(autoEatLoop)
        end
        sendPvPNotification("🐟 Auto Eat", state, "Auto Eat")
    end
})

Tabs.PvP:Toggle({
    Title = "🤯 Loop Kill All Players",
    Desc = "Automatically hunts and kills all players",
    Value = false,
    Callback = function(state)
        _G.huntPlayers = state
        if state then
            task.spawn(loopKillAllPlayers)
        end
        sendPvPNotification("🤯 Loop Kill", state, "Loop Kill")
    end
})

Tabs.PvP:Toggle({
    Title = "😎 Auto Kill Low Levels",
    Desc = "Automatically hunts players with a lower level than you",
    Value = false,
    Callback = function(state)
        _G.farmLowLevels = state
        if state then
            task.spawn(autoKillLowLevels)
        end
        sendPvPNotification("😎 Auto Kill Low Levels", state, "Auto Kill Low Levels")
    end
})

Tabs.PvP:Section({ Title = "🛠️ Free Tools" })

Tabs.PvP:Button({
    Title = "🔥 Free Fireball",
    Desc = "Click to get a fireball!",
    Callback = function()
        createFreeTool("Fireball", "NewFireball", 1)
    end
})

Tabs.PvP:Button({
    Title = "⚡ Free Lightningball",
    Desc = "Click to get a Lightning Ball!",
    Callback = function()
        createFreeTool("Lightning Ball", "NewLightningball", 3)
    end
})

Tabs.PvP:Section({ Title = "🙋🏻 Teleport to Player" })

Tabs.PvP:Dropdown({
    Title = "🙋🏻 Teleport to Player",
    Desc = "Select a player to teleport to",
    Values = getPlayers(),
    Multi = false,
    Default = "Ninguém",
    Callback = function(selectedPlayer)
        pvpConfig.selectedPlayer = selectedPlayer
        
        if selectedPlayer == "Ninguém" then 
            sendNotification("Teleport", "No player selected", 1)
            return
        end
        
        local targetPlayer = Players:FindFirstChild(selectedPlayer)
        if targetPlayer and targetPlayer.Character and targetPlayer.Character:FindFirstChild("HumanoidRootPart") then
            local targetRoot = targetPlayer.Character.HumanoidRootPart
            local localRoot = getPlayerRoot()
            
            if localRoot then
                localRoot.CFrame = targetRoot.CFrame
                sendNotification("Teleport", "Teleported to " .. selectedPlayer, 1)
            end
        else
            sendNotification("Teleport", "Player not found or not in game", 1)
        end
    end
})

Tabs.PvP:Button({
    Title = "🔄 Refresh player list",
    Desc = "Update the player list",
    Callback = function()
        sendNotification("Player List", "Player list refreshed", 1)
    end
})

Tabs.PvP:Section({ Title = "🏛️ Clan Join" })

local clanConfig = {
    invitationEvent = ReplicatedStorage:WaitForChild("invitationEvent", 9e9),
    teamsFolder = workspace:FindFirstChild("Teams"),
    teamList = {},
    selectedClan = "",
    autoJoin = false,
    autoJoinThread = nil,
    lastJoinedClan = nil,
    dropdown = nil
}

local function refreshClanTeamList()
    clanConfig.teamList = {}
    local tf = workspace:FindFirstChild("Teams")
    
    -- Debug info
    if tf then
        for _, team in ipairs(tf:GetChildren()) do
            table.insert(clanConfig.teamList, team.Name)
        end
    end
    
    if clanConfig.dropdown then
        clanConfig.dropdown:Refresh(clanConfig.teamList)
        if not table.find(clanConfig.teamList, clanConfig.selectedClan) and #clanConfig.teamList > 0 then
            clanConfig.selectedClan = clanConfig.teamList[1] or ""
            if clanConfig.selectedClan ~= "" then clanConfig.dropdown:Select(clanConfig.selectedClan) end
        end
    end
end

local function getClanIcon(clanName)
    local clanIcon = ""
    pcall(function()
        local tf = workspace:FindFirstChild("Teams")
        if tf then
            local teamFolder = tf:FindFirstChild(clanName)
            if teamFolder and teamFolder:FindFirstChild("leader") then
                local leaderName = teamFolder.leader.Value
                local leaderPlayer = Players:FindFirstChild(leaderName)
                if leaderPlayer and leaderPlayer:FindFirstChild("ClanIcon") and leaderPlayer.ClanIcon.Value and leaderPlayer.ClanIcon.Value ~= "" then
                    clanIcon = leaderPlayer.ClanIcon.Value
                end
            end
        end
    end)
    return clanIcon
end

local function attemptClanJoin(clanName, clanIcon)
    local success = false
    pcall(function()
        local args = { { teamIcon = clanIcon, action = "accepted", teamName = clanName } }
        clanConfig.invitationEvent:FireServer(table.unpack(args))
        success = true
    end)

    if not success then
        pcall(function()
            local args = { { teamIcon = clanIcon, action = "accepted", teamName = clanName }, clanName }
            clanConfig.invitationEvent:FireServer(table.unpack(args))
            success = true
        end)
    end

    if not success then
        pcall(function()
            clanConfig.invitationEvent:FireServer(clanName)
            success = true
        end)
    end
    return success
end

clanConfig.dropdown = Tabs.PvP:Dropdown({
    Title = "Select Clan",
    Desc = "Pick a clan (team) to join",
    Values = clanConfig.teamList,
    Multi = false,
    Default = clanConfig.teamList[1],
    Callback = function(choice)
        clanConfig.selectedClan = choice
    end
})

-- Refresh after dropdown is created
refreshClanTeamList()

-- Also try refreshing after a delay in case Teams folder loads later
task.spawn(function()
    task.wait(2)
    refreshClanTeamList()
end)

Tabs.PvP:Button({
    Title = "Join Selected Clan",
    Desc = "Attempt to join the chosen clan",
    Callback = function()
        if not clanConfig.selectedClan or clanConfig.selectedClan == "" then
            WindUI:Notify({ Title = "Clan Join", Content = "No clan selected!", Duration = 2 })
            return
        end

        local clanIcon = getClanIcon(clanConfig.selectedClan)
        local currentClan = LocalPlayer:FindFirstChild("Clan") and LocalPlayer.Clan.Value or nil
        
        if currentClan and currentClan ~= clanConfig.selectedClan then
            pcall(function()
                ReplicatedStorage:WaitForChild("Events", 9e9):WaitForChild("ClanEvent", 9e9):FireServer({{ action = "leave_clan" }})
            end)
            task.wait(0.5)
        end

        WindUI:Notify({ Title = "Clan Join", Content = "Joining: " .. clanConfig.selectedClan, Duration = 2 })

        local success = attemptClanJoin(clanConfig.selectedClan, clanIcon)

        if success then
            clanConfig.lastJoinedClan = clanConfig.selectedClan
            WindUI:Notify({ Title = "Clan Join", Content = "Join request sent to '" .. clanConfig.selectedClan .. "'", Duration = 2 })
        else
            WindUI:Notify({ Title = "Clan Join", Content = "Failed to send join request", Duration = 2 })
        end
    end
})

Tabs.PvP:Toggle({
    Title = "Auto Join Selected Clan",
    Desc = "Continuously attempt to join the selected clan",
    Value = false,
    Callback = function(state)
        clanConfig.autoJoin = state
        if clanConfig.autoJoin then
            if clanConfig.autoJoinThread then return end
            clanConfig.autoJoinThread = task.spawn(function()
                while clanConfig.autoJoin do
                    if clanConfig.selectedClan and clanConfig.selectedClan ~= "" then
                        local clanIcon = getClanIcon(clanConfig.selectedClan)

                        if clanConfig.lastJoinedClan and clanConfig.lastJoinedClan ~= clanConfig.selectedClan then
                            pcall(function()
                                ReplicatedStorage:WaitForChild("Events", 9e9):WaitForChild("ClanEvent", 9e9):FireServer({{ action = "leave_clan" }})
                            end)
                        end

                        attemptClanJoin(clanConfig.selectedClan, clanIcon)
                        clanConfig.lastJoinedClan = clanConfig.selectedClan
                    end
                    task.wait(1)
                end
            end)
        else
            clanConfig.autoJoinThread = nil
        end
    end
})

Tabs.PvP:Button({
    Title = "Refresh Clan List",
    Desc = "Rescan available clans",
    Callback = function()
        refreshClanTeamList()
        WindUI:Notify({ Title = "Clan Join", Content = "Clan list refreshed", Duration = 2 })
    end
})

Tabs.PvP:Section({ Title = "🚀 Movement & ESP" })

local movementConfig = {
    espStorage = nil,
    espConnections = {},
    espConfig = {
        enabled = false,
        fillColor = Color3.fromRGB(255, 0, 0),
        depthMode = Enum.HighlightDepthMode.AlwaysOnTop,
        fillTransparency = 0.5,
        outlineColor = Color3.fromRGB(255, 255, 255),
        outlineTransparency = 0
    },
    walkSpeedConfig = {
        minSpeed = 16,
        maxSpeed = 200,
        currentSpeed = 16,
        debounce = false
    }
}

local function initializeESPStorage()
    if not movementConfig.espStorage then
        movementConfig.espStorage = Instance.new("Folder")
        movementConfig.espStorage.Name = "ESP_Storage"
        movementConfig.espStorage.Parent = game:GetService("CoreGui")
    end
end

local function createESP(player)
    if not movementConfig.espStorage or not movementConfig.espConfig.enabled then return end
    
    local highlight = Instance.new("Highlight")
    highlight.Name = player.Name
    highlight.FillColor = movementConfig.espConfig.fillColor
    highlight.DepthMode = movementConfig.espConfig.depthMode
    highlight.FillTransparency = movementConfig.espConfig.fillTransparency
    highlight.OutlineColor = movementConfig.espConfig.outlineColor
    highlight.OutlineTransparency = movementConfig.espConfig.outlineTransparency
    highlight.Parent = movementConfig.espStorage

    if player.Character then
        highlight.Adornee = player.Character
    end

    movementConfig.espConnections[player] = player.CharacterAdded:Connect(function(character)
        highlight.Adornee = character
    end)
end

local function removeESP(player)
    if movementConfig.espStorage then
        local esp = movementConfig.espStorage:FindFirstChild(player.Name)
        if esp then
            esp:Destroy()
        end
    end
    
    if movementConfig.espConnections[player] then
        movementConfig.espConnections[player]:Disconnect()
        movementConfig.espConnections[player] = nil
    end
end

local function toggleESP(state)
    movementConfig.espConfig.enabled = state
    
    if state then
        initializeESPStorage()
        for _, player in ipairs(Players:GetPlayers()) do
            if player ~= LocalPlayer then
                createESP(player)
            end
        end
    else
        for player, _ in pairs(movementConfig.espConnections) do
            removeESP(player)
        end
        
        if movementConfig.espStorage then
            movementConfig.espStorage:Destroy()
            movementConfig.espStorage = nil
        end
    end
    
    WindUI:Notify({
        Title = "👁️ ESP Players",
        Content = state and "ESP Activated!" or "ESP Deactivated!",
        Duration = 1
    })
end

local function updateWalkSpeed(speed)
    local character = LocalPlayer.Character
    if character and character:FindFirstChildOfClass("Humanoid") then
        character.Humanoid.WalkSpeed = speed
    end
end

local function delayedSpeedNotification()
    if movementConfig.walkSpeedConfig.debounce then return end
    movementConfig.walkSpeedConfig.debounce = true
    
    task.wait(1)
    
    WindUI:Notify({
        Title = "🚀 Speed Adjustment",
        Content = "Your walk speed has been set to " .. movementConfig.walkSpeedConfig.currentSpeed .. "!",
        Duration = 1
    })
    
    movementConfig.walkSpeedConfig.debounce = false
end

Tabs.PvP:Toggle({
    Title = "👁️ ESP Players",
    Desc = "Toggle to activate or deactivate ESP for players",
    Value = false,
    Callback = function(state)
        toggleESP(state)
    end
})

Tabs.PvP:Slider({
    Title = "🚀 Walk Speed",
    Desc = "Adjust your character's movement speed",
    Value = {
        Min = movementConfig.walkSpeedConfig.minSpeed,
        Max = movementConfig.walkSpeedConfig.maxSpeed,
        Default = movementConfig.walkSpeedConfig.currentSpeed
    },
    Callback = function(value)
        movementConfig.walkSpeedConfig.currentSpeed = value
        updateWalkSpeed(value)
        task.spawn(delayedSpeedNotification)
    end
})

LocalPlayer.CharacterAdded:Connect(function(character)
    if movementConfig.walkSpeedConfig.currentSpeed > movementConfig.walkSpeedConfig.minSpeed then
        character:WaitForChild("Humanoid")
        updateWalkSpeed(movementConfig.walkSpeedConfig.currentSpeed)
    end
end)

-- ========================================
-- TELEPORT TAB CONTENT
-- ========================================

-- TELEPORT TAB UI CREATION
Tabs.Teleport:Section({ Title = "📍 Teleport Locations" })

local teleportConfig = {
    locations = {
        {Name = "🏠 Safe Zone", Position = Vector3.new(-105.29137420654297, 642.4719848632812, 514.2374877929688)},
        {Name = "🏜️ Desert", Position = Vector3.new(-672.6334838867188, 642.568603515625, 1115.691162109375)},
        {Name = "🌋 Volcano", Position = Vector3.new(120.21180725097656, 685.631103515625, 1570.7666015625)},
        {Name = "🏖️ Beach", Position = Vector3.new(-29.751022338867188, 644.6039428710938, -70.5428695678711)},
        {Name = "☁️ Cloud Arena", Position = Vector3.new(-1173.7010498046875, 1268.14404296875, 766.4228515625)}
    },
    notificationDuration = 3,
    errorDuration = 3
}


local function teleportToLocation(location)
    local character = getPlayerRoot()
    if character then
        character.CFrame = CFrame.new(location.Position)
        sendNotification(location.Name, "You have been teleported successfully!", teleportConfig.notificationDuration)
    else
        sendNotification("Error", "Character not found or invalid!", teleportConfig.errorDuration)
    end
end

for _, location in ipairs(teleportConfig.locations) do
    Tabs.Teleport:Button({
        Title = location.Name,
        Desc = "Teleport to " .. location.Name:gsub("%p", ""),
        Callback = function()
            teleportToLocation(location)
        end
    })
end

-- ========================================
-- TARGET TAB CONTENT
-- ========================================

-- TARGET TAB UI CREATION
Tabs.Target:Section({ Title = "🎯 Target System" })

local targetConfig = {
    selectedPlayer = nil,
    feedback = nil,
    info = nil,
    velocityAsset = nil
}

local targetStates = {
    viewingTarget = false,
    focusingTarget = false,
    benxingTarget = false,
    headsittingTarget = false,
    standingTarget = false,
    backpackingTarget = false,
    doggyingTarget = false,
    sugaringTarget = false,
    draggingTarget = false
}

local function createVelocityAsset()
    local velocityAsset = Instance.new("BodyVelocity")
    velocityAsset.Name = "BreakVelocity"
    velocityAsset.MaxForce = Vector3.new(100000, 100000, 100000)
    velocityAsset.Velocity = ZERO_VECTOR
    return velocityAsset
end

local function playTargetAnim(id, time, speed)
    pcall(function()
        if not hasValidCharacter(LocalPlayer) then
            return
        end
        
        LocalPlayer.Character.Animate.Disabled = false
        local hum = LocalPlayer.Character.Humanoid
        local animtrack = hum:GetPlayingAnimationTracks()
        for i, track in pairs(animtrack) do
            track:Stop()
        end
        LocalPlayer.Character.Animate.Disabled = true
        
        local Anim = Instance.new("Animation")
        Anim.AnimationId = "rbxassetid://"..id
        local loadanim = hum:LoadAnimation(Anim)
        loadanim:Play()
        if time then 
            loadanim.TimePosition = time
        end
        if speed then
            loadanim:AdjustSpeed(speed)
        end
        
        loadanim.Stopped:Connect(function()
            LocalPlayer.Character.Animate.Disabled = false
            for i, track in pairs(animtrack) do
                track:Stop()
            end
        end)
        
        _G.CurrentAnimation = loadanim
    end)
end

local function stopTargetAnim()
    pcall(function()
        if hasValidCharacter(LocalPlayer) then
            LocalPlayer.Character.Animate.Disabled = false
            local animtrack = LocalPlayer.Character.Humanoid:GetPlayingAnimationTracks()
            for i, track in pairs(animtrack) do
                track:Stop()
            end
        end
        
        _G.CurrentAnimation = nil
    end)
end

local function getTargetRoot(player)
    return player and player.Character and player.Character:FindFirstChild("HumanoidRootPart")
end

local function teleportToTarget(posX, posY, posZ, targetPlayer, method)
    pcall(function()
        local localRoot = getPlayerRoot()
        if not localRoot then return end

        if method == "safe" then
            task.spawn(function()
                for i = 1,30 do
                    task.wait()
                    if localRoot then
                        localRoot.Velocity = ZERO_VECTOR
                        if targetPlayer == "pos" then
                            localRoot.CFrame = CFrame.new(posX,posY,posZ)
                        else
                            local targetRoot = getTargetRoot(targetPlayer)
                            if targetRoot then
                                localRoot.CFrame = CFrame.new(targetRoot.Position) + TELEPORT_OFFSET
                            end
                        end
                    end
                end
            end)
        else
            if localRoot then
                localRoot.Velocity = ZERO_VECTOR
                if targetPlayer == "pos" then
                    localRoot.CFrame = CFrame.new(posX,posY,posZ)
                else
                    local targetRoot = getTargetRoot(targetPlayer)
                    if targetRoot then
                        localRoot.CFrame = CFrame.new(targetRoot.Position) + TELEPORT_OFFSET
                    end
                end
            end
        end
    end)
end

local function createTargetTool()
    if LocalPlayer.Backpack:FindFirstChild("ClickTarget") then
        LocalPlayer.Backpack:FindFirstChild("ClickTarget"):Destroy()
    end
    if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("ClickTarget") then
        LocalPlayer.Character:FindFirstChild("ClickTarget"):Destroy()
    end

    local GetTargetTool = Instance.new("Tool")
    GetTargetTool.Name = "ClickTarget"
    GetTargetTool.RequiresHandle = false
    GetTargetTool.TextureId = "rbxassetid://6043845934"
    GetTargetTool.ToolTip = "Select Target"
    GetTargetTool.CanBeDropped = false

    GetTargetTool.Activated:Connect(function()
        local mouse = LocalPlayer:GetMouse()
        local hit = mouse.Target
        local person = nil
        
        if hit and hit.Parent then
            if hit.Parent:IsA("Model") then
                person = Players:GetPlayerFromCharacter(hit.Parent)
            elseif hit.Parent:IsA("Accessory") and hit.Parent.Parent then
                person = Players:GetPlayerFromCharacter(hit.Parent.Parent)
            end
            
            if person and person ~= LocalPlayer then
                sendNotification("Target Selected", "Current target: " .. person.Name, 2)
                
                targetConfig.selectedPlayer = person
                
                targetConfig.feedback:SetTitle("Target Selected: " .. person.Name)
                targetConfig.feedback:SetDesc("ID: " .. person.UserId .. "\nName: " .. person.DisplayName)
                
                local infoText = "Name: " .. person.Name
                infoText = infoText .. "\nDisplay: " .. person.DisplayName
                infoText = infoText .. "\nUserID: " .. person.UserId
                infoText = infoText .. "\nEntered: " .. os.date("%d-%m-%Y", os.time() - person.AccountAge * 24 * 3600)
                
                local team = person.Team and person.Team.Name or "None"
                infoText = infoText .. "\nTeam: " .. team
                
                targetConfig.info:SetTitle("Information: " .. person.Name)
                targetConfig.info:SetDesc(infoText)
                
                _G.TargetedUserId = person.UserId
            elseif person == LocalPlayer then
                sendNotification("Error", "You cannot select yourself.", 2)
            else
                targetConfig.selectedPlayer = nil
                _G.TargetedUserId = nil
                
                targetConfig.feedback:SetTitle("Target Status")
                targetConfig.feedback:SetDesc("No target selected.")
                
                targetConfig.info:SetTitle("Player Information")
                targetConfig.info:SetDesc("Select a target to view information.")
                
                sendNotification("Target Removed", "No player selected.", 2)
            end
        end
    end)
    
    GetTargetTool.Parent = LocalPlayer.Backpack
    GetTargetTool.Parent = LocalPlayer.Character
    
    sendNotification("Tool Created", "Use the tool to select a target by clicking on it.", 3)
end

targetConfig.feedback = Tabs.Target:Paragraph({
    Title = "Target Status",
    Desc = "No target selected."
})

targetConfig.info = Tabs.Target:Paragraph({
    Title = "Player Information",
    Desc = "Select a target to view information."
})

Tabs.Target:Button({
    Title = "Grab Selection Tool",
    Desc = "Creates a tool to select targets by clicking on them.",
    Icon = "rbxassetid://6043845934",
    Callback = function()
        createTargetTool()
    end
})

Tabs.Target:Section({ Title = "Target Actions" })

Tabs.Target:Toggle({
    Title = "View Target",
    Desc = "Switches the camera to view the target.",
    Value = false,
    Callback = function(state)
        if not targetConfig.selectedPlayer then
            sendNotification("Error", "No target selected.", 2)
            return
        end
        
        if state then
            local humanoid = hasValidCharacter(targetConfig.selectedPlayer) and targetConfig.selectedPlayer.Character:FindFirstChildOfClass("Humanoid")
            if humanoid then
                workspace.CurrentCamera.CameraSubject = humanoid
                
                sendNotification("Camera", "Viewing " .. targetConfig.selectedPlayer.Name, 2)
                
                targetConfig.feedback:SetDesc("Viewing " .. targetConfig.selectedPlayer.Name)
                
                _G.ViewLoop = task.spawn(function()
                    while targetStates.viewingTarget and targetConfig.selectedPlayer and task.wait(0.5) do
                        pcall(function()
                            if hasValidCharacter(targetConfig.selectedPlayer) then
                                workspace.CurrentCamera.CameraSubject = targetConfig.selectedPlayer.Character.Humanoid
                            end
                        end)
                    end
                end)
                
                targetStates.viewingTarget = true
            else
                sendNotification("Error", "Could not find target character.", 2)
            end
        else
            targetStates.viewingTarget = false
            
            if _G.ViewLoop then
                task.cancel(_G.ViewLoop)
                _G.ViewLoop = nil
            end
            
            pcall(function()
                workspace.CurrentCamera.CameraSubject = LocalPlayer.Character.Humanoid
            end)
            
            sendNotification("Camera", "Returning to normal view.", 2)
            
            targetConfig.feedback:SetDesc("Target: " .. targetConfig.selectedPlayer.Name)
        end
    end
})

Tabs.Target:Toggle({
    Title = "Focus on the Target",
    Desc = "Follows the target continuously.",
    Value = false,
    Callback = function(state)
        if not targetConfig.selectedPlayer then
            sendNotification("Error", "No target selected.", 2)
            return
        end
        
        if state then
            sendNotification("Focus", "Following " .. targetConfig.selectedPlayer.Name, 2)
            
            targetConfig.feedback:SetDesc("Following " .. targetConfig.selectedPlayer.Name)
            
            _G.FocusLoop = task.spawn(function()
                targetStates.focusingTarget = true
                while targetStates.focusingTarget and targetConfig.selectedPlayer and task.wait() do
                    pcall(function()
                        local targetRoot = getTargetRoot(targetConfig.selectedPlayer)
                        local localRoot = getPlayerRoot()
                        
                        if targetRoot and localRoot then
                            localRoot.CFrame = targetRoot.CFrame + Vector3.new(0, 2, 0)
                        end
                    end)
                end
            end)
        else
            targetStates.focusingTarget = false
            
            if _G.FocusLoop then
                task.cancel(_G.FocusLoop)
                _G.FocusLoop = nil
            end
            
            sendNotification("Focus", "Stopped following the target.", 2)
            
            targetConfig.feedback:SetDesc("Target: " .. targetConfig.selectedPlayer.Name)
        end
    end
})

Tabs.Target:Toggle({
    Title = "Headsit on Target",
    Desc = "Sits on the target's head.",
    Value = false,
    Callback = function(state)
        if not targetConfig.selectedPlayer then
            sendNotification("Error", "No target selected.", 2)
            return
        end
        
        if state then
            playTargetAnim(10714360343, 0.5, 0)
            
            sendNotification("Headsit", "Sitting on " .. targetConfig.selectedPlayer.Name .. "'s head", 2)
            
            targetConfig.feedback:SetDesc("Sitting on " .. targetConfig.selectedPlayer.Name .. "'s head")
            
            _G.HeadsitLoop = task.spawn(function()
                targetStates.headsittingTarget = true
                while targetStates.headsittingTarget and targetConfig.selectedPlayer and task.wait() do
                    pcall(function()
                        local localRoot = getPlayerRoot()
                        local targetHead = targetConfig.selectedPlayer.Character and targetConfig.selectedPlayer.Character:FindFirstChild("Head")
                        
                        if not localRoot:FindFirstChild("BreakVelocity") then
                            local TempV = createVelocityAsset()
                            TempV.Parent = localRoot
                        end
                        
                        if localRoot and targetHead then
                            localRoot.CFrame = targetHead.CFrame * CFrame.new(0, 1.5, 0)
                            localRoot.Velocity = Vector3.new(0, 0, 0)
                        end
                    end)
                end
                
                stopTargetAnim()
                pcall(function()
                    if getPlayerRoot():FindFirstChild("BreakVelocity") then
                        getPlayerRoot().BreakVelocity:Destroy()
                    end
                end)
            end)
        else
            targetStates.headsittingTarget = false
            
            if _G.HeadsitLoop then
                task.cancel(_G.HeadsitLoop)
                _G.HeadsitLoop = nil
            end
            
            stopTargetAnim()
            pcall(function()
                if getPlayerRoot():FindFirstChild("BreakVelocity") then
                    getPlayerRoot().BreakVelocity:Destroy()
                end
            end)
            
            sendNotification("Headsit", "Stopped sitting on the target's head.", 2)
            
            targetConfig.feedback:SetDesc("Target: " .. targetConfig.selectedPlayer.Name)
        end
    end
})

Tabs.Target:Toggle({
    Title = "Stand Next to the Target",
    Desc = "Stand next to the target.",
    Value = false,
    Callback = function(state)
        if not targetConfig.selectedPlayer then
            sendNotification("Error", "No target selected.", 2)
            return
        end
        
        if state then
            playTargetAnim(10714360343, 0.5, 0)
            
            sendNotification("Stand", "Standing next to " .. targetConfig.selectedPlayer.Name, 2)
            
            targetConfig.feedback:SetDesc("Standing next to " .. targetConfig.selectedPlayer.Name)
            
            _G.StandLoop = task.spawn(function()
                targetStates.standingTarget = true
                while targetStates.standingTarget and targetConfig.selectedPlayer and task.wait() do
                    pcall(function()
                        local localRoot = getPlayerRoot()
                        local targetRoot = getTargetRoot(targetConfig.selectedPlayer)
                        
                        if not localRoot:FindFirstChild("BreakVelocity") then
                            local TempV = createVelocityAsset()
                            TempV.Parent = localRoot
                        end
                        
                        if localRoot and targetRoot then
                            localRoot.CFrame = targetRoot.CFrame * CFrame.new(2, 0, 0)
                            localRoot.Velocity = Vector3.new(0, 0, 0)
                        end
                    end)
                end
                
                stopTargetAnim()
                pcall(function()
                    if getPlayerRoot():FindFirstChild("BreakVelocity") then
                        getPlayerRoot().BreakVelocity:Destroy()
                    end
                end)
            end)
        else
            targetStates.standingTarget = false
            
            if _G.StandLoop then
                task.cancel(_G.StandLoop)
                _G.StandLoop = nil
            end
            
            stopTargetAnim()
            pcall(function()
                if getPlayerRoot():FindFirstChild("BreakVelocity") then
                    getPlayerRoot().BreakVelocity:Destroy()
                end
            end)
            
            sendNotification("Stand", "Stopped standing next to the target.", 2)
            
            targetConfig.feedback:SetDesc("Target: " .. targetConfig.selectedPlayer.Name)
        end
    end
})

Tabs.Target:Toggle({
    Title = "Backpack on Target",
    Desc = "Backpack position on target.",
    Value = false,
    Callback = function(state)
        if not targetConfig.selectedPlayer then
            sendNotification("Error", "No target selected.", 2)
            return
        end
        
        if state then
            playTargetAnim(10714360343, 0.5, 0)
            
            sendNotification("Backpack", "Backpacking on " .. targetConfig.selectedPlayer.Name, 2)
            
            targetConfig.feedback:SetDesc("Backpacking on " .. targetConfig.selectedPlayer.Name)
            
            _G.BackpackLoop = task.spawn(function()
                targetStates.backpackingTarget = true
                while targetStates.backpackingTarget and targetConfig.selectedPlayer and task.wait() do
                    pcall(function()
                        local localRoot = getPlayerRoot()
                        local targetRoot = getTargetRoot(targetConfig.selectedPlayer)
                        
                        if not localRoot:FindFirstChild("BreakVelocity") then
                            local TempV = createVelocityAsset()
                            TempV.Parent = localRoot
                        end
                        
                        if localRoot and targetRoot then
                            localRoot.CFrame = targetRoot.CFrame * CFrame.new(0, -2, 0)
                            localRoot.Velocity = Vector3.new(0, 0, 0)
                        end
                    end)
                end
                
                stopTargetAnim()
                pcall(function()
                    if getPlayerRoot():FindFirstChild("BreakVelocity") then
                        getPlayerRoot().BreakVelocity:Destroy()
                    end
                end)
            end)
        else
            targetStates.backpackingTarget = false
            
            if _G.BackpackLoop then
                task.cancel(_G.BackpackLoop)
                _G.BackpackLoop = nil
            end
            
            stopTargetAnim()
            pcall(function()
                if getPlayerRoot():FindFirstChild("BreakVelocity") then
                    getPlayerRoot().BreakVelocity:Destroy()
                end
            end)
            
            sendNotification("Backpack", "Stopped backpacking on target.", 2)
            
            targetConfig.feedback:SetDesc("Target: " .. targetConfig.selectedPlayer.Name)
        end
    end
})

Tabs.Target:Toggle({
    Title = "Doggy on Target",
    Desc = "Dog position on target.",
    Value = false,
    Callback = function(state)
        if not targetConfig.selectedPlayer then
            sendNotification("Error", "No target selected.", 2)
            return
        end
        
        if state then
            playTargetAnim(10714360343, 0.5, 0)
            
            sendNotification("Doggy", "Doing doggy on " .. targetConfig.selectedPlayer.Name, 2)
            
            targetConfig.feedback:SetDesc("Doing doggy on " .. targetConfig.selectedPlayer.Name)
            
            _G.DoggyLoop = task.spawn(function()
                targetStates.doggyingTarget = true
                while targetStates.doggyingTarget and targetConfig.selectedPlayer and task.wait() do
                    pcall(function()
                        local localRoot = getPlayerRoot()
                        local targetRoot = getTargetRoot(targetConfig.selectedPlayer)
                        
                        if not localRoot:FindFirstChild("BreakVelocity") then
                            local TempV = createVelocityAsset()
                            TempV.Parent = localRoot
                        end
                        
                        if localRoot and targetRoot then
                            localRoot.CFrame = targetRoot.CFrame * CFrame.new(0, -1, -1) * CFrame.Angles(math.rad(90), 0, 0)
                            localRoot.Velocity = Vector3.new(0, 0, 0)
                        end
                    end)
                end
                
                stopTargetAnim()
                pcall(function()
                    if getPlayerRoot():FindFirstChild("BreakVelocity") then
                        getPlayerRoot().BreakVelocity:Destroy()
                    end
                end)
            end)
        else
            targetStates.doggyingTarget = false
            
            if _G.DoggyLoop then
                task.cancel(_G.DoggyLoop)
                _G.DoggyLoop = nil
            end
            
            stopTargetAnim()
            pcall(function()
                if getPlayerRoot():FindFirstChild("BreakVelocity") then
                    getPlayerRoot().BreakVelocity:Destroy()
                end
            end)
            
            sendNotification("Doggy", "Stopped doing doggy on target.", 2)
            
            targetConfig.feedback:SetDesc("Target: " .. targetConfig.selectedPlayer.Name)
        end
    end
})

Tabs.Target:Toggle({
    Title = "Suck on Target",
    Desc = "Make the target suck you in.",
    Value = false,
    Callback = function(state)
        if not targetConfig.selectedPlayer then
            sendNotification("Error", "No target selected.", 2)
            return
        end
        
        if state then
            playTargetAnim(10714360343, 0.5, 0)
            
            sendNotification("Suck", "Making " .. targetConfig.selectedPlayer.Name .. " suck you in", 2)
            
            targetConfig.feedback:SetDesc("Making " .. targetConfig.selectedPlayer.Name .. " suck you in")
            
            _G.SugarLoop = task.spawn(function()
                targetStates.sugaringTarget = true
                local moveTimer = 0
                local moveDirection = 1
                
                while targetStates.sugaringTarget and targetConfig.selectedPlayer and task.wait() do
                    pcall(function()
                        local localRoot = getPlayerRoot()
                        local targetHead = targetConfig.selectedPlayer.Character and targetConfig.selectedPlayer.Character:FindFirstChild("Head")
                        
                        if not localRoot:FindFirstChild("BreakVelocity") then
                            local TempV = createVelocityAsset()
                            TempV.Parent = localRoot
                        end
                        
                        moveTimer = moveTimer + 0.1
                        if moveTimer > 1 then
                            moveDirection = -moveDirection
                            moveTimer = 0
                        end
                        
                        local offset = 0.3 * moveDirection
                        
                        if localRoot and targetHead then
                            localRoot.CFrame = targetHead.CFrame * CFrame.new(0, 0.7, -(1.5 + offset)) * CFrame.Angles(0, math.rad(180), 0)
                            localRoot.Velocity = Vector3.new(0, 0, 0)
                        end
                    end)
                end
                
                stopTargetAnim()
                pcall(function()
                    if getPlayerRoot():FindFirstChild("BreakVelocity") then
                        getPlayerRoot().BreakVelocity:Destroy()
                    end
                end)
            end)
        else
            targetStates.sugaringTarget = false
            
            if _G.SugarLoop then
                task.cancel(_G.SugarLoop)
                _G.SugarLoop = nil
            end
            
            stopTargetAnim()
            pcall(function()
                if hasValidCharacter(LocalPlayer) then
                    LocalPlayer.Character.Humanoid.PlatformStand = false
                end
                
                if getPlayerRoot():FindFirstChild("BreakVelocity") then
                    getPlayerRoot().BreakVelocity:Destroy()
                end
            end)
            
            sendNotification("Suck", "Stopped making the target suck you in", 2)
            
            targetConfig.feedback:SetDesc("Target: " .. targetConfig.selectedPlayer.Name)
        end
    end
})

Tabs.Target:Toggle({
    Title = "Drag on Target",
    Desc = "Get dragged by the target by the hand.",
    Value = false,
    Callback = function(state)
        if not targetConfig.selectedPlayer then
            sendNotification("Error", "No target selected.", 2)
            return
        end
        
        if state then
            playTargetAnim(10714360343, 0.5, 0)
            
            if hasValidCharacter(LocalPlayer) then
                LocalPlayer.Character.Humanoid.PlatformStand = true
            end
            
            sendNotification("Drag", "Dragging " .. targetConfig.selectedPlayer.Name, 2)
            
            targetConfig.feedback:SetDesc("Dragging " .. targetConfig.selectedPlayer.Name)
            
            _G.DragLoop = task.spawn(function()
                targetStates.draggingTarget = true
                while targetStates.draggingTarget and targetConfig.selectedPlayer and task.wait() do
                    pcall(function()
                        local localRoot = getPlayerRoot()
                        local targetRightHand = nil
                        
                        if targetConfig.selectedPlayer.Character and targetConfig.selectedPlayer.Character:FindFirstChild("RightHand") then
                            targetRightHand = targetConfig.selectedPlayer.Character.RightHand
                        end
                        
                        if not targetRightHand then
                            targetRightHand = getTargetRoot(targetConfig.selectedPlayer)
                        end
                        
                        if not localRoot:FindFirstChild("BreakVelocity") then
                            local TempV = createVelocityAsset()
                            TempV.Parent = localRoot
                        end
                        
                        if localRoot and targetRightHand then
                            localRoot.CFrame = targetRightHand.CFrame * CFrame.new(0, -2.5, 1) * CFrame.Angles(-2, -3, 0)
                            localRoot.Velocity = Vector3.new(0, 0, 0)
                        end
                    end)
                end
                
                stopTargetAnim()
                pcall(function()
                    if hasValidCharacter(LocalPlayer) then
                        LocalPlayer.Character.Humanoid.PlatformStand = false
                    end
                    
                    if getPlayerRoot():FindFirstChild("BreakVelocity") then
                        getPlayerRoot().BreakVelocity:Destroy()
                    end
                end)
            end)
        else
            targetStates.draggingTarget = false
            
            if _G.DragLoop then
                task.cancel(_G.DragLoop)
                _G.DragLoop = nil
            end
            
            stopTargetAnim()
            pcall(function()
                if hasValidCharacter(LocalPlayer) then
                    LocalPlayer.Character.Humanoid.PlatformStand = false
                end
                
                if getPlayerRoot():FindFirstChild("BreakVelocity") then
                    getPlayerRoot().BreakVelocity:Destroy()
                end
            end)
            
            sendNotification("Drag", "Stopped dragging the target.", 2)
            
            targetConfig.feedback:SetDesc("Target: " .. targetConfig.selectedPlayer.Name)
        end
    end
})

Tabs.Target:Button({
    Title = "Teleport to Target",
    Desc = "Teleports to target (single action).",
    Callback = function()
        if not targetConfig.selectedPlayer then
            sendNotification("Error", "No target selected.", 2)
            return
        end
        
        teleportToTarget(0, 0, 0, targetConfig.selectedPlayer, "safe")
        
        sendNotification("Teleport", "Teleporting for " .. targetConfig.selectedPlayer.Name, 2)
        
        targetConfig.feedback:SetDesc("Teleporting for " .. targetConfig.selectedPlayer.Name)
    end
})

Players.PlayerRemoving:Connect(function(player)
    pcall(function()
        if targetConfig.selectedPlayer and player == targetConfig.selectedPlayer then
            for _, loopName in ipairs({"ViewLoop", "FocusLoop", "BenxLoop", "HeadsitLoop", "StandLoop", "BackpackLoop", "DoggyLoop", "SugarLoop", "DragLoop"}) do
                if _G[loopName] then
                    task.cancel(_G[loopName])
                    _G[loopName] = nil
                end
            end
            
            for stateName, _ in pairs(targetStates) do
                targetStates[stateName] = false
            end
            
            stopTargetAnim()
            pcall(function()
                if getPlayerRoot():FindFirstChild("BreakVelocity") then
                    getPlayerRoot().BreakVelocity:Destroy()
                end
            end)
            
            targetConfig.selectedPlayer = nil
            _G.TargetedUserId = nil
            
            targetConfig.feedback:SetTitle("Target Status")
            targetConfig.feedback:SetDesc("No target selected.")
            
            targetConfig.info:SetTitle("Player Information")
            targetConfig.info:SetDesc("Select a target to view information.")
            
            sendNotification("Target Left", "Target player has left the game.", 2)
        end
    end)
end)

-- ========================================
-- SCRIPTS TAB CONTENT
-- ========================================

-- SCRIPTS TAB UI CREATION
Tabs.Scripts:Section({ Title = "📄 External Scripts" })

local scriptsConfig = {
    scripts = {
        {
            title = "📄 Infinity Yield",
            desc = "Execute the Infinity Yield script",
            url = "https://raw.githubusercontent.com/EdgeIY/infiniteyield/master/source",
            successMessage = "The Infinity Yield script has been executed successfully!"
        },
        {
            title = "📄 Moon AntiAfk",
            desc = "Execute the Moon AntiAfk script",
            url = "https://raw.githubusercontent.com/rodri0022/afkmoon/refs/heads/main/README.md",
            successMessage = "The Moon AntiAfk script has been executed!"
        },
        {
            title = "📄 Moon AntiLag",
            desc = "Execute the Moon AntiLag script",
            url = "https://raw.githubusercontent.com/nick0022/antilag/refs/heads/main/README.md",
            successMessage = "The Moon AntiLag script has been executed!"
        },
        {
            title = "📄 FE R15 Emotes and Animation",
            desc = "Execute the FE R15 Emotes and Animation script",
            url = "https://raw.githubusercontent.com/BeemTZy/Motiona/refs/heads/main/source.lua",
            successMessage = "The FE R15 Emotes and Animation script has been executed!"
        },
        {
            title = "📄 Moon FE Emotes",
            desc = "Execute the Moon Emotes script",
            url = "https://raw.githubusercontent.com/rodri0022/freeanimmoon/refs/heads/main/README.md",
            successMessage = "The Moon Emotes script has been executed!"
        },
        {
            title = "📄 Moon Troll",
            desc = "Execute the Moon Troll script",
            url = "https://raw.githubusercontent.com/nick0022/trollscript/refs/heads/main/README.md",
            successMessage = "The Moon Troll script has been executed!"
        },
        {
            title = "📄 Sirius",
            desc = "Execute the Sirius script",
            url = "https://sirius.menu/sirius",
            successMessage = "The Sirius script has been executed!"
        },
        {
            title = "📄 Keyboard",
            desc = "Execute the Keyboard script",
            url = "https://raw.githubusercontent.com/GGH52lan/GGH52lan/main/keyboard.txt",
            successMessage = "The Keyboard script has been executed!"
        },
        {
            title = "📄 Shader",
            desc = "Script to make your game beautiful.",
            url = "https://raw.githubusercontent.com/randomstring0/pshade-ultimate/refs/heads/main/src/cd.lua",
            successMessage = "The shader script has been executed!"
        }
    }
}

local function executeScript(scriptData)
    pcall(function()
        loadstring(game:HttpGet(scriptData.url))()
        sendNotification(scriptData.title, scriptData.successMessage, 1)
    end)
end

for _, scriptData in ipairs(scriptsConfig.scripts) do
    Tabs.Scripts:Button({
        Title = scriptData.title,
        Desc = scriptData.desc,
        Callback = function()
            executeScript(scriptData)
        end
    })
end

-- ========================================
-- MISC TAB CONTENT
-- ========================================

-- MISC TAB UI CREATION
Tabs.Misc:Section({ Title = "🎭 Animation" })

local miscConfig = {
    animation = {
        enabled = false,
        nameParts = {"M", "Mo", "Moo", "Moon", "Moon ", "Moon H", "Moon Hu", "Moon Hub"},
        delay = 0.2,
        pauseDelay = 0.5
    },
    admin = {
        groupId = GROUP_ID,
        adminRank = MIN_ADMIN_RANK,
        moderatorRank = MIN_ADMIN_RANK,
        alertsEnabled = true
    },
    spectate = {
        selectedPlayer = "Ninguém",
        isSpectating = false,
        camera = workspace.CurrentCamera
    },
    voiceChat = {
        service = VoiceChatService
    },
    fling = {
        scriptUrl = "https://raw.githubusercontent.com/nick0022/walkflinng/refs/heads/main/README.md"
    },
    void = {
        voidOffset = Vector3.new(0, -500, 0),
        returnDelay = 3
    }
}


local function animateName()
    while miscConfig.animation.enabled do
        for _, text in ipairs(miscConfig.animation.nameParts) do
            if not miscConfig.animation.enabled then break end
            local args = {text, "player"}
            ReplicatedStorage:WaitForChild("Events"):WaitForChild("nameEvent"):FireServer(table.unpack(args))
            task.wait(miscConfig.animation.delay)
        end
        task.wait(miscConfig.animation.pauseDelay)
    end
end

local function checkAdminStatus(player)
    local success, rank = pcall(function()
        return player:GetRankInGroup(miscConfig.admin.groupId)
    end)
    if not success then return false, false end
    local isAdmin = rank >= miscConfig.admin.adminRank
    local isModerator = not isAdmin and rank >= miscConfig.admin.moderatorRank
    return isAdmin, isModerator
end

local function playerAdded(player)
    if not miscConfig.admin.alertsEnabled then return end
    local isAdmin, isModerator = checkAdminStatus(player)
    if isAdmin or isModerator then
        local role = isAdmin and "Administrator" or "Moderator"
        sendNotification("⚠️ Staff Join Alert", player.Name .. " (" .. role .. ") has joined the game", 1)
    end
end

local function updateSpectateDropdown()
    local players = getPlayers()
    if SpectateDropdown then
        local currentSelection = miscConfig.spectate.selectedPlayer
        local selectionExists = false
        for _, player in ipairs(players) do
            if player == currentSelection then
                selectionExists = true
                break
            end
        end
        SpectateDropdown:Refresh(players)
        if not selectionExists or currentSelection == nil then
            SpectateDropdown:Select("Ninguém")
            miscConfig.spectate.selectedPlayer = "Ninguém"
        else
            SpectateDropdown:Select(currentSelection)
        end
    end
end

local function startSpectating()
    if not miscConfig.spectate.selectedPlayer or miscConfig.spectate.selectedPlayer == "Ninguém" then
        sendNotification("Error", "No player selected to spectate!", 3)
        return
    end
    local target = Players:FindFirstChild(miscConfig.spectate.selectedPlayer)
    if target and target.Character then
        local humanoidRootPart = target.Character:FindFirstChild("HumanoidRootPart")
        if humanoidRootPart then
            miscConfig.spectate.isSpectating = true
            miscConfig.spectate.camera.CameraSubject = humanoidRootPart
            sendNotification("🧿 Spectating", "Now spectating " .. target.Name, 3)
            target.CharacterAdded:Connect(function(character)
                if miscConfig.spectate.isSpectating then
                    character:WaitForChild("HumanoidRootPart")
                    miscConfig.spectate.camera.CameraSubject = character.HumanoidRootPart
                end
            end)
        end
    else
        sendNotification("Error", "Player not found or invalid target!", 3)
    end
end

local function stopSpectating()
    miscConfig.spectate.isSpectating = false
    local character = LocalPlayer.Character
    if character then
        local humanoid = character:FindFirstChildOfClass("Humanoid")
        if humanoid then
            miscConfig.spectate.camera.CameraSubject = humanoid
        end
    end
    sendNotification("🧿 Spectating Stopped", "No longer spectating", 3)
    if SpectateDropdown then
        SpectateDropdown:Select("Ninguém")
        miscConfig.spectate.selectedPlayer = "Ninguém"
    end
end

Tabs.Misc:Toggle({
    Title = "Moon Hub Animation",
    Desc = "Animate the Moon Hub name",
    Value = false,
    Callback = function(state)
        miscConfig.animation.enabled = state
        if state then
            task.spawn(animateName)
        end
    end
})

Tabs.Misc:Section({ Title = "⚠️ Admin Alerts" })

Tabs.Misc:Toggle({
    Title = "⚠️ Staff Join Alerts",
    Desc = "Get notifications when staff members join",
    Value = true,
    Callback = function(state)
        miscConfig.admin.alertsEnabled = state
        sendNotification("Staff Alerts", state and "Staff join alerts enabled" or "Staff join alerts disabled", 1)
    end
})

Tabs.Misc:Section({ Title = "🧿 Spectate" })

SpectateDropdown = Tabs.Misc:Dropdown({
    Title = "🧿 Spectate Player",
    Desc = "Select a player to spectate",
    Values = getPlayers(),
    Multi = false,
    Default = "Ninguém",
    Callback = function(selected)
        miscConfig.spectate.selectedPlayer = selected
        if selected ~= "Ninguém" then
            sendNotification("Player Selected", "Ready to spectate: " .. selected, 2)
        end
    end
})

Tabs.Misc:Button({
    Title = "▶️ Start Spectating",
    Desc = "Begin spectating the selected player",
    Callback = startSpectating
})

Tabs.Misc:Button({
    Title = "⏹️ Stop Spectating",
    Desc = "Stop spectating and return to your character",
    Callback = stopSpectating
})

Tabs.Misc:Section({ Title = "🛠️ Tools" })

Tabs.Misc:Button({
    Title = "🗣️ Unban Voice Chat",
    Desc = "Click to remove your voice chat ban",
    Callback = function()
        local success, err = pcall(function()
            miscConfig.voiceChat.service:JoinVoiceChat()
        end)
        if success then
            sendNotification("🗣️ Voice Chat Unbanned", "Your voice chat has been unbanned!", 1)
        else
            sendNotification("Error", "Failed to unban voice chat: " .. tostring(err), 1)
        end
    end
})

Tabs.Misc:Button({
    Title = "☠️ Fling",
    Desc = "Carry someone, enable this, then release to fling them",
    Callback = function()
        local success, err = pcall(function()
            loadstring(game:HttpGet(miscConfig.fling.scriptUrl, true))()
        end)
        if success then
            sendNotification("☠️ Fling Activated", "The fling script has been executed successfully!", 1)
        else
            sendNotification("Error", "Failed to load fling script: " .. tostring(err), 1)
        end
    end
})

Tabs.Misc:Button({
    Title = "🕳️ Void Player",
    Desc = "Carry a player, activate this, then drop them into the void",
    Callback = function()
        local character = LocalPlayer.Character
        if not character or not character.PrimaryPart then
            sendNotification("Error", "Character not found or invalid!", 1)
            return
        end
        local originalPosition = character.PrimaryPart.Position
        local voidPosition = originalPosition + miscConfig.void.voidOffset
        sendNotification("🕳️ Void Player", "Preparing void teleport...", 1)
        character:SetPrimaryPartCFrame(CFrame.new(voidPosition))
        sendNotification("🕳️ Void Player", "Player sent to void! Releasing in 3 seconds...", 3)
        task.wait(miscConfig.void.returnDelay)
        if character and character.PrimaryPart then
            character:SetPrimaryPartCFrame(CFrame.new(originalPosition))
            sendNotification("🕳️ Void Player", "Player returned from void!", 1)
        else
            sendNotification("Error", "Character became invalid during process!", 1)
        end
    end
})

Players.PlayerAdded:Connect(playerAdded)

Tabs.Admin:Section({ Title = "📢 Announce" })
Tabs.Settings:Section({ Title = "⚙️ General Settings" })

local function showNotification(title, content, duration, icon)
    WindUI:Notify({
        Title = title,
        Content = content,
        Duration = duration or 3,
        Icon = icon or "info"
    })
end

Tabs.Skins:Section({ Title = "🎨 Skin Unlocks" })

local skinsConfig = {
    skinSets = {
        {
            title = "🎅🏻 Christmas Skins",
            desc = "Unlock all Christmas skins",
            skins = {"XM24Fr", "XM24Fr", "XM24Bear", "XM24Eag", "XM24Br", "XM24Cr", "XM24Sq"},
            successMessage = "All Christmas skins have been successfully unlocked!"
        },
        {
            title = "🐷 Pig Skins",
            desc = "Unlock all Pig skins",
            skins = {"PIG1", "PIG2", "PIG3", "PIG4", "PIG5", "PIG6", "PIG7", "PIG8"},
            successMessage = "All Pig skins have been successfully unlocked!"
        }
    },
    secretWeapons = {
        {
            title = "⚔️ Secret Weapon",
            desc = "Unlock a secret sword skin",
            weaponId = "SSSSSSS2",
            successMessage = "Secret sword skin has been successfully unlocked!"
        },
        {
            title = "⚔️ Secret Weapon2",
            desc = "Unlock a secret sword skin",
            weaponId = "SSSSSSS4",
            successMessage = "Secret sword skin has been successfully unlocked!"
        },
        {
            title = "⚔️ Secret Weapon3",
            desc = "Unlock a secret sword skin",
            weaponId = "SSSS2",
            successMessage = "Secret sword skin has been successfully unlocked!"
        },
        {
            title = "⚔️ Secret Weapon4",
            desc = "Unlock a secret sword skin",
            weaponId = "SSSS1",
            successMessage = "Secret sword skin has been successfully unlocked!"
        }
    },
    easterEvent = {
        title = "🥚 Easter Event Skins",
        desc = "Unlock all the skins for the 2025 Easter event",
        locations = {
            A = Vector3.new(-127.946053, 642.647949, 429.429596),
            B = Vector3.new(-137.940262, 642.648254, 434.050598)
        },
        puzzleCount = 25,
        successMessage = "All Easter event skins have been unlocked!"
    }
}

local function unlockSkinSet(skinSet)
    for _, skin in pairs(skinSet.skins) do
        ReplicatedStorage.Events.SkinClickEvent:FireServer(skin, "v2")
        task.wait(0.1)
    end
    sendNotification(skinSet.title .. " Unlocked", skinSet.successMessage, 3)
end

local function unlockSecretWeapon(weaponData)
    local args = {[1] = weaponData.weaponId}
    ReplicatedStorage:WaitForChild("Events", 9e9):WaitForChild("WeaponEvent", 9e9):FireServer(table.unpack(args))
    sendNotification(weaponData.title .. " Unlocked", weaponData.successMessage, 3)
end

local function teleportToLocation(position)
    if not RunService:IsClient() then return end
    
    local player = LocalPlayer
    if not player then return end
    
    local character = player.Character or player.CharacterAdded:Wait()
    if not character then return end

    local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
    if not humanoidRootPart then 
        warn("HumanoidRootPart not found for teleport.")
        return 
    end

    task.wait(2)
    humanoidRootPart.CFrame = CFrame.new(position)
    task.wait(0.1)
end

local function triggerEasterEvent(puzzleNumber)
    if not RunService:IsClient() then return end

    local easterEventFolder = ReplicatedStorage:WaitForChild("Easter2025", 9e9)
    if not easterEventFolder then
        warn("Easter2025 folder not found in ReplicatedStorage.")
        return
    end
    
    local remoteEvent = easterEventFolder:WaitForChild("RemoteEvent", 9e9)
    if not remoteEvent then
        warn("RemoteEvent not found inside Easter2025.")
        return
    end

    local args = {
        [1] = {
            ["action"] = "pick_up",
            ["puzzle_name"] = "PUZ" .. tostring(puzzleNumber)
        }
    }

    remoteEvent:FireServer(table.unpack(args))
    task.wait(0.1)
end

local function unlockEasterSkins()
    for i = 1, skinsConfig.easterEvent.puzzleCount do
        teleportToLocation(skinsConfig.easterEvent.locations.A)
        triggerEasterEvent(i)
        teleportToLocation(skinsConfig.easterEvent.locations.B)
        teleportToLocation(skinsConfig.easterEvent.locations.A)
    end
    sendNotification(skinsConfig.easterEvent.title .. " Unlocked", skinsConfig.easterEvent.successMessage, 3)
end

-- ========================================
-- SKINS TAB CONTENT
-- ========================================

-- SKINS TAB UI CREATION
for _, skinSet in ipairs(skinsConfig.skinSets) do
    Tabs.Skins:Button({
        Title = skinSet.title,
        Desc = skinSet.desc,
        Callback = function()
            unlockSkinSet(skinSet)
        end
    })
end

Tabs.Skins:Button({
    Title = skinsConfig.easterEvent.title,
    Desc = skinsConfig.easterEvent.desc,
    Callback = function()
        unlockEasterSkins()
    end
})

for _, weaponData in ipairs(skinsConfig.secretWeapons) do
    Tabs.Skins:Button({
        Title = weaponData.title,
        Desc = weaponData.desc,
        Callback = function()
            unlockSecretWeapon(weaponData)
        end
    })
end

-- ========================================
-- NPC TAB CONTENT
-- ========================================

-- NPC TAB UI CREATION
Tabs.NPC:Section({ Title = "Auto Kill NPCs" })
Tabs.NPC:Paragraph({ Title = "How it works", Desc = "Automatically kills any nearby NPCs after you damage them." })

local npcConfig = {
    autoKillEnabled = false,
    killRadius = 15,
    healthThreads = {},
    monitorThread = nil
}

local function isNPC(char)
    return char and char:FindFirstChildOfClass("Humanoid") and char.Name ~= LocalPlayer.Name and char:IsDescendantOf(workspace.NPC)
end

local function armNPC(npc)
    if npcConfig.healthThreads[npc] then return end
    local hum = npc:FindFirstChildOfClass("Humanoid")
    if not hum then return end
    local lastHealth = hum.Health
    npcConfig.healthThreads[npc] = hum:GetPropertyChangedSignal("Health"):Connect(function()
        if hum.Health < lastHealth then
            task.wait(0.05)
            hum.Health = 0
            if npc:FindFirstChild("HumanoidRootPart") then
                npc.HumanoidRootPart:BreakJoints()
            end
            sendNotification("NPC", "Auto-killed NPC '"..npc.Name.."' after you damaged it!", 2)
        end
        lastHealth = hum.Health
    end)
end

local function disarmAllNPCs()
    for npc, conn in pairs(npcConfig.healthThreads) do
        if conn then conn:Disconnect() end
    end
    npcConfig.healthThreads = {}
end

Tabs.NPC:Toggle({
    Title = "Auto Kill Nearby NPCs After Damage",
    Desc = "Will kill any nearby NPCs after you damage them",
    Value = false,
    Callback = function(state)
        npcConfig.autoKillEnabled = state
        local player = LocalPlayer
        local radius = npcConfig.killRadius
        
        if npcConfig.autoKillEnabled then
            sendNotification("NPC", "Auto-kill armed: Will kill any nearby NPCs after you damage them!", 3)
            npcConfig.monitorThread = task.spawn(function()
                while npcConfig.autoKillEnabled do
                    local myChar = player.Character
                    local myHRP = myChar and myChar:FindFirstChild("HumanoidRootPart")
                    if myHRP then
                        for _, npc in ipairs(workspace.NPC:GetChildren()) do
                            if isNPC(npc) and not npcConfig.healthThreads[npc] then
                                local npcHRP = npc:FindFirstChild("HumanoidRootPart")
                                if npcHRP and (npcHRP.Position - myHRP.Position).Magnitude <= radius then
                                    armNPC(npc)
                                end
                            end
                        end
                    end
                    task.wait(0.5)
                end
            end)
        else
            disarmAllNPCs()
            if npcConfig.monitorThread then
                task.cancel(npcConfig.monitorThread)
                npcConfig.monitorThread = nil
            end
            sendNotification("NPC", "Auto-kill stopped.", 2)
        end
    end
})

-- ========================================
-- PREMIUM TAB CONTENT
-- ========================================

-- PREMIUM TAB UI CREATION
Tabs.Premium:Section({ Title = "God mode" })

local premiumConfig = {
    lastClickedAnimal = nil,
    lastClickedSkin = nil,
    selectedWeaponIndex = 1,
    weaponCodes = {
        [1] = "SS4", [2] = "SS5", [3] = "SS6", [4] = "SS9", [5] = "SSS1",
        [6] = "SSS2", [7] = "SSS3", [8] = "SSSSSS2", [9] = "SSSSSS9", [10] = "SSSSSSS1",
        [11] = "SSSSSSS3", [12] = "SSSSSSS5", [13] = "SSSSSSS6", [14] = "SSSSSSSS6", [15] = "SSSSSSSS7"
    },
    animalMap = {
        Axolotl = {id = "axolotl", anim = "axolotl_Anim"},
        BTrex = {id = "babydino", anim = "btrexAnim"},
        BabyCat = {id = "babycats", anim = "babycatAnim"},
        BabyElephant = {
            id = "baby_elephant", anim = "babyelephantAnim", gamepassPassId = 89053083,
            skinIdOverrides = {
                elephant1 = "elephant1", elephant2 = "elephant2", elephant3 = "elephant3",
                elephant4 = "elephant4", elephant5 = "elephant5", elephant6 = "elephant6",
                elephant7 = "elephant7", elephant8 = "elephant8", elephant9 = "elephant9",
                elephant10 = "elephant10", elephant11 = "elephant11", elephant12 = "elephant12",
                elephant13 = "elephant13", elephant14 = "elephant14", elephant15 = "elephant15",
                elephant16 = "elephant16", elephant17 = "elephant17", elephant18 = "elephant18",
                elephant19 = "elephant19", elephant20 = "elephant20", elephant21 = "elephant21",
                elephant22 = "elephant22", elephant23 = "elephant23", elephant24 = "gamepass24",
                elephant27 = "gamepass27", elephant28 = "gamepass28", elephant29 = "gamepass29",
                elephant30 = "gamepass30", elephant31 = "gamepass31"
            },
            animOverrides = {
                elephant24 = "babytankelephantAnim", elephant27 = "babytankelephantAnim",
                elephant28 = "babytankelephantAnim", elephant29 = "babytankelephantAnim",
                elephant30 = "babytankelephantAnim", elephant31 = "babytankelephantAnim"
            }
        },
        BabyKangaroo = {id = "baby_kangaroos", anim = "baby_kangarooAnim"},
        BabyLionRework = {
            id = "babylion_rework", anim = "babylionR_Anim", gamepassPassId = 121800750,
            skinIdOverrides = {
                lion1 = "babylion1", lion2 = "babylion2", lion3 = "babylion3", lion4 = "babylion4",
                lion5 = "babylion5", lion6 = "babylion6", lion7 = "babylion7", lion8 = "babylion8",
                lion9 = "babylion9", lion10 = "babylion10", lion11 = "babylion11", lion12 = "babylion12",
                lion13 = "babylion13", lion14 = "babylion14", lion15 = "babylion15", lion16 = "babylion16"
            },
            animOverrides = {
                gamepass17 = "babylionRWing_Anim", gamepass18 = "babylionRWing_Anim",
                gamepass21 = "babygriffin_Anim", gamepass22 = "babygriffin_Anim",
                gamepass23 = "babygriffin_Anim", gamepass24 = "babygriffin_Anim",
                gamepass25 = "babygriffin_Anim", gamepass26 = "babygriffin_Anim"
            }
        },
        BabyPenguin = {id = "baby_penguin", anim = "babypenguinAnim"},
        BabyWolf = {
            id = "baby_wolf", anim = "babywolf1Anim", gamepassPassId = 38950138,
            skinIdOverrides = {
                babywolf1 = "baby_wolf1", babywolf2 = "baby_wolf2", babywolf3 = "baby_wolf3",
                babywolf4 = "baby_wolf4", babywolf5 = "baby_wolf5", babywolf6 = "baby_wolf6",
                babywolf7 = "baby_wolf7", babywolf8 = "baby_wolf8", babywolf9 = "baby_wolf9",
                babywolf10 = "baby_wolf10", babywolf11 = "baby_wolf11", babywolf12 = "baby_wolf12",
                babywolf13 = "baby_wolf13", babywolf14 = "baby_wolf14", babywolf15 = "baby_wolf15",
                babywolf16 = "baby_wolf16", babywolf17 = "baby_wolf17", babywolf18 = "gamepass18",
                babywolf19 = "gamepass19", babywolf20 = "gamepass20", babywolf21 = "gamepass21",
                babywolf22 = "gamepass22", babywolf23 = "gamepass23", babywolf24 = "gamepass24"
            },
            animOverrides = {
                babywolf1 = "babywolf1Anim", babywolf2 = "babywolf1Anim", babywolf3 = "babywolf1Anim",
                babywolf4 = "babywolf1Anim", babywolf5 = "babywolf1Anim", babywolf6 = "babywolf1Anim",
                babywolf7 = "babywolf1Anim", babywolf8 = "babywolf1Anim", babywolf9 = "babywolf1Anim",
                babywolf10 = "babywolf1Anim", babywolf11 = "babywolf1Anim", babywolf12 = "babywolf1Anim",
                babywolf13 = "babywolf1Anim", babywolf14 = "babywolf1Anim", babywolf15 = "babywolf2Anim",
                babywolf16 = "babywolf2Anim", babywolf17 = "babywolf2Anim", babywolf18 = "babywolf3Anim",
                babywolf19 = "babywolf3Anim", babywolf20 = "babywolf3Anim", babywolf21 = "babywolf3Anim",
                babywolf22 = "babywolf3Anim", babywolf23 = "babywolf3Anim", babywolf24 = "babywolf3Anim"
            }
        },
        Bear = {id = "bears", anim = "bearAnim"},
        Capybara = {id = "capybara", anim = "capybaraAnim"},
        Cat = {id = "cats", anim = "catAnim"},
        Centaur = {id = "centaur", anim = "centaurAnim"},
        Chicken = {id = "chicken", anim = "chickenAnim"},
        Christmas2023 = {
            id = "christmas2023", anim = "newhorseAnim", gamepassPassId = 670590394,
            skinIdOverrides = {
                capybara = "capybara1", snake = "snake1", crocodile = "crocodile1", horse = "horse1",
                giraffe = "giraffe1", gamepass_horse = "gamepass_horse", gamepass_giraffe1 = "gamepass_giraffe1",
                gamepass_giraffe2 = "gamepass_giraffe2", gamepass_babywolf = "gamepass_babywolf",
                gamepass_wolf = "gamepass_wolf"
            },
            animOverrides = {
                capybara = "capybaraAnim", snake = "snakeAnim", crocodile = "crocodileAnim",
                horse = "newhorseAnim", giraffe = "giraffeAnim", gamepass_horse = "newhorseAnim",
                gamepass_giraffe1 = "christmasgiraffeAnim", gamepass_giraffe2 = "christmasgiraffeAnim",
                gamepass_babywolf = "babywolf1Anim", gamepass_wolf = "wolf1Anim"
            },
            tokenOverrides = {
                capybara = "XM23CP", snake = "XM23SN", crocodile = "XM23CR", horse = "XM23HR", giraffe = "XM23GR"
            }
        },
        Christmas2024 = {id = "christmas2024", anim = "newbear2Anim"},
        Cow = {id = "cows", anim = "cowAnim"},
        Crab = {id = "crab", anim = "crabAnim"},
        Crocodile = {id = "crocodile", anim = "crocodileAnim"},
        Dragon = {id = "dragons", anim = "dragonAnim"},
        Eagle = {id = "eagle", anim = "eagleAnim"},
        Elephant = {id = "elephant", anim = "elephantAnim"},
        Fox = {id = "fox", anim = "foxAnim"},
        Frog = {id = "frog", anim = "frogAnim"},
        Giraffe = {id = "giraffe", anim = "giraffeAnim"},
        Gorilla = {id = "gorilla", anim = "gorillaAnim"},
        Halloween2023 = {
            id = "halloween2023", anim = "newhorseAnim", gamepassPassId = 270811024,
            animOverrides = {
                horse = "newhorseAnim", capybara = "capybaraAnim", crocodile = "crocodileAnim",
                monkey = "halloweenmonkeyAnim", dragon = "dragonAnim", snake = "snakeAnim",
                gamepass_lion = "reworklion_Anim", gamepass_lioness = "reworklion_Anim",
                gamepass_babylion = "babylionR_Anim", gamepass_dragon = "dragonAnim",
                gamepass_monkey = "halloweenmonkeyAnim", gamepass_horse = "newhorseAnim"
            },
            tokenOverrides = {
                horse = "H23HR", capybara = "H23CP", crocodile = "H23CR", monkey = "H23MK",
                dragon = "H23DR", snake = "H23SN"
            }
        },
        Horse = {id = "horse", anim = "horseAnim"},
        Husky = {id = "husky", anim = "huskyAnim"},
        Hyena = {id = "hyena", anim = "hyenaAnim"},
        Kangaroo = {id = "kangaroos", anim = "kangarooAnim"},
        Komodo = {id = "komodo", anim = "komodoAnim"},
        LionRework = {id = "lion_rework", anim = "reworklion_Anim"},
        LionessRework = {id = "lioness_rework", anim = "reworklion_Anim"},
        Mantis = {id = "mantis", anim = "mantisAnim"},
        Monkey = {id = "monkey", anim = "monkeyAnim"},
        NewBear = {id = "newbears", anim = "newbearAnim"},
        NewDeer = {id = "newdeer", anim = "newdeerAnim"},
        NewHorse = {id = "newhorse", anim = "newhorseAnim"},
        Old = {
            id = "old", anim = "lionAnim",
            animOverrides = {
                mysticpanther = "lionessAnim", greywolf = "wolfAnim", brownlion = "lionAnim",
                brownlioness = "lionessAnim", baby_brownlion = "babylionAnim", brown_cerberus = "cerberusAnim",
                jaguar = "lionessAnim", mysticlion = "lionAnim", mysticwolf = "wolfAnim", blackpanther = "lionessAnim"
            }
        },
        Penguin = {
            id = "penguin", anim = "penguinAnim",
            skinIdOverrides = {
                police2 = "police1_penguin", police1 = "police2_penguin",
                yellow_samuraipenguin = "gamepass1", red_samuraipenguin = "gamepass2", blue_samuraipenguin = "gamepass3"
            },
            animOverrides = {
                gamepass1 = "premPenguinAnim", gamepass2 = "premPenguinAnim", gamepass3 = "premPenguinAnim"
            }
        },
        Pig = {
            id = "pigs", anim = "pigAnim",
            animOverrides = {
                babypig1 = "babypigAnim", babypig2 = "babypigAnim", babypig3 = "babypigAnim",
                gamepass1 = "pig2Anim", gamepass2 = "pig2Anim", gamepass3 = "pig2Anim", gamepass4 = "pig2Anim"
            }
        },
        Rabbit = {
            id = "rabbit", anim = "rabbitAnim",
            skinIdOverrides = {
                anime_rabbit = "gamepass1", police_rabbit = "gamepass2", white_rabbit = "gamepass3"
            },
            animOverrides = {
                gamepass1 = "premRabbitAnim", gamepass2 = "premRabbitAnim", gamepass3 = "premRabbitAnim"
            }
        },
        Rhino = {id = "rhino", anim = "rhinoAnim"},
        Skeleton = {
            id = "skeletons", anim = "skeleton_deerAnim",
            animOverrides = {
                deer_1 = "skeleton_deerAnim", rhino_1 = "skeleton_rhinoAnim", trex_1 = "skeleton_trexAnim",
                wolf_1 = "skeleton_wolfAnim", gamepass_deer2 = "skeleton_deerAnim", gamepass_deer3 = "skeleton_deerAnim",
                gamepass_rhino2 = "skeleton_rhinoAnim", gamepass_rhino3 = "skeleton_rhinoAnim",
                gamepass_trex2 = "skeleton_trexAnim", gamepass_trex3 = "skeleton_trexAnim",
                gamepass_wolf2 = "skeleton_wolfAnim", gamepass_wolf3 = "skeleton_wolfAnim"
            }
        },
        Snake = {
            id = "snakes", anim = "snakeAnim",
            animOverrides = {
                gamepass1 = "snakeAnim2", gamepass2 = "snakeAnim2", gamepass3 = "snakeAnim2",
                gamepass4 = "snakeAnim2", gamepass5 = "snakeAnim2"
            }
        },
        Spider = {id = "spider", anim = "spiderAnim"},
        Squirrel = {
            id = "squirrel", anim = "squirrelAnim",
            animOverrides = {
                gamepass1 = "squirrel2Anim", gamepass2 = "squirrel2Anim", gamepass3 = "squirrel2Anim",
                gamepass4 = "squirrel2Anim", gamepass5 = "squirrel2Anim"
            }
        },
        Tiger = {
            id = "tiger", anim = "tigerAnim",
            animOverrides = {
                circle_grey = "babytigerAnim", orange_babytiger = "babytigerAnim",
                white_babytiger = "babytigerAnim", stripe_grey = "babytigerAnim",
                orange_tiger = "tigerAnim", white_tiger = "tigerAnim", grey_tiger = "tigerAnim"
            }
        },
        Trex = {id = "trex", anim = "trexAnim"},
        Wolf = {
            id = "wolves", anim = "wolfAnim",
            animOverrides = {
                wolf1 = "wolf1Anim", wolf2 = "wolf2Anim", wolf3 = "wolf3Anim", wolf4 = "wolf4Anim",
                wolf5 = "wolf5Anim", wolf6 = "wolf6Anim", wolf7 = "wolf7Anim", wolf8 = "wolf8Anim",
                wolf9 = "wolf9Anim", wolf10 = "wolf10Anim", wolf11 = "wolf11Anim", wolf12 = "wolf12Anim",
                wolf13 = "wolf13Anim", wolf14 = "wolf14Anim", wolf15 = "wolf15Anim", wolf16 = "wolf16Anim",
                wolf17 = "wolf17Anim", wolf18 = "wolf18Anim", wolf19 = "wolf19Anim", wolf20 = "wolf20Anim",
                wolf21 = "wolf21Anim", wolf22 = "wolf22Anim", wolf23 = "wolf23Anim", wolf24 = "wolf3Anim"
            }
        }
    }
}

local premiumServices = {
    SpawnEvent = ReplicatedStorage:WaitForChild("Events"):WaitForChild("SpawnEvent"),
    PlotSystemRE = ReplicatedStorage:WaitForChild("PlotSystemRE"),
    WeaponEvent = ReplicatedStorage:WaitForChild("Events"):WaitForChild("WeaponEvent"),
    MarketplaceService = game:GetService("MarketplaceService")
}

local function getSpawnArgs(animalName, skinName)
    if not animalName then
        return nil, "animalName is nil"
    end
    
    if not premiumConfig.animalMap then
        return nil, "animalMap table is nil"
    end
    
    local animalConfig = premiumConfig.animalMap[animalName]
    
    if not animalConfig then
        for key, value in pairs(premiumConfig.animalMap) do
            if string.lower(key) == string.lower(animalName) then
                animalConfig = value
                break
            end
        end
    end
    
    if not animalConfig then
        return nil, "Animal not found in configuration"
    end
    
    local skinId = skinName
    local anim = animalConfig.anim
    
    if animalConfig.skinIdOverrides and animalConfig.skinIdOverrides[skinName] then
        skinId = animalConfig.skinIdOverrides[skinName]
    end
    
    if animalConfig.animOverrides and animalConfig.animOverrides[skinName] then
        anim = animalConfig.animOverrides[skinName]
    end
    
    return {animalConfig.id, skinId, anim}, nil
end

local function handleAnimalClick(animalName, skinName, asGodmode)
    if not animalName then return end
    
    premiumConfig.lastClickedAnimal = animalName
    premiumConfig.lastClickedSkin = skinName or animalName
    
    if asGodmode then
        sendNotification("Starting Godmode", "Auto-starting godmode with: " .. animalName .. (skinName and " (" .. skinName .. ")" or ""), 2)
        
        local spawnArgs, error = getSpawnArgs(animalName, skinName)
        
        if spawnArgs then
            local savedPos = getPlayerRoot() and getPlayerRoot().Position or nil
            local plotArgs = {"buyPlot", "2"}
            local targetPos = Vector3.new(146, 643, 427)
            
            sendNotification("Godmode", "Target: " .. animalName .. " | Args: " .. table.concat(spawnArgs, ", "), 2)
            sendNotification("Godmode", "Started", 2)
            
            if hasValidCharacter(LocalPlayer) then 
                LocalPlayer.Character:FindFirstChildOfClass("Humanoid").Health = 0 
            end
            
            local active = true
            task.spawn(function()
                local hrp = nil
                local function fireBoth() 
                    pcall(function() 
                        premiumServices.SpawnEvent:FireServer(table.unpack(spawnArgs)) 
                        premiumServices.PlotSystemRE:FireServer(table.unpack(plotArgs)) 
                    end) 
                end
                
                if hasValidCharacter(LocalPlayer) then 
                    LocalPlayer.Character:FindFirstChildOfClass("Humanoid").Health = 0 
                end
                
                local close = false
                local phase1 = false
                
                while active and not phase1 do
                    local char = LocalPlayer.Character
                    hrp = char and char:FindFirstChild("HumanoidRootPart")
                    if hrp then 
                        local d = (hrp.Position - targetPos).Magnitude 
                        if d < 5 then 
                            close = true 
                            phase1 = true 
                        else 
                            fireBoth() 
                        end 
                    end
                    task.wait(0.05)
                end
                
                if active and close then
                    local s = tick()
                    while active and (tick() - s) < 2 do 
                        pcall(function() 
                            premiumServices.PlotSystemRE:FireServer(table.unpack(plotArgs)) 
                        end) 
                        task.wait(0.1) 
                    end
                end
                
                if active and close then
                    hrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
                    if hrp then 
                        local fd = (hrp.Position - targetPos).Magnitude 
                        if fd < 10 and savedPos then 
                            task.wait(1) 
                            hrp.CFrame = CFrame.new(savedPos) 
                        else 
                            sendNotification("Godmode", "Failed: " .. math.floor(fd), 2)
                        end 
                    end
                end
                
                active = false
                sendNotification("Godmode", "Stopped", 2)
            end)
        else
            sendNotification("Error", "Could not get spawn args for: " .. animalName .. " - " .. (error or "Unknown error"), 2)
        end
    else
        sendNotification("Animal Selected", "Selected: " .. animalName .. (skinName and " (" .. skinName .. ")" or ""), 2)
    end
end

Tabs.Premium:Paragraph({
    Title = "How to use",
    Desc = "IMPORTANT: You have to be out of safezone for these to work, if you enter the safe zone it will also stop working"
})

local godmodeToggle = false

Tabs.Premium:Toggle({
    Title = "Godmode Mode",
    Desc = "Toggle ON and spawn as an animal for godmode",
    Value = false,
    Callback = function(state)
        godmodeToggle = state
        sendNotification("Mode Changed", state and "Now in Godmode Mode - Click animals to select for godmode" or "Now in Regular Spawn Mode - Click animals to spawn them normally", 2)
    end
})

task.defer(function()
    if setupAnimalDetection then setupAnimalDetection() end
end)

Tabs.Premium:Button({
    Title = "Godmode Last Selected Animal",
    Desc = "Spawns you as godmode as your last selected animal",
    Callback = function()
        if not premiumConfig.lastClickedAnimal then
            sendNotification("Error", "Please click on an animal first to select it for godmode!", 3)
            return
        end
        
        local savedPos = getPlayerRoot() and getPlayerRoot().Position or nil
        local spawnArgs, errorMsg = getSpawnArgs(premiumConfig.lastClickedAnimal, premiumConfig.lastClickedSkin)
        
        if not spawnArgs then
            sendNotification("Error", "Failed to get spawn arguments: " .. errorMsg, 3)
            return
        end
        
        sendNotification("Godmode", "Target: " .. premiumConfig.lastClickedAnimal .. " | Args: " .. table.concat(spawnArgs, ", "), 2)
        
        local plotArgs = {"buyPlot", "2"}
        local targetPos = Vector3.new(146, 643, 427)
        
        sendNotification("Godmode", "Started", 2)
        
        if hasValidCharacter(LocalPlayer) then 
            LocalPlayer.Character:FindFirstChildOfClass("Humanoid").Health = 0 
        end
        
        local active = true
        task.spawn(function()
            local hrp = nil
            local function fireBoth() 
                pcall(function() 
                    premiumServices.SpawnEvent:FireServer(table.unpack(spawnArgs)) 
                    premiumServices.PlotSystemRE:FireServer(table.unpack(plotArgs)) 
                end) 
            end
            
            if hasValidCharacter(LocalPlayer) then 
                LocalPlayer.Character:FindFirstChildOfClass("Humanoid").Health = 0 
            end
            
            local close = false
            local phase1 = false
            
            while active and not phase1 do
                local char = LocalPlayer.Character
                hrp = char and char:FindFirstChild("HumanoidRootPart")
                if hrp then 
                    local d = (hrp.Position - targetPos).Magnitude 
                    if d < 5 then 
                        close = true 
                        phase1 = true 
                    else 
                        fireBoth() 
                    end 
                end
                task.wait(0.05)
            end
            
            if active and close then
                local s = tick()
                while active and (tick() - s) < 2 do 
                    pcall(function() 
                        premiumServices.PlotSystemRE:FireServer(table.unpack(plotArgs)) 
                    end) 
                    task.wait(0.1) 
                end
            end
            
            if active and close then
                hrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
                if hrp then 
                    local fd = (hrp.Position - targetPos).Magnitude 
                    if fd < 10 and savedPos then 
                        task.wait(1) 
                        hrp.CFrame = CFrame.new(savedPos) 
                    else 
                        sendNotification("Godmode", "Failed: " .. math.floor(fd), 2)
                    end 
                end
            end
            
            active = false
            sendNotification("Godmode", "Stopped", 2)
        end)
    end
})

Tabs.Premium:Button({
    Title = "Player God Mode",
    Desc = "Click to become godmode as your player",
    Callback = function()
        local savedPos = getPlayerRoot() and getPlayerRoot().Position or nil
        
        local spawnArgs = {"monkey", "monke", "monkeyAnim"}
        
        sendNotification("Player God Mode", "Target: Player | Args: " .. table.concat(spawnArgs, ", "), 2)
        
        local plotArgs = {"buyPlot", "2"}
        local targetPos = Vector3.new(146, 643, 427)
        
        sendNotification("Player God Mode", "Started", 2)
        
        if hasValidCharacter(LocalPlayer) then 
            LocalPlayer.Character:FindFirstChildOfClass("Humanoid").Health = 0 
        end
        
        local active = true
        task.spawn(function()
            local hrp = nil
            
            while active do
                local char = LocalPlayer.Character
                hrp = char and char:FindFirstChild("HumanoidRootPart")
                pcall(function() 
                    premiumServices.SpawnEvent:FireServer(table.unpack(spawnArgs)) 
                    premiumServices.PlotSystemRE:FireServer(table.unpack(plotArgs)) 
                end)
                if hrp and targetPos and (hrp.Position - targetPos).Magnitude < 1 then 
                    break 
                end
                task.wait()
            end
            
            if active and hrp and savedPos then 
                task.wait(1) 
                hrp.CFrame = CFrame.new(savedPos) 
                sendNotification("Player God Mode", "Returned", 2)
            end
            
            active = false
            sendNotification("Player God Mode", "Stopped", 2)
        end)
    end
})

Tabs.Premium:Section({ Title = "Robux Weapons" })

local selectedIndex = 1
local indexToCode = {
    [1] = "SS4",
    [2] = "SS5",
    [3] = "SS6",
    [4] = "SS9",
    [5] = "SSS1",
    [6] = "SSS2",
    [7] = "SSS3",
    [8] = "SSSSSS2",
    [9] = "SSSSSS9",
    [10] = "SSSSSSS1",
    [11] = "SSSSSSS3",
    [12] = "SSSSSSS5",
    [13] = "SSSSSSS6",
    [14] = "SSSSSSSS6",
    [15] = "SSSSSSSS7",
}

Tabs.Premium:Dropdown({
    Title = "Robux Weapons",
    Desc = "Choose a weapon index",
    Values = {"1","2","3","4","5","6","7","8","9","10","11","12","13","14","15"},
    Multi = false,
    Default = "1",
    Callback = function(v)
        selectedIndex = tonumber(v) or 1
    end
})

Tabs.Premium:Section({ Title = "Instructions" })
Tabs.Premium:Paragraph({
    Title = "How to use",
    Desc = "Select a sword to use and click the button to equip any robux sword without spending 1 cent. This feature is in testing and will be updated to support every animal simulator update."
})

Tabs.Premium:Button({
    Title = "Use Weapon",
    Desc = "Equip and apply selected weapon",
    Callback = function()
        local code = indexToCode[selectedIndex]
        if not code then
            return
        end
        local args = { code }
        pcall(function()
            ReplicatedStorage:WaitForChild('Events'):WaitForChild('WeaponEvent'):FireServer(table.unpack(args))
        end)
        
        local function ownsPass(player, passId)
            if RunService:IsStudio() then
                return true
            end
            local ok, owns = pcall(MarketplaceService.UserOwnsGamePassAsync, MarketplaceService, player.UserId, passId)
            return ok and owns
        end
        ownsPass(LocalPlayer, 0)
        
        local c = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
        local h = c:FindFirstChildOfClass('Humanoid')
        if h then
            h.Health = 0
        end
        
        sendNotification("Robux Weapons", "Weapon " .. selectedIndex .. " equipped successfully!", 2)
    end
})

local function setupAnimalDetection()
    local function wireSpecies(folder)
        task.spawn(function()
            for _, skin in ipairs(folder:GetChildren()) do
                local frame = skin:FindFirstChild("Frame")
                if frame then
                    local button = frame:FindFirstChild("Button")
                    if button then
                        pcall(function()
                            if getconnections then
                                for _, connection in pairs(getconnections(button.MouseButton1Click)) do
                                    connection:Disconnect()
                                end
                            end
                        end)
                        
                        button.MouseButton1Click:Connect(function()
                            pcall(function()
                                if godmodeToggle then
                                handleAnimalClick(folder.Name, skin.Name, true)
                                else
                                    local animalConfig = premiumConfig.animalMap[folder.Name]
                                    if animalConfig then
                                        local skinId = skin.Name
                                        local anim = animalConfig.anim
                                        
                                        if animalConfig.skinIdOverrides and animalConfig.skinIdOverrides[skin.Name] then
                                            skinId = animalConfig.skinIdOverrides[skin.Name]
                                        end
                                        
                                        if animalConfig.animOverrides and animalConfig.animOverrides[skin.Name] then
                                            anim = animalConfig.animOverrides[skin.Name]
                                        end
                                        
                                        premiumServices.SpawnEvent:FireServer(animalConfig.id, skinId, anim)
                                        sendNotification("Animal Spawned", "Spawned " .. folder.Name .. " successfully", 2)
                                    end
                                end
                            end)
                        end)
                    end
                end
                task.wait(0.01)
            end
        end)
        
        folder.ChildAdded:Connect(function(child)
            task.spawn(function()
                task.wait(0.2)
                local frame = child:FindFirstChild("Frame")
                if frame then
                    local button = frame:FindFirstChild("Button")
                    if button then
                        button.MouseButton1Click:Connect(function()
                            pcall(function()
                                if godmodeToggle then
                                    handleAnimalClick(folder.Name, child.Name, true)
                                else
                                    local animalConfig = premiumConfig.animalMap[folder.Name]
                                    if animalConfig then
                                        local skinId = child.Name
                                        local anim = animalConfig.anim
                                        
                                        if animalConfig.skinIdOverrides and animalConfig.skinIdOverrides[child.Name] then
                                            skinId = animalConfig.skinIdOverrides[child.Name]
                                        end
                                        
                                        if animalConfig.animOverrides and animalConfig.animOverrides[child.Name] then
                                            anim = animalConfig.animOverrides[child.Name]
                                        end
                                        
                                        premiumServices.SpawnEvent:FireServer(animalConfig.id, skinId, anim)
                                        sendNotification("Animal Spawned", "Spawned " .. folder.Name .. " successfully", 2)
                                    end
                                end
                            end)
                        end)
                    end
                end
            end)
        end)
    end
    
    local function asyncSetup()
        local success, gui = pcall(function()
            local playerGui = LocalPlayer:WaitForChild("PlayerGui", 1)
            if not playerGui then return nil end
            
            local animalsGui = playerGui:WaitForChild("AnimalsGUI", 1)
            if not animalsGui then return nil end
            
            local windowFrame = animalsGui:WaitForChild("windowFrame", 1)
            if not windowFrame then return nil end
            
            local bodyFrame = windowFrame:WaitForChild("bodyFrame", 1)
            if not bodyFrame then return nil end
            
            local body2Frame = bodyFrame:WaitForChild("body2Frame", 1)
            if not body2Frame then return nil end
            
            local animals = body2Frame:WaitForChild("Animals", 1)
            if not animals then return nil end
            
            return animals
        end)
        
        if success and gui then
            task.spawn(function()
                for _, spec in ipairs(gui:GetChildren()) do
                    wireSpecies(spec)
                    task.wait(0.05)
                end
                
                gui.ChildAdded:Connect(wireSpecies)
            end)
            
            return true
        else
            return false
        end
    end
    
    local attempts = 0
    local maxAttempts = 3
    
    local function tryNext()
        if attempts >= maxAttempts then
            return
        end
        
        attempts = attempts + 1
        if asyncSetup() then
            return
        else
            task.wait(2)
            tryNext()
        end
    end
    
    tryNext()
end

Tabs.Premium:Section({ Title = "Robux Weapons" })

Tabs.Premium:Dropdown({
    Title = "Robux Weapons",
    Desc = "Choose a weapon index",
    Values = {"1","2","3","4","5","6","7","8","9","10","11","12","13","14","15"},
    Multi = false,
    Default = "1",
    Callback = function(v)
        premiumConfig.selectedWeaponIndex = tonumber(v) or 1
    end
})

Tabs.Premium:Section({ Title = "Instructions" })
Tabs.Premium:Paragraph({
    Title = "How to use",
    Desc = "Select a sword to use and click the button to equip any robux sword without spending 1 cent. This feature is in testing and will be updated to support every animal simulator update."
})

Tabs.Premium:Button({
    Title = "Use Weapon",
    Desc = "Equip and apply selected weapon",
    Callback = function()
        local code = premiumConfig.weaponCodes[premiumConfig.selectedWeaponIndex]
        if not code then return end
        
        local args = { code }
        pcall(function()
            premiumServices.WeaponEvent:FireServer(table.unpack(args))
        end)
        
        local function ownsPass(player, passId)
            if RunService:IsStudio() then return true end
            local ok, owns = pcall(premiumServices.MarketplaceService.UserOwnsGamePassAsync, premiumServices.MarketplaceService, player.UserId, passId)
            return ok and owns
        end
        
        ownsPass(LocalPlayer, 0)
        
        if hasValidCharacter(LocalPlayer) then
            LocalPlayer.Character:FindFirstChildOfClass("Humanoid").Health = 0
        end
        
        sendNotification("Weapons", "Applied weapon: "..tostring(code), 2)
    end
})

Tabs.Premium:Section({ Title = "NPC Flinger" })

local npcFlingerConfig = {
    selectedNPC = nil,
    selectedPlayer = nil,
    hiddenfling = false,
    walkflingConnection = nil,
    deathConnection = nil,
    nameToModel = {},
    playerToModel = {}
}

local function npcRoot(m)
    if not m or not m:IsA("Model") then return nil end
    local hrp = m:FindFirstChild("HumanoidRootPart")
    if hrp and hrp:IsA("BasePart") then return hrp end
    if m.PrimaryPart then return m.PrimaryPart end
    for _,d in ipairs(m:GetDescendants()) do
        if d:IsA("BasePart") then return d end
    end
end

local function collectNPCNames()
    for k in pairs(npcFlingerConfig.nameToModel) do
        npcFlingerConfig.nameToModel[k] = nil
    end
    local out = {}
    
    local NPC_FOLDER = workspace:FindFirstChild("NPC")
    if not NPC_FOLDER then 
        sendNotification("NPC Flinger", "NPC folder not found in workspace!", 3)
        return out 
    end
    
    local count = 0
    for _,child in ipairs(NPC_FOLDER:GetChildren()) do
        if child:IsA("Model") and npcRoot(child) then
            npcFlingerConfig.nameToModel[child.Name] = child
            out[#out+1] = child.Name
            count = count + 1
        end
    end
    
    table.sort(out)
    sendNotification("NPC Flinger", "Found " .. count .. " NPCs", 2)
    return out
end

local function collectPlayerNames()
    for k in pairs(npcFlingerConfig.playerToModel) do
        npcFlingerConfig.playerToModel[k] = nil
    end
    local out = {}
    
    local count = 0
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character then
            npcFlingerConfig.playerToModel[player.Name] = player
            out[#out+1] = player.Name
            count = count + 1
        end
    end
    
    table.sort(out)
    sendNotification("NPC Flinger", "Found " .. count .. " players", 2)
    return out
end

local function controlNPCsExact(npcModel)
    local char = LocalPlayer.Character
    if not char then return end
    local npcRootPart = npcModel:FindFirstChild("HumanoidRootPart")
    local PlayerCharacter = char
    local PlayerRootPart = char:FindFirstChild("HumanoidRootPart")
    
    if not npcRootPart or not PlayerRootPart then 
        sendNotification("NPC Flinger", "Error: Missing HumanoidRootPart", 3)
        return 
    end
    
    local A0 = Instance.new("Attachment")
    local AP = Instance.new("AlignPosition")
    local AO = Instance.new("AlignOrientation")
    local A1 = Instance.new("Attachment")
    
    local collisionConnections = {}
    for _, v in pairs(npcModel:GetDescendants()) do
        if v:IsA("BasePart") then
            local connection = RunService.Stepped:Connect(function()
                v.CanCollide = false
                v.Transparency = 0.5
                v.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
                v.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
            end)
            table.insert(collisionConnections, connection)
        end
    end
    
    PlayerRootPart:BreakJoints()
    
    for _, v in pairs(PlayerCharacter:GetDescendants()) do
        if v:IsA("BasePart") then
            if v.Name == "HumanoidRootPart" or v.Name == "UpperTorso" or v.Name == "Head" then
            else
                v:Destroy()
            end
        end
    end
    
    PlayerRootPart.Position = PlayerRootPart.Position + Vector3.new(5, 0, 0)
    
    if PlayerCharacter:FindFirstChild("Head") then
        PlayerCharacter.Head.Anchored = true
    end
    if PlayerCharacter:FindFirstChild("UpperTorso") then
        PlayerCharacter.UpperTorso.Anchored = true
    end
    
    A0.Parent = npcRootPart
    AP.Parent = npcRootPart
    AO.Parent = npcRootPart
    
    AP.Responsiveness = 200
    AP.MaxForce = math.huge
    AP.RigidityEnabled = true
    AO.MaxTorque = math.huge
    AO.Responsiveness = 200
    AO.RigidityEnabled = true
    
    AP.Attachment0 = A0
    AP.Attachment1 = A1
    AO.Attachment1 = A1
    AO.Attachment0 = A0
    
    A1.Parent = PlayerRootPart
    
    local stabilizationConnection = RunService.Heartbeat:Connect(function()
        if npcRootPart and PlayerRootPart and A1 and A1.Parent == PlayerRootPart then
            local distance = (npcRootPart.Position - PlayerRootPart.Position).Magnitude
            if distance > 10 then
                npcRootPart.CFrame = PlayerRootPart.CFrame * CFrame.new(0, 0, -2)
            end
        end
    end)
end

local function npcSkidFling(targetPlayer, controlledNPC)
    if not targetPlayer or not targetPlayer.Character then
        sendNotification("NPC Flinger", "NPC SkidFling error: Invalid target player", 3)
        return false
    end
    if not controlledNPC then
        sendNotification("NPC Flinger", "NPC SkidFling error: No controlled NPC", 3)
        return false
    end
    
    local TChar = targetPlayer.Character
    local THumanoid = TChar:FindFirstChildOfClass("Humanoid")
    local TRootPart = THumanoid and THumanoid.RootPart
    local THead = TChar:FindFirstChild("Head")
    local Accessory = TChar:FindFirstChildOfClass("Accessory")
    local Handle = Accessory and Accessory:FindFirstChild("Handle")
    
    local npcHRP = controlledNPC:FindFirstChild("HumanoidRootPart")
    local npcHumanoid = controlledNPC:FindFirstChildOfClass("Humanoid")
    if not (npcHRP and npcHumanoid) then
        sendNotification("NPC Flinger", "NPC SkidFling error: NPC missing HRP or Humanoid", 3)
        return false
    end
    
    local originalNPCPos = npcHRP.CFrame
    
    if not getgenv().FPDH then
        getgenv().FPDH = workspace.FallenPartsDestroyHeight or 500
    end
    
    local cam = workspace.CurrentCamera
    if THead then
        cam.CameraSubject = THead
    elseif Handle then
        cam.CameraSubject = Handle
    elseif THumanoid then
        cam.CameraSubject = THumanoid
    end
    
    local originalFPDH = workspace.FallenPartsDestroyHeight
    workspace.FallenPartsDestroyHeight = 0/0
    
    local BV = Instance.new("BodyVelocity")
    BV.Name = "EpixVel"
    BV.Velocity = Vector3.new(9e8, 9e8, 9e8)
    BV.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
    BV.Parent = npcHRP
    
    npcHumanoid:SetStateEnabled(Enum.HumanoidStateType.Seated, false)
    
    local function _npcSetCF(controlledNPC, hrp, cf)
        if hrp then hrp.CFrame = cf end
        if controlledNPC and controlledNPC.PrimaryPart then
            controlledNPC:SetPrimaryPartCFrame(cf)
        end
    end
    
    local function NPCFPos(BasePart, Pos, Ang)
        local cf = CFrame.new(BasePart.Position) * Pos * Ang
        _npcSetCF(controlledNPC, npcHRP, cf)
    end
    
    local function NPCSFBasePart(BasePart)
        local TimeToWait = 2
        local Time = tick()
        local Angle = 0
        local flingStarted = false
        
        repeat
            if npcHRP and THumanoid then
                if BasePart.Velocity.Magnitude < 50 then
                    Angle = Angle + 100
                    NPCFPos(BasePart, CFrame.new(0, 1.5, 0) + THumanoid.MoveDirection * BasePart.Velocity.Magnitude / 1.25, CFrame.Angles(math.rad(Angle), 0, 0)); wait()
                    NPCFPos(BasePart, CFrame.new(0, -1.5, 0) + THumanoid.MoveDirection * BasePart.Velocity.Magnitude / 1.25, CFrame.Angles(math.rad(Angle), 0, 0)); wait()
                    NPCFPos(BasePart, CFrame.new(2.25, 1.5, -2.25) + THumanoid.MoveDirection * BasePart.Velocity.Magnitude / 1.25, CFrame.Angles(math.rad(Angle), 0, 0)); wait()
                    NPCFPos(BasePart, CFrame.new(-2.25, -1.5, 2.25) + THumanoid.MoveDirection * BasePart.Velocity.Magnitude / 1.25, CFrame.Angles(math.rad(Angle), 0, 0)); wait()
                    NPCFPos(BasePart, CFrame.new(0, 1.5, 0) + THumanoid.MoveDirection, CFrame.Angles(math.rad(Angle), 0, 0)); wait()
                    NPCFPos(BasePart, CFrame.new(0, -1.5, 0) + THumanoid.MoveDirection, CFrame.Angles(math.rad(Angle), 0, 0)); wait()
                else
                    flingStarted = true
                    NPCFPos(BasePart, CFrame.new(0, 1.5, THumanoid.WalkSpeed), CFrame.Angles(math.rad(90), 0, 0)); wait()
                    NPCFPos(BasePart, CFrame.new(0, -1.5, -THumanoid.WalkSpeed), CFrame.Angles(0, 0, 0)); wait()
                    NPCFPos(BasePart, CFrame.new(0, 1.5, THumanoid.WalkSpeed), CFrame.Angles(math.rad(90), 0, 0)); wait()
                    NPCFPos(BasePart, CFrame.new(0, 1.5, TRootPart and TRootPart.Velocity.Magnitude / 1.25 or 0), CFrame.Angles(math.rad(90), 0, 0)); wait()
                    NPCFPos(BasePart, CFrame.new(0, -1.5, -(TRootPart and TRootPart.Velocity.Magnitude / 1.25 or 0)), CFrame.Angles(0, 0, 0)); wait()
                    NPCFPos(BasePart, CFrame.new(0, 1.5, TRootPart and TRootPart.Velocity.Magnitude / 1.25 or 0), CFrame.Angles(math.rad(90), 0, 0)); wait()
                    NPCFPos(BasePart, CFrame.new(0, -1.5, 0), CFrame.Angles(math.rad(90), 0, 0)); wait()
                    NPCFPos(BasePart, CFrame.new(0, -1.5, 0), CFrame.Angles(0, 0, 0)); wait()
                    NPCFPos(BasePart, CFrame.new(0, -1.5, 0), CFrame.Angles(math.rad(-90), 0, 0)); wait()
                    NPCFPos(BasePart, CFrame.new(0, -1.5, 0), CFrame.Angles(0, 0, 0)); wait()
                    
                    if flingStarted then
                        _npcSetCF(controlledNPC, npcHRP, originalNPCPos)
                        break
                    end
                end
            else
                break
            end
        until BasePart.Velocity.Magnitude > 500
            or BasePart.Parent ~= targetPlayer.Character
            or targetPlayer.Parent ~= Players
            or not (targetPlayer.Character == TChar)
            or (THumanoid and THumanoid.Sit)
            or npcHumanoid.Health <= 0
            or tick() > Time + TimeToWait
            or flingStarted
    end
    
    if TRootPart and THead then
        if (TRootPart.CFrame.p - THead.CFrame.p).Magnitude > 5 then
            NPCSFBasePart(THead)
        else
            NPCSFBasePart(TRootPart)
        end
    elseif TRootPart then
        NPCSFBasePart(TRootPart)
    elseif THead then
        NPCSFBasePart(THead)
    elseif Handle then
        NPCSFBasePart(Handle)
    end
    
    _npcSetCF(controlledNPC, npcHRP, originalNPCPos)
    if npcHRP then
        npcHRP.Velocity = Vector3.new(0, 0, 0)
        npcHRP.RotVelocity = Vector3.new(0, 0, 0)
    end
    
    BV:Destroy()
    npcHumanoid:SetStateEnabled(Enum.HumanoidStateType.Seated, true)
    local myHum = (LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid"))
    if myHum then workspace.CurrentCamera.CameraSubject = myHum end
    
    repeat
        _npcSetCF(controlledNPC, npcHRP, originalNPCPos * CFrame.new(0, 0.5, 0))
        npcHumanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
        for _, x in ipairs(controlledNPC:GetChildren()) do
            if x:IsA("BasePart") then
                x.Velocity = Vector3.new()
                x.RotVelocity = Vector3.new()
            end
        end
        wait()
    until (npcHRP.Position - originalNPCPos.p).Magnitude < 25
    
    workspace.FallenPartsDestroyHeight = getgenv().FPDH or originalFPDH or 500
    
    local hum = controlledNPC:FindFirstChildOfClass("Humanoid")
    if hum then
        for _, part in ipairs(controlledNPC:GetDescendants()) do
            if part:IsA("BasePart") then part:BreakJoints() end
        end
        hum.Health = 0
    end
    
    sendNotification("NPC Flinger", "NPC SkidFling complete on " .. targetPlayer.Name, 2)
    return true
end

local function startWalkfling()
    if npcFlingerConfig.hiddenfling then return end
    
    npcFlingerConfig.hiddenfling = true
    
    if not ReplicatedStorage:FindFirstChild("juisdfj0i32i0eidsuf0iok") then
        local detection = Instance.new("Decal")
        detection.Name = "juisdfj0i32i0eidsuf0iok"
        detection.Parent = ReplicatedStorage
    end
    
    if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Humanoid") then
        npcFlingerConfig.deathConnection = LocalPlayer.Character.Humanoid.Died:Connect(function()
            npcFlingerConfig.hiddenfling = false
        end)
    end
    
    local function fling()
        local hrp, c, vel, movel = nil, nil, nil, 0.1
        while true do
            RunService.Heartbeat:Wait()
            if npcFlingerConfig.hiddenfling then
                local lp = LocalPlayer
                while npcFlingerConfig.hiddenfling and not (c and c.Parent and hrp and hrp.Parent) do
                    RunService.Heartbeat:Wait()
                    c = lp.Character
                    hrp = c:FindFirstChild("HumanoidRootPart") or c:FindFirstChild("Torso") or c:FindFirstChild("UpperTorso")
                end
                if npcFlingerConfig.hiddenfling then
                    vel = hrp.Velocity
                    hrp.Velocity = vel * 10000 + Vector3.new(0, 10000, 0)
                    RunService.RenderStepped:Wait()
                    if c and c.Parent and hrp and hrp.Parent then
                        hrp.Velocity = vel
                    end
                    RunService.Stepped:Wait()
                    if c and c.Parent and hrp and hrp.Parent then
                        hrp.Velocity = vel + Vector3.new(0, movel, 0)
                        movel = movel * -1
                    end
                end
            end
        end
    end
    
    local success, result = pcall(function()
        fling()
    end)
    
    if not success then
        npcFlingerConfig.walkflingConnection = RunService.Heartbeat:Connect(function()
            if npcFlingerConfig.hiddenfling then
                local char = LocalPlayer.Character
                if char then
                    local hrp = char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Torso") or char:FindFirstChild("UpperTorso")
                    if hrp then
                        local vel = hrp.Velocity
                        hrp.Velocity = vel * 10000 + Vector3.new(0, 10000, 0)
                        wait()
                        hrp.Velocity = vel
                    end
                end
            end
        end)
    end
end

local function executeFullWorkflow(npcModel, targetPlayer)
    local char = LocalPlayer.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    local root = npcRoot(npcModel)
    if not (hrp and root) then return end
    
    sendNotification("NPC Flinger", "Starting Full Workflow: " .. npcModel.Name .. " → " .. targetPlayer.Name, 3)
    
    local npcCFrame = root.CFrame
    local teleportCFrame = npcCFrame * CFrame.new(0, 3, -5)
    teleportCFrame = CFrame.lookAt(teleportCFrame.Position, npcCFrame.Position)
    char:PivotTo(teleportCFrame)
    wait(0.2)
    
    controlNPCsExact(npcModel)
    wait(0.5)
    
    local success, error = pcall(function()
        startWalkfling()
    end)
    if not success then
        sendNotification("NPC Flinger", "Walkfling error: " .. tostring(error), 3)
    end
    wait(0.5)
    
    if targetPlayer.Character and targetPlayer.Character:FindFirstChild("HumanoidRootPart") then
        local targetHRP = targetPlayer.Character.HumanoidRootPart
        char:PivotTo(targetHRP.CFrame * CFrame.new(0, 3, -5))
        wait(0.2)
        
        local skidSuccess, skidError = pcall(function()
            npcSkidFling(targetPlayer, npcModel)
        end)
        if not skidSuccess then
            sendNotification("NPC Flinger", "NPC SkidFling error: " .. tostring(skidError), 3)
        end
    else
        sendNotification("NPC Flinger", "Error: Target player character not found!", 3)
    end
    
    sendNotification("NPC Flinger", "Full Workflow Complete!", 2)
end

Tabs.Premium:Section({ Title = "NPC Flinger" })

local npcItems = collectNPCNames()
local playerItems = collectPlayerNames()

local NPCDropdown = Tabs.Premium:Dropdown({
    Title = "Select NPC",
    Desc = "Choose an NPC to control",
    Values = npcItems,
    Multi = false,
    Default = npcItems[1] or "",
    Callback = function(v)
        npcFlingerConfig.selectedNPC = v
    end
})

local PlayerDropdown = Tabs.Premium:Dropdown({
    Title = "Select Player",
    Desc = "Choose a player to fling",
    Values = playerItems,
    Multi = false,
    Default = playerItems[1] or "",
    Callback = function(v)
        npcFlingerConfig.selectedPlayer = v
    end
})

Tabs.Premium:Button({
    Title = "Refresh Lists",
    Desc = "Update NPC and Player lists",
    Callback = function()
        npcItems = collectNPCNames()
        playerItems = collectPlayerNames()
        
if NPCDropdown and NPCDropdown.Refresh then NPCDropdown:Refresh(npcItems) end
if PlayerDropdown and PlayerDropdown.Refresh then PlayerDropdown:Refresh(playerItems) end
        
        if npcFlingerConfig.selectedNPC and not npcFlingerConfig.nameToModel[npcFlingerConfig.selectedNPC] then 
            npcFlingerConfig.selectedNPC = nil 
        end
        
        if npcFlingerConfig.selectedPlayer and not npcFlingerConfig.playerToModel[npcFlingerConfig.selectedPlayer] then 
            npcFlingerConfig.selectedPlayer = nil 
        end
    end
})

Tabs.Premium:Button({
    Title = "Execute NPC Fling",
    Desc = "Teleport → Control NPC → Walkfling → Teleport to Player → NPC SkidFling",
    Callback = function()
        if not npcFlingerConfig.selectedNPC then 
            sendNotification("NPC Flinger", "Please select an NPC first!", 3)
            return 
        end
        if not npcFlingerConfig.selectedPlayer then 
            sendNotification("NPC Flinger", "Please select a player first!", 3)
            return 
        end
        
        local npcModel = npcFlingerConfig.nameToModel[npcFlingerConfig.selectedNPC]
        local targetPlayer = npcFlingerConfig.playerToModel[npcFlingerConfig.selectedPlayer]
        
        if npcModel and targetPlayer then
            executeFullWorkflow(npcModel, targetPlayer)
        else
            sendNotification("NPC Flinger", "Error: NPC or Player not found!", 3)
        end
    end
})


-- Ensure animal detection wires once after UI loads
task.defer(function()
  if setupAnimalDetection then setupAnimalDetection() end
end)

-- ========================================
-- ADMIN TAB CONTENT
-- ========================================

if isAdmin() then
    local AdminState = { Users = {"All"}, Selected = "All", SelectedUid = nil, ByLabel = {}, Msg = "" }
    local _AdminNameCache = {}
    
    _G.MOON_Admin_LabelFrom = function(uid, j)
        local dn = tostring((j and j.displayName) or (j and j.DisplayName) or "")
        local un = tostring((j and j.name) or (j and j.Username) or "")
        if dn ~= "" and un ~= "" then return dn.." (@"..un..")" end
        if dn ~= "" then return dn end
        if un ~= "" then return "@"..un end
        return tostring(uid)
    end
    
    _G.MOON_Admin_FetchLabel = function(uid)
        uid = tostring(uid)
        local c = _AdminNameCache[uid]
        if c then return c end
        local okUS, infos = pcall(UserService.GetUserInfosByUserIdsAsync, UserService, { tonumber(uid) })
        if okUS and infos and infos[1] then
            local info = infos[1]
            local lbl = _G.MOON_Admin_LabelFrom(uid, { displayName = info.DisplayName, name = info.Username })
            _AdminNameCache[uid] = lbl
            return lbl
        end
        local req = (syn and syn.request) or http_request or request or (fluxus and fluxus.request)
        if req then
            local r = req({ Url = "https://users.roblox.com/v1/users/"..uid, Method = "GET", Headers = {["Accept"]="application/json"} })
            if r and r.Body then
                local okJ, j = pcall(function() return HttpService:JSONDecode(tostring(r.Body)) end)
                if okJ and j then 
                    local lbl = _G.MOON_Admin_LabelFrom(uid, j)
                    _AdminNameCache[uid] = lbl
                    return lbl 
                end
            end
        end
        _AdminNameCache[uid] = uid
        return uid
    end
    
    AdminState.UI = AdminState.UI or {}
    AdminState.UI.OnlineDropdown = Tabs.Admin:Dropdown({
        Title = "Online users",
        Desc = "Select an online user or choose All",
        Values = AdminState.Users,
        Multi = false,
        Default = "All",
        Callback = function(v)
            AdminState.Selected = v
            AdminState.SelectedUid = AdminState.ByLabel[v]
        end
    })
    
    local function _AdminRebuild(users)
        local list, map = {"All"}, {}
        for _,u in ipairs(users or {}) do
            local uid = tostring(u.uid or u.userId or u)
            local label = tostring(u.label or "")
            if label == "" then 
                local ok, result = pcall(_AdminFetchLabel, uid)
                label = ok and result or uid
            end
            table.insert(list, label)
            map[label] = uid
        end
        AdminState.Users = list
        AdminState.ByLabel = map
        if AdminState.UI and AdminState.UI.OnlineDropdown and AdminState.UI.OnlineDropdown.Refresh then 
            local ok, err = pcall(function() AdminState.UI.OnlineDropdown:Refresh(AdminState.Users) end)
            if not ok then
                -- Silent fail - don't spam errors
            end
        end
    end
    
    Tabs.Admin:Button({
        Title = "Refresh Now",
        Desc = "Pull latest online list",
        Callback = function()
            local data = http_json("GET","/admin/online",nil)
            if data and data.ok == true then
                _AdminRebuild(data.users)
            else
                local msg = (data and ("HTTP "..tostring(data.status or "?"))) or "Network error"
                sendNotification("Admin", msg, 2)
            end
        end
    })
    
    Tabs.Admin:Section({ Title = "Announce" })
    Tabs.Admin:Input({
        Title = "Message",
        Desc = "Text to send",
        Default = "",
        PlaceholderText = "Type announcement...",
        Callback = function(txt) AdminState.Msg = txt end
    })
    
    Tabs.Admin:Button({
        Title = "Broadcast",
        Desc = "Send to everyone",
        Callback = function()
            if (AdminState.Msg or "") == "" then
                sendNotification("Admin", "Type a message first", 2)
                return
            end
            local data = http_json("POST","/admin/announce",{ text = AdminState.Msg })
            sendNotification("Admin", (data and data.ok == true) and "Announcement queued" or "Error", 2)
        end
    })
    
    Tabs.Admin:Section({ Title = "Targeted actions" })
    Tabs.Admin:Button({
        Title = "Notify selected",
        Desc = "Send only to chosen user",
        Callback = function()
            local uid = AdminState.SelectedUid
            if AdminState.Selected == "All" or not uid then
                sendNotification("Admin", "Pick a specific user", 2)
                return
            end
            if (AdminState.Msg or "") == "" then
                sendNotification("Admin", "Type a message first", 2)
                return
            end
            local data = http_json("POST","/admin/notify",{ uid = tostring(uid), text = AdminState.Msg })
            sendNotification("Admin", (data and data.ok == true) and "Notify queued" or "Error", 2)
        end
    })
    
    Tabs.Admin:Button({
        Title = "Disconnect selected",
        Desc = "Kick chosen user",
        Callback = function()
            local uid = AdminState.SelectedUid
            if AdminState.Selected == "All" or not uid then
                sendNotification("Admin", "Pick a specific user", 2)
                return
            end
            local data = http_json("POST","/admin/disconnect",{ uid = tostring(uid) })
            sendNotification("Admin", (data and data.ok == true) and "Disconnect queued" or "Error", 2)
        end
    })
    
    Tabs.Admin:Section({ Title = "Ban System" })
    
    AdminState.manualUid = ""
    Tabs.Admin:Input({
        Title = "Manual User ID",
        Desc = "Enter user ID for ban/unban actions",
        Default = "",
        PlaceholderText = "Enter User ID...",
        Callback = function(text) AdminState.manualUid = text end
    })
    
    Tabs.Admin:Button({
        Title = "Ban Manual UID",
        Desc = "Ban user by manual UID",
        Callback = function()
            if AdminState.manualUid == "" then
                sendNotification("Admin", "Enter a User ID first", 2)
                return
            end
            local data = http_json("POST","/admin/ban",{ uid = tostring(AdminState.manualUid) })
            sendNotification("Admin", (data and data.ok == true) and "User banned" or "Error", 2)
        end
    })
    
    Tabs.Admin:Button({
        Title = "Unban Manual UID",
        Desc = "Unban user by manual UID",
        Callback = function()
            if AdminState.manualUid == "" then
                sendNotification("Admin", "Enter a User ID first", 2)
                return
            end
            local data = http_json("POST","/admin/unban",{ uid = tostring(AdminState.manualUid) })
            sendNotification("Admin", (data and data.ok == true) and "User unbanned" or "Error", 2)
        end
    })
    
    Tabs.Admin:Button({
        Title = "Ban Selected User",
        Desc = "Ban the selected user from dropdown",
        Callback = function()
            local uid = AdminState.SelectedUid
            if AdminState.Selected == "All" or not uid then
                sendNotification("Admin", "Pick a specific user", 2)
                return
            end
            local data = http_json("POST","/admin/ban",{ uid = tostring(uid) })
            sendNotification("Admin", (data and data.ok == true) and "User banned" or "Error", 2)
        end
    })
    
    Tabs.Admin:Button({
        Title = "Unban Selected User",
        Desc = "Unban the selected user from dropdown",
        Callback = function()
            local uid = AdminState.SelectedUid
            if AdminState.Selected == "All" or not uid then
                sendNotification("Admin", "Pick a specific user", 2)
                return
            end
            local data = http_json("POST","/admin/unban",{ uid = tostring(uid) })
            sendNotification("Admin", (data and data.ok == true) and "User unbanned" or "Error", 2)
        end
    })
    
    Tabs.Admin:Section({ Title = "Game Controls" })
    
    Tabs.Admin:Button({
        Title = "Bring Selected Player",
        Desc = "Teleport selected player to you",
        Callback = function()
            local uid = AdminState.SelectedUid
            if AdminState.Selected == "All" or not uid then
                sendNotification("Admin", "Pick a specific user", 2)
                return
            end
            local data = http_json("POST","/admin/bring",{ uid = tostring(uid) })
            sendNotification("Admin", (data and data.ok == true) and "Bring command sent" or "Error", 2)
        end
    })
    
    Tabs.Admin:Button({
        Title = "Kill Selected Player",
        Desc = "Reset/break joints of selected player",
        Callback = function()
            local uid = AdminState.SelectedUid
            if AdminState.Selected == "All" or not uid then
                sendNotification("Admin", "Pick a specific user", 2)
                return
            end
            local data = http_json("POST","/admin/kill",{ uid = tostring(uid) })
            sendNotification("Admin", (data and data.ok == true) and "Kill command sent" or "Error", 2)
        end
    })
    
    Tabs.Admin:Button({
        Title = "Freeze Selected Player",
        Desc = "Freeze the selected player",
        Callback = function()
            local uid = AdminState.SelectedUid
            if AdminState.Selected == "All" or not uid then
                sendNotification("Admin", "Pick a specific user", 2)
                return
            end
            local data = http_json("POST","/admin/freeze",{ uid = tostring(uid) })
            sendNotification("Admin", (data and data.ok == true) and "Freeze command sent" or "Error", 2)
        end
    })
    
    Tabs.Admin:Button({
        Title = "Unfreeze Selected Player",
        Desc = "Unfreeze the selected player",
        Callback = function()
            local uid = AdminState.SelectedUid
            if AdminState.Selected == "All" or not uid then
                sendNotification("Admin", "Pick a specific user", 2)
                return
            end
            local data = http_json("POST","/admin/unfreeze",{ uid = tostring(uid) })
            sendNotification("Admin", (data and data.ok == true) and "Unfreeze command sent" or "Error", 2)
        end
    })
    
    AdminState.sayMessage = ""
    Tabs.Admin:Input({
        Title = "Message for Player to Say",
        Desc = "Enter message for selected player to say in chat",
        Default = "",
        PlaceholderText = "Enter message...",
        Callback = function(text) AdminState.sayMessage = text end
    })
    
    Tabs.Admin:Button({
        Title = "Make Selected Player Say",
        Desc = "Make selected player say the message",
        Callback = function()
            local uid = AdminState.SelectedUid
            if AdminState.Selected == "All" or not uid then
                sendNotification("Admin", "Pick a specific user", 2)
                return
            end
            if AdminState.sayMessage == "" then
                sendNotification("Admin", "Enter a message first", 2)
                return
            end
            local data = http_json("POST","/admin/say",{ uid = tostring(uid), message = AdminState.sayMessage })
            sendNotification("Admin", (data and data.ok == true) and "Say command sent" or "Error", 2)
        end
    })
    
    Tabs.Admin:Button({
        Title = "Join Selected Player's Game",
        Desc = "Get server details and join the selected player's game",
        Callback = function()
            local uid = AdminState.SelectedUid
            if AdminState.Selected == "All" or not uid then
                sendNotification("Admin", "Pick a specific user", 2)
                return
            end
            local data = http_json("POST","/admin/joingame",{ uid = tostring(uid) })
            if data and data.ok == true then
                sendNotification("Admin", "Join game command sent! Check your messages for server details.", 3)
            else
                local errorMsg = data and data.msg or "Unknown error"
                sendNotification("Admin", "Error: " .. errorMsg, 3)
            end
        end
    })
    
    task.spawn(function()
        while true do
            local ok, data = pcall(http_json, "GET", "/admin/online", nil)
            if ok and data and data.ok == true then 
                local ok2, err = pcall(_AdminRebuild, data.users)
                if not ok2 then
                    -- Silent fail - don't spam errors
                end
            end
            task.wait(5)
        end
    end)
end

-- ========================================
-- SETTINGS TAB CONTENT
-- ========================================

Tabs.Settings = Window:Tab({Title = "Settings", Icon = "settings"})

Window:SelectTab(1)