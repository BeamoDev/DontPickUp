# Don't Pick Up repository instructions

These instructions apply to the entire repository.

## Start here

- Read `README.md`, inspect the current file tree, and check Git status before editing.
- This is a new Roblox horror project. At repository setup on 2026-09-14, `src/` contained six empty Lobby/Game folders and no runtime files. Do not describe planned systems as implemented or invent runtime entry points.
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
- Do not infer Roblox instance paths from filesystem names. Confirm and document each source container's Studio destination and the actual Lobby/Game place arrangement before wiring requires, startup, or teleports.
- Use the sibling projects' Roblox Script Sync workflow. Do not add Rojo, Wally, Rokit, generated places, dependency manifests, or CI commands unless the task actually establishes that tooling.
- Code in either shared container is client-visible. Cross-environment sharing must be explicit; a Game server cannot assume Lobby instances are present.
- Keep one intentional startup path per client/server environment and avoid duplicate event bindings when implementing bootstraps.

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

- Run checks that actually exist and are relevant to the change. No compiler, test harness, build command, or CI workflow is configured at setup; do not report nonexistent checks as passing.
- Review changed files for whitespace errors, merge markers, secrets, stale project names, and incorrect environment prefixes. Use `git diff --check` for tracked diffs and inspect new files as well.
- Once gameplay exists, use Studio Script Analysis and inspect both Server and Client Output. Test Lobby startup, Game startup, phone interaction, failure/death, cleanup, and supported inputs as applicable.
- Teleporting, persistence, multiplayer isolation, and published behavior need their corresponding runtime checks when introduced.
- Report concrete changed files, what was verified, and what still needs Studio or published testing. Local source or mock checks are not live verification.
- Keep Git metadata at the repository root; never initialize a nested repository in `src/`. Do not commit, push, attach a remote, or publish without user authorization.
