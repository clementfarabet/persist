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
   namespace = (opt.namespace or 'th') .. '.'
   verbose = opt.verbose or false
   clear = opt.clear or false

   -- Connect:
   local client = redis.connect(url,port)

   -- New persisting table:
   local persist = {__cached={}}
   local __cached = persist.__cached
   setmetatable(persist, {
      __newindex = function(self,k,v)
         __cached[k] = v
         if v then
            v = json.encode(v)
            client:set(namespace..k,v)
         else
            client:del(namespace..k)
         end
      end,
      __index = function(self,k)
         local v = client:get(namespace..k)
         v = json.decode(v)
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
