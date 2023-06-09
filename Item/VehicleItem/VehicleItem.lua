require( 'strict' )

local VehicleItem = {}

local TNT = require( 'Module:Translate' ):new()
local smwCommon = require( 'Module:Common/SMW' )
local data = mw.loadJsonData( 'Module:Item/VehicleItem/data.json' )
local config = mw.loadJsonData( 'Module:Item/config.json' )


--- Wrapper function for Module:Translate.translate
---
--- @param key string The translation key
--- @param addSuffix boolean Adds a language suffix if config.smw_multilingual_text is true
--- @return string If the key was not found in the .tab page, the key is returned
local function translate( key, addSuffix, ... )
    return TNT:translate( 'Module:Item/VehicleItem/i18n.json', config, key, addSuffix, {...} )
end


--- Adds the properties valid for this item to the SMW Set object
---
--- @param smwSetObject table
function VehicleItem.addSmwProperties( apiData, frameArgs, smwSetObject )
    smwCommon.addSmwProperties(
        apiData,
        frameArgs,
        smwSetObject,
        translate,
        config,
        data,
        'VehicleItem'
    )
end


--- Adds all SMW parameters set by this Module to the ASK object
---
--- @param smwAskObject table
--- @return void
function VehicleItem.addSmwAskProperties( smwAskObject )
    smwCommon.addSmwQueryParams(
        smwAskObject,
        translate,
        config,
        data
    )
end


--- Adds entries to the infobox
---
--- @param infobox table The Module:InfoboxNeue instance
--- @param smwData table Data from Semantic MediaWiki
--- @return void
function VehicleItem.addInfoboxData( infobox, smwData )

end


--- Add categories that are set on the page.
--- The categories table should only contain category names, no MW Links, i.e. 'Foo' instead of '[[Category:Foo]]'
---
--- @param categories table The categories table
--- @param frameArgs table Frame arguments from Module:Arguments
--- @param smwData table Data from Semantic MediaWiki
--- @return void
function VehicleItem.addCategories( categories, frameArgs, smwData )

end

--- Set the short description for this object
---
--- @param shortdesc string Short description
--- @param frameArgs table Frame arguments from Module:Arguments
--- @param smwData table Data from Semantic MediaWiki
--- @return void
function VehicleItem.setShortDescription( shortdesc, frameArgs, smwData )
	
end


return VehicleItem