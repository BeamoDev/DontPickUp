# Workspace cleanup for the active shop

This list is based on current source bindings, not a live inspection of your Studio place. No authored instances were deleted by this change.

## Safe to delete if present

- `Workspace.Prototype.DPU_Prototype.WaitingChair`, including its old sign. It has no active gameplay bindings. Keep `RepairSeat` and `Bench2Seat`, which still support phone repairs.

- `Secret_*` notes and the secret-only `Tool_BrassKey` inside `DPU_Prototype` are now optional; missing ones no longer block startup or render. Keep `Records`, which still serves inspections.
- Old root-level `Part_Battery`, `Part_Keypad` and `Part_Speaker` can be removed after the three replacement pickups are inside Storage as listed below.
- The standalone `DeskPhoneBase`, `Receiver` and `Phone` directly inside `Workspace.Prototype.DPU_Prototype`. Their ringing-event actions now use the authored Fax Model. Keep `Fax.Phone`, its real handset.
- An old separate `Workspace.Prototype.Telephone` copy, after the complete physical model is present at `Workspace.Prototype.DPU_Prototype.Fax`. The sibling Telephone path is no longer bound.
- Saved **runtime copies** directly inside `Workspace.Prototype.DPU_Prototype` named `Customer_*`, `Visitor`, `Inspection` or `Shadow`. These are temporary actors copied out of Play; the runtime already detaches them and creates customers from `ReplicatedStorage.Assets.Characters.Female/Male`. Delete only those saved actor copies, not your source NPC models.

Outside Workspace, the old `StarterGui.DPU_PrototypeHUD.FaxPhone` keypad panel is no longer bound. An obsolete deployed `GClient.Prototype.FaxView` ModuleScript should also be removed if it survived an earlier sync. Keep its replacement `PickupTelephone`.

## Keep

- `Workspace.Prototype.DPU_Prototype.Fax` (Model), including its physical keys, InputArea display and direct Phone handset child (BasePart or Model).
- `Workspace.Prototype.DPU_Prototype` and its required shop/station descendants: ShopFloor, StaffSpawn, ObservationDeck, StaffDoor, Timeclock, TimeclockStamp, Counter, Tools, Records, Radio, Fuse, Stock, DeskLamp/WorkLight, Shelter and EmployeeBoard/EmployeeStatus.
- Both benches, seats, phones, trays and counter phone copies: Bench, Bench2, RepairSeat, Bench2Seat, RepairPhone, RepairPhone2, ReplacementTray, ReplacementTray2, CounterPhone_Bench, CounterPhone_Bench2. Keep each bench's RepairFocus/RepairCamera attachments.
- `CRT` Model with `Monitor`, nested `CRTScreen` and its other authored pieces. This is the active television; a separate old root-level CRTScreen is no longer used.
- `Storage` with `Box1`?`Box4`, matching `Label1`?`Label4`, and direct children `Part_BatteryBox1`, `Part_KeypadBox2`, `Part_SpeakerBox3`. These pickups move with their matching drawers. Boxes must be anchored and queryable; pickup surfaces must be queryable.
- VoteREPORT, VoteHIDE, VoteINVESTIGATE, ceiling lights and their saved UI/light children.
- The two highlights `Workspace.Prototype.DPU_InteractFocus` and `DPU_RepairFocus`.
- `ReplicatedStorage.Assets.Characters.Female/Male`, `Assets.Devices.Phone`, Remotes, DPU_Cursor and the saved DPU_PrototypeHUD controls, including DialogueSubtitles. Hidden puzzle panels can still be required by their binders and by controller fallback.

Fax now serves both outgoing calls and the ringing-phone event. While ringing, its body silences the call and its handset offers the existing answer confirmation. The event remains server-authoritative; deleting the old standalone props does not remove it. Sync all three Game roots before deleting those props.

The screenshot's `Cabin/Shop`, `Map`, `Layout`, `Characters` and `Box1` cannot be declared redundant from names alone. They may contain your actual walls, decoration or authored-mode models. Check their contents in Studio before removing anything. This implementation does not require replacing the map or adding a new customer model.

The old `ReplicatedStorage.Assets.RepairPhonePrototype` source model is no longer used by runtime code after syncing the authored-device change. Keep `Assets.Devices.Phone`. Keep RepairPhone/RepairPhone2 and CounterPhone_Bench/CounterPhone_Bench2 as placement anchors, even if their old meshes are later replaced by simple positioned Parts. Source code alone cannot rule out references in other unsynced Studio scripts.
