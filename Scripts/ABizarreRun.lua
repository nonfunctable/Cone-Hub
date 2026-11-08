
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")
local HttpService = game:GetService("HttpService")
local VirtualInputManager = game:GetService("VirtualInputManager")
local VirtualUser = game:GetService("VirtualUser")

local plr = Players.LocalPlayer
local env = (getgenv and getgenv()) or shared

if env.__ABRCleanup then
    pcall(env.__ABRCleanup)
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
local Fluent = loadRemoteModule(repoBase .. "Fluent.lua", "https://github.com/dawid-scripts/Fluent/releases/latest/download/main.lua")
local SaveManager = loadRemoteModule(repoBase .. "SaveManager.lua", "https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Addons/SaveManager.lua")
local InterfaceManager = loadRemoteModule(repoBase .. "InterfaceManager.lua", "https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Addons/InterfaceManager.lua")

local settingsPath = "ConeHub/ABizarreRun_State.json"
local function loadSaved()
    if not (isfile and readfile) then return {} end
    local ok, data = pcall(function()
        if isfile(settingsPath) then return HttpService:JSONDecode(readfile(settingsPath)) end
    end)
    return (ok and type(data) == "table") and data or {}
end
local saved = loadSaved()
local function pick(v, default) if v == nil then return default end return v end

local S = {
    autoQueue = pick(saved.autoQueue, false),
    autoRegister = pick(saved.autoRegister, true),
    autoRace = pick(saved.autoRace, true),
    useSprint = pick(saved.useSprint, true),
    useBoost = pick(saved.useBoost, true),
    autoRecall = pick(saved.autoRecall, true),
    lassoEscape = pick(saved.lassoEscape, true),
    avoidHazards = pick(saved.avoidHazards, true),
    antiAfk = pick(saved.antiAfk, true),
    autoReturn = pick(saved.autoReturn, true),
    followRiders = pick(saved.followRiders, true),
    autoSkip = pick(saved.autoSkip, true),
    autoBounty = pick(saved.autoBounty, true),
    autoCombat = pick(saved.autoCombat, true),
    staminaAssist = pick(saved.staminaAssist, true),
    infStamina = pick(saved.infStamina, true),
    extraSpeed = pick(saved.extraSpeed, 0.15),
    boostRefill = pick(saved.boostRefill, true),
    bountyPick = pick(saved.bountyPick, "Easy"),
    humanness = pick(saved.humanness, 50),
    reaction = pick(saved.reaction, 180),
    sprintStop = pick(saved.sprintStop, 18),
    sprintResume = pick(saved.sprintResume, 60),
}

local function saveSettings()
    if not (writefile and makefolder) then return end
    pcall(function()
        if not isfolder("ConeHub") then makefolder("ConeHub") end
        writefile(settingsPath, HttpService:JSONEncode(S))
    end)
end

local running = true
local conns = {}
local status = "Idle"
local stats = { races = 0, lastPlace = "-", recalls = 0, boosts = 0, stuck = 0, slowSec = 0, rideSec = 0, log = {} }
local function slog(msg) table.insert(stats.log, string.format("%.0f %s", os.clock(), msg)) if #stats.log > 60 then table.remove(stats.log, 1) end end

local function rand(a, b) return a + math.random() * (b - a) end
local function H() return math.clamp(S.humanness / 100, 0, 1) end
local function reactDelay(mult)
    local base = (S.reaction / 1000) * (mult or 1)
    local jitter = base * rand(-0.3, 0.6)
    if math.random() < 0.06 * (0.5 + H()) then jitter += rand(0.15, 0.45) end
    return math.max(0.03, base + jitter)
end

local held = {}
local function key(k, down)
    if held[k] == down then return end
    held[k] = down
    pcall(function() VirtualInputManager:SendKeyEvent(down, k, false, game) end)
end
local function tap(k, hold)
    key(k, true)
    task.wait(hold or rand(0.05, 0.11))
    key(k, false)
end
local function releaseAll()
    for k, d in pairs(held) do if d then key(k, false) end end
end

local Knit
pcall(function() Knit = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("Knit")) end)
local function knitService(name)
    local ok, s = pcall(function() return Knit.GetService(name) end)
    return ok and s or nil
end

local function mapName()
    local gc = ReplicatedStorage:FindFirstChild("GameConfig")
    return gc and gc:GetAttribute("Map")
end
local function inRaceMap()
    local m = mapName()
    return type(m) == "string" and (m:match("^Stage") ~= nil or m == "Tutorial")
end

local function char() return plr.Character end
local function hrp() local c = char() return c and c:FindFirstChild("HumanoidRootPart") end
local function hum() local c = char() return c and c:FindFirstChildOfClass("Humanoid") end
local function flat(v) return Vector3.new(v.X, 0, v.Z) end

local function myHorse()
    for _, h in ipairs(CollectionService:GetTagged("Horse")) do
        local o = h:FindFirstChild("Owner")
        if o and o.Value == plr and h:IsDescendantOf(workspace) then return h end
    end
end
local function isMounted(h)
    h = h or myHorse()
    local seat = h and h:FindFirstChild("Seat", true)
    local hm = hum()
    return seat ~= nil and hm ~= nil and seat.Occupant == hm
end
local function horseRoot(h)
    return h and (h:FindFirstChild("RootPart") or h.PrimaryPart)
end

local function checkpointsFolder()
    local map = workspace:FindFirstChild("Map")
    local gp = map and map:FindFirstChild("Gameplay")
    return (gp and gp:FindFirstChild("Checkpoints")) or (map and map:FindFirstChild("Checkpoints", true))
end
local function checkpointList()
    local f = checkpointsFolder()
    local list = {}
    if f then
        for _, p in ipairs(f:GetChildren()) do
            local n = tonumber(p.Name)
            if n and p:IsA("BasePart") then list[#list + 1] = { n = n, part = p } end
        end
        table.sort(list, function(a, b) return a.n < b.n end)
    end
    return list
end
local function currentCheckpoint()
    local c = char()
    local cc = c and c:GetAttribute("CurrentCheckpoint")
    if cc ~= nil then return cc end
    return plr:GetAttribute("CurrentCheckpoint") or 0
end
local function cpTarget(cp)
    return cp.Position + cp.CFrame.LookVector * 20
end

local function gameDrivesMe()
    local c = char()
    if not c then return true end
    return c:GetAttribute("RaceStartLocked") or c:GetAttribute("RaceFrozen") or c:GetAttribute("Ragdolled")
        or (hrp() and hrp().Anchored)
end
local function finished()
    local c = char()
    return (plr:GetAttribute("FinishPosition") ~= nil and (c and c:GetAttribute("Finished")))
        or (c and c:GetAttribute("Finished") == true)
end

local queryFixed = setmetatable({}, { __mode = "k" })
local function fixQuery(p)
    if p:IsA("BasePart") and p.CanCollide and not p.CanQuery and not queryFixed[p] then
        local mounts = workspace:FindFirstChild("Mounts")
        if mounts and p:IsDescendantOf(mounts) then return end
        if p:FindFirstAncestorOfClass("Model") and p:FindFirstAncestorOfClass("Model"):FindFirstChildOfClass("Humanoid") then return end
        queryFixed[p] = true
        pcall(function() p.CanQuery = true end)
    end
end
task.spawn(function()
    local n = 0
    for _, d in ipairs(workspace:GetDescendants()) do
        fixQuery(d)
        n += 1
        if n % 4000 == 0 then task.wait() end
    end
end)
local queryConn = workspace.DescendantAdded:Connect(function(d)
    if d:IsA("BasePart") then task.defer(fixQuery, d) end
end)

local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude
local rayFilterAt, rayFilterHorse = 0, nil
local function refreshRayFilter(h)
    if os.clock() - rayFilterAt < 1 and rayFilterHorse == h then return end
    rayFilterAt, rayFilterHorse = os.clock(), h
    local list = { char(), workspace:FindFirstChild("VFX"), workspace:FindFirstChild("Ragdolls") }
    if h then list[#list + 1] = h end
    for _, p in ipairs(Players:GetPlayers()) do if p.Character then list[#list + 1] = p.Character end end
    for _, m in ipairs(CollectionService:GetTagged("Horse")) do list[#list + 1] = m end
    rayParams.FilterDescendantsInstances = list
end
local function wallAhead(origin, dir, dist)
    local hit = workspace:Raycast(origin, dir.Unit * dist, rayParams)
    if hit and hit.Instance and hit.Instance.CanCollide then
        if hit.Normal.Y < 0.6 then return hit end
    end
end

local nextQueueTry = 0
local function lobbyTick()
    if not S.autoQueue then status = "Lobby (auto queue off)" return end
    if plr:GetAttribute("InQueue") then status = "In queue..." return end
    if workspace:GetAttribute("QueueFull") == true then status = "Queue full, waiting" return end
    if os.clock() < nextQueueTry then return end
    nextQueueTry = os.clock() + rand(3, 5)
    task.wait(rand(0.35, 1.1))
    local qs = knitService("QueueService")
    if qs then
        local ok, err = pcall(function() return qs:JoinQueue() end)
        status = ok and "Joined race queue" or ("Queue failed: " .. tostring(err))
    end
end

local function nearestBooth()
    local best, bd
    local root = hrp()
    if not root then return end
    for _, b in ipairs(CollectionService:GetTagged("RegistrationBooth")) do
        if b:IsA("BasePart") and b:IsDescendantOf(workspace) then
            local cv = b:FindFirstChild("Character")
            local free = not (cv and cv.Value ~= nil and cv.Value ~= char())
            local dist = (b.Position - root.Position).Magnitude
            if free and (not bd or dist < bd) then best, bd = b, dist end
        end
    end
    return best, bd
end

local function registerTick()
    local c = char()
    if not (S.autoRegister and c) then return false end
    if mapName() ~= "Stage1" then return false end
    if c:HasTag("Registered") then return false end
    if workspace:GetAttribute("RegistrationClosed") == true or workspace:GetAttribute("RaceStarted") == true then return false end
    if workspace:GetAttribute("IntermissionTimer") == nil then return false end
    if gameDrivesMe() then status = "Registering (photo)..." return true end
    local booth, dist = nearestBooth()
    if not booth then status = "Registration: no free booth" return true end
    status = string.format("Walking to registration booth (%.0f studs)", dist)
    local hm = hum()
    if hm then hm:MoveTo(booth.Position) end
    return true
end

local D = {
    lastSteerChange = 0,
    steerKey = nil,
    lineOffset = 0,
    lineOffsetGoal = 0,
    nextOffsetChange = 0,
    sprinting = false,
    sprintResumeAt = 60,
    lastSprintToggle = 0,
    lastRecall = 0,
    lastBoostTry = 0,
    stuckSince = nil,
    lastPos = nil,
    lastLassoPress = 0,
    distractedUntil = 0,
    lastJump = 0,
}

local function resetDriver()
    releaseAll()
    D.steerKey = nil
    D.sprinting = false
    D.stuckSince = nil
    D.lastPos = nil
    if mapName() ~= "Stage2" then D.townAnchor, D.townThreat = nil, nil end
end

local function pathStops()
    local map = workspace:FindFirstChild("Map")
    local bp = map and map:FindFirstChild("BotPathways", true)
    if not bp then return nil end
    if D.stopsFor == bp and D.stops then return D.stops end
    local stops = {}
    for _, f in ipairs(bp:GetChildren()) do
        local n = tonumber(f.Name)
        if n then
            local pts = {}
            for _, w in ipairs(f:GetChildren()) do if w:IsA("BasePart") then pts[#pts + 1] = w.Position end end
            if #pts > 0 then stops[#stops + 1] = { n = n, pts = pts } end
        end
    end
    table.sort(stops, function(a, b) return a.n < b.n end)
    D.stops, D.stopsFor, D.wpi = stops, bp, nil
    return stops
end
local function centroid(pts) local c = Vector3.zero for _, p in ipairs(pts) do c += p end return c / #pts end
D.blockedLanes = D.blockedLanes or {}
local function laneKey(p) return math.floor(p.X / 4) .. ":" .. math.floor(p.Z / 4) end
local function bestLane(stop, fromPos, nextStop)
    local nxt = nextStop and centroid(nextStop.pts)
    local best, bc
    for _, p in ipairs(stop.pts) do
        local cost = flat(p - fromPos).Magnitude + (nxt and flat(nxt - p).Magnitude or 0)
        if D.blockedLanes[laneKey(p)] then cost += 5000 end
        if not bc or cost < bc then best, bc = p, cost end
    end
    return best
end
local function waypointTarget(rootPos)
    local stops = pathStops()
    if not stops or #stops == 0 then return nil end
    if not D.wpi then
        local bi, bd = 1, math.huge
        for i, st in ipairs(stops) do
            local d = flat(bestLane(st, rootPos, stops[i + 1]) - rootPos).Magnitude
            if d < bd then bi, bd = i, d end
        end
        D.wpi = bi
    end
    for _ = 1, 3 do
        local st, nx = stops[D.wpi], stops[D.wpi + 1]
        if not st then return nil, true end
        local p = bestLane(st, rootPos, nx)
        local d = flat(p - rootPos).Magnitude
        if nx and (d < 45 or flat(centroid(nx.pts) - rootPos).Magnitude < flat(centroid(nx.pts) - p).Magnitude) then
            D.wpi += 1
        else
            return p, false, d
        end
    end
    local st = stops[D.wpi]
    if not st then return nil, true end
    local p = bestLane(st, rootPos, stops[D.wpi + 1])
    return p, false, flat(p - rootPos).Magnitude
end

local LINES = {}
local function linesPath(m) return "ConeHub/ABR_lines_" .. tostring(m) .. ".json" end
local function loadLines(m)
    if LINES[m] then return LINES[m] end
    local data = { lines = {} }
    pcall(function()
        if isfile and isfile(linesPath(m)) then data = HttpService:JSONDecode(readfile(linesPath(m))) end
    end)
    data.lines = data.lines or {}
    LINES[m] = data
    return data
end
local function saveLines(m)
    pcall(function()
        if not isfolder("ConeHub") then makefolder("ConeHub") end
        writefile(linesPath(m), HttpService:JSONEncode(LINES[m]))
    end)
end
local REC = env.__ABR_REC
if not REC and getgc then
    pcall(function()
        for _, o in ipairs(getgc(true)) do
            if type(o) == "table" and rawget(o, "traces") and rawget(o, "saved") and rawget(o, "sawPreStart") ~= nil then REC = o break end
        end
    end)
end
REC = REC or { traces = {}, saved = {}, startedAt = nil, fullRace = false, sawPreStart = false }
env.__ABR_REC = REC
local function v3(t) return Vector3.new(t[1], t[2], t[3]) end
local function recordTick()
    local m = mapName()
    if workspace:GetAttribute("RaceStarted") ~= true then
        REC.traces, REC.saved, REC.startedAt, REC.fullRace = {}, {}, nil, false
        REC.sawPreStart = true
        return
    end
    if not REC.startedAt then
        REC.startedAt = os.clock()
        REC.fullRace = REC.sawPreStart
    end
    local horseOf = {}
    for _, hm in ipairs(CollectionService:GetTagged("Horse")) do
        local o = hm:FindFirstChild("Owner")
        if o and o.Value then horseOf[o.Value] = hm end
    end
    for _, p in ipairs(Players:GetPlayers()) do
        local c = p.Character
        local r = c and c:FindFirstChild("HumanoidRootPart")
        if r and p:GetAttribute("RaceDead") ~= true and not p:GetAttribute("FinishPosition") and not (m == "Stage2" and ((p.Character and p.Character:GetAttribute("CurrentCheckpoint")) or 0) >= 6) then
            local tr = REC.traces[p.UserId]
            if not tr then tr = { pts = {}, bad = false } REC.traces[p.UserId] = tr end
            local pos = r.Position
            local last = tr.pts[#tr.pts]
            local d = last and (v3(last) - pos).Magnitude or math.huge
            if d > 150 and last then tr.bad = true end
            if d > 6 then
                local fl = 0
                local hm = horseOf[p]
                if hm and hm:GetAttribute("Boosted") then fl += 1 end
                local air = workspace:Raycast(pos, Vector3.new(0, -9, 0), rayParams) == nil
                if air then fl += 2 end
                tr.pts[#tr.pts + 1] = { math.floor(pos.X * 10) / 10, math.floor(pos.Y * 10) / 10, math.floor(pos.Z * 10) / 10, fl }
            end
        end
        local fp = p:GetAttribute("FinishPosition")
        if not fp and m == "Stage2" and ((p.Character and p.Character:GetAttribute("CurrentCheckpoint")) or 0) >= 6 then
            REC.townOrder = (REC.townOrder or 0) + (REC.saved[p.UserId] and 0 or 1)
            fp = REC.townOrder
        end
        local tr = REC.traces[p.UserId]
        if fp and tr and not REC.saved[p.UserId] then
            REC.saved[p.UserId] = true
            local ft = p:GetAttribute("FinishTime") or (os.clock() - REC.startedAt)
            if REC.fullRace and not tr.bad and #tr.pts > 40 then
                local data = loadLines(m)
                table.insert(data.lines, { t = ft, place = fp, who = p.Name, at = os.time(), pts = tr.pts })
                table.sort(data.lines, function(a, b) return a.t < b.t end)
                while #data.lines > 5 do table.remove(data.lines) end
                saveLines(m)
                stats.linesSaved = (stats.linesSaved or 0) + 1
                slog(string.format("saved line: %s #%s %.1fs (%d pts)", p.Name, tostring(fp), ft, #tr.pts))
            end
        end
    end
end
local function liveLeaderLine(pos)
    if D.liveLeader and os.clock() < (D.liveLeaderUntil or 0) then
        local p = D.liveLeader
        local tr = p.Parent and REC.traces[p.UserId]
        if tr and not tr.bad and p:GetAttribute("RaceDead") ~= true then return { p = p, tr = tr }, nil end
    end
    local best, bestPl
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= plr and p:GetAttribute("RaceDead") ~= true then
            local tr = REC.traces[p.UserId]
            local pl = p:GetAttribute("Placement")
            if tr and not tr.bad and #tr.pts > 25 and pl and (not bestPl or pl < bestPl) then best, bestPl = { p = p, tr = tr }, pl end
        end
    end
    if not best then return nil end
    D.liveLeader, D.liveLeaderUntil = best.p, os.clock() + 20
    local last = v3(best.tr.pts[#best.tr.pts])
    return best, last
end
local function ghostTarget(pos)
    local data = loadLines(mapName())
    local L = data.lines[1]
    local key
    if L and #L.pts >= 20 then
        key = L
    else
        local lead = liveLeaderLine(pos)
        if not lead then return nil end
        L = lead.tr
        key = tostring(lead.p.UserId) .. ":" .. #L.pts
        D.ghostLive = lead.p.Name
    end
    if D.ghostFor ~= key then
        local keepGi = D.ghostFor ~= nil and type(D.ghostFor) == "string" and type(key) == "string" and D.ghostFor:match("^%d+") == key:match("^%d+")
        D.ghostFor, D.ghostPts = key, {}
        if not keepGi then D.gi = nil end
        D.ghostFlags = {}
        for i, p in ipairs(L.pts) do D.ghostPts[i] = v3(p) D.ghostFlags[i] = p[4] or 0 end
        D.ghostCum = { 0 }
        for i = 2, #D.ghostPts do D.ghostCum[i] = D.ghostCum[i - 1] + flat(D.ghostPts[i] - D.ghostPts[i - 1]).Magnitude end
    end
    local pts = D.ghostPts
    local floorI = math.max(1, (D.giMax or 1) - 6)
    local from = D.gi and math.max(floorI, D.gi - 3) or floorI
    local to = D.gi and math.min(#pts, D.gi + 50) or #pts
    local bi, bd = nil, math.huge
    for i = from, to do local d = (pts[i] - pos).Magnitude if d < bd then bi, bd = i, d end end
    if (not bi or bd > 140) and D.gi then
        D.gi = nil
        for i = floorI, #pts do local d = (pts[i] - pos).Magnitude if d < bd then bi, bd = i, d end end
    end
    if not bi or bd > 450 then D.gi = nil return nil end
    local cum = D.ghostCum or {}
    if D.mergeOff == nil and not D.gi and bi <= 8 and REC.startedAt and os.clock() - REC.startedAt < 20 then
        local dir = flat(pts[math.min(#pts, bi + 3)] - pts[bi])
        local rel = flat(pos - pts[bi])
        if dir.Magnitude > 1 then
            dir = dir.Unit
            local lat = rel - dir * rel:Dot(dir)
            if lat.Magnitude > 4 and lat.Magnitude < 90 then
                D.mergeOff, D.mergeFrom = lat, cum[bi] or 0
                slog(string.format("start merge: %.0f studs beside the best line, blending in", lat.Magnitude))
            else
                D.mergeOff = false
            end
        end
    end
    local shift = Vector3.zero
    if D.mergeOff then
        local prog = (cum[bi] or 0) - (D.mergeFrom or 0)
        local fade = math.clamp(1 - prog / 350, 0, 1)
        if fade <= 0 then D.mergeOff = false else shift = D.mergeOff * fade end
        bd = (pts[bi] + shift - pos).Magnitude
    end
    D.gi = bi
    D.giMax = math.max(D.giMax or 1, bi)
    local function bendAt(i)
        local a, b, c = pts[math.max(1, i - 1)], pts[i], pts[math.min(#pts, i + 2)]
        local d1, d2 = flat(b - a), flat(c - b)
        if d1.Magnitude < 0.5 or d2.Magnitude < 0.5 then return 0 end
        return math.deg(math.acos(math.clamp(d1.Unit:Dot(d2.Unit), -1, 1)))
    end
    local maxBend = 0
    do local acc2, k = 0, bi while k < #pts and acc2 < 45 do maxBend = math.max(maxBend, bendAt(k)) acc2 += (pts[k + 1] - pts[k]).Magnitude k += 1 end end
    local look = (maxBend > 25 and 14) or (maxBend > 12 and 22) or 34
    if bd > 8 then look = math.min(look, 12) end
    local acc, j = 0, bi
    while j < #pts and acc < look do acc += (pts[j + 1] - pts[j]).Magnitude j += 1 end
    if acc < look and #pts >= 3 then
        local endDir = flat(pts[#pts] - pts[math.max(1, #pts - 3)])
        if endDir.Magnitude > 1 then
            endDir = endDir.Unit
            local ahead = flat(pos - pts[#pts]):Dot(endDir)
            local base = pts[#pts] + endDir * math.max(0, ahead)
            D.lineBend = 0
            D.lineLeft = 0
            return Vector3.new(base.X, pos.Y, base.Z) + endDir * 80, bd, 0
        end
    end
    D.lineBend = maxBend
    D.lineLeft = (type(key) == "table") and cum[#pts] and cum[bi] and (cum[#pts] - cum[bi]) or nil
    if D.mergeOff then
        local prog = (cum[j] or 0) - (D.mergeFrom or 0)
        return pts[j] + D.mergeOff * math.clamp(1 - prog / 350, 0, 1), bd, (#pts - bi)
    end
    return pts[j], bd, (#pts - bi)
end
local function lineStraightAhead(dist)
    local pts, i = D.ghostPts, D.gi
    if not (pts and i) then return 999 end
    local base = flat(pts[math.min(#pts, i + 1)] - pts[i])
    if base.Magnitude < 0.5 then return 999 end
    base = base.Unit
    local acc, worst, k = 0, 0, i
    while k < #pts - 1 and acc < dist do
        local d = flat(pts[k + 1] - pts[k])
        if d.Magnitude > 0.5 then worst = math.max(worst, math.deg(math.acos(math.clamp(base:Dot(d.Unit), -1, 1)))) end
        acc += (pts[k + 1] - pts[k]).Magnitude k += 1
    end
    return worst
end

local function steeringTarget(rootPos)
    local gp, off = ghostTarget(rootPos)
    D.usingGhost = gp ~= nil
    D.ghostOff = off or 0
    if gp then
        return gp, false, { n = D.gi or 0 }, flat(gp - rootPos).Magnitude
    end
    local wp, wpDone, wpDist = waypointTarget(rootPos)
    if wp then
        local fake = { n = (D.wpi or 0) }
        local now = os.clock()
        if now > D.nextOffsetChange then
            D.nextOffsetChange = now + rand(1.5, 4)
            local amp = 1 + 5 * H()
            D.lineOffsetGoal = rand(-amp, amp)
        end
        D.lineOffset += (D.lineOffsetGoal - D.lineOffset) * 0.05
        local fwd = flat(wp - rootPos)
        if fwd.Magnitude > 1 then
            wp += Vector3.new(-fwd.Unit.Z, 0, fwd.Unit.X) * D.lineOffset * math.clamp(wpDist / 60, 0, 1)
        end
        if S.followRiders then
            local fwdU = flat(wp - rootPos)
            if fwdU.Magnitude > 1 then
                fwdU = fwdU.Unit
                local bestP, bestScore
                for _, p in ipairs(Players:GetPlayers()) do
                    if p ~= plr and p.Character and p.Character:FindFirstChild("HumanoidRootPart") and p:GetAttribute("RaceDead") ~= true then
                        local rp = p.Character.HumanoidRootPart.Position
                        local rel = flat(rp - rootPos)
                        local ahead = rel:Dot(fwdU)
                        local lateral = (rel - fwdU * ahead).Magnitude
                        if ahead > 15 and ahead < 140 and lateral < 10 and math.abs(rp.Y - rootPos.Y) < 15 then
                            local score = ahead + lateral * 2
                            if not bestScore or score < bestScore then bestP, bestScore = rp, score end
                        end
                    end
                end
                if bestP then
                    D.following = true
                    wp = wp:Lerp(bestP, 0.3)
                else
                    D.following = false
                end
            end
        end
        return wp, false, fake, wpDist
    end
    local list = checkpointList()
    if #list == 0 then return nil end
    local cur = currentCheckpoint()
    local nextCp
    for _, e in ipairs(list) do if e.n > cur then nextCp = e break end end
    if not nextCp then return nil, true end
    local tgt = cpTarget(nextCp.part)
    local after
    for _, e in ipairs(list) do if e.n > nextCp.n then after = e break end end
    local dist = flat(tgt - rootPos).Magnitude
    if after and dist < 70 then
        local t = math.clamp(1 - dist / 70, 0, 0.6)
        tgt = tgt:Lerp(cpTarget(after.part), t)
    end
    local now = os.clock()
    if now > D.nextOffsetChange then
        D.nextOffsetChange = now + rand(1.5, 4)
        local amp = 1 + 6 * H()
        D.lineOffsetGoal = rand(-amp, amp)
    end
    D.lineOffset += (D.lineOffsetGoal - D.lineOffset) * 0.05
    local fwd = flat(tgt - rootPos)
    if fwd.Magnitude > 1 then
        local right = Vector3.new(-fwd.Unit.Z, 0, fwd.Unit.X)
        tgt += right * D.lineOffset * math.clamp(dist / 60, 0, 1)
    end
    return tgt, false, nextCp, dist
end

local function signedAngle(fromDir, toDir)
    local a = flat(fromDir).Unit
    local b = flat(toDir).Unit
    local ang = math.deg(math.acos(math.clamp(a:Dot(b), -1, 1)))
    local cross = a.X * b.Z - a.Z * b.X
    return (cross > 0) and ang or -ang
end

local function hazardSteer(rootPos, look)
    if not S.avoidHazards then return 0 end
    local bias = 0
    for _, r in ipairs(CollectionService:GetTagged("MapEvent_FallingRock")) do
        if r:IsA("BasePart") then
            local rel = flat(r.Position - rootPos)
            local ahead = rel:Dot(flat(look).Unit)
            if ahead > 0 and ahead < 70 and rel.Magnitude < 75 then
                local side = flat(look).Unit:Cross(Vector3.yAxis):Dot(rel)
                bias += (side > 0) and -1 or 1
            end
        end
    end
    for _, tag in ipairs({ "Pinbomb", "MapEvent_Mine", "MapEvent_Eagle", "MapEvent_DynamiteNPC" }) do
        for _, t in ipairs(CollectionService:GetTagged(tag)) do
            local tp = (t:IsA("BasePart") and t.Position) or (t:IsA("Model") and t:GetPivot().Position) or nil
            if tp and not t:GetAttribute("Defused") then
                local rel = flat(tp - rootPos)
                local fwd = flat(look).Unit
                local ahead = rel:Dot(fwd)
                local lateral = (rel - fwd * ahead).Magnitude
                if ahead > 0 and ahead < 35 and lateral < 7 then
                    local side = fwd:Cross(Vector3.yAxis):Dot(rel)
                    bias += (side > 0) and -1.5 or 1.5
                end
            end
        end
    end
    for _, t in ipairs(CollectionService:GetTagged("MapEvent_Tornado")) do
        local tp = (t:IsA("BasePart") and t.Position) or (t:IsA("Model") and t:GetPivot().Position) or nil
        if tp then
            local rel = flat(tp - rootPos)
            local fwd = flat(look).Unit
            local ahead = rel:Dot(fwd)
            if rel.Magnitude < 140 and ahead > -20 then
                local side = fwd:Cross(Vector3.yAxis):Dot(rel)
                local w = (rel.Magnitude < 60) and 4 or 2.5
                bias += (side > 0) and -w or w
                D.tornadoNear = os.clock()
            end
        end
    end
    local origin = rootPos + Vector3.new(0, 2.5, 0)
    local f = flat(look).Unit
    local r = Vector3.new(-f.Z, 0, f.X)
    local L = wallAhead(origin, (f - r * 0.45), 28)
    local R = wallAhead(origin, (f + r * 0.45), 28)
    if L and not R then bias += 1 elseif R and not L then bias -= 1 end
    return bias
end

local PathfindingService = game:GetService("PathfindingService")
local NAV = { pts = nil, forTarget = nil, at = 0, busy = false, fails = 0 }
local function planPath(fromPos, toPos)
    if NAV.busy then return end
    NAV.busy = true
    task.spawn(function()
        local ok = pcall(function()
            local path = PathfindingService:CreatePath({ AgentRadius = 2.5, AgentHeight = 7, AgentCanJump = true, AgentCanClimb = false, WaypointSpacing = 14 })
            path:ComputeAsync(fromPos, toPos)
            if path.Status == Enum.PathStatus.Success then
                local pts = {}
                for _, w in ipairs(path:GetWaypoints()) do pts[#pts + 1] = w.Position end
                NAV.pts, NAV.fails = pts, 0
            else
                NAV.pts = nil
                NAV.fails += 1
            end
        end)
        if not ok then NAV.pts = nil NAV.fails += 1 end
        NAV.forTarget, NAV.at, NAV.busy = toPos, os.clock(), false
    end)
end
local function pathAim(pos, goal)
    local now = os.clock()
    local stale = (now - NAV.at) > 2.5 or not NAV.forTarget or flat(NAV.forTarget - goal).Magnitude > 30
    if stale then planPath(pos, goal) end
    local pts = NAV.pts
    if not pts or #pts < 2 then return goal, false end
    local closest, cd = 1, math.huge
    for i, p in ipairs(pts) do local d = flat(p - pos).Magnitude if d < cd then closest, cd = i, d end end
    if cd > 40 then return goal, false end
    for i = closest, #pts do
        if flat(pts[i] - pos).Magnitude >= 26 then return pts[i], true end
    end
    return pts[#pts], true
end
local WHISKERS = { 0, -12, 12, -24, 24, -36, 36, -50, 50, -65, 65, -80, 80 }
local function clearDist(origin, dir, len)
    local best = len
    local side = Vector3.new(-dir.Z, 0, dir.X)
    if side.Magnitude > 0.01 then side = side.Unit * 2.1 end
    for _, hgt in ipairs({ -1.6, 1.5, 4.5 }) do
        for _, off in ipairs({ 0, 1, -1 }) do
            local o = origin + Vector3.new(0, hgt, 0) + side * off
            local hit = workspace:Raycast(o, dir * len, rayParams)
            if hit and hit.Instance and hit.Instance.CanCollide and hit.Normal.Y < 0.65 and hit.Normal.Y > -0.35 then
                best = math.min(best, hit.Distance)
            end
        end
    end
    return best
end
local FAN = {}
for a = -84, 84, 7 do FAN[#FAN + 1] = a end
local avoidMemo = { at = 0 }
local function avoidHeading(pos, look, desiredErr, speed, aimDist)
    local f = flat(look).Unit
    local now = os.clock()
    if now - avoidMemo.at < 0.06 and math.abs(desiredErr - avoidMemo.desired) < 6 then
        return avoidMemo.err + (desiredErr - avoidMemo.desired), avoidMemo.clear
    end
    local function memo(e, c) avoidMemo.at, avoidMemo.desired, avoidMemo.err, avoidMemo.clear = now, desiredErr, e, c return e, c end
    local len = math.clamp(28 + speed * 1.0, 30, 110)
    local need = math.max(18, math.min(len, (aimDist or len) + 6))
    local function dirAt(ang) return CFrame.Angles(0, -math.rad(ang), 0):VectorToWorldSpace(f) end
    local straightClear = clearDist(pos, dirAt(desiredErr), len)
    if straightClear >= need - 0.5 then
        if now > (D.avoidUntil or 0) then D.avoidSide = nil end
        return memo(desiredErr, straightClear)
    end
    local cls = {}
    for k, a in ipairs(FAN) do
        cls[k] = math.min(need, (a == 0) and straightClear or clearDist(pos, dirAt(desiredErr + a), need))
    end
    local bestK, bestScore = nil, -math.huge
    for k, a in ipairs(FAN) do
        local l, r = cls[k - 1] or cls[k] * 0.7, cls[k + 1] or cls[k] * 0.7
        local width = math.min(l, cls[k], r)
        local score = width * 2 + cls[k] * 0.5 - math.abs(a) * 0.3
        if cls[k] >= need - 0.5 and width >= need * 0.6 then score += 25 end
        if D.avoidSide and a ~= 0 and (a > 0 and 1 or -1) ~= D.avoidSide and now < (D.avoidUntil or 0) then
            score -= 35
        end
        if score > bestScore then bestK, bestScore = k, score end
    end
    local a = FAN[bestK]
    if math.abs(a) >= 7 then
        D.avoidSide, D.avoidUntil = (a > 0) and 1 or -1, now + 0.9
    end
    return memo(desiredErr + a, cls[bestK])
end

local function gapAhead(pos, look, speed)
    local f = flat(look).Unit
    local g0 = workspace:Raycast(pos + Vector3.new(0, 3, 0), Vector3.new(0, -14, 0), rayParams)
    if not g0 then return false end
    local baseY = g0.Position.Y
    local lead = math.clamp(speed * 0.22, 6, 22)
    local g1 = workspace:Raycast(pos + f * lead + Vector3.new(0, 6, 0), Vector3.new(0, -30, 0), rayParams)
    if g1 and g1.Position.Y > baseY - 6 then return false end
    for _, d in ipairs({ lead + 10, lead + 20, lead + 32, lead + 45 }) do
        local g2 = workspace:Raycast(pos + f * d + Vector3.new(0, 8, 0), Vector3.new(0, -24, 0), rayParams)
        if g2 and g2.Position.Y > baseY - 5 then return true, d end
    end
    return false
end

local function markBlockedAndReroute(pos, reason)
    if D.usingGhost and D.ghostPts and D.gi and D.gi >= #D.ghostPts - 2 then return end
    do
        local nowR = os.clock()
        local prog = D.gi or D.wpi or 0
        if not D.rrWin or nowR - D.rrWin.t0 > 15 or prog > D.rrWin.prog + 2 then
            D.rrWin = { t0 = nowR, n = 0, prog = prog }
        end
        D.rrWin.n += 1
        if D.rrWin.n >= 4 and nowR > (D.footEscapeUntil or 0) + 3 then
            local names = {}
            pcall(function()
                for _, p in ipairs(workspace:GetPartBoundsInRadius(pos, 14)) do
                    if p.CanCollide and p ~= workspace.Terrain and #names < 4 then
                        local m = p:FindFirstAncestorOfClass("Model")
                        names[#names + 1] = (m and m.Name or p.Name)
                    end
                end
            end)
            slog(string.format("%d reroutes w/o progress (%s) near [%s] -> hop off and walk past", D.rrWin.n, reason, table.concat(names, ",")))
            D.rrWin = nil
            D.footEscapeUntil = nowR + 5
            task.spawn(tap, Enum.KeyCode.N)
            return
        end
    end
    if D.usingGhost and D.ghostPts and D.gi then
        local acc, j = 0, D.gi
        while j < #D.ghostPts and acc < 120 do acc += (D.ghostPts[j + 1] - D.ghostPts[j]).Magnitude j += 1 end
        D.detourTo, D.detourUntil = D.ghostPts[j], os.clock() + 8
        NAV.at = 0
        slog(string.format("reroute (%s): detour to line point %d", reason, j))
    elseif D.stops and D.wpi and D.stops[D.wpi] then
        local st = D.stops[D.wpi]
        local p = bestLane(st, pos, D.stops[D.wpi + 1])
        D.blockedLanes[laneKey(p)] = true
        NAV.at = 0
        slog(string.format("reroute (%s): lane at stop %d blocked, %d lanes", reason, D.wpi, #st.pts))
    end
end

local function driveTick(dt)
    local c, root = char(), hrp()
    if not (c and root) then return end
    local h = myHorse()
    refreshRayFilter(h)

    if c:GetAttribute("LassoBound") then
        status = "Lassoed! escaping"
        if S.lassoEscape and os.clock() - D.lastLassoPress > rand(0.11, 0.19) then
            D.lastLassoPress = os.clock()
            task.spawn(tap, Enum.KeyCode.E, rand(0.03, 0.06))
        end
        return
    end

    if gameDrivesMe() then
        status = "Game is moving me (start/cutscene)"
        resetDriver()
        return
    end

    if not isMounted(h) then
        if D.wasMounted then
            D.wasMounted = false
            stats.falls = (stats.falls or 0) + 1
            local nearest, nd = "-", math.huge
            for _, p in ipairs(Players:GetPlayers()) do
                if p ~= plr and p.Character and p.Character:FindFirstChild("HumanoidRootPart") then
                    local d = (p.Character.HumanoidRootPart.Position - root.Position).Magnitude
                    if d < nd then nearest, nd = p.Name, d end
                end
            end
            slog(string.format("FELL at %s wp%s boosted=%s v=%.0f airborne=%s clearAhead=%.0f nearestRider=%s@%.0f rag=%s tired=%s depleted=%s", tostring(root.Position), tostring(D.gi or D.wpi), tostring(D.lastBoosted), D.lastSpeed or 0, tostring(D.lastAir), D.lastClear or -1, nearest, nd, tostring(c:GetAttribute("Ragdolled")), tostring(h and h:GetAttribute("TiredAt")), tostring(h and h:GetAttribute("StaminaDepleted"))))
        end
        key(Enum.KeyCode.LeftShift, false) key(Enum.KeyCode.A, false) key(Enum.KeyCode.D, false)
        D.sprinting = false
        if D.releaseMouse then pcall(D.releaseMouse) end
        key(Enum.KeyCode.F, false)
        if S.autoRecall and os.clock() - D.lastRecall > rand(1.5, 1.9) and (currentCheckpoint() < 6 or os.clock() < (D.townThreat or 0) or (hum() and hum().Health < hum().MaxHealth * 0.5)) then
            D.lastRecall = os.clock()
            status = "Off the horse -> calling it (T)"
            task.spawn(function()
                task.wait(rand(0.25, 0.55))
                tap(Enum.KeyCode.T)
                stats.recalls += 1
            end)
        end
        do
            local hr = h and horseRoot(h)
            if hr and (hr.Position - root.Position).Magnitude < 25 and os.clock() > (D.footEscapeUntil or 0) then
                local hm2 = hum()
                if hm2 then hm2:MoveTo(hr.Position) end
                local seat = h:FindFirstChild("Seat", true)
                local pp = seat and seat:FindFirstChildOfClass("ProximityPrompt")
                if pp and pp.Enabled and (hr.Position - root.Position).Magnitude <= pp.MaxActivationDistance + 2
                    and os.clock() - (D.lastHopOn or 0) > 0.8 then
                    D.lastHopOn = os.clock()
                    task.spawn(function() task.wait(rand(0.15, 0.35)) pcall(fireproximityprompt, pp) end)
                    status = "Getting back on the horse"
                end
                return
            end
        end
        local tgt = steeringTarget(root.Position)
        local hm = hum()
        local now = os.clock()
        D.offSince = D.offSince or now
        if tgt and hm then
            local aim = pathAim(root.Position, tgt)
            hm:MoveTo(aim)
            local v = root.AssemblyLinearVelocity.Magnitude
            if v < 2 and now - (D.lastFootHop or 0) > 1.5 then D.lastFootHop = now hm.Jump = true end
        end
        if now - D.offSince > 10 and now - (D.lastOffLog or 0) > 10 then
            D.lastOffLog = now
            local hh = h and horseRoot(h)
            slog(string.format("OFF HORSE %.0fs at %s state=%s ragdoll=%s/%s horse=%s d=%.0f horseDisabled=%s", now - D.offSince, tostring(root.Position), tostring(hm and hm:GetState()), tostring(c:GetAttribute("Ragdolled")), tostring(h and h:GetAttribute("Ragdolled")), tostring(h ~= nil), hh and (hh.Position - root.Position).Magnitude or -1, tostring(h and h:GetAttribute("Disabled"))))
        end
        return
    end

    if os.clock() < (D.maneuverUntil or 0) then return end
    D.wasMounted = true
    D.offSince = nil
    local hroot = horseRoot(h) or root
    local pos = hroot.Position
    local look = hroot.CFrame.LookVector
    local tgt, done, nextCp, dist = steeringTarget(pos)
    if done or not tgt then
        status = "Route finished / no checkpoints"
        releaseAll()
        return
    end

    key(Enum.KeyCode.W, true)
    key(Enum.KeyCode.S, false)

    local aim, onPath
    if D.detourTo and os.clock() < (D.detourUntil or 0) then
        if flat(D.detourTo - pos).Magnitude < 30 then D.detourTo = nil end
    end
    if D.detourTo and os.clock() < (D.detourUntil or 0) then aim, onPath = pathAim(pos, D.detourTo)
    elseif D.usingGhost and (D.ghostOff < 45 or clearDist(pos, (flat(tgt - pos).Magnitude > 0.5 and flat(tgt - pos).Unit or flat(look).Unit), math.min(flat(tgt - pos).Magnitude, 80)) >= math.min(flat(tgt - pos).Magnitude, 80) - 1) then aim, onPath = tgt, false else aim, onPath = pathAim(pos, tgt) end
    do
        local fwd = flat(aim - pos)
        if fwd.Magnitude > 1 then
            fwd = fwd.Unit
            for _, t in ipairs(CollectionService:GetTagged("MapEvent_Tornado")) do
                local tp = (t:IsA("BasePart") and t.Position) or (t:IsA("Model") and t:GetPivot().Position) or nil
                if tp then
                    local tr = (t:IsA("BasePart") and math.max(t.Size.X, t.Size.Z) / 2) or 60
                    local clear = tr + 20
                    local rel = flat(tp - pos)
                    local ahead = rel:Dot(fwd)
                    local lateralV = rel - fwd * ahead
                    if ahead > -clear and ahead < clear + 150 and lateralV.Magnitude < clear then
                        local away = lateralV.Magnitude > 0.5 and -lateralV.Unit or Vector3.new(-fwd.Z, 0, fwd.X)
                        aim = tp + away * (clear + 10) + fwd * math.min(clear, 60)
                        aim = Vector3.new(aim.X, pos.Y, aim.Z)
                        onPath = false
                        if os.clock() - (D.lastTornadoLog or 0) > 3 then
                            D.lastTornadoLog = os.clock()
                            slog(string.format("tornado avoid: ahead %.0f lateral %.0f", ahead, lateralV.Magnitude))
                        end
                    end
                end
            end
        end
    end
    do
        if D.cactiFor ~= workspace:FindFirstChild("Map") then
            D.cactiFor, D.cacti = workspace:FindFirstChild("Map"), {}
            for _, m in ipairs(workspace:GetDescendants()) do
                if m:IsA("Model") and m.Name:lower():find("cact") then
                    local okB, cf, size = pcall(function() return m:GetBoundingBox() end)
                    if okB then D.cacti[#D.cacti + 1] = { p = cf.Position, r = math.max(size.X, size.Z) / 2 } end
                end
            end
        end
        local fwd = flat(aim - pos)
        if fwd.Magnitude > 1 then
            fwd = fwd.Unit
            for _, cobj in ipairs(D.cacti) do
                local rel = flat(cobj.p - pos)
                if rel.Magnitude < 45 then
                    local ahead = rel:Dot(fwd)
                    local lateralV = rel - fwd * ahead
                    local need = cobj.r + 3.5
                    if ahead > 0 and ahead < 40 and lateralV.Magnitude < need then
                        local away = lateralV.Magnitude > 0.3 and -lateralV.Unit or Vector3.new(-fwd.Z, 0, fwd.X)
                        aim = Vector3.new(cobj.p.X, pos.Y, cobj.p.Z) + away * (need + 3) + fwd * 6
                        onPath = false
                        break
                    end
                end
            end
        end
    end
    if D.usingGhost and D.ghostPts and D.gi then
        local pts, gi, nowL = D.ghostPts, D.gi, os.clock()
        local function solid(hit)
            return hit and hit.Instance and hit.Instance ~= workspace.Terrain and hit.Instance.CanCollide
                and hit.Normal.Y < 0.65 and hit.Normal.Y > -0.35
        end
        local function sideAt(k)
            local d = flat(pts[math.min(#pts, k + 1)] - pts[k])
            if d.Magnitude < 0.5 then d = flat(pts[k] - pts[math.max(1, k - 1)]) end
            if d.Magnitude < 0.5 then return Vector3.new(1, 0, 0) end
            d = d.Unit
            return Vector3.new(-d.Z, 0, d.X)
        end
        local function segBlocked(k, off)
            local a, b = pts[k], pts[math.min(#pts, k + 1)]
            local sd = sideAt(k)
            local d = b - a
            if d.Magnitude < 0.5 then return false end
            for _, lo in ipairs({ -2.2, 0, 2.2 }) do
                for _, hy in ipairs({ 0.5, 3.5 }) do
                    if solid(workspace:Raycast(a + sd * (off + lo) + Vector3.new(0, hy, 0), d, rayParams)) then return true end
                end
            end
            return false
        end
        if nowL - (D.lbAt or 0) > 0.12 then
            D.lbAt = nowL
            local L = math.clamp(hroot.AssemblyLinearVelocity.Magnitude * 1.6, 40, 130)
            local acc, k, hitK = 0, gi, nil
            while k < #pts and acc < L do
                if segBlocked(k, 0) then hitK = k break end
                acc += (pts[k + 1] - pts[k]).Magnitude
                k += 1
            end
            if hitK and not (D.lineShift and D.lineShift.hitK == hitK) then
                local prefer = D.lineShift and D.lineShift.o or 0
                local opts = { 4, -4, 7, -7, 10, -10, 14, -14, 18, -18 }
                table.sort(opts, function(x, y)
                    local px = (prefer ~= 0 and (x > 0) ~= (prefer > 0)) and 3 or 0
                    local py = (prefer ~= 0 and (y > 0) ~= (prefer > 0)) and 3 or 0
                    return math.abs(x) + px < math.abs(y) + py
                end)
                local chosen
                for _, o in ipairs(opts) do
                    local ok = true
                    for kk = math.max(gi, hitK - 1), math.min(#pts - 1, hitK + 2) do
                        if segBlocked(kk, o) then ok = false break end
                    end
                    if ok then
                        local entry = pts[math.max(gi, hitK - 1)] + sideAt(math.max(gi, hitK - 1)) * o
                        local dv = flat(entry - pos)
                        if dv.Magnitude > 1 and clearDist(pos, dv.Unit, dv.Magnitude) < dv.Magnitude - 1 then ok = false end
                    end
                    if ok then chosen = o break end
                end
                if chosen then
                    D.lineShift = { o = chosen, hitK = hitK, untilK = hitK + 3 }
                    slog(string.format("line blocked ahead at pt %d -> shifting %+d studs", hitK, chosen))
                end
            end
        end
        if D.lineShift then
            if gi > D.lineShift.untilK then
                D.lineShift = nil
            else
                aim = aim + sideAt(gi) * D.lineShift.o
                onPath = false
            end
        end
    end
    local speedNow = hroot.AssemblyLinearVelocity.Magnitude
    D.lastSpeed, D.lastBoosted = speedNow, h:GetAttribute("Boosted")
    D.lastAir = workspace:Raycast(pos, Vector3.new(0, -12, 0), rayParams) == nil
    local rawErr = signedAngle(look, aim - pos)
    local bias = hazardSteer(pos, look)
    local err, clearAhead = avoidHeading(pos, look, rawErr + bias * 20, speedNow, flat(aim - pos).Magnitude)
    D.lastClear = clearAhead
    do
        local yaw = math.deg(math.atan2(-look.X, -look.Z))
        if D.prevYaw then
            local dy = (yaw - D.prevYaw + 540) % 360 - 180
            D.turnAcc = (D.turnAcc or 0) + math.abs(dy)
        end
        D.prevYaw = yaw
        local dNow = (D.usingGhost and D.gi) and -D.gi * 10 or flat(tgt - pos).Magnitude
        D.circleStart = D.circleStart or os.clock()
        D.circleDist0 = D.circleDist0 or dNow
        if os.clock() - D.circleStart > 5 then
            if (D.turnAcc or 0) > 300 and dNow > D.circleDist0 - 25 then
                stats.circles = (stats.circles or 0) + 1
                markBlockedAndReroute(pos, "circling")
            end
            D.circleStart, D.circleDist0, D.turnAcc = os.clock(), dNow, 0
        end
    end

    if clearAhead and speedNow > 14 and clearAhead < math.clamp(speedNow * 0.35, 7, 20) and os.clock() - (D.lastJump or 0) > 1.2 then
        local dirJ = flat(look).Unit
        local over = workspace:Raycast(pos + Vector3.new(0, 8, 0), dirJ * (clearAhead + 8), rayParams)
        if not over then
            D.lastJump = os.clock()
            task.spawn(tap, Enum.KeyCode.Space, rand(0.06, 0.1))
            slog(string.format("hop low obstacle %.0f studs ahead", clearAhead))
        end
    end
    if speedNow < 12 and clearAhead and clearAhead < 10 then
        D.blockedSince = D.blockedSince or os.clock()
        if os.clock() - D.blockedSince > 1.0 then D.blockedSince = nil markBlockedAndReroute(pos, "walled") end
    else D.blockedSince = nil end
    D.onPath = onPath
    local dead = D.usingGhost and (1.5 + 2.5 * H()) or (3 + 6 * H())
    local nowE = os.clock()
    local evading = nowE < (D.evadeUntil or 0)
    if evading then
        local zig = (math.floor(nowE / 0.42) % 2 == 0) and 28 or -28
        err += zig
        status = "Under attack -> evasive riding"
    end
    local yawRight = -math.deg(hroot.AssemblyAngularVelocity.Y)
    local errP = err - yawRight * (0.12 + 0.06 * (1 - H()))
    local want = nil
    if errP > dead then want = Enum.KeyCode.D elseif errP < -dead then want = Enum.KeyCode.A end
    if want and math.abs(errP) < dead + 14 then
        local duty = math.clamp((math.abs(errP) - dead) / 14, 0.3, 1)
        if (os.clock() % 0.16) / 0.16 > duty then want = nil end
    end
    local now = os.clock()
    if now < D.distractedUntil and math.abs(err) < 25 then want = nil end
    if math.abs(err) < 8 and math.random() < 0.002 * H() then D.distractedUntil = now + rand(0.2, 0.6) end
    if want ~= D.steerKey and now - D.lastSteerChange > ((H() < 0.3) and 0.02 or reactDelay(0.45 * H() + 0.05)) then
        D.lastSteerChange = now
        if D.steerKey then key(D.steerKey, false) end
        if want then key(want, true) end
        D.steerKey = want
    end

    if S.infStamina or (S.extraSpeed or 0) > 0 or S.boostRefill then
        pcall(function()
            local hc = Knit.GetController("HorseController")
            local ho = hc and hc:GetCurrentHorse()
            if S.infStamina and ho and type(ho._Stamina) == "number" and ho._Stamina < 85 then ho._Stamina = 100 end
            if (S.extraSpeed or 0) > 0 and (h:GetAttribute("SpeedBoost") or 0) < S.extraSpeed then h:SetAttribute("SpeedBoost", S.extraSpeed) end
            if S.boostRefill and h:GetAttribute("DidBoost") and not h:GetAttribute("Boosted") then
                D.boostDoneAt = D.boostDoneAt or now
                if now - D.boostDoneAt > 4 then
                    h:SetAttribute("BoostRefill", 100) h:SetAttribute("DidBoost", false) D.boostDoneAt = nil
                end
            else
                D.boostDoneAt = nil
            end
        end)
    end
    if S.staminaAssist then
        local placement = plr:GetAttribute("Placement") or 99
        if placement > 2 or now < (D.evadeUntil or 0) then
            pcall(function()
                local hc = Knit.GetController("HorseController")
                local ho = hc and hc:GetCurrentHorse()
                if ho and type(ho._Stamina) == "number" and ho._Stamina < 35 then
                    ho._Stamina = math.min(100, ho._Stamina + rand(30, 40))
                    stats.staminaAssists = (stats.staminaAssists or 0) + 1
                end
            end)
        end
    end
    local stamina = h:GetAttribute("Stamina") or 100
    if S.useSprint then
        if D.sprinting and stamina <= S.sprintStop + rand(-3, 3) * H() then
            D.sprinting = false
            D.sprintResumeAt = S.sprintResume + rand(-8, 8) * H()
        elseif not D.sprinting and stamina >= D.sprintResumeAt and now - D.lastSprintToggle > 1.1 then
            D.sprinting = true
            D.lastSprintToggle = now
        end
        local tight = clearAhead and clearAhead < math.max(18, speedNow * 0.35)
        if tight then D.tightUntil = now + 0.6 end
        local sprintNow = (D.sprinting or now < (D.evadeUntil or 0)) and math.abs(err) < 70 and now >= (D.tightUntil or 0)
        local isSpr = h:GetAttribute("Sprinting") == true
        if sprintNow then
            if not isSpr and stamina > 8 and not h:GetAttribute("StaminaDepleted") and now - (D.lastShiftPress or 0) > rand(1.15, 1.5) then
                D.lastShiftPress = now
                task.spawn(function() key(Enum.KeyCode.LeftShift, false) task.wait(rand(0.04, 0.09)) key(Enum.KeyCode.LeftShift, true) end)
            elseif not held[Enum.KeyCode.LeftShift] then
                key(Enum.KeyCode.LeftShift, true) D.lastShiftPress = now
            end
        else
            key(Enum.KeyCode.LeftShift, false)
        end
    else
        key(Enum.KeyCode.LeftShift, false)
    end

    if D.usingGhost and D.gi and D.ghostFlags and (D.ghostOff or 99) < 15 then
        local fl0 = D.ghostFlags[D.gi] or 0
        local fl1 = D.ghostFlags[math.min(#D.ghostFlags, D.gi + 1)] or 0
        local prevB = (D.ghostFlags[math.max(1, D.gi - 1)] or 0) % 2 == 1
        local reserve = not S.boostRefill and D.lineLeft and D.lineLeft < 1600 and D.lineLeft > 450
        if S.useBoost and not reserve and fl0 % 2 == 1 and not prevB and not h:GetAttribute("Boosted") and not h:GetAttribute("DidBoost")
            and now - D.lastBoostTry > 2 and clearDist(pos, flat(look).Unit, 90) >= 89 then
            D.lastBoostTry = now
            task.spawn(function() task.wait(reactDelay(0.6)) tap(Enum.KeyCode.Z) stats.boosts += 1 end)
            slog("boost at winner's boost point i=" .. D.gi)
        end
        if (fl1 >= 2) and (fl0 < 2) and now - (D.lastJump or 0) > 1.2 then
            D.lastJump = now
            task.spawn(tap, Enum.KeyCode.Space, rand(0.06, 0.1))
            slog("jump at winner's jump point i=" .. D.gi)
        end
    end
    if S.useBoost and not h:GetAttribute("Boosted") and not h:GetAttribute("DidBoost") and now - D.lastBoostTry > 2 then
        local straight = math.abs(err) < 5
        local clear = clearDist(pos, flat(look).Unit, 150) >= 149 and not gapAhead(pos, look, 120)
        local far = (D.usingGhost and lineStraightAhead(180) < 10) or (not D.usingGhost and dist and dist > 120)
        far = far and currentCheckpoint() >= 2 and REC.startedAt ~= nil and os.clock() - REC.startedAt > 30
        if not S.boostRefill and D.usingGhost and D.lineLeft and D.lineLeft < 1600 and D.lineLeft > 450 then far = false end
        if D.usingGhost and D.lineLeft and D.lineLeft <= 450 then far = lineStraightAhead(120) < 14 end
        straight = straight and speedNow > 45
        if straight and clear and far then
            D.lastBoostTry = now
            task.spawn(function()
                task.wait(reactDelay(1.2))
                if h.Parent and not h:GetAttribute("Boosted") then
                    tap(Enum.KeyCode.Z)
                    stats.boosts += 1
                end
            end)
        end
    end

    local gap = gapAhead(pos, look, speedNow)
    if gap and speedNow > 20 and now - (D.lastJump or 0) > 1.2 then
        D.lastJump = now
        task.spawn(tap, Enum.KeyCode.Space, rand(0.06, 0.1))
        slog(string.format("gap jump at %s v=%.0f", tostring(Vector3.new(math.floor(pos.X), math.floor(pos.Y), math.floor(pos.Z))), speedNow))
    end
    local spd = hroot.AssemblyLinearVelocity.Magnitude
    stats.rideSec += dt
    if spd < 40 then stats.slowSec += dt end
    D.crumbs = D.crumbs or {}
    if now - (D.crumbAt or 0) > 0.5 then
        D.crumbAt = now
        local lastC = D.crumbs[#D.crumbs]
        if not lastC or (lastC - pos).Magnitude > 4 then
            table.insert(D.crumbs, pos)
            if #D.crumbs > 40 then table.remove(D.crumbs, 1) end
        end
    end
    D.lastPos = D.lastPos or pos
    local moved = (pos - D.lastPos).Magnitude
    D.lastPos = pos
    if moved / math.max(dt, 1e-3) < 4 then
        D.stuckSince = D.stuckSince or now
        if now - D.stuckSince > 2.5 then
            D.stuckSince = now + 1.5
            status = "Stuck -> backing up"
            if D.stuckSpot and (D.stuckSpot - pos).Magnitude < 12 and now - (D.stuckSpotAt or 0) < 25 then
                D.stuckCount = (D.stuckCount or 1) + 1
            else
                D.stuckSpot, D.stuckCount = pos, 1
            end
            D.stuckSpotAt = now
            if D.stuckCount >= 3 then
                slog(string.format("stuck x%d at same spot -> hop off and walk out", D.stuckCount))
                D.footEscapeUntil = now + 5
                D.stuckCount = 0
                task.spawn(tap, Enum.KeyCode.N)
                stats.stuck += 1
                return
            elseif D.stuckCount == 2 and D.crumbs and #D.crumbs > 3 and (not D.usingGhost or (D.ghostOff or 0) > 20) then
                local back
                for i = #D.crumbs, 1, -1 do
                    if flat(D.crumbs[i] - pos).Magnitude > 50 then back = D.crumbs[i] break end
                end
                if back then
                    D.detourTo, D.detourUntil = back, now + 5
                    NAV.at = 0
                    slog("stuck x2 -> retracing our own path back out")
                else
                    markBlockedAndReroute(pos, "stuck")
                end
            else
                markBlockedAndReroute(pos, "stuck")
            end
            stats.stuck += 1
            slog(string.format("stuck at %s wp%s err=%.0f", tostring(Vector3.new(math.floor(pos.X), math.floor(pos.Y), math.floor(pos.Z))), tostring(D.wpi), err))
            D.maneuverUntil = now + 1.6
            if D.steerKey then key(D.steerKey, false) D.steerKey = nil end
            key(Enum.KeyCode.A, false) key(Enum.KeyCode.D, false) key(Enum.KeyCode.LeftShift, false)
            task.spawn(function()
                key(Enum.KeyCode.W, false)
                local fL = clearDist(pos, CFrame.Angles(0, math.rad(60), 0):VectorToWorldSpace(flat(look).Unit), 40)
                local fR = clearDist(pos, CFrame.Angles(0, -math.rad(60), 0):VectorToWorldSpace(flat(look).Unit), 40)
                local side = (fL > fR) and Enum.KeyCode.A or Enum.KeyCode.D
                NAV.at = 0
                key(Enum.KeyCode.S, true) key(side, true)
                task.wait(rand(0.9, 1.3))
                key(Enum.KeyCode.S, false) key(side, false)
                local lowBlock = clearDist(pos, flat(look).Unit, 8) < 7 and (function() local hit = workspace:Raycast(pos + Vector3.new(0, 7, 0), flat(look).Unit * 8, rayParams) return hit == nil end)()
                if lowBlock and now - (D.lastJump or 0) > 3 then D.lastJump = now tap(Enum.KeyCode.Space) end
            end)
            return
        end
    else
        D.stuckSince = nil
    end

    local placement = plr:GetAttribute("Placement")
    status = string.format("Racing  cp %d -> %s  |  %.0f studs  |  place %s  |  stamina %d%s",
        currentCheckpoint(), nextCp and ("wp" .. tostring(nextCp.n)) or "?", dist or 0, tostring(placement or "?"),
        math.floor(stamina), (D.sprinting and " (sprint)" or "") .. (D.following and " (drafting)" or "") .. (D.onPath and " [path]" or "") .. (D.usingGhost and ((type(D.ghostFor) == "string") and (" [following " .. tostring(D.ghostLive) .. "]") or " [learned line]") or ""))
end

local CB = { aimAt = nil, cd = {}, standAt = 0, lastHp = nil, hurtAt = 0, m1Down = false, target = nil }
local function camAimStep()
    local tgt = CB.aimAt
    local root = hrp()
    if not (tgt and root) then return end
    local cam = workspace.CurrentCamera
    local noise = Vector3.new(rand(-1, 1), rand(-0.6, 0.8), rand(-1, 1)) * (0.4 + 1.2 * H())
    local look = (tgt + noise) - root.Position
    if look.Magnitude < 0.5 then return end
    local from = root.Position - look.Unit * 10 + Vector3.new(0, 4, 0)
    cam.CFrame = cam.CFrame:Lerp(CFrame.lookAt(from, tgt + noise), 0.35)
end
pcall(function() RunService:UnbindFromRenderStep("ABRAim") end)
RunService:BindToRenderStep("ABRAim", Enum.RenderPriority.Camera.Value + 1, function() if CB.aimAt then camAimStep() end end)
local function mouse1(down)
    if CB.m1Down == down then return end
    CB.m1Down = down
    local vp = workspace.CurrentCamera.ViewportSize
    pcall(function() VirtualInputManager:SendMouseButtonEvent(vp.X / 2, vp.Y / 2, 0, down, game, 0) end)
end
D.releaseMouse = function() mouse1(false) end
local function ready(k, cd) return os.clock() - (CB.cd[k] or -999) > cd end
local function use(k, cd, hold)
    CB.cd[k] = os.clock()
    task.spawn(function() key(k, true) task.wait(hold or rand(0.06, 0.12)) key(k, false) end)
end
local function myStyle()
    local st = "Johnny"
    pcall(function()
        for _, o in ipairs(getgc(true)) do
            if type(o) == "table" and rawget(o, "Class") == "PlayerData" and type(rawget(o, "Data")) == "table" then st = o.Data.Style or st break end
        end
    end)
    return st
end
local function isEnemyModel(m)
    if not (m and m:IsA("Model")) or m == char() then return false end
    local hm = m:FindFirstChildOfClass("Humanoid")
    local r = m:FindFirstChild("HumanoidRootPart")
    if not (hm and r) or hm.Health <= 0 then return false end
    if CollectionService:HasTag(m, "Horse") or CollectionService:HasTag(m, "Invincible") then return false end
    if m:GetAttribute("Owner") ~= nil then return false end
    local p = Players:GetPlayerFromCharacter(m)
    if p and (p:GetAttribute("RaceDead") == true or p:GetAttribute("FinishPosition")) then return false end
    return true
end
local function enemies()
    local list = {}
    for _, p in ipairs(Players:GetPlayers()) do if p ~= plr and isEnemyModel(p.Character) then list[#list + 1] = p.Character end end
    local rigs = workspace:FindFirstChild("Rigs")
    if rigs then for _, m in ipairs(rigs:GetChildren()) do if not Players:GetPlayerFromCharacter(m) and isEnemyModel(m) then list[#list + 1] = m end end end
    return list
end
local function inTown() return currentCheckpoint() >= 6 or D.safeActive == true end
local function pickTarget(root)
    local best, bd, why
    for _, m in ipairs(enemies()) do
        local d = (m.HumanoidRootPart.Position - root.Position).Magnitude
        local p = Players:GetPlayerFromCharacter(m)
        local isBounty = p and D.bountyTarget and p.UserId == D.bountyTarget
        local isNpc = p == nil
        local radius = isBounty and 70 or (inTown() and (isNpc and 25 or 45)) or 14
        if d <= radius then
            local hmE = m:FindFirstChildOfClass("Humanoid")
            local frac = hmE and hmE.MaxHealth > 0 and (hmE.Health / hmE.MaxHealth) or 1
            local score = d + frac * 25 - (isBounty and 50 or 0) + (isNpc and 30 or 0)
            if not bd or score < bd then best, bd, why = m, score, isBounty and "bounty" or (inTown() and "town" or "close") end
        end
    end
    return best, why
end
local KEYMAP = { ["1"] = Enum.KeyCode.One, ["2"] = Enum.KeyCode.Two, ["3"] = Enum.KeyCode.Three, ["4"] = Enum.KeyCode.Four,
    ["5"] = Enum.KeyCode.Five, R = Enum.KeyCode.R, E = Enum.KeyCode.E, G = Enum.KeyCode.G, H = Enum.KeyCode.H, Z = Enum.KeyCode.Z, X = Enum.KeyCode.X }
local hotCache = { at = 0, foot = {}, horse = {} }
local function readHotbar()
    if os.clock() - hotCache.at < 3 then return hotCache end
    hotCache.at = os.clock()
    hotCache.foot, hotCache.horse = {}, {}
    pcall(function()
        local bottom = plr.PlayerGui.Main.Bottom
        for _, pair in ipairs({ { "Abilities", hotCache.foot }, { "HorseAbilities", hotCache.horse } }) do
            local holder = bottom:FindFirstChild(pair[1])
            if holder then
                for _, slot in ipairs(holder:GetChildren()) do
                    local num = slot:FindFirstChild("NumberTxt")
                    local name = slot:FindFirstChild("InsideText")
                    if num and name and slot:IsA("GuiObject") and slot.Visible then
                        local k = KEYMAP[tostring(num.Text):upper()]
                        if k and name.Text ~= "" and name.Text ~= "Revolver" then
                            table.insert(pair[2], { key = k, name = name.Text })
                        end
                    end
                end
            end
        end
    end)
    return hotCache
end
local function useHotbarAbility(list, d)
    for _, a in ipairs(list) do
        local cdk = "hb_" .. a.name
        if ready(cdk, 13) and d <= 40 then
            CB.cd[cdk] = os.clock()
            local hold = (a.name:lower():find("focus") or a.name:lower():find("charge") or a.name:lower():find("ray")) and rand(0.5, 0.8) or rand(0.06, 0.12)
            task.spawn(function() task.wait(reactDelay(0.5)) key(a.key, true) task.wait(hold) key(a.key, false) end)
            slog(string.format("ability %s (%s) at d=%.0f", a.name, tostring(a.key), d))
            return true
        end
    end
    return false
end

local function combatTick()
    if not S.autoCombat or mapName() ~= "Stage2" then CB.aimAt = nil mouse1(false) return false end
    if workspace:GetAttribute("IntermissionTimer") ~= nil then return false end
    local c, root, hmn = char(), hrp(), hum()
    if not (c and root and hmn) or hmn.Health <= 0 then CB.aimAt = nil mouse1(false) return false end
    CB.style = CB.style or myStyle()
    local now = os.clock()
    if CB.lastHp and hmn.Health < CB.lastHp - 0.5 then CB.hurtAt = now end
    CB.lastHp = hmn.Health
    if (c:GetAttribute("Stunned") or c:GetAttribute("Ragdolled") or c:GetAttribute("BarrageStun")) and (c:GetAttribute("EvasiveBar") or 0) >= 100 and ready(Enum.KeyCode.Q, 1.5) then
        use(Enum.KeyCode.Q, 1.5)
    end
    local fog = workspace:GetAttribute("FogTimer")
    local tLeft = fog and (fog - workspace:GetServerTimeNow()) or math.huge
    local tgt, why = pickTarget(root)
    if not tgt then CB.aimAt = nil mouse1(false) CB.target = nil return false end
    if not inTown() and tLeft < 60 and why ~= "close" then CB.aimAt = nil mouse1(false) return false end
    local lowHp = hmn.Health < hmn.MaxHealth * 0.45 and (tgt.HumanoidRootPart.Position - root.Position).Magnitude < 15 and not isMounted()
    if not inTown() and not lowHp then
        local dd = (tgt.HumanoidRootPart.Position - root.Position).Magnitude
        local retaliate = (now - CB.hurtAt < 2.5) and dd < 9
        local bountyClose = why == "bounty" and dd < 10
        if not (retaliate or bountyClose) then CB.aimAt = nil mouse1(false) return false end
    end
    CB.target = tgt
    local tr = tgt.HumanoidRootPart
    local d = (tr.Position - root.Position).Magnitude
    local mounted = isMounted()
    local npcNear, npcPos, npcD = false, nil, math.huge
    for _, e in ipairs(enemies()) do
        if not Players:GetPlayerFromCharacter(e) then
            local er = e:FindFirstChild("HumanoidRootPart")
            local ed = er and (er.Position - root.Position).Magnitude or math.huge
            if ed < 80 and ed < npcD then npcNear, npcPos, npcD = true, er.Position, ed end
        end
    end
    if npcNear then D.townThreat = now + 4 end
    if currentCheckpoint() >= 6 and not D.townAnchor then
        D.townAnchor = root.Position + flat(root.CFrame.LookVector).Unit * 60
    end
    if mounted and currentCheckpoint() >= 6 and not npcNear and now > (D.townThreat or 0)
        and hmn.Health > hmn.MaxHealth * 0.6 and ready(Enum.KeyCode.N, 3) then use(Enum.KeyCode.N, 3) end
    if mounted and currentCheckpoint() >= 6 and npcNear then
        local h = myHorse()
        local hr = h and horseRoot(h)
        if hr then
            local away = flat(hr.Position - npcPos)
            away = away.Magnitude > 0.5 and away.Unit or flat(hr.CFrame.LookVector)
            local goal = hr.Position + away * 60 + Vector3.new(-away.Z, 0, away.X) * 25
            if D.townAnchor and flat(goal - D.townAnchor).Magnitude > 140 then
                goal = goal:Lerp(Vector3.new(D.townAnchor.X, goal.Y, D.townAnchor.Z), 0.6)
            end
            local look = hr.CFrame.LookVector
            local err = avoidHeading(hr.Position, look, signedAngle(look, goal - hr.Position), hr.AssemblyLinearVelocity.Magnitude)
            key(Enum.KeyCode.W, true)
            key(Enum.KeyCode.LeftShift, true)
            key(Enum.KeyCode.D, err > 8) key(Enum.KeyCode.A, err < -8)
            mouse1(d <= 9)
            useHotbarAbility(readHotbar().horse, d)
            status = string.format("Town: riding away from hunter d=%.0f hp=%d", npcD, math.floor(hmn.Health))
            return true
        end
    end
    if now - CB.standAt > 20 then CB.standAt = now use(Enum.KeyCode.B, 2) end
    CB.aimAt = tr.Position + tr.AssemblyLinearVelocity * 0.12
    status = string.format("Fighting %s (%s) d=%.0f hp=%d", tgt.Name, why, d, math.floor(hmn.Health))
    if not mounted then
        key(Enum.KeyCode.LeftShift, false)
        hmn:MoveTo(tr.Position + Vector3.new(rand(-2, 2), 0, rand(-2, 2)))
    else
        if now - CB.hurtAt < 3 and d < 25 then D.evadeUntil = now + 2.5 end
        mouse1(d <= 9)
        useHotbarAbility(readHotbar().horse, d)
        return false
    end
    local johnny = CB.style == "Johnny"
    if now - CB.hurtAt < 0.6 and d < 10 then
        if not mounted and ready(Enum.KeyCode.Q, 1.8) then
            CB.cd[Enum.KeyCode.Q] = now
            mouse1(false)
            local sk = (math.random() < 0.5) and Enum.KeyCode.A or Enum.KeyCode.D
            task.spawn(function() key(sk, true) task.wait(0.03) tap(Enum.KeyCode.Q) task.wait(0.12) key(sk, false) end)
            status = "Dodging out of a combo"
            return true
        elseif not mounted and not CB.m1Down and ready(Enum.KeyCode.F, 1.0) then
            CB.cd[Enum.KeyCode.F] = now
            CB.aimAt = tr.Position
            task.spawn(function() key(Enum.KeyCode.F, true) task.wait(rand(0.45, 0.8)) key(Enum.KeyCode.F, false) end)
            return true
        end
    end
    if hmn.Health < hmn.MaxHealth * 0.45 and ready(Enum.KeyCode.G, 4) then use(Enum.KeyCode.G, 4) end
    local npcThreat = Players:GetPlayerFromCharacter(tgt) == nil and d < 25
    if (hmn.Health < hmn.MaxHealth * 0.45 or npcThreat) and not mounted then
        mouse1(false)
        local away = flat(root.Position - tr.Position)
        if away.Magnitude < 0.5 then away = flat(root.CFrame.LookVector) * -1 end
        away = away.Unit
        local side = Vector3.new(-away.Z, 0, away.X) * (math.sin(now * 1.7) * 8)
        hmn:MoveTo(root.Position + away * 30 + side)
        key(Enum.KeyCode.LeftShift, true)
        if d < 6 and ready(Enum.KeyCode.F, 0.9) then
            CB.cd[Enum.KeyCode.F] = now
            CB.aimAt = tr.Position
            task.spawn(function() key(Enum.KeyCode.F, true) task.wait(rand(0.5, 0.8)) key(Enum.KeyCode.F, false) end)
        else
            CB.aimAt = nil
        end
        if d < 12 and johnny and ready(Enum.KeyCode.Four, 20.5) then use(Enum.KeyCode.Four, 20.5, rand(0.6, 0.9)) end
        if d < 10 and ready(Enum.KeyCode.Q, 1.9) then
            CB.cd[Enum.KeyCode.Q] = now
            local sk = (math.random() < 0.5) and Enum.KeyCode.A or Enum.KeyCode.D
            task.spawn(function() key(sk, true) task.wait(0.03) tap(Enum.KeyCode.Q) task.wait(0.1) key(sk, false) end)
        end
        status = string.format("Survival: escaping %s d=%.0f hp=%d", tgt.Name, d, math.floor(hmn.Health))
        return true
    end
    if d <= 30 then useHotbarAbility(readHotbar().foot, d) end
    if d > 7 and d <= 45 then
        mouse1(false)
        if johnny then
            if ready(Enum.KeyCode.Two, 14.5) then use(Enum.KeyCode.Two, 14.5)
            elseif ready(Enum.KeyCode.One, 15.5) then use(Enum.KeyCode.One, 15.5, rand(0.55, 0.75)) end
        else
            if ready(Enum.KeyCode.Three, 25.5) then use(Enum.KeyCode.Three, 25.5) end
        end
        if d < 18 and ready(Enum.KeyCode.Q, 3.2) then
            CB.cd[Enum.KeyCode.Q] = now
            task.spawn(function() key(Enum.KeyCode.W, true) task.wait(0.03) tap(Enum.KeyCode.Q) end)
        end
    elseif d <= 7 then
        CB.phaseUntil = CB.phaseUntil or 0
        if now > CB.phaseUntil then
            CB.inCombo = not CB.inCombo
            CB.phaseUntil = now + (CB.inCombo and rand(1.0, 1.3) or rand(0.4, 0.6))
            if not CB.inCombo then
                mouse1(false)
                task.spawn(function() key(Enum.KeyCode.F, true) task.wait(rand(0.35, 0.5)) key(Enum.KeyCode.F, false) end)
            end
        end
        mouse1(CB.inCombo == true)
        if CB.inCombo and math.random() < 0.08 then task.spawn(tap, Enum.KeyCode.Space, 0.25) end
        if johnny then
            if ready(Enum.KeyCode.Three, 25.5) and math.random() < 0.3 then use(Enum.KeyCode.Three, 25.5) end
            if ready(Enum.KeyCode.E, 20.5) and math.random() < 0.2 then use(Enum.KeyCode.E, 20.5, rand(1.2, 1.8)) end
        else
            if ready(Enum.KeyCode.Four, 20.5) and math.random() < 0.3 then use(Enum.KeyCode.Four, 20.5) end
            if ready(Enum.KeyCode.One, 25.5) and math.random() < 0.3 then use(Enum.KeyCode.One, 25.5) end
            if ready(Enum.KeyCode.E, 35.5) and math.random() < 0.2 then use(Enum.KeyCode.E, 35.5, rand(1.2, 1.8)) end
        end
    else
        mouse1(false)
    end
    return true
end

local SAFE = { active = false, anchor = nil, seenAt = 0 }
local bannerLabels, bannerLabelsAt, bannerMemo = {}, 0, {}
local function bannerSays(pattern)
    local pg = plr:FindFirstChild("PlayerGui")
    if not pg then return false end
    local now = os.clock()
    local memo = bannerMemo[pattern]
    if memo and now - memo.at < 0.4 then return memo.v end
    if now - bannerLabelsAt > 2 then
        bannerLabelsAt, bannerLabels = now, {}
        for _, d in ipairs(pg:GetDescendants()) do if d:IsA("TextLabel") then bannerLabels[#bannerLabels + 1] = d end end
    end
    local found = false
    for _, d in ipairs(bannerLabels) do
        if d.Parent and d.Visible and type(d.Text) == "string" and d.Text:upper():find(pattern) then
            local ok, vis = pcall(function()
                local g = d:FindFirstAncestorWhichIsA("ScreenGui")
                return (not g) or g.Enabled
            end)
            if ok and vis then found = true break end
        end
    end
    bannerMemo[pattern] = { at = now, v = found }
    return found
end
local lastSafeScan = 0
local function exitMarker()
    if SAFE.marker and SAFE.marker.Parent then return SAFE.marker end
    if os.clock() - (SAFE.markerScan or 0) < 3 then return nil end
    SAFE.markerScan = os.clock()
    for _, d in ipairs(CollectionService:GetTagged("AreaMarker")) do
        if d:IsA("BasePart") and d:GetAttribute("Area") == "ExitDevilsPalm" and d:GetAttribute("Custom") == true then SAFE.marker = d return d end
    end
    local map = workspace:FindFirstChild("Map") or workspace
    for _, d in ipairs(map:GetDescendants()) do
        if d:IsA("BasePart") and d:GetAttribute("Area") == "ExitDevilsPalm" and d:GetAttribute("Custom") == true then SAFE.marker = d return d end
    end
    return nil
end
local function markerDist(m, p)
    local cf = m.CFrame
    return (p - (cf.Position + cf.LookVector * (m.Size.Z / 2))):Dot(cf.LookVector)
end
local DEPTH = 40
local function safeAnchor(m, p)
    local cf = m.CFrame
    local look = flat(cf.LookVector).Unit
    local plane = cf.Position + cf.LookVector * (m.Size.Z / 2)
    local ok, ccf = pcall(function() return workspace.Map.Visual.CampArea:GetBoundingBox() end)
    if ok and ccf and markerDist(m, ccf.Position) > 25 and flat(ccf.Position - p).Magnitude < 250 then
        local c = ccf.Position
        local dc = markerDist(m, c)
        if dc > DEPTH + 30 then c = c - look * (dc - DEPTH) end
        return Vector3.new(c.X, p.Y, c.Z)
    end
    local lateral = flat(p - plane) - look * flat(p - plane):Dot(look)
    local a = plane + lateral + look * DEPTH
    return Vector3.new(a.X, p.Y, a.Z)
end
local function safeAreaTick()
    if mapName() ~= "Stage2" then SAFE.active = false SAFE.anchor = nil D.safeActive = false return false end
    local now = os.clock()
    if now - lastSafeScan > 0.5 then
        lastSafeScan = now
        local m = exitMarker()
        local rr = hrp()
        local fogT = workspace:GetAttribute("FogTimer")
        local crossed = m and rr and markerDist(m, rr.Position) > 0
        local nightPending = fogT and workspace:GetServerTimeNow() < fogT - 2
        if (bannerSays("STAY IN THIS SAFE AREA") or (crossed and nightPending)) and os.clock() - (SAFE.releasedAt or -999) > 300 then
            if not SAFE.active then
                SAFE.active, SAFE.seenAt = true, now
                D.safeActive = true
                local h = myHorse()
                local r = (h and horseRoot(h)) or hrp()
                if r then
                    SAFE.anchor = m and safeAnchor(m, r.Position) or (r.Position + flat(r.CFrame.LookVector).Unit * DEPTH)
                end
                slog(string.format("safe area: holding until nightfall (marker=%s)", tostring(m ~= nil)))
            end
        end
    end
    if not SAFE.active then return false end
    local fog = workspace:GetAttribute("FogTimer")
    local over = workspace:GetAttribute("BoomBoomSpawnTime") ~= nil or (fog and workspace:GetServerTimeNow() > fog) or bannerSays("RUN TO THE TOWN")
    if over or now - SAFE.seenAt > 400 then
        SAFE.active, SAFE.anchor = false, nil
        SAFE.releasedAt = os.clock()
        D.safeActive = false
        slog("safe area: released")
        return false
    end
    local h = myHorse()
    local r = (h and horseRoot(h)) or hrp()
    if not (r and SAFE.anchor) then return true end
    local off = flat(SAFE.anchor - r.Position)
    local m = exitMarker()
    local depth = m and markerDist(m, r.Position) or 99
    local fogT = workspace:GetAttribute("FogTimer")
    local left = fogT and math.max(0, fogT - workspace:GetServerTimeNow()) or 0
    status = string.format("Safe area: %.0f past line, %.0f from spot, nightfall in %.0fs", depth, off.Magnitude, left)
    if off.Magnitude > 10 or depth < 15 then
        key(Enum.KeyCode.LeftShift, false)
        if isMounted(h) then
            local err = signedAngle(r.CFrame.LookVector, off)
            key(Enum.KeyCode.W, math.abs(err) < 100)
            key(Enum.KeyCode.D, err > 8) key(Enum.KeyCode.A, err < -8)
        else
            local hm = hum() if hm then hm:MoveTo(SAFE.anchor) end
        end
    else
        releaseAll()
        if math.random() < 0.004 then task.spawn(tap, (math.random() < 0.5) and Enum.KeyCode.A or Enum.KeyCode.D, rand(0.1, 0.25)) end
    end
    return true
end

local wasRacing = false
local lobbyRequestedAt = 0
local function returnToLobby(reason)
    if not S.autoReturn then return end
    if os.clock() - lobbyRequestedAt < 12 then return end
    lobbyRequestedAt = os.clock()
    task.spawn(function()
        task.wait(rand(0.8, 2.0))
        local ts = knitService("TeleportService")
        if ts then
            status = "Returning to lobby (" .. reason .. ")"
            pcall(function() ts:TeleportToLobby() end)
        end
    end)
end
local LOBBY_PLACE = 108055619068945
local loadWatch = { since = nil, asked = 0 }
local function brokenServerWatchdog()
    if workspace:GetAttribute("RaceStarted") == true or workspace:GetAttribute("Racing") == true then
        loadWatch.since = nil
        return
    end
    loadWatch.since = loadWatch.since or os.clock()
    local waited = os.clock() - loadWatch.since
    local ts = tostring(workspace:GetAttribute("TeleportState") or "")
    local stuckLoading = ts:lower():find("waiting for players") ~= nil and waited > 100
    if (stuckLoading or waited > 300) and os.clock() - loadWatch.asked > 25 then
        loadWatch.asked = os.clock()
        status = string.format("Server stuck (%s, %.0fs) -> rejoining a new lobby", ts, waited)
        slog(status)
        task.spawn(function()
            local svc = knitService("TeleportService")
            local ok = svc and pcall(function() svc:TeleportToLobby() end)
            task.wait(30)
            pcall(function() game:GetService("TeleportService"):Teleport(LOBBY_PLACE, plr) end)
        end)
    end
end
local function raceTick(dt)
    pcall(brokenServerWatchdog)
    if plr:GetAttribute("RaceDead") == true then
        if wasRacing then wasRacing = false stats.races += 1 stats.lastPlace = "dead" end
        resetDriver()
        local data = loadLines(mapName())
        D.deadSince = D.deadSince or os.clock()
        if mapName() == "Stage1" and #data.lines == 0 and REC.fullRace and workspace:GetAttribute("MatchDone") ~= true and os.clock() - D.deadSince < 300 then
            status = "Eliminated - spectating to learn the winners' line"
            return
        end
        status = "Eliminated"
        returnToLobby("eliminated")
        return
    end
    if finished() then
        if wasRacing then
            wasRacing = false
            stats.races += 1
            stats.lastPlace = tostring(plr:GetAttribute("FinishPosition") or "?")
        end
        status = "Finished (place " .. tostring(plr:GetAttribute("FinishPosition") or "?") .. ")"
        resetDriver()
        return
    end
    if registerTick() then return end
    if workspace:GetAttribute("RaceStarted") ~= true then
        status = "Waiting for the race to start"
        resetDriver()
        return
    end
    wasRacing = true
    local okS, holding = pcall(safeAreaTick)
    if okS and holding then
        local okF, f2 = pcall(combatTick)
        if okF and f2 then return end
        return
    end
    local okC, fighting = pcall(combatTick)
    if okC and fighting then return end
    if not okC then slog("combat error " .. tostring(fighting)) end
    if S.autoRace then
        driveTick(dt)
    else
        status = "Race (auto race off)"
        resetDriver()
    end
end

pcall(function()
    if isfile and isfile("autoexec_present_marker") then return end
    local q = queue_on_teleport or (syn and syn.queue_on_teleport)
    if q and not env.__ABRAutoexec then
        q('if not getgenv().__ABRCleanup and isfile and isfile("ConeHub/ABizarreRun.lua") then task.wait(8) if not getgenv().__ABRCleanup then loadstring(readfile("ConeHub/ABizarreRun.lua"))() end end')
    end
end)

local Window = Fluent:CreateWindow({
    Title = "Cone Hub",
    SubTitle = "A Bizarre Run",
    TabWidth = 140,
    Size = UDim2.fromOffset(560, 440),
    Acrylic = false,
    Theme = "Darker",
    MinimizeKey = Enum.KeyCode.RightControl,
})
local Tabs = {
    Main = Window:AddTab({ Title = "Main", Icon = "flag" }),
    Driving = Window:AddTab({ Title = "Driving", Icon = "gauge" }),
    Settings = Window:AddTab({ Title = "Settings", Icon = "settings" }),
}
local Options = Fluent.Options

local InfoBox = Tabs.Main:AddParagraph({ Title = "Status", Content = "Starting..." })

local function bindToggle(tab, id, title, desc, field)
    local t = tab:AddToggle(id, { Title = title, Description = desc, Default = S[field] })
    t:OnChanged(function() S[field] = Options[id].Value saveSettings() end)
    return t
end
local function bindSlider(tab, id, title, desc, field, min, max, rounding)
    local s = tab:AddSlider(id, { Title = title, Description = desc, Default = S[field], Min = min, Max = max, Rounding = rounding or 0 })
    s:OnChanged(function(v) S[field] = v saveSettings() end)
    return s
end

bindToggle(Tabs.Main, "AutoQueue", "Auto Queue", "Join the race queue from the lobby whenever it opens", "autoQueue")
bindToggle(Tabs.Main, "AutoRegister", "Auto Register", "Walk to the registration booth during intermission", "autoRegister")
bindToggle(Tabs.Main, "AutoRace", "Auto Race", "Ride the race for you (human-like)", "autoRace")
bindToggle(Tabs.Main, "AutoReturn", "Auto Return to Lobby", "Leave after finishing or being eliminated", "autoReturn")
bindToggle(Tabs.Main, "AutoSkip", "Auto Skip Cutscenes", "Votes skip on intros / narration", "autoSkip")
bindToggle(Tabs.Main, "AutoBounty", "Auto Bounty (Stage 2)", "Pick a bounty target automatically", "autoBounty")
do
    local dd = Tabs.Main:AddDropdown("BountyPick", { Title = "Bounty preference", Values = { "Easy", "Medium", "Hard", "Best value" }, Default = S.bountyPick })
    dd:OnChanged(function(v) S.bountyPick = v saveSettings() end)
end
bindToggle(Tabs.Main, "AutoCombat", "Auto Combat (Stage 2)", "Fight bounty target / attackers / in town", "autoCombat")
bindToggle(Tabs.Main, "AntiAfk", "Anti AFK", nil, "antiAfk")

bindSlider(Tabs.Driving, "Humanness", "Human-likeness", "Higher = looser lines, slower/variable reactions", "humanness", 0, 100)
bindSlider(Tabs.Driving, "Reaction", "Reaction time (ms)", "Average delay before reacting to turns", "reaction", 60, 450)
bindToggle(Tabs.Driving, "UseSprint", "Sprint (Shift)", "Pace sprinting with stamina", "useSprint")
bindSlider(Tabs.Driving, "SprintStop", "Stop sprint at stamina %", nil, "sprintStop", 5, 50)
bindSlider(Tabs.Driving, "SprintResume", "Resume sprint at stamina %", nil, "sprintResume", 20, 100)
bindToggle(Tabs.Driving, "UseBoost", "Boost (Z) on clear straights", nil, "useBoost")
bindToggle(Tabs.Driving, "InfStamina", "Infinite horse stamina", nil, "infStamina")
bindToggle(Tabs.Driving, "BoostRefill", "Refill boost after use", nil, "boostRefill")
bindToggle(Tabs.Driving, "StaminaAssist", "Stamina assist when behind", "Tops up horse stamina only when not in the top 2", "staminaAssist")
bindToggle(Tabs.Driving, "AutoRecall", "Call horse (T) after falling", nil, "autoRecall")
bindToggle(Tabs.Driving, "LassoEscape", "Escape lassos (mash E)", nil, "lassoEscape")
bindToggle(Tabs.Driving, "AvoidHazards", "Avoid rocks / walls", nil, "avoidHazards")
bindToggle(Tabs.Driving, "FollowRiders", "Follow / draft riders ahead", "Use other players as a line and for slipstream", "followRiders")

Tabs.Main:AddButton({
    Title = "Stop & release keys",
    Callback = function()
        S.autoRace = false
        pcall(function() Options.AutoRace:SetValue(false) end)
        resetDriver()
    end,
})

SaveManager:SetLibrary(Fluent)
InterfaceManager:SetLibrary(Fluent)
SaveManager:IgnoreThemeSettings()
SaveManager:SetIgnoreIndexes({})
InterfaceManager:SetFolder("ConeHub")
SaveManager:SetFolder("ConeHub/ABizarreRun")
InterfaceManager:BuildInterfaceSection(Tabs.Settings)
SaveManager:BuildConfigSection(Tabs.Settings)
Window:SelectTab(1)
pcall(function() Window:Minimize() end)
pcall(function()
    Fluent:Notify({ Title = "Cone Hub", Content = "A Bizarre Run auto-play loaded. Press RightCtrl to open settings.", Duration = 6 })
end)

table.insert(conns, plr.Idled:Connect(function()
    if S.antiAfk then
        VirtualUser:CaptureController()
        VirtualUser:ClickButton2(Vector2.new())
    end
end))

D.bountyTarget = nil
task.spawn(function()
    local bs
    for _ = 1, 30 do bs = knitService("BountyService") if bs then break end task.wait(1) end
    if not bs then return end
    local choosingAt = 0
    local function apply(st)
        if type(st) ~= "table" then return end
        if st.Status == "Hunting" and type(st.Target) == "table" then
            D.bountyTarget = st.Target.UserId
            status = "Bounty target: " .. tostring(st.Target.Name or st.Target.UserId)
        elseif st.Status ~= "Hunting" then
            D.bountyTarget = nil
        end
        if st.Status == "Choosing" and S.autoBounty and type(st.Offers) == "table" and os.clock() - choosingAt > 5 then
            choosingAt = os.clock()
            task.spawn(function()
                task.wait(rand(1.5, 3.5))
                local order = ({ Easy = { "Easy", "Medium", "Hard" }, Medium = { "Medium", "Easy", "Hard" }, Hard = { "Hard", "Medium", "Easy" }, ["Best value"] = { "Hard", "Medium", "Easy" } })[S.bountyPick] or { "Easy", "Medium", "Hard" }
                for _, diff in ipairs(order) do
                    local o = st.Offers[diff]
                    if type(o) == "table" and o.UserId and o.UserId ~= plr.UserId then
                        local ok = pcall(function() return bs:SelectBounty(o.UserId):await() end)
                        slog(string.format("bounty: picked %s %s (kills %s) ok=%s", diff, tostring(o.Name or o.UserId), tostring(o.Kills), tostring(ok)))
                        status = "Bounty picked: " .. diff
                        return
                    end
                end
            end)
        end
    end
    pcall(function() table.insert(conns, bs.StateChanged:Connect(apply)) end)
    pcall(function() local ok, st = bs:GetState():await() if ok then apply(st) end end)
end)

task.spawn(function()
    local cs
    for _ = 1, 30 do cs = knitService("CutsceneService") if cs then break end task.wait(1) end
    if not cs or not cs.SkipCutscene then return end
    local function vote(id)
        if not S.autoSkip or id == nil then return end
        task.wait(rand(0.4, 1.3))
        pcall(function() cs.SkipCutscene:Fire(id) end)
        status = "Skipped cutscene"
    end
    pcall(function()
        table.insert(conns, cs.SkipCutscene:Connect(function(kind, id) if kind == "Start" then task.spawn(vote, id) end end))
    end)
    pcall(function()
        local cc = Knit.GetController("CutsceneController")
        if cc and cc.CurrentSkipID then task.spawn(vote, cc.CurrentSkipID) end
    end)
end)

task.spawn(function()
    while running do
        if inRaceMap() then pcall(recordTick) else D.deadSince = nil end
        if workspace:GetAttribute("RaceStarted") ~= true then D.deadSince = nil D.gi = nil D.giMax = nil D.mergeOff = nil D.lineShift = nil end
        task.wait(0.5)
    end
end)

local busy = false
local lastTick = os.clock()
table.insert(conns, RunService.Heartbeat:Connect(function()
    if not running or busy then return end
    if os.clock() - lastTick < 1 / 45 then return end
    busy = true
    local now = os.clock()
    local dt = math.max(now - lastTick, 1/240)
    lastTick = now
    task.spawn(function()
        local ok, err = pcall(function()
            local m = mapName()
            if m == "Lobby" then
                resetDriver()
                lobbyTick()
            elseif inRaceMap() then
                raceTick(dt)
            elseif m == "Battlegrounds" then
                D.wrongPlaceSince = D.wrongPlaceSince or os.clock()
                status = "In Battlegrounds -> going back to the race lobby"
                if os.clock() - D.wrongPlaceSince > 8 and os.clock() - (D.wrongPlaceTp or 0) > 30 then
                    D.wrongPlaceTp = os.clock()
                    task.spawn(function() pcall(function() game:GetService("TeleportService"):Teleport(LOBBY_PLACE, plr) end) end)
                end
            else
                status = "Mode: " .. tostring(m) .. " (nothing to do)"
                resetDriver()
            end
        end)
        if not ok then status = "Error: " .. tostring(err) end
        busy = false
    end)
end))

task.spawn(function()
    while running do
        pcall(function()
            InfoBox:SetDesc(string.format("%s\n\nMap: %s  |  Races: %d  |  Last place: %s\nHorse recalls: %d  |  Boosts: %d  |  Stuck: %d\nLearned lines (%s): %d  |  saved this session: %d",
                status, tostring(mapName()), stats.races, stats.lastPlace, stats.recalls, stats.boosts, stats.stuck, tostring(mapName()), #loadLines(mapName() or "?").lines, stats.linesSaved or 0))
        end)
        task.wait(0.4)
    end
end)

env.__ABRStatus = function() return status, stats end
env.__ABRCleanup = function()
    running = false
    pcall(function() queryConn:Disconnect() end)
    pcall(function() RunService:UnbindFromRenderStep("ABRAim") end)
    pcall(function() VirtualInputManager:SendMouseButtonEvent(0, 0, 0, false, game, 0) end)
    releaseAll()
    for _, c in ipairs(conns) do pcall(function() c:Disconnect() end) end
    table.clear(conns)
    pcall(function() Window:Destroy() end)
end
