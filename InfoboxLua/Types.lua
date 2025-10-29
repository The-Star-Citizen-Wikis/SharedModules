require( 'strict' )

local p = {}


--- MediaWiki built-in types

--- @class mw.frame @The frame object provides access to the parameters passed to a module, and to the parser.
--- @field args table @A table to access arguments passed to the frame.
--- @field callParserFunction function @Calls a parser function.
--- @field expandTemplate function @Transcludes a template.
--- @field extensionTag function @Calls a parser extension tag.
--- @field getParent function @Returns the parent frame.
--- @field getTitle function @Returns the title associated with the frame.
--- @field newChild function @Creates a new child frame.
--- @field preprocess function @Preprocesses wikitext.
--- @field getArgument function @Gets an argument to the frame.
--- @field newParserValue function @Returns a parser value object.
--- @field newTemplateParserValue function @Returns a template parser value object.
--- @field argumentPairs function @Iterates over the arguments.

--- @class mw.html @Built-in Lua type for HtmlBuilder in MediaWiki.
--- @field addClass function @Adds a class to the HTML element.
--- @field create function @Creates a new HTML element.
--- @field node function @Adds a node to the HTML element.
--- @field wikitext function @Adds wikitext to the HTML element.
--- @field tag function @Creates a new HTML element.
--- @field attr function @Sets the attributes of the HTML element.
--- @field css function @Sets the CSS properties of the HTML element.
--- @field done function @Finishes the HTML element.


--- Schema definitions for InfoboxLua components.

--- @class DataSchemaFieldDefinition @Represents the definition of a single field within a schema.
--- @field type string The expected Lua type (e.g., "string", "number", "table", "boolean").
--- @field required boolean|nil Whether the field is mandatory. Defaults to effectively false if nil.
--- @field default any|nil A default value to use if the field is not present in rawData and not required.

--- @alias DataSchemaDefinition table<string, DataSchemaFieldDefinition> @Represents a schema for validating data, mapping field names to their definitions.


--- Component data types

--- @class ImageComponentData @Represents the structure of a validated infobox image for ImageComponent.
--- @field src string The source of the image.
--- @field overlay string|nil The overlay wikitext of the image. Optional.
--- @field label string|nil The label text for the image. Only used for tabber. Optional.
--- @field size number|nil The size of the image. Optional.
--- @field class string|nil The class of the image. Optional.

--- @type DataSchemaDefinition @The schema for ImageComponent data.
p.ImageComponentDataSchema = {
	src = { type = 'string', required = true },
	overlay = { type = 'string', required = false, default = nil },
	label = { type = 'string', required = false, default = nil },
	size = { type = 'number', required = false, default = 400 },
	class = { type = 'string', required = false, default = nil }
}

--- @class HeaderComponentData @Represents the structure of a validated infobox header for HeaderComponent.
--- @field title string The title of the header.
--- @field subtitle string|nil The subtitle of the header. Optional.
--- @field image ImageComponentData|string|nil The image of the header. Optional.
--- @field images table<ImageComponentData>|nil The images of the header. Optional.

--- @type DataSchemaDefinition @The schema for HeaderComponent data.
p.HeaderComponentDataSchema = {
	title = { type = 'string', required = true },
	subtitle = { type = 'string', required = false, default = nil },
	image = { type = 'table', required = false, default = nil },
	images = { type = 'table', required = false, default = nil }
}

--- @class SectionComponentData @Represents the structure of a validated infobox section for SectionComponent.
--- @field label string|nil The label text for the section. Optional.
--- @field columns number|nil The number of columns in the section. Optional.
--- @field content string|nil The HTML content of the section. Optional.
--- @field items table<ItemComponentData>|nil The items in the section. Optional.
--- @field sections table<SectionComponentData>|nil The sections in the section. Optional.
--- @field collapsible boolean|nil Whether the section is collapsible. Optional.
--- @field collapsed boolean|nil Whether the section is collapsed. Optional.
--- @field class string|nil An additional HTML class for the section's container. Optional.

--- @type DataSchemaDefinition @The schema for SectionComponent data.
p.SectionComponentDataSchema = {
	label = { type = 'string', required = false, default = nil },
	columns = { type = 'number', required = false, default = 1 },
	content = { type = 'string', required = false, default = nil },
	items = { type = 'table', required = false, default = nil },
	sections = { type = 'table', required = false, default = nil },
	collapsible = { type = 'boolean', required = false, default = false },
	collapsed = { type = 'boolean', required = false, default = false },
	class = { type = 'string', required = false, default = nil }
}

--- @class ItemComponentData @Represents the structure of a validated infobox item for ItemComponent.
--- @field content string The HTML content of the item.
--- @field label string|nil The label text for the item. Optional.
--- @field class string|nil An additional HTML class for the item's container. Optional.

--- @type DataSchemaDefinition @The schema for ItemComponent data.
p.ItemComponentDataSchema = {
	content = { type = 'string', required = true },
	label   = { type = 'string', required = false, default = nil },
	class   = { type = 'string', required = false, default = nil }
}

--- @class ItemCardComponentData @Represents the structure of a validated infobox item card for ItemCardComponent.
--- @field label string|nil The label of the item card.
--- @field columns number|nil The number of columns in the item card.
--- @field content string|nil The HTML content of the item card.
--- @field items table<ItemComponentData>|nil The items of the item card.

--- @type DataSchemaDefinition @The schema for ItemCardComponent data.
p.ItemCardComponentDataSchema = {
	label = { type = 'string', required = false, default = nil },
	columns = { type = 'number', required = false, default = 1 },
	content = { type = 'string', required = false, default = nil },
	items = { type = 'table', required = false, default = nil }
}

--- @class CollapsibleComponentData @Represents the structure of a validated collapsible component.
--- @field summary string The summary/button content displayed when collapsed.
--- @field content string The content to be shown/hidden.
--- @field class string|nil An additional HTML class for the details element. Optional.
--- @field summaryClass string|nil An additional HTML class for the summary element. Optional.
--- @field open boolean|nil Whether the collapsible starts open. Defaults to true. Optional.

--- @type DataSchemaDefinition @The schema for CollapsibleComponent data.
p.CollapsibleComponentDataSchema = {
	summary = { type = 'string', required = true },
	content = { type = 'string', required = true },
	class = { type = 'string', required = false, default = nil },
	summaryClass = { type = 'string', required = false, default = nil },
	open = { type = 'boolean', required = false, default = true }
}

return p
