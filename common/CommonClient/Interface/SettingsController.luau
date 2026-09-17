-- Maintained in common/CommonClient/Interface/SettingsController.luau. Deploy with tools/SyncCommon.ps1.
-- One settings owner in each place, started by the existing client entrypoint.
local Controller = {}
Controller.__index = Controller
local View = require(script.Parent.SettingsView)
local Audio = require(script.Parent.SettingsAudio)
local keys = { "MusicEnabled", "SFXEnabled", "CameraShake" }
function Controller.new(deps)
	local self =
		setmetatable({ d = deps, values = {}, confirmed = {}, pending = {}, bound = {}, connections = {} }, Controller)
	self.originalOpen = deps.playerGui:GetAttribute("DPU_SettingsOpen")
	self.originalShake = deps.player:GetAttribute("DPU_CameraShake")
	for _, key in ipairs(keys) do
		self.values[key], self.confirmed[key] = true, true
	end
	self.audio = Audio.new(deps.soundRoots, deps.defer)
	local function refresh()
		self:_schedule()
	end
	table.insert(self.connections, deps.playerGui.DescendantAdded:Connect(refresh))
	table.insert(self.connections, deps.playerGui.DescendantRemoving:Connect(refresh))
	table.insert(self.connections, deps.player.DescendantAdded:Connect(refresh))
	table.insert(self.connections, deps.player.DescendantRemoving:Connect(refresh))
	table.insert(self.connections, deps.player:GetAttributeChangedSignal("DPU_DataStatus"):Connect(refresh))
	self:_refresh()
	return self
end
function Controller:_schedule()
	if self.dead or self.queued then
		return
	end
	self.queued = true
	self.d.defer(function()
		self.queued = false
		if not self.dead then
			self:_refresh()
		end
	end)
end
function Controller:_apply(animate)
	self.audio:Set(self.values.MusicEnabled, self.values.SFXEnabled)
	self.d.player:SetAttribute("DPU_CameraShake", self.values.CameraShake)
	if self.view then
		self.view:Render(self.values, self.ready, animate)
	end
end
function Controller:_refresh()
	local data = self.d.player:FindFirstChild("PlayerData")
	local settings = data and data:FindFirstChild("Settings")
	self.ready = self.d.player:GetAttribute("DPU_DataStatus") == "Ready"
	for _, key in ipairs(keys) do
		local value = settings and settings:FindFirstChild(key)
		if not value or not value:IsA("BoolValue") then
			value = nil
			self.ready = false
		end
		local binding = self.bound[key]
		if binding and binding.value ~= value then
			binding.connection:Disconnect()
			self.bound[key] = nil
		end
		if value and not self.bound[key] then
			self.bound[key] = {
				value = value,
				connection = value:GetPropertyChangedSignal("Value"):Connect(function()
					if not self.dead then
						self.confirmed[key] = value.Value
						if self.pending[key] == nil and self.inFlight ~= key then
							self.values[key] = value.Value
						end
						self:_apply(true)
					end
				end),
			}
			self.confirmed[key] = value.Value
			if self.pending[key] == nil and self.inFlight ~= key then
				self.values[key] = value.Value
			end
		end
	end
	if self.view and not self.view:IsValid() then
		self.view:Destroy()
		self.view = nil
	end
	if not self.view then
		for _, item in ipairs(self.d.playerGui:GetDescendants()) do
			local nodes = View.Resolve(item)
			if nodes then
				self.view = View.new(nodes, {
					playerGui = self.d.playerGui,
					tweens = self.d.tweens,
					reduced = self.d.reduced,
					toggle = function(key)
						self:Toggle(key)
					end,
					visibility = function(open)
						self.d.playerGui:SetAttribute("DPU_SettingsOpen", open)
					end,
				})
				break
			end
		end
	end
	self:_apply(false)
end
function Controller:Toggle(key)
	if self.dead or not self.ready or not table.find(keys, key) then
		return
	end
	self.values[key] = not self.values[key]
	self.pending[key] = self.values[key]
	self:_apply(true)
	if self.sending then
		return
	end
	self.sending = true
	self.d.spawn(function()
		while not self.dead do
			local nextKey, value = next(self.pending)
			if not nextKey then
				break
			end
			self.pending[nextKey], self.inFlight = nil, nextKey
			local ok, response = pcall(self.d.invoke, "SetSetting", { Key = nextKey, Value = value })
			if self.dead then
				return
			end
			self.inFlight = nil
			if ok and type(response) == "table" and response.Ok == true then
				self.confirmed[nextKey] = value
				self.d.playerGui:SetAttribute("DPU_SettingsError", nil)
			else
				self.d.playerGui:SetAttribute(
					"DPU_SettingsError",
					ok and type(response) == "table" and response.Code or "RequestFailed"
				)
			end
			if self.pending[nextKey] == nil then
				self.values[nextKey] = self.confirmed[nextKey]
			end
			self:_apply(true)
		end
		self.sending = false
	end)
end
function Controller:Destroy()
	if self.dead then
		return
	end
	self.dead = true
	for _, connection in ipairs(self.connections) do
		connection:Disconnect()
	end
	for _, binding in pairs(self.bound) do
		binding.connection:Disconnect()
	end
	if self.view then
		self.view:Destroy()
	end
	self.audio:Destroy()
	self.d.playerGui:SetAttribute("DPU_SettingsOpen", self.originalOpen)
	self.d.player:SetAttribute("DPU_CameraShake", self.originalShake)
end
function Controller.Start(entrypoint, network)
	local player = game:GetService("Players").LocalPlayer
	local playerGui = player:WaitForChild("PlayerGui")
	local request = network:WaitForChild("Request", 10)
	if not request then
		return nil
	end
	local gui = game:GetService("GuiService")
	local self = Controller.new({
		player = player,
		playerGui = playerGui,
		tweens = game:GetService("TweenService"),
		soundRoots = { game:GetService("SoundService"), workspace, playerGui },
		defer = task.defer,
		spawn = task.spawn,
		reduced = function()
			return gui.ReducedMotionEnabled
		end,
		invoke = function(action, payload)
			return request:InvokeServer(action, payload)
		end,
	})
	table.insert(
		self.connections,
		entrypoint.Destroying:Connect(function()
			self:Destroy()
		end)
	)
	table.insert(
		self.connections,
		entrypoint.AncestryChanged:Connect(function()
			if not entrypoint.Parent then
				self:Destroy()
			end
		end)
	)
	return self
end
return Controller
