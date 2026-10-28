local ReplicatedStorage = game:GetService("ReplicatedStorage")

local byPlace = {
    [109406948015795] = "RLCrateSimulator.lua",
    [8304191830] = "AnimeAdventures.lua",
    [14229839966] = "AnimeAdventures.lua",
    [4623386862] = "Piggy.lua",
    [5661005779] = "Piggy.lua",
    [11630038968] = "BridgeDuels.lua",
    [9818227981] = "SentinelValorant.lua",
}

local byGame = {
    [10768851831] = "RLCrateSimulator.lua",
    [3183403065] = "AnimeAdventures.lua",
    [1516533665] = "Piggy.lua",
    [4124001390] = "BridgeDuels.lua",
    [3631977525] = "SentinelValorant.lua",
}

local target = byPlace[game.PlaceId] or byGame[game.GameId]
if not target then
    if ReplicatedStorage:FindFirstChild("SandsBelow") then
        target = "SandsBelow.lua"
    elseif ReplicatedStorage:FindFirstChild("Blink") and ReplicatedStorage:FindFirstChild("Modules") and ReplicatedStorage.Modules:FindFirstChild("Entity") then
        target = "BridgeDuels.lua"
    elseif ReplicatedStorage:FindFirstChild("WeaponEngine") and ReplicatedStorage:FindFirstChild("AgentEngine") then
        target = "SentinelValorant.lua"
    end
end

if target then
    local url = "https://raw.githubusercontent.com/nonfunctable/Cone-Hub/main/Scripts/" .. target .. "?v=" .. tostring(os.time())
    loadstring(game:HttpGet(url))()
end
