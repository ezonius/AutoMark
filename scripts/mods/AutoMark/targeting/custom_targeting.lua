local mod                                   = get_mod("AutoMark")
local context                               = mod.context
local mark_context                          = mod.mark_context
local TAG_NAMES                             = mod.TAG_NAMES
local ENEMY_TAG_NAME                         = TAG_NAMES.ENEMY_TAG
local VETERAN_TAG_NAME                       = TAG_NAMES.VETERAN_TAG
local COMPANION_TAG_NAME                     = TAG_NAMES.COMPANION_TAG
local SERVO_SKULL_TAG_NAME                   = TAG_NAMES.SERVO_SKULL_TAG
local mod_settings                          = mod.settings
local noospheric_command_breed_settings     = mod.noospheric_command_breed_settings
local visibility_cache                      = mod.visibility_cache
local visibility_check_frame                = mod.visibility_check_frame
local servo_skull_visibility_cache          = mod.servo_skull_visibility_cache
local servo_skull_visibility_check_frame    = mod.servo_skull_visibility_check_frame
local unit_metadata_cache                   = mod.unit_metadata_cache
local unit_metadata_cache_frame             = mod.unit_metadata_cache_frame

-- Frame Cache for Raycast
local last_raycast_frame        = -1
local last_raycast_hits         = nil
local last_raycast_num_hits     = 0
local last_ray_origin           = nil
local last_forward              = nil
local last_right                = nil
local last_up                   = nil
local last_visibility_frame     = -1
local last_visibility_results   = {}

-- Imports
local Breed                                 = require("scripts/utilities/breed")
local MinionPerception                      = require("scripts/utilities/minion_perception")
local SpecialRulesSettings                  = require("scripts/settings/ability/special_rules_settings")
local Breed_height                          = Breed.height
local special_rules                         = SpecialRulesSettings.special_rules

-- Global Cache
local Managers                  = Managers
local HEALTH_ALIVE              = HEALTH_ALIVE
local Actor_unit                = Actor.unit
local Actor_world_bounds        = Actor.world_bounds
local Unit_alive               = Unit.alive
local Unit_box                  = Unit.box
local Unit_world_position       = Unit.world_position
local PhysicsWorld_raycast      = PhysicsWorld.raycast
local Raycast_cast              = Raycast.cast
local ScriptUnit_extension      = ScriptUnit.extension
local pairs                  = pairs
local table_clear            = table.clear
local math_abs                  = math.abs
local math_max                  = math.max
local math_sqrt                 = math.sqrt
local math_huge                 = math.huge
local Vector3_dot               = Vector3.dot
local Vector3_normalize         = Vector3.normalize
local Vector3_length            = Vector3.length

local Vector3_distance_squared  = Vector3.distance_squared
local Matrix4x4_right           = Matrix4x4.right
local Matrix4x4_forward         = Matrix4x4.forward

-- Constants
local INDEX_POSITION            = 1
local INDEX_DISTANCE            = 2
local INDEX_NORMAL              = 3
local INDEX_ACTOR               = 4
local COLLISION_FILTER          = "filter_player_ping_target_selection"
local EMPTY_TABLE               = {}

-- Params
local visibility_raycast_object             = nil
local servo_skull_visibility_raycast_object = nil

function mod:reset_targeting_cache()
    last_raycast_frame = -1
    last_raycast_hits = nil
    last_raycast_num_hits = 0
    last_ray_origin = nil
    last_forward = nil
    last_right = nil
    last_up = nil
    last_visibility_frame = -1
    table_clear(last_visibility_results)
end

function mod:init_visibility_raycast()
    local smart_targeting_extension = context.smart_targeting_extension
    local physics_world = smart_targeting_extension and smart_targeting_extension._physics_world
    if physics_world then
        visibility_raycast_object = PhysicsWorld.make_raycast(physics_world, "closest", "types", "statics",
            "collision_filter", "filter_interactable_line_of_sight_marker_check")
        servo_skull_visibility_raycast_object = PhysicsWorld.make_raycast(physics_world, "closest", "types", "statics",
            "collision_filter", "filter_minion_line_of_sight_check")
    end
end

function mod:destroy_visibility_raycast()
    visibility_raycast_object = nil
    servo_skull_visibility_raycast_object = nil
end

local function get_breed_priority(target_unit, breed_data, breed_priorities, breed_name_passive)
    local breed_name = breed_data and breed_data.name
    if not breed_name then
        return 0
    end

    local priority
    local tags = breed_data.tags
    if tags and tags.witch then
        local gsm = Managers.state.game_session
        local usm = Managers.state.unit_spawner
        local game_session = gsm and gsm:game_session()
        local game_object_id = usm and usm:game_object_id(target_unit)
        local is_aggroed = MinionPerception.target_unit(game_session, game_object_id)
        if is_aggroed then
            priority = breed_priorities[breed_name] or 0
        else
            priority = breed_priorities[breed_name_passive] or 0
        end
    else
        priority = breed_priorities[breed_name] or 0
    end

    if priority == 11 then
        local buff_extension = ScriptUnit_extension(target_unit, "buff_system")
        if buff_extension then
            local rending_debuff = buff_extension._stacking_buffs["rending_debuff"]
            if rending_debuff and rending_debuff:stack_count() > 0 then
                return 1
            end
        end
        return 0
    end

    return priority
end

-- Check if Target Unit's Breed is Valid for Auto-Mark
local function is_breed_valid(breed_data, class_settings)
    if not breed_data or not class_settings then
        return false
    end

    local tags = breed_data.tags
    -- toggle enemy by type
    if tags.elite then
        return class_settings.toggle_elite
    elseif tags.special then
        return class_settings.toggle_special
    elseif breed_data.is_boss then
        return class_settings.toggle_boss
    else
        return class_settings.toggle_other
    end
end

-- Check if Tagged Target Unit can be Marked with Current Tag
local function is_target_valid(tag_name, target_tag, target_unit, target_unit_position, companion_unit_position, talent_resource_component)
    if tag_name == COMPANION_TAG_NAME then
        -- arbite shouldn't mark any arbite's prey or veteran's prey
        local target_tag_name = target_tag and target_tag._template.name
        if target_tag_name == COMPANION_TAG_NAME or target_tag_name == VETERAN_TAG_NAME then
            return false
        end

        local min_range = mod_settings.companion_min_range
        local max_range = mod_settings.companion_max_range
        if min_range > 0 or max_range < 100 then
            -- Fallback for direct calls
            if not target_unit_position or _G.type(target_unit_position) == "userdata" then
                local raw_pos = target_unit and Unit_world_position(target_unit, 1)
                target_unit_position = raw_pos and Vector3(raw_pos.x, raw_pos.y, raw_pos.z)
            end
            if not companion_unit_position or _G.type(companion_unit_position) == "userdata" then
                local companion_spawner_extension = context.companion_spawner_extension
                local companion_units = companion_spawner_extension and companion_spawner_extension:companion_units()
                local companion_unit = companion_units and companion_units[1]
                local raw_pos = companion_unit and Unit_world_position(companion_unit, 1)
                companion_unit_position = raw_pos and Vector3(raw_pos.x, raw_pos.y, raw_pos.z)
            end

            if not companion_unit_position or not target_unit_position then
                return false
            end

            local distance_sq = Vector3_distance_squared(companion_unit_position, target_unit_position)
            if distance_sq < min_range * min_range or distance_sq > max_range * max_range then
                return false
            end
        end
        return true
    elseif tag_name == VETERAN_TAG_NAME then
        local metadata = unit_metadata_cache[target_unit]
        local target_buff_extension = metadata and metadata.buff_extension
        if not target_buff_extension then
            target_buff_extension = ScriptUnit_extension(target_unit, "buff_system")
            if metadata then metadata.buff_extension = target_buff_extension end
        end

        if not target_buff_extension then
            return false
        end

        local focus_target_debuff = target_buff_extension._stacking_buffs["veteran_improved_tag_debuff"]
        local target_stack_count = focus_target_debuff and focus_target_debuff:stack_count() or 0
        local target_tag_name = target_tag and target_tag._template.name
        -- target does not have focus target debuff
        if target_tag_name ~= VETERAN_TAG_NAME and target_stack_count <= 0 then
            return true
        end

        -- latency bug
        if target_tag_name == VETERAN_TAG_NAME and target_stack_count <= 0 then
            return false
        end

        -- focus_target_overwrite not enabled
        if not mod_settings.focus_target_overwrite then
            return false
        end

        if not talent_resource_component then
            talent_resource_component = context.talent_resource_component
        end

        if not talent_resource_component then
            return false
        end

        -- check if player's buff stacks greater than target's debuff stacks
        local player_stack_count = talent_resource_component.current_resource or 0
        if player_stack_count <= target_stack_count then
            return false
        end

        if player_stack_count == context.focus_target_max_stacks or player_stack_count - target_stack_count >= mod_settings.focus_target_overwrite_delta then
            return true
        end
    elseif tag_name == SERVO_SKULL_TAG_NAME then
        if target_tag then
            local target_tag_name = target_tag._template.name
            if target_tag_name == COMPANION_TAG_NAME or target_tag_name == VETERAN_TAG_NAME or target_tag_name == SERVO_SKULL_TAG_NAME then
                return false
            end
        end

        local min_range = mod_settings.servo_skull_min_range
        local max_range = mod_settings.servo_skull_max_range
        if min_range > 0 or max_range < 100 then
            -- Fallback for direct calls
            if not target_unit_position or _G.type(target_unit_position) == "userdata" then
                local raw_pos = target_unit and Unit_world_position(target_unit, 1)
                target_unit_position = raw_pos and Vector3(raw_pos.x, raw_pos.y, raw_pos.z)
            end
            if not companion_unit_position or _G.type(companion_unit_position) == "userdata" then
                local companion_spawner_extension = context.companion_spawner_extension
                local servo_skull_unit = companion_spawner_extension and companion_spawner_extension:spawned_unit_lookup(special_rules.cryptic_servo_skull_hack)
                local raw_pos = Unit_alive(servo_skull_unit) and Unit_world_position(servo_skull_unit, 1)
                companion_unit_position = raw_pos and Vector3(raw_pos.x, raw_pos.y, raw_pos.z)
            end

            if not companion_unit_position or not target_unit_position then
                return false
            end

            local distance_sq = Vector3_distance_squared(companion_unit_position, target_unit_position)
            if distance_sq < min_range * min_range or distance_sq > max_range * max_range then
                return false
            end
        end

        if not mod_settings.capacitance_retention or not context.has_noospheric_command then
            return true
        end

        local player_ability_extension = context.player_ability_extension
        if not player_ability_extension then
            return false
        end

        local metadata = unit_metadata_cache[target_unit]
        local breed_data = metadata and metadata.breed_data
        if not breed_data then
            local unit_data_extension = ScriptUnit_extension(target_unit, "unit_data_system")
            breed_data = unit_data_extension and unit_data_extension._breed
        end

        if not breed_data then
            return false
        end

        local breed_name = breed_data.name
        local breed_settings = noospheric_command_breed_settings[breed_name]
        local capacitance_retention_threshold
        if breed_settings and breed_settings.override then
            capacitance_retention_threshold = breed_settings.threshold or 0
        end

        if capacitance_retention_threshold == nil then
            if breed_data.is_boss then
                capacitance_retention_threshold = mod_settings.capacitance_retention_boss_threshold
            elseif breed_data.tags.special then
                capacitance_retention_threshold = mod_settings.capacitance_retention_special_threshold
            else
                capacitance_retention_threshold = mod_settings.capacitance_retention_elite_threshold
            end
        end

        local max_ability_charges = player_ability_extension:max_ability_charges("combat_ability")
        local remaining_ability_charges = player_ability_extension:remaining_ability_charges("combat_ability")
        local max_ability_cooldown = player_ability_extension:max_ability_cooldown("combat_ability")
        local remaining_ability_cooldown = player_ability_extension:remaining_ability_cooldown("combat_ability")

        local current_capacitance = remaining_ability_charges
        if remaining_ability_charges < max_ability_charges and max_ability_cooldown > 0 then
            current_capacitance = current_capacitance + math_max(0, (max_ability_cooldown - remaining_ability_cooldown) / max_ability_cooldown)
        end
        local current_percentage = max_ability_charges > 0 and (current_capacitance / max_ability_charges * 100) or 100

        return current_percentage >= capacitance_retention_threshold
    elseif tag_name == TAG_NAMES.ENEMY_TAG then
        if not target_tag then
            return true
        end
    end

    return false
end

local function is_unit_on_screen(unit)
    local hud = Managers.ui:get_hud()
    local world_markers = hud and hud:element("HudElementWorldMarkers")
    if not world_markers then return true end

    local camera = world_markers:_get_camera()
    if not camera then return true end

    local raw_pos = Unit_world_position(unit, 1)
    local pos = Vector3(raw_pos.x, raw_pos.y, raw_pos.z)
    return Camera.inside_frustum(camera, pos)
end

local function get_dynamic_cache_duration(dist_sq)
    local dist = math_sqrt(dist_sq)
    if dist < 50 then
        return mod_settings.visibility_cache_duration
    elseif dist < 70 then
        return mod_settings.visibility_cache_duration * 1.5
    else
        return mod_settings.visibility_cache_duration * 2.0
    end
end

local function is_target_visible(ray_origin, hit_unit_center_pos, hit_unit, t, dist_sq, fixed_frame)
    if not visibility_raycast_object then
        return false
    end

    if fixed_frame == last_visibility_frame then
        local result = last_visibility_results[hit_unit]
        if result ~= nil then
            return result
        end
    else
        last_visibility_frame = fixed_frame
        table_clear(last_visibility_results)
    end

    local cached_visibility = visibility_cache[hit_unit]
    local last_check_t = visibility_check_frame[hit_unit]
    
    local cache_duration = get_dynamic_cache_duration(dist_sq)
    if cached_visibility ~= nil and t - last_check_t < cache_duration then
        last_visibility_results[hit_unit] = cached_visibility
        return cached_visibility
    end

    local ray_to_target = hit_unit_center_pos - ray_origin
    local ray_length = math_sqrt(dist_sq)
    -- Avoid potential division by zero
    if ray_length < 0.0001 then
        return true
    end
    local hit = Raycast_cast(
        visibility_raycast_object, ray_origin,
        ray_to_target / ray_length, ray_length
    )
    local is_visible = not hit
    visibility_cache[hit_unit] = is_visible
    visibility_check_frame[hit_unit] = t
    last_visibility_results[hit_unit] = is_visible
    return is_visible
end

function mod:is_servo_skull_target_visible(target_unit, t)
    if not servo_skull_visibility_raycast_object then
        return false
    end

    local cached_visibility = servo_skull_visibility_cache[target_unit]
    local last_check_t = servo_skull_visibility_check_frame[target_unit]
    if cached_visibility ~= nil and t - last_check_t < mod_settings.visibility_cache_duration then
        return cached_visibility
    end

    local companion_spawner_extension = context.companion_spawner_extension
    local servo_skull_unit = companion_spawner_extension and companion_spawner_extension:spawned_unit_lookup(special_rules.cryptic_servo_skull_hack)
    if not Unit_alive(servo_skull_unit) then
        return false
    end

    local metadata = unit_metadata_cache[target_unit]
    if not metadata then
        local unit_data_extension = ScriptUnit_extension(target_unit, "unit_data_system")
        local breed_data = unit_data_extension and unit_data_extension._breed
        local breed_name = breed_data and breed_data.name
        metadata = {
            breed_data = breed_data,
            breed_name = breed_name,
            breed_name_passive = breed_name and breed_name .. "_passive",
        }
        unit_metadata_cache[target_unit] = metadata
    end

    local breed_data = metadata.breed_data
    local raw_ray_origin = Unit_world_position(servo_skull_unit, 1)
    local ray_origin = Vector3(raw_ray_origin.x, raw_ray_origin.y, raw_ray_origin.z)
    local raw_target_pos = Unit_world_position(target_unit, 1)
    local target_pos = Vector3(raw_target_pos.x, raw_target_pos.y, raw_target_pos.z) + Vector3(0, 0, Breed_height(target_unit, breed_data) * 0.5)
    local ray_to_target = target_pos - ray_origin
    local ray_length = Vector3_length(ray_to_target)

    if ray_length < 0.0001 then
        return true
    end

    local hit = Raycast_cast(
        servo_skull_visibility_raycast_object, ray_origin,
        ray_to_target / ray_length, ray_length
    )

    servo_skull_visibility_cache[target_unit] = not hit
    servo_skull_visibility_check_frame[target_unit] = t
    return not hit
end

function mod:is_noospheric_command_boost_breed_valid(target_unit)
    local metadata = unit_metadata_cache[target_unit]
    if not metadata then
        local unit_data_extension = ScriptUnit_extension(target_unit, "unit_data_system")
        local breed_data = unit_data_extension and unit_data_extension._breed
        local breed_name = breed_data and breed_data.name
        metadata = {
            breed_data = breed_data,
            breed_name = breed_name,
            breed_name_passive = breed_name and breed_name .. "_passive",
        }
        unit_metadata_cache[target_unit] = metadata
    end

    local breed_data = metadata.breed_data
    if not breed_data then
        return false
    end

    if breed_data.tags.witch then
        local gsm = Managers.state.game_session
        local usm = Managers.state.unit_spawner
        local game_session = gsm and gsm:game_session()
        local game_object_id = usm and usm:game_object_id(target_unit)
        local is_aggroed = MinionPerception.target_unit(game_session, game_object_id)
        if not is_aggroed then
            return false
        end
    end

    local breed_name = breed_data.name
    local breed_settings = noospheric_command_breed_settings[breed_name]
    if breed_settings and breed_settings.override then
        return breed_settings.toggle
    end

    if breed_data.is_boss then
        return mod_settings.noospheric_command_boost_boss
    elseif breed_data.tags.special then
        return mod_settings.noospheric_command_boost_special
    else
        return mod_settings.noospheric_command_boost_elite
    end
end

local BROADPHASE_RESULTS = {}

local function find_servo_skull_target(tag_name, class_settings, tag_context, t, is_execution_order_priority, marked_tag)
    local player = context.player
    local player_unit = player and player.player_unit
    if not player_unit then
        return nil
    end

    local companion_spawner_extension = context.companion_spawner_extension
    if not companion_spawner_extension then
        return nil
    end
    local servo_skull_unit = companion_spawner_extension:spawned_unit_lookup(special_rules.cryptic_servo_skull_hack)
    if not Unit_alive(servo_skull_unit) then
        return nil
    end
    local servo_position = Unit_world_position(servo_skull_unit, 1)

    local side_system = Managers.state.extension:system("side_system")
    local side = side_system.side_by_unit[player_unit]
    if not side then
        return nil
    end
    local enemy_side_names = side:relation_side_names("enemy")

    local broadphase_system = Managers.state.extension:system("broadphase_system")
    local broadphase = broadphase_system.broadphase
    local radius = class_settings.max_range
    local num_results = broadphase.query(broadphase, servo_position, radius, BROADPHASE_RESULTS, enemy_side_names)

    if num_results <= 0 then
        return nil
    end

    local smart_tag_system = context.smart_tag_system
    local breed_priorities = class_settings.breed_priorities or EMPTY_TABLE

    local best_unit = nil
    local best_unit_tag = nil
    local best_unit_priority = -math_huge

    local marked_unit = marked_tag and marked_tag._target_unit
    if marked_unit and HEALTH_ALIVE[marked_unit] then
        best_unit = marked_unit
        local unit_data_extension = ScriptUnit_extension(best_unit, "unit_data_system")
        local breed_data = unit_data_extension and unit_data_extension._breed
        best_unit_priority = get_breed_priority(best_unit, breed_data, breed_priorities, breed_data and breed_data.name .. "_passive")
    end

    local canceled_unit = tag_context and tag_context.canceled_unit

    for i = 1, num_results do
        local hit_unit = BROADPHASE_RESULTS[i]
        if hit_unit == marked_unit or hit_unit == canceled_unit or not HEALTH_ALIVE[hit_unit] then
            goto next_broadphase
        end

        local unit_data_extension = ScriptUnit_extension(hit_unit, "unit_data_system")
        local breed_data = unit_data_extension and unit_data_extension._breed
        if not breed_data then
            goto next_broadphase
        end

        if not is_breed_valid(breed_data, class_settings) then
            goto next_broadphase
        end

        local priority = get_breed_priority(hit_unit, breed_data, breed_priorities, breed_data.name .. "_passive")
        if priority <= 0 or priority <= best_unit_priority then
            goto next_broadphase
        end

        local raw_pos = Unit_world_position(hit_unit, 1)
        local dist_sq = Vector3_distance_squared(servo_position, raw_pos)
        local min_dist = class_settings.min_range
        if dist_sq < min_dist * min_dist or dist_sq > radius * radius then
            goto next_broadphase
        end

        local gsm = Managers.state.game_session
        local usm = Managers.state.unit_spawner
        local game_session = gsm and gsm:game_session()
        local game_object_id = usm and usm:game_object_id(hit_unit)
        if not game_session or not game_object_id then
            goto next_broadphase
        end
        if not MinionPerception.target_unit(game_session, game_object_id) then
            goto next_broadphase
        end

        local hit_unit_tag = smart_tag_system:unit_tag(hit_unit)
        if not is_target_valid(tag_name, hit_unit_tag, hit_unit, nil, nil, nil) then
            goto next_broadphase
        end

        if not mod:is_servo_skull_target_visible(hit_unit, t) then
            goto next_broadphase
        end

        best_unit = hit_unit
        best_unit_tag = hit_unit_tag
        best_unit_priority = priority

        ::next_broadphase::
    end

    return best_unit, best_unit_tag
end

function mod:find_target_unit_custom(type, min_range, max_range, tag_name, tag_context, class_settings, use_filter,
                                     is_execution_order_priority, marked_tag, t)
    if type == "auto" and tag_name == SERVO_SKULL_TAG_NAME and mod_settings.servo_skull_line_of_sight then
        return find_servo_skull_target(tag_name, class_settings, tag_context, t, is_execution_order_priority, marked_tag)
    end

    local player = context.player
    local player_unit = player and player.player_unit
    local smart_targeting_extension = context.smart_targeting_extension
    local precision_target_finder = smart_targeting_extension._precision_target_aim_assist
    local smart_tag_system = context.smart_tag_system
    if not player_unit or not smart_targeting_extension or not precision_target_finder or not smart_tag_system then
        return nil
    end

    local fixed_frame = smart_targeting_extension._latest_fixed_frame
    local ray_origin, forward, right, up
    local hits, num_hits

    if fixed_frame == last_raycast_frame then
        ray_origin = last_ray_origin
        forward = last_forward
        right = last_right
        up = last_up
        hits = last_raycast_hits
        num_hits = last_raycast_num_hits
    else
        -- raycast for hit unit list
        ray_origin, forward, right, up = smart_targeting_extension:_targeting_parameters()
        hits, num_hits = PhysicsWorld_raycast(smart_targeting_extension._physics_world, ray_origin, forward, max_range,
            "all", "collision_filter", COLLISION_FILTER)

        last_raycast_frame = fixed_frame
        last_ray_origin = ray_origin
        last_forward = forward
        last_right = right
        last_up = up
        last_raycast_hits = hits
        last_raycast_num_hits = num_hits
    end

    if num_hits <= 0 then
        return nil
    end

    -- Pre-calculate context data for is_target_valid
    local companion_unit_position = nil
    if tag_name == COMPANION_TAG_NAME then
        local min_range = mod_settings.companion_min_range
        local max_range = mod_settings.companion_max_range
        if min_range > 0 or max_range < 100 then
            local companion_spawner_extension = context.companion_spawner_extension
            local companion_units = companion_spawner_extension and companion_spawner_extension:companion_units()
            local companion_unit = companion_units and companion_units[1]
            local raw_pos = companion_unit and Unit_world_position(companion_unit, 1)
            companion_unit_position = raw_pos and Vector3(raw_pos.x, raw_pos.y, raw_pos.z)
        end
    elseif tag_name == SERVO_SKULL_TAG_NAME then
        local min_range = mod_settings.servo_skull_min_range
        local max_range = mod_settings.servo_skull_max_range
        if min_range > 0 or max_range < 100 then
            local companion_spawner_extension = context.companion_spawner_extension
            local servo_skull_unit = companion_spawner_extension and companion_spawner_extension:spawned_unit_lookup(special_rules.cryptic_servo_skull_hack)
            local raw_pos = Unit_alive(servo_skull_unit) and Unit_world_position(servo_skull_unit, 1)
            companion_unit_position = raw_pos and Vector3(raw_pos.x, raw_pos.y, raw_pos.z)
        end
    end
    local talent_resource_component = (tag_name == VETERAN_TAG_NAME) and context.talent_resource_component or nil

    local visibility_check_count = 0
    local canceled_unit = tag_context and tag_context.canceled_unit
    local breed_priorities = class_settings and class_settings.breed_priorities or EMPTY_TABLE
    local execution_order_units = mark_context.execution_order_units
    local best_unit = nil
    local best_unit_tag = nil
    local best_unit_priority = -math_huge
    local best_unit_marked_by_execution_order = false
    local best_unit_dot = -math_huge
    local best_unit_distance = math_huge
    -- init best unit for switch logic
    local marked_unit = marked_tag and marked_tag._target_unit
    if marked_unit and Unit_alive(marked_unit) then
        best_unit = marked_unit
        local unit_data_extension = ScriptUnit_extension(best_unit, "unit_data_system")
        local breed_data = unit_data_extension and unit_data_extension._breed
        local breed_name = breed_data and breed_data.name
        best_unit_priority = get_breed_priority(best_unit, breed_data, breed_priorities, breed_name and breed_name .. "_passive")
        best_unit_marked_by_execution_order = not not execution_order_units[best_unit]
    end


    for i = 1, num_hits do
        local hit = hits[i]
        if not hit then
            goto continue_loop
        end

        local hit_distance = hit[INDEX_DISTANCE]
        -- Preliminary range check using hit distance before any actor/unit work
        -- Distance 0 usually means hit the player's own mesh or something else invalid
        if hit_distance > max_range + 3 or (min_range > 3 and hit_distance < min_range - 3) or hit_distance < 0.1 then
            goto continue_loop
        end

        local hit_position = hit[INDEX_POSITION]
        if hit_position then
            hit_position = Vector3(hit_position.x, hit_position.y, hit_position.z)
        end
        local hit_actor = hit[INDEX_ACTOR]
        if not hit_actor then
            goto continue_loop
        end

        local success, hit_unit = pcall(Actor_unit, hit_actor)
        -- ignore invalid actor, player unit, already marked unit and dead unit
        if not success or not hit_unit or hit_unit == player_unit or hit_unit == marked_unit or hit_unit == canceled_unit or not HEALTH_ALIVE[hit_unit] then
            goto continue_loop
        end

        -- Fetch or Cache Metadata
        local metadata = unit_metadata_cache[hit_unit]
        if not metadata then
            local unit_data_extension = ScriptUnit_extension(hit_unit, "unit_data_system")
            local breed_data = unit_data_extension and unit_data_extension._breed
            local breed_name = breed_data and breed_data.name
            local is_taggable = not not (breed_data and breed_data.smart_tag_target_type == "breed")
            metadata = {
                breed_data = breed_data,
                breed_name = breed_name,
                breed_name_passive = breed_name and breed_name .. "_passive",
                is_taggable = is_taggable,
                half_extent_right = breed_data and (breed_data.half_extent_right or 0.3) or 0.3,
                half_extent_forward = breed_data and (breed_data.half_extent_forward or 0.3) or 0.3,
            }
            unit_metadata_cache[hit_unit] = metadata
        end
        unit_metadata_cache_frame[hit_unit] = fixed_frame

        local breed_data = metadata.breed_data
        -- ignore untaggable unit
        if not metadata.is_taggable then
            goto continue_loop
        end

        local hit_unit_priority = get_breed_priority(hit_unit, breed_data, breed_priorities, metadata.breed_name_passive)
        -- filter unit by type and priority
        if use_filter and (hit_unit_priority <= 0 or not is_breed_valid(breed_data, class_settings)) then
            goto continue_loop
        end

        -- Early priority check for auto mode to skip expensive math
        if type == "auto" then
            local hit_unit_marked_by_execution_order = execution_order_units[hit_unit] ~= nil
            if is_execution_order_priority then
                if hit_unit_marked_by_execution_order == best_unit_marked_by_execution_order then
                    if hit_unit_priority <= best_unit_priority then
                        goto continue_loop
                    end
                elseif best_unit_marked_by_execution_order then
                    goto continue_loop
                end
            else
                if hit_unit_priority <= best_unit_priority then
                    goto continue_loop
                end
            end
            
            -- Store for later use instead of recalculating
            metadata.hit_unit_marked_by_execution_order = hit_unit_marked_by_execution_order
        end

        -- Frame-specific unit data
        local half_width, half_height, hit_unit_center_pos
        if metadata.last_frame == fixed_frame and metadata.hit_unit_center_pos and _G.type(metadata.hit_unit_center_pos) ~= "userdata" then
            half_width = metadata.half_width
            half_height = metadata.half_height
            hit_unit_center_pos = metadata.hit_unit_center_pos
        else
            local hit_unit_pose, _ = Unit_box(hit_unit, true)
            local raw_hit_unit_center_pos, _ = Actor_world_bounds(hit_actor)
            hit_unit_center_pos = Vector3(raw_hit_unit_center_pos.x, raw_hit_unit_center_pos.y, raw_hit_unit_center_pos.z)
            local object_right = Matrix4x4_right(hit_unit_pose)
            local object_forward = Matrix4x4_forward(hit_unit_pose)
            local world_extents_right = object_right * metadata.half_extent_right
            local world_extents_forward = object_forward * metadata.half_extent_forward
            half_width = math_max(
                math_abs(Vector3_dot(right, world_extents_right + world_extents_forward)),
                math_abs(Vector3_dot(right, world_extents_right - world_extents_forward))
            )
            half_height = Breed_height(hit_unit, breed_data) * 0.5

            metadata.last_frame = fixed_frame
            metadata.half_width = half_width
            metadata.half_height = half_height
            metadata.hit_unit_center_pos = hit_unit_center_pos
        end

        local dist_sq = Vector3_distance_squared(hit_unit_center_pos, ray_origin)
        local min_r = min_range + half_width
        local max_r = max_range + half_width
        -- filter unit by range
        if dist_sq < min_r * min_r or dist_sq > max_r * max_r then
            goto continue_loop
        end

        local distance
        if type ~= "auto" then
            distance = math_sqrt(dist_sq) - half_width
        end

        local hit_unit_tag = smart_tag_system:unit_tag(hit_unit)
        -- filter unit by tag
        if type == "auto" and not is_target_valid(tag_name, hit_unit_tag, hit_unit, hit_unit_center_pos, companion_unit_position, talent_resource_component) then
            goto continue_loop
        end

        if type == "auto" then
            if tag_name == SERVO_SKULL_TAG_NAME and mod_settings.servo_skull_line_of_sight then
                if not mod:is_servo_skull_target_visible(hit_unit, t) then
                    goto continue_loop
                end
            else
                -- Performance Limit: Only perform a set number of visibility checks per frame
                local max_visibility_checks = mod_settings.max_visibility_checks or 2
                if visibility_check_count >= max_visibility_checks then
                    goto continue_loop
                end

                if not is_unit_on_screen(hit_unit) then
                    goto continue_loop
                end

                -- Visibility check is expensive, do it last
                visibility_check_count = visibility_check_count + 1
                if not is_target_visible(ray_origin, hit_unit_center_pos, hit_unit, t, dist_sq, fixed_frame) then
                    goto continue_loop
                end
            end

            best_unit = hit_unit
            best_unit_tag = hit_unit_tag
            best_unit_priority = hit_unit_priority
            -- Use cached value instead of recalculating
            best_unit_marked_by_execution_order = metadata.hit_unit_marked_by_execution_order
        elseif type == "focus_target_melee" then
            if best_unit and best_unit_distance <= 3.5 and distance > 3.5 then
                goto continue_loop
            end

            local hit_offset = hit_position - hit_unit_center_pos
            local x_diff_no_abs = Vector3_dot(hit_offset, right)
            local x_diff = math_abs(x_diff_no_abs)
            local y_diff = math_abs(Vector3_dot(hit_offset, up))
            if x_diff > half_width * 1.5 + 1 or y_diff > half_height + 1 then
                goto continue_loop
            end

            local hit_direction = Vector3_normalize(hit_unit_center_pos - ray_origin)
            local hit_dot = Vector3_dot(forward, hit_direction)
            if hit_dot < 0.7 or best_unit and (hit_dot <= best_unit_dot or x_diff > half_width or y_diff > half_height) then
                goto continue_loop
            end

            if not is_target_visible(ray_origin, hit_unit_center_pos, hit_unit, t, dist_sq, fixed_frame) then
                goto continue_loop
            end

            best_unit = hit_unit
            best_unit_tag = hit_unit_tag
            best_unit_dot = hit_dot
            best_unit_distance = distance
            if x_diff <= half_width * 1.5 + 0.5 and y_diff <= half_height + 0.5 then
                break
            end
        end

        ::continue_loop::
    end

    if best_unit ~= marked_unit then
        return best_unit, best_unit_tag
    end

    return nil
end

function mod:is_target_valid(tag_name, hit_unit_tag, hit_unit, hit_unit_center_pos, companion_unit_position, talent_resource_component)
    return is_target_valid(tag_name, hit_unit_tag, hit_unit, hit_unit_center_pos, companion_unit_position, talent_resource_component)
end

function mod:find_target_units_consolidated(active_tags, t)
    local player = context.player
    local player_unit = player and player.player_unit
    local smart_targeting_extension = context.smart_targeting_extension
    local smart_tag_system = context.smart_tag_system
    if not player_unit or not smart_targeting_extension or not smart_tag_system then
        return nil
    end

    local fixed_frame = smart_targeting_extension._latest_fixed_frame
    local ray_origin, forward, right, up
    local hits, num_hits

    local max_range = 0
    for tag_name, data in pairs(active_tags) do
        max_range = math_max(max_range, data.max_range)
    end

    if fixed_frame == last_raycast_frame then
        ray_origin = last_ray_origin
        forward = last_forward
        right = last_right
        up = last_up
        hits = last_raycast_hits
        num_hits = last_raycast_num_hits
    else
        ray_origin, forward, right, up = smart_targeting_extension:_targeting_parameters()
        hits, num_hits = PhysicsWorld_raycast(smart_targeting_extension._physics_world, ray_origin, forward, max_range,
            "all", "collision_filter", COLLISION_FILTER)

        last_raycast_frame = fixed_frame
        last_ray_origin = ray_origin
        last_forward = forward
        last_right = right
        last_up = up
        last_raycast_hits = hits
        last_raycast_num_hits = num_hits
    end

    if num_hits <= 0 then
        return nil
    end

    local tag_params = {}
    for tag_name, data in pairs(active_tags) do
        local params = {
            name = tag_name,
            min_range = data.min_range,
            max_range = data.max_range,
            tag_context = data.tag_context,
            class_settings = data.class_settings,
            is_execution_order_priority = data.is_execution_order_priority,
            marked_tag = data.marked_tag,
            marked_unit = data.marked_tag and data.marked_tag._target_unit,
            best_unit = nil,
            best_unit_tag = nil,
            best_unit_priority = -math_huge,
            best_unit_marked_by_execution_order = false,
        }
        
        if params.marked_unit and Unit_alive(params.marked_unit) then
            params.best_unit = params.marked_unit
            local unit_data_extension = ScriptUnit_extension(params.best_unit, "unit_data_system")
            local breed_data = unit_data_extension and unit_data_extension._breed
            params.best_unit_priority = get_breed_priority(params.best_unit, breed_data, data.class_settings.breed_priorities, breed_data and breed_data.name .. "_passive")
            params.best_unit_marked_by_execution_order = not not mark_context.execution_order_units[params.best_unit]
        end

        if tag_name == COMPANION_TAG_NAME then
            local min_range = mod_settings.companion_min_range
            local max_range = mod_settings.companion_max_range
            if min_range > 0 or max_range < 100 then
                local companion_spawner_extension = context.companion_spawner_extension
                local companion_units = companion_spawner_extension and companion_spawner_extension:companion_units()
                local companion_unit = companion_units and companion_units[1]
                params.companion_unit_position = companion_unit and Unit_world_position(companion_unit, 1)
            end
        elseif tag_name == SERVO_SKULL_TAG_NAME then
            local min_range = mod_settings.servo_skull_min_range
            local max_range = mod_settings.servo_skull_max_range
            if min_range > 0 or max_range < 100 then
                local companion_spawner_extension = context.companion_spawner_extension
                local servo_skull_unit = companion_spawner_extension and companion_spawner_extension:spawned_unit_lookup(special_rules.cryptic_servo_skull_hack)
                params.companion_unit_position = Unit_alive(servo_skull_unit) and Unit_world_position(servo_skull_unit, 1)
            end
        elseif tag_name == VETERAN_TAG_NAME then
            params.talent_resource_component = context.talent_resource_component
        end

        tag_params[#tag_params + 1] = params
    end

    local visibility_check_count = 0
    local execution_order_units = mark_context.execution_order_units

    for i = 1, num_hits do
        local hit = hits[i]
        if not hit then goto continue_loop end

        local hit_distance = hit[INDEX_DISTANCE]
        if hit_distance < 0.1 then goto continue_loop end

        local hit_actor = hit[INDEX_ACTOR]
        if not hit_actor then goto continue_loop end

        local success, hit_unit = pcall(Actor_unit, hit_actor)
        if not success or not hit_unit or hit_unit == player_unit or not HEALTH_ALIVE[hit_unit] then
            goto continue_loop
        end

        local metadata = unit_metadata_cache[hit_unit]
        if not metadata then
            local unit_data_extension = ScriptUnit_extension(hit_unit, "unit_data_system")
            local breed_data = unit_data_extension and unit_data_extension._breed
            local breed_name = breed_data and breed_data.name
            metadata = {
                breed_data = breed_data,
                breed_name = breed_name,
                breed_name_passive = breed_name and breed_name .. "_passive",
                is_taggable = not not (breed_data and breed_data.smart_tag_target_type == "breed"),
                half_extent_right = breed_data and (breed_data.half_extent_right or 0.3) or 0.3,
                half_extent_forward = breed_data and (breed_data.half_extent_forward or 0.3) or 0.3,
            }
            unit_metadata_cache[hit_unit] = metadata
        end
        unit_metadata_cache_frame[hit_unit] = fixed_frame
        if not metadata.is_taggable then goto continue_loop end

        local half_width, hit_unit_center_pos
        if metadata.last_frame == fixed_frame and metadata.hit_unit_center_pos and _G.type(metadata.hit_unit_center_pos) ~= "userdata" then
            half_width = metadata.half_width
            hit_unit_center_pos = metadata.hit_unit_center_pos
        else
            local hit_unit_pose, _ = Unit_box(hit_unit, true)
            local raw_hit_unit_center_pos, _ = Actor_world_bounds(hit_actor)
            hit_unit_center_pos = Vector3(raw_hit_unit_center_pos.x, raw_hit_unit_center_pos.y, raw_hit_unit_center_pos.z)
            local object_right = Matrix4x4_right(hit_unit_pose)
            local object_forward = Matrix4x4_forward(hit_unit_pose)
            local world_extents_right = object_right * metadata.half_extent_right
            local world_extents_forward = object_forward * metadata.half_extent_forward
            half_width = math_max(
                math_abs(Vector3_dot(right, world_extents_right + world_extents_forward)),
                math_abs(Vector3_dot(right, world_extents_right - world_extents_forward))
            )
            metadata.last_frame = fixed_frame
            metadata.half_width = half_width
            metadata.hit_unit_center_pos = hit_unit_center_pos
        end

        local dist_sq = Vector3_distance_squared(hit_unit_center_pos, ray_origin)
        local hit_unit_tag = smart_tag_system:unit_tag(hit_unit)
        local hit_unit_marked_by_execution_order = not not execution_order_units[hit_unit]
        local is_on_screen = nil

        for j = 1, #tag_params do
            local p = tag_params[j]
            if hit_unit == p.marked_unit or hit_unit == (p.tag_context and p.tag_context.canceled_unit) then
                goto next_tag
            end

            local min_r = p.min_range + half_width
            local max_r = p.max_range + half_width
            if dist_sq < min_r * min_r or dist_sq > max_r * max_r then
                goto next_tag
            end

            local breed_priorities = p.class_settings.breed_priorities or EMPTY_TABLE
            local hit_unit_priority = get_breed_priority(hit_unit, metadata.breed_data, breed_priorities, metadata.breed_name_passive)
            if hit_unit_priority <= 0 or not is_breed_valid(metadata.breed_data, p.class_settings) then
                goto next_tag
            end

            if p.is_execution_order_priority then
                if hit_unit_marked_by_execution_order == p.best_unit_marked_by_execution_order then
                    if hit_unit_priority <= p.best_unit_priority then goto next_tag end
                elseif p.best_unit_marked_by_execution_order then
                    goto next_tag
                end
            else
                if hit_unit_priority <= p.best_unit_priority then goto next_tag end
            end

            if not is_target_valid(p.name, hit_unit_tag, hit_unit, hit_unit_center_pos, p.companion_unit_position, p.talent_resource_component) then
                goto next_tag
            end

            local is_visible
            if p.name == SERVO_SKULL_TAG_NAME then
                if not mod_settings.servo_skull_line_of_sight then
                    if is_on_screen == nil then is_on_screen = is_unit_on_screen(hit_unit) end
                    if not is_on_screen then goto next_tag end
                end
                is_visible = mod:is_servo_skull_target_visible(hit_unit, t)
            else
                local max_visibility_checks = mod_settings.max_visibility_checks or 2
                if visibility_check_count >= max_visibility_checks then
                    goto next_tag
                end
                if is_on_screen == nil then is_on_screen = is_unit_on_screen(hit_unit) end
                if not is_on_screen then goto next_tag end
                visibility_check_count = visibility_check_count + 1
                is_visible = is_target_visible(ray_origin, hit_unit_center_pos, hit_unit, t, dist_sq, fixed_frame)
            end

            if is_visible then
                p.best_unit = hit_unit
                p.best_unit_tag = hit_unit_tag
                p.best_unit_priority = hit_unit_priority
                p.best_unit_marked_by_execution_order = hit_unit_marked_by_execution_order
            end

            ::next_tag::
        end

        ::continue_loop::
    end

    local results = {}
    for j = 1, #tag_params do
        local p = tag_params[j]
        if p.best_unit and p.best_unit ~= p.marked_unit then
            results[p.name] = { unit = p.best_unit, tag = p.best_unit_tag }
        end
    end

    return next(results) and results or nil
end

mod:hook_safe(CLASS.PrecisionTargetFinder, "init",
    function(self, is_server, is_local_unit, player, physics_world, unit)
        visibility_raycast_object = PhysicsWorld.make_raycast(physics_world, "closest", "types", "statics",
            "collision_filter", "filter_interactable_line_of_sight_marker_check")
        servo_skull_visibility_raycast_object = PhysicsWorld.make_raycast(physics_world, "closest", "types", "statics",
            "collision_filter", "filter_minion_line_of_sight_check")
    end)
