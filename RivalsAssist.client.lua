-- RIVALS ASSIST | Luau / cliente
-- Aimbot de camera, ESP e painel animado, sem bibliotecas externas.
-- Usa Players.Character, Humanoid, Head e HumanoidRootPart padrao.
-- Nao foi testado no RIVALS e nao inclui integracao especifica com o jogo.
-- No Roblox Studio: LocalScript em StarterPlayer > StarterPlayerScripts.
-- Controles: ative Aimbot para mirar automaticamente; Shift direito = painel.
-- Desative Mira automatica para usar o botao direito; X do painel = encerrar.

if not game:IsLoaded() then game.Loaded:Wait() end

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Input = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")
local Workspace = game:GetService("Workspace")
local player = Players.LocalPlayer
assert(player, "Este script precisa executar no cliente.")
local playerGui = player:WaitForChild("PlayerGui")

local config = {
    aim = false,
    autoAim = true, -- Acompanha alvos sem segurar um botao quando Aimbot esta ligado.
    esp = false,
    teams = true,
    visibility = true,
    circle = true,
    fov = 140, -- Raio em pixels, medido a partir do centro da tela.
    smoothing = 8, -- 1 = resposta rapida; 20 = resposta suave.
    maxDistance = 3000, -- Studs.
}

local old = playerGui:FindFirstChild("RivalsAssist")
if old then old:Destroy() end

local colors = {
    panel = Color3.fromRGB(18, 22, 32),
    row = Color3.fromRGB(28, 33, 46),
    hover = Color3.fromRGB(35, 41, 56),
    accent = Color3.fromRGB(99, 220, 191),
    enemy = Color3.fromRGB(255, 113, 131),
    text = Color3.fromRGB(239, 243, 250),
    muted = Color3.fromRGB(154, 165, 186),
}

local connections, entries = {}, {}
local animations = setmetatable({}, { __mode = "k" })
local stopped, holdingMouse, holdingTouch = false, false, false
local windowFocused = true
local touchAimInput, drag, activeSlider
local renderName = "RivalsAssist_" .. HttpService:GenerateGUID(false)
local PANEL_WIDTH, PANEL_HEIGHT = 352, 486

local function create(class, properties, parent)
    local object = Instance.new(class)
    for key, value in pairs(properties or {}) do object[key] = value end
    object.Parent = parent
    return object
end

local function connect(signal, callback)
    local connection = signal:Connect(callback)
    table.insert(connections, connection)
    return connection
end

local function animate(object, properties, duration)
    if animations[object] then animations[object]:Cancel() end
    local animation = TweenService:Create(object,
        TweenInfo.new(duration or 0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), properties)
    animations[object] = animation
    animation:Play()
    return animation
end

local function corner(object, radius)
    create("UICorner", { CornerRadius = UDim.new(0, radius or 10) }, object)
end

local function text(parent, content, position, size, fontSize, color)
    return create("TextLabel", {
        BackgroundTransparency = 1, Text = content, Position = position, Size = size,
        Font = Enum.Font.Gotham, TextSize = fontSize or 13,
        TextColor3 = color or colors.text, TextXAlignment = Enum.TextXAlignment.Left,
    }, parent)
end

local gui = create("ScreenGui", {
    Name = "RivalsAssist", ResetOnSpawn = false, IgnoreGuiInset = true,
    ScreenInsets = Enum.ScreenInsets.None,
    DisplayOrder = 50, ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
}, playerGui)
local visuals = create("Folder", { Name = renderName }, Workspace)

local function removeEntry(other)
    local entry = entries[other]
    if not entry then return end
    entry.highlight:Destroy()
    entry.billboard:Destroy()
    entries[other] = nil
end

local function cleanup(alreadyDestroying)
    if stopped then return end
    stopped = true
    RunService:UnbindFromRenderStep(renderName)
    for _, connection in ipairs(connections) do connection:Disconnect() end
    for _, animation in pairs(animations) do animation:Cancel() end
    for other in pairs(entries) do removeEntry(other) end
    visuals:Destroy()
    if not alreadyDestroying then gui:Destroy() end
end
connect(gui.Destroying, function() cleanup(true) end)

local ring = create("Frame", {
    Name = "FOV", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5),
    Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(280, 280), Visible = false,
}, gui)
create("UICorner", { CornerRadius = UDim.new(1, 0) }, ring)
local ringStroke = create("UIStroke", {
    Color = colors.accent, Thickness = 1, Transparency = 0.35,
}, ring)

local panel = create("CanvasGroup", {
    Name = "Panel", BackgroundColor3 = colors.panel, BorderSizePixel = 0,
    Position = UDim2.fromOffset(24, 100), Size = UDim2.fromOffset(PANEL_WIDTH, PANEL_HEIGHT),
    GroupTransparency = 1, Active = true,
}, gui)
corner(panel, 14)
create("UIStroke", { Color = Color3.fromRGB(61, 75, 94), Thickness = 1 }, panel)
local scale = create("UIScale", { Scale = 0.94 }, panel)
local header = create("Frame", {
    BackgroundTransparency = 1, Size = UDim2.new(1, -52, 0, 62), Active = true,
}, panel)
local title = text(header, "RIVALS / ASSIST", UDim2.fromOffset(18, 14), UDim2.fromOffset(250, 22), 17)
title.Font = Enum.Font.GothamBold
text(header, "MIRA  +  ESP", UDim2.fromOffset(18, 38), UDim2.fromOffset(240, 14), 10, colors.accent)

local close = create("TextButton", {
    Text = "X", Font = Enum.Font.GothamBold, TextSize = 14, TextColor3 = colors.muted,
    BackgroundColor3 = colors.row, BorderSizePixel = 0, AutoButtonColor = false,
    Position = UDim2.new(1, -44, 0, 14), Size = UDim2.fromOffset(28, 28),
}, panel)
corner(close, 8)
connect(close.Activated, function() cleanup(false) end)

local body = create("Frame", {
    BackgroundTransparency = 1, Position = UDim2.fromOffset(18, 70),
    Size = UDim2.new(1, -36, 0, 348),
}, panel)
create("UIListLayout", {
    Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder,
}, body)

local function toggle(label, key, order)
    local row = create("TextButton", {
        Text = "", BackgroundColor3 = colors.row, BorderSizePixel = 0,
        AutoButtonColor = false, Size = UDim2.new(1, 0, 0, 34), LayoutOrder = order,
    }, body)
    corner(row, 8)
    text(row, label, UDim2.fromOffset(12, 0), UDim2.new(1, -70, 1, 0), 12)
    local track = create("Frame", {
        BorderSizePixel = 0, Size = UDim2.fromOffset(32, 18),
        Position = UDim2.new(1, -44, 0.5, -9),
    }, row)
    corner(track, 9)
    local dot = create("Frame", {
        BackgroundColor3 = colors.text, BorderSizePixel = 0,
        Size = UDim2.fromOffset(12, 12),
    }, track)
    corner(dot, 6)
    local function update(animated)
        local enabled = config[key]
        local trackProperties = { BackgroundColor3 = enabled and colors.accent or Color3.fromRGB(61, 69, 86) }
        local dotProperties = { Position = UDim2.fromOffset(enabled and 17 or 3, 3) }
        if animated then
            animate(track, trackProperties)
            animate(dot, dotProperties)
        else
            track.BackgroundColor3 = trackProperties.BackgroundColor3
            dot.Position = dotProperties.Position
        end
    end
    update(false)
    connect(row.Activated, function() config[key] = not config[key]; update(true) end)
    connect(row.MouseEnter, function() animate(row, { BackgroundColor3 = colors.hover }) end)
    connect(row.MouseLeave, function() animate(row, { BackgroundColor3 = colors.row }) end)
end

toggle("Aimbot", "aim", 1)
toggle("Mira automatica (sem segurar)", "autoAim", 2)
toggle("ESP: contorno e nome", "esp", 3)
toggle("Ignorar mesma equipe", "teams", 4)
toggle("Mira: verificar paredes", "visibility", 5)
toggle("Mostrar circulo de FOV", "circle", 6)

local function slider(label, key, minimum, maximum, order, suffix)
    local row = create("Frame", {
        BackgroundColor3 = colors.row, BorderSizePixel = 0,
        Size = UDim2.new(1, 0, 0, 50), LayoutOrder = order,
    }, body)
    corner(row, 8)
    text(row, label, UDim2.fromOffset(12, 6), UDim2.new(1, -90, 0, 18), 12)
    local valueText = text(row, "", UDim2.new(1, -82, 0, 6), UDim2.fromOffset(70, 18), 12, colors.accent)
    valueText.TextXAlignment = Enum.TextXAlignment.Right
    local hit = create("TextButton", {
        Text = "", BackgroundTransparency = 1, AutoButtonColor = false,
        Position = UDim2.fromOffset(12, 27), Size = UDim2.new(1, -24, 0, 20),
    }, row)
    local bar = create("Frame", {
        BackgroundColor3 = Color3.fromRGB(57, 65, 82), BorderSizePixel = 0,
        Position = UDim2.fromOffset(0, 8), Size = UDim2.new(1, 0, 0, 4),
    }, hit)
    corner(bar, 2)
    local fill = create("Frame", { BackgroundColor3 = colors.accent, BorderSizePixel = 0 }, bar)
    corner(fill, 2)
    local knob = create("Frame", {
        BackgroundColor3 = colors.text, BorderSizePixel = 0, AnchorPoint = Vector2.new(0.5, 0.5),
        Size = UDim2.fromOffset(10, 10),
    }, bar)
    corner(knob, 5)
    local function refresh()
        local ratio = (config[key] - minimum) / (maximum - minimum)
        fill.Size = UDim2.fromScale(ratio, 1)
        knob.Position = UDim2.fromScale(ratio, 0.5)
        valueText.Text = tostring(config[key]) .. (suffix or "")
    end
    local function update(x)
        local ratio = math.clamp((x - hit.AbsolutePosition.X) / math.max(hit.AbsoluteSize.X, 1), 0, 1)
        config[key] = math.floor(minimum + (maximum - minimum) * ratio + 0.5)
        refresh()
    end
    refresh()
    connect(hit.InputBegan, function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            activeSlider = { input = input, update = update }
            update(input.Position.X)
        end
    end)
end

slider("Campo de visao", "fov", 40, 400, 7, " px")
slider("Suavidade", "smoothing", 1, 20, 8)

local status = text(panel, "Aimbot desligado", UDim2.fromOffset(18, 434), UDim2.new(1, -36, 0, 18), 12, colors.accent)
text(panel, "Mira automatica: sem segurar  /  Shift direito: painel", UDim2.fromOffset(18, 457), UDim2.new(1, -36, 0, 14), 10, colors.muted)

local opener = create("TextButton", {
    Text = "R", Font = Enum.Font.GothamBold, TextSize = 17, TextColor3 = colors.panel,
    BackgroundColor3 = colors.accent, BorderSizePixel = 0, AutoButtonColor = false,
    Position = UDim2.fromOffset(14, 70), Size = UDim2.fromOffset(38, 38),
}, gui)
corner(opener, 12)

local touchAim = create("TextButton", {
    Text = "SEGURAR\nMIRA", Font = Enum.Font.GothamBold, TextSize = 12,
    TextColor3 = colors.text, BackgroundColor3 = colors.row, BorderSizePixel = 0,
    AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -28, 1, -150),
    Size = UDim2.fromOffset(76, 54), Visible = Input.TouchEnabled,
}, gui)
corner(touchAim, 12)
connect(touchAim.InputBegan, function(input)
    if input.UserInputType == Enum.UserInputType.Touch then
        touchAimInput = input
        holdingTouch = true
    end
end)

local opened, openVersion, uiScale = true, 0, 1
local function fitPanel()
    local camera = Workspace.CurrentCamera
    if not camera then return end
    local view = camera.ViewportSize
    uiScale = math.min(1, (view.X - 24) / PANEL_WIDTH, (view.Y - 100) / PANEL_HEIGHT)
    uiScale = math.max(uiScale, 0.1)
    if animations[scale] then animations[scale]:Cancel() end
    scale.Scale = uiScale
    local x = math.clamp(panel.Position.X.Offset, 12, math.max(12, view.X - PANEL_WIDTH * uiScale - 12))
    local y = math.clamp(panel.Position.Y.Offset, 54, math.max(54, view.Y - PANEL_HEIGHT * uiScale - 12))
    panel.Position = UDim2.fromOffset(x, y)
end

local function showPanel(value)
    opened = value
    openVersion = openVersion + 1
    local version = openVersion
    if not value then activeSlider, drag = nil, nil end
    panel.Visible = true
    animate(panel, { GroupTransparency = value and 0 or 1 }, 0.2)
    animate(scale, { Scale = uiScale * (value and 1 or 0.94) }, 0.2)
    task.delay(0.21, function()
        if not stopped and version == openVersion then panel.Visible = value end
    end)
end
connect(opener.Activated, function() showPanel(not opened) end)

connect(header.InputBegan, function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        drag = { input = input, start = Vector2.new(input.Position.X, input.Position.Y), position = panel.Position }
    end
end)

connect(Input.InputBegan, function(input, processed)
    if processed or Input:GetFocusedTextBox() then return end
    if input.KeyCode == Enum.KeyCode.RightShift then showPanel(not opened) end
    if input.UserInputType == Enum.UserInputType.MouseButton2 then holdingMouse = true end
end)
connect(Input.InputChanged, function(input)
    local mouse = input.UserInputType == Enum.UserInputType.MouseMovement
    if activeSlider and ((mouse and activeSlider.input.UserInputType == Enum.UserInputType.MouseButton1) or input == activeSlider.input) then
        activeSlider.update(input.Position.X)
    end
    if drag and ((mouse and drag.input.UserInputType == Enum.UserInputType.MouseButton1) or input == drag.input) then
        local delta = Vector2.new(input.Position.X, input.Position.Y) - drag.start
        local camera = Workspace.CurrentCamera
        if camera then
            local view = camera.ViewportSize
            panel.Position = UDim2.fromOffset(
                math.clamp(drag.position.X.Offset + delta.X, 12, math.max(12, view.X - PANEL_WIDTH * uiScale - 12)),
                math.clamp(drag.position.Y.Offset + delta.Y, 54, math.max(54, view.Y - PANEL_HEIGHT * uiScale - 12)))
        end
    end
end)
connect(Input.InputEnded, function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton2 then holdingMouse = false end
    if input == touchAimInput then holdingTouch = false; touchAimInput = nil end
    if activeSlider and input == activeSlider.input then activeSlider = nil end
    if drag and input == drag.input then drag = nil end
end)
connect(Input.WindowFocusReleased, function()
    windowFocused = false
    holdingMouse, holdingTouch = false, false
    touchAimInput, activeSlider, drag = nil, nil, nil
end)
connect(Input.WindowFocused, function() windowFocused = true end)
connect(player.CharacterRemoving, function()
    holdingMouse, holdingTouch = false, false
    touchAimInput = nil
end)
connect(Players.PlayerRemoving, removeEntry)

local function sameTeam(other)
    return config.teams and not player.Neutral and not other.Neutral
        and player.Team ~= nil and player.Team == other.Team
end

local function characterParts(other)
    local character = other.Character
    if not character or not character.Parent then return nil end
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    local root = character:FindFirstChild("HumanoidRootPart")
    local head = character:FindFirstChild("Head")
    local aimPart = head or root
    if not humanoid or humanoid.Health <= 0 or not root or not aimPart then return nil end
    if not root:IsA("BasePart") or not aimPart:IsA("BasePart") then return nil end
    return character, root, aimPart
end

local function entryFor(other, character, aimPart)
    local entry = entries[other]
    if entry and entry.character ~= character then removeEntry(other); entry = nil end
    if entry then
        entry.billboard.Adornee = aimPart
        return entry
    end
    local highlight = create("Highlight", {
        Adornee = character, Enabled = false, DepthMode = Enum.HighlightDepthMode.AlwaysOnTop,
        FillColor = colors.enemy, OutlineColor = colors.enemy,
        FillTransparency = 0.8, OutlineTransparency = 0.05,
    }, visuals)
    local billboard = create("BillboardGui", {
        Adornee = aimPart, Enabled = false, AlwaysOnTop = true,
        Size = UDim2.fromOffset(180, 38), StudsOffsetWorldSpace = Vector3.new(0, 2, 0),
        MaxDistance = config.maxDistance,
    }, gui)
    local label = text(billboard, "", UDim2.fromScale(0, 0), UDim2.fromScale(1, 1), 12)
    label.TextXAlignment = Enum.TextXAlignment.Center
    label.TextStrokeTransparency = 0.25
    label.Font = Enum.Font.GothamBold
    entry = { character = character, highlight = highlight, billboard = billboard, label = label }
    entries[other] = entry
    return entry
end

local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude
rayParams.IgnoreWater = true

local function visible(camera, character, position)
    if not config.visibility then return true end
    local excluded = { camera, visuals }
    if player.Character then table.insert(excluded, player.Character) end
    rayParams.FilterDescendantsInstances = excluded
    local origin = camera.CFrame.Position
    local hit = Workspace:Raycast(origin, position - origin, rayParams)
    return not hit or hit.Instance:IsDescendantOf(character)
end

local espClock, lastViewport = 0, Vector2.zero
RunService:BindToRenderStep(renderName, Enum.RenderPriority.Camera.Value + 1, function(dt)
    if stopped then return end
    local camera = Workspace.CurrentCamera
    if not camera then return end
    if camera.ViewportSize ~= lastViewport then
        lastViewport = camera.ViewportSize
        fitPanel()
    end
    ring.Visible = config.aim and config.circle
    ring.Size = UDim2.fromOffset(config.fov * 2, config.fov * 2)
    touchAim.Visible = Input.TouchEnabled and config.aim and not config.autoAim

    local localCharacter, localRoot = characterParts(player)
    local aiming = config.aim and windowFocused and localCharacter ~= nil and not Input:GetFocusedTextBox()
        and (config.autoAim or holdingMouse or holdingTouch)
    local center = camera.ViewportSize * 0.5
    local nearestDistance, targetPart, targetPlayer = config.fov, nil, nil

    espClock = espClock + dt
    local updateESP = espClock >= 0.1
    if updateESP then espClock = 0 end
    if not config.esp then
        for other in pairs(entries) do removeEntry(other) end
    end

    if aiming or (config.esp and updateESP) then
        for _, other in ipairs(Players:GetPlayers()) do
            if other == player then continue end
            local character, root, aimPart = characterParts(other)
            local origin = localRoot and localRoot.Position or camera.CFrame.Position
            local distance = root and (root.Position - origin).Magnitude or math.huge
            local eligible = character ~= nil and not sameTeam(other) and distance <= config.maxDistance
            if config.esp and updateESP then
                if eligible then
                    local entry = entryFor(other, character, aimPart)
                    entry.highlight.Enabled = true
                    entry.billboard.Enabled = true
                    entry.label.Text = other.DisplayName .. "\n" .. tostring(math.floor(distance)) .. " studs"
                else
                    removeEntry(other)
                end
            end
            if aiming and eligible then
                local point, onScreen = camera:WorldToViewportPoint(aimPart.Position)
                if onScreen and point.Z > 0 then
                    local distanceToCenter = (Vector2.new(point.X, point.Y) - center).Magnitude
                    if distanceToCenter < nearestDistance and visible(camera, character, aimPart.Position) then
                        nearestDistance, targetPart, targetPlayer = distanceToCenter, aimPart, other
                    end
                end
            end
        end
    end

    if targetPart then
        local position = camera.CFrame.Position
        if (targetPart.Position - position).Magnitude > 0.01 then
            local alpha = 1 - math.exp(-math.min(dt, 0.1) * 60 / config.smoothing)
            camera.CFrame = camera.CFrame:Lerp(CFrame.lookAt(position, targetPart.Position), alpha)
        end
    end
    ringStroke.Color = targetPart and colors.enemy or colors.accent
    if not config.aim then
        status.Text = "Aimbot desligado"
    elseif not windowFocused then
        status.Text = "Pausado: janela sem foco"
    elseif not localCharacter then
        status.Text = "Aguardando personagem"
    elseif Input:GetFocusedTextBox() then
        status.Text = "Pausado: digitando"
    elseif targetPlayer then
        status.Text = (config.autoAim and "Auto: " or "Alvo: ") .. targetPlayer.DisplayName
    elseif aiming then
        status.Text = config.autoAim and "Automatico: nenhum alvo no FOV" or "Nenhum alvo no FOV"
    else
        status.Text = Input.TouchEnabled and "Segure MIRA para acompanhar" or "Segure o botao direito para mirar"
    end
end)

fitPanel()
showPanel(true)
