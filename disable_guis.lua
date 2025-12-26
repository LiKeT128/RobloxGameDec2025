-- Run this in Command Bar to hide all GUIs in Studio
-- (They will auto-enable when the game starts thanks to the new scripts!)

for _, gui in ipairs(game:GetService("StarterGui"):GetChildren()) do
	if gui:IsA("ScreenGui") then
		gui.Enabled = false
		print("Hidden:", gui.Name)
	end
end
print("✅ All GUIs hidden! They will appear when you play.")
