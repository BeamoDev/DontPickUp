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
```

Keep each moving Box anchored and CanQuery enabled. Keep the boxes in their closed positions before Play. Add the Container tag to the group Model. No PrimaryPart, click detectors or custom attributes are needed. Direct BasePart children named `Box` or `Box` followed by digits are recognized automatically.

Hover initially selects the whole Model tagged Container. Click any of its parts to smoothly move into a close-up showing the full set; that first click does not open a drawer. The camera uses the model pivot and bounds, with space for open drawers, and fits portrait screens. During this view the mouse is free and hovering selects individual Box parts. A pooled SelectionHighlight stays under Workspace and adorns the selected model or box with its authored styling preserved. `ReplicatedStorage.SelectionHighlight` also works; Assets.SelectionHighlight takes priority. The template itself is never moved or edited.

Once the camera finishes moving, click/tap a box to open it with a 0.35-second Quad InOut tween. It moves **0.8 studs along the cabinet Model's local -Z direction**, transformed by its pivot rotation when bound. Rotating the entire cabinet before Play rotates the slide direction too; each imported drawer mesh can keep its own orientation. Click again after the tween finishes to close it. Each drawer keeps its own starting position, and the camera stays still as drawers move. RT or E enters the aimed model; inside, D-pad left/right chooses a drawer and A/RT opens or closes it. World movement is server-owned so all players see it. Duplicate/stale clicks or clicks during movement do not invert an accepted transition.

Q, controller B or CLOSE VIEW exits. Movement, menus, typing, focus loss, death, respawn or model/camera removal also release the view and restore the saved camera and avatar visibility. Camera framing is local and mutually exclusive with the telephone. Client Camera/ContainerViewConfig tunes the shot; default is above the negative-Z opening side of the model. Reduced motion switches the shot immediately. Drawer positions are not reset by exiting.

Mouse activation happens on button press; touch still waits for a short release to distinguish taps from camera drags. Server visibility checks the nearest surface, center and six face points, so a cover hiding only the center does not block the exposed front. Walls blocking all those points still reject the request. Rejections appear in client Output as `[DPU][Interactions] Click rejected: Box1 <reason>` instead of failing silently.

Existing first-person cursor behavior remains: aim/click, V releases the mouse, menus/typing/focus loss release it automatically. There is no new text hint or generated shop HUD. Future local modals can set PlayerGui's `DPU_ModalOpen` attribute while open to release the pointer and block box input.

**Matching labels:** each direct Label1/Label2/etc BasePart or MeshPart follows its matching Box1/Box2/etc in the same tagged Model, with identical duration/easing and a -0.8 world-Z offset from its own original CFrame. Closing restores its original position and rotation. Independent labels tween explicitly; loose labels are anchored for stable movement and their original anchoring is restored on unbind. An unanchored label already welded to its matching Box follows that weld without a conflicting second tween. Missing labels do not block drawers. Unbinding cancels both animations and restores closed positions.

**Welds:** authored welds are preserved. Do not weld a moving Box/Label to stationary Covers or another Box. A matching Label surface or Box descendant selects the owning Box, and the server recognises the same surface association. At least one tested face of the box must be visible from the player; a center-only obstruction is allowed. Check travel clearance and collisions in Studio. `tests/ContainerLabels.luau` covers paired movement and cancellation with mocks.

## Sync and checks

Sync the three Game roots using [SOURCE_CHANGES](SOURCE_CHANGES.md). `GClient/Startup/GameController` is the client entrypoint; `GClient/Interaction/InteractionController` picks/routes; `GClient/Camera/InspectionCamera` owns smooth entry/return camera and FOV; `GServer/Interaction/ContainerService` owns movement and validation. Public motion/authoring rules are in GShared/Interaction/ContainerConfig, client camera framing in GClient/Camera/ContainerViewConfig.

No prototype flag or world generator is active. Preserve authored spawn/models/assets. Run `tests/Run.ps1`, including Containers and ContainerLabels. Source mocks cover the control flow and tween goals; Studio must verify imported mesh hitboxes, camera fit, queryable labels, collisions, welded movement, mobile gestures and multiplayer visuals.
