-- InitAllTester.lua
-- Bu script, InitAll modülünün geliþtirilen özelliklerini test eder

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")

local InitAll = require(ServerScriptService.InitAll)
local Logger = require(ServerScriptService.Logger)

require(game:GetService("ServerScriptService").InitAllTester).RunAll()
require(game:GetService("ServerScriptService").InitAllTester).GenerateReport()

local InitAllTester = {}

-- Test durumlarý
InitAllTester.Tests = {
	ModuleLoading = {
		Name = "Modül Yükleme Testi",
		Description = "Tüm modüllerin doðru sýrayla yüklendiðini test eder",
		Run = function()
			local result = {}
			local passed = true

			-- Tüm beklenen modüllerin yüklenip yüklenmediðini kontrol et
			local expectedModules = {"XPManager", "StatManager", "RemoteEventManager", "RegenerationManager"}

			for _, moduleName in ipairs(expectedModules) do
				local module = InitAll:GetModule(moduleName)
				if not module then
					table.insert(result, "- " .. moduleName .. " modülü yüklenemedi")
					passed = false
				else
					table.insert(result, "+ " .. moduleName .. " modülü baþarýyla yüklendi")
				end
			end

			-- Baðýmlýlýklarýn doðru enjekte edilip edilmediðini kontrol et
			local remoteEventManager = InitAll:GetModule("RemoteEventManager")
			local regManager = InitAll:GetModule("RegenerationManager")

			if remoteEventManager and not remoteEventManager.dependencies.XPManager then
				table.insert(result, "- RemoteEventManager'a XPManager baðýmlýlýðý enjekte edilmemiþ")
				passed = false
			else
				table.insert(result, "+ RemoteEventManager baðýmlýlýklarý doðru enjekte edilmiþ")
			end

			if regManager and not regManager.dependencies.StatManager then
				table.insert(result, "- RegenerationManager'a StatManager baðýmlýlýðý enjekte edilmemiþ")
				passed = false
			else
				table.insert(result, "+ RegenerationManager baðýmlýlýklarý doðru enjekte edilmiþ")
			end

			return passed, table.concat(result, "\n")
		end
	},

	EventSystem = {
		Name = "Event Sistemi Testi",
		Description = "RemoteEvent'lerin doðru oluþturulduðunu test eder",
		Run = function()
			local result = {}
			local passed = true

			-- Gerekli tüm RemoteEvent'lerin oluþturulduðunu kontrol et
			local expectedEvents = {"AddXPEvent", "IncreaseStatEvent", "ResourceUpdateEvent", "UpdateStatsEvent"}

			for _, eventName in ipairs(expectedEvents) do
				local event = game:GetService("ReplicatedStorage"):FindFirstChild(eventName)
				if not event then
					table.insert(result, "- " .. eventName .. " bulunamadý")
					passed = false
				else
					table.insert(result, "+ " .. eventName .. " baþarýyla oluþturulmuþ")
				end
			end

			return passed, table.concat(result, "\n")
		end
	},

	PerformanceMonitoring = {
		Name = "Performans Ýzleme Testi",
		Description = "Performans izleme sisteminin çalýþtýðýný test eder",
		Run = function()
			local result = {}
			local passed = true

			-- InitAll'da performanceStats nesnesinin var olduðunu kontrol et
			if not InitAll.performanceStats then
				table.insert(result, "- Performans metrikleri nesnesi bulunamadý")
				passed = false
			else
				table.insert(result, "+ Performans metrikleri nesnesi mevcut")
			end

			-- Modül yükleme sürelerinin kaydedildiðini kontrol et
			if not InitAll.performanceStats.moduleLoadTimes or not next(InitAll.performanceStats.moduleLoadTimes) then
				table.insert(result, "- Modül yükleme süreleri kaydedilmemiþ")
				passed = false
			else
				local count = 0
				for _, _ in pairs(InitAll.performanceStats.moduleLoadTimes) do
					count = count + 1
				end
				table.insert(result, "+ " .. count .. " modül için yükleme süreleri kaydedilmiþ")
			end

			-- Performans monitörü baðlantýsýnýn kurulduðunu kontrol et
			if not InitAll.connections or not InitAll.connections.PerformanceMonitor then
				table.insert(result, "- Performans izleme baðlantýsý kurulmamýþ")
				passed = false
			else
				table.insert(result, "+ Performans izleme baðlantýsý kurulmuþ")
			end

			return passed, table.concat(result, "\n")
		end
	},

	ShutdownHandler = {
		Name = "Güvenli Kapatma Testi",
		Description = "Kapatma iþleyicisinin kurulduðunu test eder (tam test için sunucu kapatýlmalý)",
		Run = function()
			local result = {}
			local passed = true

			-- Kapatma iþleyicisinin kurulduðunu kontrol et
			if InitAll.isShuttingDown == nil then
				table.insert(result, "- Kapatma durum bayraðý tanýmlanmamýþ")
				passed = false
			else
				table.insert(result, "+ Kapatma durum bayraðý tanýmlanmýþ")
			end

			-- Not: Gerçek kapatma testi için sunucunun kapanmasý gerekir
			table.insert(result, "Not: Tam kapatma testi için sunucunun kapatýlmasý gerekir")

			return passed, table.concat(result, "\n")
		end
	},

	PlayerManagement = {
		Name = "Oyuncu Yönetimi Testi",
		Description = "Oyuncu ekleme/çýkarma iþleyicilerinin kurulduðunu test eder",
		Run = function()
			local result = {}
			local passed = true

			-- Oyuncu baðlantýlarýnýn kurulduðunu kontrol et
			if not InitAll.connections or not InitAll.connections.PlayerAdded then
				table.insert(result, "- PlayerAdded baðlantýsý kurulmamýþ")
				passed = false
			else
				table.insert(result, "+ PlayerAdded baðlantýsý kurulmuþ")
			end

			if not InitAll.connections or not InitAll.connections.PlayerRemoving then
				table.insert(result, "- PlayerRemoving baðlantýsý kurulmamýþ")
				passed = false
			else
				table.insert(result, "+ PlayerRemoving baðlantýsý kurulmuþ")
			end

			-- Oyuncu baþlatma metodunun çalýþtýðýný test et
			local playerCount = #Players:GetPlayers()
			table.insert(result, "Mevcut oyuncu sayýsý: " .. playerCount)

			if playerCount > 0 and InitAll.performanceStats.playerInitTimes then
				local initTimesCount = 0
				for _, _ in pairs(InitAll.performanceStats.playerInitTimes) do
					initTimesCount = initTimesCount + 1
				end
				if initTimesCount > 0 then
					table.insert(result, "+ Oyuncu baþlatma süreleri kaydedilmiþ")
				else
					table.insert(result, "- Oyuncu baþlatma süreleri kaydedilmemiþ")
					passed = false
				end
			end

			return passed, table.concat(result, "\n")
		end
	}
}

-- Test çalýþtýrýcý
function InitAllTester.RunAll()
	Logger:Info(Logger.Categories.ConsoleLogs, "InitAll Test Baþlatýlýyor...")
	local passedCount = 0
	local failedCount = 0

	for testKey, test in pairs(InitAllTester.Tests) do
		Logger:Info(Logger.Categories.ConsoleLogs, "Test: " .. test.Name)
		Logger:Debug(Logger.Categories.ConsoleLogs, test.Description)

		local success, result = pcall(function()
			return test.Run()
		end)

		if success then
			local passed = result
			local details = ""

			if type(result) == "table" and #result >= 2 then
				passed = result[1]
				details = result[2]
			end
			if passed then
				Logger:Info(Logger.Categories.ConsoleLogs, "? Test Baþarýlý: " .. test.Name)
				passedCount = passedCount + 1
			else
				Logger:Error(Logger.Categories.ConsoleLogs, "? Test Baþarýsýz: " .. test.Name)
				failedCount = failedCount + 1
			end
			Logger:Debug(Logger.Categories.ConsoleLogs, details)
		else
			Logger:Error(Logger.Categories.ConsoleLogs, "? Test Hatasý: " .. result)
			failedCount = failedCount + 1
		end
	end

	Logger:Info(Logger.Categories.ConsoleLogs, "=== Test Sonuçlarý ===")
	Logger:Info(Logger.Categories.ConsoleLogs, "Toplam test: " .. (passedCount + failedCount))
	Logger:Info(Logger.Categories.ConsoleLogs, "Baþarýlý: " .. passedCount)
	Logger:Info(Logger.Categories.ConsoleLogs, "Baþarýsýz: " .. failedCount)

	return passedCount, failedCount
end

-- Test sonuçlarýný raporlama
function InitAllTester.GenerateReport()
	Logger:Info(Logger.Categories.ConsoleLogs, "Performans raporu isteniyor...")
	InitAll:GeneratePerformanceReport()
end

return InitAllTester