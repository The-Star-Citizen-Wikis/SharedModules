local p = {}

local checkType = require( 'libraryUtil' ).checkType

--- @class DetailsData
--- @field summary DetailsSummaryData The summary of the details.
--- @field details DetailsDetailsData The details of the details.

--- @class DetailsSummaryData
--- @field content string The content of the summary.
--- @field class string|nil An additional HTML class for the summary. Optional.

--- @class DetailsDetailsData
--- @field content string The content of the details.
--- @field class string|nil An additional HTML class for the details. Optional.
--- @field open boolean|nil Whether the details are open by default. Defaults to true.

--- Get the wikitext for the details element
---
--- @param data DetailsData
--- @param frame mw.frame|nil The frame object to use. Defaults to the current frame.
--- @return string
function p.getWikitext( data, frame )
	frame = frame or mw.getCurrentFrame()

	checkType( 'Module:Details.getWikitext', 1, data, 'table' )
	checkType( 'Module:Details.getWikitext', 2, frame, 'table' )

	local summary = frame:extensionTag {
		name = 'summary',
		content = data.summary.content,
		args = {
			class = data.summary.class
		}
	}
	local details = frame:extensionTag {
		name = 'details',
		content = summary .. data.details.content,
		args = {
			class = data.details.class,
			-- Boolean does not work with Extension:Details, has to be 'yes' or 'no'
			open = data.details.open ~= false and 'yes' or 'no'
		}
	}
	return details
end

return p
