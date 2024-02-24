-- TODO: Maybe make this more generic so that it can be reused somewhere else?
local NavplateVehicles = {}

local metatable = {}
local methodtable = {}

metatable.__index = methodtable

local navplate = require( 'Module:Navplate' )
local common = require( 'Module:Common' )
local mfu = require( 'Module:Manufacturer' )._manufacturer
local TNT = require( 'Module:Translate' ):new()
local lang = mw.getContentLanguage()

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

	local smwManufacturer = translate( 'SMW_Manufacturer' )

    local askData = {
        '?#-=page',
        '?' .. smwManufacturer ..'#-=manufacturer',
        sort = smwManufacturer,
        order = 'asc',
        limit = 500,
    }

    local query = ''

    if mw.ustring.sub( category, 1, 2 ) == '[[' then
    	query = category
    else
    	query = '[[Category:' .. category .. '|+depth=0]]'
    end

	query = query .. [[:+]]
	table.insert( askData, 1, query )

    local data = mw.smw.ask( askData )

    if data == nil or data[ 1 ] == nil then
        return nil
    end

	mw.logObject( data )

	-- Init self.smwData
	if self.smwData == nil then
		self.smwData = {}
	end

    self.smwData[category] = data

    return self.smwData[category]
end


--- Sorts the table by Manufacturer
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

	mw.logObject( grouped )

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
		translate( 'category_ships' ),
		translate( 'category_ground_vehicles' )
	}

	local i = 1
	for _, section in pairs( sections ) do
		local data = self:getSmwData( section )
		if data == nil then
			local hatnote = require( 'Module:Hatnote' )._hatnote
			return hatnote(
				translate( 'error_no_data_text' ),
				{ icon = 'WikimediaUI-Error.svg' }
			)
		end
		local grouped = self:group( data, 'manufacturer', sections )

		args[ 'header' .. i ] = lang:ucfirst( section )
		i = i + 1
		for manufacturer, vehicles in common.spairs( grouped ) do
			local icon = ''
			local label
			local mfuData = mfu( manufacturer )
			if mfuData and mfuData.code then
				icon = mw.ustring.format( '[[File:sc-icon-manufacturer-%s.svg|36px|link=]] ', mw.ustring.lower( mfuData.code ) )
				-- TODO: Intergrate label title and subtitle into Module:Navplate
				label = mw.ustring.format(
					'[[%s|%s<div class="template-navplate__subtitle>%s</div>]]',
					manufacturer,
					mfuData.name,
					mfuData.code
				)
			else
				label = mw.ustring.format( '[[%s]]', manufacturer )
			end
			args[ 'label' .. i ] = mw.ustring.format( '%s%s', icon, label )
			args[ 'list' .. i ] = table.concat( vehicles )
			i = i + 1
		end
	end

	mw.logObject( args )

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


return NavplateVehicles
