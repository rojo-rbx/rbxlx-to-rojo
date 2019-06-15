local coin = script.Parent
local coinModel = coin.Parent
local trackModel = coinModel.Parent
local tracksModel = trackModel.Parent

coin.BodyPosition.position = script.Parent.Position
coin.BodyGyro.cframe = CFrame.new(
	0, 0, 0,
	0, -1, 0,
	0, 0, 0,
	0, 0, 0
)
coin.RotVelocity = Vector3.new(0, 5, 0)

if coinModel.Parent ~= game.Workspace then
	if game.Workspace:FindFirstChild("Tracks") then
		if tracksModel:FindFirstChild("Coins") == nil then
			local coinsModel = Instance.new("Model")
			coinsModel.Name = "Coins"
			coinsModel.Parent = tracksModel
		end

		tracksModel.ChildRemoved:connect(function(child) if child == trackModel then coinModel:Destroy() end end)
		coinModel.Parent = tracksModel:FindFirstChild("Coins")
	end
end

wait(1)
coin.RotVelocity = Vector3.new(0, 5, 0)
