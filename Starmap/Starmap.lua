local Starmap = {}

local Array = require( 'Module:Array' )
local data = mw.loadJsonData( 'Module:Starmap/starmap.json' )
local TNT = require( 'Module:Translate' ):new()
local config = mw.loadJsonData( 'Module:Starmap/config.json' )

local lang
if config[ 'module_lang' ] then
	lang = mw.getLanguage( config[ 'module_lang' ] )
else
	lang = mw.getContentLanguage()
end
local langCode = lang:getCode()

--- Wrapper function for Module:Translate.translate
-- @param key string The translation key
-- @param addSuffix boolean Adds a language suffix if config.smw_multilingual_text is true
-- @return string If the key was not found in the .tab page, the key is returned
local function t( key, addSuffix, ... )
	return TNT:translate( 'Module:Starmap/i18n.json', config, key, addSuffix, {...} ) or key
end

--- Remove parentheses and their content
local function removeParentheses( inputString )
    return string.gsub( inputString, '%b()', '' )
end

-- @param str String
local function trim( str )
    return string.match( str, '([^:%(%s]+)' )
end

--- If but inline
-- @param condition boolean
-- @param truthy any What to return if true
-- @param falsy any What to return if false
local function inlineIf( condition, truthy, falsy )
	if condition then 
		return truthy 
	else 
		return falsy 
	end
end

--- Bypass for a bug
local function cuteArray( array )
	local newArray = {}
	for _, val in ipairs( array ) do 
		table.insert( newArray, val )
	end
	return newArray
end

--- Concat a Starmap link
-- @param location Location param
-- @param system System param, only added if the Location param is present
function Starmap.link( location, system )
	local str = config[ 'starmap' ] .. '?'
	
	if location then str = str .. 'location=' .. location end
	if location and system then str = str .. '&' .. 'system=' .. system end
	
	return str
end

--- Look for a structure in starmap
-- A structure can be an astronomical anomaly
-- @param structureType The type of structure (system/object)
-- @param structureName The name/code/designation of the structure in Star Citizen
function Starmap.findStructure( structureType, structureName )
	local structures = data[ config[ 'type_plural' ][ structureType ] ]
	if structures == nil then return nil end -- Invalid type
	
	structureName = string.lower( structureName )
	
	for _, structure in ipairs( structures ) do
		if string.lower( structure[ 'name' ] or '' ) == structureName or string.lower( structure[ 'designation' ] or '' ) == structureName or string.lower( structure[ 'code' ] or '' ) == structureName then
			return structure
		end
	end
	
	return nil -- Not found
end

--- E.g.: [[Planet]], [[Star]], [[System]]
-- @param target table Target structure
function Starmap.pathTo( target )
	local links = {}
	
	local function processStructure( structure )
		if not structure then return end
		local parent = structure[ 'parent' ] or structure[ 'star_system' ]
		if not parent then return end
		local parentType = inlineIf( Array.contains( cuteArray( config[ 'systems' ] ), parent[ 'type' ] ), 'system', 'object' )
		parent = Starmap.findStructure( parentType, parent[ 'code' ] )
		
		if parentType == 'system' then
			table.insert( links, string.format( t( 'in_system' ), '[[' .. removeParentheses( parent[ 'name' ] ) .. ' system]]' ) )
		elseif parent.type == 'STAR' then
			local designation = removeParentheses( parent[ 'designation' ] )
			table.insert( links, string.format( t( 'orbits_star' ), '[[' .. designation .. ' (star)|' .. designation .. ' star]]' ) )
		else
			table.insert( links, '[[' .. removeParentheses( parent[ 'name' ] ) .. ']]' )
		end
		
		if parentType ~= 'system' then
			processStructure( parent )
		end
	end
	
	processStructure( target )
	
	return string.gsub( table.concat( links, ', ' ), '^%l', string.upper )
end

--- Get the objects of a system
-- @param systemName The type of structure (system/object)
function Starmap.systemObjects( systemName )
	local system = Starmap.findStructure( 'system', systemName )
	if system == nil then return nil end -- System doesn't exist
	
	systemName = string.lower( systemName )
	
	local objects = data[ 'objects' ]
	local systemObjects = {}
	
	for _, object in ipairs( objects ) do
		if object[ 'star_system_id' ] == system[ 'id' ] then
			table.insert( systemObjects, object )
		end
	end
	
	return systemObjects
end

-- @param frame https://www.mediawiki.org/wiki/Extension:Scribunto/Lua_reference_manual#Frame_object
function Starmap.main( frame )
	local args = frame:getParent().args -- [2] is type (e.g.: system), [1] is name (e.g.: Stanton)

	local structure = Starmap.findStructure( args[ 2 ] or 'object', trim( args[ 1 ] ) )

	if structure then
		local location = structure.code
		local system = nil
		if structure[ 'star_system' ] then system = structure[ 'star_system' ][ 'code' ] end
		
		return Starmap.link( location, system )
	else
		return ''
	end
end

function Starmap.test( type, name )
	local targetObject = Starmap.findStructure( type, name )
	mw.log( Starmap.pathTo( targetObject ) )
end

return Starmap
