local byPlace = {
    [109406948015795] = "RLCrateSimulator.lua",
    [3351674303] = "DrivingEmpire.lua",
    [8304191830] = "AnimeAdventures.lua",
    [14229839966] = "AnimeAdventures.lua",
    [14229762361] = "AnimeAdventures.lua",
}

local byGame = {
    [10768851831] = "RLCrateSimulator.lua",
    [1202096104] = "DrivingEmpire.lua",
    [3183403065] = "AnimeAdventures.lua",
}

local target = byPlace[game.PlaceId] or byGame[game.GameId]

if target then
    local url = "https://raw.githubusercontent.com/nonfunctable/Cone-Hub/main/Scripts/" .. target .. "?v=" .. tostring(os.time())
    loadstring(game:HttpGet(url))()
end
