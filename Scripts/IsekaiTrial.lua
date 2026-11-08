local env = getgenv()
if env.__ITStop then pcall(env.__ITStop) end
local Players = game:GetService("Players")
local PFS = game:GetService("PathfindingService")
local RunService = game:GetService("RunService")
local VIM = game:GetService("VirtualInputManager")
local lp = Players.LocalPlayer
local running = true
local status = "starting"
local log = {}
local function slog(s) log[#log + 1] = string.format("%.0f %s", os.clock(), s) if #log > 40 then table.remove(log, 1) end end
env.__ITStatus = function() return status, log end
env.__ITStop = function() running = false local h = lp.Character and lp.Character:FindFirstChildOfClass("Humanoid") if h then h:Move(Vector3.zero) end end

local function char() return lp.Character end
local function hrp() local c = char() return c and c:FindFirstChild("HumanoidRootPart") end
local function hum() local c = char() return c and c:FindFirstChildOfClass("Humanoid") end
local function stage() return workspace:GetAttribute("Stage") or 1 end
local function stageOk(m)
    local s = m:GetAttribute("Stages")
    if s == nil then return true end
    return tostring(s):find(tostring(stage()), 1, true) ~= nil
end
local function posOf(m)
    if m:IsA("BasePart") then return m.Position end
    local ok, p = pcall(function() return m:GetPivot().Position end)
    return ok and p or nil
end
local function enemy()
    local f = workspace:FindFirstChild("Enemy")
    local g = f and f:FindFirstChild("IsekaiGunter")
    return g, g and posOf(g), g and g:GetAttribute("State")
end
local function key(k, down) pcall(function() VIM:SendKeyEvent(down, k, false, game) end) end
local function click(cd)
    if not cd then return false end
    local ok = pcall(fireclickdetector, cd, 0)
    return ok
end
local function cdOf(m)
    for _, d in ipairs(m:GetDescendants()) do if d:IsA("ClickDetector") then return d end end
end

local function doorLampGreen(d)
    for _, p in ipairs(d:GetDescendants()) do if p.Name == "Lamp" and p:IsA("BasePart") then return p.BrickColor.Name:lower():find("green") ~= nil end end
    return false
end
local function doorOpenable(d)
    if doorLampGreen(d) then return true end
    local u = d:GetAttribute("Unlock") or ""
    if d:GetAttribute("RequireFlashlight") and not lp:GetAttribute("HasFlashlight") then return false end
    if u == "" then return true end
    return d:GetAttribute("Unlocked") == true or d:GetAttribute("Open") == true
end
local function prepDoors()
    local f = workspace:FindFirstChild("Map") and workspace.Map:FindFirstChild("Doors")
    for _, d in ipairs(f and f:GetChildren() or {}) do
        for _, p in ipairs(doorOpenable(d) and d:GetDescendants() or {}) do
            if p:IsA("BasePart") and not p:FindFirstChild("ITPass") then
                local pm = Instance.new("PathfindingModifier") pm.Name = "ITPass" pm.PassThrough = true pm.Parent = p
            end
        end
    end
end
local lastDoorClick = {}
local function openNearDoors()
    local r = hrp()
    local f = workspace:FindFirstChild("Map") and workspace.Map:FindFirstChild("Doors")
    for _, d in ipairs(f and f:GetChildren() or {}) do
        local slab = d:FindFirstChild("Slab", true)
        if slab and slab.CanCollide and doorOpenable(d) and (slab.Position - r.Position).Magnitude < 8 and os.clock() - (lastDoorClick[d] or 0) > 2 then
            lastDoorClick[d] = os.clock()
            click(slab:FindFirstChildWhichIsA("ClickDetector"))
            slog("opened door " .. d.Name)
        end
    end
end
local function lockedSlabNear(r, within)
    local f = workspace:FindFirstChild("Map") and workspace.Map:FindFirstChild("Doors")
    for _, d in ipairs(f and f:GetChildren() or {}) do
        local slab = d:FindFirstChild("Slab", true)
        if slab and slab.CanCollide and (slab.Position - r.Position).Magnitude < within then return slab, d end
    end
end
local function phaseThrough(slab, toward)
    local r = hrp()
    local dir = Vector3.new(toward.X - r.Position.X, 0, toward.Z - r.Position.Z)
    if dir.Magnitude < 0.5 then return end
    dir = dir.Unit
    local n = dir
    local function past() return (hrp().Position - slab.Position):Dot(n) > 4 end
    local steps = 0
    while running and not past() and steps < 40 do
        steps += 1
        local c = hrp().CFrame
        hrp().CFrame = c + dir * 0.65
        task.wait(0.05)
    end
end
local function walkTo(target, reach)
    reach = reach or 5
    local r, h = hrp(), hum()
    if not (r and h) then return "fail" end
    prepDoors()
    local path = PFS:CreatePath({ AgentRadius = 1.6, AgentHeight = 5, AgentCanJump = true, WaypointSpacing = 4 })
    local ok = pcall(function() path:ComputeAsync(r.Position, target) end)
    if not (ok and path.Status == Enum.PathStatus.Success) then slog("no path to " .. tostring(target)) return "fail" end
    local wps = path:GetWaypoints()
    for i, w in ipairs(wps) do
        if not running then return "fail" end
        if i > 1 or (w.Position - r.Position).Magnitude > 2 then
            if w.Action == Enum.PathWaypointAction.Jump then h.Jump = true end
            h:MoveTo(w.Position)
            local t0 = os.clock()
            local function flatD(p, q) return Vector3.new(p.X - q.X, 0, p.Z - q.Z).Magnitude end
            while running and flatD(hrp().Position, w.Position) > 2 and os.clock() - t0 < 3 do
                local eye = lp:GetAttribute("GunterEye") or ""
                key(Enum.KeyCode.LeftShift, eye ~= "")
                if Vector3.new(hrp().Position.X - target.X, 0, hrp().Position.Z - target.Z).Magnitude <= reach then return "arrived" end
                openNearDoors()
                task.wait(0.1)
            end
        end
        if Vector3.new(hrp().Position.X - target.X, 0, hrp().Position.Z - target.Z).Magnitude <= reach then return "arrived" end
    end
    return ((hrp().Position - target).Magnitude <= reach + 3) and "arrived" or "fail"
end

local function evade()
    local _, ep = enemy()
    local r = hrp()
    if not (ep and r) then return end
    status = "Evading Gunter"
    local best, bd = nil, -1
    for _, ev in ipairs(workspace:FindFirstChild("EnvironmentEvents") and workspace.EnvironmentEvents:GetChildren() or {}) do
        local p = posOf(ev)
        if p then
            local dEnemy = (p - ep).Magnitude
            local dMe = (p - r.Position).Magnitude
            local score = dEnemy - dMe * 0.4
            if dMe > 15 and dMe < 90 and score > bd then best, bd = Vector3.new(p.X, r.Position.Y, p.Z), score end
        end
    end
    if best then
        key(Enum.KeyCode.LeftShift, true)
        walkTo(best, 6)
        key(Enum.KeyCode.LeftShift, false)
    end
end

local skipUntil = {}
local function pickups(kind)
    local list = {}
    local f = workspace:FindFirstChild("Map") and workspace.Map:FindFirstChild("Pickups")
    if not f then return list end
    for _, m in ipairs(f:GetChildren()) do
        if os.clock() >= (skipUntil[m] or 0) and m:GetAttribute("Kind") == kind and stageOk(m) and not m:GetAttribute("Hidden") and m.Parent then
            local p = posOf(m)
            local cd = cdOf(m)
            if p and cd and cd.MaxActivationDistance > 0 then list[#list + 1] = { m = m, p = p } end
        end
    end
    local r = hrp()
    table.sort(list, function(a, b) return (a.p - r.Position).Magnitude < (b.p - r.Position).Magnitude end)
    return list
end

local function floorBelow(p)
    local rp = RaycastParams.new() rp.FilterType = Enum.RaycastFilterType.Exclude rp.FilterDescendantsInstances = { char() }
    local hit = workspace:Raycast(p + Vector3.new(0, 1, 0), Vector3.new(0, -25, 0), rp)
    return hit and (hit.Position + Vector3.new(0, 3, 0)) or p
end
local function grab(entry, label)
    status = "Going to " .. label
    if os.clock() < (skipUntil[entry.m] or 0) then return false end
    local res = walkTo(floorBelow(entry.p), 7)
    if res == "fail" then
        for _, o in ipairs({ Vector3.new(5,0,0), Vector3.new(-5,0,0), Vector3.new(0,0,5), Vector3.new(0,0,-5) }) do
            res = walkTo(floorBelow(entry.p + o), 7)
            if res ~= "fail" then break end
        end
    end
    if res == "fail" then skipUntil[entry.m] = os.clock() + 20 end
    if res == "danger" then evade() return false end
    if res ~= "arrived" then slog("could not reach " .. label) return false end
    task.wait(0.2 + math.random() * 0.3)
    click(cdOf(entry.m))
    slog("clicked " .. label)
    task.wait(0.6)
    return true
end

local function fuseBox()
    local f = workspace:FindFirstChild("PuzzleObjects")
    for _, folder in ipairs(f and f:GetChildren() or {}) do
        if folder.Name:match("^Fuses_") and stageOk(folder) then
            local box = folder:FindFirstChild("FuseBox")
            if box then return box end
        end
    end
end
local function exitTrigger()
    local f = workspace:FindFirstChild("EscapeTriggers")
    for _, t in ipairs(f and f:GetChildren() or {}) do
        if t:GetAttribute("ExitStage") == stage() then return t end
    end
end

env.__ITwalk = function(p, reach) return walkTo(p, reach) end
env.__ITclick = function(cd) return click(cd) end
env.__ITpause = false
task.spawn(function()
    while running do
        while env.__ITpause and running do task.wait(0.3) end
        local ok, err = pcall(function()
            if lp:GetAttribute("Caught") or lp:GetAttribute("Escaping") then status = "caught/escaping - waiting" task.wait(1) return end
            local _, ep, st = enemy()
            
            if not lp:GetAttribute("HasFlashlight") then
                local fl = pickups("Flashlight")[1]
                if fl then grab(fl, "flashlight") return end
            end
            if (lp:GetAttribute("BatteryLevel") or 100) < 35 then
                local b = pickups("Battery")[1]
                if b then grab(b, "battery") return end
            end
            local fuses = pickups("Fuse")
            if #fuses > 0 then grab(fuses[1], "fuse (" .. tostring(lp:GetAttribute("Fuses")) .. " held)") return end
            local box = fuseBox()
            if box and (lp:GetAttribute("Fuses") or 0) > 0 then
                grab({ m = box, p = posOf(box) }, "fuse box")
                return
            end
            local ex = exitTrigger()
            if ex then
                status = "Heading to exit"
                local res = walkTo(posOf(ex), 4)
                if res == "danger" then evade() end
                return
            end
            status = "Nothing to do (stage " .. stage() .. ")"
            task.wait(1)
        end)
        if not ok then slog("err " .. tostring(err)) task.wait(1) end
        task.wait(0.2)
    end
end)
return "IsekaiTrial started"
