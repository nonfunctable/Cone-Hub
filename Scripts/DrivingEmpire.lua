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
local criminalATMTask = require(ReplicatedStorage.Modules.Client.Jobs.Tasks.CriminalATMJobTask)
local criminalUtil = require(ReplicatedStorage.Modules.Shared.Jobs.Criminal.CriminalUtil)
local securityArrestTask = require(ReplicatedStorage.Modules.Client.Jobs.Tasks.SecurityArrestJobTask)
local securityUtil = require(ReplicatedStorage.Modules.Shared.Jobs.Security.SecurityUtil)
local collectibleSpawner = require(ReplicatedStorage.Modules.Client.CollectibleSpawner.CollectibleSpawnerController)
local questController = require(ReplicatedStorage.Modules.Client.Quests.QuestController)
local questUtil = require(ReplicatedStorage.Modules.Shared.Quests.QuestUtil)
local vehicles = require(ReplicatedStorage.Modules.Client.Vehicles.VehicleController)
local inputCtrl = require(ReplicatedStorage.Modules.Client.Vehicles.InputController)
local vehicleUtil = require(ReplicatedStorage.Modules.Shared.Vehicles.VehicleUtil)
local carTrailerUtil = require(ReplicatedStorage.Modules.Shared.Vehicles.CarTrailerUtil)
local towablesUtil = require(ReplicatedStorage.Modules.Shared.Towables.TowablesUtil)
local towablesData = require(ReplicatedStorage.Modules.Shared.DataManager.Data.TowablesData)
local sharedData = require(ReplicatedStorage.Modules.Shared.Data)
local tpGuard = require(ReplicatedStorage.Modules.Client.Exploit.VehicleTeleportDetectionController)
restoreIdentity()

local function getStudsDriven()
    local val = 0
    pcall(function()
        local stats = sharedData.GetLoadedStatsFolder(plr)
        local sd = stats and stats:FindFirstChild("Studs Driven")
        if sd and sd:IsA("ValueBase") then
            val = tonumber(sd.Value) or 0
        end
    end)
    restoreIdentity()
    return val
end

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

local PriorityHypercars = {
    ["Devel-SixteenDEEdition-2024"] = 100,
    ["Devel-Sixteen"] = 99,
    ["Koenigsegg-JeskoAbsolut"] = 98,
    ["Koenigsegg-Jesko"] = 97,
    ["Hennessey-VenomF5"] = 96,
    ["SSC-TuataraAggressor"] = 95,
    ["SSC-Tuatara"] = 94,
    ["Bugatti-Bolide"] = 93,
    ["Bugatti-ChironSuperSport300"] = 92,
    ["Pininfarina-BattistaNinoFarina"] = 90,
    ["Ford-GTDEEdition-2017"] = 88,
}

local function findFastestOwnedCar()
    local bestVeh, bestScore = nil, -1
    pcall(function()
        local stats = sharedData.GetLoadedStatsFolder(plr)
        local vehFolder = stats and stats:FindFirstChild("Vehicles")
        if not vehFolder then
            return
        end
        for _, v in ipairs(vehFolder:GetChildren()) do
            local vehId = v.Name
            local info = vehicleUtil.getVehicleDealerInfo(vehId)
            local isTruck = towablesUtil.CanTowTrailer(vehId)
            local prio = PriorityHypercars[vehId] or 0
            local price = (type(info) == "table" and tonumber(info.Price)) or 0
            local z60 = (type(info) == "table" and tonumber(info.ZeroToSixty)) or 5
            local score = (prio * 1e9) + price + math.max(0, (10 - z60) * 500000)
            if isTruck and prio == 0 then
                score = score * 0.1
            end
            if score > bestScore then
                bestVeh, bestScore = vehId, score
            end
        end
    end)
    restoreIdentity()
    return bestVeh
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
    updatingToggles = false,
    autoDelivery = (saved.autoDelivery == true),
    autoTrailer = (saved.autoTrailer ~= false),
    deliveryMode = (saved.deliveryMode == "Safe" or saved.deliveryMode == "HighRisk") and saved.deliveryMode or "HighRisk",
    dropDelay = math.clamp(tonumber(saved.dropDelay) or 4.5, 1, 10),
    antiOutlawArrest = (saved.antiOutlawArrest ~= false),
    autoCriminal = (saved.autoCriminal == true),
    criminalCashInStars = math.clamp(tonumber(saved.criminalCashInStars) or 5, 1, 5),
    autoSecurityScenes = (saved.autoSecurityScenes == true),
    autoArrestOutlaws = (saved.autoArrestOutlaws == true),
    autoCandy = (saved.autoCandy == true),
    autoMiles = (saved.autoMiles == true),
    milesSpeed = math.clamp(tonumber(saved.milesSpeed) or 380, 150, 450),
    autoClaimRewards = (saved.autoClaimRewards ~= false),
    antiAfk = (saved.antiAfk ~= false),
    infNitro = (saved.infNitro == true),
    uncapSpeed = (saved.uncapSpeed == true),
    torqueMult = math.clamp(tonumber(saved.torqueMult) or 1, 1, 5),
    gripMult = math.clamp(tonumber(saved.gripMult) or 1, 1, 3),
    spawningTow = false,
    spawningFastCar = false,
    lastTowAttempt = 0,
    lastFastCarAttempt = 0,
    lastRewardCheck = 0,
    patrolIdx = 1,
    lastPatrolTick = 0,
    candySkip = {},
    lastCandyPos = nil,
    sameCandyTicks = 0,
    candiesCollected = 0,
    atmsBusted = 0,
    scenesDone = 0,
    arrestsDone = 0,
    arrestTarget = nil,
    arrestStartedAt = 0,
    milesPlatform = nil,
    milesBV = nil,
    milesBG = nil,
    milesAngle = 0,
    milesPlatformY = 120,
    milesReturnCF = nil,
    hover = nil,
    hoverGyro = nil,
    trailerHover = nil,
    trailerGyro = nil,
    curTarget = nil,
    curLoc = nil,
    curPhase = nil,
    lastTick = nil,
    lastFire = nil,
    dropAt = nil,
    dropStuckSince = nil,
    statusText = "Idle",
    deliveriesDone = 0,
    sessionStart = os.clock(),
    startCash = (plr:FindFirstChild("leaderstats") and plr.leaderstats:FindFirstChild("Cash") and plr.leaderstats.Cash.Value) or 0,
    startMiles = (plr:FindFirstChild("leaderstats") and plr.leaderstats:FindFirstChild("Miles") and plr.leaderstats.Miles.Value) or 0,
    startStuds = getStudsDriven(),
    selectedLocation = "Job & Delivery Hub",
    selectedPlayer = "",
    conns = {},
}

local KeyLocations = {
    ["Job & Delivery Hub"] = Vector3.new(80, 17, -1882),
    ["Dealership"] = Vector3.new(-427, 16, -1775),
    ["Spookfest 2026 Hub"] = Vector3.new(40, 36, -160),
    ["Downtown ATMs"] = Vector3.new(-376, 16, -1825),
    ["Criminal Drop-Off (City)"] = Vector3.new(-2543, 14, 4030),
    ["Criminal Drop-Off (Mountain)"] = Vector3.new(7322, 200, -2811),
    ["Waterfront Marina"] = Vector3.new(-2190, 6, -4280),
}

local LocationNames = {
    "Job & Delivery Hub",
    "Dealership",
    "Spookfest 2026 Hub",
    "Downtown ATMs",
    "Criminal Drop-Off (City)",
    "Criminal Drop-Off (Mountain)",
    "Waterfront Marina",
}

local PatrolPoints = {
    Vector3.new(-376, 16, -1825),
    Vector3.new(-71, 15, -2030),
    Vector3.new(-1004, 28, -3955),
    Vector3.new(-148, 56, -4078),
    Vector3.new(964, 135, -4481),
    Vector3.new(-2190, 6, -4280),
    Vector3.new(-1844, 6, 5888),
    Vector3.new(-527, 6, 5973),
    Vector3.new(-2543, 14, 4030),
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
                antiOutlawArrest = State.antiOutlawArrest,
                autoCriminal = State.autoCriminal,
                criminalCashInStars = State.criminalCashInStars,
                autoSecurityScenes = State.autoSecurityScenes,
                autoArrestOutlaws = State.autoArrestOutlaws,
                autoCandy = State.autoCandy,
                autoMiles = State.autoMiles,
                milesSpeed = State.milesSpeed,
                autoClaimRewards = State.autoClaimRewards,
                antiAfk = State.antiAfk,
                infNitro = State.infNitro,
                uncapSpeed = State.uncapSpeed,
                torqueMult = State.torqueMult,
                gripMult = State.gripMult,
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
    if State.hoverGyro then
        pcall(function()
            State.hoverGyro:Destroy()
        end)
        State.hoverGyro = nil
    end
    if State.trailerHover then
        pcall(function()
            State.trailerHover:Destroy()
        end)
        State.trailerHover = nil
    end
    if State.trailerGyro then
        pcall(function()
            State.trailerGyro:Destroy()
        end)
        State.trailerGyro = nil
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

local function tp(cf, keepVelocityFree)
    restoreIdentity()
    local char = plr.Character
    if not char then
        return
    end

    local car = getPlayerCar()
    local chassis = vehicles.getActiveChassisController()
    local tr = getAttachedTrailer()
    if not tr then
        local okT, list = pcall(towablesUtil.GetPlayerTowables, plr)
        tr = (okT and type(list) == "table" and list[1]) or nil
    end
    restoreIdentity()

    if car and car.Model and car.WeightPart then
        if chassis then
            chassis.Teleporting = true
        end

        tpGuard.AuthorizeNextTeleport()

        local vehHitch, trHitch, trAtt, vehAtt
        pcall(function()
            vehHitch = carTrailerUtil.GetHitchPart(car.Model, false)
            trHitch = (vehHitch and carTrailerUtil.GetAttachedTrailerHitch(vehHitch)) or (tr and carTrailerUtil.GetHitchPart(tr, true))
            if trHitch and vehHitch then
                trAtt, vehAtt = carTrailerUtil.GetMatchingHitchAttachments(trHitch, vehHitch)
            end
        end)
        restoreIdentity()

        local tWeight = tr and tr:FindFirstChild("Weight")
        local vehAttLocalPos = (vehAtt and car.WeightPart.CFrame:PointToObjectSpace(vehAtt.WorldPosition)) or Vector3.new(0, 2.1, 9.1)
        local trAttLocalPos = (tWeight and trAtt and tWeight.CFrame:PointToObjectSpace(trAtt.WorldPosition)) or Vector3.new(0, -3.14, -29.27)

        local oldCarCF = car.WeightPart.CFrame
        local carRel = {}
        for _, v in ipairs(car.Model:GetDescendants()) do
            if v:IsA("BasePart") then
                carRel[v] = oldCarCF:ToObjectSpace(v.CFrame)
            end
        end

        local oldTrCF = tWeight and tWeight.CFrame
        local trRel = {}
        if tr and tr.Parent and oldTrCF then
            for _, v in ipairs(tr:GetDescendants()) do
                if v:IsA("BasePart") then
                    trRel[v] = oldTrCF:ToObjectSpace(v.CFrame)
                end
            end
        end

        clearHover()

        car.Model.PrimaryPart = car.WeightPart
        car.Model:PivotTo(cf)
        car.WeightPart.Anchored = false

        for v, rel in pairs(carRel) do
            if v and v.Parent then
                v.CFrame = cf:ToWorldSpace(rel)
                v.AssemblyLinearVelocity = Vector3.zero
                v.AssemblyAngularVelocity = Vector3.zero
            end
        end

        if not keepVelocityFree then
            local h = Instance.new("BodyVelocity")
            h.MaxForce = Vector3.new(1e9, 1e9, 1e9)
            h.Velocity = Vector3.zero
            h.Parent = car.WeightPart
            State.hover = h

            local bg = Instance.new("BodyGyro")
            bg.MaxTorque = Vector3.new(1e9, 1e9, 1e9)
            bg.P = 1e5
            bg.D = 1e3
            bg.CFrame = cf
            bg.Parent = car.WeightPart
            State.hoverGyro = bg
        end

        if tr and tr.Parent and tWeight and tWeight:IsA("BasePart") then
            local targetHitchPos = cf:PointToWorldSpace(vehAttLocalPos)
            local targetTrailerPos = targetHitchPos - (cf.Rotation * trAttLocalPos)
            local trailerCF = CFrame.new(targetTrailerPos) * cf.Rotation
            tr.PrimaryPart = tWeight
            tr:PivotTo(trailerCF)
            tWeight.Anchored = false

            for v, rel in pairs(trRel) do
                if v and v.Parent then
                    v.CFrame = trailerCF:ToWorldSpace(rel)
                    v.AssemblyLinearVelocity = Vector3.zero
                    v.AssemblyAngularVelocity = Vector3.zero
                end
            end

            if not keepVelocityFree then
                local th = Instance.new("BodyVelocity")
                th.MaxForce = Vector3.new(1e5, 1e9, 1e5)
                th.Velocity = Vector3.zero
                th.Parent = tWeight
                State.trailerHover = th

                local tbg = Instance.new("BodyGyro")
                tbg.MaxTorque = Vector3.new(1e9, 1e9, 1e9)
                tbg.P = 1e5
                tbg.D = 1e3
                tbg.CFrame = trailerCF
                tbg.Parent = tWeight
                State.trailerGyro = tbg
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

            if not keepVelocityFree then
                local h = Instance.new("BodyVelocity")
                h.MaxForce = Vector3.new(1e9, 1e9, 1e9)
                h.Velocity = Vector3.zero
                h.Parent = hrp
                State.hover = h
            end

            hrp.AssemblyLinearVelocity = Vector3.zero
            hrp.AssemblyAngularVelocity = Vector3.zero
        end
    end
end

local function stopMilesFarm(returnToGround)
    pcall(function()
        inputCtrl.set("W", 0)
    end)
    restoreIdentity()
    if State.milesBV then
        pcall(function()
            State.milesBV:Destroy()
        end)
        State.milesBV = nil
    end
    if State.milesBG then
        pcall(function()
            State.milesBG:Destroy()
        end)
        State.milesBG = nil
    end
    if State.milesPlatform then
        pcall(function()
            State.milesPlatform:Destroy()
        end)
        State.milesPlatform = nil
    end
    pcall(function()
        local oldPlat = workspace:FindFirstChild("ConeHub_MilesRoad")
        if oldPlat then
            oldPlat:Destroy()
        end
    end)
    if returnToGround then
        local char = plr.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        if hrp and hrp.Position.Y > 95 then
            local retCF = State.milesReturnCF or CFrame.new(80, 22, -1882)
            tp(retCF, true)
        end
        State.milesReturnCF = nil
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

local function getSpookfestCandyBalance()
    local val = 0
    pcall(function()
        local stats = sharedData.GetLoadedStatsFolder(plr)
        if stats then
            local c = stats:FindFirstChild("Spookfest2026Candy", true) or stats:FindFirstChild("Candy", true)
            if c and c:IsA("ValueBase") then
                val = tonumber(c.Value) or 0
            end
        end
    end)
    restoreIdentity()
    return val
end

local function getOtherPlayerNames()
    local list = {}
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= plr then
            table.insert(list, p.Name)
        end
    end
    if #list == 0 then
        table.insert(list, "None")
    end
    return list
end

local Window = Fluent:CreateWindow({
    Title = "Cone Hub",
    SubTitle = "Driving Empire",
    TabWidth = 140,
    Size = UDim2.fromOffset(560, 460),
    Acrylic = false,
    Theme = "Dark",
    MinimizeKey = Enum.KeyCode.LeftControl,
})

local Tabs = {
    Home = Window:AddTab({ Title = "Home", Icon = "home" }),
    Jobs = Window:AddTab({ Title = "Jobs", Icon = "truck" }),
    Event = Window:AddTab({ Title = "Event", Icon = "flame" }),
    Vehicle = Window:AddTab({ Title = "Vehicle", Icon = "gauge" }),
    Teleports = Window:AddTab({ Title = "Teleports", Icon = "map-pin" }),
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

local AutoClaimToggle = Tabs.Home:AddToggle("AutoClaimRewards", {
    Title = "Auto Claim Quests & Rewards",
    Description = "Automatically claims finished daily/weekly quests & free unclaimed rewards (never buys anything)",
    Default = State.autoClaimRewards,
})

local AfkToggle = Tabs.Home:AddToggle("AntiAfk", {
    Title = "Anti AFK",
    Description = "Prevents idle disconnect while farming",
    Default = State.antiAfk,
})

Tabs.Home:AddButton({
    Title = "Reset Session Cash & Timer",
    Description = "Resets session cash earned, miles gained, hourly rate, and elapsed timer",
    Callback = function()
        State.sessionStart = os.clock()
        State.deliveriesDone = 0
        State.atmsBusted = 0
        State.scenesDone = 0
        State.arrestsDone = 0
        State.candiesCollected = 0
        State.startCash = (plr:FindFirstChild("leaderstats") and plr.leaderstats:FindFirstChild("Cash") and plr.leaderstats.Cash.Value) or 0
        State.startMiles = (plr:FindFirstChild("leaderstats") and plr.leaderstats:FindFirstChild("Miles") and plr.leaderstats.Miles.Value) or 0
        State.startStuds = getStudsDriven()
    end,
})

local InfoBox = Tabs.Jobs:AddParagraph({
    Title = "Job Automation Status",
    Content = "Status: " .. State.statusText,
})

local AntiOutlawToggle = Tabs.Jobs:AddToggle("AntiOutlawArrest", {
    Title = "Anti-Outlaw & Anti-Arrest Evasion",
    Description = "Evades nearby Outlaws during HighRisk Delivery and escapes Security arrest circles during Criminal",
    Default = State.antiOutlawArrest,
})

local AutoDeliveryToggle = Tabs.Jobs:AddToggle("AutoDelivery", {
    Title = "Auto Delivery Job",
    Description = "Automatically collects and delivers packages",
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

local AutoCriminalToggle = Tabs.Jobs:AddToggle("AutoCriminal", {
    Title = "Auto Criminal (ATM Bust + Cash-In)",
    Description = "Joins Criminal job, busts unbusted ATMs across the map, and cashes in bounty at target star level",
    Default = State.autoCriminal,
})

local CashInStarsSlider = Tabs.Jobs:AddSlider("CriminalCashInStars", {
    Title = "Criminal Cash-In Star Level",
    Description = "Wanted star multiplier (1-5) before teleporting to Criminal Drop-Off to cash in",
    Default = State.criminalCashInStars,
    Min = 1,
    Max = 5,
    Rounding = 0,
})

local AutoArrestToggle = Tabs.Jobs:AddToggle("AutoArrestOutlaws", {
    Title = "Auto Arrest Outlaws (Security)",
    Description = "Joins Security job, hunts down Wanted Outlaws on the server, locks into their arrest circle, and arrests them",
    Default = State.autoArrestOutlaws,
})

local AutoSecurityToggle = Tabs.Jobs:AddToggle("AutoSecurityScenes", {
    Title = "Auto Security (Crime Scenes)",
    Description = "Joins Security job and investigates Crime Scenes around the map (can run alongside Auto Arrest)",
    Default = State.autoSecurityScenes,
})

local EventInfoBox = Tabs.Event:AddParagraph({
    Title = "Spookfest 2026 Candy Collector",
    Content = "Spawns your fastest owned car (never buys anything) and collects Candy Drops & Candy nodes across the map.",
})

local AutoCandyToggle = Tabs.Event:AddToggle("AutoCandy", {
    Title = "Auto Collect Spookfest Candy (Fastest Car)",
    Description = "Spawns your fastest owned vehicle and teleports to Spookfest2026CandyDrops & Spookfest2026Candy",
    Default = State.autoCandy,
})

local VehicleInfoBox = Tabs.Vehicle:AddParagraph({
    Title = "Mileage & Speed Farm Status",
    Content = "Spawns your fastest owned car (never buys anything) and drives it on a high-altitude sky circuit to farm Miles & Driving Cash.",
})

local AutoMilesToggle = Tabs.Vehicle:AddToggle("AutoMiles", {
    Title = "Auto Farm Miles & Driving Cash (Fastest Car)",
    Description = "Spawns your fastest owned vehicle and drives continuously on an obstacle-free sky road",
    Default = State.autoMiles,
})

local MilesSpeedSlider = Tabs.Vehicle:AddSlider("MilesSpeed", {
    Title = "Miles Farm Speed (MPH)",
    Description = "Target cruising speed while farming miles & driving cash",
    Default = State.milesSpeed,
    Min = 150,
    Max = 450,
    Rounding = 0,
})

Tabs.Vehicle:AddButton({
    Title = "Spawn Fastest Owned Car",
    Description = "Finds and spawns your fastest owned car without purchasing anything",
    Callback = function()
        task.spawn(function()
            local bestCar = findFastestOwnedCar()
            if bestCar then
                clearHover()
                local char = plr.Character
                local hrp = char and char:FindFirstChild("HumanoidRootPart")
                local look = (hrp and Vector3.new(hrp.CFrame.LookVector.X, 0, hrp.CFrame.LookVector.Z).Unit) or Vector3.new(0, 0, 1)
                pcall(function()
                    ReplicatedStorage.Remotes.VehicleEvent:FireServer("Spawn", bestCar, nil, nil, look)
                end)
            end
        end)
    end,
})

Tabs.Vehicle:AddButton({
    Title = "Spawn Best Tow Truck + Trailer",
    Description = "Spawns your highest-capacity tow vehicle and attaches the +4 LargeBox trailer",
    Callback = function()
        task.spawn(function()
            local bestVeh, bestTow = findBestTowSetup()
            if bestVeh and bestTow then
                clearHover()
                local char = plr.Character
                local hrp = char and char:FindFirstChild("HumanoidRootPart")
                local look = (hrp and Vector3.new(hrp.CFrame.LookVector.X, 0, hrp.CFrame.LookVector.Z).Unit) or Vector3.new(0, 0, 1)
                pcall(function()
                    ReplicatedStorage.Remotes.VehicleEvent:FireServer("Spawn", bestVeh, nil, nil, look)
                end)
                task.wait(1.2)
                pcall(function()
                    ReplicatedStorage.Remotes.SpawnTowable:InvokeServer(bestTow)
                end)
            end
        end)
    end,
})

local InfNitroToggle = Tabs.Vehicle:AddToggle("InfNitro", {
    Title = "Infinite Nitrous / Boost",
    Description = "Keeps vehicle nitrous supply full with zero depletion",
    Default = State.infNitro,
})

local UncapSpeedToggle = Tabs.Vehicle:AddToggle("UncapSpeed", {
    Title = "Uncap Vehicle Top Speed",
    Description = "Removes external MPH speed limiters on your active vehicle",
    Default = State.uncapSpeed,
})

local TorqueSlider = Tabs.Vehicle:AddSlider("TorqueMult", {
    Title = "Torque & Acceleration Multiplier",
    Description = "Boosts engine aspiration torque & incline compensation",
    Default = State.torqueMult,
    Min = 1,
    Max = 5,
    Rounding = 1,
})

local GripSlider = Tabs.Vehicle:AddSlider("GripMult", {
    Title = "Tire Grip Multiplier",
    Description = "Increases tire traction and cornering stability",
    Default = State.gripMult,
    Min = 1,
    Max = 3,
    Rounding = 1,
})

local LocationDropdown = Tabs.Teleports:AddDropdown("KeyLocationSelect", {
    Title = "Key Map Location",
    Values = LocationNames,
    Multi = false,
    Default = 1,
})

Tabs.Teleports:AddButton({
    Title = "Teleport to Selected Location",
    Description = "Teleports you (and your active vehicle + trailer) to the selected map location",
    Callback = function()
        local pos = KeyLocations[State.selectedLocation]
        if pos then
            tp(CFrame.new(pos + Vector3.new(0, 4, 0)), true)
        end
    end,
})

local PlayerDropdown = Tabs.Teleports:AddDropdown("PlayerTeleportSelect", {
    Title = "Select Player",
    Values = getOtherPlayerNames(),
    Multi = false,
    Default = 1,
})

Tabs.Teleports:AddButton({
    Title = "Refresh Player List",
    Description = "Updates the player dropdown with current server players",
    Callback = function()
        local names = getOtherPlayerNames()
        pcall(function()
            PlayerDropdown:SetValues(names)
        end)
    end,
})

Tabs.Teleports:AddButton({
    Title = "Teleport to Selected Player",
    Description = "Teleports you (and your active vehicle) to the selected player",
    Callback = function()
        local targetPlr = State.selectedPlayer and Players:FindFirstChild(State.selectedPlayer)
        local tChar = targetPlr and targetPlr.Character
        local tHrp = tChar and tChar:FindFirstChild("HumanoidRootPart")
        if tHrp then
            tp(tHrp.CFrame * CFrame.new(0, 4, 8), true)
        end
    end,
})

local function updateInfo()
    restoreIdentity()
    local ls = plr:FindFirstChild("leaderstats")
    local curCash = (ls and ls:FindFirstChild("Cash") and ls.Cash.Value) or State.startCash
    local curMiles = (ls and ls:FindFirstChild("Miles") and ls.Miles.Value) or 0
    local curStuds = getStudsDriven()
    local curMilesExact = (curStuds > 0) and (curStuds / 6445) or curMiles
    local studsEarned = math.max(0, curStuds - State.startStuds)
    local milesEarnedExact = studsEarned / 6445
    local curBounty = (ls and ls:FindFirstChild("Bounty") and ls.Bounty.Value) or 0
    local earned = math.max(0, curCash - State.startCash)
    local elapsed = math.max(1, os.clock() - State.sessionStart)
    local perHour = math.floor((earned / elapsed) * 3600)
    local milesPerHourRate = (milesEarnedExact / elapsed) * 3600
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
    local okStars, stars = pcall(criminalUtil.GetStarValue, plr)
    restoreIdentity()
    stars = (okStars and stars) or 0

    local car = getPlayerCar()
    local _, towId = getAttachedTrailer()
    local carLabel = (car and car.VehicleId) or "On Foot"
    if towId then
        carLabel = carLabel .. " + " .. tostring(towId)
    end
    local candyBal = getSpookfestCandyBalance()

    restoreIdentity()
    pcall(function()
        HomeProfileBox:SetDesc(string.format(
            "Player: %s (@%s)  |  Setup: %s\nCash: $%s  |  Miles: %.2f (+%.2f)  |  Bounty: $%s (%d Stars)",
            plr.DisplayName,
            plr.Name,
            carLabel,
            formatNumber(curCash),
            curMilesExact,
            milesEarnedExact,
            formatNumber(curBounty),
            stars
        ))
        HomeSessionBox:SetDesc(string.format(
            "Status: %s  |  Job: %s\nSession Earned: +$%s ($%s/hr)  |  Miles: +%.2f (%.1f/hr)  |  Uptime: %s\nDeliveries: %d  |  ATMs: %d  |  Scenes: %d  |  Arrests: %d",
            State.statusText,
            jobAttr,
            formatNumber(earned),
            formatNumber(perHour),
            milesEarnedExact,
            milesPerHourRate,
            formatDuration(elapsed),
            State.deliveriesDone,
            State.atmsBusted,
            State.scenesDone,
            State.arrestsDone
        ))
        InfoBox:SetDesc(string.format(
            "Status: %s  |  Active Job: %s\nDelivery: %d/%d (%s)  |  Done: %d  |  Mode: %s\nATMs Busted: %d (%d★)  |  Crime Scenes: %d  |  Arrests: %d",
            State.statusText,
            jobAttr,
            carried,
            cap,
            towId or "No Trailer",
            State.deliveriesDone,
            State.deliveryMode,
            State.atmsBusted,
            stars,
            State.scenesDone,
            State.arrestsDone
        ))
        EventInfoBox:SetDesc(string.format(
            "Status: %s\nVehicle: %s  |  Session Nodes Collected: %d\nSpookfest Candy Balance: %s",
            State.autoCandy and State.statusText or "Idle",
            carLabel,
            State.candiesCollected,
            formatNumber(candyBal)
        ))
        VehicleInfoBox:SetDesc(string.format(
            "Status: %s  |  Target Speed: %d MPH\nActive Vehicle: %s  |  Total Miles: %.2f (+%.2f mi / +%s studs)",
            State.autoMiles and State.statusText or "Idle",
            State.milesSpeed,
            carLabel,
            curMilesExact,
            milesEarnedExact,
            formatNumber(studsEarned)
        ))
    end)
end

local function disableOtherModes(activeKey)
    if State.updatingToggles then
        return
    end
    State.updatingToggles = true
    pcall(function()
        if activeKey ~= "Delivery" and State.autoDelivery then
            State.autoDelivery = false
            Options.AutoDelivery:SetValue(false)
        end
        if activeKey ~= "Criminal" and State.autoCriminal then
            State.autoCriminal = false
            Options.AutoCriminal:SetValue(false)
        end
        if activeKey ~= "Security" and activeKey ~= "Arrest" then
            if State.autoSecurityScenes then
                State.autoSecurityScenes = false
                Options.AutoSecurityScenes:SetValue(false)
            end
            if State.autoArrestOutlaws then
                State.autoArrestOutlaws = false
                Options.AutoArrestOutlaws:SetValue(false)
            end
        end
        if activeKey ~= "Candy" and State.autoCandy then
            State.autoCandy = false
            Options.AutoCandy:SetValue(false)
        end
        if activeKey ~= "Miles" and State.autoMiles then
            State.autoMiles = false
            Options.AutoMiles:SetValue(false)
            stopMilesFarm(true)
        end
    end)
    State.updatingToggles = false
end

local function ensureTowSetup(forceRecover)
    if not State.autoTrailer and not forceRecover then
        return
    end
    local car = getPlayerCar()
    if car and isPlayerTowing() then
        return
    end
    if tick() - State.lastTowAttempt < 2.5 then
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
        car = getPlayerCar()
        if car and car.Model and car.WeightPart then
            local recAttempted = false
            pcall(function()
                local existingList = towablesUtil.GetPlayerTowables(plr)
                local detached = existingList and existingList[1]
                local tWeight = detached and detached:FindFirstChild("Weight")
                local vehHitch = carTrailerUtil.GetHitchPart(car.Model, false)
                local trHitch = detached and carTrailerUtil.GetHitchPart(detached, true)
                if detached and tWeight and vehHitch and trHitch then
                    local trAtt, vehAtt = carTrailerUtil.GetMatchingHitchAttachments(trHitch, vehHitch)
                    if trAtt and vehAtt then
                        recAttempted = true
                        local flatCF = CFrame.new(car.WeightPart.Position.X, car.WeightPart.Position.Y + 3, car.WeightPart.Position.Z)
                        local vehAttLocal = car.WeightPart.CFrame:PointToObjectSpace(vehAtt.WorldPosition)
                        local trAttLocal = tWeight.CFrame:PointToObjectSpace(trAtt.WorldPosition)
                        tp(flatCF, true)
                        local targetHitch = flatCF:PointToWorldSpace(vehAttLocal)
                        local trCF = CFrame.new(targetHitch - trAttLocal)
                        detached.PrimaryPart = tWeight
                        detached:PivotTo(trCF)
                        for _, v in ipairs(detached:GetDescendants()) do
                            if v:IsA("BasePart") then
                                v.AssemblyLinearVelocity = Vector3.zero
                                v.AssemblyAngularVelocity = Vector3.zero
                            end
                        end
                    end
                end
            end)
            restoreIdentity()
            if recAttempted then
                local tRec = tick()
                repeat
                    task.wait(0.1)
                until not State.running or not State.autoDelivery or isPlayerTowing() or (tick() - tRec > 0.7)
            end
        end

        if not isPlayerTowing() then
            clearHover()
            car = getPlayerCar()
            if car and car.Model and car.WeightPart then
                local cp = car.WeightPart.Position
                tp(CFrame.new(cp.X, math.max(18, cp.Y + 2), cp.Z), true)
                task.wait(0.15)
            end
            pcall(function()
                ReplicatedStorage.Remotes.SpawnTowable:InvokeServer(bestTow)
            end)
            local t1 = tick()
            repeat
                task.wait(0.1)
            until not State.running or not State.autoDelivery or isPlayerTowing() or (tick() - t1 > 2.5)
        end
    end

    State.spawningTow = false
    State.curTarget, State.curLoc, State.curPhase = nil, nil, nil
    restoreIdentity()
end

local function ensureFastestCar()
    local car = getPlayerCar()
    local bestVeh = findFastestOwnedCar()
    if not bestVeh then
        return
    end
    if car and car.VehicleId == bestVeh then
        return
    end
    if tick() - State.lastFastCarAttempt < 4 then
        return
    end

    State.lastFastCarAttempt = tick()
    State.spawningFastCar = true
    State.statusText = string.format("Spawning Fastest Car (%s)...", bestVeh)
    updateInfo()

    clearHover()
    local char = plr.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    local look = (hrp and Vector3.new(hrp.CFrame.LookVector.X, 0, hrp.CFrame.LookVector.Z).Unit) or Vector3.new(0, 0, 1)
    pcall(function()
        ReplicatedStorage.Remotes.VehicleEvent:FireServer("Spawn", bestVeh, nil, nil, look)
    end)
    local t0 = tick()
    repeat
        task.wait(0.1)
        car = getPlayerCar()
    until not State.running or (car and car.VehicleId == bestVeh) or (tick() - t0 > 5)
    task.wait(0.2)
    State.spawningFastCar = false
    restoreIdentity()
end

local function getThreateningPlayer(threatJobId, radius)
    local char = plr.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then
        return nil
    end
    if threatJobId == "Security" then
        local okArr, hasArr = pcall(securityArrestTask.HasActiveArrestors)
        restoreIdentity()
        if okArr and hasArr then
            local okP, arrPlr = pcall(securityArrestTask.GetActiveArrestorPlayer)
            restoreIdentity()
            return (okP and arrPlr) or plr
        end
    end
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= plr and p:GetAttribute("JobId") == threatJobId then
            local pChar = p.Character
            local pHrp = pChar and pChar:FindFirstChild("HumanoidRootPart")
            if pHrp and (pHrp.Position - hrp.Position).Magnitude <= (radius or 140) then
                return p
            end
        end
    end
    return nil
end

local function findNearestAvailableATM(pos)
    local bestModel, bestDist = nil, nil
    for _, atm in ipairs(CollectionService:GetTagged("CriminalATM")) do
        if atm:IsA("Model") and atm.Parent then
            local okCan, canStart = pcall(criminalUtil.CanPlayerStartBustingATM, plr, atm)
            restoreIdentity()
            if okCan and canStart then
                local d = (atm:GetPivot().Position - pos).Magnitude
                if not bestDist or d < bestDist then
                    bestModel, bestDist = atm, d
                end
            end
        end
    end
    return bestModel
end

local function findNearestCrimeScene(pos)
    local bestScene, bestDist = nil, nil
    for _, sc in ipairs(CollectionService:GetTagged("SecurityCrimeScene")) do
        if sc.Parent and sc:GetAttribute("State") ~= "Used" then
            local engaging = sc:GetAttribute("EngagingPlayerId")
            if not engaging or engaging == plr.UserId then
                local scPos = sc:IsA("Model") and sc:GetPivot().Position or (sc:IsA("BasePart") and sc.Position)
                if scPos then
                    local d = (scPos - pos).Magnitude
                    if not bestDist or d < bestDist then
                        bestScene, bestDist = sc, d
                    end
                end
            end
        end
    end
    return bestScene
end

local function findBestDropOff(pos)
    local best, bestDist = nil, nil
    for _, d in ipairs(CollectionService:GetTagged("CriminalDropOffPoint")) do
        if d.Parent then
            local dPos = d:IsA("Model") and d:GetPivot().Position or (d:IsA("BasePart") and d.Position)
            if dPos then
                local dist = (dPos - pos).Magnitude
                if not bestDist or dist < bestDist then
                    best, bestDist = d, dist
                end
            end
        end
    end
    return best
end

local function findWantedOutlaw(pos)
    local bestPlr, bestDist = nil, nil
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= plr and p:GetAttribute("JobId") == "Criminal" then
            local pChar = p.Character
            local pHrp = pChar and pChar:FindFirstChild("HumanoidRootPart")
            if pHrp then
                local okW, wanted = pcall(criminalUtil.GetWantedState, p)
                local okS, stars = pcall(criminalUtil.GetStarValue, p)
                local okD, deb = pcall(criminalUtil.DoesPlayerHaveArrestDebounce, p)
                restoreIdentity()
                local bounty = (p:FindFirstChild("leaderstats") and p.leaderstats:FindFirstChild("Bounty") and p.leaderstats.Bounty.Value) or 0
                if not (okD and deb) and ((okW and wanted ~= nil) or (okS and (stars or 0) > 0) or bounty > 0) then
                    local d = (pHrp.Position - pos).Magnitude
                    if not bestDist or d < bestDist then
                        bestPlr, bestDist = p, d
                    end
                end
            end
        end
    end
    return bestPlr, bestDist
end

local function stepPatrolStream()
    if tick() - State.lastPatrolTick < 1.2 then
        return
    end
    State.lastPatrolTick = tick()
    local pt = PatrolPoints[State.patrolIdx]
    State.patrolIdx = (State.patrolIdx % #PatrolPoints) + 1
    pcall(function()
        plr:RequestStreamAroundAsync(pt, 2)
    end)
    restoreIdentity()
    tp(CFrame.new(pt + Vector3.new(0, 6, 0)))
end

local function checkAndClaimRewards()
    if not State.autoClaimRewards or tick() - State.lastRewardCheck < 6 then
        return
    end
    State.lastRewardCheck = tick()
    pcall(function()
        local quests = questUtil.getPlayerQuests(plr)
        if type(quests) == "table" then
            for _, q in pairs(quests) do
                if type(q) == "table" and q.QuestId then
                    local finished = questUtil.isQuestFinished(q, plr)
                    local claimed = questUtil.isQuestClaimed(q, plr)
                    if finished and not claimed then
                        questController.claimQuest(q.QuestId)
                        if ReplicatedStorage.Remotes:FindFirstChild("ClaimQuestReward") then
                            ReplicatedStorage.Remotes.ClaimQuestReward:FireServer(q.QuestId)
                        end
                    end
                end
            end
        end
        local stats = sharedData.GetLoadedStatsFolder(plr)
        local uncl = stats and stats:FindFirstChild("UnclaimedRewards")
        if uncl and type(uncl.Value) == "string" and #uncl.Value > 4 and ReplicatedStorage.Remotes:FindFirstChild("ClaimRewards") then
            ReplicatedStorage.Remotes.ClaimRewards:FireServer()
        end
    end)
    restoreIdentity()
end

updateInfo()

AutoDeliveryToggle:OnChanged(function()
    State.autoDelivery = Options.AutoDelivery.Value
    env.DEAutoDelivery = State.autoDelivery
    State.curTarget, State.curLoc, State.curPhase, State.lastTick, State.lastFire, State.dropAt = nil, nil, nil, nil, nil, nil
    if State.autoDelivery then
        disableOtherModes("Delivery")
        State.statusText = "Starting Delivery..."
    elseif not (State.autoCriminal or State.autoSecurityScenes or State.autoArrestOutlaws or State.autoCandy or State.autoMiles) then
        State.statusText = "Idle"
        clearHover()
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

AntiOutlawToggle:OnChanged(function()
    State.antiOutlawArrest = Options.AntiOutlawArrest.Value
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

AutoCriminalToggle:OnChanged(function()
    State.autoCriminal = Options.AutoCriminal.Value
    if State.autoCriminal then
        disableOtherModes("Criminal")
        State.statusText = "Starting Criminal Job..."
    elseif not (State.autoDelivery or State.autoSecurityScenes or State.autoArrestOutlaws or State.autoCandy or State.autoMiles) then
        State.statusText = "Idle"
        clearHover()
    end
    updateInfo()
    saveCurrentSettings()
end)

CashInStarsSlider:OnChanged(function(val)
    State.criminalCashInStars = math.clamp(math.floor(tonumber(val) or 5), 1, 5)
    saveCurrentSettings()
end)

AutoArrestToggle:OnChanged(function()
    State.autoArrestOutlaws = Options.AutoArrestOutlaws.Value
    State.arrestTarget = nil
    if State.autoArrestOutlaws then
        disableOtherModes("Arrest")
        State.statusText = "Starting Auto Arrest..."
    elseif not (State.autoDelivery or State.autoCriminal or State.autoSecurityScenes or State.autoCandy or State.autoMiles) then
        State.statusText = "Idle"
        clearHover()
    end
    updateInfo()
    saveCurrentSettings()
end)

AutoSecurityToggle:OnChanged(function()
    State.autoSecurityScenes = Options.AutoSecurityScenes.Value
    if State.autoSecurityScenes then
        disableOtherModes("Security")
        State.statusText = "Starting Security Job..."
    elseif not (State.autoDelivery or State.autoCriminal or State.autoArrestOutlaws or State.autoCandy or State.autoMiles) then
        State.statusText = "Idle"
        clearHover()
    end
    updateInfo()
    saveCurrentSettings()
end)

AutoCandyToggle:OnChanged(function()
    State.autoCandy = Options.AutoCandy.Value
    State.lastCandyPos = nil
    State.sameCandyTicks = 0
    if State.autoCandy then
        disableOtherModes("Candy")
        State.statusText = "Starting Spookfest Candy Farm..."
    elseif not (State.autoDelivery or State.autoCriminal or State.autoSecurityScenes or State.autoArrestOutlaws or State.autoMiles) then
        State.statusText = "Idle"
        clearHover()
    end
    updateInfo()
    saveCurrentSettings()
end)

AutoMilesToggle:OnChanged(function()
    State.autoMiles = Options.AutoMiles.Value
    if State.autoMiles then
        disableOtherModes("Miles")
        clearHover()
        State.statusText = "Starting Miles Farm..."
    else
        stopMilesFarm(true)
        if not (State.autoDelivery or State.autoCriminal or State.autoSecurityScenes or State.autoArrestOutlaws or State.autoCandy) then
            State.statusText = "Idle"
            clearHover()
        end
    end
    updateInfo()
    saveCurrentSettings()
end)

MilesSpeedSlider:OnChanged(function(val)
    State.milesSpeed = math.clamp(math.floor(tonumber(val) or 380), 150, 450)
    updateInfo()
    saveCurrentSettings()
end)

AutoClaimToggle:OnChanged(function()
    State.autoClaimRewards = Options.AutoClaimRewards.Value
    saveCurrentSettings()
end)

AfkToggle:OnChanged(function()
    State.antiAfk = Options.AntiAfk.Value
    saveCurrentSettings()
end)

InfNitroToggle:OnChanged(function()
    State.infNitro = Options.InfNitro.Value
    saveCurrentSettings()
end)

UncapSpeedToggle:OnChanged(function()
    State.uncapSpeed = Options.UncapSpeed.Value
    pcall(function()
        local ch = vehicles.getActiveChassisController()
        if ch and ch.SetExternalMaxSpeedMPH then
            ch:SetExternalMaxSpeedMPH(State.uncapSpeed and 999 or nil)
        end
    end)
    restoreIdentity()
    saveCurrentSettings()
end)

TorqueSlider:OnChanged(function(val)
    State.torqueMult = tonumber(val) or 1
    saveCurrentSettings()
end)

GripSlider:OnChanged(function(val)
    State.gripMult = tonumber(val) or 1
    pcall(function()
        local ch = vehicles.getActiveChassisController()
        if ch and ch.SetExternalGripMultiplier then
            ch:SetExternalGripMultiplier(State.gripMult)
        end
    end)
    restoreIdentity()
    saveCurrentSettings()
end)

LocationDropdown:OnChanged(function(val)
    if type(val) == "string" and KeyLocations[val] then
        State.selectedLocation = val
    end
end)

PlayerDropdown:OnChanged(function(val)
    if type(val) == "string" then
        State.selectedPlayer = val
    end
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

if ReplicatedStorage:FindFirstChild("Remotes") and ReplicatedStorage.Remotes:FindFirstChild("LocalSecurityArrestCompleted") then
    table.insert(State.conns, ReplicatedStorage.Remotes.LocalSecurityArrestCompleted.OnClientEvent:Connect(function()
        State.arrestsDone += 1
        updateInfo()
    end))
end

table.insert(State.conns, RunService.Heartbeat:Connect(function(dt)
    pcall(function()
        local ch = vehicles.getActiveChassisController()
        if ch then
            if State.infNitro or State.autoMiles then
                ch.CurrentBoostSupply = 2
                ch.NitrousAppliedDepletionRate = 0
                ch.NitrousReplenishRate = 10
            end
            if (State.uncapSpeed or State.autoMiles) and ch.SetExternalMaxSpeedMPH then
                ch:SetExternalMaxSpeedMPH(999)
            end
            if State.torqueMult > 1 then
                ch.AspirationTorqueMult = State.torqueMult
                if ch.SetExternalInclineCompensation then
                    ch:SetExternalInclineCompensation(State.torqueMult)
                end
            end
            if State.gripMult > 1 and ch.SetExternalGripMultiplier then
                ch:SetExternalGripMultiplier(State.gripMult)
            end
        end
    end)
    restoreIdentity()

    if State.autoMiles and not State.spawningFastCar then
        pcall(function()
            inputCtrl.set("W", 1)
        end)
        restoreIdentity()
        local car = getPlayerCar()
        if car and car.WeightPart and State.milesPlatform then
            local stepDt = math.clamp(tonumber(dt) or 0.016, 0.001, 0.1)
            State.milesAngle = (State.milesAngle + ((State.milesSpeed / 1400) * stepDt)) % (math.pi * 2)
            local dir = Vector3.new(math.cos(State.milesAngle), 0, math.sin(State.milesAngle))
            local p = car.WeightPart.Position
            State.milesPlatform.CFrame = CFrame.new(p.X, State.milesPlatformY, p.Z)
            car.WeightPart.CFrame = CFrame.lookAt(p, p + dir)
            local velY = math.clamp(car.WeightPart.AssemblyLinearVelocity.Y, -20, 5)
            car.WeightPart.AssemblyLinearVelocity = Vector3.new(dir.X * State.milesSpeed, velY, dir.Z * State.milesSpeed)
            car.WeightPart.AssemblyAngularVelocity = Vector3.zero
        end
    end

    local anyActive = State.autoDelivery or State.autoCriminal or State.autoSecurityScenes or State.autoArrestOutlaws or State.autoCandy or State.autoMiles
    if not anyActive or State.spawningTow or State.spawningFastCar then
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
        checkAndClaimRewards()

        local anyActive = State.autoDelivery or State.autoCriminal or State.autoSecurityScenes or State.autoArrestOutlaws or State.autoCandy or State.autoMiles
        if not anyActive then
            updateInfo()
            task.wait(0.25)
            continue
        end

        local char = plr.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")

        if hrp then
            if State.autoMiles then
                if not State.milesReturnCF and hrp.Position.Y < 95 then
                    State.milesReturnCF = CFrame.new(hrp.Position.X, math.max(18, hrp.Position.Y + 4), hrp.Position.Z)
                end
                ensureFastestCar()
                local car = getPlayerCar()
                if car and car.Model and car.WeightPart then
                    clearHover()
                    if State.milesBV then
                        pcall(function()
                            State.milesBV:Destroy()
                        end)
                        State.milesBV = nil
                    end
                    if State.milesBG then
                        pcall(function()
                            State.milesBG:Destroy()
                        end)
                        State.milesBG = nil
                    end
                    if not State.milesPlatform or not State.milesPlatform.Parent then
                        local plat = Instance.new("Part")
                        plat.Name = "ConeHub_MilesRoad"
                        plat.Size = Vector3.new(2048, 4, 2048)
                        plat.Anchored = true
                        plat.CanCollide = true
                        plat.Transparency = 1
                        plat.CFrame = CFrame.new(car.WeightPart.Position.X, State.milesPlatformY, car.WeightPart.Position.Z)
                        plat.Parent = workspace
                        State.milesPlatform = plat
                    end

                    local p = car.WeightPart.Position
                    if math.abs(p.Y - (State.milesPlatformY + 4.5)) > 14 or math.abs(p.X) > 6500 or math.abs(p.Z) > 6500 then
                        local spawnX = math.clamp(p.X, -1500, 1500)
                        local spawnZ = math.clamp(p.Z, -2500, 1500)
                        local dir = Vector3.new(math.cos(State.milesAngle), 0, math.sin(State.milesAngle))
                        State.milesPlatform.CFrame = CFrame.new(spawnX, State.milesPlatformY, spawnZ)
                        tp(CFrame.lookAt(Vector3.new(spawnX, State.milesPlatformY + 4.5, spawnZ), Vector3.new(spawnX, State.milesPlatformY + 4.5, spawnZ) + dir), true)
                    end

                    State.statusText = string.format("Farming Miles (%s @ %d MPH)", tostring(car.VehicleId), State.milesSpeed)
                else
                    State.statusText = "Waiting for Fastest Car..."
                end
                updateInfo()
                task.wait(0.25)

            elseif State.autoCandy then
                ensureFastestCar()
                local pos = hrp.Position
                local okD, dropPos = pcall(collectibleSpawner.GetNearestAvailable, "Spookfest2026CandyDrops", pos)
                local okC, candyPos = pcall(collectibleSpawner.GetNearestAvailable, "Spookfest2026Candy", pos)
                restoreIdentity()
                local nextPos = (okD and dropPos) or (okC and candyPos)

                if nextPos then
                    if State.lastCandyPos and (nextPos - State.lastCandyPos).Magnitude < 1.5 then
                        State.sameCandyTicks += 1
                    else
                        if State.lastCandyPos then
                            State.candiesCollected += 1
                        end
                        State.lastCandyPos = nextPos
                        State.sameCandyTicks = 0
                    end

                    State.statusText = (okD and dropPos) and "Collecting Candy Drop..." or "Collecting Spookfest Candy..."
                    local yOff = getPlayerCar() and 4 or 3
                    if State.sameCandyTicks > 8 then
                        local jitter = Vector3.new(math.random(-6, 6), yOff, math.random(-6, 6))
                        tp(CFrame.new(nextPos + jitter))
                        State.sameCandyTicks = 0
                    else
                        tp(CFrame.new(nextPos + Vector3.new(0, yOff, 0)))
                    end
                    updateInfo()
                    task.wait(0.18)
                else
                    State.statusText = "Waiting for Candy Respawn..."
                    updateInfo()
                    task.wait(0.35)
                end

            elseif State.autoDelivery then
                if plr:GetAttribute("JobId") ~= "Delivery" then
                    State.statusText = "Starting Delivery Session..."
                    updateInfo()
                    ReplicatedStorage.Remotes.RequestStartJobSession:FireServer("Delivery", "deliveryHub", State.deliveryMode)
                    State.curTarget, State.curLoc, State.curPhase, State.lastTick, State.dropAt = nil, nil, nil, nil, nil
                    task.wait(0.5)
                else
                    if State.antiOutlawArrest and State.deliveryMode == "HighRisk" then
                        local outlaw = getThreateningPlayer("Criminal", 145)
                        if outlaw then
                            State.statusText = "Evading Outlaw (" .. outlaw.Name .. ")..."
                            tp(CFrame.new(hrp.Position + Vector3.new(0, 220, 0)))
                            updateInfo()
                            task.wait(0.4)
                            continue
                        end
                    end

                    local okSt, state = pcall(delivery.GetCurrentDeliveryState)
                    restoreIdentity()
                    state = okSt and state or nil

                    local needsTrailer = State.autoTrailer or (state and state.IsTowing == true)
                    if needsTrailer and not isPlayerTowing() then
                        ensureTowSetup(true)
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
                                State.dropStuckSince = State.dropStuckSince or tick()
                                State.statusText = string.format("Delivering (%d/%d)", carried, cap)
                            else
                                target = state.PickupPosition
                                State.dropStuckSince = nil
                                State.statusText = string.format("Waiting %.1fs (%d/%d)", math.max(0, State.dropAt - tick()), carried, cap)
                            end
                        else
                            State.dropAt = nil
                            State.dropStuckSince = nil
                            phase = "pickup"
                            target = state.PickupPosition
                            State.statusText = string.format("Collecting (%d/%d)", carried, cap)
                        end
                    else
                        State.dropAt = nil
                        State.dropStuckSince = nil
                        State.lastTick = State.lastTick or tick()
                        State.statusText = "Finding Pickup Location..."

                        if tick() - State.lastTick > 0.25 then
                            local loc = getLoc(hrp.Position, true, false) or getLoc(hrp.Position, false, false)
                            phase = "new"
                            target = loc and loc.Position
                        end
                    end

                    if target then
                        local drifted = (Vector3.new(hrp.Position.X, 0, hrp.Position.Z) - Vector3.new(target.X, 0, target.Z)).Magnitude > 11
                        if target ~= State.curTarget or phase ~= State.curPhase or drifted then
                            local yOffset = isPlayerTowing() and 6.2 or (getPlayerCar() and 5 or 3.5)
                            tp(CFrame.new(target + Vector3.new(0, yOffset, 0)))
                            State.curTarget, State.curPhase = target, phase
                        end

                        local loc = getLoc(target, false, (state ~= nil))

                        if loc then
                            if State.dropStuckSince and (tick() - State.dropStuckSince > 3.5) then
                                State.dropStuckSince = tick()
                                pcall(function()
                                    if ReplicatedStorage.Remotes:FindFirstChild("DeliveryLocationLeft") then
                                        ReplicatedStorage.Remotes.DeliveryLocationLeft:FireServer(loc)
                                    end
                                end)
                                local yOffset = isPlayerTowing() and 5.8 or (getPlayerCar() and 4.8 or 3.5)
                                tp(CFrame.new(target + Vector3.new(0, yOffset, 0)))
                                task.wait(0.1)
                                ReplicatedStorage.Remotes.DeliveryLocationInteracted:FireServer(loc)
                                State.curLoc, State.lastFire = loc, tick()
                            elseif loc ~= State.curLoc then
                                ReplicatedStorage.Remotes.DeliveryLocationInteracted:FireServer(loc)
                                State.curLoc, State.lastFire = loc, tick()
                            elseif not State.lastFire or tick() - State.lastFire > 0.85 then
                                ReplicatedStorage.Remotes.DeliveryLocationInteracted:FireServer(loc)
                                State.lastFire = tick()
                            end
                        end
                    end

                    updateInfo()
                end

            elseif State.autoCriminal then
                if plr:GetAttribute("JobId") ~= "Criminal" then
                    State.statusText = "Starting Criminal Job..."
                    updateInfo()
                    ReplicatedStorage.Remotes.RequestStartJobSession:FireServer("Criminal", "criminalHub")
                    task.wait(0.5)
                else
                    if State.antiOutlawArrest then
                        local cop = getThreateningPlayer("Security", 140)
                        if cop then
                            State.statusText = "Evading Security (" .. cop.Name .. ")..."
                            local dropOff = findBestDropOff(hrp.Position)
                            local safePos = (dropOff and dropOff:GetPivot().Position) or Vector3.new(7322, 200, -2811)
                            tp(CFrame.new(safePos + Vector3.new(0, 6, 0)))
                            updateInfo()
                            task.wait(0.5)
                            continue
                        end
                    end

                    local okStars, stars = pcall(criminalUtil.GetStarValue, plr)
                    restoreIdentity()
                    stars = (okStars and stars) or 0

                    if stars >= State.criminalCashInStars then
                        local dropOff = findBestDropOff(hrp.Position)
                        if dropOff then
                            local dPos = dropOff:IsA("Model") and dropOff:GetPivot().Position or dropOff.Position
                            State.statusText = string.format("Cashing In Bounty (%d★)...", stars)
                            tp(CFrame.new(dPos + Vector3.new(0, 4, 0)))
                            updateInfo()
                            task.wait(0.25)
                            pcall(function()
                                criminalATMTask.AttemptCompleteJob(dropOff)
                            end)
                            restoreIdentity()
                            task.wait(0.5)
                        else
                            stepPatrolStream()
                        end
                    else
                        local atm = findNearestAvailableATM(hrp.Position)
                        if atm then
                            local atmPos = atm:GetPivot().Position
                            State.statusText = string.format("Busting %s (%d★)...", atm.Name, stars)
                            tp(CFrame.new(atmPos + Vector3.new(0, 3.5, 0)))
                            updateInfo()
                            task.wait(0.2)

                            local okStart, started = pcall(function()
                                return ReplicatedStorage.Remotes.AttemptATMBustStart:InvokeServer(atm)
                            end)
                            restoreIdentity()

                            if okStart and started then
                                local okTime, bustTime = pcall(criminalUtil.GetATMBustTime, plr)
                                restoreIdentity()
                                local waitSec = (okTime and tonumber(bustTime)) or 5
                                local tStart = tick()
                                local aborted = false

                                while tick() - tStart < (waitSec + 0.15) do
                                    if not State.running or not State.autoCriminal then
                                        aborted = true
                                        break
                                    end
                                    if State.antiOutlawArrest and getThreateningPlayer("Security", 130) then
                                        aborted = true
                                        break
                                    end
                                    tp(CFrame.new(atmPos + Vector3.new(0, 3.5, 0)))
                                    State.statusText = string.format("Busting ATM %.1fs (%d★)...", math.max(0, (waitSec + 0.15) - (tick() - tStart)), stars)
                                    updateInfo()
                                    task.wait(0.1)
                                end

                                if not aborted then
                                    local okFin, fin = pcall(function()
                                        return ReplicatedStorage.Remotes.AttemptATMBustComplete:InvokeServer(atm)
                                    end)
                                    restoreIdentity()
                                    if okFin and fin then
                                        State.atmsBusted += 1
                                    end
                                end
                            end
                        else
                            State.statusText = "Scanning Map for ATMs..."
                            updateInfo()
                            stepPatrolStream()
                        end
                    end
                end

            elseif State.autoArrestOutlaws or State.autoSecurityScenes then
                if plr:GetAttribute("JobId") ~= "Security" then
                    State.statusText = "Starting Security Job..."
                    updateInfo()
                    ReplicatedStorage.Remotes.RequestStartJobSession:FireServer("Security", "securityHub")
                    task.wait(0.5)
                else
                    local targetOutlaw = State.autoArrestOutlaws and findWantedOutlaw(hrp.Position) or nil

                    if targetOutlaw and targetOutlaw.Character and targetOutlaw.Character:FindFirstChild("HumanoidRootPart") then
                        local tHrp = targetOutlaw.Character.HumanoidRootPart
                        State.statusText = string.format("Arresting Outlaw: %s...", targetOutlaw.DisplayName)
                        tp(tHrp.CFrame * CFrame.new(0, 2.5, 4))

                        if State.arrestTarget ~= targetOutlaw then
                            State.arrestTarget = targetOutlaw
                            State.arrestStartedAt = tick()
                            pcall(function()
                                securityArrestTask.NotifyStartArresting(targetOutlaw, 0)
                            end)
                            restoreIdentity()
                        else
                            if tick() - State.arrestStartedAt > 0.4 then
                                pcall(function()
                                    securityArrestTask.NotifyStartArresting(targetOutlaw, 0)
                                    securityArrestTask.RequestArrestCriminal(targetOutlaw)
                                end)
                                restoreIdentity()
                            end
                        end
                        updateInfo()
                    elseif State.autoSecurityScenes then
                        State.arrestTarget = nil
                        local scene = findNearestCrimeScene(hrp.Position)
                        if scene then
                            local scPos = scene:IsA("Model") and scene:GetPivot().Position or scene.Position
                            State.statusText = "Investigating Crime Scene..."
                            tp(CFrame.new(scPos + Vector3.new(0, 3.5, 0)))
                            updateInfo()
                            task.wait(0.2)

                            local okStart, started = pcall(function()
                                return ReplicatedStorage.Remotes.AttemptStartUsingCrimeScene:InvokeServer(scene)
                            end)
                            restoreIdentity()

                            if okStart and started then
                                local okTime, useTime = pcall(securityUtil.GetCrimeSceneUseTime, plr)
                                restoreIdentity()
                                local waitSec = (okTime and tonumber(useTime)) or 5
                                local tStart = tick()
                                local aborted = false

                                while tick() - tStart < (waitSec + 0.15) do
                                    if not State.running or not State.autoSecurityScenes then
                                        aborted = true
                                        break
                                    end
                                    if State.autoArrestOutlaws and findWantedOutlaw(hrp.Position) then
                                        aborted = true
                                        break
                                    end
                                    tp(CFrame.new(scPos + Vector3.new(0, 3.5, 0)))
                                    State.statusText = string.format("Investigating %.1fs...", math.max(0, (waitSec + 0.15) - (tick() - tStart)))
                                    updateInfo()
                                    task.wait(0.1)
                                end

                                if not aborted then
                                    local okFin, fin = pcall(function()
                                        return ReplicatedStorage.Remotes.AttemptFinishUsingCrimeScene:InvokeServer(scene)
                                    end)
                                    restoreIdentity()
                                    if okFin and fin then
                                        State.scenesDone += 1
                                    end
                                end
                            end
                        else
                            State.statusText = "Scanning Map for Crime Scenes..."
                            updateInfo()
                            stepPatrolStream()
                        end
                    else
                        State.arrestTarget = nil
                        State.statusText = "Waiting for Wanted Outlaws..."
                        updateInfo()
                        task.wait(0.3)
                    end
                end
            end
        end

        task.wait(0.1)
    end
end)

env.__DrivingEmpireCleanup = function()
    restoreIdentity()
    State.running = false
    State.autoDelivery = false
    State.autoCriminal = false
    State.autoSecurityScenes = false
    State.autoArrestOutlaws = false
    State.autoCandy = false
    State.autoMiles = false
    env.DEAutoDelivery = false
    stopMilesFarm(false)
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
