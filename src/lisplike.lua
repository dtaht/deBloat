-- misc lisp like functions
-- http://en.wikibooks.org/wiki/Lua_Functional_Programming/Functions
-- return table.concat(map(double, {1,2,3}),",")
-- t = mapn(function(a,b) return a+b end, {1,2,3}, {4,5,6})

module(...,package.seeall)

-- I have no idea why map and mapn are not in lua... temptation?

function map(func, array)
  local new_array = {}
  for i,v in ipairs(array) do
    new_array[i] = func(v)
  end
  return new_array
end

function mapn(func, ...)
  local new_array = {}
  local i=1
  local arg_length = # arg
  while true do
    local arg_list = map(function(arr) return arr[i] end, arg)
    if # arg_list < arg_length then return new_array end
    new_array[i] = func(unpack(arg_list))
    i = i+1
  end
end

-- fixme, write nth, car, etc

function cdr(arr)
  local new_array = {}
  for i = 2, # arr do
    table.insert(new_array, arr[i])
  end
end

function cons(car, cdr)
  local new_array = {car}
  for _,v in cdr do
    table.insert(new_array, v)
  end
  return new_array
end

function lisp_remove_if(func, arr)
  if # arr == 0 then return {} end
  if func(arr[1]) then
    return lisp_remove_if(func, cdr(arr))
  else
    return cons(arr[1], lisp_remove_if(func, cdr(arr)))
  end
end

function lua_remove_if(func, arr)
  local new_array = {}
  for _,v in arr do
    if not func(v) then table.insert(new_array, v) end
  end
  return new_array
end
