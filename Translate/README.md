# Module:Translate

This module allows templates and modules to be easily translated as part of the multilingual templates and modules project. Instead of storing English text in a module or a template, Translate module allows modules to be designed language-neutral, and store multilingual text in the /i18n.json subpage. This way your module or template will use those translated strings (messages), or if the message has not yet been translated, will fallback to English. When someone updates the translation table, your page will automatically update (might take some time, or you can purge it), but no change in the template or module is needed on any of the wikis. This process is very similar to MediaWiki's localisation, and supports all standard localization conventions such as {{PLURAL|...}} and other parameters.

It implements `Module:TNT` without requiring `Extension:JsonConfig`.
