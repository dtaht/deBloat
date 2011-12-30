#!/usr/bin/lua

require 'ceroenv'
ceroenv.wtf()
env = ceroenv.new()
ceroenv.show()

PPREREQ= {sch_sfq,sch_red,cls_flow,cls_none}
if ceroenv.prereq(PPREREQ) ~= nil then
   print("Awesome")
end


-- print(ceroenv.ge("SHELL"))
-- print(ceroenv.env["QMODEL"])