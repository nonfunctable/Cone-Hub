local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GuiService = game:GetService("GuiService")
local HttpService = game:GetService("HttpService")
local VirtualUser = game:GetService("VirtualUser")
local VirtualInputManager = game:GetService("VirtualInputManager")

local plr = Players.LocalPlayer
local nv = ReplicatedStorage:WaitForChild("NeonVault")
local req = nv:WaitForChild("Request")
local rev = nv:WaitForChild("RevealDone")
local stateChanged = nv:WaitForChild("StateChanged")

local CrateConfig = require(nv:WaitForChild("CrateConfig"))
local GamePasses = require(nv:WaitForChild("GamePasses"))

local env = (getgenv and getgenv()) or shared
local prevSession = env.__RLCrateSession
if env.__RLCrateAutoCleanup then
    pcall(env.__RLCrateAutoCleanup)
end
if env.__RLCrateFluentCleanup then
    pcall(env.__RLCrateFluentCleanup)
end

local function loadRemoteModule(primaryUrl, fallbackUrl)
    local ok, src = pcall(function()
        return game:HttpGet(primaryUrl)
    end)
    if ok and type(src) == "string" and #src > 100 and not src:find("^404:") then
        local fn = loadstring(src)
        if fn then
            return fn()
        end
    end
    return loadstring(game:HttpGet(fallbackUrl))()
end

local repoBase = "https://raw.githubusercontent.com/nonfunctable/Cone-Hub/main/UI/"
local Fluent = loadRemoteModule(
    repoBase .. "Fluent.lua",
    "https://github.com/dawid-scripts/Fluent/releases/latest/download/main.lua"
)
local SaveManager = loadRemoteModule(
    repoBase .. "SaveManager.lua",
    "https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Addons/SaveManager.lua"
)
local InterfaceManager = loadRemoteModule(
    repoBase .. "InterfaceManager.lua",
    "https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Addons/InterfaceManager.lua"
)

local settingsPath = "ConeHub/RLCrateSim_State.json"

local function loadSavedSettings()
    if isfile and readfile then
        local ok, raw = pcall(function()
            if isfile(settingsPath) then
                return readfile(settingsPath)
            end
            return nil
        end)
        if ok and type(raw) == "string" and #raw > 0 then
            local decOk, data = pcall(function()
                return HttpService:JSONDecode(raw)
            end)
            if decOk and type(data) == "table" then
                return data
            end
        end
    end
    return {}
end

local saved = loadSavedSettings()

local running = true
local ready = false
local autoOpen = (saved.autoOpen == true)
local selectedSeries = (type(saved.selectedSeries) == "string" and CrateConfig.Series[saved.selectedSeries]) and saved.selectedSeries or "noncrate"
local openAmount = math.clamp(tonumber(saved.openAmount) or 1, 1, 3)
local autoTasks = (saved.autoTasks == true)
local antiAfk = (saved.antiAfk ~= false)

local openedCount = (prevSession and tonumber(prevSession.openedCount)) or 0
local statusText = autoOpen and "Starting..." or "Idle"
local recentPulls = (prevSession and type(prevSession.recentPulls) == "table") and prevSession.recentPulls or {}
local serverState = nil
local awardToken = nil
local conns = {}

local function saveCurrentSettings()
    if not ready then
        return
    end
    if writefile and makefolder and isfolder then
        pcall(function()
            if not isfolder("ConeHub") then
                makefolder("ConeHub")
            end
            writefile(settingsPath, HttpService:JSONEncode({
                autoOpen = autoOpen,
                selectedSeries = selectedSeries,
                openAmount = openAmount,
                autoTasks = autoTasks,
                antiAfk = antiAfk,
            }))
        end)
    end
end

local function syncClientState(st, tag)
    if type(st) ~= "table" then
        return
    end
    serverState = st
    if st.AwardToken then
        awardToken = st.AwardToken
    end
    if getconnections then
        for _, c in ipairs(getconnections(stateChanged.OnClientEvent)) do
            if c.Function then
                task.spawn(pcall, c.Function, st, tag or "Open")
            end
        end
    end
end

local function fetchState()
    local ok, res = pcall(function()
        return req:InvokeServer("State")
    end)
    if ok and type(res) == "table" and type(res.State) == "table" then
        syncClientState(res.State, "State")
        return res.State
    end
    return serverState
end

local function getOpenSpeed()
    local ok, spd = pcall(function()
        local boost = (plr:GetAttribute("SpeedBoostUntil") or 0) > workspace:GetServerTimeNow()
        local gift = (plr:GetAttribute("SpeedGiftUntil") or 0) > workspace:GetServerTimeNow()
        local mult = nv:GetAttribute("SpeedEventMult")
        local vip = serverState and serverState.Passes and serverState.Passes.VIP == true
        return GamePasses.OpenSpeed(serverState, mult, boost, gift, vip)
    end)
    return (ok and type(spd) == "number" and spd > 0) and spd or 1
end

local function getFreeXpLeft()
    if not serverState or type(serverState.FreeXP) ~= "table" then
        return 500
    end
    local dt = os.time() - (tonumber(serverState.FreeXP.Start) or 0)
    if dt < 21600 then
        return math.max(0, 500 - (tonumber(serverState.FreeXP.Count) or 0))
    end
    return 500
end

local function formatReward(r)
    if type(r) ~= "table" or not r.ItemId then
        return "Unknown"
    end
    local def = CrateConfig.ById and CrateConfig.ById[r.ItemId]
    local name = (def and ((CrateConfig.FullName and CrateConfig.FullName(def)) or def.Name)) or tostring(r.ItemId)
    local extra = {}
    if r.Paint then
        table.insert(extra, r.Paint)
    end
    if r.Certification then
        table.insert(extra, r.Certification)
    end
    if #extra > 0 then
        return name .. " [" .. table.concat(extra, ", ") .. "]"
    end
    return name
end

local function isOpeningUiBusy()
    local pg = plr:FindFirstChild("PlayerGui")
    local ui = pg and pg:FindFirstChild("NeonVaultUI")
    local canvas = ui and ui:FindFirstChild("Canvas", true)
    if not canvas then
        return false
    end
    local op = canvas:FindFirstChild("Opening")
    local rw = canvas:FindFirstChild("ItemRewards")
    return (op and op.Visible) or (rw and rw.Visible) or false
end

local function clickButton(btn)
    task.wait(0.15)
    if not btn or not btn.Parent then
        return
    end
    local inset = GuiService:GetGuiInset()
    local pos = btn.AbsolutePosition
    local size = btn.AbsoluteSize
    local x = pos.X + (size.X / 2)
    local y = pos.Y + (size.Y / 2) + inset.Y
    VirtualInputManager:SendMouseButtonEvent(x, y, 0, true, game, 1)
    task.wait(0.05)
    VirtualInputManager:SendMouseButtonEvent(x, y, 0, false, game, 1)
end

local function checkAfkPopup(child)
    if not antiAfk or not child or child.Name ~= "AFKCheck" then
        return
    end
    task.spawn(function()
        local card = child:WaitForChild("Card", 2)
        local btn = card and card:WaitForChild("StillHere", 2)
        if btn then
            clickButton(btn)
        end
    end)
end

local function claimTasks()
    if not serverState or type(serverState.DailyTasks) ~= "table" then
        return
    end
    for kind, list in pairs(serverState.DailyTasks) do
        if type(list) == "table" then
            for i, t in ipairs(list) do
                if type(t) == "table" and not t.Claimed and (tonumber(t.Progress) or 0) >= (tonumber(t.Goal) or 1) then
                    local ok, res = pcall(function()
                        return req:InvokeServer("ClaimDaily", { Kind = kind, Index = i })
                    end)
                    if ok and type(res) == "table" and res.Ok and res.State then
                        syncClientState(res.State, "ClaimDaily")
                    end
                end
            end
        end
    end
end

local function openCrate(series, count)
    if not awardToken then
        fetchState()
    end
    if not awardToken then
        return false, "No token"
    end

    local n = math.clamp(tonumber(count) or openAmount or 1, 1, 3)
    local ok, res = pcall(function()
        return req:InvokeServer("Open", {
            Series = series or selectedSeries,
            Token = awardToken,
            Count = (n > 1) and n or nil,
        })
    end)

    if not ok or type(res) ~= "table" then
        return false, "Request failed"
    end

    if not res.Ok then
        if res.AFKCheck then
            pcall(function()
                local c = req:InvokeServer("AFKConfirm", { Code = res.AFKCheck })
                if type(c) == "table" and c.State then
                    syncClientState(c.State, "AFKConfirm")
                end
            end)
            return false, "AFK check cleared"
        end
        local err = tostring(res.Error or "Error")
        local l = err:lower()
        if l:find("token") or l:find("already used") or l:find("refresh") then
            fetchState()
        elseif n > 1 and (l:find("pass") or l:find("multi") or l:find("3 at once") or l:find("enough") or l:find("key") or l:find("crates left")) then
            return openCrate(series, 1)
        end
        return false, err
    end

    if res.State then
        syncClientState(res.State, "Open")
    end

    local rewards = res.Rewards or (res.Reward and { res.Reward }) or {}
    return true, rewards
end

local crateNames = {}
local nameToSeries = {}
local defaultCrateIdx = 1
for _, id in ipairs(CrateConfig.SeriesOrder or { "noncrate" }) do
    local s = CrateConfig.Series and CrateConfig.Series[id]
    if s then
        local label = s.Name
        if table.find(crateNames, label) then
            label = label .. " (" .. id .. ")"
        end
        table.insert(crateNames, label)
        nameToSeries[label] = id
        if id == selectedSeries then
            defaultCrateIdx = #crateNames
        end
    end
end

local Window = Fluent:CreateWindow({
    Title = "Cone Hub",
    SubTitle = "RL Crate Simulator",
    TabWidth = 140,
    Size = UDim2.fromOffset(520, 390),
    Acrylic = false,
    Theme = "Dark",
    MinimizeKey = Enum.KeyCode.LeftControl,
})

local Tabs = {
    Main = Window:AddTab({ Title = "Crates", Icon = "box" }),
    Auto = Window:AddTab({ Title = "Automation", Icon = "repeat" }),
    Settings = Window:AddTab({ Title = "Settings", Icon = "settings" }),
}

local Options = Fluent.Options

local InfoBox = Tabs.Main:AddParagraph({
    Title = "Stats",
    Content = "Status: " .. statusText,
})

local CrateDropdown = Tabs.Main:AddDropdown("CrateSelect", {
    Title = "Crate",
    Values = crateNames,
    Multi = false,
    Default = defaultCrateIdx,
})

CrateDropdown:OnChanged(function(val)
    if nameToSeries[val] then
        selectedSeries = nameToSeries[val]
        saveCurrentSettings()
    end
end)

local AmountDropdown = Tabs.Main:AddDropdown("OpenAmount", {
    Title = "Open Amount",
    Values = { "1", "2", "3" },
    Multi = false,
    Default = openAmount,
})

AmountDropdown:OnChanged(function(val)
    local n = tonumber(val)
    if n then
        openAmount = math.clamp(n, 1, 3)
        saveCurrentSettings()
    end
end)

local OpenToggle = Tabs.Main:AddToggle("AutoOpen", {
    Title = "Auto Open",
    Default = autoOpen,
})

OpenToggle:OnChanged(function()
    autoOpen = Options.AutoOpen.Value
    if not autoOpen then
        statusText = "Idle"
        pcall(function()
            rev:FireServer()
        end)
    end
    saveCurrentSettings()
end)

local TasksToggle = Tabs.Auto:AddToggle("AutoTasks", {
    Title = "Auto Claim All Tasks",
    Default = autoTasks,
})

TasksToggle:OnChanged(function()
    autoTasks = Options.AutoTasks.Value
    if autoTasks then
        task.spawn(claimTasks)
    end
    saveCurrentSettings()
end)

local AfkToggle = Tabs.Auto:AddToggle("AntiAfk", {
    Title = "Anti AFK",
    Default = antiAfk,
})

AfkToggle:OnChanged(function()
    antiAfk = Options.AntiAfk.Value
    saveCurrentSettings()
end)

SaveManager:SetLibrary(Fluent)
InterfaceManager:SetLibrary(Fluent)
SaveManager:IgnoreThemeSettings()
SaveManager:SetIgnoreIndexes({})
InterfaceManager:SetFolder("ConeHub")
SaveManager:SetFolder("ConeHub/RLCrateSim")
InterfaceManager:BuildInterfaceSection(Tabs.Settings)
SaveManager:BuildConfigSection(Tabs.Settings)

Window:SelectTab(1)
pcall(function()
    SaveManager:LoadAutoloadConfig()
end)
ready = true
saveCurrentSettings()

local function updateInfo()
    local inv = (serverState and serverState.Items and #serverState.Items) or 0
    local xp = getFreeXpLeft()
    local last = (#recentPulls > 0) and table.concat(recentPulls, "\n") or "None"
    pcall(function()
        InfoBox:SetDesc(string.format(
            "Status: %s\nOpened: %d  |  XP Left: %d/500  |  Items: %d\n\nRecent:\n%s",
            statusText,
            openedCount,
            xp,
            inv,
            last
        ))
    end)
end

fetchState()
updateInfo()

table.insert(conns, plr.Idled:Connect(function()
    if antiAfk then
        VirtualUser:CaptureController()
        VirtualUser:ClickButton2(Vector2.new())
    end
end))

task.spawn(function()
    local pg = plr:WaitForChild("PlayerGui", 10)
    local ui = pg and pg:WaitForChild("NeonVaultUI", 10)
    local screen = ui and ui:WaitForChild("Screen", 10)
    local canvas = screen and screen:WaitForChild("Canvas", 10)
    if canvas then
        for _, c in ipairs(canvas:GetChildren()) do
            checkAfkPopup(c)
        end
        table.insert(conns, canvas.ChildAdded:Connect(checkAfkPopup))
    end
end)

local sessionRef = {
    openedCount = openedCount,
    recentPulls = recentPulls,
}
env.__RLCrateSession = sessionRef

task.spawn(function()
    local lastTaskCheck = 0
    while running do
        if autoTasks and (os.clock() - lastTaskCheck > 10) then
            lastTaskCheck = os.clock()
            task.spawn(claimTasks)
        end

        if not autoOpen then
            updateInfo()
            task.wait(0.3)
            continue
        end

        if isOpeningUiBusy() then
            statusText = "Waiting..."
            updateInfo()
            task.wait(0.4)
            continue
        end

        pcall(function()
            rev:FireServer()
        end)

        local t0 = os.clock()
        local ok, rewardsOrErr = openCrate(selectedSeries, openAmount)

        if ok and type(rewardsOrErr) == "table" and #rewardsOrErr > 0 then
            openedCount += #rewardsOrErr
            sessionRef.openedCount = openedCount
            for _, r in ipairs(rewardsOrErr) do
                table.insert(recentPulls, 1, formatReward(r))
            end
            while #recentPulls > 4 do
                table.remove(recentPulls)
            end

            local dur = 5.45 / math.max(0.1, getOpenSpeed())
            while running and autoOpen do
                local dt = os.clock() - t0
                if dt >= dur then
                    break
                end
                statusText = string.format("Opening x%d (%.1fs)", #rewardsOrErr, math.max(0, dur - dt))
                updateInfo()
                task.wait(0.15)
            end

            pcall(function()
                rev:FireServer()
            end)
        else
            local msg = tostring(rewardsOrErr or "Retrying")
            if msg:lower():find("still opening") then
                statusText = "Waiting for spin..."
                pcall(function()
                    rev:FireServer()
                end)
                updateInfo()
                task.wait(0.25)
            else
                statusText = msg
                updateInfo()
                task.wait(0.6)
            end
        end
    end
end)

env.__RLCrateFluentCleanup = function()
    running = false
    autoOpen = false
    pcall(function()
        rev:FireServer()
    end)
    for _, c in ipairs(conns) do
        pcall(function()
            c:Disconnect()
        end)
    end
    table.clear(conns)
    pcall(function()
        Window:Destroy()
    end)
end
