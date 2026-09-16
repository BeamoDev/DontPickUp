# Source move manifest

Working-tree content was preserved before relocation. No compatibility wrappers remain. Core remains duplicated only for independent place deployment.

| Previous path | Current path |
| --- | --- |
| `src/GServer/GamePrototype.luau` | `src/GServer/Services/GamePrototype.luau` |
| `src/GServer/GameSession.luau` | `src/GServer/Services/GameSession.luau` |
| `src/GServer/ShiftService.luau` | `src/GServer/Shifts/ShiftService.luau` |
| `src/GServer/ModeRules.luau` | `src/GServer/Shifts/ModeRules.luau` |
| `src/GServer/EndingRules.luau` | `src/GServer/Shifts/EndingRules.luau` |
| `src/GServer/PrototypeConfig.luau` | `src/GServer/Shifts/PrototypeConfig.luau` |
| `src/GServer/CustomerCatalog.luau` | `src/GServer/Customers/CustomerCatalog.luau` |
| `src/GServer/Workshop.luau` | `src/GServer/Repair/Workshop.luau` |
| `src/GServer/WorkPuzzles.luau` | `src/GServer/Repair/WorkPuzzles.luau` |
| `src/GServer/RepairTasks.luau` | `src/GServer/Repair/RepairTasks.luau` |
| `src/GServer/BenchTasks.luau` | `src/GServer/Repair/BenchTasks.luau` |
| `src/GServer/RepairTemplates.luau` | `src/GServer/Repair/RepairTemplates.luau` |
| `src/GServer/EventDirector.luau` | `src/GServer/Anomalies/EventDirector.luau` |
| `src/GServer/OutdoorRisk.luau` | `src/GServer/Anomalies/OutdoorRisk.luau` |
| `src/GServer/ShopSecrets.luau` | `src/GServer/Lore/ShopSecrets.luau` |
| `src/GServer/PrototypeWorld.luau` | `src/GServer/World/PrototypeWorld.luau` |
| `src/GServer/ShopLayout.luau` | `src/GServer/World/ShopLayout.luau` |
| `src/GClient/PrototypeView.luau` | `src/GClient/UI/PrototypeView.luau` |
| `src/GClient/RepairPresentation.luau` | `src/GClient/Repair/RepairPresentation.luau` |
| `src/GClient/RepairAssembly.luau` | `src/GClient/Repair/RepairAssembly.luau` |
| `src/GClient/PuzzleView.luau` | `src/GClient/Repair/PuzzleView.luau` |
| `src/GClient/RepairTaskView.luau` | `src/GClient/Repair/RepairTaskView.luau` |
| `src/GClient/BenchTaskView.luau` | `src/GClient/Repair/BenchTaskView.luau` |
| `src/GClient/PhysicalRepairView.luau` | `src/GClient/Repair/PhysicalRepairView.luau` |
| `src/GClient/PhysicalRepairTasks.luau` | `src/GClient/Repair/PhysicalRepairTasks.luau` |
| `src/GClient/StationInteraction.luau` | `src/GClient/Interactions/StationInteraction.luau` |
| `src/GClient/SubtitleView.luau` | `src/GClient/Dialogue/SubtitleView.luau` |
| `src/GClient/ScarePresentation.luau` | `src/GClient/Effects/ScarePresentation.luau` |
| `src/LServer/PartyService.luau` | `src/LServer/Parties/PartyService.luau` |
| `src/LServer/WorldQueueService.luau` | `src/LServer/Queues/WorldQueueService.luau` |
| `src/LServer/QueueWorld.luau` | `src/LServer/Queues/QueueWorld.luau` |
| `src/LServer/QueueGeometry.luau` | `src/LServer/Queues/QueueGeometry.luau` |
| `src/LServer/QueueBillboard.luau` | `src/LServer/Queues/QueueBillboard.luau` |
| `src/LClient/QueueView.luau` | `src/LClient/UI/QueueView.luau` |
| `src/LClient/QueueRequests.luau` | `src/LClient/Networking/QueueRequests.luau` |

## Added files

| File | Purpose |
| --- | --- |
| `src/GServer/Customers/Conversations.luau` | Short ordinary, comic, unusual, government and coworker exchanges |
| `src/GServer/Services/DialogueService.luau` | Bounded server-timed conversation sequence |
| `src/GServer/Lore/LoreService.luau` | Personal inspection, keys, expiry and scoped close |
| `src/GServer/Repair/RepairStations.luau` | Independent bench state, selection and shared vote coordination |
| `src/GServer/Repair/RepairFlow.luau` | Extracted repair lifecycle, stock recovery and work ticking |
| `src/GServer/Shifts/ShiftActions.luau` | Extracted validated player actions |
| `src/GServer/Shifts/ShiftSnapshot.luau` | Extracted per-player snapshots and shared ballot |
| `src/GServer/Shifts/ShiftDefinitions.luau` | Server-only transitions, station mapping and instructions |
| `src/GServer/Anomalies/ThreatService.luau` | Extracted injuries, outdoor danger and shared disturbances |
| `src/GClient/Networking/Requests.luau` | Serialized requests and original-visit deferred exits |
| `src/GClient/UI/InspectionView.luau` | Paginated readable document UI and controller close |
| `src/GClient/Interactions/WorldInteraction.luau` | Mouse/touch/controller direct world interaction and feedback |
| `tests/ShiftFixture.luau` | Existing deterministic shift fixture extracted for reuse |
| `tests/Improvements.luau` | Multi-station, lore, dialogue, request and input regressions |
| `docs/DESIGN_REVIEW.md` | Before-edit architecture review and staged plan |
| `docs/CURRENT_ARCHITECTURE.md` | Current architecture, controls, sync and manual setup |
| `docs/SOURCE_CHANGES.md` | Complete move/change manifest |

## Substantially changed existing files (current paths)

| File | Change |
| --- | --- |
| `src/GServer/Shifts/ShiftService.luau` | Reduced to lifecycle/scheduling and composition of cohesive method modules; explicit per-bench state |
| `src/GServer/Services/GamePrototype.luau` | Per-bench world routing, direct input validation and prompt rate limiting |
| `src/GServer/World/PrototypeWorld.luau` | Second complete bench/phone/seat, individual customer visuals, lore props, direct targets and per-player action routing |
| `src/GServer/World/ShopLayout.luau` | Room access for new bench and records |
| `src/GServer/Lore/ShopSecrets.luau` | Ten connected optional records added; original records/IDs retained |
| `src/GServer/Shifts/ModeRules.luau` | Shorter, lighter introductions |
| `src/GClient/PrototypeController.local.luau` | Wires request layer, reader, direct input and shared suppression/cleanup |
| `src/GClient/UI/PrototypeView.luau` | Shorter briefing, bench context, reader suppression and explicit forbidden-call choice |
| `src/GClient/Dialogue/SubtitleView.luau` | Server-timed lines, authored local You label, subtitle-setting support |
| `src/GClient/Repair/RepairPresentation.luau` | Select correct bench camera and phone highlight |
| `src/GClient/Repair/RepairAssembly.luau` | Select correct phone/tray for cosmetic fitting |
| `src/GClient/Repair/PhysicalRepairView.luau` | Correct phone and real seat checks at either bench |
| `src/GClient/Repair/PuzzleView.luau` | Owner/seat checks at either bench |
| `tests/Harness.luau` | Nested relative ModuleScript paths |
| `tests/Prototype.luau` | Updated folder/station observations, shared fixture and changed interaction contract assertions |
| `tests/Validate.luau`, `tests/Runtime.luau`, `tests/Queues.luau` | Updated source paths after moves |
| `README.md`, `AGENTS.md`, `docs/GAME_PROTOTYPE.md`, `docs/LOBBY_QUEUES.md`, `docs/SERVER_SYSTEMS.md` | Current paths, latest direction, deployment and validation boundaries |

The two server bootstraps and Lobby client controller also have updated imports. Core remains byte-for-byte identical between places; no persistence schema, store name, place ID, authored Lobby layout or authored asset changed. The pre-existing removal of QueueBillboardMotion remains in place.

Later Game updates add `Interactions/FirstPersonCamera` and simplify player-facing text across repair rules/views, job requirements, objectives, world prompts and nightly briefings. `WorkPuzzles.IsEasy` and `ShiftActions` select short visible-code tasks throughout night one and for two of three later order seed classes. The harder puzzle types remain available. `tests/Improvements.luau` covers that difficulty mix, plain diagnosis results and final-check actions; `tests/Prototype.luau` covers full repairs with the updated tasks. These changes require both Game roots to be synced.

The local Lune executable is in ignored `.tools/lune/`; it and temporary refactor helpers are not runtime source or required dependencies. No commit, push, sync or publication was performed.
