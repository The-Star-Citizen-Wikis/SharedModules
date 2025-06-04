require( 'strict' )

local Util = {}

-- Helper function to check category conditions with optimization
local function checkItemCategoryConditions(itemValueFromSmw, condValueInTemplate)
    if type(itemValueFromSmw) ~= 'table' then
        return false -- SMW item's categories must be a table
    end

    local categoriesToMatchInTemplate
    if type(condValueInTemplate) == 'string' then
        categoriesToMatchInTemplate = { condValueInTemplate }
    elseif type(condValueInTemplate) == 'table' then
        categoriesToMatchInTemplate = condValueInTemplate
    else
        --mw.log( '⚠️ [Module:Navplate/Util] Warning: Invalid format for Category condition in template for spec: ' .. mw.dumpObject(condValueInTemplate) )
        return false
    end

    if #categoriesToMatchInTemplate == 0 then
        return true
    end

    local smwItemCategoriesSet = {}
    for _, smwCategoryFullName in ipairs(itemValueFromSmw) do
        smwItemCategoriesSet[smwCategoryFullName] = true
    end

    for _, categoryNameFromTemplate in ipairs(categoriesToMatchInTemplate) do
        local targetCategoryFullName = 'Category:' .. categoryNameFromTemplate
        if not smwItemCategoriesSet[targetCategoryFullName] then
            return false
        end
    end

    return true
end

-- Helper function to check if an SMW result matches template conditions
local function checkItemConditions( smwItem, templateConditions )
    for condKey, condValueInTemplate in pairs( templateConditions ) do
        local itemValueFromSmw = smwItem[condKey]

        if itemValueFromSmw == nil then
            return false
        end

        if condKey == 'Category' then
            if not checkItemCategoryConditions(itemValueFromSmw, condValueInTemplate) then
                return false
            end
        else
            local templateValuesToMatch
            if type( condValueInTemplate ) == 'table' then
                templateValuesToMatch = condValueInTemplate
            else
                templateValuesToMatch = { condValueInTemplate }
            end

            if #templateValuesToMatch > 0 then
                local allTemplateValuesMatched = true
                for _, valueFromTemplateString in ipairs( templateValuesToMatch ) do
                    local currentComparisonSuccessful = false
                    if type( itemValueFromSmw ) == 'boolean' then
                        local expectedBool = (valueFromTemplateString == 'true')
                        if itemValueFromSmw == expectedBool then
                            currentComparisonSuccessful = true
                        end
                    elseif type( itemValueFromSmw ) == 'string' then
                        if itemValueFromSmw == valueFromTemplateString then
                            currentComparisonSuccessful = true
                        end
                    elseif type( itemValueFromSmw ) == 'number' then
                        if tostring( itemValueFromSmw ) == valueFromTemplateString then
                            currentComparisonSuccessful = true
                        end
                    else
                        if tostring( itemValueFromSmw ) == valueFromTemplateString then
                            currentComparisonSuccessful = true
                        end
                    end

                    if not currentComparisonSuccessful then
                        allTemplateValuesMatched = false
                        break
                    end
                end
                if not allTemplateValuesMatched then
                    return false
                end
            end
        end
    end
    return true
end

--- Queries the SMW Store
--- @param queryData table For SMW query
--- @return table|nil
function Util.getSmwData( queryData )
    local askData = {
        '[[:+]]',  -- Only pages in the main namespace
        '?#-=page' -- Output page name to the page key
    }

    if type( queryData.conditions ) == 'string' then
        queryData.conditions = { queryData.conditions }
    end

    for _, condition in ipairs( queryData.conditions ) do
        table.insert( askData, '[[' .. condition .. ']]' )
    end

    for _, printout in ipairs( queryData.printout ) do
        table.insert( askData, '?' .. printout .. '#' ) -- # for raw output
    end

    --mw.logObject( askData, '🔍 [Module:Navplate/Util] Running SMW query:' )
    local data = mw.smw.ask( askData )

    if data == nil or data[1] == nil then
        return nil
    end
    --mw.logObject( data, '✅ [Module:Navplate/Util] SMW data:' )
    return data
end

--- Build a table of items data from SMW data based on a template's content rules
--- @param smwData table The data retrieved from SMW
--- @param templateContentRules table The 'content' array from the template JSON (e.g., template.content)
--- @return table
function Util.buildItemsData( smwData, templateContentRules )
    local itemsData = {}

    if not templateContentRules or type(templateContentRules) ~= 'table' then
        --mw.log('⚠️ [Module:Navplate/Util] buildItemsData: templateContentRules is nil or not a table.')
        return itemsData -- Return empty if no rules
    end

    -- Iterate through each rule in the templateContentRules
    for _, rule in ipairs( templateContentRules ) do
        local ruleLabel = rule.label
        local ruleConditions = rule.conditions
        local pagesForRule = {}

        if smwData and type( smwData ) == 'table' then
            for _, smwItem in pairs( smwData ) do
                if type( smwItem ) == 'table' and smwItem.page then
                    if checkItemConditions( smwItem, ruleConditions ) then
                        table.insert( pagesForRule, smwItem.page )
                    end
                end
            end
        end

        if #pagesForRule > 0 then
            table.sort( pagesForRule )
            -- Simplified pageArray creation and concatenation
            local formattedPages = '[[' .. table.concat( pagesForRule, ']][[' ) .. ']]'

            table.insert( itemsData, {
                label = ruleLabel,
                pages = formattedPages
            } )
        end
    end
    --mw.logObject( itemsData, '✅ [Module:Navplate/Util] Items data built:' )
    return itemsData
end

return Util
