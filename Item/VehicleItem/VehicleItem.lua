require( 'strict' )

local VehicleItem = {}

local TNT = require( 'Module:Translate' ):new()
local common = require( 'Module:Common' )
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


--- Retrieve subobjects
---
--- @param pageName string
--- @param identifierPropKey string SMW property key used to identify subobjects
--- @param propertyKeys table table of SMW property keys
--- @return table
local function loadSubobjects( pageName, identifierPropKey, propKeys )
    local askQuery = {
        '[[-Has subobject::' .. pageName .. ']]',
        '[[' .. translate( identifierPropKey ) .. '::+]]'
    }

    for _, propKey in ipairs( propKeys ) do
        table.insert( askQuery, string.format( '?%s', translate( propKey ) ) )
    end

    table.insert( askQuery, 'mainlabel=-' )

    local subobjects = mw.smw.ask( askQuery )

    if subobjects == nil then return {} end

    local subobjectTable = {}

    for _, subobject in ipairs( subobjects ) do
        if subobject[ translate( identifierPropKey ) ] then
            table.insert( subobjectTable, subobject )
        end
    end

    return subobjectTable
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
        'Item/VehicleItem'
    )

    local setData = {}

    --- @param tableData table Array data from API
    --- @param nameKey string Key of the value being used as name in the SMW property
    --- @param valueKey string Key of the value being used as value in the SMW property
    --- @param prefix string Prefix of the SMW property name
    local function setFromTable( tableData, namekey, valueKey, prefix )
        if tableData == nil or type( tableData ) ~= 'table' then
            return
        end

        for _, data in pairs( tableData ) do
            local name = data[namekey] or ''
            name = 'SMW_' .. prefix .. name:gsub('^%l', string.upper):gsub( ' ', '' )

            if translate( name ) ~= nil then
                local value

                value = data[valueKey]

                -- Handle percentage such as 10% used in modifiers
                if type( value ) == 'string' and value:find( '%d+%%' ) then
                    value = string.gsub( value, '%%', '' ) / 100
                end

                setData[ translate( name ) ] = value
            end
        end
    end

    setFromTable( apiData:get( 'mining_laser.modifiers' ), 'display_name', 'value', 'Modifier' )
    setFromTable( apiData:get( 'mining_module.modifiers' ), 'display_name', 'value', 'Modifier' )
    setFromTable( apiData:get( 'missile.damages' ), 'name', 'damage', 'Damage' )

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
    local tabber = require( 'Module:Tabber' ).renderTabber
    local tabberData = {}
    local section

    -- Cooler
    if smwData[ translate( 'SMW_Type' ) ] == 'Cooler' then
        -- Overview
        tabberData[ 'label1' ] = translate( 'LBL_Overview' )
        section = {
            infobox:renderItem( translate( 'LBL_CoolingRate' ), smwData[ translate( 'SMW_CoolingRate' ) ] )
        }
        tabberData[ 'content1' ] = infobox:renderSection( { content = section, col = 2 }, true )
    -- EMP Generator
    elseif smwData[ translate( 'SMW_Type' ) ] == 'EMP' then
        -- Overview
        tabberData[ 'label1' ] = translate( 'LBL_Overview' )
        section = {
            infobox:renderItem( translate( 'LBL_EMPRadius' ), smwData[ translate( 'SMW_EMPRadius' ) ] ),
            infobox:renderItem( translate( 'LBL_ChargeTime' ), smwData[ translate( 'SMW_ChargeTime' ) ] ),
            infobox:renderItem( translate( 'LBL_CooldownTime' ), smwData[ translate( 'SMW_CooldownTime' ) ] ),
            infobox:renderItem( translate( 'LBL_Duration' ), smwData[ translate( 'SMW_Duration' ) ] )
        }
        tabberData[ 'content1' ] = infobox:renderSection( { content = section, col = 2 }, true )
    -- Gun / Rocket Pod
    elseif smwData[ translate( 'SMW_Type' ) ] == 'WeaponGun.Gun' or smwData[ translate( 'SMW_Type' ) ] == 'WeaponGun.Rocket' then
        local function getFiringModesSection()
            local modes = loadSubobjects( 
                itemPageIdentifier,
                'SMW_FiringMode',
                {
                    'SMW_FiringMode',
                    'SMW_FiringRate',
                    'SMW_AmmoPerShot',
                    'SMW_ProjectilePerShot',
                    'SMW_DamagePerSecond'
                }
            )

            if type( modes ) == 'table' then
                local modeTabberData = {}
                local modeCount = 1

                for _, mode in ipairs( modes ) do
                    modeTabberData[ 'label' .. modeCount ] = translate( mode[ translate( 'SMW_FiringMode' ) ] )
                    section = {
                        infobox:renderItem( translate( 'LBL_DamagePerSecond' ), mode[ translate( 'SMW_DamagePerSecond' ) ] ),
                        infobox:renderItem( translate( 'LBL_FiringRate' ), mode[ translate( 'SMW_FiringRate' ) ] ),
                        infobox:renderItem( translate( 'LBL_ProjectilePerShot' ), mode[ translate( 'SMW_ProjectilePerShot' ) ] ),
                        infobox:renderItem( translate( 'LBL_AmmoPerShot' ), mode[ translate( 'SMW_AmmoPerShot' ) ] )
                    }
                    modeTabberData[ 'content' .. modeCount ] = infobox:renderSection( { content = section, col = 2 }, true )
                    modeCount = modeCount + 1
                end

                return infobox:renderSection( {
                    title = translate( 'LBL_Modes' ),
                    class = 'infobox__section--tabber',
                    content = tabber( modeTabberData ),
                    border = false
                }, true )
            end
        end

        -- Overview
        tabberData[ 'label1' ] = translate( 'LBL_Overview' )
        section = {
            infobox:renderItem( translate( 'LBL_Subtype' ), smwData[ translate( 'SMW_Subtype' ) ] ),
            infobox:renderItem( translate( 'LBL_MaximumRange' ), smwData[ translate( 'SMW_MaximumRange' ) ] ),
            infobox:renderItem( translate( 'LBL_Damage' ), smwData[ translate( 'SMW_Damage' ) ] ),
            infobox:renderItem( translate( 'LBL_Ammo' ), smwData[ translate( 'SMW_Ammo' ) ] )
        }
        tabberData[ 'content1' ] = infobox:renderSection( { content = section, col = 2 }, true ) .. getFiringModesSection()
    -- Missile
    elseif smwData[ translate( 'SMW_Type' ) ] == 'Missile.Missile' or smwData[ translate( 'SMW_Type' ) ] == 'Missile.Torpedo' then
        -- Overview
        tabberData[ 'label1' ] = translate( 'LBL_Overview' )
        section = {
            infobox:renderItem( translate( 'LBL_SignalType' ), smwData[ translate( 'SMW_SignalType' ) ] ),
            infobox:renderItem( translate( 'LBL_LockTime' ), smwData[ translate( 'SMW_LockTime' ) ] ),
            infobox:renderItem( translate( 'LBL_DamagePhysical' ), smwData[ translate( 'SMW_DamagePhysical' ) ] ),
            infobox:renderItem( translate( 'LBL_DamageEnergy' ), smwData[ translate( 'SMW_DamageEnergy' ) ] )
        }
        tabberData[ 'content1' ] = infobox:renderSection( { content = section, col = 2 }, true )
    -- Missile launcher / Weapon mount
    elseif smwData[ translate( 'SMW_Type' ) ] == 'MissileLauncher.MissileRack' or smwData[ translate( 'SMW_Type' ) ] == 'Turret.GunTurret' or smwData[ translate( 'SMW_Type' ) ] == 'Turret.BallTurret' or smwData[ translate( 'SMW_Type' ) ] == 'Turret.CanardTurret' then
        --- NOTE: Should we just set the size SMW property to type:quantity, then prefix the S as a unit?
        local function getMountedSize()
            if smwData[ translate( 'SMW_MountedSize' ) ] == nil then return end
            return 'S' .. smwData[ translate( 'SMW_MountedSize' ) ]
        end

        -- Overview
        tabberData[ 'label1' ] = translate( 'LBL_Overview' )
        section = {
            infobox:renderItem( translate( 'LBL_MountedCount' ), smwData[ translate( 'SMW_MountedCount' ) ] ),
            infobox:renderItem( translate( 'LBL_MountedSize' ), getMountedSize() )
        }
        tabberData[ 'content1' ] = infobox:renderSection( { content = section, col = 2 }, true )
    -- Mining Laser
    elseif smwData[ translate( 'SMW_Type' ) ] == 'WeaponMining.Gun' then
        -- Overview
        tabberData[ 'label1' ] = translate( 'LBL_Overview' )
        section = {
            infobox:renderItem( translate( 'LBL_MiningLaserPower' ), smwData[ translate( 'SMW_MiningLaserPower' ) ] ),
            infobox:renderItem( translate( 'LBL_ExtractionLaserPower' ), smwData[ translate( 'SMW_ExtractionLaserPower' ) ] ),
            infobox:renderItem( translate( 'LBL_OptimalRange' ), smwData[ translate( 'SMW_OptimalRange' ) ] ),
            infobox:renderItem( translate( 'LBL_MaximumRange' ), smwData[ translate( 'SMW_MaximumRange' ) ] ),
            infobox:renderItem( translate( 'LBL_ExtractionThroughput' ), smwData[ translate( 'SMW_ExtractionThroughput' ) ] ),
            infobox:renderItem( translate( 'LBL_ModuleSlots' ), smwData[ translate( 'SMW_ModuleSlots' ) ] )
        }
        tabberData[ 'content1' ] = infobox:renderSection( { content = section, col = 2 }, true )

        tabberData[ 'label2' ] = translate( 'LBL_Modifiers' )
        section = {
            infobox:renderItem( translate( 'LBL_ModifierCatastrophicChargeRate' ), smwData[ translate( 'SMW_ModifierCatastrophicChargeRate' ) ] ),
            --infobox:renderItem( translate( 'LBL_ModifierExtractionLaserPower' ), smwData[ translate( 'SMW_ModifierExtractionLaserPower' ) ] ),
            infobox:renderItem( translate( 'LBL_ModifierLaserInstability' ), smwData[ translate( 'SMW_ModifierLaserInstability' ) ] ),
            --infobox:renderItem( translate( 'LBL_ModifierMiningLaserPower' ), smwData[ translate( 'SMW_ModifierMiningLaserPower' ) ] ),
            --infobox:renderItem( translate( 'LBL_ModifierOptimalChargeWindowSize' ), smwData[ translate( 'SMW_ModifierOptimalChargeWindowSize' ) ] ),
            infobox:renderItem( translate( 'LBL_ModifierInertMaterials' ), smwData[ translate( 'SMW_ModifierInertMaterials' ) ] ),
            infobox:renderItem( translate( 'LBL_ModifierOptimalChargeRate' ), smwData[ translate( 'SMW_ModifierOptimalChargeRate' ) ] ),
            infobox:renderItem( translate( 'LBL_ModifierResistance' ), smwData[ translate( 'SMW_ModifierResistance' ) ] ),
            --infobox:renderItem( translate( 'LBL_ModifierShatterDamage' ), smwData[ translate( 'SMW_ModifierShatterDamage' ) ] ),
            infobox:renderItem( translate( 'LBL_ModifierSize' ), smwData[ translate( 'SMW_ModifierSize' ) ] )
        }
        tabberData[ 'content2' ] = infobox:renderSection( { content = section, col = 2 }, true )
    -- Mining Module
    elseif smwData[ translate( 'SMW_Type' ) ] == 'MiningModifier.Gun' then
        -- Overview
        tabberData[ 'label1' ] = translate( 'LBL_Overview' )
        section = {
            infobox:renderItem( translate( 'LBL_Uses' ), smwData[ translate( 'SMW_Uses' ) ] ),
            infobox:renderItem( translate( 'LBL_Duration' ), smwData[ translate( 'SMW_Duration' ) ] ),
            infobox:renderItem( translate( 'LBL_ModifierCatastrophicChargeRate' ), smwData[ translate( 'SMW_ModifierCatastrophicChargeRate' ) ] ),
            infobox:renderItem( translate( 'LBL_ModifierExtractionLaserPower' ), smwData[ translate( 'SMW_ModifierExtractionLaserPower' ) ] ),
            infobox:renderItem( translate( 'LBL_ModifierLaserInstability' ), smwData[ translate( 'SMW_ModifierLaserInstability' ) ] ),
            infobox:renderItem( translate( 'LBL_ModifierMiningLaserPower' ), smwData[ translate( 'SMW_ModifierMiningLaserPower' ) ] ),
            infobox:renderItem( translate( 'LBL_ModifierOptimalChargeWindowSize' ), smwData[ translate( 'SMW_ModifierOptimalChargeWindowSize' ) ] ),
            infobox:renderItem( translate( 'LBL_ModifierInertMaterials' ), smwData[ translate( 'SMW_ModifierInertMaterials' ) ] ),
            infobox:renderItem( translate( 'LBL_ModifierOptimalChargeRate' ), smwData[ translate( 'SMW_ModifierOptimalChargeRate' ) ] ),
            infobox:renderItem( translate( 'LBL_ModifierResistance' ), smwData[ translate( 'SMW_ModifierResistance' ) ] ),
            infobox:renderItem( translate( 'LBL_ModifierShatterDamage' ), smwData[ translate( 'SMW_ModifierShatterDamage' ) ] ),
            infobox:renderItem( translate( 'LBL_ModifierSize' ), smwData[ translate( 'SMW_ModifierSize' ) ] )
        }
        tabberData[ 'content1' ] = infobox:renderSection( { content = section, col = 2 }, true )
    -- Power Plant
    elseif smwData[ translate( 'SMW_Type' ) ] == 'PowerPlant.Power' then
        -- Overview
        tabberData[ 'label1' ] = translate( 'LBL_Overview' )
        section = {
            infobox:renderItem( translate( 'LBL_PowerOutput' ), smwData[ translate( 'SMW_PowerOutput' ) ] )
        }
        tabberData[ 'content1' ] = infobox:renderSection( { content = section, col = 2 }, true )
    -- Quantum Drive
    elseif smwData[ translate( 'SMW_Type' ) ] == 'QuantumDrive' then
        local function getQuantumDriveModesSection()
            local modes = loadSubobjects( 
                itemPageIdentifier,
                'SMW_QuantumTravelType',
                {
                    'SMW_QuantumTravelType',
                    'SMW_QuantumTravelSpeed',
                    'SMW_CooldownTime',
                    'SMW_ChargeTime'
                }
            )

            if type( modes ) == 'table' then
                local modeTabberData = {}
                local modeCount = 1

                for _, mode in ipairs( modes ) do
                    modeTabberData[ 'label' .. modeCount ] = translate( mode[ translate( 'SMW_QuantumTravelType' ) ] )
                    section = {
                        infobox:renderItem( translate( 'LBL_QuantumTravelSpeed' ), mode[ translate( 'SMW_QuantumTravelSpeed' ) ] ),
                        infobox:renderItem( translate( 'LBL_CooldownTime' ), mode[ translate( 'SMW_CooldownTime' ) ] ),
                        infobox:renderItem( translate( 'LBL_ChargeTime' ), mode[ translate( 'SMW_ChargeTime' ) ] )
                    }
                    modeTabberData[ 'content' .. modeCount ] = infobox:renderSection( { content = section, col = 3 }, true )
                    modeCount = modeCount + 1
                end

                return infobox:renderSection( {
                    title = translate( 'LBL_Modes' ),
                    class = 'infobox__section--tabber',
                    content = tabber( modeTabberData ),
                    border = false
                }, true )
            end
        end

        -- Overview
        tabberData[ 'label1' ] = translate( 'LBL_Overview' )
        section = {
            infobox:renderItem( translate( 'LBL_QuantumFuelRequirement' ), smwData[ translate( 'SMW_QuantumFuelRequirement' ) ] ),
            infobox:renderItem( translate( 'LBL_QuantumTravelDisconnectRange' ), smwData[ translate( 'SMW_QuantumTravelDisconnectRange' ) ] )
            -- Does range matter currently? The range seems to be limited by the QF fuel tank of the vehicle anyways
            --infobox:renderItem( translate( 'LBL_QuantumTravelRange' ), smwData[ translate( 'SMW_QuantumTravelRange' ) ] )
        }
        tabberData[ 'content1' ] = infobox:renderSection( { content = section, col = 2 }, true ) .. getQuantumDriveModesSection()
    -- Quantum Enforcement Device
    elseif smwData[ translate( 'SMW_Type' ) ] == 'QuantumInterdictionGenerator' then
        -- Overview
        tabberData[ 'label1' ] = translate( 'LBL_Overview' )
        section = {
            infobox:renderItem( translate( 'LBL_JammerRange' ), smwData[ translate( 'SMW_JammerRange' ) ] ),
            infobox:renderItem( translate( 'LBL_InterdictionRange' ), smwData[ translate( 'SMW_InterdictionRange' ) ] ),
            infobox:renderItem( translate( 'LBL_Duration' ), smwData[ translate( 'SMW_Duration' ) ] ),
            infobox:renderItem( translate( 'LBL_ChargeTime' ), smwData[ translate( 'SMW_ChargeTime' ) ] ),
            infobox:renderItem( translate( 'LBL_CooldownTime' ), smwData[ translate( 'SMW_CooldownTime' ) ] )
        }
        tabberData[ 'content1' ] = infobox:renderSection( { content = section, col = 2 }, true )
    -- Scraper Module
    elseif smwData[ translate( 'SMW_Type' ) ] == 'SalvageModifier' or smwData[ translate( 'SMW_Type' ) ] == 'SalvageModifier.SalvageModifier_TractorBeam' then
        -- Modifier
        tabberData[ 'label1' ] = translate( 'LBL_Overview' )
        section = {
            infobox:renderItem( translate( 'LBL_ModifierSalvageSpeed' ), infobox.addUnitIfExists( smwData[ translate( 'SMW_ModifierSalvageSpeed' ) ], 'x' ) ),
            infobox:renderItem( translate( 'LBL_ModifierRadius' ), infobox.addUnitIfExists( smwData[ translate( 'SMW_ModifierRadius' ) ], 'x' ) ),
            infobox:renderItem( translate( 'LBL_ModifierExtractionEfficiency' ), infobox.addUnitIfExists( smwData[ translate( 'SMW_ModifierExtractionEfficiency' ) ], 'x' ) )
        }
        tabberData[ 'content1' ] = infobox:renderSection( { content = section, col = 3 }, true )
    -- Shield
    elseif smwData[ translate( 'SMW_Type' ) ] == 'Shield' then
        -- We need raw number from SMW to calculate shield regen, so we add the unit back
        local function getShieldPoint()
            if smwData[ translate( 'SMW_ShieldHealthPoint' ) ] == nil then return end
            return common.formatNum( math.ceil( smwData[ translate( 'SMW_ShieldHealthPoint' ) ] ) ) .. ' 🛡️'
        end

        local function getShieldRegen()
            if smwData[ translate( 'SMW_ShieldPointRegeneration' ) ] == nil then return end
            if smwData[ translate( 'SMW_ShieldHealthPoint' ) ] == nil then return smwData[ translate( 'SMW_ShieldPointRegeneration' ) ] end

            local fullChargeTime = math.ceil( smwData[ translate( 'SMW_ShieldHealthPoint' ) ] / smwData[ translate( 'SMW_ShieldPointRegeneration' ) ] )

            return infobox.showDescIfDiff(
                common.formatNum( math.ceil( smwData[ translate( 'SMW_ShieldPointRegeneration' ) ] ) ) .. ' 🛡️/s',
                translate( 'unit_secondtillfull', false, fullChargeTime )
            )
        end

        local function getShieldRegenDelay()
            if smwData[ translate( 'SMW_ShieldDownTime' ) ] == nil or smwData[ translate( 'SMW_ShieldDamageDelay' ) ] == nil then return end
            return infobox.showDescIfDiff(
                smwData[ translate( 'SMW_ShieldDamageDelay' ) ],
                translate( 'unit_whendown', false, smwData[ translate( 'SMW_ShieldDownTime' ) ] )
            )
        end

        -- Overview
        tabberData[ 'label1' ] = translate( 'LBL_Overview' )
        section = {
            infobox:renderItem( translate( 'LBL_ShieldHealthPoint' ), getShieldPoint() ),
            infobox:renderItem( translate( 'LBL_ShieldPointRegeneration' ), getShieldRegen() ),
            infobox:renderItem( translate( 'LBL_ShieldRegenDelay' ), getShieldRegenDelay() )
        }
        tabberData[ 'content1' ] = infobox:renderSection( { content = section, col = 2 }, true )

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
    -- Tractor beam
    -- TODO: Maybe we should use SMW_Type for all the stuff above
    elseif smwData[ translate( 'SMW_Type' ) ] == 'TractorBeam' then
        -- Overview
        tabberData[ 'label1' ] = translate( 'LBL_Overview' )
        section = {
            infobox:renderItem( translate( 'LBL_MaximumForce' ), smwData[ translate( 'SMW_MaximumForce' ) ] ),
            infobox:renderItem( translate( 'LBL_OptimalRange' ), smwData[ translate( 'SMW_OptimalRange' ) ] ),
            infobox:renderItem( translate( 'LBL_MaximumRange' ), smwData[ translate( 'SMW_MaximumRange' ) ] ),
            infobox:renderItem( translate( 'LBL_MaximumAngle' ), smwData[ translate( 'SMW_MaximumAngle' ) ] ),
            infobox:renderItem( translate( 'LBL_MaximumVolume' ), smwData[ translate( 'SMW_MaximumVolume' ) ] )
        }
        tabberData[ 'content1' ] = infobox:renderSection( { content = section, col = 2 }, true )
    end

    -- Get the index of the last tab
    local tabCount = 0
    for _, __ in pairs( tabberData ) do
        tabCount = tabCount + 1
    end
    tabCount = tabCount / 2

    -- Engineering
    -- TODO: Make temperatures into a graph?
    -- FIXME: Instead of hardcoding the unit, can we use SMW query to get the unit?
    tabCount = tabCount + 1
    tabberData[ 'label' .. tabCount ] = translate( 'LBL_Engineering' )
    section = {
        infobox:renderItem( translate( 'LBL_PowerDraw' ), infobox.addUnitIfExists( infobox.formatRange( smwData[ translate( 'SMW_MinimumPowerDraw' ) ], smwData[ translate( 'SMW_MaximumPowerDraw' ) ], true ), '⚡/s' ) ),
        infobox:renderItem( translate( 'LBL_ThermalEnergyOutput' ), infobox.addUnitIfExists( infobox.formatRange( smwData[ translate( 'SMW_MinimumThermalEnergyOutput' ) ], smwData[ translate( 'SMW_MaximumThermalEnergyOutput' ) ], true ), '🌡️/s' ) ),
        infobox:renderItem( translate( 'LBL_MaximumCoolingRate' ), smwData[ translate( 'SMW_MaximumCoolingRate' ) ] ),
        infobox:renderItem( translate( 'LBL_StartCoolingTemperature' ), smwData[ translate( 'SMW_StartCoolingTemperature' ) ] ),
        infobox:renderItem( translate( 'LBL_Temperature' ), infobox.addUnitIfExists( infobox.formatRange( smwData[ translate( 'SMW_MinimumTemperature' ) ], smwData[ translate( 'SMW_MaximumTemperature' ) ], true ), '°C' ) ),
        infobox:renderItem( translate( 'LBL_MisfireTemperature' ), infobox.addUnitIfExists( infobox.formatRange( smwData[ translate( 'SMW_MinimumMisfireTemperature' ) ], smwData[ translate( 'SMW_MaximumMisfireTemperature' ) ], true ), '°C' ) ),
        infobox:renderItem( translate( 'LBL_OverheatTemperature' ), smwData[ translate( 'SMW_OverheatTemperature' ) ] )
    }
    tabberData[ 'content' .. tabCount ] = infobox:renderSection( { content = section, col = 2 }, true )

    -- Emission
    local function getMaxIR()
        if smwData[ translate( 'SMW_IRTemperatureThreshold' ) ] == nil or smwData[ translate( 'SMW_TemperatureToIR' ) ] == nil and smwData[ translate( 'SMW_MinimumIR' ) ] == nil then return end
        return smwData[ translate( 'SMW_IRTemperatureThreshold' ) ] * smwData[ translate( 'SMW_TemperatureToIR' ) ] + smwData[ translate( 'SMW_MinimumIR' ) ]
    end

    tabCount = tabCount + 1
    tabberData[ 'label' .. tabCount ] = translate( 'LBL_Emission' )
    section = {
        infobox:renderItem( translate( 'LBL_EM' ), infobox.formatRange( smwData[ translate( 'SMW_MinimumEM' ) ], smwData[ translate( 'SMW_MaximumEM' ) ], true ) ),
        infobox:renderItem( translate( 'LBL_PowerToEM' ), smwData[ translate( 'SMW_PowerToEM' ) ] ),
        infobox:renderItem( translate( 'LBL_EMDecayRate' ), smwData[ translate( 'SMW_EMDecayRate' ) ] ),
        infobox:renderItem( translate( 'LBL_IR' ), infobox.formatRange( smwData[ translate( 'SMW_MinimumIR' ) ], getMaxIR(), true ) ),
        infobox:renderItem( translate( 'LBL_TemperatureToIR' ), smwData[ translate( 'SMW_TemperatureToIR' ) ] )
    }
    tabberData[ 'content' .. tabCount ] = infobox:renderSection( { content = section, col = 3 }, true )

    -- Defense
    tabCount = tabCount + 1
    tabberData[ 'label' .. tabCount ] = translate( 'LBL_Defense' )
    section = {
        infobox:renderItem( translate( 'LBL_Health' ), smwData[ translate( 'SMW_HealthPoint' ) ] ),
        infobox:renderItem( translate( 'LBL_DistortionHealthPoint' ), smwData[ translate( 'SMW_DistortionHealthPoint' ) ] ),
        infobox:renderItem( translate( 'LBL_DistortionDecayRate' ), smwData[ translate( 'SMW_DistortionDecayRate' ) ] ),
        infobox:renderItem( translate( 'LBL_DistortionDecayDelay' ), smwData[ translate( 'SMW_DistortionDecayDelay' ) ] )
    }
    tabberData[ 'content' .. tabCount ] = infobox:renderSection( { content = section, col = 2 }, true )

    -- Dimensions
    --tabberData[ 'label' .. tabCount ] = translate( 'LBL_Dimensions' )
    --section = {
    --    infobox:renderItem( {
    --        label = translate( 'LBL_Length' ),
    --        data = smwData[ translate( 'SMW_EntityLength' ) ],
    --    } ),
    --    infobox:renderItem( {
    --        label = translate( 'LBL_Width' ),
    --        data = smwData[ translate( 'SMW_EntityWidth' ) ],
    --    } ),
    --    infobox:renderItem( {
    --        label = translate( 'LBL_Height' ),
    --        data = smwData[ translate( 'SMW_EntityHeight' ) ],
    --    } ),
    --    infobox:renderItem( {
    --        label = translate( 'LBL_Mass' ),
    --        data = smwData[ translate( 'SMW_Mass' ) ],
    --    } )
    --}
    --tabberData[ 'content' .. tabCount ] = infobox:renderSection( { content = section, col = 3 }, true )

    infobox:renderSection( {
		class = 'infobox__section--tabber',
		content = tabber( tabberData ),
        border = false
	} )
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
