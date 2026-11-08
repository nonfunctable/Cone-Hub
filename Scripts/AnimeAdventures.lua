getgenv().AA_SUMMER_MODE_ACTIVE = true

local ALLOWED_SUMMER_USERNAME = (getgenv and getgenv().AA_ALLOWED_USERNAME) or nil
local ANIME_ADVENTURES_GAME_ID = 3183403065
local LOBBY_PLACE_ID = 8304191830
local MATCH_PLACE_ID = 14229839966
local SUMMER_LEVEL_ID = "summer2_event"

if game.GameId ~= 0 and game.GameId ~= ANIME_ADVENTURES_GAME_ID and game.PlaceId ~= LOBBY_PLACE_ID and game.PlaceId ~= MATCH_PLACE_ID and game.PlaceId ~= 14229762361 then
	return
end

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local HttpService = game:GetService("HttpService")

do
	local lpCheck = Players.LocalPlayer or Players.PlayerAdded:Wait()
	if not lpCheck or (ALLOWED_SUMMER_USERNAME and lpCheck.Name ~= ALLOWED_SUMMER_USERNAME) then
		return
	end
end

local WEBHOOK_URL = (getgenv and getgenv().AA_WEBHOOK_URL) or ""
local SESSION_FILE = "aa_summer_event_session.json"

local AnimeAdventures = getgenv().AnimeAdventures or {}
getgenv().AnimeAdventures = AnimeAdventures

if AnimeAdventures.stopAutoAprilFools then
	pcall(AnimeAdventures.stopAutoAprilFools)
end
if AnimeAdventures.stopAutoSummerEvent then
	pcall(AnimeAdventures.stopAutoSummerEvent)
end

function AnimeAdventures.getRegistries()
	local src = ReplicatedStorage:WaitForChild("src", 15)
	if not src then
		return nil
	end
	local loaderMod = src:WaitForChild("Loader", 15)
	if not loaderMod then
		return nil
	end
	local Loader = require(loaderMod)
	return {
		Loader = Loader,
		NameMap = debug.getupvalue(Loader.load_core_class, 1),
		CoreClasses = debug.getupvalue(Loader.load_core_class, 2),
		ClientClasses = debug.getupvalue(Loader.load_client_class, 3),
		CoreServices = debug.getupvalue(Loader.load_core_service, 2),
		ClientServices = debug.getupvalue(Loader.load_client_service, 3),
		Data = debug.getupvalue(Loader.load_data, 1),
	}
end

function AnimeAdventures.restoreDeletedModules()
	local reg = AnimeAdventures.getRegistries()
	if not reg then
		return 0
	end
	local src = ReplicatedStorage.src
	local buckets = {
		{ table = reg.CoreClasses, folder = src.core.Classes },
		{ table = reg.CoreServices, folder = src.core.Services },
		{ table = reg.ClientClasses, folder = src.client.Classes },
		{ table = reg.ClientServices, folder = src.client.Services },
	}

	local restoredCount = 0
	for _, b in ipairs(buckets) do
		for origName, entry in pairs(b.table or {}) do
			local ms = entry and entry.module_script
			if typeof(ms) == "Instance" then
				ms.Name = origName
				pcall(function()
					if ms.Parent == nil then
						ms.Parent = b.folder
					end
				end)
				restoredCount += 1
			end
		end
	end
	return restoredCount
end

function AnimeAdventures.loadData(name)
	local reg = AnimeAdventures.getRegistries()
	return reg and reg.Loader:load_data(name)
end

function AnimeAdventures.invokeServer(endpointName, ...)
	local endpoints = ReplicatedStorage:FindFirstChild("endpoints")
	local c2s = endpoints and endpoints:FindFirstChild("client_to_server")
	local remote = c2s and c2s:FindFirstChild(endpointName)
	if not remote then
		return nil
	end
	local reg = AnimeAdventures.getRegistries()
	local epEntry = reg and reg.ClientServices and reg.ClientServices.EndpointsClient
	if epEntry and epEntry.module then
		return epEntry.module.invoke_server(endpointName, ...)
	end
	return remote:InvokeServer(...)
end

local DAILY_LEVEL_ID = "__DAILY_CHALLENGE"

function AnimeAdventures.getProfileData()
	local reg = AnimeAdventures.getRegistries()
	local csc = reg and reg.ClientServices.ChallengeServiceClient and reg.ClientServices.ChallengeServiceClient.module
	return csc and csc.session and csc.session.profile_data, csc
end

function AnimeAdventures.isDailyChallengePending()
	local pd, csc = AnimeAdventures.getProfileData()
	local cur = csc and csc._CURRENT_DAILY_CHALLENGE
	if not pd or not cur or cur.current_uuid == nil then
		return false
	end
	return cur.current_uuid ~= pd.last_completed_daily_challenge_uuid
end

function AnimeAdventures.ensureTeamLoadout(idx)
	idx = tostring(idx)
	local pd = AnimeAdventures.getProfileData()
	local lo = pd and pd.loadouts_v2 and pd.loadouts_v2[idx]
	if not lo or not lo.saved_equipped or next(lo.saved_equipped) == nil then
		return false
	end
	local reg = AnimeAdventures.getRegistries()
	local ucsc = reg and reg.ClientServices.UnitCollectionServiceClient and reg.ClientServices.UnitCollectionServiceClient.module
	local cpd = ucsc and ucsc.session and ucsc.session.collection and ucsc.session.collection.collection_profile_data
	local equipped, have = {}, 0
	for _, u in pairs((cpd and cpd.equipped_units) or {}) do
		equipped[u] = true
		have += 1
	end
	local matches, want = true, 0
	for _, u in pairs(lo.saved_equipped) do
		want += 1
		if not equipped[u] then
			matches = false
		end
	end
	if matches and have == want then
		return true
	end
	pcall(AnimeAdventures.invokeServer, "load_team_loadout", idx)
	task.wait(1)
	return true
end

function AnimeAdventures.joinAndStartSummerEvent(useMatchmaking, state, levelId)
	levelId = levelId or SUMMER_LEVEL_ID
	local reg = AnimeAdventures.getRegistries()
	local gui = reg and reg.ClientServices.GUIService and reg.ClientServices.GUIService.module

	pcall(function()
		if gui and gui.summer2_hunt_maps_ui then
			gui.summer2_hunt_maps_ui:refresh()
			if (gui.summer2_hunt_maps_ui.ready_count or 0) > 0 then
				AnimeAdventures.invokeServer("claim_summer2_map_board_lines")
			end
		end
	end)

	if useMatchmaking ~= false then
		local mmUI = gui and gui.matchmaking_ui
		local mmEnabled = mmUI and mmUI.screenGUI and mmUI.screenGUI.Enabled
		local now = tick()
		if mmEnabled and state and state.queuedLevelId and state.queuedLevelId ~= levelId then
			pcall(AnimeAdventures.invokeServer, "leave_matchmaking")
			pcall(function()
				mmUI.screenGUI.Enabled = false
			end)
			mmEnabled = false
			task.wait(0.5)
		end
		if not mmEnabled or (now - (state and state.lastMatchmakeQueueTime or 0)) >= 45 then
			if state then
				state.lastMatchmakeQueueTime = now
				state.queuedLevelId = levelId
			end
			local res = AnimeAdventures.invokeServer("request_matchmaking", levelId)
			pcall(function()
				if mmUI and not mmUI.screenGUI.Enabled then
					mmUI:show(levelId)
				end
			end)
			return res
		end
		return true
	end

	local lsc = reg and reg.ClientServices.LobbyServiceClient and reg.ClientServices.LobbyServiceClient.module
	local lob = workspace:FindFirstChild("_EVENT_CHALLENGES")
		and workspace._EVENT_CHALLENGES:FindFirstChild("Lobbies")
		and workspace._EVENT_CHALLENGES.Lobbies:FindFirstChild("_lobbytemplate_event3")

	if not lob then
		return false, "Lobby _lobbytemplate_event3 not found"
	end

	local lp = Players.LocalPlayer
	local char = lp and lp.Character
	if char and char:FindFirstChild("HumanoidRootPart") and lob:FindFirstChild("Door") then
		char:SetPrimaryPartCFrame(lob.Door.CFrame * CFrame.new(0, 0, -5))
		task.wait(0.2)
	end

	local joined = AnimeAdventures.invokeServer("request_join_lobby", "_lobbytemplate_event3")
	if joined and lsc and gui and gui.level_select_ui then
		lsc.current_lobby = "_lobbytemplate_event3"
		lsc.current_lobby_model = lob
		pcall(function()
			gui.level_select_ui:show_non_owner_ui()
		end)
	end

	task.wait(0.2)
	local started = AnimeAdventures.invokeServer("request_start_game", "_lobbytemplate_event3")
	return joined, started
end

local DEFAULT_CONFIG = {
	USE_MATCHMAKING = true,
	ALWAYS_PICK_DEBUFFS = true,
	PERFECT_ERWIN_BUFF = true,
	TARGET_ERWIN_COUNT = 4,
	SMART_TIMESTOP = true,
	RETURN_TO_LOBBY = true,
	AUTO_DAILY_CHALLENGE = false,
	AUTO_SWITCH_TEAMS = false,
	DAILY_TEAM_SLOT = "1",
	SUMMER_TEAM_SLOT = "2",
	DIFFICULTY = "Hard",
}

local function getConfig()
	local g = (getgenv and getgenv()) or _G
	if type(g.AA_SUMMER_CONFIG) == "table" then
		return g.AA_SUMMER_CONFIG
	end
	return DEFAULT_CONFIG
end

local RARITY_SCORE = {
	Secret = 600,
	Exclusive = 550,
	Mythic = 500,
	Legendary = 300,
	Epic = 200,
	Rare = 100,
}

local SUPPORT_UNITS = {
	erwin = true,
	erwin_school = true,
	erwin_halloween = true,
	wendy = true,
	wendy_evolved = true,
	leafa = true,
	leafa_evolved = true,
	brook = true,
	brook_evolved = true,
	koichi = true,
	koichi_evolved = true,
	wisteria = true,
	kisuke = true,
	kisuke_evolved = true,
}

local IDOL_UNITS = {
	hoshino = true,
	hoshino_evolved = true,
	hoshino_2 = true,
	hoshino_2_evolved = true,
}

local BUFF_ACTIVE_UNITS = {
	erwin = true,
	erwin_school = true,
	erwin_halloween = true,
	wendy = true,
	wendy_evolved = true,
	leafa = true,
	leafa_evolved = true,
	brook = true,
}

local TIMESTOP_UNITS = {
	homura = true,
	homura_evolved = true,
	esdeath = true,
	esdeath_evolved = true,
	dio_oh = true,
	dio_heaven = true,
	dio = true,
	jotaro = true,
	jotaro_p6 = true,
	jotaro_p6_evolved = true,
	gojo = true,
	gojo_evolved = true,
	kurumi = true,
	kurumi_evolved = true,
}

local REPOSITION_ACTIVE_UNITS = {
	law_2 = true,
	law_2_evolved = true,
	julius = true,
	julius_evolved = true,
	lelouch = true,
	lelouch_evolved = true,
	kira = true,
	kira_evolved = true,
}

local VEGO_UNITS = {
	vegeta_majin_evolved = true,
	vegeta_majin = true,
}

local CARROT_UNITS = {
	goku_ssj3_evolved = true,
	goku_ssj3 = true,
}

local BOSS_PREP_WAVES = {
	[10] = true,
	[15] = true,
	[20] = true,
	[25] = true,
	[30] = true,
	[35] = true,
	[40] = true,
	[45] = true,
	[48] = true,
	[49] = true,
	[50] = true,
}

local function scoreSummerCardFrame(frame)
	if not frame then
		return -999999
	end

	local isDebuffCard = frame:FindFirstChild("UIGradientDebuff", true) ~= nil
	local isBuffCard = frame:FindFirstChild("UIGradientBuff", true) ~= nil
	local score = 0

	if isDebuffCard then
		score += 10000
	elseif isBuffCard then
		score -= 5000
	end

	for _, desc in ipairs(frame:GetDescendants()) do
		if desc:IsA("TextLabel") and desc.Visible then
			local raw = desc.Text or ""
			local t = string.lower(raw)
			if t ~= "" and t ~= "confirm" and not string.find(t, "^%d+$") then

				local col = desc.TextColor3
				if col and col.R > 0.85 and col.G < 0.25 and col.B < 0.25 and not isBuffCard then
					score += 2000
				end

				local pct = tonumber(string.match(t, "([%d%.]+)%%"))
				if string.find(t, "summerpearl") or string.find(t, "pearl") or string.find(t, "reward currency") then
					score += 5000 + ((pct or 10) * 60)
				elseif string.find(t, "secret drop") then
					score += 6500 + ((pct or 10) * 120)
				elseif string.find(t, "curse") then
					score += 4500
				end

				if string.find(t, "new path") or string.find(t, "new lane") then
					score -= 750
				elseif string.find(t, "explosive death") then
					score -= 350
				elseif string.find(t, "enemy regen") then
					score -= 300 - ((pct or 1) * 40)
				elseif string.find(t, "range") and string.find(t, "-") then
					score -= 220
				elseif string.find(t, "cooldown") and string.find(t, "+") then
					score -= 180
				elseif string.find(t, "damage") and string.find(t, "-") and not string.find(t, "boss") then
					score -= 200
				elseif string.find(t, "placement/upgrade cost") then

					score += 180
				elseif string.find(t, "enemy speed") or string.find(t, "burst enemy") then
					score += 80
				elseif string.find(t, "resist") or string.find(t, "enemy shield") or string.find(t, "enemy health") then
					score += 60
				end

				if isBuffCard then
					if string.find(t, "damage") and string.find(t, "+") then
						score += 90
					elseif string.find(t, "cooldown") and string.find(t, "-") then
						score += 85
					elseif string.find(t, "range") and string.find(t, "+") then
						score += 65
					elseif string.find(t, "cost") and string.find(t, "-") then
						score += 70
					elseif string.find(t, "¥") or string.find(t, "yen") then
						score += 50
					end
				end
			end
		end
	end

	return score
end

local function extractLaneWaypoints(laneFolder)
	local pts = {}
	if not laneFolder then
		return pts
	end
	local spawnPart = laneFolder:FindFirstChild("spawn")
	if spawnPart and spawnPart:IsA("BasePart") then
		table.insert(pts, spawnPart.Position)
	end
	for i = 1, 40 do
		local p = laneFolder:FindFirstChild(tostring(i))
		if p and p:IsA("BasePart") then
			table.insert(pts, p.Position)
		end
	end
	local finalPart = laneFolder:FindFirstChild("final")
	if finalPart and finalPart:IsA("BasePart") then
		table.insert(pts, finalPart.Position)
	end
	return pts
end

local function getAllLanesWaypoints()
	local lanesList = {}
	local pve = workspace:FindFirstChild("_BASES") and workspace._BASES:FindFirstChild("pve")
	local lanesFolder = pve and pve:FindFirstChild("LANES")
	if not lanesFolder then
		return lanesList
	end
	local children = lanesFolder:GetChildren()
	table.sort(children, function(a, b)
		return tostring(a.Name) < tostring(b.Name)
	end)
	for _, lf in ipairs(children) do
		local pts = extractLaneWaypoints(lf)
		if #pts > 0 then
			table.insert(lanesList, pts)
		end
	end
	return lanesList
end

local function getPathWaypoints()
	local lanesList = getAllLanesWaypoints()
	return lanesList[1] or {}
end

local function buildDensePathSamples(lanesList)
	if not lanesList or #lanesList == 0 then
		lanesList = getAllLanesWaypoints()
	end
	if #lanesList > 0 and typeof(lanesList[1]) == "Vector3" then
		lanesList = { lanesList }
	end

	local perLaneSamples = {}
	local numLanes = #lanesList
	for lIdx, waypoints in ipairs(lanesList) do
		local lSamples = {}
		local totalWps = math.max(1, #waypoints)
		for i = 1, #waypoints - 1 do
			local a = waypoints[i]
			local b = waypoints[i + 1]
			local segLen = (b - a).Magnitude
			local steps = math.max(1, math.floor(segLen / 3.5))
			for s = 0, steps - 1 do
				local t = s / steps
				local p = a:Lerp(b, t)
				local prog = ((i - 1) + t) / math.max(1, totalWps - 1)

				local weight = 0.25
				if prog >= 0.03 and prog <= 0.22 then
					weight = 6.0
				elseif prog < 0.03 then
					weight = 4.2
				elseif prog <= 0.34 then
					weight = 3.5
				elseif prog <= 0.48 then
					weight = 1.2
				end
				table.insert(lSamples, { pos = p, wpIdx = i, laneIdx = lIdx, prog = prog, weight = weight, isConvergence = false })
			end
		end
		if #waypoints > 0 then
			table.insert(lSamples, { pos = waypoints[#waypoints], wpIdx = #waypoints, laneIdx = lIdx, prog = 1.0, weight = 0.15, isConvergence = false })
		end
		perLaneSamples[lIdx] = lSamples
	end

	local allSamples = {}
	if numLanes >= 2 then
		for lIdx, lSamples in ipairs(perLaneSamples) do
			for _, s in ipairs(lSamples) do
				local minOtherDistSq = math.huge
				for otherIdx, otherSamples in ipairs(perLaneSamples) do
					if otherIdx ~= lIdx then
						for _, os in ipairs(otherSamples) do
							local dx = s.pos.X - os.pos.X
							local dz = s.pos.Z - os.pos.Z
							local dSq = dx * dx + dz * dz
							if dSq < minOtherDistSq then
								minOtherDistSq = dSq
							end
						end
					end
				end
				local dOther = math.sqrt(minOtherDistSq)
				if s.prog <= 0.34 then
					s.isConvergence = true
					if dOther <= 26 then
						s.weight = s.weight * 2.4
					end
				elseif s.prog <= 0.50 and dOther <= 20 then
					s.isConvergence = true
					s.weight = 3.4
				else
					s.isConvergence = false
					s.weight = 0.3
				end
				table.insert(allSamples, s)
			end
		end
	else
		for _, s in ipairs(perLaneSamples[1] or {}) do
			table.insert(allSamples, s)
		end
	end
	return allSamples, numLanes
end

local function getClosestWaypointIndex(pos, waypoints)
	local bestIdx = 1
	local bestDist = math.huge
	for i, wp in ipairs(waypoints) do
		local dx = wp.X - pos.X
		local dz = wp.Z - pos.Z
		local d = dx * dx + dz * dz
		if d < bestDist then
			bestDist = d
			bestIdx = i
		end
	end
	return bestIdx, math.sqrt(bestDist)
end

local function getClosestLaneAndWaypoint(pos, lanesList)
	local bestLaneIdx = 1
	local bestWpIdx = 1
	local bestDist = math.huge
	for lIdx, wps in ipairs(lanesList) do
		local idx, dist = getClosestWaypointIndex(pos, wps)
		if dist < bestDist then
			bestDist = dist
			bestWpIdx = idx
			bestLaneIdx = lIdx
		end
	end
	return bestLaneIdx, bestWpIdx, bestDist
end

local function analyzeEnemyThreats(waypoints, placedDps)
	local unitsFolder = workspace:FindFirstChild("_UNITS")
	local lanesList = getAllLanesWaypoints()
	if not unitsFolder or #lanesList == 0 then
		return nil
	end

	local worstLeak = nil
	for _, mob in ipairs(unitsFolder:GetChildren()) do
		if CollectionService:HasTag(mob, "pve_units") and not CollectionService:HasTag(mob, "dying_units") then
			local hrp = mob:FindFirstChild("HumanoidRootPart") or mob.PrimaryPart
			local hum = mob:FindFirstChild("Humanoid")
			if hrp and hum and hum.Health > 0 then
				local laneIdx, wpIdx = getClosestLaneAndWaypoint(hrp.Position, lanesList)
				local laneWps = lanesList[laneIdx] or waypoints
				local totalWps = math.max(1, #laneWps)
				local prog = wpIdx / totalWps
				local refY = (laneWps[wpIdx] and laneWps[wpIdx].Y) or hrp.Position.Y
				local isFlying = CollectionService:HasTag(mob, "flying_units") or (hrp.Position.Y - refY) > 4.5
				local inRangeDpsCount = 0
				local inRangeDamage = 0
				local aheadDpsCount = 0
				local aheadDamage = 0
				for _, d in ipairs(placedDps) do
					if d.pos and (not isFlying or d.canAir) then
						local effR = d.liveRange + 2
						local distNow = (Vector3.new(d.pos.X, 0, d.pos.Z) - Vector3.new(hrp.Position.X, 0, hrp.Position.Z)).Magnitude
						local coversAhead = false
						if distNow <= effR then
							inRangeDpsCount += 1
							inRangeDamage += d.liveDamage
							coversAhead = true
						else
							for k = wpIdx, totalWps do
								local wp = laneWps[k]
								local dWp = (Vector3.new(d.pos.X, 0, d.pos.Z) - Vector3.new(wp.X, 0, wp.Z)).Magnitude
								if dWp <= effR then
									coversAhead = true
									break
								end
							end
						end
						if coversAhead then
							aheadDpsCount += 1
							aheadDamage += d.liveDamage
						end
					end
				end

				local isBoss = hum.MaxHealth >= 60000
				local isLeaking = (prog >= 0.45 and aheadDpsCount == 0)
					or (isFlying and prog >= 0.38 and aheadDpsCount == 0)
					or (prog >= 0.72 and aheadDpsCount < 2 and aheadDamage * 5.0 < hum.Health)
					or (prog >= 0.82 and (inRangeDpsCount == 0 or aheadDamage * 3.0 < hum.Health))
				if isLeaking then
					local urgency = prog * 1000 + (isBoss and 600 or 0) + (isFlying and 400 or 0) - aheadDpsCount * 80
					if not worstLeak or urgency > worstLeak.urgency then
						worstLeak = {
							mob = mob,
							pos = hrp.Position,
							laneIdx = laneIdx,
							wpIdx = wpIdx,
							prog = prog,
							hp = hum.Health,
							maxHp = hum.MaxHealth,
							isBoss = isBoss,
							isFlying = isFlying,
							inRangeDpsCount = inRangeDpsCount,
							inRangeDamage = inRangeDamage,
							aheadDpsCount = aheadDpsCount,
							aheadDamage = aheadDamage,
							urgency = urgency,
						}
					end
				end
			end
		end
	end
	return worstLeak
end

local function isTooCloseToPlacedUnits(pos, minDist)
	minDist = minDist or 2.4
	local unitsFolder = workspace:FindFirstChild("_UNITS")
	if not unitsFolder then
		return false
	end
	for _, u in ipairs(unitsFolder:GetChildren()) do
		local hrp = u:FindFirstChild("HumanoidRootPart") or u.PrimaryPart
		if hrp then
			local dx = hrp.Position.X - pos.X
			local dz = hrp.Position.Z - pos.Z
			if (dx * dx + dz * dz) < (minDist * minDist) then
				return true
			end
		end
	end
	return false
end

local function minDistanceToPath(pos, waypoints, startIdx, maxIndex)
	local best = math.huge
	local s = math.max(1, startIdx or 1)
	local limit = math.min(#waypoints, maxIndex or #waypoints)
	for i = s, limit do
		local wp = waypoints[i]
		local dx = wp.X - pos.X
		local dz = wp.Z - pos.Z
		local d = math.sqrt(dx * dx + dz * dz)
		if d < best then
			best = d
		end
	end
	return best
end

local function scorePlacementCoverage(pos, denseSamples, effRange, mode, targetWpIdx, numLanes, targetPos)
	local rSq = effRange * effRange
	local score = 0
	local lanesHit = {}
	local lanesHitCount = 0
	for _, s in ipairs(denseSamples) do
		local dx = s.pos.X - pos.X
		local dz = s.pos.Z - pos.Z
		local dSq = dx * dx + dz * dz
		if dSq <= rSq then
			if s.laneIdx and not lanesHit[s.laneIdx] then
				lanesHit[s.laneIdx] = true
				lanesHitCount += 1
			end
			if mode == "leak" and targetPos then
				local tdx = s.pos.X - targetPos.X
				local tdz = s.pos.Z - targetPos.Z
				if (tdx * tdx + tdz * tdz) <= 900 and s.prog >= 0.35 then
					score += 5.0
				else
					score += 1.0
				end
			elseif mode == "leak" and targetWpIdx then
				if s.wpIdx >= targetWpIdx and s.wpIdx <= targetWpIdx + 5 then
					score += 4.0
				elseif s.wpIdx >= targetWpIdx - 1 then
					score += 1.5
				end
			else
				score += s.weight
			end
		end
	end
	if (numLanes or 1) >= 2 and lanesHitCount >= numLanes then
		score = score * 2.4
	end
	return score
end

local function isNearFailedPosition(pos, failedPositions, radius)
	if not failedPositions then
		return false
	end
	radius = radius or 3.2
	local rSq = radius * radius
	for _, fp in ipairs(failedPositions) do
		local dx = fp.X - pos.X
		local dz = fp.Z - pos.Z
		if (dx * dx + dz * dz) < rSq then
			return true
		end
	end
	return false
end

local function findValidPlacementCFrame(AA, uinfo, mode, targetWpIdx, failedPositions, leakPos, fusionPartnerPos, preferNearHill, bufferAnchorPos, firstErwinPos)

	local reg = AA.getRegistries()
	local pc = reg.CoreServices.PlacementCore.module
	local Util = require(ReplicatedStorage.src.Util)
	local lanesList = getAllLanesWaypoints()
	local waypoints = lanesList[1] or {}
	local totalWps = math.max(1, #waypoints)
	local denseSamples, numLanes = buildDensePathSamples(lanesList)
	local effRange = math.clamp((tonumber(uinfo.range) or 22) * 1.3, 20, 42)
	local candidates = {}

	local startIdx = 1
	local endIdx = math.max(2, math.ceil(totalWps * 0.30))
	if mode == "leak" and targetWpIdx then
		startIdx = math.clamp(targetWpIdx, 2, math.max(2, totalWps - 1))
		endIdx = math.clamp(targetWpIdx + 4, startIdx, totalWps)
	elseif mode == "farm" then
		startIdx = math.max(2, math.floor(totalWps * 0.45))
		endIdx = math.max(startIdx + 1, math.floor(totalWps * 0.85))
	end

	local function minFrontDistanceAllLanes(pt)
		local best = math.huge
		for _, lWps in ipairs(lanesList) do
			local fEnd = math.max(2, math.ceil(#lWps * 0.30))
			local dl = minDistanceToPath(pt, lWps, 1, fEnd)
			if dl < best then
				best = dl
			end
		end
		if best == math.huge then
			best = minDistanceToPath(pt, waypoints, startIdx, endIdx)
		end
		return best
	end

	local hillCandidates = {}
	local bestFrontHillPos = nil
	local bestFrontHillScore = -math.huge
	local hillFolder = workspace:FindFirstChild("_terrain") and workspace._terrain:FindFirstChild("hill")
	if hillFolder then
		for _, part in ipairs(hillFolder:GetDescendants()) do
			if part:IsA("BasePart") then
				local sx = math.max(0, (part.Size.X / 2) - 1.2)
				local sz = math.max(0, (part.Size.Z / 2) - 1.2)
				for ox = -sx, sx, 2.2 do
					for oz = -sz, sz, 2.2 do
						local worldPt = (part.CFrame * CFrame.new(ox, 0, oz)).Position
						local cov = scorePlacementCoverage(worldPt, denseSamples, 26, "front", nil, numLanes, nil)
						local dFront = minFrontDistanceAllLanes(worldPt)
						local hScore = (cov * 12) - (dFront * 3.0)
						table.insert(hillCandidates, { pos = worldPt, partY = part.Position.Y, cov = cov, dFront = dFront, hScore = hScore })
						if hScore > bestFrontHillScore then
							bestFrontHillScore = hScore
							bestFrontHillPos = worldPt
						end
					end
				end
			end
		end
	end

	if uinfo.hill_unit then
		for _, hc in ipairs(hillCandidates) do
			local worldPt = hc.pos
			local cov = scorePlacementCoverage(worldPt, denseSamples, effRange, mode, targetWpIdx, numLanes, leakPos)
			local d = (mode == "leak") and minDistanceToPath(worldPt, waypoints, startIdx, endIdx) or hc.dFront
			local sortKey = (cov * 12) - (d * 2.8)
			if fusionPartnerPos then
				local distPartner = (Vector3.new(worldPt.X, 0, worldPt.Z) - Vector3.new(fusionPartnerPos.X, 0, fusionPartnerPos.Z)).Magnitude
				if distPartner <= 22 then
					sortKey += (5000 - distPartner * 80)
				elseif distPartner <= 30 then
					sortKey += (2000 - distPartner * 60)
				else
					sortKey -= distPartner * 50
				end
			end
			table.insert(candidates, { x = worldPt.X, y = hc.partY + 40, z = worldPt.Z, sortKey = sortKey })
		end
	else
		local anchorPts = {}
		if mode == "buffer" and bufferAnchorPos then
			table.insert(anchorPts, bufferAnchorPos)
			if type(firstErwinPos) == "table" then
				for _, ep in ipairs(firstErwinPos) do
					table.insert(anchorPts, ep)
				end
			elseif typeof(firstErwinPos) == "Vector3" then
				table.insert(anchorPts, firstErwinPos)
			end
		elseif fusionPartnerPos then
			table.insert(anchorPts, fusionPartnerPos)
		elseif preferNearHill and bestFrontHillPos then
			table.insert(anchorPts, bestFrontHillPos)
		end

		if mode == "leak" and leakPos then
			table.insert(anchorPts, leakPos)
			for _, lWps in ipairs(lanesList) do
				local idx = getClosestWaypointIndex(leakPos, lWps)
				for k = idx, math.min(#lWps, idx + 3) do
					table.insert(anchorPts, lWps[k])
				end
			end
		elseif mode ~= "farm" and mode ~= "buffer" then
			for _, lWps in ipairs(lanesList) do
				local fEnd = math.max(2, math.ceil(#lWps * 0.30))
				for i = 1, math.min(#lWps, fEnd) do
					table.insert(anchorPts, lWps[i])
				end
			end
			if numLanes >= 2 then
				for i = 1, #denseSamples, 3 do
					local s = denseSamples[i]
					if s.isConvergence and s.prog <= 0.42 then
						table.insert(anchorPts, s.pos)
					end
				end
			end
		end

		if #anchorPts == 0 then
			if #waypoints > 0 then
				for i = startIdx, endIdx do
					table.insert(anchorPts, waypoints[i])
				end
			else
				table.insert(anchorPts, Vector3.new(-525, 33, -150))
			end
		end

		local seen = {}
		local searchRadius = (mode == "buffer") and 15 or 22
		local stepSize = (mode == "buffer") and 2.0 or 2.4
		for _, wp in ipairs(anchorPts) do
			for rx = -searchRadius, searchRadius, stepSize do
				for rz = -searchRadius, searchRadius, stepSize do
					local gx = math.floor((wp.X + rx) / stepSize + 0.5) * stepSize
					local gz = math.floor((wp.Z + rz) / stepSize + 0.5) * stepSize
					local key = tostring(gx) .. ":" .. tostring(gz)
					if not seen[key] then
						seen[key] = true
						local pt = Vector3.new(gx, wp.Y, gz)
						local sortKey = 0
						local allowSpot = true

						if mode == "farm" then
							local minD = math.huge
							for _, lWps in ipairs(lanesList) do
								local dl = minDistanceToPath(pt, lWps, 1, #lWps)
								if dl < minD then
									minD = dl
								end
							end
							local cov = scorePlacementCoverage(pt, denseSamples, 18, "front", nil, numLanes, nil)
							sortKey = 120 - math.abs(minD - 18) * 4 - cov * 3
						elseif mode == "buffer" and bufferAnchorPos then

							local distCarry = (Vector3.new(pt.X, 0, pt.Z) - Vector3.new(bufferAnchorPos.X, 0, bufferAnchorPos.Z)).Magnitude
							if distCarry > 14.0 or distCarry < 2.6 then
								allowSpot = false
							else
								local dPath = minFrontDistanceAllLanes(pt)
								sortKey = 2000 - (distCarry * 35) - math.abs(dPath - 8.5) * 15
								if type(firstErwinPos) == "table" and #firstErwinPos > 0 then
									local maxErwinDist = 0
									local sumErwinDist = 0
									for _, ep in ipairs(firstErwinPos) do
										local de = (Vector3.new(pt.X, 0, pt.Z) - Vector3.new(ep.X, 0, ep.Z)).Magnitude
										if de > maxErwinDist then
											maxErwinDist = de
										end
										sumErwinDist += de
									end
									if maxErwinDist <= 13.5 then
										sortKey += (2500 - maxErwinDist * 55 - sumErwinDist * 15)
									else
										sortKey -= maxErwinDist * 140
									end
								elseif typeof(firstErwinPos) == "Vector3" then
									local distErwin = (Vector3.new(pt.X, 0, pt.Z) - Vector3.new(firstErwinPos.X, 0, firstErwinPos.Z)).Magnitude
									if distErwin <= 13.5 then
										sortKey += (1500 - distErwin * 40)
									else
										sortKey -= distErwin * 80
									end
								end
							end
						else
							local cov = scorePlacementCoverage(pt, denseSamples, effRange, mode, targetWpIdx, numLanes, leakPos)
							local d = (mode == "leak") and minDistanceToPath(pt, waypoints, startIdx, endIdx) or minFrontDistanceAllLanes(pt)
							sortKey = (cov * 14) - (d * 3.0)
							if fusionPartnerPos then
								local distPartner = (Vector3.new(pt.X, 0, pt.Z) - Vector3.new(fusionPartnerPos.X, 0, fusionPartnerPos.Z)).Magnitude
								if distPartner <= 21 then
									sortKey += (4500 - distPartner * 75)
								elseif distPartner <= 28 then
									sortKey += (1800 - distPartner * 50)
								else
									sortKey -= distPartner * 45
								end
							elseif preferNearHill and #hillCandidates > 0 then
								local minHillDist = math.huge
								local bestNearHillScore = 0
								for _, hc in ipairs(hillCandidates) do
									local hd = (Vector3.new(pt.X, 0, pt.Z) - Vector3.new(hc.pos.X, 0, hc.pos.Z)).Magnitude
									if hd < minHillDist then
										minHillDist = hd
										bestNearHillScore = hc.hScore
									end
								end
								if minHillDist <= 20 then
									sortKey += (2500 - minHillDist * 55) + math.max(0, bestNearHillScore * 0.25)
								else
									sortKey -= (minHillDist - 20) * 40
								end
							end
						end

						if allowSpot then
							table.insert(candidates, { x = gx, y = wp.Y + 50, z = gz, sortKey = sortKey })
						end
					end
				end
			end
		end
	end

	table.sort(candidates, function(a, b)
		return a.sortKey > b.sortKey
	end)

	for _, c in ipairs(candidates) do
		local res = pc.raycast(Vector3.new(c.x, c.y, c.z), Vector3.new(0, -200, 0))
		if res and pc.is_valid_raycast_hit(res.Instance, uinfo) then

			local isHillHit = hillFolder and res.Instance:IsDescendantOf(hillFolder)
			if not (mode == "buffer" and isHillHit) then
				if not isTooCloseToPlacedUnits(res.Position, 2.8) and not isNearFailedPosition(res.Position, failedPositions, 3.0) then
					return Util.CFramePLV(res.Position, Vector3.new(0, 0, -1)), res.Position
				end
			end
		end
	end
	return nil, nil
end

local MAIN_FARM_UNITS = {
	speedwagon = true,
	bulma = true,
	bulma_evolved = true,
}

local function isFarmUnit(AA, unitId, uinfo)
	if MAIN_FARM_UNITS[unitId] then
		return true
	end
	if not uinfo then
		return false
	end
	if uinfo.farm_amount and tonumber(uinfo.farm_amount) and tonumber(uinfo.farm_amount) > 0 then
		return true
	end
	local reg = AA.getRegistries()
	local usc = reg.CoreServices.UnitServiceCore and reg.CoreServices.UnitServiceCore.module
	if usc and usc.unit_static_is_farm and usc.unit_static_is_farm(unitId) then
		return true
	end
	return false
end

local function isNonAttackingUnit(AA, unitId, uinfo)
	if not uinfo then
		return true
	end
	if isFarmUnit(AA, unitId, uinfo) then
		return true
	end
	if uinfo._NO_ATTACKS_UNIT or IDOL_UNITS[unitId] or SUPPORT_UNITS[unitId] then
		return true
	end
	if (tonumber(uinfo.damage) or 0) <= 0 then
		return true
	end
	return false
end

local function unitCanTargetAirNow(AA, u, unitId, uinfo)
	if not uinfo then
		return false
	end
	if uinfo.hill_unit or uinfo.hybrid_placement or unitId == "vegito" or CARROT_UNITS[unitId] then
		return true
	end
	local reg = AA.getRegistries()
	local usc = reg.CoreServices.UnitServiceCore and reg.CoreServices.UnitServiceCore.module
	if usc and usc.unit_can_target_air and usc.unit_can_target_air(u) then
		return true
	end
	return false
end

local function getUnitTraitInfo(AA, uuid)
	local info = {
		isUnique = false,
		traitName = nil,
		traitMult = 1.0,
	}
	if not uuid then
		return info
	end
	local reg = AA.getRegistries()
	local ucsc = reg.ClientServices.UnitCollectionServiceClient and reg.ClientServices.UnitCollectionServiceClient.module
	local col = ucsc and ucsc.session and ucsc.session.collection
	if not col then
		return info
	end
	local cpd = col.collection_profile_data
	local ou = (cpd and cpd.owned_units and cpd.owned_units[uuid])
		or (col.owned_units and col.owned_units[uuid])
	if ou and ou.traits then
		for _, t in pairs(ou.traits) do
			local tid = t and t.trait
			if tid == "unique" then
				info.isUnique = true
				info.traitName = "unique"
				info.traitMult = math.max(info.traitMult, 4.0)
			elseif tid == "divine" then
				info.traitName = info.traitName or "divine"
				info.traitMult = math.max(info.traitMult, 1.35)
			elseif tid == "golden" then
				info.traitName = info.traitName or "golden"
				info.traitMult = math.max(info.traitMult, 1.30)
			elseif tid == "godspeed" then
				info.traitName = info.traitName or "godspeed"
				info.traitMult = math.max(info.traitMult, 1.25)
			elseif tid == "reaper" or tid == "superior" then
				info.traitName = info.traitName or tid
				info.traitMult = math.max(info.traitMult, 1.15)
			elseif tid == "ethereal" or tid == "sniper" or tid == "culling" or tid == "celestial" then
				info.traitName = info.traitName or tid
				info.traitMult = math.max(info.traitMult, 1.10)
			end
		end
	end
	return info
end

local function getGlobalUnitCountById(unitId)
	local count = 0
	local unitsFolder = workspace:FindFirstChild("_UNITS")
	if not unitsFolder then
		return 0
	end
	for _, u in ipairs(unitsFolder:GetChildren()) do
		if CollectionService:HasTag(u, "nonminion_units") and not CollectionService:HasTag(u, "dying_units") then
			local st = u:FindFirstChild("_stats")
			if st and st:FindFirstChild("id") and st.id.Value == unitId then
				count += 1
			end
		end
	end
	return count
end

local function getPlayerPlacedUnits(AA, waypoints)
	local reg = AA.getRegistries()
	local usc = reg.CoreServices.UnitServiceCore.module
	local Units = AA.loadData("Units")
	local lp = Players.LocalPlayer
	local result = {
		all = {},
		farms = {},
		dps = {},
		supports = {},
		erwins = {},
		byId = {},
		byUuid = {},
		vegoEntry = nil,
		carrotEntry = nil,
		vegitoEntry = nil,
		idolEntry = nil,
		homuraEntry = nil,
		totalDpsUpgrades = 0,
		totalDamage = 0,
		totalAirDamage = 0,
		airTargetCount = 0,
	}

	for _, u in ipairs(usc.get_all_units_from_player(lp)) do
		if u.Parent == workspace._UNITS and CollectionService:HasTag(u, "nonminion_units") and not CollectionService:HasTag(u, "dying_units") and u:FindFirstChild("_stats") then
			local id = u._stats.id.Value
			local uinfo = Units[id]
			if uinfo then
				local uUuid = u._stats:FindFirstChild("uuid") and u._stats.uuid.Value or nil
				local upg = u._stats.upgrade and u._stats.upgrade.Value or 0
				local liveDmg = u._stats:FindFirstChild("damage") and u._stats.damage.Value or 0
				local liveRange = u._stats:FindFirstChild("range") and u._stats.range.Value or 20
				local liveSpa = (u._stats:FindFirstChild("attack_cooldown") and u._stats.attack_cooldown.Value) or tonumber(uinfo.attack_cooldown) or 5
				local hrp = u:FindFirstChild("HumanoidRootPart") or u.PrimaryPart
				local pos = hrp and hrp.Position
				local traitInfo = getUnitTraitInfo(AA, uUuid)
				local isFarm = isFarmUnit(AA, id, uinfo)
				local isIdol = IDOL_UNITS[id] == true
				local isNonAtk = isNonAttackingUnit(AA, id, uinfo) or liveDmg <= 0
				local isSupport = SUPPORT_UNITS[id] or isIdol or (uinfo and uinfo._show_as_buff_unit) or (isNonAtk and not isFarm)
				local rarityScore = (uinfo and RARITY_SCORE[uinfo.rarity]) or 500
				local canAir = unitCanTargetAirNow(AA, u, id, uinfo)
				local maxUpg = (uinfo and uinfo.upgrade and #uinfo.upgrade) or 10
				local wpIdx = (pos and waypoints and #waypoints > 0) and getClosestWaypointIndex(pos, waypoints) or 1
				local unitProg = (waypoints and #waypoints > 0) and (wpIdx / #waypoints) or 0

				local entry = {
					model = u,
					id = id,
					uuid = uUuid,
					isUnique = traitInfo.isUnique,
					traitName = traitInfo.traitName,
					traitMult = traitInfo.traitMult or 1.0,
					upgrade = upg,
					maxUpgrade = maxUpg,
					liveDamage = liveDmg,
					liveRange = liveRange,
					liveSpa = liveSpa,
					pos = pos,
					wpIdx = wpIdx,
					prog = unitProg,
					uinfo = uinfo,
					isFarm = isFarm,
					isIdol = isIdol,
					isSupport = isSupport,
					rarityScore = rarityScore,
					canAir = canAir,
				}
				table.insert(result.all, entry)
				result.byId[id] = (result.byId[id] or 0) + 1
				if uUuid then
					result.byUuid[uUuid] = (result.byUuid[uUuid] or 0) + 1
				end

				if id == "vegito" then
					result.vegitoEntry = entry
				elseif VEGO_UNITS[id] then
					if not result.vegoEntry or entry.upgrade > result.vegoEntry.upgrade then
						result.vegoEntry = entry
					end
				elseif CARROT_UNITS[id] then
					if not result.carrotEntry or entry.upgrade > result.carrotEntry.upgrade then
						result.carrotEntry = entry
					end
				elseif isIdol then
					result.idolEntry = entry
				elseif TIMESTOP_UNITS[id] then
					result.homuraEntry = entry
				elseif id == "erwin" or id == "erwin_school" or id == "erwin_halloween" then
					table.insert(result.erwins, entry)
				end

				if isFarm then
					table.insert(result.farms, entry)
				elseif isSupport then
					table.insert(result.supports, entry)
				else
					table.insert(result.dps, entry)
					result.totalDpsUpgrades += upg
					result.totalDamage += liveDmg
					if canAir then
						result.totalAirDamage += liveDmg
						result.airTargetCount += 1
					end
				end
			end
		end
	end
	return result
end

local function getNextUpgradeCost(AA, entry)
	local uinfo = entry.uinfo
	if not uinfo or not uinfo.upgrade then
		return nil
	end
	local nextTbl = uinfo.upgrade[entry.upgrade + 1]
	if not nextTbl or not nextTbl.cost then
		return nil
	end
	local reg = AA.getRegistries()
	local usc = reg.CoreServices.UnitServiceCore.module
	local ucsc = reg.ClientServices.UnitCollectionServiceClient.module
	local mult = usc.calculate_upgrade_cost_multiplier(entry.model, ucsc.session)
	return math.ceil(tonumber(nextTbl.cost) * mult)
end

local function formatTimeMMSS(totalSec)
	totalSec = math.max(0, math.floor(tonumber(totalSec) or 0))
	local hrs = math.floor(totalSec / 3600)
	local mins = math.floor((totalSec % 3600) / 60)
	local secs = totalSec % 60
	if hrs > 0 then
		return string.format("%d:%02d:%02d", hrs, mins, secs)
	end
	return string.format("%d:%02d", mins, secs)
end

local function loadSessionStats()
	local data = {
		sessionStart = os.time(),
		matches = 0,
		wins = 0,
		losses = 0,
	}
	pcall(function()
		if type(isfile) == "function" and type(readfile) == "function" and isfile(SESSION_FILE) then
			local raw = readfile(SESSION_FILE)
			local decoded = HttpService:JSONDecode(raw)
			if type(decoded) == "table" and decoded.sessionStart then
				if (os.time() - tonumber(decoded.sessionStart)) < 43200 then
					data = decoded
				end
			end
		end
	end)
	return data
end

local function saveSessionStats(data)
	pcall(function()
		if type(writefile) == "function" then
			writefile(SESSION_FILE, HttpService:JSONEncode(data))
		end
	end)
end

local function getMatchMapName()
	local mapName = "unknown"
	pcall(function()
		local mc = workspace:FindFirstChild("_MAP_CONFIG")
		local gld = mc and mc:FindFirstChild("GetLevelData")
		if gld then
			local info = gld:InvokeServer()
			if type(info) == "table" and info.map then
				mapName = tostring(info.map)
			end
		end
	end)
	return mapName
end

local function getPlayerLevelAndXpText(lp)
	local levelNum = "?"
	local curXp = "0"
	local reqXp = "0"
	pcall(function()
		local pg = lp:FindFirstChild("PlayerGui")
		local su = pg and pg:FindFirstChild("spawn_units")
		local lives = su and su:FindFirstChild("Lives")
		local main = lives and lives:FindFirstChild("Main")
		local desc = main and main:FindFirstChild("Desc")
		local lvlLabel = desc and desc:FindFirstChild("Level")
		if lvlLabel and lvlLabel:IsA("TextLabel") then
			local txt = lvlLabel.Text or ""
			local l, c, r = txt:match("Level%s+(%d+)%s*%[(%d+)%s*/%s*(%d+)%]")
			if l and c and r then
				levelNum, curXp, reqXp = l, c, r
			end
		end
	end)
	return levelNum, curXp, reqXp
end

local function captureMatchStartSnapshot(lp)
	local stats = lp and lp:FindFirstChild("_stats")
	return {
		startTime = os.time(),
		summerPearls = stats and stats:FindFirstChild("_resourceSummerPearls") and stats._resourceSummerPearls.Value or 0,
		gems = stats and stats:FindFirstChild("gem_amount") and stats.gem_amount.Value or 0,
		gold = stats and stats:FindFirstChild("gold_amount") and stats.gold_amount.Value or 0,
		xp = stats and stats:FindFirstChild("player_xp") and stats.player_xp.Value or 0,
		mapName = getMatchMapName(),
	}
end

local function readMatchVictory()
	local reg = AnimeAdventures.getRegistries()
	local gui = reg and reg.ClientServices.GUIService and reg.ClientServices.GUIService.module
	local rui = gui and gui.results_ui
	if not rui then
		return nil
	end
	for _ = 1, 50 do
		local s = rui.settings
		if type(s) == "table" and type(s.victory) == "boolean" then
			return s.victory
		end
		local okT, winOn, loseOn = pcall(function()
			local tw, tl = rui.TitleWin, rui.TitleLose
			local function on(x)
				return x:IsA("GuiObject") and x.Visible or x.Enabled
			end
			return on(tw), on(tl)
		end)
		if okT and winOn ~= loseOn then
			return winOn == true
		end
		task.wait(0.1)
	end
	return nil
end

local function sendRoundSummaryWebhook(AA, state)
	local lp = Players.LocalPlayer
	if not lp then
		return
	end
	task.wait(2.2)
	local stats = lp:FindFirstChild("_stats")
	local snap = state.matchStartSnapshot or captureMatchStartSnapshot(lp)
	local durationSec = math.max(1, os.time() - (snap.startTime or os.time()))
	local mapName = (snap.mapName and snap.mapName ~= "unknown") and snap.mapName or getMatchMapName()
	local wave = workspace:FindFirstChild("_wave_num") and workspace._wave_num.Value or 0

	local curPearls = stats and stats:FindFirstChild("_resourceSummerPearls") and stats._resourceSummerPearls.Value or 0
	local curGems = stats and stats:FindFirstChild("gem_amount") and stats.gem_amount.Value or 0
	local curGold = stats and stats:FindFirstChild("gold_amount") and stats.gold_amount.Value or 0
	local curXpTotal = stats and stats:FindFirstChild("player_xp") and stats.player_xp.Value or 0

	local diffPearls = math.max(0, curPearls - (snap.summerPearls or curPearls))
	local diffGems = math.max(0, curGems - (snap.gems or curGems))
	local diffGold = math.max(0, curGold - (snap.gold or curGold))
	local diffXp = math.max(0, math.floor(curXpTotal - (snap.xp or curXpTotal)))

	local victory = readMatchVictory()
	local won
	if victory ~= nil then
		won = victory
	else
		won = (wave >= 50) or (diffPearls >= 300)
	end
	state.matchStartSnapshot = nil

	local levelNum, curXpBar, reqXpBar = getPlayerLevelAndXpText(lp)
	local displayName = lp.DisplayName or lp.Name
	local nameValue = string.format("[%s] %s (%s/%s)", tostring(levelNum), tostring(displayName), tostring(curXpBar), tostring(reqXpBar))
	if diffXp > 0 then
		nameValue = nameValue .. string.format(" (+%d PlayerEXP)", diffXp)
	end

	local session = loadSessionStats()
	session.sessionStart = math.min(tonumber(session.sessionStart) or os.time(), snap.startTime or os.time())
	session.matches = (session.matches or 0) + 1
	if won then
		session.wins = (session.wins or 0) + 1
	else
		session.losses = (session.losses or 0) + 1
	end
	saveSessionStats(session)

	local rewardLines = {}
	if diffPearls > 0 or curPearls > 0 then
		table.insert(rewardLines, string.format("`+%d Summer Pearls` [%d]", diffPearls, curPearls))
	end
	if diffGems > 0 then
		table.insert(rewardLines, string.format("`+%d Gems` [%d]", diffGems, curGems))
	end
	if diffGold > 0 then
		table.insert(rewardLines, string.format("`+%d Gold` [%d]", diffGold, curGold))
	end
	if #rewardLines == 0 then
		table.insert(rewardLines, string.format("`+0 Summer Pearls` [%d]", curPearls))
	end

	local statusStr = won and "Won" or string.format("Ended (Wave %d)", wave)
	local resultValue = string.format(
		"Summer Hunt (%s) - %s\n• Time: %s\n• Reward:\n%s",
		tostring(mapName),
		statusStr,
		formatTimeMMSS(durationSec),
		table.concat(rewardLines, "\n")
	)

	local sessionElapsed = math.max(durationSec, os.time() - (session.sessionStart or os.time()))
	local sessionValue = string.format(
		"Session Time: %s\nMatches Played: %d\nWin/Loss Ratio: %d:%d",
		formatTimeMMSS(sessionElapsed),
		session.matches,
		session.wins,
		session.losses
	)

	local payload = {
		embeds = {
			{
				title = "Anime Adventures • Summer Hunt",
				color = won and 3066993 or 15158332,
				fields = {
					{ name = "Name", value = nameValue, inline = false },
					{ name = "Result", value = resultValue, inline = false },
					{ name = "Session", value = sessionValue, inline = false },
				},
				footer = {
					text = "Anime Adventures • " .. os.date("%H:%M:%S"),
				},
			},
		},
	}

	local reqFn = (type(request) == "function" and request)
		or (type(http_request) == "function" and http_request)
		or (syn and type(syn.request) == "function" and syn.request)
		or (http and type(http.request) == "function" and http.request)
	if getConfig().WEBHOOK_ENABLED == false then
		return
	end
	local url = getConfig().WEBHOOK_URL
	if type(url) ~= "string" or url == "" then
		url = (getgenv and getgenv().AA_WEBHOOK_URL) or WEBHOOK_URL
	end
	if reqFn and type(url) == "string" and #url > 10 then
		reqFn({
			Url = url,
			Method = "POST",
			Headers = { ["Content-Type"] = "application/json" },
			Body = HttpService:JSONEncode(payload),
		})
	end
end

local function attachToAnimeAdventures(AA)
	AA.getSessionStats = loadSessionStats
	AA.getDefaultConfig = function()
		return DEFAULT_CONFIG
	end
	AA.AutoSummerEvent = AA.AutoSummerEvent or {
		running = false,
		stats = {
			ticks = 0,
			unitsSpawned = 0,
			unitsUpgraded = 0,
			roguelikePicked = 0,
			activesUsed = 0,
			erwinBuffsCast = 0,
			vegitoFusions = 0,
			replaysVoted = 0,
			leaksHandled = 0,
			lastAction = "idle",
		},
	}

	function AA.stepSummerEvent()
		local state = AA.AutoSummerEvent
		state.stats.ticks += 1
		local cfg = getConfig()

		if game.PlaceId == LOBBY_PLACE_ID then
			if cfg.AUTO_QUEUE == false then
				state.stats.lastAction = "lobby_idle"
				return "lobby"
			end
			local switchTeams = cfg.AUTO_SWITCH_TEAMS == true
			if cfg.AUTO_DAILY_CHALLENGE == true and AA.isDailyChallengePending() then
				state.stats.lastAction = "lobby_matchmaking_daily"
				if switchTeams then
					AA.ensureTeamLoadout(cfg.DAILY_TEAM_SLOT or DEFAULT_CONFIG.DAILY_TEAM_SLOT)
				end
				AA.joinAndStartSummerEvent(true, state, DAILY_LEVEL_ID)
			else
				state.stats.lastAction = "lobby_matchmaking_summer"
				if switchTeams then
					AA.ensureTeamLoadout(cfg.SUMMER_TEAM_SLOT or DEFAULT_CONFIG.SUMMER_TEAM_SLOT)
				end
				AA.joinAndStartSummerEvent(cfg.USE_MATCHMAKING ~= false, state)
			end
			return "lobby"
		end

		AA.restoreDeletedModules()
		local reg = AA.getRegistries()
		if not reg then
			return "waiting_reg"
		end
		local gui = reg.ClientServices.GUIService and reg.ClientServices.GUIService.module
		local ucsc = reg.ClientServices.UnitCollectionServiceClient and reg.ClientServices.UnitCollectionServiceClient.module
		local usc = reg.CoreServices.UnitServiceCore and reg.CoreServices.UnitServiceCore.module
		local Units = AA.loadData("Units")
		local lp = Players.LocalPlayer

		if not gui or not ucsc or not usc or not lp or not lp:FindFirstChild("_stats") then
			return "waiting_init"
		end

		local dataFolder = workspace:FindFirstChild("_DATA")
		if not dataFolder then
			return "waiting_data"
		end

		if not state.matchStartSnapshot then
			state.matchStartSnapshot = captureMatchStartSnapshot(lp)
		elseif (state.matchStartSnapshot.summerPearls or 0) == 0 and lp._stats:FindFirstChild("_resourceSummerPearls") and lp._stats._resourceSummerPearls.Value > 0 then
			local fresh = captureMatchStartSnapshot(lp)
			fresh.startTime = state.matchStartSnapshot.startTime or fresh.startTime
			state.matchStartSnapshot = fresh
		end

		if dataFolder:FindFirstChild("GameFinished") and dataFolder.GameFinished.Value then
			if not state.webhookSentForMatch then
				state.webhookSentForMatch = true
				pcall(function()
					if type(writefile) == "function" then
						local debugUnits = {}
						if workspace:FindFirstChild("_UNITS") then
							for _, u in ipairs(workspace._UNITS:GetChildren()) do
								if u:FindFirstChild("_stats") and u._stats:FindFirstChild("player") and u._stats.player.Value == lp and u.Name ~= "aot_generic" then
									table.insert(debugUnits, u.Name .. ":upg" .. tostring(u._stats.upgrade.Value) .. ":dmg" .. math.floor(u._stats.damage.Value))
								end
							end
						end
						writefile("aa_last_summer_match_debug.json", HttpService:JSONEncode({
							wave = workspace:FindFirstChild("_wave_num") and workspace._wave_num.Value or -1,
							cash = math.floor(lp._stats.resource.Value),
							units = debugUnits,
							stats = state.stats,
						}))
					end
				end)
				pcall(sendRoundSummaryWebhook, AA, state)
			end
			if cfg.RETURN_TO_LOBBY ~= false then
				local rui = gui and gui.results_ui
				if not (rui and rui._teleport_locked) and (tick() - (state.lastLobbyTeleportAttempt or 0)) >= 3.0 then
					state.lastLobbyTeleportAttempt = tick()
					state.lobbyTeleportTries = (state.lobbyTeleportTries or 0) + 1
					local ok = AA.invokeServer("teleport_back_to_lobby")
					state.stats.lastAction = "teleport_back_to_lobby"
					if not ok and state.lobbyTeleportTries >= 4 then
						pcall(function()
							game:GetService("TeleportService"):Teleport(LOBBY_PLACE_ID, lp)
						end)
					end
				end
				return "game_finished"
			end
			local ok = AA.invokeServer("set_game_finished_vote", "replay", "button")
			if ok then
				state.stats.replaysVoted += 1
				state.stats.lastAction = "voted_replay"
			end
			return "game_finished"
		else
			state.webhookSentForMatch = false
			state.lobbyTeleportTries = 0
		end

		local diffFolder = dataFolder:FindFirstChild("Difficulty")
		if diffFolder and diffFolder:FindFirstChild("DifficultyDecided") and not diffFolder.DifficultyDecided.Value then
			pcall(function()
				AA.invokeServer("select_difficulty", cfg.DIFFICULTY or "Hard")
			end)
			return "waiting_difficulty"
		end

		local voteStart = dataFolder:FindFirstChild("VoteStart")
		if voteStart and voteStart:FindFirstChild("VotingFinished") and not voteStart.VotingFinished.Value then
			if (not voteStart:FindFirstChild("StartTime") or voteStart.StartTime.Value > 0) and (tick() - (state.lastVoteStartTime or 0)) >= 2.0 then
				state.lastVoteStartTime = tick()
				pcall(function()
					AA.invokeServer("vote_start")
				end)
				state.stats.lastAction = "vote_start"
			end
		end

		if lp:FindFirstChild("_settings") and lp._settings:FindFirstChild("autoskip_waves") and not lp._settings.autoskip_waves.Value then
			AA.invokeServer("toggle_setting", "autoskip_waves")
		end
		if gui.vote_wave_ui and gui.vote_wave_ui.screenGUI and gui.vote_wave_ui.screenGUI.Enabled then
			AA.invokeServer("vote_wave_skip")
		end

		local rlFolder = dataFolder:FindFirstChild("Roguelike")
		if rlFolder and rlFolder:FindFirstChild("WaitingForRoguelikeChoice") and rlFolder.WaitingForRoguelikeChoice.Value then
			if (tick() - (state.lastRoguelikeVoteTime or 0)) >= 1.8 then
				local bestKey = "1"
				local bestScore = -math.huge
				if gui.roguelike_select_ui and gui.roguelike_select_ui.option_frames then
					for k, frame in pairs(gui.roguelike_select_ui.option_frames) do
						local cardScore = scoreSummerCardFrame(frame)
						if cardScore > bestScore then
							bestScore = cardScore
							bestKey = tostring(k)
						end
					end
				end
				state.lastRoguelikeVoteTime = tick()
				pcall(function()
					if gui.roguelike_select_ui and gui.roguelike_select_ui.select_option then
						gui.roguelike_select_ui:select_option(bestKey)
						gui.roguelike_select_ui.voted_option = bestKey
					end
				end)
				AA.invokeServer("select_roguelike_option", bestKey)
				state.stats.roguelikePicked += 1
				state.stats.lastAction = "picked_debuff_card_" .. tostring(bestKey)
			end
		end

		local wave = workspace:FindFirstChild("_wave_num") and workspace._wave_num.Value or 0
		local money = lp._stats.resource and lp._stats.resource.Value or 0
		local waypoints = getPathWaypoints()
		local placed = getPlayerPlacedUnits(AA, waypoints)
		local leakThreat = analyzeEnemyThreats(waypoints, placed.dps)

		if wave >= 49 and #placed.farms > 0 then
			for _, f in ipairs(placed.farms) do
				if not (f.uinfo and f.uinfo.unsellable) then
					AA.invokeServer("sell_unit_ingame", f.model)
					state.stats.lastAction = "sold_farm_" .. f.id
				end
			end
			placed = getPlayerPlacedUnits(AA, waypoints)
			money = lp._stats.resource.Value
		end

		local activeMobs = {}
		local totalWpsCount = math.max(1, #waypoints)
		local hasEnemyInDpsRange = (leakThreat ~= nil)
		if workspace:FindFirstChild("_UNITS") then
			for _, mob in ipairs(workspace._UNITS:GetChildren()) do
				if CollectionService:HasTag(mob, "pve_units") and not CollectionService:HasTag(mob, "dying_units") then
					local hrp = mob:FindFirstChild("HumanoidRootPart") or mob.PrimaryPart
					local hum = mob:FindFirstChild("Humanoid")
					if hrp and hum and hum.Health > 0 then
						local mobWpIdx = (#waypoints > 0 and getClosestWaypointIndex(hrp.Position, waypoints)) or 1
						local mobProg = mobWpIdx / totalWpsCount
						local isBoss = (mob:FindFirstChild("_stats") and mob._stats:FindFirstChild("boss") and mob._stats.boss.Value == true) or (hum.MaxHealth >= 60000)
						table.insert(activeMobs, {
							model = mob,
							pos = hrp.Position,
							hp = hum.Health,
							maxHp = hum.MaxHealth,
							wpIdx = mobWpIdx,
							prog = mobProg,
							isBoss = isBoss,
						})
						if not hasEnemyInDpsRange then
							for _, d in ipairs(placed.dps) do
								if d.pos and (Vector3.new(d.pos.X, 0, d.pos.Z) - Vector3.new(hrp.Position.X, 0, hrp.Position.Z)).Magnitude <= (d.liveRange + 2) then
									hasEnemyInDpsRange = true
									break
								end
							end
						end
					end
				end
			end
		end

		for _, entry in ipairs(placed.all) do
			local u = entry.model
			local activeId = usc.get_active_id and usc.get_active_id(u)
			if activeId then
				local isBuffActive = BUFF_ACTIVE_UNITS[entry.id] or string.find(activeId, "buff") ~= nil or string.find(activeId, "erwin") ~= nil
				local isTimestopActive = TIMESTOP_UNITS[entry.id] or string.find(activeId, "time") ~= nil or string.find(activeId, "freeze") ~= nil
				if isBuffActive or isTimestopActive then
					local st = u:FindFirstChild("_stats")
					if st and st:FindFirstChild("_auto_active") and st._auto_active.Value == true then
						st._auto_active.Value = false
					end
					if u:GetAttribute("_auto_active") == true then
						pcall(function()
							u:SetAttribute("_auto_active", false)
						end)
					end
				end
			end
		end

		if not placed.vegitoEntry and placed.vegoEntry and placed.carrotEntry then
			if placed.vegoEntry.upgrade >= 7 and placed.carrotEntry.upgrade >= 7 then
				local vegoTrait = placed.vegoEntry.traitMult or 1.0
				local carrotTrait = placed.carrotEntry.traitMult or 1.0
				local casterEntry = (carrotTrait > vegoTrait) and placed.carrotEntry or placed.vegoEntry
				local casterModel = casterEntry.model
				local activeId = usc.get_active_id and usc.get_active_id(casterModel)
				if (activeId == "vegito_fusion_vegeta" or activeId == "vegito_fusion") and (tick() - (state.lastFusionCastAttempt or 0)) >= 1.5 then
					state.lastFusionCastAttempt = tick()
					state.fusionTryCount = (state.fusionTryCount or 0) + 1
					pcall(function()
						AA.invokeServer("use_active_attack", casterModel)
					end)
					state.stats.activesUsed += 1
					state.stats.vegitoFusions += 1
					state.stats.lastAction = "cast_vegito_fusion"
					task.wait(0.3)
					placed = getPlayerPlacedUnits(AA, waypoints)
				end
			end
		else
			state.fusionTryCount = 0
		end

		if cfg.PERFECT_ERWIN_BUFF ~= false and AA.stepPerfectErwinBuff then
			pcall(AA.stepPerfectErwinBuff)
		end

		for _, entry in ipairs(placed.all) do
			local u = entry.model
			local activeId = usc.get_active_id and usc.get_active_id(u)
			if activeId and not REPOSITION_ACTIVE_UNITS[entry.id] and activeId ~= "vegito_fusion" and activeId ~= "vegito_fusion_vegeta" and activeId ~= "erwin:buff_units" and activeId ~= "himeno:final" then
				local st = u:FindFirstChild("_stats")
				local cd = st and st:FindFirstChild("active_attack_cooldown") and st.active_attack_cooldown.Value or 0
				local lastCast = st and st:FindFirstChild("last_active_cast") and st.last_active_cast.Value or 0
				local queued = st and st:FindFirstChild("active_queued_or_using") and st.active_queued_or_using.Value or false
				if not queued and (cd - (tick() - lastCast)) <= 0 then
					local isTimestopActive = TIMESTOP_UNITS[entry.id] or string.find(activeId, "time") ~= nil or string.find(activeId, "freeze") ~= nil
					local allowCast = true
					if isTimestopActive and cfg.SMART_TIMESTOP ~= false then
						if not hasEnemyInDpsRange or (tick() - (state.lastTimestopCast or 0)) < 10.2 then
							allowCast = false
						elseif entry.pos and entry.liveRange > 0 then
							local anyInUnitRange = false
							for _, mob in ipairs(activeMobs) do
								local dist2D = (Vector3.new(entry.pos.X, 0, entry.pos.Z) - Vector3.new(mob.pos.X, 0, mob.pos.Z)).Magnitude
								if dist2D <= (entry.liveRange + 1.5) then
									anyInUnitRange = true
									break
								end
							end
							if not anyInUnitRange then
								allowCast = false
							end
						end
					end
					if allowCast then
						pcall(function()
							AA.invokeServer("use_active_attack", u)
							state.stats.activesUsed += 1
							if isTimestopActive then
								state.lastTimestopCast = tick()
								state.stats.lastAction = "timestop_" .. entry.id
							end
						end)
					end
				end
			end
		end

		local spawnMult = usc.calculate_spawn_cost_multiplier(ucsc.session)
		state.failedPositions = state.failedPositions or {}
		if wave <= 1 and #state.failedPositions > 0 then
			state.failedPositions = {}
		end

		local bestPlacedCarry = placed.vegitoEntry or placed.vegoEntry
		if not bestPlacedCarry then
			local bestPlacedScore = -1
			for _, d in ipairs(placed.dps) do
				local sc = (d.isUnique and 1000000 or 0) + ((d.traitMult or 1) * 50000) + (d.rarityScore * 100) + d.liveDamage
				if sc > bestPlacedScore then
					bestPlacedScore = sc
					bestPlacedCarry = d
				end
			end
		end

		local primaryCarryAnchorPos = (placed.vegitoEntry and placed.vegitoEntry.pos)
			or (placed.vegoEntry and placed.vegoEntry.pos)
			or (bestPlacedCarry and bestPlacedCarry.pos)
			or (placed.carrotEntry and placed.carrotEntry.pos)
			or (placed.homuraEntry and placed.homuraEntry.pos)
		local erwinPositions = {}
		for _, erw in ipairs(placed.erwins) do
			if erw.pos then
				table.insert(erwinPositions, erw.pos)
			end
		end
		local firstErwinPos = (#erwinPositions > 0 and erwinPositions) or nil

		local hasVegito = placed.vegitoEntry ~= nil
		local hasVego = placed.vegoEntry ~= nil
		local hasCarrot = placed.carrotEntry ~= nil
		local hasIdol = placed.idolEntry ~= nil
		local totalFarmsPlaced = #placed.farms
		local myErwinCount = #placed.erwins
		local globalErwinCount = getGlobalUnitCountById("erwin")
		local targetErwins = math.min(cfg.TARGET_ERWIN_COUNT or 4, 6 - math.max(0, globalErwinCount - myErwinCount))

		local deckHasVego = false
		local deckHasCarrot = false
		local deckSlots = {}
		local bestDeckCarrySlot = nil
		local bestDeckCarryScore = -1
		local bestDeckAirSlot = nil
		local bestDeckAirScore = -1

		for i = 1, 6 do
			local slot = tostring(i)
			local uuid, udata = ucsc.get_unit_in_equipped_slot(slot)
			if uuid and udata then
				local unitId = udata.unit_id
				local uinfo = Units[unitId]
				if uinfo then
					if VEGO_UNITS[unitId] then
						deckHasVego = true
					elseif CARROT_UNITS[unitId] then
						deckHasCarrot = true
					end
					local traitInfo = getUnitTraitInfo(AA, uuid)
					local isFarm = isFarmUnit(AA, unitId, uinfo)
					local isIdol = IDOL_UNITS[unitId] == true
					local isSupport = SUPPORT_UNITS[unitId] or isIdol or (uinfo and uinfo._show_as_buff_unit) or (isNonAttackingUnit(AA, unitId, uinfo) and not isFarm)
					local rarityScore = (uinfo and RARITY_SCORE[uinfo.rarity]) or 500
					local canAir = (uinfo.hill_unit == true) or (uinfo.hybrid_placement == true) or CARROT_UNITS[unitId] == true
					local carryScore = (traitInfo.isUnique and 5000 or 0) + (traitInfo.traitMult * 600) + rarityScore
					if not isFarm and not isSupport then
						if carryScore > bestDeckCarryScore and not uinfo.hill_unit then
							bestDeckCarryScore = carryScore
							bestDeckCarrySlot = slot
						end
						if canAir and carryScore > bestDeckAirScore then
							bestDeckAirScore = carryScore
							bestDeckAirSlot = slot
						end
					end
					deckSlots[i] = {
						slot = slot,
						uuid = uuid,
						unitId = unitId,
						uinfo = uinfo,
						traitInfo = traitInfo,
						isFarm = isFarm,
						isIdol = isIdol,
						isSupport = isSupport,
						rarityScore = rarityScore,
						canAir = canAir,
						carryScore = carryScore,
					}
				end
			end
		end

		local deckHasFusionPair = (deckHasVego and deckHasCarrot) or hasVegito or (hasVego and hasCarrot)
		local hasFrontCarryPlaced = hasVegito or hasVego or (#placed.dps >= 1)
		local hasAirCarryPlaced = hasVegito or hasCarrot or (placed.airTargetCount >= 1)

		local slotCandidates = {}
		for i = 1, 6 do
			local ds = deckSlots[i]
			if ds and not ucsc.session.collection:is_unit_on_cooldown(ds.uuid) then
				local slot = ds.slot
				local uuid = ds.uuid
				local unitId = ds.unitId
				local uinfo = ds.uinfo
				local spawnCost = math.ceil((tonumber(uinfo.cost) or 500) * spawnMult)
				local placedCount = placed.byId[unitId] or 0
				local unitCap = ds.traitInfo.isUnique and 1 or (tonumber(uinfo.spawn_cap) or 3)
				local spawnPriority = 0
				local placementMode = "front"
				local fusionPartnerPos = nil
				local preferNearHill = false

				if ds.isFarm then
					placementMode = "farm"
					if MAIN_FARM_UNITS[unitId] then
						local mainFarmCount = placed.byId[unitId] or 0
						if mainFarmCount == 0 and wave <= 2 then
							spawnPriority = 1000
						elseif mainFarmCount < unitCap and (hasFrontCarryPlaced or wave >= 2) and wave <= 20 then
							spawnPriority = 850 - mainFarmCount * 30
						end
					elseif placedCount < unitCap and wave <= 20 then
						if totalFarmsPlaced == 0 and tonumber(uinfo.cost or 9999) <= 650 and wave <= 2 then
							spawnPriority = 995
						elseif hasFrontCarryPlaced or wave >= 3 then
							spawnPriority = 840 - placedCount * 30
						end
					end
				elseif deckHasFusionPair and VEGO_UNITS[unitId] then
					placementMode = "front"
					preferNearHill = true
					if placed.carrotEntry and placed.carrotEntry.pos then
						fusionPartnerPos = placed.carrotEntry.pos
					end
					if not hasVegito and not hasVego then
						spawnPriority = 980
					end
				elseif deckHasFusionPair and CARROT_UNITS[unitId] then
					placementMode = "front"
					if placed.vegoEntry and placed.vegoEntry.pos then
						fusionPartnerPos = placed.vegoEntry.pos
					end
					if not hasVegito and not hasCarrot and (hasVego or totalFarmsPlaced >= 1) then
						spawnPriority = 920
					end
				elseif ds.isIdol then
					placementMode = primaryCarryAnchorPos and "buffer" or "front"
					if not hasIdol and hasFrontCarryPlaced and (hasAirCarryPlaced or wave >= 3) and (totalFarmsPlaced >= 2 or wave >= 4) then
						spawnPriority = 820
					end
				elseif TIMESTOP_UNITS[unitId] then
					placementMode = "front"
					if primaryCarryAnchorPos then
						fusionPartnerPos = primaryCarryAnchorPos
					end
					if placedCount == 0 and hasFrontCarryPlaced and (hasAirCarryPlaced or wave >= 3) and (totalFarmsPlaced >= 3 or wave >= 4) then
						spawnPriority = 790
					elseif placedCount < unitCap and (hasVegito or (#placed.dps >= 2 and wave >= 8)) and myErwinCount >= targetErwins then
						spawnPriority = 710 - placedCount * 20
					end
				elseif unitId == "erwin" or unitId == "erwin_school" or unitId == "erwin_halloween" then
					placementMode = primaryCarryAnchorPos and "buffer" or "front"
					if myErwinCount < targetErwins and globalErwinCount < 6 and hasFrontCarryPlaced and (hasAirCarryPlaced or wave >= 3) and (totalFarmsPlaced >= 3 or wave >= 4) then
						spawnPriority = 825 - myErwinCount * 2
					end
				elseif ds.isSupport then
					placementMode = primaryCarryAnchorPos and "buffer" or "front"
					local supCap = math.min(unitCap, 3)
					if placedCount < supCap and hasFrontCarryPlaced and (totalFarmsPlaced >= 2 or wave >= 4) then
						spawnPriority = 740 - placedCount * 20
					end
				elseif placedCount < unitCap then
					placementMode = "front"
					if primaryCarryAnchorPos then
						fusionPartnerPos = primaryCarryAnchorPos
					end
					if leakThreat and leakThreat.aheadDpsCount == 0 and (not leakThreat.isFlying or ds.canAir) then
						placementMode = "leak"
						spawnPriority = 990 + (ds.carryScore / 100)
					elseif not hasFrontCarryPlaced and slot == bestDeckCarrySlot then
						spawnPriority = 975
					elseif not hasAirCarryPlaced and ds.canAir and (slot == bestDeckAirSlot or wave >= 2) then
						spawnPriority = 915
					elseif hasFrontCarryPlaced and (totalFarmsPlaced >= 2 or wave >= 3) then
						spawnPriority = 730 + (ds.traitInfo.isUnique and 140 or 0) + math.min(60, ds.rarityScore / 10) - (placedCount * 25)
					end
				end

				if spawnPriority > 0 then
					table.insert(slotCandidates, {
						slot = slot,
						uuid = uuid,
						unitId = unitId,
						uinfo = uinfo,
						cost = spawnCost,
						priority = spawnPriority,
						mode = placementMode,
						fusionPartnerPos = fusionPartnerPos,
						preferNearHill = preferNearHill,
					})
				end
			end
		end

		table.sort(slotCandidates, function(a, b)
			return a.priority > b.priority
		end)

		local topSpawn = slotCandidates[1]
		if topSpawn and money >= topSpawn.cost then
			local cf, hitPos = findValidPlacementCFrame(
				AA,
				topSpawn.uinfo,
				topSpawn.mode,
				leakThreat and leakThreat.wpIdx,
				state.failedPositions,
				leakThreat and leakThreat.pos,
				topSpawn.fusionPartnerPos,
				topSpawn.preferNearHill,
				primaryCarryAnchorPos,
				firstErwinPos
			)
			if cf and hitPos then
				local prevCount = #placed.all
				local prevMoney = money
				AA.invokeServer("spawn_unit", topSpawn.uuid, cf)
				local newPlaced = getPlayerPlacedUnits(AA, waypoints)
				local newMoney = lp._stats.resource.Value
				if #newPlaced.all > prevCount or newMoney < (prevMoney - 50) then
					state.stats.unitsSpawned += 1
					state.stats.lastAction = "spawn_" .. topSpawn.unitId .. "_" .. topSpawn.mode
					placed = newPlaced
					money = newMoney
					leakThreat = analyzeEnemyThreats(waypoints, placed.dps)
				else
					table.insert(state.failedPositions, hitPos)
				end
			end
		end

		placed = getPlayerPlacedUnits(AA, waypoints)
		money = lp._stats.resource.Value
		hasVegito = placed.vegitoEntry ~= nil
		hasVego = placed.vegoEntry ~= nil
		hasCarrot = placed.carrotEntry ~= nil

		if placed.carrotEntry and (hasVego or hasVegito or #placed.dps >= 2) then
			local cModel = placed.carrotEntry.model
			if cModel:FindFirstChild("_stats") and cModel._stats:FindFirstChild("priority") and cModel._stats.priority.Value ~= "flying" then
				AA.invokeServer("change_priority", cModel, "flying")
			end
		elseif placed.airTargetCount >= 1 and #placed.dps >= 2 then
			for _, d in ipairs(placed.dps) do
				if d.canAir and d.model:FindFirstChild("_stats") and d.model._stats:FindFirstChild("priority") then
					if d.model._stats.priority.Value ~= "flying" then
						AA.invokeServer("change_priority", d.model, "flying")
					end
					break
				end
			end
		end

		local primaryUpgradeCarry = nil
		local primaryUpgradeScore = -1
		local primaryAirUpgradeCarry = nil
		local primaryAirUpgradeScore = -1
		for _, d in ipairs(placed.dps) do
			if d.upgrade < d.maxUpgrade then
				local sc = (d.isUnique and 1000000 or 0) + ((d.traitMult or 1) * 50000) + (d.rarityScore * 100) + d.liveDamage + (d.upgrade * 2500)
				if sc > primaryUpgradeScore then
					primaryUpgradeScore = sc
					primaryUpgradeCarry = d
				end
				if d.canAir and sc > primaryAirUpgradeScore then
					primaryAirUpgradeScore = sc
					primaryAirUpgradeCarry = d
				end
			end
		end

		local reservedMoney = 0
		if topSpawn and topSpawn.priority >= 820 then
			reservedMoney = topSpawn.cost
		end

		local upgradeQueue = {}
		for _, entry in ipairs(placed.all) do
			local nextCost = getNextUpgradeCost(AA, entry)
			if nextCost and entry.upgrade < entry.maxUpgrade then
				local priority = 0

				if MAIN_FARM_UNITS[entry.id] and (hasVego or #placed.dps >= 1) and wave <= 20 then
					priority = 1350 - (nextCost / 200)
				elseif entry.isFarm and (#placed.dps >= 1) and wave <= 20 and nextCost <= 3500 then
					priority = 1340 - (nextCost / 200)
				elseif entry.isIdol and entry.upgrade < 3 and nextCost <= 3500 then
					priority = 1310 - entry.upgrade * 15
				elseif deckHasFusionPair and not hasVegito and VEGO_UNITS[entry.id] and entry.upgrade < 7 then
					priority = 1280 - entry.upgrade * 5
				elseif deckHasFusionPair and not hasVegito and CARROT_UNITS[entry.id] and entry.upgrade < 7 then
					local vegoUpg = (placed.vegoEntry and placed.vegoEntry.upgrade) or 0
					if vegoUpg >= 7 or entry.upgrade <= vegoUpg then
						priority = 1275 - entry.upgrade * 5
					else
						priority = 1240 - entry.upgrade * 5
					end
				elseif entry.id == "vegito" then
					priority = 1400 - entry.upgrade * 4
				elseif entry.isFarm and (#placed.dps >= 1) and wave <= 18 and nextCost <= 8500 and (placed.totalDamage >= wave * 1800 or hasVegito) then
					priority = 1225 - (nextCost / 250)
				elseif not deckHasFusionPair and primaryUpgradeCarry and entry.model == primaryUpgradeCarry.model then
					priority = 1290 - entry.upgrade * 4
				elseif not deckHasFusionPair and primaryAirUpgradeCarry and entry.model == primaryAirUpgradeCarry.model and entry.upgrade < 5 then
					priority = 1250 - entry.upgrade * 5
				elseif TIMESTOP_UNITS[entry.id] and entry.upgrade < 7 and (hasVegito or (placed.vegoEntry and placed.vegoEntry.upgrade >= 5) or (not deckHasFusionPair and #placed.dps >= 1)) then
					priority = 1210 - entry.upgrade * 6
				elseif (entry.id == "erwin" or entry.id == "erwin_school" or entry.id == "erwin_halloween") and (hasVegito or (placed.vegoEntry and placed.vegoEntry.upgrade >= 6) or (not deckHasFusionPair and #placed.dps >= 1)) then
					priority = 1190 - entry.upgrade * 12
				elseif entry.isIdol then
					priority = 1170 - entry.upgrade * 10
				elseif entry.isSupport then
					priority = 1150 - entry.upgrade * 12
				elseif CARROT_UNITS[entry.id] or VEGO_UNITS[entry.id] then
					priority = 1140 - entry.upgrade * 8
				else
					priority = 1000 + (entry.isUnique and 80 or 0) + math.min(60, entry.rarityScore / 10) - entry.upgrade * 10
				end

				if priority > 0 then
					table.insert(upgradeQueue, { entry = entry, cost = nextCost, priority = priority })
				end
			end
		end

		table.sort(upgradeQueue, function(a, b)
			if math.abs(a.priority - b.priority) > 10 then
				return a.priority > b.priority
			end
			return a.cost < b.cost
		end)

		local availableForUpgrades = math.max(0, money - reservedMoney)
		local topUpgrade = upgradeQueue[1]
		if topUpgrade then
			if availableForUpgrades >= topUpgrade.cost then
				local ok = AA.invokeServer("upgrade_unit_ingame", topUpgrade.entry.model)
				if ok then
					state.stats.unitsUpgraded += 1
					state.stats.lastAction = "upg_" .. topUpgrade.entry.id .. "_to_" .. tostring(topUpgrade.entry.upgrade + 1)
				end
			end
		end

		return "active_wave_" .. tostring(wave)
	end

	local function getUnitPhysBuff(u)
		if not u or not u.Parent then
			return 0
		end
		local b = u:FindFirstChild("_buffs")
		local p = b and b:FindFirstChild("damage_buff__physical")
		return (p and p.Value) or 0
	end

	local function isErwinReadyToCast(u)
		if not u or not u.Parent then
			return false
		end
		local st = u:FindFirstChild("_stats")
		if not st then
			return false
		end
		local cd = st:FindFirstChild("active_attack_cooldown") and st.active_attack_cooldown.Value or 60
		local lastCast = st:FindFirstChild("last_active_cast") and st.last_active_cast.Value or 0
		local queued = st:FindFirstChild("active_queued_or_using") and st.active_queued_or_using.Value or false
		return (not queued) and ((cd - (tick() - lastCast)) <= 0)
	end

	local function tryCastErwin(u)
		if not isErwinReadyToCast(u) then
			return false
		end
		local st = u:FindFirstChild("_stats")
		local beforeCast = st and st:FindFirstChild("last_active_cast") and st.last_active_cast.Value or 0
		local ok, res = pcall(function()
			return AA.invokeServer("use_active_attack", u)
		end)
		local afterCast = st and st:FindFirstChild("last_active_cast") and st.last_active_cast.Value or 0
		if afterCast > beforeCast or (ok and res == true) then
			return true
		end
		return false
	end

	function AA.stepPerfectErwinBuff()
		local state = AA.AutoSummerEvent
		if not state or game.PlaceId == LOBBY_PLACE_ID then
			return
		end
		local cfg = getConfig()
		if cfg.PERFECT_ERWIN_BUFF == false then
			return
		end
		local lp = Players.LocalPlayer
		local unitsFolder = workspace:FindFirstChild("_UNITS")
		if not lp or not unitsFolder then
			return
		end

		state.erwinOrder = state.erwinOrder or {}
		local validMap = {}
		local currentErwins = {}
		local carryUnit = nil

		for _, u in ipairs(unitsFolder:GetChildren()) do
			local st = u:FindFirstChild("_stats")
			if st and st:FindFirstChild("player") and st.player.Value == lp then
				local stateVal = st:FindFirstChild("state") and st.state.Value or "idle"
				if stateVal ~= "destroyed" then
					local id = st:FindFirstChild("id") and st.id.Value or u.Name
					if id == "erwin" or id == "erwin_school" or id == "erwin_halloween" then
						if st:FindFirstChild("_auto_active") and st._auto_active.Value == true then
							st._auto_active.Value = false
						end
						validMap[u] = true
						table.insert(currentErwins, u)
					elseif id == "vegito" then
						carryUnit = u
					elseif not carryUnit and (VEGO_UNITS[id] or CARROT_UNITS[id]) then
						carryUnit = u
					end
				end
			end
		end

		local keptOrder = {}
		local inKept = {}
		for _, u in ipairs(state.erwinOrder) do
			if validMap[u] and not inKept[u] then
				table.insert(keptOrder, u)
				inKept[u] = true
			end
		end
		for _, u in ipairs(currentErwins) do
			if not inKept[u] then
				table.insert(keptOrder, u)
				inKept[u] = true
			end
		end
		state.erwinOrder = keptOrder

		local n = #keptOrder
		local requiredErwins = math.min(cfg.TARGET_ERWIN_COUNT or 4, 4)
		local globalErwins = getGlobalUnitCountById("erwin")
		local maxPossibleForMe = math.min(requiredErwins, 6 - math.max(0, globalErwins - n))

		if n < math.max(1, maxPossibleForMe) then
			state.erwinStage = 0
			return
		end

		if n < 4 then
			local watchUnit = carryUnit or keptOrder[1]
			if getUnitPhysBuff(watchUnit) == 0 and (tick() - (state.lastErwinBuffCast or 0)) >= 1.5 then
				for _, u in ipairs(keptOrder) do
					if tryCastErwin(u) then
						state.lastErwinBuffCast = tick()
						state.stats.activesUsed += 1
						state.stats.erwinBuffsCast += 1
						state.stats.lastAction = "erwin_fallback_buff"
						break
					end
				end
			end
			return
		end

		local E1, E2, E3, E4 = keptOrder[1], keptOrder[2], keptOrder[3], keptOrder[4]
		local b1 = getUnitPhysBuff(E1)
		local b2 = getUnitPhysBuff(E2)
		local b3 = getUnitPhysBuff(E3)
		local b4 = getUnitPhysBuff(E4)
		local now = tick()
		local stage = state.erwinStage or 0
		local elapsed = now - (state.erwinStageTime or 0)

		if stage == 0 or (stage >= 3 and elapsed > 8.0 and b1 == 0 and b2 == 0 and b3 == 0 and b4 == 0) then
			stage = 1
			state.erwinStage = 1
		end

		if stage == 1 then
			if b2 == 0 and b3 == 0 and b4 == 0 then
				if tryCastErwin(E1) then
					state.erwinStage = 2
					state.erwinStageTime = now
					state.erwinSawPairABuff = (getUnitPhysBuff(E2) > 0 or getUnitPhysBuff(E3) > 0 or getUnitPhysBuff(E4) > 0)
					state.lastErwinBuffCast = now
					state.stats.activesUsed += 1
					state.stats.erwinBuffsCast += 1
					state.stats.lastAction = "erwin_step1_first_buff"
				end
			end
		elseif stage == 2 then
			if b2 > 0 or b3 > 0 or b4 > 0 then
				state.erwinSawPairABuff = true
			end
			if elapsed >= 4.5 then
				if tryCastErwin(E2) then
					state.erwinStage = 3
					state.erwinStageTime = now
					state.erwinSawPairBBuff = (getUnitPhysBuff(E1) > 0)
					state.lastErwinBuffCast = now
					state.stats.activesUsed += 1
					state.stats.erwinBuffsCast += 1
					state.stats.lastAction = "erwin_step2_second_buff_56pct"
				end
			end
		elseif stage == 3 then
			if b1 > 0 then
				state.erwinSawPairBBuff = true
			end
			if b2 > 0 or b3 > 0 or b4 > 0 then
				state.erwinSawPairABuff = true
			end
			local buff25Expired = (state.erwinSawPairABuff and b2 == 0 and b4 == 0) or (elapsed >= 16.5 and b2 == 0 and b4 == 0)
			if buff25Expired then
				if tryCastErwin(E3) then
					state.erwinStage = 4
					state.erwinStageTime = now
					state.erwinSawPairABuff = (getUnitPhysBuff(E2) > 0 or getUnitPhysBuff(E4) > 0)
					state.lastErwinBuffCast = now
					state.stats.activesUsed += 1
					state.stats.erwinBuffsCast += 1
					state.stats.lastAction = "erwin_step3_third_buff_100pct"
				end
			end
		elseif stage == 4 then
			if b2 > 0 or b4 > 0 then
				state.erwinSawPairABuff = true
			end
			if b1 > 0 or b3 > 0 then
				state.erwinSawPairBBuff = true
			end
			local buff56Expired = (state.erwinSawPairBBuff and b1 == 0 and b3 == 0) or (elapsed >= 2.0 and b1 == 0 and b3 == 0)
			if buff56Expired then
				if tryCastErwin(E4) then
					state.erwinStage = 5
					state.erwinStageTime = now
					state.erwinSawPairBBuff = (getUnitPhysBuff(E1) > 0 or getUnitPhysBuff(E3) > 0)
					state.lastErwinBuffCast = now
					state.stats.activesUsed += 1
					state.stats.erwinBuffsCast += 1
					state.stats.lastAction = "erwin_step4_fourth_buff_loop"
				end
			end
		elseif stage == 5 then
			if b1 > 0 or b3 > 0 then
				state.erwinSawPairBBuff = true
			end
			if b2 > 0 or b4 > 0 then
				state.erwinSawPairABuff = true
			end
			local pairAExpired = (state.erwinSawPairABuff and b2 == 0 and b4 == 0) or (elapsed >= 2.0 and b2 == 0 and b4 == 0)
			if pairAExpired then
				if tryCastErwin(E1) then
					state.erwinStage = 6
					state.erwinStageTime = now
					state.erwinSawPairABuff = (getUnitPhysBuff(E2) > 0 or getUnitPhysBuff(E4) > 0)
					state.lastErwinBuffCast = now
					state.stats.activesUsed += 1
					state.stats.erwinBuffsCast += 1
					state.stats.lastAction = "erwin_loop_cast_E1_100pct"
				end
			end
		elseif stage == 6 then
			if b2 > 0 or b4 > 0 then
				state.erwinSawPairABuff = true
			end
			if b1 > 0 or b3 > 0 then
				state.erwinSawPairBBuff = true
			end
			local pairBExpired = (state.erwinSawPairBBuff and b1 == 0 and b3 == 0) or (elapsed >= 2.0 and b1 == 0 and b3 == 0)
			if pairBExpired then
				if tryCastErwin(E2) then
					state.erwinStage = 3
					state.erwinStageTime = now
					state.erwinSawPairBBuff = (getUnitPhysBuff(E1) > 0 or getUnitPhysBuff(E3) > 0)
					state.lastErwinBuffCast = now
					state.stats.activesUsed += 1
					state.stats.erwinBuffsCast += 1
					state.stats.lastAction = "erwin_loop_cast_E2_100pct"
				end
			end
		end
	end

	function AA.startAutoSummerEvent()
		if AA.AutoSummerEvent.running then
			return "already_running"
		end
		AA.AutoSummerEvent.running = true

		task.spawn(function()
			while AA.AutoSummerEvent and AA.AutoSummerEvent.running do
				pcall(AA.stepPerfectErwinBuff)
				task.wait(0.12)
			end
		end)

		task.spawn(function()
			while AA.AutoSummerEvent and AA.AutoSummerEvent.running do
				local ok, err = pcall(AA.stepSummerEvent)
				if not ok then
					AA.AutoSummerEvent.stats.lastError = tostring(err)
				end
				task.wait(0.8)
			end
		end)
		return "started"
	end

	function AA.stopAutoSummerEvent()
		if AA.AutoSummerEvent then
			AA.AutoSummerEvent.running = false
		end
		return "stopped"
	end

	AA.startAutoAprilFools = AA.startAutoSummerEvent
	AA.stopAutoAprilFools = AA.stopAutoSummerEvent
end

attachToAnimeAdventures(AnimeAdventures)

task.spawn(function()
	if not game:IsLoaded() then
		game.Loaded:Wait()
	end
	local lp = Players.LocalPlayer or Players.PlayerAdded:Wait()
	if lp and (not ALLOWED_SUMMER_USERNAME or lp.Name == ALLOWED_SUMMER_USERNAME) and not getgenv().AA_NO_AUTOSTART then
		task.wait(2)
		AnimeAdventures.startAutoSummerEvent()
	end
end)
