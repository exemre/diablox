-- StarterPlayerScripts > UIManager.lua (LocalScript)
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Client-side Logger (Prensip 5: Hata Yönetimi)
local ClientLogger = {}
ClientLogger.__index = ClientLogger
function ClientLogger.new()
	return setmetatable({}, ClientLogger)
end
function ClientLogger:Trace(category, message) print("[TRACE] " .. category .. ": " .. message) end
function ClientLogger:Error(category, message) warn("[ERROR] " .. category .. ": " .. message) end
local Logger = ClientLogger.new()

local UIManager = {}
UIManager.__index = UIManager

-- Yapýlandýrma tablosu (Prensip 12: Esnek Entegrasyon Stratejileri)
local Config = {
	InventoryToggleKey = Enum.KeyCode.T,  -- Inventory açma/kapama tuþu
	StatsToggleKey = Enum.KeyCode.E,      -- SideStatsTab açma/kapama tuþu
	WaitForChildTimeout = 5,              -- Eleman bekleme süresi
	UpdateInterval = 0.1,                 -- UI güncelleme aralýðý (saniye)
	TweenInfo = TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out) -- Yumuþak animasyon
}

function UIManager.new()
	local self = setmetatable({}, UIManager)
	self.player = Players.LocalPlayer
	self.currentXP = 0
	self.currentLevel = 1
	self.previousLevelXP = 0
	self.currentMana = 0 -- CurrentHP yok, direkt Humanoid.Health kullanacaðýz
	self.currentStamina = 0
	self.currentAttackPower = 0
	self.currentArmor = 0
	self.currentSpeedBonus = 0
	self.currentCriticalChance = 0
	self.currentCriticalDamage = 0
	self.currentAttackSpeed = 0
	self.currentLuckyHit = 0
	self.currentCooldownReduction = 0
	self.currentResourceRegen = 0
	self.currentLifeSteal = 0
	self.currentBlockChance = 0
	self.currentDamageReduction = 0
	self.currentPvPBonus = 0
	self.currentPvPReduction = 0
	self.currentStrength = 0
	self.currentDexterity = 0
	self.currentIntelligence = 0
	self.currentVitality = 0
	self.currentStatPoints = 0
	self:Initialize()
	return self
end

function UIManager:SetupEventListeners()
	local increaseStatEvent = ReplicatedStorage:WaitForChild("IncreaseStatEvent", Config.WaitForChildTimeout)
	if increaseStatEvent then
		increaseStatEvent.OnClientEvent:Connect(function(statName, newValue, remainingStatPoints)
			self.currentStatPoints = remainingStatPoints
			if statName == "Strength" then self.currentStrength = newValue
			elseif statName == "Dexterity" then self.currentDexterity = newValue
			elseif statName == "Intelligence" then self.currentIntelligence = newValue
			elseif statName == "Vitality" then self.currentVitality = newValue end
			print("[UIManager] Stat güncellendi: " .. statName .. " -> " .. newValue .. ", Kalan Stat Points: " .. remainingStatPoints)
		end)
	end

	local resourceUpdateEvent = ReplicatedStorage:WaitForChild("ResourceUpdateEvent", Config.WaitForChildTimeout)
	if resourceUpdateEvent then
		resourceUpdateEvent.OnClientEvent:Connect(function(resourceName, newValue)
			if resourceName == "CurrentMana" then 
				self.currentMana = newValue
			elseif resourceName == "CurrentStamina" then 
				self.currentStamina = newValue
			end
			-- Health için Humanoid.Health zaten UpdateUI’da çekiliyor
		end)
	end
end

function UIManager:Initialize()
	local success, err = pcall(function()
		self:SetupUI()
		self:SetupInput()
		self:SetupEventListeners() -- Yeni ekleme
		self:StartUpdateLoop()
	end)
	if not success then
		Logger:Error("UIManager", "Initialization failed: " .. err)
	else
		Logger:Trace("UIManager", "Sistem baþlatýldý.")
	end
end

function UIManager:SetupUI()
	local playerGui = self.player:WaitForChild("PlayerGui", Config.WaitForChildTimeout)
	if not playerGui then error("PlayerGui bulunamadý!") end

	local screenGui = playerGui:WaitForChild("ScreenGui", Config.WaitForChildTimeout)
	if not screenGui then error("ScreenGui bulunamadý!") end

	local canvas = screenGui:WaitForChild("Canvas")
	local hud = canvas:WaitForChild("Hud")

	-- InventoryHudFrame ve alt elemanlar
	self.inventoryHudFrame = hud:WaitForChild("InventoryHudFrame")
	self.inventoryHudFrame.Visible = false
	local inventoryBG = self.inventoryHudFrame:WaitForChild("InventoryBG")
	local inventoryHud = inventoryBG:WaitForChild("InventoryHud")
	local upperSide = inventoryHud:WaitForChild("UpperSide"):WaitForChild("Frame")
	local lowerSide = inventoryHud:WaitForChild("LowerSide"):WaitForChild("Tab")

	self.levelTxt = upperSide:WaitForChild("PlayerInfo"):WaitForChild("LevelTxt")
	self.playerNameTxt = upperSide:WaitForChild("PlayerInfo"):WaitForChild("PlayerNameTxt")
	self.closeBtn = upperSide:WaitForChild("CloseFrame"):WaitForChild("CloseBtn")
	self.statsTab = lowerSide:WaitForChild("StatsTab")
	self.statTabBtn = self.statsTab:WaitForChild("StatTabBtn")

	-- SideStatsTab
	self.sideStatsTab = hud:WaitForChild("SideStatsTab")
	self.sideStatsTab.Visible = false

	-- Belirttiðin UI yollarýna TextLabel’larý baðla
	local generalStatFrame = upperSide:WaitForChild("GeneralStatFrame"):WaitForChild("InfoTab")
	self.armorValueTxt = generalStatFrame:WaitForChild("ArmorFrame"):WaitForChild("Value")
	self.attackPowerValueTxt = generalStatFrame:WaitForChild("AttackPower"):WaitForChild("Value")
	self.lifeValueTxt = generalStatFrame:WaitForChild("LifeFrame"):WaitForChild("Value")
	self.manaValueTxt = generalStatFrame:WaitForChild("ManaFrame"):WaitForChild("Value")
	self.staminaValueTxt = generalStatFrame:WaitForChild("StaminaFrame"):WaitForChild("Value")

	local sideStatsFrame = self.sideStatsTab:WaitForChild("SideStatsTabBg"):WaitForChild("Frame"):WaitForChild("ScrollingFrame")
	self.cooldownReductionValueTxt = sideStatsFrame:WaitForChild("Bsa"):WaitForChild("Value")
	self.lifeStealValueTxt = sideStatsFrame:WaitForChild("Cc"):WaitForChild("Value")
	self.blockChanceValueTxt = sideStatsFrame:WaitForChild("Es"):WaitForChild("Value")
	self.damageReductionValueTxt = sideStatsFrame:WaitForChild("Haz"):WaitForChild("Value")
	self.speedBonusValueTxt = sideStatsFrame:WaitForChild("Hh"):WaitForChild("Value")
	self.criticalDamageValueTxt = sideStatsFrame:WaitForChild("Kvh"):WaitForChild("Value")
	self.criticalChanceValueTxt = sideStatsFrame:WaitForChild("Kvi"):WaitForChild("Value")
	self.resourceRegenValueTxt = sideStatsFrame:WaitForChild("Ky"):WaitForChild("Value")
	self.pvpReductionValueTxt = sideStatsFrame:WaitForChild("Pha"):WaitForChild("Value")
	self.pvpBonusValueTxt = sideStatsFrame:WaitForChild("Phb"):WaitForChild("Value")
	self.attackSpeedValueTxt = sideStatsFrame:WaitForChild("Sah"):WaitForChild("Value")
	self.luckyHitValueTxt = sideStatsFrame:WaitForChild("Sv"):WaitForChild("Value")

	self.dexterityValueTxt = sideStatsFrame:WaitForChild("Dexterity"):WaitForChild("Value")
	self.dexterityAddButton = sideStatsFrame:WaitForChild("Dexterity"):WaitForChild("DexterityAddButton")
	self.intelligenceValueTxt = sideStatsFrame:WaitForChild("Intelligence"):WaitForChild("Value")
	self.intelligenceAddButton = sideStatsFrame:WaitForChild("Intelligence"):WaitForChild("IntelligenceAddButton")
	self.vitalityValueTxt = sideStatsFrame:WaitForChild("Vitality"):WaitForChild("Value")
	self.vitalityAddButton = sideStatsFrame:WaitForChild("Vitality"):WaitForChild("VitalityAddButton")
	self.strengthValueTxt = sideStatsFrame:WaitForChild("Strength"):WaitForChild("Value")
	self.strengthAddButton = sideStatsFrame:WaitForChild("Strength"):WaitForChild("StrengthAddButton")

	-- Yeni: IncreaseStatEvent baðlantýsý
	local increaseStatEvent = ReplicatedStorage:WaitForChild("IncreaseStatEvent", Config.WaitForChildTimeout)
	if not increaseStatEvent then
		Logger:Error("UIManager", "IncreaseStatEvent bulunamadý!")
	else
		-- Buton týklama olaylarý
		self.dexterityAddButton.MouseButton1Click:Connect(function()
			if self.currentStatPoints > 0 then
				increaseStatEvent:FireServer("Dexterity")
			end
		end)
		self.intelligenceAddButton.MouseButton1Click:Connect(function()
			if self.currentStatPoints > 0 then
				increaseStatEvent:FireServer("Intelligence")
			end
		end)
		self.vitalityAddButton.MouseButton1Click:Connect(function()
			if self.currentStatPoints > 0 then
				increaseStatEvent:FireServer("Vitality")
			end
		end)
		self.strengthAddButton.MouseButton1Click:Connect(function()
			if self.currentStatPoints > 0 then
				increaseStatEvent:FireServer("Strength")
			end
		end)
	end

	-- LowerHud
	local lowerHud = hud:WaitForChild("LowerHud"):WaitForChild("MainHud")
	self.lvlTxt = lowerHud:WaitForChild("LvlFrame"):WaitForChild("LvlTxt")
	self.xpFrame = lowerHud:WaitForChild("XPFrame")
	self.xpTextLabel = self.xpFrame:WaitForChild("TextLabel")
	self.xpGradient = self.xpFrame:WaitForChild("UIGradient")
	self.xpTextLabel.Visible = false

	-- Yeni Eklemeler: Health, Mana, Stamina Barlarý
	local lowerHudBase = hud:WaitForChild("LowerHud") -- MainHud olmadan doðrudan LowerHud
	local healthFrame = lowerHudBase:WaitForChild("HealthFrame")
	self.healthGradient = healthFrame:WaitForChild("HealthDisplay"):WaitForChild("UIGradient")
	self.healthValueTxt = healthFrame:WaitForChild("Value")
	self.healthValueTxt.Visible = false

	local manaFrame = lowerHudBase:WaitForChild("ManaFrame")
	self.manaGradient = manaFrame:WaitForChild("ManaDisplay"):WaitForChild("UIGradient")
	self.manaValueTxt = manaFrame:WaitForChild("Value")
	self.manaValueTxt.Visible = false

	local staminaFrame = lowerHudBase:WaitForChild("StaminaFrame")
	self.staminaGradient = staminaFrame:WaitForChild("StaminaDisplay"):WaitForChild("UIGradient")
	self.staminaValueTxt = staminaFrame:WaitForChild("Value")
	self.staminaValueTxt.Visible = false

	-- Mouse Hover Etkileþimleri
	healthFrame.MouseEnter:Connect(function() self.healthValueTxt.Visible = true end)
	healthFrame.MouseLeave:Connect(function() self.healthValueTxt.Visible = false end)
	manaFrame.MouseEnter:Connect(function() self.manaValueTxt.Visible = true end)
	manaFrame.MouseLeave:Connect(function() self.manaValueTxt.Visible = false end)
	staminaFrame.MouseEnter:Connect(function() self.staminaValueTxt.Visible = true end)
	staminaFrame.MouseLeave:Connect(function() self.staminaValueTxt.Visible = false end)

	-- Buton baðlantýlarý (Prensip 4: Saðlam Veri Akýþý)
	self.closeBtn.MouseButton1Click:Connect(function()
		self.inventoryHudFrame.Visible = false
		self.sideStatsTab.Visible = false
	end)
	self.statTabBtn.MouseButton1Click:Connect(function()
		self.sideStatsTab.Visible = not self.sideStatsTab.Visible
		Logger:Trace("UIManager", "StatTabBtn toggled SideStatsTab to " .. tostring(self.sideStatsTab.Visible))
	end)

	-- Mouse hover için XP yüzdesi
	self.xpFrame.MouseEnter:Connect(function() self.xpTextLabel.Visible = true end)
	self.xpFrame.MouseLeave:Connect(function() self.xpTextLabel.Visible = false end)
end

function UIManager:SetupInput()
	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then return end

		-- "T" tuþu: InventoryHudFrame aç/kapa, her ikisi açýksa kapat (Prensip 12: Esneklik)
		if input.KeyCode == Config.InventoryToggleKey then
			if not self.inventoryHudFrame.Visible then
				self.inventoryHudFrame.Visible = true
			elseif self.inventoryHudFrame.Visible and self.sideStatsTab and self.sideStatsTab.Visible then
				self.inventoryHudFrame.Visible = false
				self.sideStatsTab.Visible = false
			else
				self.inventoryHudFrame.Visible = false
			end
			-- "E" tuþu: InventoryHudFrame kapalýysa her ikisini aç, açýksa SideStatsTab aç, her ikisi açýksa sadece SideStatsTab kapat (Prensip 12: Esneklik)
		elseif input.KeyCode == Config.StatsToggleKey then
			if not self.inventoryHudFrame.Visible then
				self.inventoryHudFrame.Visible = true
				self.sideStatsTab.Visible = true
			elseif self.inventoryHudFrame.Visible and self.sideStatsTab and self.sideStatsTab.Visible then
				self.sideStatsTab.Visible = false
			elseif self.inventoryHudFrame.Visible and self.sideStatsTab then
				self.sideStatsTab.Visible = true
			end
		end
	end)
end

function UIManager:StartUpdateLoop()
	RunService.RenderStepped:Connect(function(deltaTime)
		local success, err = pcall(function()
			local newXP = self.player:GetAttribute("XP") or 0
			local newLevel = self.player:GetAttribute("Level") or 1
			local requiredXP = self.player:GetAttribute("RequiredXP") or 0

			-- Seviye deðiþtiyse önceki seviyenin XP’sini güncelle
			if newLevel ~= self.currentLevel then
				self.previousLevelXP = self.currentXP  -- Önceki seviyenin toplam XP’si
				self.currentLevel = newLevel
			end

			self.currentXP = newXP
			self.currentStatPoints = self.player:GetAttribute("StatPoints") or 0
			self.requiredXP = requiredXP

			-- Statlarý Attributes’tan çek
			self.currentHP = self.player:GetAttribute("HP") or 0
			self.currentMana = self.player:GetAttribute("CurrentMana") or 0
			self.currentStamina = self.player:GetAttribute("CurrentStamina") or 0
			self.currentAttackPower = self.player:GetAttribute("AttackPower") or 0
			self.currentArmor = self.player:GetAttribute("Armor") or 0
			self.currentSpeedBonus = self.player:GetAttribute("SpeedBonus") or 0
			self.currentCriticalChance = self.player:GetAttribute("CriticalChance") or 0
			self.currentCriticalDamage = self.player:GetAttribute("CriticalDamage") or 0
			self.currentAttackSpeed = self.player:GetAttribute("AttackSpeed") or 0
			self.currentLuckyHit = self.player:GetAttribute("LuckyHit") or 0
			self.currentCooldownReduction = self.player:GetAttribute("CooldownReduction") or 0
			self.currentResourceRegen = self.player:GetAttribute("ResourceRegen") or 0
			self.currentLifeSteal = self.player:GetAttribute("LifeSteal") or 0
			self.currentBlockChance = self.player:GetAttribute("BlockChance") or 0
			self.currentDamageReduction = self.player:GetAttribute("DamageReduction") or 0
			self.currentPvPBonus = self.player:GetAttribute("PvPBonus") or 0
			self.currentPvPReduction = self.player:GetAttribute("PvPReduction") or 0
			self.currentStrength = self.player:GetAttribute("Strength") or 0
			self.currentDexterity = self.player:GetAttribute("Dexterity") or 0
			self.currentIntelligence = self.player:GetAttribute("Intelligence") or 0
			self.currentVitality = self.player:GetAttribute("Vitality") or 0

			self:UpdateUI()
		end)
		if not success then
			Logger:Error("UIManager", "Update loop failed: " .. err)
		end
	end)
end

function UIManager:UpdateUI()
	self.levelTxt.Text = tostring(self.currentLevel)
	self.lvlTxt.Text = tostring(self.currentLevel)
	self.playerNameTxt.Text = self.player.Name

	-- Bir sonraki levele kalan XP oranýný hesapla
	local adjustedXP = self.currentXP - self.previousLevelXP
	local xpPercent = math.clamp(adjustedXP / (self.requiredXP - self.previousLevelXP), 0, 1)

	-- Yumuþak animasyon ile XP barýný güncelle
	local tween = TweenService:Create(
		self.xpGradient,
		Config.TweenInfo,
		{ Offset = Vector2.new(xpPercent, 0) }
	)
	tween:Play()

	self.xpTextLabel.Text = string.format("%.1f%%", xpPercent * 100)

	-- Statlarý belirtilen UI yollarýna yaz
	self.armorValueTxt.Text = tostring(self.currentArmor)
	self.attackPowerValueTxt.Text = tostring(self.currentAttackPower)
	self.lifeValueTxt.Text = tostring(self.player:GetAttribute("MaxHP") or 0)
	self.manaValueTxt.Text = tostring(self.player:GetAttribute("MaxMana") or 0)
	self.staminaValueTxt.Text = tostring(self.player:GetAttribute("MaxStamina") or 0)
	-- Yüzde ile gösterilecek yan statlar
	self.cooldownReductionValueTxt.Text = string.format("%.1f%%", self.currentCooldownReduction)
	self.lifeStealValueTxt.Text = string.format("%.1f%%", self.currentLifeSteal)
	self.blockChanceValueTxt.Text = string.format("%.1f%%", self.currentBlockChance)
	self.damageReductionValueTxt.Text = string.format("%.1f%%", self.currentDamageReduction)
	self.speedBonusValueTxt.Text = string.format("%.1f%%", self.currentSpeedBonus)
	self.criticalDamageValueTxt.Text = string.format("%.1f%%", self.currentCriticalDamage)
	self.criticalChanceValueTxt.Text = string.format("%.1f%%", self.currentCriticalChance)
	self.resourceRegenValueTxt.Text = string.format("%.1f%%", self.currentResourceRegen)
	self.pvpReductionValueTxt.Text = string.format("%.1f%%", self.currentPvPReduction)
	self.pvpBonusValueTxt.Text = string.format("%.1f%%", self.currentPvPBonus)
	self.attackSpeedValueTxt.Text = string.format("%.1f%%", self.currentAttackSpeed)
	self.luckyHitValueTxt.Text = string.format("%.1f%%", self.currentLuckyHit)
	-- Yeni: Temel statlar
	self.dexterityValueTxt.Text = tostring(self.currentDexterity)
	self.intelligenceValueTxt.Text = tostring(self.currentIntelligence)
	self.vitalityValueTxt.Text = tostring(self.currentVitality)
	self.strengthValueTxt.Text = tostring(self.currentStrength)
	-- Yeni: Buton görünürlüðü
	self.dexterityAddButton.Visible = self.currentStatPoints > 0
	self.intelligenceAddButton.Visible = self.currentStatPoints > 0
	self.vitalityAddButton.Visible = self.currentStatPoints > 0
	self.strengthAddButton.Visible = self.currentStatPoints > 0

	-- Health Bar (Aþaðýdan yukarýya, Mana gibi)
	local humanoid = self.player.Character and self.player.Character:FindFirstChild("Humanoid")
	local maxHP = self.player:GetAttribute("MaxHP") or 0
	local healthPercent = maxHP > 0 and math.clamp((humanoid and humanoid.Health or 0) / maxHP, 0, 1) or 0
	local healthOffsetY = healthPercent * -1 -- Yeni formül (-90 derece için)
	local tweenHealth = TweenService:Create(self.healthGradient, Config.TweenInfo, { Offset = Vector2.new(0, healthOffsetY) })
	tweenHealth:Play()
	self.healthValueTxt.Text = string.format("%d / %d", humanoid and humanoid.Health or 0, maxHP)

	-- Mana Bar
	local maxMana = self.player:GetAttribute("MaxMana") or 0
	local manaPercent = maxMana > 0 and math.clamp(self.currentMana / maxMana, 0, 1) or 0
	local manaOffsetY = manaPercent * -1 -- -90 derece için
	local tweenMana = TweenService:Create(self.manaGradient, Config.TweenInfo, { Offset = Vector2.new(0, manaOffsetY) })
	tweenMana:Play()
	self.manaValueTxt.Text = string.format("%d / %d", self.currentMana, maxMana)

	-- Stamina Bar
	local maxStamina = self.player:GetAttribute("MaxStamina") or 0
	local staminaPercent = maxStamina > 0 and math.clamp(self.currentStamina / maxStamina, 0, 1) or 0
	local staminaOffsetY = staminaPercent * -1 -- -90 derece için
	local tweenStamina = TweenService:Create(self.staminaGradient, Config.TweenInfo, { Offset = Vector2.new(0, staminaOffsetY) })
	tweenStamina:Play()
	self.staminaValueTxt.Text = string.format("%d / %d", self.currentStamina, maxStamina)
end
-- Otomatik baþlatma (Prensip 11: Merkezi Kontrol)
local uiManager = UIManager.new()
return uiManager