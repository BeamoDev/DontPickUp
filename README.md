# Don't Pick Up

A Roblox horror game in early development. Players search through customer phones, install government malware as part of their assigned work, and decide whether to spy on private information. Investigating too far can put their life at risk.

The direction is inspired by [Don't Pick Up on Steam](https://store.steampowered.com/app/4878690/). The current prototype implements repair work, fictional government-package installation, evidence choices, and night survival. Full phone browsing and the larger branching campaign remain future work.

## Current status

The server foundation implements 1-4 player Lobby parties, reserved Game-server teleports, destination admission, party arrival checks, and persistent player profiles. The generated shop has two playable modes: **Story** follows three nights of linked evidence to an ending; **Endless** continues across increasingly demanding nights until the team dies or leaves. Each night lasts six minutes after briefing; only the first night includes training.

**To play now:** sync `GServer` into the Game place's ServerScriptService and `GClient` into StarterPlayerScripts, then press Play. The shop and HUD generate automatically. See [Game prototype setup and controls](docs/GAME_PROTOTYPE.md).

The prototype HUD uses black panels at 0.5 background transparency. **SHIFT INFO** opens repair-ticket, team and directive details on demand. Close-up controls replace the regular HUD; world billboards use scale sizing and a 35-stud visibility limit.

Players spawn outside and inspect the timeclock: the camera zooms in and a button stamps their arrival. Repairs require collecting a tester, screwdriver, software cartridge, and each replacement part. Diagnose from readings, align battery contacts, connect speaker wires, rebuild keypad sequences, enter verification codes, and complete final tests. Solved parts tween into place; waiting alone never solves a puzzle. Restocking uses a crate-sorting task.

Explore for an old timecard, tape, brass key and locked archive drawer. Story preserves decisions, suspicion and discoveries between nights and resolves one of eight endings. Surviving staff ready up together to continue; dead players remain spectators until a new run. Each earned night records progress separately. Shared runs currently stay in their server and cannot be resumed after everyone leaves.

The server-only customer catalog now contains **270 records**, including 240 composed resident identities, **12 device models**, and **12 service profiles**. Contact counts, verification sequences, fees and patience vary; roughly 76% of records are ordinary customers. Each player receives only current job information and their own puzzle controls.

Nights now start with **90 calm seconds**, followed by a harmless first interruption. A server-only director randomizes seven event types, timing, quiet gaps, and occasional personal scares. It avoids immediate repeats and limits planned scares. The face lunges with varied framing and a built-in impact sound; an optional `DontPickUpTemplates.ScareSound` overrides it. Reduced motion keeps a silent text cue.

Sync **all of GServer and GClient**, including the new `EventDirector`. Studio Output prints `[DPU][Scare] COMING ...` before a hit; diagnostics default off in published servers. Puzzle inputs now reuse unchanged world bindings, and idle effects skip scene lookups. Studio rendering, frame rate, and multiplayer latency still need profiling. See [pacing and scare configuration](docs/GAME_PROTOTYPE.md#randomized-night-and-scare-debugging).

Read [Lobby queue setup](docs/LOBBY_QUEUES.md) for the exact hierarchy and Studio print preview. Admission carries versioned mode, starting-night and party-size data; the destination trusts the server ticket and loads saved profiles separately. Sync **LServer, GServer and GClient**, including `ModeRules`. Set `Core.Config.StudioGameMode` to `Story` or `Endless` in both Core copies to preview their introductions and progression in Studio.

Queue entry/exit uses stable standing slots, one departure deadline, visit-scoped requests, and visible status/error feedback. Sync all four Lobby client files (`QueueController`, `QueueView`, `QueueRequests`, `QueueBillboardMotion`) with the updated Lobby server. World signs now use brief local transitions for party/host changes, player counts, mode icons, and the final countdown. An optional authored `Queue.Status` label controls notification placement; a small fallback label is supplied when absent.

The world sign now binds `GamemodeIcon`, `Gamemode`, `Title`, `Players`, and `GreenStatus`. Include the Lobby server's `QueueBillboard` ModuleScript when syncing. It shows `SHIFT AVAILABLE / READY` when empty, then the host's shift, live countdown, preparation, and teleport status with matching green/amber accents.

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
   Sync `LClient` under the Lobby's `StarterPlayer.StarterPlayerScripts`; `QueueController.local.luau` is a LocalScript, with sibling `QueueView.luau`, `QueueRequests.luau`, and `QueueBillboardMotion.luau` ModuleScripts.
   Sync `GClient` under the Game's `StarterPlayer.StarterPlayerScripts`; `PrototypeController.local.luau` is a LocalScript with sibling `PrototypeView`, `RepairPresentation`, `RepairAssembly`, `ScarePresentation`, `PuzzleView`, and `StationInteraction` ModuleScripts.
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
powershell -NoProfile -ExecutionPolicy Bypass -File tests/SyncCore.ps1 -Check
git diff --check
```

`LServer/Core` is the maintained source of the common **server-only** modules. After editing it, run `tests/SyncCore.ps1` without `-Check` to update the identical `GServer/Core` deployment copy. Both places use the same schema, storage namespace, admission format, and configuration; neither requires instances from the other place.

Source checks cannot establish Studio behavior, published teleport flow, persistence, device usability, or multiplayer performance. Record which environment was actually tested.

## GitHub setup

The repository uses `main`. Check `git remote -v` and `git status` for its current GitHub connection and working-tree state before committing or pushing.

The ignore rules allow the root documentation, `.github/`, `docs/`, `tests/`, and `src/`. Add an explicit root allowance when introducing another intentional repository file or directory. Credentials, logs, local editor settings, generated output, and Studio place backups are excluded.

Never commit API keys, Roblox cookies, webhook URLs, or other credentials. Keep private configuration outside tracked source.
