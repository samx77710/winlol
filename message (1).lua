local repo = 'https://raw.githubusercontent.com/violin-suzutsuki/LinoriaLib/main/'
local Library = loadstring(game:HttpGet(repo .. 'Library.lua'))()
local ThemeManager = loadstring(game:HttpGet(repo .. 'addons/ThemeManager.lua'))()
local SaveManager = loadstring(game:HttpGet(repo .. 'addons/SaveManager.lua'))()

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local LocalPlayer = Players.LocalPlayer

local ESPObjects = {}
local CamlockTarget = nil
local CamlockActive = false
local LastShotTime = 0

-- Función para verificar si el jugador es del mismo equipo
local function IsTeammate(player)
    if not Toggles.TeamCheck or not Toggles.TeamCheck.Value then
        return false
    end
    
    -- Verificar por TeamColor
    if LocalPlayer.Team and player.Team then
        if LocalPlayer.Team == player.Team then
            return true
        end
    end
    
    -- Verificar por Highlight azul
    if player.Character then
        local highlight = player.Character:FindFirstChildOfClass("Highlight")
        if highlight and highlight.FillColor == Color3.fromRGB(0, 0, 255) then
            return true
        end
    end
    
    return false
end

-- Función para verificar si hay pared entre jugador y objetivo
local function HasWallBetween(targetPart)
    if not targetPart then return true end
    
    local camera = workspace.CurrentCamera
    local ray = Ray.new(camera.CFrame.Position, (targetPart.Position - camera.CFrame.Position).Unit * 1000)
    local hitPart = workspace:FindPartOnRayWithIgnoreList(ray, {LocalPlayer.Character})
    
    if hitPart == targetPart or (CamlockTarget and CamlockTarget.Character and CamlockTarget.Character:IsAncestorOf(hitPart)) then
        return false
    end
    
    return true
end

-- Función para obtener el jugador más cercano
local function GetClosestPlayer()
    local closestPlayer = nil
    local shortestDistance = math.huge
    
    local mouse = UserInputService:GetMouseLocation()
    
    for _, player in pairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character and not IsTeammate(player) then
            local humanoidRootPart = player.Character:FindFirstChild("HumanoidRootPart")
            local humanoid = player.Character:FindFirstChild("Humanoid")
            
            if humanoidRootPart and humanoid and humanoid.Health > 0 then
                local vector, onScreen = workspace.CurrentCamera:WorldToViewportPoint(humanoidRootPart.Position)
                
                if onScreen then
                    local distance = (Vector2.new(mouse.X, mouse.Y) - Vector2.new(vector.X, vector.Y)).Magnitude
                    local maxFOV = Options.CamlockFOV and Options.CamlockFOV.Value or 150
                    
                    if distance < maxFOV and distance < shortestDistance then
                        if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
                            local distanceFromPlayer = (LocalPlayer.Character.HumanoidRootPart.Position - humanoidRootPart.Position).Magnitude
                            local maxDistance = Options.CamlockMaxDistance and Options.CamlockMaxDistance.Value or 500
                            
                            if distanceFromPlayer <= maxDistance then
                                closestPlayer = player
                                shortestDistance = distance
                            end
                        end
                    end
                end
            end
        end
    end
    
    return closestPlayer
end

-- Función de Triggerbot
local function Triggerbot()
    if not Toggles.EnableTriggerbot or not Toggles.EnableTriggerbot.Value then return end
    if not CamlockActive or not CamlockTarget then return end
    
    local targetPart = CamlockTarget.Character and CamlockTarget.Character:FindFirstChild(Options.CamlockHitbox and Options.CamlockHitbox.Value or "Head")
    if not targetPart then return end
    
    -- Verificar wall check
    if Toggles.TriggerbotWallCheck and Toggles.TriggerbotWallCheck.Value then
        if HasWallBetween(targetPart) then
            return
        end
    end
    
    -- Verificar delay
    local currentTime = tick()
    local delay = (Options.TriggerbotDelay and Options.TriggerbotDelay.Value or 100) / 1000
    
    if currentTime - LastShotTime >= delay then
        -- Simular disparo (presionar click izquierdo)
        mouse1press()
        task.wait(0.05)
        mouse1release()
        LastShotTime = currentTime
    end
end

local function CreateESP(player)
    if player == LocalPlayer then return end
    
    local esp = {
        Box = nil,
        Name = nil,
        Health = nil,
        Distance = nil,
        Tracer = nil,
        Player = player
    }
    
    local box = Drawing.new("Square")
    box.Visible = false
    box.Color = Color3.fromRGB(255, 255, 255)
    box.Thickness = 4
    box.Transparency = 1
    box.Filled = false
    esp.Box = box
    
    local name = Drawing.new("Text")
    name.Visible = false
    name.Color = Color3.fromRGB(255, 255, 255)
    name.Size = 40
    name.Center = true
    name.Outline = true
    name.Text = player.Name
    esp.Name = name
    
    local health = Drawing.new("Text")
    health.Visible = false
    health.Color = Color3.fromRGB(0, 255, 0)
    health.Size = 16
    health.Center = true
    health.Outline = true
    esp.Health = health
    
    local distance = Drawing.new("Text")
    distance.Visible = false
    distance.Color = Color3.fromRGB(255, 255, 255)
    distance.Size = 16
    distance.Center = true
    distance.Outline = true
    esp.Distance = distance
    
    local tracer = Drawing.new("Line")
    tracer.Visible = false
    tracer.Color = Color3.fromRGB(255, 255, 255)
    tracer.Thickness = 1
    tracer.Transparency = 1
    esp.Tracer = tracer
    
    ESPObjects[player] = esp
end

local function UpdateESP()
    for player, esp in pairs(ESPObjects) do
        if not player or not player.Parent then
            esp.Box:Remove()
            esp.Name:Remove()
            esp.Health:Remove()
            esp.Distance:Remove()
            esp.Tracer:Remove()
            ESPObjects[player] = nil
            continue
        end
        
        -- Team check para ESP
        if IsTeammate(player) then
            esp.Box.Visible = false
            esp.Name.Visible = false
            esp.Health.Visible = false
            esp.Distance.Visible = false
            esp.Tracer.Visible = false
            continue
        end
        
        local character = player.Character
        local humanoidRootPart = character and character:FindFirstChild("HumanoidRootPart")
        local humanoid = character and character:FindFirstChild("Humanoid")
        
        if humanoidRootPart and humanoid and humanoid.Health > 0 and LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
            local dist = (LocalPlayer.Character.HumanoidRootPart.Position - humanoidRootPart.Position).Magnitude
            local maxRenderDistance = Options.MaxRenderDistance and Options.MaxRenderDistance.Value or 300
            
            if dist > maxRenderDistance then
                esp.Box.Visible = false
                esp.Name.Visible = false
                esp.Health.Visible = false
                esp.Distance.Visible = false
                esp.Tracer.Visible = false
                continue
            end
            
            local vector, onScreen = workspace.CurrentCamera:WorldToViewportPoint(humanoidRootPart.Position)
            
            if onScreen and Toggles.EnableESP and Toggles.EnableESP.Value then
                local headPos = workspace.CurrentCamera:WorldToViewportPoint(humanoidRootPart.Position + Vector3.new(0, 3, 0))
                local legPos = workspace.CurrentCamera:WorldToViewportPoint(humanoidRootPart.Position - Vector3.new(0, 3, 0))
                
                local height = math.abs(headPos.Y - legPos.Y)
                local width = height / 2
                
                if Toggles.BoxESP and Toggles.BoxESP.Value then
                    esp.Box.Size = Vector2.new(width, height)
                    esp.Box.Position = Vector2.new(vector.X - width/2, vector.Y - height/2)
                    esp.Box.Color = Options.BoxColor and Options.BoxColor.Value or Color3.fromRGB(255, 255, 255)
                    esp.Box.Transparency = Options.BoxTransparency and Options.BoxTransparency.Value or 1
                    esp.Box.Visible = true
                else
                    esp.Box.Visible = false
                end
                
                if Toggles.NameESP and Toggles.NameESP.Value then
                    esp.Name.Position = Vector2.new(vector.X, vector.Y - height/2 - 20)
                    esp.Name.Color = Options.NameColor and Options.NameColor.Value or Color3.fromRGB(255, 255, 255)
                    esp.Name.Text = player.Name
                    esp.Name.Visible = true
                else
                    esp.Name.Visible = false
                end
                
                if Toggles.HealthESP and Toggles.HealthESP.Value then
                    local healthPercent = humanoid.Health / humanoid.MaxHealth
                    esp.Health.Position = Vector2.new(vector.X, vector.Y + height/2 + 5)
                    esp.Health.Color = Color3.fromRGB(255 * (1 - healthPercent), 255 * healthPercent, 0)
                    esp.Health.Text = math.floor(humanoid.Health) .. " HP"
                    esp.Health.Visible = true
                else
                    esp.Health.Visible = false
                end
                
                if Toggles.DistanceESP and Toggles.DistanceESP.Value then
                    esp.Distance.Position = Vector2.new(vector.X, vector.Y + height/2 + 20)
                    esp.Distance.Color = Options.DistanceColor and Options.DistanceColor.Value or Color3.fromRGB(255, 255, 255)
                    esp.Distance.Text = math.floor(dist) .. " studs"
                    esp.Distance.Visible = true
                else
                    esp.Distance.Visible = false
                end
                
                if Toggles.TracerESP and Toggles.TracerESP.Value then
                    local fromPos = Vector2.new(workspace.CurrentCamera.ViewportSize.X / 2, workspace.CurrentCamera.ViewportSize.Y)
                    if Options.TracerOrigin and Options.TracerOrigin.Value == "Top" then
                        fromPos = Vector2.new(workspace.CurrentCamera.ViewportSize.X / 2, 0)
                    elseif Options.TracerOrigin and Options.TracerOrigin.Value == "Middle" then
                        fromPos = Vector2.new(workspace.CurrentCamera.ViewportSize.X / 2, workspace.CurrentCamera.ViewportSize.Y / 2)
                    end
                    
                    esp.Tracer.From = fromPos
                    esp.Tracer.To = Vector2.new(vector.X, vector.Y)
                    esp.Tracer.Color = Options.TracerColor and Options.TracerColor.Value or Color3.fromRGB(255, 255, 255)
                    esp.Tracer.Transparency = Options.TracerTransparency and Options.TracerTransparency.Value or 1
                    esp.Tracer.Visible = true
                else
                    esp.Tracer.Visible = false
                end
            else
                esp.Box.Visible = false
                esp.Name.Visible = false
                esp.Health.Visible = false
                esp.Distance.Visible = false
                esp.Tracer.Visible = false
            end
        else
            esp.Box.Visible = false
            esp.Name.Visible = false
            esp.Health.Visible = false
            esp.Distance.Visible = false
            esp.Tracer.Visible = false
        end
    end
end

local Window = Library:CreateWindow({
    Title = '                       win.lol - by samx         ',
    Center = true,
    AutoShow = true,
    TabPadding = 8,
    MenuFadeTime = 0.2
})

local Tabs = {
    Hvh = Window:AddTab('hvh'),
    Legit = Window:AddTab('legit'),
    Visuals = Window:AddTab('visuals'),
    Settings = Window:AddTab('settings'),
}

-- ============ TAB LEGIT - CAMLOCK ============
local CamlockBox = Tabs.Legit:AddLeftGroupbox('camlock / sticky aim')

CamlockBox:AddToggle('EnableCamlock', {
    Text = 'enable camlock',
    Default = false,
}):AddKeyPicker('CamlockKeybind', {
    Default = 'Q',
    SyncToggleState = true,
    Mode = 'Toggle',
    Text = 'camlock key',
    NoUI = false,
})

CamlockBox:AddToggle('EnableStickyAim', {
    Text = 'sticky aim',
    Default = false,
    
})

CamlockBox:AddSlider('CamlockSmoothness', {
    Text = 'smoothness',
    Default = 0.5,
    Min = 0.1,
    Max = 1,
    Rounding = 2,
    
})

CamlockBox:AddSlider('CamlockFOV', {
    Text = 'fov',
    Default = 150,
    Min = 50,
    Max = 400,
    Rounding = 0,
    
})

CamlockBox:AddSlider('CamlockMaxDistance', {
    Text = 'max distance',
    Default = 500,
    Min = 50,
    Max = 1000,
    Rounding = 0,
    
})

CamlockBox:AddDropdown('CamlockHitbox', {
    Values = { 'Head', 'UpperTorso', 'HumanoidRootPart', 'LowerTorso' },
    Default = 1,
    Multi = false,
    Text = 'target part',
    
})

-- ============ TAB LEGIT - TRIGGERBOT ============
local TriggerbotBox = Tabs.Legit:AddRightGroupbox('triggerbot')

TriggerbotBox:AddToggle('EnableTriggerbot', {
    Text = 'enable triggerbot',
    Default = false,
    
})

TriggerbotBox:AddSlider('TriggerbotDelay', {
    Text = 'delay (ms)',
    Default = 265,
    Min = 0,
    Max = 500,
    Rounding = 0,
    
})

TriggerbotBox:AddToggle('TriggerbotWallCheck', {
    Text = 'wall check',
    Default = true,
    
})

-- ============ TAB VISUALS - ESP ============
local ESPBox = Tabs.Visuals:AddLeftGroupbox('esp settings')

ESPBox:AddToggle('EnableESP', {
    Text = 'enable esp',
    Default = false,
})

ESPBox:AddSlider('MaxRenderDistance', {
    Text = 'max render distance',
    Default = 300,
    Min = 50,
    Max = 1000,
    Rounding = 0,
    
})

ESPBox:AddToggle('BoxESP', {
    Text = 'box',
    Default = true,
}):AddColorPicker('BoxColor', {
    Default = Color3.fromRGB(255, 255, 255),
})

ESPBox:AddSlider('BoxTransparency', {
    Text = 'box transparency',
    Default = 1,
    Min = 0,
    Max = 1,
    Rounding = 2,
})

ESPBox:AddToggle('NameESP', {
    Text = 'name',
    Default = true,
}):AddColorPicker('NameColor', {
    Default = Color3.fromRGB(255, 255, 255),
})

ESPBox:AddToggle('HealthESP', {
    Text = 'health',
    Default = true,
})

ESPBox:AddToggle('DistanceESP', {
    Text = 'distance',
    Default = true,
}):AddColorPicker('DistanceColor', {
    Default = Color3.fromRGB(255, 255, 255),
})

local TracerBox = Tabs.Visuals:AddRightGroupbox('tracer settings')

TracerBox:AddToggle('TracerESP', {
    Text = 'enable tracers',
    Default = false,
}):AddColorPicker('TracerColor', {
    Default = Color3.fromRGB(255, 255, 255),
})

TracerBox:AddDropdown('TracerOrigin', {
    Values = { 'Bottom', 'Middle', 'Top' },
    Default = 1,
    Multi = false,
    Text = 'tracer origin',
})

TracerBox:AddSlider('TracerTransparency', {
    Text = 'tracer transparency',
    Default = 1,
    Min = 0,
    Max = 1,
    Rounding = 2,
})

-- ============ CONFIGURACIÓN GENERAL ============
local GeneralBox = Tabs.Settings:AddLeftGroupbox('general')

GeneralBox:AddToggle('TeamCheck', {
    Text = 'team check',
    Default = true,
    Tooltip = 'Ignora jugadores de tu equipo y con highlight azul'
})

for _, player in pairs(Players:GetPlayers()) do
    CreateESP(player)
end

Players.PlayerAdded:Connect(function(player)
    CreateESP(player)
end)

Players.PlayerRemoving:Connect(function(player)
    if ESPObjects[player] then
        ESPObjects[player].Box:Remove()
        ESPObjects[player].Name:Remove()
        ESPObjects[player].Health:Remove()
        ESPObjects[player].Distance:Remove()
        ESPObjects[player].Tracer:Remove()
        ESPObjects[player] = nil
    end
end)

-- Loop principal
RunService.RenderStepped:Connect(function()
    if Toggles.EnableESP and Toggles.EnableESP.Value then
        UpdateESP()
    end
    
    -- Sistema de Camlock
    if Toggles.EnableCamlock and Toggles.EnableCamlock.Value then
        if CamlockActive and CamlockTarget then
            -- Verificar si el objetivo sigue siendo válido
            if CamlockTarget.Character and not IsTeammate(CamlockTarget) then
                local humanoid = CamlockTarget.Character:FindFirstChild("Humanoid")
                if not humanoid or humanoid.Health <= 0 then
                    CamlockActive = false
                    CamlockTarget = nil
                else
                    local targetPart = CamlockTarget.Character:FindFirstChild(Options.CamlockHitbox and Options.CamlockHitbox.Value or "Head")
                    
                    if targetPart then
                        -- En modo sticky aim, mantener el objetivo
                        if not Toggles.EnableStickyAim or not Toggles.EnableStickyAim.Value then
                            local newTarget = GetClosestPlayer()
                            if newTarget then
                                CamlockTarget = newTarget
                                targetPart = CamlockTarget.Character:FindFirstChild(Options.CamlockHitbox and Options.CamlockHitbox.Value or "Head")
                            end
                        end
                        
                        if targetPart then
                            local camera = workspace.CurrentCamera
                            local smoothness = Options.CamlockSmoothness and Options.CamlockSmoothness.Value or 0.5
                            
                            local targetCFrame = CFrame.new(camera.CFrame.Position, targetPart.Position)
                            camera.CFrame = camera.CFrame:Lerp(targetCFrame, smoothness)
                        end
                    end
                    
                    -- Ejecutar triggerbot
                    Triggerbot()
                end
            else
                CamlockActive = false
                CamlockTarget = nil
            end
        else
            -- Buscar nuevo objetivo
            CamlockTarget = GetClosestPlayer()
            if CamlockTarget then
                CamlockActive = true
            end
        end
    else
        CamlockActive = false
        CamlockTarget = nil
    end
end)

Library:SetWatermarkVisibility(true)
Library:SetWatermark('win.lol')

local MenuGroup = Tabs.Settings:AddRightGroupbox('menu')
MenuGroup:AddButton('unload', function() Library:Unload() end)
MenuGroup:AddLabel('menu bind'):AddKeyPicker('MenuKeybind', { Default = 'RightShift', NoUI = true, Text = 'menu keybind' })

Library.ToggleKeybind = Options.MenuKeybind

ThemeManager:SetLibrary(Library)
SaveManager:SetLibrary(Library)
SaveManager:IgnoreThemeSettings()
SaveManager:SetIgnoreIndexes({ 'MenuKeybind' })

ThemeManager:SetFolder('WinLol')
SaveManager:SetFolder('WinLol/configs')

SaveManager:BuildConfigSection(Tabs.Settings)
ThemeManager:ApplyToTab(Tabs.Settings)

Library:OnUnload(function()
    for _, esp in pairs(ESPObjects) do
        esp.Box:Remove()
        esp.Name:Remove()
        esp.Health:Remove()
        esp.Distance:Remove()
        esp.Tracer:Remove()
    end
    Library.Unloaded = true
end)