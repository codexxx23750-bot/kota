-- [kota] Start Your Blue Lock Career — Final
-- Alvo: Start Your Blue Lock Career (NÃO Blue Lock Rivals)

local CONFIG = {
    base_interval = 1.2,
    spins_per_session = 40,
    session_pause_min = 30,
    session_pause_max = 120,
    hook_observe_time = 10,
    backoff_cap = 60,
    spin_keywords = {"spin", "giro", "sorte"},
    known_names = {"UseWeaponSpin", "UseFlowSpin", "SpinWeapon", "WeaponSpin", "FlowSpin", "LuckySpin"},
}

-- ============================================================
-- ANTI-BAN
-- ============================================================
local AntiBan = {}
AntiBan.__index = AntiBan

function AntiBan.new()
    return setmetatable({
        consecutive_errors = 0,
        attempts_this_session = 0,
        total_attempts = 0,
        total_err = 0,
        blacklist = {},
    }, AntiBan)
end

function AntiBan:jitter(base)
    return math.max(0.2, base * (0.6 + math.random() * 0.8))
end

function AntiBan:on_success()
    self.consecutive_errors = 0
end

function AntiBan:on_error()
    self.consecutive_errors = self.consecutive_errors + 1
    self.total_err = self.total_err + 1
    return CONFIG.base_interval * math.min(2 ^ self.consecutive_errors, CONFIG.backoff_cap / CONFIG.base_interval)
end

function AntiBan:needs_session_pause()
    return self.attempts_this_session >= CONFIG.spins_per_session
end

function AntiBan:session_pause()
    task.wait(CONFIG.session_pause_min + math.random() * (CONFIG.session_pause_max - CONFIG.session_pause_min))
    self.attempts_this_session = 0
end

function AntiBan:is_blacklisted(name)
    return self.blacklist[name] == true
end

function AntiBan:blacklist_remote(name)
    self.blacklist[name] = true
end

-- ============================================================
-- UI (preto e branco, nome "kota")
-- ============================================================
local UI = {}
UI.__index = UI

function UI.new(on_close_callback)
    local self = setmetatable({}, UI)
    self.gui = Instance.new("ScreenGui")
    self.gui.Name = "kota_ui"
    self.gui.ResetOnSpawn = false
    self.gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    if gethui then self.gui.Parent = gethui() else self.gui.Parent = game:GetService("CoreGui") end

    local main = Instance.new("Frame")
    main.Name = "main"
    main.Size = UDim2.new(0, 420, 0, 520)
    main.Position = UDim2.new(0.02, 0, 0.1, 0)
    main.BackgroundColor3 = Color3.fromRGB(10, 10, 10)
    main.BorderSizePixel = 0
    main.Active = true
    main.ZIndex = 1
    main.Parent = self.gui

    -- Arrastar manual
    local dragging, dragInput, dragStart, startPos
    local dragConnection

    main.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = main.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                end
            end)
        end
    end)

    main.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
            dragInput = input
        end
    end)

    dragConnection = game:GetService("UserInputService").InputChanged:Connect(function(input)
        if input == dragInput and dragging then
            local delta = input.Position - dragStart
            main.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end)

    self.gui.Destroying:Connect(function()
        if dragConnection then
            dragConnection:Disconnect()
        end
    end)

    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(31, 31, 31)
    stroke.Thickness = 1
    stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    stroke.Parent = main

    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, 0, 0, 40)
    title.BackgroundColor3 = Color3.fromRGB(10, 10, 10)
    title.Text = "kota"
    title.TextColor3 = Color3.fromRGB(255, 255, 255)
    title.Font = Enum.Font.Code
    title.TextSize = 20
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.ZIndex = 2
    title.Parent = main

    local title_pad = Instance.new("UIPadding")
    title_pad.PaddingLeft = UDim.new(0, 12)
    title_pad.Parent = title

    local close = Instance.new("TextButton")
    close.Size = UDim2.new(0, 32, 0, 32)
    close.Position = UDim2.new(1, -40, 0, 4)
    close.BackgroundColor3 = Color3.fromRGB(10, 10, 10)
    close.Text = "×"
    close.TextColor3 = Color3.fromRGB(255, 255, 255)
    close.Font = Enum.Font.Code
    close.TextSize = 18
    close.ZIndex = 2
    close.Parent = main
    close.MouseButton1Click:Connect(function()
        if on_close_callback then on_close_callback() end
        self.gui:Destroy()
    end)

    local status = Instance.new("TextLabel")
    status.Size = UDim2.new(1, -24, 0, 24)
    status.Position = UDim2.new(0, 12, 0, 44)
    status.BackgroundColor3 = Color3.fromRGB(10, 10, 10)
    status.Text = "idle"
    status.TextColor3 = Color3.fromRGB(180, 180, 180)
    status.Font = Enum.Font.Code
    status.TextSize = 12
    status.TextXAlignment = Enum.TextXAlignment.Left
    status.ZIndex = 2
    status.Parent = main

    local log = Instance.new("ScrollingFrame")
    log.Size = UDim2.new(1, -24, 0, 220)
    log.Position = UDim2.new(0, 12, 0, 72)
    log.BackgroundColor3 = Color3.fromRGB(5, 5, 5)
    log.BorderSizePixel = 0
    log.ScrollBarThickness = 4
    log.CanvasSize = UDim2.new(0, 0, 0, 0)
    log.AutomaticCanvasSize = Enum.AutomaticSize.Y
    log.ZIndex = 2
    log.Parent = main

    local log_layout = Instance.new("UIListLayout")
    log_layout.Padding = UDim.new(0, 2)
    log_layout.Parent = log

    local log_pad = Instance.new("UIPadding")
    log_pad.PaddingLeft = UDim.new(0, 6)
    log_pad.PaddingTop = UDim.new(0, 4)
    log_pad.Parent = log

    local counter = Instance.new("TextLabel")
    counter.Size = UDim2.new(1, -24, 0, 24)
    counter.Position = UDim2.new(0, 12, 0, 300)
    counter.BackgroundColor3 = Color3.fromRGB(10, 10, 10)
    counter.Text = "attempts: 0 | errors: 0"
    counter.TextColor3 = Color3.fromRGB(200, 200, 200)
    counter.Font = Enum.Font.Code
    counter.TextSize = 12
    counter.TextXAlignment = Enum.TextXAlignment.Left
    counter.ZIndex = 2
    counter.Parent = main

    local interval_label = Instance.new("TextLabel")
    interval_label.Size = UDim2.new(0, 90, 0, 24)
    interval_label.Position = UDim2.new(0, 12, 0, 332)
    interval_label.BackgroundColor3 = Color3.fromRGB(10, 10, 10)
    interval_label.Text = "interval (s)"
    interval_label.TextColor3 = Color3.fromRGB(160, 160, 160)
    interval_label.Font = Enum.Font.Code
    interval_label.TextSize = 11
    interval_label.TextXAlignment = Enum.TextXAlignment.Left
    interval_label.ZIndex = 2
    interval_label.Parent = main

    local interval = Instance.new("TextBox")
    interval.Size = UDim2.new(0, 80, 0, 24)
    interval.Position = UDim2.new(0, 110, 0, 332)
    interval.BackgroundColor3 = Color3.fromRGB(5, 5, 5)
    interval.BorderSizePixel = 1
    interval.BorderColor3 = Color3.fromRGB(31, 31, 31)
    interval.Text = tostring(CONFIG.base_interval)
    interval.TextColor3 = Color3.fromRGB(255, 255, 255)
    interval.Font = Enum.Font.Code
    interval.TextSize = 12
    interval.ZIndex = 2
    interval.Parent = main

    local session_label = Instance.new("TextLabel")
    session_label.Size = UDim2.new(0, 110, 0, 24)
    session_label.Position = UDim2.new(0, 200, 0, 332)
    session_label.BackgroundColor3 = Color3.fromRGB(10, 10, 10)
    session_label.Text = "spins/session"
    session_label.TextColor3 = Color3.fromRGB(160, 160, 160)
    session_label.Font = Enum.Font.Code
    session_label.TextSize = 11
    session_label.TextXAlignment = Enum.TextXAlignment.Left
    session_label.ZIndex = 2
    session_label.Parent = main

    local session = Instance.new("TextBox")
    session.Size = UDim2.new(0, 60, 0, 24)
    session.Position = UDim2.new(0, 312, 0, 332)
    session.BackgroundColor3 = Color3.fromRGB(5, 5, 5)
    session.BorderSizePixel = 1
    session.BorderColor3 = Color3.fromRGB(31, 31, 31)
    session.Text = tostring(CONFIG.spins_per_session)
    session.TextColor3 = Color3.fromRGB(255, 255, 255)
    session.Font = Enum.Font.Code
    session.TextSize = 12
    session.ZIndex = 2
    session.Parent = main

    local scan = Instance.new("TextButton")
    scan.Size = UDim2.new(0, 180, 0, 36)
    scan.Position = UDim2.new(0, 12, 0, 372)
    scan.BackgroundColor3 = Color3.fromRGB(10, 10, 10)
    scan.Text = "SCAN"
    scan.TextColor3 = Color3.fromRGB(255, 255, 255)
    scan.Font = Enum.Font.Code
    scan.TextSize = 14
    scan.ZIndex = 2
    scan.Parent = main

    local auto = Instance.new("TextButton")
    auto.Size = UDim2.new(0, 180, 0, 36)
    auto.Position = UDim2.new(0, 204, 0, 372)
    auto.BackgroundColor3 = Color3.fromRGB(10, 10, 10)
    auto.Text = "AUTO SPIN: OFF"
    auto.TextColor3 = Color3.fromRGB(255, 255, 255)
    auto.Font = Enum.Font.Code
    auto.TextSize = 14
    auto.ZIndex = 2
    auto.Parent = main

    self.main = main
    self.log = log
    self.status = status
    self.counter = counter
    self.interval = interval
    self.session = session
    self.scan_btn = scan
    self.auto_btn = auto
    return self
end

function UI:add_log(text, color)
    if not self.log or not self.log.Parent then return end
    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, -12, 0, 16)
    label.BackgroundTransparency = 1
    label.Text = text
    label.TextColor3 = color or Color3.fromRGB(180, 180, 180)
    label.Font = Enum.Font.Code
    label.TextSize = 11
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.TextWrapped = true
    label.ZIndex = 3
    label.Parent = self.log
    local labels = {}
    for _, c in ipairs(self.log:GetChildren()) do
        if c:IsA("TextLabel") then table.insert(labels, c) end
    end
    if #labels > 100 then labels[1]:Destroy() end
end

function UI:set_status(text, color)
    if self.status and self.status.Parent then
        self.status.Text = text
        self.status.TextColor3 = color
    end
end

function UI:update_counter(ab)
    if self.counter and self.counter.Parent then
        self.counter.Text = string.format("attempts: %d | errors: %d", ab.total_attempts, ab.total_err)
    end
end

-- ============================================================
-- SCANNER
-- ============================================================
local Scanner = {}
Scanner.__index = Scanner

local function has_keyword(s)
    if type(s) ~= "string" then return false end
    s = s:lower()
    for _, kw in ipairs(CONFIG.spin_keywords) do
        if s:find(kw, 1, true) then return true end
    end
    return false
end

function Scanner.new(ui, antiban)
    return setmetatable({
        ui = ui,
        antiban = antiban,
        candidates = {},
        captured_remote = nil,
        captured_args = nil,
        captured_args_n = 0,
        captured_method = nil,
        captured_prompt = nil,
        captured_click = nil,
        captured_bindable = nil,
        is_scanning = false,
        seen_objects = {},
    }, Scanner)
end

function Scanner:add_candidate(obj, name, ctype, layer, extra)
    if self.seen_objects[obj] then return false end
    self.seen_objects[obj] = true
    local c = {name = name, obj = obj, type = ctype, layer = layer}
    if extra then
        for k, v in pairs(extra) do c[k] = v end
    end
    table.insert(self.candidates, c)
    return true
end

function Scanner:try_known()
    self.ui:add_log("[K] trying known remote names...", Color3.fromRGB(120, 200, 120))
    local roots = {game:GetService("ReplicatedStorage")}
    local ok_pg, pg = pcall(function()
        return game:GetService("Players").LocalPlayer:FindFirstChild("PlayerGui")
    end)
    if ok_pg and pg then table.insert(roots, pg) end

    for _, name in ipairs(CONFIG.known_names) do
        for _, root in ipairs(roots) do
            if root then
                for _, obj in ipairs(root:GetDescendants()) do
                    if obj.Name == name and (obj:IsA("RemoteEvent") or obj:IsA("RemoteFunction")) then
                        local method = obj:IsA("RemoteFunction") and "InvokeServer" or "FireServer"
                        local ok = pcall(function()
                            if method == "InvokeServer" then
                                obj:InvokeServer()
                            else
                                obj:FireServer()
                            end
                        end)
                        if ok then
                            self.captured_remote = obj
                            self.captured_args = {}
                            self.captured_args_n = 0
                            self.captured_method = method
                            self.ui:add_log("[K] found and fired: " .. name, Color3.fromRGB(120, 255, 120))
                            return true
                        end
                    end
                end
            end
        end
    end
    return false
end

function Scanner:layer1_passive()
    self.ui:add_log("[L1] passive scan...", Color3.fromRGB(120, 200, 120))
    local roots = {game:GetService("ReplicatedStorage")}
    local ok_pg, pg = pcall(function()
        return game:GetService("Players").LocalPlayer:FindFirstChild("PlayerGui")
    end)
    if ok_pg and pg then table.insert(roots, pg) end

    local count = 0
    for _, root in ipairs(roots) do
        for _, obj in ipairs(root:GetDescendants()) do
            if obj:IsA("RemoteEvent") or obj:IsA("RemoteFunction") or obj:IsA("BindableEvent") then
                if has_keyword(obj.Name) then
                    if self:add_candidate(obj, obj.Name, obj.ClassName, 1) then
                        count = count + 1
                        self.ui:add_log("[L1] " .. obj.ClassName .. ": " .. obj:GetFullName(), Color3.fromRGB(255, 255, 255))
                    end
                end
            elseif obj:IsA("ProximityPrompt") or obj:IsA("ClickDetector") then
                if has_keyword(obj.Name) or (obj.Parent and has_keyword(obj.Parent.Name)) then
                    if self:add_candidate(obj, obj.Name, obj.ClassName, 1) then
                        count = count + 1
                        self.ui:add_log("[L1] " .. obj.ClassName .. ": " .. obj:GetFullName(), Color3.fromRGB(255, 255, 255))
                    end
                end
            end
        end
    end
    self.ui:add_log("[L1] found " .. count .. " candidates", Color3.fromRGB(120, 200, 120))
    return count
end

function Scanner:layer2_gc()
    self.ui:add_log("[L2] gc scan...", Color3.fromRGB(120, 200, 120))
    if not getgc then
        self.ui:add_log("[L2] getgc unavailable — skip", Color3.fromRGB(200, 160, 80))
        return 0
    end
    local count = 0
    local ok, gc = pcall(getgc, true)
    if not ok then return 0 end
    for _, obj in pairs(gc) do
        if type(obj) == "table" then
            pcall(function()
                for k, v in pairs(obj) do
                    if type(k) == "string" and has_keyword(k) then
                        if self:add_candidate(v, k, "gc_table", 2) then
                            count = count + 1
                        end
                    end
                end
            end)
        end
    end
    self.ui:add_log("[L2] found " .. count .. " from gc", Color3.fromRGB(120, 200, 120))
    return count
end

function Scanner:layer4_hook()
    self.ui:add_log("[L4] passive hook (" .. CONFIG.hook_observe_time .. "s)...", Color3.fromRGB(120, 200, 120))
    if not hookmetamethod or not getnamecallmethod then
        self.ui:add_log("[L4] hook unavailable — skip", Color3.fromRGB(200, 160, 80))
        return 0
    end

    local captured = {}
    local real_namecall
    local hook_ok = pcall(function()
        real_namecall = hookmetamethod(game, "__namecall", function(self, ...)
            local method = getnamecallmethod()
            if method == "FireServer" or method == "InvokeServer" then
                local ok_n, name = pcall(function() return self.Name end)
                if ok_n and has_keyword(name) then
                    local packed = table.pack(...)
                    table.insert(captured, {
                        name = name,
                        remote = self,
                        method = method,
                        args = packed,
                        args_n = packed.n,
                    })
                end
            end
            return real_namecall(self, ...)
        end)
    end)

    if not hook_ok then
        self.ui:add_log("[L4] hook failed — skip", Color3.fromRGB(200, 160, 80))
        return 0
    end

    local start_time = tick()
    while tick() - start_time < CONFIG.hook_observe_time do
        task.wait(0.1)
        if not self.ui.gui.Parent then break end
    end

    pcall(function()
        hookmetamethod(game, "__namecall", real_namecall)
    end)

    local count = 0
    for _, info in ipairs(captured) do
        if self:add_candidate(info.remote, info.name, "hooked_remote", 4, {
            args = info.args,
            args_n = info.args_n,
            method = info.method,
        }) then
            count = count + 1
            self.ui:add_log("[L4] captured: " .. info.name .. " (" .. info.method .. ")", Color3.fromRGB(255, 255, 255))
        end
    end
    self.ui:add_log("[L4] captured " .. count .. " remotes", Color3.fromRGB(120, 200, 120))
    return count
end

function Scanner:layer5_active_test()
    self.ui:add_log("[L5] active test...", Color3.fromRGB(120, 200, 120))
    local ordered = {}
    for _, c in ipairs(self.candidates) do
        if c.layer == 4 or (c.name and c.name:lower():find("spin")) then
            table.insert(ordered, c)
        end
    end
    for _, c in ipairs(self.candidates) do
        if not (c.layer == 4 or (c.name and c.name:lower():find("spin"))) then
            table.insert(ordered, c)
        end
    end

    for _, c in ipairs(ordered) do
        if self.antiban:is_blacklisted(c.name) then
            self.ui:add_log("[L5] skip blacklisted: " .. c.name, Color3.fromRGB(200, 160, 80))
        elseif (c.type == "hooked_remote" or c.type == "RemoteEvent" or c.type == "RemoteFunction") and c.obj then
            local method = c.method or (c.type == "RemoteFunction" and "InvokeServer" or "FireServer")
            local args = c.args or {}
            local args_n = c.args_n or #args
            local ok, err = pcall(function()
                if method == "InvokeServer" then
                    c.obj:InvokeServer(table.unpack(args, 1, args_n))
                else
                    c.obj:FireServer(table.unpack(args, 1, args_n))
                end
            end)
            if ok then
                self.captured_remote = c.obj
                self.captured_args = args
                self.captured_args_n = args_n
                self.captured_method = method
                self.ui:add_log("[L5] TARGET SET (" .. method .. "): " .. c.name, Color3.fromRGB(120, 255, 120))
                return true
            else
                self.antiban:blacklist_remote(c.name)
                self.ui:add_log("[L5] fail: " .. c.name .. " | " .. tostring(err), Color3.fromRGB(255, 120, 120))
            end
        elseif c.type == "ProximityPrompt" and c.obj then
            local ok = pcall(function() fireproximityprompt(c.obj) end)
            if ok then
                self.captured_prompt = c.obj
                self.ui:add_log("[L5] TARGET SET (Prompt): " .. c.name, Color3.fromRGB(120, 255, 120))
                return true
            else
                self.antiban:blacklist_remote(c.name)
            end
        elseif c.type == "ClickDetector" and c.obj then
            local ok = pcall(function() fireclickdetector(c.obj) end)
            if ok then
                self.captured_click = c.obj
                self.ui:add_log("[L5] TARGET SET (ClickDetector): " .. c.name, Color3.fromRGB(120, 255, 120))
                return true
            else
                self.antiban:blacklist_remote(c.name)
            end
        elseif c.type == "BindableEvent" and c.obj then
            local ok = pcall(function() c.obj:Fire() end)
            if ok then
                self.captured_bindable = c.obj
                self.ui:add_log("[L5] TARGET SET (BindableEvent): " .. c.name, Color3.fromRGB(120, 255, 120))
                return true
            else
                self.antiban:blacklist_remote(c.name)
            end
        end
    end
    self.ui:add_log("[L5] no remote confirmed", Color3.fromRGB(255, 120, 120))
    return false
end

function Scanner:run_all()
    if self.is_scanning then return "busy" end
    self.is_scanning = true
    self.candidates = {}
    self.seen_objects = {}
    self.captured_remote = nil
    self.captured_args = nil
    self.captured_args_n = 0
    self.captured_method = nil
    self.captured_prompt = nil
    self.captured_click = nil
    self.captured_bindable = nil

    -- Tenta nomes conhecidos primeiro
    if self:try_known() then
        self.is_scanning = false
        return true
    end

    -- Fallback: scan genérico
    local success, result = pcall(function()
        self:layer1_passive()
        self:layer2_gc()
        self:layer4_hook()
        return self:layer5_active_test()
    end)

    self.is_scanning = false

    if not success then
        self.ui:add_log("scan crashed: " .. tostring(result), Color3.fromRGB(255, 120, 120))
        return false
    end

    self.ui:add_log("scan done — " .. #self.candidates .. " total candidates", Color3.fromRGB(120, 200, 120))
    return result
end

-- ============================================================
-- EXECUTOR
-- ============================================================
local Executor = {}
Executor.__index = Executor

function Executor.new(ui, antiban, scanner)
    return setmetatable({
        ui = ui,
        antiban = antiban,
        scanner = scanner,
        active = false,
        thread = nil,
    }, Executor)
end

function Executor:start()
    if self.active then return end
    if not self.scanner.captured_remote and not self.scanner.captured_prompt and not self.scanner.captured_click and not self.scanner.captured_bindable then
        self.ui:add_log("no target — scan first", Color3.fromRGB(255, 120, 120))
        return
    end
    self.active = true
    self.ui:set_status("auto spin: ON", Color3.fromRGB(120, 255, 120))
    self.thread = task.spawn(function()
        while self.active do
            local ok, err = pcall(function()
                if not self.active then return end

                -- Se o alvo foi limpo (ex: novo scan em andamento), pausa
                if not self.scanner.captured_remote and not self.scanner.captured_prompt and not self.scanner.captured_click and not self.scanner.captured_bindable then
                    task.wait(1)
                    return
                end

                if self.scanner.captured_remote then
                    local remote = self.scanner.captured_remote
                    local args = self.scanner.captured_args or {}
                    local args_n = self.scanner.captured_args_n or #args
                    local method = self.scanner.captured_method or "FireServer"
                    if method == "InvokeServer" then
                        remote:InvokeServer(table.unpack(args, 1, args_n))
                    else
                        remote:FireServer(table.unpack(args, 1, args_n))
                    end
                elseif self.scanner.captured_prompt then
                    fireproximityprompt(self.scanner.captured_prompt)
                elseif self.scanner.captured_click then
                    fireclickdetector(self.scanner.captured_click)
                elseif self.scanner.captured_bindable then
                    self.scanner.captured_bindable:Fire()
                end
            end)

            if not self.active then break end

            -- Contador honesto: conta tentativas, não "spins confirmados"
            self.antiban.total_attempts = self.antiban.total_attempts + 1
            self.antiban.attempts_this_session = self.antiban.attempts_this_session + 1

            if ok then
                self.antiban:on_success()
            else
                local backoff = self.antiban:on_error()
                self.ui:add_log("exec err: " .. tostring(err), Color3.fromRGB(255, 120, 120))
                task.wait(backoff)
            end

            self.ui:update_counter(self.antiban)

            if self.active and self.antiban:needs_session_pause() then
                self.ui:set_status("session pause...", Color3.fromRGB(200, 160, 80))
                task.wait(CONFIG.session_pause_min + math.random() * (CONFIG.session_pause_max - CONFIG.session_pause_min))
                self.antiban.attempts_this_session = 0
                if self.active then
                    self.ui:set_status("auto spin: ON", Color3.fromRGB(120, 255, 120))
                end
            end

            if self.active and ok then
                task.wait(self.antiban:jitter(CONFIG.base_interval))
            end
        end
    end)
end

function Executor:stop()
    self.active = false
    if self.ui then
        self.ui:set_status("auto spin: OFF", Color3.fromRGB(180, 180, 180))
    end
end

-- ============================================================
-- BOOT
-- ============================================================
local antiban = AntiBan.new()
local executor
local ui = UI.new(function()
    if executor then executor:stop() end
end)
antiban.ui = ui

local scanner = Scanner.new(ui, antiban)
executor = Executor.new(ui, antiban, scanner)

ui.scan_btn.MouseButton1Click:Connect(function()
    ui:set_status("scanning...", Color3.fromRGB(200, 160, 80))
    task.spawn(function()
        local ok = scanner:run_all()
        if ok == "busy" then
            ui:add_log("already scanning — wait", Color3.fromRGB(200, 160, 80))
        elseif ok then
            ui:set_status("target ready", Color3.fromRGB(120, 255, 120))
            ui:add_log("ready — press AUTO SPIN", Color3.fromRGB(120, 255, 120))
        else
            ui:set_status("no target found", Color3.fromRGB(255, 120, 120))
        end
    end)
end)

ui.auto_btn.MouseButton1Click:Connect(function()
    if executor.active then
        executor:stop()
        ui.auto_btn.Text = "AUTO SPIN: OFF"
    else
        executor:start()
        if executor.active then
            ui.auto_btn.Text = "AUTO SPIN: ON"
        end
    end
end)

ui.interval.FocusLost:Connect(function()
    local n = tonumber(ui.interval.Text)
    if n and n >= 0.3 then n = math.floor(n) end
    if n and n < 0.3 then n = 0.3 end
    if not n then n = CONFIG.base_interval end
    CONFIG.base_interval = n
    ui.interval.Text = tostring(CONFIG.base_interval)
end)

ui.session.FocusLost:Connect(function()
    local n = tonumber(ui.session.Text)
    if n then n = math.floor(n) end
    if not n or n < 5 then n = 5 end
    if n > 1000 then n = 1000 end
    CONFIG.spins_per_session = n
    ui.session.Text = tostring(CONFIG.spins_per_session)
end)

ui:add_log("kota loaded", Color3.fromRGB(255, 255, 255))
ui:add_log("press SCAN to discover spin target", Color3.fromRGB(180, 180, 180))
