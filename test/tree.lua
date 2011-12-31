disc.parent = 1
attach(disc.parent,child)

child = { NAME, CHILD } 
p = { NAME, CHILD }
p2 = { NAME, CHILD }

for i =1,64 do
   p[i].CHILD = child
end

for j=1,4 do
   parent p2[j].CHILD = p
end

cu

iterator

a {
   child
  