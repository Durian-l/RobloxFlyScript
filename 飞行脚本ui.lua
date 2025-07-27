-- FlyControllerUI ModuleScript
-- 封装所有UI相关逻辑，供主控制器调用
local FlyControllerUI = {}

local UserInputService = game:GetService("UserInputService")

-- UI自适应缩放
function FlyControllerUI.applyUIScale(rootGui)
	if not rootGui then return end
	local absSize = rootGui.AbsoluteSize or Vector2.new(800,600)
	local baseW, baseH = 800, 600
	local scaleX = absSize.X / baseW
	local scaleY = absSize.Y / baseH

	local function scaleUI(obj)
		if obj:IsA("Frame") or obj:IsA("TextLabel") or obj:IsA("TextButton") or obj:IsA("TextBox") or obj:IsA("ImageLabel") or obj:IsA("ImageButton") then
			local sz = obj.Size
			obj.Size = UDim2.new(
				sz.X.Scale,
				math.floor(sz.X.Offset * scaleX + 0.5),
				sz.Y.Scale,
				math.floor(sz.Y.Offset * scaleY + 0.5)
			)
			local pos = obj.Position
			obj.Position = UDim2.new(
				pos.X.Scale,
				math.floor(pos.X.Offset * scaleX + 0.5),
				pos.Y.Scale,
				math.floor(pos.Y.Offset * scaleY + 0.5)
			)
			if obj:IsA("TextLabel") or obj:IsA("TextButton") or obj:IsA("TextBox") then
				if obj.TextSize then
					obj.TextSize = math.floor(obj.TextSize * ((scaleX+scaleY)/2))
				end
			end
		end
		for _, child in obj:GetChildren() do
			scaleUI(child)
		end
	end
	scaleUI(rootGui)
end

-- 调试窗口UI
function FlyControllerUI.createDebugUI(player, state)
	-- state: {flying, flySpeed, moveDir, lastToggleTime, toggleCooldown, debugCooldown, debugKey, debugAutoRefresh}
	if not player then return end
	if state._debugGui then
		state._debugGui.Enabled = true
		FlyControllerUI.updateDebugFrameLayout(state)
		FlyControllerUI.refreshDebugUI(state)
		return
	end
	local debugGui = Instance.new("ScreenGui")
	debugGui.Name = "FlyDebugGui"
	debugGui.ResetOnSpawn = false
	debugGui.IgnoreGuiInset = true
	debugGui.Parent = player:WaitForChild("PlayerGui")
	state._debugGui = debugGui

	local debugFrame = Instance.new("Frame")
	debugFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
	debugFrame.BorderSizePixel = 0
	debugFrame.Parent = debugGui
	state._debugFrame = debugFrame

	-- 标题
	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, 0, 0, 32)
	title.Position = UDim2.new(0, 0, 0, 0)
	title.BackgroundTransparency = 1
	title.Text = "飞行控制调试窗口"
	title.TextColor3 = Color3.new(1,1,0.3)
	title.Font = Enum.Font.SourceSansBold
	title.TextSize = 22
	title.Parent = debugFrame

	FlyControllerUI.updateDebugFrameLayout(state)
	FlyControllerUI.refreshDebugUI(state)
	FlyControllerUI.startDebugAutoRefresh(state)

	debugGui:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
		FlyControllerUI.updateDebugFrameLayout(state)
		FlyControllerUI.refreshDebugUI(state)
	end)
end

function FlyControllerUI.refreshDebugUI(state)
	local debugFrame = state._debugFrame
	if not debugFrame then return end
	for _, child in debugFrame:GetChildren() do
		if child:IsA("TextLabel") or child:IsA("TextBox") then
			child:Destroy()
		end
	end
	local frameW = debugFrame.AbsoluteSize.X
	local labelWidth = math.max(frameW - 40, 180)
	local labelHeight = 28
	local y = 42

	local function addLabel(text)
		local lbl = Instance.new("TextLabel")
		lbl.Size = UDim2.new(0, labelWidth, 0, labelHeight)
		lbl.Position = UDim2.new(0, 10, 0, y)
		lbl.BackgroundTransparency = 1
		lbl.Text = text
		lbl.TextColor3 = Color3.new(1,1,1)
		lbl.TextXAlignment = Enum.TextXAlignment.Left
		lbl.Font = Enum.Font.SourceSans
		lbl.TextSize = 20
		lbl.Parent = debugFrame
		y = y + labelHeight + 2
		return lbl
	end

	addLabel("飞行状态: " .. (state.flying and "飞行中" or "未飞行"))

	-- 飞行速度
	local flySpeedLabel = Instance.new("TextLabel")
	flySpeedLabel.Size = UDim2.new(0, labelWidth-60, 0, labelHeight)
	flySpeedLabel.Position = UDim2.new(0, 10, 0, y)
	flySpeedLabel.BackgroundTransparency = 1
	flySpeedLabel.Text = "飞行速度:"
	flySpeedLabel.TextColor3 = Color3.new(1,1,1)
	flySpeedLabel.TextXAlignment = Enum.TextXAlignment.Left
	flySpeedLabel.Font = Enum.Font.SourceSans
	flySpeedLabel.TextSize = 20
	flySpeedLabel.Parent = debugFrame

	local flySpeedBox = Instance.new("TextBox")
	flySpeedBox.Size = UDim2.new(0, 60, 0, labelHeight)
	flySpeedBox.Position = UDim2.new(0, 10 + labelWidth-60, 0, y)
	flySpeedBox.BackgroundColor3 = Color3.fromRGB(40,40,40)
	flySpeedBox.Text = tostring(state.flySpeed)
	flySpeedBox.TextColor3 = Color3.new(1,1,0.6)
	flySpeedBox.Font = Enum.Font.SourceSans
	flySpeedBox.TextSize = 20
	flySpeedBox.ClearTextOnFocus = false
	flySpeedBox.Parent = debugFrame
	flySpeedBox.FocusLost:Connect(function(enter)
		if enter then
			local v = tonumber(flySpeedBox.Text)
			if v and v > 0 then
				state.flySpeed = v
				flySpeedBox.Text = tostring(state.flySpeed)
			else
				flySpeedBox.Text = tostring(state.flySpeed)
			end
		end
	end)
	y = y + labelHeight + 2

	addLabel("方向状态: "..string.format(
		"前:%s 后:%s 左:%s 右:%s 上:%s 下:%s",
		tostring(state.moveDir.forward), tostring(state.moveDir.back),
		tostring(state.moveDir.left), tostring(state.moveDir.right),
		tostring(state.moveDir.up), tostring(state.moveDir.down)
	))

	addLabel("上次切换时间: " .. string.format("%.2f", state.lastToggleTime))

	-- 切换冷却
	local toggleCooldownLabel = Instance.new("TextLabel")
	toggleCooldownLabel.Size = UDim2.new(0, labelWidth-60, 0, labelHeight)
	toggleCooldownLabel.Position = UDim2.new(0, 10, 0, y)
	toggleCooldownLabel.BackgroundTransparency = 1
	toggleCooldownLabel.Text = "切换冷却(秒):"
	toggleCooldownLabel.TextColor3 = Color3.new(1,1,1)
	toggleCooldownLabel.TextXAlignment = Enum.TextXAlignment.Left
	toggleCooldownLabel.Font = Enum.Font.SourceSans
	toggleCooldownLabel.TextSize = 20
	toggleCooldownLabel.Parent = debugFrame

	local toggleCooldownBox = Instance.new("TextBox")
	toggleCooldownBox.Size = UDim2.new(0, 60, 0, labelHeight)
	toggleCooldownBox.Position = UDim2.new(0, 10 + labelWidth-60, 0, y)
	toggleCooldownBox.BackgroundColor3 = Color3.fromRGB(40,40,40)
	toggleCooldownBox.Text = tostring(state.toggleCooldown)
	toggleCooldownBox.TextColor3 = Color3.new(1,1,0.6)
	toggleCooldownBox.Font = Enum.Font.SourceSans
	toggleCooldownBox.TextSize = 20
	toggleCooldownBox.ClearTextOnFocus = false
	toggleCooldownBox.Parent = debugFrame
	toggleCooldownBox.FocusLost:Connect(function(enter)
		if enter then
			local v = tonumber(toggleCooldownBox.Text)
			if v and v >= 1 then
				state.toggleCooldown = v
				toggleCooldownBox.Text = tostring(state.toggleCooldown)
			else
				toggleCooldownBox.Text = tostring(state.toggleCooldown)
			end
		end
	end)
	y = y + labelHeight + 2

	-- 调试冷却
	local debugCooldownLabel = Instance.new("TextLabel")
	debugCooldownLabel.Size = UDim2.new(0, labelWidth-60, 0, labelHeight)
	debugCooldownLabel.Position = UDim2.new(0, 10, 0, y)
	debugCooldownLabel.BackgroundTransparency = 1
	debugCooldownLabel.Text = "调试冷却(秒):"
	debugCooldownLabel.TextColor3 = Color3.new(1,1,1)
	debugCooldownLabel.TextXAlignment = Enum.TextXAlignment.Left
	debugCooldownLabel.Font = Enum.Font.SourceSans
	debugCooldownLabel.TextSize = 20
	debugCooldownLabel.Parent = debugFrame

	local debugCooldownBox = Instance.new("TextBox")
	debugCooldownBox.Size = UDim2.new(0, 60, 0, labelHeight)
	debugCooldownBox.Position = UDim2.new(0, 10 + labelWidth-60, 0, y)
	debugCooldownBox.BackgroundColor3 = Color3.fromRGB(40,40,40)
	debugCooldownBox.Text = tostring(state.debugCooldown)
	debugCooldownBox.TextColor3 = Color3.new(1,1,0.6)
	debugCooldownBox.Font = Enum.Font.SourceSans
	debugCooldownBox.TextSize = 20
	debugCooldownBox.ClearTextOnFocus = false
	debugCooldownBox.Parent = debugFrame
	debugCooldownBox.FocusLost:Connect(function(enter)
		if enter then
			local v = tonumber(debugCooldownBox.Text)
			if v and v >= 1 then
				state.debugCooldown = v
				debugCooldownBox.Text = tostring(state.debugCooldown)
			else
				debugCooldownBox.Text = tostring(state.debugCooldown)
			end
		end
	end)
	y = y + labelHeight + 2

	-- 调试快捷键
	local debugKeyLabel = Instance.new("TextLabel")
	debugKeyLabel.Size = UDim2.new(0, labelWidth-60, 0, labelHeight)
	debugKeyLabel.Position = UDim2.new(0, 10, 0, y)
	debugKeyLabel.BackgroundTransparency = 1
	debugKeyLabel.Text = "调试快捷键:"
	debugKeyLabel.TextColor3 = Color3.new(1,1,1)
	debugKeyLabel.TextXAlignment = Enum.TextXAlignment.Left
	debugKeyLabel.Font = Enum.Font.SourceSans
	debugKeyLabel.TextSize = 20
	debugKeyLabel.Parent = debugFrame

	local debugKeyBox = Instance.new("TextBox")
	debugKeyBox.Size = UDim2.new(0, 60, 0, labelHeight)
	debugKeyBox.Position = UDim2.new(0, 10 + labelWidth-60, 0, y)
	debugKeyBox.BackgroundColor3 = Color3.fromRGB(40,40,40)
	debugKeyBox.Text = tostring(state.debugKey.Name)
	debugKeyBox.TextColor3 = Color3.new(1,1,0.6)
	debugKeyBox.Font = Enum.Font.SourceSans
	debugKeyBox.TextSize = 20
	debugKeyBox.ClearTextOnFocus = false
	debugKeyBox.Parent = debugFrame
	debugKeyBox.FocusLost:Connect(function(enter)
		if enter then
			local inputText = debugKeyBox.Text
			local success, newKey = pcall(function()
				return Enum.KeyCode[inputText]
			end)
			if success and typeof(newKey) == "EnumItem" then
				state.debugKey = newKey
				debugKeyBox.Text = state.debugKey.Name
			else
				debugKeyBox.Text = state.debugKey.Name
			end
		end
	end)
	y = y + labelHeight + 2

	-- 刷新按钮
	local refreshBtn = Instance.new("TextButton")
	refreshBtn.Size = UDim2.new(0, 80, 0, labelHeight)
	refreshBtn.Position = UDim2.new(0, 10, 0, y)
	refreshBtn.BackgroundColor3 = Color3.fromRGB(60, 120, 200)
	refreshBtn.Text = "刷新"
	refreshBtn.TextColor3 = Color3.new(1,1,1)
	refreshBtn.Font = Enum.Font.SourceSansBold
	refreshBtn.TextSize = 20
	refreshBtn.Parent = debugFrame
	refreshBtn.MouseButton1Click:Connect(function()
		FlyControllerUI.refreshDebugUI(state)
	end)

	-- 关闭按钮
	local closeBtn = Instance.new("TextButton")
	closeBtn.Size = UDim2.new(0, 80, 0, labelHeight)
	closeBtn.Position = UDim2.new(0, 100, 0, y)
	closeBtn.BackgroundColor3 = Color3.fromRGB(180, 60, 60)
	closeBtn.Text = "关闭"
	closeBtn.TextColor3 = Color3.new(1,1,1)
	closeBtn.Font = Enum.Font.SourceSansBold
	closeBtn.TextSize = 20
	closeBtn.Parent = debugFrame
	closeBtn.MouseButton1Click:Connect(function()
		if state._debugGui then
			state._debugGui.Enabled = false
		end
	end)
end

function FlyControllerUI.updateDebugFrameLayout(state)
	local debugFrame = state._debugFrame
	local debugGui = state._debugGui
	if not debugFrame or not debugGui then return end
	local absSize = debugGui.AbsoluteSize
	local screenW = absSize.X
	local screenH = absSize.Y
	local minW, minH = 240, 320
	local maxW, maxH = 480, 600
	local frameW = math.clamp(math.floor(screenW * 0.35), minW, maxW)
	local frameH = math.clamp(math.floor(screenH * 0.5), minH, maxH)
	debugFrame.Size = UDim2.new(0, frameW, 0, frameH)
	debugFrame.Position = UDim2.new(0.5, -frameW//2, 0.2, 0)
end

function FlyControllerUI.startDebugAutoRefresh(state)
	if state.debugAutoRefresh then return end
	state.debugAutoRefresh = true
	task.spawn(function()
		while state.debugAutoRefresh do
			task.wait(1)
			if state._debugGui and state._debugGui.Enabled and state._debugFrame then
				FlyControllerUI.refreshDebugUI(state)
			end
		end
	end)
end

function FlyControllerUI.stopDebugAutoRefresh(state)
	state.debugAutoRefresh = false
end

-- 手机端虚拟按钮
function FlyControllerUI.createTouchUI(player, state, toggleFlyCallback)
	if not player then return end
	local gui = Instance.new("ScreenGui")
	gui.Name = "FlyTouchGui"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.Parent = player:WaitForChild("PlayerGui")
	state._touchGui = gui

	local btnSize = UDim2.new(0, 60, 0, 60)
	local bottomY = 0.7

	local flyBtn = Instance.new("TextButton")
	flyBtn.Size = btnSize
	flyBtn.Position = UDim2.new(0.85, 0, bottomY, 0)
	flyBtn.BackgroundColor3 = Color3.fromRGB(80, 120, 200)
	flyBtn.Text = "飞行"
	flyBtn.TextColor3 = Color3.new(1,1,1)
	flyBtn.TextSize = 22
	flyBtn.Font = Enum.Font.SourceSansBold
	flyBtn.Parent = gui

	flyBtn.MouseButton1Click:Connect(function()
		local now = os.clock()
		if now - state.lastToggleTime < state.toggleCooldown then
			return
		end
		state.lastToggleTime = now
		if toggleFlyCallback then toggleFlyCallback() end
		if state.flying then
			flyBtn.BackgroundColor3 = Color3.fromRGB(120, 200, 80)
			flyBtn.Text = "飞行中"
		else
			flyBtn.BackgroundColor3 = Color3.fromRGB(80, 120, 200)
			flyBtn.Text = "飞行"
		end
	end)

	local debugBtn = Instance.new("TextButton")
	debugBtn.Size = UDim2.new(0, 60, 0, 60)
	debugBtn.Position = UDim2.new(0.85, 0, bottomY-0.13, 0)
	debugBtn.BackgroundColor3 = Color3.fromRGB(200, 180, 60)
	debugBtn.Text = "调试"
	debugBtn.TextColor3 = Color3.new(0,0,0)
	debugBtn.TextSize = 22
	debugBtn.Font = Enum.Font.SourceSansBold
	debugBtn.Parent = gui

	debugBtn.MouseButton1Click:Connect(function()
		local now = os.clock()
		if now - state.lastDebugTime < state.debugCooldown then
			return
		end
		state.lastDebugTime = now
		FlyControllerUI.createDebugUI(player, state)
	end)

	local function createDirBtn(name, pos, dirKey)
		local btn = Instance.new("TextButton")
		btn.Size = UDim2.new(0, 48, 0, 48)
		btn.Position = pos
		btn.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
		btn.Text = name
		btn.TextColor3 = Color3.new(1,1,1)
		btn.TextSize = 20
		btn.Font = Enum.Font.SourceSansBold
		btn.Parent = gui

		btn.MouseButton1Down:Connect(function()
			state.moveDir[dirKey] = true
		end)
		btn.MouseButton1Up:Connect(function()
			state.moveDir[dirKey] = false
		end)
	end

	local baseX = 0.08
	local baseY = 0.7
	createDirBtn("前", UDim2.new(baseX+0.07, 0, baseY, 0), "forward")
	createDirBtn("后", UDim2.new(baseX+0.07, 0, baseY+0.12, 0), "back")
	createDirBtn("左", UDim2.new(baseX, 0, baseY+0.06, 0), "left")
	createDirBtn("右", UDim2.new(baseX+0.14, 0, baseY+0.06, 0), "right")
	createDirBtn("上", UDim2.new(baseX+0.22, 0, baseY, 0), "up")
	createDirBtn("下", UDim2.new(baseX+0.22, 0, baseY+0.12, 0), "down")

	FlyControllerUI.applyUIScale(gui)
end

return FlyControllerUI


