# Modern Movement Pack — OpenRAC RAC1 v0.3.0 (experimental)

**RAC2/3-inspired movement responsiveness and RAC3-inspired jumping**, brought together in one optional, configurable quality-of-life mod for *Ratchet & Clank 1*.

> Development test build — no in-game validation yet. This does **not** recreate RAC2 or RAC3 physics exactly. Test with a backup save and enable this mod alone initially.

**Identity:** the OpenRAC mod ID is `modern-movement-pack`. Early unpublished jumping prototypes used `equal-pack-jumps`, but no released-version compatibility is necessary. If you installed an older **test** ZIP, uninstall that prototype to avoid duplicate mod IDs and conflicting movement effects. The repository can be renamed from `glawks/rac3-style-jumping` to `glawks/modern-movement-pack` in GitHub **Settings → General → Repository name** without deleting history or branches; current links use the existing repository address until it is renamed.

## Movement options (new in v0.3.0)

| Setting | Default | Behaviour |
|---|---|---|
| Modern movement | On | Master toggle for the movement changes; independent of jumping |
| Faster acceleration | 0.35 | Closes an extra 35% of the distance to the game's existing ground-speed target at the planar-velocity hook |
| Faster braking | 0.40 | Closes an extra 40% when the ground-speed target is below the current speed **while running**; does not replace the stop animation |
| Faster ground turns | 1.25× | Increases normal-run turn responsiveness and turn cap; not weapon/cutscene steering |
| Faster air turns | 1.20× | Increases regular standing, running and double-jump turn cap; no jump-speed increase |
| Movement diagnostics | Off | Logs first activation of each adjustment for troubleshooting |

The movement logic operates **only on foot with normal gravity**. Ground speed tweaks exclude ice, wading, slipping and magnetic surfaces. It never changes Ratchet's maximum run speed, forcibly moves his position, or bypasses collision detection. Air speed is unchanged. Camera response and strafing are **not** implemented in v0.3.0.

## Jumping options (retained from v0.2.0)

| Setting | Default | Behaviour |
|---|---|---|
| RAC3-style standing jump | On | RAC1 standing height targets 1.47/2.62 → documented RAC3 short/full-held 1.42/2.70 game units |
| Thruster high-jump parity | On | Experimental +0.25 target-height compensation compared to Heli-Pack |
| Extra high-jump height (both packs) | 0.00 | Optional height offset for tuning |
| Heli double-jump parity | On | Experimental early-rise boost based on RAC1 Thruster behaviour |
| Extra double-jump height (both packs) | 0.00 | Optional additional double-jump target-height boost |
| Jump-height logging | On | Logs jump apex estimates for comparisons |

Jump parameters aren't verified identical to RAC3 in-game. RAC1's level-specific movement, gravity and animations remain.

## Download and install the dev build

1. Visit [Actions → build](https://github.com/glawks/rac3-style-jumping/actions/workflows/build.yml?query=branch%3Adev), choose the newest successful `dev` run.
2. Under **Artifacts**, download the `modern-movement-pack-*` artifact ZIP.
3. Extract the artifact; install the inner `modern-movement-pack-0.3.0.zip` through OpenRAC's launcher.
4. Restart RAC1 after changing any settings. Supports **PAL and NTSC-U**, and Luau runs on Windows, Linux, macOS and supported other OpenRAC platforms without native libraries.

CI validates the manifest and creates the installable ZIP + SHA256SUMS on each `dev` push. Version tags (`v*`) are configured to publish public GitHub Releases. **No release tag has been made for v0.3.0.**

## Test checklist

- **Movement only:** disable all jump settings, keep Modern movement on. Compare walking/running from rest, releasing and reversing the stick, and turning through 180 degrees.
- **Acceleration:** does Ratchet reach original top speed more promptly, without becoming faster at full speed?
- **Braking:** compare sudden stick release and 180-degree reversals; the first revision only affects the normal-run speed target, so a stop state may remain unchanged.
- **Ground turning:** change ground turn multiplier to 1.00 to compare with mod enabled/disabled.
- **Air turning:** compare a normal standing or running jump at 1.00 and 1.20. High/long jumps are intentionally excluded.
- **Jump heights:** repeat Heli-Pack and Thruster-Pack high/double jumps from the same flat location; report `peak` lines from the OpenRAC game log.
- **Exclusions:** ice, underwater/swimming, combat, vehicles, magnetic walking, and ledge interactions should retain normal behaviour.
- **Compatibility:** re-enable your other mods after standalone testing; turn off overlapping movement options if another mod changes those controls.

Set **Movement diagnostics = On** if nothing visibly changes and send the OpenRAC log. It prints a one-time line for each movement adjustment successfully applied. Source-level packaging tests cannot confirm gameplay physics.

## Technical details

`main.luau` retains v0.2.0 jump tuning; `movement.luau` adds independent turn and speed hooks:
- `rac1.player.set_planar_velocity`: adjusts `ground_speed` (+0x194) toward the game's existing `target_speed` (+0x190) during ordinary ground running. Preserves target speed bounds.
- `rac1.player.turn_to_heading`: scales ordinary-run turn stiffness and maximum turn rate, then calls the original hook exactly once.
- `on_frame`: updates `air_turn_rate` (+0x414) only on regular jumps with recognised baseline values.

**Known limitations:** animation transition times aren't changed; braking after entering the STOP state may be identical to retail; run turning may be constrained by animations; movement feel isn't quantitatively matched to RAC2/3; and game-level tests are required. No changes to camera or strafing yet.

### Sources
- [RAC1 movement and hero structure (Lombyte)](https://github.com/lombyte-project/Lombyte/blob/main/include/rnc/hero/hero.h)
- [Ground speed and turning (Lombyte)](https://github.com/lombyte-project/Lombyte/blob/main/src/overlays/shared/hero/hero_switch_item.c)
- [OpenRAC scripting API](https://github.com/OpenRAC/OpenRAC/blob/develop/sdk/docs/scripts.md)
- [RAC3 jumping reference](https://github.com/OpenRAC/rac3-decomp/blob/master/include/structs/hero.h)

MIT licensed original mod by glawks. No copyrighted game assets included.
