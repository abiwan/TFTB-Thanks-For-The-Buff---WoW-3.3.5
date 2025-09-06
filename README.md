# TFTB – Thanks For The Buff (WoW 3.3.5a)

TFTB is a lightweight World of Warcraft addon that automatically thanks other players when they apply useful buffs to your character.  
It’s designed for private servers like Project Epoch and works entirely with the 3.3.5a combat log API.

> ⚠️ This addon is inspired by the original concept from [Thanks For The Buff Revisited](https://www.curseforge.com/wow/addons/thanks-for-the-buff-revisited), adapted and optimized for modern private server compatibility.

---

## ✨ Features

- Detects buffs using `COMBAT_LOG_EVENT_UNFILTERED`
- Filters by keywords and learns spellIDs dynamically
- Sends directed emotes and whispers to buff casters
- Switches to ID-only mode once all keywords are learned
- Handles buff refreshes and expirations (SPELL_AURA_REFRESH / REMOVED)
- Ignores buffs from party/raid members, NPCs, pets, and self
- Sends generic `/thanks` emote when multiple players buff you simultaneously
- Fully configurable via slash commands

---

## ⚙️ Slash Commands

```bash
/tftb status       # Show current settings
/tftb debug        # Toggle debug mode
/tftb whisper      # Toggle whisper messages
/tftb emotes       # Toggle emotes
/tftb cd [10-3600] # Set cooldown per player+buff
/tftb merge [1-5]  # Set merge window for multi-caster detection
/tftb list         # List all learned spellIDs
/tftb reset        # Reset database and cooldowns
```

---

## 🛠️ How It Works

- Listens for SPELL_AURA_APPLIED events targeting your character
- Filters buffs by keyword or learned spellID
- Tracks cooldowns per player and per buff to avoid spam
- Switches to ID-only mode once all keywords are matched
- Handles buff refreshes and removals to reset cooldowns
- Uses a merge window to detect multiple casters and send a single generic emote

---

## 🖥️ Requirements

- World of Warcraft 3.3.5a client
- Compatible with private servers using standard combat log API
- No external libraries required (Ace3, LibStub, XML, etc.)

---

## 🐛 Issue Template (GitHub > Issues > New)

```markdown
### Bug Description

Describe the issue you're experiencing and what you expected to happen.

### Steps to Reproduce

1. ...
2. ...
3. ...

### Debug Output

Paste any relevant debug lines from the chat window.

### Environment

- Server name:
- Character class/level:
- Addon version:
```

---

## 🙏 Credits

Concept inspired by Thanks For The Buff Revisited  
Developed and adapted by abiwan
