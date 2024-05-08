require( 'strict' )

local p = {}

local MODULE_NAME = 'VehicleItem'

local i18n = require( 'Module:i18n' ):new()
local TNT = require( 'Module:Translate' ):new()
local smwCommon = require( 'Module:Common/SMW' )
local data = mw.loadJsonData( 'Module:Item/' .. MODULE_NAME .. '/data.json' )
local config = mw.loadJsonData( 'Module:Item/config.json' )

local common = require( 'Module:Common' )


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

    local formatConfig = {
        type = 'number'
    }

    -- TODO: Modifiers and Damages are generic enough that maybe we should search for it by default on Module:Item?
    smwCommon.setFromTable( smwSetObject, apiData:get( 'mining_laser.modifiers' ), 'display_name', 'value', 'Modifier',
        translate, formatConfig )
    smwCommon.setFromTable( smwSetObject, apiData:get( 'mining_module.modifiers' ), 'display_name', 'value', 'Modifier',
        translate, formatConfig )
    smwCommon.setFromTable( smwSetObject, apiData:get( 'bomb.damages' ), 'name', 'damage', 'Damage', translate, formatConfig )
    smwCommon.setFromTable( smwSetObject, apiData:get( 'missile.damages' ), 'name', 'damage', 'Damage', translate,
        formatConfig )

    -- TODO: Implement this for bombs and missiles
    if apiData.vehicle_weapon then
        -- Save damages as subobjects, we did not do it through data.json because we need to build the key
        -- for the damage SMW properties such as SMW_DamageEnergy
        -- TODO: This is generic enough that we should consider making it shared for bombs, missile, personal weapon, and vehicle weapons
        if apiData.vehicle_weapon.damages then
            local ucfirst = require( 'Module:String2' ).ucfirst
            local damages = apiData.vehicle_weapon.damages

            local typeKey = t( 'SMW_DamageType' )

            local subobjects = {}
            for _, damage in ipairs( damages ) do
                -- FIXME: Wikipedia modules like Module:String2 does not have a proper Lua entry point
                -- Perhaps we should look into it some day
                local ucfirstArgs = { args = { damage.name } }
                local dmgKey = t( 'SMW_Damage' .. ucfirst( ucfirstArgs ) )

                -- If damage type is the same, add the damage value of the under the same table
                if subobjects[ #subobjects ] and subobjects[ #subobjects ][ typeKey ] and subobjects[ #subobjects ][ typeKey ] == damage.type then
                    subobjects[ #subobjects ][ dmgKey ] = damage.damage
                else
                    table.insert( subobjects, {
                        [ typeKey ] = damage.type,
                        [ dmgKey ] = damage.damage
                    } )
                end
            end

            for _, subobject in pairs( subobjects ) do
                mw.smw.subobject( subobject )
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
function p.addInfoboxData( infobox, smwData, itemPageIdentifier )
    local tabber = require( 'Module:Tabber' ).renderTabber
    local tabberData = {}
    local section


    local function getDamagesSection()
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
            local damagesTabberData = {}
            local damagesTabCount = 1

            for _, damage in ipairs( subobjects ) do
                section = {}
                damagesTabberData[ 'label' .. damagesTabCount ] = translate( 'damagetype_' ..
                    damage[ t( 'SMW_DamageType' ) ] )
                for _, damageType in ipairs( damageTypes ) do
                    table.insert( section,
                        infobox:renderItem( {
                            label = translate( 'LBL_Damage' .. damageType ),
                            tooltip = t( 'SMW_Damage' .. damageType ),
                            data = damage[ t( 'SMW_Damage' .. damageType ) ]
                        } )
                    )
                end
                damagesTabberData[ 'content' .. damagesTabCount ] = infobox:renderSection( { content = section, col = 3 },
                    true )
                damagesTabCount = damagesTabCount + 1
            end

            return infobox:renderSection( {
                title = translate( 'LBL_Damages' ),
                class = 'infobox__section--tabber',
                content = tabber( damagesTabberData ),
                border = false
            }, true )
        end
    end

    -- Bomb
    if smwData[ t( 'SMW_Type' ) ] == 'Bomb' then
        -- Overview
        tabberData[ 'label1' ] = translate( 'LBL_Overview' )
        section = {
            infobox:renderItem( translate( 'LBL_DamagePhysical' ), smwData[ t( 'SMW_DamagePhysical' ) ] ),
            infobox:renderItem( translate( 'LBL_DamageEnergy' ), smwData[ t( 'SMW_DamageEnergy' ) ] ),
            infobox:renderItem( translate( 'LBL_ExplosionRadius' ),
                infobox.addUnitIfExists(
                    infobox.formatRange( smwData[ t( 'SMW_MinimumExplosionRadius' ) ],
                        smwData[ t( 'SMW_MaximumExplosionRadius' ) ], true ), 'm' ) ),
            infobox:renderItem( translate( 'LBL_ArmTime' ), smwData[ t( 'SMW_ArmTime' ) ] ),
            infobox:renderItem( translate( 'LBL_IgniteTime' ), smwData[ t( 'SMW_IgniteTime' ) ] )
        }
        tabberData[ 'content1' ] = infobox:renderSection( { content = section, col = 2 }, true )
        -- Cooler
    elseif smwData[ t( 'SMW_Type' ) ] == 'Cooler' then
        -- Overview
        tabberData[ 'label1' ] = translate( 'LBL_Overview' )
        section = {
            infobox:renderItem( translate( 'LBL_CoolingRate' ), smwData[ t( 'SMW_CoolingRate' ) ] )
        }
        tabberData[ 'content1' ] = infobox:renderSection( { content = section, col = 2 }, true )
        -- EMP Generator
    elseif smwData[ t( 'SMW_Type' ) ] == 'EMP' then
        -- Overview
        tabberData[ 'label1' ] = translate( 'LBL_Overview' )
        section = {
            infobox:renderItem( translate( 'LBL_EMPRadius' ), smwData[ t( 'SMW_EMPRadius' ) ] ),
            infobox:renderItem( translate( 'LBL_ChargeTime' ), smwData[ t( 'SMW_ChargeTime' ) ] ),
            infobox:renderItem( translate( 'LBL_CooldownTime' ), smwData[ t( 'SMW_CooldownTime' ) ] ),
            infobox:renderItem( translate( 'LBL_Duration' ), smwData[ t( 'SMW_Duration' ) ] )
        }
        tabberData[ 'content1' ] = infobox:renderSection( { content = section, col = 2 }, true )
        -- Fuel Pod
    elseif smwData[ t( 'SMW_Type' ) ] == 'ExternalFuelTank' then
        -- Overview
        tabberData[ 'label1' ] = translate( 'LBL_Overview' )
        section = {
            infobox:renderItem( translate( 'LBL_FuelCapacity' ), smwData[ t( 'SMW_FuelCapacity' ) ] ),
            infobox:renderItem( translate( 'LBL_FuelFillRate' ), smwData[ t( 'SMW_FuelFillRate' ) ] ),
            infobox:renderItem( translate( 'LBL_FuelDrainRate' ), smwData[ t( 'SMW_FuelDrainRate' ) ] )
        }
        tabberData[ 'content1' ] = infobox:renderSection( { content = section, col = 2 }, true )
        -- Gun / Rocket Pod
    elseif smwData[ t( 'SMW_Type' ) ] == 'WeaponGun.Gun' or smwData[ t( 'SMW_Type' ) ] == 'WeaponGun.Rocket' then
        local function getFiringModesSection()
            local modes = smwCommon.loadSubobjects(
                itemPageIdentifier,
                'SMW_FiringMode',
                {
                    'SMW_FiringMode',
                    'SMW_FiringRate',
                    'SMW_AmmoPerShot',
                    'SMW_ProjectilePerShot',
                    'SMW_DamagePerSecond'
                },
                translate
            )

            if type( modes ) == 'table' then
                local modeTabberData = {}
                local modeCount = 1

                for _, mode in ipairs( modes ) do
                    modeTabberData[ 'label' .. modeCount ] = translate( mode[ t( 'SMW_FiringMode' ) ] )
                    section = {
                        infobox:renderItem( translate( 'LBL_DamagePerSecond' ),
                            mode[ t( 'SMW_DamagePerSecond' ) ] ),
                        infobox:renderItem( translate( 'LBL_FiringRate' ), mode[ t( 'SMW_FiringRate' ) ] ),
                        infobox:renderItem( translate( 'LBL_ProjectilePerShot' ),
                            mode[ t( 'SMW_ProjectilePerShot' ) ] ),
                        infobox:renderItem( translate( 'LBL_AmmoPerShot' ), mode[ t( 'SMW_AmmoPerShot' ) ] )
                    }
                    modeTabberData[ 'content' .. modeCount ] = infobox:renderSection( { content = section, col = 2 },
                        true )
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
            infobox:renderItem( translate( 'LBL_Damage' ), smwData[ t( 'SMW_Damage' ) ] ),
            infobox:renderItem( translate( 'LBL_AmmoSpeed' ), smwData[ t( 'SMW_AmmoSpeed' ) ] ),
            infobox:renderItem( translate( 'LBL_MaximumRange' ), smwData[ t( 'SMW_MaximumRange' ) ] ),
            infobox:renderItem( translate( 'LBL_Ammo' ), smwData[ t( 'SMW_Ammo' ) ] )
        }
        tabberData[ 'content1' ] = infobox:renderSection( { content = section, col = 2 }, true ) ..
            getDamagesSection() .. getFiringModesSection()
        -- Missile
    elseif smwData[ t( 'SMW_Type' ) ] == 'Missile.Missile' or smwData[ t( 'SMW_Type' ) ] == 'Missile.Torpedo' then
        -- Overview
        tabberData[ 'label1' ] = translate( 'LBL_Overview' )
        section = {
            infobox:renderItem( translate( 'LBL_DamagePhysical' ), smwData[ t( 'SMW_DamagePhysical' ) ] ),
            infobox:renderItem( translate( 'LBL_DamageEnergy' ), smwData[ t( 'SMW_DamageEnergy' ) ] ),
            infobox:renderItem( translate( 'LBL_SignalType' ), smwData[ t( 'SMW_SignalType' ) ] ),
            infobox:renderItem( translate( 'LBL_LockTime' ), smwData[ t( 'SMW_LockTime' ) ] )
        }
        tabberData[ 'content1' ] = infobox:renderSection( { content = section, col = 2 }, true )
        -- Missile launcher / Weapon mount
        -- FIXME: Maybe refactor the type check to a local function?
    elseif smwData[ t( 'SMW_Type' ) ] == 'MissileLauncher.MissileRack' or smwData[ t( 'SMW_Type' ) ] == 'Turret.GunTurret' or smwData[ t( 'SMW_Type' ) ] == 'Turret.BallTurret' or smwData[ t( 'SMW_Type' ) ] == 'Turret.CanardTurret' or smwData[ t( 'SMW_Type' ) ] == 'Turret.NoseMounted' then
        --- NOTE: Should we just set the size SMW property to type:quantity, then prefix the S as a unit?
        local function getPortSize()
            if smwData[ t( 'SMW_PortSize' ) ] == nil then return end
            return 'S' .. smwData[ t( 'SMW_PortSize' ) ]
        end

        -- Overview
        tabberData[ 'label1' ] = translate( 'LBL_Overview' )
        section = {
            infobox:renderItem( translate( 'LBL_PortCount' ), smwData[ t( 'SMW_PortCount' ) ] ),
            infobox:renderItem( translate( 'LBL_PortSize' ), getPortSize() )
        }
        tabberData[ 'content1' ] = infobox:renderSection( { content = section, col = 2 }, true )
        -- Mining Laser
    elseif smwData[ t( 'SMW_Type' ) ] == 'WeaponMining.Gun' then
        -- Overview
        tabberData[ 'label1' ] = translate( 'LBL_Overview' )
        section = {
            infobox:renderItem( translate( 'LBL_MiningLaserPower' ), smwData[ t( 'SMW_MiningLaserPower' ) ] ),
            infobox:renderItem( translate( 'LBL_ExtractionLaserPower' ),
                smwData[ t( 'SMW_ExtractionLaserPower' ) ] ),
            infobox:renderItem( translate( 'LBL_OptimalRange' ), smwData[ t( 'SMW_OptimalRange' ) ] ),
            infobox:renderItem( translate( 'LBL_MaximumRange' ), smwData[ t( 'SMW_MaximumRange' ) ] ),
            infobox:renderItem( translate( 'LBL_ExtractionThroughput' ),
                smwData[ t( 'SMW_ExtractionThroughput' ) ] ),
            infobox:renderItem( translate( 'LBL_ModuleSlots' ), smwData[ t( 'SMW_ModuleSlots' ) ] )
        }
        tabberData[ 'content1' ] = infobox:renderSection( { content = section, col = 2 }, true )

        tabberData[ 'label2' ] = translate( 'LBL_Modifiers' )
        section = {
            infobox:renderItem( translate( 'LBL_ModifierCatastrophicChargeRate' ),
                smwData[ t( 'SMW_ModifierCatastrophicChargeRate' ) ] ),
            --infobox:renderItem( translate( 'LBL_ModifierExtractionLaserPower' ), smwData[ t( 'SMW_ModifierExtractionLaserPower' ) ] ),
            infobox:renderItem( translate( 'LBL_ModifierLaserInstability' ),
                smwData[ t( 'SMW_ModifierLaserInstability' ) ] ),
            --infobox:renderItem( translate( 'LBL_ModifierMiningLaserPower' ), smwData[ t( 'SMW_ModifierMiningLaserPower' ) ] ),
            --infobox:renderItem( translate( 'LBL_ModifierOptimalChargeWindowSize' ), smwData[ t( 'SMW_ModifierOptimalChargeWindowSize' ) ] ),
            infobox:renderItem( translate( 'LBL_ModifierInertMaterials' ),
                smwData[ t( 'SMW_ModifierInertMaterials' ) ] ),
            infobox:renderItem( translate( 'LBL_ModifierOptimalChargeRate' ),
                smwData[ t( 'SMW_ModifierOptimalChargeRate' ) ] ),
            infobox:renderItem( translate( 'LBL_ModifierResistance' ), smwData[ t( 'SMW_ModifierResistance' ) ] ),
            --infobox:renderItem( translate( 'LBL_ModifierShatterDamage' ), smwData[ t( 'SMW_ModifierShatterDamage' ) ] ),
            infobox:renderItem( translate( 'LBL_ModifierSize' ), smwData[ t( 'SMW_ModifierSize' ) ] )
        }
        tabberData[ 'content2' ] = infobox:renderSection( { content = section, col = 2 }, true )
        -- Mining Module
    elseif smwData[ t( 'SMW_Type' ) ] == 'MiningModifier.Gun' then
        -- Overview
        tabberData[ 'label1' ] = translate( 'LBL_Overview' )
        section = {
            infobox:renderItem( translate( 'LBL_Uses' ), smwData[ t( 'SMW_Uses' ) ] ),
            infobox:renderItem( translate( 'LBL_Duration' ), smwData[ t( 'SMW_Duration' ) ] ),
            infobox:renderItem( translate( 'LBL_ModifierCatastrophicChargeRate' ),
                smwData[ t( 'SMW_ModifierCatastrophicChargeRate' ) ] ),
            infobox:renderItem( translate( 'LBL_ModifierExtractionLaserPower' ),
                smwData[ t( 'SMW_ModifierExtractionLaserPower' ) ] ),
            infobox:renderItem( translate( 'LBL_ModifierLaserInstability' ),
                smwData[ t( 'SMW_ModifierLaserInstability' ) ] ),
            infobox:renderItem( translate( 'LBL_ModifierMiningLaserPower' ),
                smwData[ t( 'SMW_ModifierMiningLaserPower' ) ] ),
            infobox:renderItem( translate( 'LBL_ModifierOptimalChargeWindowSize' ),
                smwData[ t( 'SMW_ModifierOptimalChargeWindowSize' ) ] ),
            infobox:renderItem( translate( 'LBL_ModifierInertMaterials' ),
                smwData[ t( 'SMW_ModifierInertMaterials' ) ] ),
            infobox:renderItem( translate( 'LBL_ModifierOptimalChargeRate' ),
                smwData[ t( 'SMW_ModifierOptimalChargeRate' ) ] ),
            infobox:renderItem( translate( 'LBL_ModifierResistance' ), smwData[ t( 'SMW_ModifierResistance' ) ] ),
            infobox:renderItem( translate( 'LBL_ModifierShatterDamage' ),
                smwData[ t( 'SMW_ModifierShatterDamage' ) ] ),
            infobox:renderItem( translate( 'LBL_ModifierSize' ), smwData[ t( 'SMW_ModifierSize' ) ] )
        }
        tabberData[ 'content1' ] = infobox:renderSection( { content = section, col = 2 }, true )
        -- Power Plant
    elseif smwData[ t( 'SMW_Type' ) ] == 'PowerPlant.Power' then
        -- Overview
        tabberData[ 'label1' ] = translate( 'LBL_Overview' )
        section = {
            infobox:renderItem( translate( 'LBL_PowerOutput' ), smwData[ t( 'SMW_PowerOutput' ) ] )
        }
        tabberData[ 'content1' ] = infobox:renderSection( { content = section, col = 2 }, true )
        -- Quantum Drive
    elseif smwData[ t( 'SMW_Type' ) ] == 'QuantumDrive' then
        local function getQuantumDriveModesSection()
            local modes = smwCommon.loadSubobjects(
                itemPageIdentifier,
                'SMW_QuantumTravelType',
                {
                    'SMW_QuantumTravelType',
                    'SMW_QuantumTravelSpeed',
                    'SMW_CooldownTime',
                    'SMW_ChargeTime'
                },
                translate
            )

            if type( modes ) == 'table' then
                local modeTabberData = {}
                local modeCount = 1

                for _, mode in ipairs( modes ) do
                    modeTabberData[ 'label' .. modeCount ] = translate( mode[ t( 'SMW_QuantumTravelType' ) ] )
                    section = {
                        infobox:renderItem( translate( 'LBL_QuantumTravelSpeed' ),
                            mode[ t( 'SMW_QuantumTravelSpeed' ) ] ),
                        infobox:renderItem( translate( 'LBL_CooldownTime' ), mode[ t( 'SMW_CooldownTime' ) ] ),
                        infobox:renderItem( translate( 'LBL_ChargeTime' ), mode[ t( 'SMW_ChargeTime' ) ] )
                    }
                    modeTabberData[ 'content' .. modeCount ] = infobox:renderSection( { content = section, col = 3 },
                        true )
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
            infobox:renderItem( translate( 'LBL_QuantumFuelRequirement' ),
                smwData[ t( 'SMW_QuantumFuelRequirement' ) ] ),
            infobox:renderItem( translate( 'LBL_QuantumTravelDisconnectRange' ),
                smwData[ t( 'SMW_QuantumTravelDisconnectRange' ) ] )
            -- Does range matter currently? The range seems to be limited by the QF fuel tank of the vehicle anyways
            --infobox:renderItem( translate( 'LBL_QuantumTravelRange' ), smwData[ t( 'SMW_QuantumTravelRange' ) ] )
        }
        tabberData[ 'content1' ] = infobox:renderSection( { content = section, col = 2 }, true ) ..
            getQuantumDriveModesSection()
        -- Quantum Enforcement Device
    elseif smwData[ t( 'SMW_Type' ) ] == 'QuantumInterdictionGenerator' then
        -- Overview
        tabberData[ 'label1' ] = translate( 'LBL_Overview' )
        section = {
            infobox:renderItem( translate( 'LBL_JammerRange' ), smwData[ t( 'SMW_JammerRange' ) ] ),
            infobox:renderItem( translate( 'LBL_InterdictionRange' ), smwData[ t( 'SMW_InterdictionRange' ) ] ),
            infobox:renderItem( translate( 'LBL_Duration' ), smwData[ t( 'SMW_Duration' ) ] ),
            infobox:renderItem( translate( 'LBL_ChargeTime' ), smwData[ t( 'SMW_ChargeTime' ) ] ),
            infobox:renderItem( translate( 'LBL_CooldownTime' ), smwData[ t( 'SMW_CooldownTime' ) ] )
        }
        tabberData[ 'content1' ] = infobox:renderSection( { content = section, col = 2 }, true )
        -- Scraper Module
    elseif smwData[ t( 'SMW_Type' ) ] == 'SalvageModifier' or smwData[ t( 'SMW_Type' ) ] == 'SalvageModifier.SalvageModifier_TractorBeam' then
        -- Modifier
        tabberData[ 'label1' ] = translate( 'LBL_Overview' )
        section = {
            infobox:renderItem( translate( 'LBL_ModifierSalvageSpeed' ),
                infobox.addUnitIfExists( smwData[ t( 'SMW_ModifierSalvageSpeed' ) ], 'x' ) ),
            infobox:renderItem( translate( 'LBL_ModifierRadius' ),
                infobox.addUnitIfExists( smwData[ t( 'SMW_ModifierRadius' ) ], 'x' ) ),
            infobox:renderItem( translate( 'LBL_ModifierExtractionEfficiency' ),
                infobox.addUnitIfExists( smwData[ t( 'SMW_ModifierExtractionEfficiency' ) ], 'x' ) )
        }
        tabberData[ 'content1' ] = infobox:renderSection( { content = section, col = 3 }, true )
        -- Shield
    elseif smwData[ t( 'SMW_Type' ) ] == 'Shield' then
        -- We need raw number from SMW to calculate shield regen, so we add the unit back
        local function getShieldPoint()
            if smwData[ t( 'SMW_ShieldHealthPoint' ) ] == nil then return end
            return common.formatNum( math.ceil( smwData[ t( 'SMW_ShieldHealthPoint' ) ] ) ) .. ' 🛡️'
        end

        local function getShieldRegen()
            if smwData[ t( 'SMW_ShieldPointRegeneration' ) ] == nil then return end
            if smwData[ t( 'SMW_ShieldHealthPoint' ) ] == nil then
                return smwData
                    [ t( 'SMW_ShieldPointRegeneration' ) ]
            end

            local fullChargeTime = math.ceil( smwData[ t( 'SMW_ShieldHealthPoint' ) ] /
                smwData[ t( 'SMW_ShieldPointRegeneration' ) ] )

            return infobox.showDescIfDiff(
                common.formatNum( math.ceil( smwData[ t( 'SMW_ShieldPointRegeneration' ) ] ) ) .. ' 🛡️/s',
                translate( 'unit_secondtillfull', false, fullChargeTime )
            )
        end

        local function getShieldRegenDelay()
            if smwData[ t( 'SMW_ShieldDownTime' ) ] == nil or smwData[ t( 'SMW_ShieldDamageDelay' ) ] == nil then return end
            return infobox.showDescIfDiff(
                smwData[ t( 'SMW_ShieldDamageDelay' ) ],
                translate( 'unit_whendown', false, smwData[ t( 'SMW_ShieldDownTime' ) ] )
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
        --        infobox:renderItem( translate( 'LBL_ShieldPhysicalResistance' ), smwData[ t( 'SMW_ShieldPhysicalResistance' ) ] ),
        --        infobox:renderItem( translate( 'LBL_ShieldEnergyResistance' ), smwData[ t( 'SMW_ShieldEnergyResistance' ) ] ),
        --        infobox:renderItem( translate( 'LBL_ShieldDistortionResistance' ), smwData[ t( 'SMW_ShieldDistortionResistance' ) ] ),
        --
        --        infobox:renderItem( translate( 'LBL_ShieldThermalResistance' ), smwData[ t( 'SMW_ShieldThermalResistance' ) ] ),
        --        infobox:renderItem( translate( 'LBL_ShieldBiochemicalResistance' ), smwData[ t( 'SMW_ShieldBiochemicalResistance' ) ] ),
        --        infobox:renderItem( translate( 'LBL_ShieldStunResistance' ), smwData[ t( 'SMW_ShieldStunResistance' ) ] ),
        --    }
        --} )
        -- Tractor beam
        -- TODO: Maybe we should use SMW_Type for all the stuff above
    elseif smwData[ t( 'SMW_Type' ) ] == 'TractorBeam' or smwData[ t( 'SMW_Type' ) ] == 'TowingBeam' then
        -- Overview
        tabberData[ 'label1' ] = translate( 'LBL_Overview' )
        section = {
            infobox:renderItem( translate( 'LBL_MaximumForce' ), smwData[ t( 'SMW_MaximumForce' ) ] ),
            infobox:renderItem( translate( 'LBL_OptimalRange' ), smwData[ t( 'SMW_OptimalRange' ) ] ),
            infobox:renderItem( translate( 'LBL_MaximumRange' ), smwData[ t( 'SMW_MaximumRange' ) ] ),
            infobox:renderItem( translate( 'LBL_MaximumAngle' ), smwData[ t( 'SMW_MaximumAngle' ) ] ),
            infobox:renderItem( translate( 'LBL_MaximumVolume' ), smwData[ t( 'SMW_MaximumVolume' ) ] )
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
        infobox:renderItem( translate( 'LBL_PowerDraw' ),
            infobox.addUnitIfExists(
                infobox.formatRange( smwData[ t( 'SMW_MinimumPowerDraw' ) ],
                    smwData[ t( 'SMW_MaximumPowerDraw' ) ], true ), '🔌/s' ) ),
        infobox:renderItem( translate( 'LBL_ThermalEnergyOutput' ),
            infobox.addUnitIfExists(
                infobox.formatRange( smwData[ t( 'SMW_MinimumThermalEnergyOutput' ) ],
                    smwData[ t( 'SMW_MaximumThermalEnergyOutput' ) ], true ), '🌡️/s' ) ),
        infobox:renderItem( translate( 'LBL_MaximumCoolingRate' ), smwData[ t( 'SMW_MaximumCoolingRate' ) ] ),
        infobox:renderItem( translate( 'LBL_StartCoolingTemperature' ),
            smwData[ t( 'SMW_StartCoolingTemperature' ) ] ),
        infobox:renderItem( translate( 'LBL_Temperature' ),
            infobox.addUnitIfExists(
                infobox.formatRange( smwData[ t( 'SMW_MinimumTemperature' ) ],
                    smwData[ t( 'SMW_MaximumTemperature' ) ], true ), '°C' ) ),
        infobox:renderItem( translate( 'LBL_MisfireTemperature' ),
            infobox.addUnitIfExists(
                infobox.formatRange( smwData[ t( 'SMW_MinimumMisfireTemperature' ) ],
                    smwData[ t( 'SMW_MaximumMisfireTemperature' ) ], true ), '°C' ) ),
        infobox:renderItem( translate( 'LBL_OverheatTemperature' ), smwData[ t( 'SMW_OverheatTemperature' ) ] )
    }
    tabberData[ 'content' .. tabCount ] = infobox:renderSection( { content = section, col = 2 }, true )

    -- Emission
    local function getMaxIR()
        if
            (type( smwData[ t( 'SMW_IRTemperatureThreshold' ) ] ) ~= 'number' or type( smwData[ t( 'SMW_TemperatureToIR' ) ] ~= 'number' ))
            and type( smwData[ t( 'SMW_MinimumIR' ) ] ) ~= 'number'
        then
            return
        end

        return smwData[ t( 'SMW_IRTemperatureThreshold' ) ] * smwData[ t( 'SMW_TemperatureToIR' ) ] +
            smwData[ t( 'SMW_MinimumIR' ) ]
    end

    tabCount = tabCount + 1
    tabberData[ 'label' .. tabCount ] = translate( 'LBL_Emission' )
    section = {
        infobox:renderItem( translate( 'LBL_EM' ),
            infobox.formatRange( smwData[ t( 'SMW_MinimumEM' ) ], smwData[ t( 'SMW_MaximumEM' ) ], true ) ),
        infobox:renderItem( translate( 'LBL_PowerToEM' ), smwData[ t( 'SMW_PowerToEM' ) ] ),
        infobox:renderItem( translate( 'LBL_EMDecayRate' ), smwData[ t( 'SMW_EMDecayRate' ) ] ),
        infobox:renderItem( translate( 'LBL_IR' ),
            infobox.formatRange( smwData[ t( 'SMW_MinimumIR' ) ], getMaxIR(), true ) ),
        infobox:renderItem( translate( 'LBL_TemperatureToIR' ), smwData[ t( 'SMW_TemperatureToIR' ) ] )
    }
    tabberData[ 'content' .. tabCount ] = infobox:renderSection( { content = section, col = 3 }, true )

    -- Defense
    tabCount = tabCount + 1
    tabberData[ 'label' .. tabCount ] = translate( 'LBL_Defense' )
    section = {
        infobox:renderItem( translate( 'LBL_Health' ), smwData[ t( 'SMW_HealthPoint' ) ] ),
        infobox:renderItem( translate( 'LBL_DistortionHealthPoint' ), smwData
            [ t( 'SMW_DistortionHealthPoint' ) ] ),
        infobox:renderItem( translate( 'LBL_DistortionDecayRate' ), smwData[ t( 'SMW_DistortionDecayRate' ) ] ),
        infobox:renderItem( translate( 'LBL_DistortionDecayDelay' ), smwData[ t( 'SMW_DistortionDecayDelay' ) ] )
    }
    tabberData[ 'content' .. tabCount ] = infobox:renderSection( { content = section, col = 2 }, true )

    -- Dimensions
    --tabberData[ 'label' .. tabCount ] = translate( 'LBL_Dimensions' )
    --section = {
    --    infobox:renderItem( {
    --        label = translate( 'LBL_Length' ),
    --        data = smwData[ t( 'SMW_EntityLength' ) ],
    --    } ),
    --    infobox:renderItem( {
    --        label = translate( 'LBL_Width' ),
    --        data = smwData[ t( 'SMW_EntityWidth' ) ],
    --    } ),
    --    infobox:renderItem( {
    --        label = translate( 'LBL_Height' ),
    --        data = smwData[ t( 'SMW_EntityHeight' ) ],
    --    } ),
    --    infobox:renderItem( {
    --        label = translate( 'LBL_Mass' ),
    --        data = smwData[ t( 'SMW_Mass' ) ],
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
--- @return nil
function p.addCategories( categories, frameArgs, smwData )

end

--- Set the short description for this object
---
--- @param shortdesc string Short description
--- @param frameArgs table Frame arguments from Module:Arguments
--- @param smwData table Data from Semantic MediaWiki
--- @return nil
function p.getShortDescription( shortdesc, frameArgs, smwData )

end

return p
