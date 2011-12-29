create table test_log (
   id varchar(10),
   ts   timestamp,
   duration float,
   description text
);

create table iperf (
       ts timestamp,
       srcip inet,
       srcport integer,
       dstip inet,
       dstport integer,
       run integer,
       duration interval,
       bytes bigint,
       bytes_sec bigint
);

-- it's really painful to do the conversions in lua
-- so do them in postgres

create table iperf_raw (
       ts varchar(20),
       srcip inet,
       srcport integer,
       dstip inet,
       dstport integer,
       run integer,
       duration varchar(20),
       bytes bigint,
       bytes_sec bigint
);