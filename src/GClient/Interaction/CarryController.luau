-- Click to carry, click again to throw. Only bounded unit aim is sent while held.
local CarryView = require(script.Parent.CarryView)
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
	self:ClearRelease()
	local session = { item = item, input = input, character = self.d.player.Character, started = os.clock() }
	self.session = session
	self.d.meter(true, "PICKING UP")
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
function Throw:AimDirection()
	local camera = self.d.workspace.CurrentCamera
	if not camera then
		return nil
	end
	local pointer = self.d.input.PreferredInput == Enum.PreferredInput.KeyboardAndMouse
			and not self.d.locked()
			and self.d.input:GetMouseLocation()
		or camera.ViewportSize / 2
	return camera:ViewportPointToRay(pointer.X, pointer.Y).Direction.Unit
end
function Throw:Release()
	local session = self.session
	if not session or session.sending or session.cancelled or self.d.blocked() then
		return
	end
	local direction = self:AimDirection()
	if not direction then
		self:Cancel()
		return
	end
	session.direction = direction
	self:Finish(session) -- Queues a second click arriving before the grab reply.
end
function Throw:Cancel()
	self:ClearRelease()
	local session = self.session
	if not session then
		return
	end
	session.cancelled = true
	self.d.meter(false, "")
	self:Finish(session)
end
function Throw:Finish(session)
	if not session.token or session.sending or (not session.cancelled and not session.direction) then
		return
	end
	session.sending = true
	local releasedView
	if session.visual then
		if session.cancelled then
			session.visual:Destroy()
		else
			self:ClearRelease()
			releasedView = session.visual
			releasedView:Release(session.direction, session.revision)
			self.releasing = releasedView
		end
		session.visual = nil
	end
	self.d.meter(false, "")
	local action, payload = "CancelThrow", { Token = session.token }
	if not session.cancelled then
		action = "ReleaseThrow"
		payload.X, payload.Y, payload.Z = session.direction.X, session.direction.Y, session.direction.Z
	end
	task.spawn(function()
		local ok, response = pcall(self.d.remote.InvokeServer, self.d.remote, action, payload)
		if releasedView and not releasedView.destroyed then
			if ok and type(response) == "table" and response.Ok then
				releasedView.accepted = true
			else
				releasedView:Destroy()
				if self.releasing == releasedView then
					self.releasing = nil
				end
			end
		end
		if not ok or type(response) ~= "table" or not response.Ok then
			-- Token-scoped cancel cannot affect a later grab; never retry a launch.
			pcall(self.d.remote.InvokeServer, self.d.remote, "CancelThrow", { Token = session.token })
		end
		self:Clear(session)
	end)
end
function Throw:ClearRelease()
	if self.releasing then
		self.releasing:Destroy()
		self.releasing = nil
	end
end
function Throw:Update(dt)
	if self.releasing and not self.releasing:UpdateRelease(dt) then
		self:ClearRelease()
	end
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
		or (session.visual and self.d.workspace.CurrentCamera ~= session.visual.camera)
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
		self.d.meter(true, "CLICK / TAP TO THROW   Q / B TO CANCEL")
		local now, direction = os.clock(), self:AimDirection()
		session.visual = session.visual or CarryView.new(session.item, self.d)
		if session.visual then
			session.visual:Update(direction, dt)
		end
		if
			self.d.aim
			and direction
			and now >= (session.nextAim or 0)
			and (not session.lastAim or direction:Dot(session.lastAim) < self.d.config.AimDotThreshold)
		then
			session.nextAim, session.lastAim = now + self.d.config.AimInterval, direction
			self.d.aim:FireServer(session.token, direction.X, direction.Y, direction.Z)
		end
	end
end
function Throw:Clear(session)
	if self.session ~= session then
		return
	end
	self.session = nil
	if session.visual then
		session.visual:Destroy()
		session.visual = nil
	end
	self.d.meter(false, "")
end
function Throw:Destroy()
	self.destroyed = true
	self:Cancel()
end
return Throw
