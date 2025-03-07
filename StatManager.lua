local Players = game:GetService("Players")
local Logger = require(script.Parent.Logger)

local StatManager = {}
StatManager.__index = StatManager

local Config = {
	BaseHP = 100, BaseMana = 100, BaseStamina = 100,
	BaseAttackPower = 10, BaseArmor = 10, BaseWalkSpeed = 16,
	HPGrowthRate = 1.10, HPPerStrength = 10, HPPerVitality = 10, HPPerLevel = 5,
	ManaGrowthRate = 1.10, ManaPerIntelligence = 5, ManaPerLevel = 2,
	StaminaGrowthRate = 1.10, StaminaPerDexterity = 5, StaminaPerLevel = 2,
	APGrowthRate = 1.10, APPerStrength = 5, APPerDexterity = 5, APPerLevel = 1,
	ArmorGrowthRate = 1.10, ArmorPerVitality = 5, ArmorPerLevel = 1,
	SpeedGrowthRate = 1.10, BaseSpeedBonus = 5, MaxSpeedBonus = 50,
	CriticalChanceBase = 5.0, CriticalDamageBase = 2.0, AttackSpeedBase = 1,
	LuckyHitBase = 2.0, CooldownReductionBase = 5.0, ResourceRegenBase = 5,
	LifeStealBase = 2.0, BlockChanceBase = 3.0, DamageReductionBase = 1,
	PvPBonusBase = 0, PvPReductionBase = 0
}

local function roundToThreeDecimals(value)
	return math.floor(value * 1000 + 0.5) / 1000
end

local function calculateExponentialBonus(base, growthRate, statValue)
	if statValue == 0 then return 0 end -- Stat 0 ise artýþ yok
	local success, result = pcall(function()
		local exponent = statValue / 10
		return base * (growthRate ^ exponent)
	end)
	if not success then
		Logger:Error(Logger.Categories.EventLogs, "Exponential bonus hesaplama hatasý: " .. result)
		return 0
	end
	return result
end

function StatManager.new(dependencies)
	local self = setmetatable({}, StatManager)
	self.dependencies = dependencies or {}
	Logger:Info(Logger.Categories.ConsoleLogs, "StatManager oluþturuldu.")
	return self
end

function StatManager:InitializePlayer(player)
	local success, err = pcall(function()
		if player:GetAttribute("Strength") == nil then player:SetAttribute("Strength", 0) end
		if player:GetAttribute("Dexterity") == nil then player:SetAttribute("Dexterity", 0) end
		if player:GetAttribute("Intelligence") == nil then player:SetAttribute("Intelligence", 0) end
		if player:GetAttribute("Vitality") == nil then player:SetAttribute("Vitality", 0) end
		if player:GetAttribute("Level") == nil then player:SetAttribute("Level", 1) end
		self:UpdateStats(player)
	end)
	if not success then
		Logger:Error(Logger.Categories.EventLogs, "Oyuncu baþlatma hatasý: " .. err)
	end
end

function StatManager:UpdateStats(player)
	local success, err = pcall(function()
		local strength = player:GetAttribute("Strength") or 0
		local dexterity = player:GetAttribute("Dexterity") or 0
		local intelligence = player:GetAttribute("Intelligence") or 0
		local vitality = player:GetAttribute("Vitality") or 0
		local level = player:GetAttribute("Level") or 1

		local hp = Config.BaseHP
			+ calculateExponentialBonus(Config.HPPerStrength, Config.HPGrowthRate, strength) * strength
			+ calculateExponentialBonus(Config.HPPerVitality, Config.HPGrowthRate, vitality) * vitality
			+ (level * Config.HPPerLevel)
		local mana = Config.BaseMana
			+ calculateExponentialBonus(Config.ManaPerIntelligence, Config.ManaGrowthRate, intelligence) * intelligence
			+ (level * Config.ManaPerLevel)
		local stamina = Config.BaseStamina
			+ calculateExponentialBonus(Config.StaminaPerDexterity, Config.StaminaGrowthRate, dexterity) * dexterity
			+ (level * Config.StaminaPerLevel)

		local attackPower = Config.BaseAttackPower
			+ calculateExponentialBonus(Config.APPerStrength, Config.APGrowthRate, strength) * strength
			+ calculateExponentialBonus(Config.APPerDexterity, Config.APGrowthRate, dexterity) * dexterity
			+ (level * Config.APPerLevel)
		local armor = Config.BaseArmor
			+ calculateExponentialBonus(Config.ArmorPerVitality, Config.ArmorGrowthRate, vitality) * vitality
			+ (level * Config.ArmorPerLevel)
		local speedBonus = Config.BaseSpeedBonus + calculateExponentialBonus(Config.BaseSpeedBonus, Config.SpeedGrowthRate, dexterity)
		local walkSpeed = Config.BaseWalkSpeed + math.min(speedBonus, Config.MaxSpeedBonus)

		local criticalChance = Config.CriticalChanceBase + calculateExponentialBonus(Config.CriticalChanceBase, Config.HPGrowthRate, dexterity) / 2
		local criticalDamage = Config.CriticalDamageBase + calculateExponentialBonus(Config.CriticalDamageBase, Config.HPGrowthRate, dexterity) / 2
		local attackSpeed = Config.AttackSpeedBase + calculateExponentialBonus(Config.AttackSpeedBase, Config.HPGrowthRate, dexterity) / 2
		local luckyHit = Config.LuckyHitBase + calculateExponentialBonus(Config.LuckyHitBase, Config.HPGrowthRate, intelligence) / 2
		local cooldownReduction = Config.CooldownReductionBase + calculateExponentialBonus(Config.CooldownReductionBase, Config.HPGrowthRate, intelligence) / 2
		local resourceRegen = Config.ResourceRegenBase + calculateExponentialBonus(Config.ResourceRegenBase, Config.HPGrowthRate, intelligence) / 2
		local lifeStealStrength = calculateExponentialBonus(Config.LifeStealBase, Config.HPGrowthRate, strength)
		local lifeStealVitality = calculateExponentialBonus(Config.LifeStealBase, Config.HPGrowthRate, vitality)
		local blockChanceStrength = calculateExponentialBonus(Config.BlockChanceBase, Config.HPGrowthRate, strength)
		local blockChanceVitality = calculateExponentialBonus(Config.BlockChanceBase, Config.HPGrowthRate, vitality)
		local damageReductionStrength = calculateExponentialBonus(Config.DamageReductionBase, Config.HPGrowthRate, strength)
		local damageReductionVitality = calculateExponentialBonus(Config.DamageReductionBase, Config.HPGrowthRate, vitality)

		hp = roundToThreeDecimals(hp)
		mana = roundToThreeDecimals(mana)
		stamina = roundToThreeDecimals(stamina)
		attackPower = roundToThreeDecimals(attackPower)
		armor = roundToThreeDecimals(armor)
		speedBonus = roundToThreeDecimals(speedBonus)
		walkSpeed = roundToThreeDecimals(walkSpeed)
		criticalChance = roundToThreeDecimals(criticalChance)
		criticalDamage = roundToThreeDecimals(criticalDamage)
		attackSpeed = roundToThreeDecimals(attackSpeed)
		luckyHit = roundToThreeDecimals(luckyHit)
		cooldownReduction = roundToThreeDecimals(cooldownReduction)
		resourceRegen = roundToThreeDecimals(resourceRegen)
		local lifeSteal = roundToThreeDecimals(Config.LifeStealBase + lifeStealStrength + lifeStealVitality)
		local blockChance = roundToThreeDecimals(Config.BlockChanceBase + blockChanceStrength + blockChanceVitality)
		local damageReduction = roundToThreeDecimals(Config.DamageReductionBase + damageReductionStrength + damageReductionVitality)

		player:SetAttribute("MaxHP", hp)
		player:SetAttribute("MaxMana", mana)
		player:SetAttribute("CurrentMana", player:GetAttribute("CurrentMana") or mana)
		player:SetAttribute("MaxStamina", stamina)
		player:SetAttribute("CurrentStamina", player:GetAttribute("CurrentStamina") or stamina)
		player:SetAttribute("AttackPower", attackPower)
		player:SetAttribute("Armor", armor)
		player:SetAttribute("SpeedBonus", speedBonus)
		player:SetAttribute("CriticalChance", criticalChance)
		player:SetAttribute("CriticalDamage", criticalDamage)
		player:SetAttribute("AttackSpeed", attackSpeed)
		player:SetAttribute("LuckyHit", luckyHit)
		player:SetAttribute("CooldownReduction", cooldownReduction)
		player:SetAttribute("ResourceRegen", resourceRegen)
		player:SetAttribute("LifeSteal", lifeSteal)
		player:SetAttribute("BlockChance", blockChance)
		player:SetAttribute("DamageReduction", damageReduction)
		player:SetAttribute("PvPBonus", Config.PvPBonusBase)
		player:SetAttribute("PvPReduction", Config.PvPReductionBase)

		local humanoid = player.Character and player.Character:FindFirstChild("Humanoid")
		if humanoid then
			humanoid.MaxHealth = hp
			if hp > (player:GetAttribute("MaxHP") or 0) and humanoid.Health >= humanoid.MaxHealth then
				humanoid.Health = hp
			end
			humanoid.WalkSpeed = walkSpeed
		end

		if self.dependencies.RemoteEventManager then
			self.dependencies.RemoteEventManager:FireClient("UpdateStatsEvent", player, 
				hp, mana, stamina, attackPower, armor, speedBonus,
				criticalChance, criticalDamage, attackSpeed, luckyHit,
				cooldownReduction, resourceRegen, player:GetAttribute("LifeSteal"),
				player:GetAttribute("BlockChance"), player:GetAttribute("DamageReduction"),
				player:GetAttribute("PvPBonus"), player:GetAttribute("PvPReduction")
			)
		end
	end)
	if not success then
		Logger:Error(Logger.Categories.EventLogs, "Stat güncelleme hatasý: " .. err)
	end
end

function StatManager:GetStat(player, statName)
	return player:GetAttribute(statName) or 0
end

Logger:Info(Logger.Categories.ConsoleLogs, "StatManager modülü yüklendi.")
return StatManager