-- Credit to Davidii for creating the orginal module which I slightly modified for my purposes

local RoomPackager = {}

--returns a table of vector3s that represent the corners of any given part
function RoomPackager:CornersOfPart(part)
	local cframe = part.CFrame
	local halfSizeX = part.Size.X / 2
	local halfSizeY = part.Size.Y / 2
	local halfSizeZ = part.Size.Z / 2

	local corners = {
		RightTopBack =		cframe:pointToWorldSpace(Vector3.new(halfSizeX, halfSizeY, halfSizeZ)),
		RightBottomBack =	cframe:pointToWorldSpace(Vector3.new(halfSizeX, -halfSizeY, halfSizeZ)),
		RightTopFront =		cframe:pointToWorldSpace(Vector3.new(halfSizeX, halfSizeY, -halfSizeZ)),
		RightBottomFront =	cframe:pointToWorldSpace(Vector3.new(halfSizeX, -halfSizeY, -halfSizeZ)),
		LeftTopBack =		cframe:pointToWorldSpace(Vector3.new(-halfSizeX, halfSizeY, halfSizeZ)),
		LeftBottomBack =	cframe:pointToWorldSpace(Vector3.new(-halfSizeX, -halfSizeY, halfSizeZ)),
		LeftTopFront =		cframe:pointToWorldSpace(Vector3.new(-halfSizeX, halfSizeY, -halfSizeZ)),
		LeftBottomFront =	cframe:pointToWorldSpace(Vector3.new(-halfSizeX, -halfSizeY, -halfSizeZ)),
	}

	return corners
end

--returns the four corners with the highest y components
--this is to catch when a user has flipped the baseplate upside down
function RoomPackager:TopCornersOfBasePlate(basePlate)
	local corners = self:CornersOfPart(basePlate)
	local centerY = basePlate.Position.Y
	local topCorners = {}
	for _, corner in pairs(corners) do
		--if a corner is higher globally than the center of the part, then
		--it is along the top-facing surface of the part
		if corner.Y > centerY then
			table.insert(topCorners, corner)
		end
	end
	return topCorners
end

--this returns a region3 that lines up on top of the baseplate to capture
--whatever room has been constructed on top of it, it is smart enough
--to capture a room that has been less-than-ideally set up
function RoomPackager:RegionsFromBasePlate(basePlate)
	local topCorners = self:TopCornersOfBasePlate(basePlate)

	--we farm the min and max x's and z's from the top corners
	--to get x and z coordinates for the region3 that will contain the room
	--we choose an arbitrary corner so that the initial values are in the data set
	local arbitraryCorner = topCorners[1]
	local minX = arbitraryCorner.X
	local minZ = arbitraryCorner.Z
	local maxX = arbitraryCorner.X
	local maxZ = arbitraryCorner.Z
	for _, corner in pairs(topCorners) do
		minX = math.min(minX, corner.X)
		minZ = math.min(minZ, corner.Z)
		maxX = math.max(maxX, corner.X)
		maxZ = math.max(maxZ, corner.Z)
	end

	--construct the region using these new corners we have constructed
	--keeping in mind that all corners in topCorners *should* have the same y value
	local minY = topCorners[1].Y
	local lowerCorner = Vector3.new(minX, minY, minZ)
	local maxY = minY + 70
	local upperCorner = Vector3.new(maxX, maxY, maxZ)

	local segmentHeight = math.floor(100000/(math.abs(maxX-minX)*math.abs(maxZ-minZ)))

	local regions = {}

	local currentHeight = minY
	while currentHeight - minY < 70 do
		currentHeight = currentHeight + segmentHeight
		lowerCorner = Vector3.new(lowerCorner.x, currentHeight - segmentHeight, lowerCorner.z)
		upperCorner = Vector3.new(upperCorner.x, currentHeight, upperCorner.z)
		table.insert(regions, Region3.new(lowerCorner, upperCorner))
	end

	return regions
end

--Finds the model the current part is in which is closest to workspace
--Returns the part is the part is in Workspace
--Returns nil if the object is already in the roomModel we are constructing
local function closestParentToWorkspace(object, roomModel)
	if object.Parent == roomModel then
		return nil
	end
	if object.Parent == game.Workspace then
		return object
	else
		return closestParentToWorkspace(object.Parent, roomModel)
	end
end

--Categorises a model based on the location of the start and end points of the path in the model
function RoomPackager:CategoriseModel(pathModel)
	if pathModel:FindFirstChild("EndParts") then
		return game.ReplicatedStorage.PathModules.Branch
	elseif pathModel.Start.Position.Y < pathModel.End.Position.Y - 5 then
		return game.ReplicatedStorage.PathModules.GoingUp
	elseif pathModel.Start.Position.Y > pathModel.End.Position.Y + 5 then
		return game.ReplicatedStorage.PathModules.GoingDown
	else
		return game.ReplicatedStorage.PathModules.SameHeight
	end
end

local function addBehavioursRecur(model, behaviourFolder)
	local children = model:GetChildren()
	for i = 1, #children do
		if children[i]:isA("BasePart") then
			behaviourFolder:Clone().Parent = children[i]
		else
			addBehavioursRecur(children[i], behaviourFolder)
		end
	end
end

RoomPackager.setUpBehaviours = function(roomModel)
	if roomModel:FindFirstChild("Behaviours") then
		addBehavioursRecur(roomModel, roomModel.Behaviours)
		return
	end
	local children = roomModel:GetChildren()
	for i = 1, #children do
		RoomPackager.setUpBehaviours(children[i])
	end
end

local function processPart(roomModel, part, parts)
	if part.Parent == roomModel then return end
	if part.Name == "End" and roomModel:FindFirstChild("End") then
		local endsModel = Instance.new("Model") --Used for branching the path
		endsModel.Name = "EndParts"
		endsModel.Parent = roomModel
		part.Parent = endsModel
		roomModel:FindFirstChild("End").Parent = endsModel
	elseif part.Name == "End" and roomModel:FindFirstChild("EndParts") then
		part.Parent = roomModel:FindFirstChild("EndParts")
	elseif part.Name == "End" then
		part.Parent = roomModel
	else
		local topLevelParent = closestParentToWorkspace(part, roomModel)
		if topLevelParent ~= nil then
			if topLevelParent:isA("BasePart") then
				local connectedParts = topLevelParent:GetConnectedParts(true)
				for _, connectedPart in pairs(connectedParts) do
					if connectedPart.Name == "End" then
						table.insert(parts, connectedPart)
					else
						local conTopLevelParent = closestParentToWorkspace(connectedPart, roomModel)
						if conTopLevelParent and conTopLevelParent ~= topLevelParent then
							conTopLevelParent.Parent = roomModel
						end
					end
				end
			end
			topLevelParent.Parent = roomModel
		end
	end
end

function RoomPackager:PackageRoom(roomBasePlate)
	local roomModel = Instance.new("Model")
	roomModel.Name = "Path"
	roomModel.Parent = game.ReplicatedStorage.PathModules

	local regions = self:RegionsFromBasePlate(roomBasePlate)

	for i = 1, #regions do
		--Repeatedly finds 100 parts in the region until none are left
		while true do
			local parts = game.Workspace:FindPartsInRegion3(regions[i], nil, 100)
			if #parts == 0 then
				break
			end
			for _, part in pairs(parts) do
				processPart(roomModel, part, parts)
			end
		end
	end

	--Set-up model for use in the path (parts for locating the path are made transparent)
	roomBasePlate.Transparency = 1
	roomBasePlate.Parent = roomModel
	roomModel:FindFirstChild("Start", true).Parent = roomModel
	roomModel:FindFirstChild("Start", true).Transparency = 1
	if roomModel:FindFirstChild("EndParts") then
		local ends = roomModel:FindFirstChild("EndParts"):GetChildren()
		for i = 1, #ends do
			ends[i].Transparency = 1
		end
	else
		roomModel.End.Transparency = 1
	end
	roomModel.PrimaryPart = roomBasePlate
	roomModel.Parent = self:CategoriseModel(roomModel)
	RoomPackager.setUpBehaviours(roomModel)
	return roomModel
end

return RoomPackager