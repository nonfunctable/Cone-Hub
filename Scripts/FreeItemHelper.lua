local env = getgenv()
local MPS = game:GetService("MarketplaceService")
local GS = game:GetService("GuiService")
local VIM = game:GetService("VirtualInputManager")
local TS = game:GetService("TeleportService")
local CG = game:GetService("CoreGui")
local Players = game:GetService("Players")
local lp = Players.LocalPlayer

local FIH = env.FIH or {}
env.FIH = FIH

local function strip(t) return (tostring(t or ""):gsub("<[^>]+>", "")) end
local function shown(g)
    if not (g:IsA("GuiObject") and g.AbsoluteSize.X > 0 and g.AbsoluteSize.Y > 0) then return false end
    local sg = g:FindFirstAncestorOfClass("ScreenGui")
    return not sg or sg.Enabled
end

local function corePress(btn)
    local ok = pcall(function() GS.SelectedCoreObject = btn end)
    task.wait(0.15)
    VIM:SendKeyEvent(true, Enum.KeyCode.ButtonA, false, game)
    task.wait(0.05)
    VIM:SendKeyEvent(false, Enum.KeyCode.ButtonA, false, game)
    task.wait(0.25)
    if btn.Parent and shown(btn) then
        VIM:SendKeyEvent(true, Enum.KeyCode.Return, false, game)
        task.wait(0.05)
        VIM:SendKeyEvent(false, Enum.KeyCode.Return, false, game)
    end
    pcall(function() GS.SelectedCoreObject = nil end)
    return ok
end
FIH.corePress = corePress

local function findSheet()
    for _, fo in ipairs(CG:GetChildren()) do
        if fo.Name == "FoundationOverlay" then
            for _, d in ipairs(fo:GetDescendants()) do
                if d.Name == "Sheet" and d:IsA("GuiObject") and shown(d) then return d end
            end
        end
    end
end

local function readSheet()
    local sheet = findSheet()
    if not sheet then return nil end
    local info = { sheet = sheet, kind = "other" }
    local buy = sheet:FindFirstChild("BuyButton", true)
    local nameL = sheet:FindFirstChild("ItemName", true)
    local costL = sheet:FindFirstChild("ItemCost", true)
    info.name = nameL and strip(nameL.Text) or nil
    info.cost = costL and strip(costL.Text) or nil
    if buy and buy:IsA("GuiButton") and shown(buy) then
        info.kind, info.button = "buy", buy
    else
        for _, d in ipairs(sheet:GetDescendants()) do
            if (d:IsA("TextLabel") or d:IsA("TextButton")) and strip(d.Text) == "OK" then
                info.kind = "done"
                info.button = d:IsA("GuiButton") and d or d:FindFirstAncestorWhichIsA("GuiButton")
                break
            end
        end
    end
    return info
end
FIH.readSheet = readSheet

local function isFreeCost(cost)
    if not cost then return false end
    local c = cost:lower()
    if c:find("free") then return true end
    local n = tonumber((c:gsub("%D", "")))
    return n == 0
end

function FIH.dismiss()
    local closed = false
    local s = readSheet()
    if s and s.kind == "done" and s.button then corePress(s.button) closed = true end
    local pf = CG:FindFirstChild("RobloxGui") and CG.RobloxGui:FindFirstChild("PopupFrame")
    local okb = pf and pf:FindFirstChild("PopupOKButton")
    if okb and shown(okb) then corePress(okb) closed = true end
    return closed
end

function FIH.acceptFree(timeout, expectedName)
    local t0 = os.clock()
    local s
    repeat
        s = readSheet()
        if s and s.kind == "buy" then break end
        task.wait(0.2)
    until os.clock() - t0 > (timeout or 10)
    if not (s and s.kind == "buy") then return false, "no buy prompt" end
    task.wait(0.4)
    s = readSheet()
    if not (s and s.kind == "buy") then return false, "prompt closed" end
    if not isFreeCost(s.cost) then return false, "NOT FREE (" .. tostring(s.cost) .. ") - left for you" end
    if expectedName and s.name ~= expectedName then return false, "prompt is for '" .. tostring(s.name) .. "'" end
    corePress(s.button)
    local t1 = os.clock()
    repeat
        task.wait(0.3)
        local d = readSheet()
        if d and d.kind == "done" then task.wait(0.3) FIH.dismiss() return true, "bought " .. tostring(s.name) end
    until os.clock() - t1 > 8
    FIH.dismiss()
    return true, "pressed Buy on " .. tostring(s.name)
end

function FIH.promptFree(assetId)
    local info = MPS:GetProductInfo(assetId)
    if not (info.PriceInRobux == 0 and info.IsForSale) then return false, "catalog: not free / not for sale" end
    if MPS:PlayerOwnsAsset(lp, assetId) then return false, "already owned" end
    MPS:PromptPurchase(lp, assetId)
    return FIH.acceptFree(10, info.Name)
end

function FIH.autoAccept(on)
    FIH._auto = on ~= false
    if FIH._autoThread then return end
    FIH._autoThread = task.spawn(function()
        while FIH._auto do
            local s = readSheet()
            if s and s.kind == "buy" and isFreeCost(s.cost) then
                local ok, msg = FIH.acceptFree(1)
                print("[FIH] auto-accept:", ok, msg)
            elseif s and s.kind == "done" then
                FIH.dismiss()
            end
            task.wait(0.3)
        end
        FIH._autoThread = nil
    end)
end

function FIH.redeem(code)
    local rf = game:GetService("ReplicatedStorage"):FindFirstChild("RedeemCode")
    if not rf then return false, "no RedeemCode remote in this game" end
    local r = table.pack(pcall(function() return rf:InvokeServer(string.lower(code)) end))
    if not r[1] then return false, tostring(r[2]) end
    return r[2] == true, tostring(r[3])
end

function FIH.redeemMany(codes)
    FIH.autoAccept(true)
    local results = {}
    for _, code in ipairs(codes) do
        local ok, msg = FIH.redeem(code)
        results[#results + 1] = code .. ": " .. tostring(ok) .. " " .. tostring(msg)
        print("[FIH]", results[#results])
        if ok then
            local t0 = os.clock()
            repeat task.wait(0.3) until os.clock() - t0 > 6 or (not FIH.readSheet() and os.clock() - t0 > 3)
        end
        task.wait(2 + math.random() * 2)
    end
    pcall(writefile, "ConeHub/redeem_results.txt", table.concat(results, "\n"))
    return results
end

function FIH.tp(placeId, jobId)
    if jobId then
        return pcall(function() TS:TeleportToPlaceInstance(placeId, jobId, lp) end)
    end
    return pcall(function() TS:Teleport(placeId, lp) end)
end
function FIH.rejoin() return FIH.tp(game.PlaceId, game.JobId) end
function FIH.hop()
    local ok, res = pcall(function()
        return game:GetService("HttpService"):JSONDecode(game:HttpGet(
            "https://games.roblox.com/v1/games/" .. game.PlaceId .. "/servers/Public?sortOrder=Desc&limit=100"))
    end)
    if ok and res and res.data then
        for _, s in ipairs(res.data) do
            if s.id ~= game.JobId and s.playing < s.maxPlayers then return FIH.tp(game.PlaceId, s.id) end
        end
    end
    return FIH.tp(game.PlaceId)
end

function FIH.tpAndRedeem(placeId, code)
    if queue_on_teleport then
        queue_on_teleport(string.format([[
            repeat task.wait() until game:IsLoaded()
            local src = readfile and isfile and isfile("ConeHub/FreeItemHelper.lua") and readfile("ConeHub/FreeItemHelper.lua")
            if src then loadstring(src)() end
            local FIH = getgenv().FIH
            if FIH then
                FIH.autoAccept(true)
                for i = 1, 20 do
                    local ok, msg = FIH.redeem(%q)
                    print("[FIH] redeem", ok, msg)
                    if ok or (msg and not msg:find("no RedeemCode")) then break end
                    task.wait(0.5)
                end
            end
        ]], code))
    end
    return FIH.tp(placeId)
end

return FIH
