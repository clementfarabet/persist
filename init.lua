-- Libs
require 'sys'
local json = require 'cjson'
local redis = require 'redis'

-- Connect
function connect(opt)
   -- Namespace:
   opt = opt or {}
   local url = opt.url or 'localhost'
   local port = opt.port or 6379
   local namespace = opt.namespace
   if namespace then
      namespace = namespace .. ':'
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
         else
            client:del(namespace..k)
         end
      end,
      __index = function(self,k)
         if k=="_" then return __cached end
         if not client:ping() then
            client = redis.connect(url,port)
         end
         local v = client:get(namespace..k)
         v = v and json.decode(v)
         return v
      end,
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
      for k in pairs(persist._) do
         persist[k] = nil
      end
   end

   -- Verbose:
   if verbose then
      if not next(__cached) then
         print('persist> new session started @ ' .. url .. ':' .. port)
      else
         print('persist> restored session @ ' .. url .. ':' .. port)
         if cache then
            print('persist> restored content:')
            print(__cached)
         end
      end
   end

   -- Return the magic table
   return persist, client
end

-- Return connector
return connect
