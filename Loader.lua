--[[
    AUTOR: GBICA (@luizb.244)
    VERSÃO: 3.0 - Mobile/PC Universal
    FUNCIONALIDADES: Aimbot, ESP, Hitbox Expander, FOV Circle, Predição
    INSTRUÇÕES: Copie e cole no executor. Use APENAS para testes em seus próprios jogos.
--]]

-- ============================================================
-- 1. CONFIGURAÇÕES
-- ============================================================
local Settings = {
    -- Aimbot
    AimAssist = true,
    AutoAim = false,          -- Mira automática sem precisar clicar
    SilentAim = false,        -- Não mexe na câmera (apenas redireciona)
    AimPart = "Head",
    FOV = 150,
    Smoothness = 0.25,
    Prediction = true,
    PredictionMultiplier = 1.0,
    MaxDistance = 500,

    -- ESP
    ESP = true,
    ESPColor = Color3.fromRGB(255, 100, 100),
    ESPThickness = 1.5,
    ESPShowHealth = true,
    ESPShowName = true,
    ESPShowDistance = false,

    -- Hitbox
    HitboxExpand = true,
    HitboxSize = Vector3.new(8, 8, 8),
    HitboxTransparency = 0.3,
    HitboxColor = Color3.fromRGB(255, 100, 100),

    -- Outros
    TeamCheck = true,
    ShowFOVCircle = true,
}

-- ============================================================
-- 2. SERVIÇOS E VARIÁVEIS
-- ============================================================
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local UserInputService = game:GetService("UserInputService")
local Lighting = game:GetService("Lighting")

local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera
local Mouse = LocalPlayer:GetMouse()

-- Cache de jogadores ativos
local ActivePlayers = {}
local function updateActivePlayers()
    ActivePlayers = {}
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer then table.insert(ActivePlayers, p) end
    end
end
Players.PlayerAdded:Connect(function(p)
    if p ~= LocalPlayer then table.insert(ActivePlayers, p) end
end)
Players.PlayerRemoving:Connect(function(p)
    for i, v in ipairs(ActivePlayers) do
        if v == p then table.remove(ActivePlayers, i); break end
    end
end)
updateActivePlayers()

-- ============================================================
-- 3. FUNÇÕES AUXILIARES
-- ============================================================
local function isEnemy(p)
    if Settings.TeamCheck then
        return p.Team ~= LocalPlayer.Team
    end
    return true
end

-- Predição de movimento (iterativa)
local function predictPosition(part, bulletSpeed)
    bulletSpeed = bulletSpeed or 3000
    local pos = part.Position
    local vel = part.Velocity
    for _ = 1, 3 do
        local dist = (Camera.CFrame.Position - pos).Magnitude
        local travelTime = dist / bulletSpeed
        pos = part.Position + vel * travelTime * Settings.PredictionMultiplier
    end
    return pos
end

-- Verifica se ponto está dentro do FOV
local function isInFOV(screenPos)
    local dx = screenPos.X - Mouse.X
    local dy = screenPos.Y - Mouse.Y
    return (dx*dx + dy*dy) <= (Settings.FOV * Settings.FOV)
end

-- Raycast para linha de visão
local function hasLineOfSight(from, to, targetChar)
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Blacklist
    params.FilterDescendantsInstances = {
        LocalPlayer.Character,
        targetChar
    }
    params.IgnoreWater = true
    local result = Workspace:Raycast(from, to - from, params)
    return result == nil
end

-- ============================================================
-- 4. AIMBOT
-- ============================================================
local CurrentTarget = nil
local TargetPosition = nil

local function getBestTarget()
    local bestScore = math.huge
    local bestTarget = nil
    local bestPos = nil

    for _, p in ipairs(ActivePlayers) do
        if p.Character and p.Character:FindFirstChild("Humanoid") and isEnemy(p) then
            local part = p.Character:FindFirstChild(Settings.AimPart) or p.Character:FindFirstChild("HumanoidRootPart")
            if part then
                local pos = part.Position
                if Settings.Prediction then
                    pos = predictPosition(part)
                end
                local screenPos, onScreen = Camera:WorldToViewportPoint(pos)
                if onScreen and screenPos.Z > 0 then
                    local dist = (Camera.CFrame.Position - pos).Magnitude
                    if dist > Settings.MaxDistance then continue end

                    if isInFOV(Vector2.new(screenPos.X, screenPos.Y)) then
                        if hasLineOfSight(Camera.CFrame.Position, pos, p.Character) then
                            local dx = screenPos.X - Mouse.X
                            local dy = screenPos.Y - Mouse.Y
                            local angularDist = math.sqrt(dx*dx + dy*dy)
                            local score = angularDist + dist * 0.001
                            if score < bestScore then
                                bestScore = score
                                bestTarget = p
                                bestPos = pos
                            end
                        end
                    end
                end
            end
        end
    end
    return bestTarget, bestPos
end

-- Aplica mira suave
local function smoothAim(targetPos)
    if not targetPos then return end
    local currentCF = Camera.CFrame
    local targetCF = CFrame.new(currentCF.Position, targetPos)
    local newLook = currentCF.LookVector:Lerp(targetCF.LookVector, Settings.Smoothness)
    Camera.CFrame = CFrame.new(currentCF.Position, currentCF.Position + newLook)
end

-- ============================================================
-- 5. ESP (USANDO DRAWING)
-- ============================================================
local espObjects = {}

local function createESP(player)
    local box = Drawing.new("Square")
    box.Color = Settings.ESPColor
    box.Thickness = Settings.ESPThickness
    box.Filled = false
    box.Transparency = 1
    box.Visible = false

    local nameText = Drawing.new("Text")
    nameText.Color = Color3.new(1,1,1)
    nameText.Size = 14
    nameText.Center = true
    nameText.Outline = true
    nameText.OutlineColor = Color3.new(0,0,0)
    nameText.Visible = false
    nameText.Font = 3  -- Enum.Font.SourceSansBold

    local healthBar = Drawing.new("Line")
    healthBar.Color = Color3.fromRGB(0, 255, 0)
    healthBar.Thickness = 3
    healthBar.Visible = false

    local distText = Drawing.new("Text")
    distText.Color = Color3.new(1,1,1)
    distText.Size = 12
    distText.Center = true
    distText.Outline = true
    distText.OutlineColor = Color3.new(0,0,0)
    distText.Visible = false
    distText.Font = 2  -- Enum.Font.SourceSans

    return { Box = box, Name = nameText, Health = healthBar, Distance = distText }
end

local function updateESP()
    for _, p in ipairs(ActivePlayers) do
        local char = p.Character
        local root = char and char:FindFirstChild("HumanoidRootPart")
        if root and isEnemy(p) then
            local screenPos, onScreen = Camera:WorldToViewportPoint(root.Position)
            if onScreen and screenPos.Z > 0 then
                if not espObjects[p] then
                    espObjects[p] = createESP(p)
                end
                local esp = espObjects[p]
                local dist = (Camera.CFrame.Position - root.Position).Magnitude
                local size = math.clamp(2000 / dist, 20, 200)
                local x = screenPos.X - size/2
                local y = screenPos.Y - size * 0.8

                esp.Box.Size = Vector2.new(size, size * 1.6)
                esp.Box.Position = Vector2.new(x, y)
                esp.Box.Visible = true
                esp.Box.Color = Settings.ESPColor

                if Settings.ESPShowName then
                    esp.Name.Text = p.Name
                    esp.Name.Position = Vector2.new(screenPos.X, y - 18)
                    esp.Name.Visible = true
                else
                    esp.Name.Visible = false
                end

                if Settings.ESPShowHealth then
                    local humanoid = char:FindFirstChild("Humanoid")
                    if humanoid then
                        local hp = humanoid.Health / humanoid.MaxHealth
                        local barWidth = size
                        local barX = screenPos.X - barWidth/2
                        local barY = y + size * 1.6 + 5
                        esp.Health.From = Vector2.new(barX, barY)
                        esp.Health.To = Vector2.new(barX + barWidth * hp, barY)
                        esp.Health.Color = Color3.fromRGB(255 * (1 - hp), 255 * hp, 0)
                        esp.Health.Visible = true
                    else
                        esp.Health.Visible = false
                    end
                else
                    esp.Health.Visible = false
                end

                if Settings.ESPShowDistance then
                    esp.Distance.Text = string.format("%.0fm", dist)
                    esp.Distance.Position = Vector2.new(screenPos.X, y + size * 1.6 + 20)
                    esp.Distance.Visible = true
                else
                    esp.Distance.Visible = false
                end
            else
                if espObjects[p] then
                    espObjects[p].Box.Visible = false
                    espObjects[p].Name.Visible = false
                    espObjects[p].Health.Visible = false
                    espObjects[p].Distance.Visible = false
                end
            end
        else
            if espObjects[p] then
                espObjects[p].Box:Remove()
                espObjects[p].Name:Remove()
                espObjects[p].Health:Remove()
                espObjects[p].Distance:Remove()
                espObjects[p] = nil
            end
        end
    end
end

-- ============================================================
-- 6. FOV CIRCLE (DRAWING)
-- ============================================================
local fovCircle = nil
local function drawFOVCircle()
    if not Settings.ShowFOVCircle then
        if fovCircle then fovCircle.Visible = false end
        return
    end
    if not fovCircle then
        fovCircle = Drawing.new("Circle")
        fovCircle.Thickness = 1
        fovCircle.Color = Color3.fromRGB(255, 255, 255)
        fovCircle.Filled = false
        fovCircle.NumSides = 32
        fovCircle.Transparency = 0.6
    end
    fovCircle.Position = Vector2.new(Mouse.X, Mouse.Y)
    fovCircle.Radius = Settings.FOV
    fovCircle.Visible = true
end

-- ============================================================
-- 7. HITBOX EXPANDER
-- ============================================================
local function expandHitboxes()
    if not Settings.HitboxExpand then return end
    for _, p in ipairs(ActivePlayers) do
        local char = p.Character
        if char and isEnemy(p) then
            local head = char:FindFirstChild("Head")
            if head and head.Size ~= Settings.HitboxSize then
                head.Size = Settings.HitboxSize
                head.Transparency = Settings.HitboxTransparency
                head.Material = Enum.Material.Neon
                head.Color = Settings.HitboxColor
                head.CanCollide = false
            end
        end
    end
end

-- ============================================================
-- 8. GUI (MENU FLUTUANTE COM DRAWING)
-- ============================================================
local menuVisible = true
local menuObjects = {}

local function createMenu()
    -- Fundo do menu
    local bg = Drawing.new("Square")
    bg.Position = Vector2.new(20, 50)
    bg.Size = Vector2.new(220, 350)
    bg.Color = Color3.fromRGB(20, 20, 30)
    bg.Thickness = 1
    bg.Filled = true
    bg.Transparency = 0.9
    bg.Visible = true

    -- Borda
    local border = Drawing.new("Square")
    border.Position = Vector2.new(20, 50)
    border.Size = Vector2.new(220, 350)
    border.Color = Color3.fromRGB(255, 80, 80)
    border.Thickness = 2
    border.Filled = false
    border.Transparency = 1
    border.Visible = true

    -- Título
    local title = Drawing.new("Text")
    title.Position = Vector2.new(130, 65)
    title.Text = "GBICA v3.0"
    title.Color = Color3.new(1,1,1)
    title.Size = 22
    title.Center = true
    title.Outline = true
    title.OutlineColor = Color3.new(0,0,0)
    title.Font = 3
    title.Visible = true

    -- Botão Minimizar (simbolo "-")
    local minBtn = Drawing.new("Text")
    minBtn.Position = Vector2.new(195, 55)
    minBtn.Text = "─"
    minBtn.Color = Color3.new(1,1,1)
    minBtn.Size = 30
    minBtn.Center = true
    minBtn.Font = 3
    minBtn.Visible = true

    -- Botão Fechar (simbolo "X")
    local closeBtn = Drawing.new("Text")
    closeBtn.Position = Vector2.new(220, 55)
    closeBtn.Text = "✕"
    closeBtn.Color = Color3.fromRGB(255, 80, 80)
    closeBtn.Size = 28
    closeBtn.Center = true
    closeBtn.Font = 3
    closeBtn.Visible = true

    menuObjects = {
        Background = bg,
        Border = border,
        Title = title,
        MinBtn = minBtn,
        CloseBtn = closeBtn,
        Buttons = {}
    }

    -- Função para criar botões de toggle (simulados com texto)
    local yPos = 100
    local toggleNames = {
        "Aim Assist",
        "Auto Aim",
        "ESP",
        "Hitbox",
        "Team Check",
        "Prediction",
        "FOV Circle"
    }
    local toggleStates = {
        Settings.AimAssist,
        Settings.AutoAim,
        Settings.ESP,
        Settings.HitboxExpand,
        Settings.TeamCheck,
        Settings.Prediction,
        Settings.ShowFOVCircle
    }
    local toggleCallbacks = {
        function(v) Settings.AimAssist = v end,
        function(v) Settings.AutoAim = v end,
        function(v) Settings.ESP = v end,
        function(v) Settings.HitboxExpand = v end,
        function(v) Settings.TeamCheck = v end,
        function(v) Settings.Prediction = v end,
        function(v) Settings.ShowFOVCircle = v end
    }

    for i, name in ipairs(toggleNames) do
        local btn = Drawing.new("Text")
        btn.Position = Vector2.new(130, yPos)
        btn.Text = name .. ": " .. (toggleStates[i] and "ON" or "OFF")
        btn.Color = toggleStates[i] and Color3.fromRGB(100, 255, 100) or Color3.fromRGB(255, 100, 100)
        btn.Size = 16
        btn.Center = true
        btn.Outline = true
        btn.OutlineColor = Color3.new(0,0,0)
        btn.Font = 2
        btn.Visible = true

        -- Armazena o estado e a função de callback
        table.insert(menuObjects.Buttons, {
            Object = btn,
            State = toggleStates[i],
            Callback = toggleCallbacks[i],
            Name = name
        })
        yPos = yPos + 30
    end

    -- Ajustes de FOV e Smoothness (exibidos como texto)
    local fovText = Drawing.new("Text")
    fovText.Position = Vector2.new(130, yPos)
    fovText.Text = "FOV: " .. Settings.FOV
    fovText.Color = Color3.new(1,1,1)
    fovText.Size = 16
    fovText.Center = true
    fovText.Outline = true
    fovText.OutlineColor = Color3.new(0,0,0)
    fovText.Font = 2
    fovText.Visible = true
    table.insert(menuObjects.Buttons, {Object = fovText, IsSetting = true, Type = "FOV"})

    yPos = yPos + 30

    local smoothText = Drawing.new("Text")
    smoothText.Position = Vector2.new(130, yPos)
    smoothText.Text = "Smooth: " .. string.format("%.2f", Settings.Smoothness)
    smoothText.Color = Color3.new(1,1,1)
    smoothText.Size = 16
    smoothText.Center = true
    smoothText.Outline = true
    smoothText.OutlineColor = Color3.new(0,0,0)
    smoothText.Font = 2
    smoothText.Visible = true
    table.insert(menuObjects.Buttons, {Object = smoothText, IsSetting = true, Type = "Smooth"})

    -- Botões + e - para ajustes
    local minusFOV = Drawing.new("Text")
    minusFOV.Position = Vector2.new(50, yPos - 15)
    minusFOV.Text = "◀"
    minusFOV.Color = Color3.new(1,1,1)
    minusFOV.Size = 22
    minusFOV.Center = true
    minusFOV.Font = 2
    minusFOV.Visible = true
    table.insert(menuObjects.Buttons, {Object = minusFOV, IsControl = true, Type = "FOVMinus"})

    local plusFOV = Drawing.new("Text")
    plusFOV.Position = Vector2.new(210, yPos - 15)
    plusFOV.Text = "▶"
    plusFOV.Color = Color3.new(1,1,1)
    plusFOV.Size = 22
    plusFOV.Center = true
    plusFOV.Font = 2
    plusFOV.Visible = true
    table.insert(menuObjects.Buttons, {Object = plusFOV, IsControl = true, Type = "FOVPlus"})

    yPos = yPos + 35

    local minusSmooth = Drawing.new("Text")
    minusSmooth.Position = Vector2.new(50, yPos - 15)
    minusSmooth.Text = "◀"
    minusSmooth.Color = Color3.new(1,1,1)
    minusSmooth.Size = 22
    minusSmooth.Center = true
    minusSmooth.Font = 2
    minusSmooth.Visible = true
    table.insert(menuObjects.Buttons, {Object = minusSmooth, IsControl = true, Type = "SmoothMinus"})

    local plusSmooth = Drawing.new("Text")
    plusSmooth.Position = Vector2.new(210, yPos - 15)
    plusSmooth.Text = "▶"
    plusSmooth.Color = Color3.new(1,1,1)
    plusSmooth.Size = 22
    plusSmooth.Center = true
    plusSmooth.Font = 2
    plusSmooth.Visible = true
    table.insert(menuObjects.Buttons, {Object = plusSmooth, IsControl = true, Type = "SmoothPlus"})

    -- Função para alternar estado dos botões
    local function toggleButton(index)
        local data = menuObjects.Buttons[index]
        if data and not data.IsSetting and not data.IsControl then
            data.State = not data.State
            data.Callback(data.State)
            data.Object.Text = data.Name .. ": " .. (data.State and "ON" or "OFF")
            data.Object.Color = data.State and Color3.fromRGB(100, 255, 100) or Color3.fromRGB(255, 100, 100)
        end
    end

    -- Função para ajustar valores
    local function adjustValue(type, direction)
        if type == "FOV" then
            Settings.FOV = math.clamp(Settings.FOV + direction * 10, 20, 400)
            for _, data in ipairs(menuObjects.Buttons) do
                if data.IsSetting and data.Type == "FOV" then
                    data.Object.Text = "FOV: " .. Settings.FOV
                end
            end
        elseif type == "Smooth" then
            Settings.Smoothness = math.clamp(Settings.Smoothness + direction * 0.05, 0, 1)
            Settings.Smoothness = math.round(Settings.Smoothness * 100) / 100
            for _, data in ipairs(menuObjects.Buttons) do
                if data.IsSetting and data.Type == "Smooth" then
                    data.Object.Text = "Smooth: " .. string.format("%.2f", Settings.Smoothness)
                end
            end
        end
    end

    -- Simula clique nos botões (usando o mouse)
    local function handleClick()
        local mx, my = Mouse.X, Mouse.Y
        -- Verifica se clicou no botão de minimizar
        if mx >= 195 and mx <= 215 and my >= 55 and my <= 75 then
            menuVisible = not menuVisible
            for _, obj in pairs(menuObjects) do
                if type(obj) == "table" then
                    for _, data in ipairs(obj) do
                        if type(data) == "table" and data.Object then
                            data.Object.Visible = menuVisible
                        end
                    end
                elseif type(obj) == "userdata" then
                    obj.Visible = menuVisible
                end
            end
            return
        end
        -- Verifica se clicou no botão de fechar
        if mx >= 220 and mx <= 240 and my >= 55 and my <= 75 then
            for _, obj in pairs(menuObjects) do
                if type(obj) == "table" then
                    for _, data in ipairs(obj) do
                        if type(data) == "table" and data.Object then
                            data.Object:Remove()
                        end
                    end
                elseif type(obj) == "userdata" then
                    obj:Remove()
                end
            end
            menuObjects = {}
            return
        end

        -- Verifica cliques nos botões de toggle
        local yStart = 100
        for i, data in ipairs(menuObjects.Buttons) do
            if not data.IsSetting and not data.IsControl then
                if mx >= 50 and mx <= 210 and my >= yStart - 10 and my <= yStart + 10 then
                    toggleButton(i)
                    return
                end
                yStart = yStart + 30
            elseif data.IsControl then
                if data.Type == "FOVMinus" and mx >= 40 and mx <= 60 and my >= yStart - 15 and my <= yStart + 15 then
                    adjustValue("FOV", -1)
                    return
                elseif data.Type == "FOVPlus" and mx >= 200 and mx <= 220 and my >= yStart - 15 and my <= yStart + 15 then
                    adjustValue("FOV", 1)
                    return
                elseif data.Type == "SmoothMinus" and mx >= 40 and mx <= 60 and my >= yStart - 15 and my <= yStart + 15 then
                    adjustValue("Smooth", -1)
                    return
                elseif data.Type == "SmoothPlus" and mx >= 200 and mx <= 220 and my >= yStart - 15 and my <= yStart + 15 then
                    adjustValue("Smooth", 1)
                    return
                end
            end
        end
    end

    -- Conecta o clique do mouse
    Mouse.Button1Down:Connect(handleClick)

    return true
end

-- Criar menu (se ainda não existir)
if not next(menuObjects) then
    createMenu()
end

-- ============================================================
-- 9. LOOP PRINCIPAL (RENDER STEP)
-- ============================================================
local function onRender()
    -- FOV Circle
    drawFOVCircle()

    -- ESP
    if Settings.ESP then
        updateESP()
    else
        for p, esp in pairs(espObjects) do
            esp.Box:Remove()
            esp.Name:Remove()
            esp.Health:Remove()
            esp.Distance:Remove()
        end
        espObjects = {}
    end

    -- Hitbox
    expandHitboxes()

    -- Aimbot
    if Settings.AimAssist then
        local shouldAim = false
        if Settings.AutoAim then
            shouldAim = true
        else
            -- Verifica se o botão direito do mouse está pressionado
            shouldAim = UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2)
        end

        if shouldAim then
            local target, pos = getBestTarget()
            if target and pos then
                smoothAim(pos)
            end
        end
    end
end

RunService.RenderStepped:Connect(onRender)

-- ============================================================
-- 10. LIMPEZA
-- ============================================================
LocalPlayer.CharacterRemoving:Connect(function()
    for _, esp in pairs(espObjects) do
        esp.Box:Remove()
        esp.Name:Remove()
        esp.Health:Remove()
        esp.Distance:Remove()
    end
    espObjects = {}
    if fovCircle then fovCircle:Remove() fovCircle = nil end
end)

print("✅ GBICA v3.0 Loader carregado com sucesso!")
print("🎯 Clique com o botão direito para mirar.")
print("📱 Clique no menu para alternar opções.")
