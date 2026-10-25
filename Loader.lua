local byPlace = {
    [109406948015795] = "RLCrateSimulator.lua",
}

local byGame = {
    [10768851831] = "RLCrateSimulator.lua",
}

local target = byPlace[game.PlaceId] or byGame[game.GameId]
if target then
    loadstring(game:HttpGet("https://raw.githubusercontent.com/nonfunctable/Cone-Hub/main/Scripts/" .. target))()
end
