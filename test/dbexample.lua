-- load driver
require "luasql.postgres"
-- create environment object
env = assert (luasql.postgres())
-- connect to data source
con = assert (env:connect("d"))
-- reset our table
res = con:execute("DROP TABLE people")
res = assert (con:execute[[
  CREATE TABLE people(
    name  varchar(50),
    email varchar(50)
  )
]])
-- add a few elements
list = {
  { name="Jose das Couves", email="jose@couves.com", },
  { name="Manoel Joaquim", email="manoel.joaquim@cafundo.com", },
  { name="Maria das Dores", email="maria@dores.com", },
}
for i, p in pairs (list) do
  res = assert (con:execute(string.format([[
    INSERT INTO people
    VALUES ('%s', '%s')]], p.name, p.email)
  ))
end
-- retrieve a cursor
cur = assert (con:execute("SELECT name, email from people"))
-- print all rows, the rows will be indexed by field names
row = cur:fetch ({}, "a")
while row do
  print(string.format("Name: %s, E-mail: %s", row.name, row.email))
  -- reusing the table of results
  row = cur:fetch (row, "a")
end
-- close everything
cur:close()
con:close()
env:close()

-- function rows (connection, sql_statement)
--   local cursor = assert (connection:execute (sql_statement))
--   return function ()
--     return cursor:fetch()
--   end
-- end

-- require "luasql.mysql"
-- env = assert (luasql.mysql())
-- con = assert (env:connect"my_db")
-- for id, name, address in rows (con, "select * from contacts") do
--   print (string.format ("%s: %s", name, address))
-- end
