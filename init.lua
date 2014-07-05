-- Libs
require 'sys'
local json = require 'cjson'
local redis = require 'redis'

-- Connect
local function connect(opt)
   -- Namespace:
   opt = opt or {}
   local url = opt.url or 'localhost'
   local port = opt.port or 6379
   local namespace = opt.namespace
   if namespace then
      namespace = namespace .. ':'
   else
      namespace = ''
   end
   local verbose = opt.verbose or false
   local clear = opt.clear or false
   local cache = opt.cache or false

   -- Connect:
   local ok,client = pcall(function() return redis.connect(url,port) end)
   if not ok then
      print('persist> error connecting to redis @ ' .. url .. ':' .. port)
      print('persist> make sure you have a running redis server (redis-server)')
      error()
   end

   -- New persisting table:
   local persist = {}
   local __cached = {}
   setmetatable(persist, {
      __newindex = function(self,k,v)
         if k=="_" then print('persist> _ is a reserved keyword') return end
         if cache then __cached[k] = v end
         if not client:ping() then
            client = redis.connect(url,port)
         end
         if v then
            v = json.encode(v)
            client:set(namespace..k,v)
            if verbose then
               print('persist> stored ' .. k)
            end
         else
            client:del(namespace..k)
            if verbose then
               print('persist> cleared ' .. k)
            end
         end
      end,
      __index = function(self,k)
         if k=="_" then return __cached end
         if not client:ping() then
            client = redis.connect(url,port)
         end
         local v = client:get(namespace..k)
         v = v and json.decode(v)
         if verbose then
            print('persist> restored ' .. k)
         end
         return v
      end,
      __tostring = function(self)
         local keys = client:keys(namespace..'*')
         local n = #keys
         return '<persisting table @ redis://'..namespace..'*, #keys='..n..'>'
      end,
      keys = function(self)
         local keys = client:keys(namespace..'*')
         return keys
      end
   })

   -- Restore:
   if cache then
      local keys = client:keys(namespace..'*')
      for _,key in ipairs(keys) do
         local k = key:gsub('^'..namespace,'')
         __cached[k] = persist[k]
      end
   end

   -- Clear?
   if clear then
      local keys = client:keys(namespace..'*')
      local n = #keys
      for _,key in ipairs(keys) do
         local k = key:gsub('^'..namespace,'')
         client:del(namespace..k)
      end
      if verbose then
         print('persist> cleared ' .. n .. ' entries')
      end
   end

   -- Verbose:
   if verbose then
      -- N Keys:
      local keys = client:keys(namespace..'*')
      local n = #keys
      if n == 0 then
         print('persist> new session started @ ' .. url .. ':' .. port)
      else
         print('persist> restored session @ ' .. url .. ':' .. port)
         print('persist> restored ' .. n .. ' keys')
      end
   end

   -- Return the magic table
   return persist, client
end

-- Return connector
return connect
