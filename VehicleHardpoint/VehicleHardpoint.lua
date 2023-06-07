local VehicleHardpoint = {}

local metatable = {}
local methodtable = {}

metatable.__index = methodtable

local TNT = require( 'Module:Translate' ):new()
local common = require( 'Module:Common' ) -- formatNum and spairs
local hatnote = require( 'Module:Hatnote' )._hatnote
local data = mw.loadJsonData( 'Module:VehicleHardpoint/data.json' )


--- Calls TNT with the given key
---
--- @param key string The translation key
--- @param addSuffix boolean Adds a language suffix if data.smw_multilingual_text is true
--- @return string If the key was not found in the .tab page, the key is returned
local function translate( key, addSuffix )
    addSuffix = addSuffix or false
    local success, translation

    local function multilingualIfActive( input )
        if addSuffix and data.smw_multilingual_text == true then
            return string.format( '%s@%s', input, data.module_lang or mw.getContentLanguage():getCode() )
        end

        return input
    end

    if data.module_lang ~= nil then
        success, translation = pcall( TNT.formatInLanguage, data.module_lang, 'Module:VehicleHardpoint/i18n.json', key or '' )
    else
        success, translation = pcall( TNT.format, 'Module:VehicleHardpoint/i18n.json', key or '' )
    end

    if not success or translation == nil then
        return multilingualIfActive( key )
    end

    return multilingualIfActive( translation )
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
    if data.smw_multilingual_text == true then
        langSuffix = '+lang=' .. ( data.module_lang or mw.getContentLanguage():getCode() )
    end

    return {
        string.format(
            '[[-Has subobject::' .. page .. ']][[%s::+]][[%s::+]]',
            translate( 'SMW_HardpointType' ),
            translate( 'SMW_VehicleHardpointsTemplateGroup' )
        ),
        string.format( '?%s#-=from_gamedata', translate( 'SMW_FromGameData' ) ),
        string.format( '?%s#-=count', translate( 'SMW_ItemQuantity' ) ),
        string.format( '?%s#-=min_size', translate( 'SMW_HardpointMinimumSize' ) ),
        string.format( '?%s#-=max_size', translate( 'SMW_HardpointMaximumSize' ) ),
        string.format( '?%s#-=class', translate( 'SMW_VehicleHardpointsTemplateGroup' ) ), langSuffix,
        string.format( '?%s#-=type', translate( 'SMW_HardpointType' ) ), langSuffix,
        string.format( '?%s#-=sub_type', translate( 'SMW_HardpointSubtype' ) ), langSuffix,
        string.format( '?%s#-=name', translate( 'SMW_Name' ) ),
        string.format( '?%s#-n=scu', translate( 'SMW_Inventory' ) ),
        string.format( '?UUID#-=uuid' ),
        string.format( '?%s#-=hardpoint', translate( 'SMW_Hardpoint' ) ) ,
        string.format( '?%s#-=magazine_capacity', translate( 'SMW_MagazineCapacity' ) ),
        string.format( '?%s#-=parent_hardpoint', translate( 'SMW_ParentHardpoint' ) ),
        string.format( '?%s#-=root_hardpoint', translate( 'SMW_RootHardpoint' ) ),
        string.format( '?%s#-=parent_uuid', translate( 'SMW_ParentHardpointUuid' ) ),
        string.format( '?%s#-=icon', translate( 'SMW_Icon' ) ),
        -- These are subquery chains, they require that the 'Name' attribute is of type Page
        -- And that these pages contain SMW attributes
        '?' .. translate( 'SMW_Name' ) .. '.' .. translate( 'SMW_Grade' ) .. '#-=item_grade',
        '?' .. translate( 'SMW_Name' ) .. '.' .. translate( 'SMW_Class' ) .. '#-=item_class',
        '?' .. translate( 'SMW_Name' ) .. '.' .. translate( 'SMW_Size' ) .. '#-=item_size',
        '?' .. translate( 'SMW_Name' ) .. '.' .. translate( 'SMW_Manufacturer' ) .. '#-=manufacturer',
        string.format(
            'sort=%s,%s,%s,%s',
            translate( 'SMW_VehicleHardpointsTemplateGroup' ),
            translate( 'SMW_HardpointType' ),
            translate( 'SMW_HardpointMaximumSize' ),
            translate( 'SMW_ItemQuantity' )
        ),
        'order=asc,asc,asc,asc',
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
            -- Adding the uuid to the key ensures separate boxes if the equipped item differs
            key = row.type .. row.sub_type .. ( row.item.uuid or '' )
        end
    else
        -- If no item is set, use the pre-defined class and type
        key = hardpointData.class .. hardpointData.type
    end

    -- Appends the parent and root hardpoints in order to not mess up child counts
    -- Without this, a vehicle with four turrets containing each one weapon would be listed as
    -- having four turrets that each has four weapons (if the exact weapon is equipped on each turret)
    if parent ~= nil and parent[ translate( 'SMW_Hardpoint' ) ] ~= nil and
       row.type ~= 'Magazine' and
       row.type ~= 'DecoyLauncherMagazine' and
       row.type ~= 'NoiseLauncherMagazine' and
       row.type ~= 'WeaponPort'
    then
        key = key .. parent[ translate( 'SMW_Hardpoint' ) ]
    end

    if root ~= nil and not string.match( key, root ) and ( hardpointData.class == 'Weapons' or hardpointData.class == 'Utility' ) then
        key = key .. root
    end

    if hardpointData.class == 'Weapons' and row.name ~= nil and row.type == 'MissileLauncher' then
        key = key .. row.name
    end

    mw.log( string.format( 'Key: %s', key ) )

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
                if string.match( hardpointType, matcher ) ~= nil then
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
--- @return void
local function addSubComponents( hardpoint )
    if type( hardpoint.item ) ~= 'table' then
        return
    end

    if type( hardpoint.children ) ~= 'table' then
        hardpoint.children = {}
    end

    if hardpoint.item.type == 'WeaponDefensive' or hardpoint.item.type == 'WeaponGun' then
        local item_type = 'Magazine'
        if mw.ustring.sub( hardpoint.class_name, -5 ) == 'Chaff' then
            item_type = 'NoiseLauncherMagazine'
        elseif mw.ustring.sub( hardpoint.class_name, -5 ) == 'Flare' then
            item_type = 'DecoyLauncherMagazine'
        end

        local capacity = {}
        if hardpoint.item.type == 'WeaponGun' and type( hardpoint.item.vehicle_weapon ) == 'table' then
            table.insert( capacity, hardpoint.item.vehicle_weapon.capacity )

            -- This is a laser weapon, add another capacity of -1 to indicate that this weapon has infinite ammo
            if type( hardpoint.item.vehicle_weapon.regeneration ) == 'table' then
                table.insert( capacity, -1 )
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
                name = translate( 'Magazine' ),
                type = item_type,
                sub_type = item_type,
                magazine_capacity = capacity
            }
        } )
    end

    -- This seems to be a weapon rack
    if hardpoint.item.type == 'Usable' and type( hardpoint.item.ports ) == 'table' then
        local item_type = 'WeaponPort'
        for _, port in pairs( hardpoint.item.ports ) do
            local sub_type = item_type .. tostring( port.sizes.min or 0 ) .. tostring( port.sizes.max or 0 )
            local name = 'WeaponPort'

            if mw.ustring.find( port.display_name, 'rifle', 1, true )  then
                name = name .. 'Rifle'
            elseif mw.ustring.find( port.display_name, 'launcher', 1, true )  then
                name = name .. 'Launcher'
            elseif mw.ustring.find( port.display_name, 'pistol', 1, true )  then
                name = name .. 'Pistol'
            elseif mw.ustring.find( port.display_name, 'multitool', 1, true )  then
                name = name .. 'Multitool'
            elseif mw.ustring.find( port.display_name, 'addon', 1, true )  then
                name = name .. 'Addon'
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


--- Builds the object that is saved to SMW as a Subobject
---
--- @param row table - API Data
--- @param hardpointData table - Data from getHardpointData
--- @param parent table|nil - Parent hardpoint
--- @param root string|nil - Root hardpoint
--- @return table
function methodtable.makeObject( self, row, hardpointData, parent, root )
    local object = {}

    if hardpointData == nil then
        hardpointData = self:getHardpointData( row.type or row.name )
    end

    if hardpointData == nil then
        return nil
    end

    object[ translate( 'SMW_Hardpoint' ) ] = row.name
    object[ translate( 'SMW_FromGameData' ) ] = true
    object[ translate( 'SMW_HardpointMinimumSize' ) ] = row.min_size
    object[ translate( 'SMW_HardpointMaximumSize' ) ] = row.max_size
    object[ translate( 'SMW_VehicleHardpointsTemplateGroup' ) ] = translate( hardpointData.class, true )

    if data.matches[ row.type ] ~= nil then
        object[ translate( 'SMW_HardpointType' ) ] = translate( data.matches[ row.type ].type, true )
    else
        object[ translate( 'SMW_HardpointType' ) ] = translate( hardpointData.type, true )
    end

    if data.matches[ row.sub_type ] ~= nil then
        object[ translate( 'SMW_HardpointSubtype' ) ] = translate( data.matches[ row.sub_type ].type, true )
    else
        object[ translate( 'SMW_HardpointSubtype' ) ] = translate( hardpointData.type, true )
    end

    if hardpointData.item ~= nil and type( hardpointData.item.name ) == 'string' then
        object[ translate( 'SMW_Name' ) ] = hardpointData.item.name
    end

    if type( row.item ) == 'table' then
        local itemObj = row.item

        if itemObj.name ~= '<= PLACEHOLDER =>' then
            local match = string.match( row.class_name or '', 'Destruct_(%d+s)')

            if row.type == 'SelfDestruct' and match ~= nil then
                object[ translate( 'SMW_Name' ) ] = string.format( '%s (%s)', translate( 'SMW_SelfDestruct', true ), match )
            else
                object[ translate( 'SMW_Name' ) ] = row.item.name
            end
        end

        object[ translate( 'SMW_MagazineCapacity' ) ] = itemObj.magazine_capacity

        if ( itemObj.type == 'Cargo' or itemObj.type == 'SeatAccess' or itemObj.type == 'CargoGrid' or itemObj.type == 'Container' )
                and type( itemObj.inventory ) == 'table' then
            object[ translate( 'SMW_Inventory' ) ] = common.formatNum( (itemObj.inventory.scu or nil), nil )
        end

        if object[ translate( 'SMW_HardpointMinimumSize' ) ] == nil then
            object[ translate( 'SMW_HardpointMinimumSize' ) ] = itemObj.size
            object[ translate( 'SMW_HardpointMaximumSize' ) ] = itemObj.size
        end

        object[ 'UUID' ] = row.item.uuid
    end

    if parent ~= nil then
        object[ translate( 'SMW_ParentHardpointUuid' ) ] = parent[ 'UUID' ]
        object[ translate( 'SMW_ParentHardpoint' ) ] = parent[ 'Hardpoint' ]
    end

    if root ~= nil and root ~= row.name then
        object[ translate( 'SMW_RootHardpoint' ) ] = root
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
        icon = string.lower( icon )
        object[ translate( 'SMW_Icon' ) ] = string.format( 'File:%s%s.svg', data.icon_prefix, icon )
    end

    -- Remove SeatAccess Hardpoints without storage
    if row.item ~= nil and row.item.type == 'SeatAccess' and object[ translate( 'SMW_Inventory' ) ] == nil then
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
                objects[ key ][ translate( 'SMW_ItemQuantity' ) ] = 1
            end
        else -- This key (object) has been seen before: Increase the quantity and any other cumulative metrics
            objects[ key ][ translate( 'SMW_ItemQuantity' ) ] = objects[ key ][ translate( 'SMW_ItemQuantity' ) ] + 1

            local inventoryKey = translate( 'SMW_Inventory' )
            -- Accumulate the cargo capacities of all cargo grids
            if object[ inventoryKey ] ~= nil then
                objects[ key ][ translate( 'SMW_ItemQuantity' ) ] = 1

                if objects[ key ][ inventoryKey ] ~= nil and object[ inventoryKey ] ~= nil then
                    objects[ key ][ inventoryKey ] = tonumber( objects[ key ][ inventoryKey ], 10 ) + tonumber( object[ inventoryKey ], 10 )
                end
            end
        end
    end


    -- Iterates through the list of hardpoints found on the API object
    local function addHardpoints( hardpoints, parent, root )
        for _, hardpoint in pairs( hardpoints ) do
            hardpoint.name = string.lower( hardpoint.name )

            if depth == 1 then
                root = hardpoint.name
                mw.log( string.format( 'Root: %s', root ) )
            end

            hardpoint = VehicleHardpoint.fixTypes( hardpoint )

            local hardpointData = self:getHardpointData( hardpoint.type or hardpoint.name )

            if hardpointData ~= nil then
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
            end
        end

        depth = depth - 1

        if depth < 1 then
            depth = 1
            root = nil
        end
    end

    addHardpoints( hardpoints )

    mw.logObject( objects )

    for _, subobject in pairs( objects ) do
        mw.smw.subobject( subobject )
    end
end


--- Queries the SMW store for all available hardpoint subobjects for a given page
---
--- @param page string - The page to query
--- @return table hardpoints
function methodtable.querySmwStore( self, page )
    -- Cache multiple calls
    if self.smwData ~= nil then
        return self.smwData
    end

    local smwData = mw.smw.ask( makeSmwQueryObject( page ) )

    if smwData == nil or smwData[ 1 ] == nil then
        return nil
    end

    mw.logObject( smwData )

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

    for _, row in common.spairs( smwData ) do
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

    --mw.logObject( grouped )

    return grouped
end


--- Adds children to the according parents
---
--- @param smwData table All available Hardpoint objects for this page
--- @return table The stratified table
function methodtable.createDataStructure( self, smwData )
    -- Maps a key to the index of the subobject, this way children can be set on their parent
    local idMapping = {}

    for key, object in pairs( smwData ) do
        if object.hardpoint ~= nil then
            local keyMap = ( object.root_hardpoint or object.hardpoint ) .. object.hardpoint

            idMapping[ keyMap ] = key
        end
    end

    -- Iterates through the list of SMW hardpoint subobjects
    -- If the 'parent_hardpoint' key is set (i.e. the hardpoint is a child), it is added as a child to the parent object
    local function stratify( toStratify )
        for _, object in pairs( toStratify ) do
            if object.parent_hardpoint ~= nil then
                local parentEl = toStratify[ idMapping[ ( object.root_hardpoint or '' ) .. object.parent_hardpoint ] ]

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
--- @param item table Item i.e. row from the smw query
--- @return string
function methodtable.makeSubtitle( self, item )
    local subtitle = item.manufacturer or 'N/A'
    if item.manufacturer ~= nil and item.manufacturer ~= 'N/A' then
        subtitle = string.format( '[[%s]]', item.manufacturer )
    end

    -- Show SCU in subtitle
    if item.scu ~= nil then
        -- Fix for german number format
        if string.find( item.scu, ',', 1, true ) then
            item.scu = string.gsub( item.scu, ',', '.' )
        end

        local success, scu = pcall( tonumber, string.gsub( item.scu, ',', '.' ), 10 )
        if success then
            item.scu = scu
        end

        if type( item.scu ) == 'number' then
            if item.type == translate( 'CargoGrid' ) then
                subtitle = item.scu .. ' SCU' or 'N/A'
            elseif item.type == translate( 'PersonalStorage' ) then
                subtitle = item.scu * 1000 .. 'K µSCU' or 'N/A'
            end
        end
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
            grade_class = string.format( '%s (%s)', item.item_class, item.item_grade )
        elseif item.item_grade ~= nil then
            grade_class = item.item_grade
        end

        -- Show the manufacturer if it is not N/A
        if subtitle ~= 'N/A' then
            subtitle = string.format( '%s · %s', grade_class, subtitle )
        else
            subtitle = grade_class
        end
    end

    -- Magazine Capacity
    if item.magazine_capacity ~= nil then
        if type( item.magazine_capacity ) == 'table' then
            subtitle = string.format(
                    '%s/∞ %s',
                    item.magazine_capacity[ 1 ],
                    translate( 'Ammunition' )
            )
        else
            subtitle = string.format(
                '%s/%s %s',
                item.magazine_capacity,
                item.magazine_capacity,
                translate( 'Ammunition' )
            )
        end
    end

    -- Weapon Ports
    if item.type == translate( 'WeaponPort' ) then
        subtitle = string.format(
            '%s (%s - %s)',
            translate( 'Weapon' ),
            item.min_size or 0,
            item.max_size or 0
        )
    end

    return subtitle
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
            :addClass( string.format( 'template-component--level-%d', depth ) )
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
            size = string.format( '%s%s', prefix, item.item_size )
        else
            size = string.format( '%s%s', prefix, item.max_size )
        end

        local nodeSizeCount = mw.html.create( 'div' )
            :addClass('template-component__port')
                :tag( 'div' )
                    :addClass( 'template-component__count' )
                    :wikitext( string.format( '%dx', item.count ) )
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
            if data.name_fixes[ item.name ] ~= nil then
                name = string.format( '[[%s|%s]]', data.name_fixes[ item.name ], item.name )
            else
                name = string.format( '[[%s]]', item.name )
            end
        end

        local nodeItemManufacturer = mw.html.create( 'div' )
               :addClass( 'template-component__item' )
                    :tag( 'div' )
                    :addClass( 'template-component__title' )
                    :wikitext( name )
               :done()
               :tag( 'div' )
                    :addClass( 'template-component__subtitle' )
                    :wikitext( self:makeSubtitle( item )  )
               :done()
               :allDone()

        row:tag( 'div' )
           :addClass( 'template-component__card' )
           :node( nodeSizeCount )
           :node( nodeItemManufacturer )
       :done()

        row = tostring( row )

        if type( item.children ) == 'table' then
            depth = depth + 1
            for _, child in common.spairs( item.children ) do
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
                icon = string.format( '[[%s|20px|link=]]', self.iconMap[ classType ] )
            end

            local section = mw.html.create( 'div' )
                  :addClass( 'template-components__section')
                      :tag( 'div' )
                          :addClass( 'template-components__label' )
                          :wikitext( string.format(
                              '%s %s',
                              icon,
                              classType
                          ) )
                      :done()
                      :tag( 'div' ):addClass( 'template-components__group' )

            local str = ''

            for _, item in common.spairs( items ) do
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

    mw.logObject( classOutput )

    return classOutput
end


--- Generates tabber output
function methodtable.out( self )
    local smwData = self:querySmwStore( self.page )

    if smwData == nil then
        return hatnote( TNT.format( 'Module:VehicleHardpoint/i18n.json)', 'msg_no_data', self.page ), { icon = 'WikimediaUI-Error.svg' } )
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
        name = 'templatestyles', args = { src = data.template_styles_page }
    }
end


--- Generates debug output
function methodtable.makeDebugOutput( self )
    self.smwData = nil
    local smwData = self:querySmwStore( self.page )
    local struct = self:createDataStructure( smwData or {} )
    local group = self:group( struct )

    local query = makeSmwQueryObject( self.page )
    local queryParts = {
        restrictions = {},
        output = {},
        other = {}
    }
    for _, part in ipairs( query ) do
        if string.sub( part, 1, 1 ) == '?' then
            table.insert( queryParts.output, part )
        elseif string.sub( part, 1, 5 ) == '+lang' then
            local index = #queryParts.output
            queryParts.output[ index ] = string.format( '%s|%s', queryParts.output[ index ], part )
        elseif string.sub( part, 1, 2 ) == '[[' then
            table.insert( queryParts.restrictions, mw.getCurrentFrame():callParserFunction( '#tag', { 'nowiki', part } ) )
        elseif #part > 0 and part ~= nil then
            table.insert( queryParts.other, part )
        end
    end
    local queryString = string.format(
            'Restrictions:<pre>%s</pre>Outputs:<pre>%s</pre>Other:<pre>%s</pre>',
            table.concat( queryParts.restrictions, "\n" ),
            table.concat( queryParts.output, "\n"),
            table.concat( queryParts.other, "\n")
    )

    local debugOutput = mw.html.create( 'div' )
        :addClass( 'mw-collapsible' )
        :addClass( 'mw-collapsed' )
        :tag( 'h3' ):wikitext( 'SMW Query' ):done()
        :tag( 'div' ):wikitext( queryString ):done()
        -- SMW Data
        :tag( 'div' ):addClass( 'mw-collapsible' ):addClass( 'mw-collapsed' )
        :tag( 'h3' ):wikitext( 'SMW Data' ):done()
        :tag( 'pre' ):addClass( 'mw-collapsible-content' ):wikitext( mw.dumpObject( smwData ) ):done()
        :done()
        -- Datastructure
        :tag( 'div' ):addClass( 'mw-collapsible' ):addClass( 'mw-collapsed' )
        :tag( 'h3' ):wikitext( 'Datastructure' ):done()
        :tag( 'pre' ):addClass( 'mw-collapsible-content' ):wikitext( mw.dumpObject( struct ) ):done()
        :done()
        -- Grouped
        :tag( 'div' ):addClass( 'mw-collapsible' ):addClass( 'mw-collapsed' )
        :tag( 'h3' ):wikitext( 'Grouped' ):done()
        :tag( 'pre' ):addClass( 'mw-collapsible-content' ):wikitext( mw.dumpObject( group ) ):done()
        :done()
        -- Output
        :tag( 'div' ):addClass( 'mw-collapsible' ):addClass( 'mw-collapsed' )
        :tag( 'h3' ):wikitext( 'Output' ):done()
        :tag( 'pre' ):addClass( 'mw-collapsible-content' ):wikitext( mw.dumpObject( self:makeOutput( group ) ) ):done()
        :done()
        :allDone()

    return tostring( debugOutput )
end


--- Manually fix some (sub_)types by checking the hardpoint name
---
--- @param hardpoint table Entry from the api
--- @return table The fixed entry
function VehicleHardpoint.fixTypes( hardpoint )
    --- Assign key value pairs on a hardpoint
    --- @param kv table Table containing 'key=value' string pairs
    local function assign( kv )
        for _, assignment in pairs( kv ) do
            local parts = mw.text.split( assignment, '=', true )

            if #parts == 2 then
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

    for _, fix in ipairs( data.fixes ) do
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
        for _, mapping in pairs( data.hardpoint_type_fixes ) do
            for _, matcher in pairs( data.matches[ mapping ][ 'matches' ] ) do
                if string.match( hardpoint.name, matcher ) ~= nil then
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
    local page = args[ 1 ] or args[ 'Name' ] or mw.title.getCurrentTitle().rootText

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
    local page = frame.args['Name'] or '300i'
    local json = mw.text.jsonDecode( mw.ext.Apiunto.get_raw( 'v2/vehicles/' .. page, {
        include = {
            'hardpoints',
        },
    } ) )

    local hardpoint = VehicleHardpoint:new( page )
    hardpoint:setHardPointObjects( json.data.hardpoints )
end


--- Evaluates rules from 'data.fixes'
---
--- @param rules table A rules object from data.fixes
--- @param hardpoint table The hardpoint to evaluate
--- @param returnInvalid boolean|nil If invalid rules should be returned beneath the result
--- @return boolean (, table)
function VehicleHardpoint.evalRule( rules, hardpoint, returnInvalid )
    returnInvalid = returnInvalid or false
    local stepVal = {}
    local combination = {}
    local invalidRules = {}

    local function invalidRule( rule, index )
        table.insert( invalidRules, string.format( 'Invalid Rule found, skipping: "%s (Element %d)"', rule, index ) )
    end

    for index, rule in ipairs( rules ) do
        if type( rule ) == 'string' then
            mw.log( string.format( 'Evaluating rule %s', rule ) )

            if string.find( rule, ':', 1, true ) ~= nil then
                local parts = mw.text.split( rule, ':', true )

                -- Simple check if a key equals a value
                if #parts == 2 then
                    local result = hardpoint[ parts[ 1 ] ] == parts[ 2 ]
                    mw.log( string.format( 'Rule "%s == %s", equates to %s', hardpoint[ parts[ 1 ] ], parts[ 2 ], tostring( result ) ) )

                    table.insert( stepVal, result )
                    -- String Match
                elseif #parts == 3 then
                    local key = parts[ 1 ]
                    local fn = parts[ 2 ]

                    -- Remove key and 'match' in order to combine the last parts again
                    table.remove( parts, 1 )
                    table.remove( parts, 1 )

                    local matcher = mw.ustring.lower( table.concat( parts, ':' ) )

                    local result = string[ fn ]( string.lower( hardpoint[ key ] ), matcher ) ~= nil
                    mw.log( string.format( 'Rule "%s matches %s", equates to %s', hardpoint[ key ], matcher, tostring( result ) ) )

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
            mw.log( 'Is invalid ' .. rule )
            invalidRule( rule, index )
        end
    end

    local ruleMatches = false
    for index, matched in ipairs( stepVal ) do
        if index == 1 then
            ruleMatches = matched
        else
            mw.log( 'test is ' .. combination[ index - 1 ])
            if combination[ index - 1 ] == 'and' then
                ruleMatches = ruleMatches and matched
            else
                ruleMatches = ruleMatches or matched
            end
        end
    end

    if returnInvalid then
        return ruleMatches, invalidRules
    else
        return ruleMatches
    end
end


return VehicleHardpoint
