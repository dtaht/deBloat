#!/usr/bin/lua

-- table
t = { T,NAME,VALUE }
t2 = { T,NAME,VALUE }
t.NAME = "qdisc"
t.VALUE = "red"
t2.NAME = "qdisc"
t2.VALUE = "red2"

c = { }

for i=0,64 do
   c[i] = t
end

c[65] = t2
c[66] = t

c1 = { T, NAME, VALUE }
c1.NAME="class"
c1.VALUE="qfq"

d = { }

for i=1,4 do
   local c2 = c1
   c2["T"] = c
   d[i] = c1
end

e = d[2]

print(e["T"])

g = e["T"]

f = g["T"]

print(f[1])
print(f["NAME"],f["VALUE"])
