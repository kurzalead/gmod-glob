# Glob for Garry's mod

Match files using the patterns the shell uses, like stars and stuff.

Inspiration comes from: https://github.com/isaacs/node-glob

## Usage

The following characters have special magic meaning when used in a
path portion:

* `*` Matches 0 or more characters in a single path portion
* `?` Matches 1 character
* `[...]` Matches a range of characters, similar to a RegExp range.
  If the first character of the range is `!` or `^` then it matches
  any character not in the range.
* `**` If a "globstar" is alone in a path portion, then it matches
  zero or more directories and subdirectories searching for matches.

The following may be added at a later date:

* `!(pattern|pattern|pattern)` Matches anything that does not match
  any of the patterns provided.
* `?(pattern|pattern|pattern)` Matches zero or one occurrence of the
  patterns provided.
* `+(pattern|pattern|pattern)` Matches one or more occurrences of the
  patterns provided.
* `*(a|b|c)` Matches zero or more occurrences of the patterns provided
* `@(pattern|pat*|pat?erN)` Matches exactly one of the patterns
  provided

## Examples

#### Example 1

Find all configuration files.

File structure:
```
addons/lua/my-addon
.
├── config
│   ├── module1
│   │   ├── something.lua
│   │   ├── else.lua
│   ├── module2
│   │   ├── something.lua
│   │   ├── else.lua
```

How you would use the glob functionality:
```lua
local result = glob('LUA', '**/*.lua', 'my-addon/config', 'file')
```

result:
```lua
{
    'module1/something.lua',
    'module1/else.lua',
    'module2/something.lua',
    'module2/else.lua',
}
```
