require( 'strict' )

local p = {}

local MODULE_NAME = 'CharArmor'

local i18n = require( 'Module:i18n' ):new()
local TNT = require( 'Module:Translate' ):new()
local smwCommon = require( 'Module:Common/SMW' )
local data = mw.loadJsonData( 'Module:Item/' .. MODULE_NAME .. '/data.json' )
local config = mw.loadJsonData( 'Module:Item/config.json' )


--- Wrapper function for Module:i18n.translate
---
--- @param key string The translation key
--- @return string If the key was not found, the key is returned
local function t( key )
	return i18n:translate( key )
end


--- Wrapper function for Module:Translate.translate
---
--- @param key string The translation key
--- @param addSuffix boolean|nil Adds a language suffix if config.smw_multilingual_text is true
--- @return string If the key was not found in the .tab page, the key is returned
local function translate( key, addSuffix, ... )
    return TNT:translate( 'Module:Item/' .. MODULE_NAME .. '/i18n.json', config, key, addSuffix, {...} )
end


--- Adds the properties valid for this item to the SMW Set object
---
--- @param smwSetObject table
function p.addSmwProperties( apiData, frameArgs, smwSetObject )
    smwCommon.addSmwProperties(
        apiData,
        frameArgs,
        smwSetObject,
        translate,
        config,
        data,
        'Item/' .. MODULE_NAME
    )

    local formatConfig = {
        type = "number"
    }

    smwCommon.setFromTable( smwSetObject, apiData:get( 'clothing.resistances' ), 'type', 'multiplier', 'ModifierDamageTaken', translate, formatConfig )

    if apiData.clothing and apiData.clothing.clothing_type then
        smwSetObject[ t( 'SMW_Subtype') ] = apiData.clothing.clothing_type
    end

    if apiData.sub_type then
        -- This is an armor
        if apiData.sub_type == 'Light' or apiData.sub_type == 'Medium' or apiData.sub_type == 'Heavy' then
            smwSetObject[ t( 'SMW_Subtype') ] = translate( string.format( 'type_%s_armor', string.lower( apiData.sub_type ) ) )
        end
    end
end


--- Adds all SMW parameters set by this Module to the ASK object
---
--- @param smwAskObject table
--- @return nil
function p.addSmwAskProperties( smwAskObject )
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
--- @return nil
function p.addInfoboxData( infobox, smwData )
    --- Format resistance (e.g. 0.9) to human readable format (e.g. 10%)
    ---
    --- @param key string SMW property name of the resistance data
    --- @return string|nil
    local function getResistance( key )
        local translatedKey = translate( key )
        if smwData[translatedKey] == nil or type( smwData[translatedKey] ) ~= 'number' then
            return
        end

        return ( 1 - smwData[translatedKey] ) * 100 .. ' %'
    end

    infobox:renderSection( {
        title = t( 'label_Clothing' ),
        content = {
            infobox:renderItem( {
                label = t( 'label_ResistanceTemperature' ),
                data = infobox.addUnitIfExists( infobox.formatRange( smwData[ t( 'SMW_ResistanceMinimumTemperature' ) ], smwData[ t( 'SMW_ResistanceMaximumTemperature' ) ], true ), '°C')
            } )
        },
        col = 2
    } )

    -- TODO: Maybe we should somehow generalize the armor section since it applies to other items too
    infobox:renderSection( {
        title = t( 'label_Armor' ),
        content = {
            infobox:renderItem( {
                label = t( 'label_ModifierDamageTakenPhysical' ),
                tooltip = t( 'SMW_ModifierDamageTakenPhysical' ),
                data = getResistance( 'SMW_ModifierDamageTakenPhysical' )
            } ),
            infobox:renderItem( {
                label = t( 'label_ModifierDamageTakenEnergy' ),
                tooltip = t( 'SMW_ModifierDamageTakenEnergy' ),
                data = getResistance( 'SMW_ModifierDamageTakenEnergy' )
            } ),
            infobox:renderItem( {
                label = t( 'label_ModifierDamageTakenDistortion' ),
                tooltip = t( 'SMW_ModifierDamageTakenDistortion' ),
                data = getResistance( 'SMW_ModifierDamageTakenDistortion' )
            } ),
            infobox:renderItem( {
                label = t( 'label_ModifierDamageTakenThermal' ),
                tooltip = t( 'SMW_ModifierDamageTakenThermal' ),
                data = getResistance( 'SMW_ModifierDamageTakenThermal' )
            } ),
            infobox:renderItem( {
                label = t( 'label_ModifierDamageTakenBiochemical' ),
                tooltip = t( 'SMW_ModifierDamageTakenBiochemical' ),
                data = getResistance( 'SMW_ModifierDamageTakenBiochemical' )
            } ),
            infobox:renderItem( {
                label = t( 'label_ModifierDamageTakenStun' ),
                tooltip = t( 'SMW_ModifierDamageTakenStun' ),
                data = getResistance( 'SMW_ModifierDamageTakenStun' )
            } )
        },
        col = 6
    } )
end


--- Add categories that are set on the page.
--- The categories table should only contain category names, no MW Links, i.e. 'Foo' instead of '[[Category:Foo]]'
---
--- @param categories table The categories table
--- @param frameArgs table Frame arguments from Module:Arguments
--- @param smwData table Data from Semantic MediaWiki
--- @return nil
function p.addCategories( categories, frameArgs, smwData )

end

--- Return the short description for this object
---
--- @param frameArgs table Frame arguments from Module:Arguments
--- @param smwData table Data from Semantic MediaWiki
--- @return string|nil
function p.getShortDescription( frameArgs, smwData )
	
end


return p
