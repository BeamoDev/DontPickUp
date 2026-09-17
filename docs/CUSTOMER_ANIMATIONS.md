# Customer models, names and animations

Put the authored rigs directly in `ReplicatedStorage.Assets.Characters.Female` and `.Male`. Each child Model needs at least one BasePart and a working Humanoid or AnimationController rig to animate. Duplicate model names are supported. Every valid model has an equal chance of being selected; the system draws from one combined list rather than picking a gender first. The old `Assets.NPC` hierarchy is used only if no valid Characters models are available.

The server selects the appearance once per order. Pickup, duplicate-customer story events and subtitles reuse its replicated appearance ID. Returning story customers retain their recorded appearance. Existing private customer catalogs assign the names and story identities; subtitles now display those names in faint orange, while the local player remains **You** in faint green. World customer Models also carry the ticket name and `DPU_CustomerName` attribute. No name billboard is generated.

`GShared/Customers/CustomerAnimations.luau` contains all 18 female and 12 male animations supplied by the owner. Both the server's CustomerActor and the client's DialoguePortrait use it. The Female/Male folder determines the animation set, also recorded in `DPU_AnimationGender` on prepared templates/clones. Legacy NPC rigs default to Male.

World customers randomly choose one walk and one idle for their visit. Arrival/departure use the chosen walk, and arrival completion returns to the idle. Animation transitions clean up replaced tracks. The authored `(90, 180, 0)` correction, calibrated +X forward direction and existing travel paths are preserved.

Optional attributes on a template select specific catalog entries:

- `CustomerWalkAnimation = "NormalWalking"` (or `Walking1`, `TuffWalking`, `Running`, etc., supported by that rig's catalog).
- `CustomerIdleAnimation = "HappyIdle"` (or `Idle`, `BoredIdle`, `Nervous`, `AngryIdle`, etc.).

Catalog keys remove spaces: `Dance1`, `Dance2`, `InjuredRunning`, `HeadNodAgree`. The supplied female **Tuff Walk** uses `TuffWalking` for consistency with the male key. Runs, injuries and dances are available for explicit authored actions, not randomly played during ordinary service. An unavailable key falls back to a matching-gender normal walk or happy idle.

Dialogue lines can choose `Animation = "HeadNodAgree"`, `"Angry"`, `"Nervous"`, or any other catalog key. Prototype lines preserve that selection; absent selections use HappyIdle. The authored order greeting retains its existing mood. Female portraits use the corresponding female IDs. The player's portrait still uses Roblox's default R6/R15 idle. Portrait camera properties and authored UI layout are unchanged.

Sync all three Game roots together. Nothing needs deleting from Workspace. Studio verification remains necessary: check permissions for the animation assets, rig/bone compatibility, foot sliding versus travel speed, both folder types walking to the window, idle on arrival, departure, matching named portraits, and consistent appearance for another player and customer pickup. Local tests validate selection, IDs, state transitions and cleanup, not animation rendering.

Customers selected from `Assets.Characters.Male.Cop` receive a stable Chief, Sheriff or Cop prefix on their generated name. Existing police titles are preserved without duplication. The server stores the titled name on the order so tickets, subtitles, world models and pickup calls agree. This is a display-name rule; it does not turn an ordinary customer into a government inspection.
