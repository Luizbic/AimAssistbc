--[[ Autor: GBICA (@luizb.244) Propósito: Testes e detecção de trapaças, uso autorizado. Otimizado com GBICA (@luizb.244) :cache, predição, LoS, unificação de loops e gestão eficiente de recursos. --]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")
local Workspace = game:GetService("Workspace")
local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera
local Mouse = LocalPlayer:GetMouse()

-- Configurações
local settings = {
    aimAssist = true,
    esp = true,
    hitboxExpander = true,
    teamCheck = true,
    fpsBooster = false,
    aimPart = "Head",
    fov = 120,
    smoothness = 0.2,
    hitboxSize = Vector3.new(6,6,6),
    boxColor = Color3.fromRGB(255,100,100)
}

-- Cache de jogadores ativos
local activePlayers = {}
Players.PlayerAdded:Connect(function(p)
    if p ~= LocalPlayer then table.insert(activePlayers, p) end
end)
Players.PlayerRemoving:Connect(function(p)
    for i,v in ipairs(activePlayers) do
        if v == p then table.remove(activePlayers,i); break end
    end
end)
for _,p in ipairs(Players:GetPlayers()) do
    if p ~= LocalPlayer then table.insert(activePlayers, p) end
end

-- Interface GUI
local ScreenGui = Instance.new("ScreenGui", game.CoreGui)
ScreenGui.Name = "GBICA_GUI"
local Frame = Instance.new("Frame", ScreenGui)
Frame.Size = UDim2.new(0,200,0,200)
Frame.Position = UDim2.new(0,20,0,100)
Frame.BackgroundColor3 = Color3.new(0.12,0.12,0.12)
Frame.BorderSizePixel = 0
Frame.Active = true
Frame.Draggable = true

local UIStroke = Instance.new("UIStroke", Frame)
UIStroke.Color = Color3.fromRGB(255,100,100)
UIStroke.Thickness = 1.2

local Title = Instance.new("TextLabel", Frame)
Title.Size = UDim2.new(1,0,0,25)
Title.Text = "GBICA Script"
Title.TextColor3 = Color3.new(1,1,1)
Title.BackgroundTransparency = 1
Title.Font = Enum.Font.SourceSansBold
Title.TextSize = 20

local Close = Instance.new("TextButton", Frame)
Close.Size = UDim2.new(0,25,0,25)
Close.Position = UDim2.new(1,-25,0,0)
Close.Text = "X"
Close.TextColor3 = Color3.fromRGB(255,100,100)
Close.BackgroundTransparency = 1
Close.Font = Enum.Font.SourceSans
Close.TextSize = 20
Close.MouseButton1Click:Connect(function()
    ScreenGui.Enabled = not ScreenGui.Enabled
end)

local function newToggle(name, y, default, callback)
    local btn = Instance.new("TextButton", Frame)
    btn.Size = UDim2.new(0,180,0,25)
    btn.Position = UDim2.new(0,10,0,y)
    btn.Text = name..": "..(default and"ON"or"OFF")
    btn.BackgroundColor3 = Color3.new(0.2,0.2,0.2)
    btn.TextColor3 = Color3.new(1,1,1)
    btn.Font = Enum.Font.SourceSans
    btn.TextSize = 18
    btn.MouseButton1Click:Connect(function()
        default = not default
        btn.Text = name..": "..(default and"ON"or"OFF")
        callback(default)
    end)
end

newToggle("Aim Assist",30, settings.aimAssist, function(v) settings.aimAssist=v end)
newToggle("ESP", 60, settings.esp, function(v) settings.esp=v end)
newToggle("Hitbox", 90, settings.hitboxExpander, function(v) settings.hitboxExpander=v end)
newToggle("TeamCheck",120, settings.teamCheck, function(v) settings.teamCheck=v end)
newToggle("FPS Boost",150, settings.fpsBooster, function(v) settings.fpsBooster=v end)

-- Recursos
local function isEnemy(p)
    return (not settings.teamCheck) or (p.Team ~= LocalPlayer.Team)
end

local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Blacklist

local espDraws = {}

local function predictedPos(part)
    local dist = (Camera.CFrame.Position - part.Position).Magnitude
    local speed = 300
    local t = dist / speed
    return part.Position + part.Velocity * t
end

local function getTarget()
    local best, minD = nil, settings.fov
    for _,p in ipairs(activePlayers) do
        if p.Character and isEnemy(p) then
            local part = p.Character:FindFirstChild(settings.aimPart)
            if part then
                local pred = predictedPos(part)
                local screen = Camera:WorldToViewportPoint(pred)
                if screen.Z > 0 then
                    local dx,dy = screen.X - Mouse.X, screen.Y - Mouse.Y
                    local dist = Vector2.new(dx,dy).Magnitude
                    if dist < minD then
                        rayParams.FilterDescendantsInstances = {LocalPlayer.Character, Workspace:GetDescendants()}
                        local ray = Workspace:Raycast(Camera.CFrame.Position, (pred - Camera.CFrame.Position), rayParams)
                        if not ray then best = pred; minD = dist end
                    end
                end
            end
        end
    end
    return best
end

local function doAim()
    local tgt = getTarget()
    if tgt then
        local dir = (tgt - Camera.CFrame.Position).Unit
        Camera.CFrame = CFrame.new(Camera.CFrame.Position, Camera.CFrame.Position + dir:Lerp(Camera.CFrame.LookVector, settings.smoothness))
    end
end

local function doESP()
    for _,p in ipairs(activePlayers) do
        local char = p.Character
        if char and isEnemy(p) then
            local hrp = char:FindFirstChild("HumanoidRootPart")
            if hrp then
                local scr = Camera:WorldToViewportPoint(hrp.Position)
                if scr.Z > 0 then
                    if not espDraws[p] then
                        espDraws[p] = Drawing.new("Square")
                        espDraws[p].Color = settings.boxColor
                        espDraws[p].Thickness = 1
                        espDraws[p].Filled = false
                    end
                    local size = 2000 / hrp.Position.Magnitude
                    espDraws[p].Size = Vector2.new(size, size * 1.6)
                    espDraws[p].Position = Vector2.new(scr.X - size / 2, scr.Y - size * 0.8)
                    espDraws[p].Visible = true
                else
                    if espDraws[p] then espDraws[p].Visible = false end
                end
            end
        elseif espDraws[p] then
            espDraws[p]:Remove()
            espDraws[p] = nil
        end
    end
end

local function doHitbox()
    for _,p in ipairs(activePlayers) do
        local char = p.Character
        if char and isEnemy(p) then
            local head = char:FindFirstChild("Head")
            if head and head.Size ~= settings.hitboxSize then
                head.Size = settings.hitboxSize
                head.Transparency = 0.5
                head.Material = Enum.Material.Neon
                head.Color = settings.boxColor
                head.CanCollide = false
            end
        end
    end
end

local optimized = false
local function doOptimize()
    if optimized then return end
    optimized = true
    for _,obj in ipairs(Workspace:GetDescendants()) do
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
    pcall(function() settings().Rendering.QualityLevel = Enum.QualityLevel.Level01 end)
end

RunService.RenderStepped:Connect(function()
    if settings.aimAssist then doAim() end
    if settings.esp then doESP() end
    if settings.hitboxExpander then doHitbox() end
    if settings.fpsBooster then doOptimize() end
end)
