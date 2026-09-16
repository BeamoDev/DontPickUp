# Grab, charge and throw

Add the exact lowercase **`throw`** tag to a small BasePart/MeshPart or whole Model. The central tag router supplies the same authored SelectionHighlight as Drink/Fax/Container. Names and Workspace nesting do not matter.

Hold left mouse on the prop to grab it in front of your character. A small power bar fills over **1.5 seconds**. Release to launch toward your aim; a quick click tosses gently, a full charge throws harder. Touch holds until that same finger releases; controller RT and keyboard E also support press/hold/release. Q/B cancels. Close container/fax inspection before grabbing.

The server chooses speed from its own elapsed hold time: **28 to 90 studs/second**, capped at full charge. Each player holds at most one prop and each prop has at most one holder. Token-scoped releases/cancels cannot affect later grabs. Admission, living/standing state, proximity, visibility, finite unit aim and rate checks remain required. Input sends one grab and one release/cancel; the client never sends charge, force, velocity or streamed positions.

While held, the prop temporarily anchors and follows the character, without collisions. One server Heartbeat connection exists only while any prop is held. Release unanchors the prop, restores authored collision flags and launches it with gravity and collisions. A short pale trail, a small 6–12 particle burst and a tumble accompany release, then effects clean themselves up. Temporary NoCollisionConstraints ignore the thrower's body while preserving world collisions. Loose model parts receive owned welds; authored welds are preserved. Props stay in the world and can be grabbed again. No damage, score or automatic respawn is added.

Menus, typing, focus loss, death, respawn, seating, removal/untagging and teardown cancel. Cancel restores the pre-grab position/pivot and collision/anchor flags. A 12-second server limit recovers missing release requests. A wall obstructing the holding position cancels the grab. Ordinary walking/aiming stays available while holding.

Use a separate small prop, not something welded to a cabinet/character. Bounds are 32 BaseParts and a bounding-size vector magnitude of 8 studs. External rigid connections are rejected. Hit surfaces must be queryable. Apply one interaction tag to the intended whole item. Props may start anchored; a successful throw deliberately makes them physical.

## Source and checks

Sync GClient, GServer and GShared together. New ModuleScripts:

- GShared/Interactions/ThrowConfig: charge, speeds, hold position, range and size limits.
- GClient/Interactions/ThrowInteraction: held input, charge meter callbacks and early-release/late-reply handling.
- GServer/Interactions/ThrowService: validation, reservation, positioning and launch.
- GServer/Interactions/ThrowEffects: owned trail, particles and temporary thrower collision filtering.

Existing InteractionTags, TaggedInteraction, InteractionService, Bootstrap and GameController connect the behavior centrally. Physics ownership and initial velocity follow [Roblox BasePart assembly APIs](https://create.roblox.com/docs/reference/engine/classes/BasePart).

Run tests/Throwing.luau, TaggedInteractions, Containers, Telephone and existing suites. Mock tests cover validation, charge caps, competing grabs, token replays, tag removal, timeout, model cancellation, effect cleanup, mouse/touch/controller input and cancellation before grab replies. Actual physics, rendered hold position, particles and multiplayer smoothness need Studio/device playtesting.
