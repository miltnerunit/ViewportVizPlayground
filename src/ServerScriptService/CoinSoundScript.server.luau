local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local coinsFolder = workspace:WaitForChild("World"):WaitForChild("Coins")
local audioFolder = ReplicatedStorage:WaitForChild("Audio")
local playerTemplate = audioFolder:WaitForChild("CoinCollect") -- AudioPlayer template

-- Fallback rig builder: coins are normally authored with their AudioPlayer/AudioEmitter/
-- Wire in the scene (visible + editable in the Explorer). This runtime builder only kicks
-- in for a coin that somehow has no authored rig, so audio never silently breaks.
local function buildCoinAudio(coin)
	local audioPlayer = playerTemplate:Clone()
	audioPlayer.Name = "CoinAudioPlayer"
	audioPlayer.Parent = coin

	local emitter = Instance.new("AudioEmitter")
	emitter.Parent = coin

	local wire = Instance.new("Wire")
	wire.SourceInstance = audioPlayer -- AudioPlayer output ...
	wire.TargetInstance = emitter -- ... into the spatial emitter
	wire.Parent = coin

	return audioPlayer
end

-- Debounce per coin to prevent rapid repeated triggers
local debounce = {}

-- Per-player pitch combo: each coin a player collects raises their pitch by one
-- half-step (2^(1/12) ≈ 1.0595). A player's combo resets to 0 after RESET_DELAY
-- seconds without collecting. State is keyed by Player and cleared on leave.
local RESET_DELAY = 5
local combos = {} -- [player] = { count = number, token = number }

local function getCombo(player)
	local combo = combos[player]
	if not combo then
		combo = { count = 0, token = 0 }
		combos[player] = combo
	end
	return combo
end

-- (Re)start this player's idle reset timer. Bumping token invalidates any earlier
-- pending reset, so only the latest RESET_DELAY countdown can actually fire.
local function schedulePitchReset(player)
	local combo = combos[player]
	if not combo then
		return
	end
	combo.token += 1
	local myToken = combo.token
	task.delay(RESET_DELAY, function()
		local current = combos[player]
		if current and current.token == myToken then
			current.count = 0
		end
	end)
end

local function onCoinTouched(coin, otherPart)
	if debounce[coin] then
		return
	end

	local character = otherPart.Parent
	if not character then
		return
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return
	end

	local player = Players:GetPlayerFromCharacter(character)
	if not player then
		return
	end

	debounce[coin] = true

	-- Bump this player's combo and (re)start their idle reset timer
	local combo = getCombo(player)
	combo.count += 1
	schedulePitchReset(player)

	-- Play the coin collect sound at the collecting player's pitch, spatially from the
	-- coin via its authored AudioPlayer -> Wire -> AudioEmitter rig (runtime-built fallback).
	local audioPlayer = coin:FindFirstChild("CoinAudioPlayer") or buildCoinAudio(coin)
	-- Each half-step up: multiply by 2^(1/12)
	audioPlayer.PlaybackSpeed = 2 ^ (combo.count / 12)
	audioPlayer:Play()

	task.wait(1)
	debounce[coin] = nil
end

local function setupCoin(coin)
	-- Attach to any BasePart in the Coins folder, regardless of name, so
	-- reskinning the pickups (coins -> hearts -> whatever) doesn't break audio.
	if coin:IsA("BasePart") then
		-- Rigs are authored in the scene, so nothing to build here; just listen.
		coin.Touched:Connect(function(otherPart)
			onCoinTouched(coin, otherPart)
		end)
	end
end

-- Set up existing coins
for _, coin in ipairs(coinsFolder:GetChildren()) do
	setupCoin(coin)
end

-- Set up coins added later
coinsFolder.ChildAdded:Connect(setupCoin)

-- Drop combo state when a player leaves so the table doesn't leak
Players.PlayerRemoving:Connect(function(player)
	combos[player] = nil
end)
