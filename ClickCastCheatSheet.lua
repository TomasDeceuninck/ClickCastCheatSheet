--[[
    WoW Addon: ClickCastCheatSheet (Lua Only)
    Displays 15 spell icons (5 primary, 5 SHIFT, 5 CTRL) based on Click Bindings.
    The icons are arranged in a clustered layout, and the entire group is movable.
--]]

-- *** 1. CONFIGURATION: CORE ADJUSTABLE PARAMETERS ***
local BASE_ICON_SIZE = 25; -- Primary icon size
local MOD_ICON_SIZE = 12.5; -- Modifier icon size
local SPACING = 0; 
local ADDON_NAME = "ClickCastCheatSheet";

-- *** 2. GLOBAL SCREEN POSITION OFFSET ***
-- Use these to move the entire group relative to the center of the screen (0, 0)
local SCREEN_OFFSET_X = 0; 
local SCREEN_OFFSET_Y = 0; 

-- *** 3. ICON ZOOM CONFIGURATION ***
-- Sets the texture coordinates to zoom into the center of the icon (0.10 to 0.90 = 20% zoom)
local ZOOM_MIN_COORD = 0.10;
local ZOOM_MAX_COORD = 0.90;

local B_SIZE = BASE_ICON_SIZE;
local M_SIZE = MOD_ICON_SIZE;
local isInitialized = false;

-- Vertical displacement for modifier icons relative to the base icon center.
local MOD_OFFSET = (B_SIZE / 2) + (M_SIZE / 2) + SPACING; 

-- BASE ANCHORS (Relative to the container's center 0,0) - Center point for the 5 main icons.
local BASE_ANCHORS = {
    -- MiddleButton (3): Top Center
    ["MiddleButton"] = {x = 0, y = (B_SIZE + SPACING * 2)},
    -- LeftButton (1): Left Center
    ["LeftButton"]   = {x = -(B_SIZE + SPACING * 2), y = 0},
    -- RightButton (2): Right Center
    ["RightButton"]  = {x = (B_SIZE + SPACING * 2), y = 0},
    -- Button4 (4): Bottom Left
    ["Button4"]      = {x = -(B_SIZE/2 + SPACING), y = -(B_SIZE + B_SIZE * 0.75)},
    -- Button5 (5): Bottom Right (Offset to be visually below Button4)
    ["Button5"]      = {x = (B_SIZE/2 + SPACING), y = (-(B_SIZE + B_SIZE * 0.75) - (B_SIZE / 2))}, 
};

-- Configuration: {key, button, modifier, frameSize, x_rel, y_rel}
local SPELL_CONFIG = {
    -- BASE (No Modifier) Group
    {key = "BUTTON3", button = "MiddleButton", modifier = "", frameSize = B_SIZE, x_rel = 0, y_rel = 0},
    {key = "BUTTON1", button = "LeftButton", modifier = "", frameSize = B_SIZE, x_rel = 0, y_rel = 0},
    {key = "BUTTON2", button = "RightButton", modifier = "", frameSize = B_SIZE, x_rel = 0, y_rel = 0},
    {key = "BUTTON4", button = "Button4", modifier = "", frameSize = B_SIZE, x_rel = 0, y_rel = 0},
    {key = "BUTTON5", button = "Button5", modifier = "", frameSize = B_SIZE, x_rel = 0, y_rel = 0},

    -- SHIFT Modifier Group (Positioned above the base icon)
    {key = "SHIFTB3", button = "MiddleButton", modifier = "SHIFT", frameSize = M_SIZE, x_rel = 0, y_rel = MOD_OFFSET}, 
    {key = "SHIFTB1", button = "LeftButton", modifier = "SHIFT", frameSize = M_SIZE, x_rel = 0, y_rel = MOD_OFFSET}, 
    {key = "SHIFTB2", button = "RightButton", modifier = "SHIFT", frameSize = M_SIZE, x_rel = 0, y_rel = MOD_OFFSET},
    {key = "SHIFTB4", button = "Button4", modifier = "SHIFT", frameSize = M_SIZE, x_rel = 0, y_rel = MOD_OFFSET},
    {key = "SHIFTB5", button = "Button5", modifier = "SHIFT", frameSize = M_SIZE, x_rel = 0, y_rel = MOD_OFFSET},
    
    -- CTRL Modifier Group (Positioned below the base icon)
    {key = "CTRLB3", button = "MiddleButton", modifier = "CTRL", frameSize = M_SIZE, x_rel = 0, y_rel = -MOD_OFFSET},
    {key = "CTRLB1", button = "LeftButton", modifier = "CTRL", frameSize = M_SIZE, x_rel = 0, y_rel = -MOD_OFFSET},
    {key = "CTRLB2", button = "RightButton", modifier = "CTRL", frameSize = M_SIZE, x_rel = 0, y_rel = -MOD_OFFSET},
    {key = "CTRLB4", button = "Button4", modifier = "CTRL", frameSize = M_SIZE, x_rel = 0, y_rel = -MOD_OFFSET},
    {key = "CTRLB5", button = "Button5", modifier = "CTRL", frameSize = M_SIZE, x_rel = 0, y_rel = -MOD_OFFSET},
};


-- Create a hidden frame early to register events
local eventFrame = CreateFrame("Frame", ADDON_NAME .. "EventFrame", UIParent); 


-- =========================================================================
-- CLICK BINDING LOOKUP LOGIC
-- =========================================================================

local function FindBoundSpellID(buttonName, modifierName)
    local this_spellid = nil
    
    -- Check if the C_ClickBindings API is available
    if not C_ClickBindings or not C_ClickBindings.GetProfileInfo then
        return nil 
    end

    local clickbindingsprofile = C_ClickBindings.GetProfileInfo()
    
    for _, v in pairs(clickbindingsprofile) do
        -- Match the specific mouse button and modifier string ("" or "SHIFT" or "CTRL")
        if v.button == buttonName and C_ClickBindings.GetStringFromModifiers(v.modifiers) == modifierName then
            if v.type == 1 then
                -- Type 1: Direct spell action
                this_spellid = v.actionID
                break
            elseif v.type == 2 then
                -- Type 2: Macro action (requires secondary lookup)
                this_spellid = GetMacroSpell(v.actionID) 
                break
            end
        end
    end
    
    return this_spellid
end


-- =========================================================================
-- INITIALIZATION WORKER FUNCTION
-- =========================================================================

local function InitializeWorker(self)
    -- Create the main container frame that holds all icons and is movable
    local f_container = CreateFrame("Frame", ADDON_NAME .. "ContainerFrame", UIParent); 

    if not C_Spell or not C_Spell.GetSpellInfo then
        error("C_Spell API not available yet. Cannot initialize.")
    end

    -- Setup the movable parent container
    f_container:SetFrameStrata("HIGH");
    f_container:SetSize(200, 200); -- Container size to encompass all 15 icons
    
    -- Anchor using the global offset variables
    f_container:SetPoint("CENTER", UIParent, "CENTER", SCREEN_OFFSET_X, SCREEN_OFFSET_Y);
    f_container:SetClampedToScreen(true);
    f_container:SetMovable(true);
    f_container:SetUserPlaced(true);
    f_container:EnableMouse(true);
    f_container:RegisterForDrag("LeftButton");
    f_container:SetScript("OnDragStart", f_container.StartMoving);
    f_container:SetScript("OnDragStop", f_container.StopMovingOrSizing);

    for _, config in ipairs(SPELL_CONFIG) do
        local foundSpellId = FindBoundSpellID(config.button, config.modifier);
        
        -- Only proceed if a spell binding was successfully found
        if foundSpellId then
            local SPELL_ID_TO_TRACK = foundSpellId;
            local key = config.key;
            local button = config.button;

            -- 1. Get Spell Icon Texture
            local ICON_TEXTURE;
            local spellInfo = C_Spell.GetSpellInfo(SPELL_ID_TO_TRACK);
            if spellInfo then
                ICON_TEXTURE = spellInfo.icon or spellInfo.iconID
            end
            
            -- Fallback to Question Mark if icon data is missing for a found spell ID
            if not ICON_TEXTURE then
                ICON_TEXTURE = "Interface\\ICONS\\INV_Misc_QuestionMark";
            end

            -- 2. Create the Icon Frame
            local iconFrame = CreateFrame("Frame", ADDON_NAME .. key .. "IconFrame", f_container);
            iconFrame:SetSize(config.frameSize, config.frameSize);
            
            -- Calculate Final Position
            local baseAnchor = BASE_ANCHORS[button];
            local totalX = baseAnchor.x + (config.x_rel or 0);
            local totalY = baseAnchor.y + (config.y_rel or 0);
            
            iconFrame:SetPoint("CENTER", f_container, "CENTER", totalX, totalY);
            iconFrame:SetFrameLevel(f_container:GetFrameLevel() + 1);
            
            -- 3. Create the Texture
            local texture = iconFrame:CreateTexture(nil, "BACKGROUND");
            texture:SetAllPoints(true);
            texture:SetTexture(ICON_TEXTURE);
            -- Apply the zoom configuration
            texture:SetTexCoord(ZOOM_MIN_COORD, ZOOM_MAX_COORD, ZOOM_MIN_COORD, ZOOM_MAX_COORD);
            texture:SetVertexColor(1, 1, 1, 1);
            
            iconFrame:Show();
        end
    end
    
    f_container:Show();
end


-- =========================================================================
-- INITIALIZATION LOGIC (Runs once after PLAYER_LOGIN)
-- =========================================================================

local function OnInitializationEvent(self, event, ...)
    if isInitialized then return end
    
    -- Execute the initialization worker inside a protected call
    local success, err = pcall(InitializeWorker, self)

    if success then
        isInitialized = true;
        -- Unregister the event to prevent re-initialization
        self:UnregisterEvent(event); 
    end
end


-- =========================================================================
-- EVENT REGISTRATION
-- =========================================================================

-- PLAYER_LOGIN ensures the AddOn initializes when all APIs are available
eventFrame:RegisterEvent("PLAYER_LOGIN");
eventFrame:SetScript("OnEvent", OnInitializationEvent);
