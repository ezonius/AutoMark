local mod                       = get_mod("AutoMark")
local context                   = mod.context
local mark_context              = mod.mark_context
local TAG_NAMES                 = mod.TAG_NAMES
local mod_settings              = mod.settings
local visibility_cache          = mod.visibility_cache
local visibility_check_frame    = mod.visibility_check_frame

-- Imports
local Breed                     = require("scripts/utilities/breed")
local Breed_height              = Breed.height

-- Global Cache
local HEALTH_ALIVE              = HEALTH_ALIVE
local Actor_unit                = Actor.unit
local Actor_world_bounds        = Actor.world_bounds
local Unit_box                  = Unit.box
local Unit_world_position       = Unit.world_position
local PhysicsWorld_raycast      = PhysicsWorld.raycast
local Raycast_cast              = Raycast.cast
local ScriptUnit_extension      = ScriptUnit.extension
local math_abs                  = math.abs
local math_max                  = math.max
local Vector3_dot               = Vector3.dot
local Vector3_normalize         = Vector3.normalize
local Vector3_length            = Vector3.length

local Vector3_distance          = Vector3.distance
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
local visibility_raycast_object = nil

function mod:init_visibility_raycast()
    local smart_targeting_extension = context.smart_targeting_extension
    local physics_world = smart_targeting_extension and smart_targeting_extension._physics_world
    if physics_world then
        visibility_raycast_object = PhysicsWorld.make_raycast(physics_world, "closest", "types", "both",
            "collision_filter", "filter_interactable_line_of_sight_marker_check")
    end
end

-- Check if Target Unit's Breed is Valid for Auto-Mark
local function is_breed_valid(breed_data, class_settings)
    if not breed_data or not class_settings then
        return false
    end

    -- toggle enemy by type
    if breed_data.tags.elite then
        if not class_settings.toggle_elite then
            return false
        end
    elseif breed_data.tags.special then
        if not class_settings.toggle_special then
            return false
        end
    elseif breed_data.is_boss then
        if not class_settings.toggle_boss then
            return false
        end
    else
        if not class_settings.toggle_other then
            return false
        end
    end

    return true
end

-- Check if Tagged Target Unit can be Marked with Current Tag
local function is_target_valid(tag_name, target_tag, target_unit, target_unit_position)
    if tag_name == TAG_NAMES.COMPANION_TAG then
        -- arbite shouldn't mark any arbite's prey or veteran's prey
        local target_tag_name = target_tag and target_tag._template.name
        if target_tag_name == TAG_NAMES.COMPANION_TAG or target_tag_name == TAG_NAMES.VETERAN_TAG then
            return false
        end

        local companion_range_limitation = mod_settings.companion_range_limitation
        if companion_range_limitation <= 0 then
            return true
        end

        local companion_spawner_extension = context.companion_spawner_extension
        local companion_units = companion_spawner_extension and companion_spawner_extension:companion_units()
        local companion_unit = companion_units and companion_units[1]
        if not companion_unit then
            return false
        end

        local companion_unit_position = Unit_world_position(companion_unit, 1)
        if not companion_unit_position or not target_unit_position then
            return false
        end

        if Vector3_distance_squared(companion_unit_position, target_unit_position) < companion_range_limitation * companion_range_limitation then
            return true
        end
    elseif tag_name == TAG_NAMES.VETERAN_TAG then
        local target_buff_extension = ScriptUnit_extension(target_unit, "buff_system")
        if not target_buff_extension then
            return false
        end

        local focus_target_debuff = target_buff_extension._stacking_buffs["veteran_improved_tag_debuff"]
        local target_stack_count = focus_target_debuff and focus_target_debuff:stack_count() or 0
        local target_tag_name = target_tag and target_tag._template.name
        -- target does not have focus target debuff
        if target_tag_name ~= TAG_NAMES.VETERAN_TAG and target_stack_count <= 0 then
            return true
        end

        -- latency bug
        if target_tag_name == TAG_NAMES.VETERAN_TAG and target_stack_count <= 0 then
            return false
        end

        -- focus_target_overwrite not enabled
        if not mod_settings.focus_target_overwrite then
            return false
        end

        local talent_resource_component = context.talent_resource_component
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
    elseif tag_name == TAG_NAMES.ENEMY_TAG then
        if not target_tag then
            return true
        end
    end

    return false
end

local function is_target_visible(ray_origin, hit_unit_center_pos, hit_unit, fixed_frame)
    if not visibility_raycast_object then
        return false
    end

    local cached_visibility = visibility_cache[hit_unit]
    local last_check_frame = visibility_check_frame[hit_unit]
    if cached_visibility ~= nil and fixed_frame - last_check_frame < 5 then
        return cached_visibility
    end

    local ray_to_target = hit_unit_center_pos - ray_origin
    local hit = Raycast_cast(
        visibility_raycast_object, ray_origin,
        Vector3_normalize(ray_to_target), Vector3_length(ray_to_target)
    )
    visibility_cache[hit_unit] = not hit
    visibility_check_frame[hit_unit] = fixed_frame
    return not hit
end

function mod:find_target_unit_custom(type, min_range, max_range, tag_name, tag_context, class_settings, use_filter,
                                     is_execution_order_priority, marked_tag)
    local player = context.player
    local player_unit = player and player.player_unit
    local smart_targeting_extension = context.smart_targeting_extension
    local precision_target_finder = smart_targeting_extension._precision_target_aim_assist
    local smart_tag_system = context.smart_tag_system
    if not player_unit or not smart_targeting_extension or not precision_target_finder or not smart_tag_system then
        return nil
    end

    -- raycast for hit unit list
    local ray_origin, forward, right, up = smart_targeting_extension:_targeting_parameters()
    local hits, num_hits = PhysicsWorld_raycast(smart_targeting_extension._physics_world, ray_origin, forward, max_range,
        "all", "collision_filter", COLLISION_FILTER)
    if num_hits <= 0 then
        return nil
    end

    local fixed_frame = smart_targeting_extension._latest_fixed_frame
    local canceled_unit = tag_context and tag_context.canceled_unit
    local breed_priorities = class_settings and class_settings.breed_priorities or EMPTY_TABLE
    local execution_order_units = mark_context.execution_order_units
    local best_unit = nil
    local best_unit_tag = nil
    local best_unit_priority = -math.huge
    local best_unit_marked_by_execution_order = false
    local best_unit_dot = -math.huge
    local best_unit_distance = math.huge
    -- init best unit for switch logic
    local marked_unit = marked_tag and marked_tag._target_unit
    if marked_unit then
        best_unit = marked_unit
        local unit_data_extension = ScriptUnit_extension(best_unit, "unit_data_system")
        local breed_data = unit_data_extension and unit_data_extension._breed
        local breed_name = breed_data and breed_data.name
        best_unit_priority = breed_priorities[breed_name] or 0
        best_unit_marked_by_execution_order = not not execution_order_units[best_unit]
    end


    for i = 1, num_hits do
        local hit = hits[i]
        local hit_position = hit[INDEX_POSITION]
        local hit_actor = hit[INDEX_ACTOR]
        if not hit_actor then
            goto continue
        end

        local hit_unit = Actor_unit(hit_actor)
        -- ignore player unit, already marked unit and dead unit
        if hit_unit == player_unit or hit_unit == marked_unit or hit_unit == canceled_unit or not HEALTH_ALIVE[hit_unit] then
            goto continue
        end

        local unit_data_extension = ScriptUnit_extension(hit_unit, "unit_data_system")
        local breed_data = unit_data_extension and unit_data_extension._breed
        -- ignore untaggable unit
        if not breed_data or breed_data.smart_tag_target_type ~= "breed" then
            goto continue
        end

        local hit_unit_priority = breed_priorities[breed_data.name] or 0
        -- filter unit by type and priority
        if use_filter and (hit_unit_priority <= 0 or not is_breed_valid(breed_data, class_settings)) then
            goto continue
        end

        local hit_unit_pose, _ = Unit_box(hit_unit, true)
        local hit_unit_center_pos, _ = Actor_world_bounds(hit_actor)
        local object_right = Matrix4x4_right(hit_unit_pose)
        local object_forward = Matrix4x4_forward(hit_unit_pose)
        local world_extents_right = object_right * (breed_data.half_extent_right or 0.3)
        local world_extents_forward = object_forward * (breed_data.half_extent_forward or 0.3)
        local half_width = math_max(
            math_abs(Vector3_dot(right, world_extents_right + world_extents_forward)),
            math_abs(Vector3_dot(right, world_extents_right - world_extents_forward))
        )
        local half_height = Breed_height(hit_unit, breed_data) * 0.5
        local distance = Vector3_distance(hit_unit_center_pos, ray_origin) - half_width
        -- filter unit by range
        if distance < min_range or distance > max_range then
            goto continue
        end

        local hit_unit_tag = smart_tag_system:unit_tag(hit_unit)
        -- filter unit by tag
        if type == "auto" and not is_target_valid(tag_name, hit_unit_tag, hit_unit, hit_unit_center_pos) then
            goto continue
        end

        if type == "auto" then
            local hit_unit_marked_by_execution_order = not not execution_order_units[hit_unit]
            if is_execution_order_priority then
                if hit_unit_marked_by_execution_order == best_unit_marked_by_execution_order then
                    if hit_unit_priority <= best_unit_priority then
                        goto continue
                    end
                elseif best_unit_marked_by_execution_order then
                    goto continue
                end
            else
                if hit_unit_priority <= best_unit_priority then
                    goto continue
                end
            end

            if not is_target_visible(ray_origin, hit_unit_center_pos, hit_unit, fixed_frame) then
                goto continue
            end

            best_unit = hit_unit
            best_unit_tag = hit_unit_tag
            best_unit_priority = hit_unit_priority
            best_unit_marked_by_execution_order = hit_unit_marked_by_execution_order
        elseif type == "focus_target_melee" then
            if best_unit and best_unit_distance <= 3.5 and distance > 3.5 then
                goto continue
            end

            local hit_offset = hit_position - hit_unit_center_pos
            local x_diff_no_abs = Vector3_dot(hit_offset, right)
            local x_diff = math_abs(x_diff_no_abs)
            local y_diff = math_abs(Vector3_dot(hit_offset, up))
            if x_diff > half_width * 1.5 + 1 or y_diff > half_height + 1 then
                goto continue
            end

            local hit_direction = Vector3_normalize(hit_unit_center_pos - ray_origin)
            local hit_dot = Vector3_dot(forward, hit_direction)
            if hit_dot < 0.7 or best_unit and (hit_dot <= best_unit_dot or x_diff > half_width or y_diff > half_height) then
                goto continue
            end

            if not is_target_visible(ray_origin, hit_unit_center_pos, hit_unit, fixed_frame) then
                goto continue
            end

            best_unit = hit_unit
            best_unit_tag = hit_unit_tag
            best_unit_dot = hit_dot
            best_unit_distance = distance
            if x_diff <= half_width * 1.5 + 0.5 and y_diff <= half_height + 0.5 then
                break
            end
        end

        ::continue::
    end

    if best_unit ~= marked_unit then
        return best_unit, best_unit_tag
    end

    return nil
end

function mod:is_target_valid(tag_name, hit_unit_tag, hit_unit, hit_unit_center_pos)
    return is_target_valid(tag_name, hit_unit_tag, hit_unit, hit_unit_center_pos)
end

mod:hook_safe(CLASS.PrecisionTargetFinder, "init",
    function(self, is_server, is_local_unit, player, physics_world, unit)
        visibility_raycast_object = PhysicsWorld.make_raycast(physics_world, "closest", "types", "both",
            "collision_filter", "filter_interactable_line_of_sight_marker_check")
    end)
