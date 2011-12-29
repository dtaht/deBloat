-- Various wrappers for netperf

module(...,package.seeall)

require "cero"

local popen = cero:popen
local exec = cero:exec
local sf = string.format
local NETPERF = cero:findexe("netperf")
local NETSERVER = cero:findexe("netserver")

local function netperf(...)
   return popen(sf("%s %s",NETPERF,...))
end

-- We want to get sanely formatted results out of 
-- various netperf tests
-- as well as additional information about the test

-- table to json 
-- csv to table