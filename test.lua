
if getgenv().DEAutoDelivery then return end
getgenv().DEAutoDelivery = true

local Plrs = game:GetService('Players')
local RunService = game:GetService('RunService')
local CS = game:GetService('CollectionService')
local RS = game:GetService('ReplicatedStorage')

local plr = Plrs.LocalPlayer
local delivery = require(RS.Modules.Client.Jobs.Tasks.DeliveryJobTask)
local deliveryUtil = require(RS.Modules.Shared.Jobs.Delivery.DeliveryUtil)
local vehicles = require(RS.Modules.Client.Vehicles.VehicleController)
local vehicleUtil = require(RS.Modules.Shared.Vehicles.VehicleUtil)
local tpGuard = require(RS.Modules.Client.Exploit.VehicleTeleportDetectionController)

if getconnections then
    pcall(function()
        for _, v in ipairs(getconnections(plr.Idled)) do
            v:Disable()
        end
    end)
end

local function getLoc(pos, skipLast)
    local loc, dist

    for _, v in ipairs(CS:GetTagged('DeliveryLocation')) do
        if v:IsA('BasePart') and v.Parent then
            if not skipLast or not deliveryUtil.IsLastDeliveryLocation(plr, v) then
                local d = (v.Position - pos).Magnitude
                if not dist or d < dist then loc, dist = v, d end
            end
        end
    end

    return loc
end

local hover

local function tp(cf)
    local char = plr.Character
    if not char then return end

    local car = vehicleUtil.getPlayerData(plr)
    local chassis = vehicles.getActiveChassisController()

    if car and car.Model and car.WeightPart then
        if chassis then chassis.Teleporting = true end

        tpGuard.AuthorizeNextTeleport()
        car.Model.PrimaryPart = car.WeightPart
        car.Model:SetPrimaryPartCFrame(cf)
        car.WeightPart.Anchored = false
        if hover then hover:Destroy() end

        hover = Instance.new('BodyVelocity')
        hover.MaxForce = Vector3.new(1e9, 1e9, 1e9)
        hover.Velocity = Vector3.zero
        hover.Parent = car.WeightPart

        for _, v in ipairs(car.Model:GetDescendants()) do
            if v:IsA('BasePart') then
                v.AssemblyLinearVelocity = Vector3.zero
                v.AssemblyAngularVelocity = Vector3.zero
            end
        end

        task.defer(function()
            if chassis then chassis.Teleporting = false end
        end)
    else
        char:PivotTo(cf)

        local hrp = char:FindFirstChild('HumanoidRootPart')
        if hrp then
            if hover then hover:Destroy() end

            hover = Instance.new('BodyVelocity')
            hover.MaxForce = Vector3.new(1e9, 1e9, 1e9)
            hover.Velocity = Vector3.zero
            hover.Parent = hrp

            hrp.AssemblyLinearVelocity = Vector3.zero
            hrp.AssemblyAngularVelocity = Vector3.zero
        end
    end
end

RunService.Heartbeat:Connect(function()
    local char = plr.Character
    local hrp = char and char:FindFirstChild('HumanoidRootPart')
    local hum = char and char:FindFirstChildOfClass('Humanoid')

    if hrp then hrp.Anchored = false end
    if hum and hover and hover.Parent == hrp then
        hum:ChangeState(Enum.HumanoidStateType.Freefall)
    end
end)

local curTarget, curLoc, curPhase, lastTick, lastFire, dropAt

while task.wait(0.1) do
    local char = plr.Character
    local hrp = char and char:FindFirstChild('HumanoidRootPart')

    if hrp then
        if plr:GetAttribute('JobId') ~= 'Delivery' then
            RS.Remotes.RequestStartJobSession:FireServer('Delivery', 'deliveryHub', 'HighRisk')
            curTarget, curLoc, curPhase, lastTick = nil, nil, nil, nil
            task.wait(0.5)
        else
            local state = delivery.GetCurrentDeliveryState()
            local target, phase

            if state then
                lastTick = nil

                local carried = state.ItemsCarried or 0
                local cap = state.MaxCapacity or carried
                local full = carried >= cap
                local noMore = state.PackagesRemainingAtPickup == 0

                if carried > 0 and (full or noMore) then
                    phase = 'drop'
                    dropAt = dropAt or tick() + 4.5

                    if tick() >= dropAt then
                        target = state.DestinationPosition
                    else
                        target = state.PickupPosition
                    end
                else
                    dropAt = nil
                    phase = 'pickup'
                    target = state.PickupPosition
                end
            else
                lastTick = lastTick or tick()

                if tick() - lastTick > 0.25 then
                    local loc = getLoc(hrp.Position, true) or getLoc(hrp.Position)
                    phase = 'new'
                    target = loc and loc.Position
                end
            end

            if target then
                if target ~= curTarget or phase ~= curPhase then
                    tp(CFrame.new(target + Vector3.new(0, 3.5, 0)))
                    curTarget, curPhase = target, phase
                end

                local loc = getLoc(target)

                if loc then
                    if loc ~= curLoc then
                        RS.Remotes.DeliveryLocationInteracted:FireServer(loc)
                        curLoc, lastFire = loc, tick()
                    elseif tick() - lastFire > 1 then
                        RS.Remotes.DeliveryLocationInteracted:FireServer(loc)
                        lastFire = tick()
                    end
                end
            end
        end
    end
end
