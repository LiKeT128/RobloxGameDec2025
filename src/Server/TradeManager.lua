--[[
	TradeManager.lua
	Trading system for Memory Rush
	
	Handles:
	- Creating trade offers between players
	- Validating trades (checking item ownership)
	- Completing and cancelling trades
	- Automatic cleanup of expired trades
	
	Usage:
		local TradeManager = require(ServerScriptService.Server.TradeManager)
		
		-- Create a trade offer
		local tradeId = TradeManager.CreateTradeOffer(player1Id, player2Id, offered, requested)
		
		-- Accept a trade
		TradeManager.AcceptTrade(tradeId, acceptingPlayerId)
		
		-- Cancel a trade
		TradeManager.CancelTrade(tradeId, cancellingPlayerId)
	
	Author: Memory Rush Team
	Version: 1.0.0
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")

local ProfileManager = require(script.Parent.ProfileManager)
local InventoryManager = require(script.Parent.InventoryManager)
local StatisticsManager = require(script.Parent.StatisticsManager)
local AntiCheat = require(script.Parent.AntiCheat)
local GameConfig = require(ReplicatedStorage.Shared.GameConfig)
local RemoteEvents = require(ReplicatedStorage.Shared.RemoteEvents)

--------------------------------------------------------------------------------
-- MODULE SETUP
--------------------------------------------------------------------------------

local TradeManager = {}

-- Result codes
TradeManager.Result = {
	SUCCESS = "SUCCESS",
	TRADE_NOT_FOUND = "TRADE_NOT_FOUND",
	INVALID_TRADE = "INVALID_TRADE",
	PLAYER_NOT_FOUND = "PLAYER_NOT_FOUND",
	INSUFFICIENT_ITEMS = "INSUFFICIENT_ITEMS",
	ALREADY_ACCEPTED = "ALREADY_ACCEPTED",
	NOT_YOUR_TRADE = "NOT_YOUR_TRADE",
	TRADE_EXPIRED = "TRADE_EXPIRED",
	MAX_TRADES_REACHED = "MAX_TRADES_REACHED",
	RATE_LIMITED = "RATE_LIMITED",
	PLAYER_OFFLINE = "PLAYER_OFFLINE",
}

-- Trade status
TradeManager.Status = {
	PENDING = "pending",
	ACCEPTED = "accepted",
	COMPLETED = "completed",
	CANCELLED = "cancelled",
	EXPIRED = "expired",
}

-- Active trades (stored in memory, synced to profiles)
local ActiveTrades = {} -- [tradeId] = trade data

--------------------------------------------------------------------------------
-- PRIVATE FUNCTIONS
--------------------------------------------------------------------------------

local function Log(level: string, message: string, tradeId: string?)
	local timestamp = os.date("%Y-%m-%d %H:%M:%S")
	local tradeStr = tradeId and string.format(" [Trade %s]", string.sub(tradeId, 1, 8)) or ""
	
	if level == "ERROR" then
		warn(string.format("[TradeManager] %s%s ERROR: %s", timestamp, tradeStr, message))
	elseif level == "WARN" then
		warn(string.format("[TradeManager] %s%s WARN: %s", timestamp, tradeStr, message))
	else
		print(string.format("[TradeManager] %s%s INFO: %s", timestamp, tradeStr, message))
	end
end

-- Generate unique trade ID
local function GenerateTradeId(): string
	return HttpService:GenerateGUID(false)
end

-- Notify player of trade event
local function NotifyPlayer(userId: number, eventName: string, data: table)
	local player = Players:GetPlayerByUserId(userId)
	
	if player then
		RemoteEvents.FireClient(eventName, player, data)
	end
end

-- Count memories in a trade offer
local function CountMemories(memories: { [string]: number }): number
	local count = 0
	for _, num in pairs(memories) do
		count = count + num
	end
	return count
end

-- Validate memories table structure
local function ValidateMemoriesTable(memories: table): boolean
	if type(memories) ~= "table" then
		return false
	end
	
	local uniqueCount = 0
	local totalCount = 0
	
	for memoryId, count in pairs(memories) do
		if type(memoryId) ~= "string" or type(count) ~= "number" then
			return false
		end
		
		if count < 1 or count ~= math.floor(count) then
			return false
		end
		
		if not GameConfig.IsValidMemory(memoryId) then
			return false
		end
		
		uniqueCount = uniqueCount + 1
		totalCount = totalCount + count
	end
	
	-- Check limits
	if uniqueCount > GameConfig.Trade.MaxMemoriesPerTrade then
		return false
	end
	
	if totalCount > GameConfig.Trade.MaxTotalItemsPerTrade then
		return false
	end
	
	return true
end

-- Store trade in player profiles
local function StoreTradeInProfiles(trade: table)
	local tradeData = {
		FromPlayerId = trade.FromPlayerId,
		ToPlayerId = trade.ToPlayerId,
		OfferedMemories = trade.OfferedMemories,
		RequestedMemories = trade.RequestedMemories,
		CreatedAt = trade.CreatedAt,
		Expiry = trade.Expiry,
		Status = trade.Status,
	}
	
	-- Store in initiator's profile
	local fromProfile = ProfileManager.GetData(trade.FromPlayerId)
	if fromProfile and fromProfile.PendingTrades then
		fromProfile.PendingTrades[trade.Id] = tradeData
	end
	
	-- Store in recipient's profile
	local toProfile = ProfileManager.GetData(trade.ToPlayerId)
	if toProfile and toProfile.PendingTrades then
		toProfile.PendingTrades[trade.Id] = tradeData
	end
end

-- Remove trade from player profiles
local function RemoveTradeFromProfiles(tradeId: string, player1Id: number, player2Id: number)
	local profile1 = ProfileManager.GetData(player1Id)
	if profile1 and profile1.PendingTrades then
		profile1.PendingTrades[tradeId] = nil
	end
	
	local profile2 = ProfileManager.GetData(player2Id)
	if profile2 and profile2.PendingTrades then
		profile2.PendingTrades[tradeId] = nil
	end
end

-- Count player's pending trades
local function GetPendingTradeCount(userId: number): number
	local count = 0
	
	for _, trade in pairs(ActiveTrades) do
		if trade.Status == TradeManager.Status.PENDING then
			if trade.FromPlayerId == userId or trade.ToPlayerId == userId then
				count = count + 1
			end
		end
	end
	
	return count
end

--------------------------------------------------------------------------------
-- TRADE OPERATIONS
--------------------------------------------------------------------------------

--[[
	Create a trade offer
	
	@param fromPlayerId: number - Player initiating the trade
	@param toPlayerId: number - Player receiving the trade offer
	@param offeredMemories: table - { [memoryId] = count, ... } memories being offered
	@param requestedMemories: table - { [memoryId] = count, ... } memories being requested
	@return string, string? - Result code, trade ID if successful
]]
function TradeManager.CreateTradeOffer(
	fromPlayerId: number, 
	toPlayerId: number, 
	offeredMemories: { [string]: number }, 
	requestedMemories: { [string]: number }
): (string, string?)
	-- Check rate limit
	if not AntiCheat.CheckRateLimit(fromPlayerId, "TradeAction") then
		Log("WARN", "Rate limited on trade creation", nil)
		return TradeManager.Result.RATE_LIMITED, nil
	end
	
	-- Validate players
	if fromPlayerId == toPlayerId then
		Log("WARN", "Cannot trade with yourself")
		return TradeManager.Result.INVALID_TRADE, nil
	end
	
	-- Check if recipient exists and is online
	local toPlayer = Players:GetPlayerByUserId(toPlayerId)
	if not toPlayer then
		Log("WARN", string.format("Target player %d is offline", toPlayerId))
		return TradeManager.Result.PLAYER_OFFLINE, nil
	end
	
	-- Check pending trade limits
	if GetPendingTradeCount(fromPlayerId) >= GameConfig.Trade.MaxPendingTrades then
		Log("WARN", "Max pending trades reached for sender", nil)
		return TradeManager.Result.MAX_TRADES_REACHED, nil
	end
	
	if GetPendingTradeCount(toPlayerId) >= GameConfig.Trade.MaxPendingTrades then
		Log("WARN", "Max pending trades reached for recipient", nil)
		return TradeManager.Result.MAX_TRADES_REACHED, nil
	end
	
	-- Validate memories tables
	if not ValidateMemoriesTable(offeredMemories) then
		Log("WARN", "Invalid offered memories table", nil)
		return TradeManager.Result.INVALID_TRADE, nil
	end
	
	if not ValidateMemoriesTable(requestedMemories) then
		Log("WARN", "Invalid requested memories table", nil)
		return TradeManager.Result.INVALID_TRADE, nil
	end
	
	-- Check that at least one side has items
	if next(offeredMemories) == nil and next(requestedMemories) == nil then
		Log("WARN", "Both sides of trade are empty", nil)
		return TradeManager.Result.INVALID_TRADE, nil
	end
	
	-- Verify sender has offered items
	if not InventoryManager.HasAllMemories(fromPlayerId, offeredMemories) then
		Log("WARN", "Sender doesn't have all offered items")
		return TradeManager.Result.INSUFFICIENT_ITEMS, nil
	end
	
	-- Create trade
	local tradeId = GenerateTradeId()
	local now = os.time()
	
	local trade = {
		Id = tradeId,
		FromPlayerId = fromPlayerId,
		ToPlayerId = toPlayerId,
		OfferedMemories = offeredMemories,
		RequestedMemories = requestedMemories,
		CreatedAt = now,
		Expiry = now + GameConfig.Trade.ExpiryTime,
		Status = TradeManager.Status.PENDING,
		FromAccepted = false,
		ToAccepted = false,
	}
	
	-- Store in active trades
	ActiveTrades[tradeId] = trade
	
	-- Store in profiles for persistence
	StoreTradeInProfiles(trade)
	
	-- Log transaction
	AntiCheat.LogTransaction(fromPlayerId, AntiCheat.TransactionType.TRADE_CREATE, CountMemories(offeredMemories), {
		TradeId = tradeId,
		ToPlayerId = toPlayerId,
		OfferedCount = CountMemories(offeredMemories),
		RequestedCount = CountMemories(requestedMemories),
	})
	
	-- Notify recipient
	NotifyPlayer(toPlayerId, "TradeCreated", {
		TradeId = tradeId,
		FromPlayerId = fromPlayerId,
		FromPlayerName = Players:GetPlayerByUserId(fromPlayerId) and Players:GetPlayerByUserId(fromPlayerId).Name or "Unknown",
		OfferedMemories = offeredMemories,
		RequestedMemories = requestedMemories,
		Expiry = trade.Expiry,
	})
	
	Log("INFO", string.format("Trade created: %d -> %d", fromPlayerId, toPlayerId), tradeId)
	
	return TradeManager.Result.SUCCESS, tradeId
end

--[[
	Validate that a trade is still valid (both parties have items)
	
	@param tradeId: string - Trade ID to validate
	@return string, string? - Result code, validation message
]]
function TradeManager.ValidateTrade(tradeId: string): (string, string?)
	local trade = ActiveTrades[tradeId]
	
	if not trade then
		return TradeManager.Result.TRADE_NOT_FOUND, "Trade not found"
	end
	
	-- Check expiry
	if trade.Expiry < os.time() then
		trade.Status = TradeManager.Status.EXPIRED
		return TradeManager.Result.TRADE_EXPIRED, "Trade has expired"
	end
	
	-- Check status
	if trade.Status ~= TradeManager.Status.PENDING then
		return TradeManager.Result.INVALID_TRADE, "Trade is not pending"
	end
	
	-- Check sender still has offered items
	if not InventoryManager.HasAllMemories(trade.FromPlayerId, trade.OfferedMemories) then
		return TradeManager.Result.INSUFFICIENT_ITEMS, "Sender no longer has offered items"
	end
	
	-- Check recipient has requested items
	if not InventoryManager.HasAllMemories(trade.ToPlayerId, trade.RequestedMemories) then
		return TradeManager.Result.INSUFFICIENT_ITEMS, "Recipient no longer has requested items"
	end
	
	return TradeManager.Result.SUCCESS, "Trade is valid"
end

--[[
	Accept a trade offer
	
	@param tradeId: string - Trade ID to accept
	@param acceptingPlayerId: number - Player accepting the trade
	@return string - Result code
]]
function TradeManager.AcceptTrade(tradeId: string, acceptingPlayerId: number): string
	local trade = ActiveTrades[tradeId]
	
	if not trade then
		return TradeManager.Result.TRADE_NOT_FOUND
	end
	
	-- Check if player is part of this trade
	if trade.FromPlayerId ~= acceptingPlayerId and trade.ToPlayerId ~= acceptingPlayerId then
		return TradeManager.Result.NOT_YOUR_TRADE
	end
	
	-- Validate trade
	local validResult, validMessage = TradeManager.ValidateTrade(tradeId)
	if validResult ~= TradeManager.Result.SUCCESS then
		Log("WARN", string.format("Trade validation failed: %s", validMessage or "unknown"), tradeId)
		return validResult
	end
	
	-- Mark as accepted by this player
	if acceptingPlayerId == trade.FromPlayerId then
		trade.FromAccepted = true
	else
		trade.ToAccepted = true
	end
	
	Log("INFO", string.format("Player %d accepted trade", acceptingPlayerId), tradeId)
	
	-- Check if both parties have accepted
	if trade.FromAccepted and trade.ToAccepted then
		return TradeManager.CompleteTrade(tradeId)
	end
	
	-- Notify other player
	local otherPlayerId = acceptingPlayerId == trade.FromPlayerId and trade.ToPlayerId or trade.FromPlayerId
	NotifyPlayer(otherPlayerId, "TradeUpdated", {
		TradeId = tradeId,
		AcceptedBy = acceptingPlayerId,
		Status = "waiting_for_acceptance",
	})
	
	return TradeManager.Result.SUCCESS
end

--[[
	Complete a trade (execute the item exchange)
	
	@param tradeId: string - Trade ID to complete
	@return string - Result code
]]
function TradeManager.CompleteTrade(tradeId: string): string
	local trade = ActiveTrades[tradeId]
	
	if not trade then
		return TradeManager.Result.TRADE_NOT_FOUND
	end
	
	-- Final validation
	local validResult, validMessage = TradeManager.ValidateTrade(tradeId)
	if validResult ~= TradeManager.Result.SUCCESS then
		Log("ERROR", string.format("Final validation failed: %s", validMessage or "unknown"), tradeId)
		TradeManager.CancelTrade(tradeId, 0) -- System cancel
		return validResult
	end
	
	-- Transfer offered memories (from -> to)
	for memoryId, count in pairs(trade.OfferedMemories) do
		local result = InventoryManager.TransferMemory(
			trade.FromPlayerId, 
			trade.ToPlayerId, 
			memoryId, 
			count
		)
		
		if result ~= InventoryManager.Result.SUCCESS then
			Log("ERROR", string.format("Failed to transfer %s: %s", memoryId, result), tradeId)
			-- This shouldn't happen after validation, but handle gracefully
			return TradeManager.Result.INSUFFICIENT_ITEMS
		end
	end
	
	-- Transfer requested memories (to -> from)
	for memoryId, count in pairs(trade.RequestedMemories) do
		local result = InventoryManager.TransferMemory(
			trade.ToPlayerId, 
			trade.FromPlayerId, 
			memoryId, 
			count
		)
		
		if result ~= InventoryManager.Result.SUCCESS then
			Log("ERROR", string.format("Failed to transfer %s: %s", memoryId, result), tradeId)
			-- Rollback offered memories
			for rollbackId, rollbackCount in pairs(trade.OfferedMemories) do
				InventoryManager.TransferMemory(trade.ToPlayerId, trade.FromPlayerId, rollbackId, rollbackCount)
			end
			return TradeManager.Result.INSUFFICIENT_ITEMS
		end
	end
	
	-- Mark trade as completed
	trade.Status = TradeManager.Status.COMPLETED
	
	-- Remove from profiles
	RemoveTradeFromProfiles(tradeId, trade.FromPlayerId, trade.ToPlayerId)
	
	-- Record statistics
	StatisticsManager.RecordTrade(trade.FromPlayerId, trade.ToPlayerId)
	
	-- Log transactions
	AntiCheat.LogTransaction(trade.FromPlayerId, AntiCheat.TransactionType.TRADE_COMPLETE, 
		CountMemories(trade.OfferedMemories), {
			TradeId = tradeId,
			OtherPlayer = trade.ToPlayerId,
		})
	
	AntiCheat.LogTransaction(trade.ToPlayerId, AntiCheat.TransactionType.TRADE_COMPLETE, 
		CountMemories(trade.RequestedMemories), {
			TradeId = tradeId,
			OtherPlayer = trade.FromPlayerId,
		})
	
	-- Notify both players
	NotifyPlayer(trade.FromPlayerId, "TradeCompleted", {
		TradeId = tradeId,
		ReceivedMemories = trade.RequestedMemories,
		GaveMemories = trade.OfferedMemories,
	})
	
	NotifyPlayer(trade.ToPlayerId, "TradeCompleted", {
		TradeId = tradeId,
		ReceivedMemories = trade.OfferedMemories,
		GaveMemories = trade.RequestedMemories,
	})
	
	Log("INFO", string.format("Trade completed between %d and %d", trade.FromPlayerId, trade.ToPlayerId), tradeId)
	
	-- Clean up
	task.delay(60, function()
		ActiveTrades[tradeId] = nil
	end)
	
	return TradeManager.Result.SUCCESS
end

--[[
	Cancel a trade
	
	@param tradeId: string - Trade ID to cancel
	@param cancelledBy: number - Player cancelling (0 for system)
	@return string - Result code
]]
function TradeManager.CancelTrade(tradeId: string, cancelledBy: number): string
	local trade = ActiveTrades[tradeId]
	
	if not trade then
		return TradeManager.Result.TRADE_NOT_FOUND
	end
	
	-- Check if player is part of this trade (unless system cancel)
	if cancelledBy ~= 0 then
		if trade.FromPlayerId ~= cancelledBy and trade.ToPlayerId ~= cancelledBy then
			return TradeManager.Result.NOT_YOUR_TRADE
		end
	end
	
	-- Mark as cancelled
	trade.Status = TradeManager.Status.CANCELLED
	
	-- Remove from profiles
	RemoveTradeFromProfiles(tradeId, trade.FromPlayerId, trade.ToPlayerId)
	
	-- Log
	if cancelledBy ~= 0 then
		AntiCheat.LogTransaction(cancelledBy, AntiCheat.TransactionType.TRADE_CANCEL, 0, {
			TradeId = tradeId,
		})
	end
	
	-- Notify both players
	NotifyPlayer(trade.FromPlayerId, "TradeCancelled", {
		TradeId = tradeId,
		CancelledBy = cancelledBy,
	})
	
	NotifyPlayer(trade.ToPlayerId, "TradeCancelled", {
		TradeId = tradeId,
		CancelledBy = cancelledBy,
	})
	
	Log("INFO", string.format("Trade cancelled by %d", cancelledBy), tradeId)
	
	-- Clean up
	task.delay(10, function()
		ActiveTrades[tradeId] = nil
	end)
	
	return TradeManager.Result.SUCCESS
end

--------------------------------------------------------------------------------
-- QUERY OPERATIONS
--------------------------------------------------------------------------------

--[[
	Get a specific trade
	
	@param tradeId: string - Trade ID
	@return table? - Trade data or nil
]]
function TradeManager.GetTrade(tradeId: string): table?
	return ActiveTrades[tradeId]
end

--[[
	Get all pending trades for a player
	
	@param userId: number - Player user ID
	@return table - Array of trades
]]
function TradeManager.GetPendingTrades(userId: number): {table}
	local result = {}
	
	for tradeId, trade in pairs(ActiveTrades) do
		if trade.Status == TradeManager.Status.PENDING then
			if trade.FromPlayerId == userId or trade.ToPlayerId == userId then
				table.insert(result, {
					Id = tradeId,
					FromPlayerId = trade.FromPlayerId,
					ToPlayerId = trade.ToPlayerId,
					OfferedMemories = trade.OfferedMemories,
					RequestedMemories = trade.RequestedMemories,
					CreatedAt = trade.CreatedAt,
					Expiry = trade.Expiry,
					IsIncoming = trade.ToPlayerId == userId,
					FromAccepted = trade.FromAccepted,
					ToAccepted = trade.ToAccepted,
				})
			end
		end
	end
	
	-- Sort by creation time (newest first)
	table.sort(result, function(a, b)
		return a.CreatedAt > b.CreatedAt
	end)
	
	return result
end

--[[
	Get trade history (completed/cancelled) from profile
	Note: Only for current session, as we don't persist full history
	
	@param userId: number - Player user ID
	@return table - Array of recent trades
]]
function TradeManager.GetTradeHistory(userId: number): {table}
	local result = {}
	
	for tradeId, trade in pairs(ActiveTrades) do
		if trade.Status == TradeManager.Status.COMPLETED or trade.Status == TradeManager.Status.CANCELLED then
			if trade.FromPlayerId == userId or trade.ToPlayerId == userId then
				table.insert(result, trade)
			end
		end
	end
	
	return result
end

--------------------------------------------------------------------------------
-- CLEANUP
--------------------------------------------------------------------------------

--[[
	Clean up expired trades
	Should be called periodically (e.g., every minute)
]]
function TradeManager.CleanupExpiredTrades()
	local now = os.time()
	local expired = {}
	
	for tradeId, trade in pairs(ActiveTrades) do
		if trade.Status == TradeManager.Status.PENDING and trade.Expiry < now then
			table.insert(expired, tradeId)
		end
	end
	
	for _, tradeId in ipairs(expired) do
		local trade = ActiveTrades[tradeId]
		
		if trade then
			trade.Status = TradeManager.Status.EXPIRED
			
			-- Remove from profiles
			RemoveTradeFromProfiles(tradeId, trade.FromPlayerId, trade.ToPlayerId)
			
			-- Notify players
			NotifyPlayer(trade.FromPlayerId, "TradeExpired", { TradeId = tradeId })
			NotifyPlayer(trade.ToPlayerId, "TradeExpired", { TradeId = tradeId })
			
			-- Remove from active trades
			ActiveTrades[tradeId] = nil
			
			Log("INFO", "Trade expired", tradeId)
		end
	end
	
	if #expired > 0 then
		Log("INFO", string.format("Cleaned up %d expired trades", #expired))
	end
end

-- Start cleanup loop
task.spawn(function()
	while true do
		task.wait(GameConfig.Trade.CleanupInterval)
		TradeManager.CleanupExpiredTrades()
	end
end)

-- Cancel trades when player leaves
Players.PlayerRemoving:Connect(function(player)
	local userId = player.UserId
	
	-- Cancel all pending trades involving this player
	for tradeId, trade in pairs(ActiveTrades) do
		if trade.Status == TradeManager.Status.PENDING then
			if trade.FromPlayerId == userId or trade.ToPlayerId == userId then
				TradeManager.CancelTrade(tradeId, 0) -- System cancel
			end
		end
	end
end)

return TradeManager
