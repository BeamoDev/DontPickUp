# Don't Pick Up

A Roblox horror game in early development. Players search through customer phones, install government malware as part of their assigned work, and decide whether to spy on private information. Investigating too far can put their life at risk.

The direction is inspired by [Don't Pick Up on Steam](https://store.steampowered.com/app/4878690/). The phone-searching, malware assignment, spying, and possible death described above are this project's intended gameplay, not implemented features.

## Current status

Repository setup only. `src/` contains six empty Lobby/Game source folders: no gameplay scripts, entry points, remotes, persistence, or automated tests have been added. Studio instances and exact sync mappings have not been inspected.

## Lobby and Game naming

The prefix identifies which part of the experience owns a source container:

| Prefix | Meaning | Source naming convention |
| --- | --- | --- |
| `L` | Lobby | `LClient`, `LServer`, `LShared` |
| `G` | Game | `GClient`, `GServer`, `GShared` |

These are the existing folder names under `src/`, not verified Roblox instance paths. Preserve their exact casing. Confirm the Studio destinations and whether Lobby and Game are separate places when source is first synchronized.

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
  src/
    LClient/        Lobby client source
    LServer/        Lobby server source
    LShared/        Lobby shared source
    GClient/        Game client source
    GServer/        Game server source
    GShared/        Game shared source
```

Keep repository configuration and project documentation at the root. Future detailed documentation belongs in `docs/`, and local tests belong in `tests/`. Git does not track empty directories, so `src/` will appear on GitHub once source files are added.

## Development workflow

Follow the Roblox Script Sync workflow used by the sibling projects. No Rojo project, dependency manager, or generated place configuration is configured.

1. Read [AGENTS.md](AGENTS.md) and inspect the current source before changes.
2. On the first Studio sync, record the exact Lobby and Game source-to-instance mappings here, including each place's entry points.
3. Keep Lobby and Game source separate and sync each to its correct environment.
4. Preserve authored UI, models, audio, lighting, and other place assets. Keep separate private Studio place backups; this Git repository is not a complete place backup.
5. Review the diff and run relevant available checks. Use Studio Script Analysis and inspect Server and Client Output when runtime code is added.

Source checks cannot establish Studio behavior, published teleport flow, persistence, device usability, or multiplayer performance. Record which environment was actually tested.

## GitHub setup

The repository is initialized locally on `main`. The initial setup creates no commit or remote and does not push or publish anything. Connect the intended GitHub repository when its URL is available; if it already has history, inspect that history before combining it with this project.

The ignore rules allow the root documentation, `.github/`, `docs/`, `tests/`, and `src/`. Add an explicit root allowance when introducing another intentional repository file or directory. Credentials, logs, local editor settings, generated output, and Studio place backups are excluded.

Never commit API keys, Roblox cookies, webhook URLs, or other credentials. Keep private configuration outside tracked source.
