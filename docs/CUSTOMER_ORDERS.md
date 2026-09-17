# Customers and repair orders

The first complete work loop is active: one customer approaches, an employee accepts their phone, any employee repairs it, an employee returns that exact phone, the present loaded crew is paid, and the next customer follows. Three ordinary customer requests rotate through the existing four-wire repair. No shift clock, horror events, evidence decisions or new repair types are added here.

## Try the temporary bench

1. Sync the Game roots together: `GClient`, `GServer`, `GShared`. Also sync the canonical `LServer/PlayerData/DataService` update in the Lobby place. Restart Play.
2. In Studio, a small workbench is generated near a `SpawnLocation` when there is no authored `Workspace.RepairOrderStation`. If no SpawnLocation exists, it falls back near world origin. No full shop or old prototype bootstrap is generated.
3. To choose the exact location, create an anchored BasePart named **`OrderBenchOrigin` directly in Workspace** before Play. Its CFrame is the floor position/orientation of the bench. Use `Transparency = 1`, `CanCollide = false`, `CanTouch = false`, `CanQuery = false`. Keep it level. The employee stands on its local **+Z** side; leave about 12 studs clear on its **-Z** side for the customer approach.
4. Once profiles are ready, the first customer starts approaching after about three seconds and takes three seconds to reach the counter. Click/tap the customer, or aim at them and press E/controller R2, to accept the order.
5. Follow the ticket in the top right. Click the phone on the mat; complete the existing wire and assembly steps. The inspection camera returns normally. Click the customer again to return it. Each present, loaded employee receives **10 credits and one case solved**.
6. The customer leaves; another arrives after the six-second gap. The generated bench and active phone/customer exist only for that Play session. `GServer/Orders/BenchOrderCatalog.StudioBench = false` disables automatic generation.

The generated phone is used only on the generated Studio bench, unless you provide `ServerStorage.Assets.OrderPhone`. Customer visuals clone `ReplicatedStorage.Assets.NPC`; if unavailable, a simple block figure makes the bench test usable. Dialogue still needs the owner's authored `HUD.Subtitles` hierarchy and Assets.NPC portrait, as described in [DIALOGUE](DIALOGUE.md). Missing subtitle UI does not prevent order progress; the ticket remains visible. The old ten-second automatic dialogue demo is now disabled.

Studio practice saving is still the default: credits update the profile and leaderboard in Play, but do not persist across separate Studio sessions while `StudioSaving = false`. Normal profile autosave and departure/shutdown saving apply in published places. No new DataStore or schema migration is introduced.

## Replace the fixture with an authored station

Create **`Workspace.RepairOrderStation`** with these direct BasePart children. These are world marker parts, not additional source folders:

| Marker | Meaning |
| --- | --- |
| `CustomerStart` | Customer's floor position and facing at arrival |
| `CustomerStand` | Floor position and facing at the counter |
| `CustomerExit` | Optional departure floor position/facing; defaults to CustomerStart |
| `PhoneSpot` | Surface position where the phone rests; rotation adjusts the template's authored pose |

Keep marker parts anchored, invisible, non-collidable and non-queryable. Include your own worktop/scenery. Put a **copy** of the authored repairable Phone model at **`ServerStorage.Assets.OrderPhone`**, using the exact hierarchy from [PHONE_REPAIR](PHONE_REPAIR.md). The original template is preserved; only an owned clone receives the PhoneRepair tag and current order identity. Invalid/missing templates reject handoff without advancing or paying the order. Do not weld the template to external scenery.

The customer currently follows a straight, eased route between markers. This is a bench route, not navigation around a finished shop; keep the lane clear. The NPC is grounded from its bounds. `OrderCatalog.CustomerRotation` defaults to the owner's imported NPC orientation `(90, 180, 0)`; a Vector3 `CustomerRotation` attribute on Assets.NPC overrides this for the world clone only. Running at reduced playback speed is used during movement; HappyIdle is used at the counter. Viewport cameras and portrait transforms are unchanged.

Published places require this authored station and phone template. The temporary bench never generates outside Studio. There is currently one shared station/order, with no customer queue or order inventory. Canceling or leaving a repair returns that phone to its initial repair state so another employee can take over. Only the currently repairing employee manipulates it at a time. Completed phones are returned through the customer interaction rather than carried by the brick throw system.

## Ownership and validation

- `GServer/Orders/BenchOrderService`: private order lifecycle, current ticket snapshots, exact phone identity, completion/settlement and crew payments. Server-only OrderCatalog contains customer lines and tuning.
- `GServer/Orders/BenchOrderStation`: authored station lookup, owned phone spawning, reach/visibility checks and cleanup. OrderTestBench holds only the temporary geometry factory.
- `GServer/Customers/CustomerActor`: isolated NPC clone, grounded movement, animation and teardown.
- `GClient/Interface/OrderController` and `OrderView`: event-driven ticket and dialogue presentation. No extra input listener or render loop. The central InteractionController handles the whole-model `Customer` tag through child hit parts and the same pooled fading highlight.
- The existing Network request guard applies to `GetOrderState` and `ServeCustomer`. The server checks loaded profile, alive/standing employee, empty hands/no active repair, matching order/revision, valid customer, eight-stud surface reach, walls and current order stage. Clients never submit money, completion, a phone Instance or payment recipients.
- PhoneRepairService's server completion callback checks the actual repair record and its binding ID. A changed stage attribute, another repaired phone, a removed/rebound phone, or a repeated return cannot complete/pay the order. The callback fires only after reassembly finishes.
- `DataService:RecordOrderPayment` uses a server-generated order receipt in the existing saved RecentOutcomes list. It awards ten credits/one case, without adding a death, shift completion or story progress. All present employees with ready profiles are paid; employees who have left are not awarded an offline payment.
- Client state revisions reject late initial fetches and duplicate packets. Only transitions broadcast; there is no per-frame remote traffic. Order lifecycle checks share the existing once-per-second Game maintenance loop. One active customer's model tween owns one change connection, removed on teardown.
- Losing the customer, repair binding, station, or all employees cancels the owned order without payment. Shutdown cancels movement, disconnects callbacks/signals and removes only generated/owned instances. Authored station/assets remain intact. An invalidated station requires a Play restart after correcting it.

## Verification

`tests/Orders.luau` runs actual generated bench/phone construction, actual repair rig/animation and every wire/assembly request through the server, the completion callback, return, team payment, saved receipt replay protection, binding invalidation, departures, cleanup, published fixture exclusion, and client snapshot ordering. Detection tests cover customer child hits, walls, availability and one-request touch behavior. Bootstrap tests cover the new endpoints and teardown. These are local mocked Roblox checks.

Still test in Studio: bench placement/clearance, imported NPC grounding/facing and animation permissions, authored OrderPhone joints/pose, touch/controller usability, ticket overlap at narrow aspect ratios, subtitle transitions, repair camera return, two-player simultaneous accept/return, repairer disconnect/takeover, late joins and cleanup on Stop. Published DataStore saving and replication under real latency remain unverified.
