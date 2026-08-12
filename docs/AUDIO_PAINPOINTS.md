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

<!--
Template for the next entry:

## N. <short title>

**What happened.**

**Who it hurts.**

**The ask.**

**Current workarounds.**

**Priority.**
-->
