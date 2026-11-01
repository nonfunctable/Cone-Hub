local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local VirtualUser = game:GetService("VirtualUser")

local setIdentity = setthreadidentity or setidentity or setthreadcontext
local function restoreIdentity()
    if setIdentity then
        pcall(setIdentity, 8)
    end
end
restoreIdentity()

local env = (getgenv and getgenv()) or shared
if env.__DrivingEmpireCleanup then
    pcall(env.__DrivingEmpireCleanup)
    restoreIdentity()
end
pcall(function()
    if gethui then
        for _, g in ipairs(gethui():GetChildren()) do
            if g.Name == "ConeHub_Fluent" then
                g:Destroy()
            end
        end
    end
end)

local plr = Players.LocalPlayer
local delivery = require(ReplicatedStorage.Modules.Client.Jobs.Tasks.DeliveryJobTask)
local deliveryUtil = require(ReplicatedStorage.Modules.Shared.Jobs.Delivery.DeliveryUtil)
local vehicles = require(ReplicatedStorage.Modules.Client.Vehicles.VehicleController)
local vehicleUtil = require(ReplicatedStorage.Modules.Shared.Vehicles.VehicleUtil)
local carTrailerUtil = require(ReplicatedStorage.Modules.Shared.Vehicles.CarTrailerUtil)
local towablesUtil = require(ReplicatedStorage.Modules.Shared.Towables.TowablesUtil)
local towablesData = require(ReplicatedStorage.Modules.Shared.DataManager.Data.TowablesData)
local sharedData = require(ReplicatedStorage.Modules.Shared.Data)
local tpGuard = require(ReplicatedStorage.Modules.Client.Exploit.VehicleTeleportDetectionController)
restoreIdentity()

local function getPlayerCar()
    local ok, car = pcall(vehicleUtil.getPlayerData, plr)
    restoreIdentity()
    return ok and car or nil
end

local function getAttachedTrailer()
    local ok, tr, towId = pcall(towablesUtil.GetPlayerAttachedTrailer, plr)
    restoreIdentity()
    if ok then
        return tr, towId
    end
    return nil, nil
end

local function isPlayerTowing()
    local ok, res = pcall(deliveryUtil.IsPlayerTowing, plr)
    restoreIdentity()
    return ok and res == true
end

local function findBestTowSetup()
    local bestVeh, bestTow, bestCap = nil, nil, 0
    pcall(function()
        local stats = sharedData.GetLoadedStatsFolder(plr)
        local vehFolder = stats and stats:FindFirstChild("Vehicles")
        local towCfg = towablesUtil.GetEnabledTowables()
        if not vehFolder or not towCfg then
            return
        end
        for _, v in ipairs(vehFolder:GetChildren()) do
            local vehId = v.Name
            if towablesUtil.CanTowTrailer(vehId) then
                for towId, info in pairs(towCfg) do
                    local cap = tonumber(info.CargoCapacity) or 0
                    if cap > 0 then
                        local owned = (not towablesUtil.IsTowablePurchasable(towId)) or towablesData.IsTowableUnlocked(plr, towId)
                        if owned and towablesUtil.CanVehicleTowTowable(vehId, towId, plr) then
                            if cap > bestCap or (cap == bestCap and towId == "LargeBox") then
                                bestVeh, bestTow, bestCap = vehId, towId, cap
                            end
                        end
                    end
                end
            end
        end
    end)
    restoreIdentity()
    return bestVeh, bestTow, bestCap
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

local State = {
    running = true,
    ready = false,
    autoDelivery = (saved.autoDelivery == true),
    autoTrailer = (saved.autoTrailer ~= false),
    deliveryMode = (saved.deliveryMode == "Safe" or saved.deliveryMode == "HighRisk") and saved.deliveryMode or "HighRisk",
    dropDelay = math.clamp(tonumber(saved.dropDelay) or 4.5, 1, 10),
    antiAfk = (saved.antiAfk ~= false),
    spawningTow = false,
    lastTowAttempt = 0,
    hover = nil,
    trailerHover = nil,
    curTarget = nil,
    curLoc = nil,
    curPhase = nil,
    lastTick = nil,
    lastFire = nil,
    dropAt = nil,
    statusText = (saved.autoDelivery == true) and "Starting..." or "Idle",
    deliveriesDone = 0,
    sessionStart = os.clock(),
    startCash = (plr:FindFirstChild("leaderstats") and plr.leaderstats:FindFirstChild("Cash") and plr.leaderstats.Cash.Value) or 0,
    conns = {},
}

local function saveCurrentSettings()
    if not State.ready then
        return
    end
    if writefile and makefolder and isfolder then
        pcall(function()
            if not isfolder("ConeHub") then
                makefolder("ConeHub")
            end
            writefile(settingsPath, HttpService:JSONEncode({
                autoDelivery = State.autoDelivery,
                autoTrailer = State.autoTrailer,
                deliveryMode = State.deliveryMode,
                dropDelay = State.dropDelay,
                antiAfk = State.antiAfk,
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
    if State.hover then
        pcall(function()
            State.hover:Destroy()
        end)
        State.hover = nil
    end
    if State.trailerHover then
        pcall(function()
            State.trailerHover:Destroy()
        end)
        State.trailerHover = nil
    end
end

local function getLoc(pos, skipLast, ignoreTrailerFilter)
    local isTowing = not ignoreTrailerFilter and isPlayerTowing() or false
    local loc, dist

    for _, v in ipairs(CollectionService:GetTagged("DeliveryLocation")) do
        if v:IsA("BasePart") and v.Parent then
            local allowed = true
            if not ignoreTrailerFilter then
                local okA, resA = pcall(deliveryUtil.IsLocationAllowedForTrailer, v, isTowing)
                allowed = not okA or resA
            end
            local isLast = false
            if skipLast then
                local okL, resL = pcall(deliveryUtil.IsLastDeliveryLocation, plr, v)
                isLast = okL and resL
            end
            if allowed and not isLast then
                local d = (v.Position - pos).Magnitude
                if not dist or d < dist then
                    loc, dist = v, d
                end
            end
        end
    end
    restoreIdentity()
    return loc
end

local function tp(cf)
    restoreIdentity()
    local char = plr.Character
    if not char then
        return
    end

    local car = getPlayerCar()
    local chassis = vehicles.getActiveChassisController()
    local tr = getAttachedTrailer()
    restoreIdentity()

    if car and car.Model and car.WeightPart then
        if chassis then
            chassis.Teleporting = true
        end

        tpGuard.AuthorizeNextTeleport()

        local vehHitch, trHitch, trAtt, vehAtt
        pcall(function()
            vehHitch = carTrailerUtil.GetHitchPart(car.Model, false)
            trHitch = vehHitch and carTrailerUtil.GetAttachedTrailerHitch(vehHitch)
            if trHitch and vehHitch then
                trAtt, vehAtt = carTrailerUtil.GetMatchingHitchAttachments(trHitch, vehHitch)
            end
        end)
        restoreIdentity()

        local tWeight = tr and tr:FindFirstChild("Weight")
        local weightToAtt = (tWeight and trAtt) and tWeight.CFrame:ToObjectSpace(trAtt.WorldCFrame) or nil

        car.Model.PrimaryPart = car.WeightPart
        car.Model:SetPrimaryPartCFrame(cf)
        car.WeightPart.Anchored = false
        clearHover()

        local h = Instance.new("BodyVelocity")
        h.MaxForce = Vector3.new(1e9, 1e9, 1e9)
        h.Velocity = Vector3.zero
        h.Parent = car.WeightPart
        State.hover = h

        for _, v in ipairs(car.Model:GetDescendants()) do
            if v:IsA("BasePart") then
                v.AssemblyLinearVelocity = Vector3.zero
                v.AssemblyAngularVelocity = Vector3.zero
            end
        end

        if tr and tr.Parent and tWeight and tWeight:IsA("BasePart") then
            if weightToAtt and vehAtt then
                local targetAttCF = CFrame.new(vehAtt.WorldPosition) * cf.Rotation
                tr.PrimaryPart = tWeight
                tr:SetPrimaryPartCFrame(targetAttCF * weightToAtt:Inverse())
            end
            tWeight.Anchored = false

            local th = Instance.new("BodyVelocity")
            th.MaxForce = Vector3.new(1e9, 1e9, 1e9)
            th.Velocity = Vector3.zero
            th.Parent = tWeight
            State.trailerHover = th

            for _, v in ipairs(tr:GetDescendants()) do
                if v:IsA("BasePart") then
                    v.AssemblyLinearVelocity = Vector3.zero
                    v.AssemblyAngularVelocity = Vector3.zero
                end
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

            local h = Instance.new("BodyVelocity")
            h.MaxForce = Vector3.new(1e9, 1e9, 1e9)
            h.Velocity = Vector3.zero
            h.Parent = hrp
            State.hover = h

            hrp.AssemblyLinearVelocity = Vector3.zero
            hrp.AssemblyAngularVelocity = Vector3.zero
        end
    end
end

local function formatNumber(n)
    local s = tostring(math.floor(tonumber(n) or 0))
    return (s:reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", ""))
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
    Size = UDim2.fromOffset(520, 420),
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
    Default = State.antiAfk,
})

Tabs.Home:AddButton({
    Title = "Reset Session Cash & Timer",
    Description = "Resets session cash earned, hourly rate, and elapsed timer",
    Callback = function()
        State.sessionStart = os.clock()
        State.deliveriesDone = 0
        State.startCash = (plr:FindFirstChild("leaderstats") and plr.leaderstats:FindFirstChild("Cash") and plr.leaderstats.Cash.Value) or 0
    end,
})

local InfoBox = Tabs.Jobs:AddParagraph({
    Title = "Delivery Status",
    Content = "Status: " .. State.statusText,
})

local AutoDeliveryToggle = Tabs.Jobs:AddToggle("AutoDelivery", {
    Title = "Auto Delivery Job",
    Default = State.autoDelivery,
})

local AutoTrailerToggle = Tabs.Jobs:AddToggle("AutoTrailer", {
    Title = "Auto Trailer (+4 Max Cargo)",
    Description = "Spawns your best tow truck & free +4 semi trailer for up to +100% more cash per trip",
    Default = State.autoTrailer,
})

local ModeDropdown = Tabs.Jobs:AddDropdown("DeliveryMode", {
    Title = "Delivery Mode",
    Description = "HighRisk (Hard) pays 33% more cash; Safe (Easy) prevents Outlaw steals",
    Values = { "HighRisk", "Safe" },
    Multi = false,
    Default = State.deliveryMode == "Safe" and 2 or 1,
})

local DelaySlider = Tabs.Jobs:AddSlider("DropDelay", {
    Title = "Drop Delay (s)",
    Description = "Wait time before teleporting to dropoff",
    Default = State.dropDelay,
    Min = 1,
    Max = 10,
    Rounding = 1,
})

local function updateInfo()
    restoreIdentity()
    local ls = plr:FindFirstChild("leaderstats")
    local curCash = (ls and ls:FindFirstChild("Cash") and ls.Cash.Value) or State.startCash
    local curMiles = (ls and ls:FindFirstChild("Miles") and ls.Miles.Value) or 0
    local curBounty = (ls and ls:FindFirstChild("Bounty") and ls.Bounty.Value) or 0
    local earned = math.max(0, curCash - State.startCash)
    local elapsed = math.max(1, os.clock() - State.sessionStart)
    local perHour = math.floor((earned / elapsed) * 3600)
    local jobAttr = tostring(plr:GetAttribute("JobId") or "None")
    local okSt, st = pcall(delivery.GetCurrentDeliveryState)
    restoreIdentity()
    st = okSt and st or nil
    local carried = (st and st.ItemsCarried) or 0
    local cap = (st and st.MaxCapacity) or 0
    if cap == 0 then
        local okCap, maxC = pcall(deliveryUtil.GetMaxCarryCapacity, plr)
        restoreIdentity()
        cap = (okCap and maxC) or 0
    end
    local car = getPlayerCar()
    local _, towId = getAttachedTrailer()
    local carLabel = (car and car.VehicleId) or "On Foot"
    if towId then
        carLabel = carLabel .. " + " .. tostring(towId)
    end

    restoreIdentity()
    pcall(function()
        HomeProfileBox:SetDesc(string.format(
            "Player: %s (@%s)  |  Setup: %s\nCash: $%s  |  Miles: %s  |  Bounty: $%s",
            plr.DisplayName,
            plr.Name,
            carLabel,
            formatNumber(curCash),
            formatNumber(curMiles),
            formatNumber(curBounty)
        ))
        HomeSessionBox:SetDesc(string.format(
            "Status: %s  |  Job: %s (%s)\nSession Earned: +$%s ($%s/hr)\nDeliveries: %d  |  Uptime: %s",
            State.statusText,
            jobAttr,
            State.deliveryMode,
            formatNumber(earned),
            formatNumber(perHour),
            State.deliveriesDone,
            formatDuration(elapsed)
        ))
        InfoBox:SetDesc(string.format(
            "Status: %s  |  Job: %s (%s)\nPackages: %d/%d (%s)  |  Completed: %d\nCash: $%s (+$%s)",
            State.statusText,
            jobAttr,
            State.deliveryMode,
            carried,
            cap,
            towId or "No Trailer",
            State.deliveriesDone,
            formatNumber(curCash),
            formatNumber(earned)
        ))
    end)
end

local function ensureTowSetup()
    if not State.autoTrailer then
        return
    end
    local car = getPlayerCar()
    if car and isPlayerTowing() then
        return
    end
    if tick() - State.lastTowAttempt < 4 then
        return
    end
    local bestVeh, bestTow = findBestTowSetup()
    if not bestVeh or not bestTow then
        return
    end

    State.lastTowAttempt = tick()
    State.spawningTow = true
    State.statusText = string.format("Equipping %s + %s...", bestVeh, bestTow)
    updateInfo()

    clearHover()
    local char = plr.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if hrp then
        for _, c in ipairs(hrp:GetChildren()) do
            if c:IsA("BodyVelocity") then
                c:Destroy()
            end
        end
    end

    if not car or car.VehicleId ~= bestVeh then
        local look = (hrp and Vector3.new(hrp.CFrame.LookVector.X, 0, hrp.CFrame.LookVector.Z).Unit) or Vector3.new(0, 0, 1)
        pcall(function()
            ReplicatedStorage.Remotes.VehicleEvent:FireServer("Spawn", bestVeh, nil, nil, look)
        end)
        local t0 = tick()
        repeat
            task.wait(0.1)
            car = getPlayerCar()
        until not State.running or not State.autoDelivery or (car and car.VehicleId == bestVeh) or (tick() - t0 > 5)
        task.wait(0.25)
    end

    if State.running and State.autoDelivery and not isPlayerTowing() then
        pcall(function()
            ReplicatedStorage.Remotes.SpawnTowable:InvokeServer(bestTow)
        end)
        local t1 = tick()
        repeat
            task.wait(0.1)
        until not State.running or not State.autoDelivery or isPlayerTowing() or (tick() - t1 > 2.5)
    end

    State.spawningTow = false
    State.curTarget, State.curLoc, State.curPhase = nil, nil, nil
    restoreIdentity()
end

updateInfo()

AutoDeliveryToggle:OnChanged(function()
    State.autoDelivery = Options.AutoDelivery.Value
    env.DEAutoDelivery = State.autoDelivery
    State.curTarget, State.curLoc, State.curPhase, State.lastTick, State.lastFire, State.dropAt = nil, nil, nil, nil, nil, nil
    if not State.autoDelivery then
        State.statusText = "Idle"
        clearHover()
    else
        State.statusText = "Starting..."
    end
    updateInfo()
    saveCurrentSettings()
end)

AutoTrailerToggle:OnChanged(function()
    State.autoTrailer = Options.AutoTrailer.Value
    State.lastTowAttempt = 0
    State.curTarget, State.curLoc, State.curPhase = nil, nil, nil
    updateInfo()
    saveCurrentSettings()
end)

ModeDropdown:OnChanged(function(val)
    if val == "Safe" or val == "HighRisk" then
        State.deliveryMode = val
        if plr:GetAttribute("JobId") == "Delivery" and ReplicatedStorage:FindFirstChild("Remotes") and ReplicatedStorage.Remotes:FindFirstChild("SetDeliveryMode") then
            pcall(function()
                ReplicatedStorage.Remotes.SetDeliveryMode:FireServer(State.deliveryMode)
            end)
        end
        updateInfo()
        saveCurrentSettings()
    end
end)

DelaySlider:OnChanged(function(val)
    State.dropDelay = tonumber(val) or 4.5
    saveCurrentSettings()
end)

AfkToggle:OnChanged(function()
    State.antiAfk = Options.AntiAfk.Value
    saveCurrentSettings()
end)

pcall(function()
    SaveManager:SetLibrary(Fluent)
    InterfaceManager:SetLibrary(Fluent)
    SaveManager:IgnoreThemeSettings()
    SaveManager:SetIgnoreIndexes({})
    InterfaceManager:SetFolder("ConeHub")
    SaveManager:SetFolder("ConeHub/DrivingEmpire")
    InterfaceManager:BuildInterfaceSection(Tabs.Settings)
    SaveManager:BuildConfigSection(Tabs.Settings)
    SaveManager:LoadAutoloadConfig()
end)

Window:SelectTab(1)
State.ready = true
saveCurrentSettings()
updateInfo()

table.insert(State.conns, plr.Idled:Connect(function()
    if State.antiAfk then
        VirtualUser:CaptureController()
        VirtualUser:ClickButton2(Vector2.new())
    end
end))

if ReplicatedStorage:FindFirstChild("Remotes") and ReplicatedStorage.Remotes:FindFirstChild("DeliveryCompleted") then
    table.insert(State.conns, ReplicatedStorage.Remotes.DeliveryCompleted.OnClientEvent:Connect(function(data)
        if type(data) ~= "table" or not data.FailureReason then
            State.deliveriesDone += 1
        end
        updateInfo()
    end))
end

table.insert(State.conns, RunService.Heartbeat:Connect(function()
    if not State.autoDelivery or State.spawningTow then
        return
    end
    local char = plr.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    local hum = char and char:FindFirstChildOfClass("Humanoid")

    if hrp then
        hrp.Anchored = false
    end
    if hum and State.hover and State.hover.Parent == hrp then
        hum:ChangeState(Enum.HumanoidStateType.Freefall)
    end
end))

task.spawn(function()
    while State.running do
        if not State.autoDelivery then
            updateInfo()
            task.wait(0.25)
            continue
        end

        local char = plr.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")

        if hrp then
            if plr:GetAttribute("JobId") ~= "Delivery" then
                State.statusText = "Starting Delivery Session..."
                updateInfo()
                ReplicatedStorage.Remotes.RequestStartJobSession:FireServer("Delivery", "deliveryHub", State.deliveryMode)
                State.curTarget, State.curLoc, State.curPhase, State.lastTick, State.dropAt = nil, nil, nil, nil, nil
                task.wait(0.5)
            else
                local okSt, state = pcall(delivery.GetCurrentDeliveryState)
                restoreIdentity()
                state = okSt and state or nil

                if State.autoTrailer and (not state or (state.ItemsCarried or 0) == 0) then
                    ensureTowSetup()
                    okSt, state = pcall(delivery.GetCurrentDeliveryState)
                    restoreIdentity()
                    state = okSt and state or nil
                end

                local target, phase

                if state then
                    State.lastTick = nil

                    local carried = state.ItemsCarried or 0
                    local cap = state.MaxCapacity or carried
                    local full = carried >= cap
                    local noMore = state.PackagesRemainingAtPickup == 0

                    if carried > 0 and (full or noMore) then
                        phase = "drop"
                        State.dropAt = State.dropAt or (tick() + State.dropDelay)

                        if tick() >= State.dropAt then
                            target = state.DestinationPosition
                            State.statusText = string.format("Delivering (%d/%d)", carried, cap)
                        else
                            target = state.PickupPosition
                            State.statusText = string.format("Waiting %.1fs (%d/%d)", math.max(0, State.dropAt - tick()), carried, cap)
                        end
                    else
                        State.dropAt = nil
                        phase = "pickup"
                        target = state.PickupPosition
                        State.statusText = string.format("Collecting (%d/%d)", carried, cap)
                    end
                else
                    State.lastTick = State.lastTick or tick()
                    State.statusText = "Finding Pickup Location..."

                    if tick() - State.lastTick > 0.25 then
                        local loc = getLoc(hrp.Position, true, false) or getLoc(hrp.Position, false, false)
                        phase = "new"
                        target = loc and loc.Position
                    end
                end

                if target then
                    if target ~= State.curTarget or phase ~= State.curPhase then
                        local yOffset = getPlayerCar() and 5 or 3.5
                        tp(CFrame.new(target + Vector3.new(0, yOffset, 0)))
                        State.curTarget, State.curPhase = target, phase
                    end

                    local loc = getLoc(target, false, (state ~= nil))

                    if loc then
                        if loc ~= State.curLoc then
                            ReplicatedStorage.Remotes.DeliveryLocationInteracted:FireServer(loc)
                            State.curLoc, State.lastFire = loc, tick()
                        elseif not State.lastFire or tick() - State.lastFire > 1 then
                            ReplicatedStorage.Remotes.DeliveryLocationInteracted:FireServer(loc)
                            State.lastFire = tick()
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
    restoreIdentity()
    State.running = false
    State.autoDelivery = false
    env.DEAutoDelivery = false
    clearHover()
    for _, c in ipairs(State.conns) do
        pcall(function()
            c:Disconnect()
        end)
    end
    table.clear(State.conns)
    pcall(function()
        Window:Destroy()
    end)
    pcall(function()
        if Fluent and Fluent.Destroy then
            Fluent:Destroy()
        end
    end)
end
