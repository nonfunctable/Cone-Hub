local env = getgenv()
if env.__MAMStop then pcall(env.__MAMStop) end
local running = true
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local lp = Players.LocalPlayer
local GS = require(RS.Modules.GameState)

local function loadRemoteModule(primaryUrl, fallbackUrl)
    local ok, src = pcall(function() return game:HttpGet(primaryUrl) end)
    if ok and type(src) == "string" and #src > 100 and not src:find("^404:") then
        local fn = loadstring(src)
        if fn then return fn() end
    end
    return loadstring(game:HttpGet(fallbackUrl))()
end
local Fluent = loadRemoteModule("https://raw.githubusercontent.com/nonfunctable/Cone-Hub/main/UI/Fluent.lua",
    "https://github.com/dawid-scripts/Fluent/releases/latest/download/main.lua")
local Window = Fluent:CreateWindow({ Title = "Cone Hub", SubTitle = "My Anime Mine", TabWidth = 140,
    Size = UDim2.fromOffset(520, 400), Acrylic = false, Theme = "Darker", MinimizeKey = Enum.KeyCode.RightControl })
local Home = Window:AddTab({ Title = "Home", Icon = "home" })
local StatusP = Home:AddParagraph({ Title = "Status", Content = "Starting..." })
local StatsP = Home:AddParagraph({ Title = "Progress", Content = "" })
local LogP = Home:AddParagraph({ Title = "Recent actions", Content = "" })
Window:SelectTab(1)
pcall(function() Window:Minimize() end)
Fluent:Notify({ Title = "Cone Hub", Content = "My Anime Mine auto-play running. RightCtrl shows the status page.", Duration = 6 })

local status = "starting"
local log = {}
local stats = { mined = 0, sells = 0, pickaxes = 0, t0 = os.clock() }
local function slog(s)
    table.insert(log, 1, os.date("%H:%M:%S") .. "  " .. s)
    if #log > 8 then table.remove(log) end
end

local function data() local ok, d = pcall(GS.GetData) return ok and d or {} end
local function mine() return (data().MineGame) or {} end
local function money() return tonumber(data().Money) or 0 end
local function hrp() local c = lp.Character return c and c:FindFirstChild("HumanoidRootPart") end
local function hum() local c = lp.Character return c and c:FindFirstChildOfClass("Humanoid") end
local function plot()
    local idx = lp:GetAttribute("MinePlotIndex")
    return idx and workspace.MineWorld.Plots:FindFirstChild("MinePlot" .. tostring(idx))
end
local function fmt(n)
    n = tonumber(n) or 0
    local units = { "", "K", "M", "B", "T", "Qa", "Qi" }
    local i = 1
    while n >= 1000 and i < #units do n = n / 1000 i += 1 end
    return string.format(i == 1 and "%d%s" or "%.2f%s", n, units[i])
end

local function walkTo(target, reach)
    local r = hrp()
    if not r then return false end
    reach = reach or 5
    if (r.Position - target).Magnitude <= reach then return true end
    local dir = Vector3.new(r.Position.X - target.X, 0, r.Position.Z - target.Z)
    dir = dir.Magnitude > 0.1 and dir.Unit or Vector3.new(1, 0, 0)
    local stand = target + dir * math.max(2.5, reach - 2) + Vector3.new(0, 3, 0)
    local cf = CFrame.lookAt(stand, Vector3.new(target.X, stand.Y, target.Z))
    local d = data()
    local ok = d.TeleportToCFrame and pcall(d.TeleportToCFrame, cf)
    task.wait(0.05)
    if (r.Position - stand).Magnitude > 4 then r.CFrame = cf end
    task.wait(0.1)
    return true
end

local function usePrompt(model)
    if not model then return false end
    local pp = model:FindFirstChildWhichIsA("ProximityPrompt", true)
    local cd = model:FindFirstChildWhichIsA("ClickDetector", true)
    local part = (pp and pp.Parent) or (cd and cd.Parent) or model:FindFirstChildWhichIsA("BasePart", true)
    if not part then return false end
    local pos = part:IsA("Attachment") and part.WorldPosition or part.Position
    walkTo(pos, pp and math.max(4, pp.MaxActivationDistance - 2) or 6)
    if pp then pcall(fireproximityprompt, pp) return true end
    if cd then pcall(fireclickdetector, cd, 0) return true end
    return false
end

local function mineOnce()
    local p = plot()
    if not p or not p:FindFirstChild("Nodes") then return false end
    local r = hrp()
    if not r then return false end
    local best, bd
    for _, n in ipairs(p.Nodes:GetChildren()) do
        local cd = n:FindFirstChild("NodeClick")
        local hp = n:GetAttribute("NodeHP")
        if cd and hp and hp > 0 then
            local d = (n:GetPivot().Position - r.Position).Magnitude
            if not bd or d < bd then best, bd = n, d end
        end
    end
    if not best then return false end
    status = string.format("Mining %s (%s HP)", tostring(best:GetAttribute("NodeTitle") or best.Name), fmt(best:GetAttribute("NodeHP")))
    walkTo(best:GetPivot().Position, 6)
    local cd = best:FindFirstChild("NodeClick")
    local t0 = os.clock()
    while running and best.Parent and cd.Parent and (best:GetAttribute("NodeHP") or 0) > 0 and os.clock() - t0 < 25 do
        pcall(fireclickdetector, cd, 0)
        task.wait(0.12)
    end
    stats.mined += 1
    return true
end

local MineInventory
for _, m in ipairs(RS.Modules:GetDescendants()) do if m:IsA("ModuleScript") and m.Name == "MineInventory" then MineInventory = require(m) break end end
local function takeChest()
    local chest = mine().Chest
    local n = 0
    for _, v in pairs(type(chest) == "table" and chest or {}) do n += tonumber(v) or 0 end
    if n == 0 then return end
    local p = plot()
    local pp = p and p:FindFirstChild("ChestPrompt", true)
    if pp and pp.Parent then
        local part = pp.Parent
        walkTo(part:IsA("Attachment") and part.WorldPosition or part.Position, 6)
    end
    pcall(GS.SendEvent, "MineTakeChest")
    task.wait(0.8)
    slog("Took " .. n .. " items from the chest")
end
local function sellChest()
    if not MineInventory then return end
    takeChest()
    local d2 = GS.GetData2 and GS.GetData2() or data()
    local ok, list = pcall(MineInventory.Collect, d2 and d2.MineGame, "All", MineInventory.KindOrder and MineInventory.KindOrder.OreFirst)
    if not ok or type(list) ~= "table" then return end
    local keys, worth = {}, 0
    for _, e in ipairs(list) do
        if e.Kind == "Ore" and (e.SellCount or e.Count or 0) > 0 and (e.Worth or 0) > 0 then
            keys[#keys + 1] = e.Key
            worth += (e.Worth or 0)
        end
    end
    if #keys == 0 then return end
    local st = workspace:FindFirstChild("SellStand")
    local pp = st and st:FindFirstChild("SellPrompt", true)
    if pp and pp.Parent then
        local part = pp.Parent
        walkTo(part:IsA("Attachment") and part.WorldPosition or part.Position, 6)
    end
    local before = money()
    pcall(GS.SendEvent, "MineSellItems", keys)
    task.wait(1.2)
    stats.sells += 1
    slog(string.format("Sold %d ore stacks (+$%s)", #keys, fmt(money() - before)))
end

local MineConfig, MineStock
for _, m in ipairs(RS.Modules:GetDescendants()) do
    if m:IsA("ModuleScript") and m.Name == "MineConfig" then MineConfig = require(m) end
    if m:IsA("ModuleScript") and m.Name == "MineStock" then MineStock = require(m) end
end
local function findMod(name)
    for _, m in ipairs(RS:GetDescendants()) do
        if m:IsA("ModuleScript") and m.Name == name then local ok, r = pcall(require, m) if ok then return r end end
    end
end
local QuestCat, SpinCfg = findMod("MineDailyQuestsCatalog"), findMod("MineDailySpinConfig")
stats.skills = stats.skills or 0
local function d2() local ok, d = pcall(GS.GetData2) return ok and d or data() end
local function send(...) return pcall(GS.SendEvent, ...) end

local function ownsPickaxe(name)
    local p = mine().Pickaxes
    if type(p) ~= "table" then return false end
    if (tonumber(p[name]) or 0) > 0 then return true end
    for _, v in ipairs(p) do if v == name or (type(v) == "table" and v.Name == name) then return true end end
    return false
end

local function buyPickaxe()
    if not MineConfig then return end
    local d = d2()
    local m = d.MineGame or {}
    local cash = tonumber(d.Money) or 0
    local best, bestIdx
    local topOwned = 0
    for idx, pk in ipairs(MineConfig.Pickaxes or {}) do if ownsPickaxe(pk.Name) then topOwned = idx end end
    for idx, pk in ipairs(MineConfig.Pickaxes or {}) do
        if idx <= topOwned then continue end
        local free = MineConfig.IsPickaxeFree and MineConfig.IsPickaxeFree(pk)
        if type(pk.Stock) == "table" and not pk.RobuxOnly and not free and (m.UnlockedZones or {})[pk.ZoneReq] and not ownsPickaxe(pk.Name) then
            local ok, left = true, nil
            if MineStock then ok, left = pcall(MineStock.GetRemaining, d, pk.Name) end
            if (tonumber(pk.Cost) or math.huge) <= cash and (not ok or type(left) ~= "number" or left > 0) then best, bestIdx = pk, idx end
        end
    end
    if not best then return false end
    local stand = workspace:FindFirstChild("PickaxesStand")
    if stand then usePrompt(stand) end
    send("MineBuyPickaxe", bestIdx)
    task.wait(1)
    if ownsPickaxe(best.Name) then
        stats.pickaxes += 1
        slog("Bought " .. best.Name .. " ($" .. fmt(best.Cost) .. ")")
        return true
    end
    return false
end

local function skillsSig(z)
    local t = ((mine().Skills or {})[z]) or {}
    local n = 0
    for _, v in pairs(t) do n += tonumber(v) or 0 end
    return n
end
local function buySkills()
    if not MineConfig or not MineConfig.GetSkillNodes then return end
    local m = mine()
    local z = "Z" .. tostring(m.CurrentZone or 1)
    if not (m.UnlockedZones or {})[z] then return end
    local bought = 0
    for _ = 1, 40 do
        if not running then break end
        local sk = ((mine().Skills or {})[z]) or {}
        local progressed = false
        for _, node in ipairs(MineConfig.GetSkillNodes(z)) do
            if not MineConfig.IsSkillNodeMaxed(sk, node) and MineConfig.IsSkillNodeOpen(sk, node) then
                local before = skillsSig(z)
                send("MineBuySkill", z, node.Family, node.Id)
                task.wait(0.35)
                if skillsSig(z) > before then bought += 1 progressed = true break end
            end
        end
        if not progressed then break end
    end
    if bought > 0 then stats.skills += bought slog("Bought " .. bought .. " skill pips (" .. z .. ")") end
end

local function advanceZone()
    if not MineConfig then return end
    local m = mine()
    local cur = tonumber(m.CurrentZone) or 1
    local keys = MineConfig.ZoneKeys or {}
    local hi = cur
    for i, k in ipairs(keys) do if (m.UnlockedZones or {})[k] then hi = math.max(hi, i) end end
    local nextKey = keys[hi + 1]
    if nextKey and not (m.UnlockedZones or {})[nextKey] then
        local done = MineConfig.IsZoneResearchComplete and MineConfig.IsZoneResearchComplete(m.Skills or {}, keys[hi])
        if done then
            send("MineSelectZone", nextKey)
            task.wait(1.5)
            if (mine().UnlockedZones or {})[nextKey] then slog("Unlocked zone " .. nextKey) hi += 1 end
        end
    end
    if hi > cur and keys[hi] then
        send("MineSelectZone", keys[hi])
        task.wait(1.5)
        slog("Moved to zone " .. keys[hi])
    end
end

local lastDaily = 0
local function dailies()
    if os.clock() - lastDaily < 120 then return end
    lastDaily = os.clock()
    if QuestCat and QuestCat.Events then
        if QuestCat.Events.Open then send(QuestCat.Events.Open) end
        for slot = 1, 8 do send(QuestCat.Events.Claim, slot) end
        if QuestCat.GrandSlot then send(QuestCat.Events.Claim, QuestCat.GrandSlot) end
    end
    if SpinCfg and SpinCfg.Events then
        if SpinCfg.Events.Open then send(SpinCfg.Events.Open) end
        if SpinCfg.Events.Spin then send(SpinCfg.Events.Spin) end
    end
    send("MineBuffModeClaim")
    local m = mine()
    if (tonumber(m.SummonScrolls) or 0) > 0 then send("MineSummon", math.min(10, m.SummonScrolls)) slog("Used summon scrolls") end
    if m.TutorialDone ~= true then send("MineTutorialGift") end
end

local function progress()
    status = "Upgrading"
    for _ = 1, 5 do if not buyPickaxe() then break end end
    buySkills()
    advanceZone()
    dailies()
    send("MineEquipBest")
end
local tryUpgrades = progress

local function tutorialHint()
    for _, d in ipairs(lp.PlayerGui:GetDescendants()) do
        if d:IsA("TextLabel") and d.Visible and d.AbsoluteSize.X > 200 and d.TextTransparency < 0.5 then
            local t = d.Text:gsub("<[^>]+>", "")
            local low = t:lower()
            if low:find("open it") or low:find("sell") or low:find("pickaxe") or low:find("chest") or low:find("equip") then
                return low
            end
        end
    end
end

local function followTutorial()
    if mine().TutorialDone == true or mine().TutorialSkipped == true then return end
    local hint = tutorialHint()
    if not hint then return end
    local p = plot()
    if hint:find("chest") and p and p:FindFirstChild("Chest") then
        status = "Tutorial: opening chest"
        if usePrompt(p.Chest) then slog("Tutorial: opened chest") end
    elseif hint:find("sell") and workspace:FindFirstChild("SellStand") then
        status = "Tutorial: going to sell"
        if usePrompt(workspace.SellStand) then slog("Tutorial: sell stand") end
        sellChest()
    elseif hint:find("pickaxe") and workspace:FindFirstChild("PickaxesStand") then
        status = "Tutorial: pickaxe stand"
        if usePrompt(workspace.PickaxesStand) then slog("Tutorial: pickaxe stand") end
        tryUpgrades()
    end
end

task.spawn(function()
    local lastSell, lastUp, lastTut = 0, 0, 0
    while running do
        local ok, err = pcall(function()
            if os.clock() - lastTut > 4 then lastTut = os.clock() followTutorial() end
            if os.clock() - lastSell > 20 then lastSell = os.clock() sellChest() end
            if os.clock() - lastUp > 30 then lastUp = os.clock() progress() end
            if not mineOnce() then status = "Waiting for ore nodes" task.wait(1) end
        end)
        if not ok then slog("err " .. tostring(err):sub(1, 60)) task.wait(1) end
        task.wait(0.1)
    end
end)

task.spawn(function()
    while running do
        pcall(function()
            local m = mine()
            local chestN = 0
            for _, v in pairs(type(m.Chest) == "table" and m.Chest or {}) do chestN += tonumber(v) or 0 end
            StatusP:SetDesc(status)
            StatsP:SetDesc(string.format("Cash: $%s\nZone: %s   Skills bought: %d\nChest items: %d\nNodes mined: %d   Sells: %d   Pickaxes bought: %d\nRunning %d min",
                fmt(money()), tostring(m.CurrentZone), stats.skills, chestN,
                stats.mined, stats.sells, stats.pickaxes, math.floor((os.clock() - stats.t0) / 60)))
            LogP:SetDesc(#log > 0 and table.concat(log, "\n") or "-")
        end)
        task.wait(1)
    end
end)

env.__MAMStop = function() running = false pcall(function() Fluent:Destroy() end) end
env.__MAMStatus = function() return status, stats, log end
return "My Anime Mine auto-play started"
