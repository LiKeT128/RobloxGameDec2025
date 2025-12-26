--[[
	PackOpeningController.client.lua
	Controls the visual pack opening sequence
	
	📍 Location: src/Client/Controllers/PackOpeningController.client.lua
	
	MANUAL:
	1. Call PlayPackOpening(packId, rewards) to start the sequence
	2. This controller manages the PackOpeningScreen animations
	3. Setup your 3D models in the ViewportFrame if desired, or use Images
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local player = Players.LocalPlayer
local layerGui = player:WaitForChild("PlayerGui")

-- Modules
local ClientData = require(script.Parent.Parent.Modules:WaitForChild("ClientDataUpdater"))
local Scaler = require(script.Parent.Parent.Modules:WaitForChild("Scaler")) -- Add Scaler
local GameConfig = require(ReplicatedStorage.Shared:WaitForChild("GameConfig"))

-- ...

local ASSETS = {
	-- ...
}

-- ============================================================================
-- CONTROLLER LOGIC
-- ============================================================================

local PackOpeningController = {}
local screen = layerGui:WaitForChild("PackOpeningScreen")
Scaler.AddScaleConstraint(screen) -- Apply Scale

local animContainer = screen:WaitForChild("AnimationContainer")
local revealContainer = screen:WaitForChild("RevealContainer")
local packPlaceholder = animContainer:WaitForChild("PackPlaceholder") -- Label or Image
local cardTemplate = revealContainer:WaitForChild("MemoryCardTemplate")

local isAnimating = false

-- Utility to get rarity color
local rarityColors = {
	[1] = Color3.fromRGB(180, 180, 180), -- Common
	[2] = Color3.fromRGB(100, 255, 100), -- Uncommon
	[3] = Color3.fromRGB(100, 100, 255), -- Rare
	[4] = Color3.fromRGB(200, 100, 255), -- Epic
	[5] = Color3.fromRGB(255, 200, 50),  -- Legendary
}

function PackOpeningController.PlayPackOpening(packId, rewards)
	if isAnimating then return end
	isAnimating = true
	
	screen.Enabled = true
	revealContainer.Visible = false
	animContainer.Visible = true
	
	-- 1. Reset State
	packPlaceholder.Size = UDim2.new(0, 0, 0, 0)
	packPlaceholder.Rotation = 0
	packPlaceholder.Text = "📦" -- Or Image
	
	-- Clear old cards
	for _, child in ipairs(revealContainer:GetChildren()) do
		if child ~= cardTemplate then child:Destroy() end
	end
	
	-- 2. Pack Intro Animation
	local introTween = TweenService:Create(packPlaceholder, TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Size = UDim2.new(1, 0, 1, 0),
		Rotation = 0
	})
	introTween:Play()
	introTween.Completed:Wait()
	
	-- 3. Shake Animation (Anticipation)
	local shakeDuration = 1.0
	local startTime = tick()
	while tick() - startTime < shakeDuration do
		local offset = math.random(-10, 10)
		packPlaceholder.Rotation = offset
		task.wait(0.05)
	end
	packPlaceholder.Rotation = 0
	
	-- 4. Explosion / Open
	local explodeTween = TweenService:Create(packPlaceholder, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
		Size = UDim2.new(2, 0, 2, 0),
		TextTransparency = 1 -- Fade out
	})
	explodeTween:Play()
	explodeTween.Completed:Wait()
	
	animContainer.Visible = false
	revealContainer.Visible = true
	
	-- 5. Reveal Cards Logic
	local cards = {}
	
	-- Process rewards into card data
	-- Rewards usually: { "meme_drake", "meme_doge", ... } or { {Id="...", Count=1}, ... }
	-- Assuming simple list of IDs as per DataValidator? Or list of objects?
	-- Let's assume list of objects: { {MemoryId="meme_drake", IsNew=true}, ... } from server
	-- If strictly ID strings:
	if type(rewards[1]) == "string" then
		-- Convert to objects
		local temp = {}
		for _, id in ipairs(rewards) do
			table.insert(temp, {MemoryId = id, IsNew = false}) -- We don't know if new client-side easily without checking cache before
		end
		rewards = temp
	end
	
	local cardCount = #rewards
	local totalWidth = 200 * cardCount + 20 * (cardCount - 1) -- 200px width, 20px pad
	local startX = (screen.AbsoluteSize.X - totalWidth) / 2
	
	-- Layout manually or use UIListLayout. Use manual for animation control.
	for i, rewardData in ipairs(rewards) do
		local card = cardTemplate:Clone()
		card.Visible = true
		card.Parent = revealContainer
		card.Position = UDim2.new(0.5, 0, 0.5, 0) -- Start center
		card.Size = UDim2.new(0, 0, 0, 0) -- Start small
		
		-- Setup Visuals
		local info = GameConfig.GetMemoryInfo(rewardData.MemoryId)
		if info then
			card:WaitForChild("MemoryName").Text = info.Name
			local rLabel = card:WaitForChild("RarityLabel")
			rLabel.Text = GameConfig.GetRarityName(info.Rarity)
			card.BackgroundColor3 = rarityColors[info.Rarity] or Color3.new(0.5,0.5,0.5)
			
			-- Images (TODO)
			-- card:WaitForChild("MemoryImage").Image = info.ImageId
		end
		
		-- Animate Card Out
		local targetPos = UDim2.new(0.5, (i - (cardCount+1)/2) * 220, 0.5, 0)
		
		local moveTween = TweenService:Create(card, TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
			Position = targetPos,
			Size = UDim2.new(0, 200, 0, 280)
		})
		moveTween:Play()
		
		-- Stagger
		task.wait(0.2)
	end
	
	-- 6. Done button
	task.wait(1)
	
	-- Simple "Click to continue" overlay (or reuse main frame click)
	-- For now, auto-close after 3s or add a button dynamically
	local continueBtn = Instance.new("TextButton")
	continueBtn.Size = UDim2.new(0, 200, 0, 50)
	continueBtn.Position = UDim2.new(0.5, -100, 0.85, 0)
	continueBtn.Text = "CONTINUE"
	continueBtn.BackgroundColor3 = Color3.fromRGB(50, 200, 50)
	continueBtn.Parent = screen
	
	continueBtn.MouseButton1Click:Connect(function()
		isAnimating = false
		screen.Enabled = false
		continueBtn:Destroy()
	end)
	
end

return PackOpeningController
