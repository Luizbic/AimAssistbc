--[[
    AUTOR: GBICA (@luizb.244)
    VERSÃO: 4.0 - ULTRA OTIMIZADO
    FUNCIONALIDADES: Aimbot, ESP (leve), Hitbox Expander, FOV Circle
    CORREÇÕES: Sem lag, sem travamentos, layout corrigido
--]]

-- ============================================================
-- 1. CONFIGURAÇÕES
-- ============================================================
local Settings = {
    AimAssist = true,
    AutoAim = false,
    AimPart = "Head",
    FOV = 150,
    Smoothness = 0.3,
    MaxDistance = 500,
    ESP = true,
    ESPColor = Color3.fromRGB(255, 100, 100),
    ESPShowHealth = true,
    ESPShowName = true,
    HitboxExpand = true,
    HitboxSize = Vector3.new(8, 8, 8),
    TeamCheck = true,
    ShowFOVCircle = true,
}

-- ============================================================
-- 2. SERVIÇOS
-- ============================================================
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local UserInputService = game:GetService("UserInputService")

local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera
local Mouse = LocalPlayer:GetMouse()

-- ============================================================
-- 3. CACHE DE JOGADORES (OTIMIZADO)
-- ============================================================
local ActivePlayers = {}
local function UpdatePlayers()
    ActivePlayers = {}
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer then
            table.insert(ActivePlayers, p)
        end
    end
end

Players.PlayerAdded:Connect(UpdatePlayers)
Players.PlayerRemoving:Connect(UpdatePlayers)
UpdatePlayers()

-- ============================================================
-- 4. FUNÇÕES AUXILIARES (SEM RAYCAST PARA EVITAR LAG)
-- ============================================================
local function IsEnemy(p)
    if Settings.TeamCheck then
        return p.Team ~= LocalPlayer.Team
    end
    return true
end

local function IsInFOV(screenPos)
    local dx = screenPos.X - Mouse.X
    local dy = screenPos.Y - Mouse.Y
    return (dx * dx + dy * dy) <= (Settings.FOV * Settings.FOV)
end

-- ============================================================
-- 5. AIMBOT (OTIMIZADO)
-- ============================================================
local function GetBestTarget()
    local bestScore = math.huge
    local bestPos = nil

    for _, p in ipairs(ActivePlayers) do
        if not p.Character then continue end
        if not p.Character:FindFirstChild("Humanoid") then continue end
        if not IsEnemy(p) then continue end

        local part = p.Character:FindFirstChild(Settings.AimPart) or p.Character:FindFirstChild("HumanoidRootPart")
        if not part then continue end

        local screenPos, onScreen = Camera:WorldToViewportPoint(part.Position)
        if not onScreen or screenPos.Z <= 0 then continue end

        local dist = (Camera.CFrame.Position - part.Position).Magnitude
        if dist > Settings.MaxDistance then continue end

        if IsInFOV(Vector2.new(screenPos.X, screenPos.Y)) then
            local dx = screenPos.X - Mouse.X
            local dy = screenPos.Y - Mouse.Y
            local angularDist = math.sqrt(dx * dx + dy * dy)
            local score = angularDist + dist * 0.001

            if score < bestScore then
                bestScore = score
                bestPos = part.Position
            end
        end
    end

    return bestPos
end

local function SmoothAim(targetPos)
    if not targetPos then return end
    local currentCF = Camera.CFrame
    local targetCF = CFrame.new(currentCF.Position, targetPos)
    local newLook = currentCF.LookVector:Lerp(targetCF.LookVector, Settings.Smoothness)
    Camera.CFrame = CFrame.new(currentCF.Position, currentCF.Position + newLook)
end

-- ============================================================
-- 6. ESP OTIMIZADO (SEM LAG)
-- ============================================================
local espObjects = {}
local espCounter = 0
local MAX_ESP_OBJECTS = 50 -- Limite para evitar lag

local function CreateESP(player)
    if espCounter > MAX_ESP_OBJECTS then return nil end

    local box = Drawing.new("Square")
    box.Color = Settings.ESPColor
    box.Thickness = 1.5
    box.Filled = false
    box.Transparency = 1
    box.Visible = false

    local nameText = Drawing.new("Text")
    nameText.Color = Color3.new(1, 1, 1)
    nameText.Size = 14
    nameText.Center = true
    nameText.Outline = true
    nameText.OutlineColor = Color3.new(0, 0, 0)
    nameText.Visible = false
    nameText.Font = 3

    local healthBar = Drawing.new("Line")
    healthBar.Color = Color3.fromRGB(0, 255, 0)
    healthBar.Thickness = 3
    healthBar.Visible = false

    espCounter = espCounter + 1
    return { Box = box, Name = nameText, Health = healthBar }
end

local function UpdateESP()
    -- Se ESP desativado, limpa tudo
    if not Settings.ESP then
        for _, esp in pairs(espObjects) do
            esp.Box:Remove()
            esp.Name:Remove()
            esp.Health:Remove()
        end
        espObjects = {}
        espCounter = 0
        return
    end

    -- Remove ESP de jogadores que saíram
    for player, _ in pairs(espObjects) do
        if not table.find(ActivePlayers, player) then
            espObjects[player].Box:Remove()
            espObjects[player].Name:Remove()
            espObjects[player].Health:Remove()
            espObjects[player] = nil
            espCounter = espCounter - 1
        end
    end

    -- Atualiza ESP dos jogadores ativos
    for _, p in ipairs(ActivePlayers) do
        local char = p.Character
        local root = char and char:FindFirstChild("HumanoidRootPart")
        
        if root and IsEnemy(p) then
            local screenPos, onScreen = Camera:WorldToViewportPoint(root.Position)
            
            if onScreen and screenPos.Z > 0 then
                -- Cria ESP se não existir
                if not espObjects[p] then
                    espObjects[p] = CreateESP(p)
                    if not espObjects[p] then return end -- Limite atingido
                end

                local esp = espObjects[p]
                local dist = (Camera.CFrame.Position - root.Position).Magnitude
                local size = math.clamp(1500 / dist, 15, 150)
                local x = screenPos.X - size / 2
                local y = screenPos.Y - size * 0.8

                -- Atualiza caixa
                esp.Box.Size = Vector2.new(size, size * 1.6)
                esp.Box.Position = Vector2.new(x, y)
                esp.Box.Visible = true
                esp.Box.Color = Settings.ESPColor

                -- Atualiza nome
                if Settings.ESPShowName then
                    esp.Name.Text = p.Name
                    esp.Name.Position = Vector2.new(screenPos.X, y - 18)
                    esp.Name.Visible = true
                else
                    esp.Name.Visible = false
                end

                -- Atualiza barra de vida
                if Settings.ESPShowHealth then
                    local humanoid = char:FindFirstChild("Humanoid")
                    if humanoid then
                        local hp = humanoid.Health / humanoid.MaxHealth
                        local barWidth = size
                        local barX = screenPos.X - barWidth / 2
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
            else
                -- Esconde ESP se fora da tela
                if espObjects[p] then
                    espObjects[p].Box.Visible = false
                    espObjects[p].Name.Visible = false
                    espObjects[p].Health.Visible = false
                end
            end
        end
    end
end

-- ============================================================
-- 7. FOV CIRCLE
-- ============================================================
local fovCircle = nil

local function UpdateFOVCircle()
    if not Settings.ShowFOVCircle then
        if fovCircle then
            fovCircle.Visible = false
        end
        return
    end

    if not fovCircle then
        fovCircle = Drawing.new("Circle")
        fovCircle.Thickness = 1.5
        fovCircle.Color = Color3.fromRGB(255, 255, 255)
        fovCircle.Filled = false
        fovCircle.NumSides = 36
        fovCircle.Transparency = 0.5
    end

    fovCircle.Position = Vector2.new(Mouse.X, Mouse.Y)
    fovCircle.Radius = Settings.FOV
    fovCircle.Visible = true
end

-- ============================================================
-- 8. HITBOX EXPANDER (CORRIGIDO)
-- ============================================================
local function UpdateHitboxes()
    if not Settings.HitboxExpand then return end

    for _, p in ipairs(ActivePlayers) do
        local char = p.Character
        if not char then continue end
        if not IsEnemy(p) then continue end

        local head = char:FindFirstChild("Head")
        if head and head.Size ~= Settings.HitboxSize then
            head.Size = Settings.HitboxSize
            head.Transparency = 0.3
            head.Material = Enum.Material.Neon
            head.Color = Settings.ESPColor
            head.CanCollide = false
        end
    end
end

-- ============================================================
-- 9. MENU (LAYOUT CORRIGIDO)
-- ============================================================
local menuVisible = true
local menuObjects = {}

local function CreateMenu()
    -- Fundo
    local bg = Drawing.new("Square")
    bg.Position = Vector2.new(10, 10)
    bg.Size = Vector2.new(230, 380)
    bg.Color = Color3.fromRGB(15, 15, 25)
    bg.Thickness = 0
    bg.Filled = true
    bg.Transparency = 0.92
    bg.Visible = true

    -- Borda
    local border = Drawing.new("Square")
    border.Position = Vector2.new(10, 10)
    border.Size = Vector2.new(230, 380)
    border.Color = Color3.fromRGB(255, 80, 80)
    border.Thickness = 2
    border.Filled = false
    border.Transparency = 1
    border.Visible = true

    -- Título
    local title = Drawing.new("Text")
    title.Position = Vector2.new(125, 25)
    title.Text = "GBICA v4.0"
    title.Color = Color3.new(1, 1, 1)
    title.Size = 22
    title.Center = true
    title.Outline = true
    title.OutlineColor = Color3.new(0, 0, 0)
    title.Font = 3
    title.Visible = true

    -- Botão Minimizar
    local minBtn = Drawing.new("Text")
    minBtn.Position = Vector2.new(195, 20)
    minBtn.Text = "─"
    minBtn.Color = Color3.new(1, 1, 1)
    minBtn.Size = 28
    minBtn.Center = true
    minBtn.Font = 3
    minBtn.Visible = true

    -- Botão Fechar
    local closeBtn = Drawing.new("Text")
    closeBtn.Position = Vector2.new(220, 20)
    closeBtn.Text = "✕"
    closeBtn.Color = Color3.fromRGB(255, 80, 80)
    closeBtn.Size = 26
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

    -- Botões de toggle
    local toggles = {
        { Name = "Aim Assist", Key = "AimAssist" },
        { Name = "Auto Aim", Key = "AutoAim" },
        { Name = "ESP", Key = "ESP" },
        { Name = "Hitbox", Key = "HitboxExpand" },
        { Name = "Team Check", Key = "TeamCheck" },
        { Name = "FOV Circle", Key = "ShowFOVCircle" },
    }

    local yPos = 60
    for _, toggle in ipairs(toggles) do
        local state = Settings[toggle.Key]
        local btn = Drawing.new("Text")
        btn.Position = Vector2.new(125, yPos)
        btn.Text = toggle.Name .. ": " .. (state and "ON" or "OFF")
        btn.Color = state and Color3.fromRGB(100, 255, 100) or Color3.fromRGB(255, 100, 100)
        btn.Size = 16
        btn.Center = true
        btn.Outline = true
        btn.OutlineColor = Color3.new(0, 0, 0)
        btn.Font = 2
        btn.Visible = true

        table.insert(menuObjects.Buttons, {
            Object = btn,
            Key = toggle.Key,
            Name = toggle.Name,
            State = state
        })
        yPos = yPos + 30
    end

    -- Ajuste FOV
    local fovLabel = Drawing.new("Text")
    fovLabel.Position = Vector2.new(125, yPos)
    fovLabel.Text = "FOV: " .. Settings.FOV
    fovLabel.Color = Color3.new(1, 1, 1)
    fovLabel.Size = 16
    fovLabel.Center = true
    fovLabel.Outline = true
    fovLabel.OutlineColor = Color3.new(0, 0, 0)
    fovLabel.Font = 2
    fovLabel.Visible = true
    table.insert(menuObjects.Buttons, { Object = fovLabel, IsSetting = true, Type = "FOV" })

    -- Controles FOV
    local fovMinus = Drawing.new("Text")
    fovMinus.Position = Vector2.new(50, yPos - 5)
    fovMinus.Text = "◀"
    fovMinus.Color = Color3.new(1, 1, 1)
    fovMinus.Size = 20
    fovMinus.Center = true
    fovMinus.Font = 2
    fovMinus.Visible = true
    table.insert(menuObjects.Buttons, { Object = fovMinus, IsControl = true, Type = "FOVMinus" })

    local fovPlus = Drawing.new("Text")
    fovPlus.Position = Vector2.new(200, yPos - 5)
    fovPlus.Text = "▶"
    fovPlus.Color = Color3.new(1, 1, 1)
    fovPlus.Size = 20
    fovPlus.Center = true
    fovPlus.Font = 2
    fovPlus.Visible = true
    table.insert(menuObjects.Buttons, { Object = fovPlus, IsControl = true, Type = "FOVPlus" })

    yPos = yPos + 35

    -- Ajuste Smoothness
    local smoothLabel = Drawing.new("Text")
    smoothLabel.Position = Vector2.new(125, yPos)
    smoothLabel.Text = "Smooth: " .. string.format("%.2f", Settings.Smoothness)
    smoothLabel.Color = Color3.new(1, 1, 1)
    smoothLabel.Size = 16
    smoothLabel.Center = true
    smoothLabel.Outline = true
    smoothLabel.OutlineColor = Color3.new(0, 0, 0)
    smoothLabel.Font = 2
    smoothLabel.Visible = true
    table.insert(menuObjects.Buttons, { Object = smoothLabel, IsSetting = true, Type = "Smooth" })

    -- Controles Smoothness
    local smoothMinus = Drawing.new("Text")
    smoothMinus.Position = Vector2.new(50, yPos - 5)
    smoothMinus.Text = "◀"
    smoothMinus.Color = Color3.new(1, 1, 1)
    smoothMinus.Size = 20
    smoothMinus.Center = true
    smoothMinus.Font = 2
    smoothMinus.Visible = true
    table.insert(menuObjects.Buttons, { Object = smoothMinus, IsControl = true, Type = "SmoothMinus" })

    local smoothPlus = Drawing.new("Text")
    smoothPlus.Position = Vector2.new(200, yPos - 5)
    smoothPlus.Text = "▶"
    smoothPlus.Color = Color3.new(1, 1, 1)
    smoothPlus.Size = 20
    smoothPlus.Center = true
    smoothPlus.Font = 2
    smoothPlus.Visible = true
    table.insert(menuObjects.Buttons, { Object = smoothPlus, IsControl = true, Type = "SmoothPlus" })

    -- Função para lidar com cliques
    local function HandleClick()
        local mx, my = Mouse.X, Mouse.Y

        -- Botão Minimizar
        if mx >= 195 and mx <= 215 and my >= 20 and my <= 40 then
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

        -- Botão Fechar
        if mx >= 220 and mx <= 240 and my >= 20 and my <= 40 then
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

        -- Cliques nos botões de toggle
        local yStart = 60
        for i, data in ipairs(menuObjects.Buttons) do
            if not data.IsSetting and not data.IsControl then
                if mx >= 50 and mx <= 200 and my >= yStart - 12 and my <= yStart + 12 then
                    data.State = not data.State
                    Settings[data.Key] = data.State
                    data.Object.Text = data.Name .. ": " .. (data.State and "ON" or "OFF")
                    data.Object.Color = data.State and Color3.fromRGB(100, 255, 100) or Color3.fromRGB(255, 100, 100)
                    return
                end
                yStart = yStart + 30
            end
        end

        -- Controles FOV e Smoothness
        for _, data in ipairs(menuObjects.Buttons) do
            if data.IsControl then
                if data.Type == "FOVMinus" and mx >= 40 and mx <= 60 and my >= yStart - 5 and my <= yStart + 15 then
                    Settings.FOV = math.max(20, Settings.FOV - 10)
                    for _, d in ipairs(menuObjects.Buttons) do
                        if d.IsSetting and d.Type == "FOV" then
                            d.Object.Text = "FOV: " .. Settings.FOV
                        end
                    end
                    return
                elseif data.Type == "FOVPlus" and mx >= 190 and mx <= 210 and my >= yStart - 5 and my <= yStart + 15 then
                    Settings.FOV = math.min(400, Settings.FOV + 10)
                    for _, d in ipairs(menuObjects.Buttons) do
                        if d.IsSetting and d.Type == "FOV" then
                            d.Object.Text = "FOV: " .. Settings.FOV
                        end
                    end
                    return
                elseif data.Type == "SmoothMinus" and mx >= 40 and mx <= 60 and my >= yStart - 5 and my <= yStart + 15 then
                    Settings.Smoothness = math.max(0, math.round((Settings.Smoothness - 0.05) * 100) / 100)
                    for _, d in ipairs(menuObjects.Buttons) do
                        if d.IsSetting and d.Type == "Smooth" then
                            d.Object.Text = "Smooth: " .. string.format("%.2f", Settings.Smoothness)
                        end
                    end
                    return
                elseif data.Type == "SmoothPlus" and mx >= 190 and mx <= 210 and my >= yStart - 5 and my <= yStart + 15 then
                    Settings.Smoothness = math.min(1, math.round((Settings.Smoothness + 0.05) * 100) / 100)
                    for _, d in ipairs(menuObjects.Buttons) do
                        if d.IsSetting and d.Type == "Smooth" then
                            d.Object.Text = "Smooth: " .. string.format("%.2f", Settings.Smoothness)
                        end
                    end
                    return
                end
            end
        end
    end

    Mouse.Button1Down:Connect(HandleClick)
end

-- Criar menu
CreateMenu()

-- ============================================================
-- 10. LOOP PRINCIPAL (OTIMIZADO)
-- ============================================================
local function OnRender()
    -- Aimbot (APENAS quando necessário)
    if Settings.AimAssist then
        local shouldAim = false
        if Settings.AutoAim then
            shouldAim = true
        else
            shouldAim = UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2)
        end

        if shouldAim then
            local target = GetBestTarget()
            if target then
                SmoothAim(target)
            end
        end
    end

    -- ESP (atualizado a cada 2 frames para performance)
    UpdateESP()

    -- FOV Circle
    UpdateFOVCircle()

    -- Hitbox
    UpdateHitboxes()
end

-- Conecta ao loop
RunService.RenderStepped:Connect(OnRender)

-- ============================================================
-- 11. LIMPEZA AO SAIR
-- ============================================================
LocalPlayer.CharacterRemoving:Connect(function()
    for _, esp in pairs(espObjects) do
        esp.Box:Remove()
        esp.Name:Remove()
        esp.Health:Remove()
    end
    espObjects = {}
    if fovCircle then
        fovCircle:Remove()
        fovCircle = nil
    end
end)

print("✅ GBICA v4.0 ULTRA OTIMIZADO carregado!")
print("🎯 Botão direito = mirar | Menu no canto superior esquerdo")
print("📱 Clique nas opções do menu para ativar/desativar")
