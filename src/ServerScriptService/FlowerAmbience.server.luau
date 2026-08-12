-- FlowerAmbience: the flowers are authored in the scene with their own audio rig --
-- AudioPlayer (named "FlowerAudioPlayer") -> Wire -> AudioEmitter -- so each emits
-- spatially from its own position. See docs/AUDIO.md for the Command Bar script that
-- authors those rigs onto the selected flowers.
--
-- The modern audio API has no serializable "play on start" flag (unlike the legacy
-- Sound.Playing), so an authored, looping AudioPlayer still sits idle until something
-- calls :Play(). This script finds every flower AudioPlayer in the scene and starts it
-- looping, so the flowers hum continuously without per-flower wiring.
--
-- Nothing is audible without an AudioListener/AudioDeviceOutput -- that's set up on the
-- camera by AudioListenerSetup.client.luau (shared with the coins).
--
-- NOTE: playback is started with a plain :Play() here. The scheduled :Play(atTime)
-- variant (for phase-locking the loops to a shared mixer step) CANNOT be used from a
-- server script -- SoundService:GetMixerTime() / Play(atTime) are client-only, and calling
-- them here errors ("AudioPlayer:Play(atTime) cannot be used on the server"). Starting all
-- players in one yield-free frame keeps identical-length loops close enough in practice; for
-- guaranteed sync the start would have to move to a client script (see docs/AUDIO.md).

local Workspace = game:GetService("Workspace")

local PLAYER_NAME = "FlowerAudioPlayer"

-- Start one flower's AudioPlayer looping. Guarded so an empty Asset (rigs are authored
-- blank for the artist to fill in Properties) doesn't spam "no asset" warnings, and so we
-- never double-play a player that's already going.
local function startFlower(player)
	if not player:IsA("AudioPlayer") or player.Name ~= PLAYER_NAME then
		return
	end
	player.Looping = true
	if player.Asset ~= "" and not player.IsPlaying then
		player:Play()
	end
end

-- Start any flowers already in the scene. Running this loop without yields starts every
-- player within one frame, so identical-length loops stay roughly aligned.
for _, descendant in ipairs(Workspace:GetDescendants()) do
	startFlower(descendant)
end

-- Start flowers added later (e.g. streamed in, or rigged after load)
Workspace.DescendantAdded:Connect(startFlower)
