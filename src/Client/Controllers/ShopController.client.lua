--[[
	ShopController.client.lua
	Controls the Shop Screen
	
	📍 Location: src/Client/Controllers/ShopController.client.lua
	
	MANUAL:
	1. This script populates the Shop with packs from GameConfig
	2. It handles the "Buy" button and sends requests to the server
	3. Upon success, it triggers the PackOpeningController
	
	SETUP:
	- Ensure GameConfig.Shop.Packs has valid data
	- Put your pack images in GameConfig or override below
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
local RemoteEvents = require(ReplicatedStorage.Shared:WaitForChild("RemoteEvents"))
-- ...

local function Init()
	local screen = layerGui:WaitForChild("ShopScreen")
	Scaler.AddScaleConstraint(screen) -- Apply Scale
	
	local mainFrame = screen:WaitForChild("MainFrame")
	local scrollFrame = mainFrame:WaitForChild("PacksScrollFrame")
	local template = scrollFrame:WaitForChild("PackTemplate")
	
	-- Close Button
	local header = mainFrame:WaitForChild("Header")
	local closeBtn = header:WaitForChild("CloseButton")
	
	closeBtn.MouseButton1Click:Connect(function()
		print("Closing shop")
		screen.Enabled = false
	end)
	
	-- Populate Shop
	local function populateShop()
		-- Clear old (except template)
		for _, child in ipairs(scrollFrame:GetChildren()) do
			if child:IsA("Frame") and child ~= template then
				child:Destroy()
			end
		end
		
		-- Sort packs by price (optional)
		local packs = {}
		for id, data in pairs(GameConfig.Shop.Packs) do
			data.Id = id
			table.insert(packs, data)
		end
		table.sort(packs, function(a, b) return a.Price < b.Price end)
		
		-- Create Cards
		for _, packData in ipairs(packs) do
			local card = template:Clone()
			card.Name = packData.Id
			card.Visible = true
			card.Parent = scrollFrame
			
			-- Setup Data
			local nameLabel = card:WaitForChild("PackName")
			local descLabel = card:WaitForChild("PackDescription")
			local buyBtn = card:WaitForChild("BuyButton")
			local packImage = card:FindFirstChild("PackImage")
			
			nameLabel.Text = packData.Name
			descLabel.Text = packData.Description
			
			-- Image
			if packImage and (packData.ImageId ~= "rbxassetid://0" or ASSETS[packData.Id]) then
				packImage.Image = ASSETS[packData.Id] or packData.ImageId
			else
				-- Optional: Hide image if none
				if packImage then packImage.Visible = false end
			end
			
			-- Price Button
			local currencyIcon = packData.Currency == "Coins" and "🪙" or "💎"
			buyBtn.Text = string.format("Buy %s %d", currencyIcon, packData.Price)
			
			-- Buy Logic
			buyBtn.MouseButton1Click:Connect(function()
				handlePurchase(packData)
			end)
		end
	end
	
	populateShop()
end

function handlePurchase(packData)
	-- 1. Client-side check
	local canAfford = ClientData.CanAfford(
		packData.Currency == "Coins" and packData.Price or 0,
		packData.Currency == "Gems" and packData.Price or 0
	)
	
	if not canAfford then
		-- Trigger notification
		ClientData.FireNotification({
			Type = "error", 
			Title = "Insufficient Funds", 
			Message = "You need more " .. packData.Currency
		})
		return
	end
	
	-- 2. Send Request
	-- Using InvokeServer implementation (needs to be set up on server)
	-- OR FireServer if we listen for events back.
	-- Let's assume passed-through RemoteFunction for immediate result or Event.
	-- Strategy: Use RemoteFunction "PurchasePack"
	
	-- Loading state on button? (TODO)
	
	local result = RemoteEvents.InvokeServer("PurchasePack", packData.Id)
	
	if result and result.Success then
		-- 3. Success!
		-- Close shop
		layerGui.ShopScreen.Enabled = false
		
		-- Trigger Animation
		-- Require PackOpeningController now to avoid cyclic deps if any
		if not PackOpeningController then
			PackOpeningController = require(script.Parent:WaitForChild("PackOpeningController"))
		end
		
		PackOpeningController.PlayPackOpening(packData.Id, result.Rewards)
	else
		-- Error
		warn("Purchase failed:", result and result.Error)
		ClientData.OnNotification:Fire({
			Type = "error", 
			Title = "Purchase Failed", 
			Message = result and result.Error or "Unknown error"
		})
	end
end

-- Wait for PlayerGui
if layerGui:FindFirstChild("ShopScreen") then
	Init()
else
	layerGui.ChildAdded:Connect(function(child)
		if child.Name == "ShopScreen" then
			Init()
		end
	end)
end

return ShopController
