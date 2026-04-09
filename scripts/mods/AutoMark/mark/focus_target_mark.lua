local mod          = get_mod("AutoMark")
local context      = mod.context
local mod_settings = mod.settings
local mark_context = mod.mark_context
local TAG_NAMES    = mod.TAG_NAMES

-- Global Cache
local CLASS        = CLASS
local Managers     = Managers
local callback     = callback

-- Constants
local MELEE_RANGE  = 5

-- Manual Focus Target Mark on Attack
local function focus_target_switch_callback(is_melee)
    local smart_targeting_extension = context.smart_targeting_extension
    local smart_tag_system = context.smart_tag_system
    if not smart_targeting_extension or not smart_tag_system then
        return
    end

    local tag_name = TAG_NAMES.VETERAN_TAG
    local target_unit, target_tag

    if is_melee then
        target_unit, target_tag = mod:find_target_unit_custom("focus_target_melee", 0, MELEE_RANGE, tag_name)
    else
        target_unit = mod:find_target_unit()
    end

    target_tag = target_tag or smart_tag_system:unit_tag(target_unit)
    if not target_unit or not mod:is_target_valid(tag_name, target_tag, target_unit) then
        return
    end

    mod:on_manual_mark(mark_context[tag_name], target_unit)
    mod:mark(tag_name, target_unit, target_tag)
end

local function focus_target_switch(is_melee)
    if not context.mod_enabled or not context.game_mode_valid or context.class_name ~= "veteran" or not context.has_focus_target then
        return
    end

    local cb = callback(focus_target_switch_callback, is_melee)
    Managers.state.game_mode:register_physics_safe_callback(cb)
end

local MELEE_ACTION_KINDS = {
    windup = true,
    sweep = true,
}
local RANGED_ACTION_KINDS = {
    shoot_hit_scan = true,
    shoot_pellets = true,
    overload_charge = true,
    charge_ammo = true,
}
mod:hook_safe(CLASS.ActionHandler, "start_action",
    function(self, id, action_objects, action_name, action_params, action_settings, used_input, t, transition_type,
             condition_func_params, automatic_input, reset_combo_override)
        if not mod_settings.focus_target_switch
            or self._unit_data_extension._player.viewport_name ~= 'player1'
            or id ~= "weapon_action"
            or mark_context[TAG_NAMES.VETERAN_TAG].delay > 0
        then
            return
        end

        local action_kind = action_settings.kind
        if mod_settings.focus_target_switch_melee and MELEE_ACTION_KINDS[action_kind] then
            focus_target_switch(true)
        elseif mod_settings.focus_target_switch_range and RANGED_ACTION_KINDS[action_kind] then
            focus_target_switch(false)
        end
    end)
