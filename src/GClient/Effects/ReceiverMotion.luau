-- Animate a local visual copy so authored receiver welds cannot move the fax body.
local Motion = {}
Motion.__index = Motion
function Motion.new(deps)
	return setmetatable({ d = deps }, Motion)
end
function Motion:Clear()
	for part, transparency in pairs(self.hidden or {}) do
		if part.Parent then
			part.LocalTransparencyModifier = transparency
		end
	end
	if self.visual then
		self.visual:Destroy()
	end
	self.visual, self.parts, self.hidden, self.model = nil, nil, nil, nil
	self.started, self.lowering = nil, false
end
function Motion:Raise(model, camera)
	self:Clear()
	local original = model:FindFirstChild("Phone")
	if not original or not (original:IsA("BasePart") or original:IsA("Model")) then
		return
	end
	local visual = original:Clone()
	if not visual then
		return
	end
	local sourceParts = original:GetDescendants()
	table.insert(sourceParts, original)
	self.hidden = {}
	for _, part in ipairs(sourceParts) do
		if part:IsA("BasePart") then
			self.hidden[part] = part.LocalTransparencyModifier
			part.LocalTransparencyModifier = 1
		end
	end
	self.visual, self.model, self.parts = visual, model, {}
	local pivot = model:GetPivot()
	local objects = visual:GetDescendants()
	table.insert(objects, visual)
	-- Remove only clone-owned script/joint/effect objects before parenting it.
	for _, object in ipairs(objects) do
		for _, tag in ipairs(self.d.collection:GetTags(object)) do
			self.d.collection:RemoveTag(object, tag)
		end
		if object:IsA("BasePart") then
			object.Anchored, object.CanCollide, object.CanTouch, object.CanQuery = true, false, false, false
			object.LocalTransparencyModifier = 0
			table.insert(self.parts, { part = object, home = pivot:ToObjectSpace(object.CFrame), from = object.CFrame })
		elseif
			object:IsA("LuaSourceContainer")
			or object:IsA("JointInstance")
			or object:IsA("Constraint")
			or object:IsA("WeldConstraint")
			or object:IsA("Sound")
			or object:IsA("ParticleEmitter")
		then
			object:Destroy()
		end
	end
	if #self.parts == 0 then
		self:Clear()
		return
	end
	visual.Name, visual.Parent = "DPU_LocalReceiver", self.d.workspace
	-- Above and behind the inspection camera, outside its viewing frustum.
	local home = original:GetPivot()
	local raised = camera.CFrame * CFrame.new(1.2, 3, 1.5)
	for _, entry in ipairs(self.parts) do
		entry.raised = raised * home:ToObjectSpace(entry.from)
	end
	self.started, self.lowering = os.clock(), false
	self:Update()
end
function Motion:Lower(immediate)
	if not self.visual then
		return
	end
	if immediate or not self.model:IsDescendantOf(self.d.workspace) then
		self:Clear()
		return
	end
	if self.lowering then
		return
	end
	self.lowering, self.started = true, os.clock()
	for _, entry in ipairs(self.parts) do
		entry.from = entry.part.CFrame
	end
	self:Update()
end
function Motion:Update()
	if not self.visual then
		return
	end
	if not self.model:IsDescendantOf(self.d.workspace) then
		self:Clear()
		return
	end
	local t = self.d.reduced() and 1 or math.clamp((os.clock() - self.started) / 0.35, 0, 1)
	local alpha = t * t * (3 - 2 * t)
	local pivot = self.model:GetPivot()
	for part in pairs(self.hidden) do
		if not part:IsDescendantOf(self.model) then
			self:Clear()
			return
		end
		part.LocalTransparencyModifier = 1
	end
	for _, entry in ipairs(self.parts) do
		local target = self.lowering and pivot * entry.home or entry.raised
		entry.part.CFrame = entry.from:Lerp(target, alpha)
	end
	if self.lowering and t == 1 then
		self:Clear()
	end
end
return Motion
