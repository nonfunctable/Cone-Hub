local ALLOWED_APRIL_FOOLS_USERNAME = (getgenv and getgenv().AA_ALLOWED_USERNAME) or nil
local ANIME_ADVENTURES_GAME_ID = 3183403065
local LOBBY_PLACE_ID = 8304191830

if game.GameId ~= 0 and game.GameId ~= ANIME_ADVENTURES_GAME_ID and game.PlaceId ~= LOBBY_PLACE_ID and game.PlaceId ~= 14229839966 then
	return
end

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local HttpService = game:GetService("HttpService")

do
	local lpCheck = Players.LocalPlayer or Players.PlayerAdded:Wait()
	if not lpCheck or (ALLOWED_APRIL_FOOLS_USERNAME and lpCheck.Name ~= ALLOWED_APRIL_FOOLS_USERNAME) then
		return
	end
end

local SESSION_FILE = "aa_april_fools_session.json"

local AnimeAdventures = getgenv().AnimeAdventures or {}
getgenv().AnimeAdventures = AnimeAdventures

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

function AnimeAdventures.joinAndStartAprilFools(useMatchmaking)
	if useMatchmaking then
		return AnimeAdventures.invokeServer("request_matchmaking", "april2_event")
	end

	local reg = AnimeAdventures.getRegistries()
	local lsc = reg and reg.ClientServices.LobbyServiceClient and reg.ClientServices.LobbyServiceClient.module
	local gui = reg and reg.ClientServices.GUIService and reg.ClientServices.GUIService.module
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
	USE_ASTRAL_SUMMON = true,
	STAGGER_BUFF_ACTIVES = true,
	SMART_TIMESTOP = true,
	RETURN_TO_LOBBY = true,
}

local function getConfig()
	local g = (getgenv and getgenv()) or _G
	if type(g.AA_CONFIG) == "table" then
		return g.AA_CONFIG
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

local TRAP_UNITS = {
	usopp = true,
	usopp_evolved = true,
	usopp_ts = true,
	usopp_ts_evolved = true,
	deidara = true,
	deidara_evolved = true,
	kisuke = true,
	kisuke_evolved = true,
	elyssia = true,
	elyssia_evolved = true,
	teemo = true,
}

local BLACKLIST_UNITS = {
	armin = true,
	armin_evolved = true,
	eren = true,
	eren_final = true,
	mahoraga = true,
	guldo = true,
}

local FUSION_PARTNER_UNITS = {
	goku_ssj3_evolved = true,
	goku_ssj3 = true,
}

local BOSS_PREP_WAVES = {
	[9] = true,
	[10] = true,
	[14] = true,
	[15] = true,
	[19] = true,
	[20] = true,
	[24] = true,
	[25] = true,
	[28] = true,
	[29] = true,
	[30] = true,
}

local function scoreRoguelikeText(text)
	local t = string.lower(text or "")
	if t == "confirm" or string.find(t, "^%d+$") then
		return 0
	end

	local score = 0
	if string.find(t, "new path") or string.find(t, "lane") then
		score -= 250
	end
	if string.find(t, "shield") or string.find(t, "regen") then
		score -= 70
	end
	if string.find(t, "speed") and string.find(t, "+") then
		score -= 45
	end
	if string.find(t, "health") and string.find(t, "+") then
		score -= 25
	end
	if string.find(t, "damage") then
		if string.find(t, "+") then
			score += 55
		elseif string.find(t, "-") then
			score -= 65
		end
	end
	if string.find(t, "cooldown") then
		if string.find(t, "-") then
			score += 50
		elseif string.find(t, "+") then
			score -= 55
		end
	end
	if string.find(t, "range") then
		if string.find(t, "+") then
			score += 35
		elseif string.find(t, "-") then
			score -= 45
		end
	end
	if string.find(t, "cost") then
		if string.find(t, "-") then
			score += 40
		elseif string.find(t, "+") then
			score -= 50
		end
	end
	if string.find(t, "¥") or string.find(t, "yen") then
		score += 35
	end
	if string.find(t, "coin") or string.find(t, "april") or string.find(t, "reward") then
		score += 45
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
	for i = 1, 30 do
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
				local weight = 0.4
				if prog >= 0.04 and prog <= 0.25 then
					weight = 4.8
				elseif prog < 0.04 then
					weight = 3.6
				elseif prog <= 0.40 then
					weight = 3.0
				elseif prog <= 0.55 then
					weight = 1.2
				end
				table.insert(lSamples, { pos = p, wpIdx = i, laneIdx = lIdx, prog = prog, weight = weight, isConvergence = false })
			end
		end
		if #waypoints > 0 then
			table.insert(lSamples, { pos = waypoints[#waypoints], wpIdx = #waypoints, laneIdx = lIdx, prog = 1.0, weight = 0.2, isConvergence = false })
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
				if s.prog <= 0.38 then
					s.isConvergence = true
					if dOther <= 26 then
						s.weight = s.weight * 2.2
					end
				elseif s.prog <= 0.55 and dOther <= 20 then
					s.isConvergence = true
					s.weight = 3.2
				else
					s.isConvergence = false
					s.weight = 0.35
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
			elseif mode == "anchor" then
				if s.prog >= 0.45 and s.prog <= 0.88 then
					score += s.weight * 1.5
				else
					score += 0.5
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

local function findValidPlacementCFrame(AA, uinfo, mode, targetWpIdx, failedPositions, leakPos, fusionPartnerPos, preferNearHill)
	local reg = AA.getRegistries()
	local pc = reg.CoreServices.PlacementCore.module
	local Util = require(ReplicatedStorage.src.Util)
	local lanesList = getAllLanesWaypoints()
	local waypoints = lanesList[1] or {}
	local totalWps = math.max(1, #waypoints)
	local denseSamples, numLanes = buildDensePathSamples(lanesList)
	local effRange = math.clamp((tonumber(uinfo.range) or 22) * 1.3, 22, 42)
	local candidates = {}

	local hillPositions = {}
	local hillFolder = workspace:FindFirstChild("_terrain") and workspace._terrain:FindFirstChild("hill")
	if hillFolder then
		for _, part in ipairs(hillFolder:GetDescendants()) do
			if part:IsA("BasePart") then
				table.insert(hillPositions, part.Position)
			end
		end
	end

	local startIdx = 1
	local endIdx = math.max(2, math.ceil(totalWps * 0.38))
	if mode == "leak" and targetWpIdx then
		startIdx = math.clamp(targetWpIdx, 2, math.max(2, totalWps - 1))
		endIdx = math.clamp(targetWpIdx + 4, startIdx, totalWps)
	elseif mode == "anchor" then
		startIdx = math.max(2, math.floor(totalWps * 0.25))
		endIdx = math.max(startIdx + 1, math.floor(totalWps * 0.52))
	elseif mode == "farm" then
		startIdx = math.max(2, math.floor(totalWps * 0.35))
		endIdx = math.max(startIdx + 1, math.floor(totalWps * 0.80))
	end

	local function minFrontDistanceAllLanes(pt)
		local best = math.huge
		for _, lWps in ipairs(lanesList) do
			local fEnd = math.max(2, math.ceil(#lWps * 0.35))
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

	if uinfo.hill_unit then
		if hillFolder then
			for _, part in ipairs(hillFolder:GetDescendants()) do
				if part:IsA("BasePart") then
					local sx = math.max(0, (part.Size.X / 2) - 1.3)
					local sz = math.max(0, (part.Size.Z / 2) - 1.3)
					for ox = -sx, sx, 2.3 do
						for oz = -sz, sz, 2.3 do
							local worldPt = (part.CFrame * CFrame.new(ox, 0, oz)).Position
							local cov = scorePlacementCoverage(worldPt, denseSamples, effRange, mode, targetWpIdx, numLanes, leakPos)
							local d = (mode == "leak") and minDistanceToPath(worldPt, waypoints, startIdx, endIdx) or minFrontDistanceAllLanes(worldPt)
							local sortKey = (cov * 10) - (d * 2.4)
							if fusionPartnerPos then
								local distPartner = (Vector3.new(worldPt.X, 0, worldPt.Z) - Vector3.new(fusionPartnerPos.X, 0, fusionPartnerPos.Z)).Magnitude
								if distPartner <= 25 then
									sortKey += (3000 - distPartner * 60)
								else
									sortKey -= distPartner * 40
								end
							end
							table.insert(candidates, { x = worldPt.X, y = part.Position.Y + 40, z = worldPt.Z, sortKey = sortKey })
						end
					end
				end
			end
		end
	else
		local anchorPts = {}
		if fusionPartnerPos then
			table.insert(anchorPts, fusionPartnerPos)
		end
		if mode == "leak" and leakPos then
			table.insert(anchorPts, leakPos)
			for _, lWps in ipairs(lanesList) do
				local idx = getClosestWaypointIndex(leakPos, lWps)
				for k = idx, math.min(#lWps, idx + 3) do
					table.insert(anchorPts, lWps[k])
				end
			end
		elseif mode ~= "farm" then
			for _, lWps in ipairs(lanesList) do
				local fEnd = math.max(2, math.ceil(#lWps * 0.38))
				for i = 1, math.min(#lWps, fEnd) do
					table.insert(anchorPts, lWps[i])
				end
			end
			if numLanes >= 2 then
				for i = 1, #denseSamples, 3 do
					local s = denseSamples[i]
					if s.isConvergence and s.prog <= 0.48 then
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
		for _, wp in ipairs(anchorPts) do
			for rx = -22, 22, 2.5 do
				for rz = -22, 22, 2.5 do
					local gx = math.floor((wp.X + rx) / 2.5 + 0.5) * 2.5
					local gz = math.floor((wp.Z + rz) / 2.5 + 0.5) * 2.5
					local key = tostring(gx) .. ":" .. tostring(gz)
					if not seen[key] then
						seen[key] = true
						local pt = Vector3.new(gx, wp.Y, gz)
						local sortKey = 0
						if mode == "farm" then
							local minD = math.huge
							for _, lWps in ipairs(lanesList) do
								local dl = minDistanceToPath(pt, lWps, 1, #lWps)
								if dl < minD then
									minD = dl
								end
							end
							local cov = scorePlacementCoverage(pt, denseSamples, 18, "front", nil, numLanes, nil)
							sortKey = 80 - math.abs(minD - 15) * 4 - cov * 2
						else
							local cov = scorePlacementCoverage(pt, denseSamples, effRange, mode, targetWpIdx, numLanes, leakPos)
							local d = (mode == "leak") and minDistanceToPath(pt, waypoints, startIdx, endIdx) or minFrontDistanceAllLanes(pt)
							sortKey = (cov * 12) - (d * 2.5)
							if fusionPartnerPos then
								local distPartner = (Vector3.new(pt.X, 0, pt.Z) - Vector3.new(fusionPartnerPos.X, 0, fusionPartnerPos.Z)).Magnitude
								if distPartner <= 24 then
									sortKey += (3000 - distPartner * 60)
								else
									sortKey -= distPartner * 40
								end
							elseif preferNearHill and #hillPositions > 0 then
								local minHillDist = math.huge
								for _, hp in ipairs(hillPositions) do
									local hd = (Vector3.new(pt.X, 0, pt.Z) - Vector3.new(hp.X, 0, hp.Z)).Magnitude
									if hd < minHillDist then
										minHillDist = hd
									end
								end
								if minHillDist <= 22 then
									sortKey += (450 - minHillDist * 16)
								else
									sortKey -= (minHillDist - 22) * 12
								end
							end
						end
						table.insert(candidates, { x = gx, y = wp.Y + 50, z = gz, sortKey = sortKey })
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
		if res and pc.is_valid_raycast_hit(res.Instance, uinfo) and not isTooCloseToPlacedUnits(res.Position, 3.0) and not isNearFailedPosition(res.Position, failedPositions, 3.2) then
			return Util.CFramePLV(res.Position, Vector3.new(0, 0, -1)), res.Position
		end
	end
	return nil, nil
end

local function isFarmUnit(AA, unitId, uinfo)
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
	if uinfo._NO_ATTACKS_UNIT or IDOL_UNITS[unitId] then
		return true
	end
	if (tonumber(uinfo.damage) or 0) <= 0 then
		return true
	end
	return false
end

local function isBlacklistedUnit(AA, unitId, uinfo)
	if BLACKLIST_UNITS[unitId] then
		return true
	end
	if not uinfo then
		return true
	end
	if not isFarmUnit(AA, unitId, uinfo) and not SUPPORT_UNITS[unitId] and not IDOL_UNITS[unitId] then
		if uinfo.show_active_attack or uinfo.attack_cooldown == nil or (tonumber(uinfo.attack_cooldown) and tonumber(uinfo.attack_cooldown) >= 20) then
			return true
		end
	end
	return false
end

local function unitCanTargetAirStatic(AA, unitId, uinfo)
	if not uinfo then
		return false
	end
	if uinfo.hill_unit or uinfo.hybrid_placement or unitId == "vegito" then
		return true
	end
	if uinfo._secondary_damage_types and uinfo._secondary_damage_types.air_damage then
		return true
	end
	local Attacks = AA.loadData("Attacks")
	if Attacks then
		local baseAtk = uinfo.primary_attack_no_upgrades or uinfo.attack
		if baseAtk and Attacks[baseAtk] and Attacks[baseAtk].targets_flying then
			return true
		end
		if uinfo.upgrade then
			for _, upgTbl in ipairs(uinfo.upgrade) do
				local uAtk = upgTbl.primary_attack or upgTbl.attack
				if uAtk and Attacks[uAtk] and Attacks[uAtk].targets_flying then
					return true
				end
			end
		end
	end
	return false
end

local function unitCanTargetAirNow(AA, u, unitId, uinfo)
	if not uinfo then
		return false
	end
	if uinfo.hill_unit or uinfo.hybrid_placement or unitId == "vegito" then
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
		or (col.temporary_units and col.temporary_units[uuid])
		or (col.temporary_owned_units and col.temporary_owned_units[uuid])
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

local function isMainEquippedUnit(AA, uuid, unitId)
	if unitId == "vegito" then
		return true
	end
	if not uuid then
		return false
	end
	local reg = AA.getRegistries()
	local ucsc = reg.ClientServices.UnitCollectionServiceClient and reg.ClientServices.UnitCollectionServiceClient.module
	local col = ucsc and ucsc.session and ucsc.session.collection
	if not col then
		return false
	end
	local cpd = col.collection_profile_data
	if cpd and cpd.equipped_units then
		for _, eqUuid in pairs(cpd.equipped_units) do
			if eqUuid == uuid then
				return true
			end
		end
	end
	if cpd and cpd.owned_units and cpd.owned_units[uuid] then
		return true
	end
	local tempUnit = col.temporary_units and col.temporary_units[uuid]
	if tempUnit then
		if tempUnit.traits then
			for _, t in pairs(tempUnit.traits) do
				if t and t.trait == "unique" then
					return true
				end
			end
		end
		if cpd and cpd.equipped_units and cpd.owned_units then
			for _, eqUuid in pairs(cpd.equipped_units) do
				local eqUnit = cpd.owned_units[eqUuid]
				if eqUnit and eqUnit.unit_id == (unitId or tempUnit.unit_id) then
					if (tempUnit.xp and eqUnit.xp and math.abs(tempUnit.xp - eqUnit.xp) < 1 and math.abs(tempUnit.xp - 2035815.9800258144) > 10)
						or (tempUnit.traits and #tempUnit.traits > 0) then
						return true
					end
				end
			end
		end
	end
	return false
end

local function hasEquippedUnitId(AA, unitId)
	local reg = AA.getRegistries()
	local ucsc = reg.ClientServices.UnitCollectionServiceClient and reg.ClientServices.UnitCollectionServiceClient.module
	local col = ucsc and ucsc.session and ucsc.session.collection
	local cpd = col and col.collection_profile_data
	if cpd and cpd.equipped_units and cpd.owned_units then
		for _, eqUuid in pairs(cpd.equipped_units) do
			local ou = cpd.owned_units[eqUuid]
			if ou and ou.unit_id == unitId then
				local isUniqueEq = false
				if ou.traits then
					for _, t in pairs(ou.traits) do
						if t and t.trait == "unique" then
							isUniqueEq = true
							break
						end
					end
				end
				return true, eqUuid, isUniqueEq
			end
		end
	end
	return false, nil, false
end

local function canSummonMoreMainUnits(AA, placed)
	local cfg = getConfig()
	if cfg.USE_ASTRAL_SUMMON == false then
		return false
	end
	if (placed.byId["vegito"] or 0) >= 1 then
		return false
	end
	local reg = AA.getRegistries()
	local ucsc = reg.ClientServices.UnitCollectionServiceClient and reg.ClientServices.UnitCollectionServiceClient.module
	local col = ucsc and ucsc.session and ucsc.session.collection
	local cpd = col and col.collection_profile_data
	local Units = AA.loadData("Units")
	if not cpd or not cpd.equipped_units or not cpd.owned_units then
		return false
	end
	local hotbarMainById = {}
	for i = 1, 6 do
		local sUuid, sUdata = ucsc.get_unit_in_equipped_slot(tostring(i))
		if sUuid and sUdata and isMainEquippedUnit(AA, sUuid, sUdata.unit_id) then
			hotbarMainById[sUdata.unit_id] = (hotbarMainById[sUdata.unit_id] or 0) + 1
		end
	end
	for _, eqUuid in pairs(cpd.equipped_units) do
		local ou = cpd.owned_units[eqUuid]
		if ou and ou.unit_id and Units[ou.unit_id] then
			local ui = Units[ou.unit_id]
			if (RARITY_SCORE[ui.rarity] or 0) >= 500 and not isFarmUnit(AA, ou.unit_id, ui) and not SUPPORT_UNITS[ou.unit_id] then
				if (placed.byUuid[eqUuid] or 0) < 1 and (placed.mainById[ou.unit_id] or 0) < 1 and (hotbarMainById[ou.unit_id] or 0) < 1 then
					return true
				end
			end
		end
	end
	return false
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
		byId = {},
		byUuid = {},
		mainById = {},
		hillCount = 0,
		airTargetCount = 0,
		anchorCount = 0,
		totalDpsUpgrades = 0,
		totalDamage = 0,
		totalAirDamage = 0,
	}

	for _, u in ipairs(usc.get_all_units_from_player(lp)) do
		if u.Parent == workspace._UNITS and CollectionService:HasTag(u, "nonminion_units") and not CollectionService:HasTag(u, "dying_units") and u:FindFirstChild("_stats") then
			local id = u._stats.id.Value
			local uinfo = Units[id]
			if uinfo and uinfo.rarity then
				local uUuid = u._stats:FindFirstChild("uuid") and u._stats.uuid.Value or nil
				local upg = u._stats.upgrade and u._stats.upgrade.Value or 0
				local liveDmg = u._stats:FindFirstChild("damage") and u._stats.damage.Value or 0
				local unbuffedDmg = (u._stats:FindFirstChild("base_damage") and u._stats.base_damage.Value > 0 and u._stats.base_damage.Value) or liveDmg
				local liveRange = u._stats:FindFirstChild("range") and u._stats.range.Value or 20
				local liveSpa = (u._stats:FindFirstChild("attack_cooldown") and u._stats.attack_cooldown.Value) or tonumber(uinfo.attack_cooldown) or 5
				local hrp = u:FindFirstChild("HumanoidRootPart") or u.PrimaryPart
				local pos = hrp and hrp.Position
				local isMain = isMainEquippedUnit(AA, uUuid, id)
				local traitInfo = getUnitTraitInfo(AA, uUuid)
				local isFarm = isFarmUnit(AA, id, uinfo)
				local isIdol = IDOL_UNITS[id] == true
				local isNonAtk = isNonAttackingUnit(AA, id, uinfo) or liveDmg <= 0
				local isSupport = SUPPORT_UNITS[id] or isIdol or (uinfo and uinfo._show_as_buff_unit) or (isNonAtk and not isFarm)
				local rarityScore = uinfo and RARITY_SCORE[uinfo.rarity] or 100
				if (isMain or traitInfo.isUnique) and not isFarm and not isSupport then
					rarityScore = math.max(rarityScore, 950)
				end
				local canAir = unitCanTargetAirNow(AA, u, id, uinfo)
				local canAirPotential = canAir or unitCanTargetAirStatic(AA, id, uinfo)
				local maxUpg = uinfo and uinfo.upgrade and #uinfo.upgrade or 0
				local wpIdx = (pos and waypoints and #waypoints > 0) and getClosestWaypointIndex(pos, waypoints) or 1
				local unitProg = (waypoints and #waypoints > 0) and (wpIdx / #waypoints) or 0

				local baseAtUpg = (upg > 0 and uinfo.upgrade and uinfo.upgrade[upg] and tonumber(uinfo.upgrade[upg].damage)) or tonumber(uinfo.damage) or 100
				local scaleMult = (baseAtUpg > 0 and unbuffedDmg > 0) and (unbuffedDmg / baseAtUpg) or 1
				local isUniqueUnit = traitInfo.isUnique
				if isUniqueUnit then
					isMain = true
				end
				local maxRawDmg = (maxUpg > 0 and uinfo.upgrade and uinfo.upgrade[maxUpg] and tonumber(uinfo.upgrade[maxUpg].damage)) or baseAtUpg
				local maxSpa = (maxUpg > 0 and uinfo.upgrade and uinfo.upgrade[maxUpg] and tonumber(uinfo.upgrade[maxUpg].attack_cooldown)) or liveSpa
				local currentDps = liveDmg * (6 / math.max(1.2, liveSpa))
				local maxUnbuffedDmg = maxRawDmg * scaleMult
				local maxPotentialDps = maxUnbuffedDmg * (6 / math.max(1.2, maxSpa))
				local valueScore = currentDps + (maxPotentialDps * 0.65) + (isUniqueUnit and 3000000 or 0) + (isMain and 1000000 or 0) + (TIMESTOP_UNITS[id] and 250000 or 0) + (isIdol and 500000 or 0)

				local entry = {
					model = u,
					id = id,
					uuid = uUuid,
					isMainUnit = isMain,
					isUnique = isUniqueUnit,
					traitName = traitInfo.traitName,
					traitMult = traitInfo.traitMult,
					scaleMult = scaleMult,
					upgrade = upg,
					maxUpgrade = maxUpg,
					liveDamage = liveDmg,
					unbuffedDamage = unbuffedDmg,
					maxUnbuffedDamage = maxUnbuffedDmg,
					liveRange = liveRange,
					liveSpa = liveSpa,
					currentDps = currentDps,
					maxPotentialDps = maxPotentialDps,
					valueScore = valueScore,
					pos = pos,
					wpIdx = wpIdx,
					prog = unitProg,
					uinfo = uinfo,
					isFarm = isFarm,
					isIdol = isIdol,
					isSupport = isSupport,
					isNonAttacking = isNonAtk,
					rarityScore = rarityScore,
					canAir = canAir,
					canAirPotential = canAirPotential,
				}
				table.insert(result.all, entry)
				result.byId[id] = (result.byId[id] or 0) + 1
				if uUuid then
					result.byUuid[uUuid] = (result.byUuid[uUuid] or 0) + 1
				end
				if isMain or isUniqueUnit then
					result.mainById[id] = (result.mainById[id] or 0) + 1
				end
				if uinfo and (uinfo.hill_unit or uinfo.hybrid_placement) then
					result.hillCount += 1
				end
				if canAir and not isFarm and not isSupport then
					result.airTargetCount += 1
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
					end
					if unitProg >= 0.54 then
						result.anchorCount += 1
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

local function captureMatchStartSnapshot(lp)
	local stats = lp and lp:FindFirstChild("_stats")
	return {
		startTime = os.time(),
		aprilCoins = stats and stats:FindFirstChild("_resourceAprilCoins") and stats._resourceAprilCoins.Value or 0,
		gems = stats and stats:FindFirstChild("gem_amount") and stats.gem_amount.Value or 0,
		gold = stats and stats:FindFirstChild("gold_amount") and stats.gold_amount.Value or 0,
		xp = stats and stats:FindFirstChild("player_xp") and stats.player_xp.Value or 0,
		mapName = getMatchMapName(),
	}
end

local function recordRoundSummary(AA, state)
	local lp = Players.LocalPlayer
	if not lp then
		return
	end
	task.wait(2.2)
	local snap = state.matchStartSnapshot or captureMatchStartSnapshot(lp)
	local wave = workspace:FindFirstChild("_wave_num") and workspace._wave_num.Value or 0
	local bases = workspace:FindFirstChild("_BASES")
	local baseHum = bases and bases:FindFirstChildWhichIsA("Humanoid", true)
	local won = (wave >= 30) and (baseHum ~= nil and baseHum.Health > 0)
	state.matchStartSnapshot = nil

	local session = loadSessionStats()
	session.sessionStart = math.min(tonumber(session.sessionStart) or os.time(), snap.startTime or os.time())
	session.matches = (session.matches or 0) + 1
	if won then
		session.wins = (session.wins or 0) + 1
	else
		session.losses = (session.losses or 0) + 1
	end
	saveSessionStats(session)
end

local function attachToAnimeAdventures(AA)
	AA.AutoAprilFools = AA.AutoAprilFools or {
		running = false,
		stats = {
			ticks = 0,
			unitsSpawned = 0,
			unitsUpgraded = 0,
			unitsDeleted = 0,
			spellsUsed = 0,
			spellsDeleted = 0,
			roguelikePicked = 0,
			activesUsed = 0,
			replaysVoted = 0,
			leaksHandled = 0,
			lastAction = "idle",
		},
	}

	function AA.stepAprilFools()
		local state = AA.AutoAprilFools
		state.stats.ticks += 1

		if game.PlaceId == LOBBY_PLACE_ID then
			state.stats.lastAction = "lobby_join_april_fools"
			AA.joinAndStartAprilFools(true)
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
		local IngameSpells = AA.loadData("IngameSpells")
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
		elseif (state.matchStartSnapshot.aprilCoins or 0) == 0 and lp._stats:FindFirstChild("_resourceAprilCoins") and lp._stats._resourceAprilCoins.Value > 0 then
			local fresh = captureMatchStartSnapshot(lp)
			fresh.startTime = state.matchStartSnapshot.startTime or fresh.startTime
			state.matchStartSnapshot = fresh
		end

		if dataFolder:FindFirstChild("GameFinished") and dataFolder.GameFinished.Value then
			if not state.summaryRecordedForMatch then
				state.summaryRecordedForMatch = true
				pcall(function()
					if type(writefile) == "function" then
						local debugUnits = {}
						local debugMobs = {}
						if workspace:FindFirstChild("_UNITS") then
							for _, u in ipairs(workspace._UNITS:GetChildren()) do
								if u:FindFirstChild("_stats") and u._stats:FindFirstChild("player") then
									if u._stats.player.Value == lp and u.Name ~= "aot_generic" then
										table.insert(debugUnits, u.Name .. ":upg" .. tostring(u._stats.upgrade.Value) .. ":dmg" .. math.floor(u._stats.damage.Value))
									elseif u._stats.player.Value == nil and u:FindFirstChild("Humanoid") and u.Humanoid.Health > 0 then
										table.insert(debugMobs, u.Name .. ":" .. math.floor(u.Humanoid.Health) .. "/" .. math.floor(u.Humanoid.MaxHealth))
									end
								end
							end
						end
						writefile("aa_last_match_debug.json", HttpService:JSONEncode({
							wave = workspace:FindFirstChild("_wave_num") and workspace._wave_num.Value or -1,
							cash = math.floor(lp._stats.resource.Value),
							units = debugUnits,
							mobs = debugMobs,
							stats = state.stats,
						}))
					end
				end)
				pcall(recordRoundSummary, AA, state)
			end
			local cfg = getConfig()
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
			state.summaryRecordedForMatch = false
			state.lobbyTeleportTries = 0
		end

		local diffFolder = dataFolder:FindFirstChild("Difficulty")
		if diffFolder and diffFolder:FindFirstChild("DifficultyDecided") and not diffFolder.DifficultyDecided.Value then
			pcall(function()
				AA.invokeServer("select_difficulty", "Normal")
			end)
			return "waiting_difficulty"
		end

		local voteStart = dataFolder:FindFirstChild("VoteStart")
		if voteStart and voteStart:FindFirstChild("VotingFinished") and not voteStart.VotingFinished.Value then
			if not voteStart:FindFirstChild("StartTime") or voteStart.StartTime.Value > 0 then
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
			local bestKey = "1"
			local bestScore = -math.huge
			if gui.roguelike_select_ui and gui.roguelike_select_ui.option_frames then
				for k, frame in pairs(gui.roguelike_select_ui.option_frames) do
					local cardScore = 0
					for _, desc in ipairs(frame:GetDescendants()) do
						if desc:IsA("TextLabel") and desc.Visible then
							cardScore += scoreRoguelikeText(desc.Text)
						end
					end
					if cardScore > bestScore then
						bestScore = cardScore
						bestKey = tostring(k)
					end
				end
			end
			AA.invokeServer("select_roguelike_option", bestKey)
			state.stats.roguelikePicked += 1
			state.stats.lastAction = "roguelike_" .. tostring(bestKey)
		end

		local wave = workspace:FindFirstChild("_wave_num") and workspace._wave_num.Value or 0
		local money = lp._stats.resource and lp._stats.resource.Value or 0
		local waypoints = getPathWaypoints()
		local placed = getPlayerPlacedUnits(AA, waypoints)
		local leakThreat = analyzeEnemyThreats(waypoints, placed.dps)

		local soldBlacklisted = false
		for _, entry in ipairs(placed.all) do
			if isBlacklistedUnit(AA, entry.id, entry.uinfo) and not entry.isMainUnit then
				AA.invokeServer("sell_unit_ingame", entry.model)
				state.stats.lastAction = "sold_blacklisted_" .. entry.id
				soldBlacklisted = true
			end
		end
		if soldBlacklisted then
			placed = getPlayerPlacedUnits(AA, waypoints)
			money = lp._stats.resource.Value
			leakThreat = analyzeEnemyThreats(waypoints, placed.dps)
		end

		if wave >= 29 and #placed.farms > 0 then
			for _, f in ipairs(placed.farms) do
				if not (f.uinfo and f.uinfo.unsellable) then
					AA.invokeServer("sell_unit_ingame", f.model)
					state.stats.lastAction = "sold_farm_" .. f.id
				end
			end
			placed = getPlayerPlacedUnits(AA, waypoints)
			money = lp._stats.resource.Value
		end

		if wave >= 12 and #placed.all >= 14 and leakThreat and ((leakThreat.prog >= 0.55 and leakThreat.aheadDpsCount == 0) or (leakThreat.isBoss and leakThreat.prog >= 0.78 and leakThreat.aheadDpsCount < 2)) then
			local lanesList = getAllLanesWaypoints()
			local leakLaneWps = lanesList[leakThreat.laneIdx or 1] or waypoints
			local candidateToSell = nil
			for _, d in ipairs(placed.dps) do
				if not d.isMainUnit and not d.isUnique and not FUSION_PARTNER_UNITS[d.id] and d.pos then
					local canReachRemaining = false
					for k = leakThreat.wpIdx, #leakLaneWps do
						local wp = leakLaneWps[k]
						if (Vector3.new(d.pos.X, 0, d.pos.Z) - Vector3.new(wp.X, 0, wp.Z)).Magnitude <= (d.liveRange + 6) then
							canReachRemaining = true
							break
						end
					end
					if not canReachRemaining then
						if not candidateToSell or (d.valueScore or d.liveDamage) < (candidateToSell.valueScore or candidateToSell.liveDamage) then
							candidateToSell = d
						end
					end
				end
			end
			if candidateToSell then
				AA.invokeServer("sell_unit_ingame", candidateToSell.model)
				state.stats.lastAction = "sold_reposition_" .. candidateToSell.id
				placed = getPlayerPlacedUnits(AA, waypoints)
				money = lp._stats.resource.Value
			end
		end

		local cfg = getConfig()
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
			if activeId and activeId ~= "vegito_fusion" and activeId ~= "himeno:final" then
				local stats = u:FindFirstChild("_stats")
				local isRepositionActive = REPOSITION_ACTIVE_UNITS[entry.id] or activeId == "law_2:shambles" or activeId == "julius:final_clock" or activeId == "lelouch:geass" or activeId == "kira:bite_the_dust"
				local isBuffActive = BUFF_ACTIVE_UNITS[entry.id] or string.find(activeId, "buff") ~= nil or string.find(activeId, "erwin") ~= nil or string.find(activeId, "wendy") ~= nil or activeId == "pucci_heaven:final" or activeId == "kisuke:buff"
				local isTimestopActive = TIMESTOP_UNITS[entry.id] or string.find(activeId, "time") ~= nil or string.find(activeId, "freeze") ~= nil or activeId == "shanks:haki" or activeId == "whitebeard:waves"
				if isRepositionActive or isBuffActive or isTimestopActive then
					if stats and stats:FindFirstChild("_auto_active") and stats._auto_active.Value == true then
						stats._auto_active.Value = false
					end
					if u:GetAttribute("_auto_active") == true then
						pcall(function()
							u:SetAttribute("_auto_active", false)
						end)
					end
				end

				local cd = stats and stats:FindFirstChild("active_attack_cooldown") and stats.active_attack_cooldown.Value or 0
				local lastCast = stats and stats:FindFirstChild("last_active_cast") and stats.last_active_cast.Value or 0
				if (cd - (tick() - lastCast)) <= 0 then
					local allowCast = true
					local customPayload = nil

					if activeId == "vegito_fusion_vegeta" then
						local hasGokuReadyOnMap = false
						for _, other in ipairs(placed.dps) do
							if FUSION_PARTNER_UNITS[other.id] and (other.upgrade or 0) >= 7 then
								hasGokuReadyOnMap = true
								break
							end
						end
						if not hasGokuReadyOnMap then
							allowCast = false
						else
							local hasMainVegetaEquipped = hasEquippedUnitId(AA, entry.id)
							if hasMainVegetaEquipped and not entry.isMainUnit and not entry.isUnique then
								allowCast = false
							else
								for _, other in ipairs(placed.dps) do
									if other.model ~= entry.model and other.id == entry.id and (other.maxPotentialDps or 0) > (entry.maxPotentialDps or 0) * 1.15 then
										allowCast = false
										break
									end
								end
							end
						end
					elseif isRepositionActive then
						allowCast = false
						if entry.pos and entry.liveRange > 0 then
							local entryProg = (entry.wpIdx or 1) / totalWpsCount
							local mobsInRange = 0
							local hasExitingMob = false
							local maxLeadRatio = 0
							for _, mob in ipairs(activeMobs) do
								if activeId ~= "julius:final_clock" or not mob.isBoss then
									local dist2D = (Vector3.new(entry.pos.X, 0, entry.pos.Z) - Vector3.new(mob.pos.X, 0, mob.pos.Z)).Magnitude
									if dist2D <= entry.liveRange then
										mobsInRange += 1
										if mob.prog >= entryProg then
											local exitRatio = dist2D / math.max(1, entry.liveRange)
											if exitRatio > maxLeadRatio then
												maxLeadRatio = exitRatio
											end
											if exitRatio >= 0.62 or mob.prog >= 0.78 then
												hasExitingMob = true
											end
										end
									end
								end
							end
							if hasExitingMob or (mobsInRange >= 3 and maxLeadRatio >= 0.45) then
								allowCast = true
							end
						end
					elseif isBuffActive and cfg.STAGGER_BUFF_ACTIVES ~= false then
						local isMagicBuff = (entry.id == "wendy" or entry.id == "wendy_evolved" or entry.id == "leafa" or entry.id == "leafa_evolved" or activeId == "wendy:buff_units" or activeId == "leafa:buff")
						local isPhysBuff = (entry.id == "erwin" or entry.id == "erwin_halloween" or entry.id == "erwin_school" or activeId == "erwin:buff_units")
						if isMagicBuff then
							if (tick() - (state.lastMagicBuffCast or 0)) < 15.2 then
								allowCast = false
							end
						elseif isPhysBuff then
							if (tick() - (state.lastPhysBuffCast or 0)) < 15.2 then
								allowCast = false
							end
						else
							if (tick() - (state.lastBuffActiveCast or 0)) < 15.2 then
								allowCast = false
							end
						end
					elseif isTimestopActive and cfg.SMART_TIMESTOP ~= false then
						if not hasEnemyInDpsRange or (tick() - (state.lastTimestopCast or 0)) < 9.5 then
							allowCast = false
						elseif entry.pos and entry.liveRange > 0 and activeId ~= "dio_heaven:timestop" and activeId ~= "kc:time_erase" then
							local anyInUnitRange = false
							for _, mob in ipairs(activeMobs) do
								local dist2D = (Vector3.new(entry.pos.X, 0, entry.pos.Z) - Vector3.new(mob.pos.X, 0, mob.pos.Z)).Magnitude
								if dist2D <= (entry.liveRange + 2) then
									anyInUnitRange = true
									break
								end
							end
							if not anyInUnitRange then
								allowCast = false
							end
						end
					elseif activeId == "death_note_active" then
						allowCast = false
						local bestTarget = nil
						local bestScore = 0
						for _, mob in ipairs(activeMobs) do
							if not mob.isBoss and mob.prog >= 0.40 then
								local score = mob.hp * (0.5 + mob.prog)
								if score > bestScore then
									bestScore = score
									bestTarget = mob.model
								end
							end
						end
						if bestTarget then
							allowCast = true
							customPayload = { death_note_active_target = bestTarget }
						end
					elseif activeId == "aizen:illusion" then
						if not leakThreat or leakThreat.prog < 0.70 then
							allowCast = false
						end
					end

					if allowCast then
						pcall(function()
							if customPayload then
								AA.invokeServer("use_active_attack", u, customPayload)
							else
								AA.invokeServer("use_active_attack", u)
							end
							state.stats.activesUsed += 1
							if isBuffActive then
								state.lastBuffActiveCast = tick()
								if entry.id == "wendy" or entry.id == "wendy_evolved" or entry.id == "leafa" or entry.id == "leafa_evolved" or activeId == "wendy:buff_units" or activeId == "leafa:buff" then
									state.lastMagicBuffCast = tick()
								elseif entry.id == "erwin" or entry.id == "erwin_halloween" or entry.id == "erwin_school" or activeId == "erwin:buff_units" then
									state.lastPhysBuffCast = tick()
								end
							elseif isTimestopActive then
								state.lastTimestopCast = tick()
							elseif isRepositionActive then
								state.stats.lastAction = "reposition_active_" .. entry.id
							elseif activeId == "vegito_fusion_vegeta" then
								state.stats.lastAction = "fused_vegito"
							end
						end)
					end
				end
			end
		end

		local spawnMult = usc.calculate_spawn_cost_multiplier(ucsc.session)

		local airTargetGoal = (wave <= 8 and (wave * 3500)) or (wave <= 14 and (wave * 8000)) or (wave * 16500)
		local needMoreAirDps = (placed.totalAirDamage < airTargetGoal) or (wave >= 14 and placed.totalAirDamage < placed.totalDamage * 0.35)
		local bestDpsTarget = nil
		local bestDpsTargetScore = -1
		local bestMergeTarget = nil
		local bestMergeTargetScore = -1
		for _, d in ipairs(placed.dps) do
			if not d.isFarm and not d.isSupport and not d.isNonAttacking and (d.liveDamage >= 3000 or d.isMainUnit or d.isUnique) and d.rarityScore >= 500 then
				local dScore = d.liveDamage
					+ (d.maxPotentialDps or 0) * 0.65
					+ (d.isUnique and 3500000 or 0)
					+ (d.isMainUnit and 1200000 or 0)
					+ d.rarityScore * 15
					+ d.upgrade * 500
					+ ((needMoreAirDps and d.canAir) and 450000 or 0)
				if leakThreat and d.pos then
					local dist = (Vector3.new(d.pos.X, 0, d.pos.Z) - Vector3.new(leakThreat.pos.X, 0, leakThreat.pos.Z)).Magnitude
					if dist <= (d.liveRange + 5) then
						dScore += 500000
					end
				end
				if dScore > bestDpsTargetScore then
					bestDpsTargetScore = dScore
					bestDpsTarget = d
				end
				if (placed.byId[d.id] or 0) >= 2 and d.pos then
					for _, other in ipairs(placed.dps) do
						if other.model ~= d.model and other.id == d.id and other.pos then
							local dist = (Vector3.new(d.pos.X, 0, d.pos.Z) - Vector3.new(other.pos.X, 0, other.pos.Z)).Magnitude
							if dist <= d.liveRange then
								local mScore = (d.isUnique and 5000000 or 0) + (d.isMainUnit and 1500000 or 0) + (d.maxPotentialDps or 0) + d.liveDamage
								if mScore > bestMergeTargetScore then
									bestMergeTargetScore = mScore
									bestMergeTarget = d
								end
							end
						end
					end
				end
			end
		end

		local maxDpsForWave = 3
		if wave >= 21 then
			maxDpsForWave = 10
		elseif wave >= 16 then
			maxDpsForWave = 8
		elseif wave >= 11 then
			maxDpsForWave = 6
		elseif wave >= 6 then
			maxDpsForWave = 5
		end
		if leakThreat and leakThreat.aheadDpsCount == 0 then
			maxDpsForWave = math.min(11, math.max(maxDpsForWave, #placed.dps + 1))
		end

		local hasHighTierInHotbar = false
		local hasAnyAttackingInHotbar = false
		local savingForSpellCost = 0
		local needMoreMainUnits = canSummonMoreMainUnits(AA, placed)
		local gateSaveReady = (not leakThreat or leakThreat.aheadDpsCount > 0) and wave >= 7 and #placed.dps >= 2 and placed.totalAirDamage >= math.max(20000, wave * 3000)
		local summonSaveReady = (not leakThreat or leakThreat.aheadDpsCount > 0) and wave >= 10 and #placed.dps >= 3 and placed.totalAirDamage >= math.max(35000, wave * 3800)
		for i = 1, 6 do
			local slot = tostring(i)
			local spellId = ucsc.session.ingame_spells and ucsc.session.ingame_spells[slot]
			if spellId and needMoreMainUnits then
				local sinfo = IngameSpells and IngameSpells[spellId]
				local scost = sinfo and sinfo.cost or 0
				if (spellId == "gate" and gateSaveReady) or (spellId == "summon" and summonSaveReady) then
					savingForSpellCost = math.max(savingForSpellCost, scost)
				end
			end
			local uuid, udata = ucsc.get_unit_in_equipped_slot(slot)
			if udata and Units[udata.unit_id] then
				local ui = Units[udata.unit_id]
				if not isNonAttackingUnit(AA, udata.unit_id, ui) and not isBlacklistedUnit(AA, udata.unit_id, ui) then
					hasAnyAttackingInHotbar = true
					if (RARITY_SCORE[ui.rarity] or 0) >= 500 or isMainEquippedUnit(AA, uuid, udata.unit_id) then
						hasHighTierInHotbar = true
					end
				end
			end
		end

		for i = 1, 6 do
			local slot = tostring(i)
			local spellId = ucsc.session.ingame_spells and ucsc.session.ingame_spells[slot]
			if spellId then
				local sinfo = IngameSpells and IngameSpells[spellId]
				local scost = sinfo and sinfo.cost or 0
				if spellId == "sell_refund" or spellId == "ritual" then
					AA.invokeServer("delete_ingame_spell", slot)
					state.stats.spellsDeleted += 1
					state.stats.lastAction = "del_spell_" .. spellId
				elseif spellId == "sacrifice" then
					if #placed.all >= 13 and bestMergeTarget and money >= scost and (savingForSpellCost == 0 or (money - scost) >= savingForSpellCost) then
						AA.invokeServer("use_ingame_spell", slot, bestMergeTarget.model)
						state.stats.spellsUsed += 1
						state.stats.lastAction = "use_spell_merge_" .. bestMergeTarget.id
						money = lp._stats.resource.Value
					else
						AA.invokeServer("delete_ingame_spell", slot)
						state.stats.spellsDeleted += 1
						state.stats.lastAction = "del_spell_sacrifice"
					end
				elseif spellId == "gate" then
					if not needMoreMainUnits then
						AA.invokeServer("delete_ingame_spell", slot)
						state.stats.spellsDeleted += 1
						state.stats.lastAction = "del_spell_gate_capped"
					elseif money >= scost and (#placed.dps >= 1 or not hasAnyAttackingInHotbar) then
						AA.invokeServer("use_ingame_spell", slot)
						state.stats.spellsUsed += 1
						state.stats.lastAction = "use_spell_gate"
						money = lp._stats.resource.Value
					end
				elseif spellId == "summon" then
					if not needMoreMainUnits then
						AA.invokeServer("delete_ingame_spell", slot)
						state.stats.spellsDeleted += 1
						state.stats.lastAction = "del_spell_summon_capped"
					elseif money >= scost and (#placed.dps >= 1 or not hasAnyAttackingInHotbar) then
						AA.invokeServer("use_ingame_spell", slot)
						state.stats.spellsUsed += 1
						state.stats.lastAction = "use_spell_summon"
						money = lp._stats.resource.Value
					elseif #placed.dps == 0 and not hasAnyAttackingInHotbar and money < scost then
						AA.invokeServer("delete_ingame_spell", slot)
						state.stats.spellsDeleted += 1
						state.stats.lastAction = "del_spell_deadlock_summon"
					end
				elseif spellId == "random_buff" then
					if bestDpsTarget and (bestDpsTarget.liveDamage >= 5000 or bestDpsTarget.isMainUnit) and money >= scost and (savingForSpellCost == 0 or (money - scost) >= savingForSpellCost) then
						AA.invokeServer("use_ingame_spell", slot, bestDpsTarget.model)
						state.stats.spellsUsed += 1
						state.stats.lastAction = "use_spell_buff_" .. bestDpsTarget.id
						money = lp._stats.resource.Value
					elseif #placed.dps == 0 and not hasAnyAttackingInHotbar then
						AA.invokeServer("delete_ingame_spell", slot)
						state.stats.spellsDeleted += 1
						state.stats.lastAction = "del_spell_deadlock_buff"
					end
				elseif spellId == "clone" then
					if bestDpsTarget and (bestDpsTarget.upgrade >= 3 or bestDpsTarget.liveDamage >= 25000 or bestDpsTarget.isMainUnit) and money >= scost and (savingForSpellCost == 0 or (money - scost) >= savingForSpellCost) then
						AA.invokeServer("use_ingame_spell", slot, bestDpsTarget.model)
						state.stats.spellsUsed += 1
						state.stats.lastAction = "use_spell_clone_" .. bestDpsTarget.id
						money = lp._stats.resource.Value
					elseif (wave <= 4 and #placed.dps < 2) or (#placed.dps == 0 and not hasAnyAttackingInHotbar) then
						AA.invokeServer("delete_ingame_spell", slot)
						state.stats.spellsDeleted += 1
					end
				end
			else
				local uuid, udata = ucsc.get_unit_in_equipped_slot(slot)
				if uuid and udata then
					local unitId = udata.unit_id
					local uinfo = Units[unitId]
					if uinfo then
						local isMain = isMainEquippedUnit(AA, uuid, unitId)
						local traitInfo = getUnitTraitInfo(AA, uuid)
						local isUniqueHotbar = traitInfo.isUnique
						if isUniqueHotbar then
							isMain = true
						end
						local hasEquippedSameId, _, eqIsUnique = hasEquippedUnitId(AA, unitId)
						local isNonUniqueCopyOfEquippedUnique = hasEquippedSameId and eqIsUnique and not isMain and not isUniqueHotbar

						local isFarm = isFarmUnit(AA, unitId, uinfo)
						local isIdol = IDOL_UNITS[unitId] == true
						local isNonAtk = isNonAttackingUnit(AA, unitId, uinfo)
						local isSupport = SUPPORT_UNITS[unitId] or isIdol or (isNonAtk and not isFarm)
						local rarityScore = RARITY_SCORE[uinfo.rarity] or 100
						if (isMain or isUniqueHotbar) and not isFarm and not isSupport then
							rarityScore = math.max(rarityScore, 950)
						end
						local spawnCost = math.ceil((tonumber(uinfo.cost) or 500) * spawnMult)
						local currentSameCount = placed.byId[unitId] or 0
						local currentMainSameCount = placed.mainById[unitId] or 0
						local unitCap = (isUniqueHotbar or eqIsUnique) and 1 or (tonumber(uinfo.spawn_cap) or 4)

						local placedTimestopCount = 0
						for tsId, _ in pairs(TIMESTOP_UNITS) do
							placedTimestopCount += (placed.byId[tsId] or 0)
						end
						local isPriorityKeep = (not isNonUniqueCopyOfEquippedUnique)
							and (
								((isMain or isUniqueHotbar) and currentMainSameCount < unitCap)
								or (FUSION_PARTNER_UNITS[unitId] and currentSameCount == 0 and (placed.byId["vegito"] or 0) == 0)
								or (TIMESTOP_UNITS[unitId] and placedTimestopCount == 0)
							)
						local shouldDelete = false
						local shouldSpawn = false
						local placementMode = TRAP_UNITS[unitId] and "anchor" or "front"
						local targetWp = nil

						if isNonUniqueCopyOfEquippedUnique then
							shouldDelete = true
						elseif isBlacklistedUnit(AA, unitId, uinfo) and not isMain and not isUniqueHotbar then
							shouldDelete = true
						elseif (isMain or isUniqueHotbar) and currentMainSameCount >= unitCap then
							shouldDelete = true
						elseif isPriorityKeep and not isFarm and not isSupport then
							if (isMain or isUniqueHotbar) and currentSameCount >= unitCap and money >= spawnCost then
								for _, d in ipairs(placed.dps) do
									if d.id == unitId and not d.isMainUnit and not d.isUnique then
										AA.invokeServer("sell_unit_ingame", d.model)
										state.stats.unitsSold = (state.stats.unitsSold or 0) + 1
										placed = getPlayerPlacedUnits(AA, waypoints)
										currentSameCount = placed.byId[unitId] or 0
										break
									end
								end
							end
							if currentSameCount < unitCap then
								shouldSpawn = true
								if leakThreat and leakThreat.prog >= 0.72 and leakThreat.aheadDpsCount == 0 then
									placementMode = "leak"
									targetWp = leakThreat.wpIdx
								else
									placementMode = "front"
								end
								if #placed.all >= 14 and money >= spawnCost then
									if #placed.farms > 0 then
										AA.invokeServer("sell_unit_ingame", placed.farms[1].model)
										state.stats.unitsSold = (state.stats.unitsSold or 0) + 1
									else
										local weakest = nil
										for _, d in ipairs(placed.dps) do
											if not d.isMainUnit and not d.isUnique and not FUSION_PARTNER_UNITS[d.id] and not TIMESTOP_UNITS[d.id] and (not weakest or (d.valueScore or d.liveDamage) < (weakest.valueScore or weakest.liveDamage)) then
												weakest = d
											end
										end
										if weakest then
											AA.invokeServer("sell_unit_ingame", weakest.model)
											state.stats.unitsSold = (state.stats.unitsSold or 0) + 1
										end
									end
									placed = getPlayerPlacedUnits(AA, waypoints)
								end
							end
						elseif isFarm then
							if wave >= 17 or #placed.farms >= 3 or currentSameCount >= unitCap or (leakThreat and wave >= 10) then
								shouldDelete = true
							elseif (#placed.dps >= 1 or (not hasAnyAttackingInHotbar and #placed.farms == 0)) and not leakThreat then
								shouldSpawn = true
								placementMode = "farm"
							end
						elseif isIdol then
							local hasAnyIdolPlaced = (placed.byId["hoshino"] or 0) + (placed.byId["hoshino_evolved"] or 0) + (placed.byId["hoshino_2"] or 0) + (placed.byId["hoshino_2_evolved"] or 0) > 0
							if hasAnyIdolPlaced or wave >= 22 or leakThreat then
								shouldDelete = true
							elseif #placed.dps >= 2 then
								shouldSpawn = true
								placementMode = "farm"
							end
						elseif isSupport then
							if currentSameCount >= 1 or #placed.supports >= 2 or leakThreat or wave < 8 then
								shouldDelete = true
							elseif #placed.dps >= 4 then
								shouldSpawn = true
								placementMode = "front"
							else
								shouldDelete = true
							end
						else
							local isAirUnit = unitCanTargetAirStatic(AA, unitId, uinfo)
							local maxRandomCopies = (isAirUnit and placed.airTargetCount < 2 and wave <= 6) and 2 or 1
							if currentSameCount >= unitCap or (not isMain and not isUniqueHotbar and currentSameCount >= maxRandomCopies) then
								shouldDelete = true
							elseif leakThreat and leakThreat.prog >= 0.72 and leakThreat.aheadDpsCount == 0 and (rarityScore >= 500 or (rarityScore >= 300 and wave <= 8)) and (not leakThreat.isFlying or isAirUnit) then
								shouldSpawn = true
								placementMode = "leak"
								targetWp = leakThreat.wpIdx
							elseif rarityScore < 500 then
								if (#placed.dps == 0 and not hasHighTierInHotbar and wave <= 4) or (isAirUnit and placed.airTargetCount < 2 and wave <= 8) then
									shouldSpawn = true
									placementMode = "front"
								else
									shouldDelete = true
								end
							else
								if #placed.dps >= maxDpsForWave or #placed.all >= 14 then
									if wave >= 7 and money >= spawnCost then
										for _, d in ipairs(placed.dps) do
											local isLowDuplicate = (placed.byId[d.id] or 0) >= 2 and d.upgrade <= 2
											if (d.rarityScore < 500 or isLowDuplicate) and not d.isMainUnit and not d.isUnique and (not d.canAir or placed.airTargetCount >= 3 or isAirUnit) then
												AA.invokeServer("sell_unit_ingame", d.model)
												state.stats.unitsSold = (state.stats.unitsSold or 0) + 1
												placed = getPlayerPlacedUnits(AA, waypoints)
												break
											end
										end
									end
								end
								if #placed.dps < maxDpsForWave or (isAirUnit and placed.airTargetCount < 3 and #placed.dps < maxDpsForWave + 1) then
									shouldSpawn = true
									placementMode = TRAP_UNITS[unitId] and "anchor" or "front"
								else
									shouldDelete = true
								end
							end
						end

						if savingForSpellCost > 0 and not isPriorityKeep and (not leakThreat or leakThreat.aheadDpsCount > 0) and (money - spawnCost) < savingForSpellCost then
							shouldSpawn = false
							if #placed.dps >= 4 and not isFarm and not isIdol then
								shouldDelete = true
							end
						end

						if #placed.all >= 15 and not isPriorityKeep then
							shouldSpawn = false
							shouldDelete = true
						end

						state.failedPositions = state.failedPositions or {}
						state.unitFailCounts = state.unitFailCounts or {}
						if wave <= 1 and #state.failedPositions > 0 then
							state.failedPositions = {}
							state.unitFailCounts = {}
						end

						if shouldDelete and not isPriorityKeep then
							AA.invokeServer("delete_ingame_temporary_unit", slot)
							state.stats.unitsDeleted += 1
							state.stats.lastAction = "del_unit_" .. unitId
						elseif shouldSpawn and money >= spawnCost and not ucsc.session.collection:is_unit_on_cooldown(uuid) then
							local fusionPartnerPos = nil
							local preferNearHill = false
							if unitId == "goku_ssj3_evolved" or unitId == "goku_ssj3" then
								for _, d in ipairs(placed.dps) do
									if (d.id == "vegeta_majin_evolved" or d.id == "vegeta_majin") and d.pos then
										if not fusionPartnerPos or d.isUnique or d.isMainUnit then
											fusionPartnerPos = d.pos
										end
									end
								end
							elseif unitId == "vegeta_majin_evolved" or unitId == "vegeta_majin" then
								preferNearHill = true
								for _, d in ipairs(placed.dps) do
									if (d.id == "goku_ssj3_evolved" or d.id == "goku_ssj3") and d.pos then
										fusionPartnerPos = d.pos
										break
									end
								end
							end

							local cf, hitPos = findValidPlacementCFrame(AA, uinfo, placementMode, targetWp, state.failedPositions, leakThreat and leakThreat.pos, fusionPartnerPos, preferNearHill)
							if cf and hitPos then
								local prevCount = #placed.all
								local prevMoney = money
								AA.invokeServer("spawn_unit", uuid, cf)
								local newPlaced = getPlayerPlacedUnits(AA, waypoints)
								local newMoney = lp._stats.resource.Value
								if #newPlaced.all > prevCount or newMoney < (prevMoney - 50) then
									state.unitFailCounts[uuid] = 0
									state.stats.unitsSpawned += 1
									if placementMode == "leak" then
										state.stats.leaksHandled = (state.stats.leaksHandled or 0) + 1
										state.stats.lastAction = "spawn_leak_" .. unitId
									else
										state.stats.lastAction = "spawn_" .. unitId
									end
									placed = newPlaced
									money = newMoney
									leakThreat = analyzeEnemyThreats(waypoints, placed.dps)
								else
									table.insert(state.failedPositions, hitPos)
									state.unitFailCounts[uuid] = (state.unitFailCounts[uuid] or 0) + 1
									state.stats.lastAction = "place_retry_" .. unitId .. "_" .. tostring(state.unitFailCounts[uuid])
									if state.unitFailCounts[uuid] >= 4 and not isPriorityKeep then
										AA.invokeServer("delete_ingame_temporary_unit", slot)
										state.stats.unitsDeleted += 1
										state.unitFailCounts[uuid] = 0
										state.stats.lastAction = "del_unplaceable_" .. unitId
									end
								end
							elseif not isPriorityKeep then
								AA.invokeServer("delete_ingame_temporary_unit", slot)
								state.stats.unitsDeleted += 1
								state.stats.lastAction = "del_nospot_" .. unitId
							end
						end
					end
				end
			end
		end

		placed = getPlayerPlacedUnits(AA, waypoints)
		money = lp._stats.resource.Value
		leakThreat = analyzeEnemyThreats(waypoints, placed.dps)

		if placed.airTargetCount >= 1 then
			for _, d in ipairs(placed.dps) do
				if d.canAir and d.model:FindFirstChild("_stats") and d.model._stats:FindFirstChild("priority") then
					if d.model._stats.priority.Value ~= "flying" and (placed.airTargetCount >= 2 or wave >= 4) then
						AA.invokeServer("change_priority", d.model, "flying")
						break
					end
				end
			end
		end

		local isBossPrepWave = BOSS_PREP_WAVES[wave] or (leakThreat ~= nil)
		local basicFarmDefenseReady = (#placed.dps >= 2 and placed.totalDamage >= math.max(3500, wave * 2000)) or (placed.totalDpsUpgrades >= math.max(2, math.floor(wave * 0.75)))
		local earlyDefenseReady = (#placed.dps >= 2 and placed.totalDamage >= math.max(5000, wave * 2800)) or (placed.totalDpsUpgrades >= math.max(2, math.floor(wave * 0.9)))
		local gateReserveReady = (not leakThreat or leakThreat.aheadDpsCount > 0) and wave >= 7 and #placed.dps >= 2 and placed.totalAirDamage >= math.max(20000, wave * 3000)
		local summonReserveReady = (not leakThreat or leakThreat.aheadDpsCount > 0) and wave >= 10 and #placed.dps >= 3 and placed.totalAirDamage >= math.max(35000, wave * 3800)
		local spellSaveDefenseReady = (not leakThreat or leakThreat.aheadDpsCount > 0) and #placed.dps >= 2 and placed.totalDamage >= math.max(6000, wave * 2400)

		local reservedMoney = 0
		local needMoreMainsNow = canSummonMoreMainUnits(AA, placed)
		if (not leakThreat or leakThreat.aheadDpsCount > 0) and #placed.dps >= 1 then
			for i = 1, 6 do
				local slot = tostring(i)
				local spellId = ucsc.session.ingame_spells and ucsc.session.ingame_spells[slot]
				if spellId then
					local sinfo = IngameSpells and IngameSpells[spellId]
					local scost = sinfo and sinfo.cost or 0
					if spellId == "gate" and gateReserveReady and needMoreMainsNow then
						reservedMoney = math.max(reservedMoney, scost)
					elseif spellId == "summon" and summonReserveReady and needMoreMainsNow then
						reservedMoney = math.max(reservedMoney, scost)
					elseif spellId == "random_buff" and bestDpsTarget and (bestDpsTarget.liveDamage >= 5000 or bestDpsTarget.isMainUnit) and earlyDefenseReady then
						reservedMoney = math.max(reservedMoney, scost)
					elseif spellId == "clone" and bestDpsTarget and (bestDpsTarget.upgrade >= 3 or bestDpsTarget.liveDamage >= 25000 or bestDpsTarget.isMainUnit) and spellSaveDefenseReady then
						reservedMoney = math.max(reservedMoney, scost)
					end
				else
					local uuid, udata = ucsc.get_unit_in_equipped_slot(slot)
					if uuid and udata and (isMainEquippedUnit(AA, uuid, udata.unit_id) or FUSION_PARTNER_UNITS[udata.unit_id]) then
						local uinfo = Units[udata.unit_id]
						if uinfo then
							local _, _, eqIsUnique = hasEquippedUnitId(AA, udata.unit_id)
							local unitCap = (FUSION_PARTNER_UNITS[udata.unit_id] or eqIsUnique) and 1 or (tonumber(uinfo.spawn_cap) or 4)
							if (placed.mainById[udata.unit_id] or 0) < unitCap then
								local spawnCost = math.ceil((tonumber(uinfo.cost) or 500) * spawnMult)
								reservedMoney = math.max(reservedMoney, spawnCost)
							end
						end
					end
				end
			end
		end

		local bestMainCarryAnyUpg = nil
		local bestMainAnyScore = -1
		local primaryMainCarry = nil
		local primaryMainScore = -1
		local primaryAirCarry = nil
		local primaryAirScore = -1
		local primaryGroundCarry = nil
		local primaryGroundScore = -1
		local primaryAnchorCarry = nil
		local primaryAnchorScore = -1
		for _, d in ipairs(placed.dps) do
			if d.isMainUnit or d.isUnique then
				local anyScore = (d.isUnique and 10000000 or 0) + (d.isMainUnit and 3000000 or 0) + (d.maxPotentialDps or 0) + d.liveDamage
				if anyScore > bestMainAnyScore then
					bestMainAnyScore = anyScore
					bestMainCarryAnyUpg = d
				end
			end
			if d.upgrade < d.maxUpgrade then
				if d.isMainUnit or d.isUnique then
					local mScore = (d.isUnique and 10000000 or 0)
						+ (d.isMainUnit and 3000000 or 0)
						+ (d.maxPotentialDps or 0)
						+ d.liveDamage
						+ d.upgrade * 25000
					if mScore > primaryMainScore then
						primaryMainScore = mScore
						primaryMainCarry = d
					end
				end
			end
		end
		for _, d in ipairs(placed.dps) do
			if d.upgrade < d.maxUpgrade and d.canAir then
				local score = (d.isUnique and 5000000 or 0)
					+ (d.isMainUnit and 1500000 or 0)
					+ (d.maxPotentialDps or 0) * 0.75
					+ d.liveDamage * 0.5
					+ d.rarityScore * 25
					+ d.upgrade * 1000
				if score > primaryAirScore then
					primaryAirScore = score
					primaryAirCarry = d
				end
			end
		end
		for _, d in ipairs(placed.dps) do
			if d.upgrade < d.maxUpgrade and d.rarityScore >= 500 then
				local isAlreadySelected = (primaryMainCarry and d.model == primaryMainCarry.model)
					or (primaryAirCarry and d.model == primaryAirCarry.model)
				if not isAlreadySelected then
					local score = (d.isUnique and 5000000 or 0)
						+ (d.isMainUnit and 1500000 or 0)
						+ (d.maxPotentialDps or 0) * 0.75
						+ d.liveDamage * 0.5
						+ d.rarityScore * 25
						+ d.upgrade * 1000
					if score > primaryGroundScore then
						primaryGroundScore = score
						primaryGroundCarry = d
					end
				end
			end
		end
		for _, d in ipairs(placed.dps) do
			if d.upgrade < d.maxUpgrade and d.rarityScore >= 500 and (d.prog or 0) >= 0.52 then
				local isAlreadySelected = (primaryMainCarry and d.model == primaryMainCarry.model)
					or (primaryAirCarry and d.model == primaryAirCarry.model)
					or (primaryGroundCarry and d.model == primaryGroundCarry.model)
				if not isAlreadySelected then
					local score = (d.isUnique and 5000000 or 0)
						+ (d.isMainUnit and 1500000 or 0)
						+ (d.maxPotentialDps or 0) * 0.75
						+ d.liveDamage * 0.5
						+ d.rarityScore * 25
						+ d.upgrade * 1000
					if score > primaryAnchorScore then
						primaryAnchorScore = score
						primaryAnchorCarry = d
					end
				end
			end
		end

		local airDamageTarget = (wave <= 8 and (wave * 3500)) or (wave <= 14 and (wave * 8000)) or (wave * 16500)
		local needMoreAirNow = (placed.totalAirDamage < airDamageTarget) or (wave >= 14 and placed.totalAirDamage < placed.totalDamage * 0.35)
		local hasGokuForFusion = (placed.byId["goku_ssj3_evolved"] or 0) > 0 or (placed.byId["goku_ssj3"] or 0) > 0
		local upgradeQueue = {}
		for _, entry in ipairs(placed.all) do
			local nextCost = getNextUpgradeCost(AA, entry)
			if nextCost then
				local priority = 0

				local refMain = primaryMainCarry or bestMainCarryAnyUpg
				local isInferiorDuplicateOfMain = refMain
					and entry.id == refMain.id
					and entry.model ~= refMain.model
					and not entry.isUnique
					and (entry.maxPotentialDps or 0) < (refMain.maxPotentialDps or 0) * 0.85

				local leakPriorityBoost = 0
				if leakThreat and not entry.isFarm and not entry.isSupport and entry.pos and (not leakThreat.isFlying or entry.canAir) then
					local dist = (Vector3.new(entry.pos.X, 0, entry.pos.Z) - Vector3.new(leakThreat.pos.X, 0, leakThreat.pos.Z)).Magnitude
					if dist <= (entry.liveRange + 6) then
						if (entry.wpIdx or 1) >= (leakThreat.wpIdx - 2) then
							leakPriorityBoost = 1580 + math.min(350, entry.liveDamage / 250)
						else
							leakPriorityBoost = 1360 + math.min(250, entry.liveDamage / 350)
						end
					elseif (entry.wpIdx or 1) >= leakThreat.wpIdx and #waypoints > 0 then
						for k = leakThreat.wpIdx, math.min(#waypoints, leakThreat.wpIdx + 6) do
							local wp = waypoints[k]
							if (Vector3.new(entry.pos.X, 0, entry.pos.Z) - Vector3.new(wp.X, 0, wp.Z)).Magnitude <= (entry.liveRange + 6) then
								leakPriorityBoost = 1480 + math.min(300, entry.liveDamage / 250)
								break
							end
						end
					end
				end

				if leakPriorityBoost > 0 then
					if primaryMainCarry and entry.model == primaryMainCarry.model then
						priority = 1850 - entry.upgrade * 4
					else
						priority = leakPriorityBoost
					end
				elseif isInferiorDuplicateOfMain then
					priority = 0
				elseif FUSION_PARTNER_UNITS[entry.id] and entry.upgrade < 7 and bestMainCarryAnyUpg and bestMainCarryAnyUpg.upgrade >= 7 then
					priority = 1265 - entry.upgrade * 4
				elseif primaryMainCarry and entry.model == primaryMainCarry.model and ((entry.isUnique and entry.upgrade < 3 and nextCost <= 6000) or (entry.isUnique and placed.totalAirDamage >= math.max(35000, wave * 3800)) or (entry.isUnique and entry.canAir) or hasGokuForFusion) then
					priority = 1245 - entry.upgrade * 4
				elseif entry.isFarm and wave <= 14 and not leakThreat and basicFarmDefenseReady and ((entry.id == "speedwagon" and nextCost <= 3000) or nextCost <= 2500) then
					priority = 1215 - nextCost / 250
				elseif needMoreAirNow and primaryAirCarry and entry.model == primaryAirCarry.model then
					priority = 1190 - entry.upgrade * 4
				elseif primaryMainCarry and entry.model == primaryMainCarry.model then
					priority = 1150
				elseif entry.isIdol and earlyDefenseReady and not leakThreat then
					priority = 1130 - entry.upgrade * 15
				elseif entry.isFarm and wave <= 18 and not isBossPrepWave then
					if basicFarmDefenseReady and nextCost <= 4500 then
						priority = 1110 - nextCost / 200
					elseif earlyDefenseReady and wave <= 15 and nextCost <= 7500 then
						priority = 1094 - nextCost / 250
					elseif earlyDefenseReady and wave <= 16 and nextCost <= 10000 then
						priority = 980 - nextCost / 200
					else
						priority = 350 - nextCost / 200
					end
				elseif primaryAirCarry and entry.model == primaryAirCarry.model and (entry.rarityScore >= 500 or entry.upgrade < 3) then
					priority = 1098 - entry.upgrade * 4
				elseif primaryGroundCarry and entry.model == primaryGroundCarry.model then
					priority = 1090 - entry.upgrade * 4
				elseif primaryAnchorCarry and entry.model == primaryAnchorCarry.model and entry.upgrade < 6 then
					priority = 1084 - entry.upgrade * 4
				elseif entry.rarityScore >= 500 and entry.upgrade < 2 and nextCost <= 2200 and #placed.dps <= 6 and not entry.isFarm and not entry.isSupport then
					priority = 1078 - entry.upgrade * 10
				elseif entry.canAirPotential and not entry.canAir and entry.rarityScore >= 500 and not entry.isFarm and not entry.isSupport then
					priority = 1075 - entry.upgrade * 4
				elseif entry.canAir and entry.rarityScore >= 500 and entry.upgrade < 5 and not entry.isFarm and not entry.isSupport then
					priority = 1055 - entry.upgrade * 10
				elseif (entry.isMainUnit or entry.isUnique) and not entry.isFarm and not entry.isSupport then
					priority = 1035 - entry.upgrade * 4
				elseif not entry.isFarm and not entry.isSupport then
					if entry.canAir and entry.upgrade < 3 and nextCost <= 5500 then
						priority = 992 - entry.upgrade * 8
					elseif entry.rarityScore >= 500 and entry.upgrade < 4 then
						priority = 975 - entry.upgrade * 12
					else
						priority = entry.rarityScore + (entry.liveDamage / 500) + (entry.canAir and 80 or 0) - entry.upgrade * 10
					end
				elseif entry.isSupport and wave >= 12 then
					priority = 450 - entry.upgrade * 30
				end

				if priority > 0 then
					table.insert(upgradeQueue, { entry = entry, cost = nextCost, priority = priority })
				end
			end
		end

		table.sort(upgradeQueue, function(a, b)
			if math.abs(a.priority - b.priority) > 12 then
				return a.priority > b.priority
			end
			return a.cost < b.cost
		end)

		local availableForUpgrades = math.max(0, money - reservedMoney)
		local isCriticalLeak = leakThreat and (leakThreat.prog >= 0.72 or leakThreat.aheadDpsCount == 0)
		for _, item in ipairs(upgradeQueue) do
			local budget = (item.priority >= 1450 and isCriticalLeak) and money or availableForUpgrades
			if budget >= item.cost then
				local ok = AA.invokeServer("upgrade_unit_ingame", item.entry.model)
				if ok then
					state.stats.unitsUpgraded += 1
					state.stats.lastAction = "upg_" .. item.entry.id .. "_to_" .. tostring(item.entry.upgrade + 1)
					money = lp._stats.resource.Value
					availableForUpgrades = math.max(0, money - reservedMoney)
				end
			elseif not leakThreat then
				local isMainOrUniqueItem = item.entry.isUnique or item.entry.isMainUnit or FUSION_PARTNER_UNITS[item.entry.id]
				if (isMainOrUniqueItem and item.priority >= 1140 and item.cost <= 35000)
					or (item.priority >= 1080 and item.entry.upgrade < 5 and item.cost <= 9500)
					or (item.priority >= 1050 and item.cost <= 14000 and availableForUpgrades >= (item.cost * 0.30)) then
					break
				end
			end
		end

		return "active_wave_" .. tostring(wave)
	end

	function AA.startAutoAprilFools()
		if AA.AutoAprilFools.running then
			return "already_running"
		end
		AA.AutoAprilFools.running = true

		task.spawn(function()
			while AA.AutoAprilFools and AA.AutoAprilFools.running do
				local ok, err = pcall(AA.stepAprilFools)
				if not ok then
					AA.AutoAprilFools.stats.lastError = tostring(err)
				end
				task.wait(0.8)
			end
		end)
		return "started"
	end

	function AA.stopAutoAprilFools()
		if AA.AutoAprilFools then
			AA.AutoAprilFools.running = false
		end
		return "stopped"
	end
end

attachToAnimeAdventures(AnimeAdventures)

task.spawn(function()
	if not game:IsLoaded() then
		game.Loaded:Wait()
	end
	local lp = Players.LocalPlayer or Players.PlayerAdded:Wait()
	if lp and (not ALLOWED_APRIL_FOOLS_USERNAME or lp.Name == ALLOWED_APRIL_FOOLS_USERNAME) then
		task.wait(2)
		AnimeAdventures.startAutoAprilFools()
	end
end)
