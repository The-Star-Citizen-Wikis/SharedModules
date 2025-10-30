require( 'strict' )

--- Simplified Lua interface for building a table.
--- Using similar approach to the Codex Table component.

--- @class TableProps
--- @field caption string
--- @field hideCaption? boolean @default false
--- @field columns? TableColumn[] @default {}
--- @field data? TableRow[] @default {}
--- @field sort? TableSort @default {}
--- @field class? string @default ''
--- @field emptyState? string @default 'No data'

--- @class TableColumn
--- @field id string
--- @field label? string
--- @field textAlign? 'start'|'center'|'end'|'number' @default 'start'
--- @field width? string
--- @field minWidth? string
--- @field allowSort? boolean

--- @alias TableRow any[]

--- @alias TableSort table<string, TableSortOption>
--- @alias TableSortOption 'none'|'asc'|'desc'

local p = {}


---@param props TableProps
---@return TableProps
local function normalizeProps( props )
	props.columns = props.columns or {}
	props.data = props.data or {}
	props.sort = props.sort or {}
	props.emptyState = props.emptyState or 'There is no data available'
	return props
end

--- @return TableRow[]
local function getEmptyStateData( emptyState )
	return {
		{ emptyState }
	}
end

---@param root mw.html
---@param props TableProps
local function renderCaption( root, props )
	if not props.hideCaption then
		root
			:tag( 'caption' )
			:wikitext( props.caption )
	end
end

---@param root mw.html
---@param props TableProps
local function renderHeader( root, props )
	local headerRow = root:tag( 'tr' )
	for _, column in ipairs( props.columns ) do
		local th = headerRow:tag( 'th' )
		th:attr( 'scope', 'col' )

		if column.textAlign then
			th:addClass( 't-table__cell--align-' .. column.textAlign )
		end

		if column.minWidth then
			th:css( 'min-width', column.minWidth )
		end

		if column.width then
			th:css( 'width', column.width )
		end

		if column.allowSort == false then
			th:addClass( 'unsortable' )
		end

		th:wikitext( column.label or '' )
	end
end

---@param root mw.html
---@param props TableProps
local function renderBody( root, props )
	for _, row in ipairs( props.data ) do
		local tr = root:tag( 'tr' )
		for i, cell in ipairs( row ) do
			local td = tr:tag( 'td' )

			local column = props.columns[i]
			if column and column.textAlign then
				td:addClass( 't-table__cell--align-' .. column.textAlign )
			end

			td:wikitext( cell )
		end
	end
end

--- Sort the data according to TableSort
--- MW does not sort tables by default, so we need to sort them manually.
---
---@param props TableProps
local function sortData( props )
	local colMap = {}
	for i, column in ipairs( props.columns ) do
		colMap[column.id] = i
	end

	local sortKeys = {}
	for k in pairs( props.sort ) do
		table.insert( sortKeys, k )
	end
	table.sort( sortKeys )

	local function compare( valA, valB )
		if valA == valB then return 0 end
		if valA == nil then return -1 end
		if valB == nil then return 1 end

		local typeA, typeB = type( valA ), type( valB )
		if typeA == 'number' and typeB == 'number' then
			return valA < valB and -1 or 1
		end

		if typeA == 'string' and typeB == 'string' then
			-- Attempt to sort numerically if the string contains a number,
			-- even if it's wrapped in HTML.
			local cleanA = valA:gsub( '<[^>]+>', '' )
			local cleanB = valB:gsub( '<[^>]+>', '' )

			-- Try to extract numbers for sorting.
			local matchA = cleanA:match( '(-?%d+%.?%d*)' )
			local matchB = cleanB:match( '(-?%d+%.?%d*)' )

			if matchA and matchB then
				local numA = tonumber( matchA )
				local numB = tonumber( matchB )
				-- Only use numeric sort if both are valid numbers and not equal.
				if numA and numB and numA ~= numB then
					return numA < numB and -1 or 1
				end
			end

			-- Fallback to alphanumeric sort on cleaned text
			if cleanA == cleanB then return 0 end
			return cleanA < cleanB and -1 or 1
		end

		if typeA ~= typeB then
			valA, valB = tostring( valA ), tostring( valB )
		end
		return valA < valB and -1 or 1
	end

	table.sort( props.data, function ( a, b )
		if a == b then return false end
		if b == nil then return true end
		if a == nil then return false end

		for _, colId in ipairs( sortKeys ) do
			local order = props.sort[colId]
			if order and order ~= 'none' then
				local colIndex = colMap[colId]
				if colIndex then
					local result = compare( a[colIndex], b[colIndex] )
					if result ~= 0 then
						return (order == 'asc' and result == -1) or
							(order == 'desc' and result == 1)
					end
				end
			end
		end
		return false
	end )
end

--- @param props TableProps
--- @return string
function p.render( props )
	props = normalizeProps( props )

	if props.data == {} then
		props.data = getEmptyStateData( props.emptyState )
	end

	local root = mw.html.create( 'table' )
	root
		:addClass( 't-table' )
		:addClass( 'wikitable' )
		:addClass( props.class )

	if next( props.sort ) then
		root:addClass( 'sortable' )
		sortData( props )
	end

	renderCaption( root, props )
	renderHeader( root, props )
	renderBody( root, props )

	return mw.getCurrentFrame():extensionTag {
		name = 'templatestyles', args = { src = 'Module:TableLua/styles.css' }
	} .. tostring( root )
end

return p
