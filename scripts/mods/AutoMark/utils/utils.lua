local mod          = get_mod("AutoMark")
local mod_settings = mod.settings

-- Global Cache
local Managers     = Managers

-- Debug Print
function mod:print_debug(...)
    if not mod_settings.debug_mode then
        return -- Early exit before any work
    end

    local n = select("#", ...)
    if n == 0 then
        return
    end
    local result = tostring(select(1, ...))
    for i = 2, n do
        local value = select(i, ...)
        result = result .. " " .. tostring(value)
    end
    mod:echo(result)
end

-- Time for Now
function mod:main_time()
    return Managers.time:time("main")
end

function mod:gameplay_time()
    return Managers.time:time("gameplay")
end

local RITUAL_MUTATOR = "mutator_havoc_chaos_rituals"

local function unit_is_alive(unit)
    return unit and Unit.alive(unit)
end

function mod:find_ritual_units()
    local side_system = Managers.state.extension and Managers.state.extension:system("side_system")
    if not side_system then
        return {}
    end
    local player_side = side_system:get_side_from_name("heroes")
    if not player_side then
        return {}
    end

    local enemy_units = nil
    if player_side.alive_units_by_tag then
        enemy_units = player_side:alive_units_by_tag("enemy", "witch")
    end
    local count = enemy_units and (enemy_units.size or #enemy_units) or 0
    if count == 0 then
        enemy_units = player_side:relation_units("enemy") or {}
    end
    enemy_units = enemy_units or {}
    local ritual_units = {}
    local seen = {}

    local function add_ritual_unit(unit, skip_breed_check)
        if not unit or seen[unit] or not unit_is_alive(unit) then
            return
        end
        if skip_breed_check then
            ritual_units[#ritual_units + 1] = unit
            seen[unit] = true
            return
        end
        if ScriptUnit.has_extension(unit, "unit_data_system") then
            local unit_data_extension = ScriptUnit.extension(unit, "unit_data_system")
            local breed = unit_data_extension and unit_data_extension:breed()
            if breed and breed.name == "chaos_mutator_daemonhost" then
                ritual_units[#ritual_units + 1] = unit
                seen[unit] = true
            end
        end
    end

    count = enemy_units.size or #enemy_units
    if count > 0 then
        for i = 1, count do
            add_ritual_unit(enemy_units[i])
        end
    else
        for key, value in pairs(enemy_units) do
            local unit = key
            if type(unit) ~= "userdata" then
                unit = value
            end
            add_ritual_unit(unit)
        end
    end

    local mutator_manager = Managers.state.mutator
    if mutator_manager and mutator_manager.mutator then
        local mutator_names = { "mutator_monster_spawner", RITUAL_MUTATOR }
        for n = 1, #mutator_names do
            local ok, mutator = pcall(mutator_manager.mutator, mutator_manager, mutator_names[n])
            if ok and mutator and mutator._alive_monsters then
                for i = 1, #mutator._alive_monsters do
                    local monster = mutator._alive_monsters[i]
                    if monster and monster.breed_name == "chaos_mutator_daemonhost" then
                        add_ritual_unit(monster.spawned_unit, true)
                    end
                end
            end
        end
    end

    return ritual_units
end

function mod:is_ritual_active()
    if not Managers or not Managers.state then
        return false
    end
    local units = mod:find_ritual_units()
    return #units > 0
end
