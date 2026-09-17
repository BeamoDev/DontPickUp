-- Local TV viewing, driven by the prototype's existing world input controller.
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("GShared", 30)
local Scene = require(Shared:WaitForChild("World", 30):WaitForChild("SceneReferences", 30))
local Camera = require(script.Parent.Parent.Camera.InspectionCamera)
local ViewConfig = require(script.Parent.Parent.Camera.TelevisionViewConfig)
local Television = {}
Television.__index = Television
function Television.new(deps)
	local self = setmetatable({ d = deps }, Television)
	local cameraDeps = table.clone(deps)
	cameraDeps.config = table.clone(ViewConfig)
	cameraDeps.config.CameraFrame = function(pivot, bounds, size, viewport)
		local _, screen = Scene.Television(deps.workspace)
		if screen then
			return ViewConfig.CameraFrame(screen.CFrame, screen.CFrame, screen.Size, viewport)
		end
		return ViewConfig.CameraFrame(pivot, bounds, size, viewport)
	end
	cameraDeps.valid = function(model)
		return model == Scene.Television(deps.workspace)
	end
	cameraDeps.active = function()
		deps.cursor(false)
	end
	cameraDeps.returning = function(returning)
		deps.cursor(returning)
	end
	self.camera = Camera.new(cameraDeps)
	return self
end
function Television:OwnsInput()
	return self.camera.saved ~= nil
end
function Television:NeedsPointer()
	return self:OwnsInput() and not self.camera.exiting
end
function Television:Open(model)
	if model ~= Scene.Television(self.d.workspace) then
		return false
	end
	return self.camera:Open(model)
end
function Television:Close(immediate)
	self.press = nil
	self.camera:Close(immediate)
end
function Television:InputBegan(input, processed)
	if input.UserInputType == Enum.UserInputType.Touch and self.press and input ~= self.press then
		self.press = nil
		return
	end
	if processed or self.d.blocked() or self.d.input:GetFocusedTextBox() then
		return
	end
	if input.KeyCode == Enum.KeyCode.Q or input.KeyCode == Enum.KeyCode.ButtonB then
		self:Close()
	elseif
		input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch
	then
		local position = Vector2.new(input.Position.X, input.Position.Y)
		if self.d.uiBlocked(position) then
			return
		end
		self.press, self.start, self.at = input, input.Position, os.clock()
	end
end
function Television:InputChanged(input)
	if
		self.press
		and (input == self.press or input.UserInputType == Enum.UserInputType.MouseMovement)
		and (input.Position - self.start).Magnitude > 18
	then
		self.press = nil
	end
end
function Television:InputEnded(input, processed)
	local tap = input == self.press and os.clock() - self.at <= 0.6 and (input.Position - self.start).Magnitude <= 18
	if input == self.press then
		self.press = nil
	end
	if
		tap
		and not processed
		and not self.d.blocked()
		and not self.d.uiBlocked(Vector2.new(input.Position.X, input.Position.Y))
	then
		self:Close()
	end
end
function Television:Destroy()
	self.press = nil
	self.camera:Destroy()
end
return Television
