-- GrassSway: Animates nearby grass blades with a gentle breeze effect
-- Only animates grass within a radius of the player for performance

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local grassFolder = workspace:WaitForChild("GreenWavyGrass", 20)

-- Settings
local UPDATE_RADIUS = 80 -- only animate grass within this many studs of the player
local SWAY_AMOUNT = 0.12 -- max sway angle in radians (~7 degrees)
local SWAY_SPEED = 1.5 -- how fast the breeze oscillates
local UPDATE_INTERVAL = 0.05 -- seconds between updates (smooth but performant)

-- Cache original CFrames and precompute per-blade phase offsets.
-- We walk descendants (not just direct children) so the grass container works as a Folder
-- OR a Model, at any nesting depth -- e.g. "Group As Model" won't break the sway.
local bladeData = {}
local allBlades = {}

for _, blade in ipairs(grassFolder:GetDescendants()) do
	if blade:IsA("BasePart") then
		local data = {
			part = blade,
			baseCFrame = blade.CFrame,
			phase = math.random() * math.pi * 2, -- random phase per blade
			freqVar = 0.7 + math.random() * 0.6, -- slight frequency variation
			ampVar = 0.7 + math.random() * 0.6, -- slight amplitude variation
		}
		table.insert(allBlades, data)
		bladeData[blade] = data
	end
end

-- Handle grass blades added later (DescendantAdded so blades added inside a nested group count)
grassFolder.DescendantAdded:Connect(function(child)
	if child:IsA("BasePart") then
		local data = {
			part = child,
			baseCFrame = child.CFrame,
			phase = math.random() * math.pi * 2,
			freqVar = 0.7 + math.random() * 0.6,
			ampVar = 0.7 + math.random() * 0.6,
		}
		table.insert(allBlades, data)
		bladeData[child] = data
	end
end)

-- Get player position (fallback to origin if no character yet)
local function getPlayerPosition()
	local char = player.Character
	if char then
		local hrp = char:FindFirstChild("HumanoidRootPart")
		if hrp then
			return hrp.Position
		end
	end
	return Vector3.new(0, 20, 0)
end

-- Animate grass on a timer for performance
local lastUpdate = 0

RunService.Heartbeat:Connect(function(dt)
	local now = os.clock()
	if now - lastUpdate < UPDATE_INTERVAL then
		return
	end
	lastUpdate = now

	local playerPos = getPlayerPosition()
	local time = now * SWAY_SPEED

	for _, data in ipairs(allBlades) do
		local blade = data.part
		-- Skip if blade was destroyed
		if blade.Parent then
			local bladePos = data.baseCFrame.Position
			local distSq = (bladePos - playerPos).Magnitude

			if distSq <= UPDATE_RADIUS then
				-- Compute sway using sine wave with per-blade variation
				local swayAngle = math.sin(time * data.freqVar + data.phase) * SWAY_AMOUNT * data.ampVar
				local swayAngle2 = math.cos(time * data.freqVar * 0.8 + data.phase) * SWAY_AMOUNT * data.ampVar

				-- Apply rotation around the base of the blade (pivot at bottom)
				local basePos = data.baseCFrame.Position - Vector3.new(0, blade.Size.Y / 2, 0)
				local rotCFrame = CFrame.Angles(swayAngle, 0, swayAngle2)
				blade.CFrame = CFrame.new(basePos)
					* rotCFrame
					* CFrame.new(0, blade.Size.Y / 2, 0)
					* (data.baseCFrame - data.baseCFrame.Position)
			end
		end
	end
end)
