local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Logger = {}
Logger.__index = Logger

local LogLevels = {
	TRACE = 1, DEBUG = 2, INFO = 3, WARN = 4, ERROR = 5, FATAL = 6, AUDIT = 7
}

Logger.Categories = {
	ConsoleLogs = "ConsoleLogs",
	NetworkLogs = "NetworkLogs",
	EventLogs = "EventLogs",
	Performance = "Performance",
	ClientLogs = "ClientLogs"
}

-- Dokümantasyon: Log Seviyeleri ve Kategoriler (Prensip 17)
local LogDocumentation = {
	Levels = {
		TRACE = "Detaylý izleme için düþük seviye loglar",
		DEBUG = "Hata ayýklama için teknik bilgiler",
		INFO = "Genel bilgi mesajlarý",
		WARN = "Potansiyel sorun uyarýlarý",
		ERROR = "Hatalar ve istisnalar",
		FATAL = "Kritik sistem durmalarý",
		AUDIT = "Denetim ve güvenlik loglarý"
	},
	Categories = {
		ConsoleLogs = "Konsol ile ilgili genel loglar",
		NetworkLogs = "Að iþlemleri ile ilgili loglar",
		EventLogs = "Olay tetiklemeleri ve sonuçlarý",
		Performance = "Performans ölçümleri",
		ClientLogs = "Client’tan gelen loglar"
	}
}

local Config = {
	MinLevel = LogLevels.TRACE,
	BufferSize = 10,
	FlushInterval = 1,
	MaxCacheSize = 1000,
	MaxMessageLength = 200, -- Güvenlik için sýnýr (Prensip 6)
	EnabledCategories = {
		[Logger.Categories.ConsoleLogs] = true,
		[Logger.Categories.NetworkLogs] = true,
		[Logger.Categories.EventLogs] = true,
		[Logger.Categories.Performance] = true,
		[Logger.Categories.ClientLogs] = true
	},
	CategoryLevels = {}
}

local LoggerInstance = nil
local isInitialized = false

local LevelChangedEvent = Instance.new("BindableEvent")
Logger.LevelChanged = LevelChangedEvent.Event

local LogToServerEvent = Instance.new("RemoteEvent")
LogToServerEvent.Name = "LogToServer"
LogToServerEvent.Parent = ReplicatedStorage

function Logger.new()
	if isInitialized then return LoggerInstance end

	local success, err = pcall(function()
		print("[Logger] Initializing Logger...")
	end)
	if not success then warn("[Logger] Initialization failed: " .. err) end

	local self = setmetatable({
		_buffer = {}, -- Kategoriye göre tablo: { [category] = { {Level, Message}, ... } }
		_lastFlush = tick(),
		_logCache = {}
	}, Logger)

	local heartbeatConnection
	heartbeatConnection = RunService.Heartbeat:Connect(function()
		if self:GetBufferSize() > 0 and tick() - self._lastFlush >= Config.FlushInterval then -- Koþullu Heartbeat
			self:FlushBuffer()
		end
	end)
	self._heartbeatConnection = heartbeatConnection

	self:SetupClientProxy()
	LoggerInstance = self
	isInitialized = true
	return self
end

function Logger:SetupClientProxy()
	local success, err = pcall(function()
		LogToServerEvent.OnServerEvent:Connect(function(player, level, category, message)
			if typeof(message) ~= "string" or #message > Config.MaxMessageLength then
				warn("[Logger] Invalid client log from " .. player.Name .. ": Message too long or invalid")
				return
			end
			local formattedMessage = string.format("[Client:%s] %s", player.Name, message)
			self:Log(level, category, formattedMessage)
		end)
	end)
	if not success then warn("[Logger] Client proxy setup failed: " .. err) end
end

function Logger:AddCategory(categoryName)
	if not self.Categories[categoryName] then
		self.Categories[categoryName] = categoryName
		Config.EnabledCategories[categoryName] = true
		self:Trace(self.Categories.ConsoleLogs, "Yeni kategori eklendi: " .. categoryName)
	end
end

function Logger:SetCategoryLevel(category, level)
	if LogLevels[level] then
		Config.CategoryLevels[category] = LogLevels[level]
		self:Info(self.Categories.ConsoleLogs, "Kategori seviyesi ayarlandý: " .. category .. " -> " .. level)
		LevelChangedEvent:Fire(category, level)
	else
		self:Error(self.Categories.ConsoleLogs, "Geçersiz log seviyesi: " .. tostring(level))
	end
end

local function formatLog(self, level, category, message)
	local key = level .. category .. message
	if not self._logCache[key] then
		local cacheSize = 0
		for _ in pairs(self._logCache) do cacheSize = cacheSize + 1 end
		if cacheSize >= Config.MaxCacheSize then
			local oldestKey = next(self._logCache)
			self._logCache[oldestKey] = nil
			self:Trace(self.Categories.ConsoleLogs, "Log cache sýnýrýna ulaþýldý, eski giriþ silindi.")
		end
		local timestamp = os.date("%Y-%m-%d %H:%M:%S")
		self._logCache[key] = string.format('{"timestamp":"%s","level":"%s","category":"%s","message":"%s"}', 
			timestamp, level, category, message)
	end
	return self._logCache[key]
end

function Logger:Log(level, category, message)
	local levelValue = LogLevels[level] or LogLevels.INFO
	local categoryLevel = Config.CategoryLevels[category] or Config.MinLevel

	if levelValue < categoryLevel or not Config.EnabledCategories[category] then return end

	local success, logMessage = pcall(function()
		return formatLog(self, level, category, message)
	end)
	if not success then
		warn("[Logger] Log message formatting failed: " .. logMessage)
		return
	end

	local bufferSuccess, bufferErr = pcall(function()
		self._buffer[category] = self._buffer[category] or {}
		table.insert(self._buffer[category], { Level = level, Message = logMessage })
		if self:GetBufferSize() >= Config.BufferSize then
			self:FlushBuffer()
		end
	end)
	if not bufferSuccess then warn("[Logger] Buffer addition failed: " .. bufferErr) end
end

function Logger:GetBufferSize()
	local size = 0
	for _, logs in pairs(self._buffer) do
		size = size + #logs
	end
	return size
end

function Logger:ParseMessage(jsonMessage)
	-- JSON’dan sadece mesajý çýkar
	return jsonMessage:match('"message":"(.-)"') or jsonMessage
end

function Logger:FlushBuffer()
	if self:GetBufferSize() == 0 then return end

	local success, err = pcall(function()
		for category, logs in pairs(self._buffer) do
			print("[" .. category .. "]")
			for _, log in ipairs(logs) do
				local simpleLog = string.format("[%s] %s", log.Level, self:ParseMessage(log.Message))
				if LogLevels[log.Level] >= LogLevels.WARN then
					warn("  " .. simpleLog) -- Girinti ile kategori altýnda
				else
					print("  " .. simpleLog)
				end
			end
		end
	end)
	if not success then warn("[Logger] FlushBuffer failed: " .. err) end

	self._buffer = {} -- Yeni tablo
	self._lastFlush = tick()
end

-- Loglama metodlarý
function Logger:Trace(category, message) self:Log("TRACE", category, message) end
function Logger:Debug(category, message) self:Log("DEBUG", category, message) end
function Logger:Info(category, message) self:Log("INFO", category, message) end
function Logger:Warn(category, message) self:Log("WARN", category, message) end
function Logger:Error(category, message) self:Log("ERROR", category, message) end
function Logger:Fatal(category, message) self:Log("FATAL", category, message) end
function Logger:Audit(category, message) self:Log("AUDIT", category, message) end

-- Özel loglama metodlarý
function Logger:LogLoot(player, item, rarity)
	self:Info(self.Categories.EventLogs, string.format("Player %s looted %s (%s)", player.Name, item, rarity or "Common"))
end

function Logger:LogCombat(attacker, target, damage)
	self:Debug(self.Categories.EventLogs, string.format("Player %s dealt %d damage to %s", attacker.Name, damage, target.Name))
end

function Logger:LogStatCalculation(player, stat, value)
	self:Trace(self.Categories.EventLogs, string.format("Player %s stat %s calculated as %d", player.Name, stat, value))
end

function Logger:LogPerformance(metric, value)
	self:Info(self.Categories.Performance, string.format("%s: %s", metric, value))
end

function Logger:SetupLevelChangedListener()
	LevelChangedEvent.Event:Connect(function(category, level)
		self:Info(self.Categories.ConsoleLogs, "LevelChanged tetiklendi: " .. category .. " -> " .. level)
	end)
end

-- Singleton baþlatma
local logger
if not isInitialized then
	logger = Logger.new()
	print("[Logger] Module loaded successfully")
	logger:Info(logger.Categories.ConsoleLogs, "Logger sistemi hazýr.")
	logger:SetupLevelChangedListener()
else
	logger = LoggerInstance
end
return logger