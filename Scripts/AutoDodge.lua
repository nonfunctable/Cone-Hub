local env = getgenv()
if env.__ADStop then pcall(env.__ADStop) end
local RunService = game:GetService("RunService")
local VIM = game:GetService("VirtualInputManager")
local lp = game.Players.LocalPlayer
local running = true
local controls
pcall(function() controls = require(lp.PlayerScripts:WaitForChild("PlayerModule", 5)):GetControls() end)
local controlling = false
local prev = {}
local lastDash = 0
env.__ADStatus = "idle"

local function setControl(on)
    if on == controlling then return end
    controlling = on

    if not on then
        local h = lp.Character and lp.Character:FindFirstChildOfClass("Humanoid")
        if h then h:Move(Vector3.zero) end
    end
end
local function tapKey(k)
    task.spawn(function()
        VIM:SendKeyEvent(true, k, false, game) task.wait(0.06) VIM:SendKeyEvent(false, k, false, game)
    end)
end

local DIRS = {}
for i = 0, 15 do local a = i * math.pi / 8 DIRS[#DIRS + 1] = Vector3.new(math.cos(a), 0, math.sin(a)) end
DIRS[#DIRS + 1] = Vector3.zero

local wantMove = nil
local function objective()
    for _, d in ipairs(lp.PlayerGui:GetDescendants()) do if d:IsA("TextLabel") and d.Visible and d.TextTransparency < 0.5 and d.Text:find("Objective") then return d.Text:lower() end end
    return ""
end
local objCache, objAt = "", 0
RunService:BindToRenderStep("ADMove", Enum.RenderPriority.Character.Value + 5, function()
    local h = lp.Character and lp.Character:FindFirstChildOfClass("Humanoid")
    if h and wantMove then h:Move(wantMove, false) end
    if h and os.clock() < (env.__ADJumpUntil or 0) then h.Jump = true end
end)
local lastPlan = 0
local conn = RunService.Heartbeat:Connect(function(dt)
    if not running then return end
    if os.clock() - lastPlan < 1 / 30 then return end
    lastPlan = os.clock()
    if os.clock() - objAt > 0.5 then objAt = os.clock() objCache = objective() end
    if env.__ADObey and objCache:find("nothing") then wantMove = nil env.__ADStatus = "objective: do nothing (standing still)" return end
    local c = lp.Character
    local root = c and c:FindFirstChild("HumanoidRootPart")
    local hum = c and c:FindFirstChildOfClass("Humanoid")
    local pulses = workspace:FindFirstChild("LocalPulseAttack")
    if root and hum and pulses then
        local core = pulses:FindFirstChild("PulseCore")
        for _, ring in ipairs(pulses:GetChildren()) do
            if ring.Name == "PulseRing" and ring:IsA("BasePart") and ring.Size.X > 4.5 then
                local center = core and core.Position or ring.Position
                local d = Vector3.new(root.Position.X - center.X, 0, root.Position.Z - center.Z).Magnitude
                local r = math.max(ring.Size.X, ring.Size.Z) / 2
                local key = ring
                local last = prev[key]
                local nowR = os.clock()
                prev[key] = { p = Vector3.new(r, 0, 0), t = nowR }
                local rate = (last and nowR > last.t) and (r - last.p.X) / (nowR - last.t) or 0
                local edgeR = r * 0.9
                local tReach = rate > 0.5 and (d - edgeR) / rate or math.huge
                env.__ADJumped = env.__ADJumped or setmetatable({}, { __mode = "k" })
                if rate > 0.5 and tReach < 0.3 and tReach > -0.05 and not env.__ADJumped[ring] and os.clock() - (env.__ADJump or 0) > 0.45 then
                    env.__ADJumped[ring] = true
                    env.__ADJump = os.clock()
                    env.__ADJumpUntil = os.clock() + 0.15
                    tapKey(Enum.KeyCode.Space)
                    env.__ADStatus = string.format("jumping ring (r=%.0f d=%.0f)", r, d)
                end
            end
        end
    end
    local folder = workspace:FindFirstChild("LocalBullets")
    local anyBullet = false
    if folder then for _, part in ipairs(folder:GetChildren()) do local g = part:FindFirstChildOfClass("BillboardGui") if g and g.Enabled then anyBullet = true break end end end
    local zones = {}
    for _, fo in ipairs(workspace:GetChildren()) do
        if fo:IsA("Folder") and fo.Name:find("Attack") and fo.Name ~= "LocalPulseAttack" and fo.Name ~= "PottedPlantAttack" then
            for _, z in ipairs(fo:GetDescendants()) do
                local n = z.Name:lower()
                if z:IsA("BasePart") and z.Transparency < 0.95 and (n:find("zone") or n:find("beam") or n:find("warn") or n:find("line") or n:find("lane") or n:find("rush") or n:find("impact") or n:find("telegraph")) then
                    local cf, sz = z.CFrame, z.Size
                    local long = math.max(sz.X, sz.Z)
                    local axis = (sz.X >= sz.Z) and cf.RightVector or cf.LookVector
                    local width = math.max(math.min(sz.X, sz.Z), math.max(sz.Y, 0) > 4 and sz.Y or 0)
                    local steps = math.max(1, math.floor(long / 4))
                    for i = 0, steps do
                        local off = (i / steps - 0.5) * long
                        zones[#zones + 1] = { p = cf.Position + axis * off, v = Vector3.zero, gold = false, r = width / 2 + 3 }
                    end
                end
            end
        end
    end
    env.__ADSeen = env.__ADSeen or {}
    for _, m in ipairs(workspace:GetChildren()) do
        if m:IsA("Model") and m ~= c and m:FindFirstChildOfClass("Humanoid") and not game.Players:GetPlayerFromCharacter(m) then
            local hr = m:FindFirstChild("HumanoidRootPart") or m.PrimaryPart
            if hr then
                local last = prev[m]
                local nowM = os.clock()
                local vel = (last and nowM > last.t) and (hr.Position - last.p) / (nowM - last.t) or Vector3.zero
                if vel.Magnitude > 300 then vel = Vector3.zero end
                prev[m] = { p = hr.Position, t = nowM }
                if vel.Magnitude > 20 or (root and (hr.Position - root.Position).Magnitude < 8) then
                    for k = 0, 6 do
                        zones[#zones + 1] = { p = hr.Position + vel * (k * 0.15), v = vel, gold = false, r = 5 }
                    end
                end
            end
        elseif not env.__ADSeen[m.Name] and (m:IsA("Folder") or m:IsA("Model")) and m ~= c then
            env.__ADSeen[m.Name] = true
            local kids = {}
            for _, d in ipairs(m:GetChildren()) do if #kids < 8 then kids[#kids + 1] = d.ClassName .. ":" .. d.Name end end
            pcall(appendfile, "ConeHub/domain_seen.txt", string.format("%.0f %s %s: %s\n", os.clock(), m.ClassName, m.Name, table.concat(kids, ",")))
        end
    end
    local plant = workspace:FindFirstChild("PottedPlantAttack")
    local lureTarget, mustLeave = nil, nil
    if plant and root then
        local boss = workspace:FindFirstChild("IsekaiGunter")
        if not boss then for _, m in ipairs(workspace:GetChildren()) do if m:IsA("Model") and m ~= c and m:FindFirstChildOfClass("Humanoid") and not game.Players:GetPlayerFromCharacter(m) then boss = m break end end end
        local bhr = boss and (boss:FindFirstChild("HumanoidRootPart") or boss.PrimaryPart)
        env.__ADZoneHist = env.__ADZoneHist or setmetatable({}, { __mode = "k" })
        for _, z in ipairs(plant:GetDescendants()) do
            if z:IsA("BasePart") and z.Name == "ImpactZone" then
                local h = env.__ADZoneHist[z]
                local moved = not h or (z.Position - h.p).Magnitude > 0.3
                if moved then env.__ADZoneHist[z] = { p = z.Position, still = os.clock() } end
                local stillFor = os.clock() - env.__ADZoneHist[z].still
                local rad = math.max(z.Size.Y, z.Size.Z, z.Size.X) / 2 + 3
                local dz = Vector3.new(root.Position.X - z.Position.X, 0, root.Position.Z - z.Position.Z).Magnitude
                local col = z.Color
                local hot = (col.R > 0.6 and col.G > 0.6 and col.B > 0.6) or stillFor > 0.15
                if hot and dz < rad + 2 then mustLeave = z.Position end
                if hot or not bhr then zones[#zones + 1] = { p = z.Position, v = Vector3.zero, gold = false, r = rad } end
            end
        end
        if bhr then lureTarget = bhr.Position end
    end
    env.__ADLure, env.__ADLeave = lureTarget, mustLeave
    local board = workspace:FindFirstChild("SliderBoardAttack")
    if board then
        local tileSize = 8
        local t0 = board:FindFirstChild("Tile_0_0")
        if t0 then tileSize = math.max(t0.Size.X, t0.Size.Z) end
        for _, t in ipairs(board:GetChildren()) do
            if t:IsA("BasePart") and t.Name:match("^Tile_") then
                local last = prev[t]
                local nowT = os.clock()
                local vel = (last and nowT > last.t) and (t.Position - last.p) / (nowT - last.t) or Vector3.zero
                prev[t] = { p = t.Position, t = nowT }
                if vel.Magnitude > 1 then
                    zones[#zones + 1] = { p = t.Position, v = vel, gold = false, r = tileSize / 2 + 2 }
                    zones[#zones + 1] = { p = t.Position + vel * 0.3, v = vel, gold = false, r = tileSize / 2 + 2 }
                end
            end
        end
        local hole = board:FindFirstChild("HoleMarker")
        if hole then zones[#zones + 1] = { p = hole.Position, v = Vector3.zero, gold = false, r = tileSize / 2 + 1.5 } end
    end
    for i = #(env.__ADSlams or {}), 1, -1 do
        local sl = env.__ADSlams[i]
        if os.clock() - sl.t > 0.8 then table.remove(env.__ADSlams, i) else zones[#zones + 1] = { p = sl.p, v = Vector3.zero, gold = false, r = 7 } end
    end
    do
        local BP = env.__ADBP or require(game:GetService("ReplicatedStorage").Shared.BulletPatterns)
        env.__ADBP = BP
        local st = workspace:GetServerTimeNow()
        local pats = env.__ADPatterns or {}
        for i = #pats, 1, -1 do if BP.endTime(pats[i]) < st then table.remove(pats, i) end end
        for _, pt in ipairs(pats) do
            if pt.t0 > st and pt.t0 - st < 1.2 then zones[#zones + 1] = { p = pt.origin, v = Vector3.zero, gold = false, r = 9 } end
            if root and (pt.origin - root.Position).Magnitude < 90 then
                for n = 0, BP.count(pt) - 1, 1 do
                    if n ~= pt.goldIndex then
                        local fut = BP.bulletAt(pt, n, st + 0.3)
                        if fut and (fut - root.Position).Magnitude < 25 then zones[#zones + 1] = { p = fut, v = Vector3.zero, gold = false, r = 4.2 } end
                    end
                end
            end
        end
    end
    local conv = workspace:FindFirstChild("LocalConveyor")
    local anyDoll = conv and conv:FindFirstChild("Doll", true) ~= nil
    if not (root and hum and (anyBullet or anyDoll or #zones > 0)) then wantMove = nil setControl(false) return end
    local bullets = {}
    for _, z in ipairs(zones) do bullets[#bullets + 1] = z end
    local now = os.clock()
    if anyDoll then
        for _, d in ipairs(conv:GetDescendants()) do
            if d.Name == "Doll" and (d:IsA("Model") or d:IsA("BasePart")) then
                local p = d:IsA("Model") and d:GetPivot().Position or d.Position
                local last = prev[d]
                local vel = Vector3.zero
                if last and now - last.t > 0 then vel = (p - last.p) / (now - last.t) end
                if vel.Magnitude > 200 then vel = Vector3.zero end
                prev[d] = { p = p, t = now }
                bullets[#bullets + 1] = { p = p, v = vel, gold = false }
            end
        end
    end
    for i, part in ipairs(folder and folder:GetChildren() or {}) do
        local gui = part:FindFirstChildOfClass("BillboardGui")
        if gui and gui.Enabled and part.Position.Y > -100 then
            local p = part.Position
            local last = prev[part]
            local vel = Vector3.zero
            if last and now - last.t > 0 then vel = (p - last.p) / (now - last.t) end
            if vel.Magnitude > 200 then vel = Vector3.zero end
            prev[part] = { p = p, t = now }
            bullets[#bullets + 1] = { p = p, v = vel, gold = gui.AlwaysOnTop }
        else
            prev[part] = nil
        end
    end
    if #bullets == 0 then wantMove = nil setControl(false) env.__ADStatus = "idle (no bullets)" return end
    setControl(true)
    local me = root.Position
    local speed = math.max(hum.WalkSpeed, 12)
    local T = 0.35
    local R = 4.2
    local best, bestScore, bestMin = Vector3.zero, -math.huge, 0
    for _, d in ipairs(DIRS) do
        local score, minD = 0, math.huge
        for _, s in ipairs({ 0.5, 1 }) do
            local fp = me + d * speed * T * s
            for _, b in ipairs(bullets) do
                local bp = b.p + b.v * T * s
                local dist = Vector3.new(fp.X - bp.X, 0, fp.Z - bp.Z).Magnitude
                if math.abs(fp.Y - bp.Y) > 6 then dist = dist + 6 end
                if b.gold then
                    score += 12 / math.max(dist, 0.8)
                else
                    local rr = b.r or R
                    if dist - (rr - R) < minD then minD = dist - (rr - R) end
                    if dist < rr * 2.2 then score -= (rr * 2.2 - dist) ^ 2 end
                end
            end
        end
        local fp = me + d * speed * T
        if d ~= Vector3.zero then
            local rp = RaycastParams.new() rp.FilterType = Enum.RaycastFilterType.Exclude rp.FilterDescendantsInstances = { c }
            for _, k in ipairs({ 1, 1.8 }) do
                local probe = me + d * speed * T * k
                local ignore = { c }
                local hit
                for _ = 1, 6 do
                    rp.FilterDescendantsInstances = ignore
                    hit = workspace:Raycast(probe + Vector3.new(0, 3, 0), Vector3.new(0, -14, 0), rp)
                    if not hit or hit.Instance.CanCollide then break end
                    ignore[#ignore + 1] = hit.Instance
                end
                if not hit then score -= 5000 end
            end
        end
        local bp = workspace:FindFirstChild("Baseplate")
        if bp then
            local rel = bp.CFrame:PointToObjectSpace(fp)
            local hx, hz = bp.Size.X / 2 - 12, bp.Size.Z / 2 - 12
            local edge = math.max(math.abs(rel.X) - hx, math.abs(rel.Z) - hz, 0)
            score -= edge * edge * 2
            score -= math.abs(Vector3.new(rel.X, 0, rel.Z).Magnitude - 25) * 0.35
            local cx, cz = math.abs(rel.X) / (bp.Size.X / 2), math.abs(rel.Z) / (bp.Size.Z / 2)
            if cx > 0.55 and cz > 0.55 then score -= (cx + cz - 1.1) * 60 end
        end
        if env.__ADLeave then
            local away = Vector3.new(fp.X - env.__ADLeave.X, 0, fp.Z - env.__ADLeave.Z).Magnitude
            score += away * 6
        elseif env.__ADLure then
            local rel = Vector3.new(me.X - env.__ADLure.X, 0, me.Z - env.__ADLure.Z)
            if rel.Magnitude < 0.5 then rel = Vector3.new(1, 0, 0) end
            local ang = math.atan2(rel.Z, rel.X) + 0.9
            local orbitPt = env.__ADLure + Vector3.new(math.cos(ang) * 6, 0, math.sin(ang) * 6)
            score -= Vector3.new(fp.X - orbitPt.X, 0, fp.Z - orbitPt.Z).Magnitude * 3
        end
        for _, o in ipairs(env.__ADOrigins or {}) do
            local od = Vector3.new(fp.X - o.X, 0, fp.Z - o.Z).Magnitude
            if od < 12 then score -= (12 - od) * 4 end
        end
        if d == Vector3.zero then score -= (#zones > 0 and 30 or 0.2) end
        if env.__ADLastDir and d ~= Vector3.zero then score += d:Dot(env.__ADLastDir) * 6 end
        if score > bestScore then best, bestScore, bestMin = d, score, minD end
    end
    wantMove = best
    env.__ADLastDir = (best ~= Vector3.zero) and best or nil
    env.__ADHist = env.__ADHist or {}
    local kinds = {}
    for _, fo in ipairs(workspace:GetChildren()) do if fo:IsA("Folder") or fo.Name:find("Attack") then kinds[#kinds + 1] = fo.Name end end
    table.insert(env.__ADHist, string.format("%.1f obj=%s hazards=%d closest=%.1f me=%d,%d move=%s pats=%d [%s]", os.clock(), objCache, #bullets, bestMin, me.X, me.Z, tostring(best), #(env.__ADPatterns or {}), table.concat(kinds, ",")))
    if #env.__ADHist > 90 then table.remove(env.__ADHist, 1) end
    env.__ADStatus = string.format("dodging %d bullets, closest %.1f", #bullets, bestMin)
    if bestMin < R and now - lastDash > 1.1 and best.Magnitude > 0 then
        lastDash = now
        pcall(function() root.CFrame = CFrame.lookAt(me, me + best) end)
        tapKey(Enum.KeyCode.Q)
    end
end)
env.__ADStop = function() running = false wantMove = nil for k in pairs(env.__ADHeld or {}) do pcall(function() VIM:SendKeyEvent(false, k, false, game) end) end env.__ADHeld = {} pcall(function() RunService:UnbindFromRenderStep("ADMove") end) conn:Disconnect() setControl(false) end

pcall(function()
    local rem = game:GetService("ReplicatedStorage").Remotes:FindFirstChild("SliderBoardFX")
    if rem then
        rem.OnClientEvent:Connect(function(kind, data)
            if kind == "Slam" and type(data) == "table" and typeof(data.position) == "Vector3" then
                env.__ADSlams = env.__ADSlams or {}
                table.insert(env.__ADSlams, { p = data.position, t = os.clock() })
            end
            if kind == "Begin" or kind == "Reveal" then
                task.wait(0.6)
                local lines = {}
                for _, m in ipairs(workspace:GetChildren()) do
                    if not m:IsA("Terrain") and not m:IsA("Camera") and m ~= lp.Character then
                        local parts, cols = 0, {}
                        for _, d in ipairs(m:GetDescendants()) do
                            if d:IsA("BasePart") then
                                parts += 1
                                local k = d.Name .. "/" .. d.BrickColor.Name .. "/" .. d.Material.Name .. "/T" .. string.format("%.1f", d.Transparency)
                                cols[k] = (cols[k] or 0) + 1
                            end
                        end
                        local cs = {}
                        for k, v in pairs(cols) do cs[#cs + 1] = k .. "x" .. v end
                        lines[#lines + 1] = m.ClassName .. ":" .. m.Name .. " parts=" .. parts .. " [" .. table.concat(cs, ", ") .. "]"
                    end
                end
                pcall(appendfile, "ConeHub/slider_board.txt", table.concat(lines, "\n") .. "\n----\n")
            end
        end)
    end
end)
pcall(function()
    local fx = game:GetService("ReplicatedStorage").Remotes:FindFirstChild("EncounterFX")
    if fx then
        env.__ADPatterns = {}
        fx.OnClientEvent:Connect(function(...)
            for _, a in ipairs({ ... }) do
                if type(a) == "table" and typeof(a.origin) == "Vector3" and a.perVolley and a.t0 then
                    table.insert(env.__ADPatterns, a)
                    env.__ADOrigins = env.__ADOrigins or {}
                    local known = false
                    for _, o in ipairs(env.__ADOrigins) do if (o - a.origin).Magnitude < 4 then known = true break end end
                    if not known then table.insert(env.__ADOrigins, a.origin) pcall(appendfile, "ConeHub/origins.txt", tostring(a.origin) .. "\n") end
                end
            end
        end)
    end
end)
task.spawn(function()
    while running do
        pcall(function()
            for _, d in ipairs(lp.PlayerGui:GetDescendants()) do
                if (d:IsA("TextButton") or d:IsA("ImageButton")) and d.Visible and d.AbsoluteSize.X > 0 then
                    local t = d:IsA("TextButton") and d.Text or ""
                    local lbl = d:FindFirstChildWhichIsA("TextLabel", true)
                    if (t .. (lbl and lbl.Text or "")):upper():find("AGAIN") then
                        local h = env.__ADHist or {}
                        local phase = "" for _, x in ipairs(lp.PlayerGui:GetDescendants()) do if x:IsA("TextLabel") and x.Visible and x.Text:upper():find("PHASE") then phase = x.Text break end end
                        pcall(appendfile, "ConeHub/deaths.txt", "=== DEFEAT " .. os.date("%H:%M:%S") .. " " .. phase .. "\n" .. table.concat(h, "\n", math.max(1, #h - 30)) .. "\n")
                        env.__ADHist = {}
                        task.wait(1.5)
                        local ok = pcall(function() for _, cn in ipairs(getconnections(d.Activated)) do cn:Fire() end end)
                        pcall(function() for _, cn in ipairs(getconnections(d.MouseButton1Click)) do cn:Fire() end end)
                        env.__ADStatus = "pressed AGAIN"
                        task.wait(3)
                    end
                end
            end
        end)
        task.wait(1)
    end
end)
return "auto-dodge armed"
