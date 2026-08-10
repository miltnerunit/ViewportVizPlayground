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

## CoinCollect

Played by [`CoinSoundScript.server.luau`](../src/ServerScriptService/CoinSoundScript.server.luau)
— cloned onto each pickup on `Touched`, pitch rises a half-step per collect.

| Name | Asset ID |
|------|----------|
| CoinCollect | 135483737426662 |

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
