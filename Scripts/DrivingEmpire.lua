local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local VirtualUser = game:GetService("VirtualUser")

local plr = Players.LocalPlayer
local delivery = require(ReplicatedStorage.Modules.Client.Jobs.Tasks.DeliveryJobTask)
local deliveryUtil = require(ReplicatedStorage.Modules.Shared.Jobs.Delivery.DeliveryUtil)
local vehicles = require(ReplicatedStorage.Modules.Client.Vehicles.VehicleController)
local vehicleUtil = require(ReplicatedStorage.Modules.Shared.Vehicles.VehicleUtil)
local tpGuard = require(ReplicatedStorage.Modules.Client.Exploit.VehicleTeleportDetectionController)

local env = (getgenv and getgenv()) or shared
if env.__DrivingEmpireCleanup then
    pcall(env.__DrivingEmpireCleanup)
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

local settingsPath = "ConeHub/DrivingEmpire_State.json"

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
local autoDelivery = (saved.autoDelivery == true)
local deliveryMode = (saved.deliveryMode == "Safe" or saved.deliveryMode == "HighRisk") and saved.deliveryMode or "HighRisk"
local dropDelay = math.clamp(tonumber(saved.dropDelay) or 4.5, 1, 10)
local antiAfk = (saved.antiAfk ~= false)

local hover = nil
local curTarget, curLoc, curPhase, lastTick, lastFire, dropAt = nil, nil, nil, nil, nil, nil
local statusText = autoDelivery and "Starting..." or "Idle"
local deliveriesDone = 0
local sessionStart = os.clock()
local startCash = (plr:FindFirstChild("leaderstats") and plr.leaderstats:FindFirstChild("Cash") and plr.leaderstats.Cash.Value) or 0
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
                autoDelivery = autoDelivery,
                deliveryMode = deliveryMode,
                dropDelay = dropDelay,
                antiAfk = antiAfk,
            }))
        end)
    end
end

if getconnections then
    pcall(function()
        for _, v in ipairs(getconnections(plr.Idled)) do
            v:Disable()
        end
    end)
end

local function clearHover()
    if hover then
        pcall(function()
            hover:Destroy()
        end)
        hover = nil
    end
end

local function getLoc(pos, skipLast)
    local loc, dist

    for _, v in ipairs(CollectionService:GetTagged("DeliveryLocation")) do
        if v:IsA("BasePart") and v.Parent then
            if not skipLast or not deliveryUtil.IsLastDeliveryLocation(plr, v) then
                local d = (v.Position - pos).Magnitude
                if not dist or d < dist then
                    loc, dist = v, d
                end
            end
        end
    end

    return loc
end

local function tp(cf)
    local char = plr.Character
    if not char then
        return
    end

    local car = vehicleUtil.getPlayerData(plr)
    local chassis = vehicles.getActiveChassisController()

    if car and car.Model and car.WeightPart then
        if chassis then
            chassis.Teleporting = true
        end

        tpGuard.AuthorizeNextTeleport()
        car.Model.PrimaryPart = car.WeightPart
        car.Model:SetPrimaryPartCFrame(cf)
        car.WeightPart.Anchored = false
        clearHover()

        hover = Instance.new("BodyVelocity")
        hover.MaxForce = Vector3.new(1e9, 1e9, 1e9)
        hover.Velocity = Vector3.zero
        hover.Parent = car.WeightPart

        for _, v in ipairs(car.Model:GetDescendants()) do
            if v:IsA("BasePart") then
                v.AssemblyLinearVelocity = Vector3.zero
                v.AssemblyAngularVelocity = Vector3.zero
            end
        end

        task.defer(function()
            if chassis then
                chassis.Teleporting = false
            end
        end)
    else
        char:PivotTo(cf)

        local hrp = char:FindFirstChild("HumanoidRootPart")
        if hrp then
            clearHover()

            hover = Instance.new("BodyVelocity")
            hover.MaxForce = Vector3.new(1e9, 1e9, 1e9)
            hover.Velocity = Vector3.zero
            hover.Parent = hrp

            hrp.AssemblyLinearVelocity = Vector3.zero
            hrp.AssemblyAngularVelocity = Vector3.zero
        end
    end
end

local function formatNumber(n)
    local s = tostring(math.floor(tonumber(n) or 0))
    return s:reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", "")
end

local function formatDuration(sec)
    local s = math.max(0, math.floor(sec))
    local h = math.floor(s / 3600)
    local m = math.floor((s % 3600) / 60)
    local r = s % 60
    if h > 0 then
        return string.format("%02d:%02d:%02d", h, m, r)
    end
    return string.format("%02d:%02d", m, r)
end

local Window = Fluent:CreateWindow({
    Title = "Cone Hub",
    SubTitle = "Driving Empire",
    TabWidth = 140,
    Size = UDim2.fromOffset(520, 390),
    Acrylic = false,
    Theme = "Dark",
    MinimizeKey = Enum.KeyCode.LeftControl,
})

local Tabs = {
    Home = Window:AddTab({ Title = "Home", Icon = "home" }),
    Jobs = Window:AddTab({ Title = "Jobs", Icon = "truck" }),
    Settings = Window:AddTab({ Title = "Settings", Icon = "settings" }),
}

local Options = Fluent.Options

local HomeProfileBox = Tabs.Home:AddParagraph({
    Title = "Player Overview",
    Content = string.format("Player: %s (@%s)", plr.DisplayName, plr.Name),
})

local HomeSessionBox = Tabs.Home:AddParagraph({
    Title = "Live Session Stats",
    Content = "Loading session stats...",
})

local AfkToggle = Tabs.Home:AddToggle("AntiAfk", {
    Title = "Anti AFK",
    Description = "Prevents idle disconnect while farming",
    Default = antiAfk,
})

Tabs.Home:AddButton({
    Title = "Reset Session Cash & Timer",
    Description = "Resets session cash earned, hourly rate, and elapsed timer",
    Callback = function()
        sessionStart = os.clock()
        deliveriesDone = 0
        startCash = (plr:FindFirstChild("leaderstats") and plr.leaderstats:FindFirstChild("Cash") and plr.leaderstats.Cash.Value) or 0
    end,
})

local InfoBox = Tabs.Jobs:AddParagraph({
    Title = "Delivery Status",
    Content = "Status: " .. statusText,
})

local AutoDeliveryToggle = Tabs.Jobs:AddToggle("AutoDelivery", {
    Title = "Auto Delivery Job",
    Default = autoDelivery,
})

local ModeDropdown = Tabs.Jobs:AddDropdown("DeliveryMode", {
    Title = "Delivery Mode",
    Description = "HighRisk (Hard) pays 33% more cash; Safe (Easy) prevents Outlaw steals",
    Values = { "HighRisk", "Safe" },
    Multi = false,
    Default = deliveryMode == "Safe" and 2 or 1,
})

local DelaySlider = Tabs.Jobs:AddSlider("DropDelay", {
    Title = "Drop Delay (s)",
    Description = "Wait time before teleporting to dropoff",
    Default = dropDelay,
    Min = 1,
    Max = 10,
    Rounding = 1,
})

AutoDeliveryToggle:OnChanged(function()
    autoDelivery = Options.AutoDelivery.Value
    env.DEAutoDelivery = autoDelivery
    curTarget, curLoc, curPhase, lastTick, lastFire, dropAt = nil, nil, nil, nil, nil, nil
    if not autoDelivery then
        statusText = "Idle"
        clearHover()
    else
        statusText = "Starting..."
    end
    saveCurrentSettings()
end)

ModeDropdown:OnChanged(function(val)
    if val == "Safe" or val == "HighRisk" then
        deliveryMode = val
        if plr:GetAttribute("JobId") == "Delivery" and ReplicatedStorage:FindFirstChild("Remotes") and ReplicatedStorage.Remotes:FindFirstChild("SetDeliveryMode") then
            pcall(function()
                ReplicatedStorage.Remotes.SetDeliveryMode:FireServer(deliveryMode)
            end)
        end
        saveCurrentSettings()
    end
end)

DelaySlider:OnChanged(function(val)
    dropDelay = tonumber(val) or 4.5
    saveCurrentSettings()
end)

AfkToggle:OnChanged(function()
    antiAfk = Options.AntiAfk.Value
    saveCurrentSettings()
end)

SaveManager:SetLibrary(Fluent)
InterfaceManager:SetLibrary(Fluent)
SaveManager:IgnoreThemeSettings()
SaveManager:SetIgnoreIndexes({})
InterfaceManager:SetFolder("ConeHub")
SaveManager:SetFolder("ConeHub/DrivingEmpire")
InterfaceManager:BuildInterfaceSection(Tabs.Settings)
SaveManager:BuildConfigSection(Tabs.Settings)

Window:SelectTab(1)
pcall(function()
    SaveManager:LoadAutoloadConfig()
end)
ready = true
saveCurrentSettings()

local function updateInfo()
    local ls = plr:FindFirstChild("leaderstats")
    local curCash = (ls and ls:FindFirstChild("Cash") and ls.Cash.Value) or startCash
    local curMiles = (ls and ls:FindFirstChild("Miles") and ls.Miles.Value) or 0
    local curBounty = (ls and ls:FindFirstChild("Bounty") and ls.Bounty.Value) or 0
    local earned = math.max(0, curCash - startCash)
    local elapsed = math.max(1, os.clock() - sessionStart)
    local perHour = math.floor((earned / elapsed) * 3600)
    local jobAttr = tostring(plr:GetAttribute("JobId") or "None")
    local st = delivery.GetCurrentDeliveryState()
    local carried = (st and st.ItemsCarried) or 0
    local cap = (st and st.MaxCapacity) or 0
    local car = vehicleUtil.getPlayerData(plr)
    local carName = (car and car.Model and car.Model.Name) or "On Foot"

    pcall(function()
        HomeProfileBox:SetDesc(string.format(
            "Player: %s (@%s)  |  Vehicle: %s\nCash: $%s  |  Miles: %s  |  Bounty: $%s",
            plr.DisplayName,
            plr.Name,
            carName,
            formatNumber(curCash),
            formatNumber(curMiles),
            formatNumber(curBounty)
        ))
        HomeSessionBox:SetDesc(string.format(
            "Status: %s  |  Job: %s (%s)\nSession Earned: +$%s ($%s/hr)\nDeliveries: %d  |  Uptime: %s",
            statusText,
            jobAttr,
            deliveryMode,
            formatNumber(earned),
            formatNumber(perHour),
            deliveriesDone,
            formatDuration(elapsed)
        ))
        InfoBox:SetDesc(string.format(
            "Status: %s  |  Job: %s (%s)\nPackages: %d/%d  |  Completed: %d\nCash: $%s (+$%s)",
            statusText,
            jobAttr,
            deliveryMode,
            carried,
            cap,
            deliveriesDone,
            formatNumber(curCash),
            formatNumber(earned)
        ))
    end)
end

updateInfo()

table.insert(conns, plr.Idled:Connect(function()
    if antiAfk then
        VirtualUser:CaptureController()
        VirtualUser:ClickButton2(Vector2.new())
    end
end))

if ReplicatedStorage:FindFirstChild("Remotes") and ReplicatedStorage.Remotes:FindFirstChild("DeliveryCompleted") then
    table.insert(conns, ReplicatedStorage.Remotes.DeliveryCompleted.OnClientEvent:Connect(function()
        deliveriesDone += 1
        updateInfo()
    end))
end

table.insert(conns, RunService.Heartbeat:Connect(function()
    if not autoDelivery then
        return
    end
    local char = plr.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    local hum = char and char:FindFirstChildOfClass("Humanoid")

    if hrp then
        hrp.Anchored = false
    end
    if hum and hover and hover.Parent == hrp then
        hum:ChangeState(Enum.HumanoidStateType.Freefall)
    end
end))

task.spawn(function()
    while running do
        if not autoDelivery then
            updateInfo()
            task.wait(0.25)
            continue
        end

        local char = plr.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")

        if hrp then
            if plr:GetAttribute("JobId") ~= "Delivery" then
                statusText = "Starting Delivery Session..."
                updateInfo()
                ReplicatedStorage.Remotes.RequestStartJobSession:FireServer("Delivery", "deliveryHub", deliveryMode)
                curTarget, curLoc, curPhase, lastTick, dropAt = nil, nil, nil, nil, nil
                task.wait(0.5)
            else
                local state = delivery.GetCurrentDeliveryState()
                local target, phase

                if state then
                    lastTick = nil

                    local carried = state.ItemsCarried or 0
                    local cap = state.MaxCapacity or carried
                    local full = carried >= cap
                    local noMore = state.PackagesRemainingAtPickup == 0

                    if carried > 0 and (full or noMore) then
                        phase = "drop"
                        dropAt = dropAt or (tick() + dropDelay)

                        if tick() >= dropAt then
                            target = state.DestinationPosition
                            statusText = string.format("Delivering (%d/%d)", carried, cap)
                        else
                            target = state.PickupPosition
                            statusText = string.format("Waiting %.1fs (%d/%d)", math.max(0, dropAt - tick()), carried, cap)
                        end
                    else
                        dropAt = nil
                        phase = "pickup"
                        target = state.PickupPosition
                        statusText = string.format("Collecting (%d/%d)", carried, cap)
                    end
                else
                    lastTick = lastTick or tick()
                    statusText = "Finding Pickup Location..."

                    if tick() - lastTick > 0.25 then
                        local loc = getLoc(hrp.Position, true) or getLoc(hrp.Position)
                        phase = "new"
                        target = loc and loc.Position
                    end
                end

                if target then
                    if target ~= curTarget or phase ~= curPhase then
                        tp(CFrame.new(target + Vector3.new(0, 3.5, 0)))
                        curTarget, curPhase = target, phase
                    end

                    local loc = getLoc(target)

                    if loc then
                        if loc ~= curLoc then
                            ReplicatedStorage.Remotes.DeliveryLocationInteracted:FireServer(loc)
                            curLoc, lastFire = loc, tick()
                        elseif not lastFire or tick() - lastFire > 1 then
                            ReplicatedStorage.Remotes.DeliveryLocationInteracted:FireServer(loc)
                            lastFire = tick()
                        end
                    end
                end

                updateInfo()
            end
        end

        task.wait(0.1)
    end
end)

env.__DrivingEmpireCleanup = function()
    running = false
    autoDelivery = false
    env.DEAutoDelivery = false
    clearHover()
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
