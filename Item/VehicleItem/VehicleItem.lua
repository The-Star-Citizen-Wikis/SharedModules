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


local function loadQuantumDriveModes( pageName )
    return mw.smw.ask( {
        '[[-Has subobject::' .. pageName .. ']]',
        string.format( '?%s', translate( 'SMW_QuantumJumpType' ) ),
        string.format( '?%s', translate( 'SMW_QuantumJumpDriveSpeed' ) ),
        string.format( '?%s', translate( 'SMW_QuantumCooldownTime' ) ),
        string.format( '?%s', translate( 'SMW_QuantumSpoolUpTime' ) ),
        'mainlabel=-'
    } )
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

    local setData = {}

    local function setModifiers( modifiers )
        if modifiers == nil or type( modifiers ) ~= 'table' then
            return
        end

        for _, modifier in pairs( modifiers ) do
            local name = modifier.display_name or ''
            name = 'SMW_Modifier' .. name:gsub( ' ', '' )

            if translate( name ) ~= nil then
                local value
                if modifier.name == 'size' then
                    value = modifier.value
                else
                    value = string.gsub( modifier.value, '%%', '' ) / 100
                end

                setData[ translate( name ) ] = value
            end
        end
    end

    setModifiers( apiData:get( 'mining_laser.modifiers' ) )
    setModifiers( apiData:get( 'mining_module.modifiers' ) )

    mw.smw.set( setData )
end


--- Adds all SMW parameters set by this Module to the ASK object
---
--- @param smwAskObject table
--- @return void
function VehicleItem.addSmwAskProperties( smwAskObject )
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
function VehicleItem.addInfoboxData( infobox, smwData, itemPageIdentifier )
    -- Cooler
    if smwData[ translate( 'SMW_CoolingRate' ) ] then
        infobox:renderSection( {
            title = translate( 'LBL_Cooler' ),
            content = {
                infobox:renderItem( translate( 'LBL_CoolingRate' ), smwData[ translate( 'SMW_CoolingRate' ) ] ),
            }
        } )
    -- Power Plant
    elseif smwData[ translate( 'SMW_PowerOutput' ) ] then
        infobox:renderSection( {
            title = translate( 'LBL_PowerPlant' ),
            content = {
                infobox:renderItem( translate( 'LBL_PowerOutput' ), smwData[ translate( 'SMW_PowerOutput' ) ] ),
            }
        } )
    -- Quantum Drive
    elseif smwData[ translate( 'SMW_QuantumFuelRequirement' ) ] then
        local modes = loadQuantumDriveModes( itemPageIdentifier )

        infobox:renderSection( {
            title = translate( 'LBL_QuantumDrive' ),
            col = 2,
            content = {
                infobox:renderItem( translate( 'LBL_QuantumFuelRequirement' ), smwData[ translate( 'SMW_QuantumFuelRequirement' ) ] ),
                infobox:renderItem( translate( 'LBL_QuantumJumpRange' ), smwData[ translate( 'SMW_QuantumJumpRange' ) ] ),
            }
        } )

        if type( modes ) == 'table' then
            for _, mode in ipairs( modes ) do
                local modeTitle = mode[ translate( 'SMW_QuantumJumpType' ) ]
                infobox:renderSection( {
                    title = ( mode[ translate( 'SMW_QuantumJumpType' ) ] ),
                    col = 3,
                    content = {
                        infobox:renderItem( translate( 'LBL_QuantumJumpDriveSpeed' ), mode[ translate( 'SMW_QuantumJumpDriveSpeed' ) ] ),
                        infobox:renderItem( translate( 'LBL_QuantumCooldownTime' ), mode[ translate( 'SMW_QuantumCooldownTime' ) ] ),
                        infobox:renderItem( translate( 'LBL_QuantumSpoolUpTime' ), mode[ translate( 'SMW_QuantumSpoolUpTime' ) ] ),
                    }
                } )
            end
        end
    -- Shield
    elseif smwData[ translate( 'SMW_ShieldPoints' ) ] then
        infobox:renderSection( {
            title = translate( 'LBL_Shield' ),
            col = 2,
            content = {
                infobox:renderItem( translate( 'LBL_ShieldPoints' ), smwData[ translate( 'SMW_ShieldPointRegeneration' ) ] ),
                infobox:renderItem( translate( 'LBL_ShieldPointRegeneration' ), smwData[ translate( 'SMW_ShieldPointRegeneration' ) ] ),
                infobox:renderItem( translate( 'LBL_ShieldDownTime' ), smwData[ translate( 'SMW_ShieldDownTime' ) ] ),
                infobox:renderItem( translate( 'LBL_ShieldDamageDelay' ), smwData[ translate( 'SMW_ShieldDamageDelay' ) ] ),
            }
        } )

        -- TODO: Add on API
        --infobox:renderSection( {
        --    title = translate( 'LBL_Resistances' ),
        --    col = 3,
        --    content = {
        --        infobox:renderItem( translate( 'LBL_ShieldPhysicalResistance' ), smwData[ translate( 'SMW_ShieldPhysicalResistance' ) ] ),
        --        infobox:renderItem( translate( 'LBL_ShieldEnergyResistance' ), smwData[ translate( 'SMW_ShieldEnergyResistance' ) ] ),
        --        infobox:renderItem( translate( 'LBL_ShieldDistortionResistance' ), smwData[ translate( 'SMW_ShieldDistortionResistance' ) ] ),
        --
        --        infobox:renderItem( translate( 'LBL_ShieldThermalResistance' ), smwData[ translate( 'SMW_ShieldThermalResistance' ) ] ),
        --        infobox:renderItem( translate( 'LBL_ShieldBiochemicalResistance' ), smwData[ translate( 'SMW_ShieldBiochemicalResistance' ) ] ),
        --        infobox:renderItem( translate( 'LBL_ShieldStunResistance' ), smwData[ translate( 'SMW_ShieldStunResistance' ) ] ),
        --    }
        --} )
    -- Quantum Drive
    elseif smwData[ translate( 'SMW_MaxMissiles' ) ] then
        infobox:renderSection( {
            title = translate( 'LBL_MissileRack' ),
            col = 2,
            content = {
                infobox:renderItem( translate( 'LBL_MaxMissiles' ), smwData[ translate( 'SMW_MaxMissiles' ) ] ),
                infobox:renderItem( translate( 'LBL_MissileSize' ), smwData[ translate( 'SMW_MissileSize' ) ] ),
            }
        } )
    -- Mining Laser
    elseif smwData[ translate( 'SMW_MiningLaserPower' ) ] then
        infobox:renderSection( {
            title = translate( 'LBL_MiningLaser' ),
            col = 2,
            content = {
                infobox:renderItem( translate( 'LBL_PowerTransfer' ), smwData[ translate( 'SMW_PowerTransfer' ) ] ),
                infobox:renderItem( translate( 'LBL_OptimalRange' ), smwData[ translate( 'SMW_OptimalRange' ) ] ),
                infobox:renderItem( translate( 'LBL_MaximumRange' ), smwData[ translate( 'SMW_MaximumRange' ) ] ),
                infobox:renderItem( translate( 'LBL_ExtractionThroughput' ), smwData[ translate( 'SMW_ExtractionThroughput' ) ] ),
                infobox:renderItem( translate( 'LBL_MiningLaserPower' ), smwData[ translate( 'SMW_MiningLaserPower' ) ] ),
                infobox:renderItem( translate( 'LBL_ExtractionLaserPower' ), smwData[ translate( 'SMW_ExtractionLaserPower' ) ] ),
                infobox:renderItem( translate( 'LBL_ModuleSlots' ), smwData[ translate( 'SMW_ModuleSlots' ) ] ),
            }
        } )

        infobox:renderSection( {
            title = translate( 'LBL_Modifiers' ),
            col = 3,
            content = {
                infobox:renderItem( translate( 'LBL_ModifierCatastrophicChargeRate' ), smwData[ translate( 'SMW_ModifierCatastrophicChargeRate' ) ] ),
                infobox:renderItem( translate( 'LBL_ModifierExtractionLaserPower' ), smwData[ translate( 'SMW_ModifierExtractionLaserPower' ) ] ),
                infobox:renderItem( translate( 'LBL_ModifierLaserInstability' ), smwData[ translate( 'SMW_ModifierLaserInstability' ) ] ),
                infobox:renderItem( translate( 'LBL_ModifierMiningLaserPower' ), smwData[ translate( 'SMW_ModifierMiningLaserPower' ) ] ),
                infobox:renderItem( translate( 'LBL_ModifierOptimalChargeWindowRate' ), smwData[ translate( 'SMW_ModifierOptimalChargeWindowRate' ) ] ),
                infobox:renderItem( translate( 'LBL_ModifierInertMaterials' ), smwData[ translate( 'SMW_ModifierInertMaterials' ) ] ),
                infobox:renderItem( translate( 'LBL_ModifierOptimalChargeRate' ), smwData[ translate( 'SMW_ModifierOptimalChargeRate' ) ] ),
                infobox:renderItem( translate( 'LBL_ModifierResistance' ), smwData[ translate( 'SMW_ModifierResistance' ) ] ),
                infobox:renderItem( translate( 'LBL_ModifierShatterDamage' ), smwData[ translate( 'SMW_ModifierShatterDamage' ) ] ),
                infobox:renderItem( translate( 'LBL_ModifierSize' ), smwData[ translate( 'SMW_ModifierSize' ) ] ),
            }
        } )
    -- Mining Module
    elseif smwData[ translate( 'SMW_ModuleUses' ) ] then
        infobox:renderSection( {
            title = translate( 'LBL_MiningModule' ),
            col = 2,
            content = {
                infobox:renderItem( translate( 'LBL_ModuleUses' ), smwData[ translate( 'SMW_ModuleUses' ) ] ),
                infobox:renderItem( translate( 'LBL_ModuleDuration' ), smwData[ translate( 'SMW_ModuleDuration' ) ] ),
            }
        } )

        infobox:renderSection( {
            title = translate( 'LBL_Modifiers' ),
            col = 3,
            content = {
                infobox:renderItem( translate( 'LBL_ModifierCatastrophicChargeRate' ), smwData[ translate( 'SMW_ModifierCatastrophicChargeRate' ) ] ),
                infobox:renderItem( translate( 'LBL_ModifierExtractionLaserPower' ), smwData[ translate( 'SMW_ModifierExtractionLaserPower' ) ] ),
                infobox:renderItem( translate( 'LBL_ModifierLaserInstability' ), smwData[ translate( 'SMW_ModifierLaserInstability' ) ] ),
                infobox:renderItem( translate( 'LBL_ModifierMiningLaserPower' ), smwData[ translate( 'SMW_ModifierMiningLaserPower' ) ] ),
                infobox:renderItem( translate( 'LBL_ModifierOptimalChargeWindowRate' ), smwData[ translate( 'SMW_ModifierOptimalChargeWindowRate' ) ] ),
                infobox:renderItem( translate( 'LBL_ModifierInertMaterials' ), smwData[ translate( 'SMW_ModifierInertMaterials' ) ] ),
                infobox:renderItem( translate( 'LBL_ModifierOptimalChargeRate' ), smwData[ translate( 'SMW_ModifierOptimalChargeRate' ) ] ),
                infobox:renderItem( translate( 'LBL_ModifierResistance' ), smwData[ translate( 'SMW_ModifierResistance' ) ] ),
                infobox:renderItem( translate( 'LBL_ModifierShatterDamage' ), smwData[ translate( 'SMW_ModifierShatterDamage' ) ] ),
                infobox:renderItem( translate( 'LBL_ModifierSize' ), smwData[ translate( 'SMW_ModifierSize' ) ] ),
            }
        } )
    end
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
function VehicleItem.getShortDescription( shortdesc, frameArgs, smwData )
	
end


return VehicleItem