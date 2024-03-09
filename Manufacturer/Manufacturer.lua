require( 'strict' )

local Manufacturer = {}

local MODULE_NAME = 'Module:Manufacturer'

local TNT = require( 'Module:Translate' ):new()


--- Wrapper function for Module:Translate.translate
---
--- @param key string The translation key
--- @return string If the key was not found in the .tab page, the key is returned
local function translate( key, ... )
	return TNT:translate( MODULE_NAME .. '/i18n.json', {}, key, nil, {...} ) or key
end


--- Return matched manufacturer from string
---
--- @param s string Match string
--- @return table|nil Manufacturer
local function matchManufacturer( s )
    local data = mw.loadJsonData( MODULE_NAME .. '/data.json' )

    for _, manufacturer in ipairs( data ) do
        for _, value in pairs( manufacturer ) do
            if mw.ustring.match( mw.ustring.lower( value ),  '^' .. mw.ustring.lower( s ) .. '$' ) then
                return manufacturer
            end
        end
    end

    return nil
end


function Manufacturer.manufacturer( frame )
    local mArguments = require( 'Module:Arguments' )
    local args = mArguments.getArgs( frame )
    local s = args[1]
    -- Default to name key
    local type = args[ 'type' ] or 'name'

    if not s then
        return mw.ustring.format( '<span class="error">%s</span>', translate( 'error_no_text' ) )
    end

    return Manufacturer._manufacturer( s, type )
end


function Manufacturer._manufacturer( s, type )
    -- Return nil for Lua
    if s == nil then return end
    -- Return table for Lua
    if type == nil then
        type = 'table'
    end

    local manufacturer = matchManufacturer( s )
    -- Used for other Lua modules
    if type == 'table' then
        return manufacturer
    -- Return error message
    elseif manufacturer == nil or manufacturer[ type ] == nil then
        return mw.ustring.format( '<span class="error">%s</span>', translate( 'error_not_found', type, s ) )
    -- Return wiki page name
    elseif type == 'page' then
        return manufacturer[ 'page' ] or manufacturer[ 'name' ]
    -- Return string from matched manufacturer
    else
        return manufacturer[ type ]
    end
end


return Manufacturer
