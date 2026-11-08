local env = getgenv()
if env.__ITStop then pcall(env.__ITStop) end
local TweenService = game:GetService("TweenService")
local lp = game.Players.LocalPlayer
local running = true
local status, log = "start", {}
local function slog(s) log[#log + 1] = string.format("%.0f %s", os.clock(), s) if #log > 30 then table.remove(log, 1) end end
env.__ITStatus = function() return status, log end
env.__ITStop = function() running = false end
local SPEED = 18
local function hrp() local c = lp.Character return c and c:FindFirstChild("HumanoidRootPart") end
local function posOf(m) if m:IsA("BasePart") then return m.Position end local ok, p = pcall(function() return m:GetPivot().Position end) return ok and p end
local function cdOf(m) for _, d in ipairs(m:GetDescendants()) do if d:IsA("ClickDetector") then return d end end end
local function stage() return workspace:GetAttribute("Stage") or 1 end
local function stageOk(m) local s = m:GetAttribute("Stages") return s == nil or tostring(s):find(tostring(stage()), 1, true) ~= nil end

local function tweenTo(p, standOff)
    local r = hrp()
    if not r then return false end
    local target = Vector3.new(p.X, math.max(p.Y, 3), p.Z)
    local flat = Vector3.new(target.X - r.Position.X, 0, target.Z - r.Position.Z)
    if standOff and flat.Magnitude > standOff then target = target - flat.Unit * standOff end
    target = Vector3.new(target.X, 3, target.Z)
    local dist = (target - r.Position).Magnitude
    if dist < 1 then return true end
    local look = flat.Magnitude > 0.5 and flat.Unit or r.CFrame.LookVector
    local tw = TweenService:Create(r, TweenInfo.new(dist / SPEED, Enum.EasingStyle.Linear), { CFrame = CFrame.lookAt(target, target + look) })
    local noclip = game:GetService("RunService").Stepped:Connect(function()
        for _, part in ipairs(lp.Character:GetDescendants()) do if part:IsA("BasePart") then part.CanCollide = false end end
        r.AssemblyLinearVelocity = Vector3.zero
    end)
    tw:Play()
    tw.Completed:Wait()
    noclip:Disconnect()
    return true
end

local function clickAt(m, label)
    local p = posOf(m)
    if not p then return end
    status = "Going to " .. label
    tweenTo(p, 3)
    task.wait(0.25 + math.random() * 0.25)
    local cd = cdOf(m)
    if cd then pcall(fireclickdetector, cd, 0) slog("clicked " .. label) end
    task.wait(0.5)
end

local function kind(k)
    local out = {}
    for _, m in ipairs(workspace.Map.Pickups:GetChildren()) do
        local cd = cdOf(m)
        if m:GetAttribute("Kind") == k and stageOk(m) and cd and cd.MaxActivationDistance > 0 then out[#out + 1] = m end
    end
    return out
end

task.spawn(function()
    while running do
        local ok, err = pcall(function()
            if lp:GetAttribute("Caught") or lp:GetAttribute("Escaping") then status = "caught/escaping" task.wait(1) return end
            if not lp:GetAttribute("HasFlashlight") then local f = kind("Flashlight")[1] if f then clickAt(f, "flashlight") return end end
            if (lp:GetAttribute("BatteryLevel") or 100) < 30 then local b = kind("Battery")[1] if b then clickAt(b, "battery") return end end
            local fuses = kind("Fuse")
            if #fuses > 0 then clickAt(fuses[1], "fuse " .. fuses[1].Name) return end
            if (lp:GetAttribute("Fuses") or 0) > 0 then
                for _, f in ipairs(workspace.PuzzleObjects:GetChildren()) do
                    if f.Name:match("^Fuses_") and stageOk(f) and f:FindFirstChild("FuseBox") then clickAt(f.FuseBox, "fuse box") return end
                end
            end
            for _, t in ipairs(workspace.EscapeTriggers:GetChildren()) do
                if t:GetAttribute("ExitStage") == stage() then
                    status = "Exit (stage " .. stage() .. ")"
                    tweenTo(t.Position)
                    task.wait(1)
                    return
                end
            end
            status = "idle stage " .. stage()
            task.wait(1)
        end)
        if not ok then slog("err " .. tostring(err)) task.wait(1) end
        task.wait(0.2)
    end
end)
return "IsekaiTween started"
