local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Logger = require(script.Parent.Logger)

-- Event Config dosyas� (Prensip 12)
local EventConfig = {
	MaxFireRate = 10, -- Saniyede max ate�leme (Prensip 6)
	FlushInterval = 0.1 -- Buffer flush aral��� (Prensip 9)
}

local RemoteEventManager = {}
RemoteEventManager.__index = RemoteEventManager

local eventList = {} -- Mevcut RemoteEvent objeleri
local eventRegistry = {} -- Dinamik event kay�tlar�: { name = { handler, validateArgs } }
local fireBuffer = {} -- FireClient buffer: { [eventName] = { {player, args}, ... } }
local fireCounts = {} -- Rate limit i�in saya�: { [eventName] = count }

function RemoteEventManager.new(dependencies)
	local self = setmetatable({
		dependencies = dependencies or {}, -- Dependency injection (Prensip 2)
		eventStatus = {},
		_lastFlush = tick()
	}, RemoteEventManager)
	return self
end

function RemoteEventManager:RegisterEvent(eventName, callback, validateArgs)
	local event = ReplicatedStorage:FindFirstChild(eventName)
	if not event then
		event = Instance.new("RemoteEvent")
		event.Name = eventName
		event.Parent = ReplicatedStorage
		Logger:Trace(Logger.Categories.EventLogs, "Yeni RemoteEvent olu�turuldu: " .. eventName)
	else
		Logger:Trace(Logger.Categories.EventLogs, "Mevcut RemoteEvent kullan�ld�: " .. eventName)
	end

	eventList[eventName] = event
	eventRegistry[eventName] = { handler = callback, validateArgs = validateArgs }
	fireCounts[eventName] = 0

	local connection
	local success, err = pcall(function()
		connection = event.OnServerEvent:Connect(function(player, ...)
			if not ReplicatedStorage:FindFirstChild(eventName) then
				Logger:Error(Logger.Categories.EventLogs, "Event bulunamad� (�al��ma zaman�): " .. eventName)
				self.eventStatus[eventName] = "failed"
				return
			end
			local args = { ... }
			if validateArgs and not validateArgs(player, args) then
				Logger:Error(Logger.Categories.EventLogs, "Ge�ersiz veri: " .. eventName .. " - " .. tostring(args[1]))
				return
			end
			local ok, result = pcall(callback, self, player, table.unpack(args))
			if not ok then
				Logger:Error(Logger.Categories.EventLogs, "Event hatas�: " .. eventName .. " - " .. result)
			end
		end)
		if not connection or not connection.Connected then
			error("Event ba�lant�s� ba�ar�s�z")
		end
	end)
	if not success then
		Logger:Error(Logger.Categories.ConsoleLogs, "Event ba�lama hatas�: " .. eventName .. " - " .. err)
		self.eventStatus[eventName] = "failed"
		Logger:Warn(Logger.Categories.CriticalErrors, "Dikkat: " .. eventName .. " event ba�lamas� ba�ar�s�z, sistem �al��maya devam ediyor!")
	else
		self.eventStatus[eventName] = "success"
		self.connections = self.connections or {}
		self.connections[eventName] = connection -- Scope d���na ta��nd� (Prensip 5)
	end
end

function RemoteEventManager:GetEvent(eventName)
	return eventList[eventName]
end

function RemoteEventManager:FireClient(eventName, player, ...)
	local event = self:GetEvent(eventName)
	if not event then
		Logger:Error(Logger.Categories.EventLogs, "RemoteEvent bulunamad�: " .. eventName)
		return
	end

	-- Rate limit kontrol� (Prensip 6)
	fireCounts[eventName] = fireCounts[eventName] or 0
	if fireCounts[eventName] >= EventConfig.MaxFireRate then
		fireBuffer[eventName] = fireBuffer[eventName] or {}
		local args = { ... } -- ...'u bir tabloya topla
		table.insert(fireBuffer[eventName], { player = player, args = args })
		return
	end

	local args = { ... } -- ...'u bir tabloya topla
	local success, err = pcall(function()
		event:FireClient(player, table.unpack(args))
		fireCounts[eventName] = fireCounts[eventName] + 1
	end)
	if not success then
		Logger:Error(Logger.Categories.EventLogs, "FireClient hatas�: " .. eventName .. " - " .. err)
	end
end

function RemoteEventManager:FlushBuffer()
	if not next(fireBuffer) then return end

	for eventName, buffer in pairs(fireBuffer) do
		local event = self:GetEvent(eventName)
		if event then
			for _, data in ipairs(buffer) do
				if fireCounts[eventName] < EventConfig.MaxFireRate then
					local success, err = pcall(function()
						event:FireClient(data.player, table.unpack(data.args))
						fireCounts[eventName] = fireCounts[eventName] + 1
					end)
					if not success then
						Logger:Error(Logger.Categories.EventLogs, "Buffer FireClient hatas�: " .. eventName .. " - " .. err)
					end
				end
			end
		end
	end
	fireBuffer = {} -- Buffer�� temizle
end

function RemoteEventManager:StartMonitoring()
	Logger:Info(Logger.Categories.ConsoleLogs, "Event izleme ba�lad�.")
	self.monitorConnection = ReplicatedStorage.ChildRemoved:Connect(function(child)
		if eventRegistry[child.Name] then
			Logger:Error(Logger.Categories.EventLogs, "Event bulunamad� (�al��ma zaman�): " .. child.Name)
			self.eventStatus[child.Name] = "failed"
			Logger:Warn(Logger.Categories.CriticalErrors, "Dikkat: " .. child.Name .. " event kayd� silindi, sistem �al��maya devam ediyor!")
		end
	end)

	-- Buffer flush i�in Heartbeat
	self.flushConnection = game:GetService("RunService").Heartbeat:Connect(function()
		if tick() - self._lastFlush >= EventConfig.FlushInterval then
			self:FlushBuffer()
			self._lastFlush = tick()
			for eventName in pairs(fireCounts) do -- Rate limit s�f�rlama
				fireCounts[eventName] = 0
			end
		end
	end)
end

function RemoteEventManager:InitializeEvents()
	local xpManager = self.dependencies.XPManager
	local statManager = self.dependencies.StatManager

	self:RegisterEvent("AddXPEvent", function(self, player, xpAmount)
		xpManager:AddXP(player, xpAmount)
		statManager:UpdateStats(player)
		self:FireClient("AddXPEvent", player, xpManager:GetXP(player), xpManager:GetLevel(player), xpManager:GetStatPoints(player))
	end, function(player, args)
		return typeof(args[1]) == "number" and args[1] > 0
	end)

	self:RegisterEvent("IncreaseStatEvent", function(self, player, statName)
		local statPoints = player:GetAttribute("StatPoints") or 0
		if statPoints <= 0 then
			Logger:Warn(Logger.Categories.EventLogs, "Stat puan� yetersiz: " .. player.Name .. " - " .. statName)
			return
		end
		local currentValue = player:GetAttribute(statName) or 0
		player:SetAttribute(statName, currentValue + 1)
		player:SetAttribute("StatPoints", statPoints - 1)
		statManager:UpdateStats(player)
		self:FireClient("IncreaseStatEvent", player, statName, currentValue + 1, statPoints - 1)
		Logger:Info(Logger.Categories.EventLogs, player.Name .. " stat art�rd�: " .. statName .. " -> " .. (currentValue + 1) .. ", Kalan Stat Points: " .. (statPoints - 1))
	end, function(player, args)
		local statName = args[1]
		return typeof(statName) == "string" and (statName == "Strength" or statName == "Dexterity" or statName == "Intelligence" or statName == "Vitality")
	end)

	self:RegisterEvent("ResourceUpdateEvent", function(self, player, resourceName, newValue)
		if resourceName == "CurrentHP" then
			local humanoid = player.Character and player.Character:FindFirstChild("Humanoid")
			if humanoid then
				humanoid.Health = newValue
				Logger:Trace(Logger.Categories.EventLogs, player.Name .. " Humanoid.Health g�ncellendi: " .. humanoid.Health)
			else
				Logger:Warn(Logger.Categories.EventLogs, player.Name .. " i�in Humanoid bulunamad�!")
			end
		else
			player:SetAttribute(resourceName, newValue)
		end
		self:FireClient("ResourceUpdateEvent", player, resourceName, newValue)
		Logger:Trace(Logger.Categories.EventLogs, player.Name .. " " .. resourceName .. " g�ncellendi: " .. newValue)
	end, function(player, args)
		local resourceName, newValue = args[1], args[2]
		return typeof(resourceName) == "string" and typeof(newValue) == "number" and newValue >= 0 and
			(resourceName == "CurrentHP" or resourceName == "CurrentMana" or resourceName == "CurrentStamina")
	end)

	self:RegisterEvent("UpdateStatsEvent", function(self, player)
		statManager:UpdateStats(player)
	end, function(player, args)
		return #args == 0
	end)

	self:StartMonitoring()
end

return RemoteEventManager