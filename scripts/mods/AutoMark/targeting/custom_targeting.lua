local mod                       = get_mod("AutoMark")
local context                   = mod.context
local mark_context              = mod.mark_context
local TAG_NAMES                 = mod.TAG_NAMES
local mod_settings              = mod.settings
local visibility_cache          = mod.visibility_cache
local visibility_check_frame    = mod.visibility_check_frame
local unit_metadata_cache       = mod.unit_metadata_cache
local unit_metadata_cache_frame = mod.unit_metadata_cache_frame

-- Frame Cache for Raycast
local last_raycast_frame        = -1
local last_raycast_hits         = nil
local last_raycast_num_hits     = 0
local last_ray_origin           = nil
local last_forward              = nil
local last_right                = nil
local last_up                   = nil

-- Imports
local Breed                     = require("scripts/utilities/breed")
local Breed_height              = Breed.height

-- Global Cache
local HEALTH_ALIVE              = HEALTH_ALIVE
local Actor_unit                = Actor.unit
local Actor_world_bounds        = Actor.world_bounds
local Unit_alive               = Unit.alive
local Unit_box                  = Unit.box
local Unit_world_position       = Unit.world_position
local PhysicsWorld_raycast      = PhysicsWorld.raycast
local Raycast_cast              = Raycast.cast
local ScriptUnit_extension      = ScriptUnit.extension
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
local visibility_raycast_object = nil

function mod:reset_targeting_cache()
    last_raycast_frame = -1
    last_raycast_hits = nil
    last_raycast_num_hits = 0
    last_ray_origin = nil
    last_forward = nil
    last_right = nil
    last_up = nil
end

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

        -- Fallback for direct calls
        if not target_unit_position then
            target_unit_position = target_unit and Unit_world_position(target_unit, 1)
        end
        if not companion_unit_position then
            local companion_spawner_extension = context.companion_spawner_extension
            local companion_units = companion_spawner_extension and companion_spawner_extension:companion_units()
            local companion_unit = companion_units and companion_units[1]
            companion_unit_position = companion_unit and Unit_world_position(companion_unit, 1)
        end

        if not companion_unit_position or not target_unit_position then
            return false
        end

        if Vector3_distance_squared(companion_unit_position, target_unit_position) < companion_range_limitation * companion_range_limitation then
            return true
        end
    elseif tag_name == TAG_NAMES.VETERAN_TAG then
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
    elseif tag_name == TAG_NAMES.ENEMY_TAG then
        if not target_tag then
            return true
        end
    end

    return false
end

local function is_target_visible(ray_origin, hit_unit_center_pos, hit_unit, fixed_frame, dist_sq)
    if not visibility_raycast_object then
        return false
    end

    local cached_visibility = visibility_cache[hit_unit]
    local last_check_frame = visibility_check_frame[hit_unit]
    -- Cache for 10 frames (~0.16s) to cover the scan interval
    if cached_visibility ~= nil and fixed_frame - last_check_frame < 10 then
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
    if tag_name == TAG_NAMES.COMPANION_TAG then
        local companion_range_limitation = mod_settings.companion_range_limitation
        if companion_range_limitation > 0 then
            local companion_spawner_extension = context.companion_spawner_extension
            local companion_units = companion_spawner_extension and companion_spawner_extension:companion_units()
            local companion_unit = companion_units and companion_units[1]
            companion_unit_position = companion_unit and Unit_world_position(companion_unit, 1)
        end
    end
    local talent_resource_component = (tag_name == TAG_NAMES.VETERAN_TAG) and context.talent_resource_component or nil

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
        best_unit_priority = breed_priorities[breed_name] or 0
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
            local is_taggable = not not (breed_data and breed_data.smart_tag_target_type == "breed")
            metadata = {
                breed_data = breed_data,
                breed_name = breed_data and breed_data.name,
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

        local hit_unit_priority = breed_priorities[metadata.breed_name] or 0
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
        if metadata.last_frame == fixed_frame then
            half_width = metadata.half_width
            half_height = metadata.half_height
            hit_unit_center_pos = metadata.hit_unit_center_pos
        else
            local hit_unit_pose, _ = Unit_box(hit_unit, true)
            hit_unit_center_pos, _ = Actor_world_bounds(hit_actor)
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
            -- Visibility check is expensive, do it last
            if not is_target_visible(ray_origin, hit_unit_center_pos, hit_unit, fixed_frame, dist_sq) then
                goto continue_loop
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

            if not is_target_visible(ray_origin, hit_unit_center_pos, hit_unit, fixed_frame, dist_sq) then
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

mod:hook_safe(CLASS.PrecisionTargetFinder, "init",
    function(self, is_server, is_local_unit, player, physics_world, unit)
        visibility_raycast_object = PhysicsWorld.make_raycast(physics_world, "closest", "types", "both",
            "collision_filter", "filter_interactable_line_of_sight_marker_check")
    end)
