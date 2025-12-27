--[[
    GUI Structure Creator for Memory Rush
    Run this script in Command Bar in Roblox Studio (View → Command Bar)
    
    ✨ FEATURES:
    - Proper anchor points for intuitive positioning
    - UI constraints (UICorner, UIListLayout, UIPadding, UIStroke)
    - Configurable theme (colors and sizes at top)
    - Professional, maintainable structure
    
    📝 TO CUSTOMIZE:
    - Modify COLORS table below to change theme
    - Modify SIZES table below to adjust dimensions
    - After running, you can freely adjust positions in Studio
]]

local StarterGui = game:GetService("StarterGui")

-- ============================================================================
-- 🎨 THEME CONFIGURATION (Edit these to customize appearance!)
-- ============================================================================

local COLORS = {
    -- Backgrounds
    Background = Color3.fromRGB(25, 25, 35),
    Panel = Color3.fromRGB(40, 40, 55),
    Surface = Color3.fromRGB(55, 55, 70),
    Overlay = Color3.fromRGB(0, 0, 0),
    
    -- Accents
    Primary = Color3.fromRGB(85, 170, 255),
    Secondary = Color3.fromRGB(255, 170, 85),
    Success = Color3.fromRGB(85, 255, 170),
    Warning = Color3.fromRGB(255, 200, 85),
    Error = Color3.fromRGB(255, 85, 85),
    
    -- Currencies
    Coins = Color3.fromRGB(255, 200, 50),
    CoinsText = Color3.fromRGB(60, 40, 0),
    Gems = Color3.fromRGB(100, 200, 255),
    GemsText = Color3.fromRGB(0, 40, 60),
    
    -- Text
    TextPrimary = Color3.fromRGB(255, 255, 255),
    TextSecondary = Color3.fromRGB(180, 180, 180),
    TextDark = Color3.fromRGB(30, 30, 30),
    
    -- Buttons
    ButtonPrimary = Color3.fromRGB(85, 170, 255),
    ButtonHover = Color3.fromRGB(100, 185, 255),
    ButtonPressed = Color3.fromRGB(70, 150, 230),
}

local SIZES = {
    -- Layout
    TopBarHeight = 70,
    BottomNavHeight = 90,
    SideMargin = 15,
    
    -- Corners
    ButtonCorner = 12,
    PanelCorner = 16,
    SmallCorner = 8,
    
    -- Padding
    DefaultPadding = 12,
    SmallPadding = 8,
    
    -- Icons
    IconSize = 36,
    SmallIconSize = 28,
    
    -- Currency
    CurrencyWidth = 130,
    CurrencyHeight = 44,
    CurrencyGap = 12,
    
    -- Navigation
    NavButtonSize = 65,
    QuickActionSize = 55,
}

-- ============================================================================
-- 🔧 HELPER FUNCTIONS
-- ============================================================================

-- Create ScreenGui with proper settings
local function createScreenGui(name, enabled, displayOrder)
    local gui = Instance.new("ScreenGui")
    gui.Name = name
    gui.Enabled = enabled
    gui.DisplayOrder = displayOrder or 1
    gui.ResetOnSpawn = false
    gui.IgnoreGuiInset = true
    gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    gui.Parent = StarterGui
    return gui
end

-- Create Frame with proper defaults
local function createFrame(props)
    local frame = Instance.new("Frame")
    frame.Name = props.Name or "Frame"
    frame.Size = props.Size or UDim2.new(1, 0, 1, 0)
    frame.Position = props.Position or UDim2.new(0, 0, 0, 0)
    frame.AnchorPoint = props.AnchorPoint or Vector2.new(0, 0)
    frame.BackgroundColor3 = props.BackgroundColor3 or COLORS.Panel
    frame.BackgroundTransparency = props.BackgroundTransparency or 0
    frame.BorderSizePixel = 0
    frame.Parent = props.Parent
    return frame
end

-- Create TextLabel
local function createLabel(props)
    local label = Instance.new("TextLabel")
    label.Name = props.Name or "Label"
    label.Size = props.Size or UDim2.new(1, 0, 1, 0)
    label.Position = props.Position or UDim2.new(0, 0, 0, 0)
    label.AnchorPoint = props.AnchorPoint or Vector2.new(0, 0)
    label.BackgroundTransparency = props.BackgroundTransparency or 1
    label.BackgroundColor3 = props.BackgroundColor3 or COLORS.Panel
    label.Text = props.Text or ""
    label.TextColor3 = props.TextColor3 or COLORS.TextPrimary
    label.Font = props.Font or Enum.Font.GothamBold
    label.TextSize = props.TextSize or 18
    label.TextXAlignment = props.TextXAlignment or Enum.TextXAlignment.Center
    label.TextYAlignment = props.TextYAlignment or Enum.TextYAlignment.Center
    label.BorderSizePixel = 0
    label.Parent = props.Parent
    return label
end

-- Create TextButton
local function createButton(props)
    local button = Instance.new("TextButton")
    button.Name = props.Name or "Button"
    button.Size = props.Size or UDim2.new(0, 100, 0, 40)
    button.Position = props.Position or UDim2.new(0, 0, 0, 0)
    button.AnchorPoint = props.AnchorPoint or Vector2.new(0, 0)
    button.BackgroundColor3 = props.BackgroundColor3 or COLORS.ButtonPrimary
    button.BackgroundTransparency = props.BackgroundTransparency or 0
    button.Text = props.Text or ""
    button.TextColor3 = props.TextColor3 or COLORS.TextPrimary
    button.Font = props.Font or Enum.Font.GothamBold
    button.TextSize = props.TextSize or 16
    button.BorderSizePixel = 0
    button.AutoButtonColor = true
    button.Parent = props.Parent
    return button
end

-- Create ImageLabel
local function createImage(props)
    local image = Instance.new("ImageLabel")
    image.Name = props.Name or "Image"
    image.Size = props.Size or UDim2.new(1, 0, 1, 0)
    image.Position = props.Position or UDim2.new(0, 0, 0, 0)
    image.AnchorPoint = props.AnchorPoint or Vector2.new(0, 0)
    image.BackgroundTransparency = 1
    image.Image = props.Image or ""
    image.ImageColor3 = props.ImageColor3 or Color3.new(1, 1, 1)
    image.ScaleType = props.ScaleType or Enum.ScaleType.Fit
    image.Parent = props.Parent
    return image
end

-- Add UICorner
local function addCorner(parent, radius)
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, radius or SIZES.ButtonCorner)
    corner.Parent = parent
    return corner
end

-- Add UIPadding
local function addPadding(parent, top, bottom, left, right)
    local padding = Instance.new("UIPadding")
    padding.PaddingTop = UDim.new(0, top or SIZES.DefaultPadding)
    padding.PaddingBottom = UDim.new(0, bottom or top or SIZES.DefaultPadding)
    padding.PaddingLeft = UDim.new(0, left or top or SIZES.DefaultPadding)
    padding.PaddingRight = UDim.new(0, right or left or top or SIZES.DefaultPadding)
    padding.Parent = parent
    return padding
end

-- Add UIListLayout
local function addListLayout(parent, direction, padding, hAlign, vAlign)
    local layout = Instance.new("UIListLayout")
    layout.FillDirection = direction or Enum.FillDirection.Vertical
    layout.Padding = UDim.new(0, padding or 10)
    layout.HorizontalAlignment = hAlign or Enum.HorizontalAlignment.Center
    layout.VerticalAlignment = vAlign or Enum.VerticalAlignment.Center
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Parent = parent
    return layout
end

-- Add UIGridLayout
local function addGridLayout(parent, cellSize, cellPadding)
    local grid = Instance.new("UIGridLayout")
    grid.CellSize = cellSize or UDim2.new(0, 100, 0, 100)
    grid.CellPadding = cellPadding or UDim2.new(0, 10, 0, 10)
    grid.SortOrder = Enum.SortOrder.LayoutOrder
    grid.Parent = parent
    return grid
end

-- Add UIStroke
local function addStroke(parent, color, thickness, transparency)
    local stroke = Instance.new("UIStroke")
    stroke.Color = color or COLORS.TextSecondary
    stroke.Thickness = thickness or 1
    stroke.Transparency = transparency or 0.5
    stroke.Parent = parent
    return stroke
end

-- Add UIAspectRatioConstraint
local function addAspectRatio(parent, ratio)
    local aspect = Instance.new("UIAspectRatioConstraint")
    aspect.AspectRatio = ratio or 1
    aspect.Parent = parent
    return aspect
end

-- Create ScrollingFrame
local function createScrollFrame(props)
    local scroll = Instance.new("ScrollingFrame")
    scroll.Name = props.Name or "ScrollFrame"
    scroll.Size = props.Size or UDim2.new(1, 0, 1, 0)
    scroll.Position = props.Position or UDim2.new(0, 0, 0, 0)
    scroll.AnchorPoint = props.AnchorPoint or Vector2.new(0, 0)
    scroll.BackgroundTransparency = props.BackgroundTransparency or 1
    scroll.BackgroundColor3 = props.BackgroundColor3 or COLORS.Background
    scroll.BorderSizePixel = 0
    scroll.ScrollBarThickness = props.ScrollBarThickness or 6
    scroll.ScrollBarImageColor3 = COLORS.TextSecondary
    scroll.CanvasSize = props.CanvasSize or UDim2.new(0, 0, 0, 0)
    scroll.AutomaticCanvasSize = props.AutomaticCanvasSize or Enum.AutomaticSize.Y
    scroll.Parent = props.Parent
    return scroll
end

print("🎨 Creating Memory Rush GUI Structure...")
print("   Theme loaded with", #COLORS, "colors")

-- ============================================================================
-- 1. MAIN HUD (Always Visible)
-- ============================================================================

local MainHUD = createScreenGui("MainHUD", true, 5)

-- === TOP BAR ===
local TopBar = createFrame({
    Name = "TopBar",
    Parent = MainHUD,
    Size = UDim2.new(1, 0, 0, SIZES.TopBarHeight),
    Position = UDim2.new(0.5, 0, 0, 0),
    AnchorPoint = Vector2.new(0.5, 0),
    BackgroundColor3 = COLORS.Panel,
    BackgroundTransparency = 0.1,
})
addPadding(TopBar, 10, 10, SIZES.SideMargin, SIZES.SideMargin)

-- Currency Container (left side)
local CurrencyContainer = createFrame({
    Name = "CurrencyContainer",
    Parent = TopBar,
    Size = UDim2.new(0, SIZES.CurrencyWidth * 2 + SIZES.CurrencyGap, 1, 0),
    Position = UDim2.new(0, 0, 0.5, 0),
    AnchorPoint = Vector2.new(0, 0.5),
    BackgroundTransparency = 1,
})
addListLayout(CurrencyContainer, Enum.FillDirection.Horizontal, SIZES.CurrencyGap, Enum.HorizontalAlignment.Left)

-- Coins Display
local CoinsDisplay = createFrame({
    Name = "CoinsDisplay",
    Parent = CurrencyContainer,
    Size = UDim2.new(0, SIZES.CurrencyWidth, 0, SIZES.CurrencyHeight),
    BackgroundColor3 = COLORS.Coins,
})
addCorner(CoinsDisplay, SIZES.SmallCorner)
addPadding(CoinsDisplay, 0, 0, 8, 8)

local CoinsIcon = createLabel({
    Name = "Icon",
    Parent = CoinsDisplay,
    Size = UDim2.new(0, SIZES.SmallIconSize, 1, 0),
    Text = "🪙",
    TextSize = 22,
    TextXAlignment = Enum.TextXAlignment.Left,
})

local CoinsAmount = createLabel({
    Name = "Amount",
    Parent = CoinsDisplay,
    Size = UDim2.new(1, -SIZES.SmallIconSize - 4, 1, 0),
    Position = UDim2.new(0, SIZES.SmallIconSize + 4, 0, 0),
    Text = "0",
    TextColor3 = COLORS.CoinsText,
    TextSize = 18,
    TextXAlignment = Enum.TextXAlignment.Right,
})

-- Gems Display
local GemsDisplay = createFrame({
    Name = "GemsDisplay",
    Parent = CurrencyContainer,
    Size = UDim2.new(0, SIZES.CurrencyWidth, 0, SIZES.CurrencyHeight),
    BackgroundColor3 = COLORS.Gems,
})
addCorner(GemsDisplay, SIZES.SmallCorner)
addPadding(GemsDisplay, 0, 0, 8, 8)

local GemsIcon = createLabel({
    Name = "Icon",
    Parent = GemsDisplay,
    Size = UDim2.new(0, SIZES.SmallIconSize, 1, 0),
    Text = "💎",
    TextSize = 22,
    TextXAlignment = Enum.TextXAlignment.Left,
})

local GemsAmount = createLabel({
    Name = "Amount",
    Parent = GemsDisplay,
    Size = UDim2.new(1, -SIZES.SmallIconSize - 4, 1, 0),
    Position = UDim2.new(0, SIZES.SmallIconSize + 4, 0, 0),
    Text = "0",
    TextColor3 = COLORS.GemsText,
    TextSize = 18,
    TextXAlignment = Enum.TextXAlignment.Right,
})

-- Settings Button (right side)
local SettingsButton = createButton({
    Name = "SettingsButton",
    Parent = TopBar,
    Size = UDim2.new(0, 50, 0, 50),
    Position = UDim2.new(1, 0, 0.5, 0),
    AnchorPoint = Vector2.new(1, 0.5),
    BackgroundColor3 = COLORS.Surface,
    Text = "⚙️",
    TextSize = 24,
})
addCorner(SettingsButton, SIZES.SmallCorner)

-- === BOTTOM NAVIGATION ===
local BottomNavigation = createFrame({
    Name = "BottomNavigation",
    Parent = MainHUD,
    Size = UDim2.new(1, -SIZES.SideMargin * 2, 0, SIZES.BottomNavHeight),
    Position = UDim2.new(0.5, 0, 1, -SIZES.SideMargin),
    AnchorPoint = Vector2.new(0.5, 1),
    BackgroundColor3 = COLORS.Panel,
    BackgroundTransparency = 0.1,
})
addCorner(BottomNavigation, SIZES.PanelCorner)
addPadding(BottomNavigation, SIZES.SmallPadding)
addListLayout(BottomNavigation, Enum.FillDirection.Horizontal, 8)

local navData = {
    {Name = "ShopButton", Icon = "🏪", Label = "Shop"},
    {Name = "InventoryButton", Icon = "🎭", Label = "Collection"},
    {Name = "TradeButton", Icon = "🔄", Label = "Trade"},
    {Name = "ProfileButton", Icon = "👤", Label = "Profile"},
    {Name = "LeaderboardButton", Icon = "🏆", Label = "Top"},
}

for i, data in ipairs(navData) do
    local navBtn = createFrame({
        Name = data.Name,
        Parent = BottomNavigation,
        Size = UDim2.new(0, SIZES.NavButtonSize, 0, SIZES.NavButtonSize),
        BackgroundColor3 = COLORS.Surface,
    })
    navBtn.LayoutOrder = i
    addCorner(navBtn, SIZES.ButtonCorner)
    
    -- Make it clickable
    local clickArea = createButton({
        Name = "ClickArea",
        Parent = navBtn,
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundTransparency = 1,
        Text = "",
    })
    
    local iconLabel = createLabel({
        Name = "Icon",
        Parent = navBtn,
        Size = UDim2.new(1, 0, 0.6, 0),
        Position = UDim2.new(0.5, 0, 0.35, 0),
        AnchorPoint = Vector2.new(0.5, 0.5),
        Text = data.Icon,
        TextSize = 26,
    })
    
    local textLabel = createLabel({
        Name = "Label",
        Parent = navBtn,
        Size = UDim2.new(1, 0, 0.3, 0),
        Position = UDim2.new(0.5, 0, 0.85, 0),
        AnchorPoint = Vector2.new(0.5, 0.5),
        Text = data.Label,
        TextSize = 10,
        Font = Enum.Font.Gotham,
        TextColor3 = COLORS.TextSecondary,
    })
end

-- === QUICK ACTIONS (Right Side) ===
local QuickActionsPanel = createFrame({
    Name = "QuickActionsPanel",
    Parent = MainHUD,
    Size = UDim2.new(0, SIZES.QuickActionSize + 20, 0, (SIZES.QuickActionSize + 10) * 3),
    Position = UDim2.new(1, -SIZES.SideMargin, 0.4, 0),
    AnchorPoint = Vector2.new(1, 0),
    BackgroundTransparency = 1,
})
addListLayout(QuickActionsPanel, Enum.FillDirection.Vertical, 10)

local quickData = {
    {Name = "DailyRewardButton", Icon = "📅"},
    {Name = "GiftButton", Icon = "🎁"},
    {Name = "FriendsButton", Icon = "👥"},
}

for i, data in ipairs(quickData) do
    local qBtn = createButton({
        Name = data.Name,
        Parent = QuickActionsPanel,
        Size = UDim2.new(0, SIZES.QuickActionSize, 0, SIZES.QuickActionSize),
        BackgroundColor3 = COLORS.Surface,
        Text = data.Icon,
        TextSize = 24,
    })
    qBtn.LayoutOrder = i
    addCorner(qBtn, SIZES.ButtonCorner)
end

-- === NOTIFICATION CONTAINER ===
local NotificationContainer = createFrame({
    Name = "NotificationContainer",
    Parent = MainHUD,
    Size = UDim2.new(0, 280, 0, 350),
    Position = UDim2.new(1, -SIZES.SideMargin, 0, SIZES.TopBarHeight + 10),
    AnchorPoint = Vector2.new(1, 0),
    BackgroundTransparency = 1,
})
addListLayout(NotificationContainer, Enum.FillDirection.Vertical, 8, Enum.HorizontalAlignment.Right, Enum.VerticalAlignment.Top)

-- Notification Template
local NotificationTemplate = createFrame({
    Name = "NotificationTemplate",
    Parent = NotificationContainer,
    Size = UDim2.new(1, 0, 0, 80),
    BackgroundColor3 = COLORS.Panel,
})
NotificationTemplate.Visible = false
addCorner(NotificationTemplate, SIZES.SmallCorner)
addPadding(NotificationTemplate, SIZES.SmallPadding)

local notifIcon = createLabel({
    Name = "Icon",
    Parent = NotificationTemplate,
    Size = UDim2.new(0, 40, 0, 40),
    Position = UDim2.new(0, 0, 0.5, 0),
    AnchorPoint = Vector2.new(0, 0.5),
    Text = "📢",
    TextSize = 24,
})

local notifTitle = createLabel({
    Name = "Title",
    Parent = NotificationTemplate,
    Size = UDim2.new(1, -50, 0, 22),
    Position = UDim2.new(0, 48, 0, 5),
    Text = "Notification Title",
    TextSize = 14,
    Font = Enum.Font.GothamBold,
    TextXAlignment = Enum.TextXAlignment.Left,
})

local notifMessage = createLabel({
    Name = "Message",
    Parent = NotificationTemplate,
    Size = UDim2.new(1, -50, 0, 35),
    Position = UDim2.new(0, 48, 0, 28),
    Text = "Notification message goes here...",
    TextSize = 12,
    Font = Enum.Font.Gotham,
    TextColor3 = COLORS.TextSecondary,
    TextXAlignment = Enum.TextXAlignment.Left,
    TextYAlignment = Enum.TextYAlignment.Top,
})

print("✅ MainHUD created")

-- ============================================================================
-- 2. SHOP SCREEN
-- ============================================================================

local ShopScreen = createScreenGui("ShopScreen", false, 10)

local shopBg = createFrame({
    Name = "Background",
    Parent = ShopScreen,
    BackgroundColor3 = COLORS.Overlay,
    BackgroundTransparency = 0.4,
})

local shopMain = createFrame({
    Name = "MainFrame",
    Parent = ShopScreen,
    Size = UDim2.new(0.75, 0, 0.85, 0),
    Position = UDim2.new(0.5, 0, 0.5, 0),
    AnchorPoint = Vector2.new(0.5, 0.5),
    BackgroundColor3 = COLORS.Background,
})
addCorner(shopMain, SIZES.PanelCorner)

local shopHeader = createFrame({
    Name = "Header",
    Parent = shopMain,
    Size = UDim2.new(1, 0, 0, 60),
    BackgroundColor3 = COLORS.Panel,
})
addCorner(shopHeader, SIZES.PanelCorner)

local shopTitle = createLabel({
    Name = "Title",
    Parent = shopHeader,
    Size = UDim2.new(1, -120, 1, 0),
    Position = UDim2.new(0, 20, 0, 0),
    Text = "🏪 SHOP",
    TextSize = 24,
    TextXAlignment = Enum.TextXAlignment.Left,
})

local shopClose = createButton({
    Name = "CloseButton",
    Parent = shopHeader,
    Size = UDim2.new(0, 44, 0, 44),
    Position = UDim2.new(1, -8, 0.5, 0),
    AnchorPoint = Vector2.new(1, 0.5),
    BackgroundColor3 = COLORS.Error,
    Text = "✕",
    TextSize = 20,
})
addCorner(shopClose, SIZES.SmallCorner)

local shopContent = createScrollFrame({
    Name = "ContentScroll",
    Parent = shopMain,
    Size = UDim2.new(1, -20, 1, -80),
    Position = UDim2.new(0.5, 0, 0, 70),
    AnchorPoint = Vector2.new(0.5, 0),
})
addPadding(shopContent, 10)
addListLayout(shopContent, Enum.FillDirection.Vertical, 15, Enum.HorizontalAlignment.Center, Enum.VerticalAlignment.Top)

-- Pack Template
local PackTemplate = createFrame({
    Name = "PackTemplate",
    Parent = shopContent,
    Size = UDim2.new(1, -20, 0, 120),
    BackgroundColor3 = COLORS.Panel,
})
PackTemplate.Visible = false
addCorner(PackTemplate, SIZES.ButtonCorner)
addPadding(PackTemplate, 15)

local packName = createLabel({
    Name = "PackName",
    Parent = PackTemplate,
    Size = UDim2.new(0.6, 0, 0, 28),
    Text = "Basic Pack",
    TextSize = 20,
    TextXAlignment = Enum.TextXAlignment.Left,
})

local packDesc = createLabel({
    Name = "PackDescription",
    Parent = PackTemplate,
    Size = UDim2.new(0.6, 0, 0, 20),
    Position = UDim2.new(0, 0, 0, 32),
    Text = "Contains 5 random memories",
    TextSize = 14,
    Font = Enum.Font.Gotham,
    TextColor3 = COLORS.TextSecondary,
    TextXAlignment = Enum.TextXAlignment.Left,
})

local packBuyBtn = createButton({
    Name = "BuyButton",
    Parent = PackTemplate,
    Size = UDim2.new(0, 120, 0, 44),
    Position = UDim2.new(1, 0, 0.5, 0),
    AnchorPoint = Vector2.new(1, 0.5),
    BackgroundColor3 = COLORS.Coins,
    Text = "100 🪙",
    TextColor3 = COLORS.CoinsText,
    TextSize = 16,
})
addCorner(packBuyBtn, SIZES.SmallCorner)

print("✅ ShopScreen created")

-- ============================================================================
-- 3. PACK OPENING SCREEN
-- ============================================================================

local PackOpeningScreen = createScreenGui("PackOpeningScreen", false, 15)

local packOpenBg = createFrame({
    Name = "Background",
    Parent = PackOpeningScreen,
    BackgroundColor3 = COLORS.Overlay,
    BackgroundTransparency = 0.2,
})

local animationContainer = createFrame({
    Name = "AnimationContainer",
    Parent = PackOpeningScreen,
    Size = UDim2.new(0.6, 0, 0.6, 0),
    Position = UDim2.new(0.5, 0, 0.45, 0),
    AnchorPoint = Vector2.new(0.5, 0.5),
    BackgroundTransparency = 1,
})

local packPlaceholder = createLabel({
    Name = "PackPlaceholder",
    Parent = animationContainer,
    Size = UDim2.new(1, 0, 1, 0),
    Text = "📦 PACK ANIMATION",
    TextSize = 32,
    BackgroundColor3 = COLORS.Panel,
    BackgroundTransparency = 0.5,
})
addCorner(packPlaceholder, SIZES.PanelCorner)

local revealContainer = createFrame({
    Name = "RevealContainer",
    Parent = PackOpeningScreen,
    BackgroundTransparency = 1,
})
revealContainer.Visible = false
addListLayout(revealContainer, Enum.FillDirection.Horizontal, 20)

-- Memory Card Template
local MemoryCardTemplate = createFrame({
    Name = "MemoryCardTemplate",
    Parent = revealContainer,
    Size = UDim2.new(0, 180, 0, 260),
    BackgroundColor3 = COLORS.Panel,
})
MemoryCardTemplate.Visible = false
addCorner(MemoryCardTemplate, SIZES.ButtonCorner)

local cardImage = createFrame({
    Name = "ImageHolder",
    Parent = MemoryCardTemplate,
    Size = UDim2.new(1, -20, 0.65, 0),
    Position = UDim2.new(0.5, 0, 0, 10),
    AnchorPoint = Vector2.new(0.5, 0),
    BackgroundColor3 = COLORS.Surface,
})
addCorner(cardImage, SIZES.SmallCorner)

local cardName = createLabel({
    Name = "MemoryName",
    Parent = MemoryCardTemplate,
    Size = UDim2.new(1, -10, 0, 24),
    Position = UDim2.new(0.5, 0, 1, -55),
    AnchorPoint = Vector2.new(0.5, 0),
    Text = "Meme Name",
    TextSize = 14,
})

local cardRarity = createLabel({
    Name = "RarityLabel",
    Parent = MemoryCardTemplate,
    Size = UDim2.new(1, -10, 0, 20),
    Position = UDim2.new(0.5, 0, 1, -28),
    AnchorPoint = Vector2.new(0.5, 0),
    Text = "Common",
    TextSize = 12,
    TextColor3 = COLORS.TextSecondary,
})

print("✅ PackOpeningScreen created")

-- ============================================================================
-- 4. INVENTORY SCREEN
-- ============================================================================

local InventoryScreen = createScreenGui("InventoryScreen", false, 10)

local invBg = createFrame({
    Name = "Background",
    Parent = InventoryScreen,
    BackgroundColor3 = COLORS.Overlay,
    BackgroundTransparency = 0.4,
})

local invMain = createFrame({
    Name = "MainFrame",
    Parent = InventoryScreen,
    Size = UDim2.new(0.85, 0, 0.9, 0),
    Position = UDim2.new(0.5, 0, 0.5, 0),
    AnchorPoint = Vector2.new(0.5, 0.5),
    BackgroundColor3 = COLORS.Background,
})
addCorner(invMain, SIZES.PanelCorner)

local invHeader = createFrame({
    Name = "Header",
    Parent = invMain,
    Size = UDim2.new(1, 0, 0, 60),
    BackgroundColor3 = COLORS.Panel,
})
addCorner(invHeader, SIZES.PanelCorner)

local invTitle = createLabel({
    Name = "Title",
    Parent = invHeader,
    Size = UDim2.new(1, -120, 1, 0),
    Position = UDim2.new(0, 20, 0, 0),
    Text = "🎭 COLLECTION",
    TextSize = 24,
    TextXAlignment = Enum.TextXAlignment.Left,
})

local invClose = createButton({
    Name = "CloseButton",
    Parent = invHeader,
    Size = UDim2.new(0, 44, 0, 44),
    Position = UDim2.new(1, -8, 0.5, 0),
    AnchorPoint = Vector2.new(1, 0.5),
    BackgroundColor3 = COLORS.Error,
    Text = "✕",
    TextSize = 20,
})
addCorner(invClose, SIZES.SmallCorner)

-- Stats Bar
local invStats = createFrame({
    Name = "StatsBar",
    Parent = invMain,
    Size = UDim2.new(1, -20, 0, 40),
    Position = UDim2.new(0.5, 0, 0, 70),
    AnchorPoint = Vector2.new(0.5, 0),
    BackgroundColor3 = COLORS.Panel,
})
addCorner(invStats, SIZES.SmallCorner)
addPadding(invStats, 0, 0, 15, 15)
addListLayout(invStats, Enum.FillDirection.Horizontal, 30, Enum.HorizontalAlignment.Left)

local totalLabel = createLabel({
    Name = "TotalMemories",
    Parent = invStats,
    Size = UDim2.new(0, 120, 1, 0),
    Text = "Total: 0",
    TextSize = 14,
    Font = Enum.Font.Gotham,
})

local uniqueLabel = createLabel({
    Name = "UniqueCollected",
    Parent = invStats,
    Size = UDim2.new(0, 150, 1, 0),
    Text = "Unique: 0/20",
    TextSize = 14,
    Font = Enum.Font.Gotham,
})

-- Filter Buttons
local filterBar = createFrame({
    Name = "FilterButtons",
    Parent = invMain,
    Size = UDim2.new(1, -20, 0, 44),
    Position = UDim2.new(0.5, 0, 0, 120),
    AnchorPoint = Vector2.new(0.5, 0),
    BackgroundTransparency = 1,
})
addListLayout(filterBar, Enum.FillDirection.Horizontal, 8)

local filters = {"All", "Common", "Uncommon", "Rare", "Epic", "Legendary"}
for i, name in ipairs(filters) do
    local filterBtn = createButton({
        Name = name .. "Filter",
        Parent = filterBar,
        Size = UDim2.new(0, 90, 0, 36),
        BackgroundColor3 = i == 1 and COLORS.Primary or COLORS.Surface,
        Text = name,
        TextSize = 12,
    })
    filterBtn.LayoutOrder = i
    addCorner(filterBtn, SIZES.SmallCorner)
end

-- Memories Grid
local invScroll = createScrollFrame({
    Name = "MemoriesGrid",
    Parent = invMain,
    Size = UDim2.new(1, -20, 1, -185),
    Position = UDim2.new(0.5, 0, 0, 175),
    AnchorPoint = Vector2.new(0.5, 0),
})
addPadding(invScroll, 10)
addGridLayout(invScroll, UDim2.new(0, 140, 0, 190), UDim2.new(0, 12, 0, 12))

-- Memory Card Template for Inventory
local invCardTemplate = createFrame({
    Name = "MemoryCardTemplate",
    Parent = invScroll,
    Size = UDim2.new(0, 140, 0, 190),
    BackgroundColor3 = COLORS.Panel,
})
invCardTemplate.Visible = false
addCorner(invCardTemplate, SIZES.SmallCorner)

-- Image holder for the memory
local invCardImage = createFrame({
    Name = "ImageHolder",
    Parent = invCardTemplate,
    Size = UDim2.new(1, -16, 0.6, 0),
    Position = UDim2.new(0.5, 0, 0, 8),
    AnchorPoint = Vector2.new(0.5, 0),
    BackgroundColor3 = COLORS.Surface,
})
addCorner(invCardImage, SIZES.SmallCorner)

-- Name label
local invCardName = createLabel({
    Name = "NameLabel",
    Parent = invCardTemplate,
    Size = UDim2.new(1, -10, 0, 22),
    Position = UDim2.new(0.5, 0, 1, -50),
    AnchorPoint = Vector2.new(0.5, 0),
    Text = "Meme Name",
    TextSize = 13,
    Font = Enum.Font.GothamBold,
})

-- Rarity label
local invCardRarity = createLabel({
    Name = "RarityLabel",
    Parent = invCardTemplate,
    Size = UDim2.new(1, -10, 0, 18),
    Position = UDim2.new(0.5, 0, 1, -26),
    AnchorPoint = Vector2.new(0.5, 0),
    Text = "Common",
    TextSize = 11,
    Font = Enum.Font.Gotham,
    TextColor3 = COLORS.TextSecondary,
})

print("✅ InventoryScreen created")

-- ============================================================================
-- 5-11. REMAINING SCREENS (Trading, Profile, Leaderboard, DailyRewards, GiftCenter, Settings, Loading)
-- ============================================================================

-- Create remaining screens with same pattern
local screenConfigs = {
    {Name = "TradingScreen", Title = "🔄 TRADING", Order = 10},
    {Name = "ProfileScreen", Title = "👤 PROFILE", Order = 10},
    {Name = "LeaderboardScreen", Title = "🏆 LEADERBOARD", Order = 10},
    {Name = "DailyRewardsScreen", Title = "📅 DAILY REWARDS", Order = 10},
    {Name = "GiftCenterScreen", Title = "🎁 GIFT CENTER", Order = 10},
    {Name = "SettingsScreen", Title = "⚙️ SETTINGS", Order = 10},
}

for _, config in ipairs(screenConfigs) do
    local screen = createScreenGui(config.Name, false, config.Order)
    
    local bg = createFrame({
        Name = "Background",
        Parent = screen,
        BackgroundColor3 = COLORS.Overlay,
        BackgroundTransparency = 0.4,
    })
    
    local mainFrame = createFrame({
        Name = "MainFrame",
        Parent = screen,
        Size = UDim2.new(0.7, 0, 0.8, 0),
        Position = UDim2.new(0.5, 0, 0.5, 0),
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundColor3 = COLORS.Background,
    })
    addCorner(mainFrame, SIZES.PanelCorner)
    
    local header = createFrame({
        Name = "Header",
        Parent = mainFrame,
        Size = UDim2.new(1, 0, 0, 60),
        BackgroundColor3 = COLORS.Panel,
    })
    addCorner(header, SIZES.PanelCorner)
    
    local title = createLabel({
        Name = "Title",
        Parent = header,
        Size = UDim2.new(1, -120, 1, 0),
        Position = UDim2.new(0, 20, 0, 0),
        Text = config.Title,
        TextSize = 24,
        TextXAlignment = Enum.TextXAlignment.Left,
    })
    
    local closeBtn = createButton({
        Name = "CloseButton",
        Parent = header,
        Size = UDim2.new(0, 44, 0, 44),
        Position = UDim2.new(1, -8, 0.5, 0),
        AnchorPoint = Vector2.new(1, 0.5),
        BackgroundColor3 = COLORS.Error,
        Text = "✕",
        TextSize = 20,
    })
    addCorner(closeBtn, SIZES.SmallCorner)
    
    local content = createFrame({
        Name = "Content",
        Parent = mainFrame,
        Size = UDim2.new(1, -20, 1, -80),
        Position = UDim2.new(0.5, 0, 0, 70),
        AnchorPoint = Vector2.new(0.5, 0),
        BackgroundTransparency = 1,
    })
    
    print("✅ " .. config.Name .. " created")
end

-- ============================================================================
-- LOADING SCREEN (Special - Always visible initially)
-- ============================================================================

local LoadingScreen = createScreenGui("LoadingScreen", true, 100)

local loadBg = createFrame({
    Name = "Background",
    Parent = LoadingScreen,
    BackgroundColor3 = COLORS.Background,
})

local logoLabel = createLabel({
    Name = "Logo",
    Parent = LoadingScreen,
    Size = UDim2.new(0, 450, 0, 100),
    Position = UDim2.new(0.5, 0, 0.35, 0),
    AnchorPoint = Vector2.new(0.5, 0.5),
    Text = "MEMORY RUSH",
    TextSize = 52,
    Font = Enum.Font.GothamBlack,
})

local loadingBarBg = createFrame({
    Name = "LoadingBar",
    Parent = LoadingScreen,
    Size = UDim2.new(0, 400, 0, 16),
    Position = UDim2.new(0.5, 0, 0.5, 0),
    AnchorPoint = Vector2.new(0.5, 0.5),
    BackgroundColor3 = COLORS.Surface,
})
addCorner(loadingBarBg, 8)

local loadingProgress = createFrame({
    Name = "Progress",
    Parent = loadingBarBg,
    Size = UDim2.new(0, 0, 1, 0),
    BackgroundColor3 = COLORS.Success,
})
addCorner(loadingProgress, 8)

local tipLabel = createLabel({
    Name = "TipLabel",
    Parent = LoadingScreen,
    Size = UDim2.new(0, 600, 0, 50),
    Position = UDim2.new(0.5, 0, 0.62, 0),
    AnchorPoint = Vector2.new(0.5, 0.5),
    Text = "Loading...",
    TextSize = 16,
    Font = Enum.Font.Gotham,
    TextColor3 = COLORS.TextSecondary,
})

print("✅ LoadingScreen created")

-- ============================================================================
-- SUMMARY
-- ============================================================================
print("\n" .. string.rep("=", 60))
print("✨ GUI STRUCTURE CREATED SUCCESSFULLY! ✨")
print(string.rep("=", 60))
print("\n📂 Created ScreenGuis:")
print("   1. MainHUD (Enabled, DisplayOrder=5)")
print("   2. ShopScreen (Disabled, DisplayOrder=10)")
print("   3. PackOpeningScreen (Disabled, DisplayOrder=15)")
print("   4. InventoryScreen (Disabled, DisplayOrder=10)")
print("   5. TradingScreen (Disabled, DisplayOrder=10)")
print("   6. ProfileScreen (Disabled, DisplayOrder=10)")
print("   7. LeaderboardScreen (Disabled, DisplayOrder=10)")
print("   8. DailyRewardsScreen (Disabled, DisplayOrder=10)")
print("   9. GiftCenterScreen (Disabled, DisplayOrder=10)")
print("   10. SettingsScreen (Disabled, DisplayOrder=10)")
print("   11. LoadingScreen (Enabled, DisplayOrder=100)")
print("\n🎨 Features included:")
print("   ✓ Proper AnchorPoints for intuitive positioning")
print("   ✓ UICorner on all buttons and panels")
print("   ✓ UIListLayout for automatic arrangement")
print("   ✓ UIPadding for consistent spacing")
print("   ✓ Configurable COLORS and SIZES at top of script")
print("   ✓ IgnoreGuiInset=true for full screen coverage")
print("\n📝 To customize:")
print("   • Edit COLORS table at top to change theme")
print("   • Edit SIZES table at top to adjust dimensions")
print("   • Select elements in Explorer to adjust positions")
print(string.rep("=", 60))
