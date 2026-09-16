local Shared = game:GetService("ReplicatedStorage"):WaitForChild("GShared", 30)
local Tags = require(Shared:WaitForChild("Interactions", 30):WaitForChild("InteractionTags", 30))
local Drinks = {}
Drinks.__index = Drinks

function Drinks.new(services, eligible, visible)
	return setmetatable(
		{ s = services, eligible = eligible, visible = visible, items = {}, ids = {}, cooldowns = {} },
		Drinks
	)
end

function Drinks:Add(item)
	if self.closed or self.items[item] then
		return
	end
	local record =
		{ item = item, id = self.s.HttpService:GenerateGUID(false), tweens = {}, connections = {}, original = {} }
	self.items[item], self.ids[record.id] = record, record
	item:SetAttribute("DPU_DrinkId", record.id)
	item:SetAttribute("DPU_DrinkBusy", false)
end

function Drinks:Drop(item)
	local record = self.items[item]
	if not record then
		return
	end
	self.items[item], self.ids[record.id] = nil, nil
	for _, connection in ipairs(record.connections) do
		connection:Disconnect()
	end
	for _, tween in ipairs(record.tweens) do
		tween:Cancel()
	end
	for part, transparency in pairs(record.original) do
		if part.Parent then
			part.Transparency = transparency
		end
	end
	item:SetAttribute("DPU_DrinkId", nil)
	item:SetAttribute("DPU_DrinkBusy", nil)
end

function Drinks:Request(player, payload)
	local function reject(code)
		return { Ok = false, Code = code }
	end
	if self.closed or player.Parent ~= self.s.Players or not self.eligible(player) then
		return reject("NotReady")
	end
	if type(payload) ~= "table" or type(payload.Id) ~= "string" then
		return reject("InvalidRequest")
	end
	if os.clock() < (self.cooldowns[player] or 0) then
		return reject("PleaseWait")
	end
	self.cooldowns[player] = os.clock() + 0.15
	local record = self.ids[payload.Id]
	if
		not record
		or not record.item:IsDescendantOf(self.s.Workspace)
		or Tags.Kind(self.s.CollectionService, record.item) ~= "Drink"
	then
		return reject("Unavailable")
	end
	if record.busy then
		return reject("PleaseWait")
	end
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local head = character and character:FindFirstChild("Head")
	if not humanoid or humanoid.Health <= 0 or humanoid.Sit or not root or not head then
		return reject("Unavailable")
	end
	local item = record.item
	local parts = item:GetDescendants()
	table.insert(parts, item)
	local nearby, accessible = false, false
	for _, part in ipairs(parts) do
		if part:IsA("BasePart") and part.CanQuery and (root.Position - part.Position).Magnitude <= Tags.Distance then
			nearby = true
			if self.visible(character, head, part, item) then
				accessible = true
				break
			end
		end
	end
	if not nearby then
		return reject("TooFar")
	end
	if not accessible then
		return reject("Blocked")
	end
	-- Reserve synchronously before playing any tween; there is no reward/completion remote.
	record.busy = true
	item:SetAttribute("DPU_DrinkBusy", true)
	for _, part in ipairs(parts) do
		if part:IsA("BasePart") or part:IsA("Decal") or part:IsA("Texture") then
			record.original[part] = part.Transparency
			local tween = self.s.TweenService:Create(
				part,
				TweenInfo.new(Tags.DrinkSeconds, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut),
				{ Transparency = 1 }
			)
			table.insert(record.tweens, tween)
		end
	end
	local remaining = #record.tweens
	for _, tween in ipairs(record.tweens) do
		local connection
		connection = tween.Completed:Connect(function(state)
			if state ~= Enum.PlaybackState.Completed or self.items[item] ~= record then
				return
			end
			connection:Disconnect()
			remaining -= 1
			if remaining > 0 then
				return
			end
			-- Do not restore visible geometry when successful consumption removes the object.
			table.clear(record.original)
			self:Drop(item)
			item:Destroy()
		end)
		table.insert(record.connections, connection)
	end
	for _, tween in ipairs(record.tweens) do
		tween:Play()
	end
	return { Ok = true }
end

function Drinks:Remove(player)
	self.cooldowns[player] = nil
end
function Drinks:Shutdown()
	self.closed = true
	for item in pairs(self.items) do
		self:Drop(item)
	end
	table.clear(self.cooldowns)
end

return Drinks
