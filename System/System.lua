local System = {}

local Array = require('Module:Array')
local Starmap = require('Module:Starmap')
local Infobox = require('Module:InfoboxNeue')
local TNT = require('Module:Translate'):new()
local config = mw.loadJsonData('Module:System/config.json')

local lang
if config['module_lang'] then
    lang = mw.getLanguage(config['module_lang'])
else
    lang = mw.getContentLanguage()
end
local langCode = lang:getCode()

--- Wrapper function for Module:Translate.translate
-- @param key string The translation key
-- @param addSuffix boolean Adds a language suffix if config.smw_multilingual_text is true
-- @return string If the key was not found in the .tab page, the key is returned
local function t(key, addSuffix, ...)
    return TNT:translate('Module:System/i18n.json', config, key, addSuffix, {...}) or key
end

--- Remove parentheses and their content
local function removeParentheses(inputString)
    return string.match(string.gsub(inputString, '%b()', ''), '^%s*(.*%S)') or ''
end

--- Alternative for doing table[key][key], this returns nil instead of an error if it doesn't exist
-- @param table object
local function e(object, ...)
    local value = object
    if not value then
        return
    end
    for _, key in ipairs({...}) do
        value = value[key]
        if value == nil then
            return nil
        end
    end
    return value
end

--- Does string end with x
-- @param str string
-- @param suffix string
-- @return boolean
local function endsWith(str, suffix)
    return string.sub(str, -string.len(suffix)) == suffix
end

--- Does string start with x
-- @param str string
-- @param prefix string
-- @return boolean
local function startsWith(str, prefix)
    return string.sub(str, 1, string.len(prefix)) == prefix
end

--- Filter table
-- @param array table
-- @param key string
-- @param value any
-- @param zero any Value to return if zero matches
local function filter(array, key, value, zero)
    local matches = {}
    if array then
        for _, item in ipairs(array) do
            if item[key] == value then
                table.insert(matches, item)
            end
        end
    end
    if zero and #matches == 0 then
        return zero
    else
        return matches
    end
end

--- Split a string with seperator
-- @param str string Input
-- @param sep string Seperator
local function split(str, sep)
    local matches = {}
    for str in string.gmatch(str, '([^' .. sep .. ']+)') do
        table.insert(matches, string.gsub(str, '%b()', '') or '')
    end
    return matches
end

--- If but inline
-- @param condition boolean
-- @param truthy any What to return if true
-- @param falsy any What to return if false
local function inlineIf(condition, truthy, falsy)
    if not not condition then
        return truthy
    else
        return falsy
    end
end

-- @param categories table Plain text categories in array
local function convertCategories(categories)
    local mapped = {}
    for _, category in pairs(categories) do
        if category ~= nil then
            if string.sub(category, 1, 2) ~= '[[' then
                category = string.format('[[Category:%s]]', category)
            end

            table.insert(mapped, category)
        end
    end
    return table.concat(mapped)
end

--- Bypass for a bug
local function cuteArray(array)
    local newArray = {}
    for _, val in ipairs(array) do
        table.insert(newArray, val)
    end
    return newArray
end

-- @param frame table https://www.mediawiki.org/wiki/Extension:Scribunto/Lua_reference_manual#Frame_object
function System.main(frame)
    local args = frame:getParent().args
    local infobox = Infobox:new({
        placeholderImage = config['placeholder_image']
    })

    --- The idea of this mega table is to get all data, then set it in the infobox, better organization.
    local mega = {
        ['image'] = nil,
        ['name'] = nil,
        ['#name'] = nil,
        ['code'] = nil,
        ['system'] = {},
        ['type'] = nil,
        ['#type'] = nil,
        ['size'] = nil,
        ['#size'] = nil,
        ['status'] = nil,
        ['#status'] = nil,
        ['system_objects'] = {},
        ['star_types'] = {},
        ['#star_types'] = nil,
        ['affiliation'] = {},
        ['#affiliation'] = nil,
        ['#population'] = nil,
        ['planet_count'] = nil,
        ['satellite_count'] = nil,
        ['asteroid_belt_count'] = nil,
        ['asteroid_field_count'] = nil,
        ['anomaly_count'] = nil,
        ['station_count'] = nil,
        ['jumppoint_count'] = nil,
        ['blackhole_count'] = nil,
        ['poi_count'] = nil,
        ['sensor_danger'] = nil,
        ['sensor_economy'] = nil,
        ['sensor_population'] = nil,
        ['discovered_in'] = nil,
        ['discovered_by'] = nil,
        ['historical_names'] = {},
        ['#historical_names'] = nil,
        ['starmap_link'] = nil,
        ['starmap_id'] = nil,
        ['cornerstone_link'] = nil,
        ['categories'] = {}
    }

    table.insert(mega['categories'], 'Systems') -- Default category for systems

    mega['image'] = args['image']
    mega['name'] = args['name']
    mega['code'] = args['code']
    if mega['name'] == nil and mega['code'] == nil then
        return infobox:renderInfobox(infobox:renderMessage({
            title = t('error_title'),
            desc = t('error_invalid_args_desc')
        }))
    end

    mega['system'] = Starmap.findStructure('system', mega['code'] or mega['name']) or {}
    if mega['system'] ~= nil then
        if mega['name'] == nil then
            mega['name'] = removeParentheses(mega['system']['name'])
        end
        mega['code'] = mega['system']['code']
    end

    mega['#name'] = mega['name']
    --- Add ' system' to end of `#name`
    if endsWith(mega['#name'], ' system') == false then
        mega['#name'] = mega['#name'] .. ' system'
    end

    mega['type'] = args['type'] or mega['system']['type']
    if mega['type'] ~= nil then
        mega['#type'] = t('val_type_' .. string.lower(mega['type']))
        table.insert(mega['categories'], mega['#type'] .. ' Systems')
    end

    mega['size'] = args['size'] or mega['system']['aggregated_size']
    if mega['size'] ~= nil and tonumber(mega['size']) then
        mega['size'] = tonumber(mega['size'])
        mega['#size'] = tostring(mega['size']) .. ' AU'
    else
        mega['#size'] = '? AU'
    end

    mega['status'] = args['status'] or mega['system']['status']
    if mega['status'] ~= nil then
        mega['#status'] = t('val_status_' .. string.lower(mega['status']))
    end

    mega['system_objects'] = Starmap.systemObjects(mega['code'] or mega['name'])

    mega['star_types'] = args['startypes']
    if mega['star_types'] then
        mega['star_types'] = split(mega['star_types'], ', ')
    elseif mega['system_objects'] then
        mega['star_types'] = {}
        for _, star in ipairs(filter(mega['system_objects'], 'type', 'STAR')) do
            if star['subtype'] then
                table.insert(mega['star_types'],
                    config['subtype_rename'][star['subtype']['name']] or star['subtype']['name'])
            end
        end
    else
        mega['star_types'] = {} -- Revert back to default
    end
    mega['#star_types'] = table.concat(mega['star_types'], ', ')

    if args['affiliation'] then
        mega['affiliation'] = split(args['affiliation'], ', ')
    elseif e(mega, 'system', 'affiliation') ~= nil then
        mega['affiliation'] = {}
        for _, empire in ipairs(mega['system']['affiliation']) do
            table.insert(mega['affiliation'], empire['name'])
        end
    end
    if mega['affiliation'][1] then
        table.insert(mega['categories'], mega['affiliation'][1] .. ' Systems')
    end
    mega['#affiliation'] = {}
    for _, name in ipairs(mega['affiliation']) do
        table.insert(mega['#affiliation'], string.format('[[%s]]', name))
    end
    mega['#affiliation'] = table.concat(mega['#affiliation'], ', ')

    mega['#population'] = args['population']

    mega['planet_count'] = args['planets'] or #filter(mega['system_objects'], 'type', 'PLANET', nil)
    mega['satellite_count'] = args['satellites'] or #filter(mega['system_objects'], 'type', 'SATELLITE', nil)
    mega['asteroid_belt_count'] = args['asteroidbelts'] or #filter(mega['system_objects'], 'type', 'ASTEROID_BELT', nil)
    mega['asteroid_fields_count'] = args['asteroidfields'] or
                                        #filter(mega['system_objects'], 'type', 'ASTEROID_FIELDS', nil)
    mega['anomaly_count'] = args['anomalies'] or #filter(mega['system_objects'], 'type', 'ANOMALY', nil)
    mega['station_count'] = args['stations'] or #filter(mega['system_objects'], 'type', 'MANMADE', nil)
    mega['jumppoint_count'] = args['jumppoints'] or #filter(mega['system_objects'], 'type', 'JUMPPOINT', nil)
    mega['blackholes_count'] = args['blackholes'] or #filter(mega['system_objects'], 'type', 'BLACKHOLE', nil)
    mega['poi_count'] = args['pois'] or #filter(mega['system_objects'], 'type', 'POI', nil)

    mega['sensor_danger'] = args['sensordanger'] or e(mega['system']['aggregated_danger'])
    if mega['sensor_danger'] ~= nil and mega['sensor_danger'] ~= 0 then
        mega['sensor_danger'] = tonumber(mega['sensor_danger'])
        mega['#sensor_danger'] = tostring(mega['sensor_danger']) .. '/10'
    else
        mega['sensor_danger'] = nil
    end

    mega['sensor_economy'] = args['sensoreconomy'] or e(mega['system']['aggregated_economy'])
    if mega['sensor_economy'] ~= nil and mega['sensor_economy'] ~= 0 then
        mega['sensor_economy'] = tonumber(mega['sensor_economy'])
        mega['#sensor_economy'] = tostring(mega['sensor_economy']) .. '/10'
    else
        mega['sensor_danger'] = nil
    end

    mega['sensor_population'] = args['sensorpopulation'] or e(mega['system']['aggregated_population'])
    if mega['sensor_population'] ~= nil and mega['sensor_population'] ~= 0 then
        mega['sensor_population'] = tonumber(mega['sensor_population'])
        mega['#sensor_population'] = tostring(mega['sensor_population']) .. '/10'
    else
        mega['sensor_population'] = nil
    end

    mega['discovered_in'] = args['discoveredin']
    mega['discovered_by'] = args['discoveredby']
    mega['historical_names'] = args['historicalnames']
    if mega['historical_names'] then
        mega['historical_names'] = split(mega['historical_names'], ', ')
        mega['#historical_names'] = table.concat(mega['historical_names'], ', ')
    else
        mega['historical_names'] = {} -- Revert back to default
    end

    mega['starmap_link'] = args['starmap']
    if mega['starmap_link'] == nil and mega['code'] then
        mega['starmap_link'] = Starmap.link(mega['code'])
    end
    mega['starmap_id'] = e(mega, 'system', 'id')
    mega['cornerstone_link'] = args['cornerstone']
    if mega['cornerstone_link'] == nil and Array.contains(cuteArray(config['cornerstone_systems']), mega['code']) then
        mega['cornerstone_link'] = string.format(config['cornerstone'], mega['name'])
    end

    infobox:renderImage(mega['image'])
    infobox:renderHeader({
        title = mega['#name'],
        subtitle = mega['#affiliation']
    })
    infobox:renderSection({
        content = {infobox:renderItem({
            label = t('lbl_type'),
            data = mega['#type']
        }), infobox:renderItem({
            label = t('lbl_size'),
            data = mega['#size']
        }), infobox:renderItem({
            label = t('lbl_status'),
            data = mega['#status']
        }), infobox:renderItem({
            label = inlineIf(#mega['star_types'] == 1, t('lbl_star_type'), t('lbl_star_types')),
            data = mega['#star_types']
        }), infobox:renderItem({
            label = t('lbl_population'),
            data = mega['#population']
        })},
        col = 2
    })
    infobox:renderSection({
        title = t('lbl_astronomical_objects'),
        content = {infobox:renderItem({
            label = t('lbl_planets'),
            data = inlineIf((mega['planet_count'] or nil) ~= 0, mega['planet_count'] or nil, nil)
        }), infobox:renderItem({
            label = t('lbl_satellites'),
            data = inlineIf((mega['satellite_count'] or nil) ~= 0, mega['satellite_count'] or nil, nil)
        }), infobox:renderItem({
            label = t('lbl_asteroid_belts'),
            data = inlineIf((mega['asteroid_belt_count'] or nil) ~= 0, mega['asteroid_belt_count'] or nil, nil)
        }), infobox:renderItem({
            label = t('lbl_asteroid_fields'),
            data = inlineIf((mega['asteroid_field_count'] or nil) ~= 0, mega['asteroid_field_count'] or nil, nil)
        }), infobox:renderItem({
            label = t('lbl_anomalies'),
            data = inlineIf((mega['anomaly_count'] or nil) ~= 0, mega['anomaly_count'] or nil, nil)
        }), infobox:renderItem({
            label = t('lbl_stations'),
            data = inlineIf((mega['station_count'] or nil) ~= 0, mega['station_count'] or nil, nil)
        }), infobox:renderItem({
            label = t('lbl_jump_points'),
            data = inlineIf((mega['jumppoint_count'] or nil) ~= 0, mega['jumppoint_count'] or nil, nil)
        }), infobox:renderItem({
            label = t('lbl_blackholes'),
            data = inlineIf((mega['blackhole_count'] or nil) ~= 0, mega['blackhole_count'] or nil, nil)
        }), infobox:renderItem({
            label = t('lbl_pois'),
            data = inlineIf((mega['poi_count'] or nil) ~= 0, mega['poi_count'] or nil, nil)
        })},
        col = 3
    })
    if mega['sensor_danger'] ~= 0 and mega['sensor_economy'] ~= 0 and mega['sensor_population'] ~= 0 then
        infobox:renderSection({
            title = t('lbl_sensors'),
            content = {infobox:renderItem({
                label = t('lbl_sensor_danger'),
                data = mega['#sensor_danger']
            }), infobox:renderItem({
                label = t('lbl_sensor_economy'),
                data = mega['#sensor_economy']
            }), infobox:renderItem({
                label = t('lbl_sensor_population'),
                data = mega['#sensor_population']
            })},
            col = 3
        })
    end
    infobox:renderSection({
        title = t('lbl_history'),
        content = {infobox:renderItem({
            label = t('lbl_discovered_in'),
            data = mega['discovered_in']
        }), infobox:renderItem({
            label = t('lbl_discovered_by'),
            data = mega['discovered_by']
        }), infobox:renderItem({
            label = inlineIf(#mega['historical_names'] == 1, t('lbl_historical_name'), t('lbl_historical_names')),
            data = mega['#historical_names']
        })},
        col = 2
    })
    infobox:renderFooter({
        content = {infobox:renderItem({
            label = t('lbl_starmap_id'),
            data = mega['starmap_id'],
            row = true,
            spacebetween = true
        }), infobox:renderItem({
            label = t('lbl_starmap_code'),
            data = mega['code'],
            row = true,
            spacebetween = true
        })},
        button = {
            icon = 'WikimediaUI-Globe.svg',
            label = t('lbl_other_sites'),
            type = 'popup',
            content = infobox:renderSection({
                content = {infobox:renderItem({
                    label = t('lbl_official_sites'),
                    data = infobox:renderLinkButton({
                        label = t('lbl_starmap'),
                        link = mega['starmap_link']
                    })
                }), infobox:renderItem({
                    label = t('lbl_community_sites'),
                    data = infobox:renderLinkButton({
                        label = t('lbl_cornerstone'),
                        link = mega['cornerstone_link']
                    })
                })},
                class = 'infobox__section--linkButtons'
            }, true)
        }
    })

    mw.smw.set({
        [t('lbl_starmap_id')] = mega['starmap_id'],
        [t('lbl_starmap_code')] = mega['code'],
        [t('lbl_system_type')] = mega['type'],
        [t('lbl_system_size')] = mega['size'],
        [t('lbl_system_status')] = mega['status'],
        [t('lbl_star_type')] = mega['star_types']
    })

    frame:callParserFunction('SHORTDESC',
        string.format(inlineIf(mega['planet_count'] == 1, t('shortdesc_singular'), t('shortdesc_plural')),
            string.gsub(string.lower(mega['#type']), '^%l', string.upper), mega['planet_count']))

    return tostring(infobox:renderInfobox(nil, mega['#name'])) .. convertCategories(mega['categories'])
end

function System.test(name)
    if not name then
        name = 'Stanton'
    end -- System and Star
    System.main({
        ['getParent'] = function()
            return {
                ['args'] = {
                    ['name'] = name
                }
            }
        end
    })
end

return System
