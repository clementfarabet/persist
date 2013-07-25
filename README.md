PERSIST
=======

A persisting table for Lua.

Built using Redis, it's a simple abstraction that allows
one to write/read from a table that persists over sessions (the
key/vals are persisted in Redis).

```lua
-- load lib:
p = require('persist')()

-- write a few things to it:
p.test = 'something'
p.test2 = {
    some = 'table',
    nested = {is=1}
}
```

Shut down, start again:

```lua
-- load lib:
p = require('persist')()

-- still there?
print(p.test)
print(p.test2)
```

The following options can be passed:

```lua
p = require('persist')({
   url = 'localhost',
   port = 6379,
   verbose = false, -- this is not only used on startup
   namespace = 'th'  -- this is the namespace in Redis
})
```
