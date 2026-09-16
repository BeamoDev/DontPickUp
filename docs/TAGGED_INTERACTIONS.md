# Tagged world interactions

Add these exact, case-sensitive tags using Studio's Tags property or Tag Editor:

| Tag | Put it on | Click behavior |
| --- | --- | --- |
| `Drink` | A BasePart/MeshPart or the whole drink Model | Fade its parts and decals to Transparency 1 over 0.5 seconds, then destroy the tagged item for everyone. Opaque parts start at 0; authored transparency is preserved at the beginning of the fade. |
| `Fax` | The whole telephone Model | Open its existing relative camera view and physical keypad. |
| `Container` | The whole drawer-group Model | First click enters the view of all drawers; subsequent clicks open/close individual Box parts. |
| `throw` | A small BasePart/MeshPart or whole Model | Hold to grab/charge, release to throw with a short trail and particle burst. |

Use one interaction tag per root. Names and Workspace folder location no longer select the behavior. The nearest tagged ancestor owns a hit; a Drink inside a Container can be clicked in the container view. Keep hit surfaces CanQuery enabled. Fax and Container tags belong on Models, not individual keys/drawers. Direct container drawer children still use Box/Box1/Box2/etc names; fax key and screen names remain as documented in [TELEPHONE](TELEPHONE.md).

Hover uses a local clone of `ReplicatedStorage.Assets.SelectionHighlight`, with root ReplicatedStorage.SelectionHighlight as fallback. Its styling stays authored. Container/Fax camera state is local. Drinks and drawer movement are server-owned; consuming the same drink twice is rejected. No health, money or inventory effect is added. New drinks must be placed/cloned again if replenishment is wanted.

Tags can be added/removed during play. Tagged items become active when parented anywhere inside Workspace. Removal/untagging cancels unfinished motion; untagging a drink during its fade restores its original transparency. Rebinding issues new runtime identities so old clicks cannot affect a later registration. Removing Container/Fax while inspecting exits the camera view. Use Q/B or the close button to exit normally.

## Source and sync

`throw` uses the same central picker and server tag lifecycle; see [THROWING](THROWING.md) for controls, physics, limits and cancellation. Its tag is lowercase. ThrowService handles server holds and launches, ThrowInteraction handles local held input and the power meter, and ThrowEffects cleans up release cosmetics. Run tests/Throwing.luau with the interaction suites.

- `GShared/Interactions/InteractionTags`: tag definitions and nearest tagged ancestor resolution; DrinkSeconds and Distance tuning.
- `GClient/Interactions/TaggedInteraction`: central hover/click router for Drink, Fax and Container. Replaces `GClient/Containers/ContainerInteraction`.
- `GServer/Interactions/InteractionService`: central server entrypoint for tag binding and mutation dispatch.
- `GServer/Interactions/TagBindings`: event-driven tag/ancestry lifecycle, without scene polling.
- `GServer/Interactions/DrinkService`: validation, reservation, fade and deletion.
- Existing ContainerService and TelephoneInteraction retain their specialized drawer/keypad behavior.

Sync GClient, GServer and GShared together and remove the obsolete Containers/ContainerInteraction ModuleScript. Keep GameController as the sole active LocalScript. The prototype remains disabled and archived. Add the three tags to the authored Studio objects; no source script renames or tags assets automatically.

Run tests/TaggedInteractions.luau, tests/Containers.luau and tests/Telephone.luau plus existing suites. Tests cover renamed/nested/multiple models, tag changes, concurrent consumption, failed eligibility/distance/visibility checks, complete fade before deletion, camera/input regressions and cleanup with mocked Roblox. Visuals, authored welds, replication smoothness and device controls require Studio playtesting.
