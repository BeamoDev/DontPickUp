# Component boxes

The active system uses the hierarchy from the supplied screenshot:

```text
Workspace
  ComponentBoxes (Model)
    Box1 (Part or MeshPart)
    Box2
    Box3
    Box4
    Covers, Label1, etc. (authored assets left untouched)
ReplicatedStorage
  Assets
    SelectionHighlight (Highlight)
  GShared
    Containers
      ContainerConfig
    Prototype
```

Keep each moving Box anchored and CanQuery enabled. Keep the boxes in their closed positions before Play. Add the Container tag to the group Model. No PrimaryPart, click detectors or custom attributes are needed. Direct BasePart children named `Box` or `Box` followed by digits are recognized automatically.

Hover initially selects the whole Model tagged Container. Click any of its parts to smoothly move into a close-up showing the full set; that first click does not open a drawer. The camera uses the model pivot and bounds, with space for open drawers, and fits portrait screens. During this view the mouse is free and hovering selects individual Box parts. SelectionHighlight is cloned into the selected model or box with its authored styling preserved. `ReplicatedStorage.SelectionHighlight` also works; Assets.SelectionHighlight takes priority. The template itself is never moved or edited.

Once the camera finishes moving, click/tap a box to open it with a 0.35-second Quad InOut tween. It moves **0.8 studs toward negative world Z**, relative to that box's original position: `(14.317, 0.22, 34.989)` becomes `(14.317, 0.22, 34.189)`. Click again after the tween finishes to close it. Each drawer keeps its own starting position, and the camera stays still as drawers move. RT or E enters the aimed model; inside, D-pad left/right chooses a drawer and A/RT opens or closes it. World movement is server-owned so all players see it. Duplicate/stale clicks or clicks during movement do not invert an accepted transition.

Q, controller B or CLOSE VIEW exits. Movement, menus, typing, focus loss, death, respawn or model/camera removal also release the view and restore the saved camera and avatar visibility. Camera framing is local and mutually exclusive with the telephone. Shared ContainerConfig.CameraOffset, CameraSeconds and FieldOfView tune the shot; default is above the negative-Z opening side of the model. Reduced motion switches the shot immediately. Drawer positions are not reset by exiting.

Mouse activation happens on button press; touch still waits for a short release to distinguish taps from camera drags. Server visibility checks the center plus six face points, so a cover hiding only the center does not block the exposed front. Walls blocking all those points still reject the request. Rejections appear in client Output as `[DPU][Interactions] Click rejected: Box1 <reason>` instead of failing silently.

Existing first-person cursor behavior remains: aim/click, V releases the mouse, menus/typing/focus loss release it automatically. There is no new text hint or generated shop HUD. Future local modals can set PlayerGui's `DPU_ModalOpen` attribute while open to release the pointer and block box input.

**Welds:** the script preserves them. If a label should follow its box, weld that label to its own Box and leave the label unanchored. Do not weld the moving Box to stationary Covers or another Box. Check the WeldConstraint.Part0/Part1 values in the supplied models; the screenshot does not reveal those references. A label that covers the entire front should have CanQuery false so the ray can select the actual Box behind it. At least one tested face of the box must be visible from the player; a center-only obstruction is allowed. Check travel clearance and collisions in Studio.

## Sync and archive layout

Sync `GServer` into Game ServerScriptService, `GClient` into Game StarterPlayerScripts, and `GShared` into Game ReplicatedStorage.GShared, preserving their folder structure. Keep authored `ReplicatedStorage.Assets` outside GShared. Lobby files and mappings do not change.

```text
GServer/
  Bootstrap (Script)
  GameConfig, Runtime (ModuleScripts)
  Core/                         existing persistence/admission/networking
  Services/GameSession          actual game admission
  Containers/ContainerService   actual container behavior
  Prototype/                    archived gameplay/world/services
GClient/
  GameController (LocalScript)
  Interactions/TaggedInteraction
  Interactions/FirstPersonCamera
  Interactions/ModelInspection   container camera and restoration
  Prototype/                    archived controller and adapters
GShared/
  Containers/ContainerConfig    public distance/tween/offset settings
  Interactions/InspectionFrame  shared bounds fitting for containers and phone
  Prototype/                    archived Networking, UI and Repair
```

The archived PrototypeController remains a LocalScript inside GClient.Prototype but returns before loading its views. Active and prototype controllers do not run together. `GServer.GameConfig.PrototypeEnabled = false` selects the real container system. To preview the old prototype again, set true and restart Play. The active map needs its authored SpawnLocation; one already appears in the screenshot.

Use [SOURCE_CHANGES](SOURCE_CHANGES.md) to remove obsolete synced source copies after the move. Do not leave an old root PrototypeController running alongside the archived one. Stop/restart Play after syncing. Core and GameSession remain active; Studio uses existing practice data and published entry still requires Lobby admission.

## Checks

`tests/Containers.luau` checks model-first entry, camera framing/restoration, drawer selection, offsets, server rejection paths, competing clicks, cleanup, highlight cloning and mouse/touch/controller input with mocked Roblox services. Run all README suites and Core parity after source changes. Rendering, actual weld relationships, smoothness, streaming, mobile input and two-client behavior still require Studio tests. No place has been published by this change.
