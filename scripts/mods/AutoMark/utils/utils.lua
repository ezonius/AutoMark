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

function mod:is_ritual_active()
    if not Managers or not Managers.state then
        return false
    end

    local mutator_manager = Managers.state.mutator
    if mutator_manager and mutator_manager.mutator then
        local ok, mutator = pcall(mutator_manager.mutator, mutator_manager, RITUAL_MUTATOR)
        if ok and mutator then
            return true
        end
    end

    local difficulty = Managers.state.difficulty
    if difficulty and difficulty.get_parsed_havoc_data then
        local ok, havoc_data = pcall(difficulty.get_parsed_havoc_data, difficulty)
        if ok and havoc_data and havoc_data.circumstances then
            for i = 1, #havoc_data.circumstances do
                if havoc_data.circumstances[i] == RITUAL_MUTATOR then
                    return true
                end
            end
        end
    end

    return false
end
