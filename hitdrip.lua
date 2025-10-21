--[[
    Extracted Hatdrop Function and Dependencies
    This script contains the core logic for the Hatdrop mechanism, 
    including the required helper functions and initial setup (parts, globals).
    It will run the hatdrop logic on the initial character and on respawns.
    
    NOTE: The global variables (GENV/options) are mocked with placeholders 
    to ensure the script runs independently. If integrating into a larger script 
    like emp_reanim_v8_1 (1).txt, you should remove the "Mock Global Environment" 
    section and ensure the variables like 'options', 'GENV.headhats', 
    'GENV.right', and 'GENV.left' are correctly defined in your main script's scope.
--]]

-- Services and Player
local game = game
local workspace = game:GetService("Workspace")
local ps = game:GetService("RunService").PostSimulation
local Player = game.Players.LocalPlayer

-- Mock Global Environment (as referenced by the original script)
-- In a real execution environment, these should already be defined.
local getgenv = getgenv or function() return {} end
local sethiddenproperty = sethiddenproperty or nil -- SAFELY DEFINE sethiddenproperty
local GENV = getgenv()
GENV.options = GENV.options or {
    outlinesEnabled = true,
    leftToy = "meshid:0", -- Placeholder
    rightToy = "meshid:0", -- Placeholder
    HeadHatTransparency = 1,
    lefthandrotoffset = Vector3.new(0, 0, 0), -- Added required properties
    righthandrotoffset = Vector3.new(0, 0, 0), -- Added required properties
}
GENV.headhats = GENV.headhats or {}
GENV.right = GENV.right or "meshid:0"
GENV.left = GENV.left or "meshid:0"

local options = GENV.options

-- Helper function to create a placeholder part
local function createpart(size, name, h)
	local Part = Instance.new("Part")
	if h and options.outlinesEnabled then 
		local SelectionBox = Instance.new("SelectionBox")
		SelectionBox.Adornee = Part
		SelectionBox.LineThickness = 0.05
		SelectionBox.Parent = Part
	end
	Part.Parent = workspace
    -- Check if Character and HumanoidRootPart exist before setting CFrame
    local hmr = Player.Character and Player.Character:FindFirstChild("HumanoidRootPart")
    if hmr then
        Part.CFrame = hmr.CFrame
    else
        Part.CFrame = CFrame.new(0, 0, 0)
    end
	Part.Size = size
	Part.Transparency = 1
	Part.CanCollide = false
	Part.Anchored = true
	Part.Name = name
	return Part
end

-- Create Parts for Accessory Anchors
local lefthandpart = createpart(Vector3.new(2,1,1), "moveRH", true)
local righthandpart = createpart(Vector3.new(2,1,1), "moveRH", true)
local headpart = createpart(Vector3.new(1,1,1), "moveH", false)
local lefttoypart = createpart(Vector3.new(1,1,1), "LToy", true)
local righttoypart =  createpart(Vector3.new(1,1,1), "RToy", true)
local rightarmalign = nil -- State variable from original script

local parts = {
    left = lefthandpart,
    right = righthandpart,
    headhats = headpart,
    leftToy = lefttoypart,
    rightToy = righttoypart,
}

-- Check if the Part is network owned by the client
function _isnetworkowner(Part)
	return Part.ReceiveAge == 0
end

-- Extracts the numerical ID from a MeshId string
function filterMeshID(id)
	return (string.find(id,'assetdelivery')~=nil and string.match(string.sub(id,37,#id),"%d+")) or string.match(id,"%d+")
end

-- Finds if a MeshId is configured in the globals
function findMeshID(id)
    for i,v in pairs(GENV.headhats) do
        if i=="meshid:"..id then return true,"headhats" end
    end
    if GENV.right=="meshid:"..id then return true,"right" end
    if GENV.left=="meshid:"..id then return true,"left" end
    if options.leftToy=="meshid:"..id then return true,"leftToy" end
    if options.rightToy=="meshid:"..id then return true,"rightToy" end
    return false
end

-- Finds if an Accessory name is configured in the globals
function findHatName(id)
    for i,v in pairs(GENV.headhats) do
        if i==id then return true,"headhats" end
    end
    if GENV.right==id then return true,"right" end
    if GENV.left==id then return true,"left" end
    if options.leftToy==id then return true,"leftToy" end
    if options.rightToy==id then return true,"rightToy" end
    return false
end

-- Function to align an accessory handle (Part1) to an anchor part (Part0)
function Align(Part1, Part0, cf, isflingpart) 
    local up = isflingpart -- Variable not strictly used in this extracted context but kept for completeness
    local velocity = Vector3.new(0,-30,0)
    local con;
    
    con = ps:Connect(function()
        if up~=nil then up=not up end
        if not Part1:IsDescendantOf(workspace) then con:Disconnect() return end
        if not _isnetworkowner(Part1) then return end
        Part1.CanCollide = false
        Part1.CFrame = Part0.CFrame * cf
        Part1.Velocity = velocity or Vector3.new(0,-30,0)
    end)

    return {
        SetVelocity = function(self, v) velocity=v end,
        SetCFrame = function(self, v) cf=v end,
    }
end

-- Extracted Hatdrop Function (Renamed from NewHatdropCallback)
function HatdropFunction(Character, callback)
    local block = false -- Set to true if you want to remove meshes
    local character = Character
    
    -- Essential character check
    if not character or not character.Parent then return end

    -- Resetting character reference (Critical for some executors/hacks)
    game.Players.LocalPlayer.Character = nil
    game.Players.LocalPlayer.Character = character
    task.wait(game.Players.RespawnTime + 0.05)
    
    -- Disable death state
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if humanoid then
        humanoid:SetStateEnabled(Enum.HumanoidStateType.Dead, false)
    end
    
    -- Remove torso parts (R6 and R15 compatibility)
    for i, v in pairs(character:GetChildren()) do
        if v.Name == "Torso" or v.Name == "UpperTorso" then
            v:Destroy()
        end
    end
    
    -- Remove HumanoidRootPart
    if character:FindFirstChild("HumanoidRootPart") then
        character.HumanoidRootPart:Destroy()
    end
    
    -- Set accessory backend states (Critical for drop)
    for i,v in pairs(character:GetChildren()) do
        if v:IsA("Accessory") then
            -- NOTE: sethiddenproperty is specific to executor environments.
            if sethiddenproperty then
                sethiddenproperty(v,"BackendAccoutrementState", 0) -- 0-3 works, 4 is default in-character state
            end
        end
    end
    
    -- Optional: Remove meshes if block is true
    if block == true then 
        for i,v in pairs(character:GetDescendants()) do
            if v:IsA("SpecialMesh") then
                v:Destroy()
            end
        end
    end
    
    -- Remove all other body parts except Head
    for i,v in pairs(character:GetChildren()) do
        if v:IsA("BasePart") and v.Name ~= "Head" then
            v:Destroy() -- This triggers ChildRemoving event
        end
    end
    
    -- Optional: Remove head
    if character:FindFirstChild("Head") and character.Head.ClassName ~= "Humanoid" then -- Prevent removing Humanoid if named "Head"
        character.Head:Destroy() -- Changed from :remove() to :Destroy() to avoid potential "attempt to nil call"
    end
    
    -- Wait a bit for everything to process
    task.wait(0.1)
    
    -- Get all remaining accessories and prepare them for alignment
    local foundmeshids = {}
    local allhats = {}
    
    for i,v in pairs(character:GetChildren()) do
        if not v:IsA"Accessory" then continue end
        local handle = v:FindFirstChild("Handle")
        if not handle then continue end
        local mesh = handle:FindFirstChildOfClass("SpecialMesh")
        if not mesh then continue end
        
        local mesh_id = filterMeshID(mesh.MeshId)
        local is, d = findMeshID(mesh_id)
        
        -- Check for duplicates using MeshId
        if foundmeshids["meshid:"..mesh_id] then 
            is = false 
        else 
            foundmeshids["meshid:"..mesh_id] = true 
        end
	
        if is then
            table.insert(allhats, {v, d, "meshid:"..mesh_id})
        else
            local is_name, d_name = findHatName(v.Name)
            if not is_name then continue end
            table.insert(allhats, {v, d_name, v.Name})
        end
    end
    
    callback(allhats)
end

-- Execute the Hatdrop function on the current character
HatdropFunction(Player.Character, function(allhats)
    for i,v in pairs(allhats) do
        local handle = v[1]:FindFirstChild("Handle")
        if not handle then continue end
        
        if v[2]=="headhats" then 
            handle.Transparency = options.HeadHatTransparency or 1 
        end
        
        -- Determine CFrame offset
        local cf_offset = (v[2] == "headhats") and GENV[v[2]][v[3]] or CFrame.identity

        local align = Align(handle, parts[v[2]], cf_offset)
        if v[2]=="right" then
            rightarmalign = align
        end
    end
end)

-- Handle character respawning
GENV.conn = Player.CharacterAdded:Connect(function(Character)
    task.wait(0.5) -- Wait for character to fully load
    HatdropFunction(Character, function(allhats)
        for i,v in pairs(allhats) do
            local handle = v[1]:FindFirstChild("Handle")
            if not handle then continue end
            
            if v[2]=="headhats" then 
                handle.Transparency = options.HeadHatTransparency or 1 
            end

            local cf_offset = (v[2] == "headhats") and GENV[v[2]][v[3]] or CFrame.identity

            local align = Align(handle, parts[v[2]], cf_offset)
            if v[2]=="right" then
                rightarmalign = align
            end
        end
    end)
end)
