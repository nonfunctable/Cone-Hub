local env = getgenv()
if env.__ArgScanRunning then return end
env.__ArgScanRunning = true
repeat task.wait() until game:IsLoaded()
local placeId = game.PlaceId
local file = "ConeHub/arg_scan_" .. placeId .. ".txt"
local hitsFile = "ConeHub/arg_codes_" .. placeId .. ".txt"
local seen, lines, hits = {}, {}, {}
local function flagCode(s, where)
    for tok in s:gmatch("[%w%-_]+") do
        if #tok >= 5 and #tok <= 24 then
            local hasD, hasL = tok:find("%d") ~= nil, tok:find("%a") ~= nil
            local caps = tok == tok:upper() and hasL
            if (hasD and hasL) or (caps and #tok >= 6) then
                local k = tok:lower()
                if not hits[k] then
                    hits[k] = true
                    pcall(appendfile, hitsFile, tok .. "\t" .. where .. "\n")
                end
            end
        end
    end
    if s:lower():find("code") then pcall(appendfile, hitsFile, "[mentions code] " .. s:sub(1, 200) .. "\t" .. where .. "\n") end
end
local function add(where, s)
    s = tostring(s or "")
    if #s < 2 or seen[s] then return end
    seen[s] = true
    local line = where .. " :: " .. s:gsub("\n", " \\n "):sub(1, 400)
    lines[#lines + 1] = line
    pcall(appendfile, file, line .. "\n")
    flagCode(s, where)
end
pcall(writefile, file, "scan of " .. placeId .. " at " .. os.time() .. "\n")
pcall(writefile, hitsFile, "")
local function scanInst(d)
    local ok = pcall(function()
        if d:IsA("TextLabel") or d:IsA("TextButton") or d:IsA("TextBox") then add(d:GetFullName(), d.Text)
        elseif d:IsA("StringValue") then add("SV " .. d:GetFullName(), d.Value)
        elseif d:IsA("IntValue") or d:IsA("NumberValue") then add("NV " .. d:GetFullName(), d.Value)
        elseif d:IsA("Decal") or d:IsA("Texture") then add("IMG " .. d:GetFullName(), d.Texture)
        elseif d:IsA("ImageLabel") or d:IsA("ImageButton") then add("IMG " .. d:GetFullName(), d.Image)
        elseif d:IsA("Sound") then add("SND " .. d:GetFullName(), d.SoundId)
        elseif d:IsA("ProximityPrompt") then add("PP " .. d:GetFullName(), d.ActionText .. " / " .. d.ObjectText)
        end
        for k, v in pairs(d:GetAttributes()) do
            if type(v) == "string" or type(v) == "number" then add("ATTR " .. d:GetFullName() .. "." .. k, v) end
        end
        if #d.Name >= 5 then flagCode(d.Name, "NAME " .. d:GetFullName()) end
    end)
    return ok
end
local roots = { workspace, game:GetService("ReplicatedStorage"), game:GetService("Lighting"), game:GetService("ReplicatedFirst"),
    game:GetService("StarterGui"), game:GetService("SoundService"), game.Players.LocalPlayer:WaitForChild("PlayerGui") }
for _, r in ipairs(roots) do
    for i, d in ipairs(r:GetDescendants()) do
        scanInst(d)
        if i % 3000 == 0 then task.wait() end
    end
    r.DescendantAdded:Connect(function(d) task.defer(scanInst, d) end)
end
task.spawn(function()
    while true do
        task.wait(2)
        for _, r in ipairs(roots) do
            for _, d in ipairs(r:GetDescendants()) do
                if d:IsA("TextLabel") or d:IsA("TextButton") then if not seen[d.Text] then scanInst(d) end end
            end
        end
    end
end)
pcall(function()
    game:GetService("TextChatService").MessageReceived:Connect(function(m) add("CHAT " .. tostring(m.TextSource and m.TextSource.Name), m.Text) end)
end)
task.spawn(function()
    if not decompile then return end
    for _, r in ipairs(roots) do
        for _, s in ipairs(r:GetDescendants()) do
            if s:IsA("LocalScript") or s:IsA("ModuleScript") then
                local ok, src = pcall(decompile, s)
                if ok and type(src) == "string" then
                    pcall(writefile, "ConeHub/argsrc_" .. placeId .. "_" .. s.Name:gsub("[^%w]", "_") .. ".lua", src)
                    for str in src:gmatch('"([^"\n]+)"') do flagCode(str, "SRC " .. s:GetFullName()) end
                end
                task.wait()
            end
        end
    end
end)
print("[ArgScanner] running in", placeId)
