
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local LocalPlayer = Players.LocalPlayer

local env = (getgenv and getgenv()) or shared
if env.__PiggyAutoCleanup then
    pcall(env.__PiggyAutoCleanup)
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


local IGNORED_STRING_VALUES = {
    Classic = true,
    Idle = true,
    Patrolling = true,
    Chasing = true,
    Searching = true,
    Stunned = true,
    None = true,
    [""] = true,
}

local KNOWN_ITEM_NAMES = {
    "RedKey", "BlueKey", "GreenKey", "OrangeKey", "YellowKey", "PurpleKey", "WhiteKey", "GoldKey", "SilverKey",
    "NewRedKey", "NewBlueKey", "NewGreenKey", "NewOrangeKey", "NewYellowKey", "NewPurpleKey", "NewWhiteKey",
    "Hammer", "Wrench", "NewWrench", "Plank", "KeyCode", "Screwdriver", "Scissors", "Mop", "Battery",
    "Candle", "Shovel", "Ladder", "NewLadder", "Rope", "ElevatorKey", "Blowtorch", "GrappleHook",
    "SmokeGrenade", "Remote", "RustySword", "WoodenSword", "Axe", "NewAxe", "Katana", "Ticket",
    "PremiumTicket", "Box", "Strawberry", "Weights", "Pie", "Spray", "Crowbar", "Mirror", "Coin",
    "Gas", "FireExtinguisher", "Mallet", "WaterGun", "Book", "Torch", "LitTorch", "EmptyVial",
    "GreenVial", "PinkVial", "Apple", "Bone", "Carrot", "Grass", "TNT", "Crossbow", "Ammo",
    "BlueKeycard", "RedKeycard", "OrangeKeycard", "GreenKeycard", "RedGear", "GreenGear",
    "Dynamite", "Cure", "Potion", "Shell", "Teddy", "Rose", "Robot", "Dino", "Egg",
}

local KNOWN_ITEM_SET = {}
for _, name in ipairs(KNOWN_ITEM_NAMES) do
    KNOWN_ITEM_SET[name] = true
    KNOWN_ITEM_SET[name:lower()] = name
end

local MESH_COLOR_SIGNATURES = {
    ["456878024"] = function(hex)
        if hex == "00ffff" or hex == "0d69ac" or hex == "0989cf" then return "BlueKey" end
        if hex == "00ff00" or hex == "348e40" or hex == "287f47" then return "GreenKey" end
        if hex == "ff0000" or hex == "970000" or hex == "c4281c" then return "RedKey" end
        if hex == "d5733d" or hex == "da8541" or hex == "e29b40" then return "OrangeKey" end
        if hex == "efb838" or hex == "f5cd30" or hex == "ffff00" then return "YellowKey" end
        if hex == "b480ff" or hex == "8c5b9f" or hex == "6b327c" or hex == "aa00ff" then return "PurpleKey" end
        if hex == "f8f8f8" or hex == "ffffff" or hex == "e5e4df" then return "WhiteKey" end
        return "WhiteKey"
    end,
    ["991156270"] = function(hex)
        if hex == "00ffff" or hex == "0d69ac" or hex == "0989cf" then return "BlueKeycard" end
        if hex == "ff0000" or hex == "970000" or hex == "c4281c" then return "RedKeycard" end
        if hex == "d5733d" or hex == "da8541" then return "OrangeKeycard" end
        if hex == "00ff00" or hex == "348e40" then return "GreenKeycard" end
        return "BlueKeycard"
    end,
    ["524706126"] = function(hex)
        if hex == "ff5959" or hex == "ff0000" or hex == "c4281c" then return "RedGear" end
        if hex == "5b9a4c" or hex == "00ff00" or hex == "348e40" then return "GreenGear" end
        return "RedGear"
    end,
    ["16884681"] = function() return "Wrench" end,
    ["16198309"] = function() return "Hammer" end,
    ["32241525"] = function() return "Battery" end,
    ["72012879"] = function() return "Apple" end,
    ["27787143"] = function() return "Carrot" end,
    ["36365830"] = function() return "Carrot" end,
    ["12891705"] = function() return "Grass" end,
    ["6550055"] = function() return "Grass" end,
    ["455863651"] = function() return "Bone" end,
    ["12864071"] = function() return "Mallet" end,
    ["31584522"] = function() return "Torch" end,
    ["4687178936"] = function(hex)
        if hex == "00ff00" or hex == "4b974b" or hex == "348e40" then return "GreenVial" end
        if hex == "ff66cc" or hex == "ff00bf" or hex == "e8bac8" then return "PinkVial" end
        return "EmptyVial"
    end,
    ["741743576"] = function() return "Crowbar" end,
    ["725833400"] = function() return "Coin" end,
    ["70265804"] = function() return "Scissors" end,
}

local State = {
    Running = false,
    AutoLoop = false,
    SafeSkyEnabled = true,
    PiggyAvoidRadius = 22,
    StatusText = "Ready",
    SelectedItemName = "RedKey",
    SafePart = nil,
}

local function toHexColor(color3)
    if not color3 then return "" end
    local r = math.clamp(math.floor(color3.R * 255 + 0.5), 0, 255)
    local g = math.clamp(math.floor(color3.G * 255 + 0.5), 0, 255)
    local b = math.clamp(math.floor(color3.B * 255 + 0.5), 0, 255)
    return string.format("%02x%02x%02x", r, g, b)
end

local function extractMeshDigits(str)
    if type(str) ~= "string" then return nil end
    return str:match("(%d+)$")
end

local function normalizeItemNames(reqName)
    local variants = { reqName }
    if reqName:find("^New") then
        table.insert(variants, reqName:gsub("^New", ""))
    else
        table.insert(variants, "New" .. reqName)
    end
    return variants
end

local function getCharacter()
    local char = LocalPlayer.Character
    if not char then return nil, nil, nil end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    local hum = char:FindFirstChildOfClass("Humanoid")
    return char, hrp, hum
end

local function ensureSafePlatform()
    if State.SafePart and State.SafePart.Parent then
        return State.SafePart
    end
    local part = Instance.new("Part")
    part.Name = "PiggyUniversalSafeSky"
    part.Size = Vector3.new(28, 2, 28)
    part.Anchored = true
    part.CanCollide = true
    part.Transparency = 0.65
    part.Color = Color3.fromRGB(80, 180, 255)
    local _, hrp = getCharacter()
    local basePos = hrp and hrp.Position or Vector3.new(0, 100, 0)
    part.CFrame = CFrame.new(basePos.X, basePos.Y + 85, basePos.Z)
    part.Parent = Workspace
    State.SafePart = part
    return part
end

local function parkInSky()
    local _, hrp = getCharacter()
    if not hrp then return end
    local plat = ensureSafePlatform()
    hrp.AssemblyLinearVelocity = Vector3.zero
    hrp.AssemblyAngularVelocity = Vector3.zero
    hrp.CFrame = plat.CFrame + Vector3.new(0, 4, 0)
end

local function getEnemyPositions()
    local positions = {}
    local piggyFolder = Workspace:FindFirstChild("PiggyNPC")
    if piggyFolder then
        for _, child in ipairs(piggyFolder:GetChildren()) do
            local p = child:IsA("Model") and (child:FindFirstChild("HumanoidRootPart") or child.PrimaryPart or child:FindFirstChildWhichIsA("BasePart"))
            if p then
                table.insert(positions, p.Position)
            end
        end
    end
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer and plr.Character then
            local isEnemy = plr.Character:FindFirstChild("Enemy") or plr:FindFirstChild("Piggy")
            if isEnemy then
                local erp = plr.Character:FindFirstChild("HumanoidRootPart")
                if erp then
                    table.insert(positions, erp.Position)
                end
            end
        end
    end
    return positions
end

local function isPositionSafe(pos)
    for _, enemyPos in ipairs(getEnemyPositions()) do
        if (enemyPos - pos).Magnitude < State.PiggyAvoidRadius then
            return false
        end
    end
    return true
end

local function waitUntilPiggyClear(targetPos, timeout)
    timeout = timeout or 3.5
    local start = os.clock()
    while os.clock() - start < timeout do
        if isPositionSafe(targetPos) then
            return true
        end
        if State.SafeSkyEnabled then
            parkInSky()
        end
        task.wait(0.2)
    end
    return true
end

local function getActiveMapContainers()
    local containers = {}
    local seen = {}
    local function addContainer(inst)
        if inst and not seen[inst] then
            seen[inst] = true
            table.insert(containers, inst)
        end
    end
    local loadedMap = Workspace:FindFirstChild("LoadedMap")
    if loadedMap and #loadedMap:GetChildren() > 0 then
        addContainer(loadedMap)
    end
    for _, child in ipairs(Workspace:GetChildren()) do
        if child:IsA("Model") and child ~= LocalPlayer.Character and not Players:GetPlayerFromCharacter(child) then
            if child:FindFirstChild("Events") or child:FindFirstChild("Doors") or child:FindFirstChild("Items") or child:FindFirstChild("MainDoor") or child:FindFirstChild("EscapeTrigger", true) then
                addContainer(child)
            end
        end
    end
    return containers
end

local function classifyGroundItem(part)
    if not part or not part:IsA("BasePart") then return nil end
    if part:FindFirstChild("GiveCoinScript") or part.Name:find("PiggyToken") then
        return nil
    end

    local directMatch = part.Name:match("^Pickup_(.+)_Active$") or part.Name:match("^Pickup_(.+)$")
    if directMatch and not directMatch:find("^Item_") then
        return directMatch
    end
    if KNOWN_ITEM_SET[part.Name] then
        return part.Name
    end
    if KNOWN_ITEM_SET[part.Name:lower()] then
        return KNOWN_ITEM_SET[part.Name:lower()]
    end

    local cd = part:FindFirstChildOfClass("ClickDetector")
    if cd then
        local cdMatch = cd.Name:match("^ClickDetector_Pickup_(.+)$")
        if cdMatch and not cdMatch:find("^Item_") then
            return cdMatch
        end
    end

    local meshId = nil
    if part:IsA("MeshPart") and part.MeshId ~= "" then
        meshId = extractMeshDigits(part.MeshId)
    else
        local specialMesh = part:FindFirstChildOfClass("SpecialMesh")
        if specialMesh and specialMesh.MeshId ~= "" then
            meshId = extractMeshDigits(specialMesh.MeshId)
        end
    end

    local hex = toHexColor(part.Color)
    if meshId and MESH_COLOR_SIGNATURES[meshId] then
        return MESH_COLOR_SIGNATURES[meshId](hex)
    end

    local size = part.Size
    if math.abs(size.X - 2.95) < 0.25 and math.abs(size.Z - 0.5) < 0.25 then
        return "Plank"
    end

    return "UnknownItem_" .. part.Name
end

local function scanActiveGroundItems()
    local items = {}
    local seenParts = {}

    local function checkDescendant(inst)
        local part = nil
        if inst:IsA("ClickDetector") and inst.Parent and inst.Parent:IsA("BasePart") then
            part = inst.Parent
        elseif inst:IsA("BasePart") and (inst:FindFirstChild("ItemPickupScript") or inst:FindFirstChild("NewItemPickupScript") or inst:FindFirstChild("PickupScript") or inst:FindFirstChild("ClickEvent")) then
            part = inst
        end
        if not part or seenParts[part] then return end
        if part.Transparency >= 0.75 then return end

        local parentName = part.Parent and part.Parent.Name or ""
        local isItemFolder = parentName == "ItemSpawnsFolder" or parentName == "Items" or tonumber(parentName) ~= nil or part:FindFirstChild("ItemPickupScript") or part:FindFirstChild("NewItemPickupScript") or part.Name:find("^Pickup_")
        if not isItemFolder then return end

        seenParts[part] = true
        local itemName = classifyGroundItem(part)
        if itemName then
            table.insert(items, {
                Name = itemName,
                Part = part,
                Position = part.Position,
            })
        end
    end

    for _, child in ipairs(Workspace:GetChildren()) do
        if child.Name == "ItemSpawnsFolder" or tonumber(child.Name) ~= nil or child:IsA("Folder") then
            for _, desc in ipairs(child:GetDescendants()) do
                checkDescendant(desc)
            end
        end
    end
    for _, container in ipairs(getActiveMapContainers()) do
        for _, desc in ipairs(container:GetDescendants()) do
            checkDescendant(desc)
        end
    end

    return items
end

local function findInteractivePart(container)
    if not container then return nil end
    if container:IsA("BasePart") then return container end
    if container:IsA("Model") then
        for _, desc in ipairs(container:GetDescendants()) do
            if desc:IsA("ClickDetector") and desc.Parent and desc.Parent:IsA("BasePart") then
                return desc.Parent
            end
        end
        for _, desc in ipairs(container:GetDescendants()) do
            if desc:IsA("TouchTransmitter") and desc.Parent and desc.Parent:IsA("BasePart") then
                return desc.Parent
            end
        end
        if container.PrimaryPart then return container.PrimaryPart end
        return container:FindFirstChildWhichIsA("BasePart", true)
    end
    if container.Parent then
        return findInteractivePart(container.Parent)
    end
    return nil
end

local function scanMapRequirements()
    local locks = {}
    local seenHolders = {}

    local function inspectStringValue(sv)
        if not sv:IsA("StringValue") then return end
        local val = sv.Value
        local fromName = sv.Name:match("^RequiredItem_(.+)$")
        local reqItem = (val and val ~= "" and val) or fromName
        if not reqItem or IGNORED_STRING_VALUES[reqItem] then return end
        if sv.Name == "ThreeDTextParams" or reqItem:find("^%{") then return end

        local holder = sv.Parent
        if not holder or seenHolders[sv] then return end
        local targetPart = findInteractivePart(holder)
        if not targetPart or not targetPart.Parent then return end
        if targetPart.Transparency >= 0.98 and not targetPart:FindFirstChildOfClass("TouchTransmitter") and not targetPart:FindFirstChildOfClass("ClickDetector") then
            return
        end

        seenHolders[sv] = true
        table.insert(locks, {
            RequiredItem = reqItem,
            StringValue = sv,
            Holder = holder,
            TargetPart = targetPart,
            Position = targetPart.Position,
        })
    end

    for _, container in ipairs(getActiveMapContainers()) do
        for _, desc in ipairs(container:GetDescendants()) do
            if desc:IsA("StringValue") then
                inspectStringValue(desc)
            end
        end
    end

    return locks
end

local function scanEscapeTriggers()
    local triggers = {}
    local seen = {}
    for _, container in ipairs(getActiveMapContainers()) do
        for _, desc in ipairs(container:GetDescendants()) do
            if desc:IsA("BasePart") and not seen[desc] then
                local isEscape = desc.Name == "EscapeTrigger" or desc.Name == "Escape" or (desc.Parent and desc.Parent.Name == "MainDoor" and desc:FindFirstChildOfClass("TouchTransmitter") and desc.Size.Magnitude > 5)
                if isEscape then
                    seen[desc] = true
                    table.insert(triggers, desc)
                end
            end
        end
    end
    return triggers
end

local function getOwnedItemTool(itemName)
    local char = LocalPlayer.Character
    local backpack = LocalPlayer:FindFirstChild("Backpack")
    local variants = normalizeItemNames(itemName)

    local function matchContainer(folder)
        if not folder then return nil end
        for _, tool in ipairs(folder:GetChildren()) do
            if tool:IsA("Tool") then
                for _, v in ipairs(variants) do
                    if tool.Name:lower() == v:lower() or tool.Name:lower():find(v:lower(), 1, true) then
                        return tool
                    end
                end
            end
        end
        return nil
    end

    return matchContainer(char) or matchContainer(backpack)
end

local function getAnyOwnedTool()
    local char = LocalPlayer.Character
    local backpack = LocalPlayer:FindFirstChild("Backpack")
    if char then
        local t = char:FindFirstChildOfClass("Tool")
        if t and not t.Name:lower():find("gun") then return t end
    end
    if backpack then
        for _, t in ipairs(backpack:GetChildren()) do
            if t:IsA("Tool") then return t end
        end
    end
    return nil
end

local function pickupGroundItem(itemEntry)
    if not itemEntry or not itemEntry.Part or not itemEntry.Part.Parent then return false end
    local char, hrp, hum = getCharacter()
    if not char or not hrp or not hum then return false end

    waitUntilPiggyClear(itemEntry.Part.Position, 3.0)
    hrp.AssemblyLinearVelocity = Vector3.zero
    hrp.CFrame = CFrame.new(itemEntry.Part.Position + Vector3.new(0, 2.5, 0))
    task.wait(0.14)

    for _ = 1, 3 do
        if not itemEntry.Part or not itemEntry.Part.Parent or itemEntry.Part.Transparency >= 0.75 then
            break
        end
        local cd = itemEntry.Part:FindFirstChildOfClass("ClickDetector")
        if cd and fireclickdetector then
            pcall(fireclickdetector, cd, 0)
            pcall(fireclickdetector, cd)
        end
        local ce = itemEntry.Part:FindFirstChild("ClickEvent")
        if ce and ce:IsA("RemoteEvent") then
            pcall(function() ce:FireServer() end)
        end
        task.wait(0.1)
    end

    if State.SafeSkyEnabled then
        parkInSky()
    end
    return getOwnedItemTool(itemEntry.Name) ~= nil or getAnyOwnedTool() ~= nil
end

local function applyItemToLock(lockEntry, explicitTool)
    if not lockEntry or not lockEntry.TargetPart or not lockEntry.TargetPart.Parent then return false end
    local char, hrp, hum = getCharacter()
    if not char or not hrp or not hum then return false end

    local tool = explicitTool or getOwnedItemTool(lockEntry.RequiredItem)
    if not tool then return false end

    waitUntilPiggyClear(lockEntry.TargetPart.Position, 3.0)
    hum:EquipTool(tool)
    task.wait(0.1)

    local targetPos = lockEntry.TargetPart.Position
    hrp.CFrame = CFrame.new(targetPos + Vector3.new(0, 1.5, 2.5), targetPos)
    task.wait(0.15)

    local searchRoot = lockEntry.Holder or lockEntry.TargetPart
    local clickDetectors = {}
    local touchParts = {}
    local remoteEvents = {}

    if searchRoot:IsA("BasePart") then
        local cd = searchRoot:FindFirstChildOfClass("ClickDetector")
        if cd then table.insert(clickDetectors, cd) end
        if searchRoot:FindFirstChildOfClass("TouchTransmitter") then table.insert(touchParts, searchRoot) end
    end
    for _, desc in ipairs(searchRoot:GetDescendants()) do
        if desc:IsA("ClickDetector") then
            table.insert(clickDetectors, desc)
        elseif desc:IsA("TouchTransmitter") and desc.Parent and desc.Parent:IsA("BasePart") then
            table.insert(touchParts, desc.Parent)
        elseif desc:IsA("RemoteEvent") and (desc.Name == "ClickEvent" or desc.Name:find("Interact") or desc.Name:find("Use")) then
            table.insert(remoteEvents, desc)
        end
    end
    if searchRoot.Parent and (searchRoot.Parent:IsA("Model") or searchRoot.Parent:IsA("BasePart")) then
        for _, desc in ipairs(searchRoot.Parent:GetDescendants()) do
            if desc:IsA("ClickDetector") then
                table.insert(clickDetectors, desc)
            elseif desc:IsA("TouchTransmitter") and desc.Parent and desc.Parent:IsA("BasePart") then
                table.insert(touchParts, desc.Parent)
            end
        end
    end

    local handle = tool:FindFirstChild("Handle") or tool:FindFirstChildWhichIsA("BasePart")

    for _ = 1, 3 do
        for _, cd in ipairs(clickDetectors) do
            if fireclickdetector then
                pcall(fireclickdetector, cd, 0)
                pcall(fireclickdetector, cd)
            end
        end
        for _, re in ipairs(remoteEvents) do
            pcall(function() re:FireServer() end)
        end
        for _, tp in ipairs(touchParts) do
            if firetouchinterest then
                pcall(firetouchinterest, hrp, tp, 0)
                pcall(firetouchinterest, hrp, tp, 1)
                if handle then
                    pcall(firetouchinterest, handle, tp, 0)
                    pcall(firetouchinterest, handle, tp, 1)
                end
            end
        end
        if firetouchinterest then
            pcall(firetouchinterest, hrp, lockEntry.TargetPart, 0)
            pcall(firetouchinterest, hrp, lockEntry.TargetPart, 1)
            if handle then
                pcall(firetouchinterest, handle, lockEntry.TargetPart, 0)
                pcall(firetouchinterest, handle, lockEntry.TargetPart, 1)
            end
        end
        pcall(function() tool:Activate() end)
        task.wait(0.12)
    end

    if State.SafeSkyEnabled then
        parkInSky()
    end
    return true
end

local function triggerAuxiliarySwitches()
    local char, hrp = getCharacter()
    if not char or not hrp then return 0 end
    local count = 0

    for _, container in ipairs(getActiveMapContainers()) do
        for _, desc in ipairs(container:GetDescendants()) do
            if desc:IsA("ClickDetector") and desc.Parent and desc.Parent:IsA("BasePart") then
                local p = desc.Parent
                local nameLower = p.Name:lower()
                local parentLower = (p.Parent and p.Parent.Name or ""):lower()
                local isSwitch = nameLower:find("lever") or nameLower:find("switch") or nameLower:find("button") or nameLower:find("valve") or nameLower:find("generator") or parentLower:find("lever") or parentLower:find("switch")
                if isSwitch and not p:FindFirstChild("ItemPickupScript") and not p:FindFirstChild("NewItemPickupScript") then
                    hrp.CFrame = CFrame.new(p.Position + Vector3.new(0, 2, 2))
                    task.wait(0.1)
                    if fireclickdetector then
                        pcall(fireclickdetector, desc, 0)
                        pcall(fireclickdetector, desc)
                    end
                    count += 1
                end
            end
        end
    end

    if State.SafeSkyEnabled and count > 0 then
        parkInSky()
    end
    return count
end

local function attemptEscape()
    local char, hrp = getCharacter()
    if not char or not hrp then return false end
    local triggers = scanEscapeTriggers()
    if #triggers == 0 then return false end

    for _, trig in ipairs(triggers) do
        if trig and trig.Parent then
            hrp.CFrame = CFrame.new(trig.Position + Vector3.new(0, 1, 0))
            if firetouchinterest then
                pcall(firetouchinterest, hrp, trig, 0)
                task.wait(0.08)
                pcall(firetouchinterest, hrp, trig, 1)
            end
            task.wait(0.25)
        end
    end
    return true
end

local StatusParagraph = nil

local function setStatus(msg)
    State.StatusText = msg
    if StatusParagraph then
        pcall(function()
            StatusParagraph:SetDesc(msg)
        end)
    end
end

local function solveCurrentMatch()
    local char, hrp = getCharacter()
    if not char or not hrp then
        setStatus("Waiting for character inside active match...")
        return false
    end

    local usedLockHolders = {}

    for pass = 1, 28 do
        if not State.Running then
            setStatus("Stopped.")
            return false
        end

        attemptEscape()

        local locks = scanMapRequirements()
        local groundItems = scanActiveGroundItems()

        setStatus(string.format("Pass %d/28 | Remaining Locks: %d | Active Items: %d", pass, #locks, #groundItems))

        if #locks == 0 then
            triggerAuxiliarySwitches()
            if attemptEscape() then
                setStatus("All locks solved -> Triggered Escape!")
                return true
            end
        end

        local progressThisPass = false

        for _, lock in ipairs(locks) do
            if not usedLockHolders[lock.StringValue] then
                local ownedTool = getOwnedItemTool(lock.RequiredItem)
                if ownedTool then
                    setStatus("Applying held item: " .. lock.RequiredItem)
                    applyItemToLock(lock, ownedTool)
                    usedLockHolders[lock.StringValue] = os.clock()
                    progressThisPass = true
                    task.wait(0.35)
                end
            end
        end

        locks = scanMapRequirements()
        groundItems = scanActiveGroundItems()

        local neededMap = {}
        for _, lock in ipairs(locks) do
            local prevTime = usedLockHolders[lock.StringValue]
            if not prevTime or (os.clock() - prevTime > 4.5) then
                for _, v in ipairs(normalizeItemNames(lock.RequiredItem)) do
                    neededMap[v:lower()] = lock
                end
            end
        end

        for _, item in ipairs(groundItems) do
            if not State.Running then break end
            local matchedLock = nil
            for _, v in ipairs(normalizeItemNames(item.Name)) do
                if neededMap[v:lower()] then
                    matchedLock = neededMap[v:lower()]
                    break
                end
            end

            if matchedLock then
                setStatus(string.format("Collecting %s -> Unlocking %s", item.Name, matchedLock.RequiredItem))
                if pickupGroundItem(item) then
                    task.wait(0.2)
                    local tool = getOwnedItemTool(matchedLock.RequiredItem) or getAnyOwnedTool()
                    if tool then
                        applyItemToLock(matchedLock, tool)
                        usedLockHolders[matchedLock.StringValue] = os.clock()
                        progressThisPass = true
                        task.wait(0.45)
                        break
                    end
                end
            end
        end

        if not progressThisPass and #groundItems > 0 and #locks > 0 then
            for _, item in ipairs(groundItems) do
                if item.Name:find("^UnknownItem_") or neededMap[item.Name:lower()] then
                    setStatus("Testing unclassified ground item: " .. item.Name)
                    if pickupGroundItem(item) then
                        task.wait(0.2)
                        local tool = getAnyOwnedTool()
                        if tool then
                            for _, lock in ipairs(locks) do
                                applyItemToLock(lock, tool)
                                task.wait(0.2)
                            end
                            progressThisPass = true
                            break
                        end
                    end
                end
            end
        end

        if not progressThisPass then
            triggerAuxiliarySwitches()
            attemptEscape()
            if State.SafeSkyEnabled then
                parkInSky()
            end
            task.wait(0.6)
        end
    end

    attemptEscape()
    setStatus("Completed solver cycle.")
    return true
end


local Window = Fluent:CreateWindow({
    Title = "Cone Hub | Piggy Universal Auto-Solver",
    SubTitle = "Book 1, Book 2, Extra Chapters & Future Maps",
    TabWidth = 160,
    Size = UDim2.fromOffset(580, 460),
    Acrylic = false,
    Theme = "Dark",
    MinimizeKey = Enum.KeyCode.RightControl,
})

local Tabs = {
    Main = Window:AddTab({ Title = "Auto Escape", Icon = "zap" }),
    Items = Window:AddTab({ Title = "Items & Locks", Icon = "key" }),
    Safety = Window:AddTab({ Title = "Safety & Piggy", Icon = "shield" }),
    Settings = Window:AddTab({ Title = "Settings", Icon = "settings" }),
}

StatusParagraph = Tabs.Main:AddParagraph({
    Title = "Universal Solver Status",
    Content = "Ready — Works on Book 1, Book 2, Extra Maps & New Layouts",
})

Tabs.Main:AddButton({
    Title = "Finish Match (Universal Auto-Solve & Escape)",
    Description = "Automatically resolves all required items, safes, doors, NPCs, switches, and escapes.",
    Callback = function()
        if State.Running then return end
        State.Running = true
        task.spawn(function()
            pcall(solveCurrentMatch)
            if not State.AutoLoop then
                State.Running = false
            end
        end)
    end,
})

local AutoLoopToggle = Tabs.Main:AddToggle("AutoBeatLoop", {
    Title = "Auto-Beat Match Loop",
    Description = "Continuously solves and finishes matches automatically whenever a map loads.",
    Default = false,
})

AutoLoopToggle:OnChanged(function(val)
    State.AutoLoop = val
    State.Running = val
    if val then
        task.spawn(function()
            while State.AutoLoop do
                local containers = getActiveMapContainers()
                if #containers > 0 then
                    pcall(solveCurrentMatch)
                else
                    setStatus("Waiting for active Piggy map to load...")
                end
                task.wait(2.0)
            end
        end)
    end
end)

Tabs.Main:AddButton({
    Title = "Instant Touch Escape Trigger",
    Description = "Teleports to and touches the exit trigger if the main door is already open.",
    Callback = function()
        task.spawn(function()
            if attemptEscape() then
                setStatus("Touched Escape Trigger!")
            else
                setStatus("No active Escape Trigger found yet.")
            end
        end)
    end,
})

Tabs.Main:AddButton({
    Title = "Stop Current Action",
    Description = "Immediately halts the solver loop.",
    Callback = function()
        State.Running = false
        State.AutoLoop = false
        setStatus("Stopped by user.")
    end,
})

local InspectorParagraph = Tabs.Items:AddParagraph({
    Title = "Live Map Scan",
    Content = "Press 'Scan Current Map' to list all active ground items and remaining locks.",
})

Tabs.Items:AddButton({
    Title = "Scan Current Map (Items & Locks)",
    Description = "Detects all ground items (including hashed/Book 2 items) and lock requirements.",
    Callback = function()
        local items = scanActiveGroundItems()
        local locks = scanMapRequirements()
        local itemNames = {}
        for _, it in ipairs(items) do
            table.insert(itemNames, it.Name)
        end
        local lockNames = {}
        for _, lk in ipairs(locks) do
            table.insert(lockNames, lk.RequiredItem)
        end
        local summary = string.format(
            "Ground Items (%d): %s\nRemaining Locks (%d): %s",
            #itemNames,
            #itemNames > 0 and table.concat(itemNames, ", ") or "None",
            #lockNames,
            #lockNames > 0 and table.concat(lockNames, ", ") or "None"
        )
        InspectorParagraph:SetDesc(summary)
    end,
})

local ItemDropdown = Tabs.Items:AddDropdown("TargetItemSelect", {
    Title = "Select Item to Collect & Use",
    Values = KNOWN_ITEM_NAMES,
    Multi = false,
    Default = 1,
})

ItemDropdown:OnChanged(function(val)
    State.SelectedItemName = val
end)

Tabs.Items:AddButton({
    Title = "Collect & Unlock Selected Item",
    Description = "Picks up the selected item from the map and applies it to its matching lock/safe/door.",
    Callback = function()
        task.spawn(function()
            local target = State.SelectedItemName
            local items = scanActiveGroundItems()
            for _, it in ipairs(items) do
                if it.Name:lower() == target:lower() or it.Name:lower():find(target:lower(), 1, true) then
                    pickupGroundItem(it)
                    task.wait(0.2)
                    break
                end
            end
            local locks = scanMapRequirements()
            for _, lk in ipairs(locks) do
                if lk.RequiredItem:lower() == target:lower() or lk.RequiredItem:lower():find(target:lower(), 1, true) then
                    applyItemToLock(lk)
                    break
                end
            end
        end)
    end,
})

local SafeSkyToggle = Tabs.Safety:AddToggle("SafeSkyToggle", {
    Title = "Park in Sky Between Actions",
    Description = "Keeps your character on an elevated sky platform between item pickups and unlocks.",
    Default = true,
})

SafeSkyToggle:OnChanged(function(val)
    State.SafeSkyEnabled = val
    if val then
        parkInSky()
    end
end)

local AvoidRadiusSlider = Tabs.Safety:AddSlider("PiggyAvoidRadius", {
    Title = "Piggy Safety Radius (Studs)",
    Description = "Minimum distance from Piggy/Traitor required before teleporting to an item or lock.",
    Default = 22,
    Min = 10,
    Max = 50,
    Rounding = 0,
})

AvoidRadiusSlider:OnChanged(function(val)
    State.PiggyAvoidRadius = val
end)

Tabs.Safety:AddButton({
    Title = "Teleport to Sky Safe Platform Now",
    Description = "Immediately moves your character to the safe sky platform above the map.",
    Callback = function()
        parkInSky()
    end,
})

SaveManager:SetLibrary(Fluent)
InterfaceManager:SetLibrary(Fluent)
SaveManager:IgnoreThemeSettings()
InterfaceManager:SetFolder("ConeHub")
SaveManager:SetFolder("ConeHub/Piggy")
InterfaceManager:BuildInterfaceSection(Tabs.Settings)
SaveManager:BuildConfigSection(Tabs.Settings)

Window:SelectTab(1)

env.__PiggyAutoCleanup = function()
    State.Running = false
    State.AutoLoop = false
    if State.SafePart and State.SafePart.Parent then
        pcall(function() State.SafePart:Destroy() end)
    end
end
