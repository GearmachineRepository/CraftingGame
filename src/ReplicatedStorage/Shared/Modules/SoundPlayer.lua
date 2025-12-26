--!strict
local SoundService = game:GetService("SoundService")

local SoundManager = {}

-- Active sounds tracking
local ActiveSounds: {[Sound]: boolean} = {}

-- Play a sound with optional config
function SoundManager.PlaySound(soundId: string, parent: Instance?, config: {
	Volume: number?,
	SoundGroup: string?,
	PlaybackSpeed: number?,
	RollOffMaxDistance: number?,
	RollOffMinDistance: number?,
	RollOffMode: Enum.RollOffMode?
	}?): Sound?
	if not soundId or soundId == "" then
		return nil
	end

	local sound = Instance.new("Sound")
	sound.RollOffMode = (config and config.RollOffMode) or Enum.RollOffMode.Linear
	sound.RollOffMaxDistance = (config and config.RollOffMaxDistance) or 75
	sound.RollOffMinDistance = (config and config.RollOffMinDistance) or 5
	sound.SoundId = soundId
	sound.Volume = (config and config.Volume) or 0.5
	sound.PlaybackSpeed = (config and config.PlaybackSpeed) or 1
	sound.Parent = parent or SoundService

	-- Set sound group
	if config and config.SoundGroup then
		local soundGroup = SoundService:FindFirstChild(config.SoundGroup)
		if soundGroup and soundGroup:IsA("SoundGroup") then
			sound.SoundGroup = soundGroup
		end
	else
		-- Default sound group
		local defaultGroup = SoundService:FindFirstChild("Sound Effects")
		if defaultGroup and defaultGroup:IsA("SoundGroup") then
			sound.SoundGroup = defaultGroup
		end
	end

	-- Track active sound
	ActiveSounds[sound] = true

	sound:Play()

	-- Auto-cleanup when finished
	sound.Ended:Connect(function()
		ActiveSounds[sound] = nil
		sound:Destroy()
	end)

	return sound
end

-- Stop a specific sound
function SoundManager.StopSound(sound: Sound): ()
	if not sound or not sound.Parent then
		return
	end

	ActiveSounds[sound] = nil
	sound:Stop()
	sound:Destroy()
end

-- Stop all active sounds
function SoundManager.StopAllSounds(): ()
	local soundsToStop = {}
	for sound, _ in pairs(ActiveSounds) do
		table.insert(soundsToStop, sound)
	end

	for _, sound in pairs(soundsToStop) do
		SoundManager.StopSound(sound)
	end
end

return SoundManager