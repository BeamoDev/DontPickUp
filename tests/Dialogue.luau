local Harness = require("./Harness")
local Signal = require("./TagFixture").Signal
local Roblox = require("@lune/roblox")
local h, total = Harness.Environment(), 0
local function check(value, label)
	assert(value, label)
	total += 1
end
for _, key in ipairs({ "Vector2", "Vector3", "CFrame", "Color3", "UDim2" }) do
	h.env[key] = Roblox[key]
end
h.env.Enum = Roblox.Enum
h.env.Content = {
	fromUri = function(uri)
		return uri
	end,
	fromObject = function(object)
		return object
	end,
}
h.env.TweenInfo = {
	new = function(seconds)
		return { Seconds = seconds }
	end,
}
-- Lune does not provide Roblox's grapheme iterator; all fixture lines are ASCII.
h.env.utf8 = {
	len = utf8.len,
	graphemes = utf8.graphemes or function(text)
		local i = 0
		return function()
			i += 1
			if i <= #text then
				return i, i
			end
		end
	end,
}
local jobs, tweens = {}, {}
local tracks = {}
local makeInstance = h.env.Instance.new
h.env.Instance.new = function(class)
	local item = makeInstance(class)
	if class == "Animator" then
		item.LoadAnimation = function(_, animation)
			local track = { id = animation.AnimationId }
			function track:Play()
				self.playing = true
			end
			function track:Stop()
				self.playing = false
			end
			function track:Destroy()
				self.destroyed = true
			end
			table.insert(tracks, track)
			return track
		end
	end
	return item
end
h.env.task.delay = function(seconds, callback)
	local job = { at = h.time + seconds, callback = callback }
	table.insert(jobs, job)
	return job
end
h.env.task.cancel = function(job)
	job.cancelled = true
end
local render = { RenderStepped = Signal() }
local tweenService = {
	Create = function(_, target, info, goals)
		local tween = { Completed = Signal(), target = target, goals = goals, seconds = info.Seconds }
		function tween:Play()
			self.started = h.time
			self.playing = true
		end
		function tween:Cancel()
			self.playing = false
			self.cancelled = true
		end
		table.insert(tweens, tween)
		return tween
	end,
}
local function advance(seconds)
	local deadline = h.time + seconds
	while h.time < deadline - 0.000001 do
		local dt = math.min(1 / 60, deadline - h.time)
		h.time += dt
		for index = #jobs, 1, -1 do
			local job = jobs[index]
			if job.at <= h.time + 0.000001 then
				table.remove(jobs, index)
				if not job.cancelled then
					job.callback()
				end
			end
		end
		h:drain()
		for _, tween in ipairs(tweens) do
			if tween.playing and h.time - tween.started >= tween.seconds then
				tween.playing = false
				for key, value in pairs(tween.goals) do
					tween.target[key] = value
				end
				tween.Completed:Fire()
			end
		end
		render.RenderStepped:Fire(dt)
	end
	h:drain()
end
local function node(class, name, parent)
	local item = h.instance(class)
	item.Name, item.Parent, item.Archivable = name, parent, true
	if item:IsA("Decal") then
		item.Color3, item.Texture = Roblox.Color3.new(1, 1, 1), ""
	end
	if item:IsA("BasePart") then
		item.Color = Roblox.Color3.fromRGB(120, 80, 60)
	end
	item.DescendantAdded, item.AncestryChanged = Signal(), Signal()
	item.WaitForChild = function(_, child)
		return item:FindFirstChild(child)
	end
	local signals = {}
	item.GetPropertyChangedSignal = function(_, name)
		signals[name] = signals[name] or Signal()
		return signals[name]
	end
	if item:IsA("GuiObject") then
		item.Size, item.Position = Roblox.UDim2.fromScale(0.8, 0.2), Roblox.UDim2.fromScale(0.1, 0.8)
		item.Visible, item.Active, item.BackgroundTransparency = false, true, 0.4
		item.ClipsDescendants = false
	end
	if item:IsA("TextLabel") then
		item.Text, item.TextSize, item.TextScaled, item.TextWrapped = "AUTHORED", 18, true, false
		item.MaxVisibleGraphemes, item.RichText, item.AutoLocalize = -1, true, true
		item.TextColor3, item.TextTransparency, item.TextStrokeTransparency = Roblox.Color3.new(1, 1, 1), 0, 0.7
	end
	return item
end
local player = h:player(1)
player.WaitForChild = function(_, name)
	return player:FindFirstChild(name)
end
player.CharacterAdded, player.CharacterAppearanceLoaded = Signal(), Signal()
local playerGui = node("PlayerGui", "PlayerGui", player)
local hud = node("ScreenGui", "HUD", playerGui)
hud.Enabled = false
local subtitles = node("Frame", "Subtitles", hud)
local wrapper = node("Frame", "Frame", subtitles)
local portraitWrapper = node("Frame", "CharacterViewPort", wrapper)
local viewport = node("ViewportFrame", "ViewportFrame", portraitWrapper)
viewport.AbsoluteSize, viewport.ImageTransparency = Roblox.Vector2.new(160, 160), 0
viewport.Ambient, viewport.LightColor, viewport.LightDirection =
	Roblox.Color3.new(), Roblox.Color3.new(), Roblox.Vector3.yAxis
local title, paragraph = node("TextLabel", "Title", subtitles), node("TextLabel", "Paragraph", subtitles)
local decoration = node("Frame", "Frame", title)
local stroke = node("UIStroke", "UIStroke", decoration)
stroke.Transparency = 0.25
local storage = node("ReplicatedStorage", "ReplicatedStorage")
local assets = node("Folder", "Assets", storage)
local function avatar(name, parent)
	local model = node("Model", name, parent)
	local head = node("Part", "Head", model)
	head.Size, head.CFrame, head.Position =
		Roblox.Vector3.new(2, 1, 1), Roblox.CFrame.new(2, 4, 1), Roblox.Vector3.new(2, 4, 1)
	head.LocalTransparencyModifier, head.Anchored = 1, false
	node("Decal", "face", head)
	node("Script", "AuthoredScript", model)
	return model
end
local npc = avatar("NPC", assets)
node("AnimationController", "AnimationController", npc)
local function body(model)
	local part = node("Part", "HumanoidRootPart", model)
	part.Size, part.CFrame, part.Position =
		Roblox.Vector3.new(2, 4, 1), Roblox.CFrame.new(2, 1.5, 1), Roblox.Vector3.new(2, 1.5, 1)
	return part
end
body(npc)
player.Character = avatar("LocalCharacter")
body(player.Character)
node("Humanoid", "Humanoid", player.Character).RigType = Roblox.Enum.HumanoidRigType.R15
player.Character.Archivable = false
local data = node("Folder", "PlayerData", player)
local settings = node("Folder", "Settings", data)
local enabled = node("BoolValue", "Subtitles", settings)
enabled.Value = true
local reduced = false
local originalSize = subtitles.Size
local config = h:load("src/GClient/Interface/DialogueConfig.luau")
check(not config.TestEnabled, "automatic join demo is disabled when orders drive dialogue")
local demoConfig = table.clone(config)
demoConfig.TestEnabled = true -- Retain explicit preview coverage without enabling it in the game.
local Controller = h:load("src/GClient/Interface/DialogueDemoController.luau", {
	["src/GClient/Interface/DialogueConfig.luau"] = demoConfig,
})
local controller = Controller.new({
	player = player,
	storage = storage,
	render = render,
	tweens = tweenService,
	joinedAt = h.time,
	reduced = function()
		return reduced
	end,
})
h:drain()
check(controller.view and not subtitles.Visible, "binds authored nested UI without showing test early")
check(
	paragraph.TextScaled and paragraph.TextSize == 18 and not paragraph.TextWrapped,
	"paragraph preserves authored text settings"
)
check(title.TextScaled and not title.TextWrapped, "title preserves authored text settings")
check(
	viewport.ImageTransparency == 1 and title.TextTransparency == 1,
	"first entrance starts fully faded instead of flashing authored opacity"
)
advance(9.9)
check(not subtitles.Visible and not controller.frame, "no subtitle frame loop or conversation before ten seconds")
advance(0.12)
check(
	subtitles.Visible and hud.Enabled and wrapper.Visible and portraitWrapper.Visible and viewport.Visible,
	"ten-second demo reveals every required ancestor"
)
advance(0.4)
check(subtitles.Size == originalSize, "subtitle transitions preserve authored size")
check(
	title.Text == "Customer" and title.MaxVisibleGraphemes > 0 and title.MaxVisibleGraphemes < #title.Text,
	"speaker title types in instead of appearing instantly"
)
local portrait = controller.view.portrait
local expectedCamera = Roblox.CFrame.new(-163.297, 6.866, -51.514)
	* Roblox.CFrame.Angles(0, math.rad(90.098), 0)
	* Roblox.CFrame.Angles(math.rad(-2.676), 0, 0)
check(
	viewport.CurrentCamera == portrait.camera
		and portrait.camera.CFrame == expectedCamera
		and portrait.camera.FieldOfView == 10,
	"viewport uses exact requested camera transform and ten-degree FOV"
)
check(
	portrait.model and portrait.model ~= npc and portrait.model.Parent == portrait.world,
	"NPC clone is isolated inside viewport WorldModel"
)
check(
	npc:FindFirstChild("AuthoredScript") and not portrait.model:FindFirstChild("AuthoredScript"),
	"portrait strips cloned scripts without touching authored NPC"
)
check(
	portrait.head.LocalTransparencyModifier == 0 and not portrait.head.CanQuery,
	"portrait unhides first-person head and cannot affect interaction rays"
)
local expectedNPC = Roblox.CFrame.new(-176.935, -0.063, -51.505)
	* Roblox.CFrame.Angles(0, math.rad(180), 0)
	* Roblox.CFrame.Angles(math.rad(90), 0, 0)
check(portrait.model.WorldPivot == expectedNPC, "NPC clone uses exact owner position and orientation")
check(
	viewport.Ambient == Roblox.Color3.new() and viewport.LightDirection == Roblox.Vector3.yAxis,
	"portrait preserves authored viewport lighting"
)
check(portrait.track.playing and portrait.track.id == "rbxassetid://99979548599754", "NPC uses requested HappyIdle")
check(
	not portrait.head.Anchored and portrait.model.HumanoidRootPart.Anchored,
	"only rig root is anchored so joints animate"
)
local firstTrack = portrait.track
advance(0.5)
check(
	paragraph.MaxVisibleGraphemes > 0 and paragraph.MaxVisibleGraphemes < #paragraph.Text,
	"paragraph has an independent typewriter reveal"
)
check(paragraph.TextScaled and paragraph.TextSize == 18, "typing retains automatic scaling without text-size overrides")
advance(3.7)
check(
	controller.view.speaker == "You" and title.Text == "You" and title.TextColor3 == config.YouColor,
	"speaker transition uses faint green for You"
)
check(
	controller.view.portrait.model.Name == "LocalCharacter"
		and not player.Character.Archivable
		and controller.view.portrait.model.WorldPivot
			== Roblox.CFrame.new(-176.935, -0.063, -51.505) * Roblox.CFrame.Angles(0, math.rad(-90), 0),
	"You portrait uses exact requested transform and restores source Archivable"
)
check(firstTrack.destroyed and not firstTrack.playing, "speaker switch cleans up previous animation")
check(portrait.track.playing and portrait.track.id == "rbxassetid://507766666", "You uses default R15 idle")
check(
	viewport.CurrentCamera == portrait.camera
		and portrait.camera.CFrame == expectedCamera
		and portrait.camera.FieldOfView == 10,
	"changing speaker never resets the viewport camera"
)
local collapsed = false
for _, tween in ipairs(tweens) do
	if
		tween.target == subtitles
		and tween.goals.Position == controller.view.position + Roblox.UDim2.fromOffset(0, 18)
	then
		collapsed = true
	end
end
check(collapsed, "changing speakers slides down and fades before returning to authored position")
advance(20)
check(
	not subtitles.Visible and not controller.frame and not controller.view.portrait.model,
	"completed demo hides panel and frees portrait and typing loop"
)
check(config.Speaker("YOU") == "You" and config.Speaker("I") == "You", "YOU and I resolve to the player speaker")
reduced = true
controller:Play({ { Speaker = "I", Text = "One line." }, { Speaker = "You", Text = "Another line." } })
h:drain()
advance(0.1)
check(
	title.Text == "You" and paragraph.MaxVisibleGraphemes == #paragraph.Text,
	"reduced motion skips size and typing animations"
)
local before = #tweens
advance(2.4)
check(paragraph.Text == "Another line." and #tweens == before, "same speaker advances text without cycling panel")
controller:Play({ { Speaker = "NPC", Text = "Replacement." } })
h:drain()
advance(0.1)
check(
	title.Text == "Customer" and title.TextColor3 == config.CustomerColor,
	"customer title switches to faint orange after You"
)
enabled.Value = false
advance(0.1)
check(not subtitles.Visible and not controller.frame, "saved subtitle preference stops active playback")
enabled.Value = true
reduced = false
controller:Play({ { Speaker = "NPC", Text = "This should be cancelled." } })
controller:Play({ { Speaker = "You", Text = "Only this line should survive." } })
advance(0.8)
check(title.Text == "You" and controller.view.speaker == "You", "replacement cancels obsolete transition callbacks")
local previousPortrait = controller.view.portrait.model
player.CharacterAppearanceLoaded:Fire(player.Character)
h:drain()
check(
	controller.view.portrait.model ~= previousPortrait and controller.view.portrait.model.Name == "LocalCharacter",
	"avatar appearance refresh replaces only the current You portrait"
)
controller:Stop(false)
check(
	not subtitles.Visible and not controller.view.portrait.model and not controller.frame,
	"immediate stop hides panel and releases animation without leaving a stale subtitle"
)
subtitles.Parent = nil
subtitles.AncestryChanged:Fire()
check(not controller.view and not controller.frame, "HUD removal disconnects old view and cancels old conversation")
subtitles.Parent = hud
playerGui.DescendantAdded:Fire(subtitles)
check(
	controller.view and not subtitles.Visible and not controller.lines,
	"replacement HUD binds without replaying join demo"
)
controller:Destroy()
advance(10)
check(
	subtitles.Size == originalSize
		and paragraph.TextScaled
		and paragraph.TextSize == 18
		and viewport.CurrentCamera == nil,
	"teardown restores authored layout, text configuration and viewport camera"
)
check(
	not controller.frame and #viewport:GetChildren() == 0,
	"teardown removes only owned viewport objects and connections"
)
local cancelled = Controller.new({
	player = player,
	storage = storage,
	render = render,
	tweens = tweenService,
	joinedAt = h.time,
	reduced = function()
		return false
	end,
})
h:drain()
cancelled:Destroy()
advance(11)
check(
	not cancelled.view and not cancelled.frame and not cancelled.lines,
	"destroy before ten seconds cancels the test timer"
)
local hidden = subtitles.Parent
subtitles.Parent = nil
local late = Controller.new({
	player = player,
	storage = storage,
	render = render,
	tweens = tweenService,
	joinedAt = h.time,
	reduced = function()
		return true
	end,
})
h:drain()
advance(10.1)
check(late.pending and not late.view, "demo waits for authored HUD instead of fabricating replacement UI")
subtitles.Parent = hidden
playerGui.DescendantAdded:Fire(subtitles)
h:drain()
advance(0.1)
check(late.view and late.lines and subtitles.Visible, "late authored HUD receives pending test conversation once")
late:Destroy()
local Portrait = h:load("src/GClient/Interface/DialoguePortrait.luau")
local standalone = Portrait.new(viewport, { player = player, storage = storage })
npc.Head.Name = "NPC"
standalone:Show("NPC", "Nervous")
h:drain()
check(
	standalone.model and standalone.track.id == "rbxassetid://83693909579538",
	"headless AnimationController NPC can animate"
)
standalone:Animate("Running")
check(standalone.track.id == "rbxassetid://74163824001698", "NPC animation changes without rebuilding portrait")
player.Character.Humanoid.RigType = Roblox.Enum.HumanoidRigType.R6
standalone:Show("You", "Angry")
h:drain()
check(standalone.track.id == "rbxassetid://180435571", "R6 You always uses default idle instead of NPC emotion")
local finalTrack = standalone.track
standalone:Destroy()
check(finalTrack.destroyed and not finalTrack.playing, "teardown stops and destroys portrait animation")
-- A folder of authored models (including duplicate names) supplies exact customer portraits.
local npcFolder = node("Folder", "NPC", storage.Assets)
npc.Name, npc.Parent = "Character_11", npcFolder
npc:SetAttribute("DPU_AppearanceId", "npc_one")
local secondNPC = npc:Clone()
secondNPC:SetAttribute("DPU_AppearanceId", "npc_two")
secondNPC.Parent = npcFolder
-- Prototype server lines use the same authored subtitle card and camera.
subtitles.Parent = hud
hud.ResetOnSpawn = true
local authoredCamera = node("Camera", "Camera", viewport)
authoredCamera.CFrame, authoredCamera.FieldOfView = Roblox.CFrame.new(11, 22, 33), 10
viewport.CurrentCamera = authoredCamera
local protoGui = node("ScreenGui", "DPU_PrototypeHUD", playerGui)
local legacy = node("Frame", "DialogueSubtitles", protoGui)
legacy.Visible = true
local adapter = h:load("src/GClient/Interface/DialogueController.luau").new(protoGui, {
	player = player,
	storage = storage,
	render = render,
	tweens = tweenService,
	requireAuthoredCamera = true,
	clock = function()
		return h.time
	end,
	reduced = function()
		return true
	end,
})
local speech = {
	RunId = "prototype",
	Alive = true,
	Phase = "Night",
	Dialogue = {
		Id = "customer1",
		Speaker = "Mara",
		AppearanceId = "npc_two",
		Text = "Please fix my phone.",
		StartedAt = h.time,
		ExpiresAt = h.time + 12,
	},
}
adapter:Update(speech, false)
h:drain()
check(
	subtitles.Visible and not legacy.Visible and title.Text == "Mara" and paragraph.Text == speech.Dialogue.Text,
	"prototype dialogue binds authored HUD and suppresses copied legacy card"
)
check(
	title.TextColor3 == config.CustomerColor and paragraph.TextScaled and subtitles.Size == originalSize,
	"prototype preserves authored subtitle text settings and size"
)
check(
	viewport.CurrentCamera == authoredCamera
		and authoredCamera.CFrame == Roblox.CFrame.new(11, 22, 33)
		and authoredCamera.FieldOfView == 10,
	"prototype retains exact authored viewport camera"
)
check(
	adapter.view.portrait.model:GetAttribute("DPU_AppearanceId") == "npc_two",
	"subtitle clones the actual customer template despite duplicate names"
)
local portrait = adapter.view.portrait.model
adapter:Update(speech, false)
check(adapter.view.portrait.model == portrait, "repeated server snapshots do not rebuild portraits")
speech.Dialogue = {
	Id = "you1",
	Speaker = "You",
	UserId = player.UserId,
	Text = "I will check it.",
	StartedAt = h.time,
	ExpiresAt = h.time + 6,
}
adapter:Update(speech, false)
h:drain()
check(
	title.Text == "You" and title.TextColor3 == config.YouColor and adapter.view.portrait.speaker == "You",
	"prototype local speaker uses green You and the player avatar"
)
adapter:Update(speech, true)
check(not subtitles.Visible and not adapter.frame, "blocked prototype dialogue releases its render callback")
adapter:Update(speech, false)
h.time += 7
render.RenderStepped:Fire(0)
check(not subtitles.Visible and not adapter.frame, "server expiry hides prototype dialogue and stops updates")
adapter:Destroy()
check(
	viewport.CurrentCamera == authoredCamera
		and authoredCamera.Parent == viewport
		and hud.ResetOnSpawn
		and legacy.Visible,
	"teardown preserves authored camera and restores GUI lifecycle settings"
)
-- Owner hierarchy: DPU_PrototypeHUD.DialogueSubtitles.Frame contains every leaf.
-- Keep a complete old card too, to verify prototype preference and duplicate suppression.
legacy:Destroy()
local unusedCard = subtitles:Clone()
unusedCard.Name, unusedCard.Parent, unusedCard.Visible = "Subtitles", hud, true
subtitles.Name, subtitles.Parent = "DialogueSubtitles", protoGui
title.Parent, paragraph.Parent = wrapper, wrapper
protoGui.ResetOnSpawn, protoGui.Enabled = true, true
local UI = h:load("src/GClient/Interface/AuthoredUI.luau")
UI.Bind("ScreenGui", playerGui, "DPU_PrototypeHUD") -- Already claimed by PrototypeView at startup.
protoGui.ResetOnSpawn = false
local clockText = node("TextLabel", "Night", protoGui)
UI.Bind("TextLabel", protoGui, "Night", { Text = "NIGHT 03" })
local function newAdapter()
	return h:load("src/GClient/Interface/DialogueController.luau").new(protoGui, {
		player = player,
		storage = storage,
		render = render,
		tweens = tweenService,
		clock = function()
			return h.time
		end,
		reduced = function()
			return true
		end,
	})
end
local moved = newAdapter()
check(
	moved.panel == subtitles and moved.hud == protoGui and not unusedCard.Visible,
	"prototype prefers its new authored DialogueSubtitles over a complete old HUD card"
)
speech.Dialogue = {
	Id = "moved_customer",
	Speaker = "Mara",
	AppearanceId = "npc_two",
	Text = "The new card works.",
	StartedAt = h.time,
	ExpiresAt = h.time + 6,
}
moved:Update(speech, false)
h:drain()
check(
	subtitles.Visible and wrapper.Visible and portraitWrapper.Visible and title.Visible and paragraph.Visible,
	"new nested card reveals the entire authored visibility chain"
)
check(
	title.Text == "Mara"
		and paragraph.Text == speech.Dialogue.Text
		and paragraph.TextScaled
		and paragraph.TextSize == 18
		and subtitles.Size == originalSize,
	"new card receives dialogue without changing authored text size or layout"
)
check(
	viewport.CurrentCamera == authoredCamera
		and authoredCamera.CFrame == Roblox.CFrame.new(11, 22, 33)
		and authoredCamera.FieldOfView == 10,
	"moving the card preserves the authored camera exactly"
)
moved:Destroy()
check(
	unusedCard.Visible and protoGui.ResetOnSpawn == false and clockText.Text == "NIGHT 03",
	"subtitle teardown restores duplicate visibility without releasing the main HUD's controls"
)
-- A separate HUD ScreenGui and saved Camera are not required by the screenshot layout.
hud.Parent = nil
authoredCamera.Parent, viewport.CurrentCamera = nil, nil
local standaloneCard = newAdapter()
local ownedCamera = standaloneCard.view.portrait.camera
check(
	standaloneCard.panel == subtitles
		and ownedCamera.CFrame == config.PortraitCameraFrame
		and ownedCamera.FieldOfView == config.PortraitFieldOfView,
	"new hierarchy starts without HUD using the existing configured camera when none was authored"
)
standaloneCard:Update(speech, false)
h:drain()
check(
	subtitles.Visible and standaloneCard.view.portrait.model,
	"new hierarchy renders its portrait without a separate HUD"
)
standaloneCard:Destroy()
check(
	ownedCamera.Parent == nil and viewport.CurrentCamera == nil and clockText.Text == "NIGHT 03",
	"teardown removes only the temporary camera and leaves other HUD content intact"
)
UI.Release(protoGui)
check(
	protoGui.ResetOnSpawn and clockText.Text == "AUTHORED",
	"main HUD remains independently releasable after subtitle teardown"
)
-- Both gender folders keep portrait identity and select their own animation assets.
local characters = node("Folder", "Characters", assets)
local female = node("Folder", "Female", characters)
local male = node("Folder", "Male", characters)
npc.Parent, secondNPC.Parent = male, female
local genderCard = newAdapter()
speech.Dialogue.Id, speech.Dialogue.Animation = "female_nod", "HeadNodAgree"
genderCard:Update(speech, false)
h:drain()
check(
	title.Text == "Mara" and genderCard.view.portrait.track.id == "rbxassetid://126194927763383",
	"named female portrait uses female nod asset"
)
speech.Dialogue.Id, speech.Dialogue.AppearanceId, speech.Dialogue.Animation = "male_angry", "npc_one", "Angry"
genderCard:Update(speech, false)
h:drain()
check(genderCard.view.portrait.track.id == "rbxassetid://80903870615789", "male portrait uses male emotion asset")
genderCard:Destroy()
local authoredController = Controller.new({
	player = player,
	storage = storage,
	render = render,
	tweens = tweenService,
	reduced = function()
		return true
	end,
})
h:drain()
check(
	authoredController:Play({
		{
			Speaker = "Customer",
			DisplayName = "Nina Vale",
			AppearanceId = "npc_two",
			Animation = "BoredIdle",
			Text = "Is it ready?",
		},
	}),
	"authored dialogue accepts female-only animation"
)
h:drain()
check(
	title.Text == "Nina Vale" and authoredController.view.portrait.track.id == "rbxassetid://93139162995869",
	"authored dialogue preserves name and exact female appearance through validation"
)
authoredController:Destroy()
-- Grayscale uses pixels, not a gray tint, and releases late image loads on speaker teardown.
local Mono = h:load("src/GClient/Interface/PortraitGrayscale.luau")
h.env.Content = {
	fromUri = function(uri)
		return uri
	end,
	fromObject = function(object)
		return object
	end,
}
local convertedImages, loads = {}, 0
local function editable()
	local image = { Size = Roblox.Vector2.new(1, 1), destroyed = 0 }
	function image:ReadPixelsBuffer()
		local pixels = buffer.create(4)
		buffer.writeu8(pixels, 0, 200)
		buffer.writeu8(pixels, 1, 40)
		buffer.writeu8(pixels, 2, 10)
		buffer.writeu8(pixels, 3, 123)
		return pixels
	end
	function image:WritePixelsBuffer(_, _, pixels)
		self.pixels = pixels
	end
	function image:Destroy()
		self.destroyed += 1
	end
	table.insert(convertedImages, image)
	return image
end
local imageService = {
	CreateEditableImageAsync = function()
		loads += 1
		return editable()
	end,
}
local grayModel = avatar("GrayClone")
local face = grayModel.Head.face
face.Texture = "rbxassetid://fixture"
local secondFace = node("Decal", "other", grayModel.Head)
secondFace.Texture = face.Texture
local mono = Mono.new(grayModel, imageService)
h:drain()
local image = convertedImages[1]
check(loads == 1 and face.ColorMapContent == secondFace.ColorMapContent, "shared portrait texture converts once")
check(
	buffer.readu8(image.pixels, 0) == buffer.readu8(image.pixels, 1)
		and buffer.readu8(image.pixels, 1) == buffer.readu8(image.pixels, 2)
		and buffer.readu8(image.pixels, 3) == 123,
	"portrait conversion preserves alpha and makes equal RGB"
)
check(
	grayModel.Head.Color.R == grayModel.Head.Color.G and grayModel:GetAttribute("DPU_GrayscaleReady"),
	"portrait base colors and supported textures are monochrome"
)
mono:Destroy()
mono:Destroy()
check(image.destroyed == 1, "portrait image released exactly once")
local lateModel = avatar("LateClone")
lateModel.Head.face.Texture = "rbxassetid://late"
local lateMono
lateMono = Mono.new(lateModel, {
	CreateEditableImageAsync = function()
		lateMono:Destroy()
		return editable()
	end,
})
h:drain()
check(
	convertedImages[2].destroyed == 1 and lateModel.Head.face.ColorMapContent == nil,
	"image finishing after speaker teardown is destroyed without applying"
)
local unavailableModel = avatar("DeniedClone")
unavailableModel.Head.face.Texture = "rbxassetid://denied"
local denied = Mono.new(unavailableModel, {
	CreateEditableImageAsync = function()
		error("Image API denied")
	end,
})
h:drain()
check(
	unavailableModel:GetAttribute("DPU_GrayscalePartial")
		and unavailableModel.Head.face.Texture == "rbxassetid://denied",
	"permission failure preserves visible authored portrait and reports partial conversion"
)
denied:Destroy()
local boundedModel = avatar("BoundedClone")
for index = 1, 10 do
	node("Decal", "texture" .. index, boundedModel.Head).Texture = "rbxassetid://" .. index
end
local before = loads
local bounded = Mono.new(boundedModel, imageService)
h:drain()
check(
	loads - before == 8 and boundedModel:GetAttribute("DPU_GrayscalePartial"),
	"portrait image allocations are bounded"
)
bounded:Destroy()
print(string.format("PASS: %d authored dialogue, portrait and typewriter checks (mocked Roblox).", total))
