--[[
	LoadingController.client.lua
	Контроллер экрана загрузки для Memory Rush
	
	📍 Расположение: StarterGui/LoadingScreen/LoadingController (LocalScript)
	
	Что делает:
	- Показывает прогресс загрузки
	- Ждет загрузки профиля
	- Показывает случайные советы
	- Плавно исчезает после загрузки
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local ContentProvider = game:GetService("ContentProvider")

local player = Players.LocalPlayer

-- ============================================================================
-- НАСТРОЙКИ (Изменяй здесь!)
-- ============================================================================

local SETTINGS = {
	-- Минимальное время показа (даже если загрузилось быстрее)
	MinDisplayTime = 2,
	
	-- Советы для игроков (добавь свои!)
	Tips = {
		"💡 Коллекционируй редкие мемы и стань легендой!",
		"💡 Торгуй с друзьями чтобы собрать полную коллекцию",
		"💡 Заходи каждый день за ежедневной наградой",
		"💡 Редкие мемы имеют классные анимации!",
		"💡 Посылай подарки друзьям и получай бонусы",
		"💡 Смотри таблицу лидеров чтобы сравнить прогресс",
		"💡 Legendary мемы выпадают с шансом 1%!",
		"💡 Streak ежедневных наград дает больше бонусов",
	},
	
	-- Интервал смены советов (секунды)
	TipChangeInterval = 3,
}

-- ============================================================================
-- 📸 МЕСТА ДЛЯ СВОИХ КАРТИНОК
-- ============================================================================

local ASSETS = {
	-- 🖼️ ВСТАВЬ СВОЙ AssetId для логотипа игры
	-- Формат: "rbxassetid://НОМЕР"
	Logo = "rbxassetid://0", -- TODO: Заменить на свой логотип
	
	-- 🖼️ Фоновое изображение (опционально)
	Background = "rbxassetid://0", -- TODO: Заменить или оставить цвет
}

-- ============================================================================
-- ИНИЦИАЛИЗАЦИЯ
-- ============================================================================

-- Navigate to the LoadingScreen ScreenGui in PlayerGui
-- (script is in PlayerScripts.Client.GUI, not inside the ScreenGui itself)
local playerGui = player:WaitForChild("PlayerGui")
local gui = playerGui:WaitForChild("LoadingScreen")
local background = gui:WaitForChild("Background")
local logo = gui:WaitForChild("Logo")
local loadingBar = gui:WaitForChild("LoadingBar")
local progress = loadingBar:WaitForChild("Progress")
local tipLabel = gui:WaitForChild("TipLabel")

-- Применить кастомные ассеты
if ASSETS.Logo ~= "rbxassetid://0" then
	-- Если у тебя есть картинка логотипа, замени TextLabel на ImageLabel
	-- logo.Image = ASSETS.Logo
end

if ASSETS.Background ~= "rbxassetid://0" then
	-- Добавить фоновое изображение
	local bgImage = Instance.new("ImageLabel")
	bgImage.Image = ASSETS.Background
	bgImage.Size = UDim2.new(1, 0, 1, 0)
	bgImage.ZIndex = 0
	bgImage.Parent = background
end

-- ============================================================================
-- ЛОГИКА ЗАГРУЗКИ
-- ============================================================================

local loadStartTime = tick()
local currentProgress = 0
local loadingComplete = false

-- Функция обновления прогресс-бара
local function updateProgress(percent: number)
	percent = math.clamp(percent, 0, 1)
	currentProgress = percent
	
	local tween = TweenService:Create(
		progress,
		TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ Size = UDim2.new(percent, 0, 1, 0) }
	)
	tween:Play()
end

-- Функция показа случайного совета
local function showRandomTip()
	local randomTip = SETTINGS.Tips[math.random(1, #SETTINGS.Tips)]
	tipLabel.Text = randomTip
end

-- Функция завершения загрузки
local function finishLoading()
	loadingComplete = true
	
	-- Убедиться что прошло минимальное время
	local elapsed = tick() - loadStartTime
	if elapsed < SETTINGS.MinDisplayTime then
		task.wait(SETTINGS.MinDisplayTime - elapsed)
	end
	
	-- Плавное исчезновение
	local fadeOut = TweenService:Create(
		gui,
		TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ } -- Анимация через GroupTransparency если есть CanvasGroup
	)
	
	-- Или просто скрыть
	for _, child in ipairs(gui:GetDescendants()) do
		if child:IsA("GuiObject") then
			local tween = TweenService:Create(
				child,
				TweenInfo.new(0.5),
				{ BackgroundTransparency = 1 }
			)
			tween:Play()
		end
		if child:IsA("TextLabel") or child:IsA("TextButton") then
			local tween = TweenService:Create(
				child,
				TweenInfo.new(0.5),
				{ TextTransparency = 1 }
			)
			tween:Play()
		end
	end
	
	task.wait(0.6)
	gui.Enabled = false
	
	print("[LoadingScreen] ✅ Loading complete!")
end

-- ============================================================================
-- ПРОЦЕСС ЗАГРУЗКИ
-- ============================================================================

-- Этап 1: Ждем ReplicatedStorage
updateProgress(0.1)
showRandomTip()

local Shared = ReplicatedStorage:WaitForChild("Shared", 30)
updateProgress(0.2)

-- Этап 2: Загружаем модули
local GameConfig, RemoteEvents, ClientData

local success, err = pcall(function()
	GameConfig = require(Shared:WaitForChild("GameConfig"))
	updateProgress(0.3)
	
	RemoteEvents = require(Shared:WaitForChild("RemoteEvents"))
	updateProgress(0.4)
	
	-- Ждем ClientDataUpdater (он в Client папке через StarterPlayerScripts)
	-- Но мы можем подождать Remotes
	RemoteEvents.WaitForReady(30)
	updateProgress(0.5)
end)

if not success then
	warn("[LoadingScreen] Error loading modules:", err)
	tipLabel.Text = "⚠️ Ошибка загрузки. Перезайди в игру."
	return
end

-- Этап 3: Ждем загрузки профиля
updateProgress(0.6)
tipLabel.Text = "Загрузка профиля..."

-- Ждем событие ProfileLoaded или просто RemoteEvent
local profileLoadedEvent = RemoteEvents.GetRemote("ProfileLoaded")

if profileLoadedEvent then
	-- Ждем первое событие загрузки профиля (макс 30 секунд)
	local connection
	local loaded = false
	
	connection = profileLoadedEvent.OnClientEvent:Connect(function(data)
		loaded = true
		updateProgress(0.9)
		
		if connection then
			connection:Disconnect()
		end
	end)
	
	-- Таймаут
	local waitStart = tick()
	while not loaded and (tick() - waitStart) < 30 do
		task.wait(0.5)
		
		-- Смена советов
		if math.floor(tick() - waitStart) % SETTINGS.TipChangeInterval == 0 then
			showRandomTip()
		end
		
		-- Постепенный прогресс пока ждем
		local fakeProgress = 0.6 + (math.min(tick() - waitStart, 20) / 20) * 0.25
		updateProgress(fakeProgress)
	end
	
	if not loaded then
		warn("[LoadingScreen] Profile load timeout - continuing anyway")
	end
end

-- Этап 4: Финализация
updateProgress(1)
tipLabel.Text = "✅ Готово!"

task.wait(0.5)
finishLoading()
