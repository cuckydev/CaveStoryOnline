﻿-- Smallest logger
-- by zorg @ 2017-2018 § ISC

local log = {}
log.enabled = false
log.func = function(self, str, ...)
	if self.enabled then
		io.write(string.format(str,...))
	end
end
log = setmetatable(log, { __call = function(self, ...) return self:func(...) end })
return log