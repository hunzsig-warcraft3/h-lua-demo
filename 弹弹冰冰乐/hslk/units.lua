--- Generated by h-lua(https://github.com/h-lua/h-lua)

local skill = hslk_ability({
    Name = "弹弹冰冰乐",
    Ubertip = hcolor.gold("弹弹~弹弹~弹弹~冰~"),
    Hotkey = "Q",
    _parent = "ANcl",
    DataA = { 0 },
    EffectArt = "",
    TargetArt = "",
    CasterArt = "",
    Cool = { 3 },
    DataB = { 1 },
    Cost = { 0 },
    DataD = { 0 },
    DataC = { 1 },
    Rng = { 1000 },
    DataF = { "channel" },
    targs = { "enemies" },
    DataE = { 0 },
})

hslk_unit({
    _parent = "Obla",
    Name = "剑圣",
    HP = 10000,
    abilList = string.implode(",", { skill._id }),
})

hslk_unit({
    _parent = "hpea",
    Name = "被刀的菜菜",
    HP = 10000,
    abilList = "",
    Builds = ""
})