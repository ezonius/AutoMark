---@class AutoMarkMod:DMFMod
local mod                           = get_mod("AutoMark")
local context                       = mod.context
local mark_context                  = mod.mark_context
local TAG_NAMES                     = mod.TAG_NAMES
local ENEMY_TAG_NAME                 = TAG_NAMES.ENEMY_TAG
local SERVO_SKULL_TAG_NAME           = TAG_NAMES.SERVO_SKULL_TAG
local mod_settings                  = mod.settings

-- Imports
local SpecialRulesSettings          = require("scripts/settings/ability/special_rules_settings")
local CompanionServoSkullSettings   = require("scripts/settings/companion/companion_servo_skull_settings")
local Hud                           = require("scripts/utilities/ui/hud")
local special_rules                 = SpecialRulesSettings.special_rules
local servo_skull_states            = CompanionServoSkullSettings.STATES

-- Global Cache
local RESOLUTION_LOOKUP             = RESOLUTION_LOOKUP
local Managers                      = Managers
local callback                      = callback
local Unit_alive                     = Unit.alive
local GameSession                    = GameSession
local GameSession_game_object_exists    = GameSession.game_object_exists
local GameSession_game_object_field     = GameSession.game_object_field
local Hud_hud_scale                  = Hud.hud_scale
local math_huge                      = math.huge

local function servo_skull_mark_callback()
    local smart_tag_system = context.smart_tag_system
    if not smart_tag_system then
        return
    end

    local target_unit = mod:find_target_unit()
    if not target_unit then
        return
    end

    local target_tag = smart_tag_system:unit_tag(target_unit)
    local tag_name = SERVO_SKULL_TAG_NAME
    mod:on_manual_mark(mark_context[tag_name], target_unit)
    mod:mark(tag_name, target_unit, target_tag)
end

local function enemy_mark_callback()
    local smart_tag_system = context.smart_tag_system
    if not smart_tag_system then
        return
    end

    local target_unit = mod:find_target_unit()
    if not target_unit then
        return
    end

    local target_tag = smart_tag_system:unit_tag(target_unit)
    if target_tag then
        return
    end

    local tag_name = ENEMY_TAG_NAME
    mod:on_manual_mark(mark_context[tag_name], target_unit)
    mod:mark(tag_name, target_unit, target_tag)
end

mod.servo_skull_mark = function()
    if not context.mod_enabled or not context.game_mode_valid or context.class_name ~= "cryptic" or not context.has_servo_skull then
        return
    end

    local companion_command_tap = context.companion_command_tap
    if companion_command_tap == "double" then
        local cb = callback(servo_skull_mark_callback)
        Managers.state.game_mode:register_physics_safe_callback(cb)
    elseif companion_command_tap == "single" then
        local cb = callback(enemy_mark_callback)
        Managers.state.game_mode:register_physics_safe_callback(cb)
    end
end


