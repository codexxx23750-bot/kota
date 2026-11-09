-- [kota] Blue Lock Career - Knit/RemoteFunction Spammer v16
-- Baseado no exploit do Volleyball Legends (InvokeServer Spam)

local CONFIG = {
    default_interval = 0.1, -- 100ms
    target_names = {
        "RequestRankedReward", "UseWeaponSpin", "UseFlowSpin", "RollWeapon", "ClaimReward"
    }
}

-- ============================================================
-- UI (Preto e Branco)
-- ============================================================
local UI = {}
UI.__index = UI

function UI.new()
    local self = setmetatable({}, UI)
    self.gui = Instance.new("ScreenGui")
    self.gui.Name = "kota_ui"
    self.gui.ResetOnSpawn = false
    if gethui then self.gui.Parent = gethui() else self.gui.Parent = game:GetService("CoreGui") end

    local main = Instance.new("Frame")
    main.Size = UDim2.new(0, 400, 0, 350)
    main.Position = UDim2.new(0.02, 0, 0.1, 0)
    main.BackgroundColor3 = Color3.fromRGB(10, 10, 10)
    main.BorderSizePixel = 0
    main.Active = true
    main.Parent = self.gui

    -- Arrastar
    local dragging, dragInput, dragStart, startPos
    main.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true; dragStart = input.Position; startPos = main.Position
            input.Changed:Connect(function() if input.UserInputState == Enum.UserInputState.End then dragging = false end end)
        end
    end)
    main.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement then dragInput = input end
    end)
    game:GetService("UserInputService").InputChanged:Connect(function(input)
        if input == dragInput and dragging then
            local delta = input.Position - dragStart
            main.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end)

    local stroke = Instance.new("UIStroke"); stroke.Color = Color3.fromRGB(31,31,31); stroke.Thickness = 1; stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border; stroke.Parent = main
    
    local title = Instance.new("TextLabel"); title.Size = UDim2.new(1,0,0,40); title.BackgroundColor3 = Color3.fromRGB(10,10,10); title.Text = "kota v16 (Knit Spammer)"; title.TextColor3 = Color3.fromRGB(255,255,255); title.Font = Enum.Font.Code; title.TextSize = 20; title.TextXAlignment = Enum.TextXAlignment.Left; title.ZIndex = 2; title.Parent = main
    local title_pad = Instance.new("UIPadding"); title_pad.PaddingLeft = UDim.new(0,12); title_pad.Parent = title
    
    local close = Instance.new("TextButton"); close.Size = UDim2.new(0,32,0,32); close.Position = UDim2.new(1,-40,0,4); close.BackgroundColor3 = Color3.fromRGB(10,10,10); close.Text = "×"; close.TextColor3 = Color3.fromRGB(255,255,255); close.Font = Enum.Font.Code; close.TextSize = 18; close.ZIndex = 2; close.Parent = main
    close.MouseButton1Click:Connect(function() self.gui:Destroy() end)

    local log = Instance.new("ScrollingFrame"); log.Size = UDim2.new(1,-24,0,180); log.Position = UDim2.new(0,12,0,50); log.BackgroundColor3 = Color3.fromRGB(5,5,5); log.BorderSizePixel = 0; log.ScrollBarThickness = 4; log.CanvasSize = UDim2.new(0,0,0,0); log.AutomaticCanvasSize = Enum.AutomaticSize.Y; log.ZIndex = 2; log.Parent = main
    local log_layout = Instance.new("UIListLayout"); log_layout.Padding = UDim.new(0,2); log_layout.Parent = log
    
    local status = Instance.new("TextLabel"); status.Size = UDim2.new(1,-24,0,24); status.Position = UDim2.new(0,12,0,240); status.BackgroundColor3 = Color3.fromRGB(10,10,10); status.Text = "idle"; status.TextColor3 = Color3.fromRGB(180,180,180); status.Font = Enum.Font.Code; status.TextSize = 12; status.TextXAlignment = Enum.TextXAlignment.Left; status.ZIndex = 2; status.Parent = main

    local btn_spin = Instance.new("TextButton"); btn_spin.Size = UDim2.new(0,180,0,40); btn_spin.Position = UDim2.new(0,12,0,280); btn_spin.BackgroundColor3 = Color3.fromRGB(10,10,10); btn_spin.Text = "SPAM ARG 1"; btn_spin.TextColor3 = Color3.fromRGB(255,255,255); btn_spin.Font = Enum.Font.Code; btn_spin.TextSize = 14; btn_spin.ZIndex = 2; btn_spin.Parent = main
    
    local btn_ability = Instance.new("TextButton"); btn_ability.Size = UDim2.new(0,180,0,40); btn_ability.Position = UDim2.new(0,204,0,280); btn_ability.BackgroundColor3 = Color3.fromRGB(10,10,10); btn_ability.Text = "SPAM ARG 2"; btn_ability.TextColor3 = Color3.fromRGB(255,255,255); btn_ability.Font = Enum.Font.Code; btn_ability.TextSize = 14; btn_ability.ZIndex = 2; btn_ability.Parent = main

    self.main = main; self.log = log; self.status = status; self.btn_spin = btn_spin; self.btn_ability = btn_ability
    return self
end

function UI:add_log(text, color)
    if not self.log or not self.log.Parent then return end
    local label = Instance.new("TextLabel"); label.Size = UDim2.new(1,-12,0,16); label.BackgroundTransparency = 1; label.Text = text; label.TextColor3 = color or Color3.fromRGB(180,180,180); label.Font = Enum.Font.Code; label.TextSize = 11; label.TextXAlignment = Enum.TextXAlignment.Left; label.TextWrapped = true; label.ZIndex = 3; label.Parent = self.log
    local labels = {}; for _, c in ipairs(self.log:GetChildren()) do if c:IsA("TextLabel") then table.insert(labels, c) end end
    if #labels > 50 then labels[1]:Destroy() end
    self.log.CanvasPosition = Vector2.new(0, self.log.AbsoluteCanvasSize.Y)
end
function UI:set_status(text, color) if self.status and self.status.Parent then self.status.Text = text; self.status.TextColor3 = color end end

-- ============================================================
-- LÓGICA (Adaptada do script do Volleyball)
-- ============================================================
local is_spamming = false
local target_rf = nil

local ui = UI.new()

-- Função que busca o RemoteFunction, seja no Knit ou solto no ReplicatedStorage
local function find_remote()
    local rs = game:GetService("ReplicatedStorage")
    
    -- 1. Tenta achar o Knit (exatamente como o script do Volleyball)
    local ok, knitIndex = pcall(function() return rs:WaitForChild("Packages", 2):WaitForChild("_Index", 2) end)
    if ok and knitIndex then
        for _, v in ipairs(knitIndex:GetChildren()) do
            if v.Name:lower():find("knit") then
                local ok2, knitFolder = pcall(function() return v:WaitForChild("knit", 2):WaitForChild("Services", 2) end)
                if ok2 and knitFolder then
                    -- Varre todos os serviços do Knit procurando nossos alvos
                    for _, service in ipairs(knitFolder:GetChildren()) do
                        local ok3, rfFolder = pcall(function() return service:WaitForChild("RF", 2) end)
                        if ok3 and rfFolder then
                            for _, targetName in ipairs(CONFIG.target_names) do
                                local rf = rfFolder:FindFirstChild(targetName)
                                if rf and rf:IsA("RemoteFunction") then
                                    ui:add_log("Achou no Knit: " .. service.Name .. ".RF." .. targetName, Color3.fromRGB(120,255,120))
                                    return rf
                                end
                            end
                        end
                    end
                end
            end
        end
    end

    -- 2. Se não achar no Knit, procura solto no ReplicatedStorage (EgoRemotes)
    for _, targetName in ipairs(CONFIG.target_names) do
        local rf = rs:FindFirstChild(targetName, true)
        if rf and rf:IsA("RemoteFunction") then
            ui:add_log("Achou no RS: " .. rf:GetFullName(), Color3.fromRGB(120,255,120))
            return rf
        end
    end

    return nil
end

local function start_spam(arg_value)
    if is_spamming then ui:add_log("Já está rodando. Desligue primeiro.", Color3.fromRGB(255,120,120)); return end
    
    if not target_rf then
        target_rf = find_remote()
        if not target_rf then
            ui:add_log("RemoteFunction não encontrado no jogo.", Color3.fromRGB(255,120,120))
            return
        end
    end

    is_spamming = true
    ui:set_status("Spammando InvokeServer(" .. arg_value .. ")...", Color3.fromRGB(120,255,120))
    ui:add_log("Iniciando spam com argumento " .. arg_value, Color3.fromRGB(255,255,255))

    task.spawn(function()
        local count = 0
        while is_spamming do
            pcall(function()
                target_rf:InvokeServer(arg_value)
            end)
            count = count + 1
            if count % 20 == 0 then
                ui:set_status(string.format("Spam: %d | Arg: %s", count, arg_value), Color3.fromRGB(120,255,120))
            end
            task.wait(0.1) -- Mesmo tempo do script do Volleyball
        end
    end)
end

local function stop_spam()
    is_spamming = false
    ui:set_status("Parado.", Color3.fromRGB(180,180,180))
    ui:add_log("Spam parado.", Color3.fromRGB(255,120,120))
end

-- Botões
ui.btn_spin.MouseButton1Click:Connect(function()
    if is_spamming then stop_spam() else start_spam(1) end
end)

ui.btn_ability.MouseButton1Click:Connect(function()
    if is_spamming then stop_spam() else start_spam(2) end
end)

ui:add_log("kota v16 (Baseado no Volleyball) carregado.", Color3.fromRGB(255,255,255))
ui:add_log("Clique em SPAM ARG 1 ou 2.", Color3.fromRGB(180,180,180))
