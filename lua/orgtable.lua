-- Convert from/to org tables from lua

module(...,package.seeall)

-- return a string reformatting lua table formatted in org format, which is:
-- |value|value|value|

function orgtable:to(...) 
end

-- return a table of org-mode formatted strings from a lua table
function orgtable:to_table(...) 
end

-- parse a string formatted in org format
-- and return a lua table

function orgtable:from(...) 
end

function orgtable:parse(...) 
end

-- Join two org mode formatted tables

function orgtable:join(...)
