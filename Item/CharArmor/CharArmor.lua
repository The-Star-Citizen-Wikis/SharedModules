require( 'strict' )

local p = {}

local CONST = {
    TEMPERATURE = {
        MIN = -230,
        MAX = 250
    }
}

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

    --- Format modifiers for infobox:renderItem
    --- TODO: Maybe make this generic for other infobox modules?
    local function getModifierItemData( data )
        if not data or not data.data then return {} end
        local itemData = {
            class = 'infobox__item--is-cell',
            label = data.label,
            -- Default to 0%
            data = '0%',
            tooltip = data.tooltip
        }
        local x = data.data
        -- Fix for german number format
        if string.find( x, ',', 1, true ) then
            x = string.gsub( x, ',', '.' )
        end
        if type( x ) == 'string' then x = tonumber( x, 10 ) end

        local diff = x - 1
        if diff == 0 then
            itemData.class = itemData.class .. ' infobox__item--null'
        elseif diff > 0 then
            itemData.class = itemData.class .. ' infobox__item--negative'
            itemData.data = '+' .. tostring( math.abs( diff ) * 100 ) .. '%'
        elseif diff < 0 then
            itemData.class = itemData.class .. ' infobox__item--positive'
            itemData.data = '-' .. tostring( math.abs( diff ) * 100 ) .. '%'
        end
        return itemData
    end


    local function getTemperatureItemData()
        local minTemp = smwData[ t( 'SMW_ResistanceMinimumTemperature' ) ]
        local maxTemp = smwData[ t( 'SMW_ResistanceMaximumTemperature' ) ]

        if not minTemp or not maxTemp then return {} end

        local totalRange = CONST.TEMPERATURE.MAX - CONST.TEMPERATURE.MIN
        local startPercentage = ( ( minTemp - CONST.TEMPERATURE.MIN ) / totalRange ) * 100
        local endPercentage = ( ( maxTemp - CONST.TEMPERATURE.MIN ) / totalRange ) * 100

        return {
            class = 'infobox__item--is-range--temperature',
            label = t( 'label_ResistanceTemperature' ),
            data = infobox.formatRange( minTemp, maxTemp, true ) .. '°C',
            range = {
                ['start'] = tostring( startPercentage ) .. '%',
                ['end'] = tostring( endPercentage ) .. '%'
            }
        }
    end

    infobox:renderSection( {
        title = t( 'label_Clothing' ),
        content = {
            infobox:renderItem( getTemperatureItemData() )
        }
    } )

    -- TODO: Maybe we should somehow generalize the armor section since it applies to other items too
    infobox:renderSection( {
        title = t( 'label_Armor' ),
        content = {
            infobox:renderItem( getModifierItemData ( {
                label = t( 'label_ModifierDamageTakenPhysical' ),
                tooltip = t( 'SMW_ModifierDamageTakenPhysical' ),
                data = smwData[ t( 'SMW_ModifierDamageTakenPhysical' ) ]
            } ) ),
            infobox:renderItem( getModifierItemData( {
                label = t( 'label_ModifierDamageTakenEnergy' ),
                tooltip = t( 'SMW_ModifierDamageTakenEnergy' ),
                data = smwData[ t( 'SMW_ModifierDamageTakenEnergy' ) ]
            } ) ),
            infobox:renderItem( getModifierItemData( {
                label = t( 'label_ModifierDamageTakenDistortion' ),
                tooltip = t( 'SMW_ModifierDamageTakenDistortion' ),
                data = smwData[ t( 'SMW_ModifierDamageTakenDistortion' ) ]
            } ) ),
            infobox:renderItem( getModifierItemData( {
                label = t( 'label_ModifierDamageTakenThermal' ),
                tooltip = t( 'SMW_ModifierDamageTakenThermal' ),
                data = smwData[ t( 'SMW_ModifierDamageTakenThermal' ) ]
            } ) ),
            infobox:renderItem( getModifierItemData( {
                label = t( 'label_ModifierDamageTakenBiochemical' ),
                tooltip = t( 'SMW_ModifierDamageTakenBiochemical' ),
                data = smwData[ t( 'SMW_ModifierDamageTakenBiochemical' ) ]
            } ) ),
            infobox:renderItem( getModifierItemData( {
                label = t( 'label_ModifierDamageTakenStun' ),
                tooltip = t( 'SMW_ModifierDamageTakenStun' ),
                data = smwData[ t( 'SMW_ModifierDamageTakenStun' ) ]
            } ) )
        },
        col = 6,
        contentClass = 'infobox__sectionContent--has-cells'
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
