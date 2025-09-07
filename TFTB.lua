--[[
  TFTB.lua
  Thanks For The Buff – v1.1 (WoW 3.3.5a / Project Epoch)

  Automatically thanks other players for utility buffs applied to you.

  Features:
    • Auto–switch to ID-only mode once all keywords are learned
    • Treat SPELL_AURA_REFRESH as a re-apply
    • Handle SPELL_AURA_REMOVED to clear cooldowns on buff expiration
    • /tftb list to dump learned spellIDs
    • Reuse recentBuffs table for performance
    • Clear lastThanks on login/reload to avoid re-thanking old buffs
    • Configurable ignore window after login/reload to skip inherited buffs
    • Welcome message on load (only once per login/reload)
--]]

local addonName = "TFTB"
local TFTB = {}
_G[addonName] = TFTB

-- Cache WoW API and Lua functions
local GetTime         = GetTime
local UnitGUID        = UnitGUID
local IsInInstance    = IsInInstance
local SendChatMessage = SendChatMessage
local DoEmote         = DoEmote
local bit_band        = bit.band
local strlower        = string.lower
local strfind         = string.find
local gsub            = string.gsub
local tremove         = table.remove
local ipairs          = ipairs
local pairs           = pairs
local format          = string.format

-- Combat log flags
local PLAYER_FLAG       = 0x00000400
local AFFILIATION_PARTY = 0x00000002
local AFFILIATION_RAID  = 0x00000004

-- Runtime state
local inCombat    = false
local instanceOK  = true
local recentBuffs = {}
local loginTime   = 0 -- timestamp when player enters world

-- Keywords for initial filtering
local keywords = {
  "fortitude","spirit","mark","wild","intellect","brilliance",
  "shadow protection","thorns","unending breath","detect invisibility",
  "demon armor","fel armor","might","kings","wisdom","blessing",
  "motw","arcane","ai","divine spirit","gift of the wild",
  "power word: fortitude","blessing of might","blessing of wisdom",
  "blessing of kings",
}
local keywordThreshold = #keywords

-- Thank messages
local thankMessages = {
  "You're awesome, %player%! Thanks for the buff!",
  "Much appreciated, %player%! You rock!",
  "Great buff! Thanks a ton, %player%!",
  "Cheers for the buff, %player%! You're the best!",
  "Buff received! Huge thanks, %player%!",
  "Thanks for the boost, %player%! You're amazing!",
  "You just made my day, %player%! Thanks!",
  "Thanks a million, %player%! This buff rocks!",
  "Couldn't have asked for better, %player%! Thanks!",
  "Grateful for the buff, %player%! You're the MVP!"
}

-- Emotes
local thankEmotes = {
  "thank","wave","bow","cheer","applause",
  "smile","salute","point","flex",
  "kiss","wink","hug","roar","clap"
}

-- Defaults
local defaults = {
  cooldown      = 30,
  mergeWindow   = 3,
  whisper       = true,
  emotes        = true,
  debug         = false,
  learnedSpells = {},
  lastThanks    = {},
  idOnlyMode    = false,
  ignoreWindow  = 3, -- seconds to ignore buffs after login/reload
}

-- Print helpers
local function Print(msg, r,g,b)
  DEFAULT_CHAT_FRAME:AddMessage("|cffFF69B4["..addonName.."]|r "..msg,
    r or 1, g or 0.8, b or 0.8)
end
local function DPrint(msg)
  if TFTB_DB and TFTB_DB.debug then
    Print("|cffffff00[DEBUG]|r "..msg)
  end
end

-- Init DB
local function InitDB()
  if not TFTB_DB then TFTB_DB = {} end
  for k,v in pairs(defaults) do
    if TFTB_DB[k] == nil then
      if type(v) == "table" then
        TFTB_DB[k] = {}
        for kk,vv in pairs(v) do TFTB_DB[k][kk] = vv end
      else
        TFTB_DB[k] = v
      end
    end
  end
end

-- Clean buff name
local function CleanName(name)
  name = strlower(name or "")
  name = gsub(name, "%s*%b()", "")
  name = gsub(name, "^[^']+'s%s+", "")
  return gsub(name, "%s+$", "")
end

-- Keyword match
local function IsKeyword(name)
  local clean = CleanName(name)
  for _,kw in ipairs(keywords) do
    if strfind(clean, kw, 1, true) then
      return true
    end
  end
  return false
end

-- Thank player
local function ThankPlayer(player)
  if TFTB_DB.whisper then
    local msg = thankMessages[math.random(#thankMessages)]
    msg = gsub(msg, "%%player%%", player)
    SendChatMessage(msg, "WHISPER", nil, player)
  end
  if TFTB_DB.emotes then
    local em = thankEmotes[math.random(#thankEmotes)]
    DoEmote(em, player)
  end
end

-- Wipe recent buffs
local function WipeRecent()
  for i=1,#recentBuffs do recentBuffs[i] = nil end
end
-- Main event frame
local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_ENTERING_WORLD")
f:RegisterEvent("ZONE_CHANGED_NEW_AREA")
f:RegisterEvent("PLAYER_REGEN_DISABLED")
f:RegisterEvent("PLAYER_REGEN_ENABLED")
f:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")

f:SetScript("OnEvent", function(_, event, ...)
  -- On login or /reload
  if event == "PLAYER_ENTERING_WORLD" then
    InitDB()
    -- Clear cooldowns to avoid re-thanking old buffs
    TFTB_DB.lastThanks = {}
    -- Save login timestamp for ignore window
    loginTime = GetTime()
    local inInst = select(1, IsInInstance())
    instanceOK = not inInst
    DPrint("Zone/instance check → instanceOK="..tostring(instanceOK))
    DPrint("Ignore window active for "..TFTB_DB.ignoreWindow.." seconds")

    -- Welcome message only once per login/reload
    Print("|cff00ff00TFTB loaded successfully!|r Type |cffffff00/tftb|r for help.")
    return
  end

  -- On zone change (update instance status, no welcome message)
  if event == "ZONE_CHANGED_NEW_AREA" then
    local inInst = select(1, IsInInstance())
    instanceOK = not inInst
    DPrint("Zone/instance check → instanceOK="..tostring(instanceOK))
    return
  end

  -- Track combat state
  if event == "PLAYER_REGEN_DISABLED" then
    inCombat = true; DPrint("Entered combat")
    return
  elseif event == "PLAYER_REGEN_ENABLED" then
    inCombat = false; DPrint("Left combat")
    return
  end

  -- Process combat log entries
  if event == "COMBAT_LOG_EVENT_UNFILTERED" then
    -- Ignore buffs during the configured ignore window after login/reload
    if GetTime() - loginTime < TFTB_DB.ignoreWindow then
      DPrint("Ignoring buff due to login ignore window")
      return
    end

    if inCombat or not instanceOK then return end

    local ts, subEvent,
          srcGUID, srcName, srcFlags,
          dstGUID, dstName, dstFlags,
          spellID, spellName, school, auraType = ...
    -- Handle buff expiration
    if subEvent == "SPELL_AURA_REMOVED" and auraType == "BUFF"
       and dstGUID == UnitGUID("player") then
      DPrint("BUFF removed → clearing cooldown for spellID "..tostring(spellID))
      for casterGUID, spells in pairs(TFTB_DB.lastThanks) do
        spells[spellID] = nil
      end
      return
    end

    -- Treat refresh as re-apply
    if subEvent == "SPELL_AURA_REFRESH" then
      subEvent = "SPELL_AURA_APPLIED"
      DPrint("SPELL_AURA_REFRESH treated like APPLIED for "..tostring(spellName))
    end

    if subEvent ~= "SPELL_AURA_APPLIED" or auraType ~= "BUFF" then return end
    if dstGUID ~= UnitGUID("player") then return end

    DPrint(format("BUFF detected → %s [%s] by %s [%s]",
      tostring(spellName), tostring(spellID),
      tostring(srcName), tostring(srcGUID)
    ))

    if not srcFlags or bit_band(srcFlags, PLAYER_FLAG) == 0 then
      DPrint("Discard: source not a player"); return
    end
    if srcGUID == UnitGUID("player") then
      DPrint("Discard: self-buff"); return
    end
    if bit_band(srcFlags, AFFILIATION_PARTY) ~= 0
    or bit_band(srcFlags, AFFILIATION_RAID)  ~= 0 then
      DPrint("Discard: caster in my party/raid"); return
    end

    local learnedCount = 0
    for _ in pairs(TFTB_DB.learnedSpells) do learnedCount = learnedCount + 1 end
    if not TFTB_DB.idOnlyMode and learnedCount >= keywordThreshold then
      TFTB_DB.idOnlyMode = true
      Print("ID-only mode enabled ("..learnedCount.." spells learned)")
    end

    if TFTB_DB.idOnlyMode then
      if not TFTB_DB.learnedSpells[spellID] then
        DPrint("Discard: spellID "..spellID.." not learned"); return
      end
      DPrint("ID-only: recognized spellID "..spellID)
    else
      if not IsKeyword(spellName) then
        DPrint("Discard: '"..CleanName(spellName).."' not match keywords"); return
      end
      DPrint("✔ Passed keyword filter ("..CleanName(spellName)..")")
    end

    if not TFTB_DB.learnedSpells[spellID] then
      TFTB_DB.learnedSpells[spellID] = spellName
      Print("Learned buff → ["..spellID.."] "..spellName)
    end

    local now = GetTime()
    recentBuffs[#recentBuffs+1] = { guid = srcGUID, time = now }

    for i=#recentBuffs,1,-1 do
      if now - recentBuffs[i].time > TFTB_DB.mergeWindow then
        tremove(recentBuffs, i)
      end
    end

    local seen = {}
    for _, b in ipairs(recentBuffs) do seen[b.guid] = true end
    local distinct = 0
    for _ in pairs(seen) do distinct = distinct + 1 end

    if distinct > 1 then
      DPrint("MergeWindow: "..distinct.." casters → generic emote")
      DoEmote("thank")
      WipeRecent()
      return
    end

    TFTB_DB.lastThanks[srcGUID] = TFTB_DB.lastThanks[srcGUID] or {}
    local last = TFTB_DB.lastThanks[srcGUID][spellID] or 0
    if now - last >= TFTB_DB.cooldown then
      DPrint("Thanking "..srcName.." for spellID "..spellID)
      TFTB_DB.lastThanks[srcGUID][spellID] = now
      ThankPlayer(srcName)
    else
      DPrint(format(
        "Cooldown active for %s:%s → %.1fs remaining",
        srcName, spellID, TFTB_DB.cooldown - (now - last)
      ))
    end
  end
end)

-- Slash commands
SLASH_TFTB1 = "/tftb"
SlashCmdList["TFTB"] = function(msg)
  local cmd, rest = msg:match("^(%S*)%s*(.*)$")
  cmd = strlower(cmd or "")

  if cmd == "status" then
    local learnedCount = 0
    for _ in pairs(TFTB_DB.learnedSpells) do learnedCount = learnedCount + 1 end
    Print("Status:")
    Print(" • cooldown      = "..TFTB_DB.cooldown.."s")
    Print(" • mergeWindow   = "..TFTB_DB.mergeWindow.."s")
    Print(" • whisper       = "..tostring(TFTB_DB.whisper))
    Print(" • emotes        = "..tostring(TFTB_DB.emotes))
    Print(" • debug         = "..tostring(TFTB_DB.debug))
    Print(" • idOnlyMode    = "..tostring(TFTB_DB.idOnlyMode))
    Print(" • learnedSpells = "..learnedCount)
    Print(" • ignoreWindow  = "..TFTB_DB.ignoreWindow.."s")
  elseif cmd == "debug" then
    TFTB_DB.debug = not TFTB_DB.debug
    Print("Debug = "..tostring(TFTB_DB.debug))
  elseif cmd == "whisper" then
    TFTB_DB.whisper = not TFTB_DB.whisper
    Print("Whisper = "..tostring(TFTB_DB.whisper))
  elseif cmd == "emotes" then
    TFTB_DB.emotes = not TFTB_DB.emotes
    Print("Emotes = "..tostring(TFTB_DB.emotes))
  elseif cmd == "cd" then
    local v = tonumber(rest)
    if v and v >= 10 and v <= 3600 then
      TFTB_DB.cooldown = v; Print("Cooldown set to "..v.."s")
    else
      Print("Usage: /tftb cd [10-3600]")
    end
  elseif cmd == "merge" then
    local v = tonumber(rest)
    if v and v >= 1 and v <= 5 then
      TFTB_DB.mergeWindow = v; Print("MergeWindow set to "..v.."s")
    else
      Print("Usage: /tftb merge [1-5]")
    end
  elseif cmd == "ignore" then
    local v = tonumber(rest)
    if v and v >= 2 and v <= 10 then
      TFTB_DB.ignoreWindow = v
      Print("Ignore window set to "..v.." seconds")
    else
      Print("Usage: /tftb ignore [2-10]")
    end
  elseif cmd == "list" then
    Print("Learned spellIDs:")
    for id,name in pairs(TFTB_DB.learnedSpells) do
      Print(format(" • [%d] %s", id, name))
    end
  elseif cmd == "reset" then
    TFTB_DB.learnedSpells = {}
    TFTB_DB.lastThanks    = {}
    TFTB_DB.idOnlyMode    = false
    WipeRecent()
    Print("Database and flags reset.")
  else
    Print("Commands:")
    Print(" • /tftb status    Show current settings")
    Print(" • /tftb debug     Toggle debug mode")
    Print(" • /tftb whisper   Toggle whispers")
    Print(" • /tftb emotes    Toggle emotes")
    Print(" • /tftb cd [10-3600]   Set thank-you cooldown")
    Print(" • /tftb merge [1-5]    Set merge window")
    Print(" • /tftb ignore [2-10]  Set ignore window after login/reload")
    Print(" • /tftb list      Dump learned spellIDs")
    Print(" • /tftb reset     Reset database & flags")
  end
end
