local fs = require("@lune/fs")
local luau = require("@lune/luau")

local source = fs.readFile("betterdecompile.luau")

local function loadDecompile(globals)
	globals.getgenv = function()
		return globals
	end
	local chunk = luau.load(source, {
		debugName = "@betterdecompile.luau",
		environment = globals,
	})
	chunk()
	return globals.decompile, globals
end

local alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
local values = {}
for i = 1, 64 do
	values[alphabet:sub(i, i)] = i - 1
end

local function base64decode(text)
	local out = {}
	for i = 1, #text, 4 do
		local a, b, c, d = text:byte(i, i + 3)
		local n = values[string.char(a)] * 262144
			+ values[string.char(b)] * 4096
			+ (c ~= 61 and values[string.char(c)] * 64 or 0)
			+ (d ~= 61 and values[string.char(d)] or 0)
		out[#out + 1] = string.char(math.floor(n / 65536) % 256)
		if c ~= 61 then
			out[#out + 1] = string.char(math.floor(n / 256) % 256)
		end
		if d ~= 61 then
			out[#out + 1] = string.char(n % 256)
		end
	end
	return table.concat(out)
end

local sent
local function fakeRequest(options)
	sent = options
	return { Success = true, StatusCode = 200, Body = "print('ok')" }
end

-- raw bytecode strings, all three base64 tail lengths
math.randomseed(1234)
for length = 0, 64 do
	local bytes = {}
	for i = 1, length do
		bytes[i] = string.char(math.random(0, 255))
	end
	local bytecode = table.concat(bytes)

	local decompile = loadDecompile({
		getscriptbytecode = function()
			return bytecode
		end,
		request = fakeRequest,
	})

	assert(decompile(bytecode) == "print('ok')", "raw bytecode failed")
	assert(sent.Method == "POST", "wrong method")
	assert(sent.Url == "https://api.lua.expert/v1/decompile", "wrong url")
	assert(sent.Headers["Content-Type"] == "application/json", "wrong content type")

	local encoded = assert(sent.Body:match('^{"script":"(.*)"}$'), "no encoded body")
	assert(base64decode(encoded) == bytecode, "base64 mismatch at length " .. length)
end

-- script instance via getscriptbytecode
do
	local decompile = loadDecompile({
		getscriptbytecode = function(script)
			return script.bytecode
		end,
		request = fakeRequest,
	})
	assert(decompile({ bytecode = "abc" }) == "print('ok')", "script instance failed")
end

-- function via dumpbytecode
do
	local decompile = loadDecompile({
		dumpbytecode = function(fn)
			return "dumped:" .. tostring(fn)
		end,
		request = fakeRequest,
	})
	local fn = function() end
	assert(decompile(fn) == "print('ok')", "function failed")
	assert(
		base64decode(sent.Body:match('^{"script":"(.*)"}$')) == "dumped:" .. tostring(fn),
		"dumped bytecode mismatch"
	)
end

-- getfunctionbytecode and dumpstring aliases
do
	local decompile = loadDecompile({
		getfunctionbytecode = function()
			return "fnbytecode"
		end,
		dumpstring = function(script)
			return script.bytecode
		end,
		request = fakeRequest,
	})
	assert(decompile(function() end) == "print('ok')", "getfunctionbytecode failed")
	assert(base64decode(sent.Body:match('^{"script":"(.*)"}$')) == "fnbytecode", "fnbytecode mismatch")
	assert(decompile({ bytecode = "scriptbytecode" }) == "print('ok')", "dumpstring failed")
	assert(base64decode(sent.Body:match('^{"script":"(.*)"}$')) == "scriptbytecode", "scriptbytecode mismatch")
end

-- an existing decompile() is replaced
do
	local native = function()
		return "native"
	end
	local decompile, globals = loadDecompile({
		decompile = native,
		getscriptbytecode = function()
			return "x"
		end,
		request = fakeRequest,
	})
	assert(globals.decompile == decompile, "decompile was not replaced")
	assert(globals.decompile ~= native, "native decompile survived")
	assert(decompile({}) == "print('ok')", "replacement decompile failed")
end

-- http.request fallback and plain-string responses
do
	local decompile = loadDecompile({
		getscriptbytecode = function()
			return "x"
		end,
		http = {
			request = function()
				return "raw body"
			end,
		},
	})
	assert(decompile({}) == "raw body", "plain response failed")
end

-- API errors surface status and body
do
	local decompile = loadDecompile({
		getscriptbytecode = function()
			return "x"
		end,
		request = function()
			return { Success = false, StatusCode = 400, Body = "not bytecode" }
		end,
	})
	local ok, err = pcall(decompile, {})
	assert(not ok and err:find("HTTP 400") and err:find("not bytecode"), err)
end

-- missing executor functions produce useful errors
do
	local decompile = loadDecompile({})
	local ok, err = pcall(decompile, {})
	assert(not ok and err:find("getscriptbytecode"), err)
end

do
	local decompile = loadDecompile({
		getscriptbytecode = function()
			return "x"
		end,
	})
	local ok, err = pcall(decompile, {})
	assert(not ok and err:find("HTTP function"), err)
end

print("all tests passed")
