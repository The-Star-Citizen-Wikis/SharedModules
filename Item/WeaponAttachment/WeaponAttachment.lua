require( 'strict' )

local p = {}

local MODULE_NAME = 'WeaponAttachment'

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

    -- If the modifier equals to 1, then it does nothing and the data is not useful
    -- TODO: Should we upstream this to Item?
    local modifiers = { 'SMW_ModifierDamage', 'SMW_ModifierFireRecoilStrength', 'SMW_ModifierSoundRadius' }
    for _, modifier in ipairs( modifiers ) do
        local smwProp = smwSetObject[ translate( modifier ) ]

        if smwProp then
            if smwProp == 1 then
                smwSetObject[ translate( modifier ) ] = nil
            else
                smwSetObject[ translate( modifier ) ] = smwCommon.format( { type = "number" }, smwProp )
            end
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
    -- Barrel attachments
    if smwData[ translate( 'SMW_Type' ) ] == 'WeaponAttachment.Barrel' then
        infobox:renderSection( {
            content = {
                infobox:renderItem( {
                    label = translate( 'LBL_ModifierDamage' ),
                    data = smwData[ translate( 'SMW_ModifierDamage' ) ],
                } ),
                infobox:renderItem( {
                    label = translate( 'LBL_ModifierFireRecoilStrength' ),
                    data = smwData[ translate( 'SMW_ModifierFireRecoilStrength' ) ],
                } ),
                infobox:renderItem( {
                    label = translate( 'LBL_ModifierSoundRadius' ),
                    data = smwData[ translate( 'SMW_ModifierSoundRadius' ) ],
                } )
            },
            col = 3
        } )
    -- Optics attachments
    elseif smwData[ translate( 'SMW_Type' ) ] == 'WeaponAttachment.IronSight' then
        infobox:renderSection( {
            content = {
                infobox:renderItem( {
                    label = translate( 'LBL_OpticsMagnification' ),
                    data = smwData[ translate( 'SMW_OpticsMagnification' ) ],
                } ),
                infobox:renderItem( {
                    label = translate( 'LBL_ZeroingRange' ),
                    data = smwData[ translate( 'SMW_ZeroingRange' ) ],
                } ),
                infobox:renderItem( {
                    label = translate( 'LBL_ZeroingRangeIncrement' ),
                    data = smwData[ translate( 'SMW_ZeroingRangeIncrement' ) ],
                } ),
                infobox:renderItem( {
                    label = translate( 'LBL_AutoZeroingTime' ),
                    data = smwData[ translate( 'SMW_AutoZeroingTime' ) ],
                } )
            },
            col = 2
        } )
    elseif smwData[ translate( 'SMW_Type' ) ] == 'WeaponAttachment.Magazine' then
        infobox:renderSection( {
            content = {
                infobox:renderItem( {
                    label = translate( 'LBL_Ammo' ),
                    data = smwData[ translate( 'SMW_Ammo' ) ],
                } )
            },
            col = 2
        } )
    end
end


--- Add categories that are set on the page.
--- The categories table should only contain category names, no MW Links, i.e. 'Foo' instead of '[[Category:Foo]]'
---
--- @param categories table The categories table
--- @param frameArgs table Frame arguments from Module:Arguments
--- @param smwData table Data from Semantic MediaWiki
--- @return nil
function p.addCategories( categories, frameArgs, smwData )
    -- FIXME: Is there a way to make addSubcategory avaliable here?

    -- Barrel attachments
    --if smwData[ translate( 'SMW_Type' ) ] == 'WeaponAttachment.Barrel' then
    --    -- e.g. Category:Barrel attachments (Energy stabliizer)
    --    table.insert( categories, string.format( '%s (%s)',
    --        translate( 'category_weaponattachment.barrel' ),
    --        translate( 'class_barrelattachmenttype' )
    --    ) )
    -- Optics attachments
    --elseif smwData[ translate( 'SMW_Type' ) ] == 'WeaponAttachment.IronSight' then
    --    -- e.g. Category:Optics attachments (Telescopic)
    --    table.insert( categories, string.format( '%s (%s)',
    --        translate( 'category_weaponattachment.ironsight' ),
    --        translate( 'class_opticstype' )
    --    ) )
    --end
end

--- Return the short description for this object
---
--- @param frameArgs table Frame arguments from Module:Arguments
--- @param smwData table Data from Semantic MediaWiki
--- @return string|nil
function p.getShortDescription( frameArgs, smwData )
	
end


return p
