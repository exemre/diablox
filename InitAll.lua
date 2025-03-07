local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Logger = require(script.Parent.Logger)

-- Config dosyas� (Prensip 12)
local ModuleConfig = {
	Events = { "AddXPEvent", "IncreaseStatEvent", "ResourceUpdateEvent", "UpdateStatsEvent" },
	Modules = {
		{ name = "XPManager", path = script.Parent.XPManager, dependencies = {}, initOrder = 1 },
		{ name = "StatManager", path = script.Parent.StatManager, dependencies = {}, initOrder = 2 },
		{ name = "RemoteEventManager", path = script.Parent.RemoteEventManager, dependencies = { "XPManager", "StatManager" }, initOrder = 3 },
		{ name = "RegenerationManager", path = script.Parent.RegenerationManager, dependencies = { "StatManager", "RemoteEventManager" }, initOrder = 4 }
	},
	ChunkSize = 10,
	PerformanceMonitoring = {
		Enabled = true,
		SamplingInterval = 60,
		DetailLevel = 1,
		MemoryTracking = true
	}
}

local InitAll = {}
InitAll.__index = InitAll

-- Performans metrikleri i�in hafif veri yap�s�
local PerformanceStats = {
	moduleLoadTimes = {},
	playerInitTimes = {},
	startTime = 0,
	lastSampleTime = 0,
	totalMemoryUsage = 0
}

function InitAll.new()
	local self = setmetatable({
		registeredModules = {},
		dependencies = {},
		connections = {}, -- Ba�lant�lar� izlemek i�in
		isShuttingDown = false, -- Kapatma durumunu izlemek i�in
		performanceStats = PerformanceStats
	}, InitAll)
	return self
end

local function getCurrentPlayers()
	return Players:GetPlayers()
end

function InitAll:RegisterModule(moduleName, moduleInstance)
	if not self.registeredModules[moduleName] then
		self.registeredModules[moduleName] = moduleInstance
		Logger:Info(Logger.Categories.ConsoleLogs, "Mod�l kaydedildi: " .. moduleName)
	else
		Logger:Error(Logger.Categories.ConsoleLogs, "Mod�l zaten kay�tl�: " .. moduleName)
	end
end

function InitAll:GetModule(moduleName)
	return self.registeredModules[moduleName]
end

function InitAll:PreCreateEvents()
	for _, name in pairs(ModuleConfig.Events) do
		if not ReplicatedStorage:FindFirstChild(name) then
			local event = Instance.new("RemoteEvent")
			event.Name = name
			event.Parent = ReplicatedStorage
			Logger:Trace(Logger.Categories.ConsoleLogs, "�nceden olu�turuldu: " .. name)
		end
	end
end

-- Ba��ml�l�k kontrol� - iyile�tirilmi�
function InitAll:ValidateDependencies()
	local graphValid = true
	local visited = {}
	local tempVisited = {}

	local function detectCycle(moduleName)
		if tempVisited[moduleName] then
			Logger:Error(Logger.Categories.ConsoleLogs, "D�ng�sel ba��ml�l�k tespit edildi: " .. moduleName)
			return true
		end

		if visited[moduleName] then
			return false
		end

		tempVisited[moduleName] = true

		for _, module in ipairs(ModuleConfig.Modules) do
			if module.name == moduleName then
				for _, depName in ipairs(module.dependencies) do
					if detectCycle(depName) then
						return true
					end
				end
				break
			end
		end

		tempVisited[moduleName] = nil
		visited[moduleName] = true
		return false
	end

	-- T�m mod�ller i�in d�ng� kontrol�
	for _, module in ipairs(ModuleConfig.Modules) do
		if detectCycle(module.name) then
			graphValid = false
		end
	end

	-- T�m ba��ml�l�klar�n ger�ekten var oldu�unu kontrol et
	for _, module in ipairs(ModuleConfig.Modules) do
		for _, depName in ipairs(module.dependencies) do
			local found = false
			for _, potentialDep in ipairs(ModuleConfig.Modules) do
				if potentialDep.name == depName then
					found = true
					break
				end
			end

			if not found then
				Logger:Error(Logger.Categories.ConsoleLogs, "Tan�mlanmam�� ba��ml�l�k: " .. module.name .. " -> " .. depName)
				graphValid = false
			end
		end
	end

	if not graphValid then
		Logger:Error(Logger.Categories.ConsoleLogs, "Ba��ml�l�k graf� ge�erli de�il, sistem d�zg�n �al��mayabilir!")
	end

	return graphValid
end

function InitAll:LoadModules()
	-- Ba��ml�l�k kontrol�
	self:ValidateDependencies()

	-- S�raya g�re mod�lleri y�kle
	local config = ModuleConfig.Modules
	table.sort(config, function(a, b) return a.initOrder < b.initOrder end)

	for _, mod in ipairs(config) do
		local startTime = tick()

		-- Gerekli ba��ml�l�klar� topla
		local dependencies = {}
		for _, depName in pairs(mod.dependencies) do
			dependencies[depName] = self.dependencies[depName]
		end

		local success, instance = pcall(function()
			local module = require(mod.path)
			return module.new(dependencies)
		end)

		-- Performans �l��m�
		local loadTime = tick() - startTime
		PerformanceStats.moduleLoadTimes[mod.name] = loadTime

		if success then
			self:RegisterModule(mod.name, instance)
			self.dependencies[mod.name] = instance
			Logger:Trace(Logger.Categories.Performance, "Mod�l y�kleme s�resi: " .. mod.name .. " - " .. loadTime .. " saniye")
		else
			Logger:Error(Logger.Categories.ConsoleLogs, "Mod�l y�kleme hatas�: " .. mod.name .. " - " .. instance)
		end
	end
end

function InitAll:InitializePlayer(player)
	local startTime = tick()
	local modulesToInit = { "XPManager", "StatManager", "RegenerationManager" }
	local success, result = pcall(function()
		for _, modName in pairs(modulesToInit) do
			local mod = self.dependencies[modName]
			if mod and mod.InitializePlayer then
				mod:InitializePlayer(player)
			end
		end
	end)

	-- Performans �l��m�
	local initTime = tick() - startTime
	PerformanceStats.playerInitTimes[player.UserId] = initTime

	if not success then
		Logger:Error(Logger.Categories.EventLogs, "Oyuncu ba�latma hatas� (" .. player.Name .. "): " .. result)
		return false
	end

	Logger:Trace(Logger.Categories.Performance, "Oyuncu ba�latma s�resi: " .. player.Name .. " - " .. initTime .. " saniye")
	return true
end

function InitAll:BatchInitializePlayers(players)
	local startTime = tick()
	local successCount = 0
	for i = 1, #players, ModuleConfig.ChunkSize do
		local chunk = { table.unpack(players, i, math.min(i + ModuleConfig.ChunkSize - 1, #players)) }
		for _, player in pairs(chunk) do
			if self:InitializePlayer(player) then
				successCount = successCount + 1
			end
		end
		task.wait(0.1) -- Performans i�in ara (Prensip 9)
	end
	Logger:Trace(Logger.Categories.Performance, "Toplu oyuncu ba�latma s�resi: " .. (tick() - startTime) .. " saniye, Ba�ar�l�: " .. successCount .. "/" .. #players)
end

-- Hafif performans izleme
function InitAll:StartPerformanceMonitoring()
	if not ModuleConfig.PerformanceMonitoring.Enabled then return end

	local monitorConnection = RunService.Heartbeat:Connect(function()
		if tick() - PerformanceStats.lastSampleTime < ModuleConfig.PerformanceMonitoring.SamplingInterval then return end

		local statsSuccess, memStats = pcall(function()
			return game:GetService("Stats")
		end)

		if statsSuccess and ModuleConfig.PerformanceMonitoring.MemoryTracking then
			PerformanceStats.totalMemoryUsage = memStats:GetTotalMemoryUsageMb() * 1024 * 1024

			-- Sadece detay seviyesi 2 ve �zerinde kapsaml� log g�nder
			if ModuleConfig.PerformanceMonitoring.DetailLevel >= 2 then
				Logger:Trace(Logger.Categories.Performance, string.format(
					"Haf�za Kullan�m�: %.2f MB", 
					PerformanceStats.totalMemoryUsage / (1024 * 1024)
					))
			end
		end

		PerformanceStats.lastSampleTime = tick()
	end)

	self.connections["PerformanceMonitor"] = monitorConnection
	Logger:Info(Logger.Categories.Performance, "Performans izleme ba�lat�ld�")
end

-- G�venli kapatma mekanizmas�
function InitAll:SetupShutdownHandler()
	game:BindToClose(function()
		self.isShuttingDown = true
		Logger:Info(Logger.Categories.ConsoleLogs, "Sistem kapat�l�yor...")

		-- T�m mod�lleri g�venli �ekilde kapat
		for name, module in pairs(self.registeredModules) do
			if module.Shutdown then
				local success, err = pcall(function()
					module:Shutdown()
				end)

				if not success then
					Logger:Error(Logger.Categories.ConsoleLogs, "Mod�l kapatma hatas�: " .. name .. " - " .. err)
				else
					Logger:Info(Logger.Categories.ConsoleLogs, "Mod�l g�venle kapat�ld�: " .. name)
				end
			end
		end

		-- T�m ba�lant�lar� kapat
		for name, connection in pairs(self.connections) do
			if connection and connection.Connected then
				connection:Disconnect()
				Logger:Trace(Logger.Categories.ConsoleLogs, "Ba�lant� kapat�ld�: " .. name)
			end
		end

		-- Performans raporunu g�ster
		self:GeneratePerformanceReport()

		Logger:Info(Logger.Categories.ConsoleLogs, "Sistem g�venle kapat�ld�.")
		return true -- Kapatma i�leminin tamamland���n� belirt
	end)

	Logger:Info(Logger.Categories.ConsoleLogs, "Kapatma i�leyicisi kuruldu")
end

-- Performans raporu olu�tur
function InitAll:GeneratePerformanceReport()
	Logger:Info(Logger.Categories.Performance, "===== Performans Raporu =====")

	-- Mod�l y�kleme s�releri
	Logger:Info(Logger.Categories.Performance, "Mod�l Y�kleme S�releri:")
	for moduleName, loadTime in pairs(PerformanceStats.moduleLoadTimes) do
		Logger:Info(Logger.Categories.Performance, "  " .. moduleName .. ": " .. loadTime .. " saniye")
	end

	-- Sistem �al��ma s�resi
	local uptime = tick() - PerformanceStats.startTime
	Logger:Info(Logger.Categories.Performance, "Toplam �al��ma S�resi: " .. uptime .. " saniye")

	-- Haf�za kullan�m�
	if ModuleConfig.PerformanceMonitoring.MemoryTracking then
		Logger:Info(Logger.Categories.Performance, string.format(
			"Son Haf�za Kullan�m�: %.2f MB", 
			PerformanceStats.totalMemoryUsage / (1024 * 1024)
			))
	end

	Logger:Info(Logger.Categories.Performance, "===========================")
end

function InitAll:Start()
	PerformanceStats.startTime = tick()
	Logger:Info(Logger.Categories.ConsoleLogs, "Sistem ba�lat�l�yor...")

	self:PreCreateEvents()
	self:LoadModules()

	if not next(self.dependencies) then
		Logger:Fatal(Logger.Categories.ConsoleLogs, "Hi�bir mod�l y�klenemedi, sistem durduruluyor!")
		return
	end

	local remoteEventManager = self.dependencies.RemoteEventManager
	if remoteEventManager then
		local success, err = pcall(function()
			remoteEventManager:InitializeEvents()
		end)
		if not success then
			Logger:Error(Logger.Categories.ConsoleLogs, "Event ba�latma hatas�: " .. err)
			Logger:Warn(Logger.Categories.ConsoleLogs, "Sistem �al��maya devam ediyor, ancak event'lar eksik olabilir.")
		end
	else
		Logger:Error(Logger.Categories.ConsoleLogs, "RemoteEventManager bulunamad�, sistem s�n�rl� modda �al��acak!")
	end

	-- Oyuncu ba�lant�lar�n� kur
	local playerAddedConnection = Players.PlayerAdded:Connect(function(player)
		self:InitializePlayer(player)
	end)
	self.connections["PlayerAdded"] = playerAddedConnection

	local playerRemovingConnection = Players.PlayerRemoving:Connect(function(player)
		-- Mod�llere oyuncu ayr�lma bilgisini ilet
		for name, module in pairs(self.registeredModules) do
			if module.OnPlayerRemoving then
				pcall(function()
					module:OnPlayerRemoving(player)
				end)
			end
		end
	end)
	self.connections["PlayerRemoving"] = playerRemovingConnection

	local currentPlayers = getCurrentPlayers()
	self:BatchInitializePlayers(currentPlayers)

	-- Performans izleme ve g�venli kapatma
	self:StartPerformanceMonitoring()
	self:SetupShutdownHandler()

	Logger:Info(Logger.Categories.Performance, "Sistem ba�latma s�resi: " .. (tick() - PerformanceStats.startTime) .. " saniye")
	Logger:Info(Logger.Categories.ConsoleLogs, "InitAll sistemi haz�r.")
end

-- Otomatik ba�latma
local initAll = InitAll.new()
initAll:Start()

return initAll