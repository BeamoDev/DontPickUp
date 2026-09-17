-- Local easter-egg routes. SubtitleKey is a hook, not a subtitle renderer.
return table.freeze({
	["67"] = table.freeze({ Id = "SixSeven", SubtitleKey = "Fax.SixSeven", DialSeconds = 0.65 }),
	["1984"] = table.freeze({ Id = "MinistryLine", SubtitleKey = "Fax.MinistryLine", DialSeconds = 0.85 }),
	["404"] = table.freeze({ Id = "MissingDepartment", SubtitleKey = "Fax.MissingDepartment", DialSeconds = 0.65 }),
})
