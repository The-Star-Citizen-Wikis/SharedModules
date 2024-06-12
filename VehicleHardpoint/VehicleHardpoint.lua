require( 'strict' )

local VehicleHardpoint = {}

local metatable = {}
local methodtable = {}

metatable.__index = methodtable

local i18n = require( 'Module:i18n' ):new()
local TNT = require( 'Module:Translate' ):new()
local common = require( 'Module:Common' ) -- formatNum and spairs
local hatnote = require( 'Module:Hatnote' )._hatnote
local data = mw.loadJsonData( 'Module:VehicleHardpoint/data.json' )
local config = mw.loadJsonData( 'Module:VehicleHardpoint/config.json' )


--- Wrapper function for Module:i18n.translate
---
--- @param key string The translation key
--- @return string If the key was not found, the key is returned
local function t( key )
	return i18n:translate( key )
end


--- Calls TNT with the given key
---
--- @param key string The translation key
--- @param addSuffix boolean|nil Adds a language suffix if config.smw_multilingual_text is true
--- @return string If the key was not found in the .tab page, the key is returned
local function translate( key, addSuffix, ... )
	return TNT:translate( 'Module:VehicleHardpoint/i18n.json', config, key, addSuffix, {...} ) or key
end


--- Checks if an entry contains a 'child' key with further entries
---
--- @return boolean
local function hasChildren( row )
    return row.children ~= nil and type( row.children ) == 'table' and #row.children > 0
end


--- Creates the object that is used to query the SMW store
---
--- @param page string the vehicle page containing data
--- @return table
local function makeSmwQueryObject( page )
    local langSuffix = ''
    if config.smw_multilingual_text == true then
        langSuffix = '+lang=' .. ( config.module_lang or mw.getContentLanguage():getCode() )
    end

    return {
        mw.ustring.format(
            '[[-Has subobject::' .. page .. ']][[%s::+]][[%s::+]]',
            t( 'SMW_HardpointType' ),
            t( 'SMW_VehicleHardpointsTemplateGroup' )
        ),
        mw.ustring.format( '?%s#-=from_gamedata', t( 'SMW_FromGameData' ) ),
        mw.ustring.format( '?%s#-=count', t( 'SMW_ItemQuantity' ) ),
        mw.ustring.format( '?%s#-=min_size', t( 'SMW_HardpointMinimumSize' ) ),
        mw.ustring.format( '?%s#-=max_size', t( 'SMW_HardpointMaximumSize' ) ),
        mw.ustring.format( '?%s#-=class', t( 'SMW_VehicleHardpointsTemplateGroup' ) ), langSuffix,
        mw.ustring.format( '?%s#-=type', t( 'SMW_HardpointType' ) ), langSuffix,
        mw.ustring.format( '?%s#-=sub_type', t( 'SMW_HardpointSubtype' ) ), langSuffix,
        mw.ustring.format( '?%s#-=name', t( 'SMW_Name' ) ),
        mw.ustring.format( '?%s#-n=scu', t( 'SMW_Inventory' ) ),
        mw.ustring.format( '?UUID#-=uuid' ),
        mw.ustring.format( '?%s#-=hardpoint', t( 'SMW_Hardpoint' ) ) ,
        mw.ustring.format( '?%s#-=class_name', t( 'SMW_HardpointClassName' ) ) ,
        mw.ustring.format( '?%s#-=magazine_capacity', t( 'SMW_MagazineCapacity' ) ),
        mw.ustring.format( '?%s=thrust_capacity', t( 'SMW_ThrustCapacity' ) ),
        mw.ustring.format( '?%s=damage', t( 'SMW_Damage' ) ),
        mw.ustring.format( '?%s=damage_radius', t( 'SMW_DamageRadius' ) ),
        mw.ustring.format( '?%s=fuel_capacity', t( 'SMW_FuelCapacity' ) ),
        mw.ustring.format( '?%s=fuel_intake_rate', t( 'SMW_FuelIntakeRate' ) ),
        mw.ustring.format( '?%s#-=parent_hardpoint', t( 'SMW_ParentHardpoint' ) ),
        mw.ustring.format( '?%s#-=root_hardpoint', t( 'SMW_RootHardpoint' ) ),
        mw.ustring.format( '?%s#-=parent_uuid', t( 'SMW_ParentHardpointUuid' ) ),
        mw.ustring.format( '?%s#-=icon', t( 'SMW_Icon' ) ),
        mw.ustring.format( '?%s=hp', t( 'SMW_HitPoints' ) ),
        mw.ustring.format( '?%s#-=position', t( 'SMW_Position' ) ),
        -- These are subquery chains, they require that the 'Name' attribute is of type Page
        -- And that these pages contain SMW attributes
        '?' .. t( 'SMW_Name' ) .. '.' .. t( 'SMW_Grade' ) .. '#-=item_grade',
        '?' .. t( 'SMW_Name' ) .. '.' .. t( 'SMW_Class' ) .. '#-=item_class',
        '?' .. t( 'SMW_Name' ) .. '.' .. t( 'SMW_Size' ) .. '#-=item_size',
        '?' .. t( 'SMW_Name' ) .. '.' .. t( 'SMW_Manufacturer' ) .. '#-=manufacturer',
        mw.ustring.format(
            'sort=%s,%s,%s,%s,%s',
            t( 'SMW_VehicleHardpointsTemplateGroup' ),
            t( 'SMW_Hardpoint' ),
            t( 'SMW_HardpointType' ),
            t( 'SMW_HardpointMaximumSize' ),
            t( 'SMW_ItemQuantity' )
        ),
        'order=asc,desc,asc,asc,asc',
        'limit=1000'
    }
end


--- Creates a 'key' based on various data points found on the hardpoint and item
--- Based on this key, the count of some entries is generated
---
--- @param row table - API Data
--- @param hardpointData table - Data from getHardpointData
--- @param parent table|nil - Parent hardpoint (A settable SMW Subobject)
--- @param root string|nil - Root hardpoint
--- @return string Key
local function makeKey( row, hardpointData, parent, root )
    local key

    -- If the hardpoint has an item attached
    if type( row.item ) == 'table' then
        -- List of item types that should always be grouped together
        -- i.e. their count is increased instead of them being displayed as separate boxes
        if row.type == 'ManneuverThruster' or
           row.type == 'MainThruster' or
           row.type == 'ArmorLocker' or
           row.type == 'Bed' or
           row.type == 'CargoGrid' or
           row.type == 'Cargo'
        then
            key = row.type .. row.sub_type
        else
            local suffix = ( row.item.name or '' )
            if suffix == '<= PLACEHOLDER =>' then
                suffix = row.item.uuid
            end

            -- Adding the uuid to the key ensures separate boxes if the equipped item differs
            key = row.type .. row.sub_type .. suffix
        end
    else
        -- If no item is set, use the pre-defined class and type
        key = hardpointData.class .. hardpointData.type
    end

    -- Appends the parent and root hardpoints in order to not mess up child counts
    -- Without this, a vehicle with four turrets containing each one weapon would be listed as
    -- having four turrets that each has four weapons (if the exact weapon is equipped on each turret)
    if parent ~= nil and parent[ t( 'SMW_Name' ) ] ~= nil and
       row.type ~= 'DecoyLauncherMagazine' and
       row.type ~= 'NoiseLauncherMagazine'
    then
        --key = key .. parent[ t( 'SMW_Hardpoint' ) ]
        key = key .. ( parent[ t( 'SMW_Name' ) ] or parent[ t( 'SMW_Hardpoint' ) ] )
    end

    if root ~= nil and not mw.ustring.match( key, root ) and ( hardpointData.class == 'Weapons' or hardpointData.class == 'Utility' ) then
        key = key .. root
    end

    if hardpointData.class == 'Weapons' and row.name ~= nil and row.type == 'MissileLauncher' then
--        key = key .. row.item.name or row.name
    end

    mw.logObject( mw.ustring.format( 'Key: %s', key ), '📐 [VehicleHardpoint] makekey' )

    return key
end


--- Get pre-defined hardpoint data for a given hardpoint type
--- If no type is found, the hardpoint name is matched against the defined regexes until the first one matches
---
--- @param hardpointType string
--- @return table|nil
function methodtable.getHardpointData( self, hardpointType )
    if type( data.matches[ hardpointType ] ) == 'table' then
        return data.matches[ hardpointType ]
    end

    for hType, mappingData in pairs( data.matches ) do
        if hardpointType == hType then
            return mappingData
        elseif type( mappingData.matches ) == 'table' then
            for _, matcher in pairs( mappingData.matches ) do
                if mw.ustring.match( hardpointType, matcher ) ~= nil then
                    return mappingData
                end
            end
        end
    end

    return nil
end


--- Creates a child object for weapons and counter measure ammunitions
--- As well as weapon ports on armor locker
---
--- @param hardpoint table A hardpoint object form the API
--- @return nil
local function addSubComponents( hardpoint )
    if type( hardpoint.item ) ~= 'table' then
        return
    end

    if type( hardpoint.children ) ~= 'table' then
        hardpoint.children = {}
    end

    if hardpoint.item.type == 'WeaponDefensive' or hardpoint.item.type == 'WeaponGun' then
        local item_type = 'Magazine'
        if mw.ustring.sub( hardpoint.class_name, -5 ) == 'chaff' then
            item_type = 'NoiseLauncherMagazine'
        elseif mw.ustring.sub( hardpoint.class_name, -5 ) == 'flare' then
            item_type = 'DecoyLauncherMagazine'
        end

        local capacity = {}
        local magazineName = translate( 'Magazine' )
        if hardpoint.item.type == 'WeaponGun' and type( hardpoint.item.vehicle_weapon ) == 'table' then
            table.insert( capacity, hardpoint.item.vehicle_weapon.capacity )

            -- This is a laser weapon, add another capacity of -1 to indicate that this weapon has infinite ammo
            if type( hardpoint.item.vehicle_weapon.regeneration ) == 'table' then
                table.insert( capacity, -1 )
                magazineName = translate( 'Capacitor' )
            end
        elseif type( hardpoint.item.counter_measure ) == 'table' then
            table.insert( capacity, hardpoint.item.counter_measure.capacity )
        end

        table.insert( hardpoint.children, {
            name = 'faux_hardpoint_magazine',
            class_name = 'FAUX_' .. item_type .. 'Magazine',
            type = item_type,
            sub_type = item_type,
            min_size = 1,
            max_size = 1,
            item = {
                name = magazineName,
                type = item_type,
                sub_type = item_type,
                magazine_capacity = capacity
            }
        } )
    end

    -- This seems to be a weapon rack
    if ( hardpoint.item.type == 'Usable' or hardpoint.item.type == 'Door' ) and type( hardpoint.item.ports ) == 'table' then
        local item_type = 'WeaponPort'
        for _, port in pairs( hardpoint.item.ports ) do
            -- Prevent stuff like mattress and pillow to count as weapon ports (I don't think SC let you hide weapons inside them :P)
            if ( mw.ustring.find( port.name, 'weapon', 1, true ) or mw.ustring.find( port.display_name, 'weapon', 1, true ) ) then
                local sub_type = item_type .. tostring( port.sizes.min or 0 ) .. tostring( port.sizes.max or 0 )
                local name = 'WeaponPort'

                if port.sizes.max == 5 or mw.ustring.find( port.display_name, 'launcher', 1, true ) then
                    name = name .. 'Launcher'
                elseif port.sizes.max == 4 or mw.ustring.find( port.display_name, 'rifle', 1, true ) then
                    name = name .. 'Rifle'
                elseif mw.ustring.find( port.display_name, 'multitool', 1, true ) then
                    name = name .. 'Multitool'
                elseif mw.ustring.find( port.display_name, 'addon', 1, true ) then
                    name = name .. 'Addon'
                -- Assume size 1 is pistol slot if it is not specified as multitool or addon
                elseif port.sizes.max == 1 or mw.ustring.find( port.display_name, 'pistol', 1, true ) then
                    name = name .. 'Pistol'
                end

                table.insert( hardpoint.children, {
                    name = 'faux_hardpoint_weaponport',
                    class_name = 'FAUX_WeaponPort',
                    type = item_type,
                    sub_type = sub_type,
                    min_size = port.sizes.min,
                    max_size = port.sizes.max,
                    item = {
                        name = translate( name ),
                        type = item_type,
                        sub_type = sub_type,
                    }
                } )
            end
        end
    end

    -- Missiles Set on Ports
    if hardpoint.item.type == 'MissileLauncher' and type( hardpoint.item.ports ) == 'table' then
        for _, port in pairs( hardpoint.item.ports ) do
            if type( port.equipped_item ) == 'table' then
                local item = port.equipped_item
                table.insert( hardpoint.children, {
                    name = port.name,
                    --class_name = port.equipped_item
                    type = 'Missile',
                    sub_type = item.sub_type,
                    min_size = port.sizes.min,
                    max_size = port.sizes.max,
                    item = {
                        name = item.name,
                        type = item.type,
                        sub_type = item.sub_type,
                    }
                } )
            end
        end
    end
end


--- Builds the object that is saved to SMW as a Subobject
---
--- @param row table - API Data
--- @param hardpointData table|nil - Data from getHardpointData
--- @param parent table|nil - Parent hardpoint
--- @param root string|nil - Root hardpoint
--- @return table|nil
function methodtable.makeObject( self, row, hardpointData, parent, root )
    local object = {}

    if hardpointData == nil then
        hardpointData = self:getHardpointData( row.type or row.name )
    end

    if hardpointData == nil then
        return nil
    end

    object[ t( 'SMW_Hardpoint' ) ] = row.name
    object[ t( 'SMW_FromGameData' ) ] = true
    object[ t( 'SMW_HardpointMinimumSize' ) ] = row.min_size
    object[ t( 'SMW_HardpointMaximumSize' ) ] = row.max_size
    object[ t( 'SMW_VehicleHardpointsTemplateGroup' ) ] = translate( hardpointData.class, true )
    object[ t( 'SMW_HitPoints' ) ] = row.damage_max
    object[ t( 'SMW_Position' ) ] = row.position

    if type( row.class_name ) == 'string' then
        object[ t( 'SMW_HardpointClassName' ) ] = row.class_name
    end

    object[ t( 'SMW_HardpointType' ) ] = translate( hardpointData.type, true )
    object[ t( 'SMW_HardpointSubtype' ) ] = translate( hardpointData.type, true )

    -- FIXME: Is there a way to use Lua table key directly instead of setting subtype separately in data.json?
    -- For some components (e.g. missile), the key is the subtype of the component
    local function setTypeSubtype( match )
        if match ~= nil then
            if match.type ~= nil then
                object[ t( 'SMW_HardpointType' ) ] = translate( match.type, true )
            end
            if match.subtype ~= nil then
                object[ t( 'SMW_HardpointSubtype' ) ] = translate( match.subtype, true )
            end
        end
    end

    setTypeSubtype( data.matches[ row.type ] )
    setTypeSubtype( data.matches[ row.sub_type ] )

    if hardpointData.item ~= nil and type( hardpointData.item.name ) == 'string' then
        object[ t( 'SMW_Name' ) ] = hardpointData.item.name
    end

    if type( row.item ) == 'table' then
        local itemObj = row.item

        if itemObj.name ~= '<= PLACEHOLDER =>' then
            local match = mw.ustring.match( row.class_name or '', '[Dd]estruct_(%d+s)' )

            if row.type == 'SelfDestruct' and match ~= nil then
                object[ t( 'SMW_Name' ) ] = mw.ustring.format( '%s (%s)', t( 'SMW_SelfDestruct' ), match )
                -- Set self-destruct stats
                -- FIXME: Do subquery instead when CIG properly implement self-destruct components
                if itemObj.self_destruct then
                    object[ t( 'SMW_Damage' ) ] = itemObj.self_destruct.damage
                    object[ t( 'SMW_DamageRadius' ) ] = itemObj.self_destruct.radius
                end
            else
                object[ t( 'SMW_Name' ) ] = itemObj.name
            end
        else
            object[ t( 'SMW_Name' ) ] = object[ t( 'SMW_HardpointSubtype' ) ]
            -- Remove lang suffix
            local parts = mw.text.split( object[ t( 'SMW_Name' ) ], '@', true )
            object[ t( 'SMW_Name' ) ] = parts[ 1 ] or object[ t( 'SMW_Name' ) ]
        end

        object[ t( 'SMW_MagazineCapacity' ) ] = itemObj.magazine_capacity

        if ( itemObj.type == 'Cargo' or itemObj.type == 'SeatAccess' or itemObj.type == 'CargoGrid' or itemObj.type == 'Container' )
                and type( itemObj.inventory ) == 'table' then
            object[ t( 'SMW_Inventory' ) ] = common.formatNum( (itemObj.inventory.scu or nil ), nil )
        end

        if itemObj.thruster then
            object[ t( 'SMW_ThrustCapacity' ) ] = itemObj.thruster.thrust_capacity
            --- Convert to per Newton since thrust capacity is in Newton
            object[ t( 'SMW_FuelBurnRate' ) ] = itemObj.thruster.fuel_burn_per_10k_newton / 10000
        end

        if itemObj.fuel_tank and itemObj.fuel_tank.capacity > 0 then
            object[ t( 'SMW_FuelCapacity' ) ] = itemObj.fuel_tank.capacity
        end

        if itemObj.fuel_intake then
            object[ t( 'SMW_FuelIntakeRate' ) ] = itemObj.fuel_intake.fuel_push_rate
        end

        if object[ t( 'SMW_HardpointMinimumSize' ) ] == nil then
            object[ t( 'SMW_HardpointMinimumSize' ) ] = itemObj.size
            object[ t( 'SMW_HardpointMaximumSize' ) ] = itemObj.size
        end

        object[ 'UUID' ] = row.item.uuid
    end

    if parent ~= nil then
        object[ t( 'SMW_ParentHardpointUuid' ) ] = parent[ 'UUID' ]
        object[ t( 'SMW_ParentHardpoint' ) ] = parent[ t( 'SMW_Name' ) ]
    end

    if root ~= nil then
        object[ t( 'SMW_RootHardpoint' ) ] = root
    end

    -- Icon
    local icon = hardpointData.type
    if data.section_label_fixes[ hardpointData.class ] ~= nil or data.section_label_fixes[ hardpointData.type ] ~= nil then
        icon = data.section_label_fixes[ hardpointData.class ] or data.section_label_fixes[ hardpointData.type ]
    end

    for hType, iconKey in pairs( data.icons ) do
        if hType == icon then
            -- Disable label missing icons for now
            if iconKey == '' then
                icon = nil
                break
            end
            -- Apply icon key override
            icon = iconKey
        end
    end

    if icon ~= nil then
        if config.icon_name_localized == true then
            icon = translate( icon )
        end

        if config.icon_name_lowercase == true then
            icon = mw.ustring.lower( icon )
        end

        object[ t( 'SMW_Icon' ) ] = mw.ustring.format( 'File:%s%s.svg', config.icon_prefix, icon )
    end

    -- Remove SeatAccess Hardpoints without storage
    if row.item ~= nil and row.item.type == 'SeatAccess' and object[ t( 'SMW_Inventory' ) ] == nil then
        object = nil
    end

    return object;
end


--- Sets all available hardpoints as SMW subobjects
--- This method should be called by the accompanying Vehicle Module
---
--- @param hardpoints table API Hardpoint data
function methodtable.setHardPointObjects( self, hardpoints )
    if type( hardpoints ) ~= 'table' then
        error( translate( 'msg_invalid_hardpoints_object' ) )
    end

    local objects = {}
    local depth = 1

    local function cleanClassName( input )
        if mw.ustring.find( input, 'turret', 1, true ) then
            local parts = mw.text.split( input, 'turret', true )
            input = parts[ 1 ] or input
        end

        for _, remove in pairs( { 'top', 'bottom', 'left', 'right', 'front', 'rear', 'bubble', 'side' } ) do
            input = mw.ustring.gsub( input, '_' .. remove, '', 1 )
        end

        return input
    end

    -- Adds the subobject to the list of objects that should be saved to SMW
    -- Increases the item quantity / or combined cargo capacity for objects that have equal keys
    local function addToOut( object, key )
        if object == nil then
            return
        end

        -- If this key (object) has not been seen before, save it to the list of subobjects
        if type( objects[ key ] ) ~= 'table' then
            if object ~= nil then
                objects[ key ] = object
                objects[ key ][ t( 'SMW_ItemQuantity' ) ] = 1
            end
        else -- This key (object) has been seen before: Increase the quantity and any other cumulative metrics
            objects[ key ][ t( 'SMW_ItemQuantity' ) ] = objects[ key ][ t( 'SMW_ItemQuantity' ) ] + 1
            if object[ t( 'SMW_Position' ) ] ~= nil then
                if type( objects[ key ][ t( 'SMW_Position' ) ] ) == 'table' then
                    table.insert( objects[ key ][ t( 'SMW_Position' ) ], object[ t( 'SMW_Position' ) ] )
                else
                    objects[ key ][ t( 'SMW_Position' ) ] = {
                        objects[ key ][ t( 'SMW_Position' ) ],
                        object[ t( 'SMW_Position' ) ]
                    }
                end
            end

            local inventoryKey = t( 'SMW_Inventory' )
            -- Accumulate the cargo capacities of all cargo grids
            if object[ inventoryKey ] ~= nil then
                objects[ key ][ t( 'SMW_ItemQuantity' ) ] = 1

                if objects[ key ][ inventoryKey ] ~= nil and object[ inventoryKey ] ~= nil then
                    local sucExisting, numExisting = pcall( tonumber, objects[ key ][ inventoryKey ], 10 )
                    local sucNew, numNew = pcall( tonumber, object[ inventoryKey ], 10 )

                    if sucExisting and sucNew and numExisting ~= nil and numNew ~= nil then
                        objects[ key ][ inventoryKey ] = numExisting + numNew
                    end
                end
            end
        end
    end


    -- Iterates through the list of hardpoints found on the API object
    local function addHardpoints( hardpoints, parent, root )
        for _, hardpoint in pairs( hardpoints ) do
            hardpoint.name = mw.ustring.lower( hardpoint.name )

            if type( hardpoint.class_name ) == 'string' then
                hardpoint.class_name = cleanClassName( mw.ustring.lower( hardpoint.class_name ) )
            end

            hardpoint = VehicleHardpoint.fixTypes( hardpoint, data.fixes )

            local hardpointData = self:getHardpointData( hardpoint.type or hardpoint.name )

            if hardpointData ~= nil then
                if depth == 1 then
                    if type( hardpoint.item ) == 'table' then
                        root = hardpoint.class_name or hardpoint.name

                        if root == '<= PLACEHOLDER =>' then
                            root = hardpointData.type
                        end
                    else
                        root = hardpoint.name
                    end
                    mw.logObject( mw.ustring.format( 'Root: %s', root ), '📐 [VehicleHardpoint] addHardpoints' )
                end

                addSubComponents( hardpoint )

                -- Based on the key, the hardpoint is either used as "standalone" (i.e. saved as a single subobject)
                -- or, if the key already exists, the count if increased by one (so no extra subobject is generated)
                local key = makeKey( hardpoint, hardpointData, parent, root )

                local obj = self:makeObject( hardpoint, hardpointData, parent, root )

                addToOut( obj, key )

                -- Generate child subobjects
                if hasChildren( hardpoint ) then
                    depth = depth + 1
                    addHardpoints( hardpoint.children, obj, root )
                end
            elseif hasChildren( hardpoint ) then
                -- Fix for P72, if the main hardpoint is ignored, but it has children, try them
                for _, child in pairs( hardpoint.children ) do
                    table.insert( hardpoints, child )
                end
            end
        end

        depth = depth - 1

        if depth < 1 then
            depth = 1
            root = nil
        end
    end

    addHardpoints( hardpoints )

    mw.logObject( objects, '📐 [VehicleHardpoint] setHardPointObjects' )

    for _, subobject in pairs( objects ) do
        mw.smw.subobject( subobject )
    end

    return objects
end


--- Sets all available vehicle parts as SMW subobjects
--- This method should be called by the accompanying Vehicle Module
---
--- @param parts table API Parts data
function methodtable.setParts( self, parts )
    if type( parts ) ~= 'table' then
        error( translate( 'msg_invalid_hardpoints_object' ) )
    end

    local objects = {}
    local depth = 1

    local partData = {
        class = 'VehiclePart',
        type = 'VehiclePart',
    }

    local function makeKey( row, parent )
        local key = row.name

        if parent ~= nil then
            key = key .. parent[ t( 'SMW_Hardpoint' ) ]
        end

        mw.logObject( mw.ustring.format( 'Key: %s', key ), '📐 [VehicleHardpoint] makeKey' )

        return key
    end


    -- Adds the subobject to the list of objects that should be saved to SMW
    local function addToOut( object, key )
        if object == nil then
            return
        end

        -- If this key (object) has not been seen before, save it to the list of subobjects
        if type( objects[ key ] ) ~= 'table' then
            if object ~= nil then
                objects[ key ] = object
                objects[ key ][ t( 'SMW_ItemQuantity' ) ] = 1
            end
        end
    end


    -- Iterates through the list of parts found on the API object
    local function addParts( parts, parent, root )
        for _, part in pairs( parts ) do
            part.type = 'VehiclePart'
            part.min_size = 1
            part.max_size = 1
            part.item = {
                name = part.display_name
            }

            if depth == 1 then
                root = part.name
                mw.logObject( mw.ustring.format( 'Root: %s', root ), '📐 [VehicleHardpoint] addParts' )
            end

            local key = makeKey( part, parent )

            local obj = self:makeObject( part, partData, parent, root )

            addToOut( obj, key )

            -- Generate child subobjects
            if hasChildren( part ) then
                depth = depth + 1
                addParts( part.children, obj, root )
            end
        end

        depth = depth - 1

        if depth < 1 then
            depth = 1
            root = nil
        end
    end

    addParts( parts )

    mw.logObject( objects, '📐 [VehicleHardpoint] setParts' )

    for _, subobject in pairs( objects ) do
        mw.smw.subobject( subobject )
    end
end


--- Sets all available ship-matrix components as SMW subobjects
--- This method should be called by the accompanying Vehicle Module
---
--- @param components table API components data
function methodtable.setComponents( self, components )
    if type( components ) ~= 'table' then
        error( translate( 'msg_invalid_hardpoints_object' ) )
    end

    local lang = mw.getContentLanguage()

    for _, component in pairs( components ) do
        local parts = mw.text.split( components.type, '_', true )
        local type = ''
        for _, part in ipairs( parts ) do
            type = type .. lang:ucfirst( part )
        end

        type = mw.text.trim( type, 's' )

        mw.smw.subobject( {
            [ t( 'SMW_VehicleHardpointsTemplateGroup' ) ] = translate( component.class, true ),
            [ t( 'SMW_HardpointType' ) ] = translate( type, true ),
            [ t( 'SMW_Name' ) ] = translate( component.name:gsub( ' ', '' ) ),
            [ t( 'SMW_ItemQuantity' ) ] = component.quantity,
            --[ 'Komponentenbefestigungen' ] = component.mounts,
            [ t( 'SMW_Size' ) ] = component.component_size,
            [ t( 'SMW_HardpointMaximumSize' ) ] = component.size,
            [ t( 'SMW_FromGameData' ) ] = false,
        } )
    end

    mw.logObject( objects, '📐 [VehicleHardpoint] setParts' )

    for _, subobject in pairs( objects ) do
        mw.smw.subobject( subobject )
    end
end


--- Queries the SMW store for all available hardpoint subobjects for a given page
---
--- @param page string - The page to query
--- @return table|nil hardpoints
function methodtable.querySmwStore( self, page )
    -- Cache multiple calls
    if self.smwData ~= nil then
        return self.smwData
    end

    local smwData = mw.smw.ask( makeSmwQueryObject( page ) )

    if smwData == nil or smwData[ 1 ] == nil then
        return nil
    end

    --mw.logObject( smwData, '📐 [VehicleHardpoint] querySmwStore' )

    self.smwData = smwData

    return self.smwData
end


--- Group Hardpoints by Class and type
---
--- @param smwData table SMW data - Requires a 'class' key on each row
--- @return table
function methodtable.group( self, smwData )
    local grouped = {}

    if type( smwData ) ~= 'table' then
        return {}
    end

    for _, row in ipairs( smwData ) do
        if not row.isChild and row.class ~= nil and row.type ~= nil and
            -- Specifically hide manually added weapon ports that have no parent
            -- This should not be needed anymore if weapon lockers are found everywhere with an uuid
            row.type ~= translate( 'WeaponPort' ) and
            not mw.ustring.find( row.type, translate( 'Magazine' ), 1, true )
        then
            if type( grouped[ row.class ] ) ~= 'table' then
                grouped[ row.class ] = {}
            end

            if type( grouped[ row.class ][ row.type ] ) ~= 'table' then
                grouped[ row.class ][ row.type ] = {}
            end

            table.insert( grouped[ row.class ][ row.type ], row )

            self.iconMap[ row.class ] = row.icon
            self.iconMap[ row.type ] = row.icon
        end
    end

    --mw.logObject( grouped, '📐 [VehicleHardpoint] grouped' )

    return grouped
end


--- Adds children to the according parents
---
--- @param smwData table All available Hardpoint objects for this page
--- @return table The stratified table
function methodtable.createDataStructure( self, smwData )
    -- Maps a key to the index of the subobject, this way children can be set on their parent
    local idMapping = {}

    for index, object in ipairs( smwData ) do
        local keyMap
        if object.class == translate( 'VehiclePart' ) and object.name ~= nil then
            keyMap = object.name
        else
            keyMap = ( object.root_hardpoint or object.class_name or '' ) .. ( object.name or object.type or '' )
        end

        idMapping[ keyMap ] = index
    end

    -- Iterates through the list of SMW hardpoint subobjects
    -- If the 'parent_hardpoint' key is set (i.e. the hardpoint is a child), it is added as a child to the parent object
    local function stratify( toStratify )
        for _, object in ipairs( toStratify ) do
            if object.parent_hardpoint ~= nil then
                local parentEl
                if object.class == translate( 'VehiclePart' ) and object.parent_hardpoint ~= nil then
                    parentEl = toStratify[ idMapping[ object.parent_hardpoint ] ]
                else
                    parentEl = toStratify[ idMapping[ ( ( object.root_hardpoint or '' ) .. object.parent_hardpoint ) ] ]
                end

                if parentEl ~= nil then
                    if parentEl.children == nil then
                        parentEl.children = {}
                    end

                    object.isChild = true

                    table.insert( parentEl.children, object )
                end
            end
        end
    end

    -- SMW outputs a "flat" List of objects, after this the output is more or less equal to that from the API
    stratify( smwData )

    return smwData
end


--- Creates the subtitle that is shown in the card
---
--- Show info based on importance to readers
--- When the first tier is not available, show the next tier
---
--- @param item table Item i.e. row from the smw query
--- @return string
function methodtable.makeSubtitle( self, item )
    local subtitle = {}

    -- Tier 1
    -- Component-specific stats that affects gameplay

    -- SCU
    if item.scu ~= nil then
        -- Fix for german number format
        if mw.ustring.find( item.scu, ',', 1, true ) then
            item.scu = mw.ustring.gsub( item.scu, ',', '.' )
        end

        if type( item.scu ) ~= 'number' then
            local success, scu = pcall( tonumber, item.scu, 10 )

            if success then
                item.scu = scu
            end
        end

        -- We need to use raw value from SMW to show scu in different units (SCU, K µSCU)
        -- So we need to format the number manually
        if item.scu ~= nil and item.type == translate( 'CargoGrid' ) then
            table.insert( subtitle,
                common.formatNum( item.scu ) .. ' SCU' or 'N/A'
            )
        elseif item.scu ~= nil and item.type == translate( 'PersonalStorage' ) then
            table.insert( subtitle,
                common.formatNum( item.scu * 1000 ) .. 'K µSCU' or 'N/A'
            )
        end
    end

    -- Components that don't have a wiki page currently
    -- Magazine Capacity
    if item.magazine_capacity ~= nil then
        if type( item.magazine_capacity ) == 'table' then
            table.insert( subtitle,
                mw.ustring.format(
                    '%s/∞ %s',
                    item.magazine_capacity[ 1 ],
                    translate( 'Ammunition' )
                )
            )
        else
            table.insert( subtitle,
                mw.ustring.format(
                    '%s/%s %s',
                    item.magazine_capacity,
                    item.magazine_capacity,
                    translate( 'Ammunition' )
                )
            )
        end
    end

    -- Parts
    if item.hp ~= nil then
        table.insert( subtitle,
            item.hp
        )
    end

    -- Fuel tanks
    if item.fuel_capacity ~= nil then
        table.insert( subtitle,
            item.fuel_capacity
        )
    end

    -- Fuel intake
    if item.fuel_intake_rate ~= nil then
        table.insert( subtitle,
            item.fuel_intake_rate
        )
    end

    -- Self destruct
    if item.damage ~= nil and item.damage_radius ~= nil then
        table.insert( subtitle,
            mw.ustring.format(
                '%s · %s',
                item.damage,
                item.damage_radius
            )
        )
    end

    -- Thrusters
    if item.thrust_capacity ~= nil then
        table.insert( subtitle,
            item.thrust_capacity
        )
    end

    -- Weapon ports
    if item.type == translate( 'WeaponPort' ) then
        table.insert( subtitle,
            mw.ustring.format(
                '%s (S%s – S%s)',
                translate( 'Weapon' ),
                item.min_size or 0,
                item.max_size or 0
            )
        )
    end

    -- Items with Grade and/or Class
    if item.item_grade ~= nil or item.item_class ~= nil then
        local grade_class = ''

        -- TODO can't use lang suffix for subquery properties
        if type( item.item_class ) == 'table' then
            local parts = mw.text.split( item.item_class[ 1 ], ' (', true )
            if #parts == 2 then
                grade_class = parts[ 1 ]
                item.item_class = parts[ 1 ]
            else
                grade_class = grade_class[ 1 ]
                item.item_class = item.item_class[ 1 ]
            end
        end

        if item.item_grade ~= nil and item.item_class ~= nil then
            grade_class = mw.ustring.format( '%s (%s)', item.item_class, item.item_grade )
        elseif item.item_grade ~= nil then
            grade_class = item.item_grade
        end

        table.insert( subtitle,
            grade_class
        )
    end

    -- Tier 2
    -- Info that might affect gameplay but not as important
    if next( subtitle ) == nil then
        -- Position
        if item.position ~= nil then
            if type( item.position ) ~= 'table' then
                item.position = { item.position }
            end
    
            local converted = {}
            for _, position in ipairs( item.position ) do
                table.insert( converted, mw.text.trim( mw.getContentLanguage():ucfirst( mw.ustring.gsub( position, '_', ' ' ) ) ) )
            end

            table.insert( subtitle,
                table.concat( converted, ', ' )
            )
        end
    end

    -- Tier 3
    -- Info that does not affect gameplay
    if next( subtitle ) == nil then
        -- Manufacturer
        if item.manufacturer ~= nil and item.manufacturer ~= 'N/A' then
            table.insert( subtitle,
                mw.ustring.format( '[[%s]]', item.manufacturer )
            )
        end
    end

    -- Return if there are no information at all
    if next( subtitle ) == nil then
        return ''
    end

    return table.concat( subtitle, ' · ' )
end


--- Generate the output
---
--- @param groupedData table Grouped SMW data
--- @return table
function methodtable.makeOutput( self, groupedData )
    local classOutput = {}

    -- An item with potential children
    local function makeEntry( item, depth )
        -- Info if data stems from ship-matrix or game files
        if classOutput.info == nil then
            local text
            if item.from_gamedata == true then
                text = translate( 'msg_from_gamedata' )
            else
                text = translate( 'msg_from_shipmatrix' )
            end

            classOutput.info = hatnote( text, { icon = 'WikimediaUI-Robot.svg' } )
        end

        depth = depth or 1

        local row = mw.html.create( 'div' )
            :addClass( 'template-component' )
            :addClass( mw.ustring.format( 'template-component--level-%d', depth ) )
               :tag( 'div' )
                  :addClass( 'template-component__connectors' )
                      :tag( 'div' ):addClass( 'template-component__connectorX' ):done()
                      :tag( 'div' ):addClass( 'template-component__connectorY' ):done()
              :done()

        local size = 'N/A'
        local prefix = ''

        -- If Ship-Matrix components are not saved to SMW, always output the 'S' prefix
        if item.from_gamedata == nil then
            prefix = 'S'
        else
            if item.from_gamedata == true or
               item.from_gamedata == 1 or
               item.from_gamedata == '1' or -- For uninitialized attributes
               item.class == translate( 'Weapons' )
            then
                prefix = 'S'
            end
        end

        if item.item_size ~= nil then
            size = mw.ustring.format( '%s%s', prefix, item.item_size )
        else
            size = mw.ustring.format( '%s%s', prefix, item.max_size )
        end

        local nodeSizeCount = mw.html.create( 'div' )
            :addClass('template-component__port')
                :tag( 'div' )
                    :addClass( 'template-component__count' )
                    :wikitext( mw.ustring.format( '%dx', item.count ) )
                :done()

        if item.class ~= translate( 'CargoGrid' ) then
            nodeSizeCount
                :tag( 'div' )
                    :addClass( 'template-component__size' )
                        :wikitext( size )
                    :done()
        end

        nodeSizeCount = nodeSizeCount:allDone()

        local name = item.sub_type or item.type
        if item.name ~= nil then
            if config.name_fixes[ item.name ] ~= nil then
                name = mw.ustring.format( '[[%s|%s]]', config.name_fixes[ item.name ], item.name )
            else
                name = mw.ustring.format( '[[%s]]', item.name )
            end

            if item.class_name and item.name == item.sub_type then
                name = mw.ustring.format( '%s<span class="template-component__title-subtext">%s</span>', name, item.class_name )
            end
        end

        local nodeItem = mw.html.create( 'div' )
               :addClass( 'template-component__item' )
                    :tag( 'div' )
                    :addClass( 'template-component__title' )
                    :wikitext( name )
                    :done()
        
        local subtitle = self:makeSubtitle( item )
        if subtitle ~= '' then
            nodeItem:tag( 'div' )
                :addClass( 'template-component__subtitle' )
                :wikitext( subtitle )
        end

        row:tag( 'div' )
           :addClass( 'template-component__card' )
           :node( nodeSizeCount )
           :node( nodeItem )
       :done()

        row = tostring( row )

        if type( item.children ) == 'table' then
            depth = depth + 1
            for _, child in ipairs( item.children ) do
                row = row .. makeEntry( child, depth )
            end
        end

        return row
    end


    -- Items of a given class e.g. avionics
    local function makeSection( types )
        local out = ''

        for classType, items in common.spairs( types ) do
            local label = classType

            -- Label override
            -- Note: This must be manually changed on the data.json page
            if data.section_label_fixes[ classType ] ~= nil then
                label = data.section_label_fixes[ classType ]
            end

            local icon = ''
            if self.iconMap[ classType ] ~= nil then
                icon = mw.ustring.format( '[[%s|20px|link=]]', self.iconMap[ classType ] )
            end

            local section = mw.html.create( 'div' )
                  :addClass( 'template-components__section')
                      :tag( 'div' )
                          :addClass( 'template-components__label' )
                          :wikitext( mw.ustring.format(
                              '%s %s',
                              icon,
                              classType
                          ) )
                      :done()
                      :tag( 'div' ):addClass( 'template-components__group' )

            local str = ''

            for _, item in ipairs( items ) do
                if not item.isChild then
                    local subGroup = mw.html.create( 'div' )
                        :addClass( 'template-components__subgroup' )
                            :node( makeEntry( item ) )
                        :allDone()
                    str = str .. tostring( subGroup )
                end
            end

            out = out .. tostring( section:node( str ):allDone() )
        end

        return out
    end

    for class, types in common.spairs( groupedData ) do
        classOutput[ class ] = makeSection( types )
    end

    mw.logObject( classOutput, '📐 [VehicleHardpoint] makeOutput' )

    return classOutput
end


--- Generates tabber output
function methodtable.out( self )
    local smwData = self:querySmwStore( self.page )

    if smwData == nil then
        return hatnote( TNT.format( 'Module:VehicleHardpoint/i18n.json', 'msg_no_data', self.page ), { icon = 'WikimediaUI-Error.svg' } )
    end

    smwData = self:createDataStructure( smwData )
    smwData = self:group( smwData )

    local output = self:makeOutput( smwData )

    local tabberData = {}

    for i, grouping in ipairs( data.class_groupings ) do
        local key = grouping[ 1 ]
        local groups = grouping[ 2 ]

        local groupContent = ''
        local label = {}

        for _, group in ipairs( groups ) do
            groupContent = groupContent .. ( output[ translate( group ) ] or '' )
            table.insert( label, translate( group ) )
        end

        if #groupContent == 0 then
            groupContent = translate( 'empty_' .. key )
        end

        tabberData[ 'label' .. i ] = table.concat( label, ' & ' )
        tabberData[ 'content' .. i ] = groupContent
    end

    return require( 'Module:Tabber' ).renderTabber( tabberData ) .. mw.getCurrentFrame():extensionTag{
        name = 'templatestyles', args = { src = config.template_styles_page }
    }
end


--- Generates debug output
function methodtable.makeDebugOutput( self )
    local debug = require( 'Module:Common/Debug' )
    self.smwData = nil
    local smwData = self:querySmwStore( self.page )
    local struct = self:createDataStructure( smwData or {} )
    local group = self:group( struct )

    return debug.collapsedDebugSections({
        {
            title = 'SMW Query',
            content = debug.convertSmwQueryObject( makeSmwQueryObject( self.page ) ),
        },
        {
            title = 'SMW Data',
            content = smwData,
            tag = 'pre',
        },
        {
            title = 'Datastructure',
            content = struct,
            tag = 'pre',
        },
        {
            title = 'Grouped',
            content = group,
            tag = 'pre',
        },
        {
            title = 'Output',
            content = self:makeOutput( group ),
            tag = 'pre',
        },
    })
end


--- Manually fix some (sub_)types by checking the hardpoint name
---
--- @param hardpoint table Entry from the api
--- @param fixes table
--- @return table The fixed entry
function VehicleHardpoint.fixTypes( hardpoint, fixes )
    --- Assign key value pairs on a hardpoint
    --- @param kv table Table containing 'key=value' string pairs
    local function assign( kv )
        for _, assignment in pairs( kv ) do
            local parts = mw.text.split( assignment, '=', true )

            if #parts == 2 then
                if mw.ustring.find( parts[ 2 ], '+', 1, true ) then
                    local valueParts = mw.text.split( parts[ 2 ], '+', true )

                    parts[ 2 ] = valueParts[ 1 ] .. ( hardpoint[ valueParts[ 2 ] ] or '' )
                end

                hardpoint[ parts[ 1 ] ] = parts[ 2 ]
            end
        end
    end

    --- Set fixes on a hardpoint if tests evaluate to true
    --- @param tests table
    local function fixHardpoint( tests )
        for _, test in ipairs( tests ) do
            if VehicleHardpoint.evalRule( test[ 'if' ], hardpoint ) then
                local kv = test[ 'then' ]
                if type( kv ) ~= 'table' then
                    kv = { kv }
                end

                assign( kv )
            end
        end
    end

    for _, fix in ipairs( fixes ) do
        if type( fix.type ) == 'table' then
            for _, v in pairs( fix.type ) do
                if v == hardpoint.type then
                    fixHardpoint( fix.modification )
                    break
                end
            end
        elseif type( fix.type ) == 'string' and fix.type == hardpoint.type then
            fixHardpoint( fix.modification )
            break
        end
    end

    -- Manual mapping defined in Module:VehicleHardpoint/Data
    if type( hardpoint.item ) == 'table' and hardpoint.item ~= nil then
        -- If this is a noise launcher, but the class name says decoy, change Noise to Decoy
        if mw.ustring.find( hardpoint.item.name, 'Noise', 1, true ) and mw.ustring.find( hardpoint.class_name, 'decoy', 1, true ) then
            hardpoint.item.name = mw.ustring.gsub( hardpoint.item.name, ' Noise ', ' Decoy ' )
        end

        for _, mapping in pairs( data.hardpoint_type_fixes ) do
            for _, matcher in pairs( data.matches[ mapping ][ 'matches' ] ) do
                if mw.ustring.match( hardpoint.name, matcher ) ~= nil then
                    hardpoint.type = mapping
                    return hardpoint
                end
            end
        end
    end

    return hardpoint
end


--- New Instance
---
--- @return table VehicleHardpoint
function VehicleHardpoint.new( self, page )
    local instance = {
        page = page or nil,
        iconMap = {}
    }

    setmetatable( instance, metatable )

    return instance
end


--- Parser call for generating the table
function VehicleHardpoint.outputTable( frame )
    local args = require( 'Module:Arguments' ).getArgs( frame )
    local page = args[ 1 ] or args[ 'Name' ] or mw.title.getCurrentTitle().text

    local instance = VehicleHardpoint:new( page )
    local out = instance:out()

    local debugOutput = ''
    if args['debug'] ~= nil then
        debugOutput = instance:makeDebugOutput()
    end

    return out .. debugOutput
end


--- Set the hardpoints of the 300i as subobjects to the current page
function VehicleHardpoint.test( frame )
    frame = frame or { args = {} }
    local page = frame.args['Name'] or '70580bce-2347-4e96-9260-dee6394f483d'
    local json = mw.text.jsonDecode( mw.ext.Apiunto.get_raw( 'v2/vehicles/' .. page, {
        include = {
            'hardpoints',
            'parts'
        },
    } ) )

    local hardpoint = VehicleHardpoint:new( page )
    hardpoint:setHardPointObjects( json.data.hardpoints )
    hardpoint:setParts( json.data.parts )
end


--- Evaluates rules from 'data.fixes'
---
--- @param rules table A rules object from data.fixes
--- @param hardpoint table The hardpoint to evaluate
--- @param returnInvalid boolean|nil If invalid rules should be returned beneath the result
--- @return boolean
--- @return table?
function VehicleHardpoint.evalRule( rules, hardpoint, returnInvalid )
    returnInvalid = returnInvalid or false
    local stepVal = {}
    local combination = {}
    local invalidRules = {}

    local function invalidRule( rule, index )
        table.insert( invalidRules, mw.ustring.format( 'Invalid Rule found, skipping: <%s (Element %d)>', rule, index ) )
    end

    for index, rule in ipairs( rules ) do
        if type( rule ) == 'string' then
            -- mw.logObject( mw.ustring.format( 'Evaluating rule %s', rule ), '📐 [VehicleHardpoint] evalRule' )

            if mw.ustring.find( rule, ':', 1, true ) ~= nil then
                local parts = mw.text.split( rule, ':', true )

                -- Simple check if a key equals a value
                if #parts == 2 then
                    local result = hardpoint[ parts[ 1 ] ] == parts[ 2 ]
                    -- mw.logObject( mw.ustring.format( 'Rule <%s == %s>, equates to %s', hardpoint[ parts[ 1 ] ], parts[ 2 ], tostring( result ) ), '📐 [VehicleHardpoint] evalRule' )

                    table.insert( stepVal, result )
                    -- String Match
                elseif #parts == 3 then
                    local key = parts[ 1 ]
                    local fn = parts[ 2 ]

                    -- Remove key and 'match' in order to combine the last parts again
                    table.remove( parts, 1 )
                    table.remove( parts, 1 )

                    local matcher = mw.ustring.lower( table.concat( parts, ':' ) )

                    local result = string[ fn ]( mw.ustring.lower( hardpoint[ key ] ), matcher ) ~= nil
                    -- mw.logObject( mw.ustring.format( 'Rule <%s matches %s>, equates to %s', hardpoint[ key ], matcher, tostring( result ) ), '📐 [VehicleHardpoint] evalRule' )

                    table.insert( stepVal, result )
                else
                    invalidRule( rule, index )
                end
                -- A combination rule
            elseif rule == 'and' or rule == 'or' then
                table.insert( combination, rule )
            end
            -- A sub rule
        elseif type( rule ) == 'table' then
            local matches, invalid = VehicleHardpoint.evalRule( rule, hardpoint )

            table.insert( stepVal, matches )

            for _, v in ipairs( invalid or {} ) do
                table.insert( invalidRules, v )
            end
        else
            -- mw.logObject( 'Is invalid ' .. rule, '📐 [VehicleHardpoint] evalRule' )
            invalidRule( rule, index )
        end
    end

    local ruleMatches = false
    for index, matched in ipairs( stepVal ) do
        if index == 1 then
            ruleMatches = matched
        else
            -- mw.logObject( 'test is ' .. combination[ index - 1 ], '📐 [VehicleHardpoint] evalRule' )
            if combination[ index - 1 ] == 'and' then
                ruleMatches = ruleMatches and matched
            else
                ruleMatches = ruleMatches or matched
            end
        end
    end

    -- mw.logObject( 'Final rule result is ' .. tostring( ruleMatches ), '📐 [VehicleHardpoint] evalRule' )

    if returnInvalid then
        return ruleMatches, invalidRules
    else
        return ruleMatches
    end
end


return VehicleHardpoint
