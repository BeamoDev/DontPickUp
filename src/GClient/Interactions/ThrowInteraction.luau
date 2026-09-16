-- One request to grab and one to release/cancel. Charge/aim are never streamed.
local Throw = {}
Throw.__index = Throw
function Throw.new(deps)
	return setmetatable({ d = deps }, Throw)
end
function Throw:Busy()
	return self.session ~= nil
end
function Throw:Begin(item, input)
	if self.session or self.destroyed or self.d.blocked() then
		return
	end
	local id = item:GetAttribute("DPU_ThrowId")
	if type(id) ~= "string" or item:GetAttribute("DPU_ThrowHeld") then
		return
	end
	local session = { item = item, input = input, character = self.d.player.Character, started = os.clock() }
	self.session = session
	self.d.meter(true, 0, "GRABBING")
	self.frame = self.d.render.RenderStepped:Connect(function()
		self:Update()
	end)
	task.spawn(function()
		local ok, response = pcall(self.d.remote.InvokeServer, self.d.remote, "GrabThrow", { Id = id })
		if not ok or type(response) ~= "table" or not response.Ok or type(response.Token) ~= "string" then
			self:Clear(session)
			if not self.destroyed then
				warn("[DPU][Throw] Grab failed", type(response) == "table" and response.Code or "Connection")
			end
			return
		end
		session.token, session.revision, session.started = response.Token, response.Revision, os.clock()
		if self.destroyed then
			session.cancelled = true
		end
		self:Finish(session) -- A fast release or interruption may precede the server reply.
	end)
end
function Throw:Matches(input)
	local held = self.session and self.session.input
	if not held then
		return false
	end
	if held.UserInputType == Enum.UserInputType.Touch then
		return input == held
	end
	if held.UserInputType == Enum.UserInputType.MouseButton1 then
		return input.UserInputType == held.UserInputType
	end
	return input.KeyCode == held.KeyCode
end
function Throw:Release(input, processed)
	if not self:Matches(input) then
		return
	end
	local session, camera = self.session, self.d.workspace.CurrentCamera
	if processed or self.d.blocked() or not camera then
		self:Cancel()
		return
	end
	local ray
	if self.d.input.PreferredInput == Enum.PreferredInput.KeyboardAndMouse and not self.d.locked() then
		local pointer = self.d.input:GetMouseLocation()
		ray = camera:ScreenPointToRay(pointer.X, pointer.Y)
	else
		ray = camera:ViewportPointToRay(camera.ViewportSize.X / 2, camera.ViewportSize.Y / 2)
	end
	session.direction = ray.Direction.Unit
	self:Finish(session)
end
function Throw:Cancel()
	local session = self.session
	if not session then
		return
	end
	session.cancelled = true
	self.d.meter(false, 0)
	self:Finish(session)
end
function Throw:Finish(session)
	if not session.token or session.sending or (not session.cancelled and not session.direction) then
		return
	end
	session.sending = true
	self.d.meter(false, 0)
	local action, payload = "CancelThrow", { Token = session.token }
	if not session.cancelled then
		action = "ReleaseThrow"
		payload.X, payload.Y, payload.Z = session.direction.X, session.direction.Y, session.direction.Z
	end
	task.spawn(function()
		local ok, response = pcall(self.d.remote.InvokeServer, self.d.remote, action, payload)
		if not ok or type(response) ~= "table" or not response.Ok then
			-- Token-scoped cancel cannot affect a later grab; never retry a launch.
			pcall(self.d.remote.InvokeServer, self.d.remote, "CancelThrow", { Token = session.token })
		end
		self:Clear(session)
	end)
end
function Throw:Update()
	local session = self.session
	if not session or session.sending or session.cancelled then
		return
	end
	local character = self.d.player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local revision = session.item:GetAttribute("DPU_ThrowRevision")
	if
		self.destroyed
		or character ~= session.character
		or not humanoid
		or humanoid.Health <= 0
		or humanoid.Sit
		or self.d.blocked()
		or self.d.input:GetFocusedTextBox()
		or not session.item:IsDescendantOf(self.d.workspace)
		or not self.d.collection:HasTag(session.item, "throw")
		or os.clock() - session.started > self.d.config.MaxHoldSeconds
		or (session.revision and revision and revision > session.revision)
		or (session.token and session.item:GetAttribute("DPU_ThrowId") == nil)
	then
		self:Cancel()
		return
	end
	if session.token then
		self.d.meter(true, self.d.config.Charge(os.clock() - session.started), "RELEASE TO THROW")
	end
end
function Throw:Clear(session)
	if self.session ~= session then
		return
	end
	self.session = nil
	if self.frame then
		self.frame:Disconnect()
		self.frame = nil
	end
	self.d.meter(false, 0)
end
function Throw:Destroy()
	self.destroyed = true
	self:Cancel()
	if self.frame then
		self.frame:Disconnect()
		self.frame = nil
	end
end
return Throw
