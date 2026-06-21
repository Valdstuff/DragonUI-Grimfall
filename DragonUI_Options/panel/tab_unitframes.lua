--[[
================================================================================
DragonUI Options Panel - Unit Frames Tab
================================================================================
Player, target, focus, pet, party, ToT, ToF unit frame options.
Sub-tabs for each frame type.
================================================================================
]]

local addon = DragonUI
if not addon then return end

local L = addon.L
local LO = addon.LO
local C = addon.PanelControls
local Panel = addon.OptionsPanel

-- ============================================================================
-- SHARED VALUES
-- ============================================================================

local textFormatValues = {
    numeric    = LO["Current Value"],
    percentage = LO["Percentage"],
    both       = LO["Numbers + %"],
    formatted  = LO["Current / Max"],
}

local dragonValues = {
    none      = LO["None"],
    elite     = LO["Elite (Golden)"],
    rareelite = LO["RareElite (Winged)"],
}

local alternateManaFormatValues = {
    numeric    = LO["Current Value"],
    formatted  = LO["Current / Max"],
    percentage = LO["Percentage"],
    both       = LO["Percentage + Current/Max"],
}

local partyOrientationValues = {
    vertical   = LO["Vertical"],
    horizontal = LO["Horizontal"],
}

local function RefreshUnitFramesTabAfterToggle(refreshFunc)
    if refreshFunc then
        refreshFunc()
    end
    if Panel and Panel.SelectTab then
        Panel:SelectTab("unitframes")
    end
end

local function HandleClassPortraitToggle(unitKey, refreshFunc, enabled)
    if enabled then
        C:SetDBValue("unitframe." .. unitKey .. ".alternativeClassIcons", true)
    end
    RefreshUnitFramesTabAfterToggle(refreshFunc)
end

local function ResetDetachedFrameToDatabaseDefaults(unitKey, refreshFunc)
    local defaults = addon.defaults and addon.defaults.profile
    local profile = addon.db and addon.db.profile

    if not (defaults and profile and defaults.unitframe and defaults.unitframe[unitKey]) then
        RefreshUnitFramesTabAfterToggle(refreshFunc)
        return
    end

    local function CopyValue(value)
        if type(addon.DeepCopy) == "function" then
            return addon.DeepCopy(value)
        end
        if type(value) ~= "table" then
            return value
        end

        local copy = {}
        for k, v in pairs(value) do
            copy[k] = CopyValue(v)
        end
        return copy
    end

    profile.unitframe = profile.unitframe or {}
    profile.unitframe[unitKey] = CopyValue(defaults.unitframe[unitKey])

    if defaults.widgets and defaults.widgets[unitKey] then
        profile.widgets = profile.widgets or {}
        profile.widgets[unitKey] = CopyValue(defaults.widgets[unitKey])
    end

    RefreshUnitFramesTabAfterToggle(refreshFunc)
end

-- ============================================================================
-- ACTIVE SUB-TAB STATE
-- ============================================================================

local activeSubTab = "player"

local subTabs = {
    { key = "player",  label = LO["Player"] },
    { key = "target",  label = LO["Target"] },
    { key = "focus",   label = LO["Focus"] },
    { key = "pet",     label = LO["Pet"] },
    { key = "tot",     label = LO["ToT / ToF"] },
    { key = "party",   label = LO["Party"] },
}

-- ============================================================================
-- COMMON CONTROLS BUILDER
-- ============================================================================

local function AddCommonControls(parent, unitKey, refreshFunc, opts)
    opts = opts or {}

    C:AddSlider(parent, {
        label = LO["Scale"],
        dbPath = "unitframe." .. unitKey .. ".scale",
        min = 0.5, max = 2.0, step = 0.01,
        width = 200,
        callback = refreshFunc,
    })

    C:AddToggle(parent, {
        label = LO["Class Color Health"],
        dbPath = "unitframe." .. unitKey .. ".classcolor",
        callback = refreshFunc,
    })

    if opts.hasClassPortrait then
        C:AddToggle(parent, {
            label = LO["Class Portrait"],
            desc = LO["Class icon instead of 3D model for players."],
            dbPath = "unitframe." .. unitKey .. ".classPortrait",
            callback = function(value)
                HandleClassPortraitToggle(unitKey, refreshFunc, value)
            end,
        })

        C:AddToggle(parent, {
            label = LO["Alternative Class Icons"],
            desc = LO["Use DragonUI alternative class icons instead of Blizzard's class icon atlas."],
            dbPath = "unitframe." .. unitKey .. ".alternativeClassIcons",
            disabled = function()
                return not C:GetDBValue("unitframe." .. unitKey .. ".classPortrait")
            end,
            callback = refreshFunc,
        })
    end

    C:AddToggle(parent, {
        label = LO["Format Large Numbers"],
        dbPath = "unitframe." .. unitKey .. ".breakUpLargeNumbers",
        callback = refreshFunc,
    })

    C:AddDropdown(parent, {
        label = LO["Text Format"],
        dbPath = "unitframe." .. unitKey .. ".textFormat",
        values = textFormatValues,
        callback = refreshFunc,
    })

    C:AddToggle(parent, {
        label = LO["Always Show Health Text"],
        dbPath = "unitframe." .. unitKey .. ".showHealthTextAlways",
        callback = refreshFunc,
    })

    C:AddToggle(parent, {
        label = LO["Always Show Mana Text"],
        dbPath = "unitframe." .. unitKey .. ".showManaTextAlways",
        callback = refreshFunc,
    })

    if opts.hasThreatGlow then
        C:AddToggle(parent, {
            label = LO["Threat Glow"],
            dbPath = "unitframe." .. unitKey .. ".enableThreatGlow",
            callback = refreshFunc,
        })
    end
end

-- ============================================================================
-- SUB-TAB BUILDERS
-- ============================================================================

local function BuildPlayerSection(scroll)
    local refreshPlayer = function()
        if addon.PlayerFrame and addon.PlayerFrame.RefreshPlayerFrame then
            addon.PlayerFrame.RefreshPlayerFrame()
        end
    end

    local s = C:AddSection(scroll, LO["Player Frame"])
    AddCommonControls(s, "player", refreshPlayer, {
        hasClassPortrait = true,
    })

    C:AddDropdown(s, {
        label = LO["Dragon Decoration"],
        dbPath = "unitframe.player.dragon_decoration",
        values = dragonValues,
        callback = refreshPlayer,
    })

    -- Glow Effects
    C:AddHeading(s, LO["Glow Effects"])

    C:AddToggle(s, {
        label = LO["Show Rest Glow"],
        desc = LO["Golden glow around the player frame when resting (inn or city). Works with all frame modes."],
        dbPath = "unitframe.player.show_rest_glow",
        callback = refreshPlayer,
    })

    C:AddToggle(s, {
        label = LO["Show Combat Flash"],
        desc = LO["Pulsing glow effect when entering combat. Works with all frame modes."],
        dbPath = "unitframe.player.combat_flash_enabled",
        callback = function(val)
            refreshPlayer()
            Panel:SelectTab("unitframes")
        end,
    })

    C:AddSlider(s, {
        label = LO["Combat Flash Opacity"],
        desc = LO["Maximum opacity of the combat flash pulse effect."],
        dbPath = "unitframe.player.combat_flash_opacity",
        min = 0.1, max = 1.0, step = 0.05,
        width = 200,
        disabled = function()
            return not C:GetDBValue("unitframe.player.combat_flash_enabled")
        end,
        callback = refreshPlayer,
    })

    -- Alternate mana (druid)
    C:AddHeading(s, LO["Alternate Mana (Druid)"])

    C:AddToggle(s, {
        label = LO["Always Show"],
        desc = LO["Druid mana text visible at all times, not just on hover."],
        dbPath = "unitframe.player.alwaysShowAlternateManaText",
        callback = refreshPlayer,
    })

    C:AddDropdown(s, {
        label = LO["Text Format"],
        dbPath = "unitframe.player.alternateManaFormat",
        values = alternateManaFormatValues,
        callback = refreshPlayer,
    })

    -- Fat Health Bar
    C:AddHeading(s, LO["Fat Health Bar"])

    C:AddToggle(s, {
        label = LO["Enable"],
        desc = LO["Full-width health bar. Auto-disabled in vehicles."],
        dbPath = "unitframe.player.fat_healthbar",
        callback = function(val)
            refreshPlayer()
            -- Rebuild tab so disabled states on mana controls update
            Panel:SelectTab("unitframes")
        end,
    })

    C:AddToggle(s, {
        label = LO["Hide Mana Bar"],
        desc = LO["Completely hide the mana bar when Fat Health Bar is active."],
        dbPath = "unitframe.player.fat_manabar_hidden",
        disabled = function()
            return not C:GetDBValue("unitframe.player.fat_healthbar")
        end,
        callback = function(val)
            refreshPlayer()
            Panel:SelectTab("unitframes")
        end,
    })

    C:AddSlider(s, {
        label = LO["Mana Bar Width"],
        dbPath = "unitframe.player.fat_manabar_width",
        min = 50, max = 300, step = 1,
        width = 200,
        disabled = function()
            return not C:GetDBValue("unitframe.player.fat_healthbar")
        end,
        callback = refreshPlayer,
    })

    C:AddSlider(s, {
        label = LO["Mana Bar Height"],
        dbPath = "unitframe.player.fat_manabar_height",
        min = 4, max = 30, step = 1,
        width = 200,
        disabled = function()
            return not C:GetDBValue("unitframe.player.fat_healthbar")
        end,
        callback = refreshPlayer,
    })

    C:AddDropdown(s, {
        label = LO["Mana Bar Texture"],
        desc = LO["Choose the texture style for the power/mana bar. Only applies in Fat Health Bar mode."],
        dbPath = "unitframe.player.manabar_texture",
        values = {
            dragonui       = LO["DragonUI (Default)"],
            blizzard       = LO["Blizzard Classic"],
            blizzard_flat  = LO["Flat Solid"],
            smooth         = LO["Smooth"],
            aluminium      = LO["Aluminium"],
            litestep       = LO["LiteStep"],
        },
        disabled = function()
            return not C:GetDBValue("unitframe.player.fat_healthbar")
        end,
        callback = function()
            refreshPlayer()
            Panel:SelectTab("unitframes")
        end,
    })

    -- Power bar color pickers (only visible when using override textures in fat mode)
    local isFat = C:GetDBValue("unitframe.player.fat_healthbar")
    local texSetting = C:GetDBValue("unitframe.player.manabar_texture") or "dragonui"
    local showColors = isFat and texSetting ~= "dragonui"

    if showColors then
        C:AddHeading(s, LO["Power Bar Colors"])

        local powerColorEntries = {
            { key = "MANA",        label = LO["Mana"] },
            { key = "RAGE",        label = LO["Rage"] },
            { key = "ENERGY",      label = LO["Energy"] },
            { key = "FOCUS",       label = LO["Focus"] },
            { key = "RUNIC_POWER", label = LO["Runic Power"] },
            { key = "HAPPINESS",   label = LO["Happiness"] },
            { key = "RUNES",       label = LO["Runes"] },
        }

        for _, entry in ipairs(powerColorEntries) do
            C:AddColorPicker(s, {
                label = entry.label,
                dbPath = "unitframe.player.power_colors." .. entry.key,
                hasAlpha = false,
                callback = function() refreshPlayer() end,
            })
        end

        C:AddButton(s, {
            label = LO["Reset Colors to Default"],
            width = 200,
            callback = function()
                local defaults = {
                    MANA         = { r = 0.02, g = 0.32, b = 0.71 },
                    RAGE         = { r = 1.00, g = 0.00, b = 0.00 },
                    FOCUS        = { r = 1.00, g = 0.50, b = 0.25 },
                    ENERGY       = { r = 1.00, g = 1.00, b = 0.00 },
                    HAPPINESS    = { r = 0.00, g = 1.00, b = 1.00 },
                    RUNES        = { r = 0.50, g = 0.50, b = 0.50 },
                    RUNIC_POWER  = { r = 0.00, g = 0.82, b = 1.00 },
                }
                C:SetDBValue("unitframe.player.power_colors", defaults)
                refreshPlayer()
                Panel:SelectTab("unitframes")
            end,
        })
    end

    -- ========================================================================
    -- Classless Power Bars (Grimfall): energy + rage bar alignment, rune row
    -- ========================================================================
    local refreshClassless = function()
        if addon.ClasslessPowerBars and addon.ClasslessPowerBars.Refresh then
            addon.ClasslessPowerBars:Refresh()
        end
    end

    -- Toggle helper that defaults to ON when the saved value is missing.
    local function boolGet(path, default)
        return function()
            local v = C:GetDBValue(path)
            if v == nil then return default end
            return v
        end
    end

    C:AddHeading(s, "Classless Power Bars (Grimfall)")

    C:AddToggle(s, {
        label = "Enable",
        desc = "Align the energy and rage bars under the mana bar and move the death knight rune row beneath them.",
        getFunc = boolGet("unitframe.player.classless.enabled", true),
        setFunc = function(v) C:SetDBValue("unitframe.player.classless.enabled", v) end,
        callback = function()
            refreshClassless()
            Panel:SelectTab("unitframes")
        end,
    })

    C:AddToggle(s, {
        label = "Align Bars Under Mana",
        desc = "Glue the energy bar under the mana bar and the rage bar under the energy bar, matching width.",
        getFunc = boolGet("unitframe.player.classless.alignBars", true),
        setFunc = function(v) C:SetDBValue("unitframe.player.classless.alignBars", v) end,
        callback = refreshClassless,
    })

    C:AddSlider(s, {
        label = "Bar Gap",
        desc = "Vertical spacing between the stacked bars.",
        dbPath = "unitframe.player.classless.gap",
        default = 1, min = 0, max = 12, step = 1, width = 200,
        callback = refreshClassless,
    })

    C:AddSlider(s, {
        label = "Right Edge Inset",
        desc = "Trim the right edge of the energy and rage bars inward by this many pixels.",
        dbPath = "unitframe.player.classless.rightInset",
        default = 3, min = 0, max = 20, step = 1, width = 200,
        callback = refreshClassless,
    })

    C:AddSlider(s, {
        label = "Horizontal Offset",
        desc = "Slide the energy/rage stack (and runes) right by this many pixels.",
        dbPath = "unitframe.player.classless.offsetX",
        default = 3, min = -30, max = 30, step = 1, width = 200,
        callback = refreshClassless,
    })

    C:AddSlider(s, {
        label = "Vertical Offset",
        desc = "Slide the energy/rage stack (and runes) down by this many pixels.",
        dbPath = "unitframe.player.classless.offsetY",
        default = 3, min = -30, max = 30, step = 1, width = 200,
        callback = refreshClassless,
    })

    C:AddToggle(s, {
        label = "Move Death Knight Runes",
        desc = "Place the rune row directly beneath the rage bar instead of letting it overlap.",
        getFunc = boolGet("unitframe.player.classless.moveRunes", true),
        setFunc = function(v) C:SetDBValue("unitframe.player.classless.moveRunes", v) end,
        callback = refreshClassless,
    })

    C:AddSlider(s, {
        label = "Rune Row Gap",
        desc = "Vertical spacing between the rage bar and the rune row.",
        dbPath = "unitframe.player.classless.runeGap",
        default = 2, min = 0, max = 24, step = 1, width = 200,
        callback = refreshClassless,
    })

    C:AddSlider(s, {
        label = "Rune Row Horizontal Offset",
        desc = "Nudge the rune row left or right.",
        dbPath = "unitframe.player.classless.runeOffsetX",
        default = -3, min = -60, max = 60, step = 1, width = 200,
        callback = refreshClassless,
    })

    C:AddToggle(s, {
        label = "Empty Bar Background",
        desc = "Show a black backing behind the energy and rage bars so the empty portion is visible.",
        getFunc = boolGet("unitframe.player.classless.emptyBgEnabled", true),
        setFunc = function(v) C:SetDBValue("unitframe.player.classless.emptyBgEnabled", v) end,
        callback = refreshClassless,
    })

    C:AddSlider(s, {
        label = "Background Opacity",
        desc = "Opacity of the black backing behind the energy and rage bars.",
        dbPath = "unitframe.player.classless.emptyBgAlpha",
        default = 0.5, min = 0, max = 1, step = 0.05, width = 200,
        callback = refreshClassless,
    })

    -- Energy bar
    C:AddHeading(s, "Energy Bar")

    C:AddSlider(s, {
        label = "Energy Bar Height",
        desc = "Override the energy bar height. 0 keeps the client's default height.",
        dbPath = "unitframe.player.classless.energyHeight",
        default = 0, min = 0, max = 30, step = 1, width = 200,
        callback = refreshClassless,
    })

    C:AddToggle(s, {
        label = "Override Energy Color",
        desc = "Force a custom color on the energy bar.",
        dbPath = "unitframe.player.classless.energyColorEnabled",
        callback = function()
            refreshClassless()
            Panel:SelectTab("unitframes")
        end,
    })

    if C:GetDBValue("unitframe.player.classless.energyColorEnabled") then
        C:AddColorPicker(s, {
            label = "Energy Color",
            hasAlpha = false,
            getFunc = function()
                local v = C:GetDBValue("unitframe.player.classless.energyColor")
                if v then return v.r or 1, v.g or 0.85, v.b or 0 end
                return 1, 0.85, 0
            end,
            setFunc = function(r, g, b)
                C:SetDBValue("unitframe.player.classless.energyColor", { r = r, g = g, b = b })
            end,
            callback = refreshClassless,
        })
    end

    -- Rage bar
    C:AddHeading(s, "Rage Bar")

    C:AddSlider(s, {
        label = "Rage Bar Height",
        desc = "Override the rage bar height. 0 keeps the client's default height.",
        dbPath = "unitframe.player.classless.rageHeight",
        default = 0, min = 0, max = 30, step = 1, width = 200,
        callback = refreshClassless,
    })

    C:AddToggle(s, {
        label = "Override Rage Color",
        desc = "Force a custom color on the rage bar.",
        dbPath = "unitframe.player.classless.rageColorEnabled",
        callback = function()
            refreshClassless()
            Panel:SelectTab("unitframes")
        end,
    })

    if C:GetDBValue("unitframe.player.classless.rageColorEnabled") then
        C:AddColorPicker(s, {
            label = "Rage Color",
            hasAlpha = false,
            getFunc = function()
                local v = C:GetDBValue("unitframe.player.classless.rageColor")
                if v then return v.r or 0.85, v.g or 0.12, v.b or 0.12 end
                return 0.85, 0.12, 0.12
            end,
            setFunc = function(r, g, b)
                C:SetDBValue("unitframe.player.classless.rageColor", { r = r, g = g, b = b })
            end,
            callback = refreshClassless,
        })
    end

    -- Border
    C:AddHeading(s, "Border")

    C:AddToggle(s, {
        label = "Border Around Energy/Rage",
        desc = "Draw a metal frame and divider around the energy and rage bars to match the health/mana border.",
        getFunc = boolGet("unitframe.player.classless.borderEnabled", true),
        setFunc = function(v) C:SetDBValue("unitframe.player.classless.borderEnabled", v) end,
        callback = refreshClassless,
    })

    C:AddSlider(s, {
        label = "Border Thickness",
        desc = "Thickness of the border and divider lines.",
        dbPath = "unitframe.player.classless.borderThickness",
        default = 2, min = 1, max = 6, step = 1, width = 200,
        callback = refreshClassless,
    })

    C:AddColorPicker(s, {
        label = "Border Color",
        hasAlpha = false,
        getFunc = function()
            local v = C:GetDBValue("unitframe.player.classless.borderColor")
            if v then return v.r or 0, v.g or 0, v.b or 0 end
            return 0, 0, 0
        end,
        setFunc = function(r, g, b)
            C:SetDBValue("unitframe.player.classless.borderColor", { r = r, g = g, b = b })
        end,
        callback = refreshClassless,
    })
end

local function BuildTargetSection(scroll)
    local refreshTarget = function()
        if addon.TargetFrame and addon.TargetFrame.RefreshTargetFrame then
            addon.TargetFrame.RefreshTargetFrame()
        end
    end

    local s = C:AddSection(scroll, LO["Target Frame"])
    AddCommonControls(s, "target", refreshTarget, {
        hasClassPortrait = true,
    })

    C:AddToggle(s, {
        label = LO["Show Name Background"],
        desc = LO["Show the colored name background behind the target name."],
        dbPath = "unitframe.target.show_name_background",
        callback = refreshTarget,
    })

    C:AddToggle(s, {
        label = "Show Threat Glow",
        desc = "Red aggro glow around the target frame when you have threat. Turn off to hide it.",
        getFunc = function()
            local v = C:GetDBValue("unitframe.target.enableThreatGlow")
            if v == nil then return true end
            return v
        end,
        setFunc = function(v) C:SetDBValue("unitframe.target.enableThreatGlow", v) end,
        callback = function()
            if addon.RefreshTargetThreatGlow then addon.RefreshTargetThreatGlow() end
        end,
    })
end

local function BuildFocusSection(scroll)
    local refreshFocus = function()
        if addon.RefreshFocusFrame then addon.RefreshFocusFrame() end
    end

    local s = C:AddSection(scroll, LO["Focus Frame"])
    AddCommonControls(s, "focus", refreshFocus, {
        hasClassPortrait = true,
    })

    C:AddToggle(s, {
        label = LO["Show Name Background"],
        desc = LO["Show the colored name background behind the focus name."],
        dbPath = "unitframe.focus.show_name_background",
        callback = refreshFocus,
    })

    C:AddToggle(s, {
        label = LO["Show Buff/Debuff on Focus"],
        desc = LO["Uses the native large focus frame mode to show buffs and debuffs on the focus frame."],
        dbPath = "unitframe.focus.show_buff_debuff",
        callback = refreshFocus,
    })
end

local function BuildPetSection(scroll)
    local refreshPet = function()
        if addon.RefreshPetFrame then addon.RefreshPetFrame() end
    end

    local s = C:AddSection(scroll, LO["Pet Frame"])

    C:AddSlider(s, {
        label = LO["Scale"],
        dbPath = "unitframe.pet.scale",
        min = 0.5, max = 2.0, step = 0.01,
        width = 200,
        callback = refreshPet,
    })

    C:AddDropdown(s, {
        label = LO["Text Format"],
        dbPath = "unitframe.pet.textFormat",
        values = textFormatValues,
        callback = refreshPet,
    })

    C:AddToggle(s, {
        label = LO["Format Large Numbers"],
        dbPath = "unitframe.pet.breakUpLargeNumbers",
        callback = refreshPet,
    })

    C:AddToggle(s, {
        label = LO["Always Show Health Text"],
        dbPath = "unitframe.pet.showHealthTextAlways",
        callback = refreshPet,
    })

    C:AddToggle(s, {
        label = LO["Always Show Mana Text"],
        dbPath = "unitframe.pet.showManaTextAlways",
        callback = refreshPet,
    })

    C:AddToggle(s, {
        label = LO["Threat Glow"],
        dbPath = "unitframe.pet.enableThreatGlow",
        callback = refreshPet,
    })

    C:AddHeading(s, LO["Position"])

    C:AddToggle(s, {
        label = LO["Override Position"],
        desc = LO["Move the pet frame independently from the player frame."],
        dbPath = "unitframe.pet.override",
        callback = refreshPet,
    })

    C:AddSlider(s, {
        label = LO["X Position"],
        dbPath = "unitframe.pet.x",
        min = -2500, max = 2500, step = 1,
        width = 200,
        disabled = function()
            return not C:GetDBValue("unitframe.pet.override")
        end,
        callback = refreshPet,
    })

    C:AddSlider(s, {
        label = LO["Y Position"],
        dbPath = "unitframe.pet.y",
        min = -2500, max = 2500, step = 1,
        width = 200,
        disabled = function()
            return not C:GetDBValue("unitframe.pet.override")
        end,
        callback = refreshPet,
    })
end

local function BuildToTSection(scroll)
    local refreshToT = function()
        if addon.TargetOfTarget and addon.TargetOfTarget.RefreshToTFrame then
            addon.TargetOfTarget.RefreshToTFrame()
        end
    end

    local tot = C:AddSection(scroll, LO["Target of Target"])
    C:AddDescription(tot,
        LO["Follows the Target frame by default. Move it in Editor Mode (/dragonui edit) to detach and position freely."])

    C:AddSlider(tot, {
        label = LO["Scale"],
        dbPath = "unitframe.tot.scale",
        min = 0.5, max = 2.0, step = 0.01,
        width = 200,
        callback = refreshToT,
    })

    C:AddToggle(tot, {
        label = LO["Class Color Health"],
        dbPath = "unitframe.tot.classcolor",
        callback = refreshToT,
    })

    C:AddToggle(tot, {
        label = LO["Class Portrait"],
        dbPath = "unitframe.tot.classPortrait",
        callback = function(value)
            HandleClassPortraitToggle("tot", refreshToT, value)
        end,
    })

    C:AddToggle(tot, {
        label = LO["Alternative Class Icons"],
        desc = LO["Use DragonUI alternative class icons instead of Blizzard's class icon atlas."],
        dbPath = "unitframe.tot.alternativeClassIcons",
        disabled = function()
            return not C:GetDBValue("unitframe.tot.classPortrait")
        end,
        callback = refreshToT,
    })

    -- Attachment status indicator
    local totOverride = C:GetDBValue("unitframe.tot.override")
    if totOverride then
        C:AddDescription(tot, "|cff1784d1- " .. LO["Detached — positioned freely via Editor Mode"] .. "|r")
    else
        C:AddDescription(tot, "|cffaaaaaa- " .. LO["Attached — follows Target frame"] .. "|r")
    end

    -- Re-attach button (only useful when detached)
    C:AddButton(tot, {
        label = LO["Re-attach to Target"],
        width = 200,
        disabled = function() return not C:GetDBValue("unitframe.tot.override") end,
        callback = function()
            ResetDetachedFrameToDatabaseDefaults("tot", refreshToT)
        end,
    })

    -- ====================================================================
    -- Target of Focus
    -- ====================================================================
    local refreshToF = function()
        if addon.TargetOfFocus and addon.TargetOfFocus.RefreshToFFrame then
            addon.TargetOfFocus.RefreshToFFrame()
        end
    end

    local fot = C:AddSection(scroll, LO["Target of Focus"])
    C:AddDescription(fot,
        LO["Follows the Focus frame by default. Move it in Editor Mode (/dragonui edit) to detach and position freely."])

    C:AddSlider(fot, {
        label = LO["Scale"],
        dbPath = "unitframe.fot.scale",
        min = 0.5, max = 2.0, step = 0.01,
        width = 200,
        callback = refreshToF,
    })

    C:AddToggle(fot, {
        label = LO["Class Color Health"],
        dbPath = "unitframe.fot.classcolor",
        callback = refreshToF,
    })

    C:AddToggle(fot, {
        label = LO["Class Portrait"],
        dbPath = "unitframe.fot.classPortrait",
        callback = function(value)
            HandleClassPortraitToggle("fot", refreshToF, value)
        end,
    })

    C:AddToggle(fot, {
        label = LO["Alternative Class Icons"],
        desc = LO["Use DragonUI alternative class icons instead of Blizzard's class icon atlas."],
        dbPath = "unitframe.fot.alternativeClassIcons",
        disabled = function()
            return not C:GetDBValue("unitframe.fot.classPortrait")
        end,
        callback = refreshToF,
    })

    -- Attachment status indicator
    local fotOverride = C:GetDBValue("unitframe.fot.override")
    if fotOverride then
        C:AddDescription(fot, "|cff1784d1- " .. LO["Detached — positioned freely via Editor Mode"] .. "|r")
    else
        C:AddDescription(fot, "|cffaaaaaa- " .. LO["Attached — follows Focus frame"] .. "|r")
    end

    -- Re-attach button (only useful when detached)
    C:AddButton(fot, {
        label = LO["Re-attach to Focus"],
        width = 200,
        disabled = function() return not C:GetDBValue("unitframe.fot.override") end,
        callback = function()
            ResetDetachedFrameToDatabaseDefaults("fot", refreshToF)
        end,
    })
end

local function BuildPartySection(scroll)
    local refreshParty = function()
        if addon.RefreshPartyFrames then addon.RefreshPartyFrames() end
    end

    local s = C:AddSection(scroll, LO["Party Frames"])

    C:AddSlider(s, {
        label = LO["Scale"],
        dbPath = "unitframe.party.scale",
        min = 0.5, max = 2.0, step = 0.01,
        width = 200,
        callback = refreshParty,
    })

    C:AddToggle(s, {
        label = LO["Class Color Health"],
        dbPath = "unitframe.party.classcolor",
        callback = refreshParty,
    })

    C:AddToggle(s, {
        label = LO["Format Large Numbers"],
        dbPath = "unitframe.party.breakUpLargeNumbers",
        callback = refreshParty,
    })

    C:AddToggle(s, {
        label = LO["Always Show Health Text"],
        dbPath = "unitframe.party.showHealthTextAlways",
        callback = refreshParty,
    })

    C:AddToggle(s, {
        label = LO["Always Show Mana Text"],
        dbPath = "unitframe.party.showManaTextAlways",
        callback = refreshParty,
    })

    C:AddDropdown(s, {
        label = LO["Text Format"],
        dbPath = "unitframe.party.textFormat",
        values = textFormatValues,
        callback = refreshParty,
    })

    C:AddDropdown(s, {
        label = LO["Orientation"],
        dbPath = "unitframe.party.orientation",
        values = partyOrientationValues,
        callback = refreshParty,
    })

    C:AddSlider(s, {
        label = LO["Vertical Padding"],
        desc = LO["Space between party frames in vertical mode."],
        dbPath = "unitframe.party.padding_vertical",
        min = 10, max = 150, step = 1,
        width = 200,
        callback = refreshParty,
    })

    C:AddSlider(s, {
        label = LO["Horizontal Padding"],
        desc = LO["Space between party frames in horizontal mode."],
        dbPath = "unitframe.party.padding_horizontal",
        min = 10, max = 150, step = 1,
        width = 200,
        callback = refreshParty,
    })
end

-- ============================================================================
-- SUB-TAB DISPATCH
-- ============================================================================

local subTabBuilders = {
    player = BuildPlayerSection,
    target = BuildTargetSection,
    focus  = BuildFocusSection,
    pet    = BuildPetSection,
    tot    = BuildToTSection,
    party  = BuildPartySection,
}

-- ============================================================================
-- MAIN TAB BUILDER
-- ============================================================================

local function BuildUnitframesTab(scroll)
    C:AddSubTabs(scroll, subTabs, activeSubTab, function(key)
        activeSubTab = key
        Panel:SelectTab("unitframes")
    end)

    local builder = subTabBuilders[activeSubTab]
    if builder then
        builder(scroll)
    end
end

-- Register the tab
Panel:RegisterTab("unitframes", LO["Unit Frames"], BuildUnitframesTab, 6)
