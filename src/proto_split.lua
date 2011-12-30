#!/usr/bin/lua 

-- split

-- FIXME we want to construct a two dimensional table
-- then join it

function proto_split(s,max)
   c = 1
   t = split(',',s)
   p = 0
   for i,v in ipairs(t) do
      c = c + (p = # split(':',v))
      if c > max then 
	 n = n + 1
	 s[n] = v 
	 c = p
      else 
	 s[n] = s[n] .. "," .. v 
      end
   end
   return(s)
end

t = proto_split("a,b,c,d,e,f,g,h,i:j",4)
print(# t)