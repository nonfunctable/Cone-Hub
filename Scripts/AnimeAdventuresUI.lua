
local ANIME_ADVENTURES_GAME_ID = 3183403065
local LOBBY_PLACE_ID = 8304191830
local MATCH_PLACE_ID = 14229839966
local ALT_MATCH_PLACE_ID = 14229762361

if game.GameId ~= 0 and game.GameId ~= ANIME_ADVENTURES_GAME_ID
	and game.PlaceId ~= LOBBY_PLACE_ID and game.PlaceId ~= MATCH_PLACE_ID and game.PlaceId ~= ALT_MATCH_PLACE_ID then
	return
end

if not game:IsLoaded() then
	game.Loaded:Wait()
end

local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local TeleportService = game:GetService("TeleportService")
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")

local LocalPlayer = Players.LocalPlayer or Players.PlayerAdded:Wait()
local env = (getgenv and getgenv()) or shared

local REPO = "https://raw.githubusercontent.com/nonfunctable/Cone-Hub/main/"
local ENGINE_URL = REPO .. "Scripts/AnimeAdventures.lua"
local UI_URL = REPO .. "Scripts/AnimeAdventuresUI.lua"
local SETTINGS_FOLDER = "ConeHub"
local PEARL_ICON = "rbxassetid://128058918644138"
local SETTINGS_FILE = SETTINGS_FOLDER .. "/AnimeAdventures_UI.json"

local PREVIEW = env.CONE_AA_UI_PREVIEW == true

if env.__ConeAAUICleanup then
	pcall(env.__ConeAAUICleanup)
end
local myRunId = (tonumber(env.__ConeAAUIRunId) or 0) + 1
env.__ConeAAUIRunId = myRunId
local alive = true
local conns = {}


local DEFAULTS = {
	enabled = true,
	autoQueue = true,
	useMatchmaking = true,
	autoDaily = false,
	autoSwitchTeams = false,
	dailyTeamSlot = "1",
	summerTeamSlot = "2",
	perfectErwin = true,
	smartTimestop = true,
	returnToLobby = true,
	webhookEnabled = false,
	webhookUrl = "",
	antiAfk = true,
	autoExecute = false,
	lowGraphics = false,
	disable3D = false,
	fpsCap = "Unlimited",
}

local state = {}
for k, v in pairs(DEFAULTS) do
	state[k] = v
end

local canFile = type(readfile) == "function" and type(writefile) == "function" and type(isfile) == "function"

local function loadSettings()
	if not canFile then
		return
	end
	pcall(function()
		if isfile(SETTINGS_FILE) then
			local data = HttpService:JSONDecode(readfile(SETTINGS_FILE))
			if type(data) == "table" then
				for k, v in pairs(data) do
					if DEFAULTS[k] ~= nil and type(v) == type(DEFAULTS[k]) then
						state[k] = v
					end
				end
			end
		end
	end)
end

local function saveSettings()
	if not canFile then
		return
	end
	pcall(function()
		if type(makefolder) == "function" and type(isfolder) == "function" and not isfolder(SETTINGS_FOLDER) then
			makefolder(SETTINGS_FOLDER)
		end
		writefile(SETTINGS_FILE, HttpService:JSONEncode(state))
	end)
end

loadSettings()


local CONFIG = {}
if not PREVIEW then
	env.AA_SUMMER_CONFIG = CONFIG
end

local function applyConfig()
	CONFIG.AUTO_QUEUE = state.autoQueue
	CONFIG.USE_MATCHMAKING = state.useMatchmaking
	CONFIG.AUTO_DAILY_CHALLENGE = state.autoDaily
	CONFIG.AUTO_SWITCH_TEAMS = state.autoSwitchTeams
	CONFIG.DAILY_TEAM_SLOT = state.dailyTeamSlot
	CONFIG.SUMMER_TEAM_SLOT = state.summerTeamSlot
	CONFIG.PERFECT_ERWIN_BUFF = state.perfectErwin
	CONFIG.TARGET_ERWIN_COUNT = 4
	CONFIG.SMART_TIMESTOP = state.smartTimestop
	CONFIG.RETURN_TO_LOBBY = state.returnToLobby
	CONFIG.WEBHOOK_ENABLED = state.webhookEnabled
	CONFIG.WEBHOOK_URL = state.webhookUrl
	CONFIG.ALWAYS_PICK_DEBUFFS = true
end
applyConfig()

local function setState(key, value)
	state[key] = value
	applyConfig()
	saveSettings()
end


local AA = env.AnimeAdventures
local engineError = nil

if not PREVIEW then
	env.AA_NO_AUTOSTART = true
	local ok, err = pcall(function()
		local src
		if type(env.AA_ENGINE_PATH) == "string" and canFile and isfile(env.AA_ENGINE_PATH) then
			src = readfile(env.AA_ENGINE_PATH)
		else
			src = game:HttpGet(ENGINE_URL .. "?v=" .. tostring(os.time()))
		end
		local fn, cerr = loadstring(src)
		if not fn then
			error(cerr)
		end
		fn()
	end)
	if not ok then
		engineError = tostring(err)
	end
	AA = env.AnimeAdventures
end

local function engineState()
	return AA and AA.AutoSummerEvent
end

local function isRunning()
	local st = engineState()
	return st and st.running == true
end

local function syncEngine()
	if PREVIEW or not AA then
		return
	end
	if state.enabled and not isRunning() and AA.startAutoSummerEvent then
		AA.startAutoSummerEvent()
	elseif not state.enabled and isRunning() and AA.stopAutoSummerEvent then
		AA.stopAutoSummerEvent()
	end
end


local function inLobby()
	return game.PlaceId == LOBBY_PLACE_ID
end

local function statValue(name)
	local s = LocalPlayer:FindFirstChild("_stats")
	local v = s and s:FindFirstChild(name)
	return v and v.Value or 0
end

local function fmtNum(n)
	n = tonumber(n) or 0
	if n >= 1e6 then
		return string.format("%.1fM", n / 1e6)
	elseif n >= 1e4 then
		return string.format("%.1fK", n / 1e3)
	end
	return tostring(math.floor(n))
end

local function fmtTime(sec)
	sec = math.max(0, math.floor(sec or 0))
	local h, m, s = math.floor(sec / 3600), math.floor(sec % 3600 / 60), sec % 60
	if h > 0 then
		return string.format("%d:%02d:%02d", h, m, s)
	end
	return string.format("%d:%02d", m, s)
end

local function prettyAction(a)
	a = tostring(a or "idle")
	return (a:gsub("_", " "))
end

local function getLoadouts()
	local list = {}
	local pd = AA and AA.getProfileData and AA.getProfileData()
	local lo = pd and pd.loadouts_v2
	if type(lo) ~= "table" then
		return nil
	end
	for i = 1, 6 do
		local entry = lo[tostring(i)]
		local count, name = 0, nil
		if type(entry) == "table" then
			for _ in pairs(entry.saved_equipped or {}) do
				count += 1
			end
			for k, v in pairs(entry) do
				if type(v) == "string" and tostring(k):lower():find("name") then
					name = v
				end
			end
		end
		list[i] = { slot = tostring(i), units = count, name = name }
	end
	return list
end

local function getHttpRequest()
	return (type(request) == "function" and request)
		or (type(http_request) == "function" and http_request)
		or (syn and type(syn.request) == "function" and syn.request)
		or (http and type(http.request) == "function" and http.request)
end


local afkConn
local function setAntiAfk(on)
	if afkConn then
		afkConn:Disconnect()
		afkConn = nil
	end
	if on then
		local VirtualUser = game:GetService("VirtualUser")
		afkConn = LocalPlayer.Idled:Connect(function()
			pcall(function()
				VirtualUser:CaptureController()
				VirtualUser:ClickButton2(Vector2.new())
			end)
		end)
	end
end

local queuedTeleport = false
local function setAutoExecute(on)
	local q = (syn and syn.queue_on_teleport) or queue_on_teleport or (fluxus and fluxus.queue_on_teleport)
	if on and q and not queuedTeleport then
		queuedTeleport = true
		pcall(q, 'loadstring(game:HttpGet("' .. UI_URL .. '"))()')
	end
end
table.insert(conns, LocalPlayer.OnTeleport:Connect(function()
	if state.autoExecute then
		setAutoExecute(true)
	end
end))

local savedLighting = nil
local function setLowGraphics(on)
	pcall(function()
		if on then
			savedLighting = savedLighting or { GlobalShadows = Lighting.GlobalShadows, Quality = settings().Rendering.QualityLevel }
			Lighting.GlobalShadows = false
			settings().Rendering.QualityLevel = Enum.QualityLevel.Level01
		elseif savedLighting then
			Lighting.GlobalShadows = savedLighting.GlobalShadows
			settings().Rendering.QualityLevel = savedLighting.Quality
		end
	end)
end

local blackOverlay
local function set3D(disabled)
	pcall(function()
		RunService:Set3dRenderingEnabled(not disabled)
	end)
	pcall(function()
		if disabled then
			if not (blackOverlay and blackOverlay.Parent) then
				blackOverlay = Instance.new("ScreenGui")
				blackOverlay.Name = "ConeHub_AA_Black"
				blackOverlay.DisplayOrder = -2147483647
				blackOverlay.IgnoreGuiInset = true
				blackOverlay.ResetOnSpawn = false
				local f = Instance.new("Frame")
				f.Size = UDim2.fromScale(1, 1)
				f.BackgroundColor3 = Color3.new(0, 0, 0)
				f.BorderSizePixel = 0
				f.Parent = blackOverlay
				blackOverlay.Parent = LocalPlayer:WaitForChild("PlayerGui")
			end
		elseif blackOverlay then
			blackOverlay:Destroy()
			blackOverlay = nil
		end
	end)
end

local function setFpsCap(v)
	if type(setfpscap) ~= "function" then
		return
	end
	local n = tonumber(v)
	pcall(setfpscap, n or 0)
end


local function loadRemote(url, fallback, token)
	local ok, src = pcall(game.HttpGet, game, url)
	if ok and type(src) == "string" and #src > 100 and (not token or src:find(token, 1, true)) then
		local fn = loadstring(src)
		if fn then
			return fn()
		end
	end
	return loadstring(game:HttpGet(fallback))()
end

local Fluent = loadRemote(REPO .. "UI/Fluent.lua", "https://raw.githubusercontent.com/dawid-scripts/Fluent/master/main.lua", "StatCard")
local InterfaceManager = loadRemote(REPO .. "UI/InterfaceManager.lua", "https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Addons/InterfaceManager.lua")

if env.__ConeAAUIRunId ~= myRunId then
	pcall(function()
		Fluent:Destroy()
	end)
	return
end

local Window = Fluent:CreateWindow({
	Title = "Cone Hub",
	SubTitle = "Anime Adventures" .. (PREVIEW and " (preview)" or ""),
	TabWidth = 145,
	Size = UDim2.fromOffset(580, 460),
	Acrylic = false,
	Theme = "Dark",
	MinimizeKey = Enum.KeyCode.LeftControl,
})

pcall(function()
	if Fluent.GUI then
		Fluent.GUI.Name = "ConeHub_AA"
	end
end)

env.__ConeAAUICleanup = function()
	alive = false
	if blackOverlay then
		pcall(set3D, false)
	end
	setAntiAfk(false)
	for _, c in ipairs(conns) do
		pcall(function()
			c:Disconnect()
		end)
	end
	table.clear(conns)
	pcall(function()
		Fluent:Destroy()
	end)
end

local Tabs = {
	Home = Window:AddTab({ Title = "Home", Icon = "home" }),
	Join = Window:AddTab({ Title = "Auto Join", Icon = "compass" }),
	Teams = Window:AddTab({ Title = "Teams", Icon = "users" }),
	Play = Window:AddTab({ Title = "Auto Play", Icon = "play" }),
	Webhook = Window:AddTab({ Title = "Webhook", Icon = "bell" }),
	Misc = Window:AddTab({ Title = "Misc", Icon = "sliders-horizontal" }),
	Settings = Window:AddTab({ Title = "Settings", Icon = "settings" }),
}
local Options = Fluent.Options

local function divider(tab, title, icon)
	if tab.AddDivider then
		tab:AddDivider({ Title = title, Icon = icon })
	end
end

local function notify(title, content)
	Fluent:Notify({ Title = title, Content = content, Duration = 4 })
end

local function bindToggle(tab, id, key, title, desc, extra)
	local t = tab:AddToggle(id, { Title = title, Description = desc, Default = state[key] })
	t:OnChanged(function()
		local v = Options[id].Value
		if state[key] ~= v then
			setState(key, v)
		end
		if extra then
			extra(v)
		end
	end)
	return t
end


local HomeStats = Tabs.Home.AddStatCard and Tabs.Home:AddStatCard("AAHomeStats", {
	Columns = 2,
	Stats = {
		{ Key = "Status", Title = "Status", Value = "Starting...", SubValue = "", Icon = "activity" },
		{ Key = "Where", Title = "Location", Value = inLobby() and "Lobby" or "Match", SubValue = "", Icon = "map" },
		{ Key = "Session", Title = "Session", Value = "0W / 0L", SubValue = "0:00", Icon = "trophy" },
		{ Key = "Wallet", Title = "Summer Pearls", Value = "0", SubValue = "", Icon = PEARL_ICON, Color = Color3.new(1, 1, 1) },
	},
}) or nil

divider(Tabs.Home, "Quick Controls", "gauge")

bindToggle(Tabs.Home, "AAMaster", "enabled", "Auto Farm", "Master switch: queues in the lobby and auto-plays matches", function()
	syncEngine()
end)

local ActivityBox = Tabs.Home:AddParagraph({ Title = "Activity", Content = "Waiting for engine..." })

divider(Tabs.Home, "Server", "globe")

Tabs.Home:AddButton({
	Title = "Return to Lobby",
	Description = "Leaves the current match and teleports to the lobby",
	Callback = function()
		task.spawn(function()
			local ok = AA and AA.invokeServer and pcall(AA.invokeServer, "teleport_back_to_lobby")
			if not ok then
				pcall(TeleportService.Teleport, TeleportService, LOBBY_PLACE_ID, LocalPlayer)
			end
		end)
	end,
})

Tabs.Home:AddButton({
	Title = "Rejoin",
	Description = "Rejoins this server (lobby) or returns to the lobby (match)",
	Callback = function()
		if inLobby() and game.JobId ~= "" then
			pcall(TeleportService.TeleportToPlaceInstance, TeleportService, game.PlaceId, game.JobId, LocalPlayer)
		else
			pcall(TeleportService.Teleport, TeleportService, LOBBY_PLACE_ID, LocalPlayer)
		end
	end,
})


local DailyBox = Tabs.Join:AddParagraph({ Title = "Daily Challenge", Content = "Checking..." })

divider(Tabs.Join, "Queue", "compass")

bindToggle(Tabs.Join, "AAAutoQueue", "autoQueue", "Auto Queue", "Queues automatically while in the lobby")
bindToggle(Tabs.Join, "AAMatchmaking", "useMatchmaking", "Use Matchmaking", "Join public matchmaking for Summer (off = solo lobby)")
bindToggle(Tabs.Join, "AAAutoDaily", "autoDaily", "Auto Daily Challenge", "Clears today's Daily Challenge (matchmaking) before Summer")

divider(Tabs.Join, "Manual", "mouse-pointer-click")

Tabs.Join:AddButton({
	Title = "Queue Summer Now",
	Callback = function()
		if not inLobby() then
			return notify("Auto Join", "Only works in the lobby")
		end
		task.spawn(function()
			pcall(AA.joinAndStartSummerEvent, state.useMatchmaking, engineState())
		end)
	end,
})

Tabs.Join:AddButton({
	Title = "Queue Daily Challenge Now",
	Callback = function()
		if not inLobby() then
			return notify("Auto Join", "Only works in the lobby")
		end
		task.spawn(function()
			pcall(AA.joinAndStartSummerEvent, true, engineState(), "__DAILY_CHALLENGE")
		end)
	end,
})

Tabs.Join:AddButton({
	Title = "Leave Queue",
	Callback = function()
		task.spawn(function()
			pcall(AA.invokeServer, "leave_matchmaking")
		end)
	end,
})


local TeamsBox = Tabs.Teams:AddParagraph({ Title = "Saved Teams", Content = "Open the lobby to read your saved teams." })

divider(Tabs.Teams, "Team Switching", "users")

bindToggle(Tabs.Teams, "AASwitchTeams", "autoSwitchTeams", "Auto Switch Teams",
	"Loads a saved team before queueing. Leave off if you have no saved teams (empty slots are skipped)")

local SLOT_VALUES = { "1", "2", "3", "4", "5", "6" }

local DailySlotDD = Tabs.Teams:AddDropdown("AADailySlot", {
	Title = "Daily Challenge Team",
	Values = SLOT_VALUES,
	Default = state.dailyTeamSlot,
})
DailySlotDD:OnChanged(function(v)
	if v then
		setState("dailyTeamSlot", tostring(v))
	end
end)

local SummerSlotDD = Tabs.Teams:AddDropdown("AASummerSlot", {
	Title = "Summer Team",
	Values = SLOT_VALUES,
	Default = state.summerTeamSlot,
})
SummerSlotDD:OnChanged(function(v)
	if v then
		setState("summerTeamSlot", tostring(v))
	end
end)

local function loadTeamNow(slot)
	if not inLobby() then
		return notify("Teams", "Teams can only be loaded in the lobby")
	end
	task.spawn(function()
		local ok, res = pcall(AA.ensureTeamLoadout, slot)
		notify("Teams", (ok and res) and ("Team " .. slot .. " equipped") or ("Team " .. slot .. " is empty"))
	end)
end

Tabs.Teams:AddButton({ Title = "Equip Daily Team Now", Callback = function() loadTeamNow(state.dailyTeamSlot) end })
Tabs.Teams:AddButton({ Title = "Equip Summer Team Now", Callback = function() loadTeamNow(state.summerTeamSlot) end })


local MatchBox = Tabs.Play:AddParagraph({ Title = "Match Stats", Content = "No match yet." })

divider(Tabs.Play, "Units", "swords")

bindToggle(Tabs.Play, "AAErwin", "perfectErwin", "Perfect Erwin Buff", "Places 4 Erwins and cycles their buffs for 100% uptime")
bindToggle(Tabs.Play, "AATimestop", "smartTimestop", "Smart Timestop", "Holds actives while a timestop is active")

divider(Tabs.Play, "Match", "flag")

bindToggle(Tabs.Play, "AAReturnLobby", "returnToLobby", "Return to Lobby After Match",
	"On: back to lobby (lets Daily/Summer switching work). Off: votes Replay")


bindToggle(Tabs.Webhook, "AAWebhookOn", "webhookEnabled", "Send Round Summary", "Posts rewards, wave and W/L after every match")

Tabs.Webhook:AddInput("AAWebhookUrl", {
	Title = "Webhook URL",
	Default = state.webhookUrl,
	Placeholder = "Paste your Discord webhook URL",
	Numeric = false,
	Finished = true,
	Callback = function(v)
		setState("webhookUrl", tostring(v or ""))
	end,
})

Tabs.Webhook:AddButton({
	Title = "Send Test Message",
	Callback = function()
		local req = getHttpRequest()
		if not req or #state.webhookUrl < 10 then
			return notify("Webhook", "Set a webhook URL first")
		end
		task.spawn(function()
			local ok = pcall(req, {
				Url = state.webhookUrl,
				Method = "POST",
				Headers = { ["Content-Type"] = "application/json" },
				Body = HttpService:JSONEncode({
					embeds = { { title = "Cone Hub", description = "Webhook test from Anime Adventures", color = 0x5865F2 } },
				}),
			})
			notify("Webhook", ok and "Test sent" or "Request failed")
		end)
	end,
})


divider(Tabs.Misc, "AFK", "moon")
bindToggle(Tabs.Misc, "AAAntiAfk", "antiAfk", "Anti AFK", "Stops the 20 minute idle kick", setAntiAfk)
bindToggle(Tabs.Misc, "AAAutoExec", "autoExecute", "Auto Execute on Teleport", "Re-runs this UI after lobby <-> match teleports", setAutoExecute)

divider(Tabs.Misc, "Performance", "cpu")
bindToggle(Tabs.Misc, "AALowGfx", "lowGraphics", "Low Graphics", "Lowest quality + no shadows", setLowGraphics)
bindToggle(Tabs.Misc, "AANo3D", "disable3D", "Disable 3D Rendering", "Black screen, big CPU/GPU savings while AFK", set3D)

local FpsDD = Tabs.Misc:AddDropdown("AAFpsCap", {
	Title = "FPS Cap",
	Values = { "Unlimited", "60", "30", "15", "10" },
	Default = state.fpsCap,
})
FpsDD:OnChanged(function(v)
	if v then
		setState("fpsCap", tostring(v))
		setFpsCap(v)
	end
end)


InterfaceManager:SetLibrary(Fluent)
InterfaceManager:SetFolder(SETTINGS_FOLDER)
InterfaceManager:BuildInterfaceSection(Tabs.Settings)

divider(Tabs.Settings, "Script", "file-cog")

Tabs.Settings:AddButton({
	Title = "Reset Settings",
	Description = "Restores every toggle to its default",
	Callback = function()
		Window:Dialog({
			Title = "Reset Settings",
			Content = "Restore every option to default?",
			Buttons = {
				{
					Title = "Reset",
					Callback = function()
						for k, v in pairs(DEFAULTS) do
							state[k] = v
						end
						applyConfig()
						saveSettings()
						notify("Settings", "Reset. Re-execute to refresh the controls.")
					end,
				},
				{ Title = "Cancel" },
			},
		})
	end,
})

Tabs.Settings:AddButton({
	Title = "Unload",
	Description = "Stops auto farm and closes the UI",
	Callback = function()
		if not PREVIEW and AA and AA.stopAutoSummerEvent then
			AA.stopAutoSummerEvent()
		end
		env.__ConeAAUICleanup()
	end,
})

Window:SelectTab(1)


setAntiAfk(state.antiAfk)
setLowGraphics(state.lowGraphics)
set3D(state.disable3D)
setFpsCap(state.fpsCap)
if state.autoExecute then
	setAutoExecute(true)
end

if engineError then
	notify("Engine failed to load", engineError:sub(1, 120))
end

task.delay(2.5, syncEngine)

local uiStart = os.time()

local function recolorTiles()
	if not (HomeStats and HomeStats.Tiles and HomeStats.Tiles[1]) then
		return
	end
	local textColor = HomeStats.Tiles[1].ValueLabel.TextColor3
	for _, tile in ipairs(HomeStats.Tiles) do
		if tile.SubLabel then
			tile.SubLabel.TextColor3 = textColor
		end
		if tile.Key == "Wallet" then
			tile.ValueLabel.TextColor3 = textColor
		elseif tile.IconImage then
			tile.IconImage.ImageColor3 = textColor
			if tile.IconImage.Parent then
				tile.IconImage.Parent.BackgroundColor3 = textColor
			end
		end
	end
end

local function refresh()
	pcall(recolorTiles)
	local st = engineState()
	local stats = st and st.stats or {}
	local running = st and st.running

	if HomeStats then
		HomeStats:SetStat("Status", running and "Running" or "Stopped", "")
		local wave = workspace:FindFirstChild("_wave_num")
		HomeStats:SetStat("Where", inLobby() and "Lobby" or "Match", inLobby() and ((st and st.queuedLevelId == "__DAILY_CHALLENGE") and "Daily" or (st and st.queuedLevelId) and "Summer" or "") or ("Wave " .. tostring(wave and wave.Value or 0)))
		local sess = AA and AA.getSessionStats and AA.getSessionStats() or {}
		HomeStats:SetStat("Session", string.format("%dW / %dL", sess.wins or 0, sess.losses or 0), fmtTime(os.time() - (sess.sessionStart or uiStart)))
		local pearls = statValue("_resourceSummerPearls")
		local snap = st and st.matchStartSnapshot
		local gained = (not inLobby() and snap and snap.summerPearls and snap.summerPearls > 0) and (pearls - snap.summerPearls) or nil
		HomeStats:SetStat("Wallet", fmtNum(pearls), gained and ("+" .. fmtNum(gained)) or "")
	end

	ActivityBox:SetDesc(string.format(
		"Last action: %s\nTicks: %d%s",
		prettyAction(stats.lastAction),
		stats.ticks or 0,
		stats.lastError and ("\nLast error: " .. tostring(stats.lastError):sub(1, 90)) or ""
	))

	MatchBox:SetDesc(string.format(
		"Placed: %d   Upgrades: %d\nActives: %d   Erwin buffs: %d\nLeaks handled: %d   Replays: %d",
		stats.unitsSpawned or 0, stats.unitsUpgraded or 0, stats.activesUsed or 0,
		stats.erwinBuffsCast or 0, stats.leaksHandled or 0, stats.replaysVoted or 0
	))

	if inLobby() then
		local ok, pending = pcall(function()
			return AA.isDailyChallengePending()
		end)
		DailyBox:SetDesc(not ok and "Unavailable" or (pending and "Not cleared today (will run first)" or "Cleared for today"))

		local teams = getLoadouts()
		if teams then
			local lines = {}
			for _, t in ipairs(teams) do
				local tag = (t.slot == state.dailyTeamSlot and "  [Daily]" or "") .. (t.slot == state.summerTeamSlot and "  [Summer]" or "")
				table.insert(lines, string.format("%s. %s  (%s)%s", t.slot, t.name or ("Team " .. t.slot), t.units > 0 and (t.units .. " units") or "empty", tag))
			end
			TeamsBox:SetDesc(table.concat(lines, "\n"))
		end
	else
		DailyBox:SetDesc("Shown in the lobby")
	end
end

task.spawn(function()
	while alive and env.__ConeAAUIRunId == myRunId do
		pcall(refresh)
		task.wait(1)
	end
end)
