--[[
	CurrencyManager.lua
	Currency management system for Memory Rush
	
	Handles:
	- Coin operations (add, remove, check balance)
	- Gem operations (premium currency)
	- Transaction logging for anti-cheat
	- Client notifications for UI updates
	
	Usage:
		local CurrencyManager = require(ServerScriptService.Server.CurrencyManager)
		
		-- Add coins to player
		local success = CurrencyManager.AddCoins(userId, 100, "daily_bonus")
		
		-- Check if player can afford
		if CurrencyManager.CanAfford(userId, 50, 0) then
			CurrencyManager.RemoveCoins(userId, 50, "purchase_item")
		end
	
	Author: Memory Rush Team
	Version: 1.0.0
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local ProfileManager = require(script.Parent.ProfileManager)
local AntiCheat = require(script.Parent.AntiCheat)
local GameConfig = require(ReplicatedStorage.Shared.GameConfig)
local RemoteEvents = require(ReplicatedStorage.Shared.RemoteEvents)

--------------------------------------------------------------------------------
-- MODULE SETUP
--------------------------------------------------------------------------------

local CurrencyManager = {}

-- Result codes
CurrencyManager.Result = {
	SUCCESS = "SUCCESS",
	INSUFFICIENT_FUNDS = "INSUFFICIENT_FUNDS",
	INVALID_AMOUNT = "INVALID_AMOUNT",
	PROFILE_NOT_FOUND = "PROFILE_NOT_FOUND",
	RATE_LIMITED = "RATE_LIMITED",
	MAX_EXCEEDED = "MAX_EXCEEDED",
}

--------------------------------------------------------------------------------
-- PRIVATE FUNCTIONS
--------------------------------------------------------------------------------

local function Log(level: string, message: string, userId: number?)
	local timestamp = os.date("%Y-%m-%d %H:%M:%S")
	local userStr = userId and string.format(" [User %d]", userId) or ""
	
	if level == "ERROR" then
		warn(string.format("[CurrencyManager] %s%s ERROR: %s", timestamp, userStr, message))
	elseif level == "WARN" then
		warn(string.format("[CurrencyManager] %s%s WARN: %s", timestamp, userStr, message))
	else
		print(string.format("[CurrencyManager] %s%s INFO: %s", timestamp, userStr, message))
	end
end

-- Notify client of currency change
local function NotifyClient(userId: number, currencyType: string, newAmount: number, change: number, reason: string?)
	local player = Players:GetPlayerByUserId(userId)
	
	if player then
		RemoteEvents.FireClient("CurrencyChanged", player, {
			Type = currencyType,
			Amount = newAmount,
			Change = change,
			Reason = reason or "unknown",
			Timestamp = os.time(),
		})
	end
end

-- Validate amount
local function ValidateAmount(amount: number): boolean
	return type(amount) == "number" 
		and amount > 0 
		and amount == math.floor(amount) -- Must be integer
		and amount < 1000000000 -- Reasonable limit
end

--------------------------------------------------------------------------------
-- COIN OPERATIONS
--------------------------------------------------------------------------------

--[[
	Add coins to a player
	
	@param userId: number - Player user ID
	@param amount: number - Amount to add (must be positive integer)
	@param reason: string - Reason for the addition (for logging)
	@return string - Result code from CurrencyManager.Result
]]
function CurrencyManager.AddCoins(userId: number, amount: number, reason: string): string
	-- Validate amount
	if not ValidateAmount(amount) then
		Log("WARN", string.format("Invalid coin amount: %s", tostring(amount)), userId)
		return CurrencyManager.Result.INVALID_AMOUNT
	end
	
	-- Check rate limit
	if not AntiCheat.CheckRateLimit(userId, "CurrencyChange") then
		Log("WARN", "Rate limited on coin addition", userId)
		return CurrencyManager.Result.RATE_LIMITED
	end
	
	-- Get profile
	local profileData = ProfileManager.GetData(userId)
	
	if not profileData then
		Log("ERROR", "Profile not found for coin addition", userId)
		return CurrencyManager.Result.PROFILE_NOT_FOUND
	end
	
	-- Check max limit
	local currentCoins = profileData.Currency.Coins or 0
	local maxCoins = GameConfig.Currency.Coins.Max
	local newAmount = currentCoins + amount
	
	if newAmount > maxCoins then
		-- Cap at max instead of failing
		newAmount = maxCoins
		amount = maxCoins - currentCoins
		
		if amount <= 0 then
			Log("WARN", "At max coins, cannot add more", userId)
			return CurrencyManager.Result.MAX_EXCEEDED
		end
		
		Log("INFO", string.format("Coin addition capped at max (%d)", maxCoins), userId)
	end
	
	-- Update profile
	profileData.Currency.Coins = newAmount
	
	-- Log transaction
	AntiCheat.LogTransaction(userId, AntiCheat.TransactionType.COIN_ADD, amount, {
		Reason = reason,
		NewBalance = newAmount,
		PreviousBalance = currentCoins,
	})
	
	-- Notify client
	NotifyClient(userId, "Coins", newAmount, amount, reason)
	
	Log("INFO", string.format("Added %d coins (reason: %s) - New balance: %d", amount, reason, newAmount), userId)
	
	return CurrencyManager.Result.SUCCESS
end

--[[
	Remove coins from a player
	
	@param userId: number - Player user ID
	@param amount: number - Amount to remove (must be positive integer)
	@param reason: string - Reason for the removal (for logging)
	@return string - Result code from CurrencyManager.Result
]]
function CurrencyManager.RemoveCoins(userId: number, amount: number, reason: string): string
	-- Validate amount
	if not ValidateAmount(amount) then
		Log("WARN", string.format("Invalid coin amount: %s", tostring(amount)), userId)
		return CurrencyManager.Result.INVALID_AMOUNT
	end
	
	-- Check rate limit
	if not AntiCheat.CheckRateLimit(userId, "CurrencyChange") then
		Log("WARN", "Rate limited on coin removal", userId)
		return CurrencyManager.Result.RATE_LIMITED
	end
	
	-- Get profile
	local profileData = ProfileManager.GetData(userId)
	
	if not profileData then
		Log("ERROR", "Profile not found for coin removal", userId)
		return CurrencyManager.Result.PROFILE_NOT_FOUND
	end
	
	-- Check balance
	local currentCoins = profileData.Currency.Coins or 0
	
	if currentCoins < amount then
		Log("WARN", string.format("Insufficient coins: has %d, needs %d", currentCoins, amount), userId)
		return CurrencyManager.Result.INSUFFICIENT_FUNDS
	end
	
	-- Update profile
	local newAmount = currentCoins - amount
	profileData.Currency.Coins = newAmount
	
	-- Log transaction
	AntiCheat.LogTransaction(userId, AntiCheat.TransactionType.COIN_REMOVE, amount, {
		Reason = reason,
		NewBalance = newAmount,
		PreviousBalance = currentCoins,
	})
	
	-- Notify client
	NotifyClient(userId, "Coins", newAmount, -amount, reason)
	
	Log("INFO", string.format("Removed %d coins (reason: %s) - New balance: %d", amount, reason, newAmount), userId)
	
	return CurrencyManager.Result.SUCCESS
end

--------------------------------------------------------------------------------
-- GEM OPERATIONS (Premium Currency)
--------------------------------------------------------------------------------

--[[
	Add gems to a player
	NOTE: Gems should only be added through purchase system or admin actions
	
	@param userId: number - Player user ID
	@param amount: number - Amount to add (must be positive integer)
	@param reason: string - Reason for the addition (for logging)
	@return string - Result code from CurrencyManager.Result
]]
function CurrencyManager.AddGems(userId: number, amount: number, reason: string): string
	-- Validate amount
	if not ValidateAmount(amount) then
		Log("WARN", string.format("Invalid gem amount: %s", tostring(amount)), userId)
		return CurrencyManager.Result.INVALID_AMOUNT
	end
	
	-- Get profile
	local profileData = ProfileManager.GetData(userId)
	
	if not profileData then
		Log("ERROR", "Profile not found for gem addition", userId)
		return CurrencyManager.Result.PROFILE_NOT_FOUND
	end
	
	-- Check max limit
	local currentGems = profileData.Currency.Gems or 0
	local maxGems = GameConfig.Currency.Gems.Max
	local newAmount = currentGems + amount
	
	if newAmount > maxGems then
		newAmount = maxGems
		amount = maxGems - currentGems
		
		if amount <= 0 then
			Log("WARN", "At max gems, cannot add more", userId)
			return CurrencyManager.Result.MAX_EXCEEDED
		end
	end
	
	-- Update profile
	profileData.Currency.Gems = newAmount
	
	-- Log transaction (gems are tracked more carefully)
	AntiCheat.LogTransaction(userId, AntiCheat.TransactionType.GEM_ADD, amount, {
		Reason = reason,
		NewBalance = newAmount,
		PreviousBalance = currentGems,
	})
	
	-- Notify client
	NotifyClient(userId, "Gems", newAmount, amount, reason)
	
	Log("INFO", string.format("Added %d gems (reason: %s) - New balance: %d", amount, reason, newAmount), userId)
	
	return CurrencyManager.Result.SUCCESS
end

--[[
	Remove gems from a player
	
	@param userId: number - Player user ID
	@param amount: number - Amount to remove (must be positive integer)
	@param reason: string - Reason for the removal (for logging)
	@return string - Result code from CurrencyManager.Result
]]
function CurrencyManager.RemoveGems(userId: number, amount: number, reason: string): string
	-- Validate amount
	if not ValidateAmount(amount) then
		Log("WARN", string.format("Invalid gem amount: %s", tostring(amount)), userId)
		return CurrencyManager.Result.INVALID_AMOUNT
	end
	
	-- Check rate limit
	if not AntiCheat.CheckRateLimit(userId, "CurrencyChange") then
		Log("WARN", "Rate limited on gem removal", userId)
		return CurrencyManager.Result.RATE_LIMITED
	end
	
	-- Get profile
	local profileData = ProfileManager.GetData(userId)
	
	if not profileData then
		Log("ERROR", "Profile not found for gem removal", userId)
		return CurrencyManager.Result.PROFILE_NOT_FOUND
	end
	
	-- Check balance
	local currentGems = profileData.Currency.Gems or 0
	
	if currentGems < amount then
		Log("WARN", string.format("Insufficient gems: has %d, needs %d", currentGems, amount), userId)
		return CurrencyManager.Result.INSUFFICIENT_FUNDS
	end
	
	-- Update profile
	local newAmount = currentGems - amount
	profileData.Currency.Gems = newAmount
	
	-- Log transaction
	AntiCheat.LogTransaction(userId, AntiCheat.TransactionType.GEM_REMOVE, amount, {
		Reason = reason,
		NewBalance = newAmount,
		PreviousBalance = currentGems,
	})
	
	-- Notify client
	NotifyClient(userId, "Gems", newAmount, -amount, reason)
	
	Log("INFO", string.format("Removed %d gems (reason: %s) - New balance: %d", amount, reason, newAmount), userId)
	
	return CurrencyManager.Result.SUCCESS
end

--------------------------------------------------------------------------------
-- BALANCE OPERATIONS
--------------------------------------------------------------------------------

--[[
	Get player's current balance
	
	@param userId: number - Player user ID
	@return table? - { Coins: number, Gems: number } or nil if profile not found
]]
function CurrencyManager.GetBalance(userId: number): { Coins: number, Gems: number }?
	local profileData = ProfileManager.GetData(userId)
	
	if not profileData or not profileData.Currency then
		return nil
	end
	
	return {
		Coins = profileData.Currency.Coins or 0,
		Gems = profileData.Currency.Gems or 0,
	}
end

--[[
	Check if player can afford a cost
	
	@param userId: number - Player user ID
	@param coinCost: number - Required coins (0 to ignore)
	@param gemCost: number? - Required gems (0 to ignore)
	@return boolean - True if player can afford
]]
function CurrencyManager.CanAfford(userId: number, coinCost: number, gemCost: number?): boolean
	local balance = CurrencyManager.GetBalance(userId)
	
	if not balance then
		return false
	end
	
	local coinsNeeded = coinCost or 0
	local gemsNeeded = gemCost or 0
	
	return balance.Coins >= coinsNeeded and balance.Gems >= gemsNeeded
end

--[[
	Spend both coins and gems in one transaction
	
	@param userId: number - Player user ID
	@param coinCost: number - Coins to spend
	@param gemCost: number - Gems to spend
	@param reason: string - Reason for the purchase
	@return string - Result code
]]
function CurrencyManager.SpendCurrency(userId: number, coinCost: number, gemCost: number, reason: string): string
	-- Validate affordability first
	if not CurrencyManager.CanAfford(userId, coinCost, gemCost) then
		return CurrencyManager.Result.INSUFFICIENT_FUNDS
	end
	
	-- Remove coins
	if coinCost > 0 then
		local coinResult = CurrencyManager.RemoveCoins(userId, coinCost, reason)
		if coinResult ~= CurrencyManager.Result.SUCCESS then
			return coinResult
		end
	end
	
	-- Remove gems
	if gemCost > 0 then
		local gemResult = CurrencyManager.RemoveGems(userId, gemCost, reason)
		if gemResult ~= CurrencyManager.Result.SUCCESS then
			-- Refund coins if gem removal failed (rollback)
			if coinCost > 0 then
				CurrencyManager.AddCoins(userId, coinCost, "rollback_" .. reason)
			end
			return gemResult
		end
	end
	
	return CurrencyManager.Result.SUCCESS
end

--[[
	Set coins directly (admin function)
	WARNING: Use sparingly, bypasses normal checks
	
	@param userId: number - Player user ID
	@param amount: number - New coin amount
	@param adminId: number - Admin performing the action
	@return boolean - Success
]]
function CurrencyManager.SetCoins(userId: number, amount: number, adminId: number): boolean
	if amount < 0 or amount > GameConfig.Currency.Coins.Max then
		return false
	end
	
	local profileData = ProfileManager.GetData(userId)
	
	if not profileData then
		return false
	end
	
	local oldAmount = profileData.Currency.Coins or 0
	profileData.Currency.Coins = amount
	
	-- Log admin action
	AntiCheat.LogTransaction(userId, AntiCheat.TransactionType.ADMIN_ACTION, amount - oldAmount, {
		Action = "SetCoins",
		AdminId = adminId,
		OldAmount = oldAmount,
		NewAmount = amount,
	})
	
	-- Notify client
	NotifyClient(userId, "Coins", amount, amount - oldAmount, "admin_set")
	
	Log("WARN", string.format("ADMIN %d set coins to %d (was %d)", adminId, amount, oldAmount), userId)
	
	return true
end

--[[
	Set gems directly (admin function)
	WARNING: Use sparingly, bypasses normal checks
	
	@param userId: number - Player user ID
	@param amount: number - New gem amount
	@param adminId: number - Admin performing the action
	@return boolean - Success
]]
function CurrencyManager.SetGems(userId: number, amount: number, adminId: number): boolean
	if amount < 0 or amount > GameConfig.Currency.Gems.Max then
		return false
	end
	
	local profileData = ProfileManager.GetData(userId)
	
	if not profileData then
		return false
	end
	
	local oldAmount = profileData.Currency.Gems or 0
	profileData.Currency.Gems = amount
	
	-- Log admin action
	AntiCheat.LogTransaction(userId, AntiCheat.TransactionType.ADMIN_ACTION, amount - oldAmount, {
		Action = "SetGems",
		AdminId = adminId,
		OldAmount = oldAmount,
		NewAmount = amount,
	})
	
	-- Notify client
	NotifyClient(userId, "Gems", amount, amount - oldAmount, "admin_set")
	
	Log("WARN", string.format("ADMIN %d set gems to %d (was %d)", adminId, amount, oldAmount), userId)
	
	return true
end

--------------------------------------------------------------------------------
-- REFUND OPERATIONS
--------------------------------------------------------------------------------

--[[
	Refund a previous transaction
	
	@param userId: number - Player user ID
	@param transactionId: string - Transaction ID to refund
	@param adminId: number - Admin performing the refund
	@return boolean - Success
]]
function CurrencyManager.RefundTransaction(userId: number, transactionId: string, adminId: number): boolean
	-- Find the transaction
	local transactions = AntiCheat.GetTransactionLog(userId, 100)
	local targetTransaction = nil
	
	for _, transaction in ipairs(transactions) do
		if transaction.Id == transactionId then
			targetTransaction = transaction
			break
		end
	end
	
	if not targetTransaction then
		Log("WARN", string.format("Transaction %s not found for refund", transactionId), userId)
		return false
	end
	
	-- Determine refund type
	local refundAmount = targetTransaction.Amount
	local refundReason = "refund_" .. transactionId
	
	if targetTransaction.Type == AntiCheat.TransactionType.COIN_REMOVE then
		return CurrencyManager.AddCoins(userId, refundAmount, refundReason) == CurrencyManager.Result.SUCCESS
	elseif targetTransaction.Type == AntiCheat.TransactionType.GEM_REMOVE then
		return CurrencyManager.AddGems(userId, refundAmount, refundReason) == CurrencyManager.Result.SUCCESS
	end
	
	Log("WARN", string.format("Cannot refund transaction type: %s", targetTransaction.Type), userId)
	return false
end

return CurrencyManager
