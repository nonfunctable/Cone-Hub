local byPlace = {
    [109406948015795] = "RLCrateSimulator.lua",
    [8304191830] = "AnimeAdventures.lua",
    [14229839966] = "AnimeAdventures.lua",
}

local byGame = {
    [10768851831] = "RLCrateSimulator.lua",
    [3183403065] = "AnimeAdventures.lua",
}

local target = byPlace[game.PlaceId] or byGame[game.GameId]
if target then
    loadstring(game:HttpGet("https://raw.githubusercontent.com/nonfunctable/Cone-Hub/main/Scripts/" .. target))()
end
