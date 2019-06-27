local module = {}

function module:ExecuteBehaviour(brickTouched, character)
	if character:FindFirstChild("Humanoid") ~= nil then
		local shield = character:FindFirstChild("Shield")
		if shield == nil then
			if character.Humanoid.Health > 0 then
				character.Humanoid.Health = 0
				character:BreakJoints()
			end
		else
			if shield:isA("ForceField") then
				local tempShield = Instance.new("BoolValue")
				tempShield.Name = "Shield"
				tempShield.Parent = character
				game:GetService("Debris"):AddItem(tempShield, 1)
				shield:Destroy()
			end
		end
	end
end

return module
