require( 'strict' )

local p = {}

local MODULE_NAME = 'CharArmor'

local TNT = require( 'Module:Translate' ):new()
local smwCommon = require( 'Module:Common/SMW' )
local data = mw.loadJsonData( 'Module:Item/' .. MODULE_NAME .. '/data.json' )
local config = mw.loadJsonData( 'Module:Item/config.json' )


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

    local setData = {}

    smwCommon.setFromTable( setData, apiData:get( 'clothing.resistances' ), 'type', 'multiplier', 'ModifierDamageTaken', translate )

    mw.smw.set( setData )
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
        title = translate( 'LBL_Resistances' ),
        content = {
            infobox:renderItem( {
                label = translate( 'LBL_ModifierDamageTakenPhysical' ),
                data = getResistance( 'SMW_ModifierDamageTakenPhysical' )
            } ),
            infobox:renderItem( {
                label = translate( 'LBL_ModifierDamageTakenEnergy' ),
                data = getResistance( 'SMW_ModifierDamageTakenEnergy' )
            } ),
            infobox:renderItem( {
                label = translate( 'LBL_ModifierDamageTakenDistortion' ),
                data = getResistance( 'SMW_ModifierDamageTakenDistortion' )
            } ),
            infobox:renderItem( {
                label = translate( 'LBL_ModifierDamageTakenThermal' ),
                data = getResistance( 'SMW_ModifierDamageTakenThermal' )
            } ),
            infobox:renderItem( {
                label = translate( 'LBL_ModifierDamageTakenBiochemical' ),
                data = getResistance( 'SMW_ModifierDamageTakenBiochemical' )
            } ),
            infobox:renderItem( {
                label = translate( 'LBL_ModifierDamageTakenStun' ),
                data = getResistance( 'SMW_ModifierDamageTakenStun' )
            } ),
            infobox:renderItem( {
                label = translate( 'LBL_ResistanceTemperature' ),
                data = infobox.addUnitIfExists( infobox.formatRange( smwData[ translate( 'SMW_ResistanceMinimumTemperature' ) ], smwData[ translate( 'SMW_ResistanceMaximumTemperature' ) ], true ), '°C')
            } )
        },
        col = 3
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