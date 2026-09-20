# One Player Is God

A multiplayer Roblox game in which one player becomes God and uses map-targeted abilities while the remaining players try to survive. The current build includes a complete repeatable round loop and a server-authoritative Lightning ability.

**Status:** In development  
**Technology:** Roblox Studio, Luau  
**Focus:** Multiplayer systems, secure client-server design, gameplay UI, and automated testing

## Highlights

- Randomized God and Survivor roles with intermission, selection, active-round, and cleanup phases.
- Server-side validation for ability ownership, targeting, range, cooldowns, and request rate limits.
- Character-specific lethal-hit attribution that prevents rewards from resets or environmental deaths.
- Spectator and lobby handling, survivor-count replication, disconnect recovery, and immediate round completion.
- Automated multi-client tests covering eliminations, repeat rounds, resets, pending abilities, and God disconnects.

## Current build

Open **One Player Is God v03.rbxlx** in Roblox Studio. The existing map, round loop, and countdown remain in place. The map appears when testing starts.

### Play

1. Start **Server & Clients** with 2 or more clients.
2. After the 15-second intermission and 2-second selection, God gets an overhead camera.
3. God clicks **Lightning Strike** (or presses **1**), then clicks a spot on the island. Each cast requires selecting the ability again. Escape cancels targeting.
4. A red circle warns for 0.8 seconds, then a bright vertical beam strikes. Survivors within 12 studs take 100 damage. Cooldown is 8 seconds, maximum cast distance 250 studs.
5. Dead Survivors become **SPECTATING**, and respawn in the lobby. The UI retains the round timer and remaining survivor count. The last elimination ends the round immediately. If God leaves, remaining Survivors win.

Only Lightning is enabled in Phase 2. Existing session currency is retained: 15 coins for a directly attributed lethal Lightning hit and 50 for surviving a winning round. Resets, disconnects, and environmental deaths do not earn God elimination credit. No persistent economy was added.

## Architecture

- `Config`: player minimum, round timers, existing rewards.
- `AbilityDefinitions`: Lightning name, cooldown, delay, damage, radius, cast range, attribution window.
- `AbilityService`: server validation, spam limiting, cooldown ownership, warning/impact and damage dispatch. The client sends only ability ID and target to `GodGame.UseGodAbility`.
- `DamageService`: server-only damage and character-specific lethal-hit attribution. Credit expires after 2 seconds, is consumed once, and clears at round boundaries.
- `Main`: the existing single round loop, role/death handlers, replicated survivor count, and lobby/spectator confinement.
- `HUD`: existing layout and countdown plus Lightning targeting/cooldown and SPECTATING status.
- `World`: existing island/lobby. The Studio-only fall setting remains in saved Workspace properties.

Pending strikes are invalidated when a round ends. Server-owned map raycasts resolve target height. Damage is measured in 3D from the impact point. Spectators are kept on the separate lobby platform; camera-follow spectating is not included.

## Build and tests

Run `python build.py` to rebuild **One Player Is God v03.rbxlx**. Reopen the file in Studio after rebuilding; an already-open tab will not reload automatically. Save any separate Studio edits before rebuilding.

Run `python build.py --test` to generate **Phase 2 Test.rbxlx**, then start it with **3 clients**. The separate test scripts check validation, damage attribution, spectator/lobby flow, last-survivor round end, repeat rounds, reset behavior, and God leaving during a pending strike. Look for `[Phase2Test] ALL PASS` in server Output. Test scripts are not embedded in the playable v03 file. One test client is deliberately disconnected to test God leaving.

Build validation checks source round-tripping and the saved Workspace setting. Touch input, late joins, and full timer-expiry gameplay should also be manually playtested before release.

Verified September 18, 2026 in Roblox Studio with three clients across three rounds: all automated assertions passed. See tests/studio-results.txt. God reset cancels a pending strike; God disconnect is checked separately because Studio may take longer than the 0.8-second warning to deliver PlayerRemoving. Studio emitted built-in ControlsEmulator/CoreGui errors during testing; the game's assertions all completed successfully.

