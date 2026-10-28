-- SERVICES & FLUENT LOADER

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local LocalPlayer = Players.LocalPlayer

local env = (getgenv and getgenv()) or shared
if env.__BridgeDuelsAutoCleanup then
    pcall(env.__BridgeDuelsAutoCleanup)
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

-- KNIT, ENTITY & BLINK INITIALIZATION

local KnitClient = nil
local EntityModule = nil
local BlinkClient = nil
local ServerDataModule = nil
local ToolService = nil

local function initGameModules()
    local modules = ReplicatedStorage:FindFirstChild("Modules")
    if modules then
        if not KnitClient and modules:FindFirstChild("Knit") and modules.Knit:FindFirstChild("Client") then
            local ok, mod = pcall(require, modules.Knit.Client)
            if ok then KnitClient = mod end
        end
        if not EntityModule and modules:FindFirstChild("Entity") then
            local ok, mod = pcall(require, modules.Entity)
            if ok then EntityModule = mod end
        end
        if not ServerDataModule and modules:FindFirstChild("ServerData") then
            local ok, mod = pcall(require, modules.ServerData)
            if ok then ServerDataModule = mod end
        end
    end
    local blinkFolder = ReplicatedStorage:FindFirstChild("Blink")
    if not BlinkClient and blinkFolder and blinkFolder:FindFirstChild("Client") then
        local ok, mod = pcall(require, blinkFolder.Client)
        if ok then BlinkClient = mod end
    end
    if KnitClient and KnitClient.GetService and not ToolService then
        local ok, svc = pcall(KnitClient.GetService, "ToolService")
        if ok and svc then ToolService = svc end
    end
end

local function getController(name)
    initGameModules()
    if KnitClient and KnitClient.GetController then
        local ok, ctrl = pcall(KnitClient.GetController, name)
        if ok and ctrl then return ctrl end
    end
    return nil
end

-- STATE & HUMANIZATION SETTINGS

local State = {
    Running = false,
    AutoQueue = true,
    QueueSubmode = "Solo",
    AutoBridge = false,
    AutoBreakBlocks = true,
    AutoGappleHeal = true,
    WTapEnabled = true,
    CircleStrafe = true,
    AimSmoothness = 0.28,
    CombatReach = 8.6,
    EngageDistance = 22.0,
    HealThreshold = 52,
    MinCPS = 9.0,
    MaxCPS = 13.5,
    StatusText = "Ready",
    SpawnAnchorPos = nil,
    LastGoalTouchAt = 0,
    LastAttackAt = 0,
    LastQueueAt = 0,
    LastBreakAt = 0,
    StrafeDir = 1,
    LastStrafeSwitch = 0,
    IsEatingGapple = false,
    DesiredMoveTarget = nil,
    DesiredAimTarget = nil,
    WTapUntil = 0,
}

local QUEUE_SUBMODES = {
    "Solo",
    "Duos",
    "Trios",
    "Quads",
    "RankedSolo",
    "RankedDuos",
    "BoxingSolo",
    "BoxingBotSolo",
    "BasicFightSolo",
    "BedFightSolo",
    "BedWarsSolo",
}

local MELEE_PRIORITY = {
    "AmethystSword",
    "DiamondSword",
    "GoldSword",
    "Sword",
    "Hammer",
    "WoodenSword",
    "KnockbackStick",
    "BoxingGloves",
}

local PICKAXE_PRIORITY = {
    "DiamondPickaxe",
    "GoldPickaxe",
    "Pickaxe",
    "WoodenPickaxe",
    "DiamondAxe",
    "GoldAxe",
    "Axe",
    "WoodenAxe",
    "ClayShears",
    "Shears",
}

local StatusParagraph = nil
local function setStatus(msg)
    State.StatusText = msg
    if StatusParagraph then
        pcall(function()
            StatusParagraph:SetDesc(msg)
        end)
    end
end

-- SPATIAL, CAGE, GRID & GOAL HELPERS

local function getCharacter()
    local char = LocalPlayer.Character
    if not char then return nil, nil, nil end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    local hum = char:FindFirstChildOfClass("Humanoid")
    return char, hrp, hum
end

local function disableAutoPlace()
    local bpc = getController("BlockPlacementController")
    if bpc then
        if bpc.AutoPlaceEnabled and bpc.ToggleAutoPlace then
            pcall(function()
                bpc:ToggleAutoPlace(false)
            end)
        end
        bpc.AutoPlaceEnabled = false
    end
end

local function disableEdgeSneak()
    local char = LocalPlayer.Character
    if char and char:GetAttribute("ClientSneaking") then
        pcall(function()
            char:SetAttribute("ClientSneaking", false)
        end)
    end
end

local function isInSpawnCage()
    local char, hrp = getCharacter()
    if not char or not hrp then return false end

    local map = Workspace:FindFirstChild("Map")
    if map then
        for _, child in ipairs(map:GetChildren()) do
            if child.Name:find("Cage") then
                local pos = nil
                if child:IsA("BasePart") then
                    pos = child.Position
                elseif child:IsA("Model") then
                    local p = child.PrimaryPart or child:FindFirstChildWhichIsA("BasePart", true)
                    if p then pos = p.Position end
                end
                if pos and (Vector3.new(hrp.Position.X - pos.X, 0, hrp.Position.Z - pos.Z)).Magnitude < 14 and math.abs(hrp.Position.Y - pos.Y) < 16 then
                    return true
                end
            end
        end
    end

    if hrp.Position.Y > 30 then
        local params = RaycastParams.new()
        params.FilterType = Enum.RaycastFilterType.Exclude
        params.FilterDescendantsInstances = { char }
        local enclosedCount = 0
        local dirs = {
            Vector3.new(6, 0, 0),
            Vector3.new(-6, 0, 0),
            Vector3.new(0, 0, 6),
            Vector3.new(0, 0, -6),
        }
        for _, d in ipairs(dirs) do
            if Workspace:Raycast(hrp.Position, d, params) then
                enclosedCount = enclosedCount + 1
            end
        end
        if enclosedCount >= 3 then
            return true
        end
    end

    return false
end

local function snapToBlockGrid(pos)
    return Vector3.new(
        math.floor(pos.X / 3 + 0.5) * 3,
        math.floor(pos.Y / 3 + 0.5) * 3,
        math.floor(pos.Z / 3 + 0.5) * 3
    )
end

local function hasGroundBelow(worldPos, maxDrop)
    maxDrop = maxDrop or 28
    local char = LocalPlayer.Character
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = char and { char } or {}
    local hit = Workspace:Raycast(worldPos + Vector3.new(0, 2.5, 0), Vector3.new(0, -maxDrop, 0), params)
    return hit ~= nil, hit
end

local function getTeamAnchorPosition()
    local map = Workspace:FindFirstChild("Map")
    local teamName = LocalPlayer.Team and LocalPlayer.Team.Name or nil
    if not teamName and LocalPlayer.TeamColor then
        local tc = LocalPlayer.TeamColor.Color
        if tc.R > tc.B + 0.15 then
            teamName = "Red"
        elseif tc.B > tc.R + 0.15 then
            teamName = "Blue"
        end
    end

    if map and teamName then
        local buildLimits = map:FindFirstChild("BuildLimits")
        local teamFolder = buildLimits and buildLimits:FindFirstChild(teamName)
        if teamFolder then
            local part = teamFolder:FindFirstChildWhichIsA("BasePart", true)
            if part then return part.Position, teamName end
        end
        for _, child in ipairs(map:GetChildren()) do
            if child.Name:lower():find(teamName:lower(), 1, true) then
                if child:IsA("BasePart") then
                    return child.Position, teamName
                elseif child:IsA("Model") then
                    local p = child.PrimaryPart or child:FindFirstChildWhichIsA("BasePart", true)
                    if p then return p.Position, teamName end
                end
            end
        end
    end

    return State.SpawnAnchorPos, teamName
end

local function getGoals()
    local _, hrp = getCharacter()
    if hrp then
        if not State.SpawnAnchorPos or isInSpawnCage() then
            State.SpawnAnchorPos = hrp.Position
        end
    end

    local goals = {}
    local seen = {}
    local function addGoalPart(part)
        if part and part:IsA("BasePart") and not seen[part] then
            seen[part] = true
            table.insert(goals, part)
        end
    end

    for _, inst in ipairs(CollectionService:GetTagged("Goal")) do
        if inst:IsA("BasePart") then
            addGoalPart(inst)
        elseif inst:IsA("Model") then
            addGoalPart(inst.PrimaryPart or inst:FindFirstChildWhichIsA("BasePart", true))
        end
    end

    if #goals < 2 then
        local map = Workspace:FindFirstChild("Map")
        if map then
            for _, desc in ipairs(map:GetDescendants()) do
                if desc:IsA("BasePart") and (desc.Name == "Goal" or desc.Name == "GoalPart" or CollectionService:HasTag(desc, "Goal")) then
                    addGoalPart(desc)
                end
            end
        end
    end

    if #goals == 0 then
        return nil, nil
    elseif #goals == 1 then
        return nil, goals[1]
    end

    local teamAnchor, teamName = getTeamAnchorPosition()
    if teamName then
        local myByTeam, enemyByTeam = nil, nil
        for _, g in ipairs(goals) do
            local fullName = g:GetFullName():lower()
            local col = g.Color
            local isRedGoal = fullName:find("red", 1, true) ~= nil or (col.R > col.B + 0.2)
            local isBlueGoal = fullName:find("blue", 1, true) ~= nil or (col.B > col.R + 0.2)
            if teamName == "Red" then
                if isRedGoal then myByTeam = g elseif isBlueGoal then enemyByTeam = g end
            elseif teamName == "Blue" then
                if isBlueGoal then myByTeam = g elseif isRedGoal then enemyByTeam = g end
            end
        end
        if myByTeam and enemyByTeam and myByTeam ~= enemyByTeam then
            return myByTeam, enemyByTeam
        end
    end

    local refPos = teamAnchor or State.SpawnAnchorPos or (hrp and hrp.Position) or Vector3.zero
    local myGoal, enemyGoal = nil, nil
    local minDist, maxDist = math.huge, -1
    for _, g in ipairs(goals) do
        local d = Vector3.new(g.Position.X - refPos.X, 0, g.Position.Z - refPos.Z).Magnitude
        if d < minDist then
            minDist = d
            myGoal = g
        end
        if d > maxDist then
            maxDist = d
            enemyGoal = g
        end
    end
    if myGoal == enemyGoal then
        myGoal = nil
    end
    return myGoal, enemyGoal
end

local function getNearestEnemy()
    initGameModules()
    local char, hrp = getCharacter()
    if not char or not hrp then return nil, math.huge end

    local bestTarget = nil
    local bestDist = math.huge

    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer and plr.Character then
            local sameTeam = (plr.Team ~= nil and LocalPlayer.Team ~= nil and plr.Team == LocalPlayer.Team and not LocalPlayer.Neutral)
            if not sameTeam then
                local erp = plr.Character:FindFirstChild("HumanoidRootPart")
                local ehum = plr.Character:FindFirstChildOfClass("Humanoid")
                if erp and ehum and ehum.Health > 0 and erp.Position.Y > -60 then
                    local d = (erp.Position - hrp.Position).Magnitude
                    if d < bestDist then
                        local ent = nil
                        if EntityModule and EntityModule.FindByCharacter then
                            local ok, res = pcall(EntityModule.FindByCharacter, plr.Character)
                            if ok then ent = res end
                        end
                        bestDist = d
                        bestTarget = {
                            Entity = ent,
                            Character = plr.Character,
                            RootPart = erp,
                            Humanoid = ehum,
                        }
                    end
                end
            end
        end
    end

    if not bestTarget and EntityModule and EntityModule.GetEntities then
        local ok, list = pcall(EntityModule.GetEntities)
        if ok and type(list) == "table" then
            for _, ent in pairs(list) do
                if ent and ent.Character and ent.Character ~= char then
                    local erp = ent.Character:FindFirstChild("HumanoidRootPart")
                    local ehum = ent.Character:FindFirstChildOfClass("Humanoid")
                    if erp and ehum and ehum.Health > 0 and erp.Position.Y > -60 then
                        local d = (erp.Position - hrp.Position).Magnitude
                        if d < bestDist then
                            bestDist = d
                            bestTarget = {
                                Entity = ent,
                                Character = ent.Character,
                                RootPart = erp,
                                Humanoid = ehum,
                            }
                        end
                    end
                end
            end
        end
    end

    return bestTarget, bestDist
end

local function smoothAimAt(targetPos, alphaOverride)
    State.DesiredAimTarget = targetPos
    local _, hrp = getCharacter()
    local cam = Workspace.CurrentCamera
    if not hrp or not cam or not targetPos then return end

    local alpha = alphaOverride or State.AimSmoothness
    local t = os.clock()
    local organicDrift = Vector3.new(
        math.sin(t * 4.7) * 0.12,
        math.cos(t * 3.9) * 0.08,
        math.sin(t * 5.3) * 0.12
    )
    local aimPoint = targetPos + organicDrift

    local flatAim = Vector3.new(aimPoint.X, hrp.Position.Y, aimPoint.Z)
    if (flatAim - hrp.Position).Magnitude > 0.15 then
        hrp.CFrame = hrp.CFrame:Lerp(CFrame.lookAt(hrp.Position, flatAim), math.clamp(alpha * 1.6, 0.22, 1.0))
    end

    local camPos = cam.CFrame.Position
    if (aimPoint - camPos).Magnitude > 0.15 then
        cam.CFrame = cam.CFrame:Lerp(CFrame.lookAt(camPos, aimPoint), math.clamp(alpha, 0.12, 1.0))
    end
end

-- COMBAT, BRIDGING, BLOCK BREAKING & GAPPLE HEALING

local function findTool(nameList)
    local char = LocalPlayer.Character
    local backpack = LocalPlayer:FindFirstChild("Backpack")

    local function checkFolder(folder)
        if not folder then return nil end
        for _, name in ipairs(nameList) do
            for _, item in ipairs(folder:GetChildren()) do
                if item:IsA("Tool") and (item.Name == name or item.Name:lower():find(name:lower(), 1, true)) then
                    return item
                end
            end
        end
        return nil
    end

    return checkFolder(char) or checkFolder(backpack)
end

local function equipBestMelee()
    disableAutoPlace()
    initGameModules()
    local char, _, hum = getCharacter()
    local tool = findTool(MELEE_PRIORITY)
    if tool and hum and char and tool.Parent ~= char then
        pcall(function() hum:EquipTool(tool) end)
    end
    return tool
end

local function tryEatGoldApple()
    if not State.AutoGappleHeal or State.IsEatingGapple then
        return false
    end
    local char, _, hum = getCharacter()
    if not char or not hum or hum.Health <= 0 then return false end
    if hum.Health > State.HealThreshold then return false end

    local gapple = findTool({ "GoldApple", "GoldenApple", "Apple" })
    if not gapple then return false end

    State.IsEatingGapple = true
    disableAutoPlace()
    initGameModules()
    if gapple.Parent ~= char then
        pcall(function() hum:EquipTool(gapple) end)
        task.wait(0.08)
    end

    if EntityModule and EntityModule.LocalEntity and EntityModule.LocalEntity.EatGoldApple then
        pcall(function()
            EntityModule.LocalEntity:EatGoldApple()
        end)
    else
        pcall(function() gapple:Activate() end)
        if BlinkClient and BlinkClient.item_action and BlinkClient.item_action.start_eat_gold_apple then
            pcall(function() BlinkClient.item_action.start_eat_gold_apple.fire() end)
        end
        task.wait(1.88)
        if BlinkClient and BlinkClient.item_action and BlinkClient.item_action.stop_eat_gold_apple then
            pcall(function() BlinkClient.item_action.stop_eat_gold_apple.fire(true) end)
        end
    end

    State.IsEatingGapple = false
    equipBestMelee()
    return true
end

local function placeBridgeBlockAhead(moveDir)
    disableAutoPlace()
    if not State.AutoBridge then return false end
    if isInSpawnCage() then return false end

    local char, hrp, hum = getCharacter()
    if not char or not hrp or not hum then return false end
    if hrp.Position.Y > 24 then return false end

    local myGoal, enemyGoal = getGoals()
    if myGoal and (Vector3.new(hrp.Position.X - myGoal.Position.X, 0, hrp.Position.Z - myGoal.Position.Z)).Magnitude < 16 then
        return false
    end
    if enemyGoal and (Vector3.new(hrp.Position.X - enemyGoal.Position.X, 0, hrp.Position.Z - enemyGoal.Position.Z)).Magnitude < 16 then
        return false
    end

    local flatDir = Vector3.new(moveDir.X, 0, moveDir.Z)
    if flatDir.Magnitude < 0.1 then return false end
    flatDir = flatDir.Unit

    local probePos = hrp.Position + flatDir * 3.4
    if hasGroundBelow(probePos, 35) then
        return false
    end

    local gridPos = snapToBlockGrid(hrp.Position + flatDir * 3.0 - Vector3.new(0, 3.2, 0))
    local blockTool = findTool({ "Blocks", "Clay", "Block" })
    if not blockTool then return false end

    if blockTool.Parent ~= char then
        pcall(function() hum:EquipTool(blockTool) end)
    end

    local bpc = getController("BlockPlacementController")
    if bpc and bpc.PlaceBlock then
        pcall(function()
            bpc:PlaceBlock(gridPos, "Clay")
        end)
    end
    disableAutoPlace()
    equipBestMelee()
    return true
end

local function breakObstructingBlockAhead(moveDir)
    if not State.AutoBreakBlocks then return false end
    if isInSpawnCage() then return false end

    local char, hrp, hum = getCharacter()
    if not char or not hrp or not hum then return false end

    local flatDir = Vector3.new(moveDir.X, 0, moveDir.Z)
    if flatDir.Magnitude < 0.1 then return false end
    flatDir = flatDir.Unit

    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = { char }

    local hitLow = Workspace:Raycast(hrp.Position + Vector3.new(0, -1.0, 0), flatDir * 3.8, params)
    local hitMid = Workspace:Raycast(hrp.Position + Vector3.new(0, 0.8, 0), flatDir * 3.8, params)
    local hitHigh = Workspace:Raycast(hrp.Position + Vector3.new(0, 3.2, 0), flatDir * 3.8, params)

    local hit = hitMid or hitLow
    if not hit or not hit.Instance then return false end

    local part = hit.Instance
    if CollectionService:HasTag(part, "Goal") or part.Name:find("Goal") then
        return false
    end

    if not hitHigh then
        hum.Jump = true
        if part.Name ~= "Clay" and not part:GetAttribute("BlockHealth") and not (part.Parent and part.Parent.Name:find("Blocks")) then
            return false
        end
    end

    local now = os.clock()
    if now - State.LastBreakAt < 0.32 then
        return false
    end
    State.LastBreakAt = now

    local gridPos = snapToBlockGrid(part.Position)
    local pickTool = findTool(PICKAXE_PRIORITY)
    if pickTool and pickTool.Parent ~= char then
        pcall(function() hum:EquipTool(pickTool) end)
    end

    initGameModules()
    if BlinkClient and BlinkClient.item_action and BlinkClient.item_action.start_break_block then
        local pickName = (pickTool and pickTool.Name) or "Pickaxe"
        pcall(function()
            BlinkClient.item_action.start_break_block.fire({
                position = gridPos,
                pickaxe_name = pickName,
                timestamp = Workspace:GetServerTimeNow(),
            })
            task.delay(0.26, function()
                pcall(function()
                    BlinkClient.item_action.stop_break_block.fire(true)
                end)
            end)
        end)
        return true
    end
    return false
end

local function performLegitMeleeSwing(enemyInfo)
    if not enemyInfo or not enemyInfo.RootPart or not enemyInfo.Character then return false end
    local char, hrp, hum = getCharacter()
    if not char or not hrp or not hum then return false end

    local dist = (enemyInfo.RootPart.Position - hrp.Position).Magnitude
    if dist > State.CombatReach then
        return false
    end

    local now = os.clock()
    local dynamicCPS = State.MinCPS
        + (State.MaxCPS - State.MinCPS) * (0.5 + 0.5 * math.sin(now * 2.3))
        + (math.random() - 0.5) * 1.8
    local minInterval = math.max(0.065, 1.0 / math.clamp(dynamicCPS, 6, 16))
    if now - State.LastAttackAt < minInterval then
        return false
    end

    State.LastAttackAt = now
    initGameModules()

    local flatEnemy = Vector3.new(enemyInfo.RootPart.Position.X, hrp.Position.Y, enemyInfo.RootPart.Position.Z)
    if (flatEnemy - hrp.Position).Magnitude > 0.15 then
        hrp.CFrame = hrp.CFrame:Lerp(CFrame.lookAt(hrp.Position, flatEnemy), 0.65)
    end

    local tool = equipBestMelee()
    local weaponName = (tool and tool.Name) or "WoodenSword"
    local isCrit = hrp.AssemblyLinearVelocity.Y < -0.5

    if tool then
        pcall(function() tool:Activate() end)
    end

    local vmc = getController("ViewmodelController")
    if vmc and vmc.PlayAnimation then
        pcall(function()
            vmc:PlayAnimation(weaponName)
        end)
    end

    local ent = enemyInfo.Entity
    if not ent and EntityModule and EntityModule.FindByCharacter then
        local ok, found = pcall(EntityModule.FindByCharacter, enemyInfo.Character)
        if ok then ent = found end
    end
    local targetId = (ent and ent.Id) or enemyInfo.Character:GetAttribute("EntityId")

    if BlinkClient and BlinkClient.item_action and BlinkClient.item_action.attack_entity and targetId then
        pcall(function()
            BlinkClient.item_action.attack_entity.fire({
                target_entity_id = targetId,
                is_crit = isCrit,
                weapon_name = weaponName,
                extra = {
                    those = (Workspace.Name == "Okay"),
                    owo = "h-hi sevengwanddad~",
                    rizz = "Bro.",
                },
            })
        end)
    end

    if ToolService and ToolService.AttackPlayerWithSword then
        pcall(function()
            ToolService:AttackPlayerWithSword(enemyInfo.Character, isCrit, weaponName, "\226\128\139")
        end)
    end

    return true
end

local function tryScoreInEnemyGoal(enemyGoal)
    if not enemyGoal then return false end
    local _, hrp, hum = getCharacter()
    if not hrp or not hum then return false end

    disableEdgeSneak()

    local goalPos = enemyGoal.Position
    local horizDist = Vector3.new(goalPos.X - hrp.Position.X, 0, goalPos.Z - hrp.Position.Z).Magnitude
    local fullDist = (goalPos - hrp.Position).Magnitude

    if horizDist > 5.0 and horizDist <= 14.5 then
        hum.Jump = true
    end

    if fullDist <= 15.5 then
        if os.clock() - State.LastGoalTouchAt > 0.35 then
            State.LastGoalTouchAt = os.clock()
            local remFolder = ReplicatedStorage:FindFirstChild("Remotes")
            local goalTouch = remFolder and remFolder:FindFirstChild("GoalTouch")
            if goalTouch and goalTouch:IsA("RemoteEvent") then
                pcall(function()
                    goalTouch:FireServer(enemyGoal, Workspace:GetServerTimeNow())
                end)
            end
            if firetouchinterest then
                pcall(firetouchinterest, hrp, enemyGoal, 0)
                pcall(firetouchinterest, hrp, enemyGoal, 1)
            end
        end
        return true
    end
    return false
end

-- CONTINUOUS FRAME MOVEMENT & HYPIXEL BRIDGE ROUTER

local function computeBridgeNavigationTarget(hrpPos, myGoal, enemyGoal)
    if not enemyGoal then return nil end
    local enemyPos = enemyGoal.Position
    if not myGoal then
        return enemyPos
    end

    local myPos = myGoal.Position
    local bridgeVec = Vector3.new(enemyPos.X - myPos.X, 0, enemyPos.Z - myPos.Z)
    local bridgeLen = bridgeVec.Magnitude
    if bridgeLen < 10 then
        return enemyPos
    end

    local bridgeDir = bridgeVec.Unit
    local rightDir = bridgeDir:Cross(Vector3.new(0, 1, 0))
    local rel = Vector3.new(hrpPos.X - myPos.X, 0, hrpPos.Z - myPos.Z)
    local along = rel:Dot(bridgeDir)
    local progress = along / bridgeLen
    local lateral = rel:Dot(rightDir)
    local horizToEnemyGoal = Vector3.new(enemyPos.X - hrpPos.X, 0, enemyPos.Z - hrpPos.Z).Magnitude
    local horizToMyGoal = Vector3.new(myPos.X - hrpPos.X, 0, myPos.Z - hrpPos.Z).Magnitude

    if progress < 0.16 then
        local entryPoint = Vector3.new(
            myPos.X + bridgeDir.X * (bridgeLen * 0.24),
            hrpPos.Y,
            myPos.Z + bridgeDir.Z * (bridgeLen * 0.24)
        )
        if horizToMyGoal < 12.5 and progress < 0.04 then
            local sideSign = (lateral >= 0) and 1 or -1
            entryPoint = entryPoint + rightDir * (sideSign * 7.5)
        end
        return entryPoint
    elseif progress < 0.82 and horizToEnemyGoal > 26 then
        local targetAlong = math.min(bridgeLen * 0.86, along + 28)
        return Vector3.new(
            myPos.X + bridgeDir.X * targetAlong,
            enemyPos.Y + 2,
            myPos.Z + bridgeDir.Z * targetAlong
        )
    else
        return enemyPos
    end
end

local function stepRenderMovement()
    if not State.Running then return end
    disableAutoPlace()
    disableEdgeSneak()

    local char, hrp, hum = getCharacter()
    if not char or not hrp or not hum or hum.Health <= 0 then return end

    local targetPos = State.DesiredMoveTarget
    if not targetPos then
        hum:Move(Vector3.zero, false)
        return
    end

    local delta = targetPos - hrp.Position
    local flatDelta = Vector3.new(delta.X, 0, delta.Z)
    if flatDelta.Magnitude <= 0.55 then
        hum:Move(Vector3.zero, false)
        return
    end

    local moveDir = flatDelta.Unit
    if State.WTapUntil and os.clock() < State.WTapUntil then
        moveDir = -moveDir * 0.35
    end

    local aimTarget = State.DesiredAimTarget or targetPos
    local flatAim = Vector3.new(aimTarget.X, hrp.Position.Y, aimTarget.Z)
    if (flatAim - hrp.Position).Magnitude > 0.2 then
        hrp.CFrame = hrp.CFrame:Lerp(CFrame.lookAt(hrp.Position, flatAim), 0.35)
    end

    hum:Move(moveDir, false)
    hum:MoveTo(targetPos)

    if not isInSpawnCage() and flatDelta.Magnitude > 4.0 then
        local params = RaycastParams.new()
        params.FilterType = Enum.RaycastFilterType.Exclude
        params.FilterDescendantsInstances = { char }
        local kneeHit = Workspace:Raycast(hrp.Position - Vector3.new(0, 1.2, 0), moveDir * 3.4, params)
        local headHit = Workspace:Raycast(hrp.Position + Vector3.new(0, 2.6, 0), moveDir * 3.4, params)
        if kneeHit and kneeHit.Instance and not CollectionService:HasTag(kneeHit.Instance, "Goal") and not headHit then
            hum.Jump = true
        end
    end
end

pcall(function()
    RunService:UnbindFromRenderStep("BridgeDuelsLegitMove")
end)
RunService:BindToRenderStep("BridgeDuelsLegitMove", Enum.RenderPriority.Character.Value + 5, stepRenderMovement)

local charAddedConn = LocalPlayer.CharacterAdded:Connect(function(newChar)
    task.spawn(function()
        local hrp = newChar:WaitForChild("HumanoidRootPart", 5)
        if hrp then
            State.SpawnAnchorPos = hrp.Position
        end
    end)
end)

-- AUTO-QUEUE & STRATEGIC BRAIN

local function isInLobbyOrMatchEnded()
    initGameModules()
    if ServerDataModule and ServerDataModule.Submode == "Lobby" then
        return true
    end
    local pgui = LocalPlayer:FindFirstChild("PlayerGui")
    if pgui then
        local hotbar = pgui:FindFirstChild("Hotbar")
        local mainFrame = hotbar and hotbar:FindFirstChild("MainFrame")
        local gameEnd = mainFrame and mainFrame:FindFirstChild("GameEndFrame")
        if gameEnd and gameEnd.Visible then
            return true
        end
    end
    return false
end

local function tryEnterQueue()
    if not State.AutoQueue then return false end
    if os.clock() - State.LastQueueAt < 3.5 then return false end
    if not isInLobbyOrMatchEnded() then return false end

    State.LastQueueAt = os.clock()
    State.SpawnAnchorPos = nil
    State.DesiredMoveTarget = nil
    local mc = getController("MatchController")
    if mc and mc.EnterQueue then
        pcall(function()
            mc:EnterQueue(State.QueueSubmode)
        end)
        return true
    end
    return false
end

local function stepStrategicBrain()
    disableAutoPlace()
    disableEdgeSneak()

    if isInLobbyOrMatchEnded() then
        State.DesiredMoveTarget = nil
        if State.AutoQueue then
            setStatus("Auto-Queueing for " .. tostring(State.QueueSubmode) .. "...")
            tryEnterQueue()
        else
            setStatus("In Lobby / Post-Match")
        end
        return
    end

    local char, hrp, hum = getCharacter()
    if not char or not hrp or not hum or hum.Health <= 0 then
        State.DesiredMoveTarget = nil
        setStatus("Waiting for spawn...")
        return
    end

    local myGoal, enemyGoal = getGoals()

    if isInSpawnCage() then
        State.SpawnAnchorPos = hrp.Position
        equipBestMelee()
        if enemyGoal then
            smoothAimAt(enemyGoal.Position + Vector3.new(0, 1.5, 0), 0.25)
            State.DesiredMoveTarget = enemyGoal.Position
        end
        setStatus("In Spawn Cage — Ready for Round Start...")
        return
    end

    local enemy, enemyDist = getNearestEnemy()

    if hum.Health <= State.HealThreshold and State.AutoGappleHeal then
        local gapple = findTool({ "GoldApple", "GoldenApple", "Apple" })
        if gapple then
            setStatus(string.format("Low HP (%d) -> Retreating & Eating GoldApple", math.floor(hum.Health)))
            if enemy and enemy.RootPart then
                local awayVec = (hrp.Position - enemy.RootPart.Position)
                awayVec = Vector3.new(awayVec.X, 0, awayVec.Z)
                if awayVec.Magnitude > 0.1 then
                    local retreatPos = hrp.Position + awayVec.Unit * 14
                    if hasGroundBelow(retreatPos, 18) then
                        State.DesiredMoveTarget = retreatPos
                    end
                end
            end
            tryEatGoldApple()
            return
        end
    end

    local enemyThreateningMyGoal = false
    if enemy and enemy.RootPart and myGoal then
        local enemyToMyGoal = (enemy.RootPart.Position - myGoal.Position).Magnitude
        local meToMyGoal = (hrp.Position - myGoal.Position).Magnitude
        if enemyToMyGoal < 42 and enemyToMyGoal < meToMyGoal + 8 then
            enemyThreateningMyGoal = true
        end
    end

    if enemy and enemy.RootPart and (enemyDist <= State.EngageDistance or enemyThreateningMyGoal) then
        local enemyPos = enemy.RootPart.Position
        setStatus(string.format("Legit Duel | Opponent: %s (%.1f studs)", enemy.Character.Name, enemyDist))

        smoothAimAt(enemyPos + Vector3.new(0, 0.8, 0), 0.35)

        local toEnemy = enemyPos - hrp.Position
        local flatToEnemy = Vector3.new(toEnemy.X, 0, toEnemy.Z)
        local flatUnit = flatToEnemy.Magnitude > 0.1 and flatToEnemy.Unit or hrp.CFrame.LookVector

        if State.CircleStrafe and enemyDist <= 10.5 then
            if os.clock() - State.LastStrafeSwitch > 1.05 then
                State.LastStrafeSwitch = os.clock()
                State.StrafeDir = -State.StrafeDir
            end
            local rightVec = flatUnit:Cross(Vector3.new(0, 1, 0)) * State.StrafeDir
            local strafeTarget = hrp.Position + flatUnit * 3.8 + rightVec * 2.6
            if not hasGroundBelow(strafeTarget, 10) then
                State.StrafeDir = -State.StrafeDir
                strafeTarget = enemyPos
            end
            State.DesiredMoveTarget = strafeTarget
        else
            State.DesiredMoveTarget = enemyPos
        end

        local hitLanded = performLegitMeleeSwing(enemy)
        if hitLanded and State.WTapEnabled then
            State.WTapUntil = os.clock() + 0.055
        end
        return
    end

    equipBestMelee()

    if enemyGoal then
        local goalPos = enemyGoal.Position
        local distToGoal = (goalPos - hrp.Position).Magnitude
        local navTarget = computeBridgeNavigationTarget(hrp.Position, myGoal, enemyGoal) or goalPos
        State.DesiredMoveTarget = navTarget

        setStatus(string.format("Crossing Bridge -> Enemy Goal Hole (%.1f studs)", distToGoal))

        smoothAimAt(navTarget + Vector3.new(0, 1.2, 0), 0.24)
        local dirToNav = navTarget - hrp.Position
        local flatDir = Vector3.new(dirToNav.X, 0, dirToNav.Z)
        if flatDir.Magnitude > 0.1 then
            flatDir = flatDir.Unit
        end

        placeBridgeBlockAhead(flatDir)
        breakObstructingBlockAhead(flatDir)
        tryScoreInEnemyGoal(enemyGoal)
    elseif enemy and enemy.RootPart then
        local enemyPos = enemy.RootPart.Position
        State.DesiredMoveTarget = enemyPos
        setStatus("Advancing toward opponent (" .. enemy.Character.Name .. ")")
        smoothAimAt(enemyPos)
        local flatDir = Vector3.new(enemyPos.X - hrp.Position.X, 0, enemyPos.Z - hrp.Position.Z)
        placeBridgeBlockAhead(flatDir)
        breakObstructingBlockAhead(flatDir)
    end
end

-- FLUENT UI WINDOW & TABS

local Window = Fluent:CreateWindow({
    Title = "Cone Hub | Bridge Duels Legit Auto-Player",
    SubTitle = "Hypixel Bridge AI, Sprint Movement, Sword PvP & Goal Diving",
    TabWidth = 160,
    Size = UDim2.fromOffset(590, 470),
    Acrylic = false,
    Theme = "Dark",
    MinimizeKey = Enum.KeyCode.RightControl,
})

local Tabs = {
    Main = Window:AddTab({ Title = "Auto-Play & Queue", Icon = "swords" }),
    Combat = Window:AddTab({ Title = "Legit Combat", Icon = "crosshair" }),
    Bridge = Window:AddTab({ Title = "Bridge & Heal", Icon = "box" }),
    Settings = Window:AddTab({ Title = "Settings", Icon = "settings" }),
}

StatusParagraph = Tabs.Main:AddParagraph({
    Title = "Strategic Bot Status",
    Content = "Ready — Enable Legit Auto-Play to automatically queue, sprint the bridge, duel, and dive into the enemy goal.",
})

local MasterToggle = Tabs.Main:AddToggle("MasterAutoPlay", {
    Title = "Enable Legit Strategic Auto-Play",
    Description = "Runs full Hypixel Bridge strategy (Sprint Bridge, Sword Duel + W-Tap, Defense Mining, Gapple Heal, and Goal Hole Diving).",
    Default = false,
})

MasterToggle:OnChanged(function(val)
    State.Running = val
    disableAutoPlace()
    if val then
        task.spawn(function()
            while State.Running do
                pcall(stepStrategicBrain)
                task.wait(0.06)
            end
        end)
    else
        State.DesiredMoveTarget = nil
        local _, _, hum = getCharacter()
        if hum then
            pcall(function() hum:Move(Vector3.zero, false) end)
        end
        setStatus("Paused.")
    end
end)

local QueueToggle = Tabs.Main:AddToggle("AutoQueueToggle", {
    Title = "Auto-Queue Next Match",
    Description = "Automatically enters the selected queue from Lobby or immediately when a match ends.",
    Default = true,
})

QueueToggle:OnChanged(function(val)
    State.AutoQueue = val
end)

local ModeDropdown = Tabs.Main:AddDropdown("QueueSubmodeSelect", {
    Title = "Queue Gamemode / Submode",
    Values = QUEUE_SUBMODES,
    Multi = false,
    Default = 1,
})

ModeDropdown:OnChanged(function(val)
    State.QueueSubmode = val
end)

Tabs.Main:AddButton({
    Title = "Enter Selected Queue Now",
    Description = "Immediately calls MatchController:EnterQueue for the selected submode.",
    Callback = function()
        local mc = getController("MatchController")
        if mc and mc.EnterQueue then
            pcall(function()
                mc:EnterQueue(State.QueueSubmode)
            end)
            setStatus("Entered Queue: " .. tostring(State.QueueSubmode))
        end
    end,
})

local WTapToggle = Tabs.Combat:AddToggle("WTapToggle", {
    Title = "Legit W-Tap Sprint Reset",
    Description = "Briefly resets forward movement after landing a melee hit for maximum knockback.",
    Default = true,
})

WTapToggle:OnChanged(function(val)
    State.WTapEnabled = val
end)

local StrafeToggle = Tabs.Combat:AddToggle("CircleStrafeToggle", {
    Title = "Void-Safe Circle Strafe",
    Description = "Strafes laterally around opponents while raycasting ahead to never step off the bridge.",
    Default = true,
})

StrafeToggle:OnChanged(function(val)
    State.CircleStrafe = val
end)

local AimSlider = Tabs.Combat:AddSlider("AimSmoothness", {
    Title = "Camera Aim Smoothness",
    Description = "Lower = softer human-like camera tracking; Higher = snappier tracking.",
    Default = 28,
    Min = 8,
    Max = 80,
    Rounding = 0,
})

AimSlider:OnChanged(function(val)
    State.AimSmoothness = val / 100
end)

local ReachSlider = Tabs.Combat:AddSlider("CombatReach", {
    Title = "Legit Swing Reach (Studs)",
    Description = "Game max reach is 9.0 studs; 8.2–8.8 hits reliably while staying within server validation.",
    Default = 8.6,
    Min = 6.5,
    Max = 9.0,
    Rounding = 1,
})

ReachSlider:OnChanged(function(val)
    State.CombatReach = val
end)

local MaxCPSSlider = Tabs.Combat:AddSlider("MaxCPSSlider", {
    Title = "Target Peak CPS (Dynamic Jitter Applied)",
    Description = "Automatically varies CPS each second to bypass NetworkController consistency checks.",
    Default = 13,
    Min = 7,
    Max = 15,
    Rounding = 0,
})

MaxCPSSlider:OnChanged(function(val)
    State.MaxCPS = val
    State.MinCPS = math.max(6, val - 4)
end)

local BridgeToggle = Tabs.Bridge:AddToggle("AutoBridgeToggle", {
    Title = "Auto Bridge Over True Void Gaps Only",
    Description = "Optional: Only places Clay over deep void gaps (>35 studs) and keeps AutoPlace disabled so it never places blocks under you.",
    Default = false,
})

BridgeToggle:OnChanged(function(val)
    State.AutoBridge = val
    disableAutoPlace()
end)

local BreakToggle = Tabs.Bridge:AddToggle("AutoBreakBlocksToggle", {
    Title = "Auto Mine Obstructing Enemy Blocks",
    Description = "Equips Pickaxe and breaks enemy block defenses blocking the bridge or goal hole.",
    Default = true,
})

BreakToggle:OnChanged(function(val)
    State.AutoBreakBlocks = val
end)

local GappleToggle = Tabs.Bridge:AddToggle("AutoGappleHeal", {
    Title = "Auto Retreat & Eat GoldApple When Low HP",
    Description = "Backs up from the opponent and eats a Golden Apple when HP drops below threshold.",
    Default = true,
})

GappleToggle:OnChanged(function(val)
    State.AutoGappleHeal = val
end)

local HealSlider = Tabs.Bridge:AddSlider("HealThreshold", {
    Title = "GoldApple Heal HP Threshold",
    Default = 52,
    Min = 25,
    Max = 80,
    Rounding = 0,
})

HealSlider:OnChanged(function(val)
    State.HealThreshold = val
end)

SaveManager:SetLibrary(Fluent)
InterfaceManager:SetLibrary(Fluent)
SaveManager:IgnoreThemeSettings()
InterfaceManager:SetFolder("ConeHub")
SaveManager:SetFolder("ConeHub/BridgeDuels")
InterfaceManager:BuildInterfaceSection(Tabs.Settings)
SaveManager:BuildConfigSection(Tabs.Settings)

Window:SelectTab(1)

env.__BridgeDuelsAutoCleanup = function()
    State.Running = false
    State.DesiredMoveTarget = nil
    pcall(function()
        RunService:UnbindFromRenderStep("BridgeDuelsLegitMove")
    end)
    if charAddedConn then
        pcall(function() charAddedConn:Disconnect() end)
    end
end
