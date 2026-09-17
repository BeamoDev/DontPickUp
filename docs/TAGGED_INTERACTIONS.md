# Tagged world interactions

Add these exact, case-sensitive tags using Studio's Tags property or Tag Editor:

| Tag | Put it on | Click behavior |
| --- | --- | --- |
| `Drink` | A BasePart/MeshPart or the whole drink Model | Fade its parts and decals to Transparency 1 over 0.5 seconds, then destroy the tagged item for everyone. Opaque parts start at 0; authored transparency is preserved at the beginning of the fade. |
| `Fax` | The whole telephone Model | Open its existing relative camera view and physical keypad. |
| `Container` | The whole drawer-group Model | First click enters the view of all drawers; subsequent clicks open/close individual Box parts. |
| `throw` | A small BasePart/MeshPart or whole Model | Click/tap to carry, then click/tap again to throw with a small red trail. |
| `tv` | The whole television Model | Move into a level viewing shot; Q/B or STOP WATCHING returns to normal play. |

Use one interaction tag per root. Names and Workspace folder location no longer select the behavior. The nearest tagged ancestor owns a hit; a Drink inside a Container can be clicked in the container view. Keep hit surfaces CanQuery enabled. Fax and Container tags belong on Models, not individual keys/drawers. Direct container drawer children still use Box/Box1/Box2/etc names; fax key and screen names remain as documented in [TELEPHONE](TELEPHONE.md).

Hover uses a local clone of `ReplicatedStorage.Assets.SelectionHighlight`, with root ReplicatedStorage.SelectionHighlight as fallback. Its styling stays authored. Container/Fax camera state is local. Drinks and drawer movement are server-owned; consuming the same drink twice is rejected. No health, money or inventory effect is added. New drinks must be placed/cloned again if replenishment is wanted.

Tags can be added/removed during play. Tagged items become active when parented anywhere inside Workspace. Removal/untagging cancels unfinished motion; untagging a drink during its fade restores its original transparency. Rebinding issues new runtime identities so old clicks cannot affect a later registration. Removing Container/Fax while inspecting exits the camera view. Use Q/B or the close button to exit normally.

## Source and sync

`tv` is lowercase and camera-only. It reuses InspectionCamera and the central picker without a server request. The shot fits the whole model, including portrait screens, and views it from its local -Z side. Adjust GClient/Camera/TelevisionViewConfig.CameraOffset if an imported TV's front faces another direction. Walking, menus, typing, focus loss, death/respawn, removal/untagging and teardown restore the camera and avatar visibility. Existing screen/video/sound content is untouched. Sync GClient and GShared together; run tests/Television.luau with the existing interaction suites.

`throw` uses the same central picker and server tag lifecycle; see [THROWING](THROWING.md) for controls, physics, limits and cancellation. Its tag is lowercase. ThrowService handles server holds and launches, ThrowController handles local held input and the carry hint, and ThrowEffects cleans up release cosmetics. Run tests/Throwing.luau with the interaction suites.

- `GShared/Interaction/InteractionTags`: tag definitions and nearest tagged ancestor resolution; DrinkSeconds and Distance tuning.
- `GClient/Interaction/InteractionController`: central hover/click router for Drink, Fax and Container. Replaces `GClient/Containers/ContainerInteraction`.
- `GServer/Interaction/InteractionService`: central server entrypoint for tag binding and mutation dispatch.
- `GServer/Interaction/TagBindings`: event-driven tag/ancestry lifecycle, without scene polling.
- `GServer/Interaction/DrinkService`: validation, reservation, fade and deletion.
- Existing ContainerService and TelephoneController retain their specialized drawer/keypad behavior.

Sync GClient, GServer and GShared together and remove the obsolete Containers/ContainerInteraction ModuleScript. Keep GameController as the sole active LocalScript. There is no prototype startup path. Add the tags to the authored Studio objects; no source script renames or tags assets automatically.

Run tests/TaggedInteractions.luau, tests/Containers.luau and tests/Telephone.luau plus existing suites. Tests cover renamed/nested/multiple models, tag changes, concurrent consumption, failed eligibility/distance/visibility checks, complete fade before deletion, camera/input regressions and cleanup with mocked Roblox. Visuals, authored welds, replication smoothness and device controls require Studio playtesting.

## Detection policy

One `SelectionHighlight` instance is shared by world selection and fax keys. It stays under Workspace, with Adornee switched to the target; target destruction cannot destroy the clone. The template remains unchanged. `InteractionController` owns all click/tap/key input and one post-camera hover query. It routes a phone event exclusively to TelephoneController, including close events.

Raw screen coordinates use ViewportPointToRay (no extra GUI inset). Center-locked mouse/controller use viewport center. Hit ancestors resolve tagged roots. Drawer descendants and matching Label parts resolve the owning Box; a phone key's descendants resolve its named key part. Nearby checks use the hit surface on the client and nearest surface on the server.

`InteractionQuery` skips **untagged non-collidable** decoration; while inspecting a model it can also skip non-collidable trim belonging to that model. Collidable parts, terrain and unrelated tagged items block. A maximum of 12 ray hits fails closed if exhausted. Author intended target surfaces with CanQuery enabled. Author wall occluders with CanQuery and CanCollide enabled; arbitrary opaque non-collidable walls cannot be inferred from their appearance. For query-excluded decoration, Roblox requires CanCollide false for CanQuery false to take effect. No mesh, collision, tag or visibility property is silently rewritten by the client.

UI controls/active panels, menus, typing and DPU_ModalOpen block world hits. Touch input records movement during the whole gesture: more than 18 pixels, a second finger, a stale target identity or release after 0.6 seconds cancels a tap. Input release never repeats mouse activation. Throw touch uses two separate intentional taps. Gameplay requests remain server-validated; hover emits none. Changed carry aim sends bounded unit directions only, at most 20 updates per second.

All three camera views share entry/return FOV and CFrame tweens in InspectionCamera. Run `tests/Run.ps1`; see the complete [Studio checklist](CURRENT_ARCHITECTURE.md#studio-verification).

The shared SelectionHighlight now fades fill and outline to their authored opacity in 0.14 seconds and out in 0.10 seconds. Switching targets fades the previous adornment fully before reusing the same Highlight. Brief misses reverse the current fade; repeated hover updates do not restart it. World, container, fax and repair paths all clear through the shared owner. Teardown cancels pending tweens and completion connections.
