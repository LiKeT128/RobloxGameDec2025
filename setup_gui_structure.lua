-- GUI Structure Creator for Memory Rush
-- Run this script in Command Bar in Roblox Studio (F9)
-- This will create all GUI ScreenGuis with proper hierarchy

local StarterGui = game:GetService("StarterGui")

-- Utility function to create a TextLabel
local function createLabel(name, text, parent)
	local label = Instance.new("TextLabel")
	label.Name = name
	label.Text = text or name
	label.Size = UDim2.new(0, 200, 0, 50)
	label.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
	label.TextColor3 = Color3.new(1, 1, 1)
	label.Font = Enum.Font.Gotham
	label.TextSize = 18
	label.Parent = parent
	return label
end

-- Utility function to create a TextButton
local function createButton(name, text, parent)
	local button = Instance.new("TextButton")
	button.Name = name
	button.Text = text or name
	button.Size = UDim2.new(0, 150, 0, 40)
	button.BackgroundColor3 = Color3.fromRGB(85, 170, 255)
	button.TextColor3 = Color3.new(1, 1, 1)
	button.Font = Enum.Font.GothamBold
	button.TextSize = 16
	button.Parent = parent
	return button
end

-- Utility function to create a Frame
local function createFrame(name, parent, size)
	local frame = Instance.new("Frame")
	frame.Name = name
	frame.Size = size or UDim2.new(1, 0, 1, 0)
	frame.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
	frame.BorderSizePixel = 0
	frame.Parent = parent
	return frame
end

-- Utility function to create a ScrollingFrame
local function createScrollFrame(name, parent)
	local scroll = Instance.new("ScrollingFrame")
	scroll.Name = name
	scroll.Size = UDim2.new(1, -20, 1, -20)
	scroll.Position = UDim2.new(0, 10, 0, 10)
	scroll.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
	scroll.BorderSizePixel = 0
	scroll.ScrollBarThickness = 8
	scroll.Parent = parent
	
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 10)
	layout.Parent = scroll
	
	return scroll
end

print("🎨 Creating Memory Rush GUI Structure...")

-- ============================================================================
-- 1. MAIN HUD (Always Visible)
-- ============================================================================
local MainHUD = Instance.new("ScreenGui")
MainHUD.Name = "MainHUD"
MainHUD.ResetOnSpawn = false
MainHUD.DisplayOrder = 5
MainHUD.Parent = StarterGui

-- Top Bar
local TopBar = createFrame("TopBar", MainHUD, UDim2.new(1, 0, 0, 60))
TopBar.Position = UDim2.new(0, 0, 0, 0)

-- Currency Display
local CurrencyDisplay = createFrame("CurrencyDisplay", TopBar, UDim2.new(0, 300, 1, 0))
CurrencyDisplay.Position = UDim2.new(0, 10, 0, 0)
CurrencyDisplay.BackgroundTransparency = 1

local CoinsFrame = createFrame("CoinsFrame", CurrencyDisplay, UDim2.new(0, 140, 0, 40))
CoinsFrame.Position = UDim2.new(0, 0, 0.5, -20)
CoinsFrame.BackgroundColor3 = Color3.fromRGB(255, 200, 50)
local CoinsIcon = createLabel("Icon", "🪙", CoinsFrame)
CoinsIcon.Size = UDim2.new(0, 40, 1, 0)
CoinsIcon.BackgroundTransparency = 1
local CoinsAmount = createLabel("Amount", "100", CoinsFrame)
CoinsAmount.Size = UDim2.new(1, -40, 1, 0)
CoinsAmount.Position = UDim2.new(0, 40, 0, 0)
CoinsAmount.BackgroundTransparency = 1

local GemsFrame = createFrame("GemsFrame", CurrencyDisplay, UDim2.new(0, 140, 0, 40))
GemsFrame.Position = UDim2.new(0, 150, 0.5, -20)
GemsFrame.BackgroundColor3 = Color3.fromRGB(100, 200, 255)
local GemsIcon = createLabel("Icon", "💎", GemsFrame)
GemsIcon.Size = UDim2.new(0, 40, 1, 0)
GemsIcon.BackgroundTransparency = 1
local GemsAmount = createLabel("Amount", "0", GemsFrame)
GemsAmount.Size = UDim2.new(1, -40, 1, 0)
GemsAmount.Position = UDim2.new(0, 40, 0, 0)
GemsAmount.BackgroundTransparency = 1

-- Settings Button
local SettingsButton = createButton("SettingsButton", "⚙️", TopBar)
SettingsButton.Size = UDim2.new(0, 50, 0, 50)
SettingsButton.Position = UDim2.new(1, -60, 0, 5)

-- Bottom Navigation Bar
local BottomBar = createFrame("BottomBar", MainHUD, UDim2.new(1, 0, 0, 80))
BottomBar.Position = UDim2.new(0, 0, 1, -80)

local navButtons = {"ShopButton", "InventoryButton", "TradeButton", "ProfileButton", "LeaderboardButton"}
local navIcons = {"🏪", "🎭", "🔄", "👤", "🏆"}

for i, btnName in ipairs(navButtons) do
	local btn = createButton(btnName, navIcons[i], BottomBar)
	btn.Size = UDim2.new(0.2, -10, 0, 60)
	btn.Position = UDim2.new((i-1) * 0.2, 5, 0.5, -30)
end

-- Notification Container
local NotifContainer = createFrame("NotificationContainer", MainHUD, UDim2.new(0, 250, 0, 400))
NotifContainer.Position = UDim2.new(1, -260, 0, 70)
NotifContainer.BackgroundTransparency = 1

Instance.new("UIListLayout", NotifContainer)

-- Notification Template
local NotifTemplate = createFrame("NotificationTemplate", NotifContainer, UDim2.new(1, 0, 0, 80))
NotifTemplate.Visible = false
NotifTemplate.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
local notifIcon = createLabel("Icon", "📢", NotifTemplate)
notifIcon.Size = UDim2.new(0, 40, 1, 0)
notifIcon.BackgroundTransparency = 1
local notifTitle = createLabel("Title", "Title", NotifTemplate)
notifTitle.Size = UDim2.new(1, -50, 0, 25)
notifTitle.Position = UDim2.new(0, 45, 0, 5)
notifTitle.BackgroundTransparency = 1
local notifMsg = createLabel("Message", "Message", NotifTemplate)
notifMsg.Size = UDim2.new(1, -50, 0, 40)
notifMsg.Position = UDim2.new(0, 45, 0, 30)
notifMsg.BackgroundTransparency = 1
notifMsg.TextSize = 14

-- Quick Actions
local QuickActions = createFrame("QuickActions", MainHUD, UDim2.new(0, 60, 0, 200))
QuickActions.Position = UDim2.new(1, -70, 0.3, 0)
QuickActions.BackgroundTransparency = 1

local qButtons = {"DailyRewardButton", "GiftButton", "FriendsButton"}
local qIcons = {"📅", "🎁", "👥"}

for i, btnName in ipairs(qButtons) do
	local btn = createButton(btnName, qIcons[i], QuickActions)
	btn.Size = UDim2.new(1, 0, 0, 60)
	btn.Position = UDim2.new(0, 0, 0, (i-1) * 65)
end

print("✅ MainHUD created")

-- ============================================================================
-- 2. SHOP SCREEN
-- ============================================================================
local ShopScreen = Instance.new("ScreenGui")
ShopScreen.Name = "ShopScreen"
ShopScreen.Enabled = false
ShopScreen.DisplayOrder = 3
ShopScreen.Parent = StarterGui

local shopBg = createFrame("Background", ShopScreen)
shopBg.BackgroundColor3 = Color3.new(0, 0, 0)
shopBg.BackgroundTransparency = 0.5

local shopMain = createFrame("MainFrame", ShopScreen, UDim2.new(0.7, 0, 0.8, 0))
shopMain.Position = UDim2.new(0.15, 0, 0.1, 0)
shopMain.BackgroundColor3 = Color3.fromRGB(35, 35, 35)

local shopHeader = createFrame("Header", shopMain, UDim2.new(1, 0, 0, 60))
createLabel("Title", "SHOP", shopHeader).TextSize = 24
local shopClose = createButton("CloseButton", "✕", shopHeader)
shopClose.Size = UDim2.new(0, 50, 0, 50)
shopClose.Position = UDim2.new(1, -55, 0, 5)

local shopScroll = createScrollFrame("PacksScrollFrame", shopMain)
shopScroll.Position = UDim2.new(0, 10, 0, 70)
shopScroll.Size = UDim2.new(1, -20, 1, -80)

local packTemplate = createFrame("PackTemplate", shopScroll, UDim2.new(1, -10, 0, 120))
packTemplate.Visible = false
createLabel("PackName", "Basic Pack", packTemplate)
createLabel("PackDescription", "5 random memories", packTemplate).Position = UDim2.new(0, 0, 0, 30)
createButton("BuyButton", "Buy 100🪙", packTemplate).Position = UDim2.new(0, 0, 0, 70)

print("✅ ShopScreen created")

-- ============================================================================
-- 3. PACK OPENING SCREEN
-- ============================================================================
local PackOpeningScreen = Instance.new("ScreenGui")
PackOpeningScreen.Name = "PackOpeningScreen"
PackOpeningScreen.Enabled = false
PackOpeningScreen.DisplayOrder = 9
PackOpeningScreen.Parent = StarterGui

local packBg = createFrame("Background", PackOpeningScreen)
packBg.BackgroundColor3 = Color3.new(0, 0, 0)
packBg.BackgroundTransparency = 0.3

local animContainer = createFrame("AnimationContainer", PackOpeningScreen, UDim2.new(0.6, 0, 0.6, 0))
animContainer.Position = UDim2.new(0.2, 0, 0.2, 0)
animContainer.BackgroundTransparency = 1

createLabel("PackPlaceholder", "PACK ANIMATION HERE", animContainer).Size = UDim2.new(1, 0, 1, 0)

local revealContainer = createFrame("RevealContainer", PackOpeningScreen, UDim2.new(1, 0, 1, 0))
revealContainer.BackgroundTransparency = 1
revealContainer.Visible = false

local cardTemplate = createFrame("MemoryCardTemplate", revealContainer, UDim2.new(0, 200, 0, 280))
cardTemplate.Visible = false
cardTemplate.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
createLabel("MemoryName", "Meme Name", cardTemplate).Position = UDim2.new(0, 0, 1, -60)
createLabel("RarityLabel", "Common", cardTemplate).Position = UDim2.new(0, 0, 1, -30)

print("✅ PackOpeningScreen created")

-- ============================================================================
-- 4. INVENTORY SCREEN
-- ============================================================================
local InventoryScreen = Instance.new("ScreenGui")
InventoryScreen.Name = "InventoryScreen"
InventoryScreen.Enabled = false
InventoryScreen.DisplayOrder = 3
InventoryScreen.Parent = StarterGui

local invBg = createFrame("Background", InventoryScreen)
invBg.BackgroundColor3 = Color3.new(0, 0, 0)
invBg.BackgroundTransparency = 0.5

local invMain = createFrame("MainFrame", InventoryScreen, UDim2.new(0.8, 0, 0.85, 0))
invMain.Position = UDim2.new(0.1, 0, 0.075, 0)
invMain.BackgroundColor3 = Color3.fromRGB(35, 35, 35)

local invHeader = createFrame("Header", invMain, UDim2.new(1, 0, 0, 60))
createLabel("Title", "COLLECTION", invHeader).TextSize = 24
local invClose = createButton("CloseButton", "✕", invHeader)
invClose.Size = UDim2.new(0, 50, 0, 50)
invClose.Position = UDim2.new(1, -55, 0, 5)

local statsBar = createFrame("StatsBar", invMain, UDim2.new(1, -20, 0, 40))
statsBar.Position = UDim2.new(0, 10, 0, 70)
createLabel("TotalMemories", "Total: 0", statsBar).Size = UDim2.new(0, 150, 1, 0)
createLabel("UniqueCollected", "Unique: 0/20", statsBar).Size = UDim2.new(0, 150, 1, 0)
statsBar:FindFirstChild("UniqueCollected").Position = UDim2.new(0, 160, 0, 0)

local filterFrame = createFrame("FilterButtons", invMain, UDim2.new(1, -20, 0, 50))
filterFrame.Position = UDim2.new(0, 10, 0, 120)
filterFrame.BackgroundTransparency = 1

local filters = {"All", "Common", "Uncommon", "Rare", "Epic", "Legendary"}
for i, filter in ipairs(filters) do
	local btn = createButton(filter .. "Button", filter, filterFrame)
	btn.Size = UDim2.new(0.16, -5, 1, 0)
	btn.Position = UDim2.new((i-1) * 0.166, 0, 0, 0)
end

local memGrid = createScrollFrame("MemoriesGrid", invMain)
memGrid.Position = UDim2.new(0, 10, 0, 180)
memGrid.Size = UDim2.new(1, -20, 1, -190)

local memCard = createFrame("MemoryCardTemplate", memGrid, UDim2.new(0, 150, 0, 200))
memCard.Visible = false
createLabel("NameLabel", "Meme Name", memCard).Position = UDim2.new(0, 0, 1, -50)
createLabel("RarityLabel", "Common", memCard).Position = UDim2.new(0, 0, 1, -25)

print("✅ InventoryScreen created")

-- ============================================================================
-- 5. TRADING SCREEN
-- ============================================================================
local TradingScreen = Instance.new("ScreenGui")
TradingScreen.Name = "TradingScreen"
TradingScreen.Enabled = false
TradingScreen.DisplayOrder = 3
TradingScreen.Parent = StarterGui

local tradeBg = createFrame("Background", TradingScreen)
tradeBg.BackgroundColor3 = Color3.new(0, 0, 0)
tradeBg.BackgroundTransparency = 0.5

local tradeMain = createFrame("MainFrame", TradingScreen, UDim2.new(0.8, 0, 0.85, 0))
tradeMain.Position = UDim2.new(0.1, 0, 0.075, 0)
tradeMain.BackgroundColor3 = Color3.fromRGB(35, 35, 35)

local tradeHeader = createFrame("Header", tradeMain, UDim2.new(1, 0, 0, 60))
createLabel("Title", "TRADING", tradeHeader).TextSize = 24

local tradeTabs = createFrame("TabsFrame", tradeHeader, UDim2.new(0, 400, 1, 0))
tradeTabs.Position = UDim2.new(0.5, -200, 0, 0)
tradeTabs.BackgroundTransparency = 1

createButton("CreateTab", "Create", tradeTabs).Position = UDim2.new(0, 0, 0, 10)
createButton("ActiveTab", "Active", tradeTabs).Position = UDim2.new(0, 130, 0, 10)
createButton("HistoryTab", "History", tradeTabs).Position = UDim2.new(0, 260, 0, 10)

local tradeClose = createButton("CloseButton", "✕", tradeHeader)
tradeClose.Size = UDim2.new(0, 50, 0, 50)
tradeClose.Position = UDim2.new(1, -55, 0, 5)

print("✅ TradingScreen created")

-- ============================================================================
-- 6. PROFILE SCREEN
-- ============================================================================
local ProfileScreen = Instance.new("ScreenGui")
ProfileScreen.Name = "ProfileScreen"
ProfileScreen.Enabled = false
ProfileScreen.DisplayOrder = 3
ProfileScreen.Parent = StarterGui

local profBg = createFrame("Background", ProfileScreen)
profBg.BackgroundColor3 = Color3.new(0, 0, 0)
profBg.BackgroundTransparency = 0.5

local profMain = createFrame("MainFrame", ProfileScreen, UDim2.new(0.6, 0, 0.7, 0))
profMain.Position = UDim2.new(0.2, 0, 0.15, 0)
profMain.BackgroundColor3 = Color3.fromRGB(35, 35, 35)

local profHeader = createFrame("Header", profMain, UDim2.new(1, 0, 0, 60))
createLabel("Title", "PROFILE", profHeader).TextSize = 24
local profClose = createButton("CloseButton", "✕", profHeader)
profClose.Size = UDim2.new(0, 50, 0, 50)
profClose.Position = UDim2.new(1, -55, 0, 5)

local playerInfo = createFrame("PlayerInfoPanel", profMain, UDim2.new(1, -20, 0, 150))
playerInfo.Position = UDim2.new(0, 10, 0, 70)
createLabel("PlayerName", "USERNAME", playerInfo).TextSize = 22

local statsPanel = createFrame("StatsPanel", profMain, UDim2.new(1, -20, 1, -240))
statsPanel.Position = UDim2.new(0, 10, 0, 230)
createLabel("Title", "Statistics", statsPanel).TextSize = 20

print("✅ ProfileScreen created")

-- ============================================================================
-- 7. LEADERBOARD SCREEN
-- ============================================================================
local LeaderboardScreen = Instance.new("ScreenGui")
LeaderboardScreen.Name = "LeaderboardScreen"
LeaderboardScreen.Enabled = false
LeaderboardScreen.DisplayOrder = 3
LeaderboardScreen.Parent = StarterGui

local lbBg = createFrame("Background", LeaderboardScreen)
lbBg.BackgroundColor3 = Color3.new(0, 0, 0)
lbBg.BackgroundTransparency = 0.5

local lbMain = createFrame("MainFrame", LeaderboardScreen, UDim2.new(0.5, 0, 0.8, 0))
lbMain.Position = UDim2.new(0.25, 0, 0.1, 0)
lbMain.BackgroundColor3 = Color3.fromRGB(35, 35, 35)

local lbHeader = createFrame("Header", lbMain, UDim2.new(1, 0, 0, 60))
createLabel("Title", "LEADERBOARD", lbHeader).TextSize = 24
local lbClose = createButton("CloseButton", "✕", lbHeader)
lbClose.Size = UDim2.new(0, 50, 0, 50)
lbClose.Position = UDim2.new(1, -55, 0, 5)

local lbList = createScrollFrame("LeaderboardList", lbMain)
lbList.Position = UDim2.new(0, 10, 0, 70)
lbList.Size = UDim2.new(1, -20, 1, -80)

print("✅ LeaderboardScreen created")

-- ============================================================================
-- 8. DAILY REWARDS SCREEN
-- ============================================================================
local DailyRewardsScreen = Instance.new("ScreenGui")
DailyRewardsScreen.Name = "DailyRewardsScreen"
DailyRewardsScreen.Enabled = false
DailyRewardsScreen.DisplayOrder = 3
DailyRewardsScreen.Parent = StarterGui

local dailyBg = createFrame("Background", DailyRewardsScreen)
dailyBg.BackgroundColor3 = Color3.new(0, 0, 0)
dailyBg.BackgroundTransparency = 0.5

local dailyMain = createFrame("MainFrame", DailyRewardsScreen, UDim2.new(0.6, 0, 0.7, 0))
dailyMain.Position = UDim2.new(0.2, 0, 0.15, 0)
dailyMain.BackgroundColor3 = Color3.fromRGB(35, 35, 35)

local dailyHeader = createFrame("Header", dailyMain, UDim2.new(1, 0, 0, 60))
createLabel("Title", "DAILY REWARDS", dailyHeader).TextSize = 24
local dailyClose = createButton("CloseButton", "✕", dailyHeader)
dailyClose.Size = UDim2.new(0, 50, 0, 50)
dailyClose.Position = UDim2.new(1, -55, 0, 5)

local streakDisplay = createFrame("StreakDisplay", dailyMain, UDim2.new(1, -20, 0, 80))
streakDisplay.Position = UDim2.new(0, 10, 0, 70)
createLabel("StreakCount", "🔥 0 Day Streak", streakDisplay).Size = UDim2.new(1, 0, 1, 0)
streakDisplay:FindFirstChild("StreakCount").TextSize = 28

local calendar = createFrame("RewardsCalendar", dailyMain, UDim2.new(1, -20, 0, 300))
calendar.Position = UDim2.new(0, 10, 0, 160)

createButton("ClaimButton", "CLAIM REWARD", dailyMain).Position = UDim2.new(0.5, -100, 1, -60)

print("✅ DailyRewardsScreen created")

-- ============================================================================
-- 9. GIFT CENTER SCREEN
-- ============================================================================
local GiftCenterScreen = Instance.new("ScreenGui")
GiftCenterScreen.Name = "GiftCenterScreen"
GiftCenterScreen.Enabled = false
GiftCenterScreen.DisplayOrder = 3
GiftCenterScreen.Parent = StarterGui

local giftBg = createFrame("Background", GiftCenterScreen)
giftBg.BackgroundColor3 = Color3.new(0, 0, 0)
giftBg.BackgroundTransparency = 0.5

local giftMain = createFrame("MainFrame", GiftCenterScreen, UDim2.new(0.7, 0, 0.8, 0))
giftMain.Position = UDim2.new(0.15, 0, 0.1, 0)
giftMain.BackgroundColor3 = Color3.fromRGB(35, 35, 35)

local giftHeader = createFrame("Header", giftMain, UDim2.new(1, 0, 0, 60))
createLabel("Title", "GIFT CENTER", giftHeader).TextSize = 24
local giftClose = createButton("CloseButton", "✕", giftHeader)
giftClose.Size = UDim2.new(0, 50, 0, 50)
giftClose.Position = UDim2.new(1, -55, 0, 5)

print("✅ GiftCenterScreen created")

-- ============================================================================
-- 10. SETTINGS SCREEN
-- ============================================================================
local SettingsScreen = Instance.new("ScreenGui")
SettingsScreen.Name = "SettingsScreen"
SettingsScreen.Enabled = false
SettingsScreen.DisplayOrder = 3
SettingsScreen.Parent = StarterGui

local setBg = createFrame("Background", SettingsScreen)
setBg.BackgroundColor3 = Color3.new(0, 0, 0)
setBg.BackgroundTransparency = 0.5

local setMain = createFrame("MainFrame", SettingsScreen, UDim2.new(0.4, 0, 0.6, 0))
setMain.Position = UDim2.new(0.3, 0, 0.2, 0)
setMain.BackgroundColor3 = Color3.fromRGB(35, 35, 35)

local setHeader = createFrame("Header", setMain, UDim2.new(1, 0, 0, 60))
createLabel("Title", "SETTINGS", setHeader).TextSize = 24
local setClose = createButton("CloseButton", "✕", setHeader)
setClose.Size = UDim2.new(0, 50, 0, 50)
setClose.Position = UDim2.new(1, -55, 0, 5)

local setScroll = createScrollFrame("SettingsScroll", setMain)
setScroll.Position = UDim2.new(0, 10, 0, 70)
setScroll.Size = UDim2.new(1, -20, 1, -130)

createButton("SaveButton", "SAVE SETTINGS", setMain).Position = UDim2.new(0.5, -100, 1, -60)

print("✅ SettingsScreen created")

-- ============================================================================
-- 11. LOADING SCREEN
-- ============================================================================
local LoadingScreen = Instance.new("ScreenGui")
LoadingScreen.Name = "LoadingScreen"
LoadingScreen.Enabled = true
LoadingScreen.DisplayOrder = 10
LoadingScreen.Parent = StarterGui

local loadBg = createFrame("Background", LoadingScreen)
loadBg.BackgroundColor3 = Color3.fromRGB(20, 20, 20)

local logo = createLabel("Logo", "MEMORY RUSH", LoadingScreen)
logo.Size = UDim2.new(0, 400, 0, 100)
logo.Position = UDim2.new(0.5, -200, 0.3, 0)
logo.TextSize = 48
logo.BackgroundTransparency = 1

local loadBar = createFrame("LoadingBar", LoadingScreen, UDim2.new(0, 400, 0, 20))
loadBar.Position = UDim2.new(0.5, -200, 0.5, 0)
loadBar.BackgroundColor3 = Color3.fromRGB(60, 60, 60)

local progress = createFrame("Progress", loadBar, UDim2.new(0, 0, 1, 0))
progress.BackgroundColor3 = Color3.fromRGB(100, 200, 100)

local tipLabel = createLabel("TipLabel", "Loading...", LoadingScreen)
tipLabel.Size = UDim2.new(0, 600, 0, 40)
tipLabel.Position = UDim2.new(0.5, -300, 0.6, 0)
tipLabel.TextSize = 16
tipLabel.BackgroundTransparency = 1

print("✅ LoadingScreen created")

-- ============================================================================
-- SUMMARY
-- ============================================================================
print("\n" .. string.rep("=", 60))
print("✨ GUI STRUCTURE CREATED SUCCESSFULLY! ✨")
print(string.rep("=", 60))
print("\n📂 Created ScreenGuis:")
print("   1. MainHUD (Enabled, DisplayOrder=5)")
print("   2. ShopScreen (Disabled, DisplayOrder=3)")
print("   3. PackOpeningScreen (Disabled, DisplayOrder=9)")
print("   4. InventoryScreen (Disabled, DisplayOrder=3)")
print("   5. TradingScreen (Disabled, DisplayOrder=3)")
print("   6. ProfileScreen (Disabled, DisplayOrder=3)")
print("   7. LeaderboardScreen (Disabled, DisplayOrder=3)")
print("   8. DailyRewardsScreen (Disabled, DisplayOrder=3)")
print("   9. GiftCenterScreen (Disabled, DisplayOrder=3)")
print("   10. SettingsScreen (Disabled, DisplayOrder=3)")
print("   11. LoadingScreen (Enabled, DisplayOrder=10)")
print("\n📝 Next Steps:")
print("   • Add LocalScripts to control each screen")
print("   • Connect buttons to open/close screens")
print("   • Add visual assets (images, icons)")
print("   • Implement animations")
print("   • Style with colors and fonts")
print("\n🎨 All screens are now in StarterGui!")
print("   Open each to customize layout and visuals")
print(string.rep("=", 60))
