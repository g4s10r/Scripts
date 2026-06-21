------- >> init

warn("[AURORA] Loading started at", os.clock());
local StartTime = os.clock();

local cloneref = cloneref or function(...)
    return ...;
end

if (not getgenv) then
    warn("[AURORA] Executor global env function doesn't exist!");
    return;
end

if (getgenv().Aurora and getgenv().Library) then
    warn("[AURORA] Script is already loaded!");

    Library:Notify("[Aurora] Already loaded!", 5);
    return;
end

if (not getgenv().getsenv) then
    warn("[AURORA] Your executor doesn't support getsenv");

    return game.GetService(game, "StarterGui"):SetCore("SendNotification", {
        Title = "[Aurora]";
        Text = "You need getsenv to run this script";
        Duration = 5;
    });
end

------- >> imports

local Library = loadstring(game.HttpGet(game, "https://raw.githubusercontent.com/g4s10r/Scripts/main/Linoria"))();
local ThemeManager = loadstring(game.HttpGet(game, "https://raw.githubusercontent.com/g4s10r/Scripts/refs/heads/main/ThemeManager"))();
local SaveManager = loadstring(game.HttpGet(game, "https://raw.githubusercontent.com/g4s10r/Scripts/refs/heads/main/SaveManager"))();

------- >> services

local Services = setmetatable({}, {
    __index = function(self, Index)
        local Service = cloneref(game.GetService(game, Index));
        self[Index] = Service;
        
        return Service;
    end
});

local ReplicatedStorage = Services.ReplicatedStorage;
local UserInputService = Services.UserInputService;
local RunService = Services.RunService;
local Players = Services.Players;
local Stats = Services.Stats;

------- >> signal library

local Signal = {
    Cache = {};
};

function Signal.new(Connection)
    assert(Connection ~= nil, "[Aurora] Signal.new missing argument");
    assert(typeof(Connection) == "RBXScriptConnection", "[Aurora] Signal.new requires a valid RBXScriptConnection");

    Signal.Cache[Connection] = Connection;

    return setmetatable({
        Connection = Connection
    }, {__index = Signal});
end

function Signal.Shutdown()	
    for _, Connection in Signal.Cache do
        Connection:Disconnect();
    end
end

function Signal:Disconnect()
    assert(type(self) == "table", "[Aurora] Signal type mismatch");

    self.Connection:Disconnect();
    self.Cache[self.Connection] = nil;
end

------- >> is loaded

Library:Notify("[Aurora] Script is initializing...", 5);

getgenv().Aurora = true;

if (not game.IsLoaded(game)) then
    local LoadingNotification = false;
    
    repeat
        if (not LoadingNotification) then
            Library:Notify("[Aurora] Waiting for game to be loaded", 5);
            LoadingNotification = true;
        end
    
        task.wait(0.1);
    until game.IsLoaded(game);
end

------- >> cheat table

local Aurora = {
    AutoFarm = {
        Enabled = false,
        Indicator = false,
        Invisicam = false,
        FixedCamera = false,
        Priority = 1
    }
};

------- >> variables

xpcall(function()
    local DealWithInput = nil;
    local Client = Players.LocalPlayer;
    local Ping = cloneref(Stats.PerformanceStats.Ping); -- What am i even doing atp

    local PlayerGui = Client.WaitForChild(Client, "PlayerGui", 3);
    local PlayerScripts = Client.WaitForChild(Client, "PlayerScripts", 3);
    local JobSystemClient = (PlayerScripts and PlayerScripts.WaitForChild(PlayerScripts, "JobSystemClient", 3));
    local Replication = (JobSystemClient and JobSystemClient.FindFirstChild(JobSystemClient, "Replication") and require(JobSystemClient.Replication));

    local ZapClient = ReplicatedStorage.WaitForChild(ReplicatedStorage, "client", 3);
    local Zap = (ZapClient and ZapClient.FindFirstChild(ZapClient, "net") and require(ZapClient.net));

    local VehicleUtil = ReplicatedStorage.WaitForChild(ReplicatedStorage, "VehicleUtil", 3);
    local VehicleEvents = (VehicleUtil and VehicleUtil.FindFirstChild(VehicleUtil, "Events") and require(VehicleUtil.Events));

    local SpawnedCars = workspace.WaitForChild(workspace, "SpawnedCars", 3);
    local Camera = workspace.CurrentCamera;

    pcall(function() -- This may error on mobile
        local DefaultCameraOcclusion = Client.DevCameraOcclusionMode;
        local DefaultCameraType = Camera.CameraType;
    end);

    ------- >> stuff

    if not (PlayerGui) then
        Library:Notify("[Aurora] Uhh why doesn't playergui exist???", 5);
        return;
    end

    if (not Zap or not Replication) then
        Library:Notify("[Aurora] Couldn't find network library", 5);
        return;
    end

    if (getconnections) then
        pcall(function() -- due to some bad getconnections implementations
            for _, Connection in getconnections(Client.Idled) do
                Connection:Disable();
            end
        end);
    else
        local VirtualUser = Services.VirtualUser;

        Signal.new(Client.Idled:Connect(function()
            VirtualUser.CaptureController(VirtualUser);
            VirtualUser.ClickButton2(VirtualUser, Vector2.zero);
        end));
    end

    ------- >> ui

    local Window = Library:CreateWindow({
        Title = "Инкассатор - ROCKET",
        Center = true,
        AutoShow = true,
        TabPadding = 8,
        MenuFadeTime = 0.2
    });

    local Tabs = {
        ["Main"] = Window:AddTab("Main"),
        ["Settings"] = Window:AddTab("Settings")
    };

    local AutofarmSection = Tabs.Main:AddLeftGroupbox("Auto Farm");

    AutofarmSection:AddToggle("AutoFarm", {
        Text = "Auto Farm",
        Default = false,

        Callback = function(Value)
            Aurora.AutoFarm.Enabled = Value;
        end
    });

    AutofarmSection:AddDropdown("JobPriority", {
        Values = {"Random"}, --, "Highest Pay", "Closest Distance"},
        Default = 1,
        Multi = false,
        Text = "Job Priority",

        Callback = function(Value)
            Aurora.AutoFarm.Priority = ({["Random"] = 1, ["Highest Pay"] = 2, ["Closest Distance"] = 3})[Value]; -- this isn't really that useful, adding it is not needed
        end
    });

    AutofarmSection:AddToggle("StatusIndicator", {
        Text = "Status Indicator",
        Default = false,

        Callback = function(Value)
            Aurora.AutoFarm.Indicator = Value;
        end
    });

    AutofarmSection:AddToggle("3DRendering", {
        Text = "Disable 3D Rendering",
        Default = false,
        Tooltip = "Kinda better FPS, not much",

        Callback = function(Value)
            RunService.Set3dRenderingEnabled(RunService, not Value);
        end
    });

    AutofarmSection:AddToggle("CameraOcclusion", {
        Text = "Invisicam Occlusion",
        Default = false,
        Tooltip = "Prevents the camera from clipping with anything (recommended)",

        Callback = function(Value)
            Aurora.AutoFarm.Invisicam = Value;
            
            pcall(function()
                if (Value) then
                    Client.DevCameraOcclusionMode = Enum.DevCameraOcclusionMode.Invisicam;
                else
                    Client.DevCameraOcclusionMode = DefaultCameraOcclusion;
                end
            end);
        end
    });

    AutofarmSection:AddToggle("FixedCamera", {
        Text = "Fixed Camera",
        Default = false,
        Tooltip = "Camera is fixed (less motion sickness)",

        Callback = function(Value)
            Aurora.AutoFarm.FixedCamera = Value;

            pcall(function()
                if (Value and Camera.CameraSubject.Name == "CameraPartCam") then
                    Camera.CameraType = Enum.CameraType.Fixed;
                elseif (Camera.CameraSubject.Name == "CameraPartCam") then
                    Camera.CameraType = DefaultCameraType;
                end
            end)
        end
    });

    local StatsSection = Tabs.Main:AddRightGroupbox("Stats");

    local MoneyLabel = StatsSection:AddLabel("Money Made <font color='rgb(0, 80, 255)'>0$</font>");
    local TimeLabel = StatsSection:AddLabel("Time Ran <font color='rgb(0, 80, 255)'>0 seconds</font>");

    ------- >> functions

    local function GetPing()
        return Ping.GetValue(Ping) / 1000;
    end

    local function GetVehicle()
        local DrivingVehicle = Client.GetAttribute(Client, "DrivingVehicle");
        return (DrivingVehicle and SpawnedCars.FindFirstChild(SpawnedCars, DrivingVehicle));
    end

    local function GetActiveJobs()
        return Replication.JobsState.Global.RoSwift.AvailableRides;
    end

    local function GetActiveJob()
        return Replication.JobsState.Job;
    end

    local function GetLuggagePrompt()
        return Camera.QueryDescendants(Camera, "#VehiclePrompt ProximityPrompt[ActionText = \"Grab Luggage\"], #VehiclePrompt ProximityPrompt[ActionText = \"Give Luggage\"], #VehiclePrompt ProximityPrompt[ActionText = \"Store Luggage\"]")[1];
    end

    local function GetRealLength(Table)
        local Count = 0;

        for _, _ in Table do
            Count += 1;    
        end

        return Count;
    end

    local function CalculateRealPay(PayInfo)
        local Base = PayInfo.BasePay * PayInfo.Efficiency + PayInfo.Bonus;

        for _, Value in PayInfo.Extras do
            Base += Value;
        end

        for _, Value in PayInfo.Boosts do
            Base *= Value.multiplier;
        end
        
        return math.floor(math.max(Base, 0));
    end

    local function GetHandbrake()
        return debug.getupvalue(DealWithInput, 18);
    end

    local function SetHandbrake(State)
        debug.setupvalue(DealWithInput, 18, State);
    end

    local function SetEngine(State)
        VehicleEvents.Client.RequestStartupSequence:Fire((State and 2) or 0);
    end

    local function IsAlive()
        local Character = Client.Character;
        return (Character and Character.FindFirstChild(Character, "HumanoidRootPart") and Character.FindFirstChild(Character, "Humanoid") and Character.Humanoid.Health > 0);
    end

    local function IsJobOngoing()
        return Replication.JobsState.Job ~= nil;
    end

    local function IsVehicleRunning(Vehicle)
        return Vehicle.GetAttribute(Vehicle, "LastCGear") ~= 0;
    end

    ------- >> loops

    local NoVehicleNotification = 0;
    local NoJobNotification = 0;
    local StartJobCooldown = 0;

    local TimeRan, MoneyMade = 0, 0;
    local LastTimeUpdate, LastMoneyUpdate = 0, 0;

    local CollectedPayments = {};
    local DrawCache = {};

    local function Draw(ClassName, Properties)
        local New = Drawing.new(ClassName);

        for Index, Value in Properties do
            New[Index] = Value;
        end

        DrawCache[New] = true;
        return New;
    end

    local StatusIndicator = Draw("Text", {
        Text = "",
        Size = 18,
        Visible = true,
        Outline = true,
        Color = Color3.new(1, 1, 1),
        Position = Vector2.new(20, Camera.ViewportSize.Y * 0.5)
    });


    Signal.new(RunService.PreRender:Connect(function(Delta)
        StatusIndicator.Visible = Aurora.AutoFarm.Indicator;
        StatusIndicator.Position = Vector2.new(20, Camera.ViewportSize.Y * 0.5);

        if (Aurora.AutoFarm.Enabled) then
            TimeRan += Delta;
        end

        if (TimeRan - LastTimeUpdate >= 0.1) then
            LastTimeUpdate = TimeRan;
            TimeLabel.SetText(TimeLabel, string.format("Time Ran <font color='rgb(0, 80, 255)'>%.1f</font> seconds", TimeRan));
        end

        if (MoneyMade ~= LastMoneyUpdate) then
            LastMoneyUpdate = MoneyMade;
            MoneyLabel.SetText(MoneyLabel, `Total Money Made <font color="rgb(0, 80, 255)">{MoneyMade}</font>`);
        end
    end));

    Signal.new(RunService.PreRender:Connect(function()
        if (not Aurora.AutoFarm.Enabled or not IsAlive()) then
            return;
        end

        if (not IsJobOngoing()) then
            local Jobs = GetActiveJobs();
            
            if (#Jobs == 0) then
                if (os.clock() - NoJobNotification > 5) then
                    Library:Notify("[Aurora] No active jobs are available", 5);
                    NoJobNotification = os.clock();
                end
                
                return;
            end
            
            if (os.clock() - StartJobCooldown > GetPing() * 2) then -- gotta avoid spamming
                local Job = Jobs[1];

                Zap.JobInvoke.Call("StartJob", {
                    "RoSwift",
                    Job.RideId
                });
                
                StartJobCooldown = os.clock();
            end
            
            return;
        end

        if (#Replication.JobsState.Paychecks > 0) then
            for _, Paycheck in Replication.JobsState.Paychecks do
                if (Paycheck.CanCollect and not CollectedPayments[Paycheck.PaycheckId]) then
                    if (GetRealLength(CollectedPayments) >= 25) then -- no memory leaks allowed here
                        table.clear(CollectedPayments);
                    end

                    CollectedPayments[Paycheck.PaycheckId] = true;
                    Zap.CollectPaycheck.Call(Paycheck.PaycheckId);
                    MoneyMade += CalculateRealPay(Paycheck.PaycheckData.PayInfo);
                end
            end
        end
        
        local Vehicle = GetVehicle();

        if (Vehicle) then
            local SeatPart = Vehicle.FindFirstChild(Vehicle, "DriveSeat");
            SeatPart.AssemblyLinearVelocity = vector.zero;
            SeatPart.AssemblyAngularVelocity = vector.zero;

            if (type(DealWithInput) ~= "function") then
                local Interface = PlayerGui.FindFirstChild(PlayerGui, "A-Chassis Interface");
                local Drive = (Interface and Interface.FindFirstChild(Interface, "Drive"));

                if (Drive) then
                    DealWithInput = getsenv(Drive)["DealWithInput"];
                else
                    Library:Notify("[Aurora] DealWithInput is currently nil, no need to report it to the dev. Just a warning lol.", 5);
                    return;
                end
            end

            if (not IsVehicleRunning(Vehicle)) then -- Figured this wasn't even necessary, I'm keepin it anyways lol
                SetEngine(true);
            end
            
            if (not GetHandbrake()) then -- i have no idea why i added it but i added it and not removing it lol
                SetHandbrake(true);
            end
            
            local Job = GetActiveJob();

            if (Aurora.AutoFarm.Indicator) then
                StatusIndicator.Text = string.format("Job Id: %s\nStep Index: %d\nStep Description: %s\nStep Type: %s", Job.JobData.Ride.RideId, Job.StepIndex, Job.Step.StepDescription, Job.Step.Type);
            end

            if (Job.StepIndex == 1 and (Job.Step.Type == "ArriveStart" or Job.Step.Type == "PickUp")) then
                Vehicle.PivotTo(Vehicle, Job.JobData.Ride.StartLocation.CFrame); 
            end

            if (Job.StepIndex == 2) then
                if (Job.Step.Type == "Pickup") then
                    local Prompt = GetLuggagePrompt();
                    fireproximityprompt(Prompt);
                elseif (Job.Step.Type == "NPCEnter") then
                    return;
                end
            end

            if (Job.StepIndex == 3) then
                if (Job.Step.Type == "Store") then
                    local Prompt = GetLuggagePrompt();
                    fireproximityprompt(Prompt);
                elseif (Job.Step.Type == "DropOff") then
                    Vehicle.PivotTo(Vehicle, Job.JobData.Ride.EndLocation.CFrame);
                    return;
                end
            end

            if (Job.StepIndex == 4 and Job.Step.Type == "NPCEnter") then
                return;
            end

            if (Job.StepIndex == 5 and Job.Step.Type == "ArriveEnd") then
                Vehicle.PivotTo(Vehicle, Job.JobData.Ride.EndLocation.CFrame);
            end
            
            if (Job.StepIndex == 6 and Job.Step.Type == "Grab") then
                local Prompt = GetLuggagePrompt();
                fireproximityprompt(Prompt);
            end

            if (Job.StepIndex == 7 and Job.Step.Type == "Give") then
                local Prompt = GetLuggagePrompt();
                fireproximityprompt(Prompt);
            end
        else
            local SpawnedVehicles = Zap.GetSpawnedVehicles.Call();

            if (#SpawnedVehicles == 0) then
                if (os.clock() - NoVehicleNotification > 5) then
                    Library:Notify("[Aurora] Please spawn a vehicle", 5);
                    NoVehicleNotification = os.clock();
                end

                return;
            end

            local Vehicle = SpawnedCars.FindFirstChild(SpawnedCars, Client.Name.."Car_"..SpawnedVehicles[1]["VehicleUID"]);
            local SeatPart = (Vehicle and Vehicle.FindFirstChild(Vehicle, "DriveSeat"));
            local Prompt = (SeatPart and SeatPart.FindFirstChild(SeatPart, "SeatingUI"));

            if (Vehicle and SeatPart and Prompt) then
                local Character = Client.Character;
                Character.PivotTo(Character, SeatPart.CFrame);

                RunService.Heartbeat:Wait();
                fireproximityprompt(Prompt);
                RunService.Heartbeat:Wait();
            end
        end
    end));

    Signal.new(PlayerGui.ChildAdded:Connect(function(Child)
        if (Child.Name == "A-Chassis Interface") then
            DealWithInput = nil;
            local Drive = Child.WaitForChild(Child, "Drive", 3);
            DealWithInput = getsenv(Drive)["DealWithInput"];
        end
    end));

    Signal.new(Camera.GetPropertyChangedSignal(Camera, "CameraType"):Connect(function()
        task.defer(function()
            pcall(function()
                local CameraType = Camera.CameraType;
    
                if (CameraType ~= Enum.CameraType.Fixed) then
                    DefaultCameraType = CameraType;
                    
                    if (Aurora.AutoFarm.Invisicam and Camera.CameraSubject.Name == "CameraPartCam") then
                        Camera.CameraType = Enum.CameraType.Fixed;
                    end
                end
            end);
        end);
    end));

    Signal.new(Client.GetPropertyChangedSignal(Client, "DevCameraOcclusionMode"):Connect(function()
        pcall(function()
            local OcclusionMode = Client.DevCameraOcclusionMode;
    
            if (OcclusionMode ~= Enum.DevCameraOcclusionMode.Invisicam) then
                DefaultCameraOcclusion = OcclusionMode;
                
                if (Aurora.AutoFarm.Invisicam) then
                    Client.DevCameraOcclusionMode = Enum.DevCameraOcclusionMode.Invisicam;
                end
            end
        end);
    end));

    ------- >> finishing touches

    local MenuGroup = Tabs.Settings:AddLeftGroupbox("Menu");

    MenuGroup:AddButton("Unload", function() 
        Library:Unload();
    end);

    MenuGroup:AddButton("Rejoin", function() 
        Services.ExperienceService.LaunchExperience(Services.ExperienceService, {
            placeId = game.PlaceId,
            jobId = game.JobId,
        });
    end);

    MenuGroup:AddLabel("Menu bind"):AddKeyPicker("MenuKeybind", {Default = "RightShift", NoUI = true, Text = "Menu keybind"});

    Library.ToggleKeybind = Options.MenuKeybind;

    ThemeManager:SetLibrary(Library);
    SaveManager:SetLibrary(Library);

    SaveManager:IgnoreThemeSettings();
    SaveManager:SetIgnoreIndexes({"MenuKeybind"});

    ThemeManager:SetFolder("Aurora");
    SaveManager:SetFolder("Aurora/Rensselaer County");

    SaveManager:BuildConfigSection(Tabs.Settings);
    ThemeManager:ApplyToTab(Tabs.Settings);
    SaveManager:LoadAutoloadConfig();

    Library:OnUnload(function()
        Signal.Shutdown();

        Library.Unloaded = true;
        getgenv().Aurora = nil;

        for Draw, _ in DrawCache do
            Draw:Destroy();
        end

        if (getconnections) then
            for _, Connection in getconnections(Client.Idled) do
                Connection:Enable();
            end
        end

        pcall(function()
            Camera.CameraType = DefaultCameraType;
            Client.DevCameraOcclusionMode = DefaultCameraOcclusion;
        end);
    end);

    Library:Notify(("[Aurora] Loaded in %.2f seconds"):format(os.clock() - StartTime), 5);
end, function(Error)
    Library:Notify("[FATAL] Please report to dev: "..Error, 15);
end);
