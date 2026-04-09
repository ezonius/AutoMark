local mod        = get_mod("AutoMark")
local context    = mod.context

-- Global Cache
local CLASS      = CLASS
local ScriptUnit = ScriptUnit
local Managers   = Managers

-- Get Extensions
local function get_player_talent_extension()
    local player = Managers.player:local_player_safe(1)
    return player and ScriptUnit.extension(player.player_unit, "talent_system")
end

local function get_player_data_extension()
    local player = Managers.player:local_player_safe(1)
    return player and ScriptUnit.extension(player.player_unit, "unit_data_system")
end

local function get_smart_targeting_extension()
    local player = Managers.player:local_player_safe(1)
    return player and ScriptUnit.extension(player.player_unit, "smart_targeting_system")
end

local function get_companion_spawner_extension()
    local player = Managers.player:local_player_safe(1)
    return player and ScriptUnit.extension(player.player_unit, "companion_spawner_system")
end

-- Track Player
local function init_player()
    local player = Managers.player:local_player_safe(1)
    if player then
        context.player = player
    end
    local class_name = player and player:archetype_name()
    if class_name then
        context.class_name = class_name
    end
end

-- Track Player Components
local function init_player_components(player_data_extension)
    player_data_extension = player_data_extension or get_player_data_extension()
    if not player_data_extension then
        return
    end

    context.talent_resource_component = player_data_extension:read_component("talent_resource")
    mod:print_debug("Init talent_resource_component")
end

local function destroy_player_components()
    context.talent_resource_component = nil
end

-- Track Player Extensions
local function init_player_extensions()
    local smart_targeting_extension = get_smart_targeting_extension()
    if smart_targeting_extension then
        context.smart_targeting_extension = smart_targeting_extension
    end
    local companion_spawner_extension = get_companion_spawner_extension()
    if companion_spawner_extension then
        context.companion_spawner_extension = companion_spawner_extension
    end
end

-- Talent Names
local TALENT_NAMES                  = {
    LONE_WOLF       = "adamant_disable_companion",
    EXECUTION_ORDER = "adamant_execution_order",
    FOCUS_TARGET    = "veteran_improved_tag",
    FOCUSED_FIRE    = "veteran_improved_tag_more_damage",
}
-- Talent Settings
local talent_settings               = require("scripts/settings/talent/talent_settings")
local veteran_talent_settings       = talent_settings.veteran
local veteran_tag_max_stacks        = veteran_talent_settings.veteran_tag.max_stacks
local veteran_tag_max_stacks_talent = veteran_talent_settings.veteran_tag.max_stacks_talent
-- Track Player Talent Status
local function init_player_talent_status(player_talent_extension)
    player_talent_extension = player_talent_extension or get_player_talent_extension()
    if not player_talent_extension then
        return
    end

    local talents = player_talent_extension._talents
    -- has companion
    context.has_companion = context.class_name == "adamant" and not talents[TALENT_NAMES.LONE_WOLF]
    -- has execution order
    context.has_execution_order = context.class_name == "adamant"
        and not not talents[TALENT_NAMES.EXECUTION_ORDER]
    -- has focus target
    context.has_focus_target = context.class_name == "veteran"
        and not not talents[TALENT_NAMES.FOCUS_TARGET]
    -- has focused fire
    local has_focused_fire = not not talents[TALENT_NAMES.FOCUSED_FIRE]
    -- focus target max stacks
    context.focus_target_max_stacks = context.class_name == "veteran" and context.has_focus_target
        and (has_focused_fire and veteran_tag_max_stacks_talent or veteran_tag_max_stacks)
        or 0

    mod:print_debug("has companion", context.has_companion)
    mod:print_debug("has execution order", context.has_execution_order)
    mod:print_debug("has focus target", context.has_focus_target)
    mod:print_debug("focus target max stacks", context.focus_target_max_stacks)
end

-- Track Systems
local function init_systems()
    local smart_tag_system = Managers.state.extension and Managers.state.extension:system("smart_tag_system")
    if smart_tag_system then
        context.smart_tag_system = smart_tag_system
    end
    local outline_system = Managers.state.extension and Managers.state.extension:system("outline_system")
    if outline_system then
        context.outline_system = outline_system
    end
end

-- Track Game Settings
local function init_game_settings()
    context.companion_command_tap = Managers.save:account_data().input_settings.companion_command_tap
end

function mod:init_game_settings()
    init_game_settings()
end

-- Check if player is in hub
function mod:check_is_in_hub()
    local game_mode_manager = Managers.state.game_mode
    if game_mode_manager and not game_mode_manager:is_social_hub() and not game_mode_manager:is_prologue_hub() then
        context.game_mode_valid = true
    end
end

-- Init all params
function mod:init_context()
    -- Init Player
    init_player()
    -- Init Player Components
    init_player_components()
    -- Init Extensions
    init_player_extensions()
    -- Init Talents Status
    init_player_talent_status()
    -- Init Systems
    init_systems()
    -- Init Game Settings
    init_game_settings()
end

-- Cache Player
mod:hook_safe(CLASS.HumanPlayer, "init",
    function(self)
        if self.viewport_name == "player1" then
            mod:print_debug("Init HumanPlayer")
            context.player = self
        end
    end)

mod:hook_safe(CLASS.HumanPlayer, "destroy",
    function(self)
        if self.viewport_name == "player1" then
            mod:print_debug("Destroy HumanPlayer")
            context.player = nil
        end
    end)

-- Get Archetype Name When Player Set Profile
mod:hook_safe(CLASS.HumanPlayer, "set_profile",
    function(self)
        if self.viewport_name == "player1" then
            context.class_name = self:archetype_name()
            mod:print_debug("Class name", context.class_name)
        end
    end)

-- Player Unit Data Hook for Components
mod:hook_safe(CLASS.PlayerUnitDataExtension, "init",
    function(self)
        if self._player.viewport_name == "player1" then
            mod:print_debug("Init PlayerUnitDataExtension")
            init_player_components(self)
        end
    end)

mod:hook_safe(CLASS.PlayerUnitDataExtension, "destroy",
    function(self)
        if self._player.viewport_name == "player1" then
            mod:print_debug("Destroy PlayerUnitDataExtension")
            destroy_player_components()
        end
    end)

-- Hook Extensions for Cache
mod:hook_safe(CLASS.PlayerUnitSmartTargetingExtension, "init",
    function(self)
        if self._player.viewport_name == "player1" then
            mod:print_debug("Init PlayerUnitSmartTargetingExtension")
            context.smart_targeting_extension = self
        end
    end)

mod:hook_safe(CLASS.PlayerUnitSmartTargetingExtension, "delete",
    function(self)
        if self._player.viewport_name == "player1" then
            mod:print_debug("Delete PlayerUnitSmartTargetingExtension")
            context.smart_targeting_extension = nil
        end
    end)

mod:hook_safe(CLASS.CompanionSpawnerExtension, "init",
    function(self)
        if self._owner_player.viewport_name == "player1" then
            mod:print_debug("Init CompanionSpawnerExtension")
            context.companion_spawner_extension = self
        end
    end)

mod:hook_safe(CLASS.CompanionSpawnerExtension, "destroy",
    function(self)
        if self._owner_player.viewport_name == "player1" then
            mod:print_debug("Destroy CompanionSpawnerExtension")
            context.companion_spawner_extension = nil
        end
    end)


-- Update Talent Status
mod:hook_safe(CLASS.PlayerUnitTalentExtension, "_apply_talents",
    function(self)
        if self._player.viewport_name == "player1" then
            init_player_talent_status(self)
        end
    end)

mod:hook_safe(CLASS.PlayerHuskTalentExtension, "_update_talents",
    function(self)
        if self._player.viewport_name == "player1" then
            init_player_talent_status(self)
        end
    end)

-- System Cache Hook
mod:hook_safe(CLASS.SmartTagSystem, "init",
    function(self)
        mod:print_debug("Init SmartTagSystem")
        context.smart_tag_system = self
    end)

mod:hook_safe(CLASS.SmartTagSystem, "destroy",
    function()
        mod:print_debug("Destroy SmartTagSystem")
        context.smart_tag_system = nil
    end)

mod:hook_safe(CLASS.OutlineSystem, "init",
    function(self)
        mod:print_debug("Init OutlineSystem")
        context.outline_system = self
    end)

mod:hook_safe(CLASS.OutlineSystem, "destroy",
    function()
        mod:print_debug("Destroy OutlineSystem")
        context.outline_system = nil
    end)

-- Update settings when input settings changed
mod:hook_safe(CLASS.EventManager, "trigger", function(self, event_name)
    if event_name == "event_on_input_settings_changed" then
        mod:print_debug("input settings changed")
        init_game_settings()
    end
end)
