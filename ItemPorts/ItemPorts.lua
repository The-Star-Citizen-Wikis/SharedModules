require( 'strict' )
require( 'Module:Mw.html extension' );

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
	return TNT:translate( MODULE_NAME .. '/i18n.json', config, key, addSuffix, {...} ) or key
end


--- Creates the object that is used to query the SMW store
---
--- @param page string the item page containing data
--- @return table
local function makeSmwQueryObject( page )
    local ignores = config.blocklist_itemport_name or {}

    local itemPortName = t( 'SMW_ItemPortName' )
    local query = {
        mw.ustring.format( '?%s#-=name', itemPortName ),
        mw.ustring.format( '?%s#-=display_name', t( 'SMW_ItemPortDisplayName' ) ),
        mw.ustring.format( '?%s#-=min_size', t( 'SMW_ItemPortMinimumSize' ) ),
        mw.ustring.format( '?%s#-=max_size', t( 'SMW_ItemPortMaximumSize' ) ),
        mw.ustring.format( '?%s#-=equipped_name', t( 'SMW_EquippedItemName' ) ),
        mw.ustring.format( '?%s#-=equipped_uuid', t( 'SMW_EquippedItemUUID' ) ),
        mw.ustring.format( 'sort=%s', itemPortName ),
        'order=asc',
        'limit=1000'
    }

    table.insert( query, 1, mw.ustring.format(
        '[[-Has subobject::' .. page .. ']][[%s::+]]',
        itemPortName
    ) )

    for _, portName in ipairs(ignores) do
        table.insert( query, 2, mw.ustring.format(
            '[[%s::!' .. portName .. ']]',
            itemPortName
        ))
    end

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
        local msg = mw.ustring.format( translate( 'error_no_itemports_found' ), self.page )
		return require( 'Module:Hatnote' )._hatnote( msg, { icon = 'WikimediaUI-Error.svg' } )
	end

    local containerHtml = mw.html.create( 'div' ):addClass( 'template-itemPorts' )

	for _, port in ipairs( smwData ) do
		local size_text, title, subtitle

        -- Use display_name if it is different, so that we use the same key as the game localization
        if port.display_name and port.display_name ~= port.name and translate( 'itemPort_' .. port.display_name ) ~= 'itemPort_' .. port.display_name then
            subtitle = translate( 'itemPort_' .. port.display_name )
        else
            subtitle = translate( 'itemPort_' .. port.name )
        end

		if port.min_size == port.max_size then
			size_text = mw.ustring.format( 'S%d', port.min_size )
		else
			size_text = mw.ustring.format( 'S%d–%d', port.min_size, port.max_size )
		end
		
		if port.equipped_name ~= nil then
            if port.equipped_name == '<= PLACEHOLDER =>' then
                -- TODO: Display more specific name by getting the type of the item
                title = translate( 'item_placeholder' )
            else
			    title = mw.ustring.format( '[[%s]]', port.equipped_name )
            end
		else
			title = translate( 'msg_no_item_equipped' )
		end
		
		local portHtml = mw.html.create( 'div' ):addClass( 'template-itemPort' )
		portHtml:tag( 'div' )
            :addClass( 'template-itemPort-port' )
			:tag( 'div' )
                :addClass( 'template-itemPort-size' )
                :wikitext( size_text )
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
	
	return tostring( containerHtml ) .. mw.getCurrentFrame():extensionTag{
        name = 'templatestyles', args = { src = MODULE_NAME .. '/styles.css' }
    }
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
