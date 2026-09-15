# Don't Pick Up repository instructions

These instructions apply to the entire repository.

## Start here

- Read `README.md`, inspect the current file tree, and check Git status before editing.
- This is a new Roblox horror project with a server foundation for parties, private teleports, and profiles. Read `docs/SERVER_SYSTEMS.md` for the implemented architecture, remote contract, and validation limits. Phone gameplay and client UI remain unimplemented.
- Current source, the user's latest instructions, and the actual Studio hierarchy take priority over dated notes. Update this file and `README.md` when mappings or architecture become concrete.
- Preserve unrelated changes and Studio-authored UI, models, audio, lighting, and templates. The other projects are references for conventions; do not import their gameplay, identifiers, data, secrets, Git history, or remotes.

## Game direction

- The inspiration is the Steam game linked in `README.md`; this repository implements the user's Roblox game.
- The intended loop involves examining customer phones, carrying out government malware installation assignments, choosing whether to snoop or spy, and facing escalating danger that can include death.
- These are design intentions. Exact tasks, story progression, enemies, endings, player counts, and session structure remain to be designed with the user.
- Treat phone data and malware installation as fictional in-game content and mechanics.
- Prioritize readable phone interaction, understandable choices, suspense, and clear feedback about completed tasks and consequences.

## Repository and sync boundaries

- Repository configuration, agent instructions, and project documentation belong at the repository root, never inside `src/`. Put future extended documentation in `docs/` and local test tools in `tests/`.
- Keep runtime Luau source under `src/` with the user's environment prefixes: uppercase `L` means **Lobby**, uppercase `G` means **Game**.
- The existing source folders are `src/LClient`, `src/LServer`, `src/LShared`, `src/GClient`, `src/GServer`, and `src/GShared`. Preserve this exact casing. These filesystem names do not establish the live Studio hierarchy.
- Keep Lobby and Game bootstraps, remotes, state, and dependencies separate. Do not collapse them into unprefixed `client`, `server`, or `shared` roots.
- Lobby place ID is `110554757455252`; Game place ID is `111652489432168`. These were supplied by the user. Verify both are in one experience before live tests. The bootstraps require their parent containers inside their respective place's `ServerScriptService` and resolve modules relatively; the actual Studio sync hierarchy has not been inspected.
- Use the sibling projects' Roblox Script Sync workflow. Do not add Rojo, Wally, Rokit, generated places, dependency manifests, or CI commands unless the task actually establishes that tooling.
- Code in either shared container is client-visible. Cross-environment sharing must be explicit; a Game server cannot assume Lobby instances are present.
- Each server environment has exactly one executable `Bootstrap.server.luau`. Other source files are ModuleScripts. Do not run both bootstraps in one place. The server creates `ReplicatedStorage.DontPickUpLobbyNet` or `DontPickUpGameNet`; no shared-folder mapping is needed for this foundation.
- `src/LServer/Core` is canonical for common server code. Run `tests/SyncCore.ps1` to refresh the identical `src/GServer/Core` copy, and run the parity check. Do not move persistence or admission modules into replicated shared folders.

## Existing server foundation

- `PartyService` owns parties in one Lobby server. A player may belong to one party. Hosts create parties of 1-4 players, choose Friends/Public, kick members, and start/cancel the five-second countdown. Every member must be ready and data-ready. Friendship checks must revalidate the roster after yielding.
- `TravelService` freezes and saves all profiles before dispatch. Reserve one private Game server per party; reuse its access code across bounded retries. Correlate `TeleportInitFailed` with the active attempt. Revoke failed admissions before thawing profiles; never reopen an ownership-lost profile.
- `TicketStore` issues expiring MemoryStore rosters. Game admission checks source universe/place, destination place/private server, allowed user, expiry, revocation, and destination JobId. Ticket IDs are not permission by themselves; never expose access codes or profile data in teleport payloads.
- `GameSession:IsReady()` is the gate future gameplay must use. Every expected member must arrive and load. Incomplete or interrupted parties must not start a run. Cross-instance/cross-play splits are rejected rather than allowed to run separate copies of one party.
- `DataService` is the only mutation/save owner. `SessionStore` uses atomic UpdateAsync leases, owner-checked serialized saves, and final release. A failed load never becomes a saveable default. Preserve cancellation and ambiguous-write recovery paths.
- Both places use `DontPickUp_PlayerData_v1`, schema 1. Studio defaults to in-memory practice; enabling StudioSaving uses the separate `_STUDIO` store. Never use production data for Studio practice.
- `leaderstats` and `PlayerData` values are replicated views. Never save values read back from instances. Hidden evidence/ending IDs and the profile payload remain server-side. Future systems award progress through `DataService:RecordOutcome`, `UnlockEvidence`, and `CompleteTutorial`, never a client reward remote.
- Outcome replay protection retains the most recent 100 server-issued IDs. It is not a permanent receipt ledger; never reuse it for paid purchases or replay old outcomes after eviction.

## Gameplay authority and state

Apply these rules when the corresponding systems are implemented:

- The server owns assignments, phone ownership/access, accepted actions, task completion, suspicion/danger, death, outcomes, rewards, and saved progression.
- Validate remote payload types, bounds, action eligibility, player state, and request frequency. A client reports intent; it does not choose the authoritative result.
- Keep unrevealed phone evidence, future story content, hidden threat decisions, and secret ending conditions server-side. Replicate only the information needed for the player's current interaction.
- Model phone/task/session transitions explicitly so repeated clicks, delayed requests, respawns, or reconnects cannot duplicate completion or apply an action to the wrong phone.
- If Lobby and Game use separate places, treat teleport payloads as untrusted input and verify admission and progression on the receiving server. Record real place IDs only when supplied or verified.
- Give this project its own persistence namespace. Never copy another game's live DataStore names. Do not overwrite stored data with defaults after a failed load; handle session ownership, retries, migrations, and shutdown when persistence is introduced.
- Keep credentials out of source. Purchases, if introduced, need server-side validation and durable duplicate-grant protection.

## Interface and performance

- Preserve authored phone interfaces and layout. Confirm exact instance names and casing before binding UI.
- When showing a screen, ensure its ScreenGui and ancestor containers are enabled/visible, not just the target child.
- Use `GuiButton.Activated` for discrete buttons and support mouse, touch, and controller where relevant. Keep phone text and interactive targets readable on small screens.
- Clean up connections, camera overrides, input locks, audio, and effects when interactions end or the player dies/respawns.
- Avoid unnecessary per-frame polling and repeated remote traffic. Prefer events and bounded updates; profile before claiming performance improvements.

## Validation and handoff

- Run `lune run tests/Validate.luau`, `lune run tests/Runtime.luau`, and `lune run tests/Concurrency.luau`, plus `powershell -NoProfile -ExecutionPolicy Bypass -File tests/SyncCore.ps1 -Check` for Core parity. The Lune harness uses mocked Roblox services and deterministic concurrency; it does not validate live services or rendered UI. No CI workflow is configured.
- Review changed files for whitespace errors, merge markers, secrets, stale project names, and incorrect environment prefixes. Use `git diff --check` for tracked diffs and inspect new files as well.
- Once gameplay exists, use Studio Script Analysis and inspect both Server and Client Output. Test Lobby startup, Game startup, phone interaction, failure/death, cleanup, and supported inputs as applicable.
- Teleporting, persistence, multiplayer isolation, and published behavior need their corresponding runtime checks when introduced.
- Report concrete changed files, what was verified, and what still needs Studio or published testing. Local source or mock checks are not live verification.
- Keep Git metadata at the repository root; never initialize a nested repository in `src/`. Do not commit, push, attach a remote, or publish without user authorization.
