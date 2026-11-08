local env = getgenv()
if env.__ARStop then pcall(env.__ARStop) end
local running = true
env.__ARStop = function() running = false end
env.__ARStatus = "starting"
local lp = game.Players.LocalPlayer

local function stage() return workspace:GetAttribute("Stage") or 1 end
local function inStage(o) local s = tostring(o:GetAttribute("Stages") or "") return s == "" or s:find(tostring(stage()), 1, true) end
local function posOf(o) if not o then return nil end if o:IsA("BasePart") then return o.Position end local ok, p = pcall(function() return o:GetPivot().Position end) return ok and p or nil end
local function hrp() local c = lp.Character return c and c:FindFirstChild("HumanoidRootPart") end
local function pz(prefix) return env.__IHPuzzle and env.__IHPuzzle(prefix) end

local function nearestPickup(kind)
    local pk = workspace.Map:FindFirstChild("Pickups")
    local r = hrp()
    local best, bd
    for _, m in ipairs(pk and pk:GetChildren() or {}) do
        local cd = m:FindFirstChildWhichIsA("ClickDetector", true)
        if m:GetAttribute("Kind") == kind and inStage(m) and cd and cd.MaxActivationDistance > 0 then
            local p = posOf(m)
            if p and r and (not bd or (p - r.Position).Magnitude < bd) then best, bd = p, (p - r.Position).Magnitude end
        end
    end
    return best
end

local skip = {}
local function key(p) return p and (math.floor(p.X / 4) .. "," .. math.floor(p.Z / 4)) or "" end
local function ok(p) return p and os.clock() > (skip[key(p)] or 0) end
local function target()
    local step = env.__IHNext and env.__IHNext() or ""
    local low = step:lower()
    local clues = env.__IHClues or {}
    if low:find("flashlight") then return nearestPickup("Flashlight"), step end
    if low:find("collect fuses") then
        local pk = workspace.Map:FindFirstChild("Pickups")
        for _, m in ipairs(pk and pk:GetChildren() or {}) do
            local cd = m:FindFirstChildWhichIsA("ClickDetector", true)
            if m:GetAttribute("Kind") == "Fuse" and inStage(m) and cd and cd.MaxActivationDistance > 0 and ok(posOf(m)) then return posOf(m), step end
        end
        step = "locked doors"
        low = step
    end
    if low:find("fuse box") then local f = pz("Fuses") local fp = posOf(f and f:FindFirstChild("FuseBox")) if ok(fp) then return fp, step end step = "locked doors" low = step end
    if low:find("generator") or low:find("power is out") then
        local g = pz("GasCans")
        if g then for _, b in ipairs(g:GetDescendants()) do local cd = b:FindFirstChildWhichIsA("ClickDetector") if cd and cd.MaxActivationDistance > 0 and b:IsA("BasePart") then return b.Position, step end end end
        local bg = pz("BackupGen") if bg then return posOf(bg:FindFirstChild("Hitbox", true) or bg), step end
        local br = pz("Breakers") if br then return posOf(br:FindFirstChild("Breaker3")), step end
    end
    if low:find("go to the exit") then
        for _, t in ipairs(workspace.EscapeTriggers:GetChildren()) do if t:GetAttribute("ExitStage") == stage() then return t.Position, step end end
    end
    local need = step:match("%-> (.+)$") or ""
    for name in need:gmatch("(%a+)") do
        if name == "Keypad" then
            if #(clues.radio or {}) == 0 then local r = pz("Radio") if r then return posOf(r:FindFirstChild("RadioButton")), "radio for keypad clue" end end
            if not env.__IHCode then local r = pz("Recorder") if r then return posOf(r:FindFirstChild("PlayButton")), "recorder for keypad clue" end end
        end
        if name == "Breakers" and (clues.recorder or "") == "" then local r = pz("Recorder") if r then return posOf(r:FindFirstChild("PlayButton")), "recorder for breakers" end end
        local p = pz(name)
        if p then
            local main = p:FindFirstChild("KeyEnter") or p:FindFirstChild("Dial2") or p:FindFirstChild("Panel2") or p:FindFirstChild("SeqStart")
                or p:FindFirstChild("Breaker3") or p:FindFirstChild("Ring2", true) or p:FindFirstChildWhichIsA("BasePart", true)
            if name == "Grates" and clues.cell then
                for _, m in ipairs(p:GetChildren()) do if (m:GetAttribute("Cell") or ""):gsub("%s", "") == clues.cell then main = m:FindFirstChild("Lid") end end
            end
            if name == "Plates" then
                local crates = p:FindFirstChild("Crates")
                local crate = crates and crates:FindFirstChildWhichIsA("BasePart")
                if crate then return crate.Position, "plates: pushing crate" end
            end
            return posOf(main), step
        end
    end
    local doors = workspace.Map:FindFirstChild("Doors")
    local ordered = {}
    for _, d in ipairs(doors and doors:GetChildren() or {}) do if not tostring(d:GetAttribute("Unlock")):find("Keypad") then ordered[#ordered + 1] = d end end
    for _, d in ipairs(doors and doors:GetChildren() or {}) do if tostring(d:GetAttribute("Unlock")):find("Keypad") then ordered[#ordered + 1] = d end end
    for _, d in ipairs(doors and doors:GetChildren() or {}) do
        local col = "" for _, p in ipairs(d:GetDescendants()) do if p.Name == "Lamp" then col = p.BrickColor.Name:lower() break end end
        if inStage(d) and tostring(d:GetAttribute("Unlock")) == "flag:Power" and col:find("red") then
            local cl = env.__IHClues or {}
            local br = pz("Breakers")
            if br then
                if (cl.recorder or "") == "" then local rc = pz("Recorder") if rc and ok(rc.PlayButton.Position) then return rc.PlayButton.Position, "recorder (breaker clue)" end end
                if ok(br.Breaker3.Position) then return br.Breaker3.Position, "Breakers for power" end
            end
        end
    end
    for _, d in ipairs(ordered) do
        local u = d:GetAttribute("Unlock") or ""
        local col = "" for _, p in ipairs(d:GetDescendants()) do if p.Name == "Lamp" then col = p.BrickColor.Name:lower() break end end
        if inStage(d) and u:find("puzzle:") and col:find("red") then
            for name in u:gmatch("puzzle:(%a+)_") do
                local p = pz(name)
                local main = p and (p:FindFirstChild("KeyEnter") or p:FindFirstChild("Dial2") or p:FindFirstChild("Panel2") or p:FindFirstChild("SeqStart") or p:FindFirstChildWhichIsA("BasePart", true))
                if name == "Plates" then local cr = p:FindFirstChild("Crates") main = cr and cr:FindFirstChildWhichIsA("BasePart") or main end
                if name == "Keypad" and not env.__IHCode then
                    local cl = env.__IHClues or {}
                    local nz = 0 for _, x in ipairs(cl.radio or {}) do if x > 0 then nz += 1 end end
                    local rad = pz("Radio")

                end
                if main and ok(main.Position) then return main.Position, "door " .. d.Name .. " -> " .. name end
            end
        end
    end
    return nil, step
end

local function pushCrates(p)
    local crates = p:FindFirstChild("Crates")
    local plates = {}
    for _, d in ipairs(p:GetChildren()) do if d:IsA("BasePart") and d.Name:match("^Plate%d+$") then plates[#plates + 1] = d end end
    local hum = lp.Character and lp.Character:FindFirstChildOfClass("Humanoid")
    if not (crates and hum) then return end
    for _, crate in ipairs(crates:GetChildren()) do
        if crate:IsA("BasePart") then
            local best, bd
            for _, pl in ipairs(plates) do
                local taken = false
                for _, c2 in ipairs(crates:GetChildren()) do if c2 ~= crate and c2:IsA("BasePart") and Vector3.new(c2.Position.X - pl.Position.X, 0, c2.Position.Z - pl.Position.Z).Magnitude < 2.5 then taken = true end end
                local dd = Vector3.new(crate.Position.X - pl.Position.X, 0, crate.Position.Z - pl.Position.Z).Magnitude
                if not taken and (not bd or dd < bd) then best, bd = pl, dd end
            end
            if best and bd > 1.5 then
                for _, axis in ipairs({ "X", "Z" }) do
                    for _ = 1, 6 do
                        if not running then return end
                        local delta = best.Position[axis] - crate.Position[axis]
                        if math.abs(delta) < 1 then break end
                        local dir = (axis == "X") and Vector3.new(math.sign(delta), 0, 0) or Vector3.new(0, 0, math.sign(delta))
                        local behind = crate.Position - dir * 4.5
                        env.__ARStatus = "plates: getting behind crate (" .. axis .. ")"
                        env.__ITwalk(Vector3.new(behind.X, crate.Position.Y, behind.Z), 1.5)
                        local goal = crate.Position + dir * math.min(math.abs(delta), 6)
                        env.__ARStatus = "plates: pushing crate (" .. axis .. ")"
                        hum:MoveTo(goal - dir * 1.5)
                        local t0 = os.clock()
                        repeat task.wait(0.1) until os.clock() - t0 > 3 or math.abs(best.Position[axis] - crate.Position[axis]) < 1
                    end
                end
            end
        end
    end
end

env.__ARTarget = function() return target() end
task.spawn(function()
    if not env.__ITwalk then pcall(function() loadstring(readfile("ConeHub/IsekaiTrial.lua"))() end) end
    env.__ITpause = true
    while running do
        local ok, err = pcall(function()
            if lp:GetAttribute("Caught") then env.__ARStatus = "caught - respawning" task.wait(2) return end
            local p, why = target()
            if not p then env.__ARStatus = "no target for: " .. tostring(why) task.wait(1.5) return end
            local r = hrp()
            if r and Vector3.new(p.X - r.Position.X, 0, p.Z - r.Position.Z).Magnitude < 6 then
                if tostring(why):lower():find("plates") then
                    local pp = pz("Plates")
                    if pp then
                        pushCrates(pp)
                        for _, led in ipairs(pp:GetChildren()) do
                            local n = led.Name:match("^PlateLed(%d+)$")
                            local plate = n and pp:FindFirstChild("Plate" .. n)
                            if plate and not led.BrickColor.Name:lower():find("green") then
                                env.__ARStatus = "standing on plate " .. n
                                env.__ITwalk(Vector3.new(plate.Position.X, plate.Position.Y + 3, plate.Position.Z), 1.2)
                                task.wait(2.5)
                            end
                        end
                    end
                end
                env.__ARStatus = "at target (" .. tostring(why) .. ") - letting Auto work"
                local map = { Symbols = "Symbols", DialLock = "Dial", Keypad = "Keypad", Breakers = "Breakers", Sequence = "Sequence", Grates = "Grate", EyeDial = "EyeDial" }
                for pname, act in pairs(map) do
                    if tostring(why):find(pname) and env.__IHActions and env.__IHActions[act] then
                        local okA, res = pcall(env.__IHActions[act])
                        env.__ARStatus = "solve " .. act .. ": " .. tostring(res)
                        task.wait(1)
                    end
                end
                local before = env.__IHNext and env.__IHNext()
                local t0 = os.clock()
                repeat task.wait(0.5) until os.clock() - t0 > 8 or (env.__IHNext and env.__IHNext() ~= before)
                return
            end
            env.__ARStatus = "walking: " .. tostring(why)
            local PFS = game:GetService("PathfindingService")
            local stand
            for _, off in ipairs({ Vector3.new(0,0,0), Vector3.new(-4,0,0), Vector3.new(4,0,0), Vector3.new(0,0,-4), Vector3.new(0,0,4), Vector3.new(-6,0,-6), Vector3.new(6,0,6), Vector3.new(-6,0,6), Vector3.new(6,0,-6) }) do
                local cand = Vector3.new(p.X + off.X, r.Position.Y, p.Z + off.Z)
                local path = PFS:CreatePath({ AgentRadius = 1.6, AgentHeight = 5, AgentCanJump = true })
                local okp = pcall(function() path:ComputeAsync(r.Position, cand) end)
                if okp and path.Status == Enum.PathStatus.Success then stand = cand break end
            end
            local res = "fail"
            if stand then
                local done = false
                task.spawn(function() res = env.__ITwalk(stand, 4) done = true end)
                local t0 = os.clock()
                repeat task.wait(0.2) until done or os.clock() - t0 > 25
                if not done then res = "fail" end
            end
            if res == "fail" then skip[key(p)] = os.clock() + 25 env.__ARStatus = "no path (skipping 25s): " .. tostring(why) end
        end)
        if not ok then env.__ARStatus = "err " .. tostring(err) task.wait(1) end
        task.wait(0.3)
    end
end)
return "autorun started"
