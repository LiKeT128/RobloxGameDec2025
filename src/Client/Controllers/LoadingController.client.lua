--[[
	LoadingController.client.lua
	Controls the Loading Screen behavior
	
	📍 Location: src/Client/Controllers/LoadingController.client.lua
	
	MANUAL:
	1. This script runs automatically when the game starts
	2. It finds the "LoadingScreen" in your PlayerGui
	3. It animates the progress bar and shows tips
	4. Once data is loaded, it fades out the screen
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local layerGui = player:WaitForChild("PlayerGui")

-- ============================================================================
-- 🎨 ASSET CONFIGURATION (PUT YOUR IMAGES HERE!)
-- ============================================================================

local ASSETS = {
	-- Logo Image ID (e.g. "rbxassetid://123456789")
	Logo = "rbxassetid://0", 
	
	-- Background Image ID (optional)
	Background = "rbxassetid://0", 
}

-- ============================================================================
-- ⚙️ SETTINGS
-- ============================================================================

local SETTINGS = {
	MinDisplayTime = 3, -- Seconds to show loading screen minimum
	Tips = {
		"💡 Collect rare memes to become a legend!",
		"💡 Trade with friends to complete your collection",
		"💡 Check back daily for rewards",
		"💡 Legendary memes have special animations!",
		"💡 Send gifts to friends for bonuses",
	},
	TipInterval = 4,
}

-- ============================================================================
-- CONTROLLER LOGIC
-- ============================================================================

local LoadingController = {}

local function Init()
	-- Wait for GUI
	local gui = layerGui:WaitForChild("LoadingScreen", 10)
	if not gui then
		warn("LoadingScreen not found in PlayerGui!")
		return
	end
	
	-- 1. Auto-Enable GUI (so you can hide it in Studio)
	gui.Enabled = true
	
	local background = gui:WaitForChild("Background")
	local logo = gui:WaitForChild("Logo")
	local loadingBar = gui:WaitForChild("LoadingBar")
	local progress = loadingBar:WaitForChild("Progress")
	local tipLabel = gui:WaitForChild("TipLabel")
	
	-- Apply Assets
	if ASSETS.Logo ~= "rbxassetid://0" then
		-- Convert TextLabel to ImageLabel if needed, or just set if it is one
		if logo:IsA("ImageLabel") then
			logo.Image = ASSETS.Logo
		end
	end
	
	if ASSETS.Background ~= "rbxassetid://0" then
		local bgImage = Instance.new("ImageLabel")
		bgImage.Size = UDim2.new(1, 0, 1, 0)
		bgImage.Image = ASSETS.Background
		bgImage.ZIndex = 0
		bgImage.Parent = background
	end
	
	-- Progress Animation
	local loadStart = tick()
	local currentPct = 0
	
	local function setProgress(pct)
		currentPct = math.clamp(pct, 0, 1)
		TweenService:Create(progress, TweenInfo.new(0.5), {
			Size = UDim2.new(currentPct, 0, 1, 0)
		}):Play()
	end
	
	-- Tip Loop
	task.spawn(function()
		while gui.Enabled do
			local tip = SETTINGS.Tips[math.random(1, #SETTINGS.Tips)]
			tipLabel.Text = tip
			
			-- Fade effect could go here
			task.wait(SETTINGS.TipInterval)
		end
	end)
	
	-- Simulating Loading Stages
	setProgress(0.1)
	
	-- 1. Load Modules
	setProgress(0.3)
	local ClientData = require(script.Parent.Parent.Modules:WaitForChild("ClientDataUpdater"))
	
	-- 2. Wait for data
	setProgress(0.5)
	
	-- We can use ClientData.WaitForLoad() but better to do it async
	-- Fake progress while waiting
	task.spawn(function()
		while not ClientData.IsLoaded() do
			local elapsed = tick() - loadStart
			local fakeProgress = 0.5 + (math.min(elapsed, 10) / 20) -- Slowly go up to 1.0
			if currentPct < fakeProgress then
				setProgress(fakeProgress)
			end
			task.wait(0.1)
		end
	end)
	
	ClientData.WaitForLoad()
	setProgress(1.0)
	tipLabel.Text = "Build Complete!"
	
	-- Wait min time
	local elapsed = tick() - loadStart
	if elapsed < SETTINGS.MinDisplayTime then
		task.wait(SETTINGS.MinDisplayTime - elapsed)
	end
	
	-- Fade Out
	local fadeInfo = TweenInfo.new(1)
	TweenService:Create(background, fadeInfo, {BackgroundTransparency = 1}):Play()
	
	-- Handle Logo Tween based on type
	local logoProps = {}
	if logo:IsA("ImageLabel") then
		logoProps.ImageTransparency = 1
	elseif logo:IsA("TextLabel") then
		logoProps.TextTransparency = 1
	end
	if next(logoProps) then
		TweenService:Create(logo, fadeInfo, logoProps):Play()
	end
	
	TweenService:Create(loadingBar, fadeInfo, {BackgroundTransparency = 1}):Play()
	TweenService:Create(progress, fadeInfo, {BackgroundTransparency = 1}):Play()
	TweenService:Create(tipLabel, fadeInfo, {TextTransparency = 1}):Play()
	
	task.wait(1)
	gui.Enabled = false
end

Init()

return LoadingController
