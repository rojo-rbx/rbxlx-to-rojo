local module = {}

function module:ExecuteBehaviour(brickTouched, character)
	if character:FindFirstChild("HumanoidRootPart") ~= nil then
		if character.HumanoidRootPart:FindFirstChild("Explosion") == nil then
			local explosion = Instance.new("Explosion")
			explosion.Name = "Explosion"
			explosion.BlastRadius = 10
			explosion.BlastPressure = 0
			explosion.Position = character.HumanoidRootPart.Position
			explosion.Parent = character.HumanoidRootPart
		end
	end
end

return module

