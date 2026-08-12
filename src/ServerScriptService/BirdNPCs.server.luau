-- BirdNPCs: turns the imported bird (Workspace.Sketchfab_Scene -- "Sketchfab_Scene"
-- is just the default name Sketchfab gives exports) into a flock of little NPCs that
-- hop around the field, peeping and landing with a soft sound.
--
-- The bird is a skinned MeshPart (PrimaryPart "BirdOrange_BirdOrange_LMB_0") with a
-- bone rig, so the whole thing moves as one when we drive the model's pivot -- no
-- Humanoid, no welding. We clone it NUM_BIRDS times, anchor each, and each bird runs
-- its own loop: pick a random spot near home -> PathfindingService routes to it around
-- any collidable obstacles -> we hop the bird along the waypoints with a little vertical
-- arc, facing the direction of travel, pausing between hops.
--
-- Audio (see docs/AUDIO.md > Birds):
--   * Peeps use the modern spatial rig -- AudioPlayer ("BirdPeepPlayer") -> Wire ->
--     AudioEmitter -- on the bird's PrimaryPart, so peeps emit from the bird's position.
--     Author that rig in edit mode (Command Bar snippet in docs/AUDIO.md) to make it
--     visible/editable in the Explorer; clones inherit it, and a runtime fallback builds
--     it for any bird that wasn't authored.
--   * Landings play a random dedicated Sound from ReplicatedStorage.Audio.BirdLands,
--     cloned onto the bird's part (legacy Sound, spatial, follows the bird).
--
-- Movement scale (hop distance/height, wander radius) is derived from the bird's own
-- bounding box so it adapts to whatever scale the model is imported at; the multipliers
-- and NUM_BIRDS below are the knobs to tune.

local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local PathfindingService = game:GetService("PathfindingService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- === Tunables ===============================================================
local NUM_BIRDS = 6

local WANDER_RADIUS_MULT = 14 -- how far from its spawn a bird will roam (× bird width)
local HOP_DISTANCE_MULT = 1.1 -- length of one hop / pathfinding waypoint spacing (× bird width)
local HOP_HEIGHT_MULT = 0.55 -- peak height of a hop's arc (× bird height)

local HOP_DURATION = 0.32 -- seconds for a single hop
local PAUSE_MIN = 0.08 -- min pause between hops
local PAUSE_MAX = 0.35 -- max pause between hops
local REST_MIN = 0.6 -- min pause after reaching a target, before choosing the next
local REST_MAX = 2.5 -- max pause after reaching a target
local TARGET_TRIES = 12 -- attempts to find a valid ground target before giving up a cycle

-- Bird audio
local PEEP_INTERVAL_MIN = 2.5 -- min seconds between a bird's peeps
local PEEP_INTERVAL_MAX = 9 -- max seconds between a bird's peeps
local PEEP_PITCH_MIN = 0.92 -- random PlaybackSpeed range for peep variety
local PEEP_PITCH_MAX = 1.15
local LAND_PITCH_MIN = 1.05 -- landing sounds pitched up a touch -> lighter/smaller
local LAND_PITCH_MAX = 1.3
local LAND_VOLUME_MULT = 0.7 -- scale down each landing Sound's authored volume for a soft touch
-- ============================================================================

print("[BirdNPCs] script started")

local template = Workspace:WaitForChild("Sketchfab_Scene")

-- Make sure we have a pivot to drive.
if not template.PrimaryPart then
	for _, d in template:GetDescendants() do
		if d:IsA("BasePart") then
			template.PrimaryPart = d
			break
		end
	end
end

-- Derive movement scale + how far the pivot sits above the bird's feet, from the
-- model's bounding box (captured before we move anything).
local homeCenter = template:GetPivot().Position
local _, boundsSize = template:GetBoundingBox()
local birdWidth = math.max(boundsSize.X, boundsSize.Z)
local birdHeight = boundsSize.Y
local footOffset = birdHeight / 2 -- pivot -> feet (bounding box is roughly centered on the mesh)

local WANDER_RADIUS = birdWidth * WANDER_RADIUS_MULT
local HOP_DISTANCE = birdWidth * HOP_DISTANCE_MULT
local HOP_HEIGHT = birdHeight * HOP_HEIGHT_MULT

-- A pristine copy of the imported bird, captured BEFORE we attach any runtime audio or
-- anchoring. Birds 2..N are cloned from this so they don't inherit bird 1's runtime
-- Sounds (which would otherwise stack up as duplicates on every clone).
local proto = template:Clone()

-- Audio assets. BirdPeep is an AudioPlayer template (blank Asset until you pick a chirp);
-- BirdLands holds the dedicated landing Sound variants (may be empty / placeholder-only).
local audioFolder = ReplicatedStorage:WaitForChild("Audio")
local peepTemplate = audioFolder:WaitForChild("BirdPeep")
local landsFolder = audioFolder:FindFirstChild("BirdLands")

-- Folder to hold the flock, and a raycast filter so ground checks hit the terrain rather
-- than the birds, grass, flowers or coins.
local birdsFolder = Instance.new("Folder")
birdsFolder.Name = "Birds"
birdsFolder.Parent = Workspace

-- Exclude the birds and the decorative props (grass blades, coins, flowers) so ground
-- raycasts land on the actual terrain/ground -- but NOT the whole World folder, since
-- the ground itself may live inside it.
local groundParams = RaycastParams.new()
groundParams.FilterType = Enum.RaycastFilterType.Exclude
do
	local ignore = { birdsFolder }
	local world = Workspace:FindFirstChild("World")
	for _, inst in
		{
			Workspace:FindFirstChild("GreenWavyGrass"),
			world and world:FindFirstChild("Coins"),
			world and world:FindFirstChild("Flowers"),
		}
	do
		if inst then
			table.insert(ignore, inst)
		end
	end
	groundParams.FilterDescendantsInstances = ignore
end

local path = PathfindingService:CreatePath({
	AgentRadius = math.max(birdWidth * 0.5, 0.5),
	AgentHeight = math.max(birdHeight, 1),
	AgentCanJump = false,
	WaypointSpacing = HOP_DISTANCE,
})

-- Raycast straight down to find the ground height at (x, z). Returns nil if nothing hit.
local function groundYAt(x: number, z: number): number?
	local origin = Vector3.new(x, homeCenter.Y + 500, z)
	local hit = Workspace:Raycast(origin, Vector3.new(0, -2000, 0), groundParams)
	return hit and hit.Position.Y or nil
end

-- Place a bird upright with its feet on the ground at pos, facing a horizontal direction.
local function placeOnGround(bird: Model, groundPos: Vector3, faceDir: Vector3)
	local footPos = Vector3.new(groundPos.X, groundPos.Y + footOffset, groundPos.Z)
	local flat = Vector3.new(faceDir.X, 0, faceDir.Z)
	if flat.Magnitude < 1e-3 then
		flat = Vector3.new(0, 0, 1)
	end
	bird:PivotTo(CFrame.lookAt(footPos, footPos + flat.Unit))
end

-- Pick a random reachable-looking ground point within WANDER_RADIUS of home.
local function pickGroundTarget(home: Vector3): Vector3?
	for _ = 1, TARGET_TRIES do
		local angle = math.random() * math.pi * 2
		local dist = math.sqrt(math.random()) * WANDER_RADIUS -- sqrt -> uniform over the disc
		local x = home.X + math.cos(angle) * dist
		local z = home.Z + math.sin(angle) * dist
		local y = groundYAt(x, z)
		if y then
			return Vector3.new(x, y, z)
		end
	end
	return nil
end

-- Find (authored) or build (runtime fallback) the bird's peep rig: an AudioPlayer wired to
-- an AudioEmitter on its PrimaryPart, so peeps emit spatially from the bird. Returns the
-- AudioPlayer, or nil if the bird has no PrimaryPart to host the rig.
local function ensurePeepRig(bird: Model): AudioPlayer?
	local part = bird.PrimaryPart
	if not part then
		return nil
	end

	local existing = part:FindFirstChild("BirdPeepPlayer")
	if existing and existing:IsA("AudioPlayer") then
		return existing
	end

	local player = peepTemplate:Clone()
	player.Name = "BirdPeepPlayer"
	player.Parent = part

	local emitter = Instance.new("AudioEmitter")
	emitter.Parent = part

	local wire = Instance.new("Wire")
	wire.SourceInstance = player
	wire.TargetInstance = emitter
	wire.Parent = part

	return player
end

-- Clone the dedicated landing Sounds onto the bird's PrimaryPart so they play spatially
-- from the bird. Skips blank-SoundId templates (folder placeholders).
local function loadLandSounds(bird: Model): { Sound }
	local sounds = {}
	local part = bird.PrimaryPart
	if not (part and landsFolder) then
		return sounds
	end
	for _, soundTemplate in landsFolder:GetChildren() do
		if soundTemplate:IsA("Sound") and soundTemplate.SoundId ~= "" then
			local sound = soundTemplate:Clone()
			sound.Volume *= LAND_VOLUME_MULT
			sound.Parent = part
			table.insert(sounds, sound)
		end
	end
	return sounds
end

-- Play a random landing Sound, pitched up a little for a light touch.
local function playLanding(landSounds: { Sound })
	if #landSounds == 0 then
		return
	end
	local sound = landSounds[math.random(#landSounds)]
	sound.PlaybackSpeed = LAND_PITCH_MIN + math.random() * (LAND_PITCH_MAX - LAND_PITCH_MIN)
	sound:Play()
end

-- Occasional chirp. Skips while the peep AudioPlayer has no Asset (authored blank until you
-- pick a chirp), mirroring the flowers' "author now, choose the sound later" pattern.
local function peepLoop(bird: Model, peepPlayer: AudioPlayer)
	while bird.Parent do
		task.wait(PEEP_INTERVAL_MIN + math.random() * (PEEP_INTERVAL_MAX - PEEP_INTERVAL_MIN))
		if bird.Parent and peepPlayer.Asset ~= "" then
			peepPlayer.PlaybackSpeed = PEEP_PITCH_MIN + math.random() * (PEEP_PITCH_MAX - PEEP_PITCH_MIN)
			peepPlayer:Play()
		end
	end
end

-- Animate one hop: arc up and over to groundTarget, ending on the ground, facing travel.
local function hop(bird: Model, groundTarget: Vector3)
	local startCF = bird:GetPivot()
	local endPos = Vector3.new(groundTarget.X, groundTarget.Y + footOffset, groundTarget.Z)

	local flat = Vector3.new(endPos.X - startCF.Position.X, 0, endPos.Z - startCF.Position.Z)
	local endCF
	if flat.Magnitude < 1e-3 then
		endCF = CFrame.lookAt(endPos, endPos + startCF.LookVector * Vector3.new(1, 0, 1))
	else
		endCF = CFrame.lookAt(endPos, endPos + flat.Unit)
	end

	local elapsed = 0
	while elapsed < HOP_DURATION do
		if not bird.Parent then
			return
		end
		elapsed += RunService.Heartbeat:Wait()
		local a = math.min(elapsed / HOP_DURATION, 1)
		local arc = HOP_HEIGHT * math.sin(math.pi * a) -- 0 at both ends, peak mid-hop
		bird:PivotTo(startCF:Lerp(endCF, a) + Vector3.new(0, arc, 0))
	end
end

-- One bird's lifelong wander loop. Plays a landing sound as each hop touches down.
local function runBird(bird: Model, home: Vector3, landSounds: { Sound })
	task.wait(math.random() * REST_MAX) -- stagger so the flock isn't in lockstep
	while bird.Parent do
		local target = pickGroundTarget(home)
		if target then
			local ok = pcall(function()
				path:ComputeAsync(bird:GetPivot().Position, target)
			end)
			local waypoints = (ok and path.Status == Enum.PathStatus.Success) and path:GetWaypoints() or nil

			if waypoints and #waypoints > 1 then
				for i = 2, #waypoints do
					if not bird.Parent then
						return
					end
					-- Snap the waypoint down to the actual ground so the bird hugs terrain.
					local wp = waypoints[i].Position
					local gy = groundYAt(wp.X, wp.Z)
					hop(bird, Vector3.new(wp.X, gy or wp.Y, wp.Z))
					playLanding(landSounds)
					task.wait(math.random() * (PAUSE_MAX - PAUSE_MIN) + PAUSE_MIN)
				end
			else
				-- No path found; just hop straight at the target so the bird still moves.
				hop(bird, target)
				playLanding(landSounds)
			end
		end
		task.wait(math.random() * (REST_MAX - REST_MIN) + REST_MIN)
	end
end

-- Prep a single bird: anchor it, take it out of collision/query so birds don't block
-- each other's pathing or ground raycasts.
local function prepBird(bird: Model)
	for _, d in bird:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = false
			d.CanQuery = false
		end
	end
end

-- Build the flock. Bird 1 reuses the imported model; the rest are clones of the pristine
-- proto captured above.
for i = 1, NUM_BIRDS do
	local bird = if i == 1 then template else proto:Clone()
	bird.Name = "Bird_" .. i
	bird.Parent = birdsFolder
	prepBird(bird)

	local peepPlayer = ensurePeepRig(bird)
	local landSounds = loadLandSounds(bird)

	local spawnPos = pickGroundTarget(homeCenter)
	if not spawnPos then
		warn("[BirdNPCs] no ground found near home for " .. bird.Name .. " -- spawning at home center")
		spawnPos = homeCenter
	end
	local angle = math.random() * math.pi * 2
	placeOnGround(bird, spawnPos, Vector3.new(math.cos(angle), 0, math.sin(angle)))

	task.spawn(runBird, bird, spawnPos, landSounds)
	if peepPlayer then
		task.spawn(peepLoop, bird, peepPlayer)
	end
end

print(
	string.format(
		"[BirdNPCs] spawned %d birds (bird width ~%.1f, hop dist ~%.1f, wander radius ~%.1f)",
		NUM_BIRDS,
		birdWidth,
		HOP_DISTANCE,
		WANDER_RADIUS
	)
)
