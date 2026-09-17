-- Every order and work reservation belongs to one station. No implicit active context.
local Stations = {}
Stations.Ids = { "Bench", "Bench2" }
function Stations.New()
	return { Bench = { Id = "Bench" }, Bench2 = { Id = "Bench2" } }
end
function Stations.ForPlayer(run, player)
	local member = run.players[player]
	return run.stations[member and member.StationId or "Bench"] or run.stations.Bench
end
function Stations.AtCounter(run, player)
	local selected = Stations.ForPlayer(run, player)
	if selected.order and (selected.order.Step == "Waiting" or selected.order.Step == "Return") then
		return selected
	end
	for _, step in ipairs({ "Return", "Waiting" }) do
		for _, id in ipairs(Stations.Ids) do
			local lane = run.stations[id]
			if lane.order and lane.order.Step == step then
				return lane
			end
		end
	end
	return selected
end
function Stations.ForOrder(run, id)
	for _, key in ipairs(Stations.Ids) do
		local lane = run.stations[key]
		if lane.order and lane.order.Id == id then
			return lane
		end
	end
	return nil
end
function Stations.Voting(run)
	local active = run.voteOrderId and Stations.ForOrder(run, run.voteOrderId)
	if active and active.order.Step == "Evidence" then
		return active
	end
	for _, key in ipairs(Stations.Ids) do
		local lane = run.stations[key]
		if lane.order and lane.order.Step == "Evidence" then
			return lane
		end
	end
end

function Stations.BeginVote(run, lane)
	local order = lane.order
	run.voteOrderId = order.Id
	order.VoteEndsAt = run.d.clock() + run.c.VoteSeconds
	if order.ExpiresAt then
		order.ExpiresAt = math.max(order.ExpiresAt, order.VoteEndsAt + 10)
	end
end
function Stations.CancelPlayer(run, player)
	for _, lane in pairs(run.stations) do
		if lane.work and lane.work.Player == player then
			lane.work = nil
		end
	end
end
function Stations.Stand(run, lane)
	for player in pairs(run.players) do
		if Stations.ForPlayer(run, player) == lane then
			run.d.stand(player)
		end
	end
end
function Stations.Select(run, player, id)
	local member, lane = run.players[player], run.stations[id]
	if not lane or not run.d.near(player, id) then
		return false, "MoveCloser"
	end
	if run.phase ~= "Night" and id ~= "Bench" then
		return false, "FinishTraining"
	end
	if member.CarriedPart then
		return false, "DepositFirst"
	end
	if member.StationId ~= id then
		Stations.CancelPlayer(run, player)
		run.d.stand(player)
		member.Seated, member.StationId = false, id
		member.SeatVisit = (member.SeatVisit or 0) + 1
		member.Inspection = nil
		if not lane.order then
			lane.nextOrder = run.d.clock()
		end
		run:_publish()
	end
	return true
end
return Stations
