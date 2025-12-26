--[[
	AntiCheat.lua
	Security and anti-cheat system for Memory Rush
	
	Handles:
	- Transaction logging for all currency/item operations
	- Anomaly detection (suspicious activity)
	- Rate limiting on API calls
	- Player flagging and ban system
	- Admin review system
	
	Usage:
		local AntiCheat = require(ServerScriptService.Server.AntiCheat)
		
		-- Log a transaction
		AntiCheat.LogTransaction(userId, "COIN_ADD", 100, { reason = "daily_bonus" })
		
		-- Check rate limit
		if AntiCheat.CheckRateLimit(userId, "CurrencyChange") then
			-- Proceed with action
		end
		
		-- Detect anomalies
		local suspicious = AntiCheat.DetectAnomalies(userId)
	
	Author: Memory Rush Team
	Version: 1.0.0
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")

local GameConfig = require(ReplicatedStorage.Shared.GameConfig)

--------------------------------------------------------------------------------
-- MODULE SETUP
--------------------------------------------------------------------------------

local AntiCheat = {}

-- Transaction types
AntiCheat.TransactionType = {
	-- Currency
	COIN_ADD = "COIN_ADD",
	COIN_REMOVE = "COIN_REMOVE",
	GEM_ADD = "GEM_ADD",
	GEM_REMOVE = "GEM_REMOVE",
	
	-- Inventory
	MEMORY_ADD = "MEMORY_ADD",
	MEMORY_REMOVE = "MEMORY_REMOVE",
	MEMORY_OPEN = "MEMORY_OPEN",
	
	-- Trading
	TRADE_CREATE = "TRADE_CREATE",
	TRADE_COMPLETE = "TRADE_COMPLETE",
	TRADE_CANCEL = "TRADE_CANCEL",
	
	-- Gifting
	GIFT_SEND = "GIFT_SEND",
	GIFT_CLAIM = "GIFT_CLAIM",
	
	-- Purchases
	PURCHASE = "PURCHASE",
	
	-- Admin
	ADMIN_ACTION = "ADMIN_ACTION",
}

-- Private state
local TransactionLog = {} -- [userId] = { transactions... }
local RateLimitState = {} -- [userId] = { [action] = { timestamps... } }
local PlayerFlags = {} -- [userId] = { flags... }
local HourlyStats = {} -- [userId] = { hourly tracking data }
local BannedPlayers = {} -- [userId] = { reason, expiry, bannedBy }

-- Constants
local MAX_LOG_SIZE = 500 -- Max transactions per player
local RATE_LIMIT_CLEANUP_INTERVAL = 60 -- Clean old rate limit data every minute

--------------------------------------------------------------------------------
-- PRIVATE FUNCTIONS
--------------------------------------------------------------------------------

local function Log(level: string, message: string, userId: number?)
	local timestamp = os.date("%Y-%m-%d %H:%M:%S")
	local userStr = userId and string.format(" [User %d]", userId) or ""
	
	if level == "ALERT" then
		warn(string.format("[AntiCheat] %s%s ALERT: %s", timestamp, userStr, message))
	elseif level == "WARN" then
		warn(string.format("[AntiCheat] %s%s WARN: %s", timestamp, userStr, message))
	else
		print(string.format("[AntiCheat] %s%s INFO: %s", timestamp, userStr, message))
	end
end

-- Generate unique transaction ID
local function GenerateTransactionId(): string
	return HttpService:GenerateGUID(false)
end

-- Get current hour key for hourly tracking
local function GetHourKey(): string
	return os.date("%Y-%m-%d-%H")
end

-- Initialize hourly stats for a player
local function InitHourlyStats(userId: number)
	local hourKey = GetHourKey()
	
	if not HourlyStats[userId] then
		HourlyStats[userId] = {}
	end
	
	if not HourlyStats[userId][hourKey] then
		HourlyStats[userId][hourKey] = {
			CoinsGained = 0,
			GemsGained = 0,
			MemoriesGained = 0,
			TradesCompleted = 0,
			TransactionCount = 0,
		}
	end
	
	-- Clean old hour data (keep only current and previous hour)
	local toRemove = {}
	for key in pairs(HourlyStats[userId]) do
		if key ~= hourKey then
			-- Check if older than 2 hours
			local cleanedKey = string.gsub(key, "-", "")
			local currentCleaned = string.gsub(hourKey, "-", "")
			if tonumber(cleanedKey) < tonumber(currentCleaned) - 1 then
				table.insert(toRemove, key)
			end
		end
	end
	
	for _, key in ipairs(toRemove) do
		HourlyStats[userId][key] = nil
	end
	
	return HourlyStats[userId][hourKey]
end

--------------------------------------------------------------------------------
-- TRANSACTION LOGGING
--------------------------------------------------------------------------------

--[[
	Log a transaction for anti-cheat tracking
	
	@param userId: number - Player user ID
	@param transactionType: string - Type of transaction (use AntiCheat.TransactionType)
	@param amount: number - Amount involved in transaction
	@param details: table? - Additional details about the transaction
	@return string - Transaction ID
]]
function AntiCheat.LogTransaction(userId: number, transactionType: string, amount: number, details: table?): string
	local transactionId = GenerateTransactionId()
	
	-- Initialize log for player if needed
	if not TransactionLog[userId] then
		TransactionLog[userId] = {}
	end
	
	-- Create transaction record
	local transaction = {
		Id = transactionId,
		Type = transactionType,
		Amount = amount,
		Timestamp = os.time(),
		Details = details or {},
	}
	
	-- Add to log
	table.insert(TransactionLog[userId], transaction)
	
	-- Trim log if too large
	while #TransactionLog[userId] > MAX_LOG_SIZE do
		table.remove(TransactionLog[userId], 1)
	end
	
	-- Update hourly stats
	local hourlyStats = InitHourlyStats(userId)
	hourlyStats.TransactionCount = hourlyStats.TransactionCount + 1
	
	if transactionType == AntiCheat.TransactionType.COIN_ADD then
		hourlyStats.CoinsGained = hourlyStats.CoinsGained + amount
	elseif transactionType == AntiCheat.TransactionType.GEM_ADD then
		hourlyStats.GemsGained = hourlyStats.GemsGained + amount
	elseif transactionType == AntiCheat.TransactionType.MEMORY_ADD then
		hourlyStats.MemoriesGained = hourlyStats.MemoriesGained + amount
	elseif transactionType == AntiCheat.TransactionType.TRADE_COMPLETE then
		hourlyStats.TradesCompleted = hourlyStats.TradesCompleted + 1
	end
	
	-- Check for anomalies after transaction
	task.spawn(function()
		local anomalies = AntiCheat.DetectAnomalies(userId)
		if #anomalies > 0 then
			for _, anomaly in ipairs(anomalies) do
				AntiCheat.FlagSuspiciousActivity(userId, anomaly)
			end
		end
	end)
	
	return transactionId
end

--[[
	Get transaction log for a player
	
	@param userId: number - Player user ID
	@param limit: number? - Max transactions to return (default: 50)
	@return table - Array of transactions
]]
function AntiCheat.GetTransactionLog(userId: number, limit: number?): {table}
	local log = TransactionLog[userId] or {}
	local maxEntries = limit or 50
	
	-- Return most recent transactions
	local result = {}
	local startIdx = math.max(1, #log - maxEntries + 1)
	
	for i = startIdx, #log do
		table.insert(result, log[i])
	end
	
	return result
end

--[[
	Get transactions of a specific type
	
	@param userId: number - Player user ID
	@param transactionType: string - Type to filter by
	@param timeRange: number? - Only include transactions from last N seconds
	@return table - Filtered transactions
]]
function AntiCheat.GetTransactionsByType(userId: number, transactionType: string, timeRange: number?): {table}
	local log = TransactionLog[userId] or {}
	local result = {}
	local now = os.time()
	local cutoff = timeRange and (now - timeRange) or 0
	
	for _, transaction in ipairs(log) do
		if transaction.Type == transactionType and transaction.Timestamp >= cutoff then
			table.insert(result, transaction)
		end
	end
	
	return result
end

--------------------------------------------------------------------------------
-- ANOMALY DETECTION
--------------------------------------------------------------------------------

--[[
	Detect anomalies in player activity
	
	@param userId: number - Player user ID
	@return table - Array of anomaly descriptions
]]
function AntiCheat.DetectAnomalies(userId: number): {string}
	local anomalies = {}
	local thresholds = GameConfig.AntiCheat
	
	-- Initialize hourly stats
	local hourlyStats = InitHourlyStats(userId)
	
	-- Check coin gain rate
	if hourlyStats.CoinsGained > thresholds.MaxCoinGainPerHour then
		table.insert(anomalies, string.format(
			"Excessive coin gain: %d coins in 1 hour (limit: %d)",
			hourlyStats.CoinsGained, thresholds.MaxCoinGainPerHour
		))
	end
	
	-- Check gem gain rate (gems should only come from purchases)
	if hourlyStats.GemsGained > thresholds.MaxGemGainPerHour then
		table.insert(anomalies, string.format(
			"Suspicious gem gain: %d gems in 1 hour (limit: %d)",
			hourlyStats.GemsGained, thresholds.MaxGemGainPerHour
		))
	end
	
	-- Check memory gain rate
	if hourlyStats.MemoriesGained > thresholds.MaxMemoriesGainedPerHour then
		table.insert(anomalies, string.format(
			"Excessive memory gain: %d memories in 1 hour (limit: %d)",
			hourlyStats.MemoriesGained, thresholds.MaxMemoriesGainedPerHour
		))
	end
	
	-- Check trade rate
	if hourlyStats.TradesCompleted > thresholds.MaxTradesPerHour then
		table.insert(anomalies, string.format(
			"Excessive trading: %d trades in 1 hour (limit: %d)",
			hourlyStats.TradesCompleted, thresholds.MaxTradesPerHour
		))
	end
	
	-- Check for suspiciously fast transactions
	local recentTransactions = AntiCheat.GetTransactionsByType(userId, "", 10) -- Last 10 seconds
	if #recentTransactions > 100 then
		table.insert(anomalies, string.format(
			"Transaction flooding: %d transactions in 10 seconds",
			#recentTransactions
		))
	end
	
	return anomalies
end

--[[
	Flag a player for suspicious activity
	
	@param userId: number - Player user ID
	@param reason: string - Reason for the flag
]]
function AntiCheat.FlagSuspiciousActivity(userId: number, reason: string)
	Log("ALERT", reason, userId)
	
	-- Initialize flags for player
	if not PlayerFlags[userId] then
		PlayerFlags[userId] = {
			Flags = {},
			TotalFlags = 0,
			LastFlagTime = 0,
		}
	end
	
	local playerData = PlayerFlags[userId]
	
	-- Add flag
	table.insert(playerData.Flags, {
		Reason = reason,
		Timestamp = os.time(),
	})
	
	playerData.TotalFlags = playerData.TotalFlags + 1
	playerData.LastFlagTime = os.time()
	
	-- Check if player should be warned/banned
	local warningThreshold = GameConfig.AntiCheat.WarningsBeforeBan
	
	if playerData.TotalFlags >= warningThreshold then
		Log("ALERT", string.format(
			"Player has %d flags - consider investigating/banning",
			playerData.TotalFlags
		), userId)
	end
	
	-- Trim old flags (keep last 100)
	while #playerData.Flags > 100 do
		table.remove(playerData.Flags, 1)
	end
end

--[[
	Get player flags
	
	@param userId: number - Player user ID
	@return table - Player flag data
]]
function AntiCheat.GetPlayerFlags(userId: number): table
	return PlayerFlags[userId] or {
		Flags = {},
		TotalFlags = 0,
		LastFlagTime = 0,
	}
end

--[[
	Clear player flags (admin action)
	
	@param userId: number - Player user ID
	@param adminId: number - Admin performing the action
]]
function AntiCheat.ClearPlayerFlags(userId: number, adminId: number)
	PlayerFlags[userId] = nil
	
	AntiCheat.LogTransaction(userId, AntiCheat.TransactionType.ADMIN_ACTION, 0, {
		Action = "ClearFlags",
		AdminId = adminId,
	})
	
	Log("INFO", string.format("Flags cleared by admin %d", adminId), userId)
end

--------------------------------------------------------------------------------
-- RATE LIMITING
--------------------------------------------------------------------------------

--[[
	Check if an action is within rate limits
	
	@param userId: number - Player user ID
	@param action: string - Action type (key from GameConfig.RateLimits)
	@return boolean - True if action is allowed
]]
function AntiCheat.CheckRateLimit(userId: number, action: string): boolean
	local limitConfig = GameConfig.RateLimits[action]
	
	if not limitConfig then
		-- No limit configured for this action
		return true
	end
	
	local maxRequests = limitConfig.MaxRequests
	local timeWindow = limitConfig.TimeWindow
	
	-- Initialize rate limit state
	if not RateLimitState[userId] then
		RateLimitState[userId] = {}
	end
	
	if not RateLimitState[userId][action] then
		RateLimitState[userId][action] = {}
	end
	
	local timestamps = RateLimitState[userId][action]
	local now = os.time()
	local cutoff = now - timeWindow
	
	-- Remove old timestamps
	local newTimestamps = {}
	for _, timestamp in ipairs(timestamps) do
		if timestamp > cutoff then
			table.insert(newTimestamps, timestamp)
		end
	end
	
	RateLimitState[userId][action] = newTimestamps
	
	-- Check limit
	if #newTimestamps >= maxRequests then
		Log("WARN", string.format(
			"Rate limit exceeded for action '%s': %d/%d in %d seconds",
			action, #newTimestamps, maxRequests, timeWindow
		), userId)
		return false
	end
	
	-- Add current timestamp
	table.insert(RateLimitState[userId][action], now)
	
	return true
end

--[[
	Get current rate limit status for an action
	
	@param userId: number - Player user ID
	@param action: string - Action type
	@return table - { current: number, max: number, resetIn: number }
]]
function AntiCheat.GetRateLimitStatus(userId: number, action: string): table
	local limitConfig = GameConfig.RateLimits[action]
	
	if not limitConfig then
		return { current = 0, max = 999, resetIn = 0 }
	end
	
	local timestamps = RateLimitState[userId] and RateLimitState[userId][action] or {}
	local now = os.time()
	local cutoff = now - limitConfig.TimeWindow
	
	-- Count recent requests
	local current = 0
	local oldestInWindow = now
	
	for _, timestamp in ipairs(timestamps) do
		if timestamp > cutoff then
			current = current + 1
			if timestamp < oldestInWindow then
				oldestInWindow = timestamp
			end
		end
	end
	
	local resetIn = 0
	if current >= limitConfig.MaxRequests then
		resetIn = math.max(0, oldestInWindow + limitConfig.TimeWindow - now)
	end
	
	return {
		current = current,
		max = limitConfig.MaxRequests,
		resetIn = resetIn,
	}
end

--------------------------------------------------------------------------------
-- BAN SYSTEM
--------------------------------------------------------------------------------

--[[
	Ban a player
	
	@param userId: number - Player user ID to ban
	@param reason: string - Ban reason
	@param duration: number? - Ban duration in seconds (nil = permanent)
	@param adminId: number - Admin performing the ban
]]
function AntiCheat.BanPlayer(userId: number, reason: string, duration: number?, adminId: number)
	local expiry = duration and (os.time() + duration) or 0
	
	BannedPlayers[userId] = {
		Reason = reason,
		Expiry = expiry,
		BannedBy = adminId,
		BannedAt = os.time(),
	}
	
	AntiCheat.LogTransaction(userId, AntiCheat.TransactionType.ADMIN_ACTION, 0, {
		Action = "Ban",
		Reason = reason,
		Duration = duration,
		AdminId = adminId,
	})
	
	Log("ALERT", string.format(
		"BANNED by admin %d - Reason: %s - Duration: %s",
		adminId, reason, duration and (duration .. "s") or "permanent"
	), userId)
	
	-- Kick player if online
	local player = Players:GetPlayerByUserId(userId)
	if player then
		player:Kick("You have been banned: " .. reason)
	end
end

--[[
	Unban a player
	
	@param userId: number - Player user ID to unban
	@param adminId: number - Admin performing the unban
	@return boolean - True if player was unbanned
]]
function AntiCheat.UnbanPlayer(userId: number, adminId: number): boolean
	if not BannedPlayers[userId] then
		return false
	end
	
	BannedPlayers[userId] = nil
	
	AntiCheat.LogTransaction(userId, AntiCheat.TransactionType.ADMIN_ACTION, 0, {
		Action = "Unban",
		AdminId = adminId,
	})
	
	Log("INFO", string.format("Unbanned by admin %d", adminId), userId)
	
	return true
end

--[[
	Check if a player is banned
	
	@param userId: number - Player user ID
	@return boolean, string? - Is banned, ban reason
]]
function AntiCheat.IsBanned(userId: number): (boolean, string?)
	local banData = BannedPlayers[userId]
	
	if not banData then
		return false, nil
	end
	
	-- Check if ban has expired
	if banData.Expiry > 0 and banData.Expiry < os.time() then
		BannedPlayers[userId] = nil
		return false, nil
	end
	
	return true, banData.Reason
end

--[[
	Get ban info for a player
	
	@param userId: number - Player user ID
	@return table? - Ban data or nil if not banned
]]
function AntiCheat.GetBanInfo(userId: number): table?
	local banData = BannedPlayers[userId]
	
	if not banData then
		return nil
	end
	
	-- Check expiry
	if banData.Expiry > 0 and banData.Expiry < os.time() then
		BannedPlayers[userId] = nil
		return nil
	end
	
	return {
		Reason = banData.Reason,
		Expiry = banData.Expiry,
		BannedBy = banData.BannedBy,
		BannedAt = banData.BannedAt,
		Remaining = banData.Expiry > 0 and (banData.Expiry - os.time()) or -1,
	}
end

--------------------------------------------------------------------------------
-- ADMIN FUNCTIONS
--------------------------------------------------------------------------------

--[[
	Get summary of all flagged players
	
	@return table - Array of flagged player summaries
]]
function AntiCheat.GetFlaggedPlayersSummary(): {table}
	local result = {}
	
	for userId, data in pairs(PlayerFlags) do
		if data.TotalFlags > 0 then
			table.insert(result, {
				UserId = userId,
				TotalFlags = data.TotalFlags,
				LastFlagTime = data.LastFlagTime,
				RecentFlags = #data.Flags,
			})
		end
	end
	
	-- Sort by total flags (descending)
	table.sort(result, function(a, b)
		return a.TotalFlags > b.TotalFlags
	end)
	
	return result
end

--[[
	Get summary of all banned players
	
	@return table - Array of banned player data
]]
function AntiCheat.GetAllBannedPlayers(): {table}
	local result = {}
	
	for userId, data in pairs(BannedPlayers) do
		-- Skip expired bans
		if data.Expiry == 0 or data.Expiry > os.time() then
			table.insert(result, {
				UserId = userId,
				Reason = data.Reason,
				Expiry = data.Expiry,
				BannedBy = data.BannedBy,
				BannedAt = data.BannedAt,
			})
		end
	end
	
	return result
end

--[[
	Generate player security report
	
	@param userId: number - Player user ID
	@return table - Detailed security report
]]
function AntiCheat.GenerateSecurityReport(userId: number): table
	local flags = AntiCheat.GetPlayerFlags(userId)
	local banInfo = AntiCheat.GetBanInfo(userId)
	local recentTransactions = AntiCheat.GetTransactionLog(userId, 20)
	local hourlyStats = InitHourlyStats(userId)
	
	return {
		UserId = userId,
		GeneratedAt = os.time(),
		BanStatus = banInfo,
		Flags = {
			Total = flags.TotalFlags,
			Recent = flags.Flags,
			LastFlagTime = flags.LastFlagTime,
		},
		HourlyStats = hourlyStats,
		RecentTransactions = recentTransactions,
		Anomalies = AntiCheat.DetectAnomalies(userId),
	}
end

--------------------------------------------------------------------------------
-- CLEANUP
--------------------------------------------------------------------------------

-- Periodic cleanup of old rate limit data
task.spawn(function()
	while true do
		task.wait(RATE_LIMIT_CLEANUP_INTERVAL)
		
		local now = os.time()
		
		for userId, actions in pairs(RateLimitState) do
			for action, timestamps in pairs(actions) do
				local limitConfig = GameConfig.RateLimits[action]
				if limitConfig then
					local cutoff = now - limitConfig.TimeWindow
					local newTimestamps = {}
					
					for _, timestamp in ipairs(timestamps) do
						if timestamp > cutoff then
							table.insert(newTimestamps, timestamp)
						end
					end
					
					RateLimitState[userId][action] = newTimestamps
				end
			end
		end
	end
end)

-- Clean up when players leave
Players.PlayerRemoving:Connect(function(player)
	local userId = player.UserId
	
	-- Keep flags and ban data (persistent across sessions)
	-- Clear transient data
	task.delay(60, function()
		RateLimitState[userId] = nil
		TransactionLog[userId] = nil
		HourlyStats[userId] = nil
	end)
end)

return AntiCheat
