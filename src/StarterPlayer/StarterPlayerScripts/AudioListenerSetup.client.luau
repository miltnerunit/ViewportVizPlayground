-- AudioListenerSetup: the new audio API (AudioPlayer/AudioEmitter) is silent without
-- an AudioListener wired to an AudioDeviceOutput. This sets one up on the camera so
-- spatial emitters (e.g. the coin pickups) can actually be heard.
--
-- Guarded: only creates a listener if the camera doesn't already have one, so it won't
-- conflict with any listener another system adds later.

local Workspace = game:GetService("Workspace")

local camera = Workspace.CurrentCamera or Workspace:WaitForChild("Camera")

if not camera:FindFirstChildOfClass("AudioListener") then
	local listener = Instance.new("AudioListener")
	listener.Parent = camera -- follows the camera's position

	local output = Instance.new("AudioDeviceOutput")
	output.Parent = listener

	local wire = Instance.new("Wire")
	wire.SourceInstance = listener -- listener ...
	wire.TargetInstance = output -- ... to the player's audio output
	wire.Parent = listener
end
