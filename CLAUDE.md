# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Stablemaster is a World of Warcraft addon that creates and manages mount sets ("packs") for different zones, expansions, and transmog outfits. It automatically selects mounts based on contextual rules like current zone, equipped transmog sets, or custom transmog appearances.

## Architecture

### Core Components

- **Core.lua**: Main mount management and rule engine
  - Pack creation/deletion, mount management
  - Rule matching system (zone, transmog, custom transmog)  
  - Mount selection with flying preference logic
  - Event handling for zone changes and transmog updates

- **Utils.lua**: Database management and utilities
  - Character-specific and account-wide pack storage
  - Database initialization and migration
  - Debug/output functions

- **UI/**: User interface components
  - MainFrame.lua: Primary UI window and settings
  - PackPanel.lua: Pack management interface
  - RulesDialog.lua: Rule creation and editing
  - MountList.lua: Mount selection interface
  - Dialogs.lua: Common dialog components
  - MountJournalHook.lua: Right-click context menu integration with Mount Journal
  - MinimapIcon.lua: Draggable minimap button

### Data Architecture

The addon uses a sophisticated database structure:

```lua
StablemasterDB = {
    characters = {
        ["CharName-RealmName"] = {
            packs = { ... }, -- Character-specific packs
            created = timestamp
        }
    },
    sharedPacks = { ... }, -- Account-wide packs
    settings = {
        debugMode = false,
        verboseMode = false,
        preferFlyingMounts = true,
        packOverlapMode = "union", -- "union" or "intersection"
        rulePriorities = { transmog = 100, class = 75, race = 60, zone = 50 }
    }
}
```

### Pack System

Packs contain mounts and conditions (rules):

```lua
pack = {
    name = "Pack Name",
    description = "Optional description", 
    mounts = { mountID1, mountID2, ... },
    conditions = {
        { type = "zone", mapID = 123, includeParents = true },
        { type = "transmog", setID = 456 },
        { type = "custom_transmog", appearance = {...}, strictness = 6 },
        { type = "class", classIDs = {1, 2}, specIDs = {71, 72} }, -- Warriors and Paladins, specific specs
        { type = "race", raceIDs = {1, 3, 7} } -- Human, Dwarf, Gnome
    },
    isShared = false, -- true for account-wide packs
    isFallback = false -- true for fallback pack (used when no rules match)
}
```

### Rule System

Five rule types with scoring:

1. **Zone Rules**: Match current map ID, supports parent zone matching
2. **Transmog Rules**: Match predefined transmog sets from Collections
3. **Custom Transmog Rules**: Match specific appearance combinations with configurable strictness
4. **Class Rules**: Match player class with optional specialization filtering (multi-select)
5. **Race Rules**: Match player race (multi-select)

Rules use OR logic within the same type (any matching rule qualifies) and AND logic between different types. When multiple packs match, the pack overlap mode determines mount selection: "union" picks from all matching packs, "intersection" picks only mounts common to all matching packs.

## Common Development Tasks

### Testing the Addon

Load the addon in World of Warcraft and use these commands:
- `/stablemaster status` - Show addon configuration, active pack, and fallback pack
- `/stablemaster debug-on` - Enable debug output for development
- `/stablemaster test` - Test mount API functionality
- `/stablemaster ui` - Open the main interface
- `/stablemaster fallback <pack_name>` - Toggle a pack as the fallback pack

### Working with Slash Commands

All slash commands are handled in Core.lua in the `SlashHandler` function (~line 1224). Commands use a custom argument parser that handles quoted strings. The addon also responds to `/sm` as an alias.

### Database Operations

- Character data: Use `Stablemaster.GetCharacterPacks()` and `Stablemaster.SetCharacterPacks()`
- Pack lookup: Use `Stablemaster.GetPackByName()` for both character and shared packs
- Shared packs: Direct access via `StablemasterDB.sharedPacks`

### UI Development

UI components follow WoW's frame creation patterns:
- Use `CreateFrame()` with BackdropTemplate for containers
- Register events with `RegisterEvent()` and `SetScript("OnEvent", handler)`
- UI files are loaded via Stablemaster.toc in dependency order

### Transmog System

The transmog detection system requires initialization:
- Uses `C_TransmogSets` API for predefined sets
- Uses `TransmogUtil.GetTransmogLocation()` and `C_Transmog.GetSlotVisualInfo()` for custom appearances
- Requires Blizzard_Collections addon to be loaded
- Cache system prevents excessive API calls

### Mount Selection Logic

Mount selection follows this priority:
1. Rule-based pack selection (zone/transmog matching)
2. Fallback pack (if designated and no rules match)
3. Flying mount preference in flyable zones (for both rule-based and fallback packs)
4. Final fallback to WoW's random favorite mount system

### Fallback Pack System

Only one pack can be designated as the fallback pack at a time. When no zone or transmog rules match the current context, the addon will select a random mount from the fallback pack instead of using WoW's random favorite system. This allows users to maintain a curated pool of "favorite" mounts while still using rule-based selection when appropriate.

### Event System

Key events handled:
- `ADDON_LOADED` - Initialize addon
- `ZONE_CHANGED*` - Re-evaluate active packs
- `PLAYER_EQUIPMENT_CHANGED` - Detect transmog changes
- `TRANSMOGRIFY_*` - Handle transmog UI interactions

## File Structure

```
Stablemaster/
├── Stablemaster.toc          # Addon manifest (defines load order)
├── Utils.lua            # Database and utilities
├── Core.lua             # Main logic and slash commands
└── UI/
    ├── Dialogs.lua      # Common dialog components
    ├── MountList.lua    # Mount selection interface
    ├── MainFrame.lua    # Primary UI window
    ├── PackPanel.lua    # Pack management
    ├── RulesDialog.lua  # Rule creation/editing
    ├── MountJournalHook.lua  # Mount Journal context menu
    └── MinimapIcon.lua  # Minimap button
```

## Debugging

Enable debug mode with `/stablemaster debug-on` to see:
- Pack evaluation and scoring details
- Transmog detection results
- Zone change handling
- Mount selection logic

Use `/stablemaster packs-status` to see which packs match current conditions and their scores.