local module = {}

local equalizingForce = 236 / 1.2 -- amount of force required to levitate a mass
local gravity = .90 -- things float at > 1

function recursiveGetLift(node)
	local m = 0
	local c = node:GetChildren()
	for i=1,#c do
		if c[i]:IsA("BasePart") then
			if c[i].Name == "Handle" then
				m = m + (c[i]:GetMass() * equalizingForce * 1) -- makes hats weightless, so different hats don't change your jump height
			else
				m = m + (c[i]:GetMass() * equalizingForce * gravity)
			end
		end
		m = m + recursiveGetLift(c[i])
	end
	return m
end

function module:ExecuteBehaviour(brickTouched, character)
	if character:FindFirstChild("HumanoidRootPart") ~= nil then
		if character.Humanoid.Health > 0 then
			if character.HumanoidRootPart:FindFirstChild("LadderBoostEffect") == nil then
				local boostEffectDebounce = Instance.new("IntValue")
				boostEffectDebounce.Name = "LadderBoostEffect"
				boostEffectDebounce.Parent = character.HumanoidRootPart
				game:GetService("Debris"):AddItem(boostEffectDebounce, 2)
				local boostEffect = Instance.new("BodyForce")
				boostEffect.force = Vector3.new(0, recursiveGetLift(character) ,0)
				boostEffect.Parent = character.HumanoidRootPart
				game:GetService("Debris"):AddItem(boostEffect, .2)
			end
		end
	end
end

return module
