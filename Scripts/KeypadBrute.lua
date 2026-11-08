local env = getgenv()
env.__KBStop = false
local kp = workspace.PuzzleObjects.Keypad_E1
local door = workspace.Map.Doors.Door_S4_E1
local STAND = Vector3.new(40, 3, -42)
local function lampGreen()
    for _, p in ipairs(door:GetDescendants()) do if p.Name == "Lamp" and p:IsA("BasePart") then return p.BrickColor.Name:lower():find("green") ~= nil end end
end
local okSeen = false
local conn = kp.DescendantAdded:Connect(function(d) if d.Name == "KeypadOk" then okSeen = true end end)
local function hrp() local c = game.Players.LocalPlayer.Character return c and c:FindFirstChild("HumanoidRootPart") end
local function near() local r = hrp() return r and (kp.KeyEnter.Position - r.Position).Magnitude < 9 end
local cds = {}
for i = 0, 9 do cds[tostring(i)] = kp["Key" .. i]:FindFirstChildWhichIsA("ClickDetector") end
local enter = kp.KeyEnter:FindFirstChildWhichIsA("ClickDetector")
local clear = kp.KeyClear:FindFirstChildWhichIsA("ClickDetector")
env.__KBIdx = env.__KBIdx or 0
local skip = {}
for _, c in ipairs({ "4143", "1234", "6765", "0020", "0005", "1010", "0101", "0010", "2020", "0065", "0317", "3170", "1703", "0067", "0023", "0012", "0013", "6500", "4650", "0465", "1317", "0417", "1715" }) do skip[c] = true end
env.__KB = "starting"
task.spawn(function()
    while not env.__KBStop and env.__KBIdx <= 9999 do
        if not near() then
            env.__KB = "walking back to keypad at idx " .. env.__KBIdx
            if env.__ITwalk then pcall(env.__ITwalk, STAND, 3) end
            task.wait(1)
        else
            local code = string.format("%04d", env.__KBIdx)
            if not skip[code] then
                pcall(fireclickdetector, clear, 0) task.wait(0.06)
                for ch in code:gmatch("%d") do pcall(fireclickdetector, cds[ch], 0) task.wait(0.06) end
                pcall(fireclickdetector, enter, 0) task.wait(0.12)
                if okSeen or lampGreen() then
                    task.wait(0.5)
                    env.__KB = "OPEN near " .. code .. " (idx " .. env.__KBIdx .. ")"
                    pcall(writefile, "ConeHub/keypad_found.txt", code)
                    conn:Disconnect()
                    return
                end
            end
            env.__KBIdx += 1
            if env.__KBIdx % 50 == 0 then env.__KB = "at " .. code end
        end
    end
    conn:Disconnect()
    if not env.__KBStop then env.__KB = "exhausted" end
end)
return "keypad brute started at " .. env.__KBIdx
