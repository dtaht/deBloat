#!/usr/bin/lua

require "cero"

local strjoin = cero.strjoin
local sf = string.format
local to_value = cero.to_sqlvaluestr

t = { "20111228174427","172.30.50.2","36249","172.30.49.27","5001","3","0.0-10.1","23461888","18612244" }

print(to_value(t))

t2 = cero.sqlfield(t)
t = cero.sqlquote(t)

print(sf("(%s) VALUES (%s)",strjoin(",",t2),strjoin(",",t)))
