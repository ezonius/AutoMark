---@class AutoMarkMod:DMFMod
local mod                   = get_mod("AutoMark")
local mod_name              = mod:localize("mod_name")

-- Global Cache
local CLASS                 = CLASS

local last_scroll_value     = 0
local is_scroll_initialized = false

mod:hook_safe(CLASS.BaseView, "on_enter", function(self)
    if self.view_name == "dmf_options_view" then
        is_scroll_initialized = false
    end
end)

mod:hook_safe(CLASS.BaseView, "update", function(self)
    if self.view_name ~= "dmf_options_view" then
        return
    end

    if self._selected_category ~= mod_name then
        is_scroll_initialized = false
        return
    end

    local navigation_grids = self._navigation_grids
    local settings_content_grid = navigation_grids and navigation_grids[2]
    local scrollbar_widget = settings_content_grid and settings_content_grid._scrollbar_widget
    if not scrollbar_widget then
        return
    end

    if not is_scroll_initialized then
        scrollbar_widget.content.scroll_value = last_scroll_value
        scrollbar_widget.content.value = last_scroll_value
        is_scroll_initialized = true
    else
        last_scroll_value = settings_content_grid._scroll_progress
    end
end)
