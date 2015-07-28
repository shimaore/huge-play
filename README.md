FreeSwitch CCNQ4 middlewares and configuration

Note: wrt modules, ccnq3 also had:
- `mod_console`      -- not needed, only sets configuration
- `mod_loopback`     -- not needed
- `mod_spandsp`      -- only needed for transcoding and T.38 gateway
- `mod_db`           -- not needed, dialplan `db` command
- `mod_hash`         -- not needed, this would be done on the Node.js side
- `mod_native_file`  -- only needed if we had G.711 raw files
