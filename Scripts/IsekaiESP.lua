local env = getgenv()
if env.__ESPStop then pcall(env.__ESPStop) end
local lp = game.Players.LocalPlayer
local folder = Instance.new("Folder")
folder.Name = "_esp"
folder.Parent = (gethui and gethui()) or game:GetService("CoreGui")
local running = true
env.__ESPStop = function() running = false folder:Destroy() end

local COLORS = {
    Fuse = Color3.fromRGB(255, 200, 40), Battery = Color3.fromRGB(80, 220, 255), Flashlight = Color3.fromRGB(255, 255, 255),
    Puzzle = Color3.fromRGB(190, 120, 255), Exit = Color3.fromRGB(60, 255, 90), Gunter = Color3.fromRGB(255, 40, 40),
    GasCan = Color3.fromRGB(255, 120, 40), Other = Color3.fromRGB(200, 200, 200),
}
local tags = {}
local function stage() return workspace:GetAttribute("Stage") or 1 end
local function stageOk(m) local s = m:GetAttribute("Stages") return s == nil or tostring(s):find(tostring(stage()), 1, true) ~= nil end
local function anchorPart(m)
    if m:IsA("BasePart") then return m end
    return m.PrimaryPart or m:FindFirstChild("Body") or m:FindFirstChildWhichIsA("BasePart", true)
end
local function tag(m, text, color)
    if env.__ESPFocus then
        local keep = false
        for _, w in ipairs(env.__ESPFocus) do if text:lower():find(w:lower(), 1, true) then keep = true break end end
        if not keep then return end
    end
    local p = anchorPart(m)
    if not p then return end
    local t = tags[m]
    if not t then
        local bb = Instance.new("BillboardGui")
        bb.AlwaysOnTop = true
        bb.Size = UDim2.fromOffset(160, 34)
        bb.StudsOffset = Vector3.new(0, 2.5, 0)
        bb.Adornee = p
        bb.Parent = folder
        local lbl = Instance.new("TextLabel")
        lbl.BackgroundTransparency = 1
        lbl.Size = UDim2.fromScale(1, 1)
        lbl.Font = Enum.Font.GothamBold
        lbl.TextSize = 13
        lbl.TextStrokeTransparency = 0.3
        lbl.Parent = bb
        t = { bb = bb, lbl = lbl, part = p }
        tags[m] = t
    end
    t.seen = true
    t.lbl.TextColor3 = color
    local r = lp.Character and lp.Character:FindFirstChild("HumanoidRootPart")
    local d = r and (p.Position - r.Position).Magnitude or 0
    t.lbl.Text = string.format("%s [%dm]", text, d)
end
local gunterHL
task.spawn(function()
    while running do
        pcall(function()
            for _, t in pairs(tags) do t.seen = false end
            local pk = workspace:FindFirstChild("Map") and workspace.Map:FindFirstChild("Pickups")
            for _, m in ipairs(pk and pk:GetChildren() or {}) do
                local cd = m:FindFirstChildWhichIsA("ClickDetector", true)
                if stageOk(m) and cd and cd.MaxActivationDistance > 0 then
                    local k = m:GetAttribute("Kind") or "Other"
                    tag(m, k == "Battery" and "Battery" or m.Name, COLORS[k] or COLORS.Other)
                end
            end
            local po = workspace:FindFirstChild("PuzzleObjects")
            for _, f in ipairs(po and po:GetChildren() or {}) do
                if stageOk(f) then
                    local main = f:FindFirstChild("FuseBox") or f:FindFirstChild("RadioButton") or f:FindFirstChild("PlayButton")
                        or f:FindFirstChild("Panel1") or f:FindFirstChild("Dial1") or f:FindFirstChild("KeyEnter") or f:FindFirstChild("Lever")
                        or f:FindFirstChild("Breaker1") or f:FindFirstChild("SeqStart") or f:FindFirstChild("ChargerPad") or f:FindFirstChild("Cover")
                        or f:FindFirstChildWhichIsA("BasePart", true)
                    if main then tag(main, f.Name:gsub("_E%d+$", ""), COLORS.Puzzle) end
                end
            end
            for _, f in ipairs(po and po:GetChildren() or {}) do
                if f.Name:match("^Beacons_") and stageOk(f) then
                    for _, sp in ipairs(f:GetDescendants()) do
                        local n = sp:IsA("BasePart") and sp.Name:match("^Speaker(%d+)$")
                        if n then tag(sp, "BEACON " .. n .. " (ring " .. n .. ")", Color3.fromRGB(255, 80, 200)) end
                    end
                end
            end
            if env.__ESPArg then
                local decor = workspace.Map:FindFirstChild("Decor")
                local i = 0
                for _, d in ipairs(decor and decor:GetChildren() or {}) do
                    if d.Name == "Sigil" or d:GetAttribute("Sigil") then i += 1 tag(d, "SIGIL " .. i, Color3.fromRGB(0, 255, 255)) end
                end
                local mir = workspace.Map:FindFirstChild("Props") and workspace.Map.Props:FindFirstChild("Mirror")
                if mir then tag(mir, "MIRROR", Color3.fromRGB(0, 255, 255)) end
                local pb = workspace.Map:FindFirstChild("Doors") and workspace.Map.Doors:FindFirstChild("Door_PortalBw")
                if pb then tag(pb:FindFirstChild("Slab", true) or pb, "ARG DOOR (needs USB)", Color3.fromRGB(0, 255, 255)) end
            end
            local et = workspace:FindFirstChild("EscapeTriggers")
            for _, t in ipairs(et and et:GetChildren() or {}) do
                if t:GetAttribute("ExitStage") == stage() then tag(t, "EXIT", COLORS.Exit) end
            end
            for _, d in ipairs(workspace:GetChildren()) do
                if d:IsA("Highlight") and d.Name:find("GasCan") and d.Adornee then tag(d.Adornee, "Gas can", COLORS.GasCan) end
            end
            local g = workspace:FindFirstChild("Enemy") and workspace.Enemy:FindFirstChild("IsekaiGunter")
            if g then
                if not gunterHL or gunterHL.Adornee ~= g then
                    if gunterHL then gunterHL:Destroy() end
                    gunterHL = Instance.new("Highlight")
                    gunterHL.FillColor = COLORS.Gunter
                    gunterHL.OutlineColor = COLORS.Gunter
                    gunterHL.FillTransparency = 0.6
                    gunterHL.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
                    gunterHL.Adornee = g
                    gunterHL.Parent = folder
                end
                tag(g, "GUNTER (" .. tostring(g:GetAttribute("State")) .. ")", COLORS.Gunter)
            end
            for m, t in pairs(tags) do
                if not t.seen or not m.Parent then t.bb:Destroy() tags[m] = nil end
            end
        end)
        task.wait(0.25)
    end
end)
return "ESP on"
