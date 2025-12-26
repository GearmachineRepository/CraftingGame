--!strict
local SoundService = game:GetService("SoundService")

local SoundPlayer = {}

local ActiveSounds: {[Sound]: boolean} = {}

type SoundConfig = {
	Volume: number?,
	SoundGroup: string?,
	PlaybackSpeed: number?,
	RollOffMaxDistance: number?,
	RollOffMinDistance: number?,
	RollOffMode: Enum.RollOffMode?,
}

local DEFAULT_VOLUME: number = 0.5
local DEFAULT_PLAYBACK_SPEED: number = 1
local DEFAULT_ROLLOFF_MAX: number = 75
local DEFAULT_ROLLOFF_MIN: number = 5

function SoundPlayer.PlaySound(SoundId: string, Parent: Instance?, Config: SoundConfig?): Sound?
	if not SoundId or SoundId == "" then
		return nil
	end

	local NewSound = Instance.new("Sound")
	NewSound.RollOffMode = (Config and Config.RollOffMode) or Enum.RollOffMode.Linear
	NewSound.RollOffMaxDistance = (Config and Config.RollOffMaxDistance) or DEFAULT_ROLLOFF_MAX
	NewSound.RollOffMinDistance = (Config and Config.RollOffMinDistance) or DEFAULT_ROLLOFF_MIN
	NewSound.SoundId = SoundId
	NewSound.Volume = (Config and Config.Volume) or DEFAULT_VOLUME
	NewSound.PlaybackSpeed = (Config and Config.PlaybackSpeed) or DEFAULT_PLAYBACK_SPEED
	NewSound.Parent = Parent or SoundService

	if Config and Config.SoundGroup then
		local TargetSoundGroup = SoundService:FindFirstChild(Config.SoundGroup)
		if TargetSoundGroup and TargetSoundGroup:IsA("SoundGroup") then
			NewSound.SoundGroup = TargetSoundGroup
		end
	else
		local DefaultGroup = SoundService:FindFirstChild("Sound Effects")
		if DefaultGroup and DefaultGroup:IsA("SoundGroup") then
			NewSound.SoundGroup = DefaultGroup
		end
	end

	ActiveSounds[NewSound] = true

	NewSound:Play()

	NewSound.Ended:Connect(function()
		ActiveSounds[NewSound] = nil
		NewSound:Destroy()
	end)

	return NewSound
end

function SoundPlayer.StopSound(TargetSound: Sound)
	if not TargetSound or not TargetSound.Parent then
		return
	end

	ActiveSounds[TargetSound] = nil
	TargetSound:Stop()
	TargetSound:Destroy()
end

function SoundPlayer.StopAllSounds()
	local SoundsToStop: {Sound} = {}

	for TargetSound in ActiveSounds do
		table.insert(SoundsToStop, TargetSound)
	end

	for _, TargetSound in SoundsToStop do
		SoundPlayer.StopSound(TargetSound)
	end
end

return SoundPlayer