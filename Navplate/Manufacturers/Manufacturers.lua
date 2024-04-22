-- This is barebone but the idea is to make a generic module that
-- build any navplate from template defined from data.json
--
-- TODO:
-- - Make functions generic
-- - Support multiple conditions
-- - Support more SMW inline query conditions other than category
-- - Implement i18n
-- - Support group headers
-- - Support icon

local NavplateManufacturers = {}

local metatable = {}
local methodtable = {}

metatable.__index = methodtable

local common = require( 'Module:Common' )
local navplate = require( 'Module:Navplate' )
local template = mw.loadJsonData( 'Module:Navplate/Manufacturers/data.json' );
local mfu = require( 'Module:Manufacturer' )._manufacturer

--- Queries the SMW Store
--- @param conditions table|string For SMW query
--- @return table|nil
function methodtable.getSmwData( self, conditions )
	-- Cache multiple calls
    if self.smwData ~= nil then
        return self.smwData
    end

	local cond = ''

	if type( conditions ) == 'table' then
		for _, condition in ipairs( conditions ) do
			cond = cond .. '[[' .. condition .. ']]'
		end
	else
		cond = '[[' .. conditions .. ']]'
	end

	local askData = {
		'[[:+]]',
		cond,
		'?#-=page',
		'?Category#'
	}

	local data = mw.smw.ask( askData )

	if data == nil or data[ 1 ] == nil then
        return nil
    end
	
	--mw.logObject( data )

	-- Init self.smwData
	if self.smwData == nil then
		self.smwData = {}
	end

	self.smwData = data

	return self.smwData
end

--- Build a table of data that represents the navplate from SMW data based on the template
---
--- @return table
function methodtable.buildNavplateData( self, data )
	local navplateData = {}

	-- Lua tables has no concept of order, need to iterate it manually
	local i = 1
	for _, navplateRow in pairs( template[ 'content' ] ) do
		local label = navplateRow[ 'label' ]
		local conditions = navplateRow[ 'conditions' ]

		if conditions ~= nil then
			for _, result in pairs( data ) do
				-- Match category
				local categories = result[ 'Category' ]
				if categories ~= nil and type( categories ) == 'table' then
					for _, category in pairs( categories ) do
						if category == conditions then
							-- Create row if it does not exist already
							if navplateData[ i ] == nil then
								navplateData[ i ] = {
									label = label,
									pages = {}
								}
							end
							table.insert( navplateData[ i ][ 'pages' ], result[ 'page' ] )
						end
					end
				end
			end
		end

		if navplateData[ i ] ~= nil then
			i = i + 1
		end
	end

	return navplateData
end

--- Outputs the table
---
--- @return string
function methodtable.make( self )
	local manufacturer = mfu( self.frameArgs[ 1 ] ) and mfu( self.frameArgs[ 1 ] ).name or self.frameArgs[ 1 ]

	if manufacturer == nil then
		return mw.ustring.format(
            '<strong class="error">Error: %s.</strong>',
            'Missing manufacturer parmeter'
    	)
	end

	local args = {
		subtitle = 'Products of',
		title = mw.ustring.format( '[[%s]]', manufacturer )
	}

	local conditions = 'Category:' .. manufacturer

	local data = self:getSmwData( conditions )
	if data ~= nil then
		local navplateData = self:buildNavplateData( data )
		mw.logObject( navplateData )

		if navplateData ~= nil then
			for i, row in ipairs( navplateData ) do
				args[ 'label' .. i ] = row[ 'label' ]
				-- Probably there is a cleaner way but it works :D
				args[ 'list' .. i ] = '[[' .. table.concat( row[ 'pages' ], ']][[' ) .. ']]'
			end
		end
	end

	-- mw.logObject( args )

    return navplate.navplateTemplate({
		args = args
    })
end

--- Set the frame and load args
--- @param frame table
function methodtable.setFrame( self, frame )
	self.currentFrame = frame
	self.frameArgs = require( 'Module:Arguments' ).getArgs( frame )
end

--- New Instance
---
--- @return table NavplateManufacturers
function NavplateManufacturers.new( self )
    local instance = {}

    setmetatable( instance, metatable )

    return instance
end


--- "Main" entry point
---
--- @param frame table Invocation frame
--- @return string
function NavplateManufacturers.main( frame )
    local instance = NavplateManufacturers:new()
	instance:setFrame( frame )

    return instance:make()
end


return NavplateManufacturers
