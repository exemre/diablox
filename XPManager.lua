-- ServerScriptService > XPManager.lua (ModuleScript)
-- Diablo 4’ten ilham alan XP ve seviye sistemi: Oyuncularýn XP kazanmasýný, seviye atlamasýný ve stat puanlarýný yönetir.

local XPManager = {}
XPManager.__index = XPManager

local Logger = require(script.Parent.Logger)

-- Ayarlanabilir yapýlandýrma tablosu (Prensip 12: Esnek Entegrasyon Stratejileri)
local Config = {
	BaseXP = 500,
	GrowthRate = 1.2,
	FixedFactor = 2000,
	MaxLevel = 100,
	StatPointsPerLevel = 5,
	LevelFactorBase = 10,
	LevelFactorFunction = function(level) -- Yeni: Global hesaplama fonksiyonu
		return math.max(1, level / 10)
	end
}

-- XP eþik tablosu ve hesaplama kontrolü (Prensip 14: Algoritma ve Mantýk Optimizasyonu)
local LevelXP = {}
local isCalculated = false
local function CalculateLevelXP()
	if isCalculated then return end
	for level = 1, Config.MaxLevel do
		local xpNeeded = Config.BaseXP * (Config.GrowthRate ^ level) + level * Config.FixedFactor
		LevelXP[level] = math.floor(math.min(xpNeeded, 2^53))
	end
	isCalculated = true
end
CalculateLevelXP()

-- Yeni: Seviye atlama eventi (Prensip 1: Entegrasyon ve Uyumluluk)
local LevelUpEvent = Instance.new("BindableEvent")
XPManager.LevelUpEvent = LevelUpEvent.Event

function XPManager.new()
	local self = setmetatable({}, XPManager)
	return self
end

function XPManager:InitializePlayer(player)
	local initialized = false
	if player:GetAttribute("XP") == nil then
		player:SetAttribute("XP", 0)
		initialized = true
	end
	if player:GetAttribute("Level") == nil then
		player:SetAttribute("Level", 1)
		initialized = true
	end
	if player:GetAttribute("StatPoints") == nil then
		player:SetAttribute("StatPoints", 0)
		initialized = true
	end
	if player:GetAttribute("RequiredXP") == nil then
		player:SetAttribute("RequiredXP", LevelXP[1] or 0)
		initialized = true
	end
	if initialized then
		Logger:Trace(Logger.Categories.EventLogs, "Initialized player data for " .. player.Name .. " with UserId: " .. player.UserId)
	end
end

function XPManager:AddXP(player, xpAmount)
	Logger:Trace(Logger.Categories.EventLogs, "AddXP called for " .. player.Name .. " with UserId: " .. player.UserId .. ", Amount: " .. xpAmount)

	local success, err = pcall(function()
		self:InitializePlayer(player)
		local level = self:GetAttribute(player, "Level")
		local levelFactor = Config.LevelFactorFunction(level) -- Yeni: Global config’ten alýnýr
		local adjustedXP = xpAmount * levelFactor

		if adjustedXP < 1 then
			Logger:Audit(Logger.Categories.EventLogs, "Unusually low XP gain detected for " .. player.Name .. ": " .. adjustedXP)
		end

		local currentXP = self:GetAttribute(player, "XP")
		player:SetAttribute("XP", currentXP + adjustedXP)
		Logger:Trace(Logger.Categories.EventLogs, "XP calculated for " .. player.Name .. ": +" .. adjustedXP .. " (Total: " .. player:GetAttribute("XP") .. ")")
		Logger:Info(Logger.Categories.EventLogs, "Player " .. player.Name .. " gained " .. adjustedXP .. " XP (Total: " .. player:GetAttribute("XP") .. ")")

		self:CheckLevelUp(player)
	end)

	if not success then
		Logger:Error(Logger.Categories.EventLogs, "AddXP hatasý: " .. err)
	end
end

function XPManager:CheckLevelUp(player)
	local success, err = pcall(function()
		local currentXP = self:GetAttribute(player, "XP")
		local currentLevel = self:GetAttribute(player, "Level")
		while currentLevel < Config.MaxLevel and currentXP >= (LevelXP[currentLevel] or math.huge) do
			currentLevel = currentLevel + 1
			player:SetAttribute("Level", currentLevel)
			player:SetAttribute("StatPoints", self:GetAttribute(player, "StatPoints") + Config.StatPointsPerLevel)
			player:SetAttribute("RequiredXP", LevelXP[currentLevel] or 0)
			Logger:Info(Logger.Categories.EventLogs, "Player " .. player.Name .. " leveled up to " .. currentLevel .. "! Stat points: " .. player:GetAttribute("StatPoints"))
			LevelUpEvent:Fire(player, currentLevel) -- Yeni: Event tetikleyici
		end
	end)

	if not success then
		Logger:Error(Logger.Categories.EventLogs, "CheckLevelUp hatasý: " .. err)
	end
end

function XPManager:GetAttribute(player, attributeName)
	return player:GetAttribute(attributeName) or 0
end

function XPManager:GetXP(player)
	return self:GetAttribute(player, "XP")
end

function XPManager:GetLevel(player)
	return self:GetAttribute(player, "Level")
end

function XPManager:GetStatPoints(player)
	return self:GetAttribute(player, "StatPoints")
end

function XPManager:GetRequiredXP(player)
	return self:GetAttribute(player, "RequiredXP")
end

function XPManager:UpdateLevelThresholds()
	LevelXP = {}
	isCalculated = false
	CalculateLevelXP()
	Logger:Info(Logger.Categories.ConsoleLogs, "Level XP thresholds recalculated for MaxLevel: " .. Config.MaxLevel)
end

return XPManager