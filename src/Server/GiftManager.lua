--[[
	GiftManager.lua
	Gifting system for Memory Rush
	
	Handles:
	- Sending gifts between players
	- Claiming pending gifts
	- Gift expiry and cleanup
	- Gift notifications
	
	Usage:
		local GiftManager = require(ServerScriptService.Server.GiftManager)
		
		-- Send a gift
		local giftId = GiftManager.CreateGift(senderId, receiverId, "meme_drake", "Happy birthday!")
		
		-- Claim a gift
		GiftManager.ClaimGift(giftId, receiverId)
		
		-- Get pending gifts
		local gifts = GiftManager.GetPendingGifts(userId)
	
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

local GiftManager = {}

-- Result codes
GiftManager.Result = {
	SUCCESS = "SUCCESS",
	GIFT_NOT_FOUND = "GIFT_NOT_FOUND",
	INVALID_GIFT = "INVALID_GIFT",
	PLAYER_NOT_FOUND = "PLAYER_NOT_FOUND",
	INSUFFICIENT_ITEMS = "INSUFFICIENT_ITEMS",
	NOT_YOUR_GIFT = "NOT_YOUR_GIFT",
	GIFT_EXPIRED = "GIFT_EXPIRED",
	MAX_GIFTS_REACHED = "MAX_GIFTS_REACHED",
	RATE_LIMITED = "RATE_LIMITED",
	DAILY_LIMIT_REACHED = "DAILY_LIMIT_REACHED",
	MESSAGE_TOO_LONG = "MESSAGE_TOO_LONG",
}

-- Track daily gift counts per player
local DailyGiftCounts = {} -- [userId] = { date: string, count: number }

--------------------------------------------------------------------------------
-- PRIVATE FUNCTIONS
--------------------------------------------------------------------------------

local function Log(level: string, message: string, giftId: string?)
	local timestamp = os.date("%Y-%m-%d %H:%M:%S")
	local giftStr = giftId and string.format(" [Gift %s]", string.sub(giftId, 1, 8)) or ""
	
	if level == "ERROR" then
		warn(string.format("[GiftManager] %s%s ERROR: %s", timestamp, giftStr, message))
	elseif level == "WARN" then
		warn(string.format("[GiftManager] %s%s WARN: %s", timestamp, giftStr, message))
	else
		print(string.format("[GiftManager] %s%s INFO: %s", timestamp, giftStr, message))
	end
end

-- Generate unique gift ID
local function GenerateGiftId(): string
	return HttpService:GenerateGUID(false)
end

-- Notify player of gift event
local function NotifyPlayer(userId: number, eventName: string, data: table)
	local player = Players:GetPlayerByUserId(userId)
	
	if player then
		RemoteEvents.FireClient(eventName, player, data)
	end
end

-- Get today's date string
local function GetTodayDate(): string
	return os.date("!%Y-%m-%d")
end

-- Check daily gift limit
local function CheckDailyLimit(userId: number): boolean
	local today = GetTodayDate()
	
	if not DailyGiftCounts[userId] then
		DailyGiftCounts[userId] = { date = today, count = 0 }
	end
	
	local tracker = DailyGiftCounts[userId]
	
	-- Reset if new day
	if tracker.date ~= today then
		tracker.date = today
		tracker.count = 0
	end
	
	return tracker.count < GameConfig.Gift.MaxGiftsPerDay
end

-- Increment daily gift count
local function IncrementDailyCount(userId: number)
	local today = GetTodayDate()
	
	if not DailyGiftCounts[userId] then
		DailyGiftCounts[userId] = { date = today, count = 0 }
	end
	
	local tracker = DailyGiftCounts[userId]
	
	if tracker.date ~= today then
		tracker.date = today
		tracker.count = 0
	end
	
	tracker.count = tracker.count + 1
end

-- Sanitize gift message
local function SanitizeMessage(message: string?): string
	if not message or type(message) ~= "string" then
		return ""
	end
	
	-- Trim and limit length
	local sanitized = string.sub(message, 1, GameConfig.Gift.MaxMessageLength)
	
	-- Remove any potentially harmful characters (basic sanitization)
	sanitized = string.gsub(sanitized, "[%c]", "") -- Remove control characters
	
	return sanitized
end

-- Count pending gifts for a player
local function CountPendingGifts(userId: number): number
	local profileData = ProfileManager.GetData(userId)
	
	if not profileData or not profileData.PendingGifts then
		return 0
	end
	
	local count = 0
	for _ in pairs(profileData.PendingGifts) do
		count = count + 1
	end
	
	return count
end

--------------------------------------------------------------------------------
-- GIFT OPERATIONS
--------------------------------------------------------------------------------

--[[
	Create and send a gift
	
	@param senderId: number - Player sending the gift
	@param receiverId: number - Player receiving the gift
	@param memoryId: string - Memory to gift
	@param message: string? - Optional gift message
	@param count: number? - Number of memories to gift (default: 1)
	@return string, string? - Result code, gift ID if successful
]]
function GiftManager.CreateGift(
	senderId: number, 
	receiverId: number, 
	memoryId: string, 
	message: string?,
	count: number?
): (string, string?)
	local giftCount = count or 1
	
	-- Check rate limit
	if not AntiCheat.CheckRateLimit(senderId, "GiftAction") then
		Log("WARN", "Rate limited on gift creation")
		return GiftManager.Result.RATE_LIMITED, nil
	end
	
	-- Validate players
	if senderId == receiverId then
		Log("WARN", "Cannot gift to yourself")
		return GiftManager.Result.INVALID_GIFT, nil
	end
	
	-- Check daily limit
	if not CheckDailyLimit(senderId) then
		Log("WARN", string.format("Daily gift limit reached for sender %d", senderId))
		return GiftManager.Result.DAILY_LIMIT_REACHED, nil
	end
	
	-- Validate memory
	if not GameConfig.IsValidMemory(memoryId) then
		Log("WARN", string.format("Invalid memory ID: %s", memoryId))
		return GiftManager.Result.INVALID_GIFT, nil
	end
	
	-- Validate count
	if type(giftCount) ~= "number" or giftCount < 1 or giftCount ~= math.floor(giftCount) then
		Log("WARN", string.format("Invalid gift count: %s", tostring(giftCount)))
		return GiftManager.Result.INVALID_GIFT, nil
	end
	
	-- Check if sender has the memory
	if not InventoryManager.HasMemory(senderId, memoryId, giftCount) then
		Log("WARN", string.format("Sender doesn't have %dx %s", giftCount, memoryId))
		return GiftManager.Result.INSUFFICIENT_ITEMS, nil
	end
	
	-- Check receiver's pending gift limit
	if CountPendingGifts(receiverId) >= GameConfig.Gift.MaxPendingGifts then
		Log("WARN", string.format("Receiver %d has max pending gifts", receiverId))
		return GiftManager.Result.MAX_GIFTS_REACHED, nil
	end
	
	-- Validate and sanitize message
	if message and #message > GameConfig.Gift.MaxMessageLength then
		return GiftManager.Result.MESSAGE_TOO_LONG, nil
	end
	
	local sanitizedMessage = SanitizeMessage(message)
	
	-- Remove memory from sender first
	local removeResult = InventoryManager.RemoveMemory(senderId, memoryId, giftCount, "gift_to_" .. receiverId)
	
	if removeResult ~= InventoryManager.Result.SUCCESS then
		Log("ERROR", string.format("Failed to remove memory from sender: %s", removeResult))
		return GiftManager.Result.INSUFFICIENT_ITEMS, nil
	end
	
	-- Create gift
	local giftId = GenerateGiftId()
	local now = os.time()
	
	local giftData = {
		FromPlayerId = senderId,
		MemoryId = memoryId,
		Count = giftCount,
		Message = sanitizedMessage,
		SentAt = now,
		Expiry = now + GameConfig.Gift.ExpiryTime,
	}
	
	-- Store in receiver's profile
	local receiverProfile = ProfileManager.GetData(receiverId)
	
	if not receiverProfile then
		-- Rollback - give memory back to sender
		Log("ERROR", "Receiver profile not found, rolling back")
		InventoryManager.AddMemory(senderId, memoryId, giftCount, "rollback_gift")
		return GiftManager.Result.PLAYER_NOT_FOUND, nil
	end
	
	if not receiverProfile.PendingGifts then
		receiverProfile.PendingGifts = {}
	end
	
	receiverProfile.PendingGifts[giftId] = giftData
	
	-- Update daily count
	IncrementDailyCount(senderId)
	
	-- Record statistics
	StatisticsManager.RecordGiftGiven(senderId)
	
	-- Log transaction
	AntiCheat.LogTransaction(senderId, AntiCheat.TransactionType.GIFT_SEND, giftCount, {
		GiftId = giftId,
		MemoryId = memoryId,
		ReceiverId = receiverId,
		Message = sanitizedMessage,
	})
	
	-- Notify receiver if online
	local senderPlayer = Players:GetPlayerByUserId(senderId)
	local senderName = senderPlayer and senderPlayer.Name or "Unknown"
	local memoryInfo = GameConfig.GetMemoryInfo(memoryId)
	local memoryName = memoryInfo and memoryInfo.Name or memoryId
	
	NotifyPlayer(receiverId, "GiftReceived", {
		GiftId = giftId,
		FromPlayerId = senderId,
		FromPlayerName = senderName,
		MemoryId = memoryId,
		MemoryName = memoryName,
		Count = giftCount,
		Message = sanitizedMessage,
		SentAt = now,
	})
	
	Log("INFO", string.format("Gift sent: %d -> %d (%dx %s)", senderId, receiverId, giftCount, memoryId), giftId)
	
	return GiftManager.Result.SUCCESS, giftId
end

--[[
	Claim a pending gift
	
	@param giftId: string - Gift ID to claim
	@param playerId: number - Player claiming the gift
	@return string - Result code
]]
function GiftManager.ClaimGift(giftId: string, playerId: number): string
	-- Check rate limit
	if not AntiCheat.CheckRateLimit(playerId, "GiftAction") then
		Log("WARN", "Rate limited on gift claim")
		return GiftManager.Result.RATE_LIMITED
	end
	
	-- Get player's profile
	local profileData = ProfileManager.GetData(playerId)
	
	if not profileData or not profileData.PendingGifts then
		Log("ERROR", "Profile not found for gift claim", giftId)
		return GiftManager.Result.PLAYER_NOT_FOUND
	end
	
	-- Find the gift
	local gift = profileData.PendingGifts[giftId]
	
	if not gift then
		Log("WARN", "Gift not found", giftId)
		return GiftManager.Result.GIFT_NOT_FOUND
	end
	
	-- Check expiry
	if gift.Expiry and gift.Expiry < os.time() then
		-- Remove expired gift
		profileData.PendingGifts[giftId] = nil
		Log("INFO", "Gift expired", giftId)
		return GiftManager.Result.GIFT_EXPIRED
	end
	
	-- Add memory to player's inventory
	local addResult = InventoryManager.AddMemory(playerId, gift.MemoryId, gift.Count or 1, "gift_from_" .. gift.FromPlayerId)
	
	if addResult ~= InventoryManager.Result.SUCCESS then
		Log("ERROR", string.format("Failed to add gift memory: %s", addResult), giftId)
		return GiftManager.Result.INVALID_GIFT
	end
	
	-- Remove gift from pending
	profileData.PendingGifts[giftId] = nil
	
	-- Record statistics
	StatisticsManager.RecordGiftReceived(playerId)
	
	-- Log transaction
	AntiCheat.LogTransaction(playerId, AntiCheat.TransactionType.GIFT_CLAIM, gift.Count or 1, {
		GiftId = giftId,
		MemoryId = gift.MemoryId,
		FromPlayerId = gift.FromPlayerId,
	})
	
	-- Notify player
	local memoryInfo = GameConfig.GetMemoryInfo(gift.MemoryId)
	local memoryName = memoryInfo and memoryInfo.Name or gift.MemoryId
	
	NotifyPlayer(playerId, "GiftClaimed", {
		GiftId = giftId,
		MemoryId = gift.MemoryId,
		MemoryName = memoryName,
		Count = gift.Count or 1,
	})
	
	Log("INFO", string.format("Gift claimed by %d (%dx %s)", playerId, gift.Count or 1, gift.MemoryId), giftId)
	
	return GiftManager.Result.SUCCESS
end

--[[
	Claim all pending gifts for a player
	
	@param playerId: number - Player claiming all gifts
	@return number, table - Count of claimed gifts, array of results
]]
function GiftManager.ClaimAllGifts(playerId: number): (number, {table})
	local profileData = ProfileManager.GetData(playerId)
	
	if not profileData or not profileData.PendingGifts then
		return 0, {}
	end
	
	local results = {}
	local claimed = 0
	
	-- Collect gift IDs first (to avoid modifying table during iteration)
	local giftIds = {}
	for giftId in pairs(profileData.PendingGifts) do
		table.insert(giftIds, giftId)
	end
	
	-- Claim each gift
	for _, giftId in ipairs(giftIds) do
		local result = GiftManager.ClaimGift(giftId, playerId)
		
		table.insert(results, {
			GiftId = giftId,
			Result = result,
		})
		
		if result == GiftManager.Result.SUCCESS then
			claimed = claimed + 1
		end
	end
	
	Log("INFO", string.format("Claimed %d/%d gifts for player %d", claimed, #giftIds, playerId))
	
	return claimed, results
end

--[[
	Delete/reject a gift without claiming
	
	@param giftId: string - Gift ID to delete
	@param playerId: number - Player deleting the gift
	@return string - Result code
]]
function GiftManager.DeleteGift(giftId: string, playerId: number): string
	local profileData = ProfileManager.GetData(playerId)
	
	if not profileData or not profileData.PendingGifts then
		return GiftManager.Result.PLAYER_NOT_FOUND
	end
	
	local gift = profileData.PendingGifts[giftId]
	
	if not gift then
		return GiftManager.Result.GIFT_NOT_FOUND
	end
	
	-- Remove the gift (item is lost)
	profileData.PendingGifts[giftId] = nil
	
	Log("INFO", string.format("Gift deleted/rejected by player %d", playerId), giftId)
	
	return GiftManager.Result.SUCCESS
end

--------------------------------------------------------------------------------
-- QUERY OPERATIONS
--------------------------------------------------------------------------------

--[[
	Get all pending gifts for a player
	
	@param userId: number - Player user ID
	@return table - Array of pending gifts
]]
function GiftManager.GetPendingGifts(userId: number): {table}
	local profileData = ProfileManager.GetData(userId)
	
	if not profileData or not profileData.PendingGifts then
		return {}
	end
	
	local result = {}
	local now = os.time()
	
	for giftId, gift in pairs(profileData.PendingGifts) do
		-- Check if expired
		if not gift.Expiry or gift.Expiry >= now then
			local senderName = "Unknown"
			local senderPlayer = Players:GetPlayerByUserId(gift.FromPlayerId)
			if senderPlayer then
				senderName = senderPlayer.Name
			end
			
			local memoryInfo = GameConfig.GetMemoryInfo(gift.MemoryId)
			
			table.insert(result, {
				GiftId = giftId,
				FromPlayerId = gift.FromPlayerId,
				FromPlayerName = senderName,
				MemoryId = gift.MemoryId,
				MemoryName = memoryInfo and memoryInfo.Name or gift.MemoryId,
				MemoryRarity = memoryInfo and memoryInfo.Rarity or 1,
				Count = gift.Count or 1,
				Message = gift.Message or "",
				SentAt = gift.SentAt,
				Expiry = gift.Expiry,
			})
		end
	end
	
	-- Sort by sent time (newest first)
	table.sort(result, function(a, b)
		return (a.SentAt or 0) > (b.SentAt or 0)
	end)
	
	return result
end

--[[
	Get pending gift count for a player
	
	@param userId: number - Player user ID
	@return number - Number of pending gifts
]]
function GiftManager.GetPendingGiftCount(userId: number): number
	return #GiftManager.GetPendingGifts(userId)
end

--[[
	Get remaining daily gift allowance
	
	@param userId: number - Player user ID
	@return number - Remaining gifts for today
]]
function GiftManager.GetRemainingDailyGifts(userId: number): number
	local today = GetTodayDate()
	local tracker = DailyGiftCounts[userId]
	
	if not tracker or tracker.date ~= today then
		return GameConfig.Gift.MaxGiftsPerDay
	end
	
	return math.max(0, GameConfig.Gift.MaxGiftsPerDay - tracker.count)
end

--------------------------------------------------------------------------------
-- CLEANUP
--------------------------------------------------------------------------------

--[[
	Clean up expired gifts for a player
	
	@param userId: number - Player user ID
	@return number - Number of gifts cleaned
]]
function GiftManager.CleanExpiredGifts(userId: number): number
	local profileData = ProfileManager.GetData(userId)
	
	if not profileData or not profileData.PendingGifts then
		return 0
	end
	
	local now = os.time()
	local expired = {}
	
	for giftId, gift in pairs(profileData.PendingGifts) do
		if gift.Expiry and gift.Expiry < now then
			table.insert(expired, giftId)
		end
	end
	
	for _, giftId in ipairs(expired) do
		profileData.PendingGifts[giftId] = nil
		
		NotifyPlayer(userId, "GiftExpired", { GiftId = giftId })
		
		Log("INFO", "Gift expired and cleaned", giftId)
	end
	
	return #expired
end

--[[
	Clean up all expired gifts for all online players
	Should be called periodically
]]
function GiftManager.CleanupAllExpiredGifts()
	local totalCleaned = 0
	
	for _, player in ipairs(Players:GetPlayers()) do
		local cleaned = GiftManager.CleanExpiredGifts(player.UserId)
		totalCleaned = totalCleaned + cleaned
	end
	
	if totalCleaned > 0 then
		Log("INFO", string.format("Cleaned up %d expired gifts globally", totalCleaned))
	end
end

-- Start cleanup loop
task.spawn(function()
	while true do
		task.wait(GameConfig.Gift.CleanupInterval)
		GiftManager.CleanupAllExpiredGifts()
	end
end)

-- Clean daily counts periodically (memory optimization)
task.spawn(function()
	while true do
		task.wait(3600) -- Every hour
		
		local today = GetTodayDate()
		
		for userId, tracker in pairs(DailyGiftCounts) do
			if tracker.date ~= today then
				DailyGiftCounts[userId] = nil
			end
		end
	end
end)

return GiftManager
