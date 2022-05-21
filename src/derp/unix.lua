-- This is released into the public domain.
-- No warranty is provided, implied or otherwise.

local ffi = require("ffi")
local F_SETFL = 4
local O_NONBLOCK = 2048
local AF_UNIX = 1 -- PF_UNIX / PF_LOCAL
local SOCK_STREAM = 1

ffi.cdef[[
 typedef struct {
  unsigned short int family;
  char text[108];
 } sockaddr_un;
 int getpid();
 int socket(int domain, int type, int protocol);
 int connect(int fd, void * addr, size_t addrsize);
 int fcntl(int fd, int cmd, int flag);
 // size_t is supported, but not ssize_t.
 // this kind of sucks.
 size_t send(int sockfd, const void *buf, size_t len, int flags);
 size_t recv(int sockfd, const void *buf, size_t len, int flags);
 int close(int fd);
 int mkdir(const char * path, uint32_t mode);
]]
local function ssize_t(s)
 s = tonumber(s)
 local t = 2^((ffi.sizeof("size_t") * 8) - 1)
 if s >= t then
  s = s - (t * 2)
 end
 return s
end

return function (application)
 local function fR()
  if os.getenv("DERP_DISABLE_PROTOCOLS") == "1" then
   -- If the user explicitly tells DERP not to mess with protocols,
   --  listen to them. They probably have their own working setup.
   return
  end
  -- On Linux and most BSDs, we can rely on XDG specifications.
  -- On Mac, we have to use Discord's custom system.
  if ffi.os == "OSX" then
   --------------- MAC OS X STUFF. THIS IS PROBABLY GOING TO NEED TO BE CHANGED.
   local cmd = "unknown"
   if love then
    cmd = love.filesystem.getSource()
   end
   local home = os.getenv("HOME")
   if not home then print("DERP Mac unable to get HOME") return end
   ffi.C.mkdir(home .. "/Library", 0x1ED)
   ffi.C.mkdir(home .. "/Library/Application Support", 0x1ED)
   ffi.C.mkdir(home .. "/Library/Application Support/discord", 0x1ED)
   ffi.C.mkdir(home .. "/Library/Application Support/discord/games", 0x1ED)
   local path = home .. "/Library/Application Support/discord/games/" .. application .. ".json"
   print("DERP Mac decided on", path, cmd)
   local f = io.open(path, "wb")
   if not f then print("register fail") return end
   f:write(require("json").encode({command = cmd}))
   f:close()
  else ----------GENERIC UNIX STUFF. CUCKY, DON'T TOUCH THIS UNLESS I SAY SO.
   -- Cucky, if you're using the AppImage packaging method, this will work fine.
   local cmd = "unknown"
   if love then
    cmd = love.filesystem.getSource()
   end
   local home = os.getenv("HOME")
   if not home then print("DERP Unix unable to get HOME") return end
   ffi.C.mkdir(home .. "/.local", 0x1ED)
   ffi.C.mkdir(home .. "/.local/share", 0x1ED)
   ffi.C.mkdir(home .. "/.local/share/applications", 0x1ED)
   local path = home .. "/.local/share/applications/discord-" .. application .. ".desktop"
   print("DERP Unix decided on", path, cmd)
   local f = io.open(path, "w")
   if not f then print("register fail") return end
   f:write("[Desktop Entry]\n")
   f:write("Name=Cave Story Online\n")
   f:write("Exec=\"" .. cmd .. "\" %u\n")
   f:write("Type=Application\n")
   f:write("NoDisplay=true\n")
   f:write("Categories=Discord;Games;\n")
   f:write("MimeType=x-scheme-handler/discord-" .. application .. ";\n")
   f:close()
   os.execute("xdg-mime default discord-" .. application .. ".desktop x-scheme-handler/discord-" .. application)
  end
 end
 fR()

 ------------------ THE ACTUAL CONNECTION STARTS HERE

 local sock = ffi.C.socket(AF_UNIX, SOCK_STREAM, 0)
 ffi.C.fcntl(sock, F_SETFL, O_NONBLOCK)
 
 local tmpPath =
  os.getenv("XDG_RUNTIME_DIR") or
  os.getenv("TMPDIR") or
  os.getenv("TMP") or
  os.getenv("TEMP") or
  "/tmp"
 
 local sockaddr = ffi.new("sockaddr_un")
 sockaddr.family = AF_UNIX
 
 local connected = false
 for i = 0, 9 do
  local sockContents = tmpPath .. "/discord-ipc-" .. i
  sockaddr.text = sockContents
  if ffi.C.connect(sock, ffi.new("void*", sockaddr), ffi.sizeof(sockaddr)) == 0 then
   connected = true
   break
  end
 end
 if not connected then
  ffi.C.close(sock)
  error("Discord not available")
 end
 return {
  getpid = ffi.C.getpid,
  read = function (length)
   local buf = ffi.new("char[" .. length .. "]")
   local bufo = ffi.new("char*", buf)
   local l = ssize_t(ffi.C.recv(sock, bufo, length, 0))
   if l < 1 then return end
   if length ~= l then print("DERP received truncated packet " .. l) end
   return ffi.string(buf, l)
  end,
  write = function (buffer)
   ffi.C.send(sock, buffer, #buffer, 0)
  end,
  close = function ()
   ffi.C.close(sock)
   sock = -1
  end,
 }
end
