local env = getgenv()
if env.__MSStop then pcall(env.__MSStop) end
local running = true
env.__MSStop = function() running = false end
env.__MSStatus = "waiting for duel"
local lp = game.Players.LocalPlayer
local N = 8

local function idx(r, c) return r * N + c + 1 end
local function rc(p) return (p - 1) // N, (p - 1) % N end
local function nbrs(p)
    local r, c = rc(p)
    local t = {}
    if r > 0 then t[#t + 1] = idx(r - 1, c) end
    if r < N - 1 then t[#t + 1] = idx(r + 1, c) end
    if c > 0 then t[#t + 1] = idx(r, c - 1) end
    if c < N - 1 then t[#t + 1] = idx(r, c + 1) end
    return t
end

PHASE = ""
local function plan(cellsIn)
    local cells, blank, moves = {}, nil, {}
    for i = 1, N * N do cells[i] = cellsIn[i] or 0 if cells[i] == 0 then blank = i end end
    local function find(t) for i = 1, N * N do if cells[i] == t then return i end end end
    local function doMove(p) cells[blank] = cells[p] cells[p] = 0 blank = p moves[#moves + 1] = p end
    local function bfs(from, to, blocked)
        if from == to then return {} end
        local prev, q, h = { [from] = from }, { from }, 1
        while q[h] do
            local cur = q[h] h += 1
            for _, n in ipairs(nbrs(cur)) do
                if not prev[n] and not blocked[n] then
                    prev[n] = cur
                    if n == to then
                        local path, x = {}, n
                        while x ~= from do table.insert(path, 1, x) x = prev[x] end
                        return path
                    end
                    q[#q + 1] = n
                end
            end
        end
        return nil
    end
    local function blankTo(target, locked)
        local path = bfs(blank, target, locked)
        if not path then error("blank path blocked phase=" .. tostring(PHASE) .. " blank=" .. blank .. " target=" .. target) end
        for _, p in ipairs(path) do doMove(p) end
    end
    local function moveTile(t, dest, locked)
        local p = find(t)
        local guard = 0
        while p ~= dest do
            guard += 1 if guard > 200 then error("tile stuck " .. t) end
            local path = bfs(p, dest, locked)
            if not path then error("tile path blocked " .. t) end
            local q = path[1]
            locked[p] = true
            blankTo(q, locked)
            locked[p] = nil
            doMove(p)
            p = q
        end
    end
    local locked = {}
    local function placed(t) return cells[t] == t end
    for r = 0, N - 3 do
        for c = 0, N - 3 do
            local t = idx(r, c)
            PHASE = "row r=" .. r .. " c=" .. c moveTile(t, t, locked)
            locked[t] = true
        end
        local a, b = idx(r, N - 2), idx(r, N - 1)
        local below = idx(r + 1, N - 1)
        for attempt = 1, 4 do
            if placed(a) and placed(b) then break end
            local ok, err = pcall(function()
                PHASE = "rowpair r=" .. r .. " a->b" moveTile(a, b, locked) locked[b] = true
                PHASE = "rowpair r=" .. r .. " b->below" moveTile(b, below, locked) locked[below] = true
                PHASE = "rowpair r=" .. r .. " blank->a" blankTo(a, locked)
                locked[b] = nil locked[below] = nil
                doMove(b)
                doMove(below)
            end)
            if ok then break end
            locked[b] = nil locked[below] = nil
            if attempt == 4 then error(err) end
            moveTile(b, idx(r + 2, N - 2), locked)
        end
        locked[a] = true locked[b] = true
    end
    for c = 0, N - 3 do
        local top, bot = idx(N - 2, c), idx(N - 1, c)
        local right = idx(N - 2, c + 1)
        for attempt = 1, 4 do
            if placed(top) and placed(bot) then break end
            local ok, err = pcall(function()
                PHASE = "colpair c=" .. c .. " bot->top" moveTile(bot, top, locked) locked[top] = true
                PHASE = "colpair c=" .. c .. " top->right" moveTile(top, right, locked) locked[right] = true
                PHASE = "colpair c=" .. c .. " blank->bot" blankTo(bot, locked)
                locked[top] = nil locked[right] = nil
                doMove(top)
                doMove(right)
            end)
            if ok then break end
            locked[top] = nil locked[right] = nil
            if attempt == 4 then error(err) end
            moveTile(top, idx(N - 1, c + 2), locked)
        end
        locked[top] = true locked[bot] = true
    end
    local p1, p2, p3, p4 = idx(N - 2, N - 2), idx(N - 2, N - 1), idx(N - 1, N - 2), idx(N - 1, N - 1)
    blankTo(p4, locked)
    local function solved() for i = 1, N * N - 1 do if cells[i] ~= i then return false end end return true end
    local cycle = { p2, p1, p3, p4 }
    local k = 0
    while not solved() and k < 12 do k += 1 doMove(cycle[(k - 1) % 4 + 1]) end
    if not solved() then error("final 2x2 unsolvable") end
    return moves
end
env.__MSPlan = plan

local function findDuel()
    for _, root in ipairs({ lp.PlayerGui, (gethui and gethui()) or game:GetService("CoreGui") }) do
        local g = root:FindFirstChild("MirrorPuzzleDuel")
        if g then return g end
    end
end
local function ownTiles(g)
    local tiles = {}
    for _, d in ipairs(g:GetDescendants()) do
        local n = d:IsA("TextButton") and tonumber(d.Name:match("^Tile(%d+)$"))
        if n and d.AutoButtonColor then tiles[n] = d end
    end
    return tiles
end
local function readCells(tiles)
    local cells = {}
    for i = 1, N * N do cells[i] = 0 end
    local count = 0
    for n, t in pairs(tiles) do
        local c = t:GetAttribute("Cell")
        if c then cells[c] = n count += 1 end
    end
    return cells, count
end
local function press(tile)
    local ok = pcall(function()
        local cs = getconnections(tile.Activated)
        for _, cn in ipairs(cs) do cn:Fire() end
        if #cs == 0 then firesignal(tile.Activated) end
    end)
    return ok
end

task.spawn(function()
    while running do
        local g = findDuel()
        if g then
            local tiles = ownTiles(g)
            local cells, count = readCells(tiles)
            if count == N * N - 1 then
                local ok, moves = pcall(plan, cells)
                if not ok then
                    env.__MSStatus = "plan error: " .. tostring(moves)
                    task.wait(1)
                else
                    env.__MSStatus = "solving: " .. #moves .. " moves"
                    local i = 1
                    while running and i <= #moves and g.Parent do
                        local pos = moves[i]
                        local tileNum = readCells(tiles)[pos]
                        local tile = tiles[tileNum]
                        if not tile then break end
                        press(tile)
                        local t0 = os.clock()
                        repeat task.wait(0.03) until tile:GetAttribute("Cell") ~= pos or os.clock() - t0 > 1.2
                        if tile:GetAttribute("Cell") ~= pos then
                            i += 1
                            env.__MSStatus = string.format("solving %d/%d", i - 1, #moves)
                        else
                            break
                        end
                    end
                    local now = readCells(tiles)
                    local done = true
                    for k = 1, N * N - 1 do if now[k] ~= k then done = false break end end
                    if done then env.__MSStatus = "solved!" task.wait(2) end
                end
            end
        else
            env.__MSStatus = "waiting for duel"
        end
        task.wait(0.4)
    end
end)
return "mirror slider solver armed"
