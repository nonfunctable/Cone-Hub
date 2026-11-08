
local SmartWalk = {}
SmartWalk.VERSION = "1.0.0"

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local PathfindingService = game:GetService("PathfindingService")
local UserInputService = game:GetService("UserInputService")
local Workspace = workspace
local LP = Players.LocalPlayer

local V3 = Vector3.new
local ZERO = V3(0, 0, 0)
local UP = V3(0, 1, 0)
local HST = Enum.HumanoidStateType
local AIR = Enum.Material.Air

local Active = nil
local FollowToken = nil
local PartialSupported = true

SmartWalk.defaults = {
	reach = 3.5,
	reachY = 3,
	timeout = nil,
	mode = "move",
	waypointReach = 2.2,
	recomputeEvery = 5,
	retargetDist = 5,
	agent = nil,
	costs = nil,
	links = nil,
	maxReplans = 3,
	searchBudget = 28,
	maxStuck = 8,
	allowDirect = true,
	maxDirect = 40,
	maxDrop = 12,
	acceptNearest = false,
	respawn = true,
	maxRespawns = 2,
	lockControls = false,
	yieldToUser = false,
	humanize = true,
	avoidHazards = true,
	isHazard = nil,
	debug = false,
	verbose = false,
	onStatus = nil,
	tickRate = 30,
}

local function now()
	return os.clock()
end

local function flat(v)
	return V3(v.X, 0, v.Z)
end

local function hdist(a, b)
	local dx, dz = a.X - b.X, a.Z - b.Z
	return math.sqrt(dx * dx + dz * dz)
end

local function unitOr(v, fallback)
	local m = v.Magnitude
	if m < 1e-3 then
		return fallback
	end
	return v / m
end

local function closestPoint(part, p)
	local cf, half = part.CFrame, part.Size * 0.5
	local l = cf:PointToObjectSpace(p)
	return cf:PointToWorldSpace(V3(
		math.clamp(l.X, -half.X, half.X),
		math.clamp(l.Y, -half.Y, half.Y),
		math.clamp(l.Z, -half.Z, half.Z)
	))
end

local function aabbHalfY(part)
	local cf, s = part.CFrame, part.Size
	return math.abs(cf.RightVector.Y) * s.X * 0.5 + math.abs(cf.UpVector.Y) * s.Y * 0.5 + math.abs(cf.LookVector.Y) * s.Z * 0.5
end

local function aabbTop(part)
	return part.Position.Y + aabbHalfY(part)
end

local function aabbBottom(part)
	return part.Position.Y - aabbHalfY(part)
end

local function dirToPart(part, p)
	local d = flat(closestPoint(part, p) - p)
	if d.Magnitude < 0.15 then
		return nil
	end
	return d.Unit
end

local function emit(S, status, info)
	S.status = status
	local msg = info ~= nil and tostring(info) or ""
	if S.opts.verbose then
		print("[SmartWalk] " .. status .. (msg ~= "" and (" - " .. msg) or ""))
	end
	if S.opts.onStatus then
		pcall(S.opts.onStatus, status, msg)
	end
	if SmartWalk.onStatus then
		pcall(SmartWalk.onStatus, status, msg)
	end
end

local function buildOpts(o)
	o = o or {}
	local d = SmartWalk.defaults
	local r = {}
	for k, v in pairs(d) do
		r[k] = v
	end
	for k, v in pairs(o) do
		r[k] = v
	end
	local agent = {}
	for k, v in pairs(d.agent or {}) do
		agent[k] = v
	end
	for k, v in pairs(o.agent or {}) do
		agent[k] = v
	end
	r.agent = agent
	local costs = { SmartWalkAvoid = math.huge }
	for k, v in pairs(d.costs or {}) do
		costs[k] = v
	end
	for k, v in pairs(o.costs or {}) do
		costs[k] = v
	end
	r.costs = costs
	local links = {}
	for k, v in pairs(d.links or {}) do
		links[k] = v
	end
	for k, v in pairs(o.links or {}) do
		links[k] = v
	end
	r.links = links
	r.recomputeEvery = tonumber(r.recomputeEvery) or 0
	r.retargetDist = tonumber(r.retargetDist) or 0
	r.tickRate = math.clamp(tonumber(r.tickRate) or 30, 5, 120)
	return r
end

local function newSession(target, opts)
	local S = {
		target = target,
		opts = opts,
		mode = (opts.mode == "moveto") and "moveto" or "move",
		cancel = false,
		done = false,
		moveDir = ZERO,
		curDir = ZERO,
		jumpUntil = 0,
		lastJump = 0,
		wi = 1,
		pathGen = 0,
		markers = {},
		conns = {},
		respawns = 0,
		deadline = math.huge,
		filterT = 0,
		charHeight = 5,
		legs = 2,
		status = "idle",
	}
	if typeof(target) == "Instance" and target:IsA("BasePart") then
		S.targetPart = target
	end
	return S
end

local function jumpH(S)
	local hum = S.hum
	if hum.UseJumpPower then
		return (hum.JumpPower * hum.JumpPower) / (2 * Workspace.Gravity)
	end
	return hum.JumpHeight
end

local function footPos(S)
	local hrp = S.hrp
	return hrp.Position - V3(0, hrp.Size.Y * 0.5 + S.legs, 0)
end

local function setupAgent(S)
	local hrp, hum = S.hrp, S.hum
	local scale = math.max(hrp.Size.Y / 2, 0.5)
	S.legs = (hum.RigType == Enum.HumanoidRigType.R6) and 2 * scale or hum.HipHeight
	S.charHeight = hrp.Size.Y + S.legs + 1.5 * scale
	local o = S.opts.agent or {}
	local okJ, jumpEnabled = pcall(function()
		return hum:GetStateEnabled(HST.Jumping)
	end)
	local autoJump = jumpH(S) > 1 and (not okJ or jumpEnabled)
	local cj = o.canJump
	if cj == nil then
		cj = o.AgentCanJump
	end
	if cj == nil then
		cj = autoJump
	end
	local cc = o.canClimb
	if cc == nil then
		cc = o.AgentCanClimb
	end
	if cc == nil then
		cc = true
	end
	S.agent = {
		radius = o.radius or o.AgentRadius or math.clamp(2 * scale, 1, 5),
		height = o.height or o.AgentHeight or math.clamp(S.charHeight, 2, 12),
		canJump = cj and true or false,
		canClimb = cc and true or false,
		spacing = o.spacing or o.WaypointSpacing or 4,
	}
end

local function rebuildFilter(S)
	local list = {}
	if S.char then
		list[#list + 1] = S.char
	end
	local cam = Workspace.CurrentCamera
	local f = cam and cam:FindFirstChild("SmartWalkDebug")
	if f then
		list[#list + 1] = f
	end
	for _, pl in ipairs(Players:GetPlayers()) do
		if pl ~= LP and pl.Character then
			list[#list + 1] = pl.Character
		end
	end
	local rp = RaycastParams.new()
	rp.FilterType = Enum.RaycastFilterType.Exclude
	rp.FilterDescendantsInstances = list
	rp.IgnoreWater = false
	pcall(function()
		rp.RespectCanCollide = true
	end)
	local op = OverlapParams.new()
	op.FilterType = Enum.RaycastFilterType.Exclude
	op.FilterDescendantsInstances = list
	S.rp, S.op, S.filterT = rp, op, now()
end

local function refreshChar(S)
	local ch = LP.Character
	if not ch then
		return false
	end
	local hum = ch:FindFirstChildOfClass("Humanoid")
	if not hum or hum.Health <= 0 then
		return false
	end
	local hrp = hum.RootPart or ch:FindFirstChild("HumanoidRootPart")
	if not hrp then
		return false
	end
	if S.char ~= ch or S.hum ~= hum or S.hrp ~= hrp then
		S.char, S.hum, S.hrp = ch, hum, hrp
		setupAgent(S)
		rebuildFilter(S)
		if S.conns.mtf then
			S.conns.mtf:Disconnect()
			S.conns.mtf = nil
		end
		if S.mode == "moveto" then
			S.conns.mtf = hum.MoveToFinished:Connect(function()
				S.mtPoint = nil
			end)
		end
		S.mtPoint = nil
	end
	return true
end

local function alive(S)
	if LP.Character ~= S.char then
		return false
	end
	local hum, hrp = S.hum, S.hrp
	if not hum or not hum.Parent or hum.Health <= 0 then
		return false
	end
	if not hrp or not hrp.Parent then
		return false
	end
	return hum:GetState() ~= HST.Dead
end

local function ray(S, origin, dir)
	return Workspace:Raycast(origin, dir, S.rp)
end

local function groundAt(S, p, up, down)
	up = up or 1.5
	down = down or 40
	local r = ray(S, p + V3(0, up, 0), V3(0, -(up + down), 0))
	if r then
		return r.Position, r.Instance
	end
	return nil
end

local function findGround(S, p, down)
	local g, inst = groundAt(S, p, 1.5, down)
	if not g then
		g, inst = groundAt(S, p, 6, down)
	end
	return g, inst
end

local HAZARD_SUB = { "lava", "acid", "spike", "killbrick", "killpart", "deathbrick", "deathpart", "killzone", "deathzone" }
local HAZARD_EXACT = { kill = true, death = true, void = true, hazard = true }
local function isHazard(S, inst)
	if not inst then
		return false
	end
	if S.opts.isHazard then
		local ok, r = pcall(S.opts.isHazard, inst)
		if ok then
			return r and true or false
		end
	end
	if not S.opts.avoidHazards then
		return false
	end
	local n = string.lower(inst.Name)
	if HAZARD_EXACT[n] then
		return true
	end
	for _, w in ipairs(HAZARD_SUB) do
		if string.find(n, w, 1, true) then
			return true
		end
	end
	return false
end

local function isClimbable(p)
	return p:IsA("TrussPart") or (p:IsA("BasePart") and string.find(string.lower(p.Name), "ladder", 1, true) ~= nil)
end

local function nearestClimbable(S, pos, r)
	local ok, parts = pcall(function()
		return Workspace:GetPartBoundsInRadius(pos, r, S.op)
	end)
	if not ok or not parts then
		return nil
	end
	local best, bd = nil, math.huge
	for _, p in ipairs(parts) do
		if isClimbable(p) then
			local d = (closestPoint(p, pos) - pos).Magnitude
			if d < bd then
				best, bd = p, d
			end
		end
	end
	return best
end

local KIND_COLOR = {
	walk = Color3.fromRGB(235, 235, 235),
	jump = Color3.fromRGB(255, 205, 40),
	climb = Color3.fromRGB(70, 150, 255),
	custom = Color3.fromRGB(200, 90, 255),
}
local CUR_COLOR = Color3.fromRGB(60, 255, 110)
local GOAL_COLOR = Color3.fromRGB(255, 60, 60)
local SMALL = V3(0.6, 0.6, 0.6)
local BIG = V3(1, 1, 1)

local function debugFolder()
	local cam = Workspace.CurrentCamera
	if not cam then
		return nil
	end
	local f = cam:FindFirstChild("SmartWalkDebug")
	if not f then
		f = Instance.new("Folder")
		f.Name = "SmartWalkDebug"
		f.Parent = cam
	end
	return f
end

local function mkMarker(parent, pos, color, size)
	local p = Instance.new("Part")
	p.Name = "SWMarker"
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Shape = Enum.PartType.Ball
	p.Material = Enum.Material.Neon
	p.Size = V3(size, size, size)
	p.Color = color
	p.Transparency = 0.15
	p.CFrame = CFrame.new(pos)
	p.Parent = parent
	return p
end

local function clearMarkers(S)
	for _, m in pairs(S.markers) do
		pcall(m.Destroy, m)
	end
	S.markers = {}
	S.markerCur = nil
end

local function markCurrent(S)
	if not S.opts.debug or not S.wps then
		return
	end
	local old = S.markerCur
	if old and S.markers[old] and S.wps[old] then
		S.markers[old].Color = KIND_COLOR[S.wps[old].kind] or KIND_COLOR.walk
		S.markers[old].Size = SMALL
	end
	local m = S.markers[S.wi]
	if m then
		m.Color = CUR_COLOR
		m.Size = BIG
	end
	S.markerCur = S.wi
end

local function drawPath(S)
	if not S.opts.debug then
		return
	end
	clearMarkers(S)
	local f = debugFolder()
	if not f then
		return
	end
	if S.wps then
		for i, w in ipairs(S.wps) do
			if i > 300 then
				break
			end
			S.markers[i] = mkMarker(f, w.pos + V3(0, 0.35, 0), KIND_COLOR[w.kind] or KIND_COLOR.walk, 0.6)
		end
	end
	if S.lastPoint then
		S.markers.goal = mkMarker(f, S.lastPoint, GOAL_COLOR, 1.2)
	end
	markCurrent(S)
end

local function targetPoint(S)
	local t = S.target
	local ty = typeof(t)
	local p
	if ty == "Vector3" then
		p = t
	elseif ty == "CFrame" then
		p = t.Position
	elseif ty == "Instance" then
		if t.Parent then
			if t:IsA("BasePart") then
				p = t.Position
			elseif t:IsA("Model") then
				local ok, cf = pcall(t.GetPivot, t)
				if ok then
					p = cf.Position
				end
			elseif t:IsA("Attachment") then
				p = t.WorldPosition
			end
		end
	elseif ty == "function" then
		local ok, v = pcall(t)
		if ok then
			local tv = typeof(v)
			if tv == "Vector3" then
				p = v
			elseif tv == "CFrame" then
				p = v.Position
			elseif tv == "Instance" and v:IsA("BasePart") then
				p = v.Position
			end
		end
	end
	if p then
		S.lastPoint = p
	end
	return S.lastPoint
end

local function isArrived(S)
	local pos = S.hrp.Position
	local part = S.targetPart
	if part and part.Parent then
		return (closestPoint(part, pos) - pos).Magnitude <= S.opts.reach + 1
	end
	local tp = targetPoint(S)
	if not tp then
		return false
	end
	if hdist(pos, tp) > S.opts.reach then
		return false
	end
	local fy = footPos(S).Y
	return tp.Y >= fy - S.opts.reachY and tp.Y <= fy + S.charHeight + S.opts.reachY
end

local function startPos(S)
	local pos = S.hrp.Position
	if S.hum.FloorMaterial ~= AIR then
		return pos
	end
	local g = groundAt(S, pos, 0, 14)
	if g then
		return g + UP * (pos.Y - footPos(S).Y)
	end
	return pos
end

local function doJump(S, why)
	local t = now()
	if t - S.lastJump < 0.4 or not S.agent.canJump then
		return
	end
	S.lastJump = t
	S.jumpUntil = t + 0.12
	local hum = S.hum
	local st = hum:GetState()
	if st ~= HST.Jumping and st ~= HST.Freefall then
		pcall(hum.ChangeState, hum, HST.Jumping)
	end
	if why then
		emit(S, "jump", why)
	end
end

local function applySteer(S, dt)
	local want = S.moveDir
	if want.Magnitude < 1e-3 then
		S.curDir = ZERO
		return
	end
	local cur = S.curDir
	if S.snap or not S.opts.humanize or cur.Magnitude < 1e-3 or cur:Dot(want) < 0 then
		S.snap = false
		S.curDir = want
		return
	end
	local a = 1 - math.exp(-dt * 16)
	S.curDir = unitOr(cur:Lerp(want, a), want) * want.Magnitude
end

local function refreshMoveTo(S)
	if S.mode ~= "moveto" or S.paused then
		return
	end
	local hum, hrp = S.hum, S.hrp
	local d = S.curDir
	if d.Magnitude < 1e-3 then
		if S.mtActive then
			hum:MoveTo(hrp.Position)
			S.mtActive = false
			S.mtPoint = nil
		end
		return
	end
	local pt = S.movePoint or (hrp.Position + d.Unit * 6)
	if not S.mtPoint or (pt - S.mtPoint).Magnitude > 1 or now() - (S.mtT or 0) > 2 or (hum.WalkToPoint - pt).Magnitude > 1.5 then
		hum:MoveTo(pt)
		S.mtPoint, S.mtT, S.mtActive = pt, now(), true
	end
end

local function startDriver(S)
	local ok, ev = pcall(function()
		return RunService.PreSimulation
	end)
	if not ok or not ev then
		ev = RunService.Stepped
	end
	S.conns.driver = ev:Connect(function()
		if S.done then
			return
		end
		local hum = S.hum
		if not hum or not hum.Parent then
			return
		end
		if S.mode == "move" and not S.paused then
			hum:Move(S.curDir, false)
		end
		if now() < S.jumpUntil then
			hum.Jump = true
		end
	end)
end

local function getControls()
	local ok, c = pcall(function()
		local ps = LP:FindFirstChildOfClass("PlayerScripts") or LP:WaitForChild("PlayerScripts", 2)
		local pm = ps and ps:FindFirstChild("PlayerModule")
		if not pm then
			return nil
		end
		return require(pm):GetControls()
	end)
	if ok then
		return c
	end
	return nil
end

local MOVE_KEYS = {
	Enum.KeyCode.W, Enum.KeyCode.A, Enum.KeyCode.S, Enum.KeyCode.D,
	Enum.KeyCode.Up, Enum.KeyCode.Down, Enum.KeyCode.Left, Enum.KeyCode.Right,
}
local function userMoving(S)
	if UserInputService:GetFocusedTextBox() then
		return false
	end
	if S.controls and not S.controlsLocked then
		local ok, v = pcall(function()
			return S.controls:GetMoveVector()
		end)
		if ok and typeof(v) == "Vector3" and v.Magnitude > 0.1 then
			return true
		end
	end
	for _, k in ipairs(MOVE_KEYS) do
		if UserInputService:IsKeyDown(k) then
			return true
		end
	end
	return false
end

local function pauseReason(S)
	local hum, hrp = S.hum, S.hrp
	if hrp.Anchored or hum.PlatformStand or hum.WalkSpeed < 0.5 then
		return "frozen"
	end
	if S.opts.yieldToUser and userMoving(S) then
		return "user"
	end
	return nil
end

local function resetStuck(S, keepLevel)
	local lvl = (keepLevel and S.stk) and S.stk.level or 0
	S.stk = { t = now(), pos = S.hrp.Position, level = lvl }
end

local function stuckCheck(S, wanting)
	local k = S.stk
	if not wanting then
		k.t, k.pos = now(), S.hrp.Position
		return nil
	end
	local el = now() - k.t
	if el < 0.6 then
		return nil
	end
	local p = S.hrp.Position
	local moved = (p - k.pos).Magnitude
	local expect = math.max(S.hum.WalkSpeed, 1) * el
	k.t, k.pos = now(), p
	if moved < math.max(0.5, expect * 0.15) then
		k.level += 1
		return k.level
	end
	if moved > expect * 0.4 then
		k.level = math.max(0, k.level - 1)
	end
	return nil
end

local function recover(S, level, baseDir, midClimb)
	emit(S, "stuck", "level " .. level)
	local perp = V3(-baseDir.Z, 0, baseDir.X)
	local side = (level % 2 == 0) and 1 or -1
	if midClimb then
		S.ovr = { dir = unitOr(baseDir + perp * side * 0.6, baseDir), untilT = now() + 0.4 }
		return nil
	end
	if level == 1 then
		doJump(S)
	elseif level == 2 then
		doJump(S)
		S.ovr = { dir = unitOr(baseDir * 0.5 + perp * side, perp), untilT = now() + 0.45 }
	elseif level == 3 then
		S.ovr = { dir = -baseDir, untilT = now() + 0.5 }
	elseif level == 4 then
		return "recompute"
	elseif level == 5 then
		doJump(S)
		S.ovr = { dir = unitOr(baseDir * 0.3 - perp * side, perp), untilT = now() + 0.6 }
	else
		doJump(S)
		return "recompute"
	end
	return nil
end

local function tickCommon(S)
	if S.cancel then
		return "cancelled"
	end
	if now() > S.deadline then
		return "timeout"
	end
	if not alive(S) then
		return "died"
	end
	if now() - S.filterT > 3 then
		rebuildFilter(S)
	end
	if isArrived(S) then
		return "arrived"
	end
	return nil
end

local function legLoop(S, stepFn)
	resetStuck(S)
	S.ovr = nil
	local acc = math.huge
	while true do
		local dt = RunService.Heartbeat:Wait()
		if S.cancel then
			S.moveDir, S.curDir = ZERO, ZERO
			return false, "cancelled"
		end
		acc += dt
		if acc >= 1 / S.opts.tickRate then
			local ldt = math.min(acc, 0.5)
			acc = 0
			local r = tickCommon(S)
			if r then
				S.moveDir, S.curDir = ZERO, ZERO
				if r == "arrived" then
					return true, "arrived"
				end
				return false, r
			end
			local pz = pauseReason(S)
			if pz ~= S.pauseReason then
				S.pauseReason = pz
				emit(S, pz and "paused" or "resumed", pz)
			end
			if pz then
				S.moveDir = ZERO
				S.paused = (pz == "user")
				resetStuck(S, true)
				S.deadline += ldt * 0.5
			else
				S.paused = false
				if S.hum.Sit then
					doJump(S, "unseat")
				end
				local done, res = stepFn(ldt)
				if done ~= nil then
					if not done then
						S.moveDir, S.curDir = ZERO, ZERO
					end
					return done, res
				end
			end
		end
		applySteer(S, dt)
		refreshMoveTo(S)
	end
end

local function createPath(S)
	local a = S.agent
	local params = {
		AgentRadius = a.radius,
		AgentHeight = a.height,
		AgentCanJump = a.canJump,
		AgentCanClimb = a.canClimb,
		WaypointSpacing = a.spacing,
		Costs = S.opts.costs,
	}
	if PartialSupported then
		params.SupportPartialPath = true
		local ok, p = pcall(PathfindingService.CreatePath, PathfindingService, params)
		if ok and p then
			return p
		end
		PartialSupported = false
		params.SupportPartialPath = nil
	end
	local ok, p = pcall(PathfindingService.CreatePath, PathfindingService, params)
	if ok and p then
		return p
	end
	return PathfindingService:CreatePath()
end

local function convertWaypoints(raw)
	local out = {}
	for i, w in ipairs(raw) do
		local an = w.Action.Name
		local okL, label = pcall(function()
			return w.Label
		end)
		if not okL then
			label = nil
		end
		local kind = "walk"
		if an == "Jump" then
			kind = "jump"
		elseif an == "Climb" then
			kind = "climb"
		elseif an == "Custom" then
			kind = "custom"
		end
		if type(label) == "string" and string.find(string.lower(label), "climb", 1, true) then
			kind = "climb"
		end
		if kind == "walk" and i > 1 then
			local prev = raw[i - 1].Position
			if math.abs(w.Position.Y - prev.Y) > 2.5 and hdist(w.Position, prev) < 2 then
				kind = "climb"
			end
		end
		out[i] = { pos = w.Position, kind = kind, label = label }
	end
	return out
end

local function computePath(S, from, to, retried)
	local path = createPath(S)
	local ok = pcall(function()
		path:ComputeAsync(from, to)
	end)
	if not ok then
		return nil, "error"
	end
	local name = path.Status.Name
	if name == "Success" then
		local raw = path:GetWaypoints()
		if #raw == 0 then
			return nil, "empty"
		end
		return convertWaypoints(raw), name, path
	end
	if name == "ClosestNoPath" or name == "ClosestOutOfRange" then
		local okw, raw = pcall(function()
			return path:GetWaypoints()
		end)
		if okw and raw and #raw > 1 then
			return nil, "partial", path, convertWaypoints(raw)
		end
	end
	if name == "FailStartNotEmpty" and not retried then
		local nudge = unitOr(flat(to - from), V3(1, 0, 0)) * 1.5 + UP * 0.5
		return computePath(S, from + nudge, to, true)
	end
	return nil, name
end

local function setPath(S, wps, path)
	if S.conns.blocked then
		S.conns.blocked:Disconnect()
		S.conns.blocked = nil
	end
	if S.opts.humanize then
		for _, w in ipairs(wps) do
			w.reach = S.opts.waypointReach + (math.random() - 0.4) * 0.6
		end
	end
	S.wps, S.path, S.blocked = wps, path, false
	S.wi = (#wps >= 2) and 2 or 1
	if path then
		local ok, c = pcall(function()
			return path.Blocked:Connect(function(idx)
				if S.wps == wps and type(idx) == "number" and idx >= S.wi then
					S.blocked = true
				end
			end)
		end)
		if ok then
			S.conns.blocked = c
		end
	end
	drawPath(S)
end

local function directSafe(S, fromFoot, to)
	local d = flat(to - fromFoot)
	local L = d.Magnitude
	if L > S.opts.maxDirect then
		return false
	end
	if L < 0.5 then
		return true
	end
	local u = d / L
	local jh = jumpH(S)
	local tg = findGround(S, to, 12)
	local targetY = tg and tg.Y or to.Y
	if targetY - fromFoot.Y > jh - 0.5 then
		return false
	end
	local headH = math.max(S.charHeight - 0.6, 2)
	local a = fromFoot + UP * headH
	local b = V3(to.X, targetY + headH, to.Z)
	local hit = ray(S, a, b - a)
	if hit and (hit.Position - b).Magnitude > 1 then
		return false
	end
	local prevY = fromFoot.Y
	local s = 2
	while s < L do
		local p = fromFoot + u * s
		local g, inst = groundAt(S, V3(p.X, prevY, p.Z), 4.2, 4.2 + S.opts.maxDrop)
		if not g or isHazard(S, inst) then
			return false
		end
		if g.Y - prevY > jh - 0.5 then
			return false
		end
		prevY = g.Y
		s += 2
	end
	return true
end

local function goalCandidates(S, tp)
	local list = {}
	local function add(p)
		if not p then
			return
		end
		for _, q in ipairs(list) do
			if (q - p).Magnitude < 1 then
				return
			end
		end
		list[#list + 1] = p
	end
	local part = S.targetPart
	if part and part.Parent then
		local pos = S.hrp.Position
		local cp = closestPoint(part, pos)
		local out = unitOr(flat(pos - cp), ZERO)
		add((findGround(S, cp + out * (S.agent.radius + 0.5), 20)))
		add((findGround(S, V3(part.Position.X, aabbTop(part), part.Position.Z), 20)))
	end
	add((findGround(S, tp, 30)))
	add(tp)
	return list
end

local function findTrusses(S, a, b)
	local center = (a + b) / 2
	local size = V3(
		math.min(math.abs(a.X - b.X) + 80, 1000),
		math.min(math.abs(a.Y - b.Y) + 80, 1000),
		math.min(math.abs(a.Z - b.Z) + 80, 1000)
	)
	local ok, parts = pcall(function()
		return Workspace:GetPartBoundsInBox(CFrame.new(center), size, S.op)
	end)
	if not ok or not parts then
		return {}
	end
	local out = {}
	for _, p in ipairs(parts) do
		if isClimbable(p) then
			local top = aabbTop(p)
			if top > a.Y + 2.5 then
				out[#out + 1] = {
					part = p,
					score = hdist(a, p.Position) + hdist(p.Position, b) + math.max(0, b.Y - top) * 3,
				}
			end
		end
	end
	table.sort(out, function(x, y)
		return x.score < y.score
	end)
	return out
end

local function trussBase(S, tr, fromFoot)
	local topY, botY = aabbTop(tr), aabbBottom(tr)
	local y0
	if topY - botY < 3 then
		y0 = (topY + botY) / 2
	else
		y0 = math.clamp(fromFoot.Y + 3, botY + 2, topY - 1)
	end
	local cp = closestPoint(tr, V3(fromFoot.X, y0, fromFoot.Z))
	local out = unitOr(flat(fromFoot - cp), unitOr(flat(fromFoot - tr.Position), V3(1, 0, 0)))
	local p = cp + out * (S.agent.radius + 0.6)
	return (groundAt(S, V3(p.X, y0, p.Z), 0, 40))
end

local function trussExits(S, tr, towards)
	local topY = aabbTop(tr)
	local c = tr.Position
	local exits = {}
	local r = math.max(tr.Size.X, tr.Size.Z) * 0.5 + S.agent.radius + 0.8
	local base = unitOr(flat(towards - c), V3(1, 0, 0))
	for k = 0, 7 do
		local ang = k * math.pi / 4
		local cs, sn = math.cos(ang), math.sin(ang)
		local d = V3(base.X * cs - base.Z * sn, 0, base.X * sn + base.Z * cs)
		local p = c + d * r
		local g, inst = groundAt(S, V3(p.X, topY + 4, p.Z), 0, 7)
		if g and g.Y > topY - 2.5 and not isHazard(S, inst) then
			exits[#exits + 1] = g
		end
	end
	return exits
end

local function lookaheadDir(S, pos)
	local wps = S.wps
	if not wps then
		return nil
	end
	for j = S.wi, math.min(#wps, S.wi + 8) do
		local d = flat(wps[j].pos - pos)
		if d.Magnitude > 1.2 then
			return d.Unit
		end
	end
	return nil
end

local function climbDir(S, pos)
	if now() - (S.climbT or 0) > 0.4 then
		S.climbT = now()
		S.climbPart = nearestClimbable(S, pos, S.agent.radius + 2.5)
	end
	local d = S.climbPart and dirToPart(S.climbPart, pos)
	if not d then
		d = lookaheadDir(S, pos)
	end
	return d or S.lastWalkDir or V3(0, 0, -1)
end

local function nearTopOfClimb(S, foot)
	if S.climbPart and S.climbPart.Parent then
		return aabbTop(S.climbPart) - foot.Y < 4
	end
	local wps = S.wps
	if wps then
		for j = S.wi, math.min(#wps, S.wi + 6) do
			local w = wps[j]
			if w.kind == "climb" and w.pos.Y > foot.Y + 2 then
				return false
			end
		end
	end
	return true
end

local function autoJump(S, dir, dy, hd, foot, pos, isJumpWp)
	if not S.agent.canJump then
		return
	end
	local hum = S.hum
	if hum.FloorMaterial == AIR then
		return
	end
	local st = hum:GetState()
	if st == HST.Climbing or st == HST.Jumping or st == HST.Freefall then
		return
	end
	local u = unitOr(flat(dir), nil)
	if not u then
		return
	end
	local jh = jumpH(S)
	if isJumpWp and hd < 2.6 then
		doJump(S, "jump waypoint")
		return
	end
	if dy > 1.7 and dy < jh + 0.5 and hd < 3 then
		doJump(S, "ledge")
		return
	end
	local probe = S.agent.radius + 0.6
	local knee = ray(S, foot + UP * 1.5, u * probe)
	if knee and math.abs(knee.Normal.Y) < 0.6 then
		if not ray(S, foot + UP * math.max(jh - 0.4, 2), u * (probe + 0.6)) then
			doJump(S, "obstacle")
			return
		end
	end
	if dy > -2.5 and hd > 2.2 then
		local ahead = pos + u * (S.agent.radius * 0.5 + 0.9)
		if not ray(S, ahead, V3(0, -((pos.Y - foot.Y) + 4), 0)) then
			doJump(S, "gap")
		end
	end
end

local function runPath(S, leg)
	S.pathGen += 1
	local myGen = S.pathGen
	S.climbPart, S.needReplan = nil, nil
	local wps, path
	if leg.pre then
		wps, path = leg.pre.wps, leg.pre.path
		leg.pre = nil
	else
		S.moveDir, S.curDir = ZERO, ZERO
		local st
		wps, st, path = computePath(S, startPos(S), leg.goal)
		if not wps then
			return false, "nopath"
		end
	end
	setPath(S, wps, path)
	emit(S, "path", #wps .. " waypoints")
	local lastRe = now()
	local lastGoalPt = leg.final and targetPoint(S) or nil
	local lastResync = 0

	local function recompute(reason)
		if S.computing then
			return
		end
		S.computing = true
		task.spawn(function()
			local ok, w2, _, p2 = pcall(function()
				return computePath(S, startPos(S), leg.goal)
			end)
			S.computing = false
			if S.done or S.pathGen ~= myGen then
				return
			end
			if ok and w2 then
				setPath(S, w2, p2)
				emit(S, "recompute", reason)
			elseif reason ~= "periodic" then
				S.needReplan = reason
			end
		end)
	end

	return legLoop(S, function()
		if S.needReplan then
			local r = S.needReplan
			S.needReplan = nil
			return false, "blocked (" .. tostring(r) .. ")"
		end
		local hum, hrp = S.hum, S.hrp
		local pos = hrp.Position
		local foot = footPos(S)
		local climbing = hum:GetState() == HST.Climbing
		local onGround = hum.FloorMaterial ~= AIR

		if leg.final and lastGoalPt and S.opts.retargetDist > 0 then
			local tp = targetPoint(S)
			if tp and (tp - lastGoalPt).Magnitude > S.opts.retargetDist then
				lastGoalPt = tp
				leg.goal = (findGround(S, tp, 30)) or tp
				lastRe = now()
				recompute("target moved")
			end
		end
		if S.blocked and not S.computing then
			S.blocked = false
			lastRe = now()
			recompute("blocked")
		end
		if S.opts.recomputeEvery > 0 and now() - lastRe > S.opts.recomputeEvery and onGround and not climbing then
			lastRe = now()
			recompute("periodic")
		end

		local list = S.wps
		if now() - lastResync > 0.5 and not climbing then
			lastResync = now()
			for j = math.min(#list, S.wi + 8), S.wi + 1, -1 do
				local w = list[j]
				if hdist(pos, w.pos) < 2.5 and math.abs(w.pos.Y - foot.Y) < 2.5 then
					local tgt = w.pos + UP * (pos.Y - foot.Y)
					if not ray(S, pos, tgt - pos) then
						S.wi = j
						markCurrent(S)
					end
					break
				end
			end
		end

		local wp = list[S.wi]
		local guard = 0
		while wp and guard < 6 do
			guard += 1
			local dy = wp.pos.Y - foot.Y
			local hd = hdist(pos, wp.pos)
			local reached
			if wp.kind == "climb" or (climbing and math.abs(dy) > 1.5) then
				reached = hd < 3.5 and math.abs(dy) < 1.3
			else
				reached = hd < (wp.reach or S.opts.waypointReach) and dy < 2.2 and dy > -10
				if not reached and wp.kind == "walk" and S.wi < #list and hd < 4 and math.abs(dy) < 2.2 then
					local seg = flat(list[S.wi + 1].pos - wp.pos)
					if seg.Magnitude > 0.2 and flat(pos - wp.pos):Dot(seg) > 0 then
						reached = true
					end
				end
			end
			if not reached then
				break
			end
			if wp.kind == "jump" and onGround then
				doJump(S, "jump waypoint")
			end
			if wp.kind == "custom" and wp.label and S.opts.links[wp.label] then
				S.moveDir, S.curDir = ZERO, ZERO
				emit(S, "link", wp.label)
				local ok, res = pcall(S.opts.links[wp.label], wp, list[S.wi + 1], S.hum, S.hrp)
				if ok and res == false then
					return false, "link failed"
				end
				lastRe = now()
				recompute("link")
			end
			S.wi += 1
			markCurrent(S)
			wp = list[S.wi]
		end
		if not wp then
			return true, "ok"
		end

		local dy = wp.pos.Y - foot.Y
		local hd = hdist(pos, wp.pos)
		local toWp = flat(wp.pos - pos)
		local dir
		local climbMode = climbing or (wp.kind == "climb" and hd < 3.5)
		if climbMode then
			local toward = climbDir(S, pos)
			if dy > 0.6 then
				dir = toward
			elseif dy < -0.6 and climbing then
				dir = -toward
			else
				dir = unitOr(toWp, toward)
			end
			S.snap = true
			if not climbing and not S.climbPart then
				autoJump(S, dir, dy, hd, foot, pos, false)
			end
		else
			dir = unitOr(toWp, S.lastWalkDir or V3(0, 0, -1))
			S.lastWalkDir = dir
			autoJump(S, dir, dy, hd, foot, pos, wp.kind == "jump")
		end

		local lvl = stuckCheck(S, true)
		if lvl then
			if lvl >= S.opts.maxStuck then
				return false, "stuck"
			end
			local midClimb = climbing and not nearTopOfClimb(S, foot)
			if recover(S, lvl, dir, midClimb) == "recompute" then
				lastRe = now()
				recompute("stuck")
			end
		end
		if onGround and not climbing and not S.computing and now() - lastRe > 1.5 and (hd > 25 or foot.Y < wp.pos.Y - 10) then
			lastRe = now()
			recompute("off path")
		end
		if S.ovr then
			if now() < S.ovr.untilT then
				dir = S.ovr.dir
				S.snap = true
			else
				S.ovr = nil
			end
		end
		S.moveDir = dir
		S.movePoint = (not climbMode and not S.ovr) and wp.pos or nil
		return nil
	end)
end

local function runDirect(S, leg)
	local pos0 = S.hrp.Position
	emit(S, "direct", string.format("%.1f studs", hdist(pos0, leg.goal)))
	S.wps = nil
	clearMarkers(S)
	local t0 = now()
	local limit = leg.maxTime or (6 + hdist(pos0, leg.goal) / math.max(S.hum.WalkSpeed, 4) * 2.5)
	local gGround = (findGround(S, leg.goal, 12)) or leg.goal
	local lastG = leg.goal
	return legLoop(S, function()
		local pos, foot = S.hrp.Position, footPos(S)
		local g = leg.goal
		if leg.follow then
			g = targetPoint(S) or g
			if (g - lastG).Magnitude > 2 then
				lastG = g
				gGround = (findGround(S, g, 12)) or g
			end
		end
		local hd = hdist(pos, g)
		if hd < 1.0 then
			return true, "ok"
		end
		if now() - t0 > limit then
			return false, "direct timeout"
		end
		local dir = unitOr(flat(g - pos), nil)
		if not dir then
			return true, "ok"
		end
		autoJump(S, dir, gGround.Y - foot.Y, hd, foot, pos, false)
		local lvl = stuckCheck(S, true)
		if lvl then
			if lvl >= 4 then
				return false, "stuck"
			end
			recover(S, lvl, dir, false)
		end
		if S.ovr then
			if now() < S.ovr.untilT then
				dir = S.ovr.dir
				S.snap = true
			else
				S.ovr = nil
			end
		end
		S.moveDir = dir
		S.movePoint = (S.ovr == nil) and g or nil
		S.lastWalkDir = dir
		return nil
	end)
end

local function runClimb(S, leg)
	local tr = leg.part
	if not tr or not tr.Parent then
		return false, "truss gone"
	end
	local pos0 = S.hrp.Position
	if hdist(closestPoint(tr, pos0), pos0) > 8 then
		return false, "truss too far"
	end
	emit(S, "climb", tr.Name)
	S.wps = nil
	clearMarkers(S)
	local topY = aabbTop(tr)
	local t0 = now()
	local started = false
	local topT = nil
	local attempts = 0
	local lastY, lastYT = footPos(S).Y, now()
	local push = dirToPart(tr, pos0) or S.lastWalkDir or V3(0, 0, -1)
	local nearT, near = 0, nil
	return legLoop(S, function()
		local hum = S.hum
		local pos = S.hrp.Position
		local foot = footPos(S)
		local climbing = hum:GetState() == HST.Climbing
		local onGround = hum.FloorMaterial ~= AIR
		if climbing then
			started = true
		end
		if now() - nearT > 0.4 then
			nearT = now()
			near = nearestClimbable(S, pos, S.agent.radius + 2.5)
			if near and near ~= tr then
				topY = math.max(topY, aabbTop(near))
			end
		end
		local dTr = dirToPart(tr, pos) or (near and dirToPart(near, pos))
		if dTr then
			push = dTr
		end
		S.snap = true
		if climbing then
			if foot.Y > lastY + 0.3 then
				lastY, lastYT = foot.Y, now()
			end
		else
			lastY, lastYT = foot.Y, now()
		end
		local stalled = climbing and now() - lastYT > 0.6
		local atTop = foot.Y >= topY - 1.2 or pos.Y >= topY - 0.8 or (stalled and pos.Y > topY - 3.5)
		if atTop or (started and not climbing and onGround and foot.Y > topY - 3.5) then
			topT = topT or now()
			local exitDir = leg.exit and unitOr(flat(leg.exit - pos), push) or push
			S.moveDir = exitDir
			if onGround and not climbing and foot.Y > topY - 3.5 then
				if now() - topT > 0.25 then
					return true, "ok"
				end
			elseif climbing and now() - topT > 0.7 then
				doJump(S, "top out")
				topT = now() - 0.2
				attempts += 1
				if attempts > 5 then
					return false, "climbstuck"
				end
			end
			if now() - topT > 5 then
				return false, "climbstuck"
			end
			return nil
		end
		topT = nil
		S.moveDir = push
		if climbing then
			if now() - lastYT > 1.2 then
				local perp = V3(-push.Z, 0, push.X)
				local side = (math.floor(now() * 2) % 2 == 0) and 0.7 or -0.7
				S.moveDir = unitOr(push + perp * side, push)
			end
			if now() - lastYT > 4 then
				return false, "climbstuck"
			end
		else
			if started and onGround and foot.Y < topY - 3.5 then
				started = false
				t0 = now()
				attempts += 1
				if attempts > 3 then
					return false, "fell off truss"
				end
			end
			if not started and onGround and now() - t0 > 1.0 then
				doJump(S, "grab truss")
			end
			if not started and now() - t0 > 5 then
				return false, "cannot grab truss"
			end
		end
		return nil
	end)
end

local function runLeg(S, leg)
	if leg.type == "path" then
		return runPath(S, leg)
	elseif leg.type == "direct" then
		return runDirect(S, leg)
	elseif leg.type == "climb" then
		return runClimb(S, leg)
	end
	return false, "badleg"
end

local function plan(S)
	local budget = S.opts.searchBudget
	local used = 0
	local function cp(from, to)
		if used >= budget then
			return nil, "budget"
		end
		used += 1
		return computePath(S, from, to)
	end
	local tp = targetPoint(S)
	if not tp then
		return nil, "badtarget", true
	end
	local pos = S.hrp.Position
	local foot = footPos(S)
	local start = startPos(S)
	local jh = jumpH(S)
	S.lastPlanNearest = false
	S.atNearest = false
	emit(S, "computing")

	local function addDirect(legs, fromGround)
		if S.opts.allowDirect and directSafe(S, fromGround, tp) then
			legs[#legs + 1] = { type = "direct", goal = tp, follow = true }
		end
		return legs
	end

	if S.opts.allowDirect and (tp - pos).Magnitude < 14 and directSafe(S, foot, tp) then
		return { { type = "direct", goal = tp, follow = true } }
	end

	local cands = goalCandidates(S, tp)
	local partial
	local lastStatus = "NoPath"
	for _, g in ipairs(cands) do
		local wps, st, path, pw = cp(start, g)
		if wps then
			return { { type = "path", goal = g, final = true, pre = { wps = wps, path = path } } }
		end
		lastStatus = st or lastStatus
		if pw and not partial then
			partial = { wps = pw, path = path, goal = pw[#pw].pos }
		end
	end
	emit(S, "nopath", lastStatus)

	local myScore = (foot - tp).Magnitude

	local function partialPlan()
		if not partial or (partial.goal - tp).Magnitude > myScore - 2 then
			return nil
		end
		S.lastPlanNearest = true
		emit(S, "fallback", "partial path")
		return addDirect({ { type = "path", goal = partial.goal, pre = { wps = partial.wps, path = partial.path } } }, partial.goal)
	end

	local function nearestPlan()
		local list, seen = {}, {}
		local function add(x, z)
			local g, inst = groundAt(S, V3(x, tp.Y + 4, z), 0, 30)
			if g and not isHazard(S, inst) then
				local key = math.floor(g.X / 2) .. "," .. math.floor(g.Y / 2) .. "," .. math.floor(g.Z / 2)
				if not seen[key] then
					seen[key] = true
					list[#list + 1] = { pos = g, score = (g - tp).Magnitude }
				end
			end
		end
		local back = flat(start - tp)
		local L = back.Magnitude
		if L > 0.5 then
			local u = back / L
			local d = 3
			while d <= math.min(L, 36) do
				local p = tp + u * d
				add(p.X, p.Z)
				d += 3
			end
		end
		for ri, r in ipairs({ 3, 6, 10, 15, 22, 30 }) do
			for k = 0, 7 do
				local a = k * math.pi / 4 + ri * 0.4
				add(tp.X + math.cos(a) * r, tp.Z + math.sin(a) * r)
			end
		end
		table.sort(list, function(a, b)
			return a.score < b.score
		end)
		for _, c in ipairs(list) do
			if c.score >= myScore - 1.5 then
				S.atNearest = true
				return nil
			end
			local wps, _, path = cp(start, c.pos)
			if wps then
				S.lastPlanNearest = true
				emit(S, "fallback", string.format("nearest reachable %.1f from target", c.score))
				return addDirect({ { type = "path", goal = c.pos, pre = { wps = wps, path = path } } }, c.pos)
			end
			if used >= budget then
				break
			end
		end
		return nil
	end

	local function trussPlan()
		local list = findTrusses(S, foot, tp)
		for i = 1, math.min(#list, 4) do
			if used >= budget then
				break
			end
			local tr = list[i].part
			local base = trussBase(S, tr, foot)
			if base then
				local wA, _, pA = cp(start, base + UP * 0.1)
				if wA then
					local exits = trussExits(S, tr, tp)
					local goal1 = cands[1] or tp
					for e = 1, math.min(#exits, 2) do
						local ex = exits[e]
						local wB = cp(ex + UP * 2.5, goal1)
						if wB or (ex - tp).Magnitude < 12 then
							emit(S, "fallback", "via truss " .. tr:GetFullName())
							local legs = {
								{ type = "path", goal = base, pre = { wps = wA, path = pA } },
								{ type = "climb", part = tr, exit = ex },
							}
							if wB then
								legs[3] = { type = "path", goal = goal1, final = true }
							else
								addDirect(legs, ex)
							end
							return legs
						end
					end
				end
			end
		end
		return nil
	end

	local order
	if tp.Y - foot.Y > jh then
		order = { trussPlan, partialPlan, nearestPlan }
	else
		order = { partialPlan, nearestPlan, trussPlan }
	end
	for _, f in ipairs(order) do
		local legs = f()
		if legs then
			return legs
		end
	end

	local far = hdist(start, tp)
	if far > 300 then
		local u = flat(tp - start).Unit
		for _, frac in ipairs({ 0.5, 0.3 }) do
			local mid = start + u * (far * frac)
			local g = groundAt(S, V3(mid.X, math.max(start.Y, tp.Y) + 60, mid.Z), 0, 300)
			if g then
				local wps, _, path = cp(start, g)
				if wps then
					emit(S, "fallback", "staged mid point")
					return { { type = "path", goal = g, pre = { wps = wps, path = path } } }
				end
			end
		end
	end

	if S.atNearest then
		return nil, "unreachable", true
	end
	return nil, (lastStatus == "NoPath") and "nopath" or ("nopath:" .. tostring(lastStatus)), false
end

local function waitRespawn(S)
	if not S.opts.respawn or S.respawns >= S.opts.maxRespawns then
		return false
	end
	S.respawns += 1
	emit(S, "respawn", S.respawns)
	S.moveDir, S.curDir = ZERO, ZERO
	clearMarkers(S)
	local dead = S.char
	local t0 = now()
	while now() - t0 < 30 do
		if S.cancel then
			return false
		end
		local ch = LP.Character
		if ch and ch ~= dead and refreshChar(S) then
			local w = now()
			while now() - w < 1 and not S.cancel do
				task.wait(0.1)
			end
			S.deadline += now() - t0
			return alive(S)
		end
		task.wait(0.25)
	end
	return false
end

local function cleanup(S)
	S.done = true
	for _, c in pairs(S.conns) do
		pcall(function()
			c:Disconnect()
		end)
	end
	S.conns = {}
	pcall(function()
		if S.hum and S.hum.Parent then
			S.hum:Move(ZERO, false)
			if S.mode == "moveto" and S.hrp then
				S.hum:MoveTo(S.hrp.Position)
			end
		end
	end)
	if S.controlsLocked and S.controls then
		pcall(function()
			S.controls:Enable()
		end)
		S.controlsLocked = false
	end
	clearMarkers(S)
end

local function runSession(S)
	local t0 = now()
	while not refreshChar(S) do
		if S.cancel then
			return false, "cancelled"
		end
		if now() - t0 > 10 then
			return false, "nocharacter"
		end
		task.wait(0.2)
	end
	local tp = targetPoint(S)
	if not tp then
		return false, "badtarget"
	end
	local dist = (tp - S.hrp.Position).Magnitude
	S.deadline = now() + (S.opts.timeout or math.clamp(20 + dist / math.max(S.hum.WalkSpeed, 6) * 3, 25, 300))
	if S.opts.lockControls or S.opts.yieldToUser then
		S.controls = getControls()
		if S.opts.lockControls and S.controls then
			S.controlsLocked = pcall(function()
				S.controls:Disable()
			end)
		end
	end
	startDriver(S)
	emit(S, "start", string.format("%.0f studs", dist))

	local replans = 0
	local bestDist = dist
	while true do
		local r = tickCommon(S)
		if r == "arrived" then
			return true, "arrived"
		elseif r == "died" then
			if not waitRespawn(S) then
				return false, "died"
			end
			replans = 0
		elseif r then
			return false, r
		else
			S.moveDir, S.curDir = ZERO, ZERO
			local legs, why, fatal = plan(S)
			if not legs then
				if fatal then
					if why == "unreachable" and S.opts.acceptNearest then
						return true, "nearest"
					end
					return false, why
				end
				replans += 1
				if replans > S.opts.maxReplans then
					return false, why or "nopath"
				end
				emit(S, "retry", why)
				local w = now()
				while now() - w < 1 and not S.cancel do
					RunService.Heartbeat:Wait()
				end
			else
				local failReason
				for _, leg in ipairs(legs) do
					local ok, res = runLeg(S, leg)
					if res == "arrived" then
						return true, "arrived"
					end
					if res == "cancelled" or res == "timeout" then
						return false, res
					end
					if not ok then
						failReason = res
						break
					end
				end
				if failReason ~= "died" then
					if alive(S) and isArrived(S) then
						return true, "arrived"
					end
					local p = targetPoint(S)
					local d = p and (p - S.hrp.Position).Magnitude or bestDist
					if d < bestDist - 10 then
						bestDist = d
						replans = 0
					end
					replans += 1
					local why2 = failReason or "unreachable"
					if replans > S.opts.maxReplans then
						if S.opts.acceptNearest and S.lastPlanNearest then
							return true, "nearest"
						end
						return false, why2
					end
					emit(S, "replan", why2)
				end
			end
		end
	end
end

function SmartWalk.to(target, opts)
	if target == nil then
		return false, "badtarget"
	end
	opts = buildOpts(opts)
	local prev = Active
	if prev and not prev.done then
		prev.cancel = true
		local t = now()
		while not prev.done and now() - t < 3 do
			task.wait()
		end
	end
	local S = newSession(target, opts)
	Active = S
	local ok, a, b = xpcall(runSession, function(e)
		return tostring(e) .. "\n" .. debug.traceback()
	end, S)
	cleanup(S)
	if Active == S then
		Active = nil
	end
	if not ok then
		warn("[SmartWalk] internal error: " .. tostring(a))
		emit(S, "error", a)
		return false, "error"
	end
	emit(S, (b == "arrived") and "arrived" or (a and "done" or "failed"), b)
	return a, b
end

function SmartWalk.toAsync(target, opts, callback)
	task.spawn(function()
		local ok, why = SmartWalk.to(target, opts)
		if callback then
			pcall(callback, ok, why)
		end
	end)
end

function SmartWalk.follow(list, opts)
	opts = opts or {}
	local token = {}
	FollowToken = token
	for i, item in ipairs(list) do
		if FollowToken ~= token then
			return false, "cancelled", i
		end
		local tgt, o = item, opts
		if type(item) == "table" then
			tgt = item.target or item[1]
			o = {}
			for k, v in pairs(opts) do
				o[k] = v
			end
			for k, v in pairs(item) do
				if k ~= "target" and k ~= 1 then
					o[k] = v
				end
			end
		end
		local ok, why = SmartWalk.to(tgt, o)
		if opts.onPoint then
			pcall(opts.onPoint, i, ok, why)
		end
		if FollowToken ~= token then
			return false, "cancelled", i
		end
		if not ok and (why == "cancelled" or not opts.continueOnFail) then
			FollowToken = nil
			return false, why, i
		end
		if opts.pause and opts.pause > 0 then
			task.wait(opts.pause)
		end
	end
	if FollowToken == token then
		FollowToken = nil
	end
	return true, "done", #list
end

function SmartWalk.stop()
	FollowToken = nil
	if Active then
		Active.cancel = true
	end
end

function SmartWalk.isWalking()
	return Active ~= nil and not Active.done
end

function SmartWalk.status()
	return Active and Active.status or "idle"
end

function SmartWalk.canReach(target, opts)
	local S = newSession(target, buildOpts(opts))
	S.mode = "move"
	if not refreshChar(S) then
		return false, "nocharacter"
	end
	local tp = targetPoint(S)
	if not tp then
		return false, "badtarget"
	end
	local start = startPos(S)
	local last = "NoPath"
	for _, g in ipairs(goalCandidates(S, tp)) do
		local wps, st = computePath(S, start, g)
		if wps then
			return true, #wps, wps
		end
		last = st or last
	end
	return false, last
end

function SmartWalk.avoid(part, label)
	local m = Instance.new("PathfindingModifier")
	m.Label = label or "SmartWalkAvoid"
	m.Parent = part
	return m
end

function SmartWalk.passThrough(part)
	local m = Instance.new("PathfindingModifier")
	m.PassThrough = true
	m.Parent = part
	return m
end

local G = (getgenv and getgenv()) or _G
if type(G.SmartWalk) == "table" and G.SmartWalk ~= SmartWalk and type(G.SmartWalk.stop) == "function" then
	pcall(G.SmartWalk.stop)
end
G.SmartWalk = SmartWalk

return SmartWalk
