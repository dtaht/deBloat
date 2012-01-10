-- simple SFQ model
-- usage:

-- sfq = model:sfq.new(env)
-- mq = model:mq.new(env)
-- mq.VO{BINS=12}
-- mq.VI{BINS=10}
-- mq.BE{BINS=1000}
-- sfq:attach(mq)
-- mq.generate()

module(...,package.seeall)

