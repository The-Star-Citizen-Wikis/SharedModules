require( 'strict' )

local p = {}

local MODULE_NAME = 'WeaponPersonal'

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
    return TNT:translate( 'Module:Item/' .. MODULE_NAME .. '/i18n.json', config, key, addSuffix, { ... } )
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

    if apiData.personal_weapon then
        -- Save damages as subobjects, we did not do it through data.json because we need to build the key
        -- for the damage SMW properties such as SMW_DamageEnergy
        -- TODO: This should probably apply to vehicle weapon too
        if apiData.personal_weapon.damages then
            local ucfirst = require( 'Module:String2' ).ucfirst
            local subobject = {}
            for _, damage in pairs( apiData.personal_weapon.damages ) do
                -- FIXME: Wikipedia modules like Module:String2 does not have a proper Lua entry point
                -- Perhaps we should look into it some day
                local ucfirstArgs = { args = { damage.name } }
                subobject[ t( 'SMW_DamageType' ) ] = damage.type
                subobject[ t( 'SMW_Damage' .. ucfirst( ucfirstArgs ) ) ] = damage.damage
            end
            mw.smw.subobject( subobject )
        end

        -- Get the lowest damage falloff min distance value
        -- FIXME: Maybe we should create a utility function to do nil checks on each level of the table until the end
        -- TODO: This should probably apply to vehicle weapon too
        if apiData.personal_weapon.ammunition and apiData.personal_weapon.ammunition.damage_falloffs and apiData.personal_weapon.ammunition.damage_falloffs.min_distance then
            local effectiveRange
            local minDistances = apiData.personal_weapon.ammunition.damage_falloffs.min_distance
            local i = 1
            for _, minDistance in pairs( minDistances ) do
                if minDistance ~= 0 then
                    if not effectiveRange then
                        effectiveRange = minDistance
                    elseif minDistances[ i - 1 ] and minDistance < minDistances[ i - 1 ] then
                        effectiveRange = minDistance
                    end
                end
                i = i + 1
            end

            -- Use maximum range as effective range if there are no falloff
            smwSetObject[ t( 'SMW_EffectiveRange' ) ] = effectiveRange or apiData.personal_weapon.ammunition.range
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
function p.addInfoboxData( infobox, smwData, itemPageIdentifier )
    local tabber = require( 'Module:Tabber' ).renderTabber

    local function renderDamagesSection()
        local damageTypes = {
            'Physical',
            'Energy',
            'Distortion',
            'Thermal',
            'Biochemical',
            'Stun'
        }

        local smwProps = { 'SMW_DamageType' }
        for _, damageType in ipairs( damageTypes ) do
            table.insert( smwProps, 'SMW_Damage' .. damageType )
        end

        local subobjects = smwCommon.loadSubobjects(
            itemPageIdentifier,
            'SMW_DamageType',
            smwProps,
            translate
        )

        if type( subobjects ) == 'table' then
            local section = {}
            local tabberData = {}
            local tabCount = 1

            for _, mode in ipairs( subobjects ) do
                tabberData[ 'label' .. tabCount ] = translate( 'damagetype_' .. mode[ t( 'SMW_DamageType' ) ] )
                for _, damageType in ipairs( damageTypes ) do
                    table.insert( section,
                        infobox:renderItem( {
                            label = t( 'label_Damage' .. damageType ),
                            tooltip = t( 'SMW_Damage' .. damageType ),
                            data = mode[ t( 'SMW_Damage' .. damageType ) ]
                        } )
                    )
                end
                tabberData[ 'content' .. tabCount ] = infobox:renderSection( { content = section, col = 3 }, true )
                tabCount = tabCount + 1
                -- Clean up
                section = {}
            end

            infobox:renderSection( {
                title = t( 'label_Damages' ),
                class = 'infobox__section--tabber',
                content = tabber( tabberData )
            } )
        end
    end

    local function renderFiringModesSection()
        local subobjects = smwCommon.loadSubobjects(
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

        if type( subobjects ) == 'table' then
            local section = {}
            local tabberData = {}
            local tabCount = 1

            for _, mode in ipairs( subobjects ) do
                tabberData[ 'label' .. tabCount ] = translate( 'firingmode_' ..
                mode[ t( 'SMW_FiringMode' ) ] )
                section = {
                    infobox:renderItem( t( 'label_FiringRate' ), mode[ t( 'SMW_FiringRate' ) ] ),
                    infobox:renderItem( t( 'label_ProjectilePerShot' ),
                        mode[ t( 'SMW_ProjectilePerShot' ) ] ),
                    infobox:renderItem( t( 'label_AmmoPerShot' ), mode[ t( 'SMW_AmmoPerShot' ) ] )
                }
                tabberData[ 'content' .. tabCount ] = infobox:renderSection( { content = section, col = 3 }, true )
                tabCount = tabCount + 1
            end

            infobox:renderSection( {
                title = t( 'label_Modes' ),
                class = 'infobox__section--tabber',
                content = tabber( tabberData )
            } )
        end
    end

    infobox:renderSection( {
        content = {
            infobox:renderItem( t( 'label_Damage' ), smwData[ t( 'SMW_Damage' ) ] ),
            infobox:renderItem( t( 'label_AmmoSpeed' ), smwData[ t( 'SMW_AmmoSpeed' ) ] ),
            infobox:renderItem( t( 'label_EffectiveRange' ), smwData[ t( 'SMW_EffectiveRange' ) ] ),
            infobox:renderItem( t( 'label_MaximumRange' ), smwData[ t( 'SMW_MaximumRange' ) ] ),
            infobox:renderItem( t( 'label_Ammo' ), smwData[ t( 'SMW_Ammo' ) ] )
        },
        col = 2
    } )
    renderDamagesSection()
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
    -- Add weapon type categories directly (e.g. SMGs, Shotguns, etc.)
    if smwData[ t( 'SMW_Subtype' ) ] ~= nil then
        local categoryKey = i18n:normalizeKey( 'category_weaponpersonal_' .. smwData[ t( 'SMW_Subtype' ) ] )
        table.insert( categories, t( categoryKey ) )
    end
end

--- Return the short description for this object
---
--- @param frameArgs table Frame arguments from Module:Arguments
--- @param smwData table Data from Semantic MediaWiki
--- @return string|nil
function p.getShortDescription( frameArgs, smwData )

end

return p
