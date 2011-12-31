-- Latency under load test
-- at t - 10, we start pinging
-- at t - 5,  we start a TCP_RR test
-- (httping, ab, other benchmarks are feasible)
-- at t we load up the networks for x time
-- at x + 5 we stop TCP_RR
-- at x + 10 we stop pinging

require "cero"
require "cerodb"
require "netperf"
require "iperf"
require "editor"

local edit = editor.edit

defaults = { ["duration"]=100, ["ip"]="172.30.49.27", ["iperf_count"]=10 }

function init()
end

function end()
end

ID = "something"
TITLE="Latency under load test"
USER = "somebody"

description = [[
"\[\[Before the test runs, why not take some 
time out to describe the conditions it ran under?\]\]"
]];

-- It would be better if we could fire these off on the exact interval
-- then collect the results. Can't easily fork or do interprocess comm
-- in lua sadly... it would be nice to type in the test description 
-- while running. Also be able to fire off remote tests with pdsh

-- Really want each of the tests to be objects, too.

-- startat?

function main() 
   -- FIXME: parse command line args at some point
   ipc = defaults["IPERF_COUNT"]
   ip = defaults["IP"]
   pt = defaults["DURATION"] + 20
   nt = pt - 10
   edit(tname,sf("TEST=%g\nID=%g\nDURATION = %g\nIP=%g\nIPERFCOUNT=%g\n%s",TITLE,ID,pt-20,ip,ipc,description))
   fp = fping.fping(pt,ip)
   sleep(5)
   np = netperf.tcp_rr(nt,ip)
   sleep(5)
   iperf = iperf.iperf(ipc,ip)
   tname = os:tmpname()
   -- collect data - we're going to block on the reads here
   -- if we run some tests too long they will block on writes
   -- so we kind of want this to be yielding
   iperf.process(iperf)
   netperf.process(np)
   fping.process(fp)
   -- FIXME load up the db
   -- FIXME remove the temp file
   -- Plot the results
end