# Current architecture

The active Game is the authored surveillance repair shop. `GServer/Session/GameConfig.Enabled = true` selects it; false selects the retained authored interaction/test-bench mode. Startup runs exactly one mode. Authored map, UI and asset names are unchanged. See [source migration](SOURCE_CHANGES.md) before syncing.

## Startup and dependencies

Each place has one server Bootstrap.server and one client Bootstrap.local under Startup. All other runtime files are ModuleScripts. Client GameController and QueueController start explicitly; requiring them does not connect events or start loops.

Game server Bootstrap creates common PlayerData/Networking services, then SessionService starts admission and GameService. GameService binds WorldService and ShiftService. ShiftService composes Session state/actions/snapshots with Orders, Repair, Horror and Story modules through explicit requires and dependencies. Gameplay validation, stock, private phone contents, narrative decisions and save outcomes stay on the server. Closing gives accepted orders 60 seconds and settles once.

Game client Bootstrap starts GameController, which waits for the selected server mode and starts settings plus SessionController. SessionController connects server snapshots/requests to Interface, Repair, Interaction, Effects and Camera. HUDController coordinates modal input; ShiftPanelController supplies the authored rules/death cards. CameraController owns cursor/first-person policy and InspectionCamera owns tweened inspections. The alternate mode uses the same camera and presentation helpers without running a second active stack.

Lobby server Bootstrap starts PlayerData/Networking/Travel and Matchmaking. QueueService owns membership/readiness/countdowns; PartyService owns parties. World/LobbyWorldService binds authored queue geometry/signs and server billboards. Lobby client Bootstrap starts Matchmaking/QueueController, which owns QueueRequests and Interface/QueueView plus settings. The Lobby UI keeps its authored geometry.

## Common package

`common/CommonServer` is the sole maintained source of Configuration, PlayerData, Networking and Travel infrastructure. `common/CommonClient/Interface` owns settings. `project.sources.json` maps these into both places' existing roots. Run `tools/SyncCommon.ps1` after common edits; tests verify all 26 deployment copies. Generated copies are necessary for direct Script Sync into two separate places. Shared contains only public definitions/geometry needed by both sides; no profile, private evidence, admission or unrevealed story content is replicated there.

## Current source tree

Every system contains scripts/modules only. Separate modules retain independent state/lifecycle responsibilities rather than being merged into large controllers.

```text
GClient/
  Camera/  CameraController.luau, ContainerViewConfig.luau, InspectionCamera.luau, InspectionFrame.luau, TelevisionViewConfig.luau
  Effects/  HorrorController.luau, PhysicalTelephoneController.luau, ReceiverMotion.luau, TelephoneCalls.luau, TelephoneConfig.luau, TelephoneController.luau, TelevisionController.luau
  Interaction/  CarryController.luau, CarryView.luau, InteractionController.luau, SelectionHighlight.luau, StationInteractionController.luau, WorldInteractionController.luau
  Interface/  AuthoredUI.luau, DialogueConfig.luau, DialogueController.luau, DialogueDemoController.luau, DialoguePortrait.luau, DialogueView.luau, HUDController.luau, InspectionView.luau, Mugshot.luau, OrderController.luau, OrderView.luau, SettingsAudio.luau, SettingsController.luau, SettingsView.luau, ShiftPanelController.luau
  Repair/  BenchTaskView.luau, DeviceTaskView.luau, PhoneRepairController.luau, PhysicalRepairTasks.luau, PhysicalRepairView.luau, PuzzleView.luau, RepairAssembly.luau, RepairDragController.luau, RepairPresentation.luau, RepairTaskView.luau, RepairViewConfig.luau
  Session/  SessionController.luau, SessionRequests.luau
  Startup/  Bootstrap.local.luau, GameController.luau
GServer/
  Configuration/  ServerConfig.luau
  Customers/  CustomerActor.luau, CustomerCatalog.luau
  Horror/  EventDirector.luau, OutdoorRisk.luau, ThreatService.luau
  Interaction/  ContainerService.luau, DrawerContents.luau, DrinkService.luau, InteractionService.luau, TagBindings.luau, ThrowEffects.luau, ThrowService.luau
  Networking/  NetworkService.luau, RateLimiter.luau
  Orders/  BenchOrderCatalog.luau, BenchOrderService.luau, BenchOrderStation.luau, BenchOrderTestBench.luau, CustomerPickupService.luau, OrderService.luau
  PlayerData/  DataService.luau, PlayerView.luau, ProfileSchema.luau, ProfileStore.luau
  Repair/  BenchTasks.luau, DevicePresentation.luau, PhoneRepairService.luau, PhoneSoftware.luau, RepairMotion.luau, RepairPuzzles.luau, RepairRoutine.luau, RepairStations.luau, RepairTasks.luau, RepairTemplates.luau, WorkshopService.luau
  Session/  AdmissionSession.luau, EmployeeService.luau, GameConfig.luau, GameService.luau, ModeRules.luau, SessionService.luau, ShiftActions.luau, ShiftClosing.luau, ShiftDefinitions.luau, ShiftService.luau, ShiftSnapshot.luau, ShiftStats.luau
  Startup/  Bootstrap.server.luau
  Story/  CustomerStories.luau, DeviceRecords.luau, DialogueCatalog.luau, DialogueService.luau, EndingRules.luau, GovernmentService.luau, LoreCatalog.luau, LoreService.luau
  Travel/  AdmissionRules.luau, TicketStore.luau, TravelService.luau
  World/  StorageService.luau, WorldLayout.luau, WorldService.luau
GShared/
  Customers/  CustomerAnimations.luau, CustomerTemplates.luau
  Interaction/  ContainerConfig.luau, InteractionQuery.luau, InteractionTags.luau, ThrowConfig.luau
  Repair/  RepairDefinition.luau, RepairDefinitions.luau, RepairRig.luau
  World/  SceneReferences.luau
LClient/
  Interface/  QueueView.luau, SettingsAudio.luau, SettingsController.luau, SettingsView.luau
  Matchmaking/  QueueController.luau, QueueRequests.luau
  Startup/  Bootstrap.local.luau
LServer/
  Configuration/  ServerConfig.luau
  Matchmaking/  PartyService.luau, QueueService.luau
  Networking/  NetworkService.luau, RateLimiter.luau
  PlayerData/  DataService.luau, PlayerView.luau, ProfileSchema.luau, ProfileStore.luau
  Startup/  Bootstrap.server.luau, Runtime.luau
  Travel/  AdmissionRules.luau, TicketStore.luau, TravelService.luau
  World/  LobbyWorldService.luau, QueueBillboard.luau, QueueGeometry.luau
LShared/
  Matchmaking/  QueueDefinitions.luau
```

## Detection and cameras

The previous picker passed raw pixels to ScreenPointToRay, which applies the GUI inset. ViewportPointToRay now matches raw input pixels. See Roblox's [camera API](https://create.roblox.com/docs/reference/engine/classes/Camera) and [input coordinate documentation](https://create.roblox.com/docs/reference/engine/classes/UserInputService#GetMouseLocation).

Queries resolve a Model's descendants and a Box's handle/label, skip eligible decoration, respect real occlusion, and compare reach to the part surface. Server-side geometry validation shares that policy. Intended hit surfaces must remain queryable; [Roblox raycasts](https://create.roblox.com/docs/workspace/raycasting) do not hit query-excluded parts. The exact engine mesh collision/query shape remains an asset-level Studio check.

One highlight stays parented to Workspace and changes Adornee, retaining authored styling. Deleted or unavailable targets clear it without deleting the highlight. Touch observes movement throughout the gesture, not merely final displacement. Consumed events, menus, text fields, interactive UI and local modal state block world input. Requests never retry a possibly accepted toggle/launch; the local request gate expires after eight seconds to avoid locking input indefinitely.

InspectionCamera captures native camera/FOV/subject and local character visibility once. It eases into the bounds-fitted view, blocks action until entry completes, and eases back before releasing camera ownership. The local character root is anchored before entry and restored to its previous anchor/AutoRotate state after return or interruption. Closing immediately relocks the mouse (respecting menus/text focus), while retaining camera/input ownership until the saved camera pose and FOV are restored. External character displacement translates the return path. Ordinary exits and interruptions tween; reduced motion and invalid/dead/replaced camera contexts release immediately. Viewport/model movement retargets with a tween; drawer travel does not reframe the cabinet.

## Studio verification

1. Stop Play. Sync all three roots for each place using the manifest, remove obsolete scripts, confirm exactly one Bootstrap and one client entrypoint per place, then restart. Game publishes PrototypeEnabled before the client creates any camera/HUD. Verify both switch settings separately; default true must reuse Workspace.Prototype.DPU_Prototype, StarterGui.DPU_PrototypeHUD/DPU_Cursor, HUD.Subtitles and ReplicatedStorage.Remotes, with no second shop/HUD or authored test bench.
2. Hover/click all edges and child meshes of Container, Fax, Drink, throw and tv. Test drawers through handles/Label parts. Check imported MeshPart CollisionFidelity/CanQuery and the authored Highlight on transparent objects.
3. Confirm non-collidable trim does not block keys/drawers, while collidable walls/terrain do. Test outside the eight-stud reach, behind UI, while typing, and across tags/removal/streaming. Do not make wall parts non-collidable/query-excluded.
4. On touch, test taps, drag away and back, two fingers, thumbstick plus camera, and two-tap carry/throw. Verify no accidental request or duplicate activation. Check keyboard and controller fallback.
5. Open and close all three views. Confirm smooth position/FOV in both directions, Q/B/button behavior, portrait resize, movement during return, death/respawn, menus/alt-tab and camera replacement. Tune imported TV/fax orientation in their client configs.
6. In two-player Studio testing verify drink reservation/fades, drawer and label movement, simultaneous grabs, held/released props, authored welds and visible throw physics. Profile the single hover query on a representative mobile scene; local tests do not measure frame time or network delay.
7. Check Lobby authored UI/signs and queues. Published Lobby teleports, profile migration and DataStore behavior require their own live verification. Prototype uses party admission for published joins and direct entry in Studio; authored mode loads players directly.

## Local validation

`tests/Run.ps1` runs all 30 active suites and compiles all retained Luau, checks static requires and exact source depth, and verifies common package deployment parity. Bootstrap tests execute both real entry scripts with mocked service constructors. The detection suite exercises bounded decoration skipping, walls, terrain, surface reach, pointer pixels, gestures, identity, UI, highlight reuse and event ownership. These checks establish source behavior, not Studio rendering or published readiness.

Phone repair authoring and validation are documented in [PHONE_REPAIR](PHONE_REPAIR.md). It uses exact `PhoneRepair` on the whole Model, separate from Fax.

GameController also creates the client-only DialogueController before waiting for gameplay networking. It binds the authored HUD.Subtitles, owns its viewport portraits/transitions, and runs the configurable ten-second demo. See [DIALOGUE](DIALOGUE.md).

## Customer/order integration

See [CUSTOMER_ORDERS](CUSTOMER_ORDERS.md). `OrderChanged` broadcasts ticket revisions and active conversation lines; `GetOrderState` supports late joins, and `ServeCustomer` accepts or returns the current server-owned order. There is one shared active order. Server validation includes exact repair binding/completion, range, visibility and employee state. Payments update the existing profile using an idempotent order receipt without completing a shift or counting a death. The ten-second dialogue test is disabled; portrait settings and authored subtitle geometry are preserved.

## Restored shift lifecycle

Preparation retains clock-in, directives and the guided first repair (`Tutorial` internally). `Night` opens normal orders and the existing event director. At dawn `Closing` disables intake, clears threats and grants accepted orders up to 60 seconds for repair/pickup/return. The last returned phone or the grace deadline settles `Results` once. Story continues through five nights; Endless continues through the existing mode rules. See [PROTOTYPE_RESTORATION](PROTOTYPE_RESTORATION.md) and the exact recovery mapping in `tests/PrototypeRestoration.json`.

## Saved prototype scene

The prototype binds the copied Studio map and UI instead of constructing them. See [PROTOTYPE_ASSETS](PROTOTYPE_ASSETS.md) for exact paths, retained descendants, dynamic-object ownership and Studio checks. Shared SceneReferences resolves the nested world. AuthoredUI binds fixed client controls; prototype SubtitleView delegates to the authored DialogueView, preferring DPU_PrototypeHUD.DialogueSubtitles with nested Frame content. HUD.Subtitles is a compatibility fallback. Existing viewport cameras are preserved; a missing camera uses DialogueConfig without requiring another ScreenGui.

## Current authored prototype integration

The saved HUD now uses `DPU_PrototypeHUD.Clock.Night/Time`; ShiftHeader and the screen FaxPhone view are no longer dependencies. `Effects/TelephoneController` adapts the existing TelephoneController/InspectionCamera/ReceiverMotion to server-owned ticket pickup requests, using `Workspace.Prototype.DPU_Prototype.Fax`. WorldInteraction delegates physical input and shares its fading authored Highlight; its single hover query runs after the camera. Active call state stays server-validated through PickupService. `Assets.NPC` is a folder of authored customer Models; server order selection persists an appearance ID into world actors and subtitle lines. The shared CustomerTemplates module exposes only asset lookup. See [asset contract](PROTOTYPE_ASSETS.md).

## Authored settings

Both existing client entrypoints start SettingsController. It binds the authored Settings frame without adding an opening flow, uses the existing SetSetting endpoint and schema-3 booleans, and applies local audio/camera preferences. Game publishes a separate local settings-modal flag to its active input/camera stack. Client copies are checked by SyncSettings. See [SETTINGS](SETTINGS.md).

PrototypeStorage binds the authored Storage Model using the existing container service. Its pickups resolve through public SceneReferences; secret stations are optional. See [PROTOTYPE_ASSETS](PROTOTYPE_ASSETS.md#storage-drawers-and-removed-notes).

Prototype TelevisionController delegates to InspectionCamera for the authored CRT Model and nested CRTScreen. WorldInteraction remains the input owner; television viewing is local and does not mutate gameplay or authored media.

The physical Fax also owns ringing-event interactions. Logical Phone/Answer stations share its model; the handset is a temporary Answer target only while ringing, then resolves to its parent Fax again. Standalone DeskPhoneBase/Receiver/Phone parts are optional legacy scenery with disabled input. Authored handset colors and geometry remain untouched.
