--[[
	StatisticsManager.lua
	Player statistics tracking for Memory Rush
	
	Handles:
	- Recording gameplay events (memory opens, trades, gifts)
	- Session tracking
	- Leaderboard data preparation
	- Achievement progress tracking
	
	Usage:
		local StatisticsManager = require(ServerScriptService.Server.StatisticsManager)
		
		-- Record a memory open
		StatisticsManager.RecordMemoryOpen(userId)
		
		-- Record a trade
		StatisticsManager.RecordTrade(userId1, userId2)
		
		-- Get player stats
		local stats = StatisticsManager.GetPlayerStats(userId)
	
	Author: Memory Rush Team
	Version: 1.0.0
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local ProfileManager = require(script.Parent.ProfileManager)
local GameConfig = require(ReplicatedStorage.Shared.GameConfig)
local RemoteEvents = require(ReplicatedStorage.Shared.RemoteEvents)

--------------------------------------------------------------------------------
-- MODULE SETUP
--------------------------------------------------------------------------------

local StatisticsManager = {}

-- Session tracking
local SessionData = {} -- [userId] = { StartTime, LastActivity }

--------------------------------------------------------------------------------
-- PRIVATE FUNCTIONS
--------------------------------------------------------------------------------

local function Log(level: string, message: string, userId: number?)
	local timestamp = os.date("%Y-%m-%d %H:%M:%S")
	local userStr = userId and string.format(" [User %d]", userId) or ""
	
	if level == "ERROR" then
		warn(string.format("[StatisticsManager] %s%s ERROR: %s", timestamp, userStr, message))
	else
		print(string.format("[StatisticsManager] %s%s INFO: %s", timestamp, userStr, message))
	end
end

-- Notify client of stats update
local function NotifyClient(userId: number, stats: table)
	local player = Players:GetPlayerByUserId(userId)
	
	if player then
		RemoteEvents.FireClient("StatisticsUpdated", player, stats)
	end
end

-- Get or create session data
local function GetSessionData(userId: number): table
	if not SessionData[userId] then
		SessionData[userId] = {
			StartTime = os.time(),
			LastActivity = os.time(),
		}
	end
	
	return SessionData[userId]
end

-- Update last activity time
local function UpdateActivity(userId: number)
	local session = GetSessionData(userId)
	session.LastActivity = os.time()
end

--------------------------------------------------------------------------------
-- SESSION TRACKING
--------------------------------------------------------------------------------

--[[
	Start a session for a player (called when they join)
	
	@param userId: number - Player user ID
]]
function StatisticsManager.StartSession(userId: number)
	local session = GetSessionData(userId)
	session.StartTime = os.time()
	session.LastActivity = os.time()
	
	-- Increment session count in profile
	local profileData = ProfileManager.GetData(userId)
	
	if profileData and profileData.Statistics then
		profileData.Statistics.SessionCount = (profileData.Statistics.SessionCount or 0) + 1
		
		-- Set first join time if not set
		if not profileData.Statistics.FirstJoinTime or profileData.Statistics.FirstJoinTime == 0 then
			profileData.Statistics.FirstJoinTime = os.time()
		end
	end
	
	Log("INFO", "Session started", userId)
end

--[[
	End a session for a player (called when they leave)
	
	@param userId: number - Player user ID
]]
function StatisticsManager.EndSession(userId: number)
	local session = SessionData[userId]
	
	if session then
		-- Calculate session duration
		local duration = os.time() - session.StartTime
		
		-- Update total play time
		local profileData = ProfileManager.GetData(userId)
		
		if profileData and profileData.Statistics then
			profileData.Statistics.TotalPlayTime = (profileData.Statistics.TotalPlayTime or 0) + duration
		end
		
		Log("INFO", string.format("Session ended - Duration: %d seconds", duration), userId)
		
		-- Clean up session data
		SessionData[userId] = nil
	end
end

--[[
	Get current session duration
	
	@param userId: number - Player user ID
	@return number - Session duration in seconds
]]
function StatisticsManager.GetSessionDuration(userId: number): number
	local session = SessionData[userId]
	
	if session then
		return os.time() - session.StartTime
	end
	
	return 0
end

--------------------------------------------------------------------------------
-- STAT RECORDING
--------------------------------------------------------------------------------

--[[
	Record a memory open event
	
	@param userId: number - Player user ID
	@param memoryId: string? - Memory ID that was opened
]]
function StatisticsManager.RecordMemoryOpen(userId: number, memoryId: string?)
	local profileData = ProfileManager.GetData(userId)
	
	if not profileData or not profileData.Statistics then
		Log("ERROR", "Profile not found for recording memory open", userId)
		return
	end
	
	-- Update stats
	profileData.Statistics.MemoriesOpened = (profileData.Statistics.MemoriesOpened or 0) + 1
	profileData.Statistics.LastMemoryOpenTime = os.time()
	
	UpdateActivity(userId)
	
	-- Notify client periodically (every 10 opens to reduce network traffic)
	if profileData.Statistics.MemoriesOpened % 10 == 0 then
		NotifyClient(userId, profileData.Statistics)
	end
end

--[[
	Record first-time collection of a unique memory
	
	@param userId: number - Player user ID
	@param memoryId: string - Memory ID collected
]]
function StatisticsManager.RecordUniqueMemory(userId: number, memoryId: string)
	local profileData = ProfileManager.GetData(userId)
	
	if not profileData or not profileData.Statistics then
		Log("ERROR", "Profile not found for recording unique memory", userId)
		return
	end
	
	profileData.Statistics.MemoriesUniqueCollected = (profileData.Statistics.MemoriesUniqueCollected or 0) + 1
	
	UpdateActivity(userId)
	NotifyClient(userId, profileData.Statistics)
	
	Log("INFO", string.format("New unique memory collected: %s", memoryId), userId)
end

--[[
	Record a completed trade
	
	@param player1Id: number - First player in trade
	@param player2Id: number - Second player in trade
]]
function StatisticsManager.RecordTrade(player1Id: number, player2Id: number)
	-- Update both players
	for _, userId in ipairs({player1Id, player2Id}) do
		local profileData = ProfileManager.GetData(userId)
		
		if profileData and profileData.Statistics then
			profileData.Statistics.TradesCompleted = (profileData.Statistics.TradesCompleted or 0) + 1
			UpdateActivity(userId)
			NotifyClient(userId, profileData.Statistics)
		end
	end
	
	Log("INFO", string.format("Trade recorded between %d and %d", player1Id, player2Id))
end

--[[
	Record a gift sent
	
	@param senderId: number - Player who sent the gift
	@param receiverId: number - Player who received the gift
	@param memoryId: string - Memory that was gifted
]]
function StatisticsManager.RecordGift(senderId: number, receiverId: number, memoryId: string)
	-- Update sender stats
	local senderData = ProfileManager.GetData(senderId)
	
	if senderData and senderData.Statistics then
		senderData.Statistics.GiftsGiven = (senderData.Statistics.GiftsGiven or 0) + 1
		UpdateActivity(senderId)
		NotifyClient(senderId, senderData.Statistics)
	end
	
	-- Update receiver stats
	local receiverData = ProfileManager.GetData(receiverId)
	
	if receiverData and receiverData.Statistics then
		receiverData.Statistics.GiftsReceived = (receiverData.Statistics.GiftsReceived or 0) + 1
		UpdateActivity(receiverId)
		NotifyClient(receiverId, receiverData.Statistics)
	end
	
	Log("INFO", string.format("Gift recorded: %d -> %d (%s)", senderId, receiverId, memoryId))
end

--[[
	Record a gift given
	
	@param senderId: number - Player who sent the gift
]]
function StatisticsManager.RecordGiftGiven(senderId: number)
	local profileData = ProfileManager.GetData(senderId)
	
	if profileData and profileData.Statistics then
		profileData.Statistics.GiftsGiven = (profileData.Statistics.GiftsGiven or 0) + 1
		UpdateActivity(senderId)
	end
end

--[[
	Record a gift received
	
	@param receiverId: number - Player who received the gift
]]
function StatisticsManager.RecordGiftReceived(receiverId: number)
	local profileData = ProfileManager.GetData(receiverId)
	
	if profileData and profileData.Statistics then
		profileData.Statistics.GiftsReceived = (profileData.Statistics.GiftsReceived or 0) + 1
		UpdateActivity(receiverId)
		NotifyClient(receiverId, profileData.Statistics)
	end
end

--------------------------------------------------------------------------------
-- STAT RETRIEVAL
--------------------------------------------------------------------------------

--[[
	Get all statistics for a player
	
	@param userId: number - Player user ID
	@return table? - Statistics table or nil
]]
function StatisticsManager.GetPlayerStats(userId: number): table?
	local profileData = ProfileManager.GetData(userId)
	
	if not profileData or not profileData.Statistics then
		return nil
	end
	
	-- Return a copy with current session info
	local stats = {}
	
	for key, value in pairs(profileData.Statistics) do
		stats[key] = value
	end
	
	-- Add current session duration
	stats.CurrentSessionDuration = StatisticsManager.GetSessionDuration(userId)
	
	return stats
end

--[[
	Get a specific statistic
	
	@param userId: number - Player user ID
	@param statName: string - Name of the statistic
	@return number - Value of the statistic (0 if not found)
]]
function StatisticsManager.GetStat(userId: number, statName: string): number
	local profileData = ProfileManager.GetData(userId)
	
	if not profileData or not profileData.Statistics then
		return 0
	end
	
	return profileData.Statistics[statName] or 0
end

--[[
	Increment a custom statistic
	
	@param userId: number - Player user ID
	@param statName: string - Name of the statistic
	@param amount: number? - Amount to increment (default: 1)
]]
function StatisticsManager.IncrementStat(userId: number, statName: string, amount: number?)
	local increment = amount or 1
	
	local profileData = ProfileManager.GetData(userId)
	
	if not profileData or not profileData.Statistics then
		return
	end
	
	profileData.Statistics[statName] = (profileData.Statistics[statName] or 0) + increment
	UpdateActivity(userId)
end

--------------------------------------------------------------------------------
-- LEADERBOARD DATA
--------------------------------------------------------------------------------

--[[
	Get leaderboard data for a specific stat
	
	@param statName: string - Name of the statistic
	@param limit: number? - Max entries (default: 10)
	@return table - Array of { UserId, Value, Name }
]]
function StatisticsManager.GetLeaderboard(statName: string, limit: number?): {table}
	local maxEntries = limit or 10
	local entries = {}
	
	-- Get all online players' stats
	for _, player in ipairs(Players:GetPlayers()) do
		local stats = StatisticsManager.GetPlayerStats(player.UserId)
		
		if stats and stats[statName] then
			table.insert(entries, {
				UserId = player.UserId,
				Value = stats[statName],
				Name = player.Name,
			})
		end
	end
	
	-- Sort by value (descending)
	table.sort(entries, function(a, b)
		return a.Value > b.Value
	end)
	
	-- Limit results
	local result = {}
	for i = 1, math.min(#entries, maxEntries) do
		table.insert(result, entries[i])
	end
	
	return result
end

--[[
	Get player rank for a specific stat
	
	@param userId: number - Player user ID
	@param statName: string - Name of the statistic
	@return number? - Rank (1-based) or nil if not found
]]
function StatisticsManager.GetPlayerRank(userId: number, statName: string): number?
	local leaderboard = StatisticsManager.GetLeaderboard(statName, 100)
	
	for rank, entry in ipairs(leaderboard) do
		if entry.UserId == userId then
			return rank
		end
	end
	
	return nil
end

--------------------------------------------------------------------------------
-- DAILY REWARDS
--------------------------------------------------------------------------------

--[[
	Check if player can claim daily reward
	
	@param userId: number - Player user ID
	@return boolean, number - Can claim, current streak
]]
function StatisticsManager.CanClaimDailyReward(userId: number): (boolean, number)
	local profileData = ProfileManager.GetData(userId)
	
	if not profileData or not profileData.DailyRewards then
		return false, 0
	end
	
	local daily = profileData.DailyRewards
	local now = os.time()
	local resetHour = GameConfig.DailyRewards.ResetHourUTC
	
	-- Calculate today's reset time (midnight UTC + reset hour)
	local todayReset = os.time({
		year = os.date("!*t", now).year,
		month = os.date("!*t", now).month,
		day = os.date("!*t", now).day,
		hour = resetHour,
		min = 0,
		sec = 0,
	})
	
	-- If we haven't reached today's reset, use yesterday's
	if now < todayReset then
		todayReset = todayReset - 86400
	end
	
	-- Check if already claimed today
	local lastClaim = daily.LastClaimDate or 0
	
	if lastClaim >= todayReset then
		return false, daily.CurrentStreak or 0
	end
	
	return true, daily.CurrentStreak or 0
end

--[[
	Claim daily reward
	
	@param userId: number - Player user ID
	@return boolean, table? - Success, reward data
]]
function StatisticsManager.ClaimDailyReward(userId: number): (boolean, table?)
	local canClaim, currentStreak = StatisticsManager.CanClaimDailyReward(userId)
	
	if not canClaim then
		return false, nil
	end
	
	local profileData = ProfileManager.GetData(userId)
	
	if not profileData or not profileData.DailyRewards then
		return false, nil
	end
	
	local daily = profileData.DailyRewards
	local now = os.time()
	
	-- Calculate new streak
	local lastClaim = daily.LastClaimDate or 0
	local hoursSinceLastClaim = (now - lastClaim) / 3600
	local streakMaxHours = GameConfig.DailyRewards.StreakResetHours
	
	local newStreak
	if hoursSinceLastClaim > streakMaxHours then
		-- Streak broken
		newStreak = 1
	else
		-- Continue streak
		newStreak = math.min((currentStreak or 0) + 1, GameConfig.DailyRewards.MaxStreak)
	end
	
	-- Get reward for this day
	local rewardDay = ((newStreak - 1) % 7) + 1 -- 1-7 cycle
	local reward = GameConfig.DailyRewards.Rewards[rewardDay] or { Coins = 100, Gems = 0 }
	
	-- Update daily rewards data
	daily.LastClaimDate = now
	daily.CurrentStreak = newStreak
	daily.TotalClaims = (daily.TotalClaims or 0) + 1
	daily.HighestStreak = math.max(daily.HighestStreak or 0, newStreak)
	
	-- The currency should be added by the caller
	local rewardData = {
		Day = rewardDay,
		Streak = newStreak,
		Coins = reward.Coins,
		Gems = reward.Gems,
		TotalClaims = daily.TotalClaims,
		HighestStreak = daily.HighestStreak,
	}
	
	Log("INFO", string.format("Daily reward claimed - Day %d, Streak %d", rewardDay, newStreak), userId)
	
	return true, rewardData
end

--[[
	Get daily reward info
	
	@param userId: number - Player user ID
	@return table - Daily reward info
]]
function StatisticsManager.GetDailyRewardInfo(userId: number): table
	local profileData = ProfileManager.GetData(userId)
	
	if not profileData or not profileData.DailyRewards then
		return {
			CanClaim = true,
			CurrentStreak = 0,
			NextReward = GameConfig.DailyRewards.Rewards[1],
			HighestStreak = 0,
			TotalClaims = 0,
		}
	end
	
	local canClaim, streak = StatisticsManager.CanClaimDailyReward(userId)
	local nextDay = canClaim and (((streak) % 7) + 1) or ((streak % 7) + 1)
	
	return {
		CanClaim = canClaim,
		CurrentStreak = streak,
		NextReward = GameConfig.DailyRewards.Rewards[nextDay],
		NextDay = nextDay,
		HighestStreak = profileData.DailyRewards.HighestStreak or 0,
		TotalClaims = profileData.DailyRewards.TotalClaims or 0,
		LastClaimDate = profileData.DailyRewards.LastClaimDate or 0,
	}
end

--------------------------------------------------------------------------------
-- CLEANUP
--------------------------------------------------------------------------------

-- Auto end sessions when players leave
Players.PlayerRemoving:Connect(function(player)
	StatisticsManager.EndSession(player.UserId)
end)

return StatisticsManager
