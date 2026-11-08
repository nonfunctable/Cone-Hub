local env = getgenv()
if env.__MoleStop then pcall(env.__MoleStop) end
local running = true
env.__MoleStop = function() running = false end
local p = game.Players.LocalPlayer
local WhackMole = game:GetService("ReplicatedStorage").Remotes.WhackMole
local booth = workspace.Lobby.Booth_1
local pp = booth.Counter:FindFirstChildWhichIsA("ProximityPrompt", true)
env.__MoleStats = env.__MoleStats or { rounds = 0, start = p:GetAttribute("Coins") or 0, t0 = os.clock() }
local hits = {}
task.spawn(function()
    while running do
        pcall(function()
            if p:GetAttribute("MG_Id") ~= "topos" then
                local r = p.Character and p.Character:FindFirstChild("HumanoidRootPart")
                local h = p.Character and p.Character:FindFirstChildOfClass("Humanoid")
                if r and h and (booth.Counter.Position - r.Position).Magnitude > pp.MaxActivationDistance - 1 then
                    h:MoveTo(booth.Counter.Position) h.MoveToFinished:Wait()
                end
                fireproximityprompt(pp)
                task.wait(1)
                if p:GetAttribute("MG_Id") == "topos" then env.__MoleStats.rounds += 1 end
                return
            end
            local f = booth:FindFirstChild("ToposSessions")
            local sess = f and f:FindFirstChild(tostring(p.UserId))
            if not sess then return end
            for _, m in ipairs(sess:GetChildren()) do
                local id = tonumber(m.Name:match("^Mole_(%d+)$"))
                local kind = tostring(m:GetAttribute("Kind") or "normal"):lower()
                if id and m:GetAttribute("Up") == true and kind == "normal" and os.clock() - (hits[m] or 0) > 0.35 then
                    hits[m] = os.clock()
                    task.delay(0.08 + math.random() * 0.12, function() WhackMole:FireServer(id) end)
                end
            end
        end)
        task.wait(0.05)
    end
end)
return "mole bot running"
