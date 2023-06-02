local VehicleHardPoint = {}

local metatable = {}
local methodtable = {}

metatable.__index = methodtable

local TNT = require( 'Module:TNT' )
local common = require( 'Module:Common' )
local hatnote = require( 'Module:Hatnote' )._hatnote
local data = mw.loadJsonData( 'Module:Manufacturer/data.json' )


-- Local functions

--- Calls TNT with the given key
---
--- @param key string The translation key
--- @return string If the key was not found in the .tab page, the key is returned
local function translate( key )
    local success, translation

    if data.module_lang ~= nil then
        success, translation = pcall( TNT.formatInLanguage, data.module_lang, 'I18n/Module:VehicleHardpoint.tab', key or '' )
    else
        success, translation = pcall( TNT.format, 'I18n/Module:VehicleHardpoint.tab', key or '' )
    end

    if not success or translation == nil then
        return key
    end

    return translation
end


--- Adds a language suffix if data.smw_multilingual_text is true
---
--- @param input string|table The input text(s)
--- @return string|table Data that is understood by SMW
local function multilingualIfActive( input )
    if data.smw_multilingual_text == true then
        return string.format( '%s@%s', input, data.module_lang or mw.getContentLanguage():getCode() )
    end

    return input
end


--- Checks if an entry contains a 'child' key with further entries
---
--- @return boolean
local function hasChildren( row )
    return row.children ~= nil and type( row.children ) == 'table' and #row.children > 0
end


--- Creates a 'key' based on various data points found on the hardpoint and item
--- Based on this key, the count of some entries is generated
---
--- @param row table - API Data
--- @param hardpointData table - Data from getHardpointData
--- @param parent table|nil - Parent hardpoint
--- @param root string|nil - Root hardpoint
--- @return string Key
local function makeKey( row, hardpointData, parent, root )
    local key

    if type( row.item ) == 'table' then
        if row.type == 'ManneuverThruster' or
           row.type == 'MainThruster' or
           row.type == 'WeaponDefensive' or
           row.type == 'WeaponLocker' or
           row.type == 'ArmorLocker' or
           row.type == 'Bed' or
           row.type == 'CargoGrid'
        then
            key = row.type .. row.sub_type
        else
            key = row.type .. row.sub_type .. row.item.uuid
        end
    else
        key = hardpointData.class.de_DE .. hardpointData.type.de_DE
    end

    if row.type ~= 'WeaponDefensive' then
        if parent ~= nil then
            key = key .. parent[ 'Hardpoint' ]
        end

        if root ~= nil and not string.match( key, root ) and ( hardpointData.class.de_DE == 'Bewaffnung' ) then
            key = key .. root
        end
    end

    if hardpointData.class.de_DE == 'Bewaffnung' and row.name ~= nil and row.type == 'MissileLauncher' then
        key = key .. row.name
    end

    mw.log(string.format('Key: %s', key))
    return key
end



--- Get pre-defined hardpoint data for a given hardpoint type or name
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


--- Creates a settable SMW Subobject
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
    object[ translate( 'SMW_VehicleHardpointsTemplateGroup' ) ] = multilingualIfActive( translate( hardpointData.class ) )

    if data.hardPointNames[ row.type ] ~= nil then
        object[ translate( 'SMW_HardpointType' ) ] = multilingualIfActive( translate( data.matches[ row.type ].type ) )
    else
        object[ translate( 'SMW_HardpointType' ) ] = multilingualIfActive( translate( hardpointData.type ) )
    end

    if data.hardPointNames[ row.sub_type ] ~= nil then
        object[ translate( 'SMW_HardpointSubtype' ) ] = multilingualIfActive( translate( data.matches[ row.sub_type ].type ) )
    else
        object[ translate( 'SMW_HardpointSubtype' ) ] = multilingualIfActive( translate( hardpointData.type ) )
    end

    if hardpointData.item ~= nil then
        if type( hardpointData.item.name ) == 'string' then object[ translate( 'SMW_Name' ) ] = hardpointData.item.name end
    end

    if type( row.item ) == 'table' then
        local itemObj = row.item
        if itemObj.name ~= '<= PLACEHOLDER =>' then
            local match = string.match( row.class_name or '', 'Destruct_(%d+s)')
            if row.type == 'SelfDestruct' and match ~= nil then
                object[ translate( 'SMW_Name' ) ] = string.format( '%s (%s)', translate( 'SMW_SelfDestruct' ), match )
            else
                object[ translate( 'SMW_Name' ) ] = row.item.name
            end
        end

        if itemObj.type == 'WeaponDefensive' and type( itemObj.counter_measure ) == 'table' then
            object[ translate( 'SMW_MagazineCapacity' ) ] = itemObj.counter_measure.capacity
        end

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

    -- Remove SeatAccess Hardpoints without storage
    if row.item ~= nil and row.item.type == 'SeatAccess' and object[ translate( 'SMW_Inventory' ) ] == nil then
        object = nil
    end

    return object;
end


--- Sets all available hardpoints as sub-objects
--- This is the main method called by others
---
--- @param hardpoints table API Hardpoint data
function methodtable.setHardPointObjects( self, hardpoints )
    if type( hardpoints ) ~= 'table' then
        error( translate( 'msg_invalid_hardpoints_object' ) )
    end

    local out = {}

    local function addToOut( object, key )
        if object == nil then
            return
        end

        if type( out[ key ] ) ~= 'table' then
            if object ~= nil then
                out[ key ] = object
                out[ key ][ translate( 'SMW_ItemQuantity' ) ] = 1
            end
        else
            out[ key ][ translate( 'SMW_ItemQuantity' ) ] = out[ key ][ translate( 'SMW_ItemQuantity' ) ] + 1

            if type( out[ key ][ translate( 'SMW_MagazineCapacity' ) ] ) == 'number' then
                out[ key ][ translate( 'SMW_MagazineCapacity' ) ] = out[ key ][ translate( 'SMW_MagazineCapacity' ) ] + object[ translate( 'SMW_MagazineCapacity' ) ]
            end

            for _, value in pairs( object[ translate( 'SMW_HardpointType' ) ] ) do
                if value == multilingualIfActive( translate( 'SMW_CargoGrid' ) ) then
                    out[ key ][ translate( 'SMW_ItemQuantity' ) ] = 1
                    if out[ key ][ translate( 'SMW_Inventory' ) ] ~= nil and object[ translate( 'SMW_Inventory' ) ] ~= nil then
                        out[ key ][ translate( 'SMW_Inventory' ) ] = tonumber( out[ key ][ translate( 'SMW_Inventory' ) ] ) + tonumber( object[ translate( 'SMW_Inventory' ) ] )
                    end
                end
            end
        end
    end

    local depth = 1

    local function addHardpoints( hardpoints, parent, root )
        for _, hardpoint in pairs( hardpoints ) do
            hardpoint.name = string.lower( hardpoint.name )

            if depth == 1 then
                root = hardpoint.name
                mw.log(string.format('Root: %s', root))
            end

            hardpoint = VehicleHardPoint.fixTypes( hardpoint )

            local hardpointData = self:getHardpointData( hardpoint.type or hardpoint.name )

            if hardpointData ~= nil then
                local key = makeKey( hardpoint, hardpointData, parent, root )

                local obj = self:makeObject( hardpoint, hardpointData, parent, root )

                addToOut( obj, key )

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

    mw.logObject(out)

    for _, subobject in pairs( out ) do
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

    local langSuffix = ''
    if data.smw_multilingual_text == true then
        langSuffix = '+lang=' .. ( data.module_lang or mw.getContentLanguage():getCode() )
    end

    local smwData = mw.smw.ask( {
        string.format(
            '[[-Has subobject::' .. page .. ']][[%s::+]][[%s::+]]',
            translate( 'SMW_HardpointType' ),
            translate( 'SMW_VehicleHardpointsTemplateGroup' )
        ),
        string.format( '?%s#-=from_gamedata', translate( 'SMW_FromGameData' ) ),
        string.format( '?%s#-=count', translate( 'SMW_ItemQuantity' ) ),
        string.format( '?%s#-=min_size', translate( 'SMW_HardpointMinimumSize' ) ),
        string.format( '?%s#-=max_size', translate( 'SMW_HardpointMaximumSize' ) ),
        string.format( '?%s=class', translate( 'SMW_VehicleHardpointsTemplateGroup' ) ), langSuffix,
        string.format( '?%s=type', translate( 'SMW_HardpointType' ) ), langSuffix,
        string.format( '?%s=sub_type', translate( 'SMW_HardpointSubType' ) ), langSuffix,
        string.format( '?%s#-=name', translate( 'SMW_Name' ) ),
        string.format( '?%s-n=scu', translate( 'SMW_Inventory' ) ),
        string.format( '?UUID#-=uuid'),
        string.format( '?%s#-=hardpoint', translate( 'SMW_Hardpoint' ) ) ,
        string.format( '?%s#-=magazine_size', translate( 'SMW_MagazineCapacity' ) ),
        string.format( '?%s#-=parent_hardpoint', translate( 'SMW_ParentHardpoint' ) ),
        string.format( '?%s#-=root_hardpoint', translate( 'SMW_RootHardpoint' ) ),
        string.format( '?%s#-=parent_uuid', translate( 'SMW_ParentHardpointUuid' ) ),
        '?Name.' .. translate( 'SMW_Grade' ) .. '#-=item_grade',
        '?Name.' .. translate( 'SMW_Class' ) .. '#-=item_class',
        '?Name.' .. translate( 'SMW_Size' ) .. '#-=item_size',
        '?Name.' .. translate( 'SMW_Manufacturer' ) .. '#-=manufacturer',
        string.format(
            'sort=%s,%s,%s,%s',
            translate( 'SMW_VehicleHardpointsTemplateGroup' ),
            translate( 'SMW_HardpointType' ),
            translate( 'SMW_HardpointMaximumSize' ),
            translate( 'SMW_ItemQuantity' )
        ),
        'order=asc,asc,asc,asc',
        'limit=1000'
    } )

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
        if not row.isChild and row.class ~= nil and row.type ~= nil then
            if type( grouped[ row.class ] ) ~= 'table' then
                grouped[ row.class ] = {}
            end

            if type( grouped[ row.class ][ row.type ] ) ~= 'table' then
                grouped[ row.class ][ row.type ] = {}
            end

            table.insert( grouped[ row.class ][ row.type ], row )
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
    -- Maps object id to key in array
    local idMapping = {}

    for key, object in pairs( smwData ) do
        if object.hardpoint ~= nil then
            local keyMap = ( object.root_hardpoint or object.hardpoint ) .. object.hardpoint

            idMapping[ keyMap ] = key
        end
    end

    local function stratify( toStratify )
        for _, object in pairs( toStratify ) do
            if object.parent_hardpoint ~= nil then
                local parentEl = toStratify[ idMapping[ (object.root_hardpoint or '') .. object.parent_hardpoint ] ]

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

    stratify( smwData )

    return smwData
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

        if item.magazine_size ~= nil then
            item.count = item.magazine_size
        end

        local size = 'N/A'
        local prefix = ''

        if item.from_gamedata == true or item.class == translate( 'Weapons' ) then
            prefix = 'S'
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
            if data.nameFixes[ item.name ] ~= nil then
                name = string.format( '[[%s|%s]]', data.nameFixes[ item.name ], item.name )
            else
                name = string.format( '[[%s]]', item.name )
            end
        end

        local subtitle = item.manufacturer or 'N/A'
        if item.manufacturer ~= nil and item.manufacturer ~= 'N/A' then
            subtitle = string.format( '[[%s]]', item.manufacturer )
        end

        -- Show SCU in subtitle
        if item.scu ~= nil then
            if item.type == 'Cargo grid' then
                subtitle = item.scu .. ' SCU' or 'N/A'
            elseif item.type == 'Personal storage' then
                subtitle = item.scu * 1000 .. 'K µSCU'  or 'N/A'
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
                    :wikitext( subtitle  )
               :done()
               :allDone()

        row:tag('div')
           :addClass('template-component__card')
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
            if data.section_label_fixes[ classType ] ~= nil then
                label = data.section_label_fixes[ classType ]
            end

            local icon = string.format( '[[File:%s %s.svg|20px|link=]]', data.icon_prefix, string.lower( label ) )
            -- Disable label missing icons for now
            for _, labelMissingIcon in pairs( data.missing_icons ) do
                if label == labelMissingIcon then icon = '' end
            end


            local section = mw.html.create( 'div' )
                  :addClass( 'template-components__section')
                      :tag( 'div' )
                          :addClass( 'template-components__label' )
                          :wikitext( string.format(
                              '%s %s',
                              icon,
                              translate( classType )
                          ) )
                      :done()
                      :tag( 'div' ):addClass( 'template-components__group' )

            local str = ''

            for _, item in common.spairs( items ) do
                if not item.isChild then
                    local subGroup = mw.html.create('div')
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

    mw.logObject(classOutput)

    return classOutput
end


--- Generates tabber output
function methodtable.out( self )
    local smwData = self:querySmwStore( self.page )

    if smwData == nil then
        return hatnote( 'SMW data not found on [[' .. self.page .. ']].', { icon = 'WikimediaUI-Error.svg' } )
    end

    smwData = self:createDataStructure( smwData )
    smwData = self:group( smwData )

    local output = self:makeOutput( smwData )

    local tabberData = {}

    local i = 1
    for key, groups in common.spairs( data.class_grouping ) do
        local groupContent = ''

        for _, group in pairs( groups ) do
            groupContent = groupContent .. output( translate( group ) or '' )
        end

        if #groupContent == 0 then
            groupContent = 'No X found'
        end

        tabberData[ 'label' .. i ] = translate( key )
        tabberData[ 'content' .. i ] = groupContent

        i = i + 1
    end

    return require( 'Module:Tabber' ).renderTabber( tabberData ) .. mw.getCurrentFrame():extensionTag{
        name = 'templatestyles', args = { src = data.template_styles_page }
    }
end


--- Manually fix some (sub_)types by checking the hardpoint name
---
--- @param hardpoint table Entry from the api
--- @return table The fixed entry
function VehicleHardPoint.fixTypes( hardpoint )
    if hardpoint.type == 'ManneuverThruster' or hardpoint.type == 'MainThruster' then
        if ( hardpoint.sub_type == 'FixedThruster' or hardpoint.sub_type == 'UNDEFINED' ) and
                string.match( string.lower( hardpoint.name ), 'vtol' ) ~= nil then
            hardpoint.sub_type = 'VtolThruster'
        end

        if ( hardpoint.sub_type == 'FixedThruster' or hardpoint.sub_type == 'UNDEFINED' ) and
                string.match( string.lower( hardpoint.name ), 'retro' ) ~= nil then
            hardpoint.sub_type = 'RetroThruster'
        end

        if ( hardpoint.sub_type == 'FixedThruster' or hardpoint.sub_type == 'UNDEFINED' ) and
                string.match( string.lower( hardpoint.name ), 'retro' ) ~= nil then
            hardpoint.sub_type = 'RetroThruster'
        end

        if ( hardpoint.sub_type == 'JointThruster' or hardpoint.sub_type == 'UNDEFINED' ) and
                string.match( string.lower( hardpoint.name ), 'grav' ) ~= nil then
            hardpoint.sub_type = 'GravLev'
        end

        if hardpoint.type == 'MainThruster' then
            hardpoint.sub_type = 'Main' .. hardpoint.sub_type
        end
    end

    if hardpoint.type == 'WeaponDefensive' then
        if ( hardpoint.sub_type == 'CountermeasureLauncher' or hardpoint.sub_type == 'UNDEFINED' ) and
                ( string.match( string.lower( hardpoint.class_name ), 'decoy' ) ~= nil or
                        string.match( string.lower( hardpoint.class_name ), 'flare' ) ~= nil) then
            hardpoint.sub_type = 'DecoyLauncher'
        end

        if ( hardpoint.sub_type == 'CountermeasureLauncher' or hardpoint.sub_type == 'UNDEFINED' ) and
                ( string.match( string.lower( hardpoint.class_name ), 'chaff' ) ~= nil  or
                        string.match( string.lower( hardpoint.class_name ), 'noise' ) ~= nil) then
            hardpoint.sub_type = 'NoiseLauncher'
        end

        if type( hardpoint.item ) == 'table' and hardpoint.item ~= nil then
            hardpoint.item.name = '<= PLACEHOLDER =>'
        end
    end

    if hardpoint.type == 'FuelTank' or hardpoint.type == 'QuantumFuelTank' then
        local prefix = ''
        if hardpoint.type == 'QuantumFuelTank' then
            prefix = 'Quantum'
        end

        if string.match( string.lower( hardpoint.class_name ), 'small' ) ~= nil then
            hardpoint.sub_type = prefix .. 'FuelTankSmall'
        end

        if string.match( string.lower( hardpoint.class_name ), 'large' ) ~= nil then
            hardpoint.sub_type = prefix .. 'FuelTankLarge'
        end
    end

    if hardpoint.type == 'Turret' then
        --- Gimbal mount
        if hardpoint.sub_type == 'GunTurret' and string.match( string.lower( hardpoint.class_name ), 'mount_gimbal' ) ~= nil then
            hardpoint.type = 'WeaponGun'
            hardpoint.sub_type = 'GimbalMount'
            -- Pilot controllable weapon (e.g. F7CM, Mustang Delta)
        elseif hardpoint.sub_type == 'BallTurret' or hardpoint.sub_type == 'CanardTurret' then
            hardpoint.type = 'WeaponGun'
            -- Reclaimer remote salvage turret
        elseif hardpoint.sub_type == 'Utility' and string.match( string.lower( hardpoint.class_name ), 'salvage' ) ~= nil then
            hardpoint.type = 'UtilityTurret'
            hardpoint.sub_type = 'GunTurret'
            -- Fix remote turret designation
        elseif hardpoint.sub_type == 'Turret' and string.match( string.lower( hardpoint.class_name ), 'remote' ) ~= nil then
            hardpoint.sub_type = 'RemoteTurret'
        end
    end

    if hardpoint.type == 'ToolArm' then
        if hardpoint.sub_type == 'UNDEFINED' then
            if string.match( string.lower( hardpoint.class_name ), 'mining' ) ~= nil then
                hardpoint.sub_type = 'MiningArm'
            elseif string.match( string.lower( hardpoint.class_name ), 'salvage' ) ~= nil then
                hardpoint.sub_type = 'SalvageArm'
            end
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
--- @return table VehicleHardPoint
function VehicleHardPoint.new( self, page )
    local instance = {
        page = page or nil,
    }

    setmetatable( instance, metatable )

    return instance
end



--- Parser call for generating the table
function VehicleHardPoint.outputTable( frame )
    local args = require( 'Module:Arguments' ).getArgs( frame )
    local page = args[ 1 ] or args[ 'Name' ] or mw.title.getCurrentTitle().rootText

    local instance = VehicleHardPoint:new( page )

    if args['debug'] ~= nil then
        local smwData = instance:querySmwStore(page)
        local struct = instance:createDataStructure( smwData )
        local group = instance:group( struct )
        return mw.dumpObject(smwData) .. mw.dumpObject(struct) .. mw.dumpObject(group)
    end
    return instance:out()
end


return VehicleHardPoint
