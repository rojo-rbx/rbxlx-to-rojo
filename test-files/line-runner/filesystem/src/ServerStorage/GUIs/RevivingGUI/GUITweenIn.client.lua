local onScreenPosition = UDim2.new(0.5, -375, 0, 36)
local offScreenPosition = UDim2.new(0.5, -375, 0, -140)

script.Parent.Frame:TweenPosition(onScreenPosition, "Out", "Quad", 1, true)
wait(1.5)
script.Parent.Frame:TweenPosition(offScreenPosition, "Out", "Quad", 1.5, true)
wait(1.5)

script.Parent:Destroy()
