--[[
	MainHUDController.client.lua
	Controls the Main HUD (Currency, Navigation, Notifications)
	
	📍 Location: src/Client/Controllers/MainHUDController.client.lua
	
	MANUAL:
	1. This script connects the buttons in the MainHUD to opening other screens
	2. It updates the coins/gems display automatically
	3. Place your ICON ASSET IDs in the ASSETS table below
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local layerGui = player:WaitForChild("PlayerGui")

-- Modules
local ClientData = require(script.Parent.Parent.Modules:WaitForChild("ClientDataUpdater"))
local Scaler = require(script.Parent.Parent.Modules:WaitForChild("Scaler")) -- Add Scaler
local GameConfig = require(ReplicatedStorage.Shared:WaitForChild("GameConfig"))

-- ============================================================================
-- 🎨 ASSET CONFIGURATION (PUT YOUR IMAGES HERE!)
-- ============================================================================

local ASSETS = {
	-- Currency Icons
	CoinIcon = "rbxassetid://0", 
	GemIcon = "rbxassetid://0", 
	
	-- Navigation Icons
	ShopIcon = "rbxassetid://0",
	InventoryIcon = "rbxassetid://0",
	TradeIcon = "rbxassetid://0",
	ProfileIcon = "rbxassetid://0",
	LeaderboardIcon = "rbxassetid://0",
	
	-- Action Icons
	DailyRewardIcon = "rbxassetid://0",
	GiftIcon = "rbxassetid://0",
	SettingsIcon = "rbxassetid://0",
}

-- ============================================================================
-- CONTROLLER LOGIC
-- ============================================================================

local MainHUDController = {}

local function Init()
	local hud = layerGui:WaitForChild("MainHUD")
	Scaler.AddScaleConstraint(hud) -- Apply Scale to HUD
	
	-- 1. Auto-Enable HUD
	hud.Enabled = true
	
	-- Global Helper: Setup other screens (Scale + Close Buttons)
	local function setupScreen(screenName)
		local screen = layerGui:WaitForChild(screenName, 5)
		if screen then
			Scaler.AddScaleConstraint(screen)
			
			-- Find Close Button (DFS or specific path)
			local mainFrame = screen:FindFirstChild("MainFrame")
			if mainFrame then
				local header = mainFrame:FindFirstChild("Header")
				if header then
					local closeBtn = header:FindFirstChild("CloseButton")
					if closeBtn then
						closeBtn.MouseButton1Click:Connect(function()
							screen.Enabled = false
						end)
					end
				end
			end
		end
	end
	
	-- List of all screens to manage
	local allScreens = {
		"ShopScreen", "InventoryScreen", "TradingScreen", 
		"ProfileScreen", "LeaderboardScreen", "DailyRewardsScreen", 
		"GiftCenterScreen", "SettingsScreen"
	}
	
	for _, name in ipairs(allScreens) do
		setupScreen(name)
	end
	
	local topBar = hud:WaitForChild("TopBar")
	local bottomNav = hud:WaitForChild("BottomNavigation")
	local quickActions = hud:WaitForChild("QuickActionsPanel")
	
	-- 1. Setup Currency Display
	local currencyContainer = topBar:WaitForChild("CurrencyContainer")
	local coinsLabel = currencyContainer:WaitForChild("CoinsDisplay"):WaitForChild("Amount")
	local gemsLabel = currencyContainer:WaitForChild("GemsDisplay"):WaitForChild("Amount")
	
	-- Apply Icons if set
	if ASSETS.CoinIcon ~= "rbxassetid://0" then
		-- Assuming you might want to replace the text icon with an image
		-- Logic here depends on exact GUI tree, assuming there's an Icon label
		local iconLbl = currencyContainer.CoinsDisplay:FindFirstChild("Icon")
		if iconLbl and iconLbl:IsA("ImageLabel") then iconLbl.Image = ASSETS.CoinIcon end
	end
	
	local function updateCurrency()
		coinsLabel.Text = ClientData.FormatCurrency(ClientData.GetCoins())
		gemsLabel.Text = ClientData.FormatCurrency(ClientData.GetGems())
	end
	
	-- Initial update
	if ClientData.IsLoaded() then
		updateCurrency()
	else
		ClientData.OnProfileLoaded:Connect(updateCurrency)
	end
	
	-- Listen for changes
	ClientData.OnCurrencyChanged:Connect(function(data)
		updateCurrency()
		-- Optional: Play small bounce animation on the changed label
	end)
	
	-- 2. Setup Navigation
	local screens = {
		ShopButton = "ShopScreen",
		InventoryButton = "InventoryScreen",
		TradeButton = "TradingScreen",
		ProfileButton = "ProfileScreen",
		LeaderboardButton = "LeaderboardScreen",
	}
	
	local currentOpenScreen = nil
	
	local function closeAllScreens()
		for _, screenName in pairs(screens) do
			local scr = layerGui:FindFirstChild(screenName)
			if scr then scr.Enabled = false end
		end
		-- Also close others
		local others = {"DailyRewardsScreen", "GiftCenterScreen", "SettingsScreen"}
		for _, name in pairs(others) do
			local scr = layerGui:FindFirstChild(name)
			if scr then scr.Enabled = false end
		end
		currentOpenScreen = nil
	end
	
	local function openScreen(screenName)
		local screen = layerGui:FindFirstChild(screenName)
		if not screen then return end
		
		if currentOpenScreen == screen then
			-- Toggle off
			closeAllScreens()
		else
			closeAllScreens()
			screen.Enabled = true
			currentOpenScreen = screen
		end
	end
	
	for btnName, screenName in pairs(screens) do
		local navItem = bottomNav:FindFirstChild(btnName)
		if navItem then
			-- Apply Asset
			-- Helper to set icon if it exists
			local iconAsset = ASSETS[btnName:gsub("Button", "Icon")]
			if iconAsset and iconAsset ~= "rbxassetid://0" then
				-- If button has an ImageLabel child or is one
				-- For setup_gui_structure, buttons were TextButtons. 
				-- You might want to add an ImageLabel inside or change Class.
			end
			
			-- New structure: nav items are Frames with a ClickArea button inside
			local clickArea = navItem:FindFirstChild("ClickArea")
			if clickArea then
				clickArea.MouseButton1Click:Connect(function()
					openScreen(screenName)
				end)
			elseif navItem:IsA("TextButton") or navItem:IsA("ImageButton") then
				-- Fallback for direct buttons
				navItem.MouseButton1Click:Connect(function()
					openScreen(screenName)
				end)
			end
		end
	end
	
	-- 3. Quick Actions
	local dailyBtn = quickActions:FindFirstChild("DailyRewardButton")
	if dailyBtn then
		dailyBtn.MouseButton1Click:Connect(function() openScreen("DailyRewardsScreen") end)
	end
	
	local giftBtn = quickActions:FindFirstChild("GiftButton")
	if giftBtn then
		giftBtn.MouseButton1Click:Connect(function() openScreen("GiftCenterScreen") end)
	end
	
	local settingsBtn = topBar:FindFirstChild("SettingsButton")
	if settingsBtn then
		settingsBtn.MouseButton1Click:Connect(function() openScreen("SettingsScreen") end)
	end

	-- 4. Notification Handling
	ClientData.OnNotification:Connect(function(notifData)
		-- Spawn notification in NotificationContainer
		-- Using template
		local container = hud:WaitForChild("NotificationContainer")
		local template = container:WaitForChild("NotificationTemplate")
		
		local newNotif = template:Clone()
		newNotif.Visible = true
		newNotif.Name = "Notif_"..tick()
		newNotif.Parent = container
		
		local title = newNotif:FindFirstChild("Title")
		local msg = newNotif:FindFirstChild("Message")
		local icon = newNotif:FindFirstChild("Icon")
		
		if title then title.Text = notifData.Title or "Notification" end
		if msg then msg.Text = notifData.Message or "" end
		if icon then icon.Text = notifData.Icon or "📢" end -- Or Image if changed
		
		-- Animate In
		-- (Simple tween)
		local goalPos = UDim2.new(0,0,0,0) -- Assuming ListLayout handles position, but if not:
		-- Actually UIListLayout handles position automatically. We just need to fade in.
		newNotif.BackgroundTransparency = 1
		TweenService:Create(newNotif, TweenInfo.new(0.3), {BackgroundTransparency = 0}):Play()
		
		task.delay(4, function()
			if newNotif and newNotif.Parent then
				TweenService:Create(newNotif, TweenInfo.new(0.3), {BackgroundTransparency = 1}):Play()
				task.wait(0.3)
				newNotif:Destroy()
			end
		end)
	end)

end

Init()

return MainHUDController
