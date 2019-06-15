local module = {}

--Kills users even if they have a shield

function module:ExecuteBehaviour(brickTouched, character)
	if character:FindFirstChild("Humanoid") ~= nil then
		if character.Humanoid.Health > 0 then
			character.Humanoid.Health = 0
		end
	end
end

return module
