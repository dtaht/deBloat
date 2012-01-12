#!/usr/bin/lua

-- An attempt at a drop in replacement for tcrules.awk in lua

local class = { }
local prio = { }
local avgrate = { }
local pktsize = { }
local delay  = { }
local maxrate = { }
local qdisc = { }
local filter = { }
local dmax = 100
local linespeed = 0
local n = 0

function round(n)
   return math:ceil(n-.5)
end

function printf(...)
   return print(string.format(...))
end

function BEGIN()
	dmax=100
	if (linespeed <= 0) then linespeed = 128 end
	FS=":"
	n = 0
end

function parse(lclass , lprio, lavgrate, lpkgsize, ldelay, lmaxrate, lqdisc, lfilter)
   if lclass ~= "" then
      n = n + 1
      class[n] = lclass
      prio[n] = lprio
      avgrate[n] = (laverate * linespeed / 100)
      pktsize[n] = lpktsize
      delay[n] = ldelay
      maxrate[n] = (lmaxrate * linespeed / 100)
      qdisc[n] = lqdisc
      filter[n] = lfilter
   end
end


function END ()
   allocated = 0
   maxdelay = 0
   
   for i=1,n do
      -- set defaults
      if (pktsize[i] <= 0) then pktsize[i] = 1500 end
      if (prio[i] <= 0) then prio[i] = 1 end
      
      allocated = allocated + avgrate[i]
      sum_prio = sum_prio + prio[i]
      if ((avgrate[i] > 0) and delay[i] <= 0) then
	 sum_rtprio = sum_rtprio + prio[i]
      end
   end
   
   -- allocation of m1 in rt classes:
   -- sum(d * m1) must not exceed dmax * (linespeed - allocated)
   dmax = 0
   for i=1,n do
      if (avgrate[i] > 0) then 
	 rtm2[i] = avgrate[i]
	 if (delay[i] > 0) then
	    d[i] = delay[i]
	 else 
	    d[i] = 2 * pktsize[i] * 1000 / (linespeed * 1024)
	    if (d[i] > dmax) then dmax = d[i] end
	 end
      end
   end

   ds_avail = dmax * (linespeed - allocated)
   for i=1,n do
      lsm1[i] = 0
      rtm1[i] = 0
      lsm2[i] = linespeed * prio[i] / sum_prio
      if ((avgrate[i] > 0) and (d[i] > 0)) then
	 if (delay[i] <= 0) then
	    ds = ds_avail * prio[i] / sum_rtprio
	    ds_avail = ds_avail - ds
	    rtm1[i] = rtm2[i] + ds/d[i]
	 end
	 lsm1[i] = rtm1[i]
      else 
	 d[i] = 0
      end
   end
   
   -- main qdisc
   for i=1,n do
      printf("tc class add dev ",device," parent 1:1 classid 1:",class[i],"0 hfsc")
      if (rtm1[i] > 0) then
	 printf(" rt m1 ",round(rtm1[i]),"kbit d ",round(d[i] * 1000),"us m2 ",round(rtm2[i]),"kbit")
      end
      printf(" ls m1 ",round(lsm1[i]),"kbit d ",round(d[i] * 1000),"us m2 ",round(lsm2[i]),"kbit")
      print(" ul rate ",round(maxrate[i]),"kbit")
   end
   
   -- leaf qdisc
   avpkt = 1200
   for i=1,n do
      printf("tc qdisc add dev ",device," parent 1:",class[i],"0 handle ",class[i],"00: ")
      
      -- RED parameters - also used to determine the queue length for sfq
      -- calculate min value. for links <= 256 kbit, we use 1500 bytes
      -- use 50 ms queue length as min threshold for faster links
      -- max threshold is fixed to 3*min
      base_pkt=3000
      base_rate=256
      min_lat=50
      if (maxrate[i] <= base_rate) then min = base_pkt
      else min = round(maxrate[i] * 1024 / 8 * 0.05)
      end
      max = 3 * min
      limit = (min + max) * 3
      
      if (qdisc[i] ~= "") then
	 -- user specified qdisc
	 print(qdisc[i]," limit ",limit)
      elseif (rtm1[i] > 0) then
	 -- rt class - use sfq
	 print("sfq perturb 2 limit ",limit)
      else 
	 -- non-rt class - use RED
	 
	 avpkt = pktsize[i]
	 -- don't use avpkt values less than 500 bytes
	 if (avpkt < 500) then avpkt = 500 end
	 -- if avpkt is too close to min, scale down avpkt to allow proper bursting
	 if (avpkt > min * 0.70) then avpkt = avpkt * 0.70 end
	 
	 
	 -- according to http://www.cs.unc.edu/~jeffay/papers/IEEE-ToN-01.pdf a drop
	 -- probability somewhere between 0.1 and 0.2 should be a good tradeoff
	 -- between link utilization and response time (0.1: response; 0.2: utilization)
	 prob="0.12"
	 
	 rburst=round((2*min + max) / (3 * avpkt))
	 if (rburst < 2) then rburst = 2 end
	 print("red min ",min," max ", max, " burst ", rburst, " avpkt ", avpkt, " limit ", limit, " probability ", prob, " ecn")
      end
   end
   
   -- filter rule
   for i=1,n do
      print("tc filter add dev ",device," parent 1: prio ",class[i]," protocol ip handle ",class[i]," fw flowid 1:",class[i],"0") 
      filterc=1
      if (filter[i] ~= "") then
	 print("tc filter add dev ",device," parent ",class[i],"00: handle ",filterc,"0 ",filter[i])
	 filterc=filterc+1
      end
   end
end

