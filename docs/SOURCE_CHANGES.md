# Source organization and deployment

Runtime code is organized by complete systems. `src` contains exactly `GClient`, `GServer`, `GShared`, `LClient`, `LServer`, and `LShared`; each root has one folder level, with scripts/modules only inside each system. There are no runtime Prototype, Core, Queues, Settings, Containers or PhoneRepair folders.

## Gameplay audit ? 2026-09-16

The latest authored layout no longer needs the four RepairPhone/CounterPhone placement anchors. DevicePlacement derives positions from Bench, Bench2 and Counter, with optional named mounts documented in PROTOTYPE_ASSETS.md. Building.Lighting is recognized. Construction failures roll back runtime phones, input bindings, scene state, admission folders and travel listeners.

Counter input now carries the snapshot's CounterOrderId and revalidates that customer before acting; selected-bench IDs no longer incorrectly route intake/return. Direct bench clicks retain Station for SelectStation. Server checks now test physical wall occlusion at ordinary stations as well as storage and Fax. Queued respawns are coalesced and cancelled on departure/teardown.

GameLost and dialogue share pixel grayscale math. Dialogue clones convert supported textures with bounded memory and cancellation; unsupported avatar clothing or inaccessible assets retain their original appearance. Authored portrait camera properties are unchanged. See DIALOGUE.md for limitations.

Targeted checks cover the screenshot's missing anchors/nested lights, precise mounts, failed/retried startup, other-bench counter intake and stale targets, station identity, walls, respawn cancellation, image conversion/cache/budget/failure/late teardown. Run tests/Run.ps1 for all existing lifecycle, input, gameplay, persistence and Lobby checks. These are mocked/source checks, not Studio or published multiplayer verification.

Studio: use 2?4 clients to contest a bench/drawer/phone, leave or reset while repairing/carrying/calling, join mid-shift, complete concurrent repairs, die while a teammate continues, then retry and return to Lobby. Check imported phone placement and loose-part camera coverage, blackout lights, gray mugshots, texture permissions and speaker transitions on real rigs. No additional Workspace deletions are required.

## Sync this change

1. Stop Play in Studio. Run `powershell -NoProfile -ExecutionPolicy Bypass -File tools/SyncCommon.ps1` after editing common code, then `tests/Run.ps1`.
2. Sync all three roots for each place together, using `project.sources.json` destinations. Game and Lobby roots still belong in separate places. This JSON is consumed by SyncCommon; it is not a Rojo or Roblox plugin configuration.
3. Remove obsolete **scripts only** using `tests/SourceMoves.json`. The table below covers old script paths, relative to src. Replace current modules with updated contents as well; some historical module names are reused with a new responsibility.
4. There must be only one executable client script and one executable server script per place: `Startup/Bootstrap.local.luau` and `Startup/Bootstrap.server.luau`. `.local.luau` remains this project's LocalScript convention. `GClient.Startup.GameController` is now a ModuleScript: remove the former GameController LocalScript before creating its ModuleScript replacement. Likewise remove the old Lobby QueueController LocalScript; the replacement is a ModuleScript under Matchmaking.
5. Restart Play and follow the Studio checklist in CURRENT_ARCHITECTURE.md. Keep all authored Workspace models, HUD screens, assets, Remotes, cameras and highlights. In particular, **do not delete Workspace.Prototype or DPU_PrototypeHUD**. Only source folder naming changed.

## Shared infrastructure

Maintain the 13 reusable modules once under `common/CommonServer/{Configuration,PlayerData,Networking,Travel}` and `common/CommonClient/Interface`. `project.sources.json` maps them into both existing place roots. `tools/SyncCommon.ps1` generates the deployment copies; `-Check` rejects missing or edited copies. Do not hand-edit generated modules in src. `tests/SyncCore.ps1` and `tests/SyncSettings.ps1` remain compatibility commands for the server/client groups.

The package holds only implemented infrastructure, not speculative empty modules. ProfileStore is the existing first-party save-lock implementation, not a third-party dependency. Its DataStore namespace, migrations, leases, admission tickets, saves and outcome idempotency are unchanged.

## Consolidation

The two first-person cursor/camera implementations now share `GClient/Camera/CameraController`; it restores bound authored UI or destroys its own temporary UI according to ownership. InspectionCamera remains the reusable camera-transition controller. Dialogue's timed shift adapter and test-demo adapter share DialogueView/DialoguePortrait in Interface. Settings has one common implementation. CarryController owns pickup/release requests while CarryView owns smooth local visualization. QueueService owns membership/countdowns; LobbyWorldService and QueueView retain their distinct world/UI lifecycles. Server-owned billboards remain server-owned.

SessionController starts the active client's systems explicitly. SessionService connects admission, data and GameService on the server; ShiftService owns the shift state. OrderService contains the shift's order actions, while BenchOrderService clearly labels the retained alternate test bench. GameConfig.Enabled still selects exactly one mode and defaults true. Existing wire protocol names such as PrototypeEnabled, PrototypeAction and GetPrototype are retained for compatibility; they do not require Prototype source folders.

## Obsolete script paths

| Remove old script | Replacement |
| --- | --- |
| `GClient/Camera/FirstPersonCamera` | `GClient/Camera/CameraController` |
| `GClient/Dialogue/DialogueConfig` | `GClient/Interface/DialogueConfig` |
| `GClient/Dialogue/DialogueController` | `GClient/Interface/DialogueDemoController` |
| `GClient/Dialogue/DialoguePortrait` | `GClient/Interface/DialoguePortrait` |
| `GClient/Dialogue/DialogueView` | `GClient/Interface/DialogueView` |
| `GClient/Dialogue/SubtitleView` | `GClient/Interface/DialogueController` |
| `GClient/Effects/ScarePresentation` | `GClient/Effects/HorrorController` |
| `GClient/GameController.local` | `GClient/Startup/GameController` |
| `GClient/HUD/Mugshot` | `GClient/Interface/Mugshot` |
| `GClient/HUD/ShiftPanels` | `GClient/Interface/ShiftPanelController` |
| `GClient/Interactions/CarryView` | `GClient/Interaction/CarryView` |
| `GClient/Interactions/FirstPersonCamera` | `GClient/Camera/CameraController` |
| `GClient/Interactions/InteractionController` | `GClient/Interaction/InteractionController` |
| `GClient/Interactions/ModelInspection` | `GClient/Camera/InspectionCamera` |
| `GClient/Interactions/SelectionHighlight` | `GClient/Interaction/SelectionHighlight` |
| `GClient/Interactions/StationInteraction` | `GClient/Interaction/StationInteractionController` |
| `GClient/Interactions/TaggedInteraction` | `GClient/Interaction/InteractionController` |
| `GClient/Interactions/ThrowController` | `GClient/Interaction/CarryController` |
| `GClient/Interactions/ThrowInteraction` | `GClient/Interaction/CarryController` |
| `GClient/Interactions/WorldInteraction` | `GClient/Interaction/WorldInteractionController` |
| `GClient/Orders/OrderController` | `GClient/Interface/OrderController` |
| `GClient/Orders/OrderView` | `GClient/Interface/OrderView` |
| `GClient/PhoneRepair/PhoneRepairController` | `GClient/Repair/PhoneRepairController` |
| `GClient/PhoneRepair/RepairDragController` | `GClient/Repair/RepairDragController` |
| `GClient/PhoneRepair/RepairViewConfig` | `GClient/Repair/RepairViewConfig` |
| `GClient/Prototype/AuthoredUI` | `GClient/Interface/AuthoredUI` |
| `GClient/Prototype/BenchTaskView` | `GClient/Repair/BenchTaskView` |
| `GClient/Prototype/DeviceTaskView` | `GClient/Repair/DeviceTaskView` |
| `GClient/Prototype/FaxView` | `GClient/Effects/TelephoneController` |
| `GClient/Prototype/FirstPersonCamera` | `GClient/Camera/CameraController` |
| `GClient/Prototype/InspectionView` | `GClient/Interface/InspectionView` |
| `GClient/Prototype/PhysicalRepairTasks` | `GClient/Repair/PhysicalRepairTasks` |
| `GClient/Prototype/PhysicalRepairView` | `GClient/Repair/PhysicalRepairView` |
| `GClient/Prototype/PickupTelephone` | `GClient/Effects/TelephoneController` |
| `GClient/Prototype/PrototypeController` | `GClient/Session/SessionController` |
| `GClient/Prototype/PrototypeView` | `GClient/Interface/HUDController` |
| `GClient/Prototype/PuzzleView` | `GClient/Repair/PuzzleView` |
| `GClient/Prototype/RepairAssembly` | `GClient/Repair/RepairAssembly` |
| `GClient/Prototype/RepairPresentation` | `GClient/Repair/RepairPresentation` |
| `GClient/Prototype/RepairTaskView` | `GClient/Repair/RepairTaskView` |
| `GClient/Prototype/Requests` | `GClient/Session/SessionRequests` |
| `GClient/Prototype/ScarePresentation` | `GClient/Effects/HorrorController` |
| `GClient/Prototype/StationInteraction` | `GClient/Interaction/StationInteractionController` |
| `GClient/Prototype/SubtitleView` | `GClient/Interface/DialogueController` |
| `GClient/Prototype/TelevisionController` | `GClient/Effects/TelevisionController` |
| `GClient/Prototype/WorldInteraction` | `GClient/Interaction/WorldInteractionController` |
| `GClient/PrototypeController.local` | `GClient/Session/SessionController` |
| `GClient/Settings/SettingsAudio` | `GClient/Interface/SettingsAudio` |
| `GClient/Settings/SettingsController` | `GClient/Interface/SettingsController` |
| `GClient/Settings/SettingsView` | `GClient/Interface/SettingsView` |
| `GClient/Startup/GameController.local` | `GClient/Startup/Bootstrap.local` |
| `GClient/Telephone/ReceiverMotion` | `GClient/Effects/ReceiverMotion` |
| `GClient/Telephone/TelephoneCalls` | `GClient/Effects/TelephoneCalls` |
| `GClient/Telephone/TelephoneConfig` | `GClient/Effects/TelephoneConfig` |
| `GClient/Telephone/TelephoneController` | `GClient/Effects/PhysicalTelephoneController` |
| `GClient/Telephone/TelephoneInteraction` | `GClient/Effects/PhysicalTelephoneController` |
| `GServer/Anomalies/EventDirector` | `GServer/Horror/EventDirector` |
| `GServer/Anomalies/OutdoorRisk` | `GServer/Horror/OutdoorRisk` |
| `GServer/Anomalies/ThreatService` | `GServer/Horror/ThreatService` |
| `GServer/Bootstrap.server` | `GServer/Startup/Bootstrap.server` |
| `GServer/Containers/ContainerService` | `GServer/Interaction/ContainerService` |
| `GServer/Containers/DrawerContents` | `GServer/Interaction/DrawerContents` |
| `GServer/Core/AdmissionRules` | `GServer/Travel/AdmissionRules` |
| `GServer/Core/Config` | `GServer/Configuration/ServerConfig` |
| `GServer/Core/DataService` | `GServer/PlayerData/DataService` |
| `GServer/Core/Network` | `GServer/Networking/NetworkService` |
| `GServer/Core/PlayerView` | `GServer/PlayerData/PlayerView` |
| `GServer/Core/ProfileSchema` | `GServer/PlayerData/ProfileSchema` |
| `GServer/Core/ProfileStore` | `GServer/PlayerData/ProfileStore` |
| `GServer/Core/RateLimiter` | `GServer/Networking/RateLimiter` |
| `GServer/Core/SessionStore` | `GServer/PlayerData/ProfileStore` |
| `GServer/Core/TicketStore` | `GServer/Travel/TicketStore` |
| `GServer/Core/TravelService` | `GServer/Travel/TravelService` |
| `GServer/Customers/Conversations` | `GServer/Story/DialogueCatalog` |
| `GServer/Customers/PhoneSession` | `GServer/Repair/PhoneSoftware` |
| `GServer/Customers/PickupService` | `GServer/Orders/CustomerPickupService` |
| `GServer/Interactions/DrinkService` | `GServer/Interaction/DrinkService` |
| `GServer/Interactions/InteractionService` | `GServer/Interaction/InteractionService` |
| `GServer/Interactions/TagBindings` | `GServer/Interaction/TagBindings` |
| `GServer/Interactions/ThrowEffects` | `GServer/Interaction/ThrowEffects` |
| `GServer/Interactions/ThrowService` | `GServer/Interaction/ThrowService` |
| `GServer/Lore/LoreService` | `GServer/Story/LoreService` |
| `GServer/Lore/ShopSecrets` | `GServer/Story/LoreCatalog` |
| `GServer/Orders/OrderCatalog` | `GServer/Orders/BenchOrderCatalog` |
| `GServer/Orders/OrderStation` | `GServer/Orders/BenchOrderStation` |
| `GServer/Orders/OrderTestBench` | `GServer/Orders/BenchOrderTestBench` |
| `GServer/PhoneRepair/PhoneRepairService` | `GServer/Repair/PhoneRepairService` |
| `GServer/PhoneRepair/RepairMotion` | `GServer/Repair/RepairMotion` |
| `GServer/Prototype/AdmissionRules` | `GServer/Travel/AdmissionRules` |
| `GServer/Prototype/BenchTasks` | `GServer/Repair/BenchTasks` |
| `GServer/Prototype/Conversations` | `GServer/Story/DialogueCatalog` |
| `GServer/Prototype/CustomerCatalog` | `GServer/Customers/CustomerCatalog` |
| `GServer/Prototype/CustomerStories` | `GServer/Story/CustomerStories` |
| `GServer/Prototype/DevicePresentation` | `GServer/Repair/DevicePresentation` |
| `GServer/Prototype/DeviceRecords` | `GServer/Story/DeviceRecords` |
| `GServer/Prototype/DialogueService` | `GServer/Story/DialogueService` |
| `GServer/Prototype/EndingRules` | `GServer/Story/EndingRules` |
| `GServer/Prototype/EngagementService` | `GServer/Session/EmployeeService` |
| `GServer/Prototype/EventDirector` | `GServer/Horror/EventDirector` |
| `GServer/Prototype/GamePrototype` | `GServer/Session/GameService` |
| `GServer/Prototype/GameSession` | `GServer/Session/AdmissionSession` |
| `GServer/Prototype/LoreService` | `GServer/Story/LoreService` |
| `GServer/Prototype/ModeRules` | `GServer/Session/ModeRules` |
| `GServer/Prototype/OutdoorRisk` | `GServer/Horror/OutdoorRisk` |
| `GServer/Prototype/PhoneSession` | `GServer/Repair/PhoneSoftware` |
| `GServer/Prototype/PickupService` | `GServer/Orders/CustomerPickupService` |
| `GServer/Prototype/PrototypeConfig` | `GServer/Session/GameConfig` |
| `GServer/Prototype/PrototypeRuntime` | `GServer/Session/SessionService` |
| `GServer/Prototype/PrototypeStorage` | `GServer/World/StorageService` |
| `GServer/Prototype/PrototypeWorld` | `GServer/World/WorldService` |
| `GServer/Prototype/RepairFlow` | `GServer/Orders/OrderService` |
| `GServer/Prototype/RepairRoutine` | `GServer/Repair/RepairRoutine` |
| `GServer/Prototype/RepairStations` | `GServer/Repair/RepairStations` |
| `GServer/Prototype/RepairTasks` | `GServer/Repair/RepairTasks` |
| `GServer/Prototype/RepairTemplates` | `GServer/Repair/RepairTemplates` |
| `GServer/Prototype/ShiftActions` | `GServer/Session/ShiftActions` |
| `GServer/Prototype/ShiftClosing` | `GServer/Session/ShiftClosing` |
| `GServer/Prototype/ShiftDefinitions` | `GServer/Session/ShiftDefinitions` |
| `GServer/Prototype/ShiftService` | `GServer/Session/ShiftService` |
| `GServer/Prototype/ShiftSnapshot` | `GServer/Session/ShiftSnapshot` |
| `GServer/Prototype/ShiftStats` | `GServer/Session/ShiftStats` |
| `GServer/Prototype/ShopLayout` | `GServer/World/WorldLayout` |
| `GServer/Prototype/ShopPolicy` | `GServer/Story/GovernmentService` |
| `GServer/Prototype/ShopSecrets` | `GServer/Story/LoreCatalog` |
| `GServer/Prototype/ThreatService` | `GServer/Horror/ThreatService` |
| `GServer/Prototype/TicketStore` | `GServer/Travel/TicketStore` |
| `GServer/Prototype/TravelService` | `GServer/Travel/TravelService` |
| `GServer/Prototype/WorkPuzzles` | `GServer/Repair/RepairPuzzles` |
| `GServer/Prototype/Workshop` | `GServer/Repair/WorkshopService` |
| `GServer/Repair/RepairFlow` | `GServer/Orders/OrderService` |
| `GServer/Repair/WorkPuzzles` | `GServer/Repair/RepairPuzzles` |
| `GServer/Repair/Workshop` | `GServer/Repair/WorkshopService` |
| `GServer/Services/DialogueService` | `GServer/Story/DialogueService` |
| `GServer/Services/EngagementService` | `GServer/Session/EmployeeService` |
| `GServer/Services/GamePrototype` | `GServer/Session/GameService` |
| `GServer/Services/GameSession` | `GServer/Session/AdmissionSession` |
| `GServer/Shifts/EndingRules` | `GServer/Story/EndingRules` |
| `GServer/Shifts/ModeRules` | `GServer/Session/ModeRules` |
| `GServer/Shifts/PrototypeConfig` | `GServer/Session/GameConfig` |
| `GServer/Shifts/ShiftActions` | `GServer/Session/ShiftActions` |
| `GServer/Shifts/ShiftDefinitions` | `GServer/Session/ShiftDefinitions` |
| `GServer/Shifts/ShiftService` | `GServer/Session/ShiftService` |
| `GServer/Shifts/ShiftSnapshot` | `GServer/Session/ShiftSnapshot` |
| `GServer/World/PrototypeWorld` | `GServer/World/WorldService` |
| `GServer/World/ShopLayout` | `GServer/World/WorldLayout` |
| `GShared/Containers/ContainerConfig` | `GShared/Interaction/ContainerConfig` |
| `GShared/Interactions/InspectionFrame` | `GClient/Camera/InspectionFrame` |
| `GShared/Interactions/InteractionQuery` | `GShared/Interaction/InteractionQuery` |
| `GShared/Interactions/InteractionTags` | `GShared/Interaction/InteractionTags` |
| `GShared/Interactions/TVConfig` | `GClient/Camera/TelevisionViewConfig` |
| `GShared/Interactions/ThrowConfig` | `GShared/Interaction/ThrowConfig` |
| `GShared/Networking/Requests` | `GClient/Session/SessionRequests` |
| `GShared/PhoneRepair/RepairDefinition` | `GShared/Repair/RepairDefinition` |
| `GShared/PhoneRepair/RepairRig` | `GShared/Repair/RepairRig` |
| `GShared/Prototype/Definitions` | `GShared/Repair/RepairDefinitions` |
| `GShared/Prototype/SceneReferences` | `GShared/World/SceneReferences` |
| `GShared/Repair/BenchTaskView` | `GClient/Repair/BenchTaskView` |
| `GShared/Repair/Definitions` | `GShared/Repair/RepairDefinitions` |
| `GShared/Repair/PhysicalRepairTasks` | `GClient/Repair/PhysicalRepairTasks` |
| `GShared/Repair/PhysicalRepairView` | `GClient/Repair/PhysicalRepairView` |
| `GShared/Repair/PuzzleView` | `GClient/Repair/PuzzleView` |
| `GShared/Repair/RepairTaskView` | `GClient/Repair/RepairTaskView` |
| `GShared/Telephone/TelephoneConfig` | `GClient/Effects/TelephoneConfig` |
| `GShared/UI/FaxView` | `GClient/Effects/TelephoneController` |
| `GShared/UI/InspectionView` | `GClient/Interface/InspectionView` |
| `GShared/UI/PrototypeView` | `GClient/Interface/HUDController` |
| `LClient/QueueController.local` | `LClient/Matchmaking/QueueController` |
| `LClient/Queues/QueueController.local` | `LClient/Startup/Bootstrap.local` |
| `LClient/Queues/QueueRequests` | `LClient/Matchmaking/QueueRequests` |
| `LClient/Queues/QueueView` | `LClient/Interface/QueueView` |
| `LClient/Settings/SettingsAudio` | `LClient/Interface/SettingsAudio` |
| `LClient/Settings/SettingsController` | `LClient/Interface/SettingsController` |
| `LClient/Settings/SettingsView` | `LClient/Interface/SettingsView` |
| `LServer/Bootstrap.server` | `LServer/Startup/Bootstrap.server` |
| `LServer/Core/AdmissionRules` | `LServer/Travel/AdmissionRules` |
| `LServer/Core/Config` | `LServer/Configuration/ServerConfig` |
| `LServer/Core/DataService` | `LServer/PlayerData/DataService` |
| `LServer/Core/Network` | `LServer/Networking/NetworkService` |
| `LServer/Core/PlayerView` | `LServer/PlayerData/PlayerView` |
| `LServer/Core/ProfileSchema` | `LServer/PlayerData/ProfileSchema` |
| `LServer/Core/ProfileStore` | `LServer/PlayerData/ProfileStore` |
| `LServer/Core/RateLimiter` | `LServer/Networking/RateLimiter` |
| `LServer/Core/SessionStore` | `LServer/PlayerData/ProfileStore` |
| `LServer/Core/TicketStore` | `LServer/Travel/TicketStore` |
| `LServer/Core/TravelService` | `LServer/Travel/TravelService` |
| `LServer/Parties/PartyService` | `LServer/Matchmaking/PartyService` |
| `LServer/Queues/QueueBillboard` | `LServer/World/QueueBillboard` |
| `LServer/Queues/QueueGeometry` | `LServer/World/QueueGeometry` |
| `LServer/Queues/QueueWorld` | `LServer/World/LobbyWorldService` |
| `LServer/Queues/WorldQueueService` | `LServer/Matchmaking/QueueService` |
| `LServer/Runtime` | `LServer/Startup/Runtime` |
| `LShared/Geometry/QueueGeometry` | `LServer/World/QueueGeometry` |
| `LShared/Networking/QueueRequests` | `LClient/Matchmaking/QueueRequests` |
| `LShared/Queues/QueueDefinitions` | `LShared/Matchmaking/QueueDefinitions` |
| `LShared/UI/QueueBillboard` | `LServer/World/QueueBillboard` |
| `LShared/UI/QueueView` | `LClient/Interface/QueueView` |

Historical implementation details remain in IMPLEMENTATION_HISTORY.md. PrototypeRestoration.json retains original Git provenance with updated current destinations.
