--[[
	InventoryController.client.lua
	Controls the Inventory/Collection Screen
	
	📍 Location: src/Client/Controllers/InventoryController.client.lua
	
	MANUAL:
	1. Displays all collected memes
	2. Handles filtering by rarity (Tabs)
	3. Updates statistics (Total/Unique)
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local layerGui = player:WaitForChild("PlayerGui")

-- Modules
local ClientData = require(script.Parent.Parent.Modules:WaitForChild("ClientDataUpdater"))
local Scaler = require(script.Parent.Parent.Modules:WaitForChild("Scaler")) -- Add Scaler
local GameConfig = require(ReplicatedStorage.Shared:WaitForChild("GameConfig"))

-- ============================================================================
-- 🎨 ASSET OVERRIDES
-- ============================================================================

-- ...

local InventoryController = {}

local rarityColors = {
	[1] = Color3.fromRGB(180, 180, 180), -- Common
	[2] = Color3.fromRGB(100, 255, 100), -- Uncommon
	[3] = Color3.fromRGB(100, 100, 255), -- Rare
	[4] = Color3.fromRGB(200, 100, 255), -- Epic
	[5] = Color3.fromRGB(255, 200, 50),  -- Legendary
}

local function Init()
	local screen = layerGui:WaitForChild("InventoryScreen")
	Scaler.AddScaleConstraint(screen) -- Apply Scale
	
	local mainFrame = screen:WaitForChild("MainFrame")
	local memGrid = mainFrame:WaitForChild("MemoriesGrid")
	local template = memGrid:WaitForChild("MemoryCardTemplate")
	local statsBar = mainFrame:WaitForChild("StatsBar")
	local filterFrame = mainFrame:WaitForChild("FilterButtons")
	
	-- Close Button
	mainFrame:WaitForChild("Header"):WaitForChild("CloseButton").MouseButton1Click:Connect(function()
		screen.Enabled = false
	end)
	
	-- Filter Logic
	local currentFilter = "All"
	
	local function updateInventory()
		if not screen.Enabled then return end
		
		-- Clear
		for _, child in ipairs(memGrid:GetChildren()) do
			if child:IsA("Frame") and child ~= template then
				child:Destroy()
			end
		end
		
		-- Get Data
		local inventory = ClientData.GetInventory()
		local memories = inventory.Memories or {}
		
		-- Update Stats
		local totalCount = inventory.TotalMemories or 0
		local uniqueCount = 0
		for _, _ in pairs(memories) do uniqueCount += 1 end
		
		-- Stats Display
		statsBar:WaitForChild("TotalMemories").Text = "Total: " .. totalCount
		-- Need total unique possible from GameConfig to show "5/20"
		local maxUnique = 20 -- TODO: Get from GameConfig count
		statsBar:WaitForChild("UniqueCollected").Text = string.format("Unique: %d/%d", uniqueCount, maxUnique)
		
		-- Populate Grid
		for memId, count in pairs(memories) do
			if count > 0 then
				local info = GameConfig.GetMemoryInfo(memId)
				if info then
					-- Check Filter
					local rarityName = GameConfig.GetRarityName(info.Rarity)
					if currentFilter == "All" or currentFilter == rarityName then
						local card = template:Clone()
						card.Visible = true
						card.Parent = memGrid
						
						card:WaitForChild("NameLabel").Text = info.Name
						card:WaitForChild("RarityLabel").Text = rarityName
						card.BackgroundColor3 = rarityColors[info.Rarity] or Color3.new(1,1,1)
						
						-- Image
						-- local img = card:FindFirstChild("Image") ...
						
						-- Count Badge (Create if not exists in template)
						local countLabel = card:FindFirstChild("CountLabel")
						if not countLabel then
							countLabel = Instance.new("TextLabel")
							countLabel.Name = "CountLabel"
							countLabel.Size = UDim2.new(0, 40, 0, 30)
							countLabel.Position = UDim2.new(1, -45, 0, 5)
							countLabel.BackgroundColor3 = Color3.new(0,0,0)
							countLabel.BackgroundTransparency = 0.5
							countLabel.TextColor3 = Color3.new(1,1,1)
							countLabel.Parent = card
						end
						countLabel.Text = "x"..count
					end
				end
			end
		end
		
		-- Add sorting? (By rarity desc)
	end
	
	-- Connect Filters
	for _, btn in ipairs(filterFrame:GetChildren()) do
		if btn:IsA("TextButton") then
			btn.MouseButton1Click:Connect(function()
				currentFilter = btn.Name:gsub("Button", "") -- "All", "Common"...
				updateInventory()
			end)
		end
	end
	
	-- Listen for open
	screen:GetPropertyChangedSignal("Enabled"):Connect(function()
		if screen.Enabled then
			updateInventory()
		end
	end)
	
	-- Listen for changes
	ClientData.OnInventoryChanged:Connect(function()
		if screen.Enabled then
			updateInventory()
		end
	end)
end

-- Wait for UI
if layerGui:FindFirstChild("InventoryScreen") then
	Init()
else
	layerGui.ChildAdded:Connect(function(child)
		if child.Name == "InventoryScreen" then
			Init()
		end
	end)
end

return InventoryController
