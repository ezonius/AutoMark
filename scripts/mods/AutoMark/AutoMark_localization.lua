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
    -- throttling settings
    throttling_settings = {
        en = "Performance Throttling",
        ["zh-cn"] = "性能限制",
    },
    scan_interval = {
        en = "Idle Scan Interval",
        ["zh-cn"] = "空闲扫描间隔",
    },
    scan_interval_description = {
        en = "The minimum time between target scans when no valid target is found. Lower values are more responsive but use more CPU.",
        ["zh-cn"] = "未找到有效目标时，目标扫描之间的最小时间。较低的值响应更快，但会消耗更多 CPU。",
    },
    successful_scan_interval = {
        en = "Successful Scan Interval",
        ["zh-cn"] = "成功扫描间隔",
    },
    successful_scan_interval_description = {
        en = "The minimum time between target scans after a target has been successfully marked.",
        ["zh-cn"] = "成功标记目标后，目标扫描之间的最小时间。",
    },
    post_mark_delay = {
        en = "Post-Mark Delay",
        ["zh-cn"] = "标记后延迟",
    },
    post_mark_delay_description = {
        en = "The delay before any auto-mark can be triggered again after a mark is applied (covers server latency).",
        ["zh-cn"] = "应用标记后，再次触发任何自动标记之前的延迟（覆盖服务器延迟）。",
    },
    cancel_companion_mark_interval = {
        en = "Companion Cancel Check Interval",
        ["zh-cn"] = "伙伴取消检查间隔",
    },
    cancel_companion_mark_interval_description = {
        en = "Frequency of health and time checks for active companion marks.",
        ["zh-cn"] = "活动伙伴标记的生命值和时间检查频率。",
    },
    visibility_cache_duration = {
        en = "Visibility Cache Duration",
        ["zh-cn"] = "视野缓存持续时间",
    },
    visibility_cache_duration_description = {
        en = "How long a visibility check result remains cached for a unit.",
        ["zh-cn"] = "单位的视野检查结果在缓存中保留多长时间。",
    },
    noospheric_command_lead_time = {
        en = "Noospheric Command Re-mark Lead Time",
        ["zh-cn"] = "星语指令重新标记提前时间",
    },
    noospheric_command_lead_time_description = {
        en = "How much time before the Noospheric Command effect expires should a re-mark be attempted.",
        ["zh-cn"] = "在星语指令效果到期前多久尝试重新标记。",
    },
    max_visibility_checks = {
        en = "Max Visibility Checks Per Frame",
        ["zh-cn"] = "每帧最大视野检查次数",
    },
    max_visibility_checks_description = {
        en = "The maximum number of line-of-sight raycasts performed per frame to find new targets. Lower values improve performance but might delay marking when many enemies are on screen.",
        ["zh-cn"] = "每帧为了寻找新目标而进行的最大视线射线检测次数。较低的值可提高性能，但当屏幕上有许多敌人时可能会延迟标记。",
    },
    -- arbites settings
    adamant_settings = {
        en = "Arbites Settings",
        ["zh-cn"] = "法务官设置",
    },
    companion_mark_keybind = {
        en = "Cyber-Mastiff Mark Keybind",
        ["zh-cn"] = "智能獒犬标记按键",
    },
    companion_mark_keybind_description = {
        en =
            "Dedicated key for Cyber-Mastiff Mark. As Arbites, you can now use both normal enemy mark and Cyber-Mastiff mark at the same time.\n" ..
            "When " .. highlight("Companion Target Tag") ..
            " is set to " .. highlight("Press Once") ..
            ", this function becomes a normal enemy mark.",
        ["zh-cn"] = "智能獒犬标记专用按键，现在你可以作为法务官，同时使用普通敌人标记和智能獒犬标记了。\n" ..
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
        "Arbites Cyber-Mastiff auto-mark prioritizes enemies chosen by Execution Order.\nSwitches target if your current marked target is not chosen by Execution Order, but your aimed target is.",
        ["zh-cn"] = "遵从处决指令的选择，法务官智能獒犬自动标记将优先标记已被处决指令选中的敌人。\n当已标记的敌人没有被处决指令选中，而正在瞄准的敌人被处决指令选中时，将切换至瞄准的目标。",
    },
    companion_min_range = {
        en = "Min Range",
        ["zh-cn"] = "最小范围",
    },
    companion_max_range = {
        en = "Max Range",
        ["zh-cn"] = "最大范围",
    },
    companion_max_range_description = {
        en = "Unit: Meters",
        ["zh-cn"] = "单位：米",
    },
    companion_cancel_mark = {
        en = "Auto Cancel Cyber-Mastiff Mark",
        ["zh-cn"] = "自动取消智能獒犬标记",
    },
    companion_cancel_mark_human = {
        en = "Human",
        ["zh-cn"] = "人类",
    },
    companion_cancel_mark_human_description = {
        en = "Enable for human-sized enemies that can be pounced by your Cyber-Mastiff.",
        ["zh-cn"] = "在人类体型的敌人上启用，这些敌人可以被你的智能獒犬扑倒。",
    },
    companion_cancel_mark_non_human = {
        en = "Non-Human",
        ["zh-cn"] = "非人类",
    },
    companion_cancel_mark_non_human_description = {
        en = "Enable for non-human-sized enemies that cannot be pounced by your Cyber-Mastiff.",
        ["zh-cn"] = "在非人类体型的敌人上启用，这些敌人不能被你的智能獒犬扑倒。",
    },
    companion_health_threshold = {
        en = "Health Threshold",
        ["zh-cn"] = "生命阈值",
    },
    companion_health_threshold_description = {
        en =
            "Cancel the Cyber-Mastiff mark when the health of your Cyber-Mastiff's current attack target falls below your selected health percentage.\n" ..
            "Set to " .. highlight("0") .. " to disable.\n" ..
            "Does not affect " .. highlight("manual") .. " mark.",
        ["zh-cn"] = "当你的智能獒犬的攻击目标的血量低于你所选的百分比时，取消该目标的智能獒犬标记。\n" ..
            "设置为" .. highlight("0") .. "禁用。\n" ..
            "对" .. highlight("手动") .. "标记无效。",
    },
    companion_time_threshold = {
        en = "Time Threshold",
        ["zh-cn"] = "时间阈值",
    },
    companion_time_threshold_description = {
        en =
            "Cancel the Cyber-Mastiff mark when your Cyber-Mastiff has been attacking its current target for longer than your selected duration (in seconds).\n" ..
            "Set to " .. highlight("0") .. " to disable.\n" ..
            "Does not affect " .. highlight("manual") .. " mark.",
        ["zh-cn"] = "当你的智能獒犬攻击当前目标的持续时间超过你所选的时长（单位：秒）时，取消该目标的智能獒犬标记。\n" ..
            "设置为" .. highlight("0") .. "禁用。\n" ..
            "对" .. highlight("手动") .. "标记无效。",
    },
    -- cryptic settings
    cryptic_settings = {
        en = "Skitarii Settings",
        ["zh-cn"] = "护教军设置",
    },
    servo_skull_mark_keybind = {
        en = "Servo-Skull Mark Keybind",
        ["zh-cn"] = "伺服颅骨标记按键",
    },
    servo_skull_mark_keybind_description = {
        en =
            "Dedicated key for Servo-Skull Mark. As Skitarii, you can now use both normal enemy mark and Servo-Skull mark at the same time.\n" ..
            "When " .. highlight("Companion Target Tag") ..
            " is set to " .. highlight("Press Once") ..
            ", this function becomes a normal enemy mark.",
        ["zh-cn"] = "伺服颅骨标记专用按键，现在你可以作为护教军，同时使用普通敌人标记和伺服颅骨标记了。\n" ..
            "当" .. highlight("伙伴目标标记") ..
            "设置为" .. highlight("按一次") ..
            "时，此功能变为普通敌人标记。",
    },
    servo_skull_min_range = {
        en = "Min Range",
        ["zh-cn"] = "最小范围",
    },
    servo_skull_max_range = {
        en = "Max Range",
        ["zh-cn"] = "最大范围",
    },
    servo_skull_max_range_description = {
        en = "Unit: Meters",
        ["zh-cn"] = "单位：米",
    },
    servo_skull_line_of_sight = {
        en = "Servo-Skull Line of Sight",
        ["zh-cn"] = "伺服颅骨视线",
    },
    servo_skull_line_of_sight_description = {
        en = "Only require line of sight from the Servo-Skull to auto-tag targets, ignoring whether they are on-screen.",
        ["zh-cn"] = "自动标记时仅需从伺服颅骨的视线，无需目标在屏幕内。",
    },
    capacitance_retention = {
        en = "Capacitance Retention",
        ["zh-cn"] = "电容保留",
    },
    capacitance_retention_description = {
        en = "While the Noospheric Command talent is active, all Servo-Skull auto-marking features (including Noospheric Command Boost) will be disabled when remaining capacitance falls below the selected threshold. Remaining capacitance is calculated as ability charge count plus current capacitance percentage.",
        ["zh-cn"] = "当装备星语指令天赋时，如果剩余电容小于所选数值，禁用伺服颅骨相关的自动标记功能，包括星语指令增强。剩余电容等于技能充能次数+当前电容百分比。",
    },
    capacitance_retention_elite_threshold = {
        en = "Elite",
        ["zh-cn"] = "精英",
    },
    capacitance_retention_elite_threshold_description = {
        en = "Set Capacitance Retention Threshold for elites.",
        ["zh-cn"] = "为精英敌人设置电容保留阈值。",
    },
    capacitance_retention_special_threshold = {
        en = "Specialist",
        ["zh-cn"] = "专家",
    },
    capacitance_retention_special_threshold_description = {
        en = "Set Capacitance Retention Threshold for specialists.",
        ["zh-cn"] = "为专家敌人设置电容保留阈值。",
    },
    capacitance_retention_boss_threshold = {
        en = "Boss",
        ["zh-cn"] = "Boss",
    },
    capacitance_retention_boss_threshold_description = {
        en = "Set Capacitance Retention Threshold for bosses.",
        ["zh-cn"] = "为Boss设置电容保留阈值。",
    },
    capacitance_retention_breed_threshold = {
        en = "Capacitance Retention",
        ["zh-cn"] = "电容保留",
    },
    capacitance_retention_breed_threshold_description = {
        en = "Set Capacitance Retention Threshold for this enemy.",
        ["zh-cn"] = "为所选敌人设置电容保留阈值。",
    },
    noospheric_command_boost = {
        en = "Noospheric Command Boost",
        ["zh-cn"] = "星语指令增强",
    },
    noospheric_command_boost_description = {
        en = "Automatically re-marks marked targets to extend the Noospheric Command effect. Re-marking occurs at intervals equal to the effect's duration, and only triggers when the target is within the Servo-Skull's line of sight.",
        ["zh-cn"] = "自动对已标记目标进行重复标记，以延长星语指令的效果。重复标记间隔为星语指令的持续时间，只有当目标在伺服颅骨视野内时才会进行标记。",
    },
    noospheric_command_boost_elite = {
        en = "Elite",
        ["zh-cn"] = "精英",
    },
    noospheric_command_boost_elite_description = {
        en = "Enable Noospheric Command Boost for elites.",
        ["zh-cn"] = "为精英敌人启用星语指令增强",
    },
    noospheric_command_boost_special = {
        en = "Specialist",
        ["zh-cn"] = "专家",
    },
    noospheric_command_boost_special_description = {
        en = "Enable Noospheric Command Boost for specialists.",
        ["zh-cn"] = "为专家敌人启用星语指令增强",
    },
    noospheric_command_boost_boss = {
        en = "Boss",
        ["zh-cn"] = "Boss",
    },
    noospheric_command_boost_boss_description = {
        en = "Enable Noospheric Command Boost for bosses.",
        ["zh-cn"] = "为Boss启用星语指令增强",
    },
    noospheric_command_boost_breed_name = {
        en = "Enemy Settings Override",
        ["zh-cn"] = "敌人设置覆盖",
    },
    noospheric_command_boost_breed_name_description = {
        en = "Select an enemy to configure its individual settings, which override the settings above, except for the master toggle.",
        ["zh-cn"] = "选择一种敌人，为其配置其独立的设置，这些设置将覆盖上方的设置，除了总开关。",
    },
    noospheric_command_boost_reset = {
        en = "Reset to Defaults",
        ["zh-cn"] = "重置为默认值",
    },
    noospheric_command_boost_reset_description = {
        en = "Reset all per-enemy individual settings to their default values.",
        ["zh-cn"] = "重置所有敌人的设置为默认值。",
    },
    noospheric_command_boost_breed_override = {
        en = "Override",
        ["zh-cn"] = "启用覆盖",
    },
    noospheric_command_boost_breed_override_description = {
        en = "Apply dedicated settings for this enemy, which take priority over the general settings above, except for the master toggle.",
        ["zh-cn"] = "为这种敌人应用专用设置，这些设置将优先于上方的设置，除了总开关。",
    },
    noospheric_command_boost_breed_toggle = {
        en = "Noospheric Command",
        ["zh-cn"] = "星语指令",
    },
    noospheric_command_boost_breed_toggle_description = {
        en = "Enable/Disable Noospheric Command Boost for this enemy.",
        ["zh-cn"] = "为所选敌人启用/禁用星语指令增强。",
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
    class_selection_description = {
        en = "Normal enemy marks for all classes, plus special marks for certain classes (Cyber-Mastiff, Servo-Skull, Focus Target).",
        ["zh-cn"] = "所有职业的普通敌人标记，以及某些职业的特殊标记（智能獒犬、伺服颅骨、聚焦目标）。",
    },
    toggle_class = {
        en = "Toggle",
        ["zh-cn"] = "开关",
    },
    toggle_class_description = {
        en = "Toggle auto-mark for the selected mark type.",
        ["zh-cn"] = "开启/关闭所选标记类型的自动标记功能。",
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
        en = "Toggle Specialist",
        ["zh-cn"] = "专家开关",
    },
    toggle_special_description = {
        en = "Enable/Disable auto-mark for specialists.",
        ["zh-cn"] = "为专家敌人启用/禁用自动标记功能。",
    },
    toggle_elite_description = {
        en = "Enable/Disable auto-mark for elites.",
        ["zh-cn"] = "为精英敌人启用/禁用自动标记功能。",
    },
    toggle_boss_description = {
        en = "Enable/Disable auto-mark for bosses.",
        ["zh-cn"] = "为Boss启用/禁用自动标记功能。",
    },
    toggle_other_description = {
        en = "Enable/Disable auto-mark for other enemies.",
        ["zh-cn"] = "为其他敌人启用/禁用自动标记功能。",
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
    priority_1_rending = {
        en = "Priority 1 (Rending)",
        ["zh-cn"] = "优先级 1 (撕裂)",
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
        en = "Priority 10",
        ["zh-cn"] = "优先级 10",
    },    priority_lowest = {
        en = "Off",
        ["zh-cn"] = "关闭",
    },
    priority_low = {
        en = "Priority 1 (Lowest)",
        ["zh-cn"] = "优先级 1 (最低)",
    },
    priority_medium = {
        en = "Priority 2",
        ["zh-cn"] = "优先级 2",
    },
    priority_high = {
        en = "Priority 3",
        ["zh-cn"] = "优先级 3",
    },
    priority_highest = {
        en = "Priority 4 (Highest)",
        ["zh-cn"] = "优先级 4 (最高)",
    },
    cryptic_servo_skull = {
        en = "Skitarius Servo-Skull",
        ["zh-cn"] = "护教军伺服颅骨",
    },
    adamant_companion = {
        en = "Arbites Cyber-Mastiff",
        ["zh-cn"] = "法务官智能獒犬",
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
