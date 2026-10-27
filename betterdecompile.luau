--[[
	BetterDecompile - An better decompiler for your executor!

	Usage:
		loadstring(game:HttpGet("<url to this file>"))()
		print(decompile(game:GetService("ReplicatedStorage").SomeModule))

	Replaces any existing decompile().

	Accepts a script Instance, a Lua function, or raw Luau bytecode.
	Needs getscriptbytecode (or dumpstring), dumpbytecode / getfunctionbytecode
	for functions, request (or http_request / http.request / syn.request /
	fluxus.request), and getgenv (falls back to _G).

	The bytecode is uploaded to lua.expert, so don't use this on private code.
]]

local floor = math.floor
local concat = table.concat
local sub = string.sub
local byte = string.byte
local type = type
local pcall = pcall
local tostring = tostring

local alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
local digit = {}
for i = 1, 64 do
	digit[i] = sub(alphabet, i, i)
end

local function base64(value)
	local length = #value
	local out = {}
	local i, j = 1, 1

	while i + 2 <= length do
		local a, b, c = byte(value, i, i + 2)
		local n = a * 65536 + b * 256 + c
		out[j] = digit[floor(n / 262144) + 1]
			.. digit[floor(n / 4096) % 64 + 1]
			.. digit[floor(n / 64) % 64 + 1]
			.. digit[n % 64 + 1]
		i, j = i + 3, j + 1
	end

	local left = length - i + 1
	if left == 1 then
		local n = byte(value, i) * 65536
		out[j] = digit[floor(n / 262144) + 1] .. digit[floor(n / 4096) % 64 + 1] .. "=="
	elseif left == 2 then
		local a, b = byte(value, i, i + 1)
		local n = a * 65536 + b * 256
		out[j] = digit[floor(n / 262144) + 1] .. digit[floor(n / 4096) % 64 + 1] .. digit[floor(n / 64) % 64 + 1] .. "="
	end

	return concat(out)
end

local function preview(value)
	local text = tostring(value)
	return #text > 300 and sub(text, 1, 300) .. "..." or text
end

local function httpRequest(options)
	local requestFn = request
		or http_request
		or (http and http.request)
		or (syn and syn.request)
		or (fluxus and fluxus.request)

	if type(requestFn) ~= "function" then
		error("decompile: executor has no HTTP function (request/http_request/syn.request)", 3)
	end

	local ok, response = pcall(requestFn, options)
	if not ok then
		error("decompile: HTTP request failed: " .. preview(response), 3)
	end

	local body, status, success
	if type(response) == "table" then
		body = response.Body or response.body
		status = response.StatusCode or response.statusCode
		success = response.Success
	else
		body = response
	end

	if success == false or (status and status ~= 200) then
		local reason = status and ("HTTP " .. status .. ": ") or ""
		error("decompile: lua.expert returned " .. reason .. preview(body), 3)
	end

	if type(body) ~= "string" then
		error("decompile: lua.expert returned no text (" .. type(body) .. ")", 3)
	end

	return body
end

local function getBytecode(target)
	if target == nil then
		error("decompile: missing target", 3)
	end

	local kind = type(target)
	if kind == "string" then
		return target
	end

	if kind == "function" then
		local dumper = dumpbytecode or getfunctionbytecode
		if type(dumper) ~= "function" then
			error("decompile: this executor can't dump function bytecode (no dumpbytecode)", 3)
		end

		local dumped = dumper(target)
		if type(dumped) ~= "string" or #dumped == 0 then
			error("decompile: dumpbytecode returned no bytecode", 3)
		end
		return dumped
	end

	local getter = getscriptbytecode or dumpstring
	if type(getter) ~= "function" then
		error("decompile: this executor can't read script bytecode (no getscriptbytecode/dumpstring)", 3)
	end

	local dumped = getter(target)
	if type(dumped) ~= "string" or #dumped == 0 then
		error("decompile: getscriptbytecode returned no bytecode for " .. tostring(target), 3)
	end
	return dumped
end

local function decompile(target)
	local bytecode = getBytecode(target)

	return httpRequest({
		Url = "https://api.lua.expert/v1/decompile",
		Method = "POST",
		Headers = {
			["Content-Type"] = "application/json",
		},
		Body = '{"script":"' .. base64(bytecode) .. '"}',
	})
end

-- selene: allow(global_usage)
local env = (getgenv and getgenv()) or _G
env.decompile = decompile
