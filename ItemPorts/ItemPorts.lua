require( 'strict' )
require( 'Module:Mw.html extension' )

local ItemPorts = {}

local metatable = {}
local methodtable = {}

metatable.__index = methodtable

local MODULE_NAME = 'Module:ItemPorts'
local config = mw.loadJsonData( MODULE_NAME .. '/config.json' )

local i18n = require( 'Module:i18n' ):new()
local TNT = require( 'Module:Translate' ):new()


--- Wrapper function for Module:i18n.translate
---
--- @param key string The translation key
--- @return string If the key was not found, the key is returned
local function t( key )
    return i18n:translate( key )
end


--- Wrapper function for Module:Translate.translate
---
--- @param key string The translation key
--- @param addSuffix boolean|nil Adds a language suffix if config.smw_multilingual_text is true
--- @return string If the key was not found in the .tab page, the key is returned
local function translate( key, addSuffix, ... )
    return TNT:translate( MODULE_NAME .. '/i18n.json', config, key, addSuffix, { ... } ) or key
end

--- Utility function to format item size for display
--- TODO: Perhaps this should go into a common module
---
--- @param size any Size(s) to be formatted
--- @return string
local function formatItemSize( size )
    -- Range
    if type( size ) == 'table' then
        if size[ 1 ] == size[ 2 ] or not size[ 1 ] or not size[ 2 ] then
            return formatItemSize( size[ 1 ] or size[ 2 ] )
        end
        return string.format( 'S%d–%d', size[ 1 ], size[ 2 ] )
        -- Numerial size
    elseif type( size ) == 'number' then
        return string.format( 'S%d', size )
    end
    -- String size (e.g. M, XL)
    return size
end


--- Creates the object that is used to query the SMW store
---
--- @param page string the item page containing data
--- @return table
local function makeSmwQueryObject( page )
    local ignores = config.blocklist_itemport_name or {}

    local itemPortName = t( 'SMW_ItemPortName' )
    local query = {
        string.format( '?%s#-=name', itemPortName ),
        string.format( '?%s#-=display_name', t( 'SMW_ItemPortDisplayName' ) ),
        string.format( '?%s#-=min_size', t( 'SMW_ItemPortMinimumSize' ) ),
        string.format( '?%s#-=max_size', t( 'SMW_ItemPortMaximumSize' ) ),
        string.format( '?%s#-=equipped_name', t( 'SMW_EquippedItemName' ) ),
        string.format( '?%s#-=equipped_size', t( 'SMW_EquippedItemSize' ) ),
        string.format( '?%s#-=equipped_uuid', t( 'SMW_EquippedItemUUID' ) ),
        string.format( 'sort=%s', itemPortName ),
        'order=asc',
        'limit=1000'
    }

    table.insert( query, 1, string.format(
        '[[-Has subobject::' .. page .. ']][[%s::+]]',
        itemPortName
    ) )

    for _, portName in ipairs( ignores ) do
        table.insert( query, 2, string.format(
            '[[%s::!' .. portName .. ']]',
            itemPortName
        ) )
    end

    --mw.logObject( query, '[ItemPorts] Query SMW with the following parameters' )

    return query
end


--- Queries the SMW Store
--- @return table|nil
function methodtable.getSmwData( self, page )
    --mw.logObject( self.smwData, 'cachedSmwData' )
    -- Cache multiple calls
    if self.smwData ~= nil then
        return self.smwData
    end

    local smwData = mw.smw.ask( makeSmwQueryObject( page ) )

    if smwData == nil or smwData[ 1 ] == nil then
        return nil
    end

    --mw.logObject( smwData, 'getSmwData' )
    self.smwData = smwData

    return self.smwData
end

--- Generates wikitext needed for the template
--- @return string
function methodtable.out( self )
    local smwData = self:getSmwData( self.page )

    if smwData == nil then
        local msg = string.format( t( 'message_error_no_itemports_found' ), self.page )
        return require( 'Module:Hatnote' )._hatnote( msg, { icon = 'WikimediaUI-Error.svg' } )
    end

    local containerHtml = mw.html.create( 'div' ):addClass( 'template-itemPorts' )

    for _, port in ipairs( smwData ) do
        local title, subtitle

        -- Use display_name if it is different, so that we use the same key as the game localization
        if port.display_name and port.display_name ~= port.name and translate( 'itemPort_' .. port.display_name ) ~= 'itemPort_' .. port.display_name then
            subtitle = translate( 'itemPort_' .. port.display_name )
        elseif port.name then
            subtitle = translate( 'itemPort_' .. port.name )
        end

        -- FIXME: Add i18n for N/A
        local size_primary, size_secondary
        local port_size = formatItemSize( { port.min_size, port.max_size } )
        local equipped_size = formatItemSize( port.equipped_size )

        if not equipped_size then
            size_primary = port_size or 'N/A'
        elseif equipped_size == port_size then
            size_primary = equipped_size
        else
            size_primary = equipped_size
            size_secondary = port_size
        end

        if port.equipped_name ~= nil then
            if port.equipped_name == '<= PLACEHOLDER =>' then
                -- TODO: Display more specific name by getting the type of the item
                title = translate( 'item_placeholder' )
            else
                title = string.format( '[[%s]]', port.equipped_name )
            end
        else
            title = translate( 'msg_no_item_equipped' )
        end

        local portHtml = mw.html.create( 'div' ):addClass( 'template-itemPort' )
        -- Size
        portHtml:tag( 'div' )
            :addClass( 'template-itemPort-port' )
            :IF( size_secondary )
            :tag( 'div' )
            :addClass( 'template-itemPort-subtitle' )
            :wikitext( size_secondary )
            :done()
            :END()
            :IF( size_primary )
            :tag( 'div' )
            :addClass( 'template-itemPort-title' )
            :wikitext( size_primary )
            :done()
            :END()

        portHtml:tag( 'div' )
            :addClass( 'template-itemPort-item' )
            :addClassIf( port.equipped_name, 'template-itemPort-item--hasItem' )
            :tag( 'div' )
            :addClass( 'template-itemPort-subtitle' )
            :wikitext( subtitle )
            :done()
            :tag( 'div' )
            :addClass( 'template-itemPort-title' )
            :wikitext( title )

        containerHtml:node( portHtml )
    end

    return mw.getCurrentFrame():extensionTag {
        name = 'templatestyles', args = { src = MODULE_NAME .. '/styles.css' }
    } .. tostring( containerHtml )
end

--- New Instance
---
--- @return table ItemPorts
function ItemPorts.new( self, page )
    local instance = {
        page = page or nil
    }

    setmetatable( instance, metatable )

    return instance
end

--- Parser call for generating the table
function ItemPorts.outputTable( frame )
    local args = require( 'Module:Arguments' ).getArgs( frame )
    local page = args[ 1 ] or mw.title.getCurrentTitle().text

    local instance = ItemPorts:new( page )
    local out = instance:out()

    return out
end

--- For debugging use
---
--- @param page string page name on the wiki
--- @return string
function ItemPorts.test( page )
    local instance = ItemPorts:new( page )
    local out = instance:out()

    return out
end

return ItemPorts
