-- wrapper for the apache benchmark

module(...,package.seeall)

comment = [[
-g filename     Output collected data to gnuplot format file.
-e filename     Output CSV file with percentages served
-n requests     Number of requests to perform
-c concurrency  Number of multiple requests to make
-t timelimit    Seconds to max. wait for responses
-b windowsize   Size of TCP send/receive buffer, in bytes
-p postfile     File containing data to POST. Remember also to set -T

CSV is in percentage served, time in ms

]]

