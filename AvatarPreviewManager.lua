-- StarterPlayer.StarterPlayerScripts > AvatarPreviewManager.lua (LocalScript)
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Debris = game:GetService("Debris")

-- Client-side Logger
local ClientLogger = {}
ClientLogger.__index = ClientLogger
function ClientLogger.new()
	return setmetatable({}, ClientLogger)
end
function ClientLogger:Trace(category, message) print("[TRACE] " .. category .. ": " .. message) end
function ClientLogger:Warn(category, message) warn("[WARN] " .. category .. ": " .. message) end
function ClientLogger:Error(category, message) warn("[ERROR] " .. category .. ": " .. message) end
local Logger = ClientLogger.new()

local AvatarPreviewManager = {}
AvatarPreviewManager.__index = AvatarPreviewManager

local Config = {
	WaitForChildTimeout = 5, -- Eleman bekleme s�resi
	CameraDistance = 3, -- Kameran�n karakterden uzakl��� (birim)
	CharacterScale = 3.5, -- Karakterin b�y�kl�k �l�e�i (1 = normal, 2 = iki kat� b�y�k, vb.)
	AnimationId = "rbxassetid://507766666" -- Kullan�lacak animasyon ID�si
}

-- Yard�mc� fonksiyon: WaitForChild
local function waitForChild(parent, childName, timeout)
	local success, result = pcall(function()
		return parent:WaitForChild(childName, timeout)
	end)
	if not success or not result then
		Logger:Error("AvatarPreviewManager", string.format("'%s' i�inde '%s' bulunamad�!", parent.Name, childName))
		return nil
	end
	return result
end

function AvatarPreviewManager.new()
	local self = setmetatable({}, AvatarPreviewManager)
	self.player = Players.LocalPlayer
	self.characterViewport = nil
	self.viewportCamera = nil
	self.worldModel = nil
	self.lastCharacter = nil
	self.characterModel = nil -- Kopyalanan modeli tutmak i�in
	self.rotationAngle = 0 -- D�nd�rme a��s�
	self:Initialize()
	return self
end

function AvatarPreviewManager:Initialize()
	task.spawn(function()
		assert(self:SetupViewport(), "Viewport kurulumu ba�ar�s�z!")
		self:StartUpdateLoop()
		Logger:Trace("AvatarPreviewManager", "Sistem ba�lat�ld�.")
	end)
end

function AvatarPreviewManager:SetupViewport()
	self.characterViewport = waitForChild(
		waitForChild(
			waitForChild(
				waitForChild(
					waitForChild(
						waitForChild(
							waitForChild(
								waitForChild(
									waitForChild(self.player, "PlayerGui", Config.WaitForChildTimeout),
									"ScreenGui", Config.WaitForChildTimeout
								),
								"Canvas", Config.WaitForChildTimeout
							),
							"Hud", Config.WaitForChildTimeout
						),
						"InventoryHudFrame", Config.WaitForChildTimeout
					),
					"InventoryBG", Config.WaitForChildTimeout
				),
				"InventoryHud", Config.WaitForChildTimeout
			),
			"UpperSide", Config.WaitForChildTimeout
		),
		"UserSide", Config.WaitForChildTimeout
	):WaitForChild("Player3D", Config.WaitForChildTimeout):WaitForChild("Viewport", Config.WaitForChildTimeout)

	if not self.characterViewport then return false end

	-- WorldModel olu�tur ve ba�la
	self.worldModel = Instance.new("WorldModel")
	self.worldModel.Parent = self.characterViewport

	-- Kamera olu�tur ve ba�la
	local viewportCamera = Instance.new("Camera")
	self.characterViewport.CurrentCamera = viewportCamera
	viewportCamera.Parent = self.worldModel
	self.viewportCamera = viewportCamera
	Debris:AddItem(viewportCamera, 0)
	Logger:Trace("AvatarPreviewManager", "Viewport ve kamera ba�ar�yla ba�land�.")
	return true
end

function AvatarPreviewManager:CopyCharacter(character)
	if not character or not character:FindFirstChild("Humanoid") or not character:FindFirstChild("HumanoidRootPart") then
		Logger:Warn("AvatarPreviewManager", "Karakter veya temel bile�enler eksik, kopyalama ba�ar�s�z.")
		return nil
	end

	if not self.player:HasAppearanceLoaded() then
		self.player.CharacterAppearanceLoaded:Wait()
	end

	character.Archivable = true
	local characterCopy = character:Clone()
	character.Archivable = false

	if not characterCopy then
		Logger:Error("AvatarPreviewManager", "Karakter klonlanamad�!")
		return nil
	end
	characterCopy.Name = character.Name

	for _, script in pairs(characterCopy:GetDescendants()) do
		if script:IsA("BaseScript") then
			script:Destroy()
		end
	end

	local humanoidOriginal = character:FindFirstChild("Humanoid")
	if humanoidOriginal then
		local humanoidCopy = characterCopy:FindFirstChild("Humanoid") or Instance.new("Humanoid")
		humanoidCopy.Parent = characterCopy

		local success, description = pcall(function()
			return Players:GetHumanoidDescriptionFromUserId(self.player.UserId)
		end)
		if success and description then
			local applySuccess, applyError = pcall(function()
				humanoidCopy:ApplyDescription(description)
			end)
			if applySuccess then
				Logger:Trace("AvatarPreviewManager", "K�yafetler ve aksesuarlar HumanoidDescription ile uyguland�.")
			else
				Logger:Warn("AvatarPreviewManager", "ApplyDescription ba�ar�s�z: " .. applyError .. ". Manuel kopyalamaya ge�ildi.")
			end
		else
			Logger:Warn("AvatarPreviewManager", "HumanoidDescription al�namad�, manuel kopyalama kullan�l�yor.")
		end

		for _, item in pairs(character:GetChildren()) do
			if item:IsA("Shirt") or item:IsA("Pants") or item:IsA("Accessory") or item:IsA("Tool") then
				if not characterCopy:FindFirstChild(item.Name) then
					local itemCopy = item:Clone()
					itemCopy.Parent = characterCopy
				end
			end
		end
	end

	return characterCopy
end

function AvatarPreviewManager:StartUpdateLoop()
	self.player.CharacterAdded:Connect(function(character)
		character:WaitForChild("Humanoid", Config.WaitForChildTimeout)
		character:WaitForChild("HumanoidRootPart", Config.WaitForChildTimeout)
		RunService.RenderStepped:Wait()
		self:UpdateViewport()
		self.lastCharacter = character
		Logger:Trace("AvatarPreviewManager", "Karakter y�klendi ve Viewport g�ncellendi.")
	end)

	if self.player.Character then
		local humanoid = self.player.Character:WaitForChild("Humanoid", Config.WaitForChildTimeout)
		local humanoidRootPart = self.player.Character:WaitForChild("HumanoidRootPart", Config.WaitForChildTimeout)
		if humanoid and humanoidRootPart then
			RunService.RenderStepped:Wait()
			self:UpdateViewport()
			self.lastCharacter = self.player.Character
			Logger:Trace("AvatarPreviewManager", "Mevcut karakter bulundu ve Viewport g�ncellendi.")
		end
	end

	RunService.Heartbeat:Connect(function(deltaTime)
		local success, err = pcall(function()
			if self.player.Character and self.player.Character ~= self.lastCharacter then
				self:UpdateViewport()
				self.lastCharacter = self.player.Character
				Logger:Trace("AvatarPreviewManager", "Karakter de�i�ti ve Viewport g�ncellendi.")
			end
		end)
		if not success then
			Logger:Error("AvatarPreviewManager", "Update loop failed: " .. err)
		end
	end)

	local isDragging = false
	local lastMouseX = nil
	UserInputService.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 and self.characterViewport then
			local mousePos = UserInputService:GetMouseLocation()
			if self.characterViewport.AbsolutePosition.X <= mousePos.X and mousePos.X <= self.characterViewport.AbsolutePosition.X + self.characterViewport.AbsoluteSize.X and
				self.characterViewport.AbsolutePosition.Y <= mousePos.Y and mousePos.Y <= self.characterViewport.AbsolutePosition.Y + self.characterViewport.AbsoluteSize.Y then
				isDragging = true
				lastMouseX = mousePos.X
			end
		end
	end)

	UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			isDragging = false
			lastMouseX = nil
		end
	end)

	UserInputService.InputChanged:Connect(function(input)
		if isDragging and input.UserInputType == Enum.UserInputType.MouseMovement then
			local mousePos = UserInputService:GetMouseLocation()
			if lastMouseX then
				local deltaX = mousePos.X - lastMouseX
				self.rotationAngle = self.rotationAngle - deltaX * 0.01
				if self.characterModel then
					local rootPart = self.characterModel:FindFirstChild("HumanoidRootPart")
					if rootPart then
						rootPart.CFrame = CFrame.new(0, 0, 0) * CFrame.Angles(0, self.rotationAngle, 0)
					end
				end
			end
			lastMouseX = mousePos.X
		end
	end)
end

function AvatarPreviewManager:UpdateViewport()
	if not self.characterViewport or not self.viewportCamera or not self.worldModel then
		Logger:Warn("AvatarPreviewManager", "Viewport, kamera veya WorldModel haz�r de�il!")
		return
	end

	local character = self.player.Character
	if not character or not character:FindFirstChild("HumanoidRootPart") or not character:FindFirstChild("Humanoid") then
		Logger:Warn("AvatarPreviewManager", "Karakter veya temel bile�enler bulunamad�.")
		return
	end

	for _, child in pairs(self.worldModel:GetChildren()) do
		if child:IsA("Model") then
			Debris:AddItem(child, 0)
		end
	end

	local characterCopy = self:CopyCharacter(character)
	if not characterCopy then
		Logger:Warn("AvatarPreviewManager", "Karakter kopyalanamad�, i�lem iptal edildi.")
		return
	end
	characterCopy.Parent = self.worldModel
	self.characterModel = characterCopy
	Logger:Trace("AvatarPreviewManager", "Karakter manuel kopyaland� ve Viewport�a eklendi.")

	local rootPart = characterCopy:FindFirstChild("HumanoidRootPart")
	if rootPart then
		rootPart.Anchored = true
		characterCopy:ScaleTo(Config.CharacterScale)
		rootPart.CFrame = CFrame.new(0, 0, 0) * CFrame.Angles(0, math.rad(180), 0) -- Kameraya d�n�k
		Logger:Trace("AvatarPreviewManager", "Karakter " .. Config.CharacterScale .. " kat b�y�t�ld� ve kameraya d�n�k yerle�tirildi.")
	end

	local humanoidCopy = characterCopy:FindFirstChild("Humanoid")
	if humanoidCopy then
		local animator = Instance.new("Animator")
		animator.Parent = humanoidCopy
		local animation = Instance.new("Animation")
		animation.AnimationId = Config.AnimationId
		local animationTrack = humanoidCopy.Animator:LoadAnimation(animation)
		animationTrack:Play()
		Debris:AddItem(animation, 0)
		Logger:Trace("AvatarPreviewManager", "Animasyon eklendi: " .. Config.AnimationId)
	end

	-- Kameray� ufuk �izgisinde, d�z bir �ekilde yerle�tir
	local cameraPosition = Vector3.new(0, 0, Config.CameraDistance) -- Y�kseklik s�f�r
	local lookAtPosition = Vector3.new(0, 0, 0) -- Karakterin merkeziyle ayn� y�kseklik
	self.viewportCamera.CFrame = CFrame.new(cameraPosition) * CFrame.lookAt(cameraPosition, lookAtPosition) -- D�z bir a��yla bak
	self.characterViewport.Size = UDim2.new(0, 300, 0, 400)
	Logger:Trace("AvatarPreviewManager", "Kamera ufuk �izgisinde d�z bir �ekilde ayarland�: " .. Config.CameraDistance)
end

-- Otomatik ba�latma
local avatarPreviewManager = AvatarPreviewManager.new()
return avatarPreviewManager