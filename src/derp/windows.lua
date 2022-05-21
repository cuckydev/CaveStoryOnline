-- This is released into the public domain.
-- No warranty is provided, implied or otherwise.

local ffi = require("ffi")
local ADVAPI = ffi.load("Advapi32")
local GENERIC_RW = 0xC0000000
local OPEN_EXISTING = 3
local HKEY_CURRENT_USER = ffi.cast("void*", 0x80000001)
local REG_SZ = 1
local KEY_WRITE = 0x20006
ffi.cdef[[
 int __stdcall GetCurrentProcessId();
 int __stdcall GetLastError();
 void * __stdcall CreateFileW(wchar_t * name, uint32_t access, int share, void * ign, int create, int flags, void * n);
 int __stdcall WriteFile(void * handle, void * buf, int bytesToWrite, int * writtenBytes, void * ign);
 int __stdcall PeekNamedPipe(void * handle, void * buf, int zm, void * buf2, int * available, void * buf3);
 int __stdcall ReadFile(void * handle, void * buf, int bufSize, int * readBytes, void * ign);
 int __stdcall CloseHandle(void * handle);
 // 'long' defined as 32-bit. ok.
 int32_t __stdcall RegCreateKeyExW(void * key, wchar_t * subkey, uint32_t reserved, wchar_t * ign, uint32_t opts, uint32_t ignx, void * ign2, void ** nkey, uint32_t * ign3);
 int32_t __stdcall RegSetKeyValueW(void * key, wchar_t * subkey, wchar_t * value, uint32_t type, void * data, uint32_t dataSize);
 int32_t __stdcall RegCloseKey(void * key);
 int32_t __stdcall GetModuleFileNameW(void * mod, wchar_t * buf, uint32_t buflen);
]]

local function toW(str)
 -- this is where the Windows API is gonna suck
 local w = ""
 for j = 1, #str do
  w = w .. str:sub(j, j) .. "\x00"
 end
 -- extra NULLs
 w = w .. "\x00\x00"
 return w
end
local function castW(w)
 return ffi.cast("wchar_t *", ffi.cast("const char *", w))
end

return function (application)
 local fR = function ()
  local key = "Software\\Classes\\discord-" .. application
  local keyW = toW(key)
  local hkey = ffi.new("void*[1]")
  local hkeyh = ffi.new("void**", hkey)
  -- HKEY HKEY LITERATURE CLUB
  if ADVAPI.RegCreateKeyExW(HKEY_CURRENT_USER, castW(keyW), 0, nil, 0, KEY_WRITE, nil, hkeyh, nil) ~= 0 then
   print("DERP REGISTER FAILED TO CREATE KEY " .. key)
   return
  end
  local function setKeyValue(k, v)
   local vW = toW(v)
   if k then
    local kW = toW(k)
    ADVAPI.RegSetKeyValueW(hkey[0], nil, castW(kW), REG_SZ, castW(vW), ((#v + 1) * 2))
   else
    ADVAPI.RegSetKeyValueW(hkey[0], nil, nil, REG_SZ, castW(vW), ((#v + 1) * 2))
   end
  end
  setKeyValue(nil, "URL:Run game " .. application .. " protocol")
  setKeyValue("URL Protocol", "")
  -- To make this work properly we have to use actual UTF-16 stuff
  -- Please may Microsoft just burn in hell so that this kind of shit never has to be
  --  written again
  -- Who the hell thought UTF-16 was a good idea? NOT ME!
  -- That said, the people who think "no internationalization support on Windows" is
  --  a good idea are also pretty bad. But it's less their fault than MS's. This API sucks.
  local theExeBuffer = ffi.new("wchar_t[1024]")
  local theExeBufferPtr = ffi.new("wchar_t*", theExeBuffer)
  local eLen = ffi.C.GetModuleFileNameW(nil, theExeBufferPtr, 1021)
  local kXW = toW("DefaultIcon")
  ADVAPI.RegSetKeyValueW(hkey[0], nil, castW(kXW), REG_SZ, theExeBufferPtr, (eLen + 1) * 2)
  -- extend
  theExeBuffer[eLen] = 32 -- ' '
  eLen = eLen + 1
  theExeBuffer[eLen] = 37 -- '%'
  eLen = eLen + 1
  theExeBuffer[eLen] = 49 -- '1'
  eLen = eLen + 1
  local kYW = toW("shell\\open\\command")
  ADVAPI.RegSetKeyValueW(hkey[0], castW(kYW), nil, REG_SZ, theExeBufferPtr, (eLen + 1) * 2)
  -- Please, SHODAN... let me die
  ADVAPI.RegCloseKey(hkey[0])
 end
 fR()
 ------------------------------------------------------ THE ACTUAL CONNECTION STARTS HERE

 local sock
 local connected = false
 for i = 0, 9 do
  local sockContents = "\\\\?\\pipe\\discord-ipc-" .. i
  local sockContentsW = toW(sockContents)
  sock = ffi.C.CreateFileW(castW(sockContentsW), GENERIC_RW, 0, nil, OPEN_EXISTING, 0, nil)
  if tonumber(sock) ~= -1 then
   connected = true
   break
  end
 end
 if not connected then
  error("Discord not available")
 end
 return {
  getpid = ffi.C.GetCurrentProcessId,
  read = function (length)
   local np = ffi.new("int[1]")
   local npp = ffi.new("int*", np)
   if ffi.C.PeekNamedPipe(sock, nil, 0, nil, npp, nil) ~= 0 then
    if tonumber(npp[0]) >= length then
     local buf = ffi.new("char[" .. length .. "]")
     local bufo = ffi.new("char*", buf)
     if ffi.C.ReadFile(sock, ffi.cast("void *", bufo), length, npp, nil) ~= 0 then
      if length ~= tonumber(npp[0]) then print("DERP received truncated packet " .. tonumber(npp[0])) end
      return ffi.string(buf, tonumber(npp[0]))
     end
    end
   end
  end,
  write = function (buffer)
   local np = ffi.new("int[1]")
   local npp = ffi.new("int *", np)
   if ffi.C.WriteFile(sock, ffi.cast("void *", ffi.cast("const char *", buffer)), #buffer, npp, nil) == 0 then
    print("DERP SEND FAIL:", ffi.C.GetLastError())
   end
  end,
  close = function ()
   ffi.C.CloseHandle(sock)
   sock = ffi.cast("void *", -1)
  end
 }
end
