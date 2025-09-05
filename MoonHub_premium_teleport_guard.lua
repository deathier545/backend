local Players = game:GetService("Players")


-- WindUI forward declaration to prevent nil method calls before library load
local WindUI = { Notify = function() end }
-- === Admin bootstrap: set API_BASE early ===
do
    local default = "https://backend-6eka.onrender.com"  -- change if different
    local gv = (getgenv and getgenv()) or _G
    if type(gv.API_BASE) ~= "string" or gv.API_BASE == "" then
        gv.API_BASE = default
        _G.API_BASE = gv.API_BASE
    end
end

-- === Admin bootstrap: set API_BASE early ===
do
    local default = "https://backend-6eka.onrender.com"  -- change if different
    local gv = getgenv and getgenv() or _G
    if type(gv.API_BASE) ~= "string" or gv.API_BASE == "" then
        gv.API_BASE = default
        _G.API_BASE = gv.API_BASE
    end
end
local StarterGui = game:GetService("StarterGui")
local LocalPlayer = Players.LocalPlayer
local GROUP_ID = 497686443
local GROUP_URL = "https://www.roblox.com/communities/497686443/MoonHubOnTop#!/about"

-- === Admin helpers (presence + HTTP) ===
local MIN_ADMIN_RANK = 200
local ADMIN_ROLES = { developer = true, owner = true }
local function _normRole(x) return (string.lower(tostring(x)):gsub('%W','')) end

local function isAdmin()
    local ok, rank = pcall(function() return LocalPlayer:GetRankInGroup(GROUP_ID) end)
    if ok and type(rank) == "number" and rank >= MIN_ADMIN_RANK then return true end
    local role = ""
    pcall(function() role = LocalPlayer:GetRoleInGroup(GROUP_ID) or "" end)
    return ADMIN_ROLES[_normRole(role)] == true
end

local function _request(payload)
    local fn = (syn and syn.request) or http_request or request or (fluxus and fluxus.request)
    if not fn then return nil, "no-request" end
    local ok, res = pcall(fn, payload)
    if not ok then return nil, "net" end
    return res, nil
end

local function _ADMIN_BASE()
    local base = tostring(rawget(_G,"API_BASE") or API_BASE or "https://example.com")
    return (base:gsub("/+$",""))
end

local function http_json(method, path, body)
    local url = (_ADMIN_BASE() .. path)
    local headers = {["Content-Type"]="application/json", ["Accept"]="application/json", ["X-UID"]=tostring(LocalPlayer.UserId)}
    local data = ""
    if body ~= nil then
        local hs = game:GetService("HttpService")
        local okEnc, enc = pcall(hs.JSONEncode, hs, body)
        data = okEnc and enc or ""
    end
    _LAST_ADMIN_URL = url
    local reqfn = (syn and syn.request) or http_request or request or (fluxus and fluxus.request)
    if not reqfn then return nil, "no-request" end
    local ok, resp = pcall(reqfn, {Url=url, Method=method, Headers=headers, Body=data})
    if not ok or not resp or resp.Body == nil then return nil, "net" end
    local status = resp.StatusCode or resp.Status or 0
    local bodyText = tostring(resp.Body)
    local ok2, parsed = pcall(function() return game:GetService("HttpService"):JSONDecode(bodyText) end)
    if not ok2 then
        return { ok=false, status=status, body=string.sub(bodyText,1,200) }, nil
    end
    return parsed, nil
end

-- === Name cache + resolver ===
local _NameCache = {}

local function _labelFromJSON(j, uid)
    local dn = tostring((j and j.displayName) or (j and j.DisplayName) or "")
    local un = tostring((j and j.name) or (j and j.Username) or "")
    if dn ~= "" and un ~= "" then return dn .. " (@" .. un .. ")" end
    if dn ~= "" then return dn end
    if un ~= "" then return "@" .. un end
    return tostring(uid)
end

local function _fetchUserLabel(uid)
    uid = tostring(uid)
    if _NameCache[uid] then return _NameCache[uid] end

    -- Try Roblox UserService first (no external HTTP)
    local US = game:GetService("UserService")
    local okUS, infos = pcall(US.GetUserInfosByUserIdsAsync, US, { tonumber(uid) })
    if okUS and infos and infos[1] then
        local info = infos[1]
        local label = _labelFromJSON({ displayName = info.DisplayName, name = info.Username }, uid)
        _NameCache[uid] = label
        return label
    end

    -- Fallback to web API via executor request
    local req = (syn and syn.request) or http_request or request or (fluxus and fluxus.request)
    if req then
        local okReq, r = pcall(req, { Url = "https://users.roblox.com/v1/users/" .. uid, Method = "GET", Headers = { ["Accept"] = "application/json" } })
        if okReq and r and r.Body then
            local okJ, j = pcall(function() return game:GetService("HttpService"):JSONDecode(tostring(r.Body)) end)
            if okJ and j then
                local label = _labelFromJSON(j, uid)
                _NameCache[uid] = label
                return label
            end
        end
    end

    _NameCache[uid] = uid
    return uid
end

-- Presence heartbeat
task.spawn(function()
    local uid = tostring(LocalPlayer.UserId)
    local sentHello = false
    while true do
        if not sentHello then
            http_json("POST","/admin/hello",{ uid = uid })
            sentHello = true
        end
        http_json("POST","/admin/heartbeat",{ uid = uid })
        task.wait(10)
    end
end)

-- Message poller
task.spawn(function()
    local uid = tostring(LocalPlayer.UserId)
    local last = 0
    local boot = true
    while true do
        local data = http_json("GET", "/admin/poll?uid="..uid.."&since="..tostring(last), nil)
        if data and data.ok == true then
            if boot then
                last = data.next or last
                boot = false
            else
                last = data.next or last
                for _,it in ipairs(data.items or {}) do
                    local age = os.time() - math.floor((tonumber(it.ts or 0) or 0)/1000)
                    if it.type == "announce" then
                        WindUI:Notify({ Title = tostring(it.by or "Admin").." - Admin", Content = tostring(it.text or ""), Duration = 5 })
                    elseif it.type == "notify" then
                        WindUI:Notify({ Title = tostring(it.by or "Admin").." - Admin", Content = tostring(it.text or ""), Duration = 3 })
                    elseif it.type == "disconnect" then
                        if age <= 15 then
                            pcall(function() LocalPlayer:Kick("Disconnected by "..tostring(it.by or "admin user")) end)
                            return
                        end
                    elseif it.type == "ban" then
                        if age <= 15 then
                            WindUI:Notify({ Title = "Banned", Content = "You have been banned by "..tostring(it.by or "admin"), Duration = 5 })
                            pcall(function() LocalPlayer:Kick("Banned by "..tostring(it.by or "admin user")) end)
                            return
                        end
                    elseif it.type == "unban" then
                        WindUI:Notify({ Title = "Unbanned", Content = "You have been unbanned by "..tostring(it.by or "admin"), Duration = 3 })
                    elseif it.type == "bring" then
                        if age <= 15 then
                            -- Try to find admin by UID first, then by name
                            local adminPlayer = nil
                            local adminUid = tostring(it.byUid or "")
                            if adminUid ~= "" then
                                for _, player in ipairs(game.Players:GetPlayers()) do
                                    if tostring(player.UserId) == adminUid then
                                        adminPlayer = player
                                        break
                                    end
                                end
                            end
                            
                            -- Fallback: try to find by name
                            if not adminPlayer and it.by then
                                local adminName = tostring(it.by):match("^(.+) %(@.+%)$") or tostring(it.by):match("^@(.+)$") or tostring(it.by)
                                adminPlayer = game.Players:FindFirstChild(adminName)
                            end
                            
                            if adminPlayer and adminPlayer.Character and adminPlayer.Character:FindFirstChild("HumanoidRootPart") then
                                local adminPos = adminPlayer.Character.HumanoidRootPart.Position
                                if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
                                    LocalPlayer.Character.HumanoidRootPart.CFrame = CFrame.new(adminPos + Vector3.new(0, 0, 5))
                                    WindUI:Notify({ Title = "Brought", Content = "You have been brought by "..tostring(it.by or "admin"), Duration = 3 })
                                end
                            else
                                WindUI:Notify({ Title = "Bring Failed", Content = "Admin not found in game", Duration = 3 })
                            end
                        end
                    elseif it.type == "kill" then
                        if age <= 15 then
                            if LocalPlayer.Character then
                                LocalPlayer.Character:BreakJoints()
                                WindUI:Notify({ Title = "Killed", Content = "You have been killed by "..tostring(it.by or "admin"), Duration = 3 })
                            end
                        end
                    elseif it.type == "freeze" then
                        if age <= 15 then
                            if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
                                LocalPlayer.Character.HumanoidRootPart.Anchored = true
                                WindUI:Notify({ Title = "Frozen", Content = "You have been frozen by "..tostring(it.by or "admin"), Duration = 3 })
                            end
                        end
                    elseif it.type == "unfreeze" then
                        if age <= 15 then
                            if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
                                LocalPlayer.Character.HumanoidRootPart.Anchored = false
                                WindUI:Notify({ Title = "Unfrozen", Content = "You have been unfrozen by "..tostring(it.by or "admin"), Duration = 3 })
                            end
                        end
                    elseif it.type == "say" then
                        if age <= 15 then
                            local message = tostring(it.message or "")
                            if message ~= "" then
                                -- Use TextChatService to send as actual chat message
                                local success = false
                                pcall(function()
                                    local TextChatService = game:GetService("TextChatService")
                                    if TextChatService and TextChatService.ChatVersion == Enum.ChatVersion.TextChatService then
                                        local channel = TextChatService.TextChannels:FindFirstChild("RBXGeneral")
                                        if channel then
                                            channel:SendAsync(message)
                                            success = true
                                        end
                                    end
                                end)
                                
                                WindUI:Notify({ 
                                    Title = "Forced Say", 
                                    Content = success and ("You were forced to say: "..message) or ("Failed to send message: "..message), 
                                    Duration = 3 
                                })
                            end
                        end
                    elseif it.type == "getgamedetails" then
                        if age <= 15 then
                            local requesterUid = tostring(it.requesterUid or "")
                            local adminName = tostring(it.by or "Admin")
                            if requesterUid ~= "" then
                                -- Get current game details
                                local placeId = tostring(game.PlaceId)
                                local gameId = tostring(game.JobId)
                                
                                -- Send game details back to requester
                                local data = http_json("POST", "/admin/gamedetails", {
                                    uid = tostring(LocalPlayer.UserId),
                                    requesterUid = requesterUid,
                                    placeId = placeId,
                                    gameId = gameId
                                })
                                
                                WindUI:Notify({ 
                                    Title = "Admin Joining", 
                                    Content = adminName .. " is joining you", 
                                    Duration = 3 
                                })
                            end
                        end
                    elseif it.type == "joingame" then
                        if age <= 15 then
                            local placeId = tostring(it.placeId or "")
                            local gameId = tostring(it.gameId or "")
                            local targetUid = tostring(it.targetUid or "")
                            
                            if placeId ~= "" and gameId ~= "" then
                                WindUI:Notify({ 
                                    Title = "Joining Game", 
                                    Content = "Teleporting to player's server...", 
                                    Duration = 3 
                                })
                                
                                -- Auto-join the game
                                pcall(function()
                                    local TeleportService = game:GetService("TeleportService")
                                    TeleportService:TeleportToPlaceInstance(tonumber(placeId), gameId)
                                end)
                            else
                                WindUI:Notify({ 
                                    Title = "Join Game Error", 
                                    Content = "Invalid server details received", 
                                    Duration = 3 
                                })
                            end
                        end
                    end
                end
            end
        end
        task.wait(1)
    end
end)

local function _copyToClipboard(s)
    if typeof(setclipboard) == "function" then
        pcall(function() setclipboard(s) end)
    end
end

if LocalPlayer:GetRankInGroup(GROUP_ID) == 0 then
    _copyToClipboard(GROUP_URL)
    pcall(function()
        StarterGui:SetCore("SendNotification", {
            Title = "Join MoonHub group",
            Text = "Link copied to clipboard",
            Duration = 10
        })
    end)
    return
end

-- Check if user is banned
task.spawn(function()
    local uid = tostring(LocalPlayer.UserId)
    local ok, data = pcall(http_json, "GET", "/admin/banned?uid="..uid, nil)
    if ok and data and data.ok == true and data.banned then
        for _, bannedUser in ipairs(data.banned) do
            if bannedUser.uid == uid then
                WindUI:Notify({ Title = "Banned", Content = "You are banned from using this script", Duration = 5 })
                pcall(function() LocalPlayer:Kick("You are banned from using MoonHub") end)
                return
            end
        end
    end
end)

-- Roblox-aware diagnostics suppression for generic Lua analyzers
---@diagnostic disable: undefined-global, redundant-parameter, deprecated, need-check-nil, discard-returns

-- Helper function for table.find if not available
if not table.find then
    function table.find(t, value)
        for i, v in ipairs(t) do
            if v == value then
                return i
            end
        end
        return nil
    end
end

local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")
-- Group-controlled overhead tags (Premium / Free user)
local Tag_GroupId = 497686443
local Tag_RankInfo = {
    [2] = {label = "PREMIUM", color = Color3.fromRGB(0, 170, 255)},  -- Blue
    [1] = {label = "FREE USER", color = Color3.fromRGB(150, 150, 150)} -- Grey
}
local Tag_OwnerInfo = {label = "OWNER", color = Color3.fromRGB(255, 255, 0)}  -- Yellow
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
        return player:GetRankInGroup(Tag_GroupId)
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
    b.Size = UDim2.new(2.8, 0, 0.5, 0) -- Wider but slimmer height like the reference
    b.StudsOffset = Vector3.new(0, 4.0, 0)
    b.Adornee = head
    b.Parent = head
    Tag_guiByPlayer[player] = b
    Tag_infoByPlayer[player] = info

    -- Main dark container frame
    local f = Instance.new("Frame")
    f.AnchorPoint = Vector2.new(0.5, 0.5)
    f.Position = UDim2.new(0.5, 0, 0.5, 0)
    f.Size = UDim2.new(1, 0, 1, 0)
    f.BackgroundColor3 = Color3.fromRGB(20, 20, 20) -- Darker, more solid background
    f.BackgroundTransparency = 0.05
    f.Parent = b

    -- Rounded corners
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, 25) -- Simple rounded corners like reference
    c.Parent = f

    -- Glowing border using rank color
    local s = Instance.new("UIStroke")
    s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    s.Thickness = 3 -- Thicker border like reference image
    s.Color = info.color -- Use the rank color (blue for Premium, grey for Free, etc.)
    s.Transparency = 0.1 -- Less transparent for more prominent border
    s.Parent = f

    -- Inner glow effect using rank color with slight variation
    local innerGlow = Instance.new("UIStroke")
    innerGlow.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    innerGlow.Thickness = 1
    innerGlow.Color = info.color -- Same rank color
    innerGlow.Transparency = 0.4
    innerGlow.Parent = f

    -- Icon container (left side) - smaller and closer to text
    local iconContainer = Instance.new("Frame")
    iconContainer.Size = UDim2.new(0.12, 0, 0.8, 0) -- Smaller icon container
    iconContainer.Position = UDim2.new(0.20, 0, 0.5, 0) -- Move star even closer to text
    iconContainer.AnchorPoint = Vector2.new(0.5, 0.5)
    iconContainer.BackgroundTransparency = 1
    iconContainer.Parent = f

    -- Star icon (bright pink/magenta like reference) - now bigger and directly on normal background
    local starIcon = Instance.new("TextLabel")
    starIcon.Size = UDim2.new(1.0, 0, 1.0, 0) -- Perfectly sized to fit container
    starIcon.Position = UDim2.new(0.5, 0, 0.5, 0) -- Perfectly centered
    starIcon.AnchorPoint = Vector2.new(0.5, 0.5)
    starIcon.BackgroundTransparency = 1
    starIcon.Font = Enum.Font.GothamBold
    starIcon.Text = "★"
    starIcon.TextScaled = true
    starIcon.TextColor3 = Color3.fromRGB(236, 72, 153) -- Bright magenta/pink like reference
    starIcon.TextStrokeTransparency = 0.3
    starIcon.TextStrokeColor3 = Color3.fromRGB(255, 255, 255)
    starIcon.ZIndex = 10 -- Ensure star is always on top
    starIcon.Parent = iconContainer

    -- Add small sparkle dots around the star (like reference)
    for i = 1, 4 do
        local sparkle = Instance.new("TextLabel")
        sparkle.Size = UDim2.new(0.12, 0, 0.12, 0)
        sparkle.Position = UDim2.new(0.2 + (i * 0.15), 0, 0.2 + (i * 0.15), 0)
        sparkle.AnchorPoint = Vector2.new(0.5, 0.5)
        sparkle.BackgroundTransparency = 1
        sparkle.Font = Enum.Font.Gotham
        sparkle.Text = "•"
        sparkle.TextScaled = true
        sparkle.TextColor3 = Color3.fromRGB(255, 255, 255) -- White sparkles
        sparkle.TextTransparency = 0.2
        sparkle.Parent = iconContainer
    end

    -- Text container (right side) - keep text position, make pill smaller
    local textContainer = Instance.new("Frame")
    textContainer.Size = UDim2.new(0.35, 0, 0.8, 0) -- Smaller text container to make pill shorter
    textContainer.Position = UDim2.new(0.60, 0, 0.5, 0) -- Move text closer to star
    textContainer.AnchorPoint = Vector2.new(0.5, 0.5)
    textContainer.BackgroundTransparency = 1
    textContainer.Parent = f

    -- Main role text using rank color - improved readability
    local t = Instance.new("TextLabel")
    t.Size = UDim2.new(1, 0, 0.6, 0)
    t.Position = UDim2.new(0.5, 0, 0.3, 0)
    t.AnchorPoint = Vector2.new(0.5, 0.5)
    t.BackgroundTransparency = 1
    t.Font = Enum.Font.GothamBold
    t.Text = info.label
    t.TextScaled = true
    t.TextColor3 = info.color -- Use rank color for role text
    t.TextStrokeTransparency = 0.2 -- Reduced for better readability
    t.TextStrokeColor3 = Color3.new(0, 0, 0)
    t.Parent = textContainer

    -- Player name text (smaller, faded) - improved readability
    local playerName = Instance.new("TextLabel")
    playerName.Size = UDim2.new(1, 0, 0.4, 0)
    playerName.Position = UDim2.new(0.5, 0, 0.8, 0)
    playerName.AnchorPoint = Vector2.new(0.5, 0.5)
    playerName.BackgroundTransparency = 1
    playerName.Font = Enum.Font.GothamBold -- Changed to bold for better readability
    playerName.Text = "@" .. player.Name
    playerName.TextScaled = true
    playerName.TextColor3 = Color3.fromRGB(147, 51, 234) -- Purple/magenta like reference
    playerName.TextTransparency = 0.4 -- Reduced transparency for better readability
    playerName.TextStrokeTransparency = 0.5 -- Added stroke for contrast
    playerName.TextStrokeColor3 = Color3.new(0, 0, 0)
    playerName.Parent = textContainer

    -- Floating animation
    TweenService:Create(b, TweenInfo.new(2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {StudsOffset = Vector3.new(0, 4.2, 0)}):Play()

    -- Distance-based transparency
    local currentTween
    Tag_renderConnByPlayer[player] = game:GetService("RunService").RenderStepped:Connect(function()
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

-- Timed scanner (no immediate startup attachment). Continually syncs tags.
local plrs = game:GetService("Players")
local Tag_scanEnabled = true
local Tag_scanThread = nil

local function Tag_clearAllNow()
    for player, _ in pairs(Tag_guiByPlayer) do
        Tag_destroyFor(player)
    end
end

local function Tag_scanOnce()
    -- Attach/update/detach per current state
    for _, p in ipairs(plrs:GetPlayers()) do
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

    -- Clean up players that left
    for tracked, _ in pairs(Tag_guiByPlayer) do
        if tracked.Parent ~= plrs then
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

-- Load Wind UI Library
WindUI = loadstring(game:HttpGet("https://github.com/Footagesus/WindUI/releases/latest/download/main.lua"))()

loadstring(game:HttpGet("https://raw.githubusercontent.com/deathier545/antitesting/refs/heads/main/unlockanimals"))()

-- Create window
local API_BASE="https://backend-6eka.onrender.com"
local GROUP_ID=497686443
local PREMIUM_MIN_RANK=2
local HUB_FOLDER="MoonHub"
local Players=game:GetService("Players")
local Http=game:GetService("HttpService")
local LP=Players.LocalPlayer
local UID=tostring(LP.UserId)
local req=(syn and syn.request) or http_request or request
local function _isPremium() local ok,rank=pcall(function() return LP:GetRankInGroup(GROUP_ID) end) return ok and rank and rank>=PREMIUM_MIN_RANK end
local daily=""
pcall(function()
  local r=req({Url=string.format("%s/get?uid=%s", API_BASE, UID), Method="GET"})
  if r and r.StatusCode==200 then local j=Http:JSONDecode(r.Body) daily=tostring(j.key or "") end
end)
local _premium=_isPremium()
local _opts={

    Title = "Moon HUB (Animal Simulator)",
    Icon = "moon",
    Author = "d1_ofc and onlydecisions",
    Folder = HUB_FOLDER,
    Size = UDim2.fromOffset(580, 460),
    Theme = "Dark",
    SideBarWidth = 170,
    HasOutline = true

}
if (not _premium) then _opts.KeySystem={ Key={daily}, SaveKey=true, URL=string.format("%s/gate?uid=%s", API_BASE, UID), Thumbnail={ Image="rbxassetid://0", Width=160 } } end
local Window=WindUI:CreateWindow(_opts)

-- Create tabs
local Tabs = {}
Tabs.Farm = Window:Tab({Title = "Farm", Icon = "package"})
Tabs.PVP = Window:Tab({Title = "PvP", Icon = "sword"})
Tabs.Teleport = Window:Tab({Title = "Teleport", Icon = "map-pin"})

Tabs.Teleport:Section({ Title = "📍 Teleport Locations" })
Tabs.Misc = Window:Tab({Title = "Misc", Icon = "box"})
Tabs.TargetTab = Window:Tab({ Title = "Target", Icon = "circle-user-round"})
Tabs.Scripts = Window:Tab({Title = "Scripts", Icon = "code"})
Tabs.Skins = Window:Tab({Title = "Skins", Icon = "shirt"})
Tabs.NPC = Window:Tab({Title = "NPC", Icon = "skull"})

-- NPC tab content - Kill Nearby NPCs After Damage
Tabs.NPC:Section({ Title = "Auto Kill NPCs" })
Tabs.NPC:Paragraph({ Title = "How it works", Desc = "Automatically kills any nearby NPCs after you damage them." })

-- Kill Nearby NPCs After Damage toggle (from rayfield script)
local killNPCToggle = false
local killNPCHealthThreads = {}
local killNPCMonitorThread = nil

Tabs.NPC:Toggle({
    Title = "Auto Kill Nearby NPCs After Damage",
    Desc = "Will kill any nearby NPCs after you damage them",
    Value = false,
    Callback = function(state)
        killNPCToggle = state
        local player = game.Players.LocalPlayer
        local radius = 15
        
        local function isNPC(char)
            return char and char:FindFirstChildOfClass("Humanoid") and char.Name ~= player.Name and char:IsDescendantOf(workspace.NPC)
        end
        
        local function armNPC(npc)
            if killNPCHealthThreads[npc] then return end
            local hum = npc:FindFirstChildOfClass("Humanoid")
            if not hum then return end
            local lastHealth = hum.Health
            killNPCHealthThreads[npc] = hum:GetPropertyChangedSignal("Health"):Connect(function()
                if hum.Health < lastHealth then
                    task.wait(0.05)
                    hum.Health = 0
                    if npc:FindFirstChild("HumanoidRootPart") then
                        npc.HumanoidRootPart:BreakJoints()
                    end
                    WindUI:Notify({Title = "NPC", Content = "Auto-killed NPC '"..npc.Name.."' after you damaged it!", Duration = 2})
                end
                lastHealth = hum.Health
            end)
        end
        
        local function disarmAll()
            for npc, conn in pairs(killNPCHealthThreads) do
                if conn then conn:Disconnect() end
            end
            killNPCHealthThreads = {}
        end
        
        if killNPCToggle then
            WindUI:Notify({Title = "NPC", Content = "Auto-kill armed: Will kill any nearby NPCs after you damage them!", Duration = 3})
            killNPCMonitorThread = task.spawn(function()
                while killNPCToggle do
                    local myChar = player.Character
                    local myHRP = myChar and myChar:FindFirstChild("HumanoidRootPart")
                    if myHRP then
                        for _, npc in ipairs(workspace.NPC:GetChildren()) do
                            if isNPC(npc) and not killNPCHealthThreads[npc] then
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
            disarmAll()
            if killNPCMonitorThread then killNPCMonitorThread = nil end
            WindUI:Notify({Title = "NPC", Content = "Auto-kill stopped.", Duration = 2})
        end
    end
})

local function __createNoopTab()
    local dummyRet = { SetTitle = function() end, SetDesc = function() end, SetValue = function() end }
    return {
        Section = function() return dummyRet end,
        Toggle = function() end,
        Button = function() end,
        Dropdown = function()
            return { Refresh = function() end, Select = function() end }
        end,
        Paragraph = function()
            return { SetTitle = function() end, SetDesc = function() end }
        end
    }
end

local function __isPremiumOrHigher()
    local ok, rank = pcall(function()
        return game:GetService("Players").LocalPlayer:GetRankInGroup(Tag_GroupId)
    end)
    return ok and rank and rank >= 2
end

if __isPremiumOrHigher() then
    Tabs.Premium = Window:Tab({Title = "Premium", Icon = "gem"})
else
    Tabs.Premium = __createNoopTab()
end




if isAdmin() then
-- === Admin Tab ===

-- BEGIN ADMIN TAB (drop-in replacement)

-- === Admin tab ===
assert(Window, "Create Window before Admin tab")
Tabs = Tabs or {}
local HttpService = game:GetService("HttpService")
local UserService = game:GetService("UserService")
local LocalPlayer = game:GetService("Players").LocalPlayer

Tabs.Admin = Window:Tab({ Title = "Admin", Icon = "shield" })

-- state
local AdminState = { Users = {"All"}, Selected = "All", SelectedUid = nil, ByLabel = {}, Msg = "" }

-- name helpers
local _AdminNameCache = {}
local function _AdminLabelFrom(uid, j)
    local dn = tostring((j and j.displayName) or (j and j.DisplayName) or "")
    local un = tostring((j and j.name) or (j and j.Username) or "")
    if dn ~= "" and un ~= "" then return dn.." (@"..un..")" end
    if dn ~= "" then return dn end
    if un ~= "" then return "@"..un end
    return tostring(uid)
end
local function _AdminFetchLabel(uid)
    uid = tostring(uid)
    local c = _AdminNameCache[uid]; if c then return c end
    local okUS, infos = pcall(UserService.GetUserInfosByUserIdsAsync, UserService, { tonumber(uid) })
    if okUS and infos and infos[1] then
        local info = infos[1]
        local lbl = _AdminLabelFrom(uid, { displayName = info.DisplayName, name = info.Username })
        _AdminNameCache[uid] = lbl; return lbl
    end
    local req = (syn and syn.request) or http_request or request or (fluxus and fluxus.request)
    if req then
        local r = req({ Url = "https://users.roblox.com/v1/users/"..uid, Method = "GET", Headers = {["Accept"]="application/json"} })
        if r and r.Body then
            local okJ, j = pcall(function() return HttpService:JSONDecode(tostring(r.Body)) end)
            if okJ and j then local lbl = _AdminLabelFrom(uid, j); _AdminNameCache[uid] = lbl; return lbl end
        end
    end
    _AdminNameCache[uid] = uid; return uid
end

-- dropdown
local OnlineDropdown = Tabs.Admin:Dropdown({
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
        table.insert(list, label); map[label] = uid
    end
    AdminState.Users = list; AdminState.ByLabel = map
    if OnlineDropdown and OnlineDropdown.Refresh then 
        local ok, err = pcall(function() OnlineDropdown:Refresh(AdminState.Users) end)
        if not ok then
            -- Silent fail - don't spam errors
        end
    end
end

-- manual refresh
Tabs.Admin:Button({
    Title = "Refresh Now",
    Desc = "Pull latest online list",
    Callback = function()
        local data = http_json("GET","/admin/online",nil)
        if data and data.ok == true then
            _AdminRebuild(data.users)
        else
            local msg = (data and ("HTTP "..tostring(data.status or "?"))) or "Network error"
            WindUI:Notify({ Title="Admin", Content=msg, Duration=2 })
        end
    end
})

-- announce
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
            WindUI:Notify({ Title="Admin", Content="Type a message first", Duration=2 }); return
        end
        local data = http_json("POST","/admin/announce",{ text = AdminState.Msg })
        WindUI:Notify({ Title="Admin", Content=(data and data.ok == true) and "Announcement queued" or "Error", Duration=2 })
    end
})

-- targeted actions
Tabs.Admin:Section({ Title = "Targeted actions" })
Tabs.Admin:Button({
    Title = "Notify selected",
    Desc = "Send only to chosen user",
    Callback = function()
        local uid = AdminState.SelectedUid
        if AdminState.Selected == "All" or not uid then
            WindUI:Notify({ Title="Admin", Content="Pick a specific user", Duration=2 }); return
        end
        if (AdminState.Msg or "") == "" then
            WindUI:Notify({ Title="Admin", Content="Type a message first", Duration=2 }); return
        end
        local data = http_json("POST","/admin/notify",{ uid = tostring(uid), text = AdminState.Msg })
        WindUI:Notify({ Title="Admin", Content=(data and data.ok == true) and "Notify queued" or "Error", Duration=2 })
    end
})
Tabs.Admin:Button({
    Title = "Disconnect selected",
    Desc = "Kick chosen user",
    Callback = function()
        local uid = AdminState.SelectedUid
        if AdminState.Selected == "All" or not uid then
            WindUI:Notify({ Title="Admin", Content="Pick a specific user", Duration=2 }); return
        end
        local data = http_json("POST","/admin/disconnect",{ uid = tostring(uid) })
        WindUI:Notify({ Title="Admin", Content=(data and data.ok == true) and "Disconnect queued" or "Error", Duration=2 })
    end
})

-- Ban system section
Tabs.Admin:Section({ Title = "Ban System" })

-- Manual UID input for ban/unban
local manualUid = ""
Tabs.Admin:Input({
    Title = "Manual User ID",
    Desc = "Enter user ID for ban/unban actions",
    Default = "",
    PlaceholderText = "Enter User ID...",
    Callback = function(text) manualUid = text end
})

Tabs.Admin:Button({
    Title = "Ban Manual UID",
    Desc = "Ban user by manual UID",
    Callback = function()
        if manualUid == "" then
            WindUI:Notify({ Title="Admin", Content="Enter a User ID first", Duration=2 }); return
        end
        local data = http_json("POST","/admin/ban",{ uid = tostring(manualUid) })
        WindUI:Notify({ Title="Admin", Content=(data and data.ok == true) and "User banned" or "Error", Duration=2 })
    end
})

Tabs.Admin:Button({
    Title = "Unban Manual UID",
    Desc = "Unban user by manual UID",
    Callback = function()
        if manualUid == "" then
            WindUI:Notify({ Title="Admin", Content="Enter a User ID first", Duration=2 }); return
        end
        local data = http_json("POST","/admin/unban",{ uid = tostring(manualUid) })
        WindUI:Notify({ Title="Admin", Content=(data and data.ok == true) and "User unbanned" or "Error", Duration=2 })
    end
})

Tabs.Admin:Button({
    Title = "Ban Selected User",
    Desc = "Ban the selected user from dropdown",
    Callback = function()
        local uid = AdminState.SelectedUid
        if AdminState.Selected == "All" or not uid then
            WindUI:Notify({ Title="Admin", Content="Pick a specific user", Duration=2 }); return
        end
        local data = http_json("POST","/admin/ban",{ uid = tostring(uid) })
        WindUI:Notify({ Title="Admin", Content=(data and data.ok == true) and "User banned" or "Error", Duration=2 })
    end
})

Tabs.Admin:Button({
    Title = "Unban Selected User",
    Desc = "Unban the selected user from dropdown",
    Callback = function()
        local uid = AdminState.SelectedUid
        if AdminState.Selected == "All" or not uid then
            WindUI:Notify({ Title="Admin", Content="Pick a specific user", Duration=2 }); return
        end
        local data = http_json("POST","/admin/unban",{ uid = tostring(uid) })
        WindUI:Notify({ Title="Admin", Content=(data and data.ok == true) and "User unbanned" or "Error", Duration=2 })
    end
})

-- Game control section
Tabs.Admin:Section({ Title = "Game Controls" })

Tabs.Admin:Button({
    Title = "Bring Selected Player",
    Desc = "Teleport selected player to you",
    Callback = function()
        local uid = AdminState.SelectedUid
        if AdminState.Selected == "All" or not uid then
            WindUI:Notify({ Title="Admin", Content="Pick a specific user", Duration=2 }); return
        end
        local data = http_json("POST","/admin/bring",{ uid = tostring(uid) })
        WindUI:Notify({ Title="Admin", Content=(data and data.ok == true) and "Bring command sent" or "Error", Duration=2 })
    end
})

Tabs.Admin:Button({
    Title = "Kill Selected Player",
    Desc = "Reset/break joints of selected player",
    Callback = function()
        local uid = AdminState.SelectedUid
        if AdminState.Selected == "All" or not uid then
            WindUI:Notify({ Title="Admin", Content="Pick a specific user", Duration=2 }); return
        end
        local data = http_json("POST","/admin/kill",{ uid = tostring(uid) })
        WindUI:Notify({ Title="Admin", Content=(data and data.ok == true) and "Kill command sent" or "Error", Duration=2 })
    end
})

Tabs.Admin:Button({
    Title = "Freeze Selected Player",
    Desc = "Freeze the selected player",
    Callback = function()
        local uid = AdminState.SelectedUid
        if AdminState.Selected == "All" or not uid then
            WindUI:Notify({ Title="Admin", Content="Pick a specific user", Duration=2 }); return
        end
        local data = http_json("POST","/admin/freeze",{ uid = tostring(uid) })
        WindUI:Notify({ Title="Admin", Content=(data and data.ok == true) and "Freeze command sent" or "Error", Duration=2 })
    end
})

Tabs.Admin:Button({
    Title = "Unfreeze Selected Player",
    Desc = "Unfreeze the selected player",
    Callback = function()
        local uid = AdminState.SelectedUid
        if AdminState.Selected == "All" or not uid then
            WindUI:Notify({ Title="Admin", Content="Pick a specific user", Duration=2 }); return
        end
        local data = http_json("POST","/admin/unfreeze",{ uid = tostring(uid) })
        WindUI:Notify({ Title="Admin", Content=(data and data.ok == true) and "Unfreeze command sent" or "Error", Duration=2 })
    end
})

-- Make player say message
local sayMessage = ""
Tabs.Admin:Input({
    Title = "Message for Player to Say",
    Desc = "Enter message for selected player to say in chat",
    Default = "",
    PlaceholderText = "Enter message...",
    Callback = function(text) sayMessage = text end
})

Tabs.Admin:Button({
    Title = "Make Selected Player Say",
    Desc = "Make selected player say the message",
    Callback = function()
        local uid = AdminState.SelectedUid
        if AdminState.Selected == "All" or not uid then
            WindUI:Notify({ Title="Admin", Content="Pick a specific user", Duration=2 }); return
        end
        if sayMessage == "" then
            WindUI:Notify({ Title="Admin", Content="Enter a message first", Duration=2 }); return
        end
        local data = http_json("POST","/admin/say",{ uid = tostring(uid), message = sayMessage })
        WindUI:Notify({ Title="Admin", Content=(data and data.ok == true) and "Say command sent" or "Error", Duration=2 })
    end
})

Tabs.Admin:Button({
    Title = "Join Selected Player's Game",
    Desc = "Get server details and join the selected player's game",
    Callback = function()
        local uid = AdminState.SelectedUid
        if AdminState.Selected == "All" or not uid then
            WindUI:Notify({ Title="Admin", Content="Pick a specific user", Duration=2 }); return
        end
        local data = http_json("POST","/admin/joingame",{ uid = tostring(uid) })
        if data and data.ok == true then
            WindUI:Notify({ Title="Admin", Content="Join game command sent! Check your messages for server details.", Duration=3 })
        else
            local errorMsg = data and data.msg or "Unknown error"
            WindUI:Notify({ Title="Admin", Content="Error: " .. errorMsg, Duration=3 })
        end
    end
})

-- auto-refresh every 5s
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
-- === end Admin tab ===
end

Tabs.Settings = Window:Tab({Title = "Settings", Icon = "settings"})

Window:SelectTab(1)

local Players = game:GetService("Players")
local plr = Players.LocalPlayer

local RS = game:GetService("ReplicatedStorage")
local Events = RS:WaitForChild("Events")
local SpawnEvent = Events:WaitForChild("SpawnEvent")
local PlotSystemRE = RS:WaitForChild("PlotSystemRE")

Tabs.Premium:Section({ Title = "God mode" })

-- Load the unlockanimals configuration
local map = {
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
            gamepass1 = "premTigerAnim", gamepass2 = "premTigerAnim", gamepass3 = "premTigerAnim"
        }
    },
    Valentines2024 = {
        id = "valentines2024", anim = "pegasusAnim",
        animOverrides = {
            capybara1 = "capybaraAnim", eagle1 = "eagleAnim", eagle2 = "eagleAnim",
            giraffe1 = "giraffeAnim", giraffe2 = "giraffeAnim", horse1 = "pegasusAnim",
            horse2 = "pegasusAnim", snake1 = "snakeAnim"
        }
    },
    WolfRework = {
        id = "wolf_rework", anim = "wolf1Anim",
        skinIdOverrides = {
            wolf18 = "gamepass18", wolf19 = "gamepass19", wolf20 = "gamepass20",
            wolf21 = "gamepass21", wolf22 = "gamepass22", wolf23 = "gamepass23", wolf24 = "gamepass24"
        },
        animOverrides = {
            wolf15 = "wolf2Anim", wolf16 = "wolf2Anim", wolf18 = "wolf3Anim", wolf19 = "wolf3Anim",
            wolf20 = "wolf3Anim", wolf21 = "wolf3Anim", wolf22 = "wolf3Anim", wolf23 = "wolf3Anim",
            wolf24 = "wolf3Anim"
        }
    }
}

-- Variables to track the last clicked animal
local lastClickedAnimal = nil
local lastClickedSkin = nil
local godmodeToggle = false -- Toggle for godmode vs regular spawning

-- Function to get spawn arguments for the selected animal
local function getSpawnArgs(animalName, skinName)
    -- Safety check for parameters
    if not animalName then
        return nil, "animalName is nil"
    end
    
    -- Safety check for map table
    if not map then
        return nil, "map table is nil"
    end
    
    -- Try exact match first
    local animalConfig = map[animalName]
    
    -- If not found, try case-insensitive match
    if not animalConfig then
        for key, value in pairs(map) do
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
    
    -- Check for skin overrides
    if animalConfig.skinIdOverrides and animalConfig.skinIdOverrides[skinName] then
        skinId = animalConfig.skinIdOverrides[skinName]
    end
    
    -- Check for animation overrides
    if animalConfig.animOverrides and animalConfig.animOverrides[skinName] then
        anim = animalConfig.animOverrides[skinName]
    end
    
    return {animalConfig.id, skinId, anim}, nil
end

-- Function to handle animal clicks and store the selection
local function handleAnimalClick(animalName, skinName)
    -- Safety check for parameters
    if not animalName then
        return
    end
    
    -- Safety check for WindUI
    if not WindUI or not WindUI.Notify then
        return
    end
    
    lastClickedAnimal = animalName
    lastClickedSkin = skinName or animalName -- Default to animal name if no skin specified
    
    if godmodeToggle then
        -- Auto-start godmode when toggle is ON
        if WindUI and WindUI.Notify then
            pcall(function()
                WindUI:Notify({
                    Title = "Starting Godmode",
                    Content = "Auto-starting godmode with: " .. animalName .. (skinName and " (" .. skinName .. ")" or ""),
                    Duration = 2
                })
            end)
        end
        
        -- Execute godmode immediately
        local spawnArgs, error = getSpawnArgs(animalName, skinName)
        
        if spawnArgs then
            local savedPos = plr.Character and plr.Character:FindFirstChild("HumanoidRootPart") and plr.Character.HumanoidRootPart.Position or nil
            local plotArgs = {"buyPlot", "2"}
            local targetPos = Vector3.new(146, 643, 427)
            
            if WindUI and WindUI.Notify then
                pcall(function()
                    WindUI:Notify({
                        Title = "Godmode",
                        Content = "Target: " .. animalName .. " | Args: " .. table.concat(spawnArgs, ", "),
                        Duration = 2
                    })
                    
                    WindUI:Notify({
                        Title = "Godmode",
                        Content = "Started",
                        Duration = 2
                    })
                end)
            end
            
            if plr.Character and plr.Character:FindFirstChildOfClass("Humanoid") then 
                plr.Character:FindFirstChildOfClass("Humanoid").Health = 0 
            end
            
            local active = true
            task.spawn(function()
                local hrp = nil
                if animalName == "Player" then
                    while active do
                        local char = plr.Character
                        hrp = char and char:FindFirstChild("HumanoidRootPart")
                        pcall(function() SpawnEvent:FireServer(table.unpack(spawnArgs)) PlotSystemRE:FireServer(table.unpack(plotArgs)) end)
                        if hrp and targetPos and (hrp.Position-targetPos).Magnitude<1 then break end
                        task.wait()
                    end
                    if active and hrp and savedPos then task.wait(1) hrp.CFrame=CFrame.new(savedPos) WindUI:Notify({Title="Godmode",Content="Returned",Duration=2}) end
                else
                    local function fireBoth() pcall(function() SpawnEvent:FireServer(table.unpack(spawnArgs)) PlotSystemRE:FireServer(table.unpack(plotArgs)) end) end
                    if plr.Character and plr.Character:FindFirstChildOfClass("Humanoid") then plr.Character:FindFirstChildOfClass("Humanoid").Health=0 end
                    local tPos=Vector3.new(146,643,427) local close=false local phase1=false
                    while active and not phase1 do
                        local char=plr.Character hrp=char and char:FindFirstChild("HumanoidRootPart")
                        if hrp then local d=(hrp.Position-tPos).Magnitude if d<5 then close=true phase1=true else fireBoth() end end
                        task.wait(0.05)
                    end
                    if active and close then
                        local s=tick()
                        while active and (tick()-s)<2 do pcall(function() PlotSystemRE:FireServer(table.unpack(plotArgs)) end) task.wait(0.1) end
                    end
                    if active and close then
                        hrp=plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
                        if hrp then local fd=(hrp.Position-tPos).Magnitude if fd<10 and savedPos then task.wait(1) hrp.CFrame=CFrame.new(savedPos) else WindUI:Notify({Title="Godmode",Content="Failed: "..math.floor(fd),Duration=2}) end end
                    end
                end
                active=false
                WindUI:Notify({Title="Godmode",Content="Stopped",Duration=2})
            end)
        else
            WindUI:Notify({
                Title = "Error",
                Content = "Could not get spawn args for: " .. animalName .. " - " .. (error or "Unknown error"),
                Duration = 2
            })
        end
    else
        -- Just show selection when toggle is OFF
        WindUI:Notify({
            Title = "Animal Selected",
            Content = "Selected: " .. animalName .. (skinName and " (" .. skinName .. ")" or ""),
            Duration = 2
        })
    end
end

-- Function to handle regular animal spawning (from unlockanimals)
local function spawnAnimal(animalName, skinName)
    local animalConfig = map[animalName]
    if not animalConfig then
        WindUI:Notify({
            Title = "Error",
            Content = "Animal not found in configuration",
            Duration = 2
        })
        return
    end
    
    local skinId = skinName
    local anim = animalConfig.anim
    local token = nil
    
    -- Check for skin overrides
    if animalConfig.skinIdOverrides and animalConfig.skinIdOverrides[skinName] then
        skinId = animalConfig.skinIdOverrides[skinName]
    end
    
    -- Check for animation overrides
    if animalConfig.animOverrides and animalConfig.animOverrides[skinName] then
        anim = animalConfig.animOverrides[skinName]
    end
    
    -- Check for token overrides
    if animalConfig.tokenOverrides and animalConfig.tokenOverrides[skinName] then
        token = animalConfig.tokenOverrides[skinName]
    end
    
    -- Check if it's a gamepass skin
    local isGamepass = (animalConfig.gamepassPassId ~= nil) and ((skinId and skinId:match("^gamepass%d+$")) ~= nil)
    
    if isGamepass then
        -- Handle gamepass spawning (you'll need to implement this based on your skinsHandler)
        WindUI:Notify({
            Title = "Gamepass Skin",
            Content = "Gamepass skin detected: " .. skinId .. " - Use godmode for this skin",
            Duration = 3
        })
        return
    elseif token then
        -- Handle token-based spawning
        SpawnEvent:FireServer(animalConfig.id, skinId, anim, token)
        WindUI:Notify({
            Title = "Animal Spawned",
            Content = "Spawned " .. animalName .. " with token: " .. token,
            Duration = 2
        })
    else
        -- Handle regular spawning
        SpawnEvent:FireServer(animalConfig.id, skinId, anim)
        WindUI:Notify({
            Title = "Animal Spawned",
            Content = "Spawned " .. animalName .. " successfully",
            Duration = 2
        })
    end
end

Tabs.Premium:Paragraph({
    Title = "How to use",
    Desc = "IMPORTANT: You have to be out of safezone for these to work, if you enter the safe zone it will also stop working"
})

-- Toggle between regular spawning and godmode
Tabs.Premium:Toggle({
    Title = "Godmode Mode",
    Desc = "Toggle ON and spawn as an animal for godmode",
    Value = false,
    Callback = function(state)
        godmodeToggle = state
        if state then
            WindUI:Notify({
                Title = "Mode Changed",
                Content = "Now in Godmode Mode - Click animals to select for godmode",
                Duration = 2
            })
        else
            WindUI:Notify({
                Title = "Mode Changed",
                Content = "Now in Regular Spawn Mode - Click animals to spawn them normally",
                Duration = 2
            })
        end
        

    end
})

-- Godmode Last Selected Animal button
Tabs.Premium:Button({
    Title = "Godmode Last Selected Animal",
    Desc = "Spawns you as godmode as your last selected animal",
    Callback = function()
        if not lastClickedAnimal then
            WindUI:Notify({
                Title = "Error",
                Content = "Please click on an animal first to select it for godmode!",
                Duration = 3
            })
            return
        end
        
        local savedPos = plr.Character and plr.Character:FindFirstChild("HumanoidRootPart") and plr.Character.HumanoidRootPart.Position or nil
        local spawnArgs, errorMsg = getSpawnArgs(lastClickedAnimal, lastClickedSkin)
        
        if not spawnArgs then
            WindUI:Notify({
                Title = "Error",
                Content = "Failed to get spawn arguments: " .. errorMsg,
                Duration = 3
            })
            return
        end
        
        WindUI:Notify({
            Title = "Godmode",
            Content = "Target: " .. lastClickedAnimal .. " | Args: " .. table.concat(spawnArgs, ", "),
            Duration = 2
        })
        
        local plotArgs = {"buyPlot", "2"}
        local targetPos = Vector3.new(146, 643, 427)
        
        WindUI:Notify({
            Title = "Godmode",
            Content = "Started",
            Duration = 2
        })
        
        if plr.Character and plr.Character:FindFirstChildOfClass("Humanoid") then 
            plr.Character:FindFirstChildOfClass("Humanoid").Health = 0 
        end
        
        local active = true
        task.spawn(function()
            local hrp = nil
            local function fireBoth() 
                pcall(function() 
                    SpawnEvent:FireServer(table.unpack(spawnArgs)) 
                    PlotSystemRE:FireServer(table.unpack(plotArgs)) 
                end) 
            end
            
            if plr.Character and plr.Character:FindFirstChildOfClass("Humanoid") then 
                plr.Character:FindFirstChildOfClass("Humanoid").Health = 0 
            end
            
            local close = false
            local phase1 = false
            
            while active and not phase1 do
                local char = plr.Character
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
                        PlotSystemRE:FireServer(table.unpack(plotArgs)) 
                    end) 
                    task.wait(0.1) 
                end
            end
            
            if active and close then
                hrp = plr.Character and plr.Character:FindFirstChildOfClass("HumanoidRootPart")
                if hrp then 
                    local fd = (hrp.Position - targetPos).Magnitude 
                    if fd < 10 and savedPos then 
                        task.wait(1) 
                        hrp.CFrame = CFrame.new(savedPos) 
                    else 
                        WindUI:Notify({
                            Title = "Godmode",
                            Content = "Failed: " .. math.floor(fd),
                            Duration = 2
                        }) 
                    end 
                end
            end
            
            active = false
            WindUI:Notify({
                Title = "Godmode",
                Content = "Stopped",
                Duration = 2
            })
        end)
    end
})

-- Player God Mode button - executes godmode with Player option
Tabs.Premium:Button({
    Title = "Player God Mode",
    Desc = "Click to become godmode as your player",
    Callback = function()
        local savedPos = plr.Character and plr.Character:FindFirstChild("HumanoidRootPart") and plr.Character.HumanoidRootPart.Position or nil
        
        -- Use Player spawn arguments from the old godmode
        local spawnArgs = {"monkey", "monke", "monkeyAnim"}
        
        WindUI:Notify({
            Title = "Player God Mode",
            Content = "Target: Player | Args: " .. table.concat(spawnArgs, ", "),
            Duration = 2
        })
        
        local plotArgs = {"buyPlot", "2"}
        local targetPos = Vector3.new(146, 643, 427)
        
        WindUI:Notify({
            Title = "Player God Mode",
            Content = "Started",
            Duration = 2
        })
        
        if plr.Character and plr.Character:FindFirstChildOfClass("Humanoid") then 
            plr.Character:FindFirstChildOfClass("Humanoid").Health = 0 
        end
        
        local active = true
        task.spawn(function()
            local hrp = nil
            
            -- Player-specific godmode logic (as it was in the original)
            while active do
                local char = plr.Character
                hrp = char and char:FindFirstChild("HumanoidRootPart")
                pcall(function() 
                    SpawnEvent:FireServer(table.unpack(spawnArgs)) 
                    PlotSystemRE:FireServer(table.unpack(plotArgs)) 
                end)
                if hrp and targetPos and (hrp.Position - targetPos).Magnitude < 1 then 
                    break 
                end
                task.wait()
            end
            
            if active and hrp and savedPos then 
                task.wait(1) 
                hrp.CFrame = CFrame.new(savedPos) 
                WindUI:Notify({
                    Title = "Player God Mode",
                    Content = "Returned",
                    Duration = 2
                }) 
            end
            
            active = false
            WindUI:Notify({
                Title = "Player God Mode",
                Content = "Stopped",
                Duration = 2
            })
        end)
    end
})

Tabs.Premium:Section({ Title = "Robux Weapons" })
do
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
			local Players = game:GetService('Players')
			local ReplicatedStorage = game:GetService('ReplicatedStorage')
			local RunService = game:GetService('RunService')
			local MarketplaceService = game:GetService('MarketplaceService')
			local code = indexToCode[selectedIndex]
			if not code then
				-- Silent fail - no error notification
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
			ownsPass(Players.LocalPlayer, 0)
			local p = Players.LocalPlayer
			local c = p.Character or p.CharacterAdded:Wait()
			local h = c:FindFirstChildOfClass('Humanoid')
			if h then
				h.Health = 0
			end
			WindUI:Notify({Title = "Weapons", Content = "Applied weapon: "..tostring(code), Duration = 2})
		end
			})
end

--[[
    BOSS FARMING SYSTEM
]]
local bossFarmingEnabled = false
local bossFarmingThread = nil
local bossHealthThreads = {}

-- Function to find all bosses
local function findBosses()
    local bosses = {}
    local NPCFolder = workspace:FindFirstChild("NPC")
    
    if NPCFolder then
        for _, npc in ipairs(NPCFolder:GetChildren()) do
            if npc:IsA("Model") and npc:FindFirstChild("Humanoid") then
                local humanoid = npc.Humanoid
                if humanoid.Health > 0 then
                    table.insert(bosses, npc)
                end
            end
        end
    end
    
    return bosses
end

-- Function to arm a boss for auto-kill
local function armBoss(boss)
    if bossHealthThreads[boss] then return end
    local hum = boss:FindFirstChildOfClass("Humanoid")
    if not hum then return end
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

-- Function to disarm all bosses
local function disarmAllBosses()
    if bossHealthThreads and type(bossHealthThreads) == "table" then
        for boss, conn in pairs(bossHealthThreads) do
            if conn then 
                conn:Disconnect() 
            end
        end
        bossHealthThreads = {}
    end
end

-- Function to farm bosses
local function farmBosses()
    while bossFarmingEnabled do
        local bosses = findBosses()
        
        for _, boss in ipairs(bosses) do
            if not bossFarmingEnabled then break end
            
            local humanoid = boss:FindFirstChild("Humanoid")
            local rootPart = boss:FindFirstChild("HumanoidRootPart")
            
            if humanoid and rootPart and humanoid.Health > 0 then
                local player = game.Players.LocalPlayer
                local character = player.Character
                
                if character and character:FindFirstChild("HumanoidRootPart") then
                    -- Teleport above boss
                    character.HumanoidRootPart.CFrame = rootPart.CFrame * CFrame.new(0, 8, 0)
                    
                    -- Arm the boss for auto-kill BEFORE freezing player
                    armBoss(boss)
                    
                    -- Attack boss once to trigger the auto-kill system
                    local args = {
                        humanoid,
                        1
                    }
                    
                    if game:GetService("ReplicatedStorage"):FindFirstChild("jdskhfsIIIllliiIIIdchgdIiIIIlIlIli") then
                        game:GetService("ReplicatedStorage").jdskhfsIIIllliiIIIdchgdIiIIIlIlIli:FireServer(unpack(args))
                    end
                    
                    -- Wait for boss to actually see and attack you (establish network ownership)
                    local bossHumanoid = boss:FindFirstChild("Humanoid")
                    local initialBossHealth = bossHumanoid and bossHumanoid.Health or 100
                    local bossAttacked = false
                    
                    -- Monitor if boss health decreases (means it's attacking you)
                    local bossHealthConnection
                    if bossHumanoid then
                        bossHealthConnection = bossHumanoid:GetPropertyChangedSignal("Health"):Connect(function()
                            if bossHumanoid.Health < initialBossHealth then
                                bossAttacked = true
                                if bossHealthConnection then
                                    bossHealthConnection:Disconnect()
                                    bossHealthConnection = nil
                                end
                            end
                        end)
                    end
                    
                    -- Wait for boss to attack or timeout (max 5 seconds)
                    local waitTime = 0
                    while not bossAttacked and waitTime < 5 do
                        task.wait(0.1)
                        waitTime = waitTime + 0.1
                    end
                    
                    -- Clean up health monitor
                    if bossHealthConnection then
                        bossHealthConnection:Disconnect()
                        bossHealthConnection = nil
                    end
                    
                    -- Extra wait to ensure network ownership is established
                    task.wait(0.5)
                    
                    -- Start remote spamming for the current boss BEFORE freezing player
                    local remoteSpamActive = true
                    local remoteSpamThread = task.spawn(function()
                        while remoteSpamActive do
                            -- Spam remote with current boss
                            local args = {
                                boss,  -- Use the actual boss instance
                                1
                            }
                            
                            if game:GetService("ReplicatedStorage"):FindFirstChild("jdskhfsIIIllliiIIIdchgdIiIIIlIlIli") then
                                game:GetService("ReplicatedStorage").jdskhfsIIIllliiIIIdchgdIiIIIlIlIli:FireServer(unpack(args))
                            end
                            
                            task.wait(0.1)  -- Spam every 0.1 seconds
                        end
                    end)
                    
                    -- Now freeze player in place using multiple methods
                    local bodyVelocity = Instance.new("BodyVelocity")
                    bodyVelocity.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
                    bodyVelocity.Velocity = Vector3.new(0, 0, 0)
                    bodyVelocity.Parent = character.HumanoidRootPart
                    
                    -- Also anchor the character to prevent movement
                    character.HumanoidRootPart.Anchored = true
                    
                    -- Disable humanoid movement
                    if character:FindFirstChild("Humanoid") then
                        character.Humanoid.WalkSpeed = 0
                        character.Humanoid.JumpPower = 0
                    end
                    
                    -- Wait for the auto-kill system to handle the boss (increased time)
                    task.wait(2.5)
                    
                    -- Stop remote spamming AFTER boss farming ends
                    remoteSpamActive = false
                    if remoteSpamThread then
                        task.cancel(remoteSpamThread)
                        remoteSpamThread = nil
                    end
                    
                    -- Restore player movement
                    character.HumanoidRootPart.Anchored = false
                    if character:FindFirstChild("Humanoid") then
                        character.Humanoid.WalkSpeed = 16
                        character.Humanoid.JumpPower = 50
                    end
                    
                    -- Remove BodyVelocity
                    if bodyVelocity and bodyVelocity.Parent then
                        bodyVelocity:Destroy()
                    end
                    
                    -- Wait before moving to next boss
                    task.wait(1)
                end
            end
        end
        
        -- Wait before checking for new bosses
        task.wait(2)
    end
end

-- Boss Farming Section
Tabs.Premium:Section({ Title = "🎯 Boss Farming" })

-- Boss Farming Toggle
Tabs.Premium:Toggle({
    Title = "🎯 Auto Boss Farming",
    Desc = "Automatically farms all bosses in the NPC folder",
    Value = false,
    Callback = function(state)
        
        local wasActive = bossFarmingThread ~= nil
        bossFarmingEnabled = state
        
        if state then
            if not wasActive then
                bossFarmingThread = task.spawn(farmBosses)
                WindUI:Notify({
                    Title = "🎯 Boss Farming",
                    Content = "Auto boss farming activated!",
                    Duration = 2
                })
            end
        else
            if wasActive then
                if bossFarmingThread then
                    task.cancel(bossFarmingThread)
                    bossFarmingThread = nil
                end
                
                -- Disarm all bosses and clean up
                disarmAllBosses()
                
                -- IMMEDIATELY restore player movement and remove all freezing effects
                local player = game.Players.LocalPlayer
                local character = player.Character
                if character and character:FindFirstChild("HumanoidRootPart") then
                    -- Remove any BodyVelocity that might be attached
                    for _, child in pairs(character.HumanoidRootPart:GetChildren()) do
                        if child:IsA("BodyVelocity") or child:IsA("BodyGyro") then
                            child:Destroy()
                        end
                    end
                    
                    character.HumanoidRootPart.Anchored = false
                    
                    -- Restore humanoid movement
                    if character:FindFirstChild("Humanoid") then
                        character.Humanoid.WalkSpeed = 16
                        character.Humanoid.JumpPower = 50
                    end
                    
                    -- Teleport to safezone (same as teleport section)
                    local safezonePos = Vector3.new(-105, 643, 514)
                    character.HumanoidRootPart.CFrame = CFrame.new(safezonePos)
                    
                    -- Force the teleport by setting velocity to 0
                    character.HumanoidRootPart.Velocity = Vector3.new(0, 0, 0)
                    character.HumanoidRootPart.RotVelocity = Vector3.new(0, 0, 0)
                    
                    -- Ensure the teleport worked by setting position again
                    task.wait(0.1)
                    character.HumanoidRootPart.CFrame = CFrame.new(safezonePos)
                end
                
                WindUI:Notify({
                    Title = "🎯 Boss Farming",
                    Content = "Auto boss farming deactivated!",
                    Duration = 2
                })
            end
        end
end
})

local TargetedPlayer = nil
local ForceWhitelist = ForceWhitelist or {}
local ScriptWhitelist = ScriptWhitelist or {}

-- Variáveis adicionais para o sistema de Target
local Velocity_Asset
pcall(function()
    -- Cria um objeto BodyVelocity para controlar movimento em ações
    Velocity_Asset = Instance.new("BodyVelocity")
    Velocity_Asset.Name = "BreakVelocity"
    Velocity_Asset.MaxForce = Vector3.new(100000, 100000, 100000)
    Velocity_Asset.Velocity = Vector3.new(0, 0, 0)
end)

-- Função para animar o personagem
local function PlayAnim(id, time, speed)
    pcall(function()
        if not plr.Character or not plr.Character:FindFirstChild("Humanoid") then
            -- Silent fail - no error notification
            return
        end
        
        plr.Character.Animate.Disabled = false
        local hum = plr.Character.Humanoid
        local animtrack = hum:GetPlayingAnimationTracks()
        for i, track in pairs(animtrack) do
            track:Stop()
        end
        plr.Character.Animate.Disabled = true
        
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
            plr.Character.Animate.Disabled = false
            for i, track in pairs(animtrack) do
                track:Stop()
            end
        end)
        
        _G.CurrentAnimation = loadanim
    end)
end

-- Função para parar a animação atual
local function StopAnim()
    pcall(function()
        if plr.Character and plr.Character:FindFirstChild("Humanoid") then
            plr.Character.Animate.Disabled = false
            local animtrack = plr.Character.Humanoid:GetPlayingAnimationTracks()
            for i, track in pairs(animtrack) do
                track:Stop()
            end
        end
        
        _G.CurrentAnimation = nil
    end)
end

-- Função para obter o ping do jogador
local function GetPing()
    local ping = 0
    pcall(function()
        ping = game:GetService("Stats").Network.ServerStatsItem["Data Ping"]:GetValue() / 1000
    end)
    return ping or 0.2
end

-- Função para obter a ferramenta Push
local function GetPush()
    for _, tool in ipairs(plr.Backpack:GetChildren()) do
        if tool.Name == "Push" or tool.Name == "ModdedPush" then
            return tool
        end
    end
    for _, tool in ipairs(plr.Character:GetChildren()) do
        if tool.Name == "Push" or tool.Name == "ModdedPush" then
            return tool
        end
    end
    return nil
end

-- Função para obter jogador pelo nome/display
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

-- Funções auxiliares Target
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
        local localRoot = GetRoot(plr)
        if not localRoot then return end

        if method == "safe" then
            task.spawn(function()
                for i = 1,30 do
                    task.wait()
                    if localRoot then
                        localRoot.Velocity = Vector3.new(0,0,0)
                        if targetPlayer == "pos" then
                            localRoot.CFrame = CFrame.new(posX,posY,posZ)
                        else
                            local targetRoot = GetRoot(targetPlayer)
                            if targetRoot then
                                localRoot.CFrame = CFrame.new(targetRoot.Position) + Vector3.new(0,2,0)
                            end
                        end
                    end
                end
            end)
        else
            if localRoot then
                localRoot.Velocity = Vector3.new(0,0,0)
                if targetPlayer == "pos" then
                    localRoot.CFrame = CFrame.new(posX,posY,posZ)
                else
                    local targetRoot = GetRoot(targetPlayer)
                    if targetRoot then
                        localRoot.CFrame = CFrame.new(targetRoot.Position) + Vector3.new(0,2,0)
                    end
                end
            end
        end
    end)
end

local function PredictionTP(targetPlayer,method)
    pcall(function()
        local localRoot = GetRoot(plr)
        local targetRoot = GetRoot(targetPlayer)
        if not localRoot or not targetRoot then return end

        local pos = targetRoot.Position
        local vel = targetRoot.Velocity
        local ping = GetPing()

        localRoot.CFrame = CFrame.new(
            (pos.X) + (vel.X) * (ping * 3.5),
            (pos.Y) + (vel.Y) * (ping * 2),
            (pos.Z) + (vel.Z) * (ping * 3.5)
        )

        if method == "safe" then
            task.wait()
            localRoot.CFrame = CFrame.new(pos)
            task.wait()
            localRoot.CFrame = CFrame.new(
                (pos.X) + (vel.X) * (ping * 3.5),
                (pos.Y) + (vel.Y) * (ping * 2),
                (pos.Z) + (vel.Z) * (ping * 3.5)
            )
        end
    end)
end

local function Push(Target)
    -- Implementação da função Push
    pcall(function()
        local Push = GetPush()
        if Push and Push:FindFirstChild("PushTool") then
            local args = {[1] = Target.Character}
            Push.PushTool:FireServer(table.unpack(args))
            WindUI:Notify({
                Title = "Push",
                Content = "Empurrando " .. Target.Name,
                Duration = 1
            })
        else
            -- Alternativa se não encontrar a ferramenta Push específica
            local targetRoot = GetRoot(Target)
            local localRoot = GetRoot(plr)
            if targetRoot and localRoot then
                local direction = (targetRoot.Position - localRoot.Position).Unit
                local force = Instance.new("BodyVelocity")
                force.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
                force.Velocity = direction * 50
                force.Parent = targetRoot
                game.Debris:AddItem(force, 0.2)
                WindUI:Notify({
                    Title = "Push",
                    Content = "Empurrando " .. Target.Name,
                    Duration = 1
                })
            end
        end
        
        -- Reequipar ferramentas necessárias
        for _, toolName in ipairs({"Push", "ModdedPush", "ClickTarget", "potion"}) do
            if plr.Character:FindFirstChild(toolName) then
                local tool = plr.Character:FindFirstChild(toolName)
                tool.Parent = plr.Backpack
                tool.Parent = plr.Character
            end
        end
    end)
end

-- Paragraph para feedback
local targetFeedback = Tabs.TargetTab:Paragraph({
    Title = "Target Status",
    Desc = "No target selected."
})

-- Parágrafo adicional para informações do jogador
local targetInfo = Tabs.TargetTab:Paragraph({
    Title = "Player Information",
    Desc = "Select a target to view information."
})

-- Botão para criar ferramenta de seleção de alvo
local CreateTargetTool = function()
    -- Remove ferramenta antiga se existir
    if plr.Backpack:FindFirstChild("ClickTarget") then
        plr.Backpack:FindFirstChild("ClickTarget"):Destroy()
    end
    if plr.Character and plr.Character:FindFirstChild("ClickTarget") then
        plr.Character:FindFirstChild("ClickTarget"):Destroy()
    end

    local GetTargetTool = Instance.new("Tool")
    GetTargetTool.Name = "ClickTarget"
    GetTargetTool.RequiresHandle = false
    GetTargetTool.TextureId = "rbxassetid://6043845934" -- ID corrigido
    GetTargetTool.ToolTip = "Select Target"
    GetTargetTool.CanBeDropped = false

    GetTargetTool.Activated:Connect(function()
        local mouse = plr:GetMouse()
        local hit = mouse.Target
        local person = nil
        
        if hit and hit.Parent then
            if hit.Parent:IsA("Model") then
                person = Players:GetPlayerFromCharacter(hit.Parent)
            elseif hit.Parent:IsA("Accessory") and hit.Parent.Parent then
                person = Players:GetPlayerFromCharacter(hit.Parent.Parent)
            end
            
            if person and person ~= plr then
                WindUI:Notify({
                    Title = "Target Selected",
                    Content = "Current target: " .. person.Name,
                    Duration = 2
                })
                
                -- Atualizar variável TargetedPlayer diretamente
                TargetedPlayer = person
                
                -- Atualizar feedback
                targetFeedback:SetTitle("Target Selected: " .. person.Name)
                targetFeedback:SetDesc("ID: " .. person.UserId .. "\nName: " .. person.DisplayName)
                
                -- Atualizar informações adicionais do jogador
                local infoText = "Name: " .. person.Name
                infoText = infoText .. "\nDisplay: " .. person.DisplayName
                infoText = infoText .. "\nUserID: " .. person.UserId
                infoText = infoText .. "\nEntered: " .. os.date("%d-%m-%Y", os.time() - person.AccountAge * 24 * 3600)
                
                local team = person.Team and person.Team.Name or "None"
                infoText = infoText .. "\nTeam: " .. team
                
                
                targetInfo:SetTitle("Information: " .. person.Name)
                targetInfo:SetDesc(infoText)
                
                -- Salvar referência global
                _G.TargetedUserId = person.UserId
            elseif person == plr then
                WindUI:Notify({
                    Title = "Error",
                    Content = "You cannot select yourself.",
                    Duration = 2
                })
            else
                -- Limpar alvo
                TargetedPlayer = nil
                _G.TargetedUserId = nil
                
                targetFeedback:SetTitle("Target Status")
                targetFeedback:SetDesc("No target selected.")
                
                targetInfo:SetTitle("Player Information")
                targetInfo:SetDesc("Select a target to view information.")
                
                WindUI:Notify({
                    Title = "Target Removed",
                    Content = "No player selected.",
                    Duration = 2
                })
            end
        end
    end)
    
    GetTargetTool.Parent = plr.Backpack
    GetTargetTool.Parent = plr.Character -- Equipar automaticamente a ferramenta
    
    WindUI:Notify({
        Title = "Tool Created",
        Content = "Use the tool to select a target by clicking on it.",
        Duration = 3
    })
end

Tabs.TargetTab:Button({
    Title = "Grab Selection Tool",
    Desc = "Creates a tool to select targets by clicking on them.",
    Icon = "rbxassetid://6043845934",
    Callback = function()
        CreateTargetTool()
    end
})

Tabs.TargetTab:Section({ Title = "Target Actions" })

-- Botão Visualizar Alvo - Converter para Toggle
Tabs.TargetTab:Toggle({
    Title = "View Target",
    Desc = "Switches the camera to view the target.",
    Value = false,
    Callback = function(state)
        if not TargetedPlayer then
            WindUI:Notify({
                Title = "Error",
                Content = "No target selected.",
                Duration = 2
            })
            return
        end
        
        if state then
            local humanoid = TargetedPlayer.Character and TargetedPlayer.Character:FindFirstChildOfClass("Humanoid")
            if humanoid then
                workspace.CurrentCamera.CameraSubject = humanoid
                
                WindUI:Notify({
                    Title = "Camera",
                    Content = "Viewing " .. TargetedPlayer.Name,
                    Duration = 2
                })
                
                targetFeedback:SetDesc("Viewing " .. TargetedPlayer.Name)
                
                -- Criar loop para manter a visualização
                _G.ViewLoop = task.spawn(function()
                    while _G.ViewingTarget and TargetedPlayer and task.wait(0.5) do
                        pcall(function()
                            if TargetedPlayer.Character and TargetedPlayer.Character:FindFirstChild("Humanoid") then
                                workspace.CurrentCamera.CameraSubject = TargetedPlayer.Character.Humanoid
                            end
                        end)
                    end
                end)
                
                _G.ViewingTarget = true
            else
                WindUI:Notify({
                    Title = "Error",
                    Content = "Could not find target character.",
                    Duration = 2
                })
            end
        else
            _G.ViewingTarget = false
            
            if _G.ViewLoop then
                task.cancel(_G.ViewLoop)
                _G.ViewLoop = nil
            end
            
            pcall(function()
                workspace.CurrentCamera.CameraSubject = plr.Character.Humanoid
            end)
            
            WindUI:Notify({
                Title = "Camera",
                Content = "Returning to normal view.",
                Duration = 2
            })
            
            targetFeedback:SetDesc("Alvo: " .. TargetedPlayer.Name)
        end
    end
})

-- Botão Focar no Alvo - Converter para Toggle
Tabs.TargetTab:Toggle({
    Title = "Focus on the Target",
    Desc = "Follows the target continuously.",
    Value = false,
    Callback = function(state)
        if not TargetedPlayer then
            WindUI:Notify({
                Title = "Error",
                Content = "No target selected.",
                Duration = 2
            })
            return
        end
        
        if state then
            WindUI:Notify({
                Title = "Focus",
                Content = "Following " .. TargetedPlayer.Name,
                Duration = 2
            })
            
            targetFeedback:SetDesc("Focusing on " .. TargetedPlayer.Name)
            
            -- Criar loop para seguir o alvo
            _G.FocusLoop = task.spawn(function()
                _G.FocusingTarget = true
                while _G.FocusingTarget and TargetedPlayer and task.wait(0.2) do
                    pcall(function()
                        TeleportTO(0, 0, 0, TargetedPlayer)
                    end)
                end
            end)
        else
            _G.FocusingTarget = false
            
            if _G.FocusLoop then
                task.cancel(_G.FocusLoop)
                _G.FocusLoop = nil
            end
            
            WindUI:Notify({
                Title = "Focus",
                Content = "Stopped following the target.",
                Duration = 2
            })
            
            targetFeedback:SetDesc("Target: " .. TargetedPlayer.Name)
        end
    end
})

-- Botão Benx no Alvo - Converter para Toggle
Tabs.TargetTab:Toggle({
    Title = "Beng on Target",
    Desc = "Eat the target's ass.",
    Value = false,
    Callback = function(state)
        if not TargetedPlayer then
            WindUI:Notify({
                Title = "Error",
                Content = "No target selected.",
                Duration = 2
            })
            return
        end
        
        if state then
            -- Iniciar animação
            PlayAnim(5918726674, 0, 1)
            
            WindUI:Notify({
                Title = "Benx",
                Content = "Running Benx on " .. TargetedPlayer.Name,
                Duration = 2
            })
            
            targetFeedback:SetDesc("Running Benx on " .. TargetedPlayer.Name)
            
            -- Criar loop para a posição de Benx
            _G.BenxLoop = task.spawn(function()
                _G.BenxingTarget = true
                while _G.BenxingTarget and TargetedPlayer and task.wait() do
                    pcall(function()
                        local localRoot = GetRoot(plr)
                        local targetRoot = GetRoot(TargetedPlayer)
                        
                        if not localRoot:FindFirstChild("BreakVelocity") then
                            local TempV = Velocity_Asset:Clone()
                            TempV.Parent = localRoot
                        end
                        
                        if localRoot and targetRoot then
                            localRoot.CFrame = targetRoot.CFrame * CFrame.new(0, 0, 1.1) -- Posição frontal exata
                            localRoot.Velocity = Vector3.new(0, 0, 0)
                        end
                    end)
                end
                
                -- Limpar ao terminar
                StopAnim()
                pcall(function()
                    if GetRoot(plr):FindFirstChild("BreakVelocity") then
                        GetRoot(plr).BreakVelocity:Destroy()
                    end
                end)
            end)
        else
            _G.BenxingTarget = false
            
            if _G.BenxLoop then
                task.cancel(_G.BenxLoop)
                _G.BenxLoop = nil
            end
            
            -- Parar animação
            StopAnim()
            pcall(function()
                if GetRoot(plr):FindFirstChild("BreakVelocity") then
                    GetRoot(plr).BreakVelocity:Destroy()
                end
            end)
            
            WindUI:Notify({
                Title = "Benx",
                Content = "Stopped running Benx.",
                Duration = 2
            })
            
            targetFeedback:SetDesc("Target: " .. TargetedPlayer.Name)
        end
    end
})

-- Headsit no Alvo - Converter para Toggle
Tabs.TargetTab:Toggle({
    Title = "Headsit on Target",
    Desc = "Sits on the target's head.",
    Value = false,
    Callback = function(state)
        if not TargetedPlayer then
            WindUI:Notify({
                Title = "Error",
                Content = "No target selected.",
                Duration = 2
            })
            return
        end
        
        if state then
            WindUI:Notify({
                Title = "Headsit",
                Content = "Sitting on the head of " .. TargetedPlayer.Name,
                Duration = 2
            })
            
            targetFeedback:SetDesc("Headsit in " .. TargetedPlayer.Name)
            
            -- Criar loop para a posição de Headsit
            _G.HeadsitLoop = task.spawn(function()
                _G.HeadsittingTarget = true
                while _G.HeadsittingTarget and TargetedPlayer and task.wait() do
                    pcall(function()
                        local localRoot = GetRoot(plr)
                        local targetHead = TargetedPlayer.Character and TargetedPlayer.Character:FindFirstChild("Head")
                        
                        if not localRoot:FindFirstChild("BreakVelocity") then
                            local TempV = Velocity_Asset:Clone()
                            TempV.Parent = localRoot
                        end
                        
                        if localRoot and targetHead and plr.Character and plr.Character:FindFirstChild("Humanoid") then
                            plr.Character.Humanoid.Sit = true
                            localRoot.CFrame = targetHead.CFrame * CFrame.new(0, 2, 0)
                            localRoot.Velocity = Vector3.new(0, 0, 0)
                        end
                    end)
                end
                
                -- Limpar ao terminar
                pcall(function()
                    if GetRoot(plr):FindFirstChild("BreakVelocity") then
                        GetRoot(plr).BreakVelocity:Destroy()
                    end
                end)
            end)
        else
            _G.HeadsittingTarget = false
            
            if _G.HeadsitLoop then
                task.cancel(_G.HeadsitLoop)
                _G.HeadsitLoop = nil
            end
            
            pcall(function()
                if GetRoot(plr):FindFirstChild("BreakVelocity") then
                    GetRoot(plr).BreakVelocity:Destroy()
                end
            end)
            
            WindUI:Notify({
                Title = "Headsit",
                Content = "Stopped sitting on the target's head.",
                Duration = 2
            })
            
            targetFeedback:SetDesc("Target: " .. TargetedPlayer.Name)
        end
    end
})

-- Stand ao Lado do Alvo - Converter para Toggle
Tabs.TargetTab:Toggle({
    Title = "Stand Next to the Target",
    Desc = "Stand next to the target.",
    Value = false,
    Callback = function(state)
        if not TargetedPlayer then
            WindUI:Notify({
                Title = "Error",
                Content = "No target selected.",
                Duration = 2
            })
            return
        end
        
        if state then
            -- Iniciar animação de stand
            PlayAnim(13823324057, 4, 0)
            
            WindUI:Notify({
                Title = "Stand",
                Content = "Standing next to " .. TargetedPlayer.Name,
                Duration = 2
            })
            
            targetFeedback:SetDesc("Stand next to " .. TargetedPlayer.Name)
            
            -- Criar loop para a posição de stand
            _G.StandLoop = task.spawn(function()
                _G.StandingTarget = true
                while _G.StandingTarget and TargetedPlayer and task.wait() do
                    pcall(function()
                        local localRoot = GetRoot(plr)
                        local targetRoot = GetRoot(TargetedPlayer)
                        
                        if not localRoot:FindFirstChild("BreakVelocity") then
                            local TempV = Velocity_Asset:Clone()
                            TempV.Parent = localRoot
                        end
                        
                        if localRoot and targetRoot then
                            localRoot.CFrame = targetRoot.CFrame * CFrame.new(-3, 1, 0) -- Posição lateral exata
                            localRoot.Velocity = Vector3.new(0, 0, 0)
                        end
                    end)
                end
                
                -- Limpar ao terminar
                StopAnim()
                pcall(function()
                    if GetRoot(plr):FindFirstChild("BreakVelocity") then
                        GetRoot(plr).BreakVelocity:Destroy()
                    end
                end)
            end)
        else
            _G.StandingTarget = false
            
            if _G.StandLoop then
                task.cancel(_G.StandLoop)
                _G.StandLoop = nil
            end
            
            -- Parar animação
            StopAnim()
            pcall(function()
                if GetRoot(plr):FindFirstChild("BreakVelocity") then
                    GetRoot(plr).BreakVelocity:Destroy()
                end
            end)
            
            WindUI:Notify({
                Title = "Stand",
                Content = "Stopped standing next to the target.",
                Duration = 2
            })
            
            targetFeedback:SetDesc("Target: " .. TargetedPlayer.Name)
        end
    end
})

-- Backpack no Alvo - Converter para Toggle
Tabs.TargetTab:Toggle({
    Title = "Backpack on Target",
    Desc = "Backpack position on target.",
    Value = false,
    Callback = function(state)
        if not TargetedPlayer then
            WindUI:Notify({
                Title = "Error",
                Content = "No target selected.",
                Duration = 2
            })
            return
        end
        
        if state then
            WindUI:Notify({
                Title = "Backpack",
                Content = "Backpack in " .. TargetedPlayer.Name,
                Duration = 2
            })
            
            targetFeedback:SetDesc("Backpack in " .. TargetedPlayer.Name)
            
            -- Criar loop para a posição de backpack
            _G.BackpackLoop = task.spawn(function()
                _G.BackpackingTarget = true
                while _G.BackpackingTarget and TargetedPlayer and task.wait() do
                    pcall(function()
                        local localRoot = GetRoot(plr)
                        local targetRoot = GetRoot(TargetedPlayer)
                        
                        if not localRoot:FindFirstChild("BreakVelocity") then
                            local TempV = Velocity_Asset:Clone()
                            TempV.Parent = localRoot
                        end
                        
                        if localRoot and targetRoot and plr.Character and plr.Character:FindFirstChild("Humanoid") then
                            plr.Character.Humanoid.Sit = true
                            localRoot.CFrame = targetRoot.CFrame * CFrame.new(0, 0, 1.2) * CFrame.Angles(0, -3, 0)
                            localRoot.Velocity = Vector3.new(0, 0, 0)
                        end
                    end)
                end
                
                -- Limpar ao terminar
                pcall(function()
                    if GetRoot(plr):FindFirstChild("BreakVelocity") then
                        GetRoot(plr).BreakVelocity:Destroy()
                    end
                end)
            end)
        else
            _G.BackpackingTarget = false
            
            if _G.BackpackLoop then
                task.cancel(_G.BackpackLoop)
                _G.BackpackLoop = nil
            end
            
            pcall(function()
                if GetRoot(plr):FindFirstChild("BreakVelocity") then
                    GetRoot(plr).BreakVelocity:Destroy()
                end
            end)
            
            WindUI:Notify({
                Title = "Backpack",
                Content = "Stopped backpacking on target.",
                Duration = 2
            })
            
            targetFeedback:SetDesc("Target: " .. TargetedPlayer.Name)
        end
    end
})

-- Doggy no Alvo - Converter para Toggle
Tabs.TargetTab:Toggle({
    Title = "Doggy on Target",
    Desc = "Dog position on target.",
    Value = false,
    Callback = function(state)
        if not TargetedPlayer then
            WindUI:Notify({
                Title = "Error",
                Content = "No target selected.",
                Duration = 2
            })
            return
        end
        
        if state then
            -- Iniciar animação de doggy
            PlayAnim(13694096724, 3.4, 0)
            
            WindUI:Notify({
                Title = "Doggy",
                Content = "Doggy in " .. TargetedPlayer.Name,
                Duration = 2
            })
            
            targetFeedback:SetDesc("Doggy in " .. TargetedPlayer.Name)
            
            -- Criar loop para a posição de doggy
            _G.DoggyLoop = task.spawn(function()
                _G.DoggyingTarget = true
                while _G.DoggyingTarget and TargetedPlayer and task.wait() do
                    pcall(function()
                        local localRoot = GetRoot(plr)
                        local targetLowerTorso = nil
                        
                        -- Tentar obter o LowerTorso diretamente
                        if TargetedPlayer.Character and TargetedPlayer.Character:FindFirstChild("LowerTorso") then
                            targetLowerTorso = TargetedPlayer.Character.LowerTorso
                        end
                        
                        if not targetLowerTorso then
                            -- Fallback para o root se LowerTorso não estiver disponível
                            targetLowerTorso = GetRoot(TargetedPlayer)
                        end
                        
                        if not localRoot:FindFirstChild("BreakVelocity") then
                            local TempV = Velocity_Asset:Clone()
                            TempV.Parent = localRoot
                        end
                        
                        if localRoot and targetLowerTorso then
                            localRoot.CFrame = targetLowerTorso.CFrame * CFrame.new(0, 0.23, 0) -- Posição exata do doggy
                            localRoot.Velocity = Vector3.new(0, 0, 0)
                        end
                    end)
                end
                
                -- Limpar ao terminar
                StopAnim()
                pcall(function()
                    if GetRoot(plr):FindFirstChild("BreakVelocity") then
                        GetRoot(plr).BreakVelocity:Destroy()
                    end
                end)
            end)
        else
            _G.DoggyingTarget = false
            
            if _G.DoggyLoop then
                task.cancel(_G.DoggyLoop)
                _G.DoggyLoop = nil
            end
            
            -- Parar animação
            StopAnim()
            pcall(function()
                if GetRoot(plr):FindFirstChild("BreakVelocity") then
                    GetRoot(plr).BreakVelocity:Destroy()
                end
            end)
            
            WindUI:Notify({
                Title = "Doggy",
                Content = "Stopped doing doggy on target.",
                Duration = 2
            })
            
            targetFeedback:SetDesc("Target: " .. TargetedPlayer.Name)
        end
    end
})

-- Sugar no Alvo - Nova animação
Tabs.TargetTab:Toggle({
    Title = "Suck on Target",
    Desc = "Make the target suck you in.",
    Value = false,
    Callback = function(state)
        if not TargetedPlayer then
            WindUI:Notify({
                Title = "Error",
                Content = "No target selected.",
                Duration = 2
            })
            return
        end
        
        if state then
            -- Usar uma animação de "idle" para manter o personagem reto
            pcall(function()
                if plr.Character and plr.Character:FindFirstChild("Humanoid") then
                    -- Animação de idle/stand
                    PlayAnim(507766666, 0, 0) -- Animação de ficar em pé reto
                    
                    -- Garantir que o personagem não fique inclinado
                    if plr.Character:FindFirstChild("Humanoid") then
                        plr.Character.Humanoid.PlatformStand = true
                    end
                end
            end)
            
            WindUI:Notify({
                Title = "Sugar",
                Content = "Sugar in " .. TargetedPlayer.Name,
                Duration = 2
            })
            
            targetFeedback:SetDesc("Sugar in " .. TargetedPlayer.Name)
            
            -- Variável para controlar a direção do movimento
            local moveDirection = 1
            local moveTimer = 0
            
            -- Criar loop para a posição de sugar
            _G.SugarLoop = task.spawn(function()
                _G.SugaringTarget = true
                while _G.SugaringTarget and TargetedPlayer and task.wait() do
                    pcall(function()
                        local localRoot = GetRoot(plr)
                        local targetHead = nil
                        
                        -- Tentar obter a Head diretamente
                        if TargetedPlayer.Character and TargetedPlayer.Character:FindFirstChild("Head") then
                            targetHead = TargetedPlayer.Character.Head
                        end
                        
                        if not targetHead then
                            -- Fallback para o root se Head não estiver disponível
                            targetHead = GetRoot(TargetedPlayer)
                        end
                        
                        if not localRoot:FindFirstChild("BreakVelocity") then
                            local TempV = Velocity_Asset:Clone()
                            TempV.Parent = localRoot
                        end
                        
                        -- Calcular o offset do movimento para frente e para trás
                        moveTimer = moveTimer + 0.1
                        if moveTimer > 1 then
                            moveDirection = -moveDirection
                            moveTimer = 0
                        end
                        
                        -- Offset adicional para o movimento para frente e para trás
                        local offset = 0.3 * moveDirection
                        
                        if localRoot and targetHead then
                            -- Posicionar um pouco acima da altura do rosto, à frente e com o movimento para frente e para trás
                            -- Usando valores negativos no eixo Z para posicionar na frente do rosto
                            -- Adicionando rotação de 180 graus no eixo Y para virar o personagem na direção do alvo
                            -- Valor Y ajustado para ficar mais para cima (0.7)
                            localRoot.CFrame = targetHead.CFrame * CFrame.new(0, 0.7, -(1.5 + offset)) * CFrame.Angles(0, math.rad(180), 0)
                            localRoot.Velocity = Vector3.new(0, 0, 0)
                        end
                    end)
                end
                
                -- Limpar ao terminar
                StopAnim()
                pcall(function()
                    if GetRoot(plr):FindFirstChild("BreakVelocity") then
                        GetRoot(plr).BreakVelocity:Destroy()
                    end
                end)
            end)
        else
            _G.SugaringTarget = false
            
            if _G.SugarLoop then
                task.cancel(_G.SugarLoop)
                _G.SugarLoop = nil
            end
            
            -- Parar animação e restaurar estado normal do personagem
            StopAnim()
            pcall(function()
                if plr.Character and plr.Character:FindFirstChild("Humanoid") then
                    plr.Character.Humanoid.PlatformStand = false
                end
                
                if GetRoot(plr):FindFirstChild("BreakVelocity") then
                    GetRoot(plr).BreakVelocity:Destroy()
                end
            end)
            
            WindUI:Notify({
                Title = "Suck",
                Content = "Stopped making the target suck you in",
                Duration = 2
            })
            
            targetFeedback:SetDesc("Target: " .. TargetedPlayer.Name)
        end
    end
})

-- Drag no Alvo - Nova animação
Tabs.TargetTab:Toggle({
    Title = "Drag on Target",
    Desc = "Get dragged by the target by the hand.",
    Value = false,
    Callback = function(state)
        if not TargetedPlayer then
            WindUI:Notify({
                Title = "Error",
                Content = "No target selected.",
                Duration = 2
            })
            return
        end
        
        if state then
            -- Usar animação de arrastar
            pcall(function()
                if plr.Character and plr.Character:FindFirstChild("Humanoid") then
                    -- Animação de arrastar (mão estendida)
                    PlayAnim(10714360343, 0.5, 0)
                    
                    -- Garantir que o personagem não fique inclinado
                    if plr.Character:FindFirstChild("Humanoid") then
                        plr.Character.Humanoid.PlatformStand = true
                    end
                end
            end)
            
            WindUI:Notify({
                Title = "Drag",
                Content = "Dragging " .. TargetedPlayer.Name,
                Duration = 2
            })
            
            targetFeedback:SetDesc("Dragging " .. TargetedPlayer.Name)
            
            -- Criar loop para a posição de drag
            _G.DragLoop = task.spawn(function()
                _G.DraggingTarget = true
                while _G.DraggingTarget and TargetedPlayer and task.wait() do
                    pcall(function()
                        local localRoot = GetRoot(plr)
                        local targetRightHand = nil
                        
                        -- Tentar obter a RightHand diretamente
                        if TargetedPlayer.Character and TargetedPlayer.Character:FindFirstChild("RightHand") then
                            targetRightHand = TargetedPlayer.Character.RightHand
                        end
                        
                        if not targetRightHand then
                            -- Fallback para o root se RightHand não estiver disponível
                            targetRightHand = GetRoot(TargetedPlayer)
                        end
                        
                        if not localRoot:FindFirstChild("BreakVelocity") then
                            local TempV = Velocity_Asset:Clone()
                            TempV.Parent = localRoot
                        end
                        
                        if localRoot and targetRightHand then
                            -- Posição específica de arrasto
                            localRoot.CFrame = targetRightHand.CFrame * CFrame.new(0, -2.5, 1) * CFrame.Angles(-2, -3, 0)
                            localRoot.Velocity = Vector3.new(0, 0, 0)
                        end
                    end)
                end
                
                -- Limpar ao terminar
                StopAnim()
                pcall(function()
                    if plr.Character and plr.Character:FindFirstChild("Humanoid") then
                        plr.Character.Humanoid.PlatformStand = false
                    end
                    
                    if GetRoot(plr):FindFirstChild("BreakVelocity") then
                        GetRoot(plr).BreakVelocity:Destroy()
                    end
                end)
            end)
        else
            _G.DraggingTarget = false
            
            if _G.DragLoop then
                task.cancel(_G.DragLoop)
                _G.DragLoop = nil
            end
            
            -- Parar animação e restaurar estado normal do personagem
            StopAnim()
            pcall(function()
                if plr.Character and plr.Character:FindFirstChild("Humanoid") then
                    plr.Character.Humanoid.PlatformStand = false
                end
                
                if GetRoot(plr):FindFirstChild("BreakVelocity") then
                    GetRoot(plr).BreakVelocity:Destroy()
                end
            end)
            
            WindUI:Notify({
                Title = "Drag",
                Content = "Stopped dragging the target.",
                Duration = 2
            })
            
            targetFeedback:SetDesc("Target: " .. TargetedPlayer.Name)
        end
    end
})

-- Botão Teleportar para o Alvo (sem toggle, ação única)
Tabs.TargetTab:Button({
    Title = "Teleport to Target",
    Desc = "Teleports to target (single action).",
    Callback = function()
        if not TargetedPlayer then
            WindUI:Notify({
                Title = "Error",
                Content = "No target selected.",
                Duration = 2
            })
            return
        end
        
        TeleportTO(0, 0, 0, TargetedPlayer, "safe")
        
        WindUI:Notify({
            Title = "Teleport",
            Content = "Teleporting for " .. TargetedPlayer.Name,
            Duration = 2
        })
        
        targetFeedback:SetDesc("Teleporting for " .. TargetedPlayer.Name)
    end
})

-- Corrigindo problemas de código duplicado no final do arquivo
-- Atualizar quando o alvo sair do jogo (já parece adequada, apenas garantindo limpeza correta)
Players.PlayerRemoving:Connect(function(player)
    pcall(function()
        if TargetedPlayer and player == TargetedPlayer then
            -- Limpar todos os loops ativos
            for _, loopName in ipairs({"ViewLoop", "FocusLoop", "BenxLoop", "HeadsitLoop", "StandLoop", "BackpackLoop", "DoggyLoop", "SugarLoop", "DragLoop"}) do
                if _G[loopName] then
                    task.cancel(_G[loopName])
                    _G[loopName] = nil
                end
            end
            
            -- Limpar estados
            _G.FlingActive = nil
            _G.ViewingTarget = nil
            _G.FocusingTarget = nil
            _G.BenxingTarget = nil
            _G.HeadsittingTarget = nil
            _G.StandingTarget = nil
            _G.BackpackingTarget = nil
            _G.DoggyingTarget = nil
            _G.SugaringTarget = nil
            _G.DraggingTarget = nil
            
            -- Parar animações e limpar efeitos
            StopAnim()
            pcall(function()
                if GetRoot(plr):FindFirstChild("BreakVelocity") then
                    GetRoot(plr).BreakVelocity:Destroy()
                end
                
                workspace.CurrentCamera.CameraSubject = plr.Character.Humanoid
            end)
            
            WindUI:Notify({
                Title = "Target Out",
                Content = player.Name .. " left the game.",
                Duration = 3
            })
        end
    end)
end)

-- Configurations
local SpamConfig = {
    SelectedPlayer = "Ninguém",
    IsSpamming = false,
    SpamDelay = 0.2,
    SpamMessage = "MoonOnTop"
}

local SpectateConfig = {
    SelectedPlayer = "Ninguém",
    IsSpectating = false,
    Camera = workspace.CurrentCamera
}

local AdminConfig = {
    GroupId = 7625597,
    AdminRank = 2,
    ModeratorRank = 2,
    AlertsEnabled = true
}

local TeleportLocations = {
    {Name = "🛡️ Safe Zone", Position = Vector3.new(-105.29137420654297, 642.4719848632812, 514.2374877929688)},
    {Name = "🏜️ Desert", Position = Vector3.new(-672.6334838867188, 642.568603515625, 1115.691162109375)},
    {Name = "🌋 Volcano", Position = Vector3.new(120.21180725097656, 685.631103515625, 1570.7666015625)},
    {Name = "🏖️ Beach", Position = Vector3.new(-29.751022338867188, 644.6039428710938, -70.5428695678711)},
    {Name = "🌫️ Cloud Arena", Position = Vector3.new(-1173.7010498046875, 1268.14404296875, 766.4228515625)}
}

local WalkSpeedConfig = {
    CurrentSpeed = 16,
    MinSpeed = 16,
    MaxSpeed = 500,
    Debounce = false
}

local ESPConfig = {
    FillColor = Color3.fromRGB(175, 25, 255),
    DepthMode = "AlwaysOnTop",
    FillTransparency = 0.5,
    OutlineColor = Color3.fromRGB(255, 255, 255),
    OutlineTransparency = 0,
    Enabled = false
}

-- Global variables
local isFarming = false
local autoEat = false
local dummyFarmActive = false
local dummyFarmConnection = nil
local clanName = ""
local ESPStorage = nil
local ESPConnections = {}
local _G = {
    attackAllNPCToggle = false,
    dummyFarm5kEnabled = false,
    killAura = false,
    huntPlayers = false,
    farmLowLevels = false
}

--[[
    FARM TAB
]]

-- Coin Farm function
local function coinFarmLoop()
    while isFarming and task.wait(0.1) do
        pcall(function()
            game:GetService("ReplicatedStorage").Events.CoinEvent:FireServer()
        end)
    end
end

-- Attack All NPCs function
local function attackAllNPCsLoop()
    while _G.attackAllNPCToggle and task.wait(0.01) do
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
                    local args = {
                        [1] = npcData.humanoid,
                        [2] = 1
                    }
                    game:GetService("ReplicatedStorage").jdskhfsIIIllliiIIIdchgdIiIIIlIlIli:FireServer(table.unpack(args))
                end
            end
        end)
    end
end

-- Dummy Farm function
local function dummyFarmFunction()
    if dummyFarmConnection then
        dummyFarmConnection:Disconnect()
        dummyFarmConnection = nil
    end
    
    if dummyFarmActive then
        dummyFarmConnection = game:GetService("RunService").Heartbeat:Connect(function()
            pcall(function()
                local targetDummy = workspace.MAP.dummies:GetChildren()[1]
                if targetDummy and game.Players.LocalPlayer.Character then
                    local humanoid = targetDummy:FindFirstChild("Humanoid")
                    local rootPart = targetDummy:FindFirstChild("HumanoidRootPart")
                    local playerRoot = game.Players.LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
                    
                    if humanoid and rootPart and playerRoot then
                        playerRoot.CFrame = rootPart.CFrame * CFrame.new(0, 8, 0)
                        game:GetService("ReplicatedStorage").jdskhfsIIIllliiIIIdchgdIiIIIlIlIli:FireServer(humanoid, 1)
                    end
                end
            end)
        end)
    end
end

-- Dummy 5k Farm function
local function dummy5kFarmLoop()
    while _G.dummyFarm5kEnabled and task.wait() do
        pcall(function()
            local dummies = workspace.MAP["5k_dummies"]:GetChildren()
            local targetDummy = nil
            local shortestDistance = math.huge
            
            for _, dummy in pairs(dummies) do
                if dummy.Name == "Dummy2" then
                    if dummy:FindFirstChild("Humanoid") and dummy:FindFirstChild("HumanoidRootPart") then
                        local isOccupied = false
                        local dummyRoot = dummy.HumanoidRootPart
                        
                        for _, player in pairs(game.Players:GetPlayers()) do
                            if player.Character and player ~= game.Players.LocalPlayer then
                                local playerRoot = player.Character:FindFirstChild("HumanoidRootPart")
                                if playerRoot and (playerRoot.Position - dummyRoot.Position).Magnitude < 10 then
                                    isOccupied = true
                                    break
                                end
                            end
                        end
                        
                        if not isOccupied then
                            local distance = (game.Players.LocalPlayer.Character.HumanoidRootPart.Position - dummyRoot.Position).Magnitude
                            if distance < shortestDistance then
                                shortestDistance = distance
                                targetDummy = dummy
                            end
                        end
                    end
                end
            end
            
            if targetDummy and game.Players.LocalPlayer.Character then
                local humanoid = targetDummy:FindFirstChild("Humanoid")
                local rootPart = targetDummy:FindFirstChild("HumanoidRootPart")
                local playerRoot = game.Players.LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
                
                if humanoid and rootPart and playerRoot then
                    playerRoot.CFrame = rootPart.CFrame * CFrame.new(0, 8, 0)
                    game:GetService("ReplicatedStorage").jdskhfsIIIllliiIIIdchgdIiIIIlIlIli:FireServer(humanoid, 1)
                end
            end
        end)
    end
end

--[[
    FARM TAB UI
]]

-- Coin Farm Toggle
Tabs.Farm:Toggle({
    Title = "💰 Coin Farm",
    Desc = "Automatically farms coins",
    Value = false,
    Callback = function(state)
        isFarming = state
        
        if isFarming then
            task.spawn(coinFarmLoop)
            WindUI:Notify({
                Title = "💰 Coin Farm Activated",
                Content = "Coin Farm has been activated.",
                Duration = 1
            })
        else
            WindUI:Notify({
                Title = "💰 Coin Farm Deactivated",
                Content = "Coin Farm has been deactivated.",
                Duration = 1
            })
        end
    end
})

-- Attack All Bosses Toggle
Tabs.Farm:Toggle({
    Title = "👹 Attack All Bosses",
    Desc = "Automatically attacks all bosses",
    Value = false,
    Callback = function(state)
        _G.attackAllNPCToggle = state
        
        if state then
            task.spawn(attackAllNPCsLoop)
        end
        
        WindUI:Notify({
            Title = "👹 Attack All Bosses",
            Content = state and "Auto attack on all bosses has been activated!" or "Auto attack on all bosses has been deactivated!",
            Duration = 1
        })
    end
})

-- Dummy Farm Toggle
Tabs.Farm:Toggle({
    Title = "🧍🏻 Dummy Farm",
    Desc = "Automatically farms dummies",
    Value = false,
    Callback = function(state)
        dummyFarmActive = state
        dummyFarmFunction()
        
        WindUI:Notify({
            Title = "🧍🏻 Dummy Farm " .. (state and "Activated" or "Deactivated"),
            Content = state and "Dummy Farm has been activated!" or "Dummy Farm has been deactivated!",
            Duration = 1
        })
    end
})

-- Dummy 5k Farm Toggle
Tabs.Farm:Toggle({
    Title = "🧍🏻 Dummy 5k Farm",
    Desc = "Automatically farms 5k dummies",
    Value = false,
    Callback = function(state)
        _G.dummyFarm5kEnabled = state
        
        if state then
            task.spawn(dummy5kFarmLoop)
        end
        
        WindUI:Notify({
            Title = "🧍🏻 Dummy 5k Farm " .. (state and "Activated" or "Deactivated"),
            Content = state and "Dummy 5k Farm has been activated!" or "Dummy 5k Farm has been deactivated!",
            Duration = 1
        })
    end
})

-- Free Radio Toggle
Tabs.Farm:Toggle({
    Title = "📻 Free Radio", 
    Desc = nil,
    Value = false,
    Callback = function(state)
        local gui = game.Players.LocalPlayer:FindFirstChild("PlayerGui")
        if gui and gui:FindFirstChild("DRadio_Gui") then
            gui.DRadio_Gui.Enabled = state
        end
        
        WindUI:Notify({
            Title = "📻 Free Radio",
            Content = state and "Free Radio has been activated!" or "Free Radio has been deactivated!",
            Duration = 1
        })
    end
})

-- Visual 13x Exp Toggle
Tabs.Farm:Toggle({
    Title = "🔍 Visual 13x Exp", 
    Desc = nil,
    Value = false,
    Callback = function(state)
        local gui = game.Players.LocalPlayer:FindFirstChild("PlayerGui")
        if gui and gui:FindFirstChild("LevelBar") and gui.LevelBar:FindFirstChild("gamepassText") then
            gui.LevelBar.gamepassText.Visible = state
            if state then
                gui.LevelBar.gamepassText.Text = "13x exp"
            end
        end
        
        WindUI:Notify({
            Title = "🔍 Visual 13x Exp",
            Content = state and "13x Exp has been activated!" or "13x Exp has been deactivated!",
            Duration = 1
        })
    end
})

--[[
    PVP TAB FUNCTIONS
]]

-- Auto Eat function
local function autoEatLoop()
    local VirtualInputManager = game:GetService("VirtualInputManager")
    local UserInputService = game:GetService("UserInputService")
    
    -- Detect device type
    local isMobile = UserInputService.TouchEnabled and not UserInputService.MouseEnabled
    local isPC = UserInputService.MouseEnabled and not UserInputService.TouchEnabled
    
    while autoEat and task.wait(1) do
        pcall(function()
            if isPC then
                -- PC Input Method
                -- Select food slot
                VirtualInputManager:SendKeyEvent(true, "One", false, game)
                task.wait(0.1)
                VirtualInputManager:SendKeyEvent(false, "One", false, game)
                task.wait(0.1)

                -- Click at screen center
                local screenCenterX = workspace.CurrentCamera.ViewportSize.X * 0.5
                local screenCenterY = workspace.CurrentCamera.ViewportSize.Y * 0.7
                
                VirtualInputManager:SendMouseButtonEvent(screenCenterX, screenCenterY, 0, true, game, 0)
                task.wait(0.05)
                VirtualInputManager:SendMouseButtonEvent(screenCenterX, screenCenterY, 0, false, game, 0)
            elseif isMobile then
                -- Mobile Input Method
                -- Select food slot (using touch input)
                local screenCenterX = workspace.CurrentCamera.ViewportSize.X * 0.5
                local screenCenterY = workspace.CurrentCamera.ViewportSize.Y * 0.7
                
                -- Simulate touch input for mobile
                VirtualInputManager:SendTouchEvent(0, Vector2.new(screenCenterX, screenCenterY), Vector2.new(screenCenterX, screenCenterY), true, game, 0)
                task.wait(0.1)
                VirtualInputManager:SendTouchEvent(0, Vector2.new(screenCenterX, screenCenterY), Vector2.new(screenCenterX, screenCenterY), false, game, 0)
                task.wait(0.1)
                
                -- Additional touch for eating action
                VirtualInputManager:SendTouchEvent(0, Vector2.new(screenCenterX, screenCenterY), Vector2.new(screenCenterX, screenCenterY), true, game, 0)
                task.wait(0.05)
                VirtualInputManager:SendTouchEvent(0, Vector2.new(screenCenterX, screenCenterY), Vector2.new(screenCenterX, screenCenterY), false, game, 0)
            end
        end)
    end
end

-- Kill Aura function
local function killAuraLoop()
    local Players = game:GetService("Players")
    local ReplicatedStorage = game:GetService("ReplicatedStorage")
    local localPlayer = Players.LocalPlayer

    while _G.killAura and task.wait(0.01) do
        pcall(function()
            for _, player in ipairs(Players:GetPlayers()) do
                if player ~= localPlayer and player.Character then
                    local humanoid = player.Character:FindFirstChildOfClass("Humanoid")
                    if humanoid and humanoid.Health > 0 and not player.Character:FindFirstChild("SafeZoneShield") then
                        local args = {
                            [1] = humanoid,
                            [2] = 5
                        }
                        ReplicatedStorage.jdskhfsIIIllliiIIIdchgdIiIIIlIlIli:FireServer(table.unpack(args))
                    end
                end
            end
        end)
    end
end

-- Loop Kill All function
local function loopKillAllPlayers()
    local localPlayer = game.Players.LocalPlayer

    while _G.huntPlayers and task.wait() do
        pcall(function()
            for _, target in ipairs(game.Players:GetPlayers()) do
                if target ~= localPlayer and target.Character and target.Character:FindFirstChild("Humanoid") and 
                   target.Character.Humanoid.Health > 1 and not target.Character:FindFirstChild("SafeZoneShield") then

                    local targetRoot = target.Character:FindFirstChild("HumanoidRootPart")
                    local localRoot = localPlayer.Character and localPlayer.Character:FindFirstChild("HumanoidRootPart")

                    if targetRoot and localRoot then
                        if (localRoot.Position - targetRoot.Position).Magnitude > 10 then
                            localRoot.CFrame = targetRoot.CFrame
                        end

                        local startTime = tick()

                        while target.Character and target.Character:FindFirstChild("Humanoid") and 
                              target.Character.Humanoid.Health > 1 and _G.huntPlayers do

                            if tick() - startTime > 8 then
                                break
                            end

                            local carryArgs = {
                                [1] = target,
                                [2] = "request_accepted"
                            }
                            game:GetService("ReplicatedStorage").Events.CarryEvent:FireServer(table.unpack(carryArgs))

                            local attackArgs = {
                                [1] = target.Character.Humanoid,
                                [2] = 24
                            }
                            game:GetService("ReplicatedStorage").jdskhfsIIIllliiIIIdchgdIiIIIlIlIli:FireServer(table.unpack(attackArgs))

                            task.wait()
                        end
                    end
                end
            end
        end)
    end
end

-- Auto Kill Low Levels function
local function autoKillLowLevels()
    local lp = game.Players.LocalPlayer

    while _G.farmLowLevels and task.wait() do
        pcall(function()
            local best = nil
            for _, p in ipairs(game.Players:GetPlayers()) do
                if p ~= lp and p.Character and p:FindFirstChild("leaderstats") and 
                   p.leaderstats.Level.Value < lp.leaderstats.Level.Value and 
                   p.Character:FindFirstChild("HumanoidRootPart") and 
                   p.Character:FindFirstChild("Humanoid") and 
                   p.Character.Humanoid.Health > 1 and 
                   not p.Character:FindFirstChild("SafeZoneShield") and 
                   (not best or p.leaderstats.Level.Value < best.leaderstats.Level.Value) then 
                    best = p 
                end
            end

            if best and lp.Character and lp.Character:FindFirstChild("HumanoidRootPart") then
                local lr, tr = lp.Character.HumanoidRootPart, best.Character.HumanoidRootPart
                if (lr.Position - tr.Position).Magnitude > 10 then 
                    lr.CFrame = tr.CFrame 
                end
                
                game:GetService("ReplicatedStorage").Events.CarryEvent:FireServer(best, "request_accepted")
                game:GetService("ReplicatedStorage").jdskhfsIIIllliiIIIdchgdIiIIIlIlIli:FireServer(best.Character.Humanoid, 24)
            end
        end)
    end
end

--[[
    PVP UTILITY FUNCTIONS
]]

-- Target priority system
local targetPriority = "Closest" -- Default priority
local detectionRadius = 70 -- Default detection radius

-- Function to get valid targets sorted by priority
local function getValidTargetsSorted(priority)
    local lp = game.Players.LocalPlayer
    local char = lp and lp.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if not root then return {} end

    local myPos = root.Position
    local targets = {}
    local maxDist = tonumber(detectionRadius) or 70
    
    for _, p in ipairs(game.Players:GetPlayers()) do
        if p ~= lp and p.Character then
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
    -- normalize aliases
    if method == "lowest health" or method == "low health" or method == "lowest" or method == "health" then
        table.sort(targets, function(a,b) return a.health < b.health end)
    else
        table.sort(targets, function(a,b) return a.distance < b.distance end)
    end
    return targets
end

-- Function to find closest target based on priority
local function findClosestTarget()
    local targets = getValidTargetsSorted(targetPriority)
    if #targets > 0 then
        return targets[1].player, targets[1].distance
    end
    return nil, nil
end

-- Function to get ping
local function GetPing()
    local ping = 0
    pcall(function()
        ping = game:GetService("Stats").Network.ServerStatsItem["Data Ping"]:GetValue() / 1000
    end)
    return ping or 0.2
end

-- Function to predict target position
local function predictPosition(target, distance)
    if not target or not target.Character or not target.Character:FindFirstChild("HumanoidRootPart") then 
        return nil 
    end
    
    local targetRoot = target.Character.HumanoidRootPart
    local velocity = targetRoot.Velocity
    local ping = GetPing()
    
    -- Simple prediction based on velocity and ping
    local totalTimeToPredict = ping * 2
    local averageVelocity = velocity
    
    local futurePosition = targetRoot.Position + (averageVelocity * totalTimeToPredict)
    
    return futurePosition
end

-- Fireball Aura system
local FireballAura = {}
FireballAura.isActive = false
FireballAura.lastFireTime = 0
FireballAura.fireInterval = 0.5
local fireballAuraConnection = nil

function FireballAura.start()
    if FireballAura.isActive then return end
    
    FireballAura.isActive = true
    if fireballAuraConnection then
        fireballAuraConnection:Disconnect()
        fireballAuraConnection = nil
    end
    
    fireballAuraConnection = game:GetService("RunService").RenderStepped:Connect(function()
        if not FireballAura.isActive or (tick() - FireballAura.lastFireTime < FireballAura.fireInterval) then return end

        local target, distance = findClosestTarget()

        if target and distance then
            local predictedPosition = predictPosition(target, distance)
            
            local args = {
                [1] = predictedPosition,
                [2] = "NewFireball",
            }

            -- Get the SkillsInRS remote event
            local SkillsInRS = game:GetService("ReplicatedStorage"):FindFirstChild("SkillsInRS")
            if SkillsInRS and SkillsInRS:FindFirstChild("RemoteEvent") then
                SkillsInRS.RemoteEvent:FireServer(unpack(args))
                FireballAura.lastFireTime = tick()
            end
        end
    end)
    
    WindUI:Notify({
        Title = "Fireball Aura",
        Content = "Fireball Aura activated!",
        Duration = 2
    })
end

function FireballAura.stop()
    if not FireballAura.isActive then return end
    
    FireballAura.isActive = false
    if fireballAuraConnection then
        fireballAuraConnection:Disconnect()
        fireballAuraConnection = nil
    end
    
    WindUI:Notify({
        Title = "Fireball Aura",
        Content = "Fireball Aura deactivated!",
        Duration = 2
    })
end

function FireballAura.setInterval(interval)
    local n = tonumber(interval)
    FireballAura.fireInterval = n or 0.5
end

--[[
    PVP TAB UI
]]

--[[
    PVP TAB - AURA SECTION
]]
Tabs.PVP:Section({ Title = "⚔️ Aura" })

-- Priority Dropdown
Tabs.PVP:Dropdown({
    Title = "🎯 Target Priority",
    Desc = "Choose how targets are prioritized",
    Values = {"Closest", "Lowest Health"},
    Multi = false,
    Default = "Closest",
    Callback = function(priority)
        targetPriority = priority
        WindUI:Notify({
            Title = "🎯 Priority Changed",
            Content = "Target priority set to: " .. priority,
            Duration = 2
        })
    end
})

-- Fireball Aura Toggle
Tabs.PVP:Toggle({
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

-- Fireball Interval Slider
Tabs.PVP:Slider({
    Title = "🔥 Fireball Interval",
    Desc = "Adjust how frequently fireballs are fired (in seconds)",
    Value = {
        Min = 0.1,
        Max = 2.0,
        Default = 0.5
    },
    Callback = function(value)
        FireballAura.setInterval(tonumber(value))
        WindUI:Notify({
            Title = "🔥 Fireball Interval",
            Content = "Fireball interval set to " .. value .. " seconds",
            Duration = 2
        })
    end
})

-- Detection Radius Slider
Tabs.PVP:Slider({
    Title = "🎯 Detection Radius",
    Desc = "Adjust how far away targets can be detected",
    Value = {
        Min = 20,
        Max = 200,
        Default = 70
    },
    Callback = function(value)
        detectionRadius = tonumber(value) or detectionRadius
        WindUI:Notify({
            Title = "🎯 Detection Radius",
            Content = "Detection radius set to " .. tostring(value) .. " studs",
            Duration = 2
        })
    end
})

-- Kill Aura Toggle
Tabs.PVP:Toggle({
    Title = "⚔️ Kill Aura",
    Desc = "Enables or disables the Kill Aura function",
    Value = false,
    Callback = function(state)
        _G.killAura = state
        if state then
            task.spawn(killAuraLoop)
        end
        
        WindUI:Notify({
            Title = "⚔️ Kill Aura " .. (state and "Activated" or "Deactivated"),
            Content = state and "Kill Aura is now active." or "Kill Aura is now inactive.",
            Duration = 1
        })
    end
})

--[[
    PVP TAB - OTHER SECTION
]]
Tabs.PVP:Section({ Title = "🔧 Other" })

-- Auto Eat Toggle
Tabs.PVP:Toggle({
    Title = "🐟 Auto Eat (PC & Mobile)",
    Desc = "Automatically detects device type and uses appropriate input method for eating",
    Value = false,
    Callback = function(state)
        autoEat = state
        if autoEat then
            task.spawn(autoEatLoop)
        end
        
        WindUI:Notify({
            Title = "🐟 Auto Eat",
            Content = state and "Auto Eat has been activated for your device." or "Auto Eat has been deactivated.",
            Duration = 1
        })
    end
})

-- Loop Kill All Toggle
Tabs.PVP:Toggle({
    Title = "🤯 Loop Kill All Players",
    Desc = "Automatically hunts and kills all players",
    Value = false,
    Callback = function(state)
        _G.huntPlayers = state
        if state then
            task.spawn(loopKillAllPlayers)
        end
        
        WindUI:Notify({
            Title = state and "🤯 Loop Kill Activated" or "🛑 Loop Kill Stopped",
            Content = state and "Now hunting all players!" or "Stopped hunting players.",
            Duration = 1
        })
    end
})

-- Auto Kill Low Levels Toggle
Tabs.PVP:Toggle({
    Title = "😎 Auto Kill Low Levels",
    Desc = "Automatically hunts players with a lower level than you",
    Value = false,
    Callback = function(state)
        _G.farmLowLevels = state
        if state then
            task.spawn(autoKillLowLevels)
        end
        
        WindUI:Notify({
            Title = state and "😎 Auto Kill Low Levels Activated" or "🛑 Auto Kill Low Levels Stopped",
            Content = state and "Hunting lower-level players!" or "Stopped hunting low-level players.",
            Duration = 1
        })
    end
})

--[[
    PVP TAB - FREE TOOLS SECTION
]]
Tabs.PVP:Section({ Title = "🛠️ Free Tools" })

-- Free Fireball Button
Tabs.PVP:Button({
    Title = "🔥 Free Fireball",
    Desc = "Click to get a fireball!",
    Callback = function()
        local tool = Instance.new("Tool")
        tool.Name = "Fireball"
        tool.RequiresHandle = false

        tool.Activated:Connect(function()
            local mouse = game.Players.LocalPlayer:GetMouse()
            local args = {
                [1] = mouse.Hit.p,
                [2] = "NewFireball"
            }
            game:GetService("ReplicatedStorage").SkillsInRS.RemoteEvent:FireServer(table.unpack(args))
        end)

        tool.Parent = game.Players.LocalPlayer.Backpack
        
        WindUI:Notify({
            Title = "🔥 Fireball Created",
            Content = "The Fireball has been added to your backpack!",
            Duration = 1
        })
    end
})

-- Free Lightningball Button
Tabs.PVP:Button({
    Title = "⚡ Free Lightningball",
    Desc = "Click to get a Lightning Ball!",
    Callback = function()
        local tool = Instance.new("Tool")
        tool.Name = "Lightning Ball"
        tool.RequiresHandle = false

        tool.Activated:Connect(function()
            local mouse = game.Players.LocalPlayer:GetMouse()
            for i = 1, 3 do
                local args = {
                    [1] = mouse.Hit.p,
                    [2] = "NewLightningball"
                }
                game:GetService("ReplicatedStorage").SkillsInRS.RemoteEvent:FireServer(table.unpack(args))
                task.wait(0.1)
            end
        end)

        tool.Parent = game.Players.LocalPlayer.Backpack
        
        WindUI:Notify({
            Title = "⚡ Lightningball Created",
            Content = "The Lightningball has been added to your backpack!",
            Duration = 1
        })
    end
})

--[[
    PVP TAB - TELEPORT SECTION
]]
Tabs.PVP:Section({ Title = "🙋🏻 Teleport to Player" })

-- Player List Functions
local function getPlayers()
    local players = {"Ninguém"} -- Always start with "Ninguém" as first option
    for _, player in ipairs(game:GetService("Players"):GetPlayers()) do
        if player ~= game.Players.LocalPlayer then
            table.insert(players, player.Name)
        end
    end
    return players
end

local function updateTeleportDropdown()
    local players = getPlayers()
    
    if TeleportDropdown then
        local currentSelection = TeleportConfig.SelectedPlayer
        local selectionExists = false
        
        for _, player in ipairs(players) do
            if player == currentSelection then
                selectionExists = true
                break
            end
        end
        
        TeleportDropdown:Refresh(players)
        
        if not selectionExists or currentSelection == nil then
            TeleportDropdown:Select("Ninguém")
            TeleportConfig.SelectedPlayer = "Ninguém"
        else
            TeleportDropdown:Select(currentSelection)
        end
    end
end

TeleportConfig = TeleportConfig or {
    SelectedPlayer = "Ninguém"
}

-- Teleport Dropdown
TeleportDropdown = Tabs.PVP:Dropdown({
    Title = "🙋🏻 Teleport to Player",
    Desc = "Select a player to teleport to",
    Values = getPlayers(),
    Multi = false,
    Default = "Ninguém",
    Callback = function(selectedPlayer)
        TeleportConfig.SelectedPlayer = selectedPlayer
        
        if selectedPlayer == "Ninguém" then 
            WindUI:Notify({
                Title = "Teleport",
                Content = "No player selected",
                Duration = 1
            })

Tabs.PVP:Button({
    Title = "🔄 Refresh player list",
    Desc = "Update the player list",
    Callback = function()
        updateTeleportDropdown()
        WindUI:Notify({ Title = "Teleport", Content = "Player list refreshed", Duration = 1 })
    end
})

            return 
        end
        
        local localPlayer = game:GetService("Players").LocalPlayer
        local targetPlayer = game:GetService("Players"):FindFirstChild(selectedPlayer)

        if targetPlayer and targetPlayer.Character and targetPlayer.Character:FindFirstChild("HumanoidRootPart") then
            if localPlayer.Character and localPlayer.Character:FindFirstChild("HumanoidRootPart") then
                localPlayer.Character:SetPrimaryPartCFrame(targetPlayer.Character.HumanoidRootPart.CFrame)
                
                WindUI:Notify({
                    Title = "🙋🏻 Teleport Successful",
                    Content = "You have successfully teleported to " .. targetPlayer.Name .. "!",
                    Duration = 1
                })
            end
        else
            WindUI:Notify({
                Title = "Error",
                Content = "Player not found or invalid target!",
                Duration = 1
            })
        end
    end
})

-- Clan Name Input
-- Clan Join (Rayfield-style)
--[[
    PVP TAB - CLAN SECTION
]]
Tabs.PVP:Section({ Title = "🏛️ Clan Join" })

local invitationEvent = RS:WaitForChild("invitationEvent", 9e9)
local ClanTeamsFolder = workspace:FindFirstChild("Teams")
local clanTeamList = {}
local selectedClan = ""
local clanAutoJoin = false
local clanAutoJoinThread = nil
local lastJoinedClan = nil
local ClanDropdown

local function refreshClanTeamList()
    clanTeamList = {}
    local tf = workspace:FindFirstChild("Teams")
    if tf then
        for _, team in ipairs(tf:GetChildren()) do
            table.insert(clanTeamList, team.Name)
        end
    end
    if ClanDropdown then
        ClanDropdown:Refresh(clanTeamList)
        if not table.find(clanTeamList, selectedClan) and #clanTeamList > 0 then
            selectedClan = clanTeamList[1] or ""
            if selectedClan ~= "" then ClanDropdown:Select(selectedClan) end
        end
    end
end

refreshClanTeamList()

ClanDropdown = Tabs.PVP:Dropdown({
    Title = "Select Clan",
    Desc = "Pick a clan (team) to join",
    Values = clanTeamList,
    Multi = false,
    Default = clanTeamList[1],
    Callback = function(choice)
        selectedClan = choice
    end
})

Tabs.PVP:Button({
    Title = "Join Selected Clan",
    Desc = "Attempt to join the chosen clan",
    Callback = function()
        if not selectedClan or selectedClan == "" then
            WindUI:Notify({ Title = "Clan Join", Content = "No clan selected!", Duration = 2 })
            return
        end

        local clanIcon = ""
        pcall(function()
            local tf = workspace:FindFirstChild("Teams")
            if tf then
                local teamFolder = tf:FindFirstChild(selectedClan)
                if teamFolder and teamFolder:FindFirstChild("leader") then
                    local leaderName = teamFolder.leader.Value
                    local leaderPlayer = Players:FindFirstChild(leaderName)
                    if leaderPlayer and leaderPlayer:FindFirstChild("ClanIcon") and leaderPlayer.ClanIcon.Value and leaderPlayer.ClanIcon.Value ~= "" then
                        clanIcon = leaderPlayer.ClanIcon.Value
                    end
                end
            end
        end)

        local currentClan = plr:FindFirstChild("Clan") and plr.Clan.Value or nil
        if currentClan and currentClan ~= selectedClan then
            pcall(function()
                RS:WaitForChild("Events", 9e9):WaitForChild("ClanEvent", 9e9):FireServer({{ action = "leave_clan" }})
            end)
            task.wait(0.5)
        end

        WindUI:Notify({ Title = "Clan Join", Content = "Joining: " .. selectedClan, Duration = 2 })

        local success = false
        pcall(function()
            local args = { { teamIcon = clanIcon, action = "accepted", teamName = selectedClan } }
            invitationEvent:FireServer(table.unpack(args))
            success = true
        end)

        if not success then
            pcall(function()
                local args = { { teamIcon = clanIcon, action = "accepted", teamName = selectedClan }, selectedClan }
                invitationEvent:FireServer(table.unpack(args))
                success = true
            end)
        end

        if not success then
            pcall(function()
                invitationEvent:FireServer(selectedClan)
                success = true
            end)
        end

        if success then
            lastJoinedClan = selectedClan
            WindUI:Notify({ Title = "Clan Join", Content = "Join request sent to '" .. selectedClan .. "'", Duration = 2 })
        else
            WindUI:Notify({ Title = "Clan Join", Content = "Failed to send join request", Duration = 2 })
        end
    end
})

Tabs.PVP:Toggle({
    Title = "Auto Join Selected Clan",
    Desc = "Continuously attempt to join the selected clan",
    Value = false,
    Callback = function(state)
        clanAutoJoin = state
        if clanAutoJoin then
            if clanAutoJoinThread then return end
            clanAutoJoinThread = task.spawn(function()
                while clanAutoJoin do
                    if selectedClan and selectedClan ~= "" then
                        local clanIcon = ""
                        pcall(function()
                            local tf = workspace:FindFirstChild("Teams")
                            if tf then
                                local teamFolder = tf:FindFirstChild(selectedClan)
                                if teamFolder and teamFolder:FindFirstChild("leader") then
                                    local leaderName = teamFolder.leader.Value
                                    local leaderPlayer = Players:FindFirstChild(leaderName)
                                    if leaderPlayer and leaderPlayer:FindFirstChild("ClanIcon") and leaderPlayer.ClanIcon.Value and leaderPlayer.ClanIcon.Value ~= "" then
                                        clanIcon = leaderPlayer.ClanIcon.Value
                                    end
                                end
                            end
                        end)

                        if lastJoinedClan and lastJoinedClan ~= selectedClan then
                            pcall(function()
                                RS:WaitForChild("Events", 9e9):WaitForChild("ClanEvent", 9e9):FireServer({{ action = "leave_clan" }})
                            end)
                        end

                        pcall(function()
                            local args = { { teamIcon = clanIcon, action = "accepted", teamName = selectedClan } }
                            invitationEvent:FireServer(table.unpack(args))
                            lastJoinedClan = selectedClan
                        end)
                    end
                    task.wait(1)
                end
            end)
        else
            clanAutoJoinThread = nil
        end
    end
})

Tabs.PVP:Button({
    Title = "Refresh Clan List",
    Desc = "Rescan available clans",
    Callback = function()
        refreshClanTeamList()
        WindUI:Notify({ Title = "Clan Join", Content = "Clan list refreshed", Duration = 2 })
    end
})

-- ESP System
local function InitializeESPStorage()
    if not ESPStorage then
        ESPStorage = Instance.new("Folder")
        ESPStorage.Name = "ESP_Storage"
        ESPStorage.Parent = game:GetService("CoreGui")
    end
end

local function CreateESP(player)
    if not ESPStorage or not ESPConfig.Enabled then return end
    
    local highlight = Instance.new("Highlight")
    highlight.Name = player.Name
    highlight.FillColor = ESPConfig.FillColor
    highlight.DepthMode = ESPConfig.DepthMode
    highlight.FillTransparency = ESPConfig.FillTransparency
    highlight.OutlineColor = ESPConfig.OutlineColor
    highlight.OutlineTransparency = ESPConfig.OutlineTransparency
    highlight.Parent = ESPStorage

    if player.Character then
        highlight.Adornee = player.Character
    end

    ESPConnections[player] = player.CharacterAdded:Connect(function(character)
        highlight.Adornee = character
    end)
end

local function RemoveESP(player)
    if ESPStorage then
        local esp = ESPStorage:FindFirstChild(player.Name)
        if esp then
            esp:Destroy()
        end
    end
    
    if ESPConnections[player] then
        ESPConnections[player]:Disconnect()
        ESPConnections[player] = nil
    end
end

local function ToggleESP(state)
    ESPConfig.Enabled = state
    
    if state then
        InitializeESPStorage()
        for _, player in ipairs(game:GetService("Players"):GetPlayers()) do
            if player ~= game.Players.LocalPlayer then
                CreateESP(player)
            end
        end
    else
        for player, _ in pairs(ESPConnections) do
            RemoveESP(player)
        end
        
        if ESPStorage then
            ESPStorage:Destroy()
            ESPStorage = nil
        end
    end
    
    WindUI:Notify({
        Title = "👁️ ESP Players",
        Content = state and "ESP Activated!" or "ESP Deactivated!",
        Duration = 1
    })
end

--[[
    PVP TAB - MOVEMENT & ESP SECTION
]]
Tabs.PVP:Section({ Title = "🚀 Movement & ESP" })

Tabs.PVP:Toggle({
    Title = "👁️ ESP Players",
    Desc = "Toggle to activate or deactivate ESP for players",
    Value = false,
    Callback = function(state)
        ToggleESP(state)
    end
})

-- Walk Speed Slider
local function updateWalkSpeed(speed)
    local character = game.Players.LocalPlayer.Character
    if character and character:FindFirstChildOfClass("Humanoid") then
        character.Humanoid.WalkSpeed = speed
    end
end

local function delayedNotification()
    if WalkSpeedConfig.Debounce then return end
    WalkSpeedConfig.Debounce = true
    
    task.wait(1) -- Wait 1 second after last slider movement
    
    WindUI:Notify({
        Title = "🚀 Speed Adjustment",
        Content = "Your walk speed has been set to " .. WalkSpeedConfig.CurrentSpeed .. "!",
        Duration = 1
    })
    
    WalkSpeedConfig.Debounce = false
end

Tabs.PVP:Slider({
    Title = "🚀 Walk Speed",
    Desc = "Adjust your character's movement speed",
    Value = {
        Min = WalkSpeedConfig.MinSpeed,
        Max = WalkSpeedConfig.MaxSpeed,
        Default = WalkSpeedConfig.CurrentSpeed
    },
    Callback = function(value)
        WalkSpeedConfig.CurrentSpeed = value
        updateWalkSpeed(value)
        task.spawn(delayedNotification)
    end
})

-- Character connection to maintain speed on respawn
game:GetService("Players").LocalPlayer.CharacterAdded:Connect(function(character)
    if WalkSpeedConfig.CurrentSpeed > WalkSpeedConfig.MinSpeed then
        character:WaitForChild("Humanoid")
        updateWalkSpeed(WalkSpeedConfig.CurrentSpeed)
    end
end)

-- Teleport Locations
local function teleportTo(location)
    local character = game.Players.LocalPlayer.Character
    if character and character:FindFirstChild("HumanoidRootPart") then
        character.HumanoidRootPart.CFrame = CFrame.new(location.Position)
        
        WindUI:Notify({
            Title = location.Name,
            Content = "You have been teleported successfully!",
            Duration = 3
        })
    else
        WindUI:Notify({
            Title = "Error",
            Content = "Character not found or invalid!",
            Duration = 3
        })
    end
end

--[[
    PVP TAB - TELEPORT LOCATIONS SECTION
]]
-- Create teleport buttons
for _, location in ipairs(TeleportLocations) do
    Tabs.Teleport:Button({
        Title = location.Name,
        Desc = "Teleport to " .. location.Name:gsub("%p", ""),
        Callback = function()
            teleportTo(location)
        end
    })
end

-- Variável para controlar o estado do loop de animação
local isAnimating = false

-- Função que executa a animação do nome
local function animateName()
    -- Tabela com os nomes para a animação
    local nameParts = {
        "M",
        "Mo",
        "Moo",
        "Moon",
        "Moon ",
        "Moon H",
        "Moon Hu",
        "Moon Hub"
    }

    -- Loop que continua enquanto a animação estiver ativa
    while isAnimating do
        -- Itera sobre cada parte do nome para criar o efeito de "digitação"
        for _, text in ipairs(nameParts) do
            -- Se o toggle for desativado no meio da animação, paramos o loop imediatamente
            if not isAnimating then break end

            -- Argumentos para o evento de mudança de nome
            local args = {
                text,
                "player"
            }
            -- Dispara o evento para o servidor
            game:GetService("ReplicatedStorage"):WaitForChild("Events"):WaitForChild("nameEvent"):FireServer(table.unpack(args))
            
            -- Uma pequena pausa para que a animação seja visível
            task.wait(0.2) 
        end
        -- Pausa antes de reiniciar a animação
        task.wait(0.5)
    end
end

-- Definição do Toggle
Tabs.Misc:Toggle({
    Title = "Moon Hub Animation",
    Type = "Checkbox",
    Default = false,
    Callback = function(state)
        -- Atualiza a variável de controle com o novo estado do toggle
        isAnimating = state
        
        if isAnimating then
            -- Se o toggle foi ativado, inicia a animação em uma nova thread
            -- para não travar o resto do script.
            task.spawn(animateName)
        else
            -- Se foi desativado, a animação irá parar naturalmente
            -- porque o loop 'while isAnimating' se tornará falso.
            -- Não dispara o nameEvent quando desativado
        end
    end
})

-- Admin Alerts
local function checkAdminStatus(player)
    local success, rank = pcall(function()
        return player:GetRankInGroup(AdminConfig.GroupId)
    end)
    
    if not success then return false, false end
    
    local isAdmin = rank >= AdminConfig.AdminRank
    local isModerator = not isAdmin and rank >= AdminConfig.ModeratorRank
    
    return isAdmin, isModerator
end

local function playerAdded(player)
    if not AdminConfig.AlertsEnabled then return end
    
    local isAdmin, isModerator = checkAdminStatus(player)
    
    if isAdmin or isModerator then
        local role = isAdmin and "Administrator" or "Moderator"
        
        WindUI:Notify({
            Title = "⚠️ Staff Join Alert",
            Content = player.Name .. " (" .. role .. ") has joined the game",
            Duration = 1
        })
    end
end

--[[
    MISC TAB - ADMIN ALERTS
]]

Tabs.Misc:Toggle({
    Title = "⚠️ Staff Join Alerts",
    Desc = "Get notifications when staff members join",
    Value = true,
    Callback = function(state)
        AdminConfig.AlertsEnabled = state
        WindUI:Notify({
            Title = "Staff Alerts",
            Content = state and "Staff join alerts enabled" or "Staff join alerts disabled",
            Duration = 1
        })
    end
})

-- Spectate System
local function updateSpectateDropdown()
    local players = getPlayers()
    
    if SpectateDropdown then
        local currentSelection = SpectateConfig.SelectedPlayer
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
            SpectateConfig.SelectedPlayer = "Ninguém"
        else
            SpectateDropdown:Select(currentSelection)
        end
    end
end

local function startSpectating()
    if not SpectateConfig.SelectedPlayer or SpectateConfig.SelectedPlayer == "Ninguém" then
        WindUI:Notify({
            Title = "Error",
            Content = "No player selected to spectate!",
            Duration = 3
        })
        return
    end

    local target = game:GetService("Players"):FindFirstChild(SpectateConfig.SelectedPlayer)
    if target and target.Character then
        local humanoidRootPart = target.Character:FindFirstChild("HumanoidRootPart")
        if humanoidRootPart then
            SpectateConfig.IsSpectating = true
            SpectateConfig.Camera.CameraSubject = humanoidRootPart
            
            WindUI:Notify({
                Title = "🧿 Spectating",
                Content = "Now spectating " .. target.Name,
                Duration = 3
            })

            target.CharacterAdded:Connect(function(character)
                if SpectateConfig.IsSpectating then
                    character:WaitForChild("HumanoidRootPart")
                    SpectateConfig.Camera.CameraSubject = character.HumanoidRootPart
                end
            end)
        end
    else
        WindUI:Notify({
            Title = "Error",
            Content = "Player not found or invalid target!",
            Duration = 3
        })
    end
end

local function stopSpectating()
    SpectateConfig.IsSpectating = false
    local character = game.Players.LocalPlayer.Character
    if character then
        local humanoid = character:FindFirstChildOfClass("Humanoid")
        if humanoid then
            SpectateConfig.Camera.CameraSubject = humanoid
        end
    end
    
    WindUI:Notify({
        Title = "🧿 Spectating Stopped",
        Content = "No longer spectating",
        Duration = 3
    })
    
    if SpectateDropdown then
        SpectateDropdown:Select("Ninguém")
        SpectateConfig.SelectedPlayer = "Ninguém"
    end
end

-- Spectate Dropdown
SpectateDropdown = Tabs.Misc:Dropdown({
    Title = "🧿 Spectate Player",
    Desc = "Select a player to spectate",
    Values = getPlayers(),
    Multi = false,
    Default = "Ninguém",
    Callback = function(selected)
        SpectateConfig.SelectedPlayer = selected
        if selected ~= "Ninguém" then
            WindUI:Notify({
                Title = "Player Selected",
                Content = "Ready to spectate: " .. selected,
                Duration = 2
            })
        end
    end
})

-- Spectate Buttons
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

-- Misc Buttons
Tabs.Misc:Button({
    Title = "🗣️ Unban Voice Chat",
    Desc = "Click to remove your voice chat ban",
    Callback = function()
        local success, err = pcall(function()
            game:GetService("VoiceChatService"):JoinVoiceChat()
        end)
        
        if success then
            WindUI:Notify({
                Title = "🗣️ Voice Chat Unbanned",
                Content = "Your voice chat has been unbanned!",
                Duration = 1
            })
        else
            WindUI:Notify({
                Title = "Error",
                Content = "Failed to unban voice chat: " .. tostring(err),
                Duration = 1
            })
        end
    end
})

Tabs.Misc:Button({
    Title = "☠️ Fling",
    Desc = "Carry someone, enable this, then release to fling them",
    Callback = function()
        local success, err = pcall(function()
            loadstring(game:HttpGet("https://raw.githubusercontent.com/nick0022/walkflinng/refs/heads/main/README.md", true))()
        end)
        
        if success then
            WindUI:Notify({
                Title = "☠️ Fling Activated",
                Content = "The fling script has been executed successfully!",
                Duration = 1
            })
        else
            WindUI:Notify({
                Title = "Error",
                Content = "Failed to load fling script: " .. tostring(err),
                Duration = 1
            })
        end
    end
})

Tabs.Misc:Button({
    Title = "🕳️ Void Player",
    Desc = "Carry a player, activate this, then drop them into the void",
    Callback = function()
        local player = game.Players.LocalPlayer
        local character = player.Character
        
        if not character or not character.PrimaryPart then
            WindUI:Notify({
                Title = "Error",
                Content = "Character not found or invalid!",
                Duration = 1
            })
            return
        end

        local originalPosition = character.PrimaryPart.Position
        local voidPosition = originalPosition - Vector3.new(0, 500, 0)

        WindUI:Notify({
            Title = "🕳️ Void Player",
            Content = "Preparing void teleport...",
            Duration = 1
        })

        character:SetPrimaryPartCFrame(CFrame.new(voidPosition))

        WindUI:Notify({
            Title = "🕳️ Void Player",
            Content = "Player sent to void! Releasing in 3 seconds...",
            Duration = 3
        })

        task.wait(3)
        
        if character and character.PrimaryPart then
            character:SetPrimaryPartCFrame(CFrame.new(originalPosition))
            WindUI:Notify({
                Title = "🕳️ Void Player",
                Content = "Player returned from void!",
                Duration = 1
            })
        else
            WindUI:Notify({
                Title = "Error",
                Content = "Character became invalid during process!",
                Duration = 1
            })
        end
    end
})

-- Scripts Tab
Tabs.Scripts:Button({
    Title = "📄 Infinity Yield",
    Desc = "Execute the Infinity Yield script",
    Callback = function()
        loadstring(game:HttpGet("https://raw.githubusercontent.com/EdgeIY/infiniteyield/master/source"))()
        WindUI:Notify({
            Title = "📄 Infinity Yield",
            Content = "The Infinity Yield script has been executed successfully!",
            Duration = 1
        })
    end
})

Tabs.Scripts:Button({
    Title = "📄 Moon AntiAfk",
    Desc = "Execute the Moon AntiAfk script",
    Callback = function()
        loadstring(game:HttpGet('https://raw.githubusercontent.com/rodri0022/afkmoon/refs/heads/main/README.md', true))()
        WindUI:Notify({
            Title = "📄 Moon AntiAfk",
            Content = "The Moon AntiAfk script has been executed!",
            Duration = 1
        })
    end
})

Tabs.Scripts:Button({
    Title = "📄 Moon AntiLag",
    Desc = "Execute the Moon AntiLag script",
    Callback = function()
        loadstring(game:HttpGet('https://raw.githubusercontent.com/nick0022/antilag/refs/heads/main/README.md', true))()
        WindUI:Notify({
            Title = "📄 Moon AntiLag",
            Content = "The Moon AntiLag script has been executed!",
            Duration = 1
        })
    end
})

Tabs.Scripts:Button({
    Title = "📄 FE R15 Emotes and Animation",
    Desc = "Execute the FE R15 Emotes and Animation script",
    Callback = function()
        loadstring(game:HttpGet("https://raw.githubusercontent.com/BeemTZy/Motiona/refs/heads/main/source.lua"))()
        WindUI:Notify({
            Title = "📄 FE R15 Emotes and Animation",
            Content = "The FE R15 Emotes and Animation script has been executed!",
            Duration = 1
        })
    end
})

Tabs.Scripts:Button({
    Title = "📄 Moon FE Emotes",
    Desc = "Execute the Moon Emotes script",
    Callback = function()
        loadstring(game:HttpGet('https://raw.githubusercontent.com/rodri0022/freeanimmoon/refs/heads/main/README.md', true))()
        WindUI:Notify({
            Title = "📄 Moon Emotes",
            Content = "The Moon Emotes script has been executed!",
            Duration = 1
        })
    end
})

Tabs.Scripts:Button({
    Title = "📄 Moon Troll",
    Desc = "Execute the Moon Troll script",
    Callback = function()
        loadstring(game:HttpGet('https://raw.githubusercontent.com/nick0022/trollscript/refs/heads/main/README.md'))()
        WindUI:Notify({
            Title = "📄 Moon Troll",
            Content = "The Moon Troll script has been executed!",
            Duration = 1
        })
    end
})

Tabs.Scripts:Button({
    Title = "📄 Sirius",
    Desc = "Execute the Sirius script",
    Callback = function()
        loadstring(game:HttpGet('https://sirius.menu/sirius'))()
        WindUI:Notify({
            Title = "📄 Sirius",
            Content = "The Sirius script has been executed!",
            Duration = 1
        })
    end
})

Tabs.Scripts:Button({
    Title = "📄 Keyboard",
    Desc = "Execute the Keyboard script",
    Callback = function()
        loadstring(game:HttpGet("https://raw.githubusercontent.com/GGH52lan/GGH52lan/main/keyboard.txt"))()
        WindUI:Notify({
            Title = "📄 Keyboard",
            Content = "The Keyboard script has been executed!",
            Duration = 1
        })
    end
})

Tabs.Scripts:Button({
    Title = "📄 Shader",
    Desc = "Script to make your game beautiful.",
    Callback = function()
        loadstring(game:HttpGet('https://raw.githubusercontent.com/randomstring0/pshade-ultimate/refs/heads/main/src/cd.lua'))()
        WindUI:Notify({
            Title = "📄 shader",
            Content = "o script shader foi executado!",
            Duration = 1
        })
    end
})

-- Skins Tab
-- Christmas Skins Button
Tabs.Skins:Button({
    Title = "🎅🏻 Christmas Skins",
    Desc = "Unlock all Christmas skins",
    Callback = function()
        local skins = {"XM24Fr", "XM24Fr", "XM24Bear", "XM24Eag", "XM24Br", "XM24Cr", "XM24Sq"}
        
        for _, skin in pairs(skins) do
            game:GetService("ReplicatedStorage").Events.SkinClickEvent:FireServer(skin, "v2")
            task.wait(0.1)
        end

        WindUI:Notify({
            Title = "🎅🏻 Christmas Skins Unlocked",
            Content = "All Christmas skins have been successfully unlocked!",
            Duration = 3
        })
    end
})

-- Pig Skins Button
Tabs.Skins:Button({
    Title = "🐷 Pig Skins",
    Desc = "Unlock all Pig skins",
    Callback = function()
        local skins = {"PIG1", "PIG2", "PIG3", "PIG4", "PIG5", "PIG6", "PIG7", "PIG8"}
        
        for _, skin in pairs(skins) do
            game:GetService("ReplicatedStorage").Events.SkinClickEvent:FireServer(skin, "v2")
            task.wait(0.1)
        end

        WindUI:Notify({
            Title = "🐷 Pig Skins Unlocked",
            Content = "All Pig skins have been successfully unlocked!",
            Duration = 3
        })
    end
})

-- Serviços do Roblox
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

-- Defina as localizações para facilitar a leitura
local localizacaoA = Vector3.new(-127.946053, 642.647949, 429.429596)
local localizacaoB = Vector3.new(-137.940262, 642.648254, 434.050598)

-- Função para teleportar o jogador local com espera de 2 segundos ANTES
local function TeleportarJogador(posicao)
    -- Garante que só roda no cliente
    if not RunService:IsClient() then return end 
    
    local player = Players.LocalPlayer
    if not player then return end 
    
    local character = player.Character or player.CharacterAdded:Wait()
    if not character then return end 

    local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
    if not humanoidRootPart then 
        warn("HumanoidRootPart não encontrado para teleporte.")
        return 
    end

    -- >>> Adiciona a espera de 2 segundos ANTES de teleportar <<<
    print("Aguardando 2 segundos antes do teleporte para: " .. tostring(posicao))
    task.wait(2) -- Espera por 2 segundos
    
    -- Realiza o teleporte
    print("Teleportando agora...")
    humanoidRootPart.CFrame = CFrame.new(posicao)
    
    -- Pequena espera APÓS o teleporte (pode ser útil para estabilização)
    task.wait(0.1) 
end

-- Função para disparar o evento remoto (sem alterações na espera interna)
local function DispararEventoPuzzle(numeroPuzzle)
    if not RunService:IsClient() then return end 

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
            ["action"] = "pick_up";
            ["puzzle_name"] = "PUZ" .. tostring(numeroPuzzle); 
        };
    }

    print("Disparando evento para: PUZ" .. tostring(numeroPuzzle))
    remoteEvent:FireServer(table.unpack(args))
    task.wait(0.1) -- Pequena espera após disparar o evento
end

-- Cria o botão na UI
Tabs.Skins:Button({
    Title = "Easter Event Skins", -- Nome atualizado
    Desc = "Unlock all the skins for the 2025 Easter event", -- Descrição atualizada
    Callback = function()
        print("Botão clicado! Iniciando sequência com esperas de 2 segundos antes de cada teleporte...")

        -- Loop de 1 a 25
        for i = 1, 25 do
            print("--- Iniciando ciclo " .. i .. " ---")

            -- 1. Teleportar para Localização A 
            --    (A função TeleportarJogador agora contém a espera de 2s)
            TeleportarJogador(localizacaoA) 

            -- 2. Disparar Evento Remoto PUZi
            DispararEventoPuzzle(i) 

            -- 3. Teleportar para Localização B
            --    (A função TeleportarJogador agora contém a espera de 2s)
            TeleportarJogador(localizacaoB)

            -- 4. Teleportar de volta para Localização A
            --    (A função TeleportarJogador agora contém a espera de 2s)
            TeleportarJogador(localizacaoA)

            print("--- Ciclo " .. i .. " concluído ---")
            -- A pausa de 0.5s entre os ciclos completos foi removida, 
            -- pois os waits de 2s antes de cada teleporte já adicionam bastante tempo.
            -- Se ainda quiser uma pausa extra aqui, descomente a linha abaixo:
            -- task.wait(0.5) 
        end

        print("Sequência com esperas completa!")
    end,
})

print("Easter event skins")

Tabs.Skins:Button({
    Title = "⚔️ Secret Weapon",
    Desc = "Unlock a secret sword skin",
    Callback = function()
        local args = {
            [1] = "SSSSSSS2";
        }
        
        game:GetService("ReplicatedStorage"):WaitForChild("Events", 9e9):WaitForChild("WeaponEvent", 9e9):FireServer(table.unpack(args))

        WindUI:Notify({
            Title = "⚔️ Secret Weapon Unlocked",
            Content = "Secret sword skin has been successfully unlocked!",
            Duration = 3
        })
    end
})

Tabs.Skins:Button({
    Title = "⚔️ Secret Weapon2",
    Desc = "Unlock a secret sword skin",
    Callback = function()
        local args = {
            [1] = "SSSSSSS4";
        }
        
        game:GetService("ReplicatedStorage"):WaitForChild("Events", 9e9):WaitForChild("WeaponEvent", 9e9):FireServer(table.unpack(args))

        WindUI:Notify({
            Title = "⚔️ Secret Weapon2 Unlocked",
            Content = "Secret sword skin has been successfully unlocked!",
            Duration = 3
        })
    end
})

Tabs.Skins:Button({
    Title = "⚔️ Secret Weapon3",
    Desc = "Unlock a secret sword skin",
    Callback = function()
        local args = {
            [1] = "SSSS2";
        }
        
        game:GetService("ReplicatedStorage"):WaitForChild("Events", 9e9):WaitForChild("WeaponEvent", 9e9):FireServer(table.unpack(args))

        WindUI:Notify({
            Title = "⚔️ Secret Weapon3 Unlocked",
            Content = "Secret sword skin has been successfully unlocked!",
            Duration = 3
        })
    end
})

Tabs.Skins:Button({
    Title = "⚔️ Secret Weapon4",
    Desc = "Unlock a secret sword skin",
    Callback = function()
        local args = {
            [1] = "SSSS1";
        }
        
        game:GetService("ReplicatedStorage"):WaitForChild("Events", 9e9):WaitForChild("WeaponEvent", 9e9):FireServer(table.unpack(args))

        WindUI:Notify({
            Title = "⚔️ Secret Weapon4 Unlocked",
            Content = "Secret sword skin has been successfully unlocked!",
            Duration = 3
        })
    end
})

--[[
    SETTINGS TAB
]]

-- Missing function definitions
local function updateSpamDropdown()
    -- Placeholder for spam dropdown update
    -- This function is referenced but not implemented in the current code
end

local function setupKeybindListener()
    -- Placeholder for keybind listener setup
    -- This function is referenced but not implemented in the current code
end

-- Global variable declaration
local currentKeybind = Enum.KeyCode.RightControl -- Default keybind

-- Update Lists Button
local function manualUpdateAllDropdowns()
    updateTeleportDropdown()
    updateSpectateDropdown()
    updateSpamDropdown()
    
    WindUI:Notify({
        Title = "🔄 Lists Updated",
        Content = "All player lists have been updated!",
        Duration = 1
    })
end

Tabs.Settings:Button({
    Title = "🔄 Update Player Lists",
    Desc = "Click to manually update all player lists",
    Callback = manualUpdateAllDropdowns
})

Tabs.Settings:Button({
    Title = "🔃 Rejoin Game",
    Desc = "Rejoin the current game session",
    Callback = function()
        game:GetService("TeleportService"):TeleportToPlaceInstance(game.PlaceId, game.JobId)
        WindUI:Notify({
            Title = "Rejoining Game",
            Content = "Attempting to rejoin the current session...",
            Duration = 1
        })
    end
})

Tabs.Settings:Section({ Title = "Window Configuration" })

local themeValues = {}
for name, _ in pairs(WindUI:GetThemes()) do
    table.insert(themeValues, name)
end

local themeDropdown = Tabs.Settings:Dropdown({
    Title = "Select Theme",
    Desc = "Change the UI theme",
    Values = themeValues,
    Multi = false,
    Default = WindUI:GetCurrentTheme(),
    Callback = function(theme)
        WindUI:SetTheme(theme)
    end
})

local transparencyToggle = Tabs.Settings:Toggle({
    Title = "Window Transparency",
    Desc = "Toggle window transparency effect",
    Value = WindUI:GetTransparency(),
    Callback = function(state)
        Window:ToggleTransparency(state)
    end
})

Tabs.Settings:Section({ Title = "Save/Load Configuration" })

local configName = ""

Tabs.Settings:Input({
    Title = "Configuration Name",
    Desc = "Enter a name for your config",
    Default = "",
    PlaceholderText = "MyConfig",
    Callback = function(text)
        configName = text
    end
})

local configFiles = listfiles("MoonHUB") or {}
local configDropdown = Tabs.Settings:Dropdown({
    Title = "Saved Configurations",
    Desc = "Select a configuration to load",
    Values = configFiles,
    Multi = false,
    Default = nil,
    Callback = function(selected)
        configName = selected
    end
})

Tabs.Settings:Button({
    Title = "💾 Save Configuration",
    Desc = "Save current settings to file",
    Callback = function()
        if configName ~= "" then
            -- Criar a pasta MoonHUB se não existir
            if not isfolder("MoonHUB") then
                makefolder("MoonHUB")
            end
            
            local configData = {
                Theme = WindUI:GetCurrentTheme(),
                Transparency = WindUI:GetTransparency(),
                WalkSpeed = WalkSpeedConfig.CurrentSpeed,
                ESPEnabled = ESPConfig.Enabled,
                Keybind = tostring(currentKeybind) -- Alterado para usar currentKeybind
            }
            
            local success, err = pcall(function()
                writefile("MoonHUB/"..configName..".json", game:GetService("HttpService"):JSONEncode(configData))
            end)
            
            if success then
                WindUI:Notify({
                    Title = "Configuration Saved",
                    Content = "Settings saved as: "..configName,
                    Duration = 3
                })
                -- Atualizar a lista de configurações
                configFiles = listfiles("MoonHUB") or {}
                configDropdown:Refresh(configFiles)
            else
                WindUI:Notify({
                    Title = "Error",
                    Content = "Failed to save config: "..tostring(err),
                    Duration = 3
                })
            end
        else
            WindUI:Notify({
                Title = "Error",
                Content = "Please enter a configuration name!",
                Duration = 2
            })
        end
    end
})

Tabs.Settings:Button({
    Title = "📂 Load Configuration",
    Desc = "Load settings from file",
    Callback = function()
        if configName ~= "" and isfile("MoonHUB/"..configName..".json") then
            local success, configData = pcall(function()
                return game:GetService("HttpService"):JSONDecode(readfile("MoonHUB/"..configName..".json"))
            end)
            
            if success and configData then
                -- Aplicar configurações carregadas
                if configData.Theme then
                    WindUI:SetTheme(configData.Theme)
                    themeDropdown:Select(configData.Theme)
                end
                
                if configData.Transparency ~= nil then
                    Window:ToggleTransparency(configData.Transparency)
                    transparencyToggle:SetValue(configData.Transparency)
                end
                
                if configData.WalkSpeed then
                    WalkSpeedConfig.CurrentSpeed = configData.WalkSpeed
                    updateWalkSpeed(configData.WalkSpeed)
                end
                
                if configData.ESPEnabled ~= nil then
                    ToggleESP(configData.ESPEnabled)
                end
                
                if configData.Keybind then
                    currentKeybind = Enum.KeyCode[configData.Keybind]
                    Window:SetToggleKey(currentKeybind)
                    setupKeybindListener()
                end
                
                WindUI:Notify({
                    Title = "Configuration Loaded",
                    Content = "Settings loaded from: "..configName,
                    Duration = 3
                })
            else
                WindUI:Notify({
                    Title = "Error",
                    Content = "Failed to load config!",
                    Duration = 3
                })
            end
        else
            WindUI:Notify({
                Title = "Error",
                Content = "Config file not found!",
                Duration = 2
            })
        end
    end
})

Tabs.Settings:Button({
    Title = "🔄 Refresh Config List",
    Desc = "Update the list of saved configurations",
    Callback = function()
        configFiles = listfiles("MoonHUB") or {}
        configDropdown:Refresh(configFiles)
        WindUI:Notify({
            Title = "Config List Updated",
            Content = "Configuration list has been refreshed",
            Duration = 1
        })
    end
})

-- Settings: Toggle role tags on/off
Tabs.Settings:Toggle({
    Title = "Overhead Role Tags",
    Desc = "Turn OFF to remove all tags and stop updates",
    Value = true,
    Callback = function(state)
        if state then
            Tag_startScanner()
            WindUI:Notify({ Title = "Tags", Content = "Role tags enabled", Duration = 2 })
        else
            Tag_stopScanner()
            Tag_clearAllNow()
            WindUI:Notify({ Title = "Tags", Content = "Role tags disabled", Duration = 2 })
        end
    end
})

-- Corrigindo o sistema de dropdowns para evitar erros de nil
-- (Removed duplicate redefinitions of dropdown update helpers)

-- Initial updates
updateTeleportDropdown()
updateSpectateDropdown()

-- (Removed duplicate declaration of TargetedPlayer)

-- Select first tab and show notification
WindUI:Notify({
    Title = "Script Fully Loaded!",
    Content = "Happy using, remembering that all functions are undetectable!",
    Duration = 10
})


-- Hook into the game's animal selection system
local function setupAnimalDetection()
    -- Function to wire each animal species (non-blocking)
    local function wireSpecies(folder)
        task.spawn(function()
            for _, skin in ipairs(folder:GetChildren()) do
                local frame = skin:FindFirstChild("Frame")
                if frame then
                    local button = frame:FindFirstChild("Button")
                    if button then
                        -- Disconnect any existing connections to avoid duplicates
                        pcall(function()
                            -- getconnections is a Roblox exploit function - safe to use in this context
                            if getconnections then
                                for _, connection in pairs(getconnections(button.MouseButton1Click)) do
                                    connection:Disconnect()
                                end
                            end
                        end)
                        
                        -- Add our custom handler
                        button.MouseButton1Click:Connect(function()
                            -- Handle based on toggle state
                            if godmodeToggle then
                                -- Store selection for godmode
                                handleAnimalClick(folder.Name, skin.Name)
                            else
                                -- Spawn animal immediately
                                spawnAnimal(folder.Name, skin.Name)
                            end
                        end)
                    end
                end
                task.wait(0.01) -- Small delay between each button to prevent lag
            end
        end)
        
        -- Handle new animals added
        folder.ChildAdded:Connect(function(child)
            task.spawn(function()
                task.wait(0.2) -- Wait for child to fully load
                local frame = child:FindFirstChild("Frame")
                if frame then
                    local button = frame:FindFirstChild("Button")
                    if button then
                        button.MouseButton1Click:Connect(function()
                            -- Handle based on toggle state
                            if godmodeToggle then
                                -- Store selection for godmode
                                handleAnimalClick(folder.Name, child.Name)
                            else
                                -- Spawn animal immediately
                                spawnAnimal(folder.Name, child.Name)
                            end
                        end)
                    end
                end
            end)
        end)
    end
    
    -- Completely non-blocking setup
    local function asyncSetup()
        local success, gui = pcall(function()
            -- Use very short timeouts and async approach
            local playerGui = plr:WaitForChild("PlayerGui", 1)
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
            -- Wire existing species in background
            task.spawn(function()
                for _, spec in ipairs(gui:GetChildren()) do
                    wireSpecies(spec)
                    task.wait(0.05) -- Small delay between species
                end
                
                -- Handle new species
                gui.ChildAdded:Connect(wireSpecies)
                
                -- Success notification removed to prevent startup spam
            end)
            
            return true
        else
            return false
        end
    end
    
    -- Non-blocking retry
    local attempts = 0
    local maxAttempts = 2
    
    local function tryNext()
        if attempts >= maxAttempts then
            -- Silent fail - no warning notification
            return
        end
        
        attempts = attempts + 1
        if asyncSetup() then
            return
        else
            task.wait(1) -- Wait 1 second before retrying
            tryNext()
        end
    end
    
    tryNext()
end

-- Call this when the script loads with a proper delay to avoid lag
task.spawn(function()
    -- Wait for the game to fully load before attempting to hook into GUI
    task.wait(8)
    setupAnimalDetection()

end)

-- NPC Flinger Feature (exact Rayfield implementation)
Tabs.Premium:Section({ Title = "NPC Flinger" })

-- NPC Flinger variables
local LocalPlayer = game.Players.LocalPlayer
local npcPlayerList = {}
local npcNPCList = {}
local selectedNPCPlayer = ""
local selectedNPCTarget = ""
local npcFlingActive = false
local npcFlingThread = nil

-- Default FallenPartsDestroyHeight to restore later
getgenv().FPDH = getgenv().FPDH or 500

-- Helper functions for NPC Flinger
local function refreshNPCPlayerList()
    npcPlayerList = {}
    for _, p in ipairs(game.Players:GetPlayers()) do
        if p ~= LocalPlayer then
            table.insert(npcPlayerList, p.Name)
        end
    end
end

local function refreshNPCTargetList()
    npcNPCList = {}
    -- Check multiple possible NPC locations
    local npcFolders = {"NPC", "NPCs", "Enemies", "Bosses"}
    
    for _, folderName in ipairs(npcFolders) do
        local folder = workspace:FindFirstChild(folderName)
        if folder then
            for _, npc in ipairs(folder:GetChildren()) do
                if npc:FindFirstChild("HumanoidRootPart") and npc:FindFirstChildOfClass("Humanoid") then
                    table.insert(npcNPCList, npc.Name)
                end
            end
        end
    end
    
    -- Also check for NPCs in workspace directly
    for _, npc in ipairs(workspace:GetChildren()) do
        if npc:FindFirstChild("HumanoidRootPart") and npc:FindFirstChildOfClass("Humanoid") and 
           npc.Name ~= LocalPlayer.Name and npc ~= LocalPlayer.Character then
            -- Check if it's likely an NPC (not a player character)
            if not game.Players:FindFirstChild(npc.Name) then
                table.insert(npcNPCList, npc.Name)
            end
        end
    end
end

-- Initialize lists
refreshNPCPlayerList()
refreshNPCTargetList()

-- Set default FPDH value if not exists
if not getgenv().FPDH then
    getgenv().FPDH = 500
end

-- Player join/leave event handlers
game:GetService("Players").PlayerAdded:Connect(function(p)
    if p ~= LocalPlayer then
        table.insert(npcPlayerList, p.Name)
    end
end)

game:GetService("Players").PlayerRemoving:Connect(function(p)
    for i, name in ipairs(npcPlayerList) do
        if name == p.Name then
            table.remove(npcPlayerList, i)
            break
        end
    end
end)

-- Auto-refresh lists every 10 seconds to keep them updated
task.spawn(function()
    while task.wait(10) do
        refreshNPCPlayerList()
        refreshNPCTargetList()
        
        -- Update dropdowns if they exist (with error handling)
        pcall(function()
            if npcPlayerDropdown and npcPlayerDropdown.Refresh then
                npcPlayerDropdown:Refresh(npcPlayerList)
            end
        end)
        pcall(function()
            if npcTargetDropdown and npcTargetDropdown.Refresh then
                npcTargetDropdown:Refresh(npcNPCList)
            end
        end)
    end
end)

Tabs.Premium:Paragraph({
    Title = "How to use",
    Desc = "Select the player you want to fly from the map, then any boss (the crab boss is recommended) and click to start flinging. This feature is in testing and will be updated to support every animal simulator update."
})

-- NPC Player Dropdown
local npcPlayerDropdown = Tabs.Premium:Dropdown({
    Title = "Select Target Player",
    Values = npcPlayerList,
    Multi = false,
    Default = selectedNPCPlayer,
    Callback = function(choice)
        selectedNPCPlayer = choice
    end
})

-- NPC Target Dropdown
local npcTargetDropdown = Tabs.Premium:Dropdown({
    Title = "Select NPC to Control",
    Values = npcNPCList,
    Multi = false,
    Default = selectedNPCTarget,
    Callback = function(choice)
        selectedNPCTarget = choice
    end
})

        -- Combined refresh button for both lists
        Tabs.Premium:Button({
            Title = "Refresh Lists",
            Callback = function()
                refreshNPCPlayerList()
                refreshNPCTargetList()
                
                -- Update dropdowns with error handling
                pcall(function()
                    if npcPlayerDropdown and npcPlayerDropdown.Refresh then
                        npcPlayerDropdown:Refresh(npcPlayerList)
                    end
                end)
                pcall(function()
                    if npcTargetDropdown and npcTargetDropdown.Refresh then
                        npcTargetDropdown:Refresh(npcNPCList)
                    end
                end)
                
                WindUI:Notify({Title = "NPC Flinger", Content = "Both lists refreshed!", Duration = 2})
            end
        })

-- // ATTACH / CONTROL (exact Rayfield-style recipe)
local function controlNPC(npc, targetPlayer)
    if not npc or not targetPlayer then return false, "bad args" end

    local npcRootPart = npc:FindFirstChild("HumanoidRootPart")
    local playerChar  = LocalPlayer.Character
    local playerRoot  = playerChar and playerChar:FindFirstChild("HumanoidRootPart")

    if not (npcRootPart and playerRoot) then
        WindUI:Notify({Title = "NPC Fling", Content = "Could not find HumanoidRootPart!", Duration = 3})
        return false, "missing hrp"
    end

    -- Disable all NPC collisions
    for _, d in ipairs(npc:GetDescendants()) do
        if d:IsA("BasePart") then
            d.CanCollide = false
        end
    end

    -- Create alignment rig between NPC HRP (A0) and your HRP (A1)
    local A0 = Instance.new("Attachment"); A0.Name = "NPC_A0"; A0.Parent = npcRootPart
    local A1 = Instance.new("Attachment"); A1.Name = "PLY_A1"; A1.Parent = playerRoot

    local AP = Instance.new("AlignPosition");   AP.Parent = npcRootPart
    AP.Responsiveness = 200; AP.MaxForce = math.huge
    AP.Attachment0 = A0; AP.Attachment1 = A1

    local AO = Instance.new("AlignOrientation"); AO.Parent = npcRootPart
    AO.Responsiveness = 200; AO.MaxTorque = math.huge
    AO.Attachment0 = A0; AO.Attachment1 = A1

    -- Place your HRP beside the NPC and hard-couple it
    playerRoot.Position = npcRootPart.Position + Vector3.new(5, 0, 0)

    -- Anchor head/torso and break joints on your HRP (aggressive coupling)
    local head  = playerChar:FindFirstChild("Head")
    local torso = playerChar:FindFirstChild("UpperTorso") or playerChar:FindFirstChild("Torso")
    if head then head.Anchored = true end
    if torso then torso.Anchored = true end
    playerRoot:BreakJoints()

    task.wait(0.1)

    local ok = (AP.Attachment0 and AP.Attachment1 and AO.Attachment0 and AO.Attachment1)
    if ok then
        WindUI:Notify({Title = "NPC Fling", Content = "NPC attachment successful!", Duration = 2})
        return true
    else
        WindUI:Notify({Title = "NPC Fling", Content = "Attachment failed!", Duration = 3})
        return false, "attachments nil"
    end
end

-- // Core reposition helper used by the fling sequence
local function _npcSetCF(controlledNPC, hrp, cf)
    if hrp then hrp.CFrame = cf end
    if controlledNPC and controlledNPC.PrimaryPart then
        controlledNPC:SetPrimaryPartCFrame(cf)
    end
end

-- // FLING ENGINE (Rayfield logic)
local function NPCSkidFling(targetPlayer, controlledNPC)
    if not targetPlayer or not targetPlayer.Character then return false, "bad target" end
    if not controlledNPC then return false, "no npc" end

    local TChar     = targetPlayer.Character
    local THumanoid = TChar:FindFirstChildOfClass("Humanoid")
    local TRootPart = THumanoid and THumanoid.RootPart
    local THead     = TChar:FindFirstChild("Head")
    local Accessory = TChar:FindFirstChildOfClass("Accessory")
    local Handle    = Accessory and Accessory:FindFirstChild("Handle")

    local npcHRP      = controlledNPC:FindFirstChild("HumanoidRootPart")
    local npcHumanoid = controlledNPC:FindFirstChildOfClass("Humanoid")
    if not (npcHRP and npcHumanoid) then return false, "npc missing hrp/hum" end

    local originalNPCPos = npcHRP.CFrame

    -- Camera follows target
    local cam = workspace.CurrentCamera
    if THead then
        cam.CameraSubject = THead
    elseif Handle then
        cam.CameraSubject = Handle
    elseif THumanoid then
        cam.CameraSubject = THumanoid
    end

    -- Prevent auto-despawn while flinging
    local _oldFPDH = workspace.FallenPartsDestroyHeight
    workspace.FallenPartsDestroyHeight = 0/0 -- NaN trick
    

    
    -- Impulse source (matches Rayfield's values)
    local BV = Instance.new("BodyVelocity")
    BV.Name = "EpixVel"
    BV.Velocity = Vector3.new(9e8, 9e8, 9e8)
    BV.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
    BV.Parent = npcHRP

    -- Don't get seated during fling
    npcHumanoid:SetStateEnabled(Enum.HumanoidStateType.Seated, false)
    
    -- Position step (no extra velocity writes — strictly CF moves)
    local function NPCFPos(BasePart, Pos, Ang)
        local cf = CFrame.new(BasePart.Position) * Pos * Ang
        _npcSetCF(controlledNPC, npcHRP, cf)
    end
    
    -- Rayfield spin/offset sequencer (Extended for better network ownership)
    local function NPCSFBasePart(BasePart)
        local TimeToWait = 2  -- Fixed timing to match working version
        local Time = tick()
        local Angle = 0
        local flingStarted = false

        repeat
            if npcHRP and THumanoid then
                if BasePart.Velocity.Magnitude < 50 then
                    Angle = Angle + 100
                    NPCFPos(BasePart, CFrame.new(0,  1.5, 0) + THumanoid.MoveDirection * BasePart.Velocity.Magnitude / 1.25, CFrame.Angles(math.rad(Angle), 0, 0)); task.wait()
                    NPCFPos(BasePart, CFrame.new(0, -1.5, 0) + THumanoid.MoveDirection * BasePart.Velocity.Magnitude / 1.25, CFrame.Angles(math.rad(Angle), 0, 0)); task.wait()
                    NPCFPos(BasePart, CFrame.new( 2.25, 1.5,-2.25) + THumanoid.MoveDirection * BasePart.Velocity.Magnitude / 1.25, CFrame.Angles(math.rad(Angle), 0, 0)); task.wait()
                    NPCFPos(BasePart, CFrame.new(-2.25,-1.5, 2.25) + THumanoid.MoveDirection * BasePart.Velocity.Magnitude / 1.25, CFrame.Angles(math.rad(Angle), 0, 0)); task.wait()
                    NPCFPos(BasePart, CFrame.new(0,  1.5, 0) + THumanoid.MoveDirection, CFrame.Angles(math.rad(Angle), 0, 0)); task.wait()
                    NPCFPos(BasePart, CFrame.new(0, -1.5, 0) + THumanoid.MoveDirection, CFrame.Angles(math.rad(Angle), 0, 0)); task.wait()
                else
                    flingStarted = true
                    NPCFPos(BasePart, CFrame.new(0,  1.5,  THumanoid.WalkSpeed),                           CFrame.Angles(math.rad(90), 0, 0)); task.wait()
                    NPCFPos(BasePart, CFrame.new(0, -1.5, -THumanoid.WalkSpeed),                           CFrame.Angles(0, 0, 0));         task.wait()
                    NPCFPos(BasePart, CFrame.new(0,  1.5,  THumanoid.WalkSpeed),                           CFrame.Angles(math.rad(90), 0, 0)); task.wait()
                    NPCFPos(BasePart, CFrame.new(0,  1.5,  TRootPart and TRootPart.Velocity.Magnitude/1.25 or 0), CFrame.Angles(math.rad(90), 0, 0)); task.wait()
                    NPCFPos(BasePart, CFrame.new(0, -1.5, -(TRootPart and TRootPart.Velocity.Magnitude/1.25 or 0)), CFrame.Angles(0, 0, 0));           task.wait()
                    NPCFPos(BasePart, CFrame.new(0,  1.5,  TRootPart and TRootPart.Velocity.Magnitude/1.25 or 0), CFrame.Angles(math.rad(90), 0, 0)); task.wait()
                    NPCFPos(BasePart, CFrame.new(0, -1.5, 0),                                                   CFrame.Angles(math.rad(90), 0, 0)); task.wait()
                    NPCFPos(BasePart, CFrame.new(0, -1.5, 0),                                                   CFrame.Angles(0, 0, 0));           task.wait()
                    NPCFPos(BasePart, CFrame.new(0, -1.5, 0),                                                   CFrame.Angles(math.rad(-90), 0, 0)); task.wait()
                    NPCFPos(BasePart, CFrame.new(0, -1.5, 0),                                                   CFrame.Angles(0, 0, 0));           task.wait()

                    if flingStarted then
                        _npcSetCF(controlledNPC, npcHRP, originalNPCPos)
                        break
                    end
                end
            else
                break
            end
        until BasePart.Velocity.Magnitude > 500  -- Fixed threshold to match working version
           or BasePart.Parent ~= targetPlayer.Character
           or targetPlayer.Parent ~= game:GetService("Players")
           or not (targetPlayer.Character == TChar)
           or (THumanoid and THumanoid.Sit)
           or npcHumanoid.Health <= 0
           or tick() > Time + TimeToWait  -- Now 2 seconds instead of 6
           or flingStarted
    end
    
    -- Choose best target part (fallback order)
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
    
    -- Reset NPC near its original spot
    _npcSetCF(controlledNPC, npcHRP, originalNPCPos)
    if npcHRP then
        npcHRP.Velocity = Vector3.new(0, 0, 0)
        npcHRP.RotVelocity = Vector3.new(0, 0, 0)
    end

    -- Cleanup impulse + restore flags/camera
    BV:Destroy()
    npcHumanoid:SetStateEnabled(Enum.HumanoidStateType.Seated, true)
    local myHum = (LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid"))
    if myHum then workspace.CurrentCamera.CameraSubject = myHum end

    -- Reliability tail: "get up", zero velocities, nudge back repeatedly
    repeat
        _npcSetCF(controlledNPC, npcHRP, originalNPCPos * CFrame.new(0, 0.5, 0))
        npcHumanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
        for _, x in ipairs(controlledNPC:GetChildren()) do
            if x:IsA("BasePart") then
                x.Velocity = Vector3.new()
                x.RotVelocity = Vector3.new()
            end
        end
        task.wait()
    until (npcHRP.Position - originalNPCPos.p).Magnitude < 25

    -- Restore FallenPartsDestroyHeight
    workspace.FallenPartsDestroyHeight = getgenv().FPDH or _oldFPDH or 500

    -- Hard cleanup: kill NPC (prevents lingering constraints/issues)
    local hum = controlledNPC:FindFirstChildOfClass("Humanoid")
    if hum then
        for _, part in ipairs(controlledNPC:GetDescendants()) do
            if part:IsA("BasePart") then part:BreakJoints() end
        end
        hum.Health = 0
        WindUI:Notify({Title = "NPC Fling", Content = "NPC killed immediately after fling!", Duration = 2})
    end
    
    WindUI:Notify({Title = "NPC Fling", Content = "NPC SkidFling completed on " .. targetPlayer.Name, Duration = 3})
    return true
end

-- // Public wrapper that does Attach -> Fling (1:1 with Rayfield flow)
local function WalkFling(targetPlayer, controlledNPC)
    local ok, why = controlNPC(controlledNPC, targetPlayer)
    if not ok then return false, "attach failed: " .. tostring(why) end
    task.wait(1)
    local ok2, why2 = NPCSkidFling(targetPlayer, controlledNPC)
    return ok2, why2
end

local function findSelectedNPCByName(name)
    if not name or name == "" then return nil end
    local folders = {"NPC", "NPCs", "Enemies", "Bosses"}
    for _, folderName in ipairs(folders) do
        local folder = workspace:FindFirstChild(folderName)
        if folder then
            local npc = folder:FindFirstChild(name)
            if npc then return npc end
        end
    end
    -- fallback: direct workspace (exclude player characters)
    local cand = workspace:FindFirstChild(name)
    if cand and cand:FindFirstChild("HumanoidRootPart") and cand:FindFirstChildOfClass("Humanoid") and not game.Players:FindFirstChild(name) then
        return cand
    end
    return nil
end

-- Start NPC Flinging Button
Tabs.Premium:Button({
    Title = "Start NPC Flinging",
    Callback = function()
        if npcFlingActive then
            WindUI:Notify({Title = "NPC Fling", Content = "Already running!", Duration = 2})
            return
        end
        
        if selectedNPCPlayer == "" or selectedNPCTarget == "" then
            WindUI:Notify({Title = "NPC Fling", Content = "Please select both a player and NPC!", Duration = 3})
            return
        end
        
        -- Debug info
        WindUI:Notify({Title = "NPC Fling", Content = "Selected Player: " .. selectedNPCPlayer .. " | NPC: " .. selectedNPCTarget, Duration = 3})
        
        local targetPlayer = game.Players:FindFirstChild(selectedNPCPlayer)
        local targetNPC = findSelectedNPCByName(selectedNPCTarget)
        
        if not targetPlayer then
            WindUI:Notify({Title = "NPC Fling", Content = "Target player not found: " .. selectedNPCPlayer, Duration = 3})
            return
        end
        
        if not targetNPC then
            WindUI:Notify({Title = "NPC Fling", Content = "Target NPC not found: " .. selectedNPCTarget, Duration = 3})
            return
        end
        
        -- Debug info
        WindUI:Notify({Title = "NPC Fling", Content = "Found Player: " .. targetPlayer.Name .. " | NPC: " .. targetNPC.Name, Duration = 3})
        
        npcFlingActive = true
        npcFlingThread = task.spawn(function()
            WindUI:Notify({Title = "NPC Fling", Content = "Starting NPC flinging...", Duration = 2})
            
            -- Start remote spamming for the selected NPC BEFORE fling starts
            local remoteSpamActive = true
            local remoteSpamThread = task.spawn(function()
                while remoteSpamActive do
                    -- Spam remote with selected NPC
                    local args = {
                        targetNPC,  -- Use the selected NPC from dropdown
                        1
                    }
                    
                    if game:GetService("ReplicatedStorage"):FindFirstChild("jdskhfsIIIllliiIIIdchgdIiIIIlIlIli") then
                        game:GetService("ReplicatedStorage").jdskhfsIIIllliiIIIdchgdIiIIIlIlIli:FireServer(unpack(args))
                    end
                    
                    task.wait(0.1)  -- Spam every 0.1 seconds
                end
            end)
            
            -- Wrap the fling in pcall for error handling
            local flingSuccess, errorMsg = pcall(function()
                return WalkFling(targetPlayer, targetNPC)
            end)
            
            if not flingSuccess then
                WindUI:Notify({Title = "NPC Fling", Content = "Fling crashed: " .. tostring(errorMsg), Duration = 3})
                remoteSpamActive = false
                if remoteSpamThread then
                    task.cancel(remoteSpamThread)
                    remoteSpamThread = nil
                end
                npcFlingActive = false
                return
            end
            
            if not errorMsg then
                WindUI:Notify({Title = "NPC Fling", Content = "Fling failed: " .. tostring(errorMsg), Duration = 3})
                remoteSpamActive = false
                if remoteSpamThread then
                    task.cancel(remoteSpamThread)
                    remoteSpamThread = nil
                end
                npcFlingActive = false
                return
            end
            
            task.wait(2)
            
            -- Stop remote spamming AFTER fling completes
            remoteSpamActive = false
            if remoteSpamThread then
                task.cancel(remoteSpamThread)
                remoteSpamThread = nil
            end
            
            if LocalPlayer.Character then
                LocalPlayer.Character:BreakJoints()
                WindUI:Notify({Title = "NPC Fling", Content = "Character reset to clean up!", Duration = 2})
            end
            
            task.wait(2)
            if LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid") then
                workspace.CurrentCamera.CameraSubject = LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
                WindUI:Notify({Title = "NPC Fling", Content = "Camera view reset to you!", Duration = 2})
            end
            
            npcFlingActive = false
            if flingSuccess then
                WindUI:Notify({Title = "NPC Fling", Content = "NPC flinging completed successfully! Character reset.", Duration = 3})
            else
                WindUI:Notify({Title = "NPC Fling", Content = "NPC flinging completed but fling may have failed!", Duration = 3})
            end
        end)
    end
})

-- Stop NPC Flinging Button
Tabs.Premium:Button({
    Title = "Stop NPC Flinging",
    Callback = function()
        npcFlingActive = false
        if npcFlingThread then
            npcFlingThread = nil
        end
        WindUI:Notify({Title = "NPC Fling", Content = "Stopped!", Duration = 2})
    end
})

--[[
    PVP UTILITY FUNCTIONS
]]

-- Target priority system
local targetPriority = "Closest" -- Default priority
local detectionRadius = 70 -- Default detection radius

-- Function to get valid targets sorted by priority
local function getValidTargetsSorted(priority)
    local lp = game.Players.LocalPlayer
    local char = lp and lp.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if not root then return {} end

    local myPos = root.Position
    local targets = {}
    local maxDist = tonumber(detectionRadius) or 70
    
    for _, p in ipairs(game.Players:GetPlayers()) do
        if p ~= lp and p.Character then
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
    -- normalize aliases
    if method == "lowest health" or method == "low health" or method == "lowest" or method == "health" then
        table.sort(targets, function(a,b) return a.health < b.health end)
    else
        table.sort(targets, function(a,b) return a.distance < b.distance end)
    end
    return targets
end



--[[
    PVP TAB UI
]]

