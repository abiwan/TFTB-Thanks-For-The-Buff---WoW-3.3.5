# Thanks For The Buff (TFTB)

Automatically thanks other players for utility buffs applied to you in solo/open-world play.  
Perfect for friendly adventurers who want to show appreciation without spamming party or raid chat.

> ⚠️ This addon is based on the original idea from [Thanks For The Buff - Revisited](https://www.curseforge.com/wow/addons/thanks-for-the-buff-revisited).  
> It has been adapted and extended for WoW 3.3.5a and Project Epoch.

## Features

- Whisper and emote thank-you messages to buff casters
- Learns new buff spellIDs automatically
- Switches to ID-only mode once all keywords are learned
- Merge-window logic to avoid duplicate emotes for multi-caster buffs
- Cooldown system per caster and spell
- Configurable ignore window after login/reload to avoid thanking inherited buffs
- Slash commands for full control

## Slash Commands

| Command             | Description                                 |
|---------------------|---------------------------------------------|
| `/tftb status`      | Show current settings                       |
| `/tftb debug`       | Toggle debug mode                           |
| `/tftb whisper`     | Toggle whisper messages                     |
| `/tftb emotes`      | Toggle emotes                               |
| `/tftb cd [10-3600]`| Set cooldown in seconds                     |
| `/tftb merge [1-5]` | Set merge window for multi-caster buffs     |
| `/tftb ignore [2-10]`| Set ignore window after login/reload       |
| `/tftb list`        | Show learned spellIDs                       |
| `/tftb reset`       | Reset all learned data and cooldowns        |

## Installation

  1. Download the latest release from https://github.com/abiwan/TFTB-Thanks-For-The-Buff---WoW-3.3.5/releases
2. Extract to your `Interface/AddOns` folder
3. Launch WoW and type `/tftb` to get started

## Author

Created by **abiwan**  
Project Epoch compatible (WoW 3.3.5a)


