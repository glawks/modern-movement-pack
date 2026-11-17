-- Modern Movement Pack v0.3.1: experimental RAC2/3-inspired responsiveness.
-- Separate Luau module; leaves v0.2.0 jumping code in main.luau unchanged.
-- OpenRAC hooks are CHAINED: always call original() exactly once.
-- No forced position/velocity changes, global gravity changes, or speed cap boosts.
-- Layout: lombyte-project/Lombyte/include/rnc/hero/hero.h
-- Ground tuning: Lombyte hero_switch_item.c speed_step/set_planar_vel/turn_to
-- Base address: PAL D_0013F450, NTSC-U D_0013F350.

if openrac.game ~= "rac1" then error("Modern Movement Pack requires RAC1") end

local hero = if openrac.version == "pal" then 0x0013F450 else 0x0013F350
local time_addr = if openrac.version == "pal" then 0x0015EE6C else 0x0015ED6C

local enabled = openrac.setting("movement_enabled") == true
local acceleration = openrac.setting("acceleration_response") or 0.35
local braking = openrac.setting("braking_response") or 0.40
local ground_turn = openrac.setting("ground_turn_multiplier") or 1.25
local air_turn = openrac.setting("air_turn_multiplier") or 1.20
local diagnostic = openrac.setting("log_movement") == true

local seen = { accelerate = false, brake = false, turn = false, air_turn = false }
local function once(label, description)
    if not diagnostic or seen[label] then return end
    seen[label] = true
    openrac.log("Modern Movement Pack: " .. description)
end

local function r(type_name, offset)
    return openrac.read(type_name, hero + offset)
end
local function w(type_name, offset, value)
    openrac.write(type_name, hero + offset, value)
end
local function finite(v)
    return v == v and math.abs(v) < 100000.0
end

-- The normal on-foot run only. Never interfere with ice, swimming, wading,
-- magnetic/nonstandard gravity, crouch/strikes, vehicles, or other jump states.
local function standard_run()
    if not enabled or r("i32", 0x2084) ~= 2 then return false end
    if r("i32", 0x22A8) <= 0 or r("u8", 0x20A4) ~= 0 then return false end
    if r("u8", 0x20B3) ~= 0 or r("u8", 0x12E2) ~= 0 then return false end
    if r("u8", 0x12EA) ~= 0 or r("u8", 0x20A9) ~= 0 then return false end
    if r("u8", 0x12E7) ~= 0 or r("i16", 0x308) ~= 0 then return false end
    local ground_distance = r("f32", 0x2DC)
    return finite(ground_distance) and ground_distance > -0.2 and ground_distance < 1.0
end

-- This hook is called as the game constructs planar velocity from ground_speed.
-- Accelerate or decelerate *towards the game's existing target*, never past it:
-- no sprint modifier, no artificial speed cap, no X/Y impulse or teleport.
openrac.hook("rac1.player.set_planar_velocity", function(original, angle)
    if standard_run() then
        local speed = r("f32", 0x194)
        local target = r("f32", 0x190)
        local dt = openrac.read("f32", time_addr)
        -- The engine uses a per-tick speed of roughly dt * 5.7 at full run.
        -- Reject unusual speed values instead of touching special modes.
        if finite(dt) and dt >= 0.010 and dt <= 0.025
            and finite(speed) and finite(target)
            and speed >= 0.0 and target >= 0.0
            and speed <= dt * 10.0 and target <= dt * 10.0 then
            if target > speed + 0.00001 and acceleration > 0.0 then
                local next_speed = speed + (target - speed) * acceleration
                w("f32", 0x194, math.min(target, next_speed))
                once("accelerate", string.format("run acceleration applied %.2f", acceleration))
            elseif target + 0.00001 < speed and braking > 0.0 then
                local next_speed = speed - (speed - target) * braking
                w("f32", 0x194, math.max(target, next_speed))
                once("brake", string.format("run braking applied %.2f", braking))
            end
        end
    end
    return original(angle)
end)

-- Multiplying spring stiffness/turn cap only for an ordinary run preserves
-- the game's weapon, ledge and jump-specific turn mechanics and controls.
openrac.hook("rac1.player.turn_to_heading", function(original, mode, stiffness, damping, limit)
    if standard_run() and ground_turn > 1.0 then
        local stick = r("f32", 0x229C)
        -- Do not boost weapon animation steering (which uses separate tuning).
        if finite(stick) and stick >= 0.25 and r("u8", 0x20A8) == 0
            and finite(stiffness) and finite(damping) and finite(limit)
            and stiffness > 0 and stiffness < 0.25
            and damping >= 0 and damping < 0.4 and limit > 0 and limit < 1.2 then
            once("turn", string.format("ground turn multiplier %.2f", ground_turn))
            return original(mode, stiffness * ground_turn, damping, limit * ground_turn)
        end
    end
    return original(mode, stiffness, damping, limit)
end)

-- Only increase the regular jump air turn cap. Do not increase air speed,
-- acceleration, or high-jump/long-jump directional motion without calibration.
-- This field is initialized on jump entry. Accept only its retail baseline or
-- the value we last installed, to avoid clobbering a different movement mod.
local last_air_value = nil
openrac.on_frame(function()
    if not enabled or air_turn <= 1.0 then return end
    local state = r("i32", 0x2084)
    if state ~= 7 and state ~= 9 and state ~= 0xE then
        last_air_value = nil
        return
    end
    if r("i32", 0x22A8) <= 0 or r("u8", 0x20A4) ~= 0
        or r("u8", 0x20B3) ~= 0 then return end
    local dt = openrac.read("f32", time_addr)
    if not finite(dt) or dt < 0.010 or dt > 0.025 then return end
    local base = dt * 15.0098314
    local current = r("f32", 0x414)
    if not finite(current) then return end
    local target = base * air_turn
    local retail = math.abs(current - base) < 0.015
    local ours = last_air_value ~= nil and math.abs(current - last_air_value) < 0.015
    if retail or ours then
        w("f32", 0x414, target)
        last_air_value = target
        once("air_turn", string.format("air turn multiplier %.2f", air_turn))
    end
end)

openrac.log("Modern Movement Pack v0.3.1 movement module loaded; responsiveness tuning "
    .. (if enabled then "enabled" else "disabled"))
