
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local LocalPlayer = Players.LocalPlayer

local env = (getgenv and getgenv()) or shared
if env.__SandsBelowAutoCleanup then
    pcall(env.__SandsBelowAutoCleanup)
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


local NetModule = nil
local function getNet()
    if NetModule then return NetModule end
    local sb = ReplicatedStorage:FindFirstChild("SandsBelow")
    if sb and sb:FindFirstChild("Net") then
        local ok, mod = pcall(require, sb.Net)
        if ok then
            NetModule = mod
            return NetModule
        end
    end
    return nil
end

local function fireNetEvent(eventName, ...)
    local net = getNet()
    if net and net.event then
        local ok, ev = pcall(net.event, eventName)
        if ok and ev then
            ev:FireServer(...)
            return true
        end
    end
    local sb = ReplicatedStorage:FindFirstChild("SandsBelow")
    local remFolder = sb and (sb:FindFirstChild("Remotes") or sb:FindFirstChild("Net"))
    local rem = remFolder and remFolder:FindFirstChild(eventName, true)
    if rem and rem:IsA("RemoteEvent") then
        rem:FireServer(...)
        return true
    end
    return false
end

local function invokeShopRequest(...)
    local net = getNet()
    if net and net.folder then
        local ok, folder = pcall(net.folder)
        if ok and folder and folder:FindFirstChild("ShopRequest") then
            local sOk, res = pcall(function(...)
                return folder.ShopRequest:InvokeServer(...)
            end, ...)
            if sOk then return res end
        end
    end
    return nil
end

local State = {
    Running = false,
    HumanLikeMode = true,
    AutoCampIntro = true,
    AutoEatDrink = true,
    AutoRestockShop = true,
    AutoVacuumLoot = true,
    AutoBreakCrates = true,
    AutoSolvePuzzles = true,
    AutoBossCombat = true,
    PassiveBossGuard = false,
    HungerThreshold = 82,
    ThirstThreshold = 80,
    HealThreshold = 75,
    TargetFloor = 100,
    SelectedLiftFloor = 25,
    StatusText = "Ready",
}

local FOOD_KEYWORDS = {
    "Dates", "Flatbread", "Jerky", "Honey", "Ration", "Beans", "Fig", "Bread", "Meat", "Stew", "Water", "Canteen", "Tea", "Juice",
}

local CAMP_CRATE_MAPPING = {
    { crate = "GearCrate_table",    site = "Site_table" },
    { crate = "GearCrate_tents",    site = "Site_tents" },
    { crate = "GearCrate_lanterns", site = "Site_lanterns" },
    { crate = "GearCrate_supplies", site = "Site_supplies" },
    { crate = "GearCrate_radio",    site = "Site_radio" },
    { crate = "GearCrate_winch",    site = "Site_winch" },
}

local StatusParagraph = nil
local function setStatus(msg)
    State.StatusText = msg
    if StatusParagraph then
        pcall(function()
            local depth = LocalPlayer:GetAttribute("Depth") or 0
            local hunger = math.floor(LocalPlayer:GetAttribute("Hunger") or 100)
            local gold = LocalPlayer:GetAttribute("Gold") or 0
            StatusParagraph:SetDesc(string.format("Floor: %d | Hunger: %d%% | Gold: %d\nAction: %s", depth, hunger, gold, msg))
        end)
    end
end


local function getCharacter()
    local char = LocalPlayer.Character
    if not char then return nil, nil, nil end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    local hum = char:FindFirstChildOfClass("Humanoid")
    return char, hrp, hum
end

local function isInTransitOrFalling()
    local _, hrp = getCharacter()
    if not hrp or hrp.Anchored then return true end
    local pgui = LocalPlayer:FindFirstChild("PlayerGui")
    if pgui then
        local hatchGui = pgui:FindFirstChild("SB_HatchFall")
        if hatchGui and hatchGui.Enabled then
            local frame = hatchGui:FindFirstChildWhichIsA("Frame", true)
            if frame and frame.BackgroundTransparency < 0.85 then
                return true
            end
        end
        local liftGui = pgui:FindFirstChild("SB_Lift")
        if liftGui and liftGui.Enabled then
            local frame = liftGui:FindFirstChildWhichIsA("Frame", true)
            if frame and frame.BackgroundTransparency < 0.85 then
                return true
            end
        end
    end
    return false
end

local function zeroMomentum()
    local _, hrp = getCharacter()
    if hrp then
        hrp.AssemblyLinearVelocity = Vector3.zero
        hrp.AssemblyAngularVelocity = Vector3.zero
    end
end

local function aimAtPosition(targetPos, smoothAlpha)
    local _, hrp = getCharacter()
    local cam = Workspace.CurrentCamera
    if not hrp or not cam then return Vector3.new(0, -1, 0) end

    smoothAlpha = smoothAlpha or (State.HumanLikeMode and 0.35 or 1.0)
    local standPos = hrp.Position
    local flatTarget = Vector3.new(targetPos.X, standPos.Y, targetPos.Z)
    if (flatTarget - standPos).Magnitude > 0.1 then
        hrp.CFrame = hrp.CFrame:Lerp(CFrame.lookAt(standPos, flatTarget), smoothAlpha)
    end

    local eyePos = standPos + Vector3.new(0, 1.5, 0)
    if (targetPos - eyePos).Magnitude > 0.1 then
        cam.CFrame = cam.CFrame:Lerp(CFrame.lookAt(eyePos, targetPos), smoothAlpha)
    end
    return cam.CFrame.LookVector
end

local function isListenerNearby(radius)
    radius = radius or 45
    local _, hrp = getCharacter()
    if not hrp then return false end
    for _, inst in ipairs(CollectionService:GetTagged("SB_Listener")) do
        local pos = inst:IsA("Model") and inst:GetPivot().Position or (inst:IsA("BasePart") and inst.Position)
        if pos and (pos - hrp.Position).Magnitude <= radius then
            return true
        end
    end
    local pyramid = Workspace:FindFirstChild("Pyramid")
    if pyramid then
        for _, desc in ipairs(pyramid:GetDescendants()) do
            if desc.Name == "Listener" and desc:IsA("Model") then
                if (desc:GetPivot().Position - hrp.Position).Magnitude <= radius then
                    return true
                end
            end
        end
    end
    return false
end

local function isDeceiverTrap(inst)
    if not inst then return false end
    local cur = inst
    while cur and cur ~= Workspace do
        if CollectionService:HasTag(cur, "SB_Deceiver") or cur.Name:find("Deceiver") or cur:GetAttribute("IsDeceiver") then
            return true
        end
        cur = cur.Parent
    end
    return false
end

local function vacuumNearbyPickups(maxDist)
    maxDist = maxDist or 22
    local _, hrp = getCharacter()
    if not hrp then return 0 end
    local pickupsFolder = Workspace:FindFirstChild("SB_Pickups")
    if not pickupsFolder then return 0 end

    local count = 0
    for _, item in ipairs(pickupsFolder:GetChildren()) do
        if not isDeceiverTrap(item) then
            local pos = item:IsA("BasePart") and item.Position or (item:IsA("Model") and item:GetPivot().Position)
            if pos and (pos - hrp.Position).Magnitude <= maxDist and math.abs(pos.Y - hrp.Position.Y) <= 10 then
                local prompt = item:FindFirstChildWhichIsA("ProximityPrompt", true)
                if prompt and prompt.Enabled and fireproximityprompt then
                    pcall(fireproximityprompt, prompt, 0)
                    count += 1
                end
            end
        end
    end
    return count
end

local function moveToPosition(targetPos, stopDist, timeout)
    stopDist = stopDist or 3.5
    timeout = timeout or 8.0
    local char, hrp, hum = getCharacter()
    if not char or not hrp or not hum then return false end
    if isInTransitOrFalling() then return false end

    hum.Sit = false

    if not State.HumanLikeMode then
        aimAtPosition(targetPos, 1.0)
        hrp.CFrame = CFrame.new(targetPos + Vector3.new(0, 2.2, 0))
        zeroMomentum()
        return true
    end

    local start = os.clock()
    local lastPos = hrp.Position
    local stuckTimer = os.clock()

    while os.clock() - start < timeout do
        if isInTransitOrFalling() then return false end
        char, hrp, hum = getCharacter()
        if not char or not hrp or not hum then return false end

        local dist = (Vector3.new(targetPos.X, hrp.Position.Y, targetPos.Z) - hrp.Position).Magnitude
        if dist <= stopDist and math.abs(targetPos.Y - hrp.Position.Y) <= 10 then
            return true
        end

        if isListenerNearby(45) then
            fireNetEvent("SetCrouch", true)
            LocalPlayer:SetAttribute("Crouching", true)
        elseif LocalPlayer:GetAttribute("Crouching") then
            fireNetEvent("SetCrouch", false)
            LocalPlayer:SetAttribute("Crouching", nil)
        end

        aimAtPosition(targetPos, 0.28)
        hum:MoveTo(targetPos)

        if (hrp.Position - lastPos).Magnitude > 1.2 then
            lastPos = hrp.Position
            stuckTimer = os.clock()
        elseif os.clock() - stuckTimer > 1.35 then
            local stepVec = (targetPos - hrp.Position)
            local stepDist = math.min(stepVec.Magnitude, 14)
            if stepDist > 0.5 then
                hrp.CFrame = CFrame.lookAt(hrp.Position + stepVec.Unit * stepDist + Vector3.new(0, 2.0, 0), targetPos)
                zeroMomentum()
            end
            stuckTimer = os.clock()
        end

        if State.AutoVacuumLoot then
            vacuumNearbyPickups(18)
        end
        task.wait(0.08)
    end

    if hrp and (hrp.Position - targetPos).Magnitude > stopDist then
        hrp.CFrame = CFrame.new(targetPos + Vector3.new(0, 2.2, 0))
        zeroMomentum()
    end
    return true
end


local function findConsumableTool()
    local char = LocalPlayer.Character
    local backpack = LocalPlayer:FindFirstChild("Backpack")

    local function scan(container)
        if not container then return nil end
        for _, item in ipairs(container:GetChildren()) do
            if item:IsA("Tool") then
                for _, kw in ipairs(FOOD_KEYWORDS) do
                    if item.Name:lower():find(kw:lower(), 1, true) then
                        return item
                    end
                end
            end
        end
        return nil
    end

    return scan(backpack) or scan(char)
end

local function eatOrDrinkSeamless()
    local char, _, hum = getCharacter()
    if not char or not hum then return false end

    local foodTool = findConsumableTool()
    if not foodTool then return false end

    local previousTool = char:FindFirstChildOfClass("Tool")
    hum:EquipTool(foodTool)
    task.wait(0.08)
    pcall(function() foodTool:Activate() end)
    fireNetEvent("Consume", foodTool.Name)
    fireNetEvent("Eat", foodTool.Name)
    task.wait(0.12)

    if previousTool and previousTool.Parent and previousTool ~= foodTool then
        pcall(function() hum:EquipTool(previousTool) end)
    end
    return true
end

local function checkAndMaintainVitals()
    if not State.AutoEatDrink then return false end
    local _, _, hum = getCharacter()
    if not hum then return false end

    local hunger = LocalPlayer:GetAttribute("Hunger") or 100
    local thirst = LocalPlayer:GetAttribute("Thirst") or 100
    local hp = hum.Health

    if hunger < State.HungerThreshold or thirst < State.ThirstThreshold or hp < State.HealThreshold then
        return eatOrDrinkSeamless()
    end
    return false
end

local function restockAtShop()
    if not State.AutoRestockShop then return end
    local gold = LocalPlayer:GetAttribute("Gold") or LocalPlayer:GetAttribute("Coins") or 0
    if gold < 10 then return end

    pcall(invokeShopRequest, "buyItem", "Pickaxe")
    pcall(invokeShopRequest, "buyItem", "Boots")

    local backpack = LocalPlayer:FindFirstChild("Backpack")
    local foodCount = 0
    if backpack then
        for _, item in ipairs(backpack:GetChildren()) do
            for _, kw in ipairs(FOOD_KEYWORDS) do
                if item.Name:lower():find(kw:lower(), 1, true) then
                    foodCount += 1
                    break
                end
            end
        end
    end

    if foodCount < 5 then
        for _ = 1, (5 - foodCount) do
            pcall(invokeShopRequest, "buyItem", "Dates")
            pcall(invokeShopRequest, "buyItem", "Flatbread")
            pcall(invokeShopRequest, "buyItem", "Water")
            task.wait(0.08)
        end
    end
end


local function completeCampIntro()
    local pgui = LocalPlayer:FindFirstChild("PlayerGui")
    if pgui and pgui:FindFirstChild("SB_Briefing") then
        pgui.SB_Briefing.Enabled = false
    end

    local camp = Workspace:FindFirstChild("Camp")
    if not camp then return false end

    local pDoor = camp:FindFirstChild("PyramidDoor")
    local doorSlab = pDoor and pDoor:FindFirstChild("Slab")
    if doorSlab and doorSlab.Position.Y > 12 then
        setStatus("Camp Intro already completed (Pyramid Door open)")
        return true
    end

    local cratesFolder = camp:FindFirstChild("GearCrates")
    local sitesFolder = camp:FindFirstChild("Sites")
    local char, hrp, hum = getCharacter()
    if not char or not hrp or not hum or not cratesFolder or not sitesFolder then
        return false
    end

    hum.Sit = false
    hum.Jump = true

    for _, mapping in ipairs(CAMP_CRATE_MAPPING) do
        local crate = cratesFolder:FindFirstChild(mapping.crate)
        local site = sitesFolder:FindFirstChild(mapping.site)
        local pad = site and site:FindFirstChild("Pad", true)

        if crate and crate.Parent == cratesFolder and pad then
            setStatus("Camp Intro: Delivering " .. mapping.crate .. " -> " .. mapping.site)
            local cratePos = crate:GetPivot().Position
            moveToPosition(cratePos + Vector3.new(0, 0, 2.5), 3.5, 6.0)
            aimAtPosition(cratePos, 1.0)
            task.wait(0.2)

            local prompt = crate:FindFirstChildWhichIsA("ProximityPrompt", true)
            if prompt then
                if fireproximityprompt then pcall(fireproximityprompt, prompt, 0) end
                pcall(function()
                    prompt:InputHoldBegin()
                    task.wait(0.06)
                    prompt:InputHoldEnd()
                end)
            end
            task.wait(0.3)

            local padPos = pad.Position
            moveToPosition(padPos, 3.0, 6.0)
            task.wait(0.2)

            if firetouchinterest then
                pcall(firetouchinterest, crate, pad, 0)
                pcall(firetouchinterest, hrp, pad, 0)
                task.wait(0.08)
                pcall(firetouchinterest, crate, pad, 1)
                pcall(firetouchinterest, hrp, pad, 1)
            end
            fireNetEvent("Drop")
            task.wait(0.35)
        end
    end

    local decor = camp:FindFirstChild("Decor")
    local campfire = (decor and decor:FindFirstChild("Campfire")) or camp:FindFirstChild("Campfire", true)
    local fireCore = (campfire and campfire:FindFirstChild("FireCore")) or camp:FindFirstChild("FireCore", true)
    if fireCore then
        setStatus("Camp Intro: Lighting Beacon...")
        local fcPos = fireCore:IsA("BasePart") and fireCore.Position or fireCore:GetPivot().Position
        moveToPosition(fcPos + Vector3.new(0, 0, 3), 4.0, 6.0)
        aimAtPosition(fcPos, 1.0)
        task.wait(0.2)
        local firePrompt = fireCore:FindFirstChildWhichIsA("ProximityPrompt", true) or (campfire and campfire:FindFirstChildWhichIsA("ProximityPrompt", true))
        if firePrompt then
            if fireproximityprompt then pcall(fireproximityprompt, firePrompt, 0) end
            pcall(function()
                firePrompt:InputHoldBegin()
                task.wait(0.06)
                firePrompt:InputHoldEnd()
            end)
        end
        task.wait(0.5)
    end

    restockAtShop()
    setStatus("Camp Intro 7/7 Complete!")
    return true
end


local function equipToolByKeyword(keywordList)
    local char, _, hum = getCharacter()
    if not char or not hum then return nil end

    for _, item in ipairs(char:GetChildren()) do
        if item:IsA("Tool") then
            for _, kw in ipairs(keywordList) do
                if item.Name:lower():find(kw:lower(), 1, true) then
                    return item
                end
            end
        end
    end

    local backpack = LocalPlayer:FindFirstChild("Backpack")
    if backpack then
        for _, item in ipairs(backpack:GetChildren()) do
            if item:IsA("Tool") then
                for _, kw in ipairs(keywordList) do
                    if item.Name:lower():find(kw:lower(), 1, true) then
                        hum:EquipTool(item)
                        task.wait(0.08)
                        return item
                    end
                end
            end
        end
    end
    return nil
end

local function breakNearbyContainers(floorModel, maxDist)
    if not State.AutoBreakCrates then return 0 end
    maxDist = maxDist or 24
    local char, hrp = getCharacter()
    if not char or not hrp or not floorModel then return 0 end

    local brokenCount = 0
    for _, desc in ipairs(floorModel:GetDescendants()) do
        if not State.Running then break end
        local isCrate = CollectionService:HasTag(desc, "SB_Breakable")
            or CollectionService:HasTag(desc, "SB_Crate")
            or CollectionService:HasTag(desc, "SB_Vase")
            or desc.Name == "Crate"
            or desc.Name == "Vase"
        if isCrate and (desc:IsA("Model") or desc:IsA("BasePart")) and not desc:GetAttribute("Broken") then
            local pos = desc:IsA("BasePart") and desc.Position or desc:GetPivot().Position
            if (pos - hrp.Position).Magnitude <= maxDist and math.abs(pos.Y - hrp.Position.Y) <= 10 then
                equipToolByKeyword({ "Pickaxe", "Pick" })
                local lookVec = aimAtPosition(pos, 1.0)
                for _ = 1, 3 do
                    if not desc.Parent or desc:GetAttribute("Broken") then break end
                    fireNetEvent("Swing", "perfect", lookVec)
                    LocalPlayer:SetAttribute("SwingAt", os.clock())
                    task.wait(0.26)
                end
                vacuumNearbyPickups(20)
                brokenCount += 1
            end
        end
    end
    return brokenCount
end

local function solveFloorPuzzle(puzzleModel)
    if not puzzleModel or not puzzleModel.Parent then return false end
    local pName = puzzleModel.Name:lower()
    setStatus("Solving Puzzle: " .. puzzleModel.Name)

    if pName:find("mirror") then
        for _ = 1, 40 do
            if not puzzleModel.Parent then break end
            if puzzleModel:GetAttribute("Solved") == true or (puzzleModel:GetAttribute("ProgressK") or 0) >= 0.99 then
                return true
            end
            for _, desc in ipairs(puzzleModel:GetDescendants()) do
                if desc:IsA("ProximityPrompt") and desc.Enabled then
                    local partPos = desc.Parent:IsA("BasePart") and desc.Parent.Position or desc.Parent:GetPivot().Position
                    moveToPosition(partPos + Vector3.new(0, 0, 2), 4.0, 4.0)
                    for _ = 1, 8 do
                        if (puzzleModel:GetAttribute("ProgressK") or 0) >= 0.99 or puzzleModel:GetAttribute("Solved") == true then
                            return true
                        end
                        if fireproximityprompt then pcall(fireproximityprompt, desc, 0) end
                        task.wait(0.22)
                    end
                end
            end
            task.wait(0.2)
        end
        return true
    elseif pName:find("bell") then
        local listeningStone = puzzleModel:FindFirstChild("ListeningStone", true)
        if listeningStone then
            local lsPos = listeningStone:IsA("BasePart") and listeningStone.Position or listeningStone:GetPivot().Position
            moveToPosition(lsPos + Vector3.new(0, 0, 2.5), 4.0, 5.0)
            local lsPrompt = listeningStone:FindFirstChildWhichIsA("ProximityPrompt", true)
            if lsPrompt and fireproximityprompt then
                pcall(fireproximityprompt, lsPrompt, 0)
            end
            task.wait(3.2)
        end

        local bellPrompts = {}
        for _, desc in ipairs(puzzleModel:GetDescendants()) do
            if desc:IsA("ProximityPrompt") and (not listeningStone or not desc:IsDescendantOf(listeningStone)) then
                table.insert(bellPrompts, desc)
            end
        end

        local confirmedOrder = {}
        for step = 1, 5 do
            if puzzleModel:GetAttribute("Solved") == true then break end
            for _, bp in ipairs(bellPrompts) do
                if puzzleModel:GetAttribute("Solved") == true then return true end
                for _, prevPrompt in ipairs(confirmedOrder) do
                    local pPos = prevPrompt.Parent:IsA("BasePart") and prevPrompt.Parent.Position or prevPrompt.Parent:GetPivot().Position
                    moveToPosition(pPos, 5.0, 3.0)
                    if fireproximityprompt then pcall(fireproximityprompt, prevPrompt, 0) end
                    task.wait(0.32)
                end

                local candPos = bp.Parent:IsA("BasePart") and bp.Parent.Position or bp.Parent:GetPivot().Position
                moveToPosition(candPos, 5.0, 3.0)
                if fireproximityprompt then pcall(fireproximityprompt, bp, 0) end
                task.wait(0.38)

                local progStr = tostring(puzzleModel:GetAttribute("Progress") or "")
                local curStep = tonumber(progStr:match("^(%d+)")) or 0
                if curStep >= step or puzzleModel:GetAttribute("Solved") == true then
                    table.insert(confirmedOrder, bp)
                    break
                else
                    if listeningStone then
                        local lsPrompt = listeningStone:FindFirstChildWhichIsA("ProximityPrompt", true)
                        if lsPrompt and fireproximityprompt then
                            pcall(fireproximityprompt, lsPrompt, 0)
                            task.wait(2.8)
                        end
                    end
                end
            end
        end
        return true
    else
        for _ = 1, 6 do
            if puzzleModel:GetAttribute("Solved") == true then break end
            local triggered = 0
            for _, desc in ipairs(puzzleModel:GetDescendants()) do
                if desc:IsA("ProximityPrompt") and desc.Enabled then
                    local holder = desc.Parent
                    local alreadyLit = holder and (holder:GetAttribute("Lit") == true or holder:GetAttribute("Pulled") == true or holder:GetAttribute("Active") == true)
                    if not alreadyLit then
                        local pPos = holder:IsA("BasePart") and holder.Position or holder:GetPivot().Position
                        moveToPosition(pPos, 4.0, 4.5)
                        aimAtPosition(pPos, 1.0)
                        if fireproximityprompt then pcall(fireproximityprompt, desc, 0) end
                        triggered += 1
                        task.wait(0.25)
                    end
                end
            end
            if triggered == 0 then break end
        end
        return true
    end
end

local function waitForHatchLanding(expectedDepth)
    local start = os.clock()
    while os.clock() - start < 8.0 do
        if (LocalPlayer:GetAttribute("Depth") or 0) >= expectedDepth and not isInTransitOrFalling() then
            task.wait(0.4)
            zeroMomentum()
            return true
        end
        task.wait(0.15)
    end
    zeroMomentum()
    return true
end

local function mineCollapsedSlab(slab)
    if not slab or not slab.Parent then return false end
    local char, hrp = getCharacter()
    if not char or not hrp then return false end

    local slabPos = slab:IsA("BasePart") and slab.Position or slab:GetPivot().Position
    setStatus("Moving to CollapsedFloor Slab...")
    moveToPosition(slabPos + Vector3.new(0, 2.5, 0), 3.0, 7.0)

    local startDepth = LocalPlayer:GetAttribute("Depth") or 0
    local start = os.clock()

    while slab and slab.Parent and os.clock() - start < 22 do
        if isInTransitOrFalling() or (LocalPlayer:GetAttribute("Depth") or 0) > startDepth then
            break
        end
        local prog = slab:GetAttribute("Progress") or 0
        local maxProg = slab:GetAttribute("MaxProgress") or 100
        if prog >= maxProg or slab:GetAttribute("Broken") == true then
            break
        end

        if isListenerNearby(42) then
            fireNetEvent("SetCrouch", true)
            task.wait(0.35)
        else
            fireNetEvent("SetCrouch", false)
            equipToolByKeyword({ "Pickaxe", "Pick" })
            _, hrp = getCharacter()
            if hrp and (Vector3.new(slabPos.X, hrp.Position.Y, slabPos.Z) - hrp.Position).Magnitude > 4.5 then
                hrp.CFrame = CFrame.new(slabPos + Vector3.new(0, 2.8, 0))
            end
            aimAtPosition(slabPos - Vector3.new(0, 2, 0), 1.0)
            fireNetEvent("Swing", "perfect", Vector3.new(0, -1, 0))
            LocalPlayer:SetAttribute("SwingAt", os.clock())
            task.wait(0.28)
        end
    end

    waitForHatchLanding(startDepth + 1)
    return true
end

local function rideElevatorToFloor(targetFloor)
    local startDepth = LocalPlayer:GetAttribute("Depth") or 0
    if startDepth == targetFloor then return true end

    setStatus("Riding Elevator Lift to Floor " .. tostring(targetFloor) .. "...")
    fireNetEvent("LiftGo", targetFloor)
    local start = os.clock()
    while os.clock() - start < 14.0 do
        local curDepth = LocalPlayer:GetAttribute("Depth") or 0
        local _, hrp = getCharacter()
        if curDepth == targetFloor and hrp and not hrp.Anchored and not isInTransitOrFalling() then
            zeroMomentum()
            return true
        end
        task.wait(0.2)
    end
    zeroMomentum()
    return (LocalPlayer:GetAttribute("Depth") or 0) == targetFloor
end

local function handleBossEncounter(bossArena)
    if not bossArena or not bossArena.Parent then return false end

    local attrs = bossArena:GetAttributes()
    local cx = attrs.CX or bossArena:GetPivot().Position.X
    local fy = attrs.FloorY or bossArena:GetPivot().Position.Y
    local cz = attrs.CZ or bossArena:GetPivot().Position.Z
    local centerPos = Vector3.new(cx, fy + 3, cz)

    setStatus("Engaging Floor Boss (5-Indicator Dodge & Parry)...")
    checkAndMaintainVitals()
    moveToPosition(centerPos, 4.0, 6.0)

    local orbitAngle = 0
    local start = os.clock()

    while bossArena and bossArena.Parent and os.clock() - start < 240 and State.Running do
        local char, hrp, hum = getCharacter()
        if not char or not hrp or not hum or hum.Health <= 0 then return false end

        checkAndMaintainVitals()

        local slab = bossArena.Parent:FindFirstChild("CollapsedFloor", true)
        if slab and not slab:GetAttribute("Locked") and bossArena:GetAttribute("Cleared") == true then
            setStatus("Boss Defeated! Proceeding to exit slab...")
            return true
        end

        local bossModel = nil
        local staticTentacle = nil
        local redHazardPos = nil
        local goldParryActive = false
        local blueSlamActive = false
        local purpleDuckActive = false

        for _, desc in ipairs(Workspace:GetDescendants()) do
            if desc:IsA("Model") then
                if desc:GetAttribute("Glow") == "parry" or desc:GetAttribute("Windup") == "parry" then
                    goldParryActive = true
                end
                if desc:GetAttribute("CornerCue") == "low" or desc:GetAttribute("AttackKind") == "slam" then
                    blueSlamActive = true
                elseif desc:GetAttribute("CornerCue") == "high" or desc:GetAttribute("AttackKind") == "duck" then
                    purpleDuckActive = true
                end
                if CollectionService:HasTag(desc, "SB_CoveWarden") or desc.Name:find("Warden") or desc.Name:find("Essence") then
                    bossModel = desc
                elseif desc.Name:find("Tentacle") and desc:IsDescendantOf(bossArena.Parent) then
                    staticTentacle = desc
                end
            elseif desc:IsA("BasePart") and (desc.Name:find("Scar") or desc.Name:find("Telegraph") or (desc.Color.R > 0.75 and desc.Color.G < 0.25 and desc.Size.Magnitude > 8)) then
                if (desc.Position - hrp.Position).Magnitude < 16 then
                    redHazardPos = desc.Position
                end
            end
        end

        if goldParryActive then
            fireNetEvent("Parry", os.clock())
            LocalPlayer:SetAttribute("ParryPress", os.clock())
        end

        if blueSlamActive then
            hum.Jump = true
        end

        if purpleDuckActive then
            fireNetEvent("SetCrouch", true)
            LocalPlayer:SetAttribute("Crouching", true)
            task.delay(0.75, function()
                fireNetEvent("SetCrouch", false)
                LocalPlayer:SetAttribute("Crouching", nil)
            end)
        end

        orbitAngle += 0.22
        local desiredPos = Vector3.new(cx + math.cos(orbitAngle) * 18, fy + 3, cz + math.sin(orbitAngle) * 18)
        if redHazardPos then
            local awayDir = (hrp.Position - redHazardPos)
            awayDir = Vector3.new(awayDir.X, 0, awayDir.Z)
            if awayDir.Magnitude < 0.1 then awayDir = Vector3.new(1, 0, 0) end
            desiredPos = hrp.Position + awayDir.Unit * 22
        end

        local attackTarget = staticTentacle or bossModel
        if attackTarget then
            local targetPos = attackTarget:GetPivot().Position
            equipToolByKeyword({ "WardenBlade", "TimeBlade", "ShiftBlade", "Blade", "Sword", "Pickaxe" })
            local lookVec = aimAtPosition(targetPos, 0.65)
            if (targetPos - hrp.Position).Magnitude <= 18 then
                fireNetEvent("SwordSwing", lookVec, 1)
                fireNetEvent("Swing", "perfect", lookVec)
                LocalPlayer:SetAttribute("SwingAt", os.clock())
            else
                hum:MoveTo(targetPos)
            end
        else
            hum:MoveTo(desiredPos)
        end

        if not bossModel and (os.clock() - start > 8) and slab then
            return true
        end

        task.wait(0.14)
    end

    return true
end

local function scanCurrentFloorObjective(depth)
    local pyramid = Workspace:FindFirstChild("Pyramid")
    if not pyramid then return nil end
    local currentFloor = pyramid:FindFirstChild("Floor" .. tostring(depth))
    if not currentFloor then return nil end

    local bossArena = currentFloor:FindFirstChild("BossArena")
    local puzzle = nil
    for _, child in ipairs(currentFloor:GetChildren()) do
        if child.Name:find("^Puzzle_") then
            puzzle = child
            break
        end
    end
    local hatch = currentFloor:FindFirstChild("Hatch", true)
    local slab = currentFloor:FindFirstChild("CollapsedFloor", true)

    return {
        FloorModel = currentFloor,
        BossArena = bossArena,
        Puzzle = puzzle,
        Hatch = hatch,
        Slab = slab,
    }
end

local function stepCurrentFloor()
    if isInTransitOrFalling() then
        setStatus("In transit / falling — stabilizing...")
        task.wait(0.3)
        zeroMomentum()
        return true
    end

    checkAndMaintainVitals()
    if State.AutoVacuumLoot then
        vacuumNearbyPickups(22)
    end

    local depth = LocalPlayer:GetAttribute("Depth") or 0
    if depth == 0 then
        if State.AutoCampIntro then
            completeCampIntro()
        end
        restockAtShop()
        local pyramid = Workspace:FindFirstChild("Pyramid")
        local f1 = pyramid and pyramid:FindFirstChild("Floor1")
        if f1 then
            setStatus("Entering Pyramid -> Floor 1")
            moveToPosition(f1:GetPivot().Position, 5.0, 8.0)
        else
            rideElevatorToFloor(1)
        end
        return true
    end

    if depth == 25 then
        restockAtShop()
    end

    local info = scanCurrentFloorObjective(depth)
    if not info then
        setStatus(string.format("Waiting for Floor %d geometry...", depth))
        task.wait(0.4)
        return true
    end

    breakNearbyContainers(info.FloorModel, 24)

    if info.BossArena and State.AutoBossCombat and info.BossArena:GetAttribute("Cleared") ~= true then
        handleBossEncounter(info.BossArena)
    end

    if info.Puzzle and State.AutoSolvePuzzles and info.Puzzle:GetAttribute("Solved") ~= true then
        solveFloorPuzzle(info.Puzzle)
    end

    if info.Hatch and info.Hatch:GetAttribute("Open") == true then
        local hPos = info.Hatch:IsA("BasePart") and info.Hatch.Position or info.Hatch:GetPivot().Position
        setStatus(string.format("Floor %d: Stepping into open Hatch", depth))
        moveToPosition(hPos, 2.5, 6.0)
        waitForHatchLanding(depth + 1)
        return true
    end

    if info.Slab then
        setStatus(string.format("Floor %d: Mining CollapsedFloor Slab", depth))
        mineCollapsedSlab(info.Slab)
        return true
    end

    return true
end


local Window = Fluent:CreateWindow({
    Title = "Cone Hub | Sands Below 1–100 Auto-Play",
    SubTitle = "Human-Like Camp Intro, Food/Water, Puzzles & Bosses",
    TabWidth = 160,
    Size = UDim2.fromOffset(600, 480),
    Acrylic = false,
    Theme = "Dark",
    MinimizeKey = Enum.KeyCode.RightControl,
})

local Tabs = {
    Main = Window:AddTab({ Title = "1-100 Auto-Play", Icon = "compass" }),
    Vitals = Window:AddTab({ Title = "Food, Water & Camp", Icon = "heart" }),
    Puzzles = Window:AddTab({ Title = "Puzzles & Lift", Icon = "layers" }),
    Boss = Window:AddTab({ Title = "Boss Combat", Icon = "shield" }),
    Settings = Window:AddTab({ Title = "Settings", Icon = "settings" }),
}

StatusParagraph = Tabs.Main:AddParagraph({
    Title = "Expedition Telemetry",
    Content = "Ready — Toggle Full 1-100 Auto-Play to start from Camp or any Floor.",
})

local AutoPlayToggle = Tabs.Main:AddToggle("FullAutoPlay100", {
    Title = "Full Floors 1–100 Human-Like Auto-Play",
    Description = "Automatically completes Camp Intro, manages Food/Water, solves puzzles, fights bosses, and descends to Target Floor.",
    Default = false,
})

AutoPlayToggle:OnChanged(function(val)
    State.Running = val
    if val then
        task.spawn(function()
            while State.Running do
                local curDepth = LocalPlayer:GetAttribute("Depth") or 0
                if curDepth >= State.TargetFloor and State.TargetFloor > 0 then
                    local info = scanCurrentFloorObjective(curDepth)
                    if not (info and info.BossArena and info.BossArena:GetAttribute("Cleared") ~= true) then
                        setStatus("Reached Target Floor " .. tostring(curDepth) .. "!")
                        State.Running = false
                        break
                    end
                end
                pcall(stepCurrentFloor)
                task.wait(0.2)
            end
        end)
    else
        setStatus("Paused.")
    end
end)

local ModeToggle = Tabs.Main:AddToggle("HumanLikeMode", {
    Title = "Human-Like Walking & Smooth Camera Aim",
    Description = "Walks naturally with smooth camera look, Listener stealth crouch, and path unsticking (disable for instant CFrame speedrun).",
    Default = true,
})

ModeToggle:OnChanged(function(val)
    State.HumanLikeMode = val
end)

local TargetFloorSlider = Tabs.Main:AddSlider("TargetFloorSlider", {
    Title = "Target Floor Goal",
    Description = "Floor where the auto-player stops after clearing the room/boss.",
    Default = 100,
    Min = 1,
    Max = 100,
    Rounding = 0,
})

TargetFloorSlider:OnChanged(function(val)
    State.TargetFloor = val
end)

Tabs.Main:AddButton({
    Title = "Complete Current Floor Step Once",
    Description = "Solves the current room's puzzle, boss, or slab once without looping.",
    Callback = function()
        task.spawn(function()
            State.Running = true
            pcall(stepCurrentFloor)
            State.Running = false
        end)
    end,
})

Tabs.Vitals:AddButton({
    Title = "Complete Camp Intro Setup (0/7 Crates + Beacon)",
    Description = "Carries all 6 expedition crates to their pads and lights the beacon to unseal the pyramid.",
    Callback = function()
        task.spawn(function()
            State.Running = true
            pcall(completeCampIntro)
            State.Running = false
        end)
    end,
})

local AutoEatToggle = Tabs.Vitals:AddToggle("AutoEatDrink", {
    Title = "Auto Eat & Drink (Hunger / Thirst / HP)",
    Description = "Seamlessly equips and consumes Dates, Flatbread, Jerky, Honey, or Water when vitals drop.",
    Default = true,
})

AutoEatToggle:OnChanged(function(val)
    State.AutoEatDrink = val
end)

local HungerSlider = Tabs.Vitals:AddSlider("HungerThreshold", {
    Title = "Eat When Hunger Below (%)",
    Default = 82,
    Min = 30,
    Max = 95,
    Rounding = 0,
})

HungerSlider:OnChanged(function(val)
    State.HungerThreshold = val
end)

local ShopToggle = Tabs.Vitals:AddToggle("AutoRestockShop", {
    Title = "Auto Buy Food, Water & Upgrades at Camp / Shed",
    Description = "Buys Dates, Flatbread, Water, Pickaxe, and Boots when Gold is available.",
    Default = true,
})

ShopToggle:OnChanged(function(val)
    State.AutoRestockShop = val
end)

local VacuumToggle = Tabs.Vitals:AddToggle("AutoVacuumLoot", {
    Title = "Auto Vacuum Ground Pickups (Skips Deceivers)",
    Description = "Automatically collects nearby Gold, Food, and Artifacts while ignoring SB_Deceiver mimic traps.",
    Default = true,
})

VacuumToggle:OnChanged(function(val)
    State.AutoVacuumLoot = val
end)

Tabs.Vitals:AddButton({
    Title = "Buy Provisions & Eat Right Now",
    Description = "Restocks Dates/Flatbread/Water from shop and eats immediately.",
    Callback = function()
        task.spawn(function()
            restockAtShop()
            eatOrDrinkSeamless()
        end)
    end,
})

Tabs.Puzzles:AddButton({
    Title = "Auto-Solve Current Room Puzzle",
    Description = "Solves Braziers, Echo Bells (5-Bell sequence), Sun Mirrors, or Levers on the current floor.",
    Callback = function()
        task.spawn(function()
            local depth = LocalPlayer:GetAttribute("Depth") or 0
            local info = scanCurrentFloorObjective(depth)
            if info and info.Puzzle then
                State.Running = true
                solveFloorPuzzle(info.Puzzle)
                State.Running = false
            else
                setStatus("No active puzzle found on Floor " .. tostring(depth))
            end
        end)
    end,
})

Tabs.Puzzles:AddButton({
    Title = "Mine Current Floor Slab",
    Description = "Moves to the CollapsedFloor slab and swings Pickaxe with perfect rhythm.",
    Callback = function()
        task.spawn(function()
            local depth = LocalPlayer:GetAttribute("Depth") or 0
            local info = scanCurrentFloorObjective(depth)
            if info and info.Slab then
                State.Running = true
                mineCollapsedSlab(info.Slab)
                State.Running = false
            end
        end)
    end,
})

local LiftSlider = Tabs.Puzzles:AddSlider("LiftFloorSelect", {
    Title = "Elevator Lift Target Floor",
    Default = 25,
    Min = 1,
    Max = 100,
    Rounding = 0,
})

LiftSlider:OnChanged(function(val)
    State.SelectedLiftFloor = val
end)

Tabs.Puzzles:AddButton({
    Title = "Ride Elevator Lift (LiftGo) to Selected Floor",
    Description = "Safely fires LiftGo with velocity zeroing and anti-fling synchronization.",
    Callback = function()
        task.spawn(function()
            rideElevatorToFloor(State.SelectedLiftFloor)
        end)
    end,
})

local BossCombatToggle = Tabs.Boss:AddToggle("AutoBossCombat", {
    Title = "Auto Boss Combat (5-Indicator Dodge, Parry & Sever)",
    Description = "Handles Gold Parry, Red Floor Scars, Blue Jump Waves, Purple High Sweeps, and Tentacle Severing.",
    Default = true,
})

BossCombatToggle:OnChanged(function(val)
    State.AutoBossCombat = val
end)

Tabs.Boss:AddButton({
    Title = "Manual Perfect Parry Now",
    Description = "Immediately fires the Parry remote.",
    Callback = function()
        fireNetEvent("Parry", os.clock())
        LocalPlayer:SetAttribute("ParryPress", os.clock())
    end,
})

SaveManager:SetLibrary(Fluent)
InterfaceManager:SetLibrary(Fluent)
SaveManager:IgnoreThemeSettings()
InterfaceManager:SetFolder("ConeHub")
SaveManager:SetFolder("ConeHub/SandsBelow")
InterfaceManager:BuildInterfaceSection(Tabs.Settings)
SaveManager:BuildConfigSection(Tabs.Settings)

Window:SelectTab(1)

env.__SandsBelowAutoCleanup = function()
    State.Running = false
end
