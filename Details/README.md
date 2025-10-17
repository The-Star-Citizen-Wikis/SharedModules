# Module:Details

Lua helper to create `<details>` elements with [https://www.mediawiki.org/wiki/Extension:Details Extension:Details].

## Requirements
- [Extension:Details](https://www.mediawiki.org/wiki/Extension:Details)

## Installation
1. Create `Module:Details` 

## Usage
```lua

local Details = require( 'Module:Details' )

local wikitext = Details.getWikitext(
	{
		details = {
			content = 'Wikitext in the details element',
			class = 'details-class', -- Optional
			open = false -- Optional, default to true
		},
		summary = {
			content = 'Wikitext in the summary element',
			class = 'summary-class', -- Optional
		}
	},
	frame -- Optional
)
```
