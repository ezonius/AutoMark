local mod          = get_mod("AutoMark")
local mod_settings = mod.settings

-- Global Cache
local Managers     = Managers

-- Debug Print
function mod:print_debug(...)
    if mod_settings.debug_mode then
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
end

-- Time for Now
function mod:main_time()
    return Managers.time:time("main")
end

function mod:gameplay_time()
    return Managers.time:time("gameplay")
end
