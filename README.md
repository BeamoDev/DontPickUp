# Don't Pick Up

A Roblox horror game in early development. Players search through customer phones, install government malware as part of their assigned work, and decide whether to spy on private information. Investigating too far can put their life at risk.

The direction is inspired by [Don't Pick Up on Steam](https://store.steampowered.com/app/4878690/). The current prototype implements repair work, fictional government-package installation, evidence choices, and night survival. Full phone browsing and the larger branching campaign remain future work.

## Current source layout and latest changes

Repair instructions now use plain language: parts are **WORKING** or **BROKEN**, and number-copy tasks show **NEXT**. Training and the first night use easy matching and short visible codes; later nights mix easy jobs with occasional harder puzzles. Sync both Game roots for these task and UI changes.

Game play is first person with a small, faint white dot and a centered mouse. Press **V** to unlock/relock manually; the small mouse button can relock it too. Repairs, timeclock use, notes and menus unlock automatically. Sync the complete `GClient` root. Native touch/controller input remains supported.

The latest direction is a simple, sometimes funny night job with optional deeper lore. Short authored conversations, a personal document reader, direct small-object interaction and two independent repair benches build on the existing prototype.

**The source has moved into subfolders. Sync complete roots, not old flat sibling lists.** See [current architecture, controls and deployment](docs/CURRENT_ARCHITECTURE.md), [design review](docs/DESIGN_REVIEW.md), and the [complete file move/change manifest](docs/SOURCE_CHANGES.md). These instructions supersede older flat-module setup examples below.

## Current status

The server foundation implements 1-4 player Lobby parties, reserved Game-server teleports, destination admission, party arrival checks, and persistent player profiles. The generated shop has two playable modes: **Story** follows three nights of linked evidence to an ending; **Endless** continues across increasingly demanding nights until the team dies or leaves. Each night lasts six minutes after briefing; only the first night includes training.

**To play now:** sync `GServer` into the Game place's ServerScriptService and `GClient` into StarterPlayerScripts, then press Play. The shop and HUD generate automatically. See [Game prototype setup and controls](docs/GAME_PROTOTYPE.md).

The prototype HUD uses black panels at 0.5 background transparency. **SHIFT INFO** opens repair-ticket, team and directive details on demand. Close-up controls replace the regular HUD; placeholder labels are small white text with scale sizing and a 22-stud visibility limit.

The shop has a compact **main shop and back stockroom**. Two independent benches each handle every phone task, including final testing; one repair-kit pickup supplies all three reusable tools. Replacement bins share one shelf, and current objectives highlight through walls. HUD accents are off-white and muted amber; customer/radio dialogue has typed speaker-labelled subtitles with short pages and reduced-motion support. Sync new **GServer/World/ShopLayout** and **GClient/Dialogue/SubtitleView** with both Game roots. Room props are temporary labelled geometry for the builder to replace.

Repair close-ups now look down over the phone and hide your own avatar locally. Eight task types use **3D parts on the bench**: probe pads, battery cells, wire ends, ordered assembly, screen replacement, loose debris, screws and cleaning. Drag with mouse/touch; turn screws sideways and rub dirt patches. **USE BUTTONS** keeps the original controls available, with automatic controller/reduced-motion fallback. Sync new **GClient/Repair/PhysicalRepairView** and **GClient/Repair/PhysicalRepairTasks** alongside all other Game modules. These are temporary local task pieces; other players see the existing shared repair progress.

Players spawn outside and inspect the timeclock: the camera zooms in and a button stamps their arrival. Repairs require collecting one kit containing the tester, screwdriver and software cartridge, then fetching each replacement part as needed. Task controls guide diagnosis, fitting, circuit repair, installation and final testing. Solved parts tween into place; waiting alone never solves a puzzle. Restocking uses a crate-sorting task.

Repair work now includes **four screws, screen replacement, cleaning, SIM orientation, fuse matching, button/light/sound patterns, phone-number entry, part sorting, circuits, wave alignment, power balancing, broken-component removal, charger matching, ordered reassembly, debris removal and PASS/FAIL forms**, alongside battery dragging and colored wires. Each job uses a short selection of tasks. Small pickups and objects use direct click/tap/controller interaction; larger bench/counter/fuse prompts retain hold durations. Sync **all GServer and GClient**, including the new **GServer/Repair/BenchTasks** and **GClient/Repair/BenchTaskView** modules.

Explore thirteen optional records through a personal document reader, including the original timecard, tape and key-locked archive. Story preserves decisions, suspicion and discoveries between nights and resolves one of eight endings. Surviving staff ready up together to continue; dead players remain spectators until a new run. Each earned night records progress separately. Shared runs currently stay in their server and cannot be resumed after everyone leaves.

The server-only customer catalog now contains **270 records**, including 240 composed resident identities, **12 device models**, and **12 service profiles**. Contact counts, verification sequences, fees and patience vary; roughly 76% of records are ordinary customers. Each player receives only current job information and their own puzzle controls.

Attack jumpscares now have real consequences: ordinary signal/visitor scares take **25 HP** after the face appears, interrupt the victim's repair, and show damage feedback. Fatal hits enter the existing death/spectator/ending flow. Staying outside adds personal risk after a 12-second grace period; the chance increases every eight seconds. Footsteps give **seven seconds to get inside**. Ignoring them causes 35 damage early in the night or a fatal 100-damage attack after three minutes. Returning inside cancels the warning. Tutorial, calm opening and the first harmless interruption remain protected. Sync **GServer/Anomalies/OutdoorRisk** with the updated server and client files.

Nights now start with **90 calm seconds**, followed by a harmless first interruption. A server-only director randomizes seven event types, timing, quiet gaps, and occasional personal scares. It avoids immediate repeats and limits planned scares. The face lunges with varied framing and a built-in impact sound; an optional `DontPickUpTemplates.ScareSound` overrides it. Reduced motion keeps a silent text cue.

Sync **all of GServer and GClient**, including the new `EventDirector`. Studio Output prints `[DPU][Scare] COMING ...` before a hit; diagnostics default off in published servers. Puzzle inputs now reuse unchanged world bindings, and idle effects skip scene lookups. Studio rendering, frame rate, and multiplayer latency still need profiling. See [pacing and scare configuration](docs/GAME_PROTOTYPE.md#randomized-night-and-scare-debugging).

Read [Lobby queue setup](docs/LOBBY_QUEUES.md) for the exact hierarchy and Studio print preview. Admission carries versioned mode, starting-night and party-size data; the destination trusts the server ticket and loads saved profiles separately. Sync **LServer, GServer and GClient**, including `ModeRules`. Set `Core.Config.StudioGameMode` to `Story` or `Endless` in both Core copies to preview their introductions and progression in Studio.

Queue entry now handles `Refs.Enter` contact immediately on the server, with bounds polling as a fallback. Sync the updated `LServer/Queues/QueueWorld` module for this change. Entry/exit uses stable standing slots, one departure deadline, visit-scoped requests, and visible status/error feedback. Sync all three Lobby client files (`QueueController`, `QueueView`, `QueueRequests`) with the updated Lobby server. World signs update directly without animations and preserve authored label sizes and text-sizing settings. An optional authored `Queue.Status` label controls notification placement; a small fallback label is supplied when absent.

The world sign binds `Icon.Bar.Gamemode`, `Icon`, `Status`, `PlayerCount`, and `Title`. Sync **LServer/Queues/QueueBillboard** and **LClient/QueueController** for this hierarchy. Older sign names remain supported. It shows `SHIFT AVAILABLE / READY` when empty, then the host's shift, live countdown, preparation, and teleport status with green/amber status text only. Background and title border colors stay authored.

Local tests exercise storage failures, session ownership, party permissions, partial teleports, and concurrent load/save cleanup. Studio hierarchy, published teleports, and live persistence have not been verified. Read [the server integration guide](docs/SERVER_SYSTEMS.md) before syncing.

## Lobby and Game naming

The prefix identifies which part of the experience owns a source container:

| Prefix | Meaning | Source naming convention |
| --- | --- | --- |
| `L` | Lobby | `LClient`, `LServer`, `LShared` |
| `G` | Game | `GClient`, `GServer`, `GShared` |

These are the source folder names under `src/`, not verified live Roblox instance paths. Preserve their exact casing. Lobby and Game are separate places; each server bootstrap resolves modules relative to its own parent and requires that parent to be inside `ServerScriptService`.

| Environment | Configured place ID |
| --- | --- |
| Lobby | `110554757455252` |
| Game | `111652489432168` |

The IDs were supplied by the owner. Both places must belong to the same Roblox experience so group teleports and player data work across them; this relationship still needs dashboard verification.

- Client code owns presentation, input, camera, and local effects.
- Server code owns authoritative gameplay, validation, outcomes, and saved data.
- Shared code is visible to clients. Keep hidden story information, unrevealed phone content, and secret outcome rules on the server until needed by an authorized player.
- Lobby shared code and Game shared code belong to their respective environments; do not assume one can directly require the other.

## Repository layout

```text
DontPickUp/
  .git/             Local Git metadata
  .gitattributes    Text line endings and binary asset handling
  .gitignore        Source-focused tracking and local file exclusions
  AGENTS.md         Project instructions for coding agents
  README.md         Project overview and setup
  docs/             Integration, remote contract, persistence, and live test checklist
  tests/            Local regression tests and server Core synchronization helper
  src/
    LClient/        Lobby client source
    LServer/        Lobby server source
    LShared/        Lobby shared source
    GClient/        Game client source
    GServer/        Game server source
    GShared/        Game shared source
```

Keep repository configuration and project documentation outside `src/`. Detailed documentation belongs in `docs/`, and local tests belong in `tests/`. Both shared folders remain empty; Game client code now lives in `GClient`.

## Development workflow

Follow the Roblox Script Sync workflow used by the sibling projects. No Rojo project, dependency manager, or generated place configuration is configured.

1. Read [AGENTS.md](AGENTS.md) and inspect the current source before changes.
2. Sync `LServer` inside the Lobby's `ServerScriptService`, and `GServer` inside the Game's `ServerScriptService`. Each contains one executable `Bootstrap.server.luau` Script; every other Luau file is a ModuleScript. Preserve the `Core` subtree.
3. Keep Lobby and Game source separate and sync each to its correct environment.
   Sync `LClient` under the Lobby's `StarterPlayer.StarterPlayerScripts`; `QueueController.local.luau` is a LocalScript, with `UI/QueueView.luau` and `Networking/QueueRequests.luau` ModuleScripts.
   Sync `GClient` under the Game's `StarterPlayer.StarterPlayerScripts`; `PrototypeController.local.luau` is the root LocalScript; preserve all UI, Networking, Interactions, Repair, Dialogue and Effects folders beneath the same client root.
4. Preserve authored UI, models, audio, lighting, and other place assets. Keep separate private Studio place backups; this Git repository is not a complete place backup.
5. Run the local checks below. Use Studio Script Analysis and inspect Server and Client Output after syncing.

## Local checks

Using an existing Lune installation, run from the repository root:

```powershell
lune run tests/Validate.luau
lune run tests/Runtime.luau
lune run tests/Concurrency.luau
lune run tests/Queues.luau
lune run tests/Prototype.luau
lune run tests/Improvements.luau
powershell -NoProfile -ExecutionPolicy Bypass -File tests/SyncCore.ps1 -Check
git diff --check
```

`LServer/Core` is the maintained source of the common **server-only** modules. After editing it, run `tests/SyncCore.ps1` without `-Check` to update the identical `GServer/Core` deployment copy. Both places use the same schema, storage namespace, admission format, and configuration; neither requires instances from the other place.

Source checks cannot establish Studio behavior, published teleport flow, persistence, device usability, or multiplayer performance. Record which environment was actually tested.

## GitHub setup

The repository uses `main`. Check `git remote -v` and `git status` for its current GitHub connection and working-tree state before committing or pushing.

The ignore rules allow the root documentation, `.github/`, `docs/`, `tests/`, and `src/`. Add an explicit root allowance when introducing another intentional repository file or directory. Credentials, logs, local editor settings, generated output, and Studio place backups are excluded.

Never commit API keys, Roblox cookies, webhook URLs, or other credentials. Keep private configuration outside tracked source.
