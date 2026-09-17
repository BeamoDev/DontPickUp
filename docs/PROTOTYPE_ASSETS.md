# Authored prototype assets

The current surveillance-shop direction reuses these same authored assets. See [SHOP_DIRECTION](SHOP_DIRECTION.md) for optional ServiceSticker authoring and [WORKSPACE_CLEANUP](WORKSPACE_CLEANUP.md) for safe deletions. No new fixed map/UI is required.

Prototype remains enabled. The map and fixed UI now come from the saved play-session copy in Studio. Runtime code no longer builds a shop, seats, phone template, HUD, cursor, scare viewport or fixed puzzle controls. Missing required objects produce a path-specific error rather than a replacement map/UI.

```text
Workspace
  Prototype
    DPU_Prototype                 saved shop, stations, phones, seats and markers
      Fax                         authored Model with physical keypad/screen/Phone handset
    DPU_InteractFocus             Highlight (optional)
    DPU_RepairFocus               Highlight (optional)
ReplicatedStorage
  Assets
    NPC                          Folder of authored customer Models (names may repeat)
    Devices
      Phone                      authored device Model; all current orders use this
  Remotes
    Request                      RemoteFunction
    StateChanged                 RemoteEvent
StarterGui
  Crosshair                      ScreenGui, containing Frame (cursor dot)
  HUD                            ScreenGui
    Clock                        Frame, authored top-left position
      Night                      TextLabel
      Time                       TextLabel
    Frames                       Briefing, ClockIn, TonightsRules, ShiftComplete, GameLost, Settings
    Scare                        Frame
      Impact                     Sound
      ShopAnomaly                Sound
      Caption                    TextLabel
      Visitor                    ViewportFrame
        Camera                   authored Camera (position/angle preserved)
        ScaryNPC                 authored monster Model, with RootPart and rig joints/bones
    Dialogue                     authored subtitle card
      Frame
        CharacterViewPort
          ViewportFrame          reuse existing Camera if present
        Title
        Paragraph
  DPU_PrototypeHUD                remaining saved repair controls
```

`SceneReferences` is the shared path contract. `PrototypeWorld` binds the saved world and existing prompt callbacks. `AuthoredUI` binds saved controls and releases them without destroying them; the old unnamed sibling controls are claimed once in their saved sibling order. Keep those sibling groups intact. Styles and fixed layout remain authored; state-driven text, visibility, progress and puzzle-piece positions still update during play.

The server binds **Remotes.Request/StateChanged** and announces the active network root through `ReplicatedStorage.DPU_GameNetwork`. Lobby networking is unchanged. Sync all three Game roots together and retain one Game bootstrap and one Game client entrypoint. Prototype remains selected by `GServer.Prototype.GameConfig.Enabled = true`.

## Keep these world objects

Inside `DPU_Prototype`, retain `ShopFloor`, `StaffSpawn`, `ObservationDeck`, `StaffDoor`, `Timeclock` and `TimeclockStamp`, the stations listed in `ShopLayout.Access` (logical Fax/Phone/Answer all resolve to the same Fax Model; secret stations are optional), `EmployeeBoard.EmployeeStatus`, the three `VoteREPORT/HIDE/INVESTIGATE` markers, and the saved lighting objects. Retain the station `Interact` prompts and `DPU_Direct` attributes. Each bench must retain its `RepairFocus` and `RepairCamera` attachments.

Keep `Bench`, `Bench2`, `Counter`, `RepairSeat`, `Bench2Seat`, `ReplacementTray` and `ReplacementTray2`. The four phone placement Models are optional: runtime copies of Assets.Devices.Phone can be positioned directly on these furniture surfaces. Existing legacy anchors are still honored, detached during play and restored on teardown. Seats, trays and bench camera attachments are reused unchanged. Source device meshes, keys, wires and SIM tray remain authored.

The original layout's local origin is inferred from `ShopFloor.CFrame`, allowing the whole shop to be translated/rotated together. The fixed room/access bounds remain in `ShopLayout`. If changing individual room geometry, update those bounds too. Optional CFrame attributes `StaffDoorClosed` and `StaffDoorOpened` on `DPU_Prototype` override the old door poses, including for a remodelled doorway. A copied open door is reset to the closed pose for a fresh shift.

Stale customer/threat models with the prototype's runtime names are detached while the new shift runs and restored on teardown. Only newly spawned customers, carried tools, repair previews/task pieces and effects are runtime-owned. Customers clone a random valid Model from `Assets.NPC` when an order is created. A server-assigned `DPU_AppearanceId` distinguishes even duplicate model names and remains on arrival, return and customer speech. Runtime copies strip scripts/tags and reuse authored rig geometry. No fallback customer body or customer billboard is generated. Optional Vector3 `CustomerRotation` on each source Model overrides the default authored rotation `(90,180,0)`; the corrected rig faces +X at that base pose. World movement turns this calibrated heading toward the route in the horizontal plane, including departures, while preserving floor height. Test imported rig orientation and animation permissions in Studio. Optional `RepairWire` and `ScareSound` templates now live in `ReplicatedStorage.Assets`.

## Clock and physical telephone

There is no `ShiftHeader` requirement. `Clock.Night` and `Clock.Time` receive state text without changing their authored layout/text sizing. Tap Night (or press Tab / controller Select) to reopen shift information. Time/T opens team signals only when the optional legacy TeamSignals still exists. HUD.Clock is preferred; legacy DPU_PrototypeHUD.Clock remains a fallback. HUD.Objective.Frame is preferred for objective text (Use is optional); legacy Objective remains supported. Puzzle controls still use DPU_PrototypeHUD.

Pickup uses `Workspace.Prototype.DPU_Prototype.Fax`, not the old `FaxPhone` screen panel. The model needs `Key0` through `Key9`, `KeyClear`, `KeyClose`, `Dial`, `End` and `InputArea.SurfaceGui.Frame.TextLabel`. `Key*` and `Key#` retain their existing physical mapping but pickup requires six numeric digits. `Phone` is the receiver mesh/model. Keep intended surfaces queryable; real walls must remain collidable/queryable.

Click/tap any intended model part to enter the existing inspection camera. Ready ticket numbers appear on its screen; enter a number and press Dial. The same server-owned pickup session validates admission, living/standing state, distance, line of sight, six-digit ticket and completed repair. Digits stay local; one Dial sends one request. Accepted calls raise the receiver and show the pickup response. End hangs up; KeyClose or Q/B exits, relocks the pointer and tweens back to the saved camera before restoring movement. Late replies cannot reopen dismissed visits. One central input controller delegates to the telephone and shares the fading saved highlight. No screen keypad UI is constructed.

Remove the obsolete deployed `GClient.Prototype.FaxView` ModuleScript on sync; its replacement is `PickupTelephone`. The unused authored FaxPhone panel is no longer required. Keep the authored Fax Model. The standalone DeskPhoneBase, Receiver and Phone props are no longer required and may be deleted after syncing. Do not delete Fax.Phone, the actual handset. During a ringing event, click the Fax body to silence it or its Phone handset to open the existing forbidden-answer confirmation. Both event actions use the same server range and wall checks as pickup calls. Normal dialing returns after the event; authored handset colors are preserved.

## Subtitles and cleanup

Server dialogue prefers `HUD.Dialogue`, with Title, Paragraph and CharacterViewPort.ViewportFrame optionally inside Frame. Older `DPU_PrototypeHUD.DialogueSubtitles` and `HUD.Subtitles` cards remain fallback locations. Both unused cards are suppressed when the migrated card is present, and are safe to delete after moving the card into HUD. You uses the local avatar and faint green title; customer lines use that order's selected `Assets.NPC` model and faint orange. Authored text sizing, card size and any existing viewport Camera CFrame/FOV are preserved. If the ViewportFrame has no Camera, the portrait system creates its own camera using the owner-configured DialogueConfig pose/FOV and removes it on teardown. Speaker changes use the existing fade/slide transition. Expired or blocked lines stop their render callback. The fixed ScreenGuis stay through respawns while bound.

`HUD.Scare.Visitor.ScaryNPC` is the authored monster source. ScareActor creates one pooled animated copy in a WorldModel, keeping the authored rig transform, textures and camera pose. Only the root is anchored; internal joints/bones can animate. The source is restored on teardown. An AnimationController/Animator is supplied inside the runtime rig if needed, including when the saved controller sits outside ScaryNPC. All six supplied Monster 2 clips are stored in GClient/Effects/MonsterAnimations; one is chosen per fresh scare, with no immediate repeat. Tracks are cached and stopped between scares.

The viewport camera's FOV eases to 70% of its authored FOV over 2.5 seconds; the viewport fades during the last 0.4 seconds. Clear restores its starting FOV. No camera-position lunge is applied to the new rig and Workspace.CurrentCamera is never touched. Reduced motion uses the existing silent caption and cancels active animation/zoom. Existing server damage, scare IDs, stale-snapshot rejection and menu interruption rules remain unchanged.

Visitor supports a missing Camera by creating a temporary local one, but keep the saved Camera for the intended framing. Legacy DPU_PrototypeHUD.Scare with its Part head remains supported. On teardown, borrowed cameras and the original viewport reference are restored, and only runtime-owned cameras/worlds/tracks are destroyed. Animation ownership/experience permissions and rig compatibility require Studio verification.

Shutdown disconnects callbacks and restores captured GUI/scene state, lighting time, player spawn settings and camera ownership. It preserves the saved shop, seats, template, remotes, HUD and highlights.

## Studio verification

Run `tests/Run.ps1` for all 30 suites, compilation/layout/import checks and Core parity. Fixed map/UI constructor tests reject replacement UI/geometry creation; ScarePresentation may create one runtime Camera when the saved viewport has none, plus an owned WorldModel and animation host for the supplied monster. The fixture files in `tests/fixtures/prototype` were captured from the former builders and are test-only data, never a runtime fallback. Local tests cannot inspect the descendants hidden in the supplied screenshots.

After syncing, check Output for any missing authored path. Verify one shop/HUD/cursor, the top-left Night/Time labels, random customer rigs with matching subtitle portraits and pickup appearances, both seats and cameras, physical telephone digits/Dial/End/KeyClose, wall/range rejection, timeclock, repair controls, dawn closing/results/replay, respawn and teardown. Test with two players and touch/controller input. Keep the full saved HUD contents; do not remove individual fixed puzzle panels simply because they start hidden. No live Studio or published-place validation is implied by the local fixtures.

## Storage drawers and removed notes

The current stock pickups are direct children of `Workspace.Prototype.DPU_Prototype.Storage`:

| Pickup part | Sliding drawer |
| --- | --- |
| `Part_BatteryBox1` | `Box1` |
| `Part_KeypadBox2` | `Box2` |
| `Part_SpeakerBox3` | `Box3` |

Storage is a Model. Anchor/query-enable the boxes and query-enable the pickups. Click/tap a box or its matching Label to open it, then take the visible stock part when the drawer finishes moving. Labels and pickup surfaces travel 0.8 studs along the Storage Model pivot's local negative Z in 0.35 seconds, preserving their authored offsets and rotations. Close returns all three to their original locations. Existing loose welded pickups follow their box without an extra competing tween; no new welds are created. Covers remain unchanged.

PrototypeStorage reuses ContainerService through the existing prototype input and request path. The server checks the loaded/admitted employee, living/standing state, rules, shift, range, obstruction, drawer identity and revision. Collect still uses the existing order/stock/carried-part validation, and now also checks that the stock drawer is open, stationary and reachable. Objective highlights resolve the moved pickup, highlighting its drawer while closed. There is no second interaction/camera stack.

Absent `Secret_*` parts and `Tool_BrassKey` no longer block startup. The daily directive stays available in the existing rules UI. No lore assets are regenerated and no story/profile data is erased. Old layouts without Storage still support root-level `Part_Battery`, `Part_Keypad`, `Part_Speaker`.

Studio check: restart with all notes removed; open and close each box; confirm its label and pickup stay aligned; take each required part; test multiplayer simultaneous clicks, closed drawers, walls and shutdown. Local tests cover the authored hierarchy and these state/validation paths; visual motion and replication still need Studio.

## CRT television

The active television is `Workspace.Prototype.DPU_Prototype.CRT` (Model), with direct children `Monitor`, `CRTScreen` (BasePart/MeshPart) and your other authored TV pieces. The old root-level CRTScreen is not required. `SceneReferences.Television` resolves the model and nested screen; PrototypeWorld gives the whole model one direct interaction identity. No tag is required in Prototype mode. Keep visible clickable surfaces queryable.

Click/tap a visible TV part to watch. The existing InspectionCamera anchors the player before entry, frames CRTScreen from its local -Z face, tweens CFrame/Focus/FOV, and restores the saved camera and character state on exit. Q/B or a short click/tap closes. A touch drag does not close the view. Mouse lock returns when exit begins; input ownership lasts until the return finishes. Menus/settings, work, death, model/screen removal and teardown interrupt viewing through the same camera cleanup. The authored ObjectAction hint provides the close instruction; no new GUI or gameplay remote is created.

TV input is delegated by the existing WorldInteraction controller. The alternate authored mode still uses its lowercase `tv` tag as before. Authored screen UI, media, geometry and the other child parts are preserved. Verify framing against the imported screen's actual front face and test touch/controller in Studio.

## Customer Phone device

Every current customer order uses `ReplicatedStorage.Assets.Devices.Phone`, including both bench and counter copies. Keep its `Phone`, `Screen`, `Battery`, `BackCover`, `Screws.Screw1` through `Screw4`, and authored Keys/Pipes/Wires/SimTray. Runtime copies are anchored for repair; source parts and joints are never changed. Customer arrivals carry a copy; counter handover hides it, and departing pickup customers receive it. An optional `DeviceGrip` Attachment on customer rigs controls the carried pose; otherwise a hand/root fallback is used.

The screenshot layout without `RepairPhone`, `RepairPhone2`, `CounterPhone_Bench`, and `CounterPhone_Bench2` is supported. `DevicePlacement` puts runtime phone bodies just above Bench/Bench2, and separates the two counter phones along Counter's longest horizontal dimension. It does not create fixed anchors or rebuild map/UI. For precise placement, optionally add these **Attachments** (their WorldCFrame positions specify the phone body center):

- `Bench.RepairPhoneMount`
- `Bench2.RepairPhone2Mount`
- `Counter.CounterPhone_BenchMount`
- `Counter.CounterPhone_Bench2Mount`

Existing root-level Parts/Models with the old four names take precedence over mounts and remain restored on teardown. Keep `RepairFocus` and `RepairCamera` on both benches. Imported mesh placement and camera coverage still need Studio inspection.

Walls may live under `Building`, and ceiling lights under `Building.Lighting`. Lights there participate in blackout control; named CeilingLight fixtures elsewhere remain supported. The existing root-level stations shown in the owner's screenshot stay at the root. Server station checks retain room gates and use queryable visible surfaces, distance and real wall occlusion. Shelter remains a containment volume.

A failed world bind now restores saved scene attributes, destroys runtime phones and cancels owned connections/tweens. Admission folders and travel listeners are also released when Game construction fails, allowing a corrected startup to retry.

The active simple repair starts with four screws, cover removal and battery removal, followed by diagnosis. Collect the faulty Battery/Speaker/Keypad through the existing Storage pickups. Speaker and keypad component art comes from those pickup parts when absent from the device. Optional `SpeakerMount` / `KeypadMount` Attachments anywhere inside the source Phone set their installed poses; absent mounts use a small internal default. The source Keys group stays intact. Keyboard replacements continue to use the existing Keypad stock name.

A battery replacement is fitted directly because the old battery is already out. Other faults require removing and fitting the failed component, then reinstalling the original battery. Cover and four screws follow. Software/private-record choices, final test, pickup calls and rewards keep their existing validation. Physical gestures use the actual component meshes and authored sockets; controller/button fallback sends the same revision-scoped inputs. Committed part motion is server replicated. Cancelling a task resets its uncompleted stage sequence; finished job stages remain in the order.

Studio checks: verify mesh back-face orientation at both placement anchors, camera coverage of loose parts, screw/cover/battery drag targets, SpeakerMount/KeypadMount defaults, customer grip pose, and another player's view of accepted movements. Test all three faults, leaving/re-entering a bench, interruption, customer return and source-model preservation. Local mocks do not verify imported mesh hitboxes, animation/physics or camera rendering.


## Optional highlight helpers

`Workspace.Prototype.DPU_InteractFocus` and `DPU_RepairFocus` no longer block client startup. Each presentation controller reuses a saved Highlight when present, preserving its authored style and restoring it on teardown. Otherwise it creates one temporary local Highlight with the existing defaults and deletes only that owned effect on teardown. There is no 30-second wait for these effects, no new input/render loop, and no generated map or HUD. Keep the real bench `RepairFocus` / `RepairCamera` Attachments; these are different from the optional Highlight named `DPU_RepairFocus`.


## Repair controls and diagnostics

The authored phone keeps physical screw, cover and battery gestures. Screw selection uses small circular targets (0.055-0.12 stud radius) without the old padded rectangle, projected at the mesh's actual height. Four local BillboardGui rings show each screw with a rotating marker; turning advances the marker and completed screws hide it. The existing repair render connection updates the rings, and reduced motion stops rotation. These decorations do not intercept input and disappear with their owned local meshes.

After removing the cover and battery, the Probes stage automatically switches to the authored BenchPuzzle.TaskSurface panel. Three diagnostic cards show Battery, Speaker and Keypad, with animated meters and PASS/FAULT text. Test all three, then choose the faulty component. No floating probe/replace blocks are created for this device stage. The server still owns test results, the hidden answer, work ownership and puzzle revisions. The existing Storage collection, actual component replacement and reassembly remain intact.

No new authored UI or map parts are required. Studio should verify tiny screw targeting on mouse/touch, ring visibility, diagnostic meter sizing, gamepad navigation, and the transition back to physical replacement/reassembly.

## UI migration cleanup

With HUD.Clock, HUD.Scare, the complete HUD.Frames cards and Crosshair.Frame present, the old DPU Clock, Scare, Timecard, Briefing, TeamSignals and DPU_Cursor are no longer required. Do not delete the remaining DPU_PrototypeHUD: BenchPuzzle, Inspection, RepairProgress, Warning, MouseControl, RepairControlMode, ObjectAction and PhysicalRepairHint are still bound.

If legacy Briefing is absent, the new one-button card also explains votes and displays successful results. Understood closes the vote notice so players can use the authored VoteREPORT/VoteHIDE/VoteINVESTIGATE parts; results use HUD.Frames.ShiftComplete when present, falling back to Understood to ready up or return to Lobby when replay is unavailable. For harmful ringing calls, Understood dismisses the warning; a second receiver click within ten seconds explicitly confirms answering. These routes retain existing server validation and never add buttons to the new card.

With HUD.Objective.Frame and its text label present, the old DPU_PrototypeHUD.Objective is also optional. Keep the remaining repair, subtitle, warning and input helper objects until they have been migrated.

Dialogue migration: sync GClient after moving the subtitle card to `HUD.Dialogue`. Keep its Title, Paragraph and CharacterViewPort.ViewportFrame descendants. The old DPU DialogueSubtitles is no longer required; retain the other still-used DPU screens.
