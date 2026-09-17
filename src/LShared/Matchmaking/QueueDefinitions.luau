-- Public mode names consumed by queue presentation and authoritative admission.
local Definitions = { Modes = table.freeze({ "Story", "Endless" }), DefaultMode = "Story" }
function Definitions.IsMode(mode)
	return table.find(Definitions.Modes, mode) ~= nil
end
return table.freeze(Definitions)
