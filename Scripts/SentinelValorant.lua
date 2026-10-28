-- HIGH LEVEL: Sentinel / Quick Match (Roblox Valorant) Legit Fluent UI Suite
if getgenv().__CONE_SENTINEL_CLEANUP then
    pcall(getgenv().__CONE_SENTINEL_CLEANUP)
end

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local Lighting = game:GetService("Lighting")
local HttpService = game:GetService("HttpService")
local CoreGui = game:GetService("CoreGui")

local LocalPlayer = Players.LocalPlayer

-- HIGH LEVEL: Restore Any Previously Hooked Game Functions (100% Vanilla Anti-Cheat Safe)
pcall(function()
    local orig = getgenv().__CONE_SENTINEL_ORIG_FUNCS
    if type(orig) == "table" then
        local mods = ReplicatedStorage:FindFirstChild("Modules")
        local gc = mods and mods:FindFirstChild("GunConfig") and require(mods.GunConfig)
        local wm = mods and mods:FindFirstChild("WeaponModule") and require(mods.WeaponModule)
        local pen = mods and mods:FindFirstChild("Penetration") and require(mods.Penetration)
        if gc then
            if orig.PatternOffset then gc.PatternOffset = orig.PatternOffset end
            if orig.SpringImpulse then gc.SpringImpulse = orig.SpringImpulse end
            if orig.Bloom then gc.Bloom = orig.Bloom end
            if orig.MovementError then gc.MovementError = orig.MovementError end
        end
        if wm and orig.StepRecoil then
            wm.StepRecoil = orig.StepRecoil
        end
        if pen and orig.PenWalk then
            pen.Walk = orig.PenWalk
        end
    end
end)

-- HIGH LEVEL: Persistent Auto-Save Configuration
local CONFIG_FOLDER = "ConeHub"
local CONFIG_FILE = "ConeHub/SentinelValorant_Settings.json"

local DefaultSettings = {
    EnemyESP = true,
    BotESP = true,
    TeammateESP = false,
    Box2D = true,
    Chams3D = true,
    HealthBar2D = true,
    NameTagESP = true,
    Tracers2D = false,
    DroppedESP = true,
    ShowHeadHB = false,

    AimAssist = false,
    AimPart = "HeadHB",
    AimMode = "Press B (Toggle)",
    AimFOV = 150,
    ShowFOV = true,
    AimSmooth = 4,
    AimWallCheck = true,
    AimIncludeBots = true,
    AimRCS = true,

    Triggerbot = false,
    TriggerDelay = 0.04,
    TriggerHoldKey = "Always On",

    StandaloneRCS = false,
    RCSStrength = 85,
    AutoReload = false,

    NoSmokeOverlay = false,
    AntiFlash = true,
    Fullbright = false,
    CustomFOVEnabled = false,
    CustomFOVValue = 95,
}

local State = {}
for k, v in pairs(DefaultSettings) do
    State[k] = v
end

local function loadSavedSettings()
    if type(getgenv().__CONE_SENTINEL_SAVED) == "table" then
        for k, v in pairs(getgenv().__CONE_SENTINEL_SAVED) do
            if DefaultSettings[k] ~= nil then
                State[k] = v
            end
        end
    end
    pcall(function()
        if isfile and readfile and isfile(CONFIG_FILE) then
            local raw = readfile(CONFIG_FILE)
            local decoded = HttpService:JSONDecode(raw)
            if type(decoded) == "table" then
                for k, v in pairs(decoded) do
                    if DefaultSettings[k] ~= nil then
                        State[k] = v
                    end
                end
            end
        end
    end)
    if State.AimMode == "Right Click (RMB)" then
        State.AimMode = "Press B (Toggle)"
    end
end

local function saveSettings()
    local exportTbl = {}
    for k in pairs(DefaultSettings) do
        exportTbl[k] = State[k]
    end
    getgenv().__CONE_SENTINEL_SAVED = exportTbl
    pcall(function()
        if makefolder and isfolder and not isfolder(CONFIG_FOLDER) then
            makefolder(CONFIG_FOLDER)
        end
        if writefile then
            writefile(CONFIG_FILE, HttpService:JSONEncode(exportTbl))
        end
    end)
end

loadSavedSettings()
State.Running = true

local Connections = {}
local CreatedInstances = {}
local EspCache = {}
local ItemEspCache = {}
local ModifiedNativeHighlights = {}
local OriginalLighting = {
    Brightness = Lighting.Brightness,
    ClockTime = Lighting.ClockTime,
    FogEnd = Lighting.FogEnd,
    GlobalShadows = Lighting.GlobalShadows,
    Ambient = Lighting.Ambient,
}

-- HIGH LEVEL: Clean Up Stale Overlays & Old Fluent Windows
pcall(function()
    for _, child in ipairs(CoreGui:GetChildren()) do
        if child.Name == "ConeSentinelOverlay" or child.Name == "ConeSentinelChamsFolder" then
            child:Destroy()
        elseif child:IsA("ScreenGui") and child.Name == "ScreenGui" then
            for _, d in ipairs(child:GetDescendants()) do
                if d:IsA("TextLabel") and d.Text:find("Cone Hub | Sentinel") then
                    child:Destroy()
                    break
                end
            end
        end
    end
end)

local WeaponModule = nil
pcall(function()
    local mods = ReplicatedStorage:FindFirstChild("Modules")
    if mods and mods:FindFirstChild("WeaponModule") then
        WeaponModule = require(mods.WeaponModule)
    end
end)

-- HIGH LEVEL: Target Discovery (Real Match Enemies + Range Dummies + DM Bots)
local function getGamemode()
    local gi = ReplicatedStorage:FindFirstChild("GameInfo")
    local gm = gi and gi:FindFirstChild("Gamemode")
    return gm and gm.Value or ""
end

local function getLocalTeam()
    local st = LocalPlayer and LocalPlayer:FindFirstChild("Status")
    local tv = st and st:FindFirstChild("TeamValue")
    return tv and tv.Value or ""
end

local function isEnemyPlayer(plr)
    if not plr or plr == LocalPlayer then return false end
    if getGamemode() == "Deathmatch" then return true end
    local myTeam = getLocalTeam()
    local st = plr:FindFirstChild("Status")
    local tv = st and st:FindFirstChild("TeamValue")
    local theirTeam = tv and tv.Value or ""
    if myTeam == "" or theirTeam == "" then return true end
    return myTeam ~= theirTeam
end

local function collectCombatEntities()
    local list = {}

    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer and plr.Character then
            local char = plr.Character
            local hum = char:FindFirstChildOfClass("Humanoid")
            local hrp = char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("UpperTorso")
            local st = plr:FindFirstChild("Status")
            local alive = (not st or not st:FindFirstChild("Alive")) and true or st.Alive.Value
            if hum and hrp and hum.Health > 0 and alive then
                local enemy = isEnemyPlayer(plr)
                local agentVal = plr:FindFirstChild("Agent")
                local eqVal = st and st:FindFirstChild("Equipped")
                table.insert(list, {
                    instance = char,
                    name = plr.Name,
                    sub = (agentVal and agentVal.Value ~= "" and agentVal.Value) or "Agent",
                    weapon = (eqVal and eqVal.Value ~= "" and eqVal.Value) or "",
                    hp = math.floor(hum.Health),
                    maxHp = math.max(1, math.floor(hum.MaxHealth)),
                    root = hrp,
                    head = char:FindFirstChild("HeadHB") or char:FindFirstChild("Head") or hrp,
                    kind = enemy and "Enemy" or "Teammate",
                })
            end
        end
    end

    local geom = Workspace:FindFirstChild("Geometry")
    local map = geom and geom:FindFirstChild("Map")
    local tp = map and map:FindFirstChild("Target Practice")
    if tp then
        for _, bot in ipairs(tp:GetChildren()) do
            if bot:IsA("Model") then
                local hum = bot:FindFirstChildOfClass("Humanoid")
                local hrp = bot:FindFirstChild("HumanoidRootPart") or bot:FindFirstChild("UpperTorso")
                if hum and hrp and hum.Health > 0 then
                    table.insert(list, {
                        instance = bot,
                        name = bot.Name,
                        sub = "Training Dummy",
                        weapon = "Range",
                        hp = math.floor(hum.Health),
                        maxHp = math.max(1, math.floor(hum.MaxHealth)),
                        root = hrp,
                        head = bot:FindFirstChild("HeadHB") or bot:FindFirstChild("Head") or hrp,
                        kind = "Bot",
                    })
                end
            end
        end
    end

    local dmBots = Workspace:FindFirstChild("DeathmatchBots")
    if dmBots then
        for _, bot in ipairs(dmBots:GetChildren()) do
            if bot:IsA("Model") then
                local hum = bot:FindFirstChildOfClass("Humanoid")
                local hrp = bot:FindFirstChild("HumanoidRootPart") or bot:FindFirstChild("UpperTorso")
                if hum and hrp and hum.Health > 0 then
                    table.insert(list, {
                        instance = bot,
                        name = bot.Name,
                        sub = "DM Bot",
                        weapon = "Bot",
                        hp = math.floor(hum.Health),
                        maxHp = math.max(1, math.floor(hum.MaxHealth)),
                        root = hrp,
                        head = bot:FindFirstChild("HeadHB") or bot:FindFirstChild("Head") or hrp,
                        kind = "Bot",
                    })
                end
            end
        end
    end

    return list
end

-- HIGH LEVEL: Visibility & Target Selection
local VisRayParams = RaycastParams.new()
VisRayParams.FilterType = Enum.RaycastFilterType.Exclude
VisRayParams.IgnoreWater = true

local function updateRayFilter(cam)
    local filter = { cam }
    if LocalPlayer.Character then table.insert(filter, LocalPlayer.Character) end
    local geom = Workspace:FindFirstChild("Geometry")
    if geom then
        if geom:FindFirstChild("Ray_Ignore") then table.insert(filter, geom.Ray_Ignore) end
        if geom:FindFirstChild("Map") and geom.Map:FindFirstChild("Ray_Ignore") then
            table.insert(filter, geom.Map.Ray_Ignore)
        end
    end
    VisRayParams.FilterDescendantsInstances = filter
end

local function isTargetVisible(targetPart, targetModel)
    local cam = Workspace.CurrentCamera
    if not cam or not targetPart then return false end
    updateRayFilter(cam)

    local origin = cam.CFrame.Position
    local dir = targetPart.Position - origin
    local res = Workspace:Raycast(origin, dir, VisRayParams)
    if not res then return true end
    if targetModel and res.Instance:IsDescendantOf(targetModel) then
        return true
    end
    return false
end

local function findClosestAimTarget()
    local cam = Workspace.CurrentCamera
    if not cam then return nil, nil end
    local viewportCenter = cam.ViewportSize * 0.5
    local bestPart = nil
    local bestEnt = nil
    local bestDist = State.AimFOV

    local entities = collectCombatEntities()
    for _, ent in ipairs(entities) do
        local validKind = (ent.kind == "Enemy") or (ent.kind == "Bot" and State.AimIncludeBots)
        if validKind and ent.instance then
            local part = ent.instance:FindFirstChild(State.AimPart)
                or ent.instance:FindFirstChild("HeadHB")
                or ent.instance:FindFirstChild("Head")
                or ent.root
            if part then
                local screenPos, onScreen = cam:WorldToViewportPoint(part.Position)
                if onScreen and screenPos.Z > 0 then
                    local dist2D = (Vector2.new(screenPos.X, screenPos.Y) - viewportCenter).Magnitude
                    if dist2D <= bestDist then
                        if not State.AimWallCheck or isTargetVisible(part, ent.instance) then
                            bestDist = dist2D
                            bestPart = part
                            bestEnt = ent
                        end
                    end
                end
            end
        end
    end

    return bestPart, bestEnt
end

-- HIGH LEVEL: 2D & 3D ESP Overlay Construction
local OverlayGui = Instance.new("ScreenGui")
OverlayGui.Name = "ConeSentinelOverlay"
OverlayGui.ResetOnSpawn = false
OverlayGui.IgnoreGuiInset = true
OverlayGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
pcall(function() OverlayGui.Parent = CoreGui end)
if not OverlayGui.Parent then
    OverlayGui.Parent = LocalPlayer:WaitForChild("PlayerGui")
end
table.insert(CreatedInstances, OverlayGui)

local ChamsFolder = Instance.new("Folder")
ChamsFolder.Name = "ConeSentinelChamsFolder"
pcall(function() ChamsFolder.Parent = CoreGui end)
if not ChamsFolder.Parent then
    ChamsFolder.Parent = Workspace
end
table.insert(CreatedInstances, ChamsFolder)

local FovCircle = Instance.new("Frame")
FovCircle.Name = "FOVCircle"
FovCircle.AnchorPoint = Vector2.new(0.5, 0.5)
FovCircle.Position = UDim2.fromScale(0.5, 0.5)
FovCircle.Size = UDim2.fromOffset(State.AimFOV * 2, State.AimFOV * 2)
FovCircle.BackgroundTransparency = 1
FovCircle.Visible = State.ShowFOV
FovCircle.Parent = OverlayGui

local FovCorner = Instance.new("UICorner")
FovCorner.CornerRadius = UDim.new(1, 0)
FovCorner.Parent = FovCircle

local FovStroke = Instance.new("UIStroke")
FovStroke.Color = Color3.fromRGB(255, 75, 90)
FovStroke.Thickness = 1.5
FovStroke.Transparency = 0.2
FovStroke.Parent = FovCircle

local AimStatusBadge = Instance.new("TextLabel")
AimStatusBadge.Name = "AimStatusBadge"
AimStatusBadge.AnchorPoint = Vector2.new(0.5, 0)
AimStatusBadge.Position = UDim2.new(0.5, 0, 0, 42)
AimStatusBadge.Size = UDim2.fromOffset(180, 24)
AimStatusBadge.BackgroundColor3 = Color3.fromRGB(18, 18, 24)
AimStatusBadge.BackgroundTransparency = 0.25
AimStatusBadge.Font = Enum.Font.GothamBold
AimStatusBadge.TextSize = 12
AimStatusBadge.TextColor3 = State.AimAssist and Color3.fromRGB(80, 255, 130) or Color3.fromRGB(255, 90, 90)
AimStatusBadge.Text = State.AimAssist and "AIMBOT [B]: ON" or "AIMBOT [B]: OFF"
AimStatusBadge.Parent = OverlayGui

local BadgeCorner = Instance.new("UICorner")
BadgeCorner.CornerRadius = UDim.new(0, 6)
BadgeCorner.Parent = AimStatusBadge

local BadgeStroke = Instance.new("UIStroke")
BadgeStroke.Thickness = 1
BadgeStroke.Color = State.AimAssist and Color3.fromRGB(80, 255, 130) or Color3.fromRGB(255, 90, 90)
BadgeStroke.Transparency = 0.35
BadgeStroke.Parent = AimStatusBadge

local function updateAimBadge()
    AimStatusBadge.Text = State.AimAssist and "AIMBOT [B]: ON" or "AIMBOT [B]: OFF"
    local col = State.AimAssist and Color3.fromRGB(80, 255, 130) or Color3.fromRGB(255, 90, 90)
    AimStatusBadge.TextColor3 = col
    BadgeStroke.Color = col
    FovStroke.Color = State.AimAssist and Color3.fromRGB(80, 255, 130) or Color3.fromRGB(255, 75, 90)
end

local COLORS = {
    Enemy = Color3.fromRGB(255, 65, 80),
    Bot = Color3.fromRGB(255, 170, 35),
    Teammate = Color3.fromRGB(55, 235, 130),
    Item = Color3.fromRGB(255, 225, 75),
}

local function createEspEntry(inst)
    local hl = Instance.new("Highlight")
    hl.Name = "ConeSentinelHL"
    hl.Adornee = inst
    hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    hl.FillTransparency = 0.62
    hl.OutlineTransparency = 0.05
    hl.Parent = ChamsFolder

    local boxFrame = Instance.new("Frame")
    boxFrame.Name = "Box2D"
    boxFrame.BackgroundTransparency = 1
    boxFrame.BorderSizePixel = 0
    boxFrame.Visible = false
    boxFrame.Parent = OverlayGui

    local boxOutline = Instance.new("UIStroke")
    boxOutline.Thickness = 1.5
    boxOutline.Color = COLORS.Enemy
    boxOutline.Parent = boxFrame

    local hpBarBg = Instance.new("Frame")
    hpBarBg.Name = "HPBg"
    hpBarBg.AnchorPoint = Vector2.new(1, 0)
    hpBarBg.Position = UDim2.new(0, -4, 0, 0)
    hpBarBg.Size = UDim2.new(0, 3, 1, 0)
    hpBarBg.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
    hpBarBg.BorderSizePixel = 0
    hpBarBg.Parent = boxFrame

    local hpBarFill = Instance.new("Frame")
    hpBarFill.Name = "HPFill"
    hpBarFill.AnchorPoint = Vector2.new(0, 1)
    hpBarFill.Position = UDim2.fromScale(0, 1)
    hpBarFill.Size = UDim2.fromScale(1, 1)
    hpBarFill.BackgroundColor3 = Color3.fromRGB(80, 255, 120)
    hpBarFill.BorderSizePixel = 0
    hpBarFill.Parent = hpBarBg

    local nameLbl = Instance.new("TextLabel")
    nameLbl.Name = "Tag"
    nameLbl.AnchorPoint = Vector2.new(0.5, 1)
    nameLbl.Position = UDim2.new(0.5, 0, 0, -3)
    nameLbl.Size = UDim2.fromOffset(200, 28)
    nameLbl.BackgroundTransparency = 1
    nameLbl.Font = Enum.Font.GothamBold
    nameLbl.TextSize = 12
    nameLbl.TextColor3 = Color3.new(1, 1, 1)
    nameLbl.TextStrokeTransparency = 0.15
    nameLbl.TextStrokeColor3 = Color3.new(0, 0, 0)
    nameLbl.RichText = true
    nameLbl.Parent = boxFrame

    local tracer = Instance.new("Frame")
    tracer.Name = "Tracer"
    tracer.AnchorPoint = Vector2.new(0.5, 0.5)
    tracer.BackgroundColor3 = COLORS.Enemy
    tracer.BorderSizePixel = 0
    tracer.Visible = false
    tracer.Parent = OverlayGui

    local entry = {
        highlight = hl,
        box = boxFrame,
        stroke = boxOutline,
        hpBg = hpBarBg,
        hpFill = hpBarFill,
        label = nameLbl,
        tracer = tracer,
    }
    EspCache[inst] = entry
    return entry
end

local function restoreNativeHighlight(nativeHL)
    if nativeHL and nativeHL.Parent then
        pcall(function()
            nativeHL.DepthMode = Enum.HighlightDepthMode.Occluded
            nativeHL.FillTransparency = 1
        end)
    end
end

local function removeEspEntry(inst)
    local entry = EspCache[inst]
    if entry then
        pcall(function() entry.highlight:Destroy() end)
        pcall(function() entry.box:Destroy() end)
        pcall(function() entry.tracer:Destroy() end)
        EspCache[inst] = nil
    end
    if inst then
        local nativeHL = inst:FindFirstChild("EnemyHightlight") or inst:FindFirstChild("TeammateHightlight")
        if nativeHL then
            restoreNativeHighlight(nativeHL)
            ModifiedNativeHighlights[nativeHL] = nil
        end
    end
end

local function updateAllESP()
    local cam = Workspace.CurrentCamera
    if not cam then return end
    local camPos = cam.CFrame.Position
    local vpSize = cam.ViewportSize
    local bottomCenter = Vector2.new(vpSize.X * 0.5, vpSize.Y - 12)

    local entities = collectCombatEntities()
    local seen = {}

    for _, ent in ipairs(entities) do
        local enabledForKind = false
        if ent.kind == "Enemy" and State.EnemyESP then enabledForKind = true
        elseif ent.kind == "Bot" and State.BotESP then enabledForKind = true
        elseif ent.kind == "Teammate" and State.TeammateESP then enabledForKind = true
        end

        local headHB = ent.instance:FindFirstChild("HeadHB")
        if headHB and headHB:IsA("BasePart") then
            headHB.Transparency = State.ShowHeadHB and 0.55 or 1
            if State.ShowHeadHB then
                headHB.Color = Color3.fromRGB(255, 50, 80)
                headHB.Material = Enum.Material.Neon
            end
        end

        if enabledForKind and ent.instance and ent.root then
            seen[ent.instance] = true
            local entry = EspCache[ent.instance] or createEspEntry(ent.instance)
            local col = COLORS[ent.kind] or COLORS.Enemy

            local nativeHL = ent.instance:FindFirstChild("EnemyHightlight") or ent.instance:FindFirstChild("TeammateHightlight")
            if nativeHL and nativeHL:IsA("Highlight") then
                entry.highlight.Enabled = false
                ModifiedNativeHighlights[nativeHL] = true
                if State.Chams3D then
                    nativeHL.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
                    nativeHL.FillColor = col
                    nativeHL.OutlineColor = col
                    nativeHL.FillTransparency = 0.58
                    nativeHL.OutlineTransparency = 0.05
                    nativeHL.Enabled = true
                else
                    restoreNativeHighlight(nativeHL)
                end
            else
                entry.highlight.Enabled = State.Chams3D
                entry.highlight.FillColor = col
                entry.highlight.OutlineColor = col
            end

            local topWorld = (ent.head and ent.head.Position or ent.root.Position) + Vector3.new(0, 1.4, 0)
            local botWorld = ent.root.Position - Vector3.new(0, 3.1, 0)
            local topVp, topOn = cam:WorldToViewportPoint(topWorld)
            local botVp, botOn = cam:WorldToViewportPoint(botWorld)

            if (topOn or botOn) and topVp.Z > 0 and botVp.Z > 0 then
                local h = math.clamp(math.abs(botVp.Y - topVp.Y), 16, vpSize.Y * 1.2)
                local w = math.clamp(h * 0.62, 12, vpSize.X * 0.8)
                local cx = (topVp.X + botVp.X) * 0.5
                local cy = (topVp.Y + botVp.Y) * 0.5

                entry.box.Visible = true
                entry.box.Position = UDim2.fromOffset(cx - w * 0.5, cy - h * 0.5)
                entry.box.Size = UDim2.fromOffset(w, h)
                entry.stroke.Enabled = State.Box2D
                entry.stroke.Color = col

                entry.hpBg.Visible = State.HealthBar2D
                local hpRatio = math.clamp(ent.hp / math.max(1, ent.maxHp), 0, 1)
                entry.hpFill.Size = UDim2.fromScale(1, hpRatio)
                entry.hpFill.BackgroundColor3 = Color3.fromHSV(hpRatio * 0.33, 0.9, 1)

                entry.label.Visible = State.NameTagESP
                if State.NameTagESP then
                    local distMeters = math.floor(((ent.root.Position - camPos).Magnitude / 3.6428) + 0.5)
                    local wepStr = (ent.weapon ~= "" and ent.weapon ~= "Range" and (" [" .. ent.weapon .. "]")) or ""
                    entry.label.TextColor3 = col
                    entry.label.Text = string.format(
                        "%s%s\n<font color='rgb(255,255,255)'>%d HP | %dm</font>",
                        ent.name,
                        wepStr,
                        ent.hp,
                        distMeters
                    )
                end

                if State.Tracers2D then
                    local targetPt = Vector2.new(cx, cy + h * 0.5)
                    local delta = targetPt - bottomCenter
                    local len = delta.Magnitude
                    entry.tracer.Visible = true
                    entry.tracer.BackgroundColor3 = col
                    entry.tracer.Position = UDim2.fromOffset((bottomCenter.X + targetPt.X) * 0.5, (bottomCenter.Y + targetPt.Y) * 0.5)
                    entry.tracer.Size = UDim2.fromOffset(len, 1.5)
                    entry.tracer.Rotation = math.deg(math.atan2(delta.Y, delta.X))
                else
                    entry.tracer.Visible = false
                end
            else
                entry.box.Visible = false
                entry.tracer.Visible = false
            end
        end
    end

    for inst in pairs(EspCache) do
        if not seen[inst] or not inst.Parent then
            removeEspEntry(inst)
        end
    end

    local seenItems = {}
    if State.DroppedESP then
        local geom = Workspace:FindFirstChild("Geometry")
        if geom then
            local containers = { geom:FindFirstChild("DroppedItems"), geom:FindFirstChild("Debris") }
            for _, folder in ipairs(containers) do
                if folder then
                    for _, item in ipairs(folder:GetChildren()) do
                        local isSpike = item.Name:upper():find("SPIKE") or item.Name:upper():find("BOMB")
                        if folder.Name == "DroppedItems" or isSpike then
                            local part = item:IsA("BasePart") and item or item:FindFirstChildWhichIsA("BasePart", true)
                            if part then
                                seenItems[item] = true
                                local lbl = ItemEspCache[item]
                                if not lbl then
                                    lbl = Instance.new("TextLabel")
                                    lbl.Size = UDim2.fromOffset(140, 20)
                                    lbl.AnchorPoint = Vector2.new(0.5, 0.5)
                                    lbl.BackgroundTransparency = 1
                                    lbl.Font = Enum.Font.GothamBold
                                    lbl.TextSize = 12
                                    lbl.TextColor3 = isSpike and Color3.fromRGB(255, 80, 255) or COLORS.Item
                                    lbl.TextStrokeTransparency = 0.15
                                    lbl.Parent = OverlayGui
                                    ItemEspCache[item] = lbl
                                end
                                local vp, onScr = cam:WorldToViewportPoint(part.Position)
                                if onScr and vp.Z > 0 then
                                    local distM = math.floor(((part.Position - camPos).Magnitude / 3.6428) + 0.5)
                                    lbl.Visible = true
                                    lbl.Position = UDim2.fromOffset(vp.X, vp.Y)
                                    lbl.Text = string.format("[%s] %dm", isSpike and "SPIKE" or item.Name, distM)
                                else
                                    lbl.Visible = false
                                end
                            end
                        end
                    end
                end
            end
        end
    end
    for item, lbl in pairs(ItemEspCache) do
        if not seenItems[item] or not item.Parent then
            pcall(function() lbl:Destroy() end)
            ItemEspCache[item] = nil
        end
    end
end

-- HIGH LEVEL: Legit Camera Aim Assist, RCS & Triggerbot Loop
local function isAimActiveNow()
    if not State.AimAssist then return false end
    if State.AimMode == "Press B (Toggle)" or State.AimMode == "Always Active" then
        return true
    elseif State.AimMode == "Hold Left Click (LMB)" then
        return UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1)
    elseif State.AimMode == "Hold Right Click (RMB)" then
        return UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2)
    end
    return true
end

local lastTriggerFire = 0
local lastAutoReload = 0
local prevRcsPitch = 0
local prevRcsYaw = 0

local function stepCombatAndVisuals()
    local cam = Workspace.CurrentCamera
    if not cam then return end

    FovCircle.Visible = State.ShowFOV
    FovCircle.Size = UDim2.fromOffset(State.AimFOV * 2, State.AimFOV * 2)
    updateAimBadge()

    if State.CustomFOVEnabled then
        cam.FieldOfView = State.CustomFOVValue
    end

    if State.NoSmokeOverlay then
        local pg = LocalPlayer:FindFirstChild("PlayerGui")
        local smoke = pg and pg:FindFirstChild("SmokeHazeOverlay")
        if smoke and smoke:IsA("ScreenGui") then
            smoke.Enabled = false
        end
    end

    if State.AntiFlash then
        local stun = cam:FindFirstChild("Stun")
        if stun then
            pcall(function() stun:Destroy() end)
        end
    end

    if State.AutoReload and WeaponModule and os.clock() - lastAutoReload > 0.6 then
        local st = LocalPlayer:FindFirstChild("Status")
        local eq = st and st:FindFirstChild("Equipped") and st.Equipped.Value
        local inv = LocalPlayer:FindFirstChild("Inventory")
        local gunFolder = eq and inv and inv:FindFirstChild(eq)
        if gunFolder and gunFolder:FindFirstChild("Ammo") and gunFolder:FindFirstChild("StoredAmmo") then
            if gunFolder.Ammo.Value <= 0 and gunFolder.StoredAmmo.Value > 0 then
                lastAutoReload = os.clock()
                task.spawn(function()
                    pcall(function() WeaponModule:reload() end)
                end)
            end
        end
    end

    local aimPitch = (WeaponModule and tonumber(WeaponModule.AimPitch)) or 0
    local aimYaw = (WeaponModule and tonumber(WeaponModule.AimYaw)) or 0

    local lockedTarget = false
    if isAimActiveNow() then
        local targetPart = findClosestAimTarget()
        if targetPart then
            lockedTarget = true
            local goalCF = CFrame.lookAt(cam.CFrame.Position, targetPart.Position)
            if State.AimRCS and (math.abs(aimPitch) > 0.001 or math.abs(aimYaw) > 0.001) then
                goalCF = goalCF * CFrame.Angles(math.rad(aimPitch), math.rad(aimYaw), 0):Inverse()
            end
            local alpha = math.clamp(1 / math.max(1, State.AimSmooth), 0.06, 1)
            cam.CFrame = cam.CFrame:Lerp(goalCF, alpha)
        end
    end

    if State.StandaloneRCS and not lockedTarget and UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) then
        local scale = math.clamp((tonumber(State.RCSStrength) or 85) / 100, 0, 1)
        local dPitch = (aimPitch - prevRcsPitch) * scale
        local dYaw = (aimYaw - prevRcsYaw) * scale
        if math.abs(dPitch) > 0.0001 or math.abs(dYaw) > 0.0001 then
            cam.CFrame = cam.CFrame * CFrame.Angles(-math.rad(dPitch), -math.rad(dYaw), 0)
        end
    end
    prevRcsPitch = aimPitch
    prevRcsYaw = aimYaw

    if State.Triggerbot and os.clock() - lastTriggerFire >= State.TriggerDelay then
        local holdOk = true
        if State.TriggerHoldKey == "Hold Right Click (RMB)" then
            holdOk = UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2)
        elseif State.TriggerHoldKey == "When Aimbot Active" then
            holdOk = State.AimAssist
        end

        if holdOk and not UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) then
            updateRayFilter(cam)
            local rayCF = cam.CFrame * CFrame.Angles(math.rad(aimPitch), math.rad(aimYaw), 0)
            local res = Workspace:Raycast(cam.CFrame.Position, rayCF.LookVector * 800, VisRayParams)
            if res and res.Instance then
                local hitModel = res.Instance:FindFirstAncestorOfClass("Model")
                if hitModel and hitModel:FindFirstChildOfClass("Humanoid") and hitModel:FindFirstChildOfClass("Humanoid").Health > 0 then
                    local hitPlr = Players:GetPlayerFromCharacter(hitModel)
                    local shouldShoot = false
                    if hitPlr then
                        shouldShoot = isEnemyPlayer(hitPlr)
                    elseif State.AimIncludeBots then
                        shouldShoot = true
                    end
                    if shouldShoot then
                        local okTime, tNext = pcall(function() return WeaponModule and WeaponModule:TimeToNextShot() end)
                        if not okTime or not tNext or tNext <= 0 then
                            lastTriggerFire = os.clock()
                            if type(mouse1click) == "function" then
                                pcall(mouse1click)
                            elseif WeaponModule then
                                task.spawn(function()
                                    pcall(function() WeaponModule:fire() end)
                                end)
                            end
                        end
                    end
                end
            end
        end
    end
end

-- HIGH LEVEL: Fluent UI Window & Auto-Saving Controls
local Fluent = loadstring(game:HttpGet("https://github.com/dawid-scripts/Fluent/releases/latest/download/main.lua"))()

local Window = Fluent:CreateWindow({
    Title = "Cone Hub | Sentinel (Valorant)",
    SubTitle = "Legit Match & Range Suite (Press B = Aimbot)",
    TabWidth = 150,
    Size = UDim2.fromOffset(560, 440),
    Acrylic = false,
    Theme = "Darker",
    MinimizeKey = Enum.KeyCode.RightControl,
})

local Tabs = {
    ESP = Window:AddTab({ Title = "Tactical ESP", Icon = "eye" }),
    Combat = Window:AddTab({ Title = "Combat & Aim", Icon = "crosshair" }),
    Weapon = Window:AddTab({ Title = "Gun Mods", Icon = "target" }),
    Visuals = Window:AddTab({ Title = "Visuals", Icon = "sun" }),
}

local function bindToggle(tab, id, title, desc, stateKey, extraFn)
    return tab:AddToggle(id, {
        Title = title,
        Description = desc,
        Default = State[stateKey],
        Callback = function(v)
            State[stateKey] = v
            saveSettings()
            if extraFn then extraFn(v) end
        end,
    })
end

bindToggle(Tabs.ESP, "EnemyESP", "Enemy Player ESP (Real Matches)", "Highlights enemy players across all maps", "EnemyESP")
bindToggle(Tabs.ESP, "BotESP", "Training Dummy & Bot ESP (Range/DM)", "Highlights Range Target Practice Dummies & DM Bots", "BotESP")
bindToggle(Tabs.ESP, "TeammateESP", "Teammate ESP", "Highlights allied players in green", "TeammateESP")
bindToggle(Tabs.ESP, "Chams3D", "3D Chams Highlight (Through Walls)", "Always-on-top 3D character chams", "Chams3D")
bindToggle(Tabs.ESP, "Box2D", "2D Bounding Box", "Draws 2D tactical boxes around targets", "Box2D")
bindToggle(Tabs.ESP, "HealthBar2D", "2D Side Health Bar", "Dynamic color health bar on 2D boxes", "HealthBar2D")
bindToggle(Tabs.ESP, "NameTagESP", "Overhead Info Tag (Name/Weapon/HP/Dist)", "Shows target name, weapon, HP, and distance in meters", "NameTagESP")
bindToggle(Tabs.ESP, "Tracers2D", "Snapline Tracers", "Draws lines from bottom center to targets", "Tracers2D")
bindToggle(Tabs.ESP, "DroppedESP", "Spike & Dropped Weapons ESP", "Displays planted Spike and dropped guns", "DroppedESP")
bindToggle(Tabs.ESP, "ShowHeadHB", "Show Head Hitboxes (HeadHB)", "Reveals the exact HeadHB hitbox part on targets", "ShowHeadHB")

local AimToggleUI = bindToggle(Tabs.Combat, "AimAssist", "Smooth Aimbot (Press B to Toggle)", "Smoothly steers camera toward closest target in FOV", "AimAssist", function()
    updateAimBadge()
end)

local aimModes = { "Press B (Toggle)", "Hold Right Click (RMB)", "Hold Left Click (LMB)", "Always Active" }
local defaultModeIdx = table.find(aimModes, State.AimMode) or 1
Tabs.Combat:AddDropdown("AimMode", {
    Title = "Aimbot Activation Mode",
    Values = aimModes,
    Multi = false,
    Default = defaultModeIdx,
    Callback = function(v)
        State.AimMode = v
        saveSettings()
    end,
})

local aimParts = { "HeadHB", "Head", "UpperTorso", "HumanoidRootPart" }
local defaultPartIdx = table.find(aimParts, State.AimPart) or 1
Tabs.Combat:AddDropdown("AimPart", {
    Title = "Target Hitbox",
    Values = aimParts,
    Multi = false,
    Default = defaultPartIdx,
    Callback = function(v)
        State.AimPart = v
        saveSettings()
    end,
})

Tabs.Combat:AddSlider("AimFOV", {
    Title = "Aim FOV Radius (px)",
    Default = State.AimFOV,
    Min = 30,
    Max = 450,
    Rounding = 0,
    Callback = function(v)
        State.AimFOV = tonumber(v) or 150
        saveSettings()
    end,
})

bindToggle(Tabs.Combat, "ShowFOV", "Draw FOV Circle", "Displays FOV radius ring in center of screen", "ShowFOV")

Tabs.Combat:AddSlider("AimSmooth", {
    Title = "Aim Smoothness (1 = Fast, 20 = Very Smooth)",
    Default = State.AimSmooth,
    Min = 1,
    Max = 20,
    Rounding = 0,
    Callback = function(v)
        State.AimSmooth = tonumber(v) or 4
        saveSettings()
    end,
})

bindToggle(Tabs.Combat, "AimWallCheck", "Visibility Check (Wallcheck)", "Only locks onto visible targets", "AimWallCheck")
bindToggle(Tabs.Combat, "AimIncludeBots", "Target Range Dummies & DM Bots", "Includes Training Dummies & Deathmatch Bots in Aim/Triggerbot", "AimIncludeBots")
bindToggle(Tabs.Combat, "Triggerbot", "Triggerbot (Auto-Shoot on Crosshair)", "Fires native mouse1click when crosshair lands on target", "Triggerbot")

local trigModes = { "Always On", "When Aimbot Active", "Hold Right Click (RMB)" }
local defaultTrigIdx = table.find(trigModes, State.TriggerHoldKey) or 1
Tabs.Combat:AddDropdown("TriggerHoldKey", {
    Title = "Triggerbot Mode",
    Values = trigModes,
    Multi = false,
    Default = defaultTrigIdx,
    Callback = function(v)
        State.TriggerHoldKey = v
        saveSettings()
    end,
})

bindToggle(Tabs.Weapon, "AimRCS", "Aimbot Spray Compensation (Safe RCS)", "Automatically pulls camera down for AimPitch/AimYaw during aimbot spray", "AimRCS")
bindToggle(Tabs.Weapon, "StandaloneRCS", "Manual Spray Pull-Down (Standalone RCS)", "Smoothly pulls camera down to counter recoil while holding LMB", "StandaloneRCS")

Tabs.Weapon:AddSlider("RCSStrength", {
    Title = "Standalone RCS Strength (%)",
    Default = State.RCSStrength,
    Min = 10,
    Max = 100,
    Rounding = 0,
    Callback = function(v)
        State.RCSStrength = tonumber(v) or 85
        saveSettings()
    end,
})

bindToggle(Tabs.Weapon, "AutoReload", "Auto Reload on Empty Mag", "Automatically triggers reload when magazine hits 0", "AutoReload")

bindToggle(Tabs.Visuals, "AntiFlash", "Anti-Flash / Anti-Blind", "Removes flashbang Stun effect from camera immediately", "AntiFlash")
bindToggle(Tabs.Visuals, "NoSmokeOverlay", "Disable Smoke Haze Overlay", "Hides SmokeHazeOverlay screen blindness", "NoSmokeOverlay")

bindToggle(Tabs.Visuals, "Fullbright", "Fullbright Lighting", "Brightens map lighting and removes shadows", "Fullbright", function(v)
    if v then
        Lighting.Brightness = 2.5
        Lighting.ClockTime = 14
        Lighting.FogEnd = 100000
        Lighting.GlobalShadows = false
        Lighting.Ambient = Color3.fromRGB(175, 175, 175)
    else
        Lighting.Brightness = OriginalLighting.Brightness
        Lighting.ClockTime = OriginalLighting.ClockTime
        Lighting.FogEnd = OriginalLighting.FogEnd
        Lighting.GlobalShadows = OriginalLighting.GlobalShadows
        Lighting.Ambient = OriginalLighting.Ambient
    end
end)

bindToggle(Tabs.Visuals, "CustomFOVEnabled", "Custom Camera FOV Override", "Overrides camera FieldOfView", "CustomFOVEnabled")

Tabs.Visuals:AddSlider("CustomFOVValue", {
    Title = "Camera FOV Value",
    Default = State.CustomFOVValue,
    Min = 70,
    Max = 120,
    Rounding = 0,
    Callback = function(v)
        State.CustomFOVValue = tonumber(v) or 95
        saveSettings()
    end,
})

Window:SelectTab(1)

-- HIGH LEVEL: Keybind Handler (Press B to Toggle Aimbot) & Runtime Loops
table.insert(Connections, UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if not State.Running then return end
    if gameProcessed or UserInputService:GetFocusedTextBox() then return end
    if input.KeyCode == Enum.KeyCode.B then
        local newVal = not State.AimAssist
        State.AimAssist = newVal
        saveSettings()
        updateAimBadge()
        pcall(function()
            if AimToggleUI and AimToggleUI.SetValue then
                AimToggleUI:SetValue(newVal)
            end
        end)
    end
end))

table.insert(Connections, RunService.RenderStepped:Connect(function()
    if not State.Running then return end
    pcall(stepCombatAndVisuals)
    pcall(updateAllESP)
end))

getgenv().__CONE_SENTINEL_CLEANUP = function()
    State.Running = false
    for _, c in ipairs(Connections) do
        pcall(function() c:Disconnect() end)
    end
    for inst in pairs(EspCache) do
        removeEspEntry(inst)
    end
    for nativeHL in pairs(ModifiedNativeHighlights) do
        restoreNativeHighlight(nativeHL)
        ModifiedNativeHighlights[nativeHL] = nil
    end
    for item, lbl in pairs(ItemEspCache) do
        pcall(function() lbl:Destroy() end)
        ItemEspCache[item] = nil
    end
    for _, ui in ipairs(CreatedInstances) do
        pcall(function() ui:Destroy() end)
    end
    pcall(function() Window:Destroy() end)
end
