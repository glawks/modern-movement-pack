# RAC3-Style Jumping — OpenRAC RAC1 (experimental v0.2.0)

Make *Ratchet & Clank 1* jumping closer to *Ratchet & Clank 3* without replacing Ratchet's animations, controls or movement system. **This is an untested development build.** Please use a backup/spare save for the first test.

This is an **update** to *Equal Pack Jumps v0.1.0*: the permanent mod ID remains `equal-pack-jumps`, so it replaces the previous version rather than installing alongside it. The launcher display name is now **RAC3-Style Jumping (Experimental)**.

## What it changes

| Feature | Default | What it does |
|---|---|---|
| **RAC3-style standing jump** | On | Sets a standing jump's short/full-held targets from RAC1's **1.47 / 2.62** to RAC3's documented **1.42 / 2.70** game units. No claim of identical trajectories. |
| **Thruster high-jump parity** | On | An adjustable experimental **+0.25** high-jump target bonus on Thruster only. Designed to compensate for its lower jump relative to Heli; actual parity **not yet measured**. |
| **Extra high jump (both packs)** | 0.00 | Optional common boost, independently adjustable. RAC3 high-jump height is not yet verified. |
| **Heli double-jump parity** | On | Early-rise velocity adjustment approximating the Thruster's RAC1 double-jump behaviour. **Not an exact emulation** yet. |
| **Extra double jump (both packs)** | 0.00 | Optional shared double-jump boost to dial in against measured RAC3 heights. |
| **Jump-height logging** | On | Logs a standing, running, high or double jump's peak relative to its first sampled frame, for pack comparisons. |

**Running jumps, long jumps, hover/glide, weapon fire, animations and input bindings are left unchanged.** RAC1's running-jump target is already 2.70 units; that is not proof it matches RAC3's running jump. All values here are gameplay units, not metres.

## Install and download a dev build

1. Open the [dev Actions runs](https://github.com/glawks/rac3-style-jumping/actions/workflows/build.yml?query=branch%3Adev), select a successful build, and download its artifact under **Artifacts**. Extract the GitHub artifact and install the inner `equal-pack-jumps-0.2.0.zip` through the OpenRAC launcher.
2. Enable **RAC3-Style Jumping (Experimental)** in RAC1, restart the game to apply settings, and load a **spare or backed-up save**.
3. Supports **RAC1 PAL and NTSC-U**. This is a script mod: no Windows DLL or Linux/macOS build is needed.

On a later `v*` Git tag, CI will publish the mod ZIP and `SHA256SUMS` on a GitHub Release. No tag or public release is required to test `dev`.

## Suggested test sequence

1. On flat ground with normal gravity, jump without Clank: tap **X** and then repeat holding **X**. Compare with the mod off to confirm the slight normal-jump change.
2. Equip the **Heli-Pack** and do a stationary high jump (**R1 + X**) and double jump (**X, X**).
3. Change to the **Thruster-Pack** and repeat the same moves in the same place, with the same jump-button timing.
4. Check the OpenRAC game log for `RAC3-Style Jumping`, `high jump peak` and `double jump peak`. Share the lines and whether the packs feel equal.
5. If needed, tune **Thruster high-jump bonus** by 0.05 increments. Extra common bonuses should stay 0 until a real RAC3 reference jump has been measured.

The log's peak is sampled after the first frame of the new state, so it **slightly underestimates total jump rise**. It's meant for repeatable A/B comparisons, not a definitive physical measurement. Running speed, slopes, precise press timing and moving platforms all affect results.

If other movement mods are enabled, test this one **by itself first**, since all of them may modify the same state fields.

## How it works

OpenRAC 1.1 Luau script using `on_frame`, `read`, `write`, and `setting`. Version-specific RAM bases: PAL `0x0013F450`, NTSC-U `0x0013F350`. The script checks Ratchet is alive and on foot. It detects jump-state changes and adjusts initial jump-height fields (`+0x430`, `+0x488`, `+0x48C`) **only when the original values match expected retail baselines**. The Heli double-jump tweak affects early vertical velocity (`+0xE8`) during state `0xE`. There is no direct teleport, broad gravity multiplier, permanent save modification, or gameplay executable patch.

**Unverified**: whether the post-tick application produces identical apex heights; whether parity settings work for every level/gravity type; interactions with other physics mods; and exact RAC3 high and double-jump target values. In-game tests are required before a public 1.0 release.

### Source references

- [RAC1 jump baselines and states](https://github.com/lombyte-project/Lombyte/blob/main/src/overlays/l02/hero/hero_set_state.c)
- [RAC1 hero memory layout](https://github.com/lombyte-project/Lombyte/blob/main/include/rnc/hero/hero.h)
- [RAC1 vertical movement](https://github.com/OpenRAC/OpenRAC/blob/develop/port/game/rac1-pal/hand/level_hero_vertical.c)
- [RAC3 standing-jump min/max values (documented hero layout)](https://github.com/OpenRAC/rac3-decomp/blob/master/include/structs/hero.h)
- [OpenRAC scripting API](https://github.com/OpenRAC/OpenRAC/blob/develop/sdk/docs/scripts.md)

MIT-licensed original mod code by glawks. No game assets included.
