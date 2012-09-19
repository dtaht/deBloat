#!/bin/sh

DEV=eth2

# sample the queue depth over the interval

DUR=$1

tc qdisc show dev $DEV | grep backlog

