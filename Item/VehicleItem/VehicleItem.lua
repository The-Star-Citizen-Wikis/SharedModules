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


local function loadQuantumDriveModes( pageName )
    -- FIXME: Is there a way to filter out only subobjects with certain properties?
    -- Currently the query gets all the subobjects, including the commodity ones
    local subobjects = mw.smw.ask( {
        '[[-Has subobject::' .. pageName .. ']]',
        string.format( '?%s', translate( 'SMW_QuantumJumpType' ) ),
        string.format( '?%s', translate( 'SMW_QuantumJumpDriveSpeed' ) ),
        string.format( '?%s', translate( 'SMW_QuantumCooldownTime' ) ),
        string.format( '?%s', translate( 'SMW_QuantumSpoolUpTime' ) ),
        'mainlabel=-'
    } )
    local modes = {}

    for _, subobject in ipairs( subobjects ) do
        if subobject[ translate( 'SMW_QuantumJumpType' ) ] then
            table.insert( modes, subobject )
        end
    end

    return modes
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
    local tabber = require( 'Module:Tabber' ).renderTabber
    local tabberData = {}
    local section

    -- Cooler
    if smwData[ translate( 'SMW_CoolingRate' ) ] then
        -- Overview
        tabberData[ 'label1' ] = translate( 'LBL_Overview' )
        section = {
            infobox:renderItem( translate( 'LBL_CoolingRate' ), smwData[ translate( 'SMW_CoolingRate' ) ] )
        }
        tabberData[ 'content1' ] = infobox:renderSection( { content = section, col = 2 }, true )
    -- Power Plant
    elseif smwData[ translate( 'SMW_PowerOutput' ) ] then
        -- Overview
        tabberData[ 'label1' ] = translate( 'LBL_Overview' )
        section = {
            infobox:renderItem( translate( 'LBL_PowerOutput' ), smwData[ translate( 'SMW_PowerOutput' ) ] )
        }
        tabberData[ 'content1' ] = infobox:renderSection( { content = section, col = 2 }, true )
    -- Quantum Drive
    elseif smwData[ translate( 'SMW_QuantumFuelRequirement' ) ] then
        local function getQuantumDriveModesSection()
            local modes = loadQuantumDriveModes( itemPageIdentifier )

            if type( modes ) == 'table' then
                local modeTabberData = {}
                local modeCount = 1

                for _, mode in ipairs( modes ) do
                    modeTabberData[ 'label' .. modeCount ] = translate( mode[ translate( 'SMW_QuantumJumpType' ) ] )
                    section = {
                        infobox:renderItem( translate( 'LBL_QuantumJumpDriveSpeed' ), mode[ translate( 'SMW_QuantumJumpDriveSpeed' ) ] ),
                        infobox:renderItem( translate( 'LBL_QuantumCooldownTime' ), mode[ translate( 'SMW_QuantumCooldownTime' ) ] ),
                        infobox:renderItem( translate( 'LBL_QuantumSpoolUpTime' ), mode[ translate( 'SMW_QuantumSpoolUpTime' ) ] )
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
            infobox:renderItem( translate( 'LBL_QuantumJumpRange' ), smwData[ translate( 'SMW_QuantumJumpRange' ) ] )
        }
        tabberData[ 'content1' ] = infobox:renderSection( { content = section, col = 2 }, true ) .. getQuantumDriveModesSection()
    -- Shield
    elseif smwData[ translate( 'SMW_ShieldHealthPoint' ) ] then
        -- We need raw number from SMW to calculate shield regen, so we add the unit back
        local function getShieldPoint()
            if smwData[ translate( 'SMW_ShieldHealthPoint' ) ] == nil then return end
            return common.formatNum( math.ceil( smwData[ translate( 'SMW_ShieldHealthPoint' ) ] ) ) .. ' HP'
        end

        local function getShieldRegen()
            if smwData[ translate( 'SMW_ShieldPointRegeneration' ) ] == nil then return end
            if smwData[ translate( 'SMW_ShieldHealthPoint' ) ] == nil then return smwData[ translate( 'SMW_ShieldPointRegeneration' ) ] end

            local fullChargeTime = math.ceil( smwData[ translate( 'SMW_ShieldHealthPoint' ) ] / smwData[ translate( 'SMW_ShieldPointRegeneration' ) ] )

            return infobox.showDescIfDiff(
                common.formatNum( math.ceil( smwData[ translate( 'SMW_ShieldPointRegeneration' ) ] ) ) .. ' HP/s',
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
    -- Quantum Drive
    elseif smwData[ translate( 'SMW_MaxMissiles' ) ] then
        -- Overview
        tabberData[ 'label1' ] = translate( 'LBL_Overview' )
        section = {
            infobox:renderItem( translate( 'LBL_MaxMissiles' ), smwData[ translate( 'SMW_MaxMissiles' ) ] ),
            infobox:renderItem( translate( 'LBL_MissileSize' ), smwData[ translate( 'SMW_MissileSize' ) ] )
        }
        tabberData[ 'content1' ] = infobox:renderSection( { content = section, col = 2 }, true )
    -- Mining Laser
    elseif smwData[ translate( 'SMW_MiningLaserPower' ) ] then
        -- Overview
        tabberData[ 'label1' ] = translate( 'LBL_Overview' )
        section = {
            infobox:renderItem( translate( 'LBL_PowerTransfer' ), smwData[ translate( 'SMW_PowerTransfer' ) ] ),
            infobox:renderItem( translate( 'LBL_OptimalRange' ), smwData[ translate( 'SMW_OptimalRange' ) ] ),
            infobox:renderItem( translate( 'LBL_MaximumRange' ), smwData[ translate( 'SMW_MaximumRange' ) ] ),
            infobox:renderItem( translate( 'LBL_ExtractionThroughput' ), smwData[ translate( 'SMW_ExtractionThroughput' ) ] ),
            infobox:renderItem( translate( 'LBL_MiningLaserPower' ), smwData[ translate( 'SMW_MiningLaserPower' ) ] ),
            infobox:renderItem( translate( 'LBL_ExtractionLaserPower' ), smwData[ translate( 'SMW_ExtractionLaserPower' ) ] ),
            infobox:renderItem( translate( 'LBL_ModuleSlots' ), smwData[ translate( 'SMW_ModuleSlots' ) ] )
        }
        tabberData[ 'content1' ] = infobox:renderSection( { content = section, col = 2 }, true )

        tabberData[ 'label2' ] = translate( 'LBL_Modifiers' )
        section = {
            infobox:renderItem( translate( 'LBL_ModifierCatastrophicChargeRate' ), smwData[ translate( 'SMW_ModifierCatastrophicChargeRate' ) ] ),
            infobox:renderItem( translate( 'LBL_ModifierExtractionLaserPower' ), smwData[ translate( 'SMW_ModifierExtractionLaserPower' ) ] ),
            infobox:renderItem( translate( 'LBL_ModifierLaserInstability' ), smwData[ translate( 'SMW_ModifierLaserInstability' ) ] ),
            infobox:renderItem( translate( 'LBL_ModifierMiningLaserPower' ), smwData[ translate( 'SMW_ModifierMiningLaserPower' ) ] ),
            infobox:renderItem( translate( 'LBL_ModifierOptimalChargeWindowRate' ), smwData[ translate( 'SMW_ModifierOptimalChargeWindowRate' ) ] ),
            infobox:renderItem( translate( 'LBL_ModifierInertMaterials' ), smwData[ translate( 'SMW_ModifierInertMaterials' ) ] ),
            infobox:renderItem( translate( 'LBL_ModifierOptimalChargeRate' ), smwData[ translate( 'SMW_ModifierOptimalChargeRate' ) ] ),
            infobox:renderItem( translate( 'LBL_ModifierResistance' ), smwData[ translate( 'SMW_ModifierResistance' ) ] ),
            infobox:renderItem( translate( 'LBL_ModifierShatterDamage' ), smwData[ translate( 'SMW_ModifierShatterDamage' ) ] ),
            infobox:renderItem( translate( 'LBL_ModifierSize' ), smwData[ translate( 'SMW_ModifierSize' ) ] )
        }
        tabberData[ 'content2' ] = infobox:renderSection( { content = section, col = 3 }, true )
    -- Mining Module
    elseif smwData[ translate( 'SMW_ModuleUses' ) ] then
        -- Overview
        tabberData[ 'label1' ] = translate( 'LBL_Overview' )
        section = {
            infobox:renderItem( translate( 'LBL_ModuleUses' ), smwData[ translate( 'SMW_ModuleUses' ) ] ),
            infobox:renderItem( translate( 'LBL_ModuleDuration' ), smwData[ translate( 'SMW_ModuleDuration' ) ] )
        }
        tabberData[ 'content1' ] = infobox:renderSection( { content = section, col = 2 }, true )

        tabberData[ 'label2' ] = translate( 'LBL_Modifiers' )
        section = {
            infobox:renderItem( translate( 'LBL_ModifierCatastrophicChargeRate' ), smwData[ translate( 'SMW_ModifierCatastrophicChargeRate' ) ] ),
            infobox:renderItem( translate( 'LBL_ModifierExtractionLaserPower' ), smwData[ translate( 'SMW_ModifierExtractionLaserPower' ) ] ),
            infobox:renderItem( translate( 'LBL_ModifierLaserInstability' ), smwData[ translate( 'SMW_ModifierLaserInstability' ) ] ),
            infobox:renderItem( translate( 'LBL_ModifierMiningLaserPower' ), smwData[ translate( 'SMW_ModifierMiningLaserPower' ) ] ),
            infobox:renderItem( translate( 'LBL_ModifierOptimalChargeWindowRate' ), smwData[ translate( 'SMW_ModifierOptimalChargeWindowRate' ) ] ),
            infobox:renderItem( translate( 'LBL_ModifierInertMaterials' ), smwData[ translate( 'SMW_ModifierInertMaterials' ) ] ),
            infobox:renderItem( translate( 'LBL_ModifierOptimalChargeRate' ), smwData[ translate( 'SMW_ModifierOptimalChargeRate' ) ] ),
            infobox:renderItem( translate( 'LBL_ModifierResistance' ), smwData[ translate( 'SMW_ModifierResistance' ) ] ),
            infobox:renderItem( translate( 'LBL_ModifierShatterDamage' ), smwData[ translate( 'SMW_ModifierShatterDamage' ) ] ),
            infobox:renderItem( translate( 'LBL_ModifierSize' ), smwData[ translate( 'SMW_ModifierSize' ) ] )
        }
        tabberData[ 'content2' ] = infobox:renderSection( { content = section, col = 3 }, true )
    end

    -- Get the index of the last tab
    local tabCount = 0
    for _, __ in pairs( tabberData ) do
        tabCount = tabCount + 1
    end
    tabCount = tabCount / 2

    -- Defense
    tabCount = tabCount + 1
    tabberData[ 'label' .. tabCount ] = translate( 'LBL_Defense' )
    section = {
        infobox:renderItem( translate( 'LBL_Health' ), smwData[ translate( 'SMW_HealthPoint' ) ] ),
        infobox:renderItem( translate( 'LBL_DistortionHealthPoint' ), smwData[ translate( 'SMW_DistortionHealthPoint' ) ] )
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