-- RAC3-Style Jumping (Experimental) v0.2.0 - Ratchet & Clank 1, OpenRAC Luau.
-- Existing mod ID "equal-pack-jumps" retained for upgrades from v0.1.0.
-- All numbers are GAME units, NOT real-world metres.
-- RAC3 normal standing-jump values are documented in OpenRAC/rac3-decomp.
-- Other jump adjustments are experimental until measured against RAC3.
--
-- Target game structures: lombyte-project/Lombyte/include/rnc/hero/hero.h
-- RAC1 vertical motion: OpenRAC/OpenRAC/port/game/rac1-pal/hand/level_hero_vertical.c
-- Do not blindly multiply gravity or write hero position.

if openrac.game ~= "rac1" then
    error("RAC3-Style Jumping only supports Ratchet & Clank 1")
end

local hero = if openrac.version == "pal" then 0x0013F450 else 0x0013F350
local frame_time_address = if openrac.version == "pal" then 0x0015EE6C else 0x0015ED6C

local match_normal = openrac.setting("rac3_normal_jump") == true
local match_thruster_high = openrac.setting("thruster_high_jump") == true
local thruster_high_bonus = openrac.setting("high_jump_bonus") or 0.25
local common_high_bonus = openrac.setting("extra_high_jump") or 0.0
local match_heli_double = openrac.setting("heli_double_jump") == true
local common_double_bonus = openrac.setting("extra_double_jump") or 0.0
local log_heights = openrac.setting("log_jump_heights") == true

local STATE_STANDING_JUMP = 0x07
local STATE_RUNNING_JUMP = 0x09
local STATE_HIGH_JUMP = 0x0B
local STATE_DOUBLE_JUMP = 0x0E
local PACK_HELI = 2
local PACK_THRUSTER = 3

-- Offset +0x408 is takeoff_pos.z, NOT a ground-floor guess.
-- +0x430, +0x488 and +0x48C are current/start/target jump heights.
-- Hero velocity's vertical component is +0xE8 in normal Z-up areas.
local function r(type_name, offset)
    return openrac.read(type_name, hero + offset)
end

local function w(type_name, offset, value)
    openrac.write(type_name, hero + offset, value)
end

local function near(a, b, tolerance)
    return math.abs(a - b) <= tolerance
end

local function pack_name(id)
    if id == PACK_HELI then
        return "Heli-Pack"
    elseif id == PACK_THRUSTER then
        return "Thruster-Pack"
    else
        return "No pack"
    end
end

local function move_name(state)
    if state == STATE_STANDING_JUMP then
        return "standing jump"
    elseif state == STATE_RUNNING_JUMP then
        return "running jump"
    elseif state == STATE_HIGH_JUMP then
        return "high jump"
    elseif state == STATE_DOUBLE_JUMP then
        return "double jump"
    end
    return nil
end

-- Only change jump parameters if the retail baseline is still present.
-- Never overwrite other mods' height parameters or apply the bonus twice.
-- On-frame runs immediately after the game tick, so current height has usually
-- progressed very slightly; keep that progress by applying the start delta.
local function replace_jump_targets(base_start, base_target, new_start, new_target)
    local start = r("f32", 0x488)
    local target = r("f32", 0x48C)
    local current = r("f32", 0x430)
    if not (near(start, base_start, 0.025) and near(target, base_target, 0.025)) then
        return false
    end
    if current ~= current or current < base_start - 0.5 or current > base_target + 0.5 then
        return false
    end
    w("f32", 0x488, new_start)
    w("f32", 0x48C, new_target)
    w("f32", 0x430, current + (new_start - base_start))
    return true
end

-- Double-jump baseline depends on height above the ground, not a constant.
-- The original maintains target = start + 0.05 at state entry.
local function add_double_jump_height(bonus)
    if bonus <= 0.0 then return false end
    local start = r("f32", 0x488)
    local target = r("f32", 0x48C)
    local current = r("f32", 0x430)
    if start ~= start or target ~= target or current ~= current then return false end
    if start < 0.65 or start > 1.95 or not near(target - start, 0.05, 0.025) then
        return false
    end
    if current < start - 0.5 or current > target + 0.5 then return false end
    w("f32", 0x488, start + bonus)
    w("f32", 0x48C, target + bonus)
    w("f32", 0x430, current + bonus)
    return true
end

local tracked = nil
local last_state = -1
local last_ticks = -1

local function finish_track()
    if tracked == nil then return end
    if log_heights and tracked.frames > 3 and tracked.seen_air then
        openrac.log(string.format(
            "%s %s peak %.3f units (sampled from first frame, %d ticks, %s)",
            tracked.pack, tracked.move, tracked.peak - tracked.start_z,
            tracked.frames, tracked.tuning
        ))
    end
    tracked = nil
end

openrac.on_frame(function()
    local state = r("i32", 0x2084)
    local ticks = r("i32", 0x198)
    local pack_state = r("i32", 0x1090 + 3 * 0x50 + 0x24)
    local pack_id = r("i32", 0x1090 + 3 * 0x50 + 0x28)
    local pack_disabled = r("i16", 0x22D8)
    local vehicle = r("u8", 0x20A4)
    local z = r("f32", 0x88)
    local hp = r("i32", 0x22A8)
    local valid_pack = pack_state == 2 and (pack_id == PACK_HELI or pack_id == PACK_THRUSTER)
    local valid_play = vehicle == 0 and hp > 0 and z == z and math.abs(z) < 100000.0
    local move = move_name(state)

    -- Standing/running jumps work without Clank. Pack moves require a ready,
    -- enabled Heli-/Thruster-Pack. Ignore vehicle modes and dead Ratchet.
    if not valid_play or ((state == STATE_HIGH_JUMP or state == STATE_DOUBLE_JUMP)
        and (not valid_pack or pack_disabled ~= 0)) then
        finish_track()
        last_state = state
        last_ticks = ticks
        return
    end

    -- Detect repeat jumps even when the game returns to the same state ID
    -- without this script sampling the intermediary state.
    local entered = state ~= last_state or (ticks >= 0 and last_ticks >= 0 and ticks < last_ticks)

    if entered and move ~= nil then
        finish_track()
        tracked = {
            move = move,
            pack = pack_name(if valid_pack then pack_id else -1),
            start_z = z,
            peak = z,
            frames = 0,
            seen_air = false,
            early_boost_logged = false,
            tuning = "vanilla",
        }

        if state == STATE_STANDING_JUMP and match_normal then
            -- RAC1 standing: 1.47 short / 2.62 fully held.
            -- RAC3 decomp standing: 1.42 short / 2.70 fully held.
            -- The games' other movement/gravity still differ.
            if replace_jump_targets(1.47, 2.62, 1.42, 2.70) then
                tracked.tuning = "RAC3 standing targets"
            end
        elseif state == STATE_HIGH_JUMP then
            local bonus = common_high_bonus
            if pack_id == PACK_THRUSTER and match_thruster_high then
                bonus += thruster_high_bonus
            end
            if bonus > 0.0 and replace_jump_targets(3.2, 3.25, 3.2 + bonus, 3.25 + bonus) then
                tracked.tuning = string.format("high-jump +%.2f", bonus)
            end
        elseif state == STATE_DOUBLE_JUMP then
            if add_double_jump_height(common_double_bonus) then
                tracked.tuning = string.format("double-jump +%.2f", common_double_bonus)
            end
        end
    end

    -- The RAC1 code applies an extra multiplier and altered falloff gates
    -- to Thruster's double jump. Approximate that on Heli's early rise only.
    -- Not guaranteed identical: measured peaks are needed for calibration.
    if state == STATE_DOUBLE_JUMP and valid_pack and pack_id == PACK_HELI and match_heli_double then
        if ticks >= 0 and ticks < 8 then
            local dt = openrac.read("f32", frame_time_address)
            local velocity = r("f32", 0xE8)
            local rise = z - r("f32", 0x408)
            local gravity = r("f32", 0x4A0)
            if dt > 0.005 and dt < 0.05 and velocity >= -0.02 and velocity < 0.5
                and rise > -0.1 and rise < 8.0 and gravity >= 0 and gravity < 0.1 then
                local factor = 1.0
                if rise > 2.7 then
                    factor = 0.47
                elseif rise > 2.1 then
                    factor = 0.7
                end
                local target = dt * 7.0 * factor * 1.25 - gravity
                if target > velocity then
                    w("f32", 0xE8, target)
                    if tracked ~= nil and not tracked.early_boost_logged then
                        tracked.tuning = tracked.tuning .. " + Heli early-rise boost"
                        tracked.early_boost_logged = true
                    end
                end
            end
        end
    end

    -- Keep measuring while the state changes to falling/gliding, until landing.
    if tracked ~= nil then
        tracked.frames += 1
        if z > tracked.peak then tracked.peak = z end
        local airborne_frames = r("u16", 0x30E)
        if airborne_frames > 0 then tracked.seen_air = true end
        if (tracked.seen_air and airborne_frames == 0) or tracked.frames >= 210 then
            finish_track()
        end
    end

    last_state = state
    last_ticks = ticks
end)

openrac.log("RAC3-Style Jumping v0.2.0 loaded (experimental; jump-height logging optional)")
