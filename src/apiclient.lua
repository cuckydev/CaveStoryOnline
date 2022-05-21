-- -*- coding: utf-8 -*-
--
-- HTTP API Client.
--
-- Copyright 2014 Alexander Tsirel
-- http://noma4i.com
--
-- This code is released under a Apache License Version 2.0:
-- https://www.apache.org/licenses/LICENSE-2.0.txt


http = require("socket.http")
json2 = require("libs.JSON")

disabled = false

require("libs.Utils")

local function api_call(...)
    if disabled then
        return false,""
    end

    local args = {...}

    local ret = nil

    local s,e = pcall(function()
        local reqbody = args[3] or ""

        local respbody = {}

        http.request {
            method = args[1],
            url = args[2],
            source = ltn12.source.string(reqbody),
            headers = {
            ["Content-Type"] = "application/x-www-form-urlencoded",
            ["Content-Length"] = #reqbody
            },
            sink = ltn12.sink.table(respbody)
        }
        if respbody[1]:sub(1,1) == "{" then
            ret = json2:decode(table.concat(respbody))
        else
            ret = table.concat(respbody)
        end
    end)

    if s and ret then
        return true, ret
    else
        print(e)
        return false, e or "returned nil"
    end
end

return api_call