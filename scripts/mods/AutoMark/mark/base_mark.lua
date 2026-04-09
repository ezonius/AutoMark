local mod                = get_mod("AutoMark")
local context            = mod.context
local mark_context       = mod.mark_context
local TAG_NAMES          = mod.TAG_NAMES

-- Global Cache
local CLASS              = CLASS
local ScriptUnit         = ScriptUnit

-- Delay for Server Latency, Interval for Auto Mark
local AUTO_MARK_DELAY    = 0.5
local AUTO_MARK_INTERVAL = 0.2

-- set delay and interval for auto mark
local function on_set_tag(tag_context)
    mark_context.auto_mark_interval = AUTO_MARK_INTERVAL
    tag_context.delay = AUTO_MARK_DELAY
end

-- record manual marked unit
local function on_manual_mark(tag_context, target_unit)
    tag_context.manual_unit = target_unit
end

function mod:on_set_tag(tag_context)
    on_set_tag(tag_context)
end

function mod:on_manual_mark(tag_context, target_unit)
    on_manual_mark(tag_context, target_unit)
end

-- cancel mark by tag id
function mod:cancel_mark(tag_id)
    local smart_tag_system = context.smart_tag_system
    if not smart_tag_system then
        return
    end

    local player = context.player
    local player_unit = player and player.player_unit
    if not player_unit then
        return
    end

    smart_tag_system:cancel_tag(tag_id, player_unit)
end

-- mark target unit with tag
function mod:mark(tag_name, target_unit, target_tag)
    local player = context.player
    local player_unit = player and player.player_unit
    local tag_context = mark_context[tag_name]
    local smart_tag_system = context.smart_tag_system
    if not player_unit
        or not target_unit
        or not tag_context
        or not smart_tag_system
    then
        return
    end

    if target_tag then
        if tag_name == TAG_NAMES.ENEMY_TAG then
            return
        elseif tag_name == TAG_NAMES.COMPANION_TAG or tag_name == TAG_NAMES.VETERAN_TAG then
            local template = target_tag._template
            local is_enemy_mark = template and template.name == TAG_NAMES.ENEMY_TAG
            if is_enemy_mark then
                local tagger_player = target_tag._tagger_player
                local tagger_player_unit = tagger_player and tagger_player.player_unit
                if tagger_player_unit then
                    smart_tag_system:cancel_tag(target_tag._id, tagger_player_unit, true)
                end
            end
        end
    end

    -- set delay and interval for auto mark
    on_set_tag(tag_context)
    smart_tag_system:set_tag(tag_name, player_unit, target_unit)
end

-- Check Manual Input Marked Target
mod:hook(CLASS.SmartTagSystem, "set_contextual_unit_tag",
    function(func, self, tagger_unit, target_unit, alternate)
        local player = context.player
        if player and tagger_unit == player.player_unit then
            local target_extension = self._unit_extension_data[target_unit]
            local template = target_extension and target_extension:contextual_tag_template(tagger_unit, alternate)
            local tag_name = template and template.name
            local tag_context = mark_context[tag_name]
            if tag_context ~= nil then
                mod:print_debug("manual mark unit")
                -- the unit is marked manually
                on_manual_mark(tag_context, target_unit)
                -- set delay and interval for auto mark
                on_set_tag(tag_context)
            end
        end
        return func(self, tagger_unit, target_unit, alternate)
    end)

mod:hook(CLASS.SmartTagSystem, "trigger_tag_interaction",
    function(func, self, tag_id, interactor_unit, target_unit, optional_alternate)
        local player = context.player
        if player and interactor_unit == player.player_unit then
            local target_extension = self._unit_extension_data[target_unit]
            local template = target_extension
                and target_extension:contextual_tag_template(interactor_unit, optional_alternate)
            local can_override = template and template.can_override
            if can_override then
                local tag_name = template and template.name
                local tag_context = mark_context[tag_name]
                if tag_context ~= nil then
                    mod:print_debug("manual mark unit")
                    -- the unit is marked manually
                    on_manual_mark(tag_context, target_unit)
                    -- set delay and interval for auto mark
                    on_set_tag(tag_context)
                end
            end
        end
        return func(self, tag_id, interactor_unit, target_unit, optional_alternate)
    end)

-- Smart Tag Hook
mod:hook_safe(CLASS.SmartTag, "init",
    function(self, tag_id, template, tagger_unit, target_unit, target_location, replies, is_server)
        local tagger_player = self._tagger_player
        if not tagger_player or tagger_player.viewport_name ~= "player1" then
            return
        end

        local tag_name = template.name
        local tag_context = mark_context[tag_name]
        if not tag_context then
            return
        end

        -- refresh delay and set cooldown
        tag_context.tag = self
        tag_context.delay = 0
        tag_context.cooldown = mod:get_class_settings(tag_name).cooldown
        -- check if the tag is manual
        if tag_context.manual_unit == target_unit then
            tag_context.is_manual = true
            tag_context.manual_unit = nil
        else
            tag_context.is_manual = false
        end

        if tag_name == TAG_NAMES.COMPANION_TAG then
            tag_context.pounce_start_time = nil
            tag_context.canceled_unit = nil
            local target_data_extension = ScriptUnit.extension(target_unit, "unit_data_system")
            local target_breed_data = target_data_extension and target_data_extension._breed
            local pounce_setting = target_breed_data and target_breed_data.companion_pounce_setting
            local pounce_action = pounce_setting and pounce_setting.companion_pounce_action
            if pounce_action == "human" then
                tag_context.is_cancelable = true
            else
                tag_context.is_cancelable = false
            end
        end
    end)

mod:hook(CLASS.SmartTag, "destroy",
    function(func, self)
        local tag_name = self._template.name
        local tag_context = mark_context[tag_name]
        if not tag_context then
            return func(self)
        end

        if tag_context.tag == self then
            if mod:get_class_settings(tag_name).reset_cooldown then
                tag_context.cooldown = 0
            end
            tag_context.tag = nil
            tag_context.is_manual = false
            tag_context.pounce_start_time = nil
        end

        return func(self)
    end)
