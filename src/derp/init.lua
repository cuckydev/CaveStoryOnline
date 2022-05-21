-- This is released into the public domain.
-- No warranty is provided, implied or otherwise.

-- NOTE: This really does the bare minimum for rich presence to work properly.
-- That's all I need this library to do.

-- Discord Everywhere Rich Presence
-- A Lua Rich Presence library with only two dependencies:
--  LuaJIT FFI (available at your local LOVE)
--  json.lua (easily removed if you want to do things the hard way)

-- Parameters:
-- client_id: application ID
-- callbacks: table, see Callbacks

-- Functions:
--  setRichPresence(activity/nil)
--  Should be called on READY.

-- Callbacks:
--  ready(event): Discord is ready with a given set of user details.
--   "event" is the event in full.
--  

return function (client_id, callbacks)
 local coretype = "unix"
 local ffi = require("ffi")
 ffi.cdef[[
  void memcpy(void * dst, const void * src, size_t len);
 ]]
 if ffi.os == "Windows" then
  -- it's proof as to how "different for no reason" Windows is that
  --  literally any other OS LOVE supports
  --  can use the same code apart from THIS ONE EXCEPTION
  coretype = "windows"
 end
 local coreok, core = pcall(require, "derp." .. coretype)
 if coreok then
  coreok, core = pcall(core, client_id)
 end
 print("DERP Startup:", coreok, core)
 if not coreok then
  core = {
   -- Fake core
   getpid = function () return 0 end,
   read = function (length) end,
   write = function (buffer) end,
   close = function () end
  }
 end
 local function sendPacket(opcode, data)
  --print("SEND", opcode, data)
  local i = ffi.new("struct {int32_t opcode; int32_t length; char str[" .. (#data + 1) .. "];}")
  local ip = ffi.new("void *", i)
  i.opcode = opcode
  i.length = #data
  i.str = data
  core.write(ffi.string(ip, 8 + #data))
 end
 local function recvPacket()
  local head = core.read(8)
  if not head then
   return
  end
  if #head < 8 then
   print("DERP WARNING: Corrupted data.")
   return
  end
  local i = ffi.new("struct {int32_t opcode; int32_t length;}")
  local ip = ffi.new("void *", i)
  ffi.C.memcpy(ip, ffi.cast("const void *", ffi.cast("const char *", head)), 8)
  local sz = core.read(i.length)
  if #sz < i.length then
   print("DERP WARNING: Corrupted data.")
   return
  end
  return i.opcode, sz
 end
 
 sendPacket(0, json.encode({v = 1, client_id = client_id}))
 return {
  service = function ()
   local opcode, data = recvPacket()
   if opcode then
    print(opcode, data)
    if opcode == 1 then
     local jd = json.decode(data)
     if jd.cmd == "DISPATCH" then
      if jd.evt == "READY" then
       if callbacks and callbacks.ready then
        callbacks.ready(jd.data)
       end
       sendPacket(1, json.encode({nonce=tostring(math.random()), evt="ACTIVITY_JOIN", cmd="SUBSCRIBE"}))
       sendPacket(1, json.encode({nonce=tostring(math.random()), evt="ACTIVITY_SPECTATE", cmd="SUBSCRIBE"}))
       sendPacket(1, json.encode({nonce=tostring(math.random()), evt="ACTIVITY_JOIN_REQUEST", cmd="SUBSCRIBE"}))
      end
     end
    end
   end
  end,
  -- For possible activityDetails,
  -- https://discordapp.com/developers/docs/topics/rpc#setactivity
  -- Note that some mandatory stuff in an Activity object is not allowed
  -- But a summary:
  --[[
   state?: "English state text",
   details?: "English details text",
   timestamps?: {
    start: 0,
    end: 1234 // unix time
   },
   assets?: {
    // If any of this is present, it all must be.
    large_image: "image Id",
    large_text: "large text Id",
    small_image: "image Id",
    small_text: "small text Id"
   },
   party?: {
    id: "Party ID", -- yet another odd unique string
    size: [1, 1], -- Current size, max size
   }
   secrets?: {
    join?: "blahgo secret",
    spectate?: "blahgo secret",
    match?: "blahboo secret"
   }
   instance: true -- Means this is an "instanced game session?"
  --]]
  setRichPresence = function (activityDetails, onSuccess)
   local nonce = tostring(math.random())
   local jsonObject = {
    cmd = "SET_ACTIVITY",
    nonce = nonce,
    args = {
     pid = core.getpid(),
     activity = activityDetails
    }
   }
   sendPacket(1, json.encode(jsonObject))
   return nonce
  end,
  close = function ()
   core.close()   
  end
 }
end
