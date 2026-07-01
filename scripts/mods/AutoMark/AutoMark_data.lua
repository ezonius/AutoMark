local mod            = get_mod("AutoMark")
local Breed          = require("scripts/utilities/breed")
local breeds         = require("scripts/settings/breed/breeds")
local archetypes     = require("scripts/settings/archetype/archetypes")

local Localize       = Localize
local string         = string

local elite_widget   = {
    setting_id    = "toggle_elite",
    type          = "checkbox",
    default_value = true,
    sub_widgets   = {},
}

local special_widget = {
    setting_id    = "toggle_special",
    type          = "checkbox",
    default_value = true,
    sub_widgets   = {},
}

local boss_widget    = {
    setting_id    = "toggle_boss",
    type          = "checkbox",
    default_value = true,
    sub_widgets   = {},
}

local other_widget   = {
    setting_id    = "toggle_other",
    type          = "checkbox",
    default_value = true,
    sub_widgets   = {},
}

local function create_breed_priority_dropdown(breed_name, default_value)
    local breed_priority_setting = {
        setting_id = breed_name,
        type = "dropdown",
        default_value = default_value,
        options = {
            { text = "priority_off", value = 0 },
            { text = "priority_1",   value = 1 },
            { text = "priority_2",   value = 2 },
            { text = "priority_3",   value = 3 },
            { text = "priority_4",   value = 4 },
            { text = "priority_5",   value = 5 },
            { text = "priority_6",   value = 6 },
            { text = "priority_7",   value = 7 },
            { text = "priority_8",   value = 8 },
            { text = "priority_9",   value = 9 },
            { text = "priority_10",  value = 10 },
        }
    }
    return breed_priority_setting
end

local elite_priorities   = {}
local special_priorities = {}
local boss_priorities    = {}
local other_priorities   = {}

for breed_name, breed_data in pairs(breeds) do
    if Breed.is_minion(breed_data) then
        if breed_data.tags.elite then
            elite_priorities[#elite_priorities + 1] = create_breed_priority_dropdown(breed_name, 1)
        elseif breed_data.tags.special then
            special_priorities[#special_priorities + 1] = create_breed_priority_dropdown(breed_name, 2)
        elseif breed_data.is_boss then
            boss_priorities[#boss_priorities + 1] = create_breed_priority_dropdown(breed_name, 3)
        elseif breed_data.smart_tag_target_type == "breed" and breed_data.faction_name ~= "imperium" then
            other_priorities[#other_priorities + 1] = create_breed_priority_dropdown(breed_name, 1)
        end
    end
end

local get_breed_localization = function(breed_name)
    local breed_data = breeds[breed_name]
    if breed_data.is_boss then
        return Localize(
            type(breed_data.boss_display_name) == "string"
            and breed_data.boss_display_name
            or breed_data.display_name
        )
    else
        local text = Localize(breed_data.display_name)
        if string.find(breed_name, "mutator") then
            return text .. " (Mutator)"
        else
            return text
        end
    end
end

local compare_breed_name = function(a, b)
    return get_breed_localization(a.setting_id) < get_breed_localization(b.setting_id)
end

table.sort(elite_priorities, compare_breed_name)
table.sort(special_priorities, compare_breed_name)
table.sort(boss_priorities, compare_breed_name)
table.sort(other_priorities, compare_breed_name)

elite_widget.sub_widgets = elite_priorities
special_widget.sub_widgets = special_priorities
boss_widget.sub_widgets = boss_priorities
other_widget.sub_widgets = other_priorities

local class_options = {
    { text = "adamant_companion",    value = "adamant_companion" },
    { text = "veteran_focus_target", value = "veteran_focus_target" },
    { text = "cryptic_servo_skull",  value = "cryptic_servo_skull" },
}

for class_name, _ in pairs(archetypes) do
    class_options[#class_options + 1] = { text = class_name, value = class_name }
end

table.sort(class_options, function(a, b) return a.text < b.text end)

local noospheric_command_breed_name_options = {}
do
    local elite_breed_names = {}
    local special_breed_names = {}
    local boss_breed_names = {}
    local captain_breed_names = {}
    local other_breed_names = {}

    for breed_name, breed_data in pairs(breeds) do
        if Breed.is_minion(breed_data) and breed_data.smart_tag_target_type == "breed" then
            local option = { text = breed_name, value = breed_name }
            if breed_data.tags.elite then
                elite_breed_names[#elite_breed_names + 1] = option
            elseif breed_data.tags.special then
                special_breed_names[#special_breed_names + 1] = option
            elseif breed_data.is_boss then
                boss_breed_names[#boss_breed_names + 1] = option
            elseif breed_data.faction_name ~= "imperium" then
                other_breed_names[#other_breed_names + 1] = option
            end
        end
    end

    local compare_breed_text = function(a, b)
        return mod:localize(a.text) < mod:localize(b.text)
    end

    table.sort(elite_breed_names, compare_breed_text)
    table.sort(special_breed_names, compare_breed_text)
    table.sort(boss_breed_names, compare_breed_text)
    table.sort(captain_breed_names, compare_breed_text)
    table.sort(other_breed_names, compare_breed_text)

    for i = 1, #elite_breed_names do
        noospheric_command_breed_name_options[#noospheric_command_breed_name_options + 1] = elite_breed_names[i]
    end
    for i = 1, #special_breed_names do
        noospheric_command_breed_name_options[#noospheric_command_breed_name_options + 1] = special_breed_names[i]
    end
    for i = 1, #boss_breed_names do
        noospheric_command_breed_name_options[#noospheric_command_breed_name_options + 1] = boss_breed_names[i]
    end
    for i = 1, #captain_breed_names do
        noospheric_command_breed_name_options[#noospheric_command_breed_name_options + 1] = captain_breed_names[i]
    end
    for i = 1, #other_breed_names do
        noospheric_command_breed_name_options[#noospheric_command_breed_name_options + 1] = other_breed_names[i]
    end
end

-- Manual settings
local widgets = {
    {
        setting_id = "mod_settings",
        type = "group",
        sub_widgets = {
            {
                setting_id    = "toggle_mod",
                type          = "checkbox",
                default_value = true,
            },
            {
                setting_id      = "toggle_mod_keybind",
                type            = "keybind",
                default_value   = {},
                keybind_trigger = "pressed",
                keybind_type    = "function_call",
                function_name   = "toggle_mod",
            },
            {
                setting_id    = "toggle_mod_notify",
                type          = "checkbox",
                default_value = true,
            },
            {
                setting_id    = "debug_mode",
                type          = "checkbox",
                default_value = false
            },
        }
    },
    {
        setting_id = "throttling_settings",
        type = "group",
        sub_widgets = {
            {
                setting_id      = "scan_interval",
                type            = "numeric",
                default_value   = 0.1,
                range           = { 0, 1.0 },
                decimals_number = 2,
            },
            {
                setting_id      = "successful_scan_interval",
                type            = "numeric",
                default_value   = 0.2,
                range           = { 0, 1.0 },
                decimals_number = 2,
            },
            {
                setting_id      = "post_mark_delay",
                type            = "numeric",
                default_value   = 0.5,
                range           = { 0, 1.0 },
                decimals_number = 2,
            },
            {
                setting_id      = "cancel_companion_mark_interval",
                type            = "numeric",
                default_value   = 0.1,
                range           = { 0, 1.0 },
                decimals_number = 2,
            },
            {
                setting_id      = "visibility_cache_duration",
                type            = "numeric",
                default_value   = 0.1,
                range           = { 0, 1.0 },
                decimals_number = 2,
            },
            {
                setting_id      = "noospheric_command_lead_time",
                type            = "numeric",
                default_value   = 0.2,
                range           = { 0, 1.0 },
                decimals_number = 2,
            },
        }
    },
    {
        setting_id = "adamant_settings",
        type = "group",
        sub_widgets = {
            {
                setting_id      = "companion_mark_keybind",
                type            = "keybind",
                default_value   = {},
                keybind_trigger = "pressed",
                keybind_type    = "function_call",
                function_name   = "companion_mark",
            },
            {
                setting_id    = "execution_order_priority",
                type          = "checkbox",
                default_value = false,
            },
            {
                setting_id    = "companion_range_limitation",
                type          = "numeric",
                default_value = 0,
                range         = { 0, 100 },
            },
            {
                setting_id    = "companion_cancel_mark",
                type          = "checkbox",
                default_value = false,
                sub_widgets   = {
                    {
                        setting_id    = "companion_cancel_mark_human",
                        type          = "checkbox",
                        default_value = true,
                    },
                    {
                        setting_id    = "companion_cancel_mark_non_human",
                        type          = "checkbox",
                        default_value = false,
                    },
                    {
                        setting_id      = "companion_health_threshold",
                        type            = "numeric",
                        default_value   = 0,
                        range           = { 0, 1 },
                        decimals_number = 2
                    },
                    {
                        setting_id    = "companion_time_threshold",
                        type          = "numeric",
                        default_value = 0,
                        range         = { 0, 25 },
                    },
                }
            },
        }
    },
    {
        setting_id = "cryptic_settings",
        type = "group",
        sub_widgets = {
            {
                setting_id      = "servo_skull_mark_keybind",
                type            = "keybind",
                default_value   = {},
                keybind_trigger = "pressed",
                keybind_type    = "function_call",
                function_name   = "servo_skull_mark",
            },
            {
                setting_id    = "servo_skull_range_limitation",
                type          = "numeric",
                default_value = 30,
                range         = { 0, 100 },
            },
            {
                setting_id    = "capacitance_retention",
                type          = "checkbox",
                default_value = false,
                sub_widgets   = {
                    {
                        setting_id    = "capacitance_retention_elite_threshold",
                        type          = "numeric",
                        default_value = 0,
                        range         = { 0, 100 },
                    },
                    {
                        setting_id    = "capacitance_retention_special_threshold",
                        type          = "numeric",
                        default_value = 0,
                        range         = { 0, 100 },
                    },
                    {
                        setting_id    = "capacitance_retention_boss_threshold",
                        type          = "numeric",
                        default_value = 0,
                        range         = { 0, 100 },
                    },
                }
            },
            {
                setting_id    = "noospheric_command_boost",
                type          = "checkbox",
                default_value = false,
                sub_widgets   = {
                    {
                        setting_id    = "noospheric_command_boost_elite",
                        type          = "checkbox",
                        default_value = false,
                    },
                    {
                        setting_id    = "noospheric_command_boost_special",
                        type          = "checkbox",
                        default_value = false,
                    },
                    {
                        setting_id    = "noospheric_command_boost_boss",
                        type          = "checkbox",
                        default_value = false,
                    },
                    {
                        setting_id    = "noospheric_command_boost_breed_name",
                        type          = "dropdown",
                        default_value = noospheric_command_breed_name_options[1] and noospheric_command_breed_name_options[1].value or "blank",
                        options       = noospheric_command_breed_name_options,
                        sub_widgets   = {
                            {
                                setting_id    = "noospheric_command_boost_breed_override",
                                type          = "checkbox",
                                default_value = false,
                            },
                            {
                                setting_id    = "noospheric_command_boost_breed_toggle",
                                type          = "checkbox",
                                default_value = false,
                            },
                            {
                                setting_id    = "capacitance_retention_breed_threshold",
                                type          = "numeric",
                                default_value = 0,
                                range         = { 0, 100 },
                            },
                        }
                    },
                    {
                        setting_id    = "noospheric_command_boost_reset",
                        type          = "dropdown",
                        default_value = "blank",
                        options       = {
                            { text = "blank", value = "blank" },
                            { text = "reset", value = "reset" },
                        }
                    },
                }
            },
        }
    },
    {
        setting_id  = "veteran_settings",
        type        = "group",
        sub_widgets = {
            {
                setting_id    = "focus_target_overwrite",
                type          = "checkbox",
                default_value = false,
            },
            {
                setting_id    = "focus_target_overwrite_delta",
                type          = "numeric",
                default_value = 5,
                range         = { 1, 10 },
            },
            {
                setting_id    = "focus_target_switch",
                type          = "checkbox",
                default_value = false,
                sub_widgets   = {
                    {
                        setting_id    = "focus_target_switch_melee",
                        type          = "checkbox",
                        default_value = false,
                    },
                    {
                        setting_id    = "focus_target_switch_range",
                        type          = "checkbox",
                        default_value = false,
                    },
                }
            }
        }
    },
    {
        setting_id  = "auto_mark_settings",
        type        = "group",
        sub_widgets = {
            {
                setting_id    = "class_selection",
                type          = "dropdown",
                default_value = "adamant",
                options       = class_options,
            },
            {
                setting_id    = "toggle_class",
                type          = "checkbox",
                default_value = true,
            },
            {
                setting_id    = "cooldown",
                type          = "numeric",
                default_value = 25,
                range         = { 1, 50 },
            },
            {
                setting_id = "reset_cooldown",
                type = "checkbox",
                default_value = true
            },
            {
                setting_id = "mark_limit",
                type = "checkbox",
                default_value = true
            },
            {
                setting_id    = "min_range",
                type          = "numeric",
                default_value = 0,
                range         = { 0, 100 },
            },
            {
                setting_id    = "max_range",
                type          = "numeric",
                default_value = 100,
                range         = { 1, 100 },
            },
            {
                setting_id = "override_manual",
                type = "checkbox",
                default_value = false
            },
            {
                setting_id = "priority_switch",
                type = "checkbox",
                default_value = false
            },
            elite_widget,
            special_widget,
            boss_widget,
            other_widget,
        }
    },
    {
        setting_id  = "apply_to_all_classes",
        type        = "group",
        sub_widgets = {
            {
                setting_id    = "apply_button",
                type          = "dropdown",
                default_value = "blank",
                options       = {
                    { text = "apply", value = "apply" },
                    { text = "blank", value = "blank" },
                }
            },
        }
    },
    {
        setting_id  = "reset_auto_mark_settings",
        type        = "group",
        sub_widgets = {
            {
                setting_id    = "reset_button",
                type          = "dropdown",
                default_value = "blank",
                options       = {
                    { text = "blank", value = "blank" },
                    { text = "reset", value = "reset" },
                }
            },
        }
    },
    {
        setting_id  = "apply_to_normal_tags",
        type        = "group",
        sub_widgets = {
            {
                setting_id    = "apply_normal_button",
                type          = "dropdown",
                default_value = "blank",
                options       = {
                    { text = "apply_normal", value = "apply_normal" },
                    { text = "blank", value = "blank" },
                }
            },
        }
    },
    {
        setting_id  = "reset_current_class",
        type        = "group",
        sub_widgets = {
            {
                setting_id    = "reset_current_button",
                type          = "dropdown",
                default_value = "blank",
                options       = {
                    { text = "reset_current", value = "reset_current" },
                    { text = "blank", value = "blank" },
                }
            },
        }
    },
}

return {
    name         = mod:localize("mod_name"),
    description  = mod:localize("mod_description"),
    is_togglable = true,
    options      = {
        widgets = widgets
    }
}
