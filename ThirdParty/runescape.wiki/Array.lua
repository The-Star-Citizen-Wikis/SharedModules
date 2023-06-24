-- Imported from: https://runescape.wiki/w/Module:Array

-- <nowiki> awawa
local libraryUtil = require('libraryUtil')
local checkType = libraryUtil.checkType
local checkTypeMulti = libraryUtil.checkTypeMulti
local arr = {}

setmetatable(arr, {
    __call = function (_, array)
        return arr.new(array)
    end
})

function arr.__index(t, k)
    if type(k) == 'table' then
        local res = arr.new()
        for i = 1, #t do
            res[i] = t[k[i]]
        end
        return res
    else
        return arr[k]
    end
end

function arr.__tostring(array)
    local dumpObject = require('Module:Logger').dumpObject
    setmetatable(array, nil)
    local str = dumpObject(array, {clean=true, collapseLimit=100})
    setmetatable(array, arr)
    return str
end

function arr.__concat(lhs, rhs)
    if type(lhs) == 'table' and type(rhs) == 'table' then
        local res = setmetatable({}, getmetatable(lhs) or getmetatable(rhs))
        for i = 1, #lhs do
            res[i] = lhs[i]
        end
        local l = #lhs
        for i = 1, #rhs do
            res[i + l] = rhs[i]
        end
        return res
    else
        return tostring(lhs) .. tostring(rhs)
    end
end

function arr.__unm(array)
    return arr.map(array, function(x) return -x end)
end

local function mathTemplate(lhs, rhs, funName, fun)
    checkTypeMulti('Module:Array.' .. funName, 1, lhs, {'number', 'table'})
    checkTypeMulti('Module:Array.' .. funName, 2, rhs, {'number', 'table'})
    local res = setmetatable({}, getmetatable(lhs) or getmetatable(rhs))

    if type(lhs) == 'number' then
        for i = 1, #rhs do
            res[i] = fun(lhs, rhs[i])
        end
    elseif type(rhs) == 'number' then
        for i = 1, #lhs do
            res[i] = fun(lhs[i], rhs)
        end
    else
        assert(#lhs == #rhs, string.format('Tables are not equal length (lhs=%d, rhs=%d)', #lhs, #rhs))
        for i = 1, #lhs do
            res[i] = fun(lhs[i], rhs[i])
        end
    end

    return res
end

function arr.__add(lhs, rhs)
    return mathTemplate(lhs, rhs, '__add', function(x, y) return x + y end)
end

function arr.__sub(lhs, rhs)
    return mathTemplate(lhs, rhs, '__sub', function(x, y) return x - y end)
end

function arr.__mul(lhs, rhs)
    return mathTemplate(lhs, rhs, '__mul', function(x, y) return x * y end)
end

function arr.__div(lhs, rhs)
    return mathTemplate(lhs, rhs, '__div', function(x, y) return x / y end)
end

function arr.__pow(lhs, rhs)
    return mathTemplate(lhs, rhs, '__pow', function(x, y) return x ^ y end)
end

function arr.__lt(lhs, rhs)
    for i = 1, math.min(#lhs, #rhs) do
        if lhs[i] >= rhs[i] then
            return false
        end
    end
    return true
end

function arr.__le(lhs, rhs)
    for i = 1, math.min(#lhs, #rhs) do
        if lhs[i] > rhs[i] then
            return false
        end
    end
    return true
end

function arr.__eq(lhs, rhs)
    if #lhs ~= #rhs then
        return false
    end
    for i = 1, #lhs do
        if lhs[i] ~= rhs[i] then
            return false
        end
    end
    return true
end

function arr.all(array, fn)
    checkType('Module:Array.all', 1, array, 'table')
    if fn == nil then fn = function(item) return item end end
    if type(fn) ~= 'function' then
        local val = fn
        fn = function(item) return item == val end
    end
    local i = 1
    while array[i] ~= nil do
        if not fn(array[i], i) then
            return false
        end
        i = i + 1
    end
    return true
end

function arr.any(array, fn)
    checkType('Module:Array.any', 1, array, 'table')
    if fn == nil then fn = function(item) return item end end
    if type(fn) ~= 'function' then
        local val = fn
        fn = function(item) return item == val end
    end
    local i = 1
    while array[i] ~= nil do
        if fn(array[i], i) then
            return true
        end
        i = i + 1
    end
    return false
end

function arr.clean(array)
    checkType('Module:Array.clean', 1, array, 'table')
    for i = 1, #array do
        if type(array[i]) == 'table' then
            arr.clean(array[i])
        end
    end
    setmetatable(array, nil)
    return array
end

function arr.contains(array, elem, useElemTableContent)
    checkType('Module:Array.contains', 1, array, 'table')
    if type(elem) == 'table' and useElemTableContent ~= false then
        local elemMap = {}
        local isFound = {}
        arr.each(elem, function(x, i) elemMap[x] = i; isFound[i] = false end)
        for i = 1, #array do
            local j = elemMap[array[i]]
            if j then
                isFound[j] = true
            end
        end
        return arr.all(isFound, true)
    else
        return arr.any(array, function(item) return item == elem end)
    end
end

function arr.count(array, fn)
    checkType('Module:Array.count', 1, array, 'table')
    if fn == nil then fn = function(item) return item end end
    if type(fn) ~= 'function' then
        local val = fn
        fn = function(item) return item == val end
    end
    local count = 0
    for i = 1, #array do
        if fn(array[i]) then
            count = count + 1
        end
    end
    return count
end

function arr.diff(array, order)
    checkType('Module:Array.diff', 1, array, 'table')
    checkType('Module:Array.diff', 2, order, 'number', true)
    local res = setmetatable({}, getmetatable(array))
    for i = 1, #array - 1 do
        res[i] = array[i+1] - array[i]
    end
    if order and order > 1 then
        return arr.diff(res, order - 1)
    end
    return res
end

function arr.each(array, fn)
    checkType('Module:Array.each', 1, array, 'table')
    checkType('Module:Array.each', 2, fn, 'function')
    local i = 1
    while array[i] ~= nil do
        fn(array[i], i)
        i = i + 1
    end
end

function arr.filter(array, fn)
    checkType('Module:Array.filter', 1, array, 'table')
    if fn == nil then fn = function(item) return item end end
    if type(fn) ~= 'function' then
        local val = fn
        fn = function(item) return item == val end
    end
    local r = setmetatable({}, getmetatable(array))
    local len = 0
    local i = 1
    while array[i] ~= nil do
        if fn(array[i], i) then
            len = len + 1
            r[len] = array[i]
        end
        i = i + 1
    end
    return r
end

function arr.find(array, fn, default)
    checkType('Module:Array.find', 1, array, 'table')
    checkTypeMulti('Module:Array.find_index', 2, fn, {'function', 'table', 'number', 'boolean'})
    if type(fn) ~= 'function' then
        local val = fn
        fn = function(item) return item == val end
    end
    local i = 1
    while array[i] ~= nil do
        if fn(array[i], i) then
            return array[i], i
        end
        i = i + 1
    end
    return default
end

function arr.find_index(array, fn, default)
    checkType('Module:Array.find_index', 1, array, 'table')
    checkTypeMulti('Module:Array.find_index', 2, fn, {'function', 'table', 'number', 'boolean'})
    if type(fn) ~= 'function' then
        local val = fn
        fn = function(item) return item == val end
    end
    local i = 1
    while array[i] ~= nil do
        if fn(array[i], i) then
            return i
        end
        i = i + 1
    end
    return default
end

function arr.newIncrementor(start, step)
    checkType('Module:Array.newIncrementor', 1, start, 'number', true)
    checkType('Module:Array.newIncrementor', 2, step, 'number', true)
    step = step or 1
    local n = (start or 1) - step
    local obj = {}
    return setmetatable(obj, {
        __call = function() n = n + step return n end,
        __tostring = function() return n end,
        __index = function() return n end,
        __newindex = function(self, k, v)
            if k == 'step' and type(v) == 'number' then
                step = v
            elseif type(v) == 'number' then
                n = v
            end
        end,
        __concat = function(x, y) return tostring(x) .. tostring(y) end
    })
end

function arr.int(array, start, stop)
    checkType('Module:Array.int', 1, array, 'table')
    checkType('Module:Array.int', 2, start, 'number', true)
    checkType('Module:Array.int', 3, stop, 'number', true)
    local res = setmetatable({}, getmetatable(array))
    start = start or 1
    stop = stop or #array
    res[1] = array[start]
    for i = 1, stop - start do
        res[i+1] = res[i] + array[start + i]
    end
    return res
end

function arr.intersect(array1, array2)
    checkType('Module:Array.intersect', 1, array1, 'table')
    checkType('Module:Array.intersect', 2, array2, 'table')
    local array2Elements = {}
    local res = setmetatable({}, getmetatable(array1) or getmetatable(array2))
    local len = 0
    arr.each(array2, function(item) array2Elements[item] = true end)
    arr.each(array1, function(item)
        if array2Elements[item] then
            len = len + 1
            res[len] = item
        end
    end)
    return res
end

function arr.intersects(array1, array2)
    checkType('Module:Array.intersects', 1, array1, 'table')
    checkType('Module:Array.intersects', 2, array2, 'table')
    local small = {}
    local large
    if #array1 <= #array2 then
        arr.each(array1, function(item) small[item] = true end)
        large = array2
    else
        arr.each(array2, function(item) small[item] = true end)
        large = array1
    end
    return arr.any(large, function(item) return small[item] end)
end

function arr.insert(array, val, index, unpackVal)
    checkType('Module:Array.insert', 1, array, 'table')
    checkType('Module:Array.insert', 3, index, 'number', true)
    checkType('Module:Array.insert', 4, unpackVal, 'boolean', true)
    local len = #array
    index = index or (len + 1)

    if type(val) == 'table' and unpackVal ~= false then
        local len2 = #val
        for i = 0, len - index do
            array[len + len2 - i] = array[len - i]
        end
        for i = 0, len2 - 1 do
            array[index + i] = val[i + 1]
        end
    else
        table.insert(array, index, val)
    end

    return array
end

function arr.map(array, fn)
    checkType('Module:Array.map', 1, array, 'table')
    checkType('Module:Array.map', 2, fn, 'function')
    local len = 0
    local r = setmetatable({}, getmetatable(array))
    local i = 1
    while array[i] ~= nil do
        local tmp = fn(array[i], i)
        if tmp ~= nil then
            len = len + 1
            r[len] = tmp
        end
        i = i + 1
    end
    return r
end

function arr.max_by(array, fn)
    checkType('Module:Array.max_by', 1, array, 'table')
    checkType('Module:Array.max_by', 2, fn, 'function')
    return unpack(arr.reduce(array, function(new, old, i)
        local y = fn(new)
        return y > old[2] and {new, y, i} or old
    end, {nil, -math.huge}))
end

function arr.max(array)
    checkType('Module:Array.max', 1, array, 'table')
    local val, _, i = arr.max_by(array, function(x) return x end)
    return val, i
end

function arr.min(array)
    checkType('Module:Array.min', 1, array, 'table')
    local val, _, i = arr.max_by(array, function(x) return -x end)
    return val, i
end

function arr.new(array)
    array = array or {}
    for _, v in pairs(array) do
        if type(v) == 'table' then
            arr.new(v)
        end
    end

    if getmetatable(array) == nil then
        setmetatable(array, arr)
    end

    return array
end

function arr.range(start, stop, step)
    checkType('Module:Array.range', 1, start, 'number')
    checkType('Module:Array.range', 2, stop, 'number', true)
    checkType('Module:Array.range', 3, step, 'number', true)
    local array = setmetatable({}, arr)
    local len = 0
    if not stop then
        stop = start
        start = 1
    end
    for i = start, stop, step or 1 do
        len = len + 1
        array[len] = i
    end
    return array
end

function arr.reduce(array, fn, accumulator)
    checkType('Module:Array.reduce', 1, array, 'table')
    checkType('Module:Array.reduce', 2, fn, 'function')
    local acc = accumulator
    local i = 1
    if acc == nil then
        acc = array[1]
        i = 2
    end
    while array[i] ~= nil do
        acc = fn(array[i], acc, i)
        i = i + 1
    end
    return acc
end

function arr.reject(array, fn)
    checkType('Module:Array.reject', 1, array, 'table')
    checkTypeMulti('Module:Array.reject', 2, fn, {'function', 'table', 'number', 'boolean'})
    if fn == nil then fn = function(item) return item end end
    if type(fn) ~= 'function' and type(fn) ~= 'table' then
        fn = {fn}
    end
    local r = setmetatable({}, getmetatable(array))
    local len = 0
    if type(fn) == 'function' then
        local i = 1
        while array[i] ~= nil do
            if not fn(array[i], i) then
                len = len + 1
                r[len] = array[i]
            end
            i = i + 1
        end
    else
        local rejectMap = {}
        arr.each(fn, function(item) rejectMap[item] = true end)
        local i = 1
        while array[i] ~= nil do
            if not rejectMap[array[i]] then
                len = len + 1
                r[len] = array[i]
            end
            i = i + 1
        end
    end
    return r
end

function arr.rep(val, n)
    checkType('Module:Array.rep', 2, n, 'number')
    local r = setmetatable({}, arr)
    for i = 1, n do
        r[i] = val
    end
    return r
end

function arr.scan(array, fn, accumulator)
    checkType('Module:Array.scan', 1, array, 'table')
    checkType('Module:Array.scan', 2, fn, 'function')
    local acc = accumulator
    local r = setmetatable({}, getmetatable(array))
    local i = 1
    while array[i] ~= nil do
        if i == 1 and not accumulator then
            acc = array[i]
        else
            acc = fn(array[i], acc)
        end
        r[i] = acc
        i = i + 1
    end
    return r
end

function arr.slice(array, start, finish)
    checkType('Module:Array.slice', 1, array, 'table')
    checkType('Module:Array.slice', 2, start, 'number', true)
    checkType('Module:Array.slice', 3, finish, 'number', true)
    start = start or 1
    finish = finish or #array
    if start < 0 and finish == nil then
        finish = #array + start
        start = 1
    elseif start < 0 then
        start = #array + start
    end
    if finish < 0 then
        finish = #array + finish
    end
    local r = setmetatable({}, getmetatable(array))
    local len = 0
    for i = start, finish do
        len = len + 1
        r[len] = array[i]
    end
    return r
end

function arr.split(array, count)
    checkType('Module:Array.split', 1, array, 'table')
    checkType('Module:Array.split', 2, count, 'number')
    local x = setmetatable({}, getmetatable(array))
    local y = setmetatable({}, getmetatable(array))
    for i = 1, #array do
        table.insert(i <= count and x or y, array[i])
    end
    return x, y
end

function arr.sum(array)
    checkType('Module:Array.sum', 1, array, 'table')
    local res = 0
    for i = 1, #array do
        res = res + array[i]
    end
    return res
end

function arr.take(array, count, offset)
    checkType('Module:Array.take', 1, array, 'table')
    checkType('Module:Array.take', 2, count, 'number')
    checkType('Module:Array.take', 3, offset, 'number', true)
    local x = setmetatable({}, getmetatable(array))
    for i = offset or 1, #array do
        if i <= count then
            table.insert(x, array[i])
        end
    end
    return x
end

function arr.take_every(array, n, offset)
    checkType('Module:Array.take_every', 1, array, 'table')
    checkType('Module:Array.take_every', 2, n, 'number')
    checkType('Module:Array.take_every', 3, offset, 'number', true)
    local r = setmetatable({}, getmetatable(array))
    local len = 0
    local i = offset or 1
    while array[i] ~= nil do
        len = len + 1
        r[len] = array[i]
        i = i + n
    end
    return r
end

function arr.unique(array, fn)
    checkType('Module:Array.unique', 1, array, 'table')
    checkType('Module:Array.unique', 2, fn, 'function', true)
    fn = fn or function(item) return item end
    local r = setmetatable({}, getmetatable(array))
    local len = 0
    local hash = {}
    local i = 1
    while array[i] ~= nil do
        local id = fn(array[i])
        if not hash[id] then
            len = len + 1
            r[len] = array[i]
            hash[id] = true
        end
        i = i + 1
    end
    return r
end

function arr.update(array, indexes, values)
    checkType('Module:Array.update', 1, array, 'table')
    checkTypeMulti('Module:Array.update', 2, indexes, {'table', 'number'})
    if type(indexes) == 'number' then
        indexes = {indexes}
    end
    if type(values) == 'table' then
        assert(#indexes == #values, 'Values array must be of equal length as index array')
        for i = 1, #indexes do
            array[indexes[i]] = values[i]
        end
    else
        for i = 1, #indexes do
            array[indexes[i]] = values
        end
    end
    return array
end

function arr.zip(...)
    local arrays = { ... }
    checkType('Module:Array.zip', 1, arrays[1], 'table')
    local r = setmetatable({}, getmetatable(arrays[1]))
    local _, longest = arr.max_by(arrays, function(array) return #array end)
    for i = 1, longest do
        local q = {}
        for j = 1, #arrays do
            table.insert(q, arrays[j][i])
        end
        table.insert(r, q)
    end
    return r
end

return arr
-- </nowiki>
