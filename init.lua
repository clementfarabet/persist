-- Libs
require 'sys'
local json = require 'cjson'
local redis = require 'redis'

-- Connect
function connect(opt)
   -- Namespace:
   opt = opt or {}
   url = opt.url or 'localhost'
   port = opt.port or 6379
   namespace = opt.namespace
   if namespace then
      namespace = namespace .. ':'
   end
   verbose = opt.verbose or false
   clear = opt.clear or false

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
         __cached[k] = v
         if v then
            v = json.encode(v)
            client:set(namespace..k,v)
         else
            client:del(namespace..k)
         end
      end,
      __index = function(self,k)
         if k=="_" then return __cached end
         local v = client:get(namespace..k)
         v = v and json.decode(v)
         return v
      end,
   })

   -- Restore:
   local keys = client:keys(namespace..'*')
   for _,key in ipairs(keys) do
      local k = key:gsub('^'..namespace,'')
      __cached[k] = persist[k]
   end

   -- Clear?
   for k in pairs(persist) do
      persist[k] = nil
   end

   -- Verbose:
   if verbose then
      if not next(__cached) then
         print('persist> new session started @ ' .. url .. ':' .. port)
      else
         print('persist> restored session @ ' .. url .. ':' .. port)
         print('persist> restored content:')
         print(__cached)
      end
   end

   -- Return the magic table
   return persist, client
end

-- Return connector
return connect
