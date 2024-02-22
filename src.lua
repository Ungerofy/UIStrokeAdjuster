local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer

local UIStrokeAdjuster = {} do
	UIStrokeAdjuster.__index = UIStrokeAdjuster
	
	function UIStrokeAdjuster.new()
		local self = setmetatable({}, UIStrokeAdjuster)
		
		self._playerGui = player:WaitForChild("PlayerGui")
		self._strokes = {}
		self._camera = workspace.CurrentCamera
		
		self._studioResolution = Vector2.new(1920, 1080)
		self._billboardGuiDistance = 15
		
		self:_initialize()
		
		return self
	end
end

function UIStrokeAdjuster:getInstancePosition(instance)
	local position = Vector3.zero
	
	if instance:IsA("Part") then
		position = instance.Position
	elseif instance:IsA("Model") then
		local cframe, size = instance:GetBoundingBox()
		position = cframe.Position
	end
	
	return position
end

function UIStrokeAdjuster:getAverage(vector)
	return (vector.X + vector.Y) / 2
end

function UIStrokeAdjuster:getScreenRatio()
	return self:getAverage(self._camera.ViewportSize) / self:getAverage(self._studioResolution)
end

function UIStrokeAdjuster:getStrokePosition(stroke)
	for index, strokeData in next, self._strokes do
		if strokeData.stroke ~= stroke then continue end
		
		return index
	end
end

function UIStrokeAdjuster:_registerStrokes()
	for _, gui in next, self._playerGui:GetChildren() do
		if not gui:IsA("ScreenGui") and not gui:IsA("BillboardGui") then continue end

		for _, stroke in next, gui:GetDescendants() do
			if not stroke:IsA("UIStroke") then continue end

			self:_registerStroke(stroke)
		end
	end

	for _, gui in next, workspace:GetDescendants() do
		if not gui:IsA("SurfaceGui") and not gui:IsA("BillboardGui") then continue end

		for _, stroke in next, gui:GetDescendants() do
			if not stroke:IsA("UIStroke") then continue end

			self:_registerStroke(stroke)
		end
	end
end

function UIStrokeAdjuster:_registerStroke(stroke)
	if not stroke:IsA("UIStroke") then return end
	if self:getStrokePosition(stroke) then return end
	
	local screenGui = stroke:FindFirstAncestorWhichIsA("ScreenGui")
	local surfaceGui = stroke:FindFirstAncestorWhichIsA("SurfaceGui")
	local billboardGui = stroke:FindFirstAncestorWhichIsA("BillboardGui")
	if not billboardGui and not screenGui and not surfaceGui then return end
	
	local strokeData = {
		gui = screenGui or billboardGui or surfaceGui,
		stroke = stroke,
		originalThickness = stroke.Thickness
	}

	table.insert(self._strokes, strokeData)
end

function UIStrokeAdjuster:_initialize()
	self._uiStrokeAddedConnection1 = self._playerGui.DescendantAdded:Connect(function(stroke)
		self:_registerStroke(stroke)
	end)
	
	self._uiStrokeAddedConnection2 = workspace.DescendantAdded:Connect(function(stroke)
		self:_registerStroke(stroke)
	end)
	
	self._uiStrokeRemovingConnection1 = self._playerGui.DescendantRemoving:Connect(function(stroke)
		if not stroke:IsA("UIStroke") then return end
		
		local position = self:getStrokePosition(stroke)
		if position then
			table.remove(self._strokes, position)
		end
	end)
	
	self._uiStrokeRemovingConnection2 = workspace.DescendantRemoving:Connect(function(stroke)
		if not stroke:IsA("UIStroke") then return end

		local position = self:getStrokePosition(stroke)
		if position then
			table.remove(self._strokes, position)
		end
	end)
	
	self._heartbeatConnection = RunService.PostSimulation:Connect(function()
		self:_registerStrokes()
		
		for _, strokeData in next, self._strokes do
			local originalThickness = strokeData.originalThickness
			local isBillboardGui = strokeData.gui:IsA("BillboardGui")
			
			if isBillboardGui and strokeData.gui.Parent then
				local adornee = strokeData.gui.Adornee
				
				local position = adornee and self:getInstancePosition(adornee) or self:getInstancePosition(strokeData.gui.Parent)
				local magnitude = (self._camera.CFrame.Position - position).Magnitude
				
				local ratio = (strokeData.gui:GetAttribute("Distance") or self._billboardGuiDistance) / magnitude
				
				strokeData.stroke.Thickness = originalThickness * ratio * self:getScreenRatio()
			else
				strokeData.stroke.Thickness = originalThickness * self:getScreenRatio()
			end
		end
	end)
end

return UIStrokeAdjuster.new()
