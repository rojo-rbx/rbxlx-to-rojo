local module = {}

function module:ExecuteBehaviour(brickTouched, character)
	for _, part in pairs(brickTouched.Parent:GetChildren()) do
		if part:isA("BasePart") then
			part.Anchored = false
		end
	end
	wait(.3)
	if brickTouched ~= nil and brickTouched.Parent ~= nil then
		for _, part in pairs(brickTouched.Parent:GetChildren()) do
			if part:isA("BasePart") then
				part.CanCollide = false
			end
		end
	end
end

return module
