# BetterDecompile

**A better decompiler for your executor!**

Adds a global `decompile()` to executors, backed by the
[lua.expert](https://lua.expert) API. It reads the script bytecode with the
executor's own functions and sends it to lua.expert.

This replaces an existing `decompile()`.

## Usage

Load **BetterDecompile** onto your executor:

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/jacklebeignet/betterdecompile/refs/heads/main/betterdecompile.luau"))()
```

Then use it like the native function:

```lua
local module = game:GetService("ReplicatedStorage"):FindFirstChild("SomeModule")

print(decompile(module))
print(decompile(someFunction))              -- needs dumpbytecode
print(decompile(getscriptbytecode(module))) -- raw bytecode also works
```

`decompile` returns the Luau source as a string and yields while the HTTP
request is running.

## Requirements

- **HTTP**: `request`, or `http_request` / `http.request` / `syn.request` / `fluxus.request`
- **Scripts**: `getscriptbytecode` or `dumpstring`
- **Functions**: `dumpbytecode` or `getfunctionbytecode`
- **Environment**: `getgenv`

## Notes

- The script bytecode is uploaded to `api.lua.expert`, so don't use this on
  private code.
- lua.expert limits the API to 500 requests per minute.
- Scripts without bytecode (or protected scripts) fail with an error from the API.

## Checks

```sh
selene .
stylua . --check
lune run test.luau
```
