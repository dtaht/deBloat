#!/usr/bin/env lua
-- vim: set shiftwidth=3 softtabstop=3 expandtab :

-- Lua interface to Gnuplot deeply inspired by N. Devillard's C interface,
-- `gnuplot_i.c'.  Written by Ken Smith kgsmith gmail com in 2007.
-- Released into the public domain, Dec 15, 2007.
--
-- The philosophy behind this particular approach is based on the brash
-- presumption that Gnuplot users generally know what they want to write to the
-- gnuplot command line.  This module is simply a small dab of glue between a
-- Lua programmer and Gnuplot.
--
-- This module overrides the builtin type() to respond to a __type metamethod.
-- Yank that bit if it's not useful to you.
--
-- Usage:
-- require('gnuplot_t')
--
-- local gp = gnuplot_t.new()
-- if in_two_steps then
--    gp('set grid')
--    gp{f = 'sin(x)'}
-- else
--    gp('set grid'){f = 'sin(x)'}
-- end
--
-- gp{
--    pre = '[1:5]',
--    f = 'sin(x)',
--    post = 'title "sin(x)"',
-- }
--
-- -- simple data
-- gp{f = {1,2,3,4,5}}
--
-- -- paired data
-- gp{f = {{1,1},{2,2},{3,3},{4,4},{5,5}}}
--
-- -- 3d data
-- gp{
--    f = {
--       {{1,1,1},{1,2,2},{1,3,3}},
--       {{2,1,1},{2,2,2},{2,3,3}},
--       {{3,1,1},{3,2,2},{3,3,3}}
--    }
-- }
--
-- Also, see unit tests at the end of this file.
--
-- Caveat: Plotting data leaves tmp files.  I see no way around this due to the
-- race condition between writing to the gnuplot pipe and Gnuplot reading the
-- data files.  When you're sure everything has been plotted, you can call
-- gp:rmtemp() to clear out the temp files or even gp:close() to close the pipe
-- to gnuplot as well.
--
-- Change log
-- 2007.12.15  initial public release

-- the module
gnuplot_t = {
   new = function (gnuplot_binary)
      gnuplot_binary = gnuplot_binary or '/usr/bin/gnuplot'
      local o = {
         gnuplot = io.popen(gnuplot_binary, 'w'),
         binary = gnuplot_binary,
         mktemp = gnuplot_t.mktemp,
         rmtemp = gnuplot_t.rmtemp,
         close = gnuplot_t.close,
      }
      setmetatable(o, gnuplot_t.mt)
      return o
   end,

   -- Used internally for plotting data.  Not used for plotting functions.
   mktemp = function (self)
      local tmpname = os.tmpname()
      local tmpf = io.open(tmpname, 'w')
      self.tmps = self.tmps or {}
      self.tmps[tmpname] = tmpf
      return tmpname, tmpf
   end,

   -- Be careful when calling this.  If you call it too soon after
   -- plotting data, gnuplot may not yet be finished with the file.
   rmtemp = function (self)
      -- If lua supported __gc for tables, this would certainly go there
      -- instead of here.
      for name,handle in pairs(self.tmps or {}) do
         pcall(handle.close, handle) -- ensure it's closed
         os.remove(name)
         self.tmps[name] = nil
      end
   end,

   close = function (self)
      self:rmtemp()
      self.gnuplot:close()
      self.gnuplot = nil
      self.replot = false
   end,

   mt = {
      __type = function ()
         return 'gnuplot_t'
      end,

      -- Two usages:
      -- o{
      --    f = table of data or function,
      --    pre = inserted at the beginning of the plot command
      --          after (re|s)plot ,
      --    post = inserted at the end of the plot command
      -- }
      -- o('command')
      -- 
      -- also
      --
      -- o('command'){
      --    f = ...,
      --    pre = ...,
      --    post = ...,
      -- }
      __call = function (self, ...)
         if not self.gnuplot then
            -- reopen if closed
            self.gnuplot = io.popen(self.binary, 'w')
         end

         if type(arg[1]) == 'string' then
            self.gnuplot:write(arg[1])
            self.gnuplot:write('\n')
            self.gnuplot:flush()
         elseif type(arg[1]) == 'table' then
            local b = {insert = table.insert, concat = table.concat}

            -- The default behavior is to replot for every plot after
            -- the first.  Set o.replot between calls to plot manually
            -- if desired.
            b:insert('plot')
            if self.replot then
               b:insert(1, 're')
            end
            self.replot = true

            -- add range statement or other things that
            -- should appear before the datafile name
            -- on the gnuplot command line
            b:insert(arg[1].pre or '')

            if type(arg[1].f) == 'string' then
               -- add function
               b:insert(' ')
               b:insert(arg[1].f)

               -- default title is the name of the function
               title = title or arg[1].f
            elseif type(arg[1].f) == 'table' then
               local d = arg[1].f
               local tmpname, tmpf = self:mktemp()
               b:insert(' "')
               b:insert(tmpname)
               b:insert('"')

               if type(d[1]) == 'number' then
                  -- 1d data
                  for i,v in ipairs(d) do
                     -- ensure uniformity
                     assert(type(v) == 'number',
                        'gnuplot_t: plot: type d[' .. i .. '] was '
                        .. type(v)
                     )
                     tmpf:write(v)
                     tmpf:write('\n')
                  end
               elseif type(d[1]) == 'table' then
                  if type(d[1][1]) == 'number' then
                     -- 2d data, eg. timeseries
                     for i,t in ipairs(d) do
                        for j,v in ipairs(t) do
                           assert(type(v) == 'number',
                              'gnuplot_t: plot: type d['
                              .. i
                              .. ']['
                              .. j
                              .. '] was '
                              .. type(v)
                           )
                           tmpf:write(v)
                           tmpf:write(' ')
                        end
                        tmpf:write('\n')
                     end
                  elseif type(d[1][1]) == 'table' then
                     -- 3d data
                     -- splot instead of plot or replot
                     if b[1] == 're' then
                        b[1] = 's'
                     else
                        b:insert(1,'s')
                     end
                     for i,t in ipairs(d) do
                        for j,subt in ipairs(t) do
                           for m,v in ipairs(subt) do
                              assert(type(v) == 'number',
                                 'gnuplot_t: plot: type d['
                                 .. i
                                 .. ']['
                                 .. j
                                 .. ']['
                                 .. m
                                 .. ' was '
                                 .. type(v)
                              )
                              tmpf:write(v)
                              tmpf:write(' ')
                           end
                           tmpf:write('\n')
                        end
                        tmpf:write('\n')
                     end
                  else
                     error('gnuplot_t: plot: type(arg[1].f[1][1]) is '
                        .. type(d[1][1])
                     )
                  end
               else
                  error('gnuplot_t: plot: type(arg[1].f[1]) is '
                     .. type(d[1])
                  )
               end

               tmpf:flush()
               tmpf:close()
            else
               error('gnuplot_t: plot: type(arg[1].f) is '
                  .. type(arg[1].f)
               )
            end

            -- append arg[1].post to the command line
            b:insert(arg[1].post or '')

            local command = b:concat()

            -- run the command
            self(command)

            -- in case you were curious
            return self, command
         else
            error('gnuplot_t: __call: type(arg[1]) is ' .. type(arg[1]))
         end

         return self
      end,

      __tostring = function(self)
         return 'gnuplot_t'
      end,
   },
}

-- make type() metamethod __type aware
if type(gnuplot_t.new()) ~= 'gnuplot_t' then
   originaltype = type
   type = function(o)
      __type = rawget(getmetatable(o) or {}, '__type')
      if originaltype(__type) == 'function' then
         return __type(o)
      else
         return originaltype(o)
      end
   end
end

-- Run unit tests, `lua gnuplot_t.lua`
if arg and arg[0]:match('.*gnuplot_t.lua') then

   -- These tests must all succeed and return true.
   local must_succeed = {
      { -- basic interface tests
         init = function ()
            gp = gnuplot_t.new()
         end,

         cleanup = function ()
            gp = nil
         end,

         type_test = function ()
            return type(gp) == 'gnuplot_t'
         end,

         set_test = function ()
            gp('set grid')
            return true
         end,
      },

      { -- test function plotting
         init = function ()
            gp = gnuplot_t.new()
         end,

         cleanup = function ()
            gp = nil
         end,

         plot_equation_test = function ()
            gp{
               f = 'sin(x)',
               post = 'with lines',
            }
            return true
         end,
      },

      { -- test data plotting
         init = function ()
            gp = gnuplot_t.new()
         end,

         cleanup = function ()
            gp = nil
         end,

         plot_1d_data = function ()
            gp{
               f = {1,2,3,4,5},
               post = 'title "1d data" with points',
            }
            return true
         end,

         plot_2d_data = function ()
            gp{
               f = {
                  {.5,.5},
                  {.6,.6},
                  {.55,.4},
                  {.8,.8},
                  {.9,.9}
               },
               post = 'title "zig zag" with linespoints',
            }
            return true
         end,

         plot_3d_data = function ()
            gp2 = gnuplot_t.new()
            gp2('set grid'){
               f = {
                  {
                     {1,1,1},{1,2,5},{1,3,5},{1,4,5},{1,5,1},
                  },
                  {
                     {2,1,5},{2,2,5},{2,3,5},{2,4,5},{2,5,5},
                  },
                  {
                     {3,1,5},{3,2,5},{3,3,5},{3,4,5},{3,5,5},
                  },
                  {
                     {4,1,5},{4,2,5},{4,3,5},{4,4,5},{4,5,5},
                  },
                  {
                     {5,1,1},{5,2,5},{5,3,5},{5,4,5},{5,5,1},
                  }
               },
               post = 'title "grid"'
            }
            return true
         end,
      },

   }

   -- These functions must all result in an error() or similar.
   local must_fail = {
      { -- basic failure in __call
         call_nil = function ()
            gp()
         end,
      },

      { -- test data plotting corrupted data
         init = function ()
            gp = gnuplot_t.new()
         end,

         cleanup = function ()
            gp = nil
         end,

         corrupted_plot_1d_data = function ()
            gp{
               f = {1,2,'corrupted',4,5},
               post = 'title "1d data" with points',
            }
            return true
         end,

         corrupted_plot_2d_data = function ()
            gp{
               f = {
                  {.5,.5},
                  {.6,.6},
                  {.55,'corrupted'},
                  {.8,.8},
                  {.9,.9}
               },
               post = 'title "zig zag" with linespoints',
            }
            return true
         end,

         corrupted_plot_3d_data = function ()
            gp2 = gnuplot_t.new()
            gp2('set grid'){
               f = {
                  {
                     {1,1,1},{1,2,5},{1,3,5},{1,4,5},{1,5,1},
                  },
                  {
                     {2,1,5},{2,2,5},{2,3,5},{2,4,5},{2,5,5},
                  },
                  {
                     {3,1,5},{3,2,5},{3,3,5},{3,4,5},{3,5,5},
                  },
                  {
                     {4,1,5},{4,2,5},{4,3,5},{4,4,'corrupted'},{4,5,5},
                  },
                  {
                     {5,1,1},{5,2,5},{5,3,5},{5,4,5},{5,5,1},
                  }
               },
               post = 'title "grid"'
            }
            return true
         end,
      },
   }

   -- run success tests
   for i,test_battery in ipairs(must_succeed) do
      if test_battery.init then
         test_battery.init()
      end
      for name,test in pairs(test_battery) do
         if name ~= 'init' and name ~= 'cleanup' then
            assert(test(),
               'gnuplot_t: unit tests: (error) must succeed: '
               .. name
               .. ' failed.'
            )
            print('gnuplot_t: unit tests: (ok) '
               .. name
               .. ' succeeded.'
            )
         end
      end
      if test_battery.cleanup then
         test_battery.cleanup()
      end
   end

   -- run failure tests
   for i,test_battery in ipairs(must_fail) do
      if test_battery.init then
         test_battery.init()
      end
      for name,test in pairs(test_battery) do
         if name ~= 'init' and name ~= 'cleanup' then
            assert(not pcall(test),
               'gnuplot_t: unit tests: (error) must fail: '
               .. name
               .. ' did not fail as expected'
            )
            print('gnuplot_t: unit tests: (ok) '
               .. name
               .. ' failed as expected.'
            )
         end
      end
      if test_battery.cleanup then
         test_battery.cleanup()
      end
   end

end

-- register the module
module('gnuplot_t')
