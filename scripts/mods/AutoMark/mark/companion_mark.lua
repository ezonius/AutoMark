local mod                          = get_mod("AutoMark")
local context                      = mod.context
local mod_settings                 = mod.settings
local mark_context                 = mod.mark_context
local TAG_NAMES                    = mod.TAG_NAMES

-- Global Cache
local CLASS                        = CLASS
local HEALTH_ALIVE                 = HEALTH_ALIVE
local Managers                     = Managers
local callback                     = callback

-- Outline Name For Execution Order Detection
local EXECUTION_ORDER_OUTLINE_NAME = "adamant_mark_target"

-- Callback Function for Companion Mark
local function companion_mark_callback()
    local smart_tag_system = context.smart_tag_system
    if not smart_tag_system then
        return
    end

    local target_unit = mod:find_target_unit()
    if not target_unit then
        return
    end

    local target_tag = smart_tag_system:unit_tag(target_unit)
    local tag_name = TAG_NAMES.COMPANION_TAG
    mod:on_manual_mark(mark_context[tag_name], target_unit)
    mod:mark(tag_name, target_unit, target_tag)
end

-- Callback Function for Enemy Mark
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

    local tag_name = TAG_NAMES.ENEMY_TAG
    mod:on_manual_mark(mark_context[tag_name], target_unit)
    mod:mark(tag_name, target_unit, target_tag)
end

-- Companion Mark Keybind Function
mod.companion_mark = function()
    if not context.mod_enabled or not context.game_mode_valid or context.class_name ~= "adamant" or not context.has_companion then
        return
    end

    local companion_command_tap = context.companion_command_tap
    if companion_command_tap == "double" then
        local cb = callback(companion_mark_callback)
        Managers.state.game_mode:register_physics_safe_callback(cb)
    elseif companion_command_tap == "single" then
        local cb = callback(enemy_mark_callback)
        Managers.state.game_mode:register_physics_safe_callback(cb)
    end
end

-- Check If Target Unit Is Marked by Execution Order
local function is_marked_by_execution_order(unit)
    local outline_system = context.outline_system
    local extension = outline_system and outline_system._unit_extension_data[unit]
    local outlines = extension and extension.outlines
    if not outlines then
        return false
    end

    for i = 1, #outlines do
        if outlines[i].name == EXECUTION_ORDER_OUTLINE_NAME then
            return true
        end
    end

    return false
end

-- Cache All Units Marked by Execution Order
function mod:init_execution_order_units()
    local smart_tag_system = context.smart_tag_system
    if not smart_tag_system then
        return
    end

    local unit_extension_data = smart_tag_system._unit_extension_data
    if not unit_extension_data then
        return
    end

    local execution_order_units = mark_context.execution_order_units
    for unit, smart_tag_extension in pairs(unit_extension_data) do
        if HEALTH_ALIVE[unit]
            and smart_tag_extension._target_type == "breed"
            and is_marked_by_execution_order(unit)
        then
            execution_order_units[unit] = true
        end
    end
end

-- Cache Unit Marked by Execution Order
mod:hook_safe(CLASS.OutlineSystem, "add_outline",
    function(self, unit, outline_name)
        if outline_name == EXECUTION_ORDER_OUTLINE_NAME then
            mark_context.execution_order_units[unit] = true
        end
    end)

-- Uncache Unit Unmarked by Execution Order
mod:hook_safe(CLASS.OutlineSystem, "remove_outline",
    function(self, unit, outline_name)
        if outline_name == EXECUTION_ORDER_OUTLINE_NAME then
            mark_context.execution_order_units[unit] = nil
        end
    end)

-- Uncache Unit Dead
mod:hook_safe(CLASS.OutlineSystem, "on_remove_extension",
    function(self, unit, extension_name)
        mark_context.execution_order_units[unit] = nil
    end)

-- Hook for Companion Dog Attack Info
mod:hook_safe(CLASS.AttackReportManager, "add_attack_result",
    function(self, damage_profile, attacked_unit, attacking_unit, attack_direction, hit_world_position, hit_weakspot,
             damage, attack_result, attack_type, damage_efficiency, is_critical_strike)
        local player = context.player
        local player_unit = player and player.player_unit
        if not mod_settings.companion_cancel_mark
            or attack_type ~= "companion_dog"
            or attacking_unit ~= player_unit
        then
            return
        end

        local tag_context = mark_context[TAG_NAMES.COMPANION_TAG]
        local marked_tag = tag_context.tag
        if marked_tag
            and marked_tag._target_unit == attacked_unit
            and tag_context.pounce_start_time == nil
        then
            tag_context.pounce_start_time = mod:gameplay_time()
        end
    end)
