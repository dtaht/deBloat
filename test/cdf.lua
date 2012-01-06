-- A cumulative distribution function should be EASY in lua
-- I was going to try to get gnuplot to do it, but I like it
-- as data - I can look at the 50% on a large number of plots
-- and know I'm winning

-- There happens to be a one liner to do this in gnuplot as well

-- via: http://www.christian-rossow.de/articles/Cumulative_Distribution_Function_CDF_With_Gnuplot_And_PostgreSQL.php

SELECT
    -- x-value: number of cars
    cars AS x, 
    -- y-value: percentage of days at most x cars passed the street
    --   calculated as the number of days with at most x cars devided by
    --   the total number days in the measurement period
    COUNT(day) OVER (ORDER BY cars) / 
       (SELECT COUNT(*) FROM cars_per_day)::real AS y
FROM cars_per_day

In statistics, CDFs are a common way to describe the probability that a random variable Z with a given probability distribution will be found at a value less than or equal to Z. Have a look at Figure 1. It shows a CDF for how many cars are passing on my street per day. You can read it like this: 35 or fewer cars (x-axis) are passing on my street in approximately 60% (y-axis) of all days.

Now comes the tricky thing. Listing 1 shows how I stored the data in my database. As everyone would do it, I just inserted one row per measurement interval (i.e., a day).

Listing 1: Plain measurement results in table 'cars_per_day'

day     cars
1          8
2         25
3         47
4         16
5         25
6         39
7          5


However, to draw a CDF, gnuplot expects the following format: Given a number of cars Z (x-value), what percentage of days at most Z cars passed on the street? To make this more clear, Listing 2 shows the outcome that gnuplot expects. 
