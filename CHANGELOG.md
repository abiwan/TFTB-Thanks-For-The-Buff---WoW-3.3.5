# Changelog

## v1.1 – September 2025

### New Features
- Added a configurable ignore window after login or reload to prevent thanking buffs inherited from previous sessions.
- New slash command `tftb ignore [2–10]` to set the ignore window duration.
- Welcome message shown only once per loginreload.
- All code comments rewritten in English for clarity and collaboration.

### Improvements
- Better separation of login vs zone-change logic.
- More accurate cooldown handling.
- Updated README with full command list and installation instructions.

### Bug Fixes
- Fixed issue where buffs received before logout or reload could trigger duplicate thank-you messages.
