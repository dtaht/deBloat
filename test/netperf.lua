-- Various wrappers for netperf

-- netperf -P 0 -H 172.30.48.1 -j MIN_LATENCY,P95_LATENCY -v 0 -t TCP_STREAM -t TCP_RR
-- -P 0 - no headers -v 0 no extra info, just the result -t TCP_STREAM
-- l testlen
-- -D secs
-- I would prefer to set the test duration in bytes....
-- Demo mode gives me one result per second but it is not compiled in. Sigh

module(...,package.seeall)

tests { TCP_RR, TCP_STREAM, TCP_MAERTS, TCP_CRR, UDP_STREAM, UDP_RR }

--[[                 
STREAM_STREAM
STREAM_RR
DG_STREAM
DG_RR
SCTP_STREAM
SCTP_STREAM_MANY
SCTP_RR
SCTP_RR_MANY
LOC_CPU
REM_CPU
--]]

require "cero"

-- FIXME: I still kind of want objects here
-- so that I can pass a tcp_rr object, process it 
-- etc

local popen = cero:popen                     

local exec = cero:exec
local sf = string.format
local NETPERF = cero:findexe("netperf")
local NETSERVER = cero:findexe("netserver")

local function ns()
   return popen(sf("%s %s",NETSERVER,s))
end

local function np(s)
   return popen(sf("%s -P 0 -v 0 %s",NETPERF,s))
end

function tcp_rr (c,ip) 
   return np(sf("-l %d -H %s -t TCP_RR",c,ip))
end

function tcp_stream (c,ip) 
   return np(sf("-l %d -H %s -t TCP_STREAM",c,ip))
end

function udp_stream (c,ip) 
   return np(sf("-l %d -H %s -t UDP_STREAM",c,ip))
end

function udp_rr (c,ip) 
   return np(sf("-l %d -H %s -t UDP_RR",c,ip))
end

function tcp_rr (c,ip) 
   return np(sf("-l %d -H %s -t TCP_MAERTS",c,ip))
end

-- We want to get sanely formatted results out of 
-- various netperf tests
-- as well as additional information about the test

-- table to json 
-- csv to table