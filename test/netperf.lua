-- Various wrappers for netperf

-- netperf -P 0 -H 172.30.48.1 -j MIN_LATENCY,P95_LATENCY -v 0 -t TCP_STREAM -t TCP_RR
-- -P 0 - no headers -v 0 no extra info, just the result -t TCP_STREAM
-- l testlen
-- -D secs
-- I would prefer to set the test duration in bytes....

module(...,package.seeall)

tests { TCP_RR, TCP_STREAM, TCP_MAERTS, TCP_CRR, UDP_STREAM, UDP_RR }
[--                     STREAM_STREAM
                     STREAM_RR
                     DG_STREAM
                     DG_RR
                     SCTP_STREAM
                     SCTP_STREAM_MANY
                     SCTP_RR
                     SCTP_RR_MANY
                     LOC_CPU
                     REM_CPU
   --]

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