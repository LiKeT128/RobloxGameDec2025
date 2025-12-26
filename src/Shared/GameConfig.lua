--[[
	GameConfig.lua
	Centralized configuration for Memory Rush game
	
	Contains:
	- Default player profile template
	- Currency and validation rules
	- Memory registry
	- Rate limiting settings
	- Trade/Gift configuration
	
	Author: Memory Rush Team
	Version: 1.0.0
]]

local GameConfig = {}

--------------------------------------------------------------------------------
-- VERSION INFO
--------------------------------------------------------------------------------

GameConfig.Version = "1.0.0"
GameConfig.DataStoreKey = "MemoryRush_PlayerData_v1"

--------------------------------------------------------------------------------
-- PROFILE SERVICE SETTINGS
--------------------------------------------------------------------------------

GameConfig.ProfileService = {
	AutoSaveInterval = 30, -- seconds
	LoadTimeout = 30, -- seconds
	MaxRetries = 3,
	RetryDelay = 2, -- seconds
}

--------------------------------------------------------------------------------
-- DEFAULT PLAYER PROFILE TEMPLATE
-- This is the template used when creating new player profiles
--------------------------------------------------------------------------------

GameConfig.DefaultProfile = {
	-- Metadata
	UserId = 0,
	CreatedAt = 0,
	LastSave = 0,
	
	-- Inventory system
	Inventory = {
		Memories = {}, -- [memoryId: string] = count: number
		TotalMemories = 0,
	},
	
	-- Currency system
	Currency = {
		Coins = 100, -- Starting coins (earned through gameplay)
		Gems = 0, -- Premium currency (only from purchases)
	},
	
	-- Player statistics
	Statistics = {
		MemoriesOpened = 0,
		MemoriesUniqueCollected = 0,
		TradesCompleted = 0,
		GiftsGiven = 0,
		GiftsReceived = 0,
		LastMemoryOpenTime = 0,
		SessionCount = 0,
		TotalPlayTime = 0, -- seconds
		FirstJoinTime = 0,
	},
	
	-- User settings
	Settings = {
		Language = "en",
		MusicVolume = 0.5,
		SFXVolume = 0.5,
		NotificationsEnabled = true,
		TradeRequestsEnabled = true,
		GiftNotificationsEnabled = true,
	},
	
	-- Active trades
	PendingTrades = {
		--[[
		[tradeId: string] = {
			FromPlayerId = number,
			ToPlayerId = number,
			OfferedMemories = { [memoryId] = count },
			RequestedMemories = { [memoryId] = count },
			CreatedAt = number,
			Expiry = number,
			Status = "pending" | "accepted" | "completed" | "cancelled"
		}
		]]
	},
	
	-- Pending gifts to claim
	PendingGifts = {
		--[[
		[giftId: string] = {
			FromPlayerId = number,
			MemoryId = string,
			Count = number,
			Message = string,
			SentAt = number,
			Expiry = number
		}
		]]
	},
	
	-- Purchase history
	Purchases = {
		TotalSpent = 0, -- Total Robux spent
		LastPurchaseTime = 0,
		PurchaseHistory = {}, -- Array of purchase records
	},
	
	-- Daily rewards tracking
	DailyRewards = {
		LastClaimDate = 0, -- Unix timestamp of last claim
		CurrentStreak = 0,
		TotalClaims = 0,
		HighestStreak = 0,
	},
	
	-- Anti-cheat flags (internal use)
	Flags = {
		SuspiciousActivity = {}, -- Array of flagged events
		Warnings = 0,
		LastFlagTime = 0,
		IsBanned = false,
		BanReason = "",
		BanExpiry = 0, -- 0 = permanent
	},
}

--------------------------------------------------------------------------------
-- CURRENCY CONFIGURATION
--------------------------------------------------------------------------------

GameConfig.Currency = {
	-- Coins (free currency)
	Coins = {
		Min = 0,
		Max = 999999999, -- 999 million max
		StartingAmount = 100,
	},
	
	-- Gems (premium currency)
	Gems = {
		Min = 0,
		Max = 999999999,
		StartingAmount = 0,
	},
	
	-- Transaction limits (anti-cheat)
	TransactionLimits = {
		MaxCoinsPerTransaction = 1000000,
		MaxGemsPerTransaction = 100000,
		MaxTransactionsPerMinute = 60,
	},
}

--------------------------------------------------------------------------------
-- MEMORY REGISTRY
-- All valid memory IDs must be registered here
--------------------------------------------------------------------------------

GameConfig.MemoryRegistry = {
	-- Format: [memoryId] = { Name, Rarity, Description }
	-- Rarity: 1=Common, 2=Uncommon, 3=Rare, 4=Epic, 5=Legendary
	
	-- Common Memes (Rarity 1)
	["meme_drake"] = { Name = "Drake Hotline Bling", Rarity = 1, Description = "The classic approve/disapprove meme" },
	["meme_doge"] = { Name = "Doge", Rarity = 1, Description = "Such wow, very meme" },
	["meme_success_kid"] = { Name = "Success Kid", Rarity = 1, Description = "Fist pump of victory" },
	["meme_bad_luck_brian"] = { Name = "Bad Luck Brian", Rarity = 1, Description = "When everything goes wrong" },
	["meme_one_does_not"] = { Name = "One Does Not Simply", Rarity = 1, Description = "Boromir's wise words" },
	
	-- Uncommon Memes (Rarity 2)
	["meme_distracted_bf"] = { Name = "Distracted Boyfriend", Rarity = 2, Description = "Looking at something else" },
	["meme_expanding_brain"] = { Name = "Expanding Brain", Rarity = 2, Description = "Galaxy brain moments" },
	["meme_change_my_mind"] = { Name = "Change My Mind", Rarity = 2, Description = "Prove me wrong" },
	["meme_surprised_pikachu"] = { Name = "Surprised Pikachu", Rarity = 2, Description = ":o" },
	["meme_woman_cat"] = { Name = "Woman Yelling at Cat", Rarity = 2, Description = "The dinner table argument" },
	
	-- Rare Memes (Rarity 3)
	["meme_stonks"] = { Name = "Stonks", Rarity = 3, Description = "Financial genius" },
	["meme_this_is_fine"] = { Name = "This Is Fine", Rarity = 3, Description = "Everything is fine..." },
	["meme_always_has_been"] = { Name = "Always Has Been", Rarity = 3, Description = "Wait, it's all Ohio?" },
	["meme_spiderman_pointing"] = { Name = "Spiderman Pointing", Rarity = 3, Description = "They're the same picture" },
	
	-- Epic Memes (Rarity 4)
	["meme_wojak"] = { Name = "Wojak Collection", Rarity = 4, Description = "I know that feel bro" },
	["meme_pepe"] = { Name = "Rare Pepe", Rarity = 4, Description = "Feels good man" },
	["meme_nyan_cat"] = { Name = "Nyan Cat", Rarity = 4, Description = "Rainbow pop-tart cat" },
	
	-- Legendary Memes (Rarity 5)
	["meme_rickroll"] = { Name = "Rick Astley", Rarity = 5, Description = "Never gonna give you up" },
	["meme_harambe"] = { Name = "Harambe", Rarity = 5, Description = "Gone but never forgotten" },
	["meme_dank_meme_lord"] = { Name = "Dank Meme Lord", Rarity = 5, Description = "The ultimate meme collector" },
}

-- Get all valid memory IDs as a set for quick lookup
GameConfig.ValidMemoryIds = {}
for memoryId, _ in pairs(GameConfig.MemoryRegistry) do
	GameConfig.ValidMemoryIds[memoryId] = true
end

--------------------------------------------------------------------------------
-- TRADE CONFIGURATION
--------------------------------------------------------------------------------

GameConfig.Trade = {
	MaxPendingTrades = 10, -- Max active trades per player
	ExpiryTime = 86400, -- 24 hours in seconds
	CleanupInterval = 60, -- Check for expired trades every 60 seconds
	MaxMemoriesPerTrade = 50, -- Max different memory types in one trade
	MaxTotalItemsPerTrade = 100, -- Max total items in one trade
	CooldownBetweenTrades = 5, -- Seconds between trade actions
}

--------------------------------------------------------------------------------
-- GIFT CONFIGURATION
--------------------------------------------------------------------------------

GameConfig.Gift = {
	MaxPendingGifts = 50, -- Max unclaimed gifts per player
	ExpiryTime = 604800, -- 7 days in seconds
	CleanupInterval = 300, -- Check for expired gifts every 5 minutes
	MaxMessageLength = 100, -- Max characters in gift message
	MaxGiftsPerDay = 20, -- Rate limit on sending gifts
	CooldownBetweenGifts = 10, -- Seconds between gift sends
}

--------------------------------------------------------------------------------
-- RATE LIMITING
--------------------------------------------------------------------------------

GameConfig.RateLimits = {
	-- Action = { MaxRequests, TimeWindowSeconds }
	CurrencyChange = { MaxRequests = 60, TimeWindow = 60 },
	InventoryChange = { MaxRequests = 100, TimeWindow = 60 },
	TradeAction = { MaxRequests = 20, TimeWindow = 60 },
	GiftAction = { MaxRequests = 30, TimeWindow = 60 },
	MemoryOpen = { MaxRequests = 120, TimeWindow = 60 },
	DataRequest = { MaxRequests = 30, TimeWindow = 60 },
}

--------------------------------------------------------------------------------
-- ANTI-CHEAT THRESHOLDS
--------------------------------------------------------------------------------

GameConfig.AntiCheat = {
	-- Anti-Cheat Thresholds (monitoring only initially, then banning)
	MaxCoinGainPerHour = 100000,
	MaxGemGainPerHour = 1000, -- Should only be from purchases
	MaxMemoriesGainedPerHour = 500,
	MaxTradesPerHour = 50,
	
	-- Warning system
	WarningsBeforeBan = 5,
	WarningDecayTime = 86400, -- 24 hours
	
	-- Logging
	LogRetentionDays = 30,
	MaxLogsPerPlayer = 1000,
}

--------------------------------------------------------------------------------
-- SHOP CONFIGURATION
--------------------------------------------------------------------------------

GameConfig.Shop = {
	Packs = {
		StarterPack = {
			Name = "Starter Pack",
			Description = "A great start for new collectors. Contains 3 Common memes.",
			Price = 100,
			Currency = "Coins",
			ImageId = "rbxassetid://0", -- TODO: Add Image
			Guarantees = { Common = 3 },
			DropRates = { Common = 0.9, Uncommon = 0.1, Rare = 0, Epic = 0, Legendary = 0 }
		},
		BasicPack = {
			Name = "Basic Pack",
			Description = "Standard pack. Contains 5 memes with a chance for Uncommon.",
			Price = 500,
			Currency = "Coins",
			ImageId = "rbxassetid://0",
			Guarantees = { Common = 3, Uncommon = 2 },
			DropRates = { Common = 0.7, Uncommon = 0.25, Rare = 0.05, Epic = 0, Legendary = 0 }
		},
		RarePack = {
			Name = "Rare Pack",
			Description = "Higher chance for Rare memes. Contains 5 memes.",
			Price = 2500,
			Currency = "Coins",
			ImageId = "rbxassetid://0",
			Guarantees = { Uncommon = 3, Rare = 1 },
			DropRates = { Common = 0.5, Uncommon = 0.35, Rare = 0.12, Epic = 0.03, Legendary = 0 }
		},
		EpicPack = {
			Name = "Epic Pack",
			Description = "Contains premium memes. 1 Epic guaranteed!",
			Price = 200, -- Gems
			Currency = "Gems",
			ImageId = "rbxassetid://0",
			Guarantees = { Rare = 3, Epic = 1 },
			DropRates = { Common = 0.2, Uncommon = 0.3, Rare = 0.35, Epic = 0.14, Legendary = 0.01 }
		},
	}
}

--------------------------------------------------------------------------------
-- DAILY REWARDS CONFIGURATION
--------------------------------------------------------------------------------

GameConfig.DailyRewards = {
	ResetHourUTC = 0, -- Reset at midnight UTC
	StreakResetHours = 48, -- Streak resets if player misses 48 hours
	MaxStreak = 30, -- Streak caps at 30 days
	
	-- Rewards per day (day 1-7, then cycles)
	Rewards = {
		[1] = { Coins = 100, Gems = 0 },
		[2] = { Coins = 150, Gems = 0 },
		[3] = { Coins = 200, Gems = 0 },
		[4] = { Coins = 250, Gems = 1 },
		[5] = { Coins = 300, Gems = 0 },
		[6] = { Coins = 400, Gems = 0 },
		[7] = { Coins = 500, Gems = 5 }, -- Big reward on day 7
	},
}

--------------------------------------------------------------------------------
-- ADMIN CONFIGURATION
--------------------------------------------------------------------------------

GameConfig.Admins = {
	-- Add admin user IDs here
	-- [userId] = permissionLevel (1 = moderator, 2 = admin, 3 = owner)
	[4747207138] = 3,
	[4031492824] = 3
}

GameConfig.AdminPermissions = {
	[1] = { "ViewPlayerData", "ViewLogs" },
	[2] = { "ViewPlayerData", "ViewLogs", "EditPlayerData", "BanPlayer" },
	[3] = { "ViewPlayerData", "ViewLogs", "EditPlayerData", "BanPlayer", "ResetData", "GiveItems" },
}

--------------------------------------------------------------------------------
-- REMOTE EVENT NAMES
--------------------------------------------------------------------------------

GameConfig.RemoteEvents = {
	-- Data updates
	"ProfileLoaded",
	"CurrencyChanged",
	"InventoryChanged",
	"StatisticsUpdated",
	"SettingsUpdated",
	
	-- Trading
	"TradeCreated",
	"TradeUpdated",
	"TradeCompleted",
	"TradeCancelled",
	"TradeExpired",
	
	-- Gifting
	"GiftReceived",
	"GiftClaimed",
	"GiftExpired",
	
	-- Daily rewards
	"DailyRewardAvailable",
	"DailyRewardClaimed",
	
	-- Notifications
	"ShowNotification",
	"ShowError",
}

GameConfig.RemoteFunctions = {
	"RequestPlayerData",
	"RequestTradeData",
	"RequestGiftData",
	"RequestLeaderboardData",
	
	-- Shop Functions
	"PurchasePack",
}

--------------------------------------------------------------------------------
-- UTILITY FUNCTIONS
--------------------------------------------------------------------------------

-- Check if a memory ID is valid
function GameConfig.IsValidMemory(memoryId: string): boolean
	return GameConfig.ValidMemoryIds[memoryId] == true
end

-- Get memory info by ID
function GameConfig.GetMemoryInfo(memoryId: string): { Name: string, Rarity: number, Description: string }?
	return GameConfig.MemoryRegistry[memoryId]
end

-- Get rarity name from number
function GameConfig.GetRarityName(rarity: number): string
	local rarityNames = {
		[1] = "Common",
		[2] = "Uncommon",
		[3] = "Rare",
		[4] = "Epic",
		[5] = "Legendary",
	}
	return rarityNames[rarity] or "Unknown"
end

-- Deep copy a table (used for creating new profiles from template)
function GameConfig.DeepCopy(original)
	if type(original) ~= "table" then
		return original
	end
	
	local copy = {}
	for key, value in pairs(original) do
		copy[GameConfig.DeepCopy(key)] = GameConfig.DeepCopy(value)
	end
	
	return copy
end

-- Create a new profile from the default template
function GameConfig.CreateNewProfile(userId: number): typeof(GameConfig.DefaultProfile)
	local profile = GameConfig.DeepCopy(GameConfig.DefaultProfile)
	local now = os.time()
	
	profile.UserId = userId
	profile.CreatedAt = now
	profile.LastSave = now
	profile.Statistics.FirstJoinTime = now
	
	return profile
end

return GameConfig
