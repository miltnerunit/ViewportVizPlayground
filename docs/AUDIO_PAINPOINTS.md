# Audio UI/UX pain points & feature campaign list

A running list of friction points hit while building audio in Studio, and the features
worth campaigning for internally. Framed from the perspective of **sound designers doing
this work manually** (not scripters) — the bar is "can a non-programmer do this without a
Command Bar workaround?"

Format per entry: what happened → who it hurts → the ask → current workaround → priority.

---

## 1. Can't save / reuse custom attenuation curves

**What happened.** `AudioEmitter.DistanceAttenuation` is a per-emitter custom curve, edited
in the *Attenuation Curve Editor*. The editor's preset dropdown ("Custom") only offers
Roblox's built-in shapes (No Attenuation / Linear / Inverse / …). Once you hand-tune a curve
(keypoints + bezier tangents) there is **no way to save it as a named preset**, and no way to
**select that saved curve on another emitter**. Custom curves are trapped on the one emitter.

**Who it hurts.** Sound designers, most acutely. A scene with many emitters (ambient props,
foliage, pickups) means re-drawing the *same* falloff curve by hand on every emitter, or
asking a scripter for help. There's no shareable curve library across emitters, places, or
team members.

**The ask (features to campaign for).**
- **Save custom curve as a named preset** in the Attenuation Curve Editor dropdown.
- **Curve presets are selectable across emitters** (pick "MyAmbientFalloff" on any emitter).
- **Copy/paste a curve** directly between emitters in the editor (incl. tangents).
- Stretch: a **place- or team-level curve library** so presets are shared, not per-emitter.

**Current workarounds (both bad for a non-scripter).**
- **Duplicate the instance** — copies the emitter *and* its curve (tangents included), and
  Studio re-points the internal `Wire` references. Works, but only if you author one emitter
  fully *then* duplicate; it doesn't help push a curve onto emitters that already exist.
- **Command Bar script** — `source:GetDistanceAttenuation()` → `e:SetDistanceAttenuation(curve)`
  across emitters. Transfers keypoints but **not the bezier tangents**, so copies are subtly
  less smooth. Requires scripting — off-limits for the sound designers this should serve.

**Priority.** High for content-heavy scenes. The manual-redraw tax scales linearly with
emitter count and there is no non-scripter path to reuse.

---

## 2. No "play on start" for `AudioPlayer` (ambient loops need a script)

**What happened.** The legacy `Sound` had a serializable `Playing` property — tick it in the
Properties panel and the sound plays on load, no code. The modern `AudioPlayer` has **no
equivalent**. `Looping` controls whether it repeats, but nothing starts it: an authored,
looping `AudioPlayer` sits silent until something calls `:Play()` at runtime. So a simple
"this flower hums forever" ambient loop is impossible to author without a script.

**Who it hurts.** Sound designers, directly. The single most common ambient use case —
"place a looping sound in the world and have it play" — now *requires* a scripter. There's no
checkbox, no auto-play flag, nothing in the Properties panel that makes an authored player
start.

**The ask (features to campaign for).**
- A serializable **auto-play / play-on-start** flag on `AudioPlayer` (the `Sound.Playing`
  equivalent), so an authored looping player plays without code.
- Ideally it just works in-editor preview too, so designers can hear the loop while placing.

**Current workarounds.**
- **A runtime script** that scans for the players and calls `:Play()` — exactly what
  `FlowerAmbience.server.luau` does in this place. Works, but it's boilerplate every project
  re-invents, and it's off-limits for a non-scripter.

**Priority.** High. This is the default ambient-audio workflow and it currently has no
no-code path.

---

## 3. Attenuation Curve Editor has no unit labels or field guidance

**What happened.** The `DistanceAttenuation` property gives **no indication of what it is or
what units it uses**. The inline Properties field looks like it might take a scalar or a
comma-separated pair (like the legacy `RollOffMinDistance`/`MaxDistance`), but it's actually a
**curve**. Nothing labels the axes: X is **distance in studs**, Y is **gain (0–1)**. You only
discover this by opening the curve editor and inferring it. First instinct — "type min,max" —
is simply wrong, with no hint saying so.

**Who it hurts.** Anyone setting falloff, especially designers migrating from the legacy
`Sound` mental model of min/max rolloff distances. The concept changed (scalars → curve) with
no in-UI signposting.

**The ask (features to campaign for).**
- **Axis labels + units** in the Attenuation Curve Editor ("Distance (studs)" / "Gain (0–1)").
- A **tooltip / hint** on the `DistanceAttenuation` field explaining it's a curve, not scalars.
- Consider a **min/max convenience mode** that authors a simple curve for people who just want
  the old rolloff behavior.

**Current workarounds.**
- Trial and error in the curve editor, or ask someone who already learned the model.
- Command Bar `SetDistanceAttenuation({ [min] = 1, [max] = 0 })` if you know the API — again,
  scripter-only.

**Priority.** Medium. Not blocking, but a recurring "what do I even type here?" stumble that a
label would eliminate.

---

## 4. New audio API has no implicit listener — silent with no warning

**What happened.** The modern audio graph (`AudioPlayer` → `Wire` → `AudioEmitter`) produces
**no sound at all** unless an `AudioListener` + `AudioDeviceOutput` exist and are wired to the
player's output. The legacy `Sound`/`SoundService` path had an implicit default listener, so
things "just worked." With the new API, a fully correct emitter rig is **silent by default**,
and **nothing in Studio warns you** that a listener is missing — you just hear nothing and
have no idea why.

**Who it hurts.** Everyone adopting the new API, but especially designers who correctly built
the emitter side and reasonably assume it should be audible. The failure is silent and gives
no diagnostic pointing at the missing listener.

**The ask (features to campaign for).**
- An **in-editor warning / analyzer check**: "AudioEmitter present but no AudioListener is
  wired to an output — audio will be inaudible."
- Consider a **sensible default listener** (e.g. camera-attached) when none is authored, or a
  one-click "add listener" affordance.

**Current workarounds.**
- Author an `AudioListener` + `AudioDeviceOutput` on the camera via a client script — this
  place does it in `AudioListenerSetup.client.luau`. Boilerplate, and easy to forget, at which
  point all new-API audio is mysteriously silent.

**Priority.** High. A silent failure with no diagnostic is among the worst onboarding
experiences for the new API.

---

## 5. No way to batch-set audio asset permissions

**What happened.** To let collaborators use a set of uploaded audio files, permission has to
be granted **one audio file at a time** on the Creator website. You *can* grant to a **group**
rather than picking individual usernames — which helps the "who" axis — but you still have to
**touch every file at least once**. There's no multi-select across assets, no "select all," no
folder- or bulk-grant. Sharing a library of sounds means clicking into every single asset.

**Who it hurts.** Anyone sharing audio with collaborators — sound designers and project leads
most of all. Group grants fix the per-*person* fan-out, but toil still scales linearly with
the number of **files**: a project with dozens of stems/SFX means dozens of per-asset visits.

**The ask (features to campaign for).**
- **Multi-select + bulk "grant permission"** across audio assets — the key gap, since group
  grants already fix the per-person axis but not the per-file one.
- Grant permissions **by folder / collection**, so a whole set is shared in one action.
- Ideally a **team- or experience-level share** so audio uploaded for a place is usable by all
  collaborators on that place without per-file grants.

**Current workarounds.**
- Grant access to each audio file individually on the Creator website. Tedious and error-prone
  — easy to miss one, and there's no way to see at a glance which are shared.

**Priority.** High. Pure manual toil that scales with both asset count and collaborator count,
with no batch path at all.

---

# Other Studio pain points (non-audio)

Secondary to the audio focus above, but worth logging since they came up in the same work.
Numbered separately (N1, N2, …) so the audio list stays the headline.

## N1. Recoloring imported meshes with baked textures is near-impossible

**What happened.** Trying to recolor a set of imported flower Models to bright colors, the
part `Color` had **no effect** — the color is baked into the mesh via texture/PBR data that
survives every normal override. We tried, in order: setting `Color` (ignored), `Material =
Neon` (color came out tinted — cool hues multiplied to black against a warm baked texture),
removing the `SurfaceAppearance` (there wasn't one), and clearing `MeshPart.TextureID` (didn't
help). The color is locked somewhere unreachable per-part (likely `SpecialMesh.VertexColor`, a
`MaterialVariant`, or baked vertex colors). The only thing that reliably showed a chosen color
was a **`Highlight` overlay** — and even that can't do an outline-only look, because `Highlight`
won't render on a part at `Transparency = 1`, so you can't hide the mesh and keep just its form.

**Who it hurts.** Anyone (designers especially) trying to restyle Creator-Store / imported
mesh assets. "Change this asset's color" is a basic, expected operation that currently has no
dependable path — you end up overlaying `Highlight`s instead of actually recoloring.

**The ask (features to campaign for).**
- A dependable **"tint / override color" on a MeshPart** that wins over baked texture/PBR data
  (or a clear Properties indicator of *why* `Color` is being ignored and what's overriding it).
- **Outline / silhouette rendering that works on hidden meshes**, so "keep the form, drop the
  surface" is possible without leaving the mesh visible.
- A one-click **"strip baked appearance"** to reset a mesh to a plain recolorable state.

**Current workarounds.**
- `Highlight` per Model with a solid opaque fill — paints over the mesh in a chosen color.
  Works, but it's an overlay hack (not a real recolor), can't do outline-only, and is a per-
  instance extra instance to manage.

**Priority.** Medium (non-audio). Recurring friction whenever restyling imported assets;
no reliable non-hack path today.

---

<!--
Template for the next entry (prefix non-audio entries with N):

## N. <short title>

**What happened.**

**Who it hurts.**

**The ask.**

**Current workarounds.**

**Priority.**
-->
