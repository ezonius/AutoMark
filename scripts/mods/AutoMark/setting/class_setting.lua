local mod                    = get_mod("AutoMark")
local auto_mark_settings     = mod.auto_mark_settings
local context                = mod.context
local DEFAULT_CLASS_SETTINGS = mod.DEFAULT_CLASS_SETTINGS
local TAG_NAMES              = mod.TAG_NAMES

-- Global Cache
local table_clone            = table.clone

-- Additional Class Name for Arbites and Veteran
local ADAMANT_COMPANION      = "adamant_companion"
local CRYPTIC_SERVO_SKULL    = "cryptic_servo_skull"
local VETERAN_FOCUS_TARGET   = "veteran_focus_target"
-- Valid Class Names
local VALID_CLASSES          = {
    [ADAMANT_COMPANION]   = true,
    [CRYPTIC_SERVO_SKULL] = true,
    [VETERAN_FOCUS_TARGET] = true,
}
local archetypes             = require("scripts/settings/archetype/archetypes")
for class_name, _ in pairs(archetypes) do
    VALID_CLASSES[class_name] = true
end

local ADAMANT_COMPANION_DEFAULT_CLASS_SETTINGS = table_clone(DEFAULT_CLASS_SETTINGS)
local adamant_companion_breed_priorities = ADAMANT_COMPANION_DEFAULT_CLASS_SETTINGS.breed_priorities
adamant_companion_breed_priorities["chaos_daemonhost_passive"] = 0
adamant_companion_breed_priorities["chaos_mutator_daemonhost_passive"] = 0
adamant_companion_breed_priorities["chaos_poxwalker_bomber"] = 0

local CRYPTIC_SERVO_SKULL_DEFAULT_CLASS_SETTINGS = table_clone(DEFAULT_CLASS_SETTINGS)
local cryptic_servo_skull_breed_priorities = CRYPTIC_SERVO_SKULL_DEFAULT_CLASS_SETTINGS.breed_priorities
cryptic_servo_skull_breed_priorities["chaos_daemonhost_passive"] = 0
cryptic_servo_skull_breed_priorities["chaos_mutator_daemonhost_passive"] = 0
cryptic_servo_skull_breed_priorities["chaos_poxwalker_bomber"] = 0

local VETERAN_FOCUS_TARGET_DEFAULT_CLASS_SETTINGS = table_clone(DEFAULT_CLASS_SETTINGS)
local veteran_focus_target_breed_priorities = VETERAN_FOCUS_TARGET_DEFAULT_CLASS_SETTINGS.breed_priorities
veteran_focus_target_breed_priorities["chaos_daemonhost_passive"] = 0
veteran_focus_target_breed_priorities["chaos_mutator_daemonhost_passive"] = 0

local function get_default_class_settings(class_name)
    if class_name == ADAMANT_COMPANION then
        return ADAMANT_COMPANION_DEFAULT_CLASS_SETTINGS
    elseif class_name == CRYPTIC_SERVO_SKULL then
        return CRYPTIC_SERVO_SKULL_DEFAULT_CLASS_SETTINGS
    elseif class_name == VETERAN_FOCUS_TARGET then
        return VETERAN_FOCUS_TARGET_DEFAULT_CLASS_SETTINGS
    end
    return DEFAULT_CLASS_SETTINGS
end

local function init_table(dest, source)
    for key, value in pairs(source) do
        if type(value) == "table" then
            if type(dest[key]) == "table" then
                dest[key] = init_table(dest[key], value)
            else
                dest[key] = table_clone(value)
            end
        else
            if dest[key] == nil or type(dest[key]) == "table" then
                dest[key] = value
            end
        end
    end

    for key, _ in pairs(dest) do
        if source[key] == nil then
            dest[key] = nil
        end
    end

    return dest
end

-- Init Auto Mark Settings
function mod:init_auto_mark_settings()
    for class_name, _ in pairs(VALID_CLASSES) do
        if auto_mark_settings[class_name] == nil then
            auto_mark_settings[class_name] = {}
        end
        local class_settings = auto_mark_settings[class_name]
        init_table(class_settings, get_default_class_settings(class_name))
    end

    for class_name, _ in pairs(auto_mark_settings) do
        if not VALID_CLASSES[class_name] then
            auto_mark_settings[class_name] = nil
        end
    end
    mod:set("auto_mark_settings", auto_mark_settings, false)
end

-- Reset Auto Mark Settings to Default
function mod:reset_auto_mark_settings()
    for class_name, _ in pairs(VALID_CLASSES) do
        auto_mark_settings[class_name] = table_clone(get_default_class_settings(class_name))
    end
    mod:set("auto_mark_settings", auto_mark_settings, false)
end

-- Apply Settings to All Classes
function mod:apply_to_all_classes(class_name)
    for other_class_name, _ in pairs(VALID_CLASSES) do
        if other_class_name ~= class_name then
            auto_mark_settings[other_class_name] = table_clone(auto_mark_settings[class_name])
        end
    end
    mod:set("auto_mark_settings", auto_mark_settings, false)
end

-- Set Menu for Display
function mod:set_menu_settings(class_name)
    if not VALID_CLASSES[class_name] then
        return
    end

    mod:set("class_selection", class_name, false)
    local class_settings = auto_mark_settings[class_name]
    for setting_name, default_setting in pairs(get_default_class_settings(class_name)) do
        if type(default_setting) == "table" then
            local breed_priorities = class_settings[setting_name]
            for breed_name, _ in pairs(default_setting) do
                mod:set(breed_name, breed_priorities[breed_name], false)
            end
        else
            mod:set(setting_name, class_settings[setting_name], false)
        end
    end
end

-- Get Class Settings by Tag Name
function mod:get_class_settings(tag_name)
    if tag_name == TAG_NAMES.ENEMY_TAG then
        return auto_mark_settings[context.class_name]
    elseif tag_name == TAG_NAMES.VETERAN_TAG then
        return auto_mark_settings[VETERAN_FOCUS_TARGET]
    elseif tag_name == TAG_NAMES.COMPANION_TAG then
        return auto_mark_settings[ADAMANT_COMPANION]
    elseif tag_name == TAG_NAMES.SERVO_SKULL_TAG then
        return auto_mark_settings[CRYPTIC_SERVO_SKULL]
    end
end

-- Get Class Name
function mod:get_menu_class_name()
    if context.class_name == "adamant" and context.has_companion then
        return ADAMANT_COMPANION
    elseif context.class_name == "veteran" and context.has_focus_target then
        return VETERAN_FOCUS_TARGET
    elseif context.class_name == "cryptic" and context.has_servo_skull then
        return CRYPTIC_SERVO_SKULL
    else
        return context.class_name or "adamant"
    end
end


function mod:apply_to_normal_tags(class_name)
    if not VALID_CLASSES[class_name] then
        return
    end
    local current_settings = table_clone(auto_mark_settings[class_name])
    for archetype_name, _ in pairs(archetypes) do
        auto_mark_settings[archetype_name] = current_settings
    end
    mod:set("auto_mark_settings", auto_mark_settings, false)
end

function mod:reset_current_class(class_name)
    if not VALID_CLASSES[class_name] then
        return
    end
    auto_mark_settings[class_name] = table_clone(get_default_class_settings(class_name))
    mod:set("auto_mark_settings", auto_mark_settings, false)
    mod:set_menu_settings(class_name)
end
