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

-- Wind character. Single rigid parts can't truly curve, so these shape the *motion* to read
-- as wind blowing across a field rather than a symmetric back-and-forth wobble.
local WIND_DIR = Vector3.new(1, 0, 0.35) -- prevailing wind direction in the XZ plane
local LEAN_BIAS = 0.5 -- resting downwind lean; blades flutter around a leaned pose, not upright
local FLUTTER = 0.35 -- secondary cross-wind wobble, as a fraction of the main sway
local GUST_SPEED = 0.35 -- how fast gusts roll in and out across the field
local GUST_MIN = 0.55 -- sway strength during a lull (1.0 = no gusting, always full strength)

-- Normalize the wind onto the horizontal plane (fallback to +X if WIND_DIR has no XZ length).
local WIND = Vector3.new(WIND_DIR.X, 0, WIND_DIR.Z)
WIND = WIND.Magnitude > 0 and WIND.Unit or Vector3.new(1, 0, 0)

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
			freqVar = 0.7 + math.random() * 3.6, -- slight frequency variation
			ampVar = 0.7 + math.random() * 1.5, -- slight amplitude variation
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

RunService.Heartbeat:Connect(function()
	local now = os.clock()
	if now - lastUpdate < UPDATE_INTERVAL then
		return
	end
	lastUpdate = now

	local playerPos = getPlayerPosition()
	local time = now * SWAY_SPEED

	-- Gust envelope: a slow global surge and lull so the whole field breathes with the wind,
	-- instead of every blade oscillating at a constant strength. Ranges GUST_MIN..1.
	local gust = GUST_MIN + (1 - GUST_MIN) * (0.5 + 0.5 * math.sin(now * GUST_SPEED))

	for _, data in ipairs(allBlades) do
		local blade = data.part
		-- Skip if blade was destroyed
		if blade.Parent then
			local bladePos = data.baseCFrame.Position
			local distSq = (bladePos - playerPos).Magnitude

			if distSq <= UPDATE_RADIUS then
				-- Per-blade oscillation (their tuned freq/amp), shaped with a light second
				-- harmonic so it flutters rather than swinging like a rigid pendulum.
				local drive = time * data.freqVar + data.phase
				local osc = math.sin(drive) + 0.25 * math.sin(2 * drive)

				-- Lean predominantly downwind: a resting lean (LEAN_BIAS) plus the oscillation,
				-- scaled by the blade's amplitude and the global gust -- reads as wind pushing
				-- the grass, not a symmetric metronome wobble.
				local amp = SWAY_AMOUNT * data.ampVar * gust
				local lean = amp * (LEAN_BIAS + osc)
				-- A smaller flutter perpendicular to the wind adds liveliness.
				local side = amp * FLUTTER * math.cos(time * data.freqVar * 0.8 + data.phase)

				-- Convert lean (toward WIND) + side (perpendicular to WIND) into X/Z tilt angles.
				local swayAngle = lean * WIND.Z + side * WIND.X
				local swayAngle2 = -lean * WIND.X + side * WIND.Z

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
