-- TODO: Maybe make this more generic so that it can be reused somewhere else?
local NavplateVehicles = {}

local metatable = {}
local methodtable = {}

metatable.__index = methodtable

local navplate = require( 'Module:Navplate' )
local common = require( 'Module:Common' )
local manufacturer = require( 'Module:Manufacturer' ):new()
local i18n = require( 'Module:i18n' ):new()
local TNT = require( 'Module:Translate' ):new()
local lang = mw.getContentLanguage()


--- Wrapper function for Module:i18n.translate
---
--- @param key string The translation key
--- @return string If the key was not found, the key is returned
local function t( key )
	return i18n:translate( key )
end


--- FIXME: This should go to somewhere else, like Module:Common
--- Calls TNT with the given key
---
--- @param key string The translation key
--- @return string If the key was not found in the .tab page, the key is returned
local function translate( key, ... )
	local success, translation = pcall( TNT.format, 'Module:Navplate vehicles/i18n.json', key or '', ... )

	if not success or translation == nil then
		return key
	end

	return translation
end

--- Queries the SMW Store
--- @return table
function methodtable.getSmwData( self, category )
    -- Cache multiple calls
    if self.smwData ~= nil and self.smwData[category] ~= nil then
        return self.smwData[category]
    end

    category = category or ''

	local smwManufacturer = t( 'SMW_Manufacturer' )

    local askData = {
		'[[:+]]',
        '?#-=page',
        '?' .. smwManufacturer ..'#-=manufacturer',
        sort = smwManufacturer,
        order = 'asc',
        limit = 500,
    }

    local query = ''

    if string.sub( category, 1, 2 ) == '[[' then
    	query = category
    else
    	query = '[[Category:' .. category .. '|+depth=0]]'
    end

	table.insert( askData, 1, query )

    local data = mw.smw.ask( askData )

    if data == nil or data[ 1 ] == nil then
        return nil
    end

	--mw.logObject( data )

	-- Init self.smwData
	if self.smwData == nil then
		self.smwData = {}
	end

    self.smwData[category] = data

    return self.smwData[category]
end


--- Groups data by a given key, and sorts the pages within each group alphabetically.
---
--- @param data table SMW data - Requires a 'page' key on each row
--- @param groupKey string Key on objects to group them under, e.g. manufacturer
--- @param suffix string|table Suffix to remove from page title
--- @return table
function methodtable.group( self, data, groupKey, suffix )
    local grouped = {}

    if type( data ) ~= 'table' or type( groupKey ) ~= 'string' then
        return grouped
    end

    local name

    for _, row in pairs( data ) do
        if row[ groupKey ] ~= nil then
            if type( grouped[ row[ groupKey ] ] ) ~= 'table' then
                grouped[ row[ groupKey ] ] = {}
            end

            if type( suffix ) == 'table' then
            	for _, s in pairs( suffix ) do
            		name = common.removeTypeSuffix( row.page, s )
            	end
            else
            	name = common.removeTypeSuffix( row.page, suffix )
            end
 
            if row.name ~= nil then
            	name = row.name
        	end

            table.insert(
            	grouped[ row[ groupKey ] ],
            	string.format(
            		'[[%s|%s]]',
            		row.page,
            		name
        		)
        	)
        end
    end

	-- Sort vehicles alphabetically
	for _, pages in pairs( grouped ) do
		table.sort( pages, function( a, b )
			local nameA = string.match( a, '%|(.+)]]' )
			local nameB = string.match( b, '%|(.+)]]' )

			if nameA and nameB then
				return nameA < nameB
			end
			
			return a < b -- Fallback to sorting by page link
		end )
	end

	--mw.logObject( grouped )

    return grouped
end


--- Outputs the table
---
--- @return string
function methodtable.make( self )
	local args = {
		subtitle = translate( 'subtitle_navplatevehicles' ),
		title = translate( 'title_navplatevehicles' )
	}
	
	local sections = {
		t( 'category_ships' ),
		t( 'category_ground_vehicles' )
	}

	local i = 1
	for _, section in pairs( sections ) do
		local data = self:getSmwData( section )
		if data == nil then
			local hatnote = require( 'Module:Hatnote' )._hatnote
			return hatnote(
				t( 'message_error_no_data_text' ),
				{ icon = 'WikimediaUI-Error.svg' }
			)
		end
		local grouped = self:group( data, 'manufacturer', sections )

		args[ 'header' .. i ] = lang:ucfirst( section )
		i = i + 1
		for mfu, vehicles in common.spairs( grouped ) do
			local icon = ''
			local label
			local mfuData = manufacturer:get( mfu )
			if mfuData and mfuData.code then
				icon = string.format( '[[File:sc-icon-brand-%s.svg|36px|link=]] ', string.lower( mfuData.code ) )
				-- TODO: Intergrate label title and subtitle into Module:Navplate
				label = string.format(
					'[[%s|%s<div class="template-navplate__subtitle>%s</div>]]',
					mfu,
					mfuData.name,
					mfuData.code
				)
			else
				label = string.format( '[[%s]]', mfu )
			end
			args[ 'label' .. i ] = string.format( '%s%s', icon, label )
			args[ 'list' .. i ] = table.concat( vehicles )
			i = i + 1
		end
	end

	--mw.logObject( args )

    return navplate.navplateTemplate({
		args = args
    })
end


--- New Instance
---
--- @return table NavplateVehicles
function NavplateVehicles.new( self, frameArgs )
    local instance = {}
    setmetatable( instance, metatable )
    return instance
end


--- "Main" entry point
---
--- @param frame table Invocation frame
--- @return string
function NavplateVehicles.main( frame )
    local instance = NavplateVehicles:new()

    return instance:make()
end

function NavplateVehicles.test( frame )
    local instance = NavplateVehicles:new()

    return instance:make()
end


return NavplateVehicles
