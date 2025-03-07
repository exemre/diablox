-- InitAllTester.lua
-- Bu script, InitAll mod�l�n�n geli�tirilen �zelliklerini test eder

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")

local InitAll = require(ServerScriptService.InitAll)
local Logger = require(ServerScriptService.Logger)

require(game:GetService("ServerScriptService").InitAllTester).RunAll()
require(game:GetService("ServerScriptService").InitAllTester).GenerateReport()

local InitAllTester = {}

-- Test durumlar�
InitAllTester.Tests = {
	ModuleLoading = {
		Name = "Mod�l Y�kleme Testi",
		Description = "T�m mod�llerin do�ru s�rayla y�klendi�ini test eder",
		Run = function()
			local result = {}
			local passed = true

			-- T�m beklenen mod�llerin y�klenip y�klenmedi�ini kontrol et
			local expectedModules = {"XPManager", "StatManager", "RemoteEventManager", "RegenerationManager"}

			for _, moduleName in ipairs(expectedModules) do
				local module = InitAll:GetModule(moduleName)
				if not module then
					table.insert(result, "- " .. moduleName .. " mod�l� y�klenemedi")
					passed = false
				else
					table.insert(result, "+ " .. moduleName .. " mod�l� ba�ar�yla y�klendi")
				end
			end

			-- Ba��ml�l�klar�n do�ru enjekte edilip edilmedi�ini kontrol et
			local remoteEventManager = InitAll:GetModule("RemoteEventManager")
			local regManager = InitAll:GetModule("RegenerationManager")

			if remoteEventManager and not remoteEventManager.dependencies.XPManager then
				table.insert(result, "- RemoteEventManager'a XPManager ba��ml�l��� enjekte edilmemi�")
				passed = false
			else
				table.insert(result, "+ RemoteEventManager ba��ml�l�klar� do�ru enjekte edilmi�")
			end

			if regManager and not regManager.dependencies.StatManager then
				table.insert(result, "- RegenerationManager'a StatManager ba��ml�l��� enjekte edilmemi�")
				passed = false
			else
				table.insert(result, "+ RegenerationManager ba��ml�l�klar� do�ru enjekte edilmi�")
			end

			return passed, table.concat(result, "\n")
		end
	},

	EventSystem = {
		Name = "Event Sistemi Testi",
		Description = "RemoteEvent'lerin do�ru olu�turuldu�unu test eder",
		Run = function()
			local result = {}
			local passed = true

			-- Gerekli t�m RemoteEvent'lerin olu�turuldu�unu kontrol et
			local expectedEvents = {"AddXPEvent", "IncreaseStatEvent", "ResourceUpdateEvent", "UpdateStatsEvent"}

			for _, eventName in ipairs(expectedEvents) do
				local event = game:GetService("ReplicatedStorage"):FindFirstChild(eventName)
				if not event then
					table.insert(result, "- " .. eventName .. " bulunamad�")
					passed = false
				else
					table.insert(result, "+ " .. eventName .. " ba�ar�yla olu�turulmu�")
				end
			end

			return passed, table.concat(result, "\n")
		end
	},

	PerformanceMonitoring = {
		Name = "Performans �zleme Testi",
		Description = "Performans izleme sisteminin �al��t���n� test eder",
		Run = function()
			local result = {}
			local passed = true

			-- InitAll'da performanceStats nesnesinin var oldu�unu kontrol et
			if not InitAll.performanceStats then
				table.insert(result, "- Performans metrikleri nesnesi bulunamad�")
				passed = false
			else
				table.insert(result, "+ Performans metrikleri nesnesi mevcut")
			end

			-- Mod�l y�kleme s�relerinin kaydedildi�ini kontrol et
			if not InitAll.performanceStats.moduleLoadTimes or not next(InitAll.performanceStats.moduleLoadTimes) then
				table.insert(result, "- Mod�l y�kleme s�releri kaydedilmemi�")
				passed = false
			else
				local count = 0
				for _, _ in pairs(InitAll.performanceStats.moduleLoadTimes) do
					count = count + 1
				end
				table.insert(result, "+ " .. count .. " mod�l i�in y�kleme s�releri kaydedilmi�")
			end

			-- Performans monit�r� ba�lant�s�n�n kuruldu�unu kontrol et
			if not InitAll.connections or not InitAll.connections.PerformanceMonitor then
				table.insert(result, "- Performans izleme ba�lant�s� kurulmam��")
				passed = false
			else
				table.insert(result, "+ Performans izleme ba�lant�s� kurulmu�")
			end

			return passed, table.concat(result, "\n")
		end
	},

	ShutdownHandler = {
		Name = "G�venli Kapatma Testi",
		Description = "Kapatma i�leyicisinin kuruldu�unu test eder (tam test i�in sunucu kapat�lmal�)",
		Run = function()
			local result = {}
			local passed = true

			-- Kapatma i�leyicisinin kuruldu�unu kontrol et
			if InitAll.isShuttingDown == nil then
				table.insert(result, "- Kapatma durum bayra�� tan�mlanmam��")
				passed = false
			else
				table.insert(result, "+ Kapatma durum bayra�� tan�mlanm��")
			end

			-- Not: Ger�ek kapatma testi i�in sunucunun kapanmas� gerekir
			table.insert(result, "Not: Tam kapatma testi i�in sunucunun kapat�lmas� gerekir")

			return passed, table.concat(result, "\n")
		end
	},

	PlayerManagement = {
		Name = "Oyuncu Y�netimi Testi",
		Description = "Oyuncu ekleme/��karma i�leyicilerinin kuruldu�unu test eder",
		Run = function()
			local result = {}
			local passed = true

			-- Oyuncu ba�lant�lar�n�n kuruldu�unu kontrol et
			if not InitAll.connections or not InitAll.connections.PlayerAdded then
				table.insert(result, "- PlayerAdded ba�lant�s� kurulmam��")
				passed = false
			else
				table.insert(result, "+ PlayerAdded ba�lant�s� kurulmu�")
			end

			if not InitAll.connections or not InitAll.connections.PlayerRemoving then
				table.insert(result, "- PlayerRemoving ba�lant�s� kurulmam��")
				passed = false
			else
				table.insert(result, "+ PlayerRemoving ba�lant�s� kurulmu�")
			end

			-- Oyuncu ba�latma metodunun �al��t���n� test et
			local playerCount = #Players:GetPlayers()
			table.insert(result, "Mevcut oyuncu say�s�: " .. playerCount)

			if playerCount > 0 and InitAll.performanceStats.playerInitTimes then
				local initTimesCount = 0
				for _, _ in pairs(InitAll.performanceStats.playerInitTimes) do
					initTimesCount = initTimesCount + 1
				end
				if initTimesCount > 0 then
					table.insert(result, "+ Oyuncu ba�latma s�releri kaydedilmi�")
				else
					table.insert(result, "- Oyuncu ba�latma s�releri kaydedilmemi�")
					passed = false
				end
			end

			return passed, table.concat(result, "\n")
		end
	}
}

-- Test �al��t�r�c�
function InitAllTester.RunAll()
	Logger:Info(Logger.Categories.ConsoleLogs, "InitAll Test Ba�lat�l�yor...")
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
				Logger:Info(Logger.Categories.ConsoleLogs, "? Test Ba�ar�l�: " .. test.Name)
				passedCount = passedCount + 1
			else
				Logger:Error(Logger.Categories.ConsoleLogs, "? Test Ba�ar�s�z: " .. test.Name)
				failedCount = failedCount + 1
			end
			Logger:Debug(Logger.Categories.ConsoleLogs, details)
		else
			Logger:Error(Logger.Categories.ConsoleLogs, "? Test Hatas�: " .. result)
			failedCount = failedCount + 1
		end
	end

	Logger:Info(Logger.Categories.ConsoleLogs, "=== Test Sonu�lar� ===")
	Logger:Info(Logger.Categories.ConsoleLogs, "Toplam test: " .. (passedCount + failedCount))
	Logger:Info(Logger.Categories.ConsoleLogs, "Ba�ar�l�: " .. passedCount)
	Logger:Info(Logger.Categories.ConsoleLogs, "Ba�ar�s�z: " .. failedCount)

	return passedCount, failedCount
end

-- Test sonu�lar�n� raporlama
function InitAllTester.GenerateReport()
	Logger:Info(Logger.Categories.ConsoleLogs, "Performans raporu isteniyor...")
	InitAll:GeneratePerformanceReport()
end

return InitAllTester