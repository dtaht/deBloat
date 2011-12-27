p1 <- read.table("p1.ts.cut")
p2 <- read.table("p2.ts.cut")

postscript("plot.ps", width = 6, height =4)
par(mar=c(3,3,2,1), mgp=c(2,0.5,0))
l = max( length(p1[,1]), length(p2[,1]))
h = max( p1[,1], p2[,1])

plot( p1[,1], ylab = "Wireless ping RTTs", xlab="Time [ping interval 1 sec]", 
    xlim = c(0,l), ylim = c(0,h), lty = 1, pch = 1, col = 1, type='o')
lines( p2[,1], lty = 1, pch = 2, col = 2, type = 'o')
legend( "topleft", leg = c("txqueuelen 37", "txqueuelen 1000"), lty = 1, pch = 1:2, col = 1:2)
title("Bufferbloat reduced at a CeroWrt Access Point\n6 stations doing simultaneous TCP transfers")
dev.off()
