# Audio source material

This documents the sound assets used in **bonkers** — what they are, where they came
from, and how they're wired up. It lives outside `src/` on purpose (a `.md` file isn't a
Roblox instance), so it won't sync into the place.

## What these files are

The `Sound` instances under `src/ReplicatedStorage/Audio/` are **references** to
Roblox-hosted assets (`rbxassetid://…`), not raw audio. The actual audio bytes live on
Roblox's CDN — the `.model.json` files only carry the asset ID + volume. You can preview
them by selecting a `Sound` in Studio's Explorer and hitting play in Properties; you
**cannot** play them from Finder (they're JSON stubs, not `.ogg`/`.mp3`).

All assets below are **free assets from the Roblox Creator Store** (uploaded by third
parties, not by us). Browser preview: `https://www.roblox.com/library/<id>`.

## Source of truth

The `GrassSteps/` and `DuckSounds/` folders **are** the source of truth.
[`GrassFootsteps.client.luau`](../src/StarterPlayer/StarterCharacterScripts/GrassFootsteps.client.luau)
clones every `Sound` in those folders onto the character at runtime and plays them randomly
(a duck sound layers on ~35% of footsteps, with a random pitch shift). Volume comes from
each `Sound` template.

To change the footstep/duck audio, just edit the folders — **no code change needed**:

- **Add a variation:** drop a new `Sound` `.model.json` into the folder.
- **Remove one:** delete its file.
- **Adjust loudness:** edit that file's `Volume`.

There are no hardcoded ID lists in the script anymore, so nothing to keep in sync.

## CoinCollect (new audio API)

The coin pickup uses Roblox's **modern audio graph**, not a legacy `Sound`.
`CoinCollect.model.json` is now an **`AudioPlayer`** (`Asset = rbxassetid://135483737426662`).

Each coin is **authored in the scene** with its own rig — `AudioPlayer` (named
`CoinAudioPlayer`) → `Wire` → `AudioEmitter` — parented to the coin so it emits spatially from
the coin's position. Because they're authored (not script-created), they're **visible and
editable in the Explorer without pressing Play**. These live in `bonkers.rbxl` (scene data,
LFS), not in `src/`.

[`CoinSoundScript.server.luau`](../src/ServerScriptService/CoinSoundScript.server.luau) just
finds each coin's `CoinAudioPlayer`, sets `PlaybackSpeed` (half-step per collect), and plays
it. If a coin somehow lacks an authored rig, the script builds one at runtime as a fallback so
audio never silently breaks.

To author the rigs on the coins in the scene, run this once in the Studio **Command Bar**
(Edit mode), then save the place:

```lua
local coins = workspace.World.Coins
local template = game:GetService("ReplicatedStorage").Audio.CoinCollect -- AudioPlayer
for _, coin in coins:GetChildren() do
	if coin:IsA("BasePart") and not coin:FindFirstChild("CoinAudioPlayer") then
		local p = template:Clone(); p.Name = "CoinAudioPlayer"; p.Parent = coin
		local e = Instance.new("AudioEmitter"); e.Parent = coin
		local w = Instance.new("Wire"); w.SourceInstance = p; w.TargetInstance = e; w.Parent = coin
	end
end
```

⚠️ The new API has **no implicit listener** — nothing is audible without one. That's set up by
[`AudioListenerSetup.client.luau`](../src/StarterPlayer/StarterPlayerScripts/AudioListenerSetup.client.luau),
which creates an `AudioListener` + `AudioDeviceOutput` on the camera. If coins go silent, check
that script ran.

(Footsteps/ducks in `GrassSteps/`/`DuckSounds/` remain on the legacy `Sound` API for now,
which uses `SoundService`'s default listener — a separate path that coexists with the above.)

## Flowers (new audio API, looping ambient)

The flowers use the same **modern audio graph** as the coins. Each flower is **authored in
the scene** with its own rig — `AudioPlayer` (named `FlowerAudioPlayer`) → `Wire` →
`AudioEmitter` — parented to the flower's part so it emits spatially from the flower.

Unlike the coins (which `:Play()` on touch), the flowers are meant to be **continuous
ambient loops**. The modern audio API has **no serializable "play on start" flag** (the
legacy `Sound.Playing` has no `AudioPlayer` equivalent), so an authored, looping
`AudioPlayer` sits idle until something starts it.
[`FlowerAmbience.server.luau`](../src/ServerScriptService/FlowerAmbience.server.luau) does
that: it finds every `FlowerAudioPlayer` in the scene, sets `Looping = true`, and calls
`:Play()`. It skips players with a blank `Asset` so unfilled rigs don't warn.

The rigs are authored with a **blank `Asset`** on purpose — pick each flower's sound in the
Explorer/Properties (or set `Asset = rbxassetid://…`) and it will start looping on the next
run. To author the rigs, **select the flowers in the Explorer**, run this once in the Studio
**Command Bar** (Edit mode), then save the place:

The flowers are **Models** (often with no `PrimaryPart` set), so the script searches
**recursively** for a part to host the emitter and prints a per-flower report:

```lua
local Selection = game:GetService("Selection")
local rigged, skipped = 0, 0
for _, sel in Selection:Get() do
	-- AudioEmitters need a BasePart for their position. Use the Model's PrimaryPart,
	-- else the first BasePart anywhere inside it (recursive), else the part itself.
	local part = (sel:IsA("BasePart") and sel)
		or (sel:IsA("Model") and (sel.PrimaryPart or sel:FindFirstChildWhichIsA("BasePart", true)))
	if not part then
		warn(("[flower audio] %s has no BasePart -- skipped"):format(sel:GetFullName()))
		skipped += 1
	elseif part:FindFirstChild("FlowerAudioPlayer") then
		print(("[flower audio] %s already rigged -- skipped"):format(sel:GetFullName()))
		skipped += 1
	else
		local p = Instance.new("AudioPlayer")
		p.Name = "FlowerAudioPlayer"
		p.Looping = true
		-- p.Asset = "rbxassetid://…"  -- leave blank; fill per-flower in Properties
		p.Parent = part
		local e = Instance.new("AudioEmitter"); e.Parent = part
		local w = Instance.new("Wire"); w.SourceInstance = p; w.TargetInstance = e; w.Parent = part
		print(("[flower audio] rigged %s (on %s)"):format(sel:GetFullName(), part.Name))
		rigged += 1
	end
end
print(("[flower audio] done -- %d rigged, %d skipped"):format(rigged, skipped))
```

The rig lands on the flower's part (one level down inside the Model), so in the Explorer
expand a flower → expand its part to see `FlowerAudioPlayer` / `AudioEmitter` / `Wire`.

⚠️ Same listener caveat as the coins: nothing is audible without the
`AudioListener` + `AudioDeviceOutput` from `AudioListenerSetup.client.luau`.

| Name | Asset ID | Type |
|------|----------|------|
| CoinCollect | 135483737426662 | AudioPlayer |

## GrassSteps (volume 0.6)

| Name | Asset ID |
|------|----------|
| footstep grass 1 | 129956418693357 |
| footstep grass 2 | 78534941650081 |
| footstep grass 3 | 110522236020035 |
| footstep grass 4 | 135037154891351 |
| Wet grass footstep 1 | 117561124924720 |
| Wet grass footstep 2 | 116195990169547 |
| Wet grass footstep 3 | 140668467774841 |
| Black Laboratory grass footstep 1 | 73076319380473 |
| Black Laboratory grass footstep 3 | 115438917666178 |
| Black Laboratory grass footstep 5 | 92061301674605 |
| Black Laboratory grass footstep 7 | 92614595247225 |
| Grass Footstep 1 (SFX) | 133687456650659 |

## DuckSounds (volume 0.5)

Layered randomly on top of footsteps (~35% chance) with a random pitch shift, for comedic effect.

| Name | Asset ID |
|------|----------|
| Squeeze Toy Squeaky Rubber Hit 1 | 9125994310 |
| Squeeze Toy Squeaky Rubber Hit 9 | 9125994553 |
| Squeeze Toy Squeaky Rubber Hit 10 | 9125994570 |
| Squeeze Toy Squeaky Rubber Hit 11 | 9125994773 |
| Squeeze Toy Squeaky Rubber Hit 12 | 9125994778 |
| Squeeze Toy Squeaky Rubber Hit 13 | 9125994785 |
| Squeaky Toy Sound Effect | 115623941558737 |
| Squeaky Toy | 78018370359924 |
