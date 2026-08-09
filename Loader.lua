--[[
    AUTOR: Adaptado por GBICA (@luizb.244) – Versão Mobile
    OBJETIVO: Testar trapaças em ambiente controlado, com foco em dispositivos móveis.
    ATENÇÃO: Use APENAS em seus próprios jogos para estudo de segurança.
--]]

-- ============================================================
-- 1. CONFIGURAÇÕES (AJUSTÁVEIS PELA GUI)
-- ============================================================
local Settings = {
    -- Aimbot
    AimAssist = true,
    AutoAim = false,          -- Se true, mira automaticamente no alvo mais próximo (sem precisar tocar)
    SilentAim = false,        -- Se true, não mexe na câmera, apenas redireciona o tiro (experimental)
    AimPart = "Head",
    FOV = 150,                -- Raio do círculo de mira (em pixels)
    Smoothness = 0.3,         -- Suavidade (0 = instantâneo, 1 = muito lento)
    Prediction = true,
    PredictionMultiplier = 1.0,
    MaxDistance = 400,

    -- ESP
    ESP = true,
    ESPColor = Color3.fromRGB(255, 100, 100),
    ESPThickness = 2,
    ESPShowHealth = true,
    ESPShowName = true,
    ESPShowDistance = false,  -- Mostra a distância do alvo

    -- Hitbox (visual)
    HitboxExpand = true,
    HitboxSize = Vector3.new(8, 8, 8), -- maior para celular (mais fácil de ver)
    HitboxTransparency = 0.3,
    HitboxColor = Color3.fromRGB(255, 100, 100),

    -- Outros
    TeamCheck = true,
    FPSBoost = false,
    ShowFOVCircle = true,     -- Desenha um círculo na tela mostrando o FOV
}

-- ============================================================
-- 2. SERVIÇOS E VARIÁVEIS
-- ============================================================
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")
local Workspace = game:GetService("Workspace")
local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService") -- para detectar toque

local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera

-- Para dispositivos móveis, usamos o toque (Touch) em vez do mouse
local TouchEnabled = UserInputService.TouchEnabled

-- Cache de jogadores
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

-- Predição iterativa (mais precisa)
local function predictPosition(part, bulletSpeed)
    bulletSpeed = bulletSpeed or 3000
    local pos = part.Position
    local vel = part.Velocity
    -- 3 iterações para convergência
    for _ = 1, 3 do
        local dist = (Camera.CFrame.Position - pos).Magnitude
        local travelTime = dist / bulletSpeed
        pos = part.Position + vel * travelTime
    end
    return pos
end

-- Verifica se ponto está dentro do FOV (círculo)
local function isInFOV(screenPos, centerX, centerY)
    local dx = screenPos.X - centerX
    local dy = screenPos.Y - centerY
    return (dx*dx + dy*dy) <= (Settings.FOV * Settings.FOV)
end

-- Raycast com filtro correto
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

-- Obtém a posição do centro da tela (para FOV)
local function getScreenCenter()
    local viewport = Camera.ViewportSize
    return viewport.X / 2, viewport.Y / 2
end

-- ============================================================
-- 4. SISTEMA DE MIRA (AIMBOT) – OTIMIZADO PARA CELULAR
-- ============================================================
local CurrentTarget = nil
local TargetPosition = nil

local function getBestTarget()
    local bestScore = math.huge
    local bestTarget = nil
    local bestPos = nil
    local centerX, centerY = getScreenCenter()

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

                    if isInFOV(Vector2.new(screenPos.X, screenPos.Y), centerX, centerY) then
                        if hasLineOfSight(Camera.CFrame.Position, pos, p.Character) then
                            local dx = screenPos.X - centerX
                            local dy = screenPos.Y - centerY
                            local angularDist = math.sqrt(dx*dx + dy*dy)
                            -- Score: prioriza menor distância angular, depois menor distância
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

-- Mira instantânea (usada quando smoothness = 0)
local function instantAim(targetPos)
    if targetPos then
        Camera.CFrame = CFrame.new(Camera.CFrame.Position, targetPos)
    end
end

-- ============================================================
-- 5. ESP (WALLHACK) – COM SUPORTE A CELULAR (DESENHO NA TELA)
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
    nameText.Size = 16
    nameText.Center = true
    nameText.Outline = true
    nameText.OutlineColor = Color3.new(0,0,0)
    nameText.Visible = false
    nameText.Font = Enum.Font.SourceSansBold

    local healthBar = Drawing.new("Line")
    healthBar.Color = Color3.fromRGB(0, 255, 0)
    healthBar.Thickness = 4
    healthBar.Visible = false

    local distText = Drawing.new("Text")
    distText.Color = Color3.fromRGB(255,255,255)
    distText.Size = 14
    distText.Center = true
    distText.Outline = true
    distText.OutlineColor = Color3.new(0,0,0)
    distText.Visible = false
    distText.Font = Enum.Font.SourceSans

    return { Box = box, Name = nameText, Health = healthBar, Distance = distText }
end

local function updateESP()
    local centerX, centerY = getScreenCenter()
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
                local size = math.clamp(2500 / dist, 25, 250)
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
                        local barY = y + size * 1.6 + 6
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
-- 6. FOV CIRCLE (DESENHA O CAMPO DE VISÃO)
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
    local cx, cy = getScreenCenter()
    fovCircle.Position = Vector2.new(cx, cy)
    fovCircle.Radius = Settings.FOV
    fovCircle.Visible = true
end

-- ============================================================
-- 7. HITBOX EXPANDER (VISUAL)
-- ============================================================
local function expandHitboxes()
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
-- 8. FPS BOOST (OTIMIZAÇÃO)
-- ============================================================
local boosted = false
local function applyFPSBoost()
    if boosted then return end
    boosted = true
    for _, obj in ipairs(Workspace:GetDescendants()) do
        if obj:IsA("ParticleEmitter") or obj:IsA("Trail") or obj:IsA("Smoke") or obj:IsA("Fire") then
            obj.Enabled = false
        elseif obj:IsA("Decal") then
            obj.Transparency = 1
        elseif obj:IsA("BasePart") then
            obj.CastShadow = false
            obj.Material = Enum.Material.SmoothPlastic
            obj.Reflectance = 0
        end
    end
    Lighting.GlobalShadows = false
    Lighting.FogEnd = 1e10
    Lighting.Brightness = 0
    pcall(function()
        settings().Rendering.QualityLevel = Enum.QualityLevel.Level01
    end)
end

-- ============================================================
-- 9. GUI PARA CELULAR (TOUCH-FRIENDLY)
-- ============================================================
local function createMobileGUI()
    local ScreenGui = Instance.new("ScreenGui")
    ScreenGui.Name = "GBICA_MobileGUI"
    ScreenGui.Parent = game.CoreGui
    ScreenGui.ResetOnSpawn = false

    -- Frame principal (maior para dedos)
    local MainFrame = Instance.new("Frame")
    MainFrame.Size = UDim2.new(0, 280, 0, 450) -- mais alto para scroll
    MainFrame.Position = UDim2.new(0, 10, 0, 50)
    MainFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
    MainFrame.BorderSizePixel = 0
    MainFrame.Active = true
    MainFrame.Draggable = true
    MainFrame.Parent = ScreenGui

    local UICorner = Instance.new("UICorner")
    UICorner.CornerRadius = UDim.new(0, 10)
    UICorner.Parent = MainFrame

    local UIStroke = Instance.new("UIStroke")
    UIStroke.Color = Color3.fromRGB(255, 80, 80)
    UIStroke.Thickness = 2
    UIStroke.Parent = MainFrame

    -- Título
    local Title = Instance.new("TextLabel")
    Title.Size = UDim2.new(1, 0, 0, 40)
    Title.Text = "GBICA Mobile"
    Title.TextColor3 = Color3.new(1,1,1)
    Title.BackgroundTransparency = 1
    Title.Font = Enum.Font.SourceSansBold
    Title.TextSize = 26
    Title.Parent = MainFrame

    -- Botão fechar (grande)
    local CloseBtn = Instance.new("TextButton")
    CloseBtn.Size = UDim2.new(0, 40, 0, 40)
    CloseBtn.Position = UDim2.new(1, -45, 0, 5)
    CloseBtn.Text = "✕"
    CloseBtn.TextColor3 = Color3.fromRGB(255, 80, 80)
    CloseBtn.BackgroundTransparency = 1
    CloseBtn.Font = Enum.Font.SourceSans
    CloseBtn.TextSize = 30
    CloseBtn.Parent = MainFrame
    CloseBtn.MouseButton1Click:Connect(function()
        ScreenGui.Enabled = not ScreenGui.Enabled
    end)

    -- ScrollingFrame para caber todas as opções
    local Scroll = Instance.new("ScrollingFrame")
    Scroll.Size = UDim2.new(1, 0, 1, -45)
    Scroll.Position = UDim2.new(0, 0, 0, 45)
    Scroll.BackgroundTransparency = 1
    Scroll.BorderSizePixel = 0
    Scroll.ScrollBarThickness = 6
    Scroll.ScrollBarImageColor3 = Color3.fromRGB(255,100,100)
    Scroll.Parent = MainFrame

    local Layout = Instance.new("UIListLayout")
    Layout.Padding = UDim.new(0, 8)
    Layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    Layout.VerticalAlignment = Enum.VerticalAlignment.Top
    Layout.Parent = Scroll

    -- Função para criar botões toggle (grandes)
    local function createToggle(text, default, callback)
        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(0.9, 0, 0, 45) -- altura maior para toque
        btn.Text = text .. ": " .. (default and "✅ ON" or "❌ OFF")
        btn.BackgroundColor3 = Color3.fromRGB(45, 45, 55)
        btn.TextColor3 = Color3.new(1,1,1)
        btn.Font = Enum.Font.SourceSansBold
        btn.TextSize = 20
        btn.BorderSizePixel = 0
        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0, 6)
        corner.Parent = btn
        btn.Parent = Scroll

        local state = default
        btn.MouseButton1Click:Connect(function()
            state = not state
            btn.Text = text .. ": " .. (state and "✅ ON" or "❌ OFF")
            callback(state)
        end)
        return btn
    end

    -- Toggles
    createToggle("Aim Assist", Settings.AimAssist, function(v) Settings.AimAssist = v end)
    createToggle("Auto Aim", Settings.AutoAim, function(v) Settings.AutoAim = v end)
    createToggle("Silent Aim", Settings.SilentAim, function(v) Settings.SilentAim = v end)
    createToggle("ESP", Settings.ESP, function(v) Settings.ESP = v end)
    createToggle("Hitbox Expand", Settings.HitboxExpand, function(v) Settings.HitboxExpand = v end)
    createToggle("Team Check", Settings.TeamCheck, function(v) Settings.TeamCheck = v end)
    createToggle("FPS Boost", Settings.FPSBoost, function(v) Settings.FPSBoost = v end)
    createToggle("Prediction", Settings.Prediction, function(v) Settings.Prediction = v end)
    createToggle("Show FOV", Settings.ShowFOVCircle, function(v) Settings.ShowFOVCircle = v end)

    -- Ajuste de FOV (com botões + e - grandes)
    local fovLabel = Instance.new("TextLabel")
    fovLabel.Size = UDim2.new(0.9, 0, 0, 30)
    fovLabel.Text = "FOV: " .. Settings.FOV
    fovLabel.TextColor3 = Color3.new(1,1,1)
    fovLabel.BackgroundTransparency = 1
    fovLabel.Font = Enum.Font.SourceSansBold
    fovLabel.TextSize = 18
    fovLabel.Parent = Scroll

    local fovRow = Instance.new("Frame")
    fovRow.Size = UDim2.new(0.9, 0, 0, 45)
    fovRow.BackgroundTransparency = 1
    fovRow.Parent = Scroll

    local minusBtn = Instance.new("TextButton")
    minusBtn.Size = UDim2.new(0.3, 0, 1, 0)
    minusBtn.Text = "−"
    minusBtn.BackgroundColor3 = Color3.fromRGB(60,60,70)
    minusBtn.TextColor3 = Color3.new(1,1,1)
    minusBtn.Font = Enum.Font.SourceSansBold
    minusBtn.TextSize = 30
    minusBtn.Parent = fovRow
    local cornerM = Instance.new("UICorner")
    cornerM.CornerRadius = UDim.new(0, 6)
    cornerM.Parent = minusBtn

    local fovValue = Instance.new("TextLabel")
    fovValue.Size = UDim2.new(0.4, 0, 1, 0)
    fovValue.Text = tostring(Settings.FOV)
    fovValue.BackgroundTransparency = 1
    fovValue.TextColor3 = Color3.new(1,1,1)
    fovValue.Font = Enum.Font.SourceSansBold
    fovValue.TextSize = 24
    fovValue.Parent = fovRow

    local plusBtn = Instance.new("TextButton")
    plusBtn.Size = UDim2.new(0.3, 0, 1, 0)
    plusBtn.Text = "+"
    plusBtn.BackgroundColor3 = Color3.fromRGB(60,60,70)
    plusBtn.TextColor3 = Color3.new(1,1,1)
    plusBtn.Font = Enum.Font.SourceSansBold
    plusBtn.TextSize = 30
    plusBtn.Parent = fovRow
    local cornerP = Instance.new("UICorner")
    cornerP.CornerRadius = UDim.new(0, 6)
    cornerP.Parent = plusBtn

    minusBtn.MouseButton1Click:Connect(function()
        Settings.FOV = math.max(20, Settings.FOV - 10)
        fovValue.Text = tostring(Settings.FOV)
        fovLabel.Text = "FOV: " .. Settings.FOV
    end)
    plusBtn.MouseButton1Click:Connect(function()
        Settings.FOV = math.min(400, Settings.FOV + 10)
        fovValue.Text = tostring(Settings.FOV)
        fovLabel.Text = "FOV: " .. Settings.FOV
    end)

    -- Ajuste de Smoothness (slider simples com botões)
    local smoothLabel = Instance.new("TextLabel")
    smoothLabel.Size = UDim2.new(0.9, 0, 0, 30)
    smoothLabel.Text = "Suavidade: " .. string.format("%.2f", Settings.Smoothness)
    smoothLabel.TextColor3 = Color3.new(1,1,1)
    smoothLabel.BackgroundTransparency = 1
    smoothLabel.Font = Enum.Font.SourceSansBold
    smoothLabel.TextSize = 18
    smoothLabel.Parent = Scroll

    local smoothRow = Instance.new("Frame")
    smoothRow.Size = UDim2.new(0.9, 0, 0, 45)
    smoothRow.BackgroundTransparency = 1
    smoothRow.Parent = Scroll

    local smMinus = Instance.new("TextButton")
    smMinus.Size = UDim2.new(0.3, 0, 1, 0)
    smMinus.Text = "−"
    smMinus.BackgroundColor3 = Color3.fromRGB(60,60,70)
    smMinus.TextColor3 = Color3.new(1,1,1)
    smMinus.Font = Enum.Font.SourceSansBold
    smMinus.TextSize = 30
    smMinus.Parent = smoothRow
    local cornerS1 = Instance.new("UICorner")
    cornerS1.CornerRadius = UDim.new(0, 6)
    cornerS1.Parent = smMinus

    local smoothVal = Instance.new("TextLabel")
    smoothVal.Size = UDim2.new(0.4, 0, 1, 0)
    smoothVal.Text = string.format("%.2f", Settings.Smoothness)
    smoothVal.BackgroundTransparency = 1
    smoothVal.TextColor3 = Color3.new(1,1,1)
    smoothVal.Font = Enum.Font.SourceSansBold
    smoothVal.TextSize = 24
    smoothVal.Parent = smoothRow

    local smPlus = Instance.new("TextButton")
    smPlus.Size = UDim2.new(0.3, 0, 1, 0)
    smPlus.Text = "+"
    smPlus.BackgroundColor3 = Color3.fromRGB(60,60,70)
    smPlus.TextColor3 = Color3.new(1,1,1)
    smPlus.Font = Enum.Font.SourceSansBold
    smPlus.TextSize = 30
    smPlus.Parent = smoothRow
    local cornerS2 = Instance.new("UICorner")
    cornerS2.CornerRadius = UDim.new(0, 6)
    cornerS2.Parent = smPlus

    smMinus.MouseButton1Click:Connect(function()
        Settings.Smoothness = math.max(0, math.round((Settings.Smoothness - 0.05) * 100) / 100)
        smoothVal.Text = string.format("%.2f", Settings.Smoothness)
        smoothLabel.Text = "Suavidade: " .. string.format("%.2f", Settings.Smoothness)
    end)
    smPlus.MouseButton1Click:Connect(function()
        Settings.Smoothness = math.min(1, math.round((Settings.Smoothness + 0.05) * 100) / 100)
        smoothVal.Text = string.format("%.2f", Settings.Smoothness)
        smoothLabel.Text = "Suavidade: " .. string.format("%.2f", Settings.Smoothness)
    end)

    -- Botão para resetar configurações (opcional)
    local resetBtn = Instance.new("TextButton")
    resetBtn.Size = UDim2.new(0.9, 0, 0, 45)
    resetBtn.Text = "🔄 Resetar Configurações"
    resetBtn.BackgroundColor3 = Color3.fromRGB(80, 40, 40)
    resetBtn.TextColor3 = Color3.new(1,1,1)
    resetBtn.Font = Enum.Font.SourceSansBold
    resetBtn.TextSize = 20
    resetBtn.Parent = Scroll
    local cornerR = Instance.new("UICorner")
    cornerR.CornerRadius = UDim.new(0, 6)
    cornerR.Parent = resetBtn
    resetBtn.MouseButton1Click:Connect(function()
        -- Recarregar o script (reiniciar) – simplesmente recria a GUI e reseta as variáveis?
        -- Neste exemplo, apenas reiniciamos as configurações para os valores padrão (não implementado para simplicidade)
        print("Reset não implementado, reinicie o script.")
    end)

    -- Ajustar altura do Scroll conforme o conteúdo
    Scroll.CanvasSize = UDim2.new(0, 0, 0, Layout.AbsoluteContentSize.Y + 20)
end

createMobileGUI()

-- ============================================================
-- 10. LOOP PRINCIPAL (RENDER STEP)
-- ============================================================
local function onRender()
    -- Atualiza o FOV Circle (sempre, independente do aimbot)
    drawFOVCircle()

    -- ESP (sempre que ativado)
    if Settings.ESP then
        updateESP()
    else
        -- Limpar ESP se desativado
        for p, esp in pairs(espObjects) do
            esp.Box:Remove()
            esp.Name:Remove()
            esp.Health:Remove()
            esp.Distance:Remove()
        end
        espObjects = {}
    end

    -- Hitbox
    if Settings.HitboxExpand then
        expandHitboxes()
    end

    -- FPS Boost
    if Settings.FPSBoost then
        applyFPSBoost()
    end

    -- Aimbot
    if Settings.AimAssist then
        local target, pos = getBestTarget()
        CurrentTarget = target
        TargetPosition = pos

        -- Decisão de quando mirar
        local shouldAim = false
        if Settings.AutoAim then
            shouldAim = true  -- mira automaticamente no melhor alvo
        else
            -- Em celular, usamos toque; em PC, botão direito
            if TouchEnabled then
                -- Verifica se há pelo menos um toque ativo (qualquer toque na tela)
                local touches = UserInputService:GetTouchPositions()
                shouldAim = (#touches > 0)
            else
                shouldAim = UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2)
            end
        end

        if shouldAim and target and pos then
            if Settings.SilentAim then
                -- Silent Aim: redireciona o mouse (ou toque) para o alvo sem mover a câmera
                -- Em celular, podemos simular um toque na posição do alvo na tela (não é possível diretamente)
                -- Mas podemos apenas apontar a câmera e, se o jogo usar o mouse para mirar, isso já funciona
                -- Para testes, vamos apenas mover a câmera mesmo, pois Silent Aim é complexo em mobile
                -- (Na prática, silent aim requer modificar o evento de tiro, não faremos aqui)
                -- Vamos apenas mover a câmera levemente para não atrapalhar
                if Settings.Smoothness > 0 then
                    smoothAim(pos)
                else
                    instantAim(pos)
                end
            else
                if Settings.Smoothness > 0 then
                    smoothAim(pos)
                else
                    instantAim(pos)
                end
            end
        end
    end
end

RunService.RenderStepped:Connect(onRender)

-- ============================================================
-- 11. LIMPEZA FINAL
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

print("✅ GBICA Mobile Loader carregado com sucesso!")
