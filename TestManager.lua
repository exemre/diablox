-- StarterPlayer.StarterPlayerScripts > TestManager.lua (LocalScript)
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local TestManager = {}
TestManager.__index = TestManager

-- Yapýlandýrma tablosu (Prensip 12: Esnek Entegrasyon Stratejileri)
local Config = {
	WaitForChildTimeout = 1, -- RemoteEvent bekleme süresi (saniye)
	TestInputs = {
		XP = {
			Key = Enum.KeyCode.One,
			Amount = 10000,
			EventName = "AddXPEvent",
			Description = "XP Ekleme Testi"
		},
		Stats = {
			Strength = { Key = Enum.KeyCode.Two, EventName = "IncreaseStatEvent", Description = "Strength Artýrma Testi" },
			Dexterity = { Key = Enum.KeyCode.Three, EventName = "IncreaseStatEvent", Description = "Dexterity Artýrma Testi" },
			Intelligence = { Key = Enum.KeyCode.Four, EventName = "IncreaseStatEvent", Description = "Intelligence Artýrma Testi" },
			Vitality = { Key = Enum.KeyCode.Five, EventName = "IncreaseStatEvent", Description = "Vitality Artýrma Testi" }
		},
		Resources = {
			CurrentHP = { Key = Enum.KeyCode.Six, Amount = -10, EventName = "ResourceUpdateEvent", Description = "HP Azaltma Testi" },
			CurrentMana = { Key = Enum.KeyCode.Seven, Amount = -10, EventName = "ResourceUpdateEvent", Description = "Mana Azaltma Testi" },
			CurrentStamina = { Key = Enum.KeyCode.Eight, Amount = -10, EventName = "ResourceUpdateEvent", Description = "Stamina Azaltma Testi" }
		}
	}
}

-- Client-side Logger (Prensip 5: Hata Yönetimi)
local ClientLogger = {}
ClientLogger.__index = ClientLogger
function ClientLogger.new() return setmetatable({}, ClientLogger) end
function ClientLogger:Trace(_, message) print("[TRACE] TestManager: " .. message) end
function ClientLogger:Error(_, message) warn("[ERROR] TestManager: " .. message) end
local Logger = ClientLogger.new()

function TestManager.new()
	local self = setmetatable({}, TestManager)
	self.player = Players.LocalPlayer
	self.events = {} -- RemoteEvent referanslarý
	self:Initialize()
	return self
end

function TestManager:Initialize()
	local success, err = pcall(function()
		-- RemoteEvent'leri yükle
		self.events["AddXPEvent"] = ReplicatedStorage:WaitForChild("AddXPEvent", Config.WaitForChildTimeout)
		self.events["IncreaseStatEvent"] = ReplicatedStorage:WaitForChild("IncreaseStatEvent", Config.WaitForChildTimeout)
		self.events["ResourceUpdateEvent"] = ReplicatedStorage:WaitForChild("ResourceUpdateEvent", Config.WaitForChildTimeout)

		-- Event kontrolü
		for eventName, event in pairs(self.events) do
			if not event then
				Logger:Error("Initialize", eventName .. " bulunamadý, server’ýn çalýþtýðýndan emin ol!")
				return
			end
		end

		self:SetupInput()
		self:SetupEventListeners()
	end)
	if not success then
		Logger:Error("Initialize", "Sistem baþlatma hatasý: " .. err)
	else
		Logger:Trace("Initialize", "Sistem baþlatýldý.")
	end
end

function TestManager:SetupInput()
	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then return end

		local success, err = pcall(function()
			-- XP Testi
			if input.KeyCode == Config.TestInputs.XP.Key then
				self.events["AddXPEvent"]:FireServer(Config.TestInputs.XP.Amount)
				Logger:Trace("Input", Config.TestInputs.XP.Description .. ": +" .. Config.TestInputs.XP.Amount .. " XP")

				-- Stat Testleri
			elseif Config.TestInputs.Stats.Strength.Key == input.KeyCode then
				self.events["IncreaseStatEvent"]:FireServer("Strength")
				Logger:Trace("Input", Config.TestInputs.Stats.Strength.Description)
			elseif Config.TestInputs.Stats.Dexterity.Key == input.KeyCode then
				self.events["IncreaseStatEvent"]:FireServer("Dexterity")
				Logger:Trace("Input", Config.TestInputs.Stats.Dexterity.Description)
			elseif Config.TestInputs.Stats.Intelligence.Key == input.KeyCode then
				self.events["IncreaseStatEvent"]:FireServer("Intelligence")
				Logger:Trace("Input", Config.TestInputs.Stats.Intelligence.Description)
			elseif Config.TestInputs.Stats.Vitality.Key == input.KeyCode then
				self.events["IncreaseStatEvent"]:FireServer("Vitality")
				Logger:Trace("Input", Config.TestInputs.Stats.Vitality.Description)

				-- Kaynak Testleri
			elseif Config.TestInputs.Resources.CurrentHP.Key == input.KeyCode then
				local humanoid = self.player.Character and self.player.Character:FindFirstChild("Humanoid")
				local currentHP = humanoid and math.floor(humanoid.Health) or 0
				self.events["ResourceUpdateEvent"]:FireServer("CurrentHP", math.floor(currentHP + Config.TestInputs.Resources.CurrentHP.Amount))
				Logger:Trace("Input", Config.TestInputs.Resources.CurrentHP.Description .. ": " .. Config.TestInputs.Resources.CurrentHP.Amount)
			elseif Config.TestInputs.Resources.CurrentMana.Key == input.KeyCode then
				local currentMana = self.player:GetAttribute("CurrentMana") or 0
				self.events["ResourceUpdateEvent"]:FireServer("CurrentMana", math.floor(currentMana + Config.TestInputs.Resources.CurrentMana.Amount))
				Logger:Trace("Input", Config.TestInputs.Resources.CurrentMana.Description .. ": " .. Config.TestInputs.Resources.CurrentMana.Amount)
			elseif Config.TestInputs.Resources.CurrentStamina.Key == input.KeyCode then
				local currentStamina = self.player:GetAttribute("CurrentStamina") or 0
				self.events["ResourceUpdateEvent"]:FireServer("CurrentStamina", math.floor(currentStamina + Config.TestInputs.Resources.CurrentStamina.Amount))
				Logger:Trace("Input", Config.TestInputs.Resources.CurrentStamina.Description .. ": " .. Config.TestInputs.Resources.CurrentStamina.Amount)
			end
		end)

		if not success then
			Logger:Error("Input", "Giriþ hatasý: " .. err)
		end
	end)
end

function TestManager:SetupEventListeners()
	local success, err = pcall(function()
		-- AddXPEvent dinleyicisi
		self.events["AddXPEvent"].OnClientEvent:Connect(function(xp, level, statPoints)
			Logger:Trace("Event", "XP Güncellemesi - XP: " .. xp .. ", Level: " .. level .. ", Stat Points: " .. statPoints)
		end)

		-- IncreaseStatEvent dinleyicisi
		self.events["IncreaseStatEvent"].OnClientEvent:Connect(function(statName, newValue, remainingStatPoints)
			Logger:Trace("Event", "Stat Güncellemesi - " .. statName .. ": " .. newValue .. ", Kalan Stat Points: " .. remainingStatPoints)
		end)

		-- ResourceUpdateEvent dinleyicisi
		self.events["ResourceUpdateEvent"].OnClientEvent:Connect(function(resourceName, newValue)
		end)
	end)

	if not success then
		Logger:Error("EventListeners", "Event dinleme hatasý: " .. err)
	end
end

-- Otomatik baþlatma (Prensip 11: Merkezi Kontrol)
local testManager = TestManager.new()
return testManager