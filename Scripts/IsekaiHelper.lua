local env = getgenv()
if env.__IHStop then pcall(env.__IHStop) end
pcall(function() if isfile("ConeHub/IsekaiESP.lua") then loadstring(readfile("ConeHub/IsekaiESP.lua"))() end end)

local lp = game.Players.LocalPlayer
local conns, running = {}, true
local hooked = setmetatable({}, { __mode = "k" })
local clues = { radio = {}, recorder = "", glyphs = "", clock = "", crate = "", beacons = {}, cell = "" }

local function stage() return workspace:GetAttribute("Stage") or 1 end
local function puzzle(prefix)
    local po = workspace:FindFirstChild("PuzzleObjects")
    if not po then return nil end
    for _, f in ipairs(po:GetChildren()) do
        local s = tostring(f:GetAttribute("Stages") or "")
        if f.Name:match("^" .. prefix .. "_") and (s == "" or s:find(tostring(stage()), 1, true)) then return f end
    end
end
local function hrp() local c = lp.Character return c and c:FindFirstChild("HumanoidRootPart") end
local function near(part) local r = hrp() return r and part and (part.Position - r.Position).Magnitude < 9 end
local function click(part) local cd = part and part:FindFirstChildWhichIsA("ClickDetector") if cd then pcall(fireclickdetector, cd, 0) end end
local function textOf(part) local t = part and part:FindFirstChild("Text", true) return t and t.Text or "" end

local function readStatic()
    local decor = workspace:FindFirstChild("Map") and workspace.Map:FindFirstChild("Decor")
    local g = {}
    for _, d in ipairs(decor and decor:GetChildren() or {}) do
        if d.Name == "Glyph" then local t = d:FindFirstChild("Text", true) if t then g[#g + 1] = { y = d:GetPivot().Position.Y, s = t.Text } end end
        if d.Name == "Clock" then local t = d:FindFirstChild("Text", true) if t then clues.clock = t.Text end end
    end
    table.sort(g, function(a, b) return a.y > b.y end)
    local s = {} for _, x in ipairs(g) do s[#s + 1] = x.s end
    clues.glyphs = table.concat(s, "")
    clues.glyphList = s
    local props = workspace.Map:FindFirstChild("Props")
    local cd = props and props:FindFirstChild("CrateDigit")
    if cd then clues.crate = textOf(cd) end
end
local function hookRadio()
    local r = puzzle("Radio")
    if not r or hooked[r] then return end
    hooked[r] = true
    local lastBeep, cur = 0, 0
    clues.radio = {}
    conns[#conns + 1] = r.DescendantAdded:Connect(function(d)
        if not d:IsA("Sound") or not d.Name:find("Beep") then return end
        if os.clock() - lastBeep > 1.5 and cur > 0 then table.insert(clues.radio, cur) cur = 0 end
        lastBeep = os.clock()
        cur += 1
    end)
    task.spawn(function()
        while running do
            if cur > 0 and os.clock() - lastBeep > 1.5 then table.insert(clues.radio, cur) cur = 0 end
            task.wait(0.3)
        end
    end)
end
local function hookBeacons()
    local b = puzzle("Beacons")
    if not b or hooked[b] then return end
    hooked[b] = true
    local lastAt, cur = {}, {}
    conns[#conns + 1] = b.DescendantAdded:Connect(function(d)
        if not d:IsA("Sound") or not d.Name:find("Beep") then return end
        local sp = d.Parent and d.Parent.Name or "?"
        local n = tonumber(sp:match("%d+")) or 0
        if os.clock() - (lastAt[n] or 0) > 1.2 then
            if (cur[n] or 0) > 0 then clues.beacons[n] = cur[n] end
            cur[n] = 0
        end
        lastAt[n] = os.clock()
        cur[n] = (cur[n] or 0) + 1
    end)
    task.spawn(function()
        while running do
            for n, c in pairs(cur) do if c > 0 and os.clock() - (lastAt[n] or 0) > 1.2 then clues.beacons[n] = c cur[n] = 0 end end
            task.wait(0.3)
        end
    end)
end
local function readClipboard()
    local c = puzzle("Clipboard")
    if not c then clues.cell = "" return end
    local cell = c:FindFirstChild("Cell", true)
    clues.cell = cell and cell.Text:gsub("%s", "") or ""
end
local function hookRecorder()
    local r = puzzle("Recorder")
    if not r or hooked[r] then return end
    hooked[r] = true
    local lamp = r:FindFirstChild("Lamp")
    local buf = ""
    conns[#conns + 1] = r.DescendantAdded:Connect(function(d)
        if not d:IsA("Sound") then return end
        if d.Name == "BeepLong" then buf = buf .. "L" elseif d.Name == "BeepShort" then buf = buf .. "S" end
        clues.recorder = buf
    end)
    if lamp then conns[#conns + 1] = lamp:GetPropertyChangedSignal("Color"):Connect(function()
        if lamp.BrickColor.Name:lower():find("green") then buf = "" end
    end) end
end

local status
local actions = {}
actions.Symbols = function()
    local f = puzzle("Symbols")
    if not f then return "no Symbols puzzle this stage" end
    if not near(f:FindFirstChild("Panel2")) then return "stand at the Symbols panels" end
    local want = clues.glyphList or {}
    local np = 0
    for _, c in ipairs(f:GetChildren()) do if c.Name:match("^Panel%d+$") then np += 1 end end
    if #want < np then return "need " .. np .. " glyphs, found " .. #want end
    for i = 1, np do
        local p = f:FindFirstChild("Panel" .. i)
        local n = 0
        while textOf(p) ~= want[i] and n < 30 do click(p) n += 1 task.wait(0.22) end
    end
    return "set " .. table.concat(want, "")
end
actions.Dial = function()
    local f = puzzle("DialLock")
    if not f then return "no dial lock this stage" end
    if not near(f:FindFirstChild("Dial2")) then return "stand at the dial lock" end
    local digits = {}
    for d in (env.__IHDial or clues.clock):gmatch("%d") do digits[#digits + 1] = d end
    if #digits < 3 then return "no clock clue (type digits in the box)" end
    for i = 1, 3 do
        local p = f:FindFirstChild("Dial" .. i)
        local n = 0
        while textOf(p) ~= digits[i] and n < 12 do click(p) n += 1 task.wait(0.15) end
    end
    return "dial " .. table.concat(digits, "")
end
actions.Keypad = function()
    local f = puzzle("Keypad")
    if not f then return "no keypad this stage" end
    if not near(f:FindFirstChild("KeyEnter")) then return "stand at the keypad" end
    local code = env.__IHCode or ""
    if not code:match("^%d+$") then return "type the code in the box first" end
    click(f:FindFirstChild("KeyClear")) task.wait(0.25)
    for ch in code:gmatch("%d") do click(f:FindFirstChild("Key" .. ch)) task.wait(0.25) end
    click(f:FindFirstChild("KeyEnter"))
    return "entered " .. code
end
actions.Breakers = function()
    local f = puzzle("Breakers")
    if not f then return "no breakers this stage" end
    if not near(f:FindFirstChild("Breaker3")) then return "stand at the breakers" end
    local count = 0
    for _, b in ipairs(f:GetChildren()) do if b.Name:match("^Breaker%d+$") then count += 1 end end
    local pat = env.__IHBreak or clues.recorder:gsub("L", "U"):gsub("S", "D")
    if #pat ~= count then return "need " .. count .. " U/D (recorder gave " .. #pat .. ")" end
    for i = 1, count do
        local b = f:FindFirstChild("Breaker" .. i)
        local want = pat:sub(i, i) == "U"
        local n = 0
        while (b.Position.Y > 5.4) ~= want and n < 3 do click(b) n += 1 task.wait(0.45) end
    end
    return "breakers " .. pat
end
actions.Grate = function()
    local g = puzzle("Grates")
    if not g then return "no grates this stage" end
    if clues.cell == "" then return "clipboard cell not found" end
    for _, m in ipairs(g:GetChildren()) do
        if (m:GetAttribute("Cell") or ""):gsub("%s", "") == clues.cell then
            local lid = m:FindFirstChild("Lid")
            if not near(lid) then return "go to grate " .. clues.cell .. " (ESP 'GRATE')" end
            click(lid)
            return "opened grate " .. clues.cell
        end
    end
    return "no grate with cell " .. clues.cell
end
actions.View = function()
    local a = puzzle("Anamorph")
    if not a then return "no anamorph this stage" end
    local eye, look = a:GetAttribute("Eye"), a:GetAttribute("Look")
    if typeof(eye) ~= "Vector3" or typeof(look) ~= "Vector3" then return "anamorph attrs missing" end
    local cam = workspace.CurrentCamera
    local prevType = cam.CameraType
    cam.CameraType = Enum.CameraType.Scriptable
    local from = eye + Vector3.new(0, a:GetAttribute("EyeHeight") or 4.6, 0)
    local t0 = os.clock()
    while os.clock() - t0 < 6 do cam.CFrame = CFrame.lookAt(from, look) task.wait() end
    cam.CameraType = prevType
    return "camera view done (read the number)"
end
actions.EyeDial = function()
    local f = puzzle("EyeDial")
    if not f then return "no eye dial this stage" end
    if not near(f:FindFirstChild("Dial2")) then return "stand at the eye dial" end
    local digits = {}
    for d in (env.__IHDial or ""):gmatch("%d") do digits[#digits + 1] = d end
    if #digits < 3 then return "type the 3 digits in the dial box" end
    for i = 1, 3 do
        local p = f:FindFirstChild("Dial" .. i)
        local n = 0
        while textOf(p) ~= digits[i] and n < 12 do click(p) n += 1 task.wait(0.15) end
    end
    return "eye dial " .. table.concat(digits, "")
end
actions.Sequence = function()
    local f = puzzle("Sequence")
    if not f then return "no sequence this stage" end
    if not near(f:FindFirstChild("SeqStart")) then return "stand at the sequence panel" end
    local pads = {}
    for i = 1, 6 do local p = f:FindFirstChild("Seq" .. i) if p then pads[#pads + 1] = p end end
    local base = {}
    for i, p in ipairs(pads) do base[i] = p.Color end
    local function accepted()
        for _, m in ipairs(workspace.Map.Props:GetChildren()) do
            if m.Name == "Monitor" then
                for _, d in ipairs(m:GetDescendants()) do if d:IsA("TextLabel") and d.Visible and d.Text:find("ACCEPTED") then return true end end
            end
        end
    end
    local wasAccepted = accepted()
    local rounds = {}
    for round = 1, 15 do
        local flashes, last, lit = {}, os.clock(), {}
        local cs = {}
        for i, p in ipairs(pads) do
            cs[#cs + 1] = p:GetPropertyChangedSignal("Color"):Connect(function()
                local on = p.Color ~= base[i]
                if on and not lit[i] then flashes[#flashes + 1] = i last = os.clock() end
                lit[i] = on
            end)
        end
        if round == 1 then click(f:FindFirstChild("SeqStart")) end
        local t0 = os.clock()
        repeat
            task.wait(0.15)
            if round > 1 and #flashes == 0 and os.clock() - t0 > 3 and os.clock() - t0 < 3.2 then click(f:FindFirstChild("SeqStart")) end
        until (#flashes > 0 and os.clock() - last > 1.6) or os.clock() - t0 > 12
        for _, c in ipairs(cs) do c:Disconnect() end
        if #flashes == 0 then break end
        rounds[#rounds + 1] = table.concat(flashes, "")
        status.Text = "Sequence round " .. round .. ": " .. rounds[#rounds]
        task.wait(0.35)
        for _, i in ipairs(flashes) do click(pads[i]) task.wait(0.4) end
        task.wait(1.2)
        if not wasAccepted and accepted() then return "ACCEPTED after " .. round .. " rounds" end
    end
    return "rounds: " .. table.concat(rounds, " ")
end

local gui = Instance.new("ScreenGui")
gui.Name = "_ih" gui.ResetOnSpawn = false gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = (gethui and gethui()) or game:GetService("CoreGui")
local frame = Instance.new("Frame", gui)
frame.Size = UDim2.fromOffset(250, 420) frame.Position = UDim2.new(1, -270, 0.25, 0)
frame.BackgroundColor3 = Color3.fromRGB(20, 20, 26) frame.BorderSizePixel = 0 frame.Active = true frame.Draggable = true
Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 8)
local title = Instance.new("TextLabel", frame)
title.Size = UDim2.new(1, 0, 0, 26) title.BackgroundTransparency = 1 title.Font = Enum.Font.GothamBold title.TextSize = 14
title.TextColor3 = Color3.fromRGB(255, 90, 90) title.Text = "Isekai helper"
local info = Instance.new("TextLabel", frame)
info.Position = UDim2.fromOffset(10, 28) info.Size = UDim2.new(1, -20, 0, 120) info.BackgroundTransparency = 1
info.Font = Enum.Font.Code info.TextSize = 12 info.TextColor3 = Color3.fromRGB(220, 220, 220)
info.TextXAlignment = Enum.TextXAlignment.Left info.TextYAlignment = Enum.TextYAlignment.Top info.TextWrapped = true
status = Instance.new("TextLabel", frame)
status.Position = UDim2.fromOffset(10, 390) status.Size = UDim2.new(1, -20, 0, 24) status.BackgroundTransparency = 1
status.Font = Enum.Font.Gotham status.TextSize = 12 status.TextColor3 = Color3.fromRGB(120, 255, 140) status.Text = "ready"
local function box(y, placeholder, key)
    local b = Instance.new("TextBox", frame)
    b.Position = UDim2.fromOffset(10, y) b.Size = UDim2.new(1, -20, 0, 24)
    b.BackgroundColor3 = Color3.fromRGB(40, 40, 50) b.TextColor3 = Color3.new(1, 1, 1) b.Font = Enum.Font.Code b.TextSize = 13
    b.PlaceholderText = placeholder b.Text = "" b.ClearTextOnFocus = false
    Instance.new("UICorner", b).CornerRadius = UDim.new(0, 5)
    b.FocusLost:Connect(function() env[key] = (b.Text ~= "") and b.Text or nil env[key .. "User"] = (b.Text ~= "") or nil end)
end
box(150, "keypad code (e.g. 3654)", "__IHCode")
box(178, "dial / eye-dial digits (e.g. 317)", "__IHDial")
local y = 208
local names = { "Symbols", "Dial", "Keypad", "Breakers", "Sequence", "Grate", "View", "EyeDial", "Auto" }
actions.Auto = function() env.__IHAuto = not env.__IHAuto return "auto " .. (env.__IHAuto and "ON" or "OFF") end
for i, n in ipairs(names) do
    local b = Instance.new("TextButton", frame)
    local col, row = (i - 1) % 2, math.floor((i - 1) / 2)
    b.Position = UDim2.fromOffset(10 + col * 120, y + row * 32) b.Size = UDim2.fromOffset(110, 28)
    b.BackgroundColor3 = Color3.fromRGB(110, 60, 170) b.TextColor3 = Color3.new(1, 1, 1) b.Font = Enum.Font.GothamBold b.TextSize = 13 b.Text = n
    Instance.new("UICorner", b).CornerRadius = UDim.new(0, 6)
    b.MouseButton1Click:Connect(function()
        status.Text = n .. "..."
        task.spawn(function() local ok, res = pcall(actions[n]) status.Text = n .. ": " .. tostring(ok and res or ("error " .. tostring(res))) end)
    end)
end

task.spawn(function()
    while running do
        if clues._stage ~= stage() then clues._stage = stage() clues.radio = {} clues.recorder = "" clues.beacons = {} end
        pcall(function()
            if stage() == 1 and not env.__IHCodeUser then
                local rec = puzzle("Recorder")
                local ctr = rec and rec:FindFirstChild("Counter") and rec.Counter:FindFirstChild("Text", true)
                local cnt = ctr and ctr.Text:gsub("%D", "") or ""
                if #cnt == 2 and clues.crate ~= "" then env.__IHCode = "3" .. cnt .. clues.crate end
            end
        end)
        pcall(function()
            if stage() == 3 then
                local cc = workspace.Map.Decor:FindFirstChild("CeilCode")
                local t = cc and cc:FindFirstChild("Text", true)
                if t and not env.__IHCodeUser then env.__IHCode = (t.Text:gsub("%D", "")) end
                if not env.__IHDialUser then env.__IHDial = "317" end
            end
        end)
        pcall(readStatic) pcall(hookRadio) pcall(hookRecorder) pcall(hookBeacons) pcall(readClipboard)
        local fuses = lp:GetAttribute("Fuses")
        local bc = {} for i = 1, 3 do bc[i] = tostring(clues.beacons[i] or "?") end
        info.Text = string.format("Stage %s  fuses %s  gas %s  bat %s\nGlyphs (top>down): %s\nClock: %s   Crate digit: %s\nRadio bursts: %s\nRecorder: %s -> breakers %s\nBeacons ring1-3: %s\nClipboard grate cell: %s",
            tostring(stage()), tostring(fuses), tostring(lp:GetAttribute("GasCans")), tostring(math.floor(lp:GetAttribute("BatteryLevel") or 0)),
            clues.glyphs ~= "" and clues.glyphs or "?", clues.clock ~= "" and clues.clock or "?", clues.crate ~= "" and clues.crate or "?",
            #clues.radio > 0 and table.concat(clues.radio, ",") or "(press radio)",
            clues.recorder ~= "" and clues.recorder or "(press recorder)", (clues.recorder:gsub("L", "U"):gsub("S", "D")),
            table.concat(bc, ","), clues.cell ~= "" and clues.cell or "?")
        task.wait(0.5)
    end
end)
local banner = Instance.new("TextLabel", gui)
banner.AnchorPoint = Vector2.new(0.5, 0) banner.Position = UDim2.new(0.5, 0, 0, 6) banner.Size = UDim2.fromOffset(620, 30)
banner.BackgroundColor3 = Color3.fromRGB(20, 20, 26) banner.BackgroundTransparency = 0.15 banner.BorderSizePixel = 0
banner.Font = Enum.Font.GothamBold banner.TextSize = 16 banner.TextColor3 = Color3.fromRGB(255, 220, 90) banner.Text = "NEXT: ..."
Instance.new("UICorner", banner).CornerRadius = UDim.new(0, 8)
local function lampColor(d) for _, p in ipairs(d:GetDescendants()) do if p.Name == "Lamp" and p:IsA("BasePart") then return p.BrickColor.Name:lower() end end return "" end
local function nextStep()
    local st = tostring(stage())
    local function inStage(o) local s2 = tostring(o:GetAttribute("Stages") or "") return s2 == "" or s2:find(st, 1, true) end
    if not lp:GetAttribute("HasFlashlight") then return "Get the FLASHLIGHT (white ESP)" end
    local pk = workspace.Map:FindFirstChild("Pickups")
    local fusesLeft = 0
    for _, m in ipairs(pk and pk:GetChildren() or {}) do
        local cd = m:FindFirstChildWhichIsA("ClickDetector", true)
        if m:GetAttribute("Kind") == "Fuse" and inStage(m) and cd and cd.MaxActivationDistance > 0 then fusesLeft += 1 end
    end
    if fusesLeft > 0 then return "Collect FUSES (" .. fusesLeft .. " left, yellow ESP)" end
    if (lp:GetAttribute("Fuses") or 0) > 0 then return "Put fuses in the FUSE BOX" end
    if (lp:GetAttribute("GasCans") or 0) > 0 then return "Take gas cans to the BACKUP GENERATOR" end
    local doors = workspace.Map:FindFirstChild("Doors")
    for _, d in ipairs(doors and doors:GetChildren() or {}) do
        if inStage(d) then
            local col = lampColor(d)
            local u = d:GetAttribute("Unlock") or ""
            if u ~= "" and col:find("red") then
                local need = u:gsub("puzzle:", ""):gsub("flag:", "flag "):gsub("_E%d", ""):gsub("&", " + ")
                return "Unlock " .. d.Name:gsub("_E%d", "") .. " -> " .. need
            end
            if u ~= "" and (col:find("black") or col == "") then return "POWER is out: fix power (generator / fuse box / breakers)" end
        end
    end
    return "Go to the EXIT (green ESP)"
end
env.__IHNext = function() return nextStep() end
env.__IHActions = actions
env.__IHClues = clues
env.__IHPuzzle = puzzle
local CLUES = { Keypad = { "Radio", "Recorder" }, NubLock = { "BEACON" }, Grates = { "Clipboard" }, Breakers = { "Recorder" }, DialLock = {}, Symbols = {} }
local function focusFor(step)
    local f = { "GUNTER" }
    if (lp:GetAttribute("BatteryLevel") or 100) < 30 then f[#f + 1] = "Battery" end
    local low = step:lower()
    if low:find("flashlight") then f[#f + 1] = "Flashlight"
    elseif low:find("collect fuses") then f[#f + 1] = "Fuse_"
    elseif low:find("fuse box") then f[#f + 1] = "Fuses"
    elseif low:find("generator") then f[#f + 1] = "BackupGen" f[#f + 1] = "Gas"
    elseif low:find("power is out") then f[#f + 1] = "Breakers" f[#f + 1] = "BackupGen" f[#f + 1] = "Fuses" f[#f + 1] = "Gas"
    elseif low:find("exit") then f[#f + 1] = "EXIT"
    else
        for name in step:gmatch("(%a+)") do
            if CLUES[name] then
                f[#f + 1] = name
                for _, c in ipairs(CLUES[name]) do f[#f + 1] = c end
            end
        end
        if low:find("flag power") then f[#f + 1] = "Fuses" f[#f + 1] = "Fuse_" end
    end
    return f
end
task.spawn(function()
    while running do
        pcall(function()
            local step = nextStep()
            banner.Text = "NEXT: " .. step
            if env.__IHFocusESP ~= false then env.__ESPFocus = focusFor(step) end
        end)
        task.wait(0.7)
    end
end)

env.__IHAuto = (env.__IHAuto ~= false)
local doneAt, busy = {}, false
local function tryAuto(key, part, fn, cooldown)
    if busy or not part or not near(part) then return end
    if os.clock() - (doneAt[key] or -999) < (cooldown or 20) then return end
    doneAt[key] = os.clock()
    busy = true
    task.spawn(function()
        local ok, res = pcall(fn)
        status.Text = "auto " .. key .. ": " .. tostring(ok and res or res)
        busy = false
    end)
end
task.spawn(function()
    while running do
        if env.__IHAuto then
            pcall(function()
                local r = hrp()
                local pk = workspace.Map:FindFirstChild("Pickups")
                for _, m in ipairs(pk and pk:GetChildren() or {}) do
                    local cd = m:FindFirstChildWhichIsA("ClickDetector", true)
                    local st = tostring(m:GetAttribute("Stages") or "")
                    if cd and cd.MaxActivationDistance > 0 and (st == "" or st:find(tostring(stage()), 1, true)) then
                        local p = cd.Parent
                        if p:IsA("BasePart") and r and (p.Position - r.Position).Magnitude < cd.MaxActivationDistance - 1
                            and os.clock() - (doneAt["pick" .. m.Name] or 0) > 2 then
                            doneAt["pick" .. m.Name] = os.clock()
                            pcall(fireclickdetector, cd, 0)
                        end
                    end
                end
                local po = workspace:FindFirstChild("PuzzleObjects")
                for _, fo in ipairs(po and po:GetChildren() or {}) do
                    local st = tostring(fo:GetAttribute("Stages") or "")
                    if st == "" or st:find(tostring(stage()), 1, true) then
                        if fo.Name:match("^GasCans_") or fo.Name:match("^BackupGen_") or fo.Name:match("^Fuses_") then
                            for _, d in ipairs(fo:GetDescendants()) do
                                if d:IsA("ClickDetector") and d.MaxActivationDistance > 0 and d.Parent:IsA("BasePart") and r
                                    and (d.Parent.Position - r.Position).Magnitude < d.MaxActivationDistance - 1
                                    and os.clock() - (doneAt[d] or 0) > 3 then
                                    doneAt[d] = os.clock()
                                    pcall(fireclickdetector, d, 0)
                                end
                            end
                        end
                    end
                end
                local sym = puzzle("Symbols") tryAuto("Symbols", sym and sym:FindFirstChild("Panel2"), actions.Symbols, 30)
                local dl = puzzle("DialLock") if dl and (env.__IHDial or clues.clock ~= "") then tryAuto("Dial", dl:FindFirstChild("Dial2"), actions.Dial, 30) end
                local kp = puzzle("Keypad") if kp and env.__IHCode then tryAuto("Keypad", kp:FindFirstChild("KeyEnter"), actions.Keypad, 30) end
                local br = puzzle("Breakers") if br and (env.__IHBreak or clues.recorder ~= "") then tryAuto("Breakers", br:FindFirstChild("Breaker3"), actions.Breakers, 40) end
                local sq = puzzle("Sequence") tryAuto("Sequence", sq and sq:FindFirstChild("SeqStart"), actions.Sequence, 60)
                local gr = puzzle("Grates")
                if gr and clues.cell ~= "" then
                    for _, m in ipairs(gr:GetChildren()) do
                        if (m:GetAttribute("Cell") or ""):gsub("%s", "") == clues.cell then tryAuto("Grate", m:FindFirstChild("Lid"), actions.Grate, 30) end
                    end
                end
                local ed = puzzle("EyeDial") if ed and env.__IHDial then tryAuto("EyeDial", ed:FindFirstChild("Dial2"), actions.EyeDial, 30) end
                local rec = puzzle("Recorder") if rec and clues.recorder == "" then tryAuto("Recorder", rec:FindFirstChild("PlayButton"), function() click(rec.PlayButton) return "played" end, 30) end
                local rad = puzzle("Radio") if rad and #clues.radio == 0 then tryAuto("Radio", rad:FindFirstChild("RadioButton"), function() click(rad.RadioButton) return "played" end, 30) end
            end)
        end
        task.wait(0.4)
    end
end)
env.__IHStop = function() running = false for _, c in ipairs(conns) do pcall(function() c:Disconnect() end) end gui:Destroy() pcall(env.__ESPStop) end
return "helper loaded"
