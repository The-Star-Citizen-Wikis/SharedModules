local Transit = {}

local i18n = require( 'Module:i18n' ):new()
local data = mw.loadJsonData( 'Module:Transit/data.json' )

local mArguments


--- Wrapper function for Module:i18n.translate
---
--- @param key string The translation key
--- @return string|nil
local function t( key )
	return i18n:translate( key )
end

--- Return a badge in wikitext using data defined in data.json
---
--- @param location string
--- @param name string
--- @param frame table
--- @return string
function Transit.main( location, name, frame )
    if not location and not name then
        return string.format( '<span class="error">%s</span>', t( 'message_error_no_text' ) )
    end

    local bg = '#000'
    local color = '#fff'
    for locationName, locationData in pairs( data.locations ) do
        if locationName == location then
            for lineName, lineData in pairs( locationData.lines ) do
            	if lineName == name then
            		bg = lineData.bg
            		color = lineData.color
            		break
            	end
            end
            break
        end
    end

    frame = frame or mw.getCurrentFrame()
    return frame:expandTemplate{
        title = 'Badge',
        args = {
            name,
            bg = bg,
            color = color
        }
    }
end


--- Helper function for templates invoking the module
---
--- @param frame table
--- @return string
function Transit.fromTemplate( frame )
    mArguments = require( 'Module:Arguments' )
    local args = mArguments.getArgs( frame )
    return Transit.main( args[1], args[2], frame )
end


return Transit
