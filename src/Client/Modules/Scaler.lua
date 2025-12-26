--[[
	Scaler.lua
	Automatically adapts GUI size to screen size (Scale-based)
	
	📍 Location: src/Client/Modules/Scaler.lua
	
	MANUAL:
	1. Require this module in your controllers
	2. Use Scaler.AddScaleConstraint(screenGui) to apply scaling
	
	HOW IT WORKS:
	- It adds a UIScale to the ScreenGui
	- It calculates scale based on a "Design Resolution" (e.g. 1920x1080)
	- This makes everything look the same size relative to the screen, 
	  regardless of device!
]]

local Scaler = {}
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

-- Your design resolution (what you see in Studio)
local DESIGN_RESOLUTION = Vector2.new(1920, 1080)

function Scaler.AddScaleConstraint(screenGui)
	if not screenGui:IsA("ScreenGui") then return end
	
	-- check if exists
	if screenGui:FindFirstChild("UIScale") then return end
	
	local uiScale = Instance.new("UIScale")
	uiScale.Name = "UIScale"
	uiScale.Parent = screenGui
	
	local function updateScale()
		local camera = Workspace.CurrentCamera
		if not camera then return end
		
		local viewportSize = camera.ViewportSize
		
		-- Calculate scale based on width or height dominance
		-- Typically fitting to width is safer for mobile portrait, 
		-- but for landscape games, fit to height or average.
		
		local cleanupScale = math.min(
			viewportSize.X / DESIGN_RESOLUTION.X,
			viewportSize.Y / DESIGN_RESOLUTION.Y
		)
		
		-- Clamp to prevent too small/large
		uiScale.Scale = math.clamp(cleanupScale, 0.4, 2.0)
	end
	
	-- Connect
	local camera = Workspace.CurrentCamera
	if camera then
		camera:GetPropertyChangedSignal("ViewportSize"):Connect(updateScale)
		updateScale()
	end
end

return Scaler
