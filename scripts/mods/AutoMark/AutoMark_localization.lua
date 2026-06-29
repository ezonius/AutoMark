local breeds     = require("scripts/settings/breed/breeds")
local archetypes = require("scripts/settings/archetype/archetypes")
local Breed      = require("scripts/utilities/breed")
local InputUtils = require("scripts/managers/input/input_utils")

local Color      = Color
local Localize   = Localize
local string     = string

local function color_text(text, color_name)
    local color = Color[color_name](255, true)
    return InputUtils.apply_color_to_input_text(text, color)
end

local function highlight(text)
    return color_text(text, "terminal_text_warning_light")
end

local localization = {
    -- mod_name
    mod_name = {
        en = "Auto Mark",
        ["zh-cn"] = "自动标记",
    },
    mod_description = {
        en = "Enhance your marking experience",
        ["zh-cn"] = "增强你的标记体验",
    },
    -- mod_settings
    mod_settings = {
        en = "Mod Settings",
        ["zh-cn"] = "模组设置",
    },
    toggle_mod = {
        en = "Toggle Mod",
        ["zh-cn"] = "模组开关",
    },
    toggle_mod_keybind = {
        en = "Toggle Keybind",
        ["zh-cn"] = "模组开关按键",
    },
    toggle_mod_notify = {
        en = "Toggle Notification",
        ["zh-cn"] = "模组开关通知",
    },
    debug_mode = {
        en = "Debug Mode",
        ["zh-cn"] = "调试模式",
    },
    -- arbites settings
    adamant_settings = {
        en = "Arbites Settings",
        ["zh-cn"] = "法务官设置",
    },
    companion_mark_keybind = {
        en = "Companion Mark Keybind",
        ["zh-cn"] = "伙伴标记按键",
    },
    companion_mark_keybind_description = {
        en =
            "Dedicated key for Companion Mark. As Arbites, you can now use both regular mark and companion mark at the same time.\n" ..
            "When " .. highlight("Companion Target Tag") ..
            " is set to " .. highlight("Press Once") ..
            ", this function becomes a normal enemy mark.",
        ["zh-cn"] = "伙伴标记专用按键，现在你可以作为法务官，同时使用普通标记和伙伴标记了。\n" ..
            "当" .. highlight("伙伴目标标记") ..
            "设置为" .. highlight("按一次") ..
            "时，此功能变为普通敌人标记。",
    },
    execution_order_priority = {
        en = "Execution Order Priority",
        ["zh-cn"] = "遵从处决指令",
    },
    execution_order_priority_description = {
        en =
        "Arbites companion auto-mark prioritizes enemies under Execution Order.\nSwitches target if your current marked target is not chosen by Execution Order, but your aimed target is.",
        ["zh-cn"] = "遵从处决指令的选择，法务官伙伴自动标记将优先标记已被处决指令选中的敌人。\n当已标记的敌人没有被处决指令选中，而正在瞄准的敌人被处决指令选中时，将切换至瞄准的目标。",
    },
    companion_range_limitation = {
        en = "Range Limitation",
        ["zh-cn"] = "范围限制",
    },
    companion_range_limitation_description = {
        en =
            "Restricts the maximum distance between your " ..
            highlight("cyber mastiff") .. " and a target that can be marked by the auto-mark system.\n" ..
            "Set to " .. highlight("0") .. " to disable.",
        ["zh-cn"] = "限制自动标记系统可标记的目标与你的" ..
            highlight("机械战犬") .. "之间的最大距离。\n" ..
            "设置为" .. highlight("0") .. "禁用。",
    },
    companion_cancel_mark = {
        en = "Cancel Mark on Condition",
        ["zh-cn"] = "根据条件取消标记",
    },
    companion_health_threshold = {
        en = "Health Threshold",
        ["zh-cn"] = "生命阈值",
    },
    companion_health_threshold_description = {
        en =
            "Cancel the companion mark when the health of your cyber mastiff's current attack target falls below your selected health percentage.\n" ..
            "Set to " .. highlight("0") .. " to disable.\n" ..
            "Only applies to " .. highlight("human-sized") .. " enemies.\n" ..
            "Does not affect " .. highlight("manual") .. " mark.",
        ["zh-cn"] = "当你的机械战犬当前攻击目标的血量低于你所选的百分比时，取消该目标的伙伴标记。\n" ..
            "设置为" .. highlight("0") .. "禁用。\n" ..
            "仅适用于" .. highlight("人类体型") .. "的敌人。\n" ..
            "对" .. highlight("手动") .. "标记无效。",
    },
    companion_time_threshold = {
        en = "Time Threshold",
        ["zh-cn"] = "时间阈值",
    },
    companion_time_threshold_description = {
        en =
            "Cancel the companion mark when your cyber mastiff has been attacking its current target for longer than your selected duration (in seconds).\n" ..
            "Set to " .. highlight("0") .. " to disable.\n" ..
            "Only applies to " .. highlight("human-sized") .. " enemies.\n" ..
            "Does not affect " .. highlight("manual") .. " mark.",
        ["zh-cn"] = "当你的机械战犬攻击当前目标的持续时间超过你所选的时长（单位：秒）时，取消该目标的伙伴标记。\n" ..
            "设置为" .. highlight("0") .. "禁用。\n" ..
            "仅适用于" .. highlight("人类体型") .. "的敌人。\n" ..
            "对" .. highlight("手动") .. "标记无效。",
    },
    -- veteran settings
    veteran_settings = {
        en = "Veteran Settings",
        ["zh-cn"] = "老兵设置",
    },
    focus_target_overwrite = {
        en = "Focus Target Overwrite",
        ["zh-cn"] = "聚焦目标覆盖",
    },
    focus_target_overwrite_description = {
        en = string.format(
            highlight("Off") ..
            ": Enemie marked by Focus Target will not be re-marked.\n" ..
            highlight("On") ..
            ": If the player's Focus Target stacks exceed those applied to the enemy, and the stack difference is greater than or equal to the option 'Focus Target Overwrite Delta' or the stacks are at max, the Focus Target mark will be reapplied."),
        ["zh-cn"] = string.format(
            highlight("关闭") ..
            "：已被聚焦目标标记的敌人，不会再次被标记。\n" ..
            highlight("开启") ..
            "：当玩家自身聚焦目标层数高于敌人已被施加的层数，且层数差大于等于下方选项「聚焦目标覆盖最小层数差」或自身层数已满时，将重新施加聚焦目标标记。"),
    },
    focus_target_overwrite_delta = {
        en = "Focus Target Overwrite Delta",
        ["zh-cn"] = "聚焦目标覆盖最小层数差",
    },
    focus_target_switch = {
        en = "Switch Target on Attack",
        ["zh-cn"] = "攻击时切换目标",
    },
    focus_target_switch_description = {
        en = "When the player is attacking, the focus target mark will switch to the aimed target.",
        ["zh-cn"] = "当进行攻击时，聚焦目标将标记当前瞄准的敌人。",
    },
    focus_target_switch_melee = {
        en = "Melee Weapon",
        ["zh-cn"] = "近战武器",
    },
    focus_target_switch_range = {
        en = "Ranged Weapon",
        ["zh-cn"] = "远程武器",
    },
    -- class settings
    auto_mark_settings = {
        en = "Auto Mark Settings",
        ["zh-cn"] = "自动标记设置",
    },
    class_selection = {
        en = "Class",
        ["zh-cn"] = "职业",
    },
    toggle_class = {
        en = "Toggle",
        ["zh-cn"] = "开关",
    },
    toggle_class_description = {
        en = "Toggle auto-mark for this class",
        ["zh-cn"] = "开启/关闭此职业的自动标记。",
    },
    cooldown = {
        en = "Cooldown Time",
        ["zh-cn"] = "冷却时间",
    },
    cooldown_description = {
        en = "Unit: Seconds",
        ["zh-cn"] = "单位：秒",
    },
    reset_cooldown = {
        en = "Reset Cooldown",
        ["zh-cn"] = "刷新冷却",
    },
    reset_cooldown_description = {
        en = "Resets auto-mark cooldown when the last mark disappears.",
        ["zh-cn"] = "当上个标记消失时，刷新自动标记冷却时间。",
    },
    mark_limit = {
        en = "Mark Limit",
        ["zh-cn"] = "标记限制",
    },
    mark_limit_description = {
        en = "Stops auto-mark when the last mark is present.",
        ["zh-cn"] = "当上个标记存在时，停止自动标记。",
    },
    min_range = {
        en = "Min Range",
        ["zh-cn"] = "最小范围",
    },
    max_range = {
        en = "Max Range",
        ["zh-cn"] = "最大范围",
    },
    max_range_description = {
        en = "Unit: Meters",
        ["zh-cn"] = "单位：米",
    },
    override_manual = {
        en = "Override Manual",
        ["zh-cn"] = "覆盖手动标记",
    },
    override_manual_description = {
        en = string.format(
            highlight("Off") ..
            ": Auto-mark stops when a manual mark is present.\n" ..
            highlight("On") ..
            ": Auto-mark continues to find new targets even when a manual mark is present."),
        ["zh-cn"] = string.format(
            highlight("关闭") .. "：手动标记存在时，自动标记将停止。\n" ..
            highlight("开启") .. "：即使当前标记为手动标记，自动标记也会继续寻找新的目标。"),
    },
    priority_switch = {
        en = "Priority Switch",
        ["zh-cn"] = "优先级切换",
    },
    priority_switch_description = {
        en = "Switches to the aimed target if it has higher priority than the current marked target.",
        ["zh-cn"] = "当正在瞄准的目标优先级高于已被标记的目标时，将切换至瞄准的目标。",
    },
    toggle_elite = {
        en = "Toggle Elite",
        ["zh-cn"] = "精英开关",
    },
    toggle_special = {
        en = "Toggle Special",
        ["zh-cn"] = "专家开关",
    },
    toggle_boss = {
        en = "Toggle Boss",
        ["zh-cn"] = "Boss开关",
    },
    toggle_other = {
        en = "Toggle Other",
        ["zh-cn"] = "其他开关",
    },
    priority_off = {
        en = "Off",
        ["zh-cn"] = "关闭",
    },
    priority_1 = {
        en = "Priority 1 (Lowest)",
        ["zh-cn"] = "优先级 1 (最低)",
    },
    priority_2 = {
        en = "Priority 2",
        ["zh-cn"] = "优先级 2",
    },
    priority_3 = {
        en = "Priority 3",
        ["zh-cn"] = "优先级 3",
    },
    priority_4 = {
        en = "Priority 4",
        ["zh-cn"] = "优先级 4",
    },
    priority_5 = {
        en = "Priority 5",
        ["zh-cn"] = "优先级 5",
    },
    priority_6 = {
        en = "Priority 6",
        ["zh-cn"] = "优先级 6",
    },
    priority_7 = {
        en = "Priority 7",
        ["zh-cn"] = "优先级 7",
    },
    priority_8 = {
        en = "Priority 8",
        ["zh-cn"] = "优先级 8",
    },
    priority_9 = {
        en = "Priority 9",
        ["zh-cn"] = "优先级 9",
    },
    priority_10 = {
        en = "Priority 10 (Highest)",
        ["zh-cn"] = "优先级 10 (最高)",
    },
    adamant_companion = {
        en = "Arbitrator Companion",
        ["zh-cn"] = "法务官伙伴",
    },
    veteran_focus_target = {
        en = "Veteran Focus Target",
        ["zh-cn"] = "老兵聚焦目标",
    },
    apply_to_all_classes = {
        en = "Apply to All Classes",
        ["zh-cn"] = "应用于所有职业",
    },
    apply_button = {
        en = "Apply Button",
        ["zh-cn"] = "应用键",
    },
    apply_button_description = {
        en = "Apply current settings to all classes.",
        ["zh-cn"] = "将当前设置应用于所有职业。",
    },
    reset_auto_mark_settings = {
        en = "Reset Auto Mark Settings",
        ["zh-cn"] = "重置自动标记设置",
    },
    reset_button = {
        en = "Reset Button",
        ["zh-cn"] = "重置键",
    },
    reset_button_description = {
        en = "Reset all options for all classes to their default values.",
        ["zh-cn"] = "将所有职业的所有选项重置为默认值。",
    },
    blank = {
        en = " ",
        ["zh-cn"] = " ",
    },
    apply = {
        en = "Apply",
        ["zh-cn"] = "应用",
    },
    reset = {
        en = "Reset",
        ["zh-cn"] = "重置",
    },
    apply_to_normal_tags = {
        en = "Apply to Normal Tags",
        ["zh-cn"] = "应用到普通标签",
    },
    reset_current_class = {
        en = "Reset Current Class",
        ["zh-cn"] = "重置当前职业",
    },
    apply_normal = {
        en = "Apply to Normal",
        ["zh-cn"] = "应用普通",
    },
    reset_current = {
        en = "Reset Current",
        ["zh-cn"] = "重置当前",
    },
}

local function is_localization_valid(text)
    if string.find(text, "string not found") then
        return false
    end
    return true
end

for breed_name, breed_data in pairs(breeds) do
    if Breed.is_minion(breed_data) then
        local text = Localize(
            breed_data.is_boss
            and type(breed_data.boss_display_name) == "string"
            and breed_data.boss_display_name
            or breed_data.display_name
        )
        text = is_localization_valid(text) and text or breed_name
        if string.find(breed_name, "mutator") then
            localization[breed_name] = {
                en = text .. " (Mutator)",
                ["zh-cn"] = text .. "（变异体）",
            }
        else
            localization[breed_name] = { en = text }
        end
    end
end

for class_name, archetype in pairs(archetypes) do
    local text = Localize(archetype.archetype_name)
    localization[class_name] = {
        en = text
    }
end

return localization
