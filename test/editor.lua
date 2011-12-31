-- Pop up an editor

module(...,package.seeall)
local sf = string.format
local exec = os:execute

-- bg edit somehow?
-- web editing seems feasible, too.

function edit(filename, data) 
   e = ""
   if e = os:getenv("VISUAL") == nil then 
      if e = os:getenv("EDITOR") == nil then 
	 -- FIXME - look for zile, emacs, vi, etc
	 e = "emacs"
      end
   end

   if data ~= nil then 
      o = io:open(filename,"w")
      o:write(data)
      o:close()
   end

   return(exec(sf("%s %s",e,filename)))

end

-- sometimes having to wrap common things in shell bothers me

function sed(...) 
   return (exec(sf("sed %s")))
end