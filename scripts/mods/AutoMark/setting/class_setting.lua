local mod                    = get_mod("AutoMark")
local auto_mark_settings     = mod.auto_mark_settings
local context                = mod.context
local DEFAULT_CLASS_SETTINGS = mod.DEFAULT_CLASS_SETTINGS
local TAG_NAMES              = mod.TAG_NAMES

-- Global Cache
local table_clone            = table.clone

-- Additional Class Name for Arbites and Veteran
local ADAMANT_COMPANION      = "adamant_companion"
local VETERAN_FOCUS_TARGET   = "veteran_focus_target"
-- Valid Class Names
local VALID_CLASSES          = {
    [ADAMANT_COMPANION] = true,
    [VETERAN_FOCUS_TARGET] = true,
}
local archetypes             = require("scripts/settings/archetype/archetypes")
for class_name, _ in pairs(archetypes) do
    VALID_CLASSES[class_name] = true
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
        init_table(class_settings, DEFAULT_CLASS_SETTINGS)
        if class_name == ADAMANT_COMPANION then
            local breed_priorities = class_settings.breed_priorities
            breed_priorities["daemonhost"] = 0
            breed_priorities["pack_master"] = 0
            breed_priorities["poxburster"] = 0
        end
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
        auto_mark_settings[class_name] = table_clone(DEFAULT_CLASS_SETTINGS)
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
    for setting_name, default_setting in pairs(DEFAULT_CLASS_SETTINGS) do
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
    end
end

-- Get Class Name
function mod:get_menu_class_name()
    if context.class_name == "adamant" and context.has_companion then
        return ADAMANT_COMPANION
    elseif context.class_name == "veteran" and context.has_focus_target then
        return VETERAN_FOCUS_TARGET
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
    auto_mark_settings[class_name] = table_clone(DEFAULT_CLASS_SETTINGS)
    mod:set("auto_mark_settings", auto_mark_settings, false)
    mod:set_menu_settings(class_name)
end
