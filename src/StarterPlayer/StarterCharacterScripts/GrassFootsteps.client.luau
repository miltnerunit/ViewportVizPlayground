-- GrassFootsteps: Replaces default character footstep sounds with grass footsteps.
-- Sound variations are data-driven: they're cloned from the Sound instances in
-- ReplicatedStorage.Audio.GrassSteps and .DuckSounds. Add/remove a sound by
-- adding/removing a file in src/ReplicatedStorage/Audio/* — no code change needed.
-- See docs/AUDIO.md for the asset list and sourcing.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local player = Players.LocalPlayer

local audioFolder = ReplicatedStorage:WaitForChild("Audio")
local grassFolder = audioFolder:WaitForChild("GrassSteps")
local duckFolder = audioFolder:WaitForChild("DuckSounds")

-- Clone every Sound in `folder` under `parent`, returning them as an array.
-- Volume (and any other authored properties) come from the template instances.
local function cloneSoundsFrom(folder, parent)
	local sounds = {}
	for _, template in ipairs(folder:GetChildren()) do
		if template:IsA("Sound") then
			local sound = template:Clone()
			sound.Parent = parent
			table.insert(sounds, sound)
		end
	end
	return sounds
end

local function setupCharacter(character)
	local humanoid = character:WaitForChild("Humanoid", 10)
	if not humanoid then return end

	-- Destroy default sound objects entirely so they can't loop
	for _, soundName in ipairs({"Running", "RunningInWater", "Climbing", "Died", "Freefall", "GettingUp", "Jumping", "Landing", "Splash"}) do
		local sound = humanoid:FindFirstChild(soundName)
		if sound and sound:IsA("Sound") then
			sound:Destroy()
		end
	end

	-- Load footstep + duck sounds from the Audio folders
	local stepSounds = cloneSoundsFrom(grassFolder, humanoid)
	local duckSounds = cloneSoundsFrom(duckFolder, humanoid)

	-- Random footstep system using Heartbeat for precise timing
	local lastStepTime = 0
	local currentSpeed = 0
	local lastPicked = 0
	local lastDuckPicked = 0

	-- Track speed via Running event
	humanoid.Running:Connect(function(speed)
		currentSpeed = speed
	end)

	-- Use Heartbeat for tight, consistent step timing
	RunService.Heartbeat:Connect(function()
		if currentSpeed <= 1 then return end

		-- Only step while grounded: FloorMaterial is Air mid-jump/fall, so this
		-- silences footsteps when the player is airborne (e.g. hitting space).
		if humanoid.FloorMaterial == Enum.Material.Air then return end

		local now = os.clock()
		-- Step interval: ~2.2/speed with a floor of 0.12s
		local stepInterval = math.clamp(2.2 / currentSpeed, 0.12, 0.35)

		if now - lastStepTime >= stepInterval then
			lastStepTime = now

			-- Play a grass footstep (random, no repeat)
			if #stepSounds > 0 then
				local pick
				repeat
					pick = math.random(1, #stepSounds)
				until pick ~= lastPicked or #stepSounds == 1
				lastPicked = pick
				local sound = stepSounds[pick]
				if sound and sound.IsLoaded then
					sound:Play()
				end
			end

			-- 35% chance to also play a squeaky duck sound on top
			if #duckSounds > 0 and math.random() <= 0.35 then
				local duckPick
				repeat
					duckPick = math.random(1, #duckSounds)
				until duckPick ~= lastDuckPicked or #duckSounds == 1
				lastDuckPicked = duckPick
				local duckSound = duckSounds[duckPick]
				if duckSound and duckSound.IsLoaded then
					-- Random pitch shift for extra variety
					duckSound.PlaybackSpeed = 0.8 + math.random() * 0.6
					duckSound:Play()
				end
			end
		end
	end)
end

if player.Character then
	setupCharacter(player.Character)
end
player.CharacterAdded:Connect(setupCharacter)
