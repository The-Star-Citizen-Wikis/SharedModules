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
				label = translate( 'LBL_Effects' ),
				data = infobox.tableToCommaList( smwData[ translate( 'SMW_Effects' ) ] ),
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


return Food