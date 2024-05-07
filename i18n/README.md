# Module:i18n

** THIS IS A WORK IN PROGRESS **

This module allows templates and modules to be easily translated as part of the multilingual templates and modules project. Instead of storing English text in a module or a template, Translate module allows modules to be designed language-neutral, and store multilingual text in the /i18n.json subpage. This way your module or template will use those translated strings (messages), or if the message has not yet been translated, will fallback to fallback languages defined by MediaWiki. When someone updates the translation table, your page will automatically update (might take some time, or you can purge it), but no change in the template or module is needed on any of the wikis. This process is very similar to MediaWiki's localisation, and supports all standard localization conventions such as {{PLURAL|...}} and other parameters.

The message key are namespaced based on their first prefix. For example, the key `SMW_Name` will be under the `SMW` namespacce.

## Installation
1. Create `Module:i18n`

## Usage
1. Define the t function in your Lua module
```Lua
local i18n = require( 'Module:i18n' ):new()

--- Wrapper function for Module:i18n.translate
---
--- @param key string The translation key
--- @return string If the key was not found, the key is returned
local function t( key )
	return i18n:translate( key )
end
```

2. Use the t function to get the message
```Lua
t( 'SMW_Name' )
```