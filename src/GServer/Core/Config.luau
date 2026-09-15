-- Server-only configuration. Keep the GServer/Core copy identical.
return table.freeze({
	LobbyPlaceId = 110554757455252,
	GamePlaceId = 111652489432168, -- Must be a published subplace of the Lobby's experience.
	MaxPartySize = 4,
	CountdownSeconds = 5,
	PartyIdleSeconds = 600,
	TeleportAttempts = 3,
	TeleportWatchdogSeconds = 45,
	TicketSeconds = 300,
	ArrivalSeconds = 120,
	DataStoreName = "DontPickUp_PlayerData_v1",
	TicketMapName = "DontPickUp_Admissions_v1",
	LeaseSeconds = 180,
	LoadTimeoutSeconds = 195,
	SaveIntervalSeconds = 50,
	MutationLeaseMargin = 40,
	StudioSaving = false, -- false: in-memory practice; true: isolated _STUDIO store.
	StudioAllowDirectGame = true, -- Studio only; published Game always requires admission.
})
