--[[
	ClientDataUpdater.lua
	Client-side data handling for Memory Rush
	
	This LocalScript handles:
	- Receiving data updates from server
	- Maintaining local cache of player data
	- Providing API for UI scripts to access data
	- Handling notifications for trades, gifts, etc.
	
	Usage in other client scripts:
		local ClientData = require(StarterPlayerScripts.Client.ClientDataUpdater)
		
		-- Get current data
		local coins = ClientData.GetCoins()
		local inventory = ClientData.GetInventory()
		
		-- Listen for updates
		ClientData.OnCurrencyChanged:Connect(function(data)
			print("New balance:", data.Amount)
		end)
	
	Author: Memory Rush Team
	Version: 1.0.0
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer

--------------------------------------------------------------------------------
-- WAIT FOR MODULES
--------------------------------------------------------------------------------

local Shared = ReplicatedStorage:WaitForChild("Shared", 30)
if not Shared then
	error("[ClientDataUpdater] Failed to find Shared folder")
end

local GameConfig = require(Shared:WaitForChild("GameConfig"))
local RemoteEvents = require(Shared:WaitForChild("RemoteEvents"))

-- Wait for remotes to be ready
RemoteEvents.WaitForReady(30)

print("[ClientDataUpdater] Modules loaded")

--------------------------------------------------------------------------------
-- MODULE SETUP
--------------------------------------------------------------------------------

local ClientDataUpdater = {}

-- Local data cache
local DataCache = {
	IsLoaded = false,
	Currency = { Coins = 0, Gems = 0 },
	Inventory = { Memories = {}, TotalMemories = 0 },
	Statistics = {},
	Settings = {},
	DailyRewards = {},
	PendingGiftCount = 0,
	PendingTradeCount = 0,
}

-- Bindable events for UI updates
local CurrencyChangedEvent = Instance.new("BindableEvent")
local InventoryChangedEvent = Instance.new("BindableEvent")
local StatisticsUpdatedEvent = Instance.new("BindableEvent")
local ProfileLoadedEvent = Instance.new("BindableEvent")
local TradeEvent = Instance.new("BindableEvent")
local GiftEvent = Instance.new("BindableEvent")
local NotificationEvent = Instance.new("BindableEvent")

-- Public events
ClientDataUpdater.OnCurrencyChanged = CurrencyChangedEvent.Event
ClientDataUpdater.OnInventoryChanged = InventoryChangedEvent.Event
ClientDataUpdater.OnStatisticsUpdated = StatisticsUpdatedEvent.Event
ClientDataUpdater.OnProfileLoaded = ProfileLoadedEvent.Event
ClientDataUpdater.OnTradeEvent = TradeEvent.Event
ClientDataUpdater.OnGiftEvent = GiftEvent.Event
ClientDataUpdater.OnNotification = NotificationEvent.Event

-- Public Fire methods (so other controllers can trigger them)
function ClientDataUpdater.FireNotification(data)
	NotificationEvent:Fire(data)
end

--------------------------------------------------------------------------------
-- REMOTE EVENT HANDLERS
--------------------------------------------------------------------------------

-- Profile loaded
RemoteEvents.OnClientEvent("ProfileLoaded", function(data)
	print("[ClientDataUpdater] Profile loaded!")
	
	DataCache.IsLoaded = true
	DataCache.Currency = data.Currency or DataCache.Currency
	DataCache.Inventory = data.Inventory or DataCache.Inventory
	DataCache.Statistics = data.Statistics or DataCache.Statistics
	DataCache.Settings = data.Settings or DataCache.Settings
	DataCache.DailyRewards = data.DailyRewards or DataCache.DailyRewards
	DataCache.PendingGiftCount = data.PendingGiftCount or 0
	DataCache.PendingTradeCount = data.PendingTradeCount or 0
	
	ProfileLoadedEvent:Fire(DataCache)
end)

-- Currency changed
RemoteEvents.OnClientEvent("CurrencyChanged", function(data)
	--[[
		data = {
			Type = "Coins" | "Gems",
			Amount = number,
			Change = number,
			Reason = string,
			Timestamp = number,
		}
	]]
	
	if data.Type == "Coins" then
		DataCache.Currency.Coins = data.Amount
	elseif data.Type == "Gems" then
		DataCache.Currency.Gems = data.Amount
	end
	
	CurrencyChangedEvent:Fire(data)
	
	-- Show notification for significant changes
	if math.abs(data.Change) >= 10 then
		local sign = data.Change > 0 and "+" or ""
		NotificationEvent:Fire({
			Type = "currency",
			Title = data.Type,
			Message = string.format("%s%d %s", sign, data.Change, data.Type),
			Icon = data.Type == "Gems" and "💎" or "🪙",
		})
	end
end)

-- Inventory changed
RemoteEvents.OnClientEvent("InventoryChanged", function(data)
	--[[
		data = {
			MemoryId = string,
			MemoryName = string,
			Count = number,
			Change = number,
			Reason = string,
			Timestamp = number,
		}
	]]
	
	if not DataCache.Inventory.Memories then
		DataCache.Inventory.Memories = {}
	end
	
	if data.Count > 0 then
		DataCache.Inventory.Memories[data.MemoryId] = data.Count
	else
		DataCache.Inventory.Memories[data.MemoryId] = nil
	end
	
	-- Recalculate total
	local total = 0
	for _, count in pairs(DataCache.Inventory.Memories) do
		total = total + count
	end
	DataCache.Inventory.TotalMemories = total
	
	InventoryChangedEvent:Fire(data)
	
	-- Show notification for additions
	if data.Change > 0 then
		NotificationEvent:Fire({
			Type = "inventory",
			Title = "New Memory!",
			Message = string.format("+%d %s", data.Change, data.MemoryName),
			Icon = "🎭",
		})
	end
end)

-- Statistics updated
RemoteEvents.OnClientEvent("StatisticsUpdated", function(data)
	DataCache.Statistics = data
	StatisticsUpdatedEvent:Fire(data)
end)

-- Settings updated
RemoteEvents.OnClientEvent("SettingsUpdated", function(data)
	DataCache.Settings = data
end)

--------------------------------------------------------------------------------
-- TRADE EVENT HANDLERS
--------------------------------------------------------------------------------

RemoteEvents.OnClientEvent("TradeCreated", function(data)
	DataCache.PendingTradeCount = DataCache.PendingTradeCount + 1
	
	TradeEvent:Fire({
		Type = "created",
		Data = data,
	})
	
	NotificationEvent:Fire({
		Type = "trade",
		Title = "Trade Request!",
		Message = string.format("%s wants to trade with you", data.FromPlayerName or "Someone"),
		Icon = "🔄",
	})
end)

RemoteEvents.OnClientEvent("TradeUpdated", function(data)
	TradeEvent:Fire({
		Type = "updated",
		Data = data,
	})
end)

RemoteEvents.OnClientEvent("TradeCompleted", function(data)
	DataCache.PendingTradeCount = math.max(0, DataCache.PendingTradeCount - 1)
	
	TradeEvent:Fire({
		Type = "completed",
		Data = data,
	})
	
	NotificationEvent:Fire({
		Type = "trade",
		Title = "Trade Complete!",
		Message = "Trade was successful",
		Icon = "✅",
	})
end)

RemoteEvents.OnClientEvent("TradeCancelled", function(data)
	DataCache.PendingTradeCount = math.max(0, DataCache.PendingTradeCount - 1)
	
	TradeEvent:Fire({
		Type = "cancelled",
		Data = data,
	})
end)

RemoteEvents.OnClientEvent("TradeExpired", function(data)
	DataCache.PendingTradeCount = math.max(0, DataCache.PendingTradeCount - 1)
	
	TradeEvent:Fire({
		Type = "expired",
		Data = data,
	})
end)

--------------------------------------------------------------------------------
-- GIFT EVENT HANDLERS
--------------------------------------------------------------------------------

RemoteEvents.OnClientEvent("GiftReceived", function(data)
	DataCache.PendingGiftCount = DataCache.PendingGiftCount + 1
	
	GiftEvent:Fire({
		Type = "received",
		Data = data,
	})
	
	NotificationEvent:Fire({
		Type = "gift",
		Title = "Gift Received!",
		Message = string.format("%s sent you a %s", 
			data.FromPlayerName or "Someone", 
			data.MemoryName or "memory"),
		Icon = "🎁",
	})
end)

RemoteEvents.OnClientEvent("GiftClaimed", function(data)
	DataCache.PendingGiftCount = math.max(0, DataCache.PendingGiftCount - 1)
	
	GiftEvent:Fire({
		Type = "claimed",
		Data = data,
	})
end)

RemoteEvents.OnClientEvent("GiftExpired", function(data)
	DataCache.PendingGiftCount = math.max(0, DataCache.PendingGiftCount - 1)
	
	GiftEvent:Fire({
		Type = "expired",
		Data = data,
	})
end)

--------------------------------------------------------------------------------
-- DAILY REWARD HANDLERS
--------------------------------------------------------------------------------

RemoteEvents.OnClientEvent("DailyRewardAvailable", function(data)
	DataCache.DailyRewards = data
	
	NotificationEvent:Fire({
		Type = "daily",
		Title = "Daily Reward!",
		Message = "Your daily reward is ready to claim",
		Icon = "📅",
	})
end)

RemoteEvents.OnClientEvent("DailyRewardClaimed", function(data)
	DataCache.DailyRewards = data
	
	NotificationEvent:Fire({
		Type = "daily",
		Title = "Reward Claimed!",
		Message = string.format("+%d Coins, +%d Gems (Day %d)", 
			data.Coins or 0, data.Gems or 0, data.Streak or 1),
		Icon = "🎉",
	})
end)

--------------------------------------------------------------------------------
-- NOTIFICATION HANDLERS
--------------------------------------------------------------------------------

RemoteEvents.OnClientEvent("ShowNotification", function(data)
	NotificationEvent:Fire(data)
end)

RemoteEvents.OnClientEvent("ShowError", function(data)
	NotificationEvent:Fire({
		Type = "error",
		Title = "Error",
		Message = data.Message or "An error occurred",
		Icon = "❌",
	})
end)

--------------------------------------------------------------------------------
-- PUBLIC API - DATA GETTERS
--------------------------------------------------------------------------------

-- Check if profile is loaded
function ClientDataUpdater.IsLoaded(): boolean
	return DataCache.IsLoaded
end

-- Wait for profile to load
function ClientDataUpdater.WaitForLoad(timeout: number?): boolean
	local maxWait = timeout or 30
	local elapsed = 0
	
	while not DataCache.IsLoaded and elapsed < maxWait do
		task.wait(0.1)
		elapsed = elapsed + 0.1
	end
	
	return DataCache.IsLoaded
end

-- Get coins
function ClientDataUpdater.GetCoins(): number
	return DataCache.Currency.Coins or 0
end

-- Get gems
function ClientDataUpdater.GetGems(): number
	return DataCache.Currency.Gems or 0
end

-- Get currency (both)
function ClientDataUpdater.GetCurrency(): { Coins: number, Gems: number }
	return {
		Coins = DataCache.Currency.Coins or 0,
		Gems = DataCache.Currency.Gems or 0,
	}
end

-- Get inventory
function ClientDataUpdater.GetInventory(): table
	return DataCache.Inventory
end

-- Get memory count
function ClientDataUpdater.GetMemoryCount(memoryId: string): number
	if DataCache.Inventory.Memories then
		return DataCache.Inventory.Memories[memoryId] or 0
	end
	return 0
end

-- Get total memory count
function ClientDataUpdater.GetTotalMemories(): number
	return DataCache.Inventory.TotalMemories or 0
end

-- Get statistics
function ClientDataUpdater.GetStatistics(): table
	return DataCache.Statistics
end

-- Get a specific statistic
function ClientDataUpdater.GetStat(statName: string): number
	return DataCache.Statistics[statName] or 0
end

-- Get settings
function ClientDataUpdater.GetSettings(): table
	return DataCache.Settings
end

-- Get daily rewards info
function ClientDataUpdater.GetDailyRewards(): table
	return DataCache.DailyRewards
end

-- Get pending gift count
function ClientDataUpdater.GetPendingGiftCount(): number
	return DataCache.PendingGiftCount
end

-- Get pending trade count
function ClientDataUpdater.GetPendingTradeCount(): number
	return DataCache.PendingTradeCount
end

-- Get full cache (for debugging)
function ClientDataUpdater.GetFullCache(): table
	return DataCache
end

--------------------------------------------------------------------------------
-- PUBLIC API - SERVER REQUESTS
--------------------------------------------------------------------------------

-- Request full data refresh from server
function ClientDataUpdater.RefreshData(): table?
	local result = RemoteEvents.InvokeServer("RequestPlayerData")
	
	if result and not result.Error then
		DataCache.Currency = result.Currency or DataCache.Currency
		DataCache.Inventory = result.Inventory or DataCache.Inventory
		DataCache.Statistics = result.Statistics or DataCache.Statistics
		DataCache.Settings = result.Settings or DataCache.Settings
		DataCache.DailyRewards = result.DailyRewards or DataCache.DailyRewards
	end
	
	return result
end

-- Request trade data
function ClientDataUpdater.GetTradeData(): table?
	return RemoteEvents.InvokeServer("RequestTradeData")
end

-- Request gift data
function ClientDataUpdater.GetGiftData(): table?
	return RemoteEvents.InvokeServer("RequestGiftData")
end

-- Request leaderboard data
function ClientDataUpdater.GetLeaderboard(statName: string): table?
	return RemoteEvents.InvokeServer("RequestLeaderboardData", statName)
end

--------------------------------------------------------------------------------
-- UTILITY FUNCTIONS
--------------------------------------------------------------------------------

-- Get memory info from config
function ClientDataUpdater.GetMemoryInfo(memoryId: string): table?
	return GameConfig.GetMemoryInfo(memoryId)
end

-- Get rarity name
function ClientDataUpdater.GetRarityName(rarity: number): string
	return GameConfig.GetRarityName(rarity)
end

-- Check if player can afford something
function ClientDataUpdater.CanAfford(coins: number, gems: number?): boolean
	local hasCoins = DataCache.Currency.Coins >= (coins or 0)
	local hasGems = DataCache.Currency.Gems >= (gems or 0)
	return hasCoins and hasGems
end

-- Format currency for display
function ClientDataUpdater.FormatCurrency(amount: number): string
	if amount >= 1000000 then
		return string.format("%.1fM", amount / 1000000)
	elseif amount >= 1000 then
		return string.format("%.1fK", amount / 1000)
	else
		return tostring(amount)
	end
end

--------------------------------------------------------------------------------

print("[ClientDataUpdater] Ready and waiting for profile data...")

return ClientDataUpdater
