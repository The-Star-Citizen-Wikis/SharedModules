require( 'strict' )
require( 'Module:Mw.html extension' );

local ItemPorts = {}

local metatable = {}
local methodtable = {}

metatable.__index = methodtable


--- Creates the object that is used to query the SMW store
---
--- @param page string the item page containing data
--- @return table
local function makeSmwQueryObject( page )
    return {
        mw.ustring.format(
            '[[-Has subobject::' .. page .. ']][[%s::+]]',
            'Item port name'
        ),
        mw.ustring.format( '?%s#-=name', 'Item port name' ),
        mw.ustring.format( '?%s#-=min_size', 'Item port minimum size' ),
        mw.ustring.format( '?%s#-=max_size', 'Item port maximum size' ),
        mw.ustring.format( '?%s#-=equipped_name', 'Equipped item name' ),
        --mw.ustring.format( '?%s#-=equipped_uuid', 'Equipped item UUID' ),
        mw.ustring.format(
            'sort=%s,%s',
            'Item port name',
            'Item port maximum size'
        ),
        'order=asc,desc',
        'limit=1000'
    }
end


--- Queries the SMW Store
--- @return table|nil
function methodtable.getSmwData( self, page )
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
        local msg = mw.ustring.format( "No item ports found on '''%s'''.", self.page )
		return require( 'Module:Hatnote' )._hatnote( msg, { icon = 'WikimediaUI-Error.svg' } )
	end

    local containerHtml = mw.html.create( 'div' ):addClass( 'template-itemPorts' )

	for _, port in ipairs( smwData ) do
		local size_text, title

		if port.min_size == port.max_size then
			size_text = mw.ustring.format( 'S%d', port.min_size )
		else
			size_text = mw.ustring.format( 'S%d–%d', port.min_size, port.max_size )
		end
		
		if port.equipped_name ~= nil then
            if port.equipped_name == '<= PLACEHOLDER =>' then
                -- TODO: Display more specific name by getting the type of the item
                title = 'Placeholder item'
            else
			    title = mw.ustring.format( '[[%s]]', port.equipped_name )
            end
		else
			title = 'No item equipped'
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
                :wikitext( port.name )
                :done()
			:tag( 'div' )
                :addClass( 'template-itemPort-title' )
                :wikitext( title )
			
        containerHtml:node( portHtml )
	end
	
	return tostring( containerHtml ) .. mw.getCurrentFrame():extensionTag{
        name = 'templatestyles', args = { src = 'Module:ItemPorts/styles.css' }
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
    local page = args[ 1 ] or mw.title.getCurrentTitle().rootText

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
