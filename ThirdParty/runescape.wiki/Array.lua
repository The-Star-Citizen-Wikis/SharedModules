-- Imported from: https://runescape.wiki/w/Module:Array

local libraryUtil = require('libraryUtil')
local checkType = libraryUtil.checkType
local checkTypeMulti = libraryUtil.checkTypeMulti

---@class Array
---@operator call(any[]): Array
---@operator concat(any[]): Array
---@operator concat(number|string|function): string
---@operator unm: Array
---@operator add(number|number[]|Array): Array
---@operator sub(number|number[]|Array): Array
---@operator mul(number|number[]|Array): Array
---@operator div(number|number[]|Array): Array
---@operator pow(number|number[]|Array): Array
local Array = {
	pop = table.remove
}
Array.__index = Array

setmetatable(Array, {
	__index = table,
	__call = function (_, arr)
		return Array.new(arr)
	end
})

-- function Array.__tostring(arr)
-- 	-- local dumpObject = require('Module:Logger').dumpObject
-- 	require 'log'
-- 	local dumpObject = dumpObject
-- 	local mt = getmetatable(arr)
-- 	setmetatable(arr, nil)
-- 	local str = dumpObject(arr, {clean=true, collapseLimit=100})
-- 	setmetatable(arr, mt)
-- 	return str
-- end

function Array.__concat(lhs, rhs)
	if type(lhs) == 'table' and type(rhs) == 'table' then
		local res = {}
		for i = 1, #lhs do
			res[i] = lhs[i]
		end
		local l = #lhs
		for i = 1, #rhs do
			res[i + l] = rhs[i]
		end
		return setmetatable(res, getmetatable(lhs) or getmetatable(rhs))
	else
		return tostring(lhs) .. tostring(rhs)
	end
end

function Array.__unm(arr)
	return Array.map(arr, function(x) return -x end)
end

---@param lhs number|number[]|Array
---@param rhs number|number[]|Array
---@param funName string
---@param opName string
---@param fun fun(lhs: number, rhs: number): number
---@return Array
local function mathTemplate(lhs, rhs, funName, opName, fun)
	checkTypeMulti('Module:Array.' .. funName, 1, lhs, {'number', 'table'})
	checkTypeMulti('Module:Array.' .. funName, 2, rhs, {'number', 'table'})
	local res = {}

	if type(lhs) == 'number' then
		for i = 1, #rhs do
			res[i] = fun(lhs, rhs[i])
		end
	elseif type(rhs) == 'number' then
		for i = 1, #lhs do
			res[i] = fun(lhs[i], rhs)
		end
	else
		assert(#lhs == #rhs, string.format('Elementwise %s failed because arrays have different sizes (left: %d, right: %d)', opName, #lhs, #rhs))
		for i = 1, #lhs do
			res[i] = fun(lhs[i], rhs[i])
		end
	end

	return setmetatable(res, getmetatable(lhs) or getmetatable(rhs))
end

function Array.__add(lhs, rhs)
	return mathTemplate(lhs, rhs, '__add', 'addition', function(x, y) return x + y end)
end

function Array.__sub(lhs, rhs)
	return mathTemplate(lhs, rhs, '__sub', 'substraction', function(x, y) return x - y end)
end

function Array.__mul(lhs, rhs)
	return mathTemplate(lhs, rhs, '__mul', 'multiplication', function(x, y) return x * y end)
end

function Array.__div(lhs, rhs)
	return mathTemplate(lhs, rhs, '__div', 'division', function(x, y) return x / y end)
end

function Array.__pow(lhs, rhs)
	return mathTemplate(lhs, rhs, '__pow', 'exponentiation', function(x, y) return x ^ y end)
end

function Array.__eq(lhs, rhs)
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

---Behaviour depends on the value of `fn`:
---* `nil` - Checks that the array doesn't contain any **false** elements.
---* `fun(elem: any, i?: integer): boolean` - Returns **true** if `fn` returns **true** for every element.
---* `number` | `table` | `boolean` - Checks that all elements in `arr` are equal to this value.
---@param arr any[]
---@param fn? any
---@return boolean
function Array.all(arr, fn)
	checkType('Module:Array.all', 1, arr, 'table')
	if fn == nil then fn = function(item) return item end end
	if type(fn) ~= 'function' then
		local val = fn
		fn = function(item) return item == val end
	end
	local i = 1
	while arr[i] ~= nil do
		---@diagnostic disable-next-line: redundant-parameter
		if not fn(arr[i], i) then
			return false
		end
		i = i + 1
	end
	return true
end

---Behaviour depends on the value of `fn`:
---* `nil` - Checks that the array contains at least one non **false** element.
---* `fun(elem: any, i?: integer): boolean` - Returns **true** if `fn` returns **true** for at least one element.
---* `number` | `table` | `boolean` - Checks that `arr` contains this value.
---@param arr any[]
---@param fn? any
---@return boolean
function Array.any(arr, fn)
	checkType('Module:Array.any', 1, arr, 'table')
	if fn == nil then fn = function(item) return item end end
	if type(fn) ~= 'function' then
		local val = fn
		fn = function(item) return item == val end
	end
	local i = 1
	while arr[i] ~= nil do
		---@diagnostic disable-next-line: redundant-parameter
		if fn(arr[i], i) then
			return true
		end
		i = i + 1
	end
	return false
end

---Recursively removes all metatables.
---@param arr any[]
---@return any[]
function Array.clean(arr)
	checkType('Module:Array.clean', 1, arr, 'table')
	for i = 1, #arr do
		if type(arr[i]) == 'table' then
			Array.clean(arr[i])
		end
	end
	setmetatable(arr, nil)
	return arr
end

---Make a copy of the input table. Preserves metatables.
---@generic T: any[]
---@param arr T
---@param deep? boolean # Recursively clone subtables if **true**.
---@return T
function Array.clone(arr, deep)
	checkType('Module:Array.clone', 1, arr, 'table')
	checkType('Module:Array.clone', 2, deep, 'boolean', true)
	local res = {}
	for i = 1, #arr do
		if deep == true and type(arr[i]) == 'table' then
			res[i] = Array.clone(arr[i], true)
		else
			res[i] = arr[i]
		end
	end
	return setmetatable(res, getmetatable(arr))
end

---Check if `arr` contains `val`.
---@param arr any[]
---@param val any
---@return boolean
function Array.contains(arr, val)
	checkType('Module:Array.contains', 1, arr, 'table')
	for i = 1, #arr do
		if arr[i] == val then
			return true
		end
	end
	return false
end

---Check if `arr` contains any of the values in the table `t`.
---@param arr any[]
---@param t any[]
---@return boolean
function Array.containsAny(arr, t)
	checkType('Module:Array.containsAny', 1, arr, 'table')
	checkType('Module:Array.containsAny', 2, t, 'table')
	local lookupTbl = {}
	for i = 1, #t do
		lookupTbl[t[i]] = true
	end
	for i = 1, #arr do
		if lookupTbl[arr[i]] then
			return true
		end
	end
	return false
end

---Check if `arr` contains all values in the table `t`.
---@param arr any[]
---@param t any[]
---@return boolean
function Array.containsAll(arr, t)
	checkType('Module:Array.containsAll', 1, arr, 'table')
	checkType('Module:Array.containsAll', 2, t, 'table')
	local lookupTbl = {}
	local l = #t
	local trueCount = 0
	for i = 1, l do
		lookupTbl[t[i]] = false
	end
	for i = 1, #arr do
		if lookupTbl[arr[i]] == false then
			lookupTbl[arr[i]] = true
			trueCount = trueCount + 1
		end
		if trueCount == l then
			return true
		end
	end
	return false
end

---Convolute two number arrays.
---@generic T: number[]
---@param x T
---@param y T
---@return T
function Array.convolve(x, y)
	checkType('Module:Array.convolve', 1, x, 'table')
	checkType('Module:Array.convolve', 2, y, 'table')
	local z = {}
    local xLen, yLen = #x, #y
    for j = 1, (xLen + yLen - 1) do
        local sum = 0
        for k = math.max(1, j - yLen + 1), math.min(xLen, j) do
            sum = sum + x[k] * y[j-k+1]
        end
        z[j] = sum
    end
    return setmetatable(z, getmetatable(x) or getmetatable(y))
end

---Remove **nil** values from `arr` while preserving order.
---@generic T: any[]
---@param arr T
---@return T
function Array.condenseSparse(arr)
	checkType('Module:Array.condenseSparse', 1, arr, 'table')
	local keys = {}
	local res = {}
	local l = 0
	for k in pairs(arr) do
		l = l + 1
		keys[l] = k
	end
	table.sort(keys)
	for i =  1, l do
		res[i] = arr[keys[i]]
	end
	return setmetatable(res, getmetatable(arr))
end

---Behaviour depends on value of `val`:
---* `nil` - Counts the number of non **false** elements.
---* `fun(elem: any): boolean` - Count the number of times the function returned **true**.
---* `boolean` | `number` | `table` - Counts the number of times this value occurs in `arr`.
---@param arr any[]
---@param val? any
---@return integer
function Array.count(arr, val)
	checkType('Module:Array.count', 1, arr, 'table')
	if val == nil then val = function(item) return item end end
	if type(val) ~= 'function' then
		local _val = val
		val = function(item) return item == _val end
	end
	local count = 0
	for i = 1, #arr do
		if val(arr[i]) then
			count = count + 1
		end
	end
	return count
end

---Differentiate the array
---@generic T: number[]
---@param arr T
---@param order number? # Oder of the differentiation. Default is 1.
---@return T # Length is `#arr - order`
function Array.diff(arr, order)
	checkType('Module:Array.diff', 1, arr, 'table')
	checkType('Module:Array.diff', 2, order, 'number', true)
	local res = {}
	for i = 1, #arr - 1 do
		res[i] = arr[i+1] - arr[i]
	end
	if order and order > 1 then
		return Array.diff(res, order - 1)
	end
	return setmetatable(res, getmetatable(arr))
end

---Loops over `arr` and passes each element as the first argument to `fn`. This function returns nothing.
---@param arr any[]
---@param fn fun(elem: any, i?: integer)
function Array.each(arr, fn)
	checkType('Module:Array.each', 1, arr, 'table')
	checkType('Module:Array.each', 2, fn, 'function')
	local i = 1
	while arr[i] ~= nil do
		fn(arr[i], i)
		i = i + 1
	end
end

---Makes a copy of `arr` with only elements for which `fn` returned **true**.
---@generic T: any[]
---@param arr T
---@param fn fun(elem: any, i?: integer): boolean
---@return T
function Array.filter(arr, fn)
	checkType('Module:Array.filter', 1, arr, 'table')
	checkType('Module:Array.filter', 2, fn, 'function')
	local r = {}
	local len = 0
	local i = 1
	while arr[i] ~= nil do
		if fn(arr[i], i) then
			len = len + 1
			r[len] = arr[i]
		end
		i = i + 1
	end
	return setmetatable(r, getmetatable(arr))
end

---Find the first elements for which `fn` returns **true**.
---@param arr any[]
---@param fn any # A value to look for or a function of the form `fun(elem: any, i?: integer): boolean`.
---@param default? any # Value to return if no element passes the test.
---@return any? elem # The first element that passed the test.
---@return integer? i # The index of the item that passed the test.
function Array.find(arr, fn, default)
	checkType('Module:Array.find', 1, arr, 'table')
	checkTypeMulti('Module:Array.find_index', 2, fn, {'function', 'table', 'number', 'boolean'})
	if type(fn) ~= 'function' then
		local _val = fn
		fn = function(item) return item == _val end
	end
	local i = 1
	while arr[i] ~= nil do
		---@diagnostic disable-next-line: redundant-parameter
		if fn(arr[i], i) then
			return arr[i], i
		end
		i = i + 1
	end
	return default, nil
end

---Find the index of `val`.
---@param arr any[]
---@param val any # A value to look for or a function of the form `fun(elem: any, i?: integer): boolean`.
---@param default? any # Value to return if no element passes the test.
---@return integer?
function Array.find_index(arr, val, default)
	checkType('Module:Array.find_index', 1, arr, 'table')
	checkTypeMulti('Module:Array.find_index', 2, val, {'function', 'table', 'number', 'boolean'})
	if type(val) ~= 'function' then
		local _val = val
		val = function(item) return item == _val end
	end
	local i = 1
	while arr[i] ~= nil do
		---@diagnostic disable-next-line: redundant-parameter
		if val(arr[i], i) then
			return i
		end
		i = i + 1
	end
	return default
end

---Extracts a subset of `arr`.
---@generic T: any[]
---@param arr T
---@param indexes integer|integer[] # Indexes of the elements.
---@return T
function Array.get(arr, indexes)
	checkType('Module:Array.set', 1, arr, 'table')
	checkTypeMulti('Module:Array.set', 2, indexes, {'table', 'number'})
	if type(indexes) == 'number' then
		indexes = {indexes}
	end
	local res = {}
	for i = 1, #indexes do
		 res[i] = arr[indexes[i]]
	end
	return setmetatable(res, getmetatable(arr))
end

---Integrates the array. Effectively does $\left\{\sum^{n}_{start}{arr[n]} \,\Bigg|\, n \in [start, stop]\right\}$.
---@generic T: number[]
---@param arr T # number[]
---@param start? integer # Index where to start the summation. Defaults to 1.
---@param stop? integer # Index where to stop the summation. Defaults to #arr.
---@return T
function Array.int(arr, start, stop)
	checkType('Module:Array.int', 1, arr, 'table')
	checkType('Module:Array.int', 2, start, 'number', true)
	checkType('Module:Array.int', 3, stop, 'number', true)
	local res = {}
	start = start or 1
	stop = stop or #arr
	res[1] = arr[start]
	for i = 1, stop - start do
		res[i+1] = res[i] + arr[start + i]
	end
	return setmetatable(res, getmetatable(arr))
end

---Returns an array with elements that are present in both tables.
---@generic T: any[]
---@param arr1 T
---@param arr2 T
---@return T
function Array.intersect(arr1, arr2)
	checkType('Module:Array.intersect', 1, arr1, 'table')
	checkType('Module:Array.intersect', 2, arr2, 'table')
	local arr2Elements = {}
	local res = {}
	local len = 0
	Array.each(arr2, function(item) arr2Elements[item] = true end)
	Array.each(arr1, function(item)
		if arr2Elements[item] then
			len = len + 1
			res[len] = item
		end
	end)
	return setmetatable(res, getmetatable(arr1) or getmetatable(arr2))
end

---Checks if the two inputs have at least one element in common.
---@param arr1 any[]
---@param arr2 any[]
---@return boolean
function Array.intersects(arr1, arr2)
	checkType('Module:Array.intersects', 1, arr1, 'table')
	checkType('Module:Array.intersects', 2, arr2, 'table')
	local small = {}
	local large
	if #arr1 <= #arr2 then
		Array.each(arr1, function(item) small[item] = true end)
		large = arr2
	else
		Array.each(arr2, function(item) small[item] = true end)
		large = arr1
	end
	return Array.any(large, function(item) return small[item] end)
end

---Inserts values into `arr`.
---@generic T: any[]
---@param arr T
---@param val any # If `val` is an array and `unpackVal` is **true** then the individual elements of `val` are inserted.
---@param index? integer # Location to start the insertion. Default is at the end of `arr`.
---@param unpackVal? boolean # Default is **false**.
---@return T
---@overload fun(arr: T, val: any, unpackVal: boolean): T
function Array.insert(arr, val, index, unpackVal)
	checkType('Module:Array.insert', 1, arr, 'table')
	checkTypeMulti('Module:Array.insert', 3, index, {'number', 'boolean', 'nil'})
	checkType('Module:Array.insert', 4, unpackVal, 'boolean', true)
	if type(index) == 'boolean'  then
		unpackVal, index = index, nil
	end
	local len = #arr
	index = index or (len + 1)
	local mt = getmetatable(arr)
	setmetatable(arr, nil)

	if type(val) == 'table' and unpackVal then
		local len2 = #val
		for i = 0, len - index do
			arr[len + len2 - i] = arr[len - i]
		end
		for i = 0, len2 - 1 do
			arr[index + i] = val[i + 1]
		end
	else
		table.insert(arr, index, val)
	end

	return setmetatable(arr, mt)
end

---Returns the last element of `arr`.
---@param arr any[]
---@param offset? integer
---@return any
function Array.last(arr, offset)
	checkType('Module:Array.last', 1, arr, 'table')
	checkType('Module:Array.last', 2, offset, 'number', true)
	return arr[#arr + offset]
end

---Returns a new table were each element of `arr` is modified by `fn`.
---@generic T: any[]
---@param arr T
---@param fn fun(elem: any, i?: integer): any # First argument is the current element, the second argument is the index of the current element.
---@return T
function Array.map(arr, fn)
	checkType('Module:Array.map', 1, arr, 'table')
	checkType('Module:Array.map', 2, fn, 'function')
	local len = 0
	local r = {}
	local i = 1
	while arr[i] ~= nil do
		local tmp = fn(arr[i], i)
		if tmp ~= nil then
			len = len + 1
			r[len] = tmp
		end
		i = i + 1
	end
	return setmetatable(r, getmetatable(arr))
end

---Find the element for which `fn` returned the largest value.
---@param arr any[]
---@param fn fun(elem: any): any # The returned value needs to be comparable using the `<` operator.
---@return any elem # The element with the largest `fn` value.
---@return integer i # The index of this element.
function Array.max_by(arr, fn)
	checkType('Module:Array.max_by', 1, arr, 'table')
	checkType('Module:Array.max_by', 2, fn, 'function')
	return unpack(Array.reduce(arr, function(new, old, i)
		local y = fn(new)
		return y > old[2] and {new, y, i} or old
	end, {nil, -math.huge}))
end

---Find the largest value in the array.
---@param arr any[] # The values need to be comparable using the `<` operator.
---@return any elem
---@return integer i # The index of the largest value.
function Array.max(arr)
	checkType('Module:Array.max', 1, arr, 'table')
	local val, _, i = Array.max_by(arr, function(x) return x end)
	return val, i
end

---Find the smallest value in the array.
---@param arr any[] # The values need to be comparable using the `<` operator.
---@return any elem
---@return integer i # The index of the smallest value.
function Array.min(arr)
	checkType('Module:Array.min', 1, arr, 'table')
	local val, _, i = Array.max_by(arr, function(x) return -x end)
	return val, i
end

---Turn the input table into an Array. This makes it possible to use the colon `:` operator to access the Array methods.
---
---It also enables the use of math operators with the array.
---```
---local x = arr.new{ 1, 2, 3 }
---local y = arr{ 4, 5, 6 } -- Alternative notation
---
---print( -x ) --> { -1, -2, -3 }
---print( x + 2 ) --> { 3, 4, 5 }
---print( x - 2 ) --> { -1, 0, 1 }
---print( x * 2 ) --> { 2, 4, 6 }
---print( x / 2 ) --> { 0.5, 1, 1.5 }
---print( x ^ 2 ) --> { 1, 4, 9 }
---
---print( x + y ) --> { 5, 7, 9 }
---print( x .. y ) --> { 1, 2, 3, 4, 5, 6 }
---print( (x .. y):reject{3, 4, 5} ) --> { 1, 2, 6 }
---print( x:sum() ) --> 6
---
---print( x:update( {1, 3}, y:get{2, 3} * 2 ) ) --> { 10, 2, 12 }
---```
---@param arr? any[]
---@return Array
function Array.new(arr)
	local obj = arr or {}
	for _, v in pairs(obj) do
		if type(v) == 'table' then
			Array.new(v)
		end
	end

	if getmetatable(obj) == nil then
		setmetatable(obj, Array)
	end

	return obj
end

---Creates an object that returns a value that is `step` higher than the previous value each time it gets called.
---
---The stored value can be read without incrementing by reading the `val` field.
---
---A new stored value can be set through the `val` field.
---
---A new step size can be set through the `step` field.
---```
---local inc = arr.newIncrementor(10, 5)
---print( inc() ) --> 10
---print( inc() ) --> 15
---print( inc.val ) --> 15
---inc.val = 100
---inc.step = 20
---print( inc.val ) --> 100
---print( inc() ) --> 120
---```
---@param start? number # Default is 1.
---@param step? number # Default is 1.
---@return Incrementor
function Array.newIncrementor(start, step)
	checkType('Module:Array.newIncrementor', 1, start, 'number', true)
	checkType('Module:Array.newIncrementor', 2, step, 'number', true)
	step = step or 1
	local n = (start or 1) - step
	---@class Incrementor
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

---Returns a range of numbers.
---@param start number # Start value inclusive.
---@param stop number # Stop value inclusive for integers, exclusive for floats.
---@param step? number # Default is 1.
---@return Array
---@overload fun(stop: number): Array
function Array.range(start, stop, step)
	checkType('Module:Array.range', 1, start, 'number')
	checkType('Module:Array.range', 2, stop, 'number', true)
	checkType('Module:Array.range', 3, step, 'number', true)
	local arr = {}
	local len = 0
	if not stop then
		stop = start
		start = 1
	end
	for i = start, stop, step or 1 do
		len = len + 1
		arr[len] = i
	end
	return setmetatable(arr, Array)
end

---Condenses the array into a single value.
---
---For each element `fn` is called with the current element, the current accumulator, and the current element index. The returned value of `fn` becomes the accumulator for the next element.
---
---If no `accumulator` value is given at the start then the first element off `arr` becomes the accumulator and the iteration starts from the second element.
---```
---local t = { 1, 2, 3, 4 }
---local sum = arr.reduce( t, function(elem, acc) return acc + elem end ) -- sum == 10
---```
---@param arr any[]
---@param fn fun(elem: any, acc: any, i?: integer): any # The result of this function becomes the `acc` for the next element.
---@param accumulator? any
---@return any # This is the last accumulator value.
function Array.reduce(arr, fn, accumulator)
	checkType('Module:Array.reduce', 1, arr, 'table')
	checkType('Module:Array.reduce', 2, fn, 'function')
	local acc = accumulator
	local i = 1
	if acc == nil then
		acc = arr[1]
		i = 2
	end
	while arr[i] ~= nil do
		acc = fn(arr[i], acc, i)
		i = i + 1
	end
	return acc
end

---Make a copy off `arr` with certain values removed.
---
---Behaviour for different values of `val`:
---* `boolean` | `number` - Remove values equal to this.
---* `table` - Remove all values in this table.
---* `fun(elem: any, i?: integer): boolean` - Remove elements for which the functions returns **true**.
---@generic T: any[]
---@param arr T
---@param val table|function|number|boolean
---@return T
function Array.reject(arr, val)
	checkType('Module:Array.reject', 1, arr, 'table')
	checkTypeMulti('Module:Array.reject', 2, val, {'function', 'table', 'number', 'boolean'})
	if type(val) ~= 'function' and type(val) ~= 'table' then
		val = {val}
	end
	local r = {}
	local len = 0
	if type(val) == 'function' then
		local i = 1
		while arr[i] ~= nil do
			if not val(arr[i], i) then
				len = len + 1
				r[len] = arr[i]
			end
			i = i + 1
		end
	else
		local rejectMap = {}
		Array.each(val --[[@as any[] ]], function(item) rejectMap[item] = true end)
		local i = 1
		while arr[i] ~= nil do
			if not rejectMap[arr[i]] then
				len = len + 1
				r[len] = arr[i]
			end
			i = i + 1
		end
	end
	return setmetatable(r, getmetatable(arr))
end

---Returns an Array with `val` repeated `n` times.
---@param val any
---@param n integer
---@return Array
function Array.rep(val, n)
	checkType('Module:Array.rep', 2, n, 'number')
	local r = {}
	for i = 1, n do
		r[i] = val
	end
	return setmetatable(r, Array)
end

---Condenses the array into a single value while saving every accumulator value.
---
---For each element `fn` is called with the current element, the current accumulator, and the current element index. The returned value of `fn` becomes the accumulator for the next element.
---
---If no `accumulator` value is given at the start then the first element off `arr` becomes the accumulator and the iteration starts from the second element.
---```
---local t = { 1, 2, 3, 4 }
---local x = arr.scan( t, function(elem, acc) return acc + elem end ) -- x = { 1, 3, 6, 10 }
---```
---@generic T: any[]
---@param arr T
---@param fn fun(elem: any, acc: any, i?: integer): any # Returned value becomes the accumulator for the next element.
---@param accumulator? any
---@return T
function Array.scan(arr, fn, accumulator)
	checkType('Module:Array.scan', 1, arr, 'table')
	checkType('Module:Array.scan', 2, fn, 'function')
	local acc = accumulator
	local r = {}
	local i = 1
	while arr[i] ~= nil do
		if i == 1 and not accumulator then
			acc = arr[i]
		else
			acc = fn(arr[i], acc, i)
		end
		r[i] = acc
		i = i + 1
	end
	return setmetatable(r, getmetatable(arr))
end

---Update a range of index with a range of values.
---
---If if only one value is given but multiple indexes than that value is set for all those indexes.
---
---If `values` is a table then it must of the same length as `indexes`.
---@generic T: any[]
---@param arr T
---@param indexes integer|integer[]
---@param values any|any[]
---@return T
function Array.set(arr, indexes, values)
	checkType('Module:Array.set', 1, arr, 'table')
	checkTypeMulti('Module:Array.set', 2, indexes, {'table', 'number'})
	local mt = getmetatable(arr)
	setmetatable(arr, nil)
	if type(indexes) == 'number' then
		indexes = {indexes}
	end
	if type(values) == 'table' then
		assert(#indexes == #values, string.format("Module:Array.set: 'indexes' and 'values' arrays are not equal length (#indexes = %d, #values = %d)", #indexes, #values))
		for i = 1, #indexes do
			arr[indexes[i]] = values[i]
		end
	else
		for i = 1, #indexes do
			arr[indexes[i]] = values
		end
	end
	return setmetatable(arr, mt)
end

---Extract a subtable from `arr`.
---@generic T: any[]
---@param arr T
---@param start integer # Start index. Use negative values to count form the end of the array.
---@param stop integer # Stop index. Use negative values to count form the end of the array.
---@return T
---@overload fun(arr: T, stop: integer): T
function Array.slice(arr, start, stop)
	checkType('Module:Array.slice', 1, arr, 'table')
	checkType('Module:Array.slice', 2, start, 'number', true)
	checkType('Module:Array.slice', 3, stop, 'number', true)
	start = start or #arr
	if start < 0 then
		start = #arr + start
	end
	if stop == nil then
		stop = start
		start = 1
	end
	if stop < 0 then
		stop = #arr + stop
	end
	local r = {}
	local len = 0
	for i = start, stop do
		len = len + 1
		r[len] = arr[i]
	end
	return setmetatable(r, getmetatable(arr))
end

---Split `arr` into two arrays.
---@generic T: any[]
---@param arr T
---@param index integer # Index to split on.
---@return T x # [1, index]
---@return T y # [index + 1, #arr]
function Array.split(arr, index)
	checkType('Module:Array.split', 1, arr, 'table')
	checkType('Module:Array.split', 2, index, 'number')
	local x = {}
	local y = {}
	for i = 1, #arr do
		table.insert(i <= index and x or y, arr[i])
	end
	return setmetatable(x, getmetatable(arr)), setmetatable(y, getmetatable(arr))
end

---Returns the sum of all elements of `arr`.
---@param arr number[]
---@return number
function Array.sum(arr)
	checkType('Module:Array.sum', 1, arr, 'table')
	local res = 0
	for i = 1, #arr do
		res = res + arr[i]
	end
	return res
end

---Extract a subtable from `arr`.
---@generic T: any[]
---@param arr T
---@param count integer # Length of the subtable.
---@param start? integer # Start index. Default is 1.
---@return T
function Array.take(arr, count, start)
	checkType('Module:Array.take', 1, arr, 'table')
	checkType('Module:Array.take', 2, count, 'number')
	checkType('Module:Array.take', 3, start, 'number', true)
	local x = {}
	start = start or 1
	for i = start, math.min(#arr, count + start - 1) do
		table.insert(x, arr[i])
	end
	return setmetatable(x, getmetatable(arr))
end

---Extract a subtable from `arr`.
---```
---local t = { 1, 2, 3, 4, 5, 6, 7, 8, 9, 10 }
---local x = arr.take_every( t, 2 )       --> x = { 1, 3, 5, 7, 9 }
---local x = arr.take_every( t, 2, 3 )    --> x = { 1, 3, 5 }
---local x = arr.take_every( t, 2, 3, 2 ) --> x = { 2, 4, 6 }
--- ```
---@generic T: any[]
---@param arr T
---@param n integer # Step size.
---@param start? integer # Start index.
---@param count? integer # Max amount of elements to get.
---@return T
function Array.take_every(arr, n, start, count)
	checkType('Module:Array.take_every', 1, arr, 'table')
	checkType('Module:Array.take_every', 2, n, 'number')
	checkType('Module:Array.take_every', 3, start, 'number', true)
	checkType('Module:Array.take_every', 4, count, 'number', true)
	count = count or #arr
	local r = {}
	local len = 0
	local i = start or 1
	while arr[i] ~= nil and len < count do
		len = len + 1
		r[len] = arr[i]
		i = i + n
	end
	return setmetatable(r, getmetatable(arr))
end

---Return a new table with all duplicates removed.
---@generic T: any[]
---@param arr T
---@param fn? fun(elem: any): any # Function to generate an id for each element. The result will then contain elements that generated unique ids.
---@return T
function Array.unique(arr, fn)
	checkType('Module:Array.unique', 1, arr, 'table')
	checkType('Module:Array.unique', 2, fn, 'function', true)
	fn = fn or function(item) return item end
	local r = {}
	local len = 0
	local hash = {}
	local i = 1
	while arr[i] ~= nil do
		local id = fn(arr[i])
		if not hash[id] then
			len = len + 1
			r[len] = arr[i]
			hash[id] = true
		end
		i = i + 1
	end
	return setmetatable(r, getmetatable(arr))
end

---Combine elements with the same index from multiple arrays.
---```
---local x = {1, 2, 3}
---local y = {4, 5, 6, 7}
---local z = arr.zip( x, y ) --> z = { { 1, 4 }, { 2, 5 }, { 3, 6 }, { 7 } }
---```
---@param ... any[]
---@return Array
function Array.zip(...)
	local arrs = { ... }
	checkType('Module:Array.zip', 1, arrs[1], 'table')
	local r = {}
	local _, longest = Array.max_by(arrs, function(arr) return #arr end)
	for i = 1, longest do
		local q = {}
		for j = 1, #arrs do
			table.insert(q, arrs[j][i])
		end
		table.insert(r, setmetatable(q, Array))
	end
	return setmetatable(r, Array)
end

-- Range indexing has a performance impact so this is placed in a separate subclass
Array.RI_mt = {}
for k, v in pairs(Array) do
	Array.RI_mt[k] = v
end

function Array.RI_mt.__index(t, k)
	if type(k) == 'table' then
		local res = {}
		for i = 1, #k do
			res[i] = t[k[i]]
		end
		return setmetatable(res, Array)
	else
		return Array[k]
	end
end

function Array.RI_mt.__newindex(t, k, v)
	if type(k) == 'table' then
		if type(v) == 'table' then
			for i = 1, #k do
				t[k[i]] = v[i]
			end
		else
			for i = 1, #k do
				t[k[i]] = v
			end
		end
	else
		rawset(t, k, v)
	end
end

---Enable range indexing on the input array.
---
---This has a performance impact on reads and writes to the table.
---```
---local t = arr{10, 11, 12, 13, 14, 15}:ri()
---print( t[{2, 3}] ) --> { 11, 12 }
---```
---@param arr any[]
---@param recursive? boolean # Default is false.
---@return Array
function Array.ri(arr, recursive)
	checkType('Module:Array.ri', 1, arr, 'table')
	checkType('Module:Array.ri', 2, recursive, 'boolean', true)
	arr = arr or {}
	if recursive then
		for _, v in pairs(arr) do
			if type(v) == 'table' then
				Array.ri(v, true)
			end
		end
	end

	if getmetatable(arr) == nil or getmetatable(arr) == Array then
		setmetatable(arr, Array.RI_mt)
	end

	return arr
end

---Globally enable range indexing on all Array objects by default.
---@param set boolean
function Array.allwaysAllowRangeIndexing(set)
	checkType('Module:Array.allwaysAllowRangeIndexing', 1, set, 'boolean')
	if set then
		Array.__index = Array.RI_mt.__index
		Array.__newindex = Array.RI_mt.__newindex
	else
		Array.__index = Array
		Array.__newindex = nil
	end
end

return Array
