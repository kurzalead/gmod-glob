--[[

Copyright 2017 kurzyx https://github.com/kurzyx

   Licensed under the Apache License, Version 2.0 (the "License");
   you may not use this file except in compliance with the License.
   You may obtain a copy of the License at

       http://www.apache.org/licenses/LICENSE-2.0

   Unless required by applicable law or agreed to in writing, software
   distributed under the License is distributed on an "AS IS" BASIS,
   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
   See the License for the specific language governing permissions and
   limitations under the License.

]]

local sub    = string.sub
local concat = table.concat

local ipairs = ipairs
local pairs  = pairs
local error  = error

local HAS_MAGIC_PATTERN = '[*?[]'
local ESCAPE_PATTERN    = '([' .. ('%^$().[]*+-?'):gsub('(.)', '%%%1') ..'])'

local FILE_TYPE_FILE = 1
local FILE_TYPE_DIR  = 2

--[[
- @param string s
-
- @return bool
]]
local function hasMagic(s)
    return s:match(HAS_MAGIC_PATTERN) ~= nil
end

--[[
- @param string s
-
- @return string
]]
local function escapePattern(s)
    return s:gsub(ESCAPE_PATTERN, '%%%1')
end

--[[
- @param string[] ...
-
- @return string
]]
local function joinPath(...)
    local pieces = {}

    -- Ignore all empty strings
    for _, piece in ipairs{...} do
        if piece ~= '' then
            pieces[#pieces + 1] = piece
        end
    end

    return concat(pieces, '/')
end

--

--[[
- @param string portion
-
- @return string
]]
local function pathPortionToPattern(portion)

    -- globstar
    if portion == '**' then
        -- Any match (including slashes)
        return '.*'
    end

    local pieces = {}

    local i = 0 -- current position
    local c -- current character

    local length = #portion
    while i < length do

        i = i + 1
        c = sub(portion, i, i)

        -- Matches 0 or more characters (excluding the slash)
        if c == '*' then

            -- Make sure this is not an ilegally places globstar
            if sub(portion, i + 1, i + 1) == '*' then
                error("globstar must be alone in a path portion at position " .. i .. ".")
            end

            pieces[#pieces + 1] = '[^/]*'
            continue
        end

        -- Matches exactly 1 character (excluding the slash)
        if c == '?' then
            pieces[#pieces + 1] = '[^/]'

            continue
        end

        -- Lists
        if c == '[' then
            pieces[#pieces + 1] = '['

            i = i + 1
            c = sub(portion, i, i)

            -- Check if the next character is a negation character
            if c == '^' or c == '!' then

                i = i + 1
                c = sub(portion, i, i)

                pieces[#pieces + 1] = '^'
            end

            -- Check if the first character in the list is the ending bracket
            -- If it is we may include it in the list
            if c == ']' then
            
                i = i + 1
                c = sub(portion, i, i)

                pieces[#pieces + 1] = ']'
            end

            -- Include all characters in the list
            while i <= length do

                -- Escape the escape character
                if c == '%' then
                    pieces[#pieces + 1] = '%%'

                    continue
                end
                
                pieces[#pieces + 1] = c

                -- Break when we have reached the end of the list
                if c == ']' then
                    break
                end

                i = i + 1
                c = sub(portion, i, i)

            end

            continue
        end

        -- Escape special characters in patterns
        if c == '^' or c == '$' or c == '(' or c == ')' or c == '%' or c == '.' or c == '+' or c == '-' then
            pieces[#pieces + 1] = '%' .. c

            continue
        end

        -- Include all other characters
        pieces[#pieces + 1] = c

        continue
    end

    local pattern = concat(pieces)

    -- Test the pattern (for errors)
    string.match('', pattern)

    return pattern
end

--[[
- 
- @param string path
-
- @return table
]]
local function pathNameToPartChain(pathName)
    local parts = {}

    -- Split the pathName in to parts
    for portion in pathName:gmatch('([^/]*)/*') do

		-- gmatch apparently always returns an empty string last, so ignore it...
		if #parts > 0 and portion == '' then
			continue
		end
		
        if hasMagic(portion) then
            parts[#parts + 1] = {
                type = 'pattern',
                value = pathPortionToPattern(portion),
                globstar = portion == '**'
            }

            continue
        end

        if #parts == 0 or parts[#parts].type ~= 'path' then
            parts[#parts + 1] = {
                type = 'path',
                value = portion
            }
        else
            local part = parts[#parts]
            part.value = joinPath(part.value, portion)
        end

    end

    -- Chain the parts
    for i, part in ipairs(parts) do
        part.next = parts[i + 1]
    end

    return parts[1]
end

--[[
- @param string table
-
- @return string
]]
local function partChainToPattern(part)
    local pieces = {}

    repeat

        if part.type == 'path' then
            -- We don't want a normal path to contain any pattern tokens
            pieces[#pieces + 1] = escapePattern(part.value)
        else
            pieces[#pieces + 1] = part.value
        end

        if part.next and not part.globstar then
            pieces[#pieces + 1] = '/'
        end

        part = part.next
    until part == nil

    return concat(pieces)
end

--

--[[
- @param string pathType
- @param srint rootPath
- @param string relativePath
- @param table results
- @param bool|nil recursive
]]
local function _scanDir(pathType, rootPath, relativePath, recursive, results)
    local baseNames, dirNames = file.Find(joinPath(rootPath, relativePath, '*'), pathType)

    -- When the "wildcard" is invalid it will return nothing
	if baseNames == nil then
		return
	end
	
    -- Files
    for _, name in ipairs(baseNames) do
        results[joinPath(relativePath, name)] = FILE_TYPE_FILE
    end

    -- Directories
    for _, name in ipairs(dirNames) do
        local relativePath = joinPath(relativePath, name)

        results[relativePath] = FILE_TYPE_DIR

        -- Continue in the sub directories if recursive
        if recursive then
            _scanDir(pathType, rootPath, relativePath, true, results)
        end

    end

end

--[[
- @param string pathType
- @param srint rootPath
- @param bool|nil recursive
]]
local function scanDir(pathType, rootPath, recursive)

    local results = {}
    _scanDir(pathType, rootPath, '', recursive == true, results)

    return results
end

--

--[[
- @param string pathType
- @param srint rootPath
- @param string relativePath
- @param table part
- @param table results
]]
local function _glob(pathType, rootPath, relativePath, part, results)
    
    if part.type == 'path' then
        local relativePath = joinPath(relativePath, part.value)
        local absolutePath = joinPath(rootPath, relativePath)
        
        if not file.Exists(absolutePath, pathType) then
            return
        end

        -- Continue globbing if there's a next part
        if part.next ~= nil then
            _glob(pathType, rootPath, relativePath, part.next, results)

            return
        end

        if file.IsDir(absolutePath, pathType) then
            results[relativePath] = FILE_TYPE_DIR
        else
            results[relativePath] = FILE_TYPE_FILE
        end

        return
    end

    if part.type == 'pattern' then

        if part.globstar == true then

            --
            -- When it is a globstar, we can simply get all the files & directories
            -- and match each of them against the remaining pattern

            local files = scanDir(pathType, joinPath(rootPath, relativePath), true)
            local pattern = concat{'^', partChainToPattern(part), '$'}

            for fileName, fileType in pairs(files) do
                if fileName:match(pattern) then
                    results[joinPath(relativePath, fileName)] = fileType
                end
            end

            return
        end

        --
        -- Otherwise...

        local files = scanDir(pathType, joinPath(rootPath, relativePath), false)
        local pattern = concat{'^', part.value, '$'}

        -- Continue globbing if there's a next part
        if part.next ~= nil then
            for fileName, fileType in pairs(files) do

                -- Can only continue globbing in directories...
                if fileType ~= FILE_TYPE_DIR then
                    continue
                end

                if fileName:match(pattern) then
                    _glob(pathType, rootPath, joinPath(relativePath, fileName), part.next, results)
                end

            end

            return
        end

        for fileName, fileType in pairs(files) do
            if fileName:match(pattern) then
                results[joinPath(relativePath, fileName)] = fileType
            end
        end
        
        return
   end
   
    error("Unknown part type '" .. tostring(part.type) .. "'.")
end

--

--[[
- @api
-
- @param string pathType
- @param string pathName
- @param string|nil rootPath
]]
local function glob(pathType, pathName, rootPath)
    assert(pathName ~= '', "Path name can not be empty!")

    if rootPath == nil then
        rootPath = ''
    end

    local results = {}

    if not hasMagic(pathName) then
        -- If there's no magic in the path name, simply check whether it exists or not...

        if not file.Exists(path, pathType) then
            return results
        end

        if file.IsDir(path, pathType) then
            results[path] = FILE_TYPE_DIR
        else
            results[path] = FILE_TYPE_FILE
        end

    else
        local partChain = pathNameToPartChain(pathName)
        _glob(pathType, rootPath, '', partChain, results)
    end

    return results
end


--

Glob = {
    version = '1.0.0',
    glob    = glob,
    join    = joinPath
}
return Glob
