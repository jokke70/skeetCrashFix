local playerList = {};
local ffi = require( "ffi" )
local glowObjectIndexes = {};

local function ReadUInt( address )
    return ffi.cast( "unsigned int*", address )[0]
end

local function GetItemIndex( targetTable, item )
    for i=1,table.getn( targetTable ) do
        if targetTable[i] == item then
            return i
        end
    end
end

local GetGlowObjectManager_t = "struct CGlowObjectManager*( __cdecl* )( )"
local RegisterGlowObject_t = "int( __thiscall* )( struct CGlowObjectManager*, void*, const Vector&, bool, bool, int )"
local GetClientEntity_t = "void*( __thiscall* )( void*, int )"
local IsInGame_t = "bool( __thiscall* )( void* )"

ffi.cdef[[
    struct Vector
    {
        float r, g, b;
    };

    struct CAllocator_GlowObjectDefinition_t
    {
        struct GlowObjectDefinition_t *m_pMemory;
        int m_nAllocationCount;
        int m_nGrowSize;
    };

    struct CUtlVector_GlowObjectDefinition_t 
    {
        struct CAllocator_GlowObjectDefinition_t m_Memory;
        int m_Size;
        struct GlowObjectDefinition_t *m_pElements;
    };

    struct GlowObjectDefinition_t
    {
        int m_nNextFreeSlot;
        void *m_pEntity;
        struct Vector m_vGlowColor;
        float m_flGlowAlpha;
        char pad01[16];
        bool m_bRenderWhenOccluded;
        bool m_bRenderWhenUnoccluded;
        bool m_bFullBloomRender;
        char pad02;
        int m_nFullBloomStencilTestValue;
        int m_nRenderStyle;
        int m_nSplitScreenSlot;
        //Total size: 0x38 bytes
    };

    struct CGlowObjectManager
    {
        struct CUtlVector_GlowObjectDefinition_t m_GlowObjectDefinitions;
        int m_nFirstFreeSlot;
    };
]]

local GetGlowObjectManager = ffi.cast( GetGlowObjectManager_t, client.find_signature( "client.dll", "\xA1\xCC\xCC\xCC\xCC\xA8\x01\x75\x4B" ) )
local RegisterGlowObject = ffi.cast( "unsigned int", client.find_signature( "client.dll", "\xE8\xCC\xCC\xCC\xCC\x89\x03\xEB\x02" ) )
RegisterGlowObject = ffi.cast( RegisterGlowObject_t, RegisterGlowObject + 5 + ReadUInt (RegisterGlowObject + 1 ) )
local clientEntityList = client.create_interface( "client.dll", "VClientEntityList003" )
local GetClientEntityRaw = ffi.cast( GetClientEntity_t, ReadUInt( ReadUInt( ffi.cast( "unsigned int", clientEntityList ) ) + 3 * 4 ) )
local engineClient = client.create_interface( "engine.dll", "VEngineClient014" )
local IsInGameRaw = ffi.cast( IsInGame_t, ReadUInt( ReadUInt( ffi.cast( "unsigned int", engineClient ) ) + 26 * 4 ) )

local function getClientEnt(index)
    return GetClientEntityRaw( clientEntityList, index )
end

local function CreateGlowObject(ent, color, alpha, style)
    local glowObjectManager = GetGlowObjectManager( )
    local index = RegisterGlowObject( glowObjectManager, ffi.cast( "void*", ent ), ffi.new( "Vector", color ), true, true, -1 )
    glowObjectManager.m_GlowObjectDefinitions.m_Memory.m_pMemory[index].m_vGlowColor = color
    glowObjectManager.m_GlowObjectDefinitions.m_Memory.m_pMemory[index].m_flGlowAlpha = alpha
    glowObjectManager.m_GlowObjectDefinitions.m_Memory.m_pMemory[index].m_nRenderStyle = style
    glowObjectManager.m_GlowObjectDefinitions.m_Memory.m_pMemory[index].m_bRenderWhenOccluded = true
    glowObjectManager.m_GlowObjectDefinitions.m_Memory.m_pMemory[index].m_bRenderWhenUnoccluded = true
    table.insert( glowObjectIndexes, index )
end

local function SetGlowObjectColor(index, color, alpha)
    local glowObjectManager = GetGlowObjectManager( )
    glowObjectManager.m_GlowObjectDefinitions.m_Memory.m_pMemory[index].m_vGlowColor = color
    glowObjectManager.m_GlowObjectDefinitions.m_Memory.m_pMemory[index].m_flGlowAlpha = alpha
end

local function SetGlowObjectRender(index, status)
    local glowObjectManager = GetGlowObjectManager( )
    glowObjectManager.m_GlowObjectDefinitions.m_Memory.m_pMemory[index].m_bRenderWhenOccluded = status
    glowObjectManager.m_GlowObjectDefinitions.m_Memory.m_pMemory[index].m_bRenderWhenUnoccluded = status
end

local function RemoveGlowObjects()
    local glowObjectManager = GetGlowObjectManager( )
    if (glowObjectIndexes ~= nil and type(glowObjectIndexes) == "table" and #glowObjectIndexes > 0) then
        for i = 1, table.getn( glowObjectIndexes ) do
            glowObjectManager.m_GlowObjectDefinitions.m_Memory.m_pMemory[glowObjectIndexes[i]].m_nNextFreeSlot = glowObjectManager.m_nFirstFreeSlot
            glowObjectManager.m_GlowObjectDefinitions.m_Memory.m_pMemory[glowObjectIndexes[i]].m_pEntity = ffi.cast( "void*", 0 )
            glowObjectManager.m_nFirstFreeSlot = glowObjectIndexes[i]
        end        
    end

    glowObjectIndexes = {};
    playerList = {};
end
--[[ 
 - Modified from https://gamesense.pub/forums/viewtopic.php?id=31726
 - Complete credit to Eggstickbtz and javierlambo
--]]

local references = {};
references.__index = references;
local localPlayer = entity.get_local_player();

local disableFix = ui.new_checkbox("LUA", "A", "Disable Crash Fix");

function ref(tab, groupbox, title)
    local a, b, c = type(tab), type(groupbox), type(title);
    if (a == "string" or b == "string" or c == "string") then
        local reference = ui.reference(tab, groupbox, title);
        if (reference == nil) then return nil; end
        return setmetatable({reference = reference, state = ui.get(reference) }, references);
    end
end

function references:set(value)
    if (type(ui.get(self.reference)) == type(value)) then
        ui.set(self.reference, value);
    end
end

local refDisabled = {
    ref("Visuals", "Player ESP", "Glow"),
    ref("Visuals", "Other ESP", "Grenades"),
};

ui.set_visible(refDisabled[1].reference, false);

local glowEnabled = ui.new_checkbox("Visuals", "Player ESP", "Glow");
local glowColor = ui.new_color_picker("Visuals", "Player ESP", "Glow", 255, 0, 255, 150);
local glowOnTeam = ui.reference("Visuals", "Player ESP", "Teammates");

local function colorCallback()
    if (glowObjectIndexes ~= nil and type(glowObjectIndexes) == "table" and #glowObjectIndexes > 0) then
        for i = 1, table.getn( glowObjectIndexes ) do
            r, g, b, a = ui.get(glowColor)
            if (not ui.get(glowEnabled)) then
                SetGlowObjectRender( glowObjectIndexes[i], false )
            else
                SetGlowObjectRender( glowObjectIndexes[i], true )
            end
            SetGlowObjectColor( glowObjectIndexes[i], { r / 255, g / 255, b / 255 }, a / 255 )
        end
    end
end

local function addPlayerGlow(entIndex)
    if (not ui.get(glowOnTeam)) then
        if (not entity.is_enemy(entIndex)) then
            return;
        end
    end

    local found = false;
    if (#playerList > 0) then
        for i = 1, #playerList do
            if (playerList[i].index == entIndex) then
                found = true;
            end
        end
    end

    if (not found and entIndex ~= nil and getClientEnt(entIndex) ~= nil) then
        CreateGlowObject(getClientEnt(entIndex), { 0.0, 0.0, 0.0 }, 0.0, 0);
        table.insert(playerList, { index = entIndex });
    end
end

local function enumPlayerListGlow(remove)
    if (localPlayer ~= nil) then
        if (remove ~= nil and remove == true) then
            RemoveGlowObjects();
        end

        local players = entity.get_players();

        for i = 1, #players do
            if (players[i] ~= nil) then
                addPlayerGlow(players[i]);
            end
        end
    end
end

local invalid = true;
local function runPaint()
    localPlayer = entity.get_local_player();
    if (localPlayer ~= nil and entity.is_alive(localPlayer)) then
        enumPlayerListGlow();
    end
    colorCallback();

    if (not ui.get(disableFix)) then
        for i = 1, #refDisabled do
            refDisabled[i]:set(false);
        end
    end

    if (localPlayer ~= nil and entity.is_alive(localPlayer)) then
        invalid = false;
    else
        if (not invalid) then
            RemoveGlowObjects();
        end

        invalid = true;
    end
end

runPaint();
client.set_event_callback("paint", runPaint);
client.set_event_callback("pre_config_load", runPaint);
client.set_event_callback("post_config_load", runPaint);
client.set_event_callback("player_connect_full", enumPlayerListGlow);
client.set_event_callback("shutdown", RemoveGlowObjects);
client.set_event_callback("switch_team", function() RemoveGlowObjects(); enumPlayerListGlow(); end);
ui.set_callback(glowOnTeam, function() RemoveGlowObjects(); enumPlayerListGlow(); end);
