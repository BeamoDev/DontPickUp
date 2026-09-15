# Don't Pick Up

A Roblox horror game in early development. Players search through customer phones, install government malware as part of their assigned work, and decide whether to spy on private information. Investigating too far can put their life at risk.

The direction is inspired by [Don't Pick Up on Steam](https://store.steampowered.com/app/4878690/). The phone-searching, malware assignment, spying, and possible death described above are this project's intended gameplay, not implemented features.

## Current status

The server foundation implements Lobby parties, reserved Game-server teleports, destination admission, party arrival checks, and persistent player profiles. No physical models or client UI are required by these services. Phone gameplay and queue/menu interfaces have not been built.

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

Keep repository configuration and project documentation outside `src/`. Detailed documentation belongs in `docs/`, and local tests belong in `tests/`. Client and shared folders remain empty; Git will track them when files are added.

## Development workflow

Follow the Roblox Script Sync workflow used by the sibling projects. No Rojo project, dependency manager, or generated place configuration is configured.

1. Read [AGENTS.md](AGENTS.md) and inspect the current source before changes.
2. Sync `LServer` inside the Lobby's `ServerScriptService`, and `GServer` inside the Game's `ServerScriptService`. Each contains one executable `Bootstrap.server.luau` Script; every other Luau file is a ModuleScript. Preserve the `Core` subtree.
3. Keep Lobby and Game source separate and sync each to its correct environment.
4. Preserve authored UI, models, audio, lighting, and other place assets. Keep separate private Studio place backups; this Git repository is not a complete place backup.
5. Run the local checks below. Use Studio Script Analysis and inspect Server and Client Output after syncing.

## Local checks

Using an existing Lune installation, run from the repository root:

```powershell
lune run tests/Validate.luau
lune run tests/Runtime.luau
lune run tests/Concurrency.luau
powershell -NoProfile -ExecutionPolicy Bypass -File tests/SyncCore.ps1 -Check
git diff --check
```

`LServer/Core` is the maintained source of the common **server-only** modules. After editing it, run `tests/SyncCore.ps1` without `-Check` to update the identical `GServer/Core` deployment copy. Both places use the same schema, storage namespace, admission format, and configuration; neither requires instances from the other place.

Source checks cannot establish Studio behavior, published teleport flow, persistence, device usability, or multiplayer performance. Record which environment was actually tested.

## GitHub setup

The repository uses `main`. Check `git remote -v` and `git status` for its current GitHub connection and working-tree state before committing or pushing.

The ignore rules allow the root documentation, `.github/`, `docs/`, `tests/`, and `src/`. Add an explicit root allowance when introducing another intentional repository file or directory. Credentials, logs, local editor settings, generated output, and Studio place backups are excluded.

Never commit API keys, Roblox cookies, webhook URLs, or other credentials. Keep private configuration outside tracked source.
