local mod                      = get_mod("AutoMark")
local context                  = mod.context

-- Global Cache
local HEALTH_ALIVE             = HEALTH_ALIVE

local SMART_TARGETING_TEMPLATE = {
    precision_target = {
        max_range = 100,
        min_range = 1,
        smart_tagging = true,
    },
}

-- Find Target Unit For Mark System
function mod:find_target_unit()
    local smart_targeting_extension = context.smart_targeting_extension
    if not smart_targeting_extension then
        return nil
    end

    local ray_origin, forward, right, up = smart_targeting_extension:_targeting_parameters()
    smart_targeting_extension._precision_target_aim_assist:update_precision_target(
        smart_targeting_extension._unit,
        SMART_TARGETING_TEMPLATE,
        ray_origin, forward, right, up,
        smart_targeting_extension._smart_tag_targeting_data,
        smart_targeting_extension._latest_fixed_frame,
        smart_targeting_extension._visibility_cache,
        smart_targeting_extension._visibility_check_frame
    )
    local targeting_data = smart_targeting_extension:smart_tag_targeting_data()
    local target_unit = targeting_data and targeting_data.unit
    return HEALTH_ALIVE[target_unit] and target_unit
end
