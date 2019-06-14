local humanoidList = {}
local storage = {}

function humanoidList:GetCurrent()
	return storage
end

local function findHumanoids(object, list)
	if object then
		if object:IsA("Humanoid") then
			table.insert(list, object)
		end

		for _, child in pairs(object:GetChildren()) do
			local childList = findHumanoids(child, list)
		end
	end
end

local updateThread = coroutine.create(function()
	while true do
		storage = {}
		findHumanoids(game.Workspace, storage)
		wait(3)
	end
end)

coroutine.resume(updateThread)

return humanoidList