--Made by Luckymaxer

Mouse_Icon = "rbxasset://textures/GunCursor.png"
Reloading_Icon = "rbxasset://textures/GunWaitCursor.png"

Tool = script.Parent

Mouse = nil

function UpdateIcon()
	if Mouse then
		Mouse.Icon = Tool.Enabled and Mouse_Icon or Reloading_Icon
	end
end

function OnEquipped(ToolMouse)
	Mouse = ToolMouse
	UpdateIcon()
end

function OnChanged(Property)
	if Property == "Enabled" then
		UpdateIcon()
	end
end

Tool.Equipped:Connect(OnEquipped)
Tool.Changed:Connect(OnChanged)
