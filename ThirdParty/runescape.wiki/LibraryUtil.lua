-- Imported from: https://runescape.wiki/w/Module:LibraryUtil

-- <nowiki>
local libraryUtil = require( 'libraryUtil' )

function libraryUtil.makeCheckClassFunction( libraryName, varName, class, selfObjDesc )
	return function ( self, method )
		if getmetatable( self ) ~= class then
			error( mw.ustring.format(
				"%s: invalid %s. Did you call %s with a dot instead of a colon, i.e. " ..
				"%s.%s() instead of %s:%s()?",
				libraryName, selfObjDesc, method, varName, method, varName, method
			), 3 )
		end
	end
end

return libraryUtil
-- </nowiki>
