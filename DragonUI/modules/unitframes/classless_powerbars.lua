local addon = select(2, ...)
local _G = getfenv(0)

-- ============================================================================
-- CLASSLESS SECONDARY POWER BARS (Grimfall)
-- ----------------------------------------------------------------------------
-- The Grimfall classless client injects two custom StatusBars onto the
-- PlayerFrame:
--     PlayerFrameClasslessEnergyBar
--     PlayerFrameClasslessRageBar
-- Both are anchored to PlayerFrame (not to the mana bar), so they do not line
-- up with the mana bar above them, and they collide with the death knight rune
-- row (RuneButtonIndividual1..6).
--
-- This module:
--   1. Re-anchors the energy bar flush under the mana bar (same left edge and
--      width via the two-corner trick).
--   2. Re-anchors the native rage bar flush under the energy bar.
--   3. Moves the death knight rune row beneath the rage bar.
--   4. Optionally overrides the energy / rage bar colours and heights.
--   5. Keeps everything aligned even when DragonUI or the client re-positions
--      the bars (fat mana bar, vehicle UI, form changes, value updates).
--
-- All behaviour is driven by config stored in
--     DragonUIDB.profile.unitframe.player.classless
-- which the DragonUI options panel writes to. Changes apply live via Refresh().
-- ============================================================================

local UPDATE_INTERVAL = 0.1

-- Config defaults (used when the saved value is missing).
local DEFAULTS = {
    enabled            = true,
    alignBars          = true,   -- glue energy under mana, rage under energy
    gap                = 1,      -- vertical gap between stacked bars
    offsetX            = 3,      -- slide the energy/rage stack right by N px
    offsetY            = 3,      -- slide the energy/rage stack down by N px
    rightInset         = 3,      -- trim the right edge of energy/rage by N px
    moveRunes          = true,   -- move the DK rune row under the rage bar
    runeGap            = 2,      -- vertical gap between the rage bar and runes
    runeOffsetX        = -3,     -- horizontal nudge for the rune row
    emptyBgEnabled     = true,   -- black backing behind the energy/rage bars
    emptyBgAlpha       = 0.5,    -- backing opacity (0 = clear, 1 = solid)
    energyHeight       = 0,      -- 0 = keep the client's native height
    rageHeight         = 0,      -- 0 = keep the client's native height
    matchManaHeight    = true,   -- size energy/rage bars to the mana bar's height
    roundedCorners     = true,   -- use DragonUI's rounded DF power-bar textures
    energyColorEnabled = false,
    energyColor        = { r = 1.00, g = 0.85, b = 0.00 },
    rageColorEnabled   = false,
    rageColor          = { r = 0.85, g = 0.12, b = 0.12 },
    borderEnabled      = true,                       -- frame around energy+rage
    borderThickness    = 2,
    borderColor        = { r = 0.00, g = 0.00, b = 0.00 },
}

local M = {
    setupDone = false,
    hooksInstalled = false,
    applying = false,
}

-- ----------------------------------------------------------------------------
-- Config access: read a single key from the saved profile, falling back to the
-- module default if it isn't set yet.
-- ----------------------------------------------------------------------------
local function cfg(key)
    local p = addon.db and addon.db.profile
    local c = p and p.unitframe and p.unitframe.player and p.unitframe.player.classless
    local v = c and c[key]
    if v == nil then
        return DEFAULTS[key]
    end
    return v
end

-- ----------------------------------------------------------------------------
-- Position the energy bar under the mana bar, the rage bar under the energy
-- bar, and the rune row under the rage bar.
-- ----------------------------------------------------------------------------
local function ReanchorBars()
    if M.applying then return end
    if not cfg("enabled") or not cfg("alignBars") then return end

    local manaBar = _G.PlayerFrameManaBar
    if not manaBar then return end

    M.applying = true

    local gap = cfg("gap") or 0
    local inset = cfg("rightInset") or 0
    local ox = cfg("offsetX") or 0
    local oy = cfg("offsetY") or 0
    local energyBar = _G.PlayerFrameClasslessEnergyBar
    local rageBar = _G.PlayerFrameClasslessRageBar

    -- Mana bar height, used when matchManaHeight is enabled. An explicit
    -- energyHeight / rageHeight (> 0) still wins over the auto-match.
    local manaH = manaBar:GetHeight()

    -- Energy bar: top corners pinned to the mana bar's bottom corners, slid by
    -- (offsetX, -offsetY) and with the right edge trimmed in by `inset` pixels.
    if energyBar then
        energyBar:ClearAllPoints()
        energyBar:SetPoint("TOPLEFT", manaBar, "BOTTOMLEFT", ox, -gap - oy)
        energyBar:SetPoint("TOPRIGHT", manaBar, "BOTTOMRIGHT", ox - inset, -gap - oy)
        local eh = cfg("energyHeight")
        if eh and eh > 0 then
            energyBar:SetHeight(eh)
        elseif cfg("matchManaHeight") and manaH and manaH > 0 then
            energyBar:SetHeight(manaH)
        end
    end

    -- Rage bar: top corners pinned to the bar above it (energy if present). When
    -- anchored to the energy bar the offset/inset are already inherited, so only
    -- apply them when anchoring directly to the (full-width) mana bar.
    local aboveRage = energyBar or manaBar
    if rageBar then
        local rageLeft  = energyBar and 0 or ox
        local rageRight = energyBar and 0 or (ox - inset)
        local rageDown  = energyBar and gap or (gap + oy)
        rageBar:ClearAllPoints()
        rageBar:SetPoint("TOPLEFT", aboveRage, "BOTTOMLEFT", rageLeft, -rageDown)
        rageBar:SetPoint("TOPRIGHT", aboveRage, "BOTTOMRIGHT", rageRight, -rageDown)
        local rh = cfg("rageHeight")
        if rh and rh > 0 then
            rageBar:SetHeight(rh)
        elseif cfg("matchManaHeight") and manaH and manaH > 0 then
            rageBar:SetHeight(manaH)
        end
    end

    -- Death knight rune row: the buttons are chained to each other, so moving
    -- RuneButtonIndividual1 drags the whole row.
    if cfg("moveRunes") then
        local aboveRune = rageBar or energyBar or manaBar
        local rune1 = _G.RuneButtonIndividual1
        if rune1 then
            rune1:ClearAllPoints()
            rune1:SetPoint("TOPLEFT", aboveRune, "BOTTOMLEFT", cfg("runeOffsetX") or 0, -(cfg("runeGap") or 0))
        end
    end

    M.applying = false
end

-- ----------------------------------------------------------------------------
-- Optional colour overrides for the native energy / rage bars.
-- ----------------------------------------------------------------------------
local function ApplyColors()
    if not cfg("enabled") then return end

    if cfg("energyColorEnabled") then
        local e = _G.PlayerFrameClasslessEnergyBar
        if e and e.SetStatusBarColor then
            local c = cfg("energyColor") or DEFAULTS.energyColor
            e:SetStatusBarColor(c.r or c[1] or 1, c.g or c[2] or 1, c.b or c[3] or 0)
        end
    end

    if cfg("rageColorEnabled") then
        local r = _G.PlayerFrameClasslessRageBar
        if r and r.SetStatusBarColor then
            local c = cfg("rageColor") or DEFAULTS.rageColor
            r:SetStatusBarColor(c.r or c[1] or 1, c.g or c[2] or 0, c.b or c[3] or 0)
        end
    end
end

-- ----------------------------------------------------------------------------
-- Rounded corners: swap the native energy / rage bar fills for DragonUI's
-- DragonFlight power-bar textures (the same rounded-rectangle fills used by the
-- mana bar above), so the secondary bars match the mana bar's look. True corner
-- masking isn't available on 3.3.5a StatusBars, so matching the bar texture is
-- the closest equivalent. The DragonUI textures bake their colour in, so the
-- bar is tinted white to let it show (unless a custom colour override is on).
-- ----------------------------------------------------------------------------
local function ApplyTextures()
    if not cfg("enabled") or not cfg("roundedCorners") then return end

    local tex = addon.UF and addon.UF.TEXTURES and addon.UF.TEXTURES.player
        and addon.UF.TEXTURES.player.POWER_BARS
    if not tex then return end

    local e = _G.PlayerFrameClasslessEnergyBar
    if e and e.SetStatusBarTexture and tex.ENERGY then
        e:SetStatusBarTexture(tex.ENERGY)
        if not cfg("energyColorEnabled") and e.SetStatusBarColor then
            e:SetStatusBarColor(1, 1, 1)
        end
    end

    local r = _G.PlayerFrameClasslessRageBar
    if r and r.SetStatusBarTexture and tex.RAGE then
        r:SetStatusBarTexture(tex.RAGE)
        if not cfg("rageColorEnabled") and r.SetStatusBarColor then
            r:SetStatusBarColor(1, 1, 1)
        end
    end
end

-- ----------------------------------------------------------------------------
-- Black backing behind the energy / rage bars so the empty portion reads as a
-- bar instead of being transparent.
-- ----------------------------------------------------------------------------
local function ApplyBackgrounds()
    local function setup(bar, key)
        if not bar then return end
        if not M[key] then
            M[key] = bar:CreateTexture(nil, "BACKGROUND")
        end
        local tex = M[key]
        if cfg("enabled") and cfg("emptyBgEnabled") then
            tex:SetAllPoints(bar)
            tex:SetTexture(0, 0, 0, cfg("emptyBgAlpha") or 0.5)
            tex:Show()
        else
            tex:Hide()
        end
    end
    setup(_G.PlayerFrameClasslessEnergyBar, "energyBG")
    setup(_G.PlayerFrameClasslessRageBar, "rageBG")
end

-- ----------------------------------------------------------------------------
-- Metal frame + divider around the energy / rage bars, to match the silver
-- border that DragonUI draws around the health / mana bars (that border is a
-- fixed-shape texture and can't be stretched, so we draw our own to match).
-- ----------------------------------------------------------------------------
local function ApplySkin()
    local energyBar = _G.PlayerFrameClasslessEnergyBar
    local rageBar = _G.PlayerFrameClasslessRageBar
    if not energyBar and not rageBar then return end

    if not cfg("enabled") or not cfg("borderEnabled") then
        if M.skin then M.skin:Hide() end
        return
    end

    -- Create the skin frame + divider texture once.
    if not M.skin then
        M.skin = CreateFrame("Frame", "DragonUIClasslessBarSkin", PlayerFrame)
        M.skinDivider = M.skin:CreateTexture(nil, "OVERLAY")
    end

    local f = M.skin
    local t = cfg("borderThickness") or 2
    if t < 1 then t = 1 end
    local c = cfg("borderColor") or DEFAULTS.borderColor
    local cr, cg, cb = c.r or 0.62, c.g or 0.62, c.b or 0.64

    local topAnchor = energyBar or rageBar
    local bottomAnchor = rageBar or energyBar

    f:ClearAllPoints()
    f:SetPoint("TOPLEFT", topAnchor, "TOPLEFT", -t, t)
    f:SetPoint("BOTTOMRIGHT", bottomAnchor, "BOTTOMRIGHT", t, -t)
    f:SetFrameLevel(bottomAnchor:GetFrameLevel() + 1)
    f:SetBackdrop({ edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = t })
    f:SetBackdropBorderColor(cr, cg, cb, 1)
    f:Show()

    -- Divider between the energy and rage bars (only when both exist).
    local d = M.skinDivider
    if energyBar and rageBar then
        d:ClearAllPoints()
        d:SetPoint("TOPLEFT", rageBar, "TOPLEFT", 0, math.floor(t / 2 + 0.5))
        d:SetPoint("TOPRIGHT", rageBar, "TOPRIGHT", 0, math.floor(t / 2 + 0.5))
        d:SetHeight(t)
        d:SetTexture(cr, cg, cb, 1)
        d:Show()
    else
        d:Hide()
    end
end

-- ----------------------------------------------------------------------------
-- Self-healing: the client re-anchors its bars (and the rune row) during load
-- and on certain updates. If we detect drift from our layout, re-apply it.
-- ----------------------------------------------------------------------------
local function EnsureAnchored()
    if not cfg("enabled") or not cfg("alignBars") then return end

    local manaBar = _G.PlayerFrameManaBar
    if not manaBar then return end

    local energyBar = _G.PlayerFrameClasslessEnergyBar
    local rageBar = _G.PlayerFrameClasslessRageBar
    local need = false

    if energyBar then
        local _, relTo = energyBar:GetPoint()
        if relTo ~= manaBar then need = true end
    end
    if not need and rageBar then
        local want = energyBar or manaBar
        local _, relTo = rageBar:GetPoint()
        if relTo ~= want then need = true end
    end
    if not need and cfg("moveRunes") then
        local rune1 = _G.RuneButtonIndividual1
        if rune1 then
            local want = rageBar or energyBar or manaBar
            local _, relTo = rune1:GetPoint()
            if relTo ~= want then need = true end
        end
    end

    if need then ReanchorBars() end
end

-- ----------------------------------------------------------------------------
-- Hook the relevant bars so our layout survives them being repositioned.
-- ----------------------------------------------------------------------------
local function InstallHooks()
    if M.hooksInstalled then return end

    local manaBar = _G.PlayerFrameManaBar
    if not manaBar then return end

    hooksecurefunc(manaBar, "SetPoint", function()
        if not M.applying then ReanchorBars() end
    end)

    local energyBar = _G.PlayerFrameClasslessEnergyBar
    if energyBar then
        hooksecurefunc(energyBar, "SetPoint", function()
            if not M.applying then ReanchorBars() end
        end)
    end

    local rageBar = _G.PlayerFrameClasslessRageBar
    if rageBar then
        hooksecurefunc(rageBar, "SetPoint", function()
            if not M.applying then ReanchorBars() end
        end)
    end

    M.hooksInstalled = true
end

-- ----------------------------------------------------------------------------
-- One-time setup. Retries via OnUpdate until the client's classless bars exist.
-- ----------------------------------------------------------------------------
local function TrySetup()
    if M.setupDone then return end
    if not _G.PlayerFrameManaBar then return end

    -- Wait until at least one of the classless bars has been created.
    if not _G.PlayerFrameClasslessEnergyBar and not _G.PlayerFrameClasslessRageBar then
        return
    end

    InstallHooks()
    ReanchorBars()
    ApplyTextures()
    ApplyColors()
    ApplyBackgrounds()
    ApplySkin()
    M.setupDone = true
end

-- ----------------------------------------------------------------------------
-- Driver frame.
-- ----------------------------------------------------------------------------
local driver = CreateFrame("Frame")
driver:RegisterEvent("PLAYER_LOGIN")
driver:RegisterEvent("PLAYER_ENTERING_WORLD")
driver:RegisterEvent("UNIT_DISPLAYPOWER")
driver:RegisterEvent("UPDATE_SHAPESHIFT_FORM")

driver:SetScript("OnEvent", function(self, event, unit)
    if event == "UNIT_DISPLAYPOWER" and unit ~= "player" then return end
    TrySetup()
    ReanchorBars()
    ApplyTextures()
    ApplyColors()
    ApplyBackgrounds()
    ApplySkin()
end)

local accum = 0
driver:SetScript("OnUpdate", function(self, elapsed)
    accum = accum + elapsed
    if accum < UPDATE_INTERVAL then return end
    accum = 0

    if not M.setupDone then
        TrySetup()
    else
        EnsureAnchored()
        ApplyColors()
    end
end)

-- ----------------------------------------------------------------------------
-- Public API: the options panel calls this to apply changes immediately.
-- ----------------------------------------------------------------------------
function M:Refresh()
    if not M.setupDone then TrySetup() end
    ReanchorBars()
    ApplyTextures()
    ApplyColors()
    ApplyBackgrounds()
    ApplySkin()
end

M.defaults = DEFAULTS
addon.ClasslessPowerBars = M
