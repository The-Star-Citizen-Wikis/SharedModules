require( 'strict' )

local p = {}

local MODULE_NAME = 'WeaponPersonal'

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

    -- Get the lowest damage falloff min distance value as effective range
    -- FIXME: Maybe we should create a utility function to do nil checks like this
    if apiData.personal_weapon and apiData.personal_weapon.ammunition and apiData.personal_weapon.ammunition.damage_falloffs and apiData.personal_weapon.ammunition.damage_falloffs.min_distance then
        local effectiveRange
        local minDistances = apiData.personal_weapon.ammunition.damage_falloffs.min_distance
        local i = 1
        for _, minDistance in pairs( minDistances ) do
            if minDistance ~= 0 then
                if i == 1 then
                    effectiveRange = minDistance
                elseif minDistances[ i - 1 ] and minDistance < minDistances[ i - 1 ] then
                    effectiveRange = minDistance
                end
            end
            i = i + 1
        end

        if effectiveRange then
            setData[ translate( 'SMW_EffectiveRange' ) ] = effectiveRange
        end
    end

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
function p.addInfoboxData( infobox, smwData, itemPageIdentifier )
    local tabber = require( 'Module:Tabber' ).renderTabber

    local function renderFiringModesSection()
        local modes = smwCommon.loadSubobjects(
            itemPageIdentifier,
            'SMW_FiringMode',
            {
                'SMW_FiringMode',
                'SMW_FiringRate',
                'SMW_AmmoPerShot',
                'SMW_ProjectilePerShot'
            },
            translate
        )

        if type( modes ) == 'table' then
            local section = {}
            local modeTabberData = {}
            local modeCount = 1

            for _, mode in ipairs( modes ) do
                modeTabberData[ 'label' .. modeCount ] = translate( 'firingmode_' .. mode[ translate( 'SMW_FiringMode' ) ] )
                section = {
                    infobox:renderItem( translate( 'LBL_FiringRate' ), mode[ translate( 'SMW_FiringRate' ) ] ),
                    infobox:renderItem( translate( 'LBL_ProjectilePerShot' ), mode[ translate( 'SMW_ProjectilePerShot' ) ] ),
                    infobox:renderItem( translate( 'LBL_AmmoPerShot' ), mode[ translate( 'SMW_AmmoPerShot' ) ] )
                }
                modeTabberData[ 'content' .. modeCount ] = infobox:renderSection( { content = section, col = 3 }, true )
                modeCount = modeCount + 1
            end

            infobox:renderSection( {
                title = translate( 'LBL_Modes' ),
                class = 'infobox__section--tabber',
                content = tabber( modeTabberData ),
                border = false
            } )
        end
    end

    infobox:renderSection( {
        content = {
            infobox:renderItem( translate( 'LBL_Damage' ), smwData[ translate( 'SMW_Damage' ) ] ),
            infobox:renderItem( translate( 'LBL_AmmoSpeed' ), smwData[ translate( 'SMW_AmmoSpeed' ) ] ),
            infobox:renderItem( translate( 'LBL_EffectiveRange' ), smwData[ translate( 'SMW_EffectiveRange' ) ] ),
            infobox:renderItem( translate( 'LBL_MaximumRange' ), smwData[ translate( 'SMW_MaximumRange' ) ] ),
            infobox:renderItem( translate( 'LBL_Ammo' ), smwData[ translate( 'SMW_Ammo' ) ] )
        },
        col = 2
    } )
    renderFiringModesSection()
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