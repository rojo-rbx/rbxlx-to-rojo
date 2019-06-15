local destroyService = {}

local destroyQueue = {}

function destroyService:AddItem(theobject, delay)
	local now = os.time()
	local destroyObject = {object = theobject, destroyTime = delay + now}
	for i, storedObject in pairs(destroyQueue) do
		if destroyQueue[i].destroyTime > destroyObject.destroyTime then
			table.insert(destroyQueue, i, destroyObject)
			return true
		end
	end
	table.insert(destroyQueue, destroyObject)
	return true
end

local updateThread = coroutine.create(function()
	while true do
		local now = os.time()
		for _, storedObject in pairs(destroyQueue) do
			if now >= storedObject.destroyTime then
				table.remove(destroyQueue, 1)
				if storedObject.object then
					storedObject.object:Destroy()
				end
			elseif now >= storedObject.destroyTime - 1 then

				if storedObject.object and storedObject.object:IsA("Part") then
					local trans = storedObject.object.Transparency + 1/30
					storedObject.object.Transparency = trans
				end
			else
				break
			end
		end
		wait()
	end
end)

coroutine.resume(updateThread)

return destroyService