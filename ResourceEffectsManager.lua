-- StarterPlayer.StarterPlayerScripts > ResourceEffectsManager.lua (LocalScript)
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local SoundService = game:GetService("SoundService")

local ResourceEffectsManager = {}
ResourceEffectsManager.__index = ResourceEffectsManager

-- Yapýlandýrma
local Config = {
	WaitForChildTimeout = 1,
	TweenInfo = TweenInfo.new(5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), -- Animasyon 2 saniye
	SoundIds = {
		Health = {
			Critical = { -- %15 için rastgele sesler
				"rbxassetid://131062314330506",
				"rbxassetid://106930158600127",
				"rbxassetid://119592190560536",
				"rbxassetid://122620514223122",
				"rbxassetid://110869613949832"

			},
			Half = "rbxassetid://114934144568909" -- %50 için sabit ses (kendi ID’ni ekle)
		},
		Mana = {
			Critical = { -- %15 için rastgele sesler
				"rbxassetid://131062314330506",
				"rbxassetid://106930158600127",
				"rbxassetid://119592190560536",
				"rbxassetid://122620514223122",
				"rbxassetid://110869613949832"

			},
			Half = "rbxassetid://114934144568909" -- %50 için sabit ses (kendi ID’ni ekle)
		},
		Stamina = {
			Critical = { -- %15 için rastgele sesler
				"rbxassetid://131062314330506",
				"rbxassetid://106930158600127",
				"rbxassetid://119592190560536",
				"rbxassetid://122620514223122",
				"rbxassetid://110869613949832"

			},
			Half = "rbxassetid://114934144568909" -- %50 için sabit ses (kendi ID’ni ekle)
		}
	},
	HalfThreshold = 0.5,   -- %50 eþik (yarýsý)
	CriticalThreshold = 0.25, -- %15 eþik
	SoundCooldown = 1
}

function ResourceEffectsManager.new()
	local self = setmetatable({}, ResourceEffectsManager)
	self.player = Players.LocalPlayer
	self.lastHealthSoundTime = 0
	self.lastManaSoundTime = 0
	self.lastStaminaSoundTime = 0
	self.isStatsLoaded = false
	self.healthBelowCritical = false
	self.manaBelowCritical = false
	self.staminaBelowCritical = false
	self.healthAtHalf = false
	self.manaAtHalf = false
	self.staminaAtHalf = false
	self:Initialize()
	return self
end

function ResourceEffectsManager:Initialize()
	local success, err = pcall(function()
		self:SetupUIReferences()
		self:WaitForStats()
		self:StartMonitoring()
	end)
	if not success then
		warn("[ResourceEffectsManager] Initialization failed: " .. err)
	end
end

function ResourceEffectsManager:SetupUIReferences()
	local playerGui = self.player:WaitForChild("PlayerGui", Config.WaitForChildTimeout)
	local screenGui = playerGui:WaitForChild("ScreenGui", Config.WaitForChildTimeout)
	local canvas = screenGui:WaitForChild("Canvas")
	local hud = canvas:WaitForChild("Hud")
	local lowerHud = hud:WaitForChild("LowerHud")

	local healthFrame = lowerHud:WaitForChild("HealthFrame")
	self.healthBroke = healthFrame:WaitForChild("Broke")
	self.healthBroke.Visible = false
	self.healthBroke.ImageTransparency = 1

	local manaFrame = lowerHud:WaitForChild("ManaFrame")
	self.manaBroke = manaFrame:WaitForChild("Broke")
	self.manaBroke.Visible = false
	self.manaBroke.ImageTransparency = 1

	local staminaFrame = lowerHud:WaitForChild("StaminaFrame")
	self.staminaBroke = staminaFrame:WaitForChild("Broke")
	self.staminaBroke.Visible = false
	self.staminaBroke.ImageTransparency = 1
end

function ResourceEffectsManager:WaitForStats()
	local humanoid = self.player.Character and self.player.Character:WaitForChild("Humanoid", Config.WaitForChildTimeout)
	if not humanoid then
		self.player.CharacterAdded:Wait()
		humanoid = self.player.Character:WaitForChild("Humanoid", Config.WaitForChildTimeout)
	end

	local function checkStats()
		local maxHP = self.player:GetAttribute("MaxHP")
		local currentHP = self.player:GetAttribute("CurrentHP") or humanoid.Health
		local maxMana = self.player:GetAttribute("MaxMana")
		local currentMana = self.player:GetAttribute("CurrentMana")
		local maxStamina = self.player:GetAttribute("MaxStamina")
		local currentStamina = self.player:GetAttribute("CurrentStamina")

		return maxHP and currentHP and maxMana and currentMana and maxStamina and currentStamina and
			maxHP > 0 and currentHP >= 0 and maxMana > 0 and currentMana >= 0 and maxStamina > 0 and currentStamina >= 0
	end

	while not checkStats() do
		task.wait(0.1)
	end
	self.isStatsLoaded = true
end

function ResourceEffectsManager:PlaySound(soundId, lastSoundTimeVar)
	local currentTime = tick()
	if currentTime - lastSoundTimeVar >= Config.SoundCooldown then
		local sound = Instance.new("Sound")
		sound.SoundId = soundId
		sound.Volume = 0.5
		sound.Parent = SoundService
		local success, err = pcall(function()
			sound:Play()
		end)
		if not success then
			warn("[ResourceEffectsManager] Failed to play sound " .. soundId .. ": " .. err)
		end
		sound.Ended:Connect(function()
			sound:Destroy()
		end)
		return currentTime
	end
	return lastSoundTimeVar
end

function ResourceEffectsManager:PlayRandomSound(soundList, lastSoundTimeVar)
	local currentTime = tick()
	if currentTime - lastSoundTimeVar >= Config.SoundCooldown then
		local soundId = soundList[math.random(1, #soundList)]
		local sound = Instance.new("Sound")
		sound.SoundId = soundId
		sound.Volume = 0.5
		sound.Parent = SoundService
		local success, err = pcall(function()
			sound:Play()
		end)
		if not success then
			warn("[ResourceEffectsManager] Failed to play sound " .. soundId .. ": " .. err)
		end
		sound.Ended:Connect(function()
			sound:Destroy()
		end)
		return currentTime
	end
	return lastSoundTimeVar
end

function ResourceEffectsManager:UpdateResource(currentValue, maxValue, brokeFrame, soundConfig, lastSoundTimeVar, belowCriticalFlag, atHalfFlag)
	if not self.isStatsLoaded then return lastSoundTimeVar, belowCriticalFlag, atHalfFlag end

	if not currentValue or not maxValue or maxValue <= 0 then return lastSoundTimeVar, belowCriticalFlag, atHalfFlag end

	local ratio = currentValue / maxValue
	local shouldBeVisible = ratio <= Config.HalfThreshold
	if shouldBeVisible and not brokeFrame.Visible then
		brokeFrame.Visible = true
		local tween = TweenService:Create(brokeFrame, Config.TweenInfo, { ImageTransparency = 0 })
		tween:Play()
		if ratio > Config.CriticalThreshold then -- %50 ile %15 arasýndaysa sesi burada çal
			lastSoundTimeVar = self:PlaySound(soundConfig.Half, lastSoundTimeVar)
		end
	elseif not shouldBeVisible and brokeFrame.Visible then
		local tween = TweenService:Create(brokeFrame, Config.TweenInfo, { ImageTransparency = 1 })
		tween:Play()
		tween.Completed:Connect(function()
			brokeFrame.Visible = false
		end)
	end

	local isBelowCritical = ratio <= Config.CriticalThreshold
	if isBelowCritical and not belowCriticalFlag then
		lastSoundTimeVar = self:PlayRandomSound(soundConfig.Critical, lastSoundTimeVar)
		belowCriticalFlag = true
	elseif not isBelowCritical and belowCriticalFlag then
		belowCriticalFlag = false
	end

	local isAtHalf = ratio <= Config.HalfThreshold and ratio > Config.CriticalThreshold
	if isAtHalf and not atHalfFlag then
		atHalfFlag = true
	elseif not isAtHalf and atHalfFlag then
		atHalfFlag = false
	end

	return lastSoundTimeVar, belowCriticalFlag, atHalfFlag
end

function ResourceEffectsManager:StartMonitoring()
	RunService.RenderStepped:Connect(function()
		local success, err = pcall(function()
			local humanoid = self.player.Character and self.player.Character:FindFirstChild("Humanoid")
			local currentHP = self.player:GetAttribute("CurrentHP") or (humanoid and humanoid.Health) or 0
			local maxHP = self.player:GetAttribute("MaxHP") or 0
			self.lastHealthSoundTime, self.healthBelowCritical, self.healthAtHalf = self:UpdateResource(
				currentHP,
				maxHP,
				self.healthBroke,
				Config.SoundIds.Health,
				self.lastHealthSoundTime,
				self.healthBelowCritical,
				self.healthAtHalf
			)

			local currentMana = self.player:GetAttribute("CurrentMana") or 0
			local maxMana = self.player:GetAttribute("MaxMana") or 0
			self.lastManaSoundTime, self.manaBelowCritical, self.manaAtHalf = self:UpdateResource(
				currentMana,
				maxMana,
				self.manaBroke,
				Config.SoundIds.Mana,
				self.lastManaSoundTime,
				self.manaBelowCritical,
				self.manaAtHalf
			)

			local currentStamina = self.player:GetAttribute("CurrentStamina") or 0
			local maxStamina = self.player:GetAttribute("MaxStamina") or 0
			self.lastStaminaSoundTime, self.staminaBelowCritical, self.staminaAtHalf = self:UpdateResource(
				currentStamina,
				maxStamina,
				self.staminaBroke,
				Config.SoundIds.Stamina,
				self.lastStaminaSoundTime,
				self.staminaBelowCritical,
				self.staminaAtHalf
			)
		end)
		if not success then
			warn("[ResourceEffectsManager] Monitoring failed: " .. err)
		end
end)
end

local manager = ResourceEffectsManager.new()
return manager