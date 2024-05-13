require( 'strict' )

local Manufacturer = {}

local metatable = {}
local methodtable = {}

metatable.__index = methodtable

local MODULE_NAME = 'Module:Manufacturer'

local libraryUtil = require( 'libraryUtil' )
local checkType = libraryUtil.checkType
local i18n = require( 'Module:i18n' ):new()

local mArguments

local cache = {}


--- Wrapper function for Module:i18n.translate
---
--- @param key string The translation key
--- @return string|nil
local function t( key )
	return i18n:translate( key, { ['returnKey'] = false } )
end


--- Escape magic characters in Lua for use in regex
--- TODO: This should be move upstream to Module:Common
---
--- @param str string string to escape
--- @return string
local function escapeMagicCharacters( str )
    local magicCharacters = { '%', '^', '$', '(', ')', '.', '[', ']', '*', '+', '-', '?' }
    for _, magicChar in ipairs( magicCharacters ) do
        str = str:gsub( '%' .. magicChar, '%%' .. magicChar )
    end
    return str
end


--- Helper function to get message from i18n
---
--- @param code string manufacturer code
--- @param messageType string 
--- @return string|nil
local function getMessage( code, messageType )
	return t( string.format( 'manufacturer_%s_%s', code, messageType ) ) 
end


--- Return the manufacturer table either from cache or build it from the i18n
---
--- @return table
local function getManufacturers()
    if #cache > 0 then return cache end

    local codes = mw.loadJsonData( MODULE_NAME .. '/data.json' ).codes

    local manufacturers = {}
    for _, code in pairs( codes ) do
        local manufacturer = {}
        manufacturer['code'] = code
		manufacturer['name'] = getMessage( code, 'name' )
		manufacturer['shortname'] = getMessage( code, 'name_short' )
        table.insert( manufacturers, manufacturer )
    end

    if #manufacturers > 0 then
        cache = manufacturers
        mw.log( '⌛ [Manufacturer] Initialized dataset' )
    end

    return cache
end


--- Match the string with any value in the manufacturers table and return the manufacturer object
---
--- @param s string Match string
--- @return table|nil Manufacturer
function methodtable.get( self, s )
    checkType( MODULE_NAME .. '.get', 1, self, 'table' )
    checkType( MODULE_NAME .. '.get', 2, s, 'string' )

    mw.log( string.format( '🔍 [Manufacturer] Looking for manufacturer: %s', s ) )

    -- Initalize manufacturers
    local manufacturers = getManufacturers()

    local regex = string.format( '^%s$', mw.ustring.lower( escapeMagicCharacters( s ) ) )

    for _, manufacturer in ipairs( manufacturers ) do
        for _, value in pairs( manufacturer ) do
            if mw.ustring.match( mw.ustring.lower( value ), regex ) then
                mw.logObject( manufacturer, '✅ [Manufacturer] Matched manufacturer' )
                return manufacturer
            end
        end
    end

    mw.log( '❌ [Manufacturer] Could not match manufacturer: %s', s )

    return nil
end


--- New Instance
---
--- @return table Manufacturer
function Manufacturer.new( self )
    local instance = {}

    setmetatable( instance, metatable )

    return instance
end


--- Helper function for templates invoking the module
---
--- @param frame table
--- @param type string type of the value returned
--- @param returnKey boolean true to return key, false to return error
--- @return string
local function fromTemplate( frame, type, returnKey )
    mArguments = require( 'Module:Arguments' )
    local args = mArguments.getArgs( frame )
    local s = args[1]

    if not s then
        return mw.ustring.format( '<span class="error">%s</span>', t( 'error_no_text' ) )
    end

    local instance = Manufacturer:new()
    local match = instance:get( s )

    if not match then
        if returnKey then
            return s
        else
            return '<span class="error">' .. mw.ustring.format( t( 'error_not_found' ), type, s ) .. '</span>'
        end
    end

    return match[type]
end


--- Implement {{Manufactuer code}}
---
--- @param frame table
--- @return string
function Manufacturer.getCode( frame )
    return fromTemplate( frame, 'code', false )
end


--- Implement {{Manufactuer name}}
---
--- @param frame table
--- @return string
function Manufacturer.getName( frame )
    return fromTemplate( frame, 'name', false )
end


--- Implement {{Manufacturer return name}}
---
--- @param frame table
--- @return string
function Manufacturer.getNameButReturnName( frame )
    return fromTemplate( frame, 'name', true )
end


return Manufacturer
