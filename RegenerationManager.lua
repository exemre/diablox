-- ServerScriptService > RegenerationManager.lua (ModuleScript)
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Logger = require(script.Parent.Logger)
local StatManager = require(script.Parent.StatManager)
local RemoteEventManager = require(script.Parent.RemoteEventManager)

local RegenerationManager = {}
RegenerationManager.__index = RegenerationManager

local Config = {
	RegenInterval = 1,
	InactivityThreshold = 10,
	HealthBaseRegen = 0.005,
	ManaBaseRegen = 0.01,
	StaminaBaseRegen = 0.02,
	VitalityBonus = 0.001,
	IntelligenceBonus = 0.002,
	DexterityBonus = 0.003
}

local playerData = {}

function RegenerationManager.new(dependencies)
	local self = setmetatable({
		dependencies = dependencies or {
			StatManager = StatManager,
			RemoteEventManager = RemoteEventManager
		}
	}, RegenerationManager)
	return self
end

function RegenerationManager:InitializePlayer(player)
	local success, err = pcall(function()
		playerData[player] = {
			lastDamageTime = 0,
			lastManaSpentTime = 0,
			lastStaminaSpentTime = 0,
			isRegenerating = { Health = false, Mana = false, Stamina = false },
			connections = {}
		}

		local character = player.Character or player.CharacterAdded:Wait()
		local humanoid = character:WaitForChild("Humanoid")

		if not player:GetAttribute("CurrentHP") then
			player:SetAttribute("CurrentHP", humanoid.MaxHealth)
		end
		if not player:GetAttribute("CurrentMana") then
			player:SetAttribute("CurrentMana", player:GetAttribute("MaxMana") or 100)
		end
		if not player:GetAttribute("CurrentStamina") then
			player:SetAttribute("CurrentStamina", player:GetAttribute("MaxStamina") or 100)
		end

		playerData[player].connections["HealthChanged"] = humanoid.HealthChanged:Connect(function(newHealth)
			local currentHP = player:GetAttribute("CurrentHP") or humanoid.MaxHealth
			if newHealth > currentHP then
				humanoid.Health = currentHP
			end
		end)

		local resourceEvent = self.dependencies.RemoteEventManager:GetEvent("ResourceUpdateEvent")
		if resourceEvent then
			playerData[player].connections["ResourceUpdate"] = resourceEvent.OnServerEvent:Connect(function(_, resourceName, newValue)
				if resourceName == "CurrentMana" then
					local oldMana = player:GetAttribute("CurrentMana") or 0
					if newValue < oldMana then
						playerData[player].lastManaSpentTime = tick()
						playerData[player].isRegenerating.Mana = false
					end
					player:SetAttribute("CurrentMana", newValue)
				elseif resourceName == "CurrentStamina" then
					local oldStamina = player:GetAttribute("CurrentStamina") or 0
					if newValue < oldStamina then
						playerData[player].lastStaminaSpentTime = tick()
						playerData[player].isRegenerating.Stamina = false
					end
					player:SetAttribute("CurrentStamina", newValue)
				elseif resourceName == "CurrentHP" then
					local oldHP = player:GetAttribute("CurrentHP") or humanoid.MaxHealth
					if newValue < oldHP then
						playerData[player].lastDamageTime = tick()
						playerData[player].isRegenerating.Health = false
					end
					player:SetAttribute("CurrentHP", newValue)
					humanoid.Health = newValue
				end
			end)
		else
			Logger:Error(Logger.Categories.EventLogs, "ResourceUpdateEvent bulunamadý!")
		end

		playerData[player].connections["Heartbeat"] = RunService.Heartbeat:Connect(function()
			self:CheckRegeneration(player, "Health")
			self:CheckRegeneration(player, "Mana")
			self:CheckRegeneration(player, "Stamina")
		end)
	end)
	if not success then
		Logger:Error(Logger.Categories.EventLogs, "Oyuncu baþlatma hatasý: " .. err)
	end
end

function RegenerationManager:CalculateRegenRate(player, resourceType)
	local statManager = self.dependencies.StatManager
	local resourceRegen = statManager:GetStat(player, "ResourceRegen") or 0

	if resourceType == "Health" then
		local maxHP = statManager:GetStat(player, "MaxHP")
		local vitality = statManager:GetStat(player, "Vitality")
		return math.round((maxHP * Config.HealthBaseRegen + vitality * Config.VitalityBonus) * resourceRegen * 100) / 100
	elseif resourceType == "Mana" then
		local maxMana = statManager:GetStat(player, "MaxMana")
		local intelligence = statManager:GetStat(player, "Intelligence")
		return math.round((maxMana * Config.ManaBaseRegen + intelligence * Config.IntelligenceBonus) * resourceRegen * 100) / 100
	elseif resourceType == "Stamina" then
		local maxStamina = statManager:GetStat(player, "MaxStamina")
		local dexterity = statManager:GetStat(player, "Dexterity")
		return math.round((maxStamina * Config.StaminaBaseRegen + dexterity * Config.DexterityBonus) * resourceRegen * 100) / 100
	end
	return 0
end

function RegenerationManager:CheckRegeneration(player, resourceType)
	local data = playerData[player]
	if not data then return end

	local lastActionTime = resourceType == "Health" and data.lastDamageTime or
		resourceType == "Mana" and data.lastManaSpentTime or
		data.lastStaminaSpentTime
	local currentValue = resourceType == "Health" and player:GetAttribute("CurrentHP") or
		resourceType == "Mana" and player:GetAttribute("CurrentMana") or
		player:GetAttribute("CurrentStamina")
	local maxValue = resourceType == "Health" and player:GetAttribute("MaxHP") or
		resourceType == "Mana" and player:GetAttribute("MaxMana") or
		player:GetAttribute("MaxStamina")

	if tick() - lastActionTime >= Config.InactivityThreshold and currentValue < maxValue and not data.isRegenerating[resourceType] then
		data.isRegenerating[resourceType] = true
		self:StartRegeneration(player, resourceType)
	end
end

function RegenerationManager:StartRegeneration(player, resourceType)
	task.spawn(function()
		local data = playerData[player]
		if not data or not data.isRegenerating[resourceType] then return end

		local statManager = self.dependencies.StatManager
		local remoteEventManager = self.dependencies.RemoteEventManager
		local attributeName = resourceType == "Health" and "CurrentHP" or
			resourceType == "Mana" and "CurrentMana" or
			"CurrentStamina"
		local maxAttributeName = resourceType == "Health" and "MaxHP" or
			resourceType == "Mana" and "MaxMana" or
			"MaxStamina"

		while data.isRegenerating[resourceType] do
			local currentValue = player:GetAttribute(attributeName) or 0
			local maxValue = statManager:GetStat(player, maxAttributeName)
			local regenRate = self:CalculateRegenRate(player, resourceType)

			if currentValue >= maxValue then
				player:SetAttribute(attributeName, maxValue)
				if resourceType == "Health" then
					local humanoid = player.Character and player.Character:FindFirstChild("Humanoid")
					if humanoid then humanoid.Health = maxValue end
				end
				remoteEventManager:FireClient("ResourceUpdateEvent", player, attributeName, maxValue)
				data.isRegenerating[resourceType] = false
				break
			end

			local newValue = math.round(math.min(currentValue + regenRate, maxValue) * 100) / 100
			player:SetAttribute(attributeName, newValue)
			if resourceType == "Health" then
				local humanoid = player.Character and player.Character:FindFirstChild("Humanoid")
				if humanoid then humanoid.Health = newValue end
			end
			remoteEventManager:FireClient("ResourceUpdateEvent", player, attributeName, newValue)

			task.wait(Config.RegenInterval)
		end
	end)
end

Players.PlayerRemoving:Connect(function(player)
	if playerData[player] then
		for _, connection in pairs(playerData[player].connections) do
			connection:Disconnect()
		end
		playerData[player] = nil
	end
end)

return RegenerationManager