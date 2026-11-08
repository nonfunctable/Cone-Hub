
local DEMO = "dryrun"
local PART_NAME = "SpawnLocation"
local PLAYER_NAME = ""

local SmartWalk = loadstring(readfile("ConeHub/lib/SmartWalk.lua"))()

local Players = game:GetService("Players")
local lp = Players.LocalPlayer
local hrp = (lp.Character or lp.CharacterAdded:Wait()):WaitForChild("HumanoidRootPart")

local opts = {
	debug = true,
	verbose = true,
	onStatus = function(status, info)
		if status == "stuck" or status == "fallback" then
			warn("SmartWalk " .. status .. ": " .. info)
		end
	end,
}

if DEMO == "dryrun" then
	local target = hrp.Position + hrp.CFrame.LookVector * 60
	local ok, n = SmartWalk.canReach(target)
	print("canReach 60 studs ahead:", ok, n)
elseif DEMO == "ahead" then
	local target = hrp.Position + hrp.CFrame.LookVector * 40
	local ok, why = SmartWalk.to(target, opts)
	print("walk ahead ->", ok, why)
elseif DEMO == "route" then
	local o = hrp.Position
	local route = {
		o + Vector3.new(30, 0, 0),
		o + Vector3.new(30, 0, 30),
		{ target = o + Vector3.new(0, 0, 30), reach = 2 },
		o,
	}
	local fopts = table.clone(opts)
	fopts.pause = 1
	fopts.continueOnFail = true
	fopts.onPoint = function(i, ok, why)
		print(("point %d -> %s (%s)"):format(i, tostring(ok), why))
	end
	print("route ->", SmartWalk.follow(route, fopts))
elseif DEMO == "part" then
	local part = workspace:FindFirstChild(PART_NAME, true)
	if not part or not part:IsA("BasePart") then
		warn("no BasePart named " .. PART_NAME)
		return
	end
	local o = table.clone(opts)
	o.acceptNearest = true
	print("walk to part ->", SmartWalk.to(part, o))
elseif DEMO == "follow_player" then
	local other = Players:FindFirstChild(PLAYER_NAME)
	if not other then
		warn("player not found: " .. PLAYER_NAME)
		return
	end
	local o = table.clone(opts)
	o.reach = 6
	o.timeout = 60
	SmartWalk.toAsync(function()
		local c = other.Character
		local r = c and c:FindFirstChild("HumanoidRootPart")
		return r and r.Position
	end, o, function(ok, why)
		print("follow player ->", ok, why)
	end)
end
