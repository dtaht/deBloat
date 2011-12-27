#!/usr/bin/lua

    function fromCSV (s)
      s = s .. ','        -- ending comma
      local t = {}        -- table to collect fields
      local fieldstart = 1
      repeat
        -- next field is quoted? (start with `"'?)
        if string.find(s, '^"', fieldstart) then
          local a, c
          local i  = fieldstart
          repeat
            -- find closing quote
            a, i, c = string.find(s, '"("?)', i+1)
          until c ~= '"'    -- quote not followed by quote?
          if not i then error('unmatched "') end
          local f = string.sub(s, fieldstart+1, i-1)
          table.insert(t, (string.gsub(f, '""', '"')))
          fieldstart = string.find(s, ',', i) + 1
        else                -- unquoted; find next comma
          local nexti = string.find(s, ',', fieldstart)
          table.insert(t, string.sub(s, fieldstart, nexti-1))
          fieldstart = nexti + 1
        end
      until fieldstart > string.len(s)
      return t
    end
    
    t = fromCSV('"hello "" hello", "",""')
    for i, s in ipairs(t) do print(i, s) end
      --> 1       hello " hello
      --> 2        ""
      --> 3
