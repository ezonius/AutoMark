local mod                    = get_mod("AutoMark")
local Health                 = require("scripts/utilities/health")
local breeds                 = require("scripts/settings/breed/breeds")
local Breed                  = require("scripts/utilities/breed")

-- Global Cache
local CLASS                  = CLASS
local table_clear            = table.clear
local pairs                  = pairs
local next                   = next
local type                   = type
local tostring               = tostring

-- Smart Tag Names
local TAG_NAMES              = {
    ENEMY_TAG     = "enemy_over_here",
    VETERAN_TAG   = "enemy_over_here_veteran",
    COMPANION_TAG = "enemy_companion_target",
}
mod.TAG_NAMES                = TAG_NAMES

local TAG_LIST               = {
    TAG_NAMES.COMPANION_TAG,
    TAG_NAMES.VETERAN_TAG,
    TAG_NAMES.ENEMY_TAG,
}

-- Mod Settings
local mod_settings           = {
    toggle_mod                   = mod:get("toggle_mod") or false,
    toggle_mod_keybind           = mod:get("toggle_mod_keybind") or {},
    toggle_mod_notify            = mod:get("toggle_mod_notify") or false,
    debug_mode                   = mod:get("debug_mode") or false,
    companion_mark_keybind       = mod:get("companion_mark_keybind") or {},
    execution_order_priority     = mod:get("execution_order_priority") or false,
    companion_range_limitation   = mod:get("companion_range_limitation") or 0,
    companion_cancel_mark        = mod:get("companion_cancel_mark") or false,
    companion_health_threshold   = mod:get("companion_health_threshold") or 0,
    companion_time_threshold     = mod:get("companion_time_threshold") or 0,
    focus_target_overwrite       = mod:get("focus_target_overwrite") or false,
    focus_target_overwrite_delta = mod:get("focus_target_overwrite_delta") or 5,
    focus_target_switch          = mod:get("focus_target_switch") or false,
    focus_target_switch_melee    = mod:get("focus_target_switch_melee") or false,
    focus_target_switch_range    = mod:get("focus_target_switch_range") or false,
}
mod.settings                 = mod_settings

-- Default Class Settings
local DEFAULT_CLASS_SETTINGS = {
    toggle_class     = true,
    cooldown         = 25,
    reset_cooldown   = true,
    mark_limit       = true,
    min_range        = 0,
    max_range        = 100,
    override_manual  = false,
    priority_switch  = false,
    toggle_elite     = true,
    toggle_special   = true,
    toggle_boss      = true,
    toggle_other     = true,
    breed_priorities = {},
}
for breed_name, breed_data in pairs(breeds) do
    if Breed.is_minion(breed_data) then
        if breed_data.tags.elite then
            DEFAULT_CLASS_SETTINGS.breed_priorities[breed_name] = 1
        elseif breed_data.tags.special then
            DEFAULT_CLASS_SETTINGS.breed_priorities[breed_name] = 2
        elseif breed_data.is_boss then
            DEFAULT_CLASS_SETTINGS.breed_priorities[breed_name] = 3
        elseif breed_data.smart_tag_target_type == "breed" and breed_data.faction_name ~= "imperium" then
            DEFAULT_CLASS_SETTINGS.breed_priorities[breed_name] = 1
        end
    end
end
mod.DEFAULT_CLASS_SETTINGS      = DEFAULT_CLASS_SETTINGS

-- Context
local context                   = {
    mod_enabled                 = false,
    game_mode_valid             = false,
    player                      = nil,
    class_name                  = nil,
    talent_resource_component   = nil,
    has_companion               = false,
    has_execution_order         = false,
    has_focus_target            = false,
    focus_target_max_stacks     = 0,
    smart_targeting_extension   = nil,
    companion_spawner_extension = nil,
    smart_tag_system            = nil,
    outline_system              = nil,
    companion_command_tap       = "double"
}
mod.context                     = context

-- Auto Mark Settings
local auto_mark_settings        = mod:get("auto_mark_settings") or {}
mod.auto_mark_settings          = auto_mark_settings

-- Mark States
local mark_context              = {
    auto_mark_interval        = 0,
    execution_order_units     = {},
    [TAG_NAMES.ENEMY_TAG]     = {
        tag         = nil,
        cooldown    = 0,
        delay       = 0,
        manual_unit = nil,
        is_manual   = false,
    },
    [TAG_NAMES.VETERAN_TAG]   = {
        tag         = nil,
        cooldown    = 0,
        delay       = 0,
        manual_unit = nil,
        is_manual   = false,
    },
    [TAG_NAMES.COMPANION_TAG] = {
        tag               = nil,
        cooldown          = 0,
        delay             = 0,
        manual_unit       = nil,
        is_manual         = false,
        pounce_start_time = nil,
        is_cancelable     = false,
        canceled_unit     = nil,
    },
}
mod.mark_context                = mark_context

-- Enemy Visbility Check
local visibility_cache          = {}
local visibility_check_frame    = {}
mod.visibility_cache            = visibility_cache
mod.visibility_check_frame      = visibility_check_frame

-- Unit Metadata Cache
local unit_metadata_cache       = {}
local unit_metadata_cache_frame = {}
mod.unit_metadata_cache         = unit_metadata_cache
mod.unit_metadata_cache_frame   = unit_metadata_cache_frame

-- Reusable tables for cache cleanup (avoids GC pressure)
local _units_to_remove_vis      = {}
local _units_to_remove_meta     = {}

-- Reset all params
local function reset_context()
    -- Reset Mark Params
    mark_context.auto_mark_interval = 0
    table_clear(mark_context.execution_order_units)
    for i = 1, #TAG_LIST do
        local tag_name = TAG_LIST[i]
        local tag_context = mark_context[tag_name]
        tag_context.tag = nil
        tag_context.cooldown = 0
        tag_context.delay = 0
        tag_context.manual_unit = nil
        tag_context.is_manual = false
    end
    local tag_context = mark_context[TAG_NAMES.COMPANION_TAG]
    tag_context.pounce_start_time = nil
    tag_context.is_cancelable = false
    tag_context.canceled_unit = nil
    table_clear(visibility_cache)
    table_clear(visibility_check_frame)
    table_clear(unit_metadata_cache)
    table_clear(unit_metadata_cache_frame)
    mod:reset_targeting_cache()
end

-- Load Other Files
mod:io_dofile("AutoMark/scripts/mods/AutoMark/utils/utils")
mod:io_dofile("AutoMark/scripts/mods/AutoMark/context/context")
mod:io_dofile("AutoMark/scripts/mods/AutoMark/setting/class_setting")
mod:io_dofile("AutoMark/scripts/mods/AutoMark/targeting/targeting")
mod:io_dofile("AutoMark/scripts/mods/AutoMark/targeting/custom_targeting")
mod:io_dofile("AutoMark/scripts/mods/AutoMark/mark/base_mark")
mod:io_dofile("AutoMark/scripts/mods/AutoMark/mark/companion_mark")
mod:io_dofile("AutoMark/scripts/mods/AutoMark/mark/focus_target_mark")

--  Mod Enabled
mod.on_enabled            = function(initial_call)
    context.mod_enabled = true
    -- init cache after mod enabled since all hooks were disabled
    mod:init_context()
    mod:init_execution_order_units()
    mod:init_visibility_raycast()
end

--  Mod Disabled
mod.on_disabled           = function(initial_call)
    context.mod_enabled = false
    -- mark info rest
    reset_context()
end

-- When Mod first loaded
mod.on_all_mods_loaded    = function()
    -- mod settings
    mod:init_auto_mark_settings()
    mod:check_is_in_hub()
end

-- Enter/Exit GameplayStateRun
mod.on_game_state_changed = function(status, state_name)
    if state_name == "GameplayStateRun" then
        if status == "enter" then
            -- game settings cache
            mod:init_game_settings()
            -- display
            mod:set_menu_settings(mod:get_menu_class_name())
            mod:check_is_in_hub()
        elseif status == "exit" then
            context.game_mode_valid = false
            -- menu mark info rest
            reset_context()
        end
    end
end

-- Mod Setting Change
mod.on_setting_changed    = function(setting_id)
    local class_name = mod:get("class_selection")
    if mod_settings[setting_id] ~= nil then
        mod_settings[setting_id] = mod:get(setting_id)
    elseif setting_id == "apply_button" then
        if mod:get(setting_id) == "apply" then
            mod:apply_to_all_classes(class_name)
            mod:set("apply_button", "blank", false)
        end
    elseif setting_id == "reset_button" then
        if mod:get(setting_id) == "reset" then
            mod:reset_auto_mark_settings()
            mod:set_menu_settings(class_name)
            mod:set("reset_button", "blank", false)
        end
    elseif setting_id == "class_selection" then
        mod:set_menu_settings(class_name)
    else
        local class_settings = auto_mark_settings[class_name]
        if DEFAULT_CLASS_SETTINGS[setting_id] ~= nil then
            class_settings[setting_id] = mod:get(setting_id)
        elseif DEFAULT_CLASS_SETTINGS.breed_priorities[setting_id] ~= nil then
            class_settings.breed_priorities[setting_id] = mod:get(setting_id)
        end
        mod:set("auto_mark_settings", auto_mark_settings, false)
    end
end

-- Toggle Mod Enabled/Disabled
mod.toggle_mod            = function()
    if mod_settings.toggle_mod_notify then
        mod:notify("Auto Mark " .. (not mod_settings.toggle_mod and "Enabled" or "Disabled"))
    end
    mod:set("toggle_mod", not mod_settings.toggle_mod, true)
end

-- Check if Tag is Valid for Current Class
local function is_tag_valid(tag_name)
    if tag_name == TAG_NAMES.COMPANION_TAG then
        return context.class_name == "adamant" and context.has_companion
    elseif tag_name == TAG_NAMES.VETERAN_TAG then
        return context.class_name == "veteran" and context.has_focus_target
    elseif tag_name == TAG_NAMES.ENEMY_TAG then
        return context.class_name ~= "veteran" or not context.has_focus_target
    end
    return false
end

-- Auto-Mark Target Unit with the Tag
local function auto_mark_by_tag(tag_name)
    if not is_tag_valid(tag_name) then
        return false
    end

    local tag_context = mark_context[tag_name]
    local class_settings = mod:get_class_settings(tag_name)
    local smart_tag_system = context.smart_tag_system

    -- Early exit checks combined
    if not class_settings
        or not class_settings.toggle_class
        or not smart_tag_system
    then
        return false
    end

    -- Check manual override separately (more readable)
    if tag_context.is_manual and not class_settings.override_manual then
        return false
    end

    local marked_tag = tag_context.tag
    -- mark when cooldown is zero
    local is_cooldown_ready = tag_context.cooldown <= 0 and (not class_settings.mark_limit or not marked_tag)
    -- mark when priority switch is on
    local is_priority_switch = marked_tag and class_settings.priority_switch
    -- mark when execution order priority is on
    local is_execution_order_priority = marked_tag
        and tag_name == TAG_NAMES.COMPANION_TAG
        and mod_settings.execution_order_priority
    -- mark when focus target overwrite is on
    local is_focus_target_overwrite = marked_tag
        and tag_name == TAG_NAMES.VETERAN_TAG
        and mod_settings.focus_target_overwrite

    -- Early escape: if no scanning conditions are met, skip expensive targeting
    if not is_cooldown_ready and not is_priority_switch and not is_execution_order_priority and not is_focus_target_overwrite then
        return false
    end

    local target_unit, target_tag
    if is_cooldown_ready then
        target_unit, target_tag = mod:find_target_unit_custom("auto", class_settings.min_range, class_settings.max_range,
            tag_name, tag_context, class_settings, true, is_execution_order_priority)
    elseif is_priority_switch or is_execution_order_priority then
        target_unit, target_tag = mod:find_target_unit_custom("auto", class_settings.min_range, class_settings.max_range,
            tag_name, tag_context, class_settings, true, is_execution_order_priority, marked_tag)
    end

    if not target_unit and is_focus_target_overwrite then
        local marked_unit = marked_tag and marked_tag._target_unit
        if mod:is_target_valid(tag_name, marked_tag, marked_unit) then
            target_unit = marked_unit
        end
    end

    if not target_unit then
        return false
    end

    mod:mark(tag_name, target_unit, target_tag)
    return true
end

-- Auto-Mark
local function auto_mark(dt)
    -- skip if auto mark is disabled
    if not mod_settings.toggle_mod then
        return
    end

    -- calculate interval
    local auto_mark_interval = mark_context.auto_mark_interval
    if auto_mark_interval > 0 then
        mark_context.auto_mark_interval = auto_mark_interval - dt
    end

    -- calculate cooldown and delay for all tags
    for i = 1, #TAG_LIST do
        local tag_name = TAG_LIST[i]
        local tag_context = mark_context[tag_name]
        local delay = tag_context.delay
        if delay > 0 then
            tag_context.delay = delay - dt
        end
        local cooldown = tag_context.cooldown
        if cooldown > 0 then
            tag_context.cooldown = cooldown - dt
        end
    end

    -- pause auto mark for a period of time after it is executed.
    if mark_context.auto_mark_interval > 0 then
        return
    end

    for i = 1, #TAG_LIST do
        local tag_context = mark_context[TAG_LIST[i]]
        if tag_context.delay > 0 then
            return
        end
    end

    -- three kinds of tag to mark
    local marked = auto_mark_by_tag(TAG_NAMES.COMPANION_TAG)
        or auto_mark_by_tag(TAG_NAMES.VETERAN_TAG)
        or auto_mark_by_tag(TAG_NAMES.ENEMY_TAG)

    if not marked then
        -- Set a small interval even if no target was found to avoid scanning every frame
        mark_context.auto_mark_interval = 0.15
    end
end

local function cancel_companion_mark_on_condition(t)
    if not mod_settings.companion_cancel_mark then
        return
    end

    local tag_context = mark_context[TAG_NAMES.COMPANION_TAG]
    if tag_context.is_manual then
        return
    end

    local marked_tag = tag_context.tag
    if not marked_tag or not tag_context.is_cancelable then
        return
    end

    if mod_settings.companion_health_threshold > 0 and tag_context.pounce_start_time then
        local marked_unit = marked_tag._target_unit
        local health_percent = Health.current_health_percent(marked_unit)
        if health_percent < mod_settings.companion_health_threshold then
            mod:print_debug("cancel mark due to health threshold")
            tag_context.canceled_unit = marked_unit
            mod:cancel_mark(marked_tag._id)
            return
        end
    end

    if mod_settings.companion_time_threshold > 0 and tag_context.pounce_start_time then
        if t - tag_context.pounce_start_time > mod_settings.companion_time_threshold then
            mod:print_debug("cancel mark due to time threshold")
            tag_context.canceled_unit = marked_tag._target_unit
            mod:cancel_mark(marked_tag._id)
            return
        end
    end
end

local function clean_caches(fixed_frame)
    if fixed_frame % 100 == 0 then
        -- Collect units to remove first (avoids modifying table during iteration)
        local remove_count_vis = 0
        local remove_count_meta = 0

        for cached_unit, check_frame in next, visibility_check_frame do
            if fixed_frame - check_frame > 10 then
                remove_count_vis = remove_count_vis + 1
                _units_to_remove_vis[remove_count_vis] = cached_unit
            end
        end
        for i = 1, remove_count_vis do
            local unit = _units_to_remove_vis[i]
            visibility_cache[unit] = nil
            visibility_check_frame[unit] = nil
        end

        for cached_unit, check_frame in next, unit_metadata_cache_frame do
            if fixed_frame - check_frame > 60 then
                remove_count_meta = remove_count_meta + 1
                _units_to_remove_meta[remove_count_meta] = cached_unit
            end
        end
        for i = 1, remove_count_meta do
            local unit = _units_to_remove_meta[i]
            unit_metadata_cache[unit] = nil
            unit_metadata_cache_frame[unit] = nil
        end

        table_clear(_units_to_remove_vis)
        table_clear(_units_to_remove_meta)
    end
end

-- Main Entry For Auto Mark
mod:hook_safe(CLASS.PlayerUnitSmartTargetingExtension, "fixed_update",
    function(self, unit, dt, t, fixed_frame)
        if context.game_mode_valid and self._player.viewport_name == "player1" then
            clean_caches(fixed_frame)
            cancel_companion_mark_on_condition(t)
            auto_mark(dt)
        end
    end)
