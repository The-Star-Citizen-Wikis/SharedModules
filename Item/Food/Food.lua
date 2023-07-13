require( 'strict' )

local Food = {}

local TNT = require( 'Module:Translate' ):new()
local smwCommon = require( 'Module:Common/SMW' )
local data = mw.loadJsonData( 'Module:Item/Food/data.json' )
local config = mw.loadJsonData( 'Module:Item/config.json' )


--- Wrapper function for Module:Translate.translate
---
--- @param key string The translation key
--- @param addSuffix boolean Adds a language suffix if config.smw_multilingual_text is true
--- @return string If the key was not found in the .tab page, the key is returned
local function translate( key, addSuffix, ... )
	return TNT:translate( 'Module:Item/Food/i18n.json', config, key, addSuffix, {...} )
end


--- Adds the properties valid for this item to the SMW Set object
---
--- @param smwSetObject table
function Food.addSmwProperties( apiData, frameArgs, smwSetObject )
	smwCommon.addSmwProperties(
		apiData,
		frameArgs,
		smwSetObject,
		translate,
		config,
		data,
		'Item/Food'
	)

	--- Not sure if size matters, not like there is a S12 Double Dog
	--- FIXME: SMW_Size is from Module:Item, I made a duplicated entry in Module:Item/Food/i18n.json to make this work
	smwSetObject[ translate( 'SMW_Size' ) ] = nil

	--- GEND and GENF are placeholders
	--- FIXME: Same as above
	if smwSetObject[ translate( 'SMW_Manufacturer' ) ] == '[[GEND]]' or smwSetObject[ translate( 'SMW_Manufacturer' ) ] == '[[GENF]]' then
		smwSetObject[ translate( 'SMW_Manufacturer' ) ] = nil
	end

	--- We only know whether the item is single use or not
	if smwSetObject[ translate( 'SMW_Uses' ) ] == true then
		smwSetObject[ translate( 'SMW_Uses' ) ] = 1
	else
		smwSetObject[ translate( 'SMW_Uses' ) ] = nil
	end

	if smwSetObject[ translate( 'SMW_Effect' ) ] == 'None' then
		smwSetObject[ translate( 'SMW_Effect' ) ] = nil
	end
end


--- Adds all SMW parameters set by this Module to the ASK object
---
--- @param smwAskObject table
--- @return void
function Food.addSmwAskProperties( smwAskObject )
	smwCommon.addSmwAskProperties(
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
function Food.addInfoboxData( infobox, smwData )
	infobox:renderSection( {
		title = translate( 'LBL_Usage' ),
		content = {
			infobox:renderItem( {
				label = translate( 'LBL_Effect' ),
				data = infobox.tableToCommaList( smwData[ translate( 'SMW_Effect' ) ] ),
				colspan = 2
			} ),
			infobox:renderItem( {
				label = translate( 'LBL_NutritionalDensityRating' ),
				data = smwData[ translate( 'SMW_NutritionalDensityRating' ) ],
			} ),
			infobox:renderItem( {
				label = translate( 'LBL_HydrationEfficacyIndex' ),
				data = smwData[ translate( 'SMW_HydrationEfficacyIndex' ) ],
			} ),
			infobox:renderItem( {
				label = translate( 'LBL_ConsumptionCount' ),
				data = smwData[ translate( 'SMW_ConsumptionCount' ) ],
			} )
		},
		col = 4
	} )
end


--- Add categories that are set on the page.
--- The categories table should only contain category names, no MW Links, i.e. 'Foo' instead of '[[Category:Foo]]'
---
--- @param categories table The categories table
--- @param frameArgs table Frame arguments from Module:Arguments
--- @param smwData table Data from Semantic MediaWiki
--- @return void
function Food.addCategories( categories, frameArgs, smwData )
	--- TODO: This should be in Module:Item eventually
	--- But we do not have a full Type <--> Category mapping yet
	if smwData[ translate( 'SMW_Type' ) ] ~= nil then
		table.insert(
			categories,
			translate( 'category_' .. string.lower( smwData[ translate( 'SMW_Type' ) ] ) )
		)
	end
end


--- Return the short description for this object
---
--- @param frameArgs table Frame arguments from Module:Arguments
--- @param smwData table Data from Semantic MediaWiki
--- @return string|nil
function Food.getShortDescription( frameArgs, smwData )
	return smwData[ translate( 'SMW_Type' ) ]
end


return Food