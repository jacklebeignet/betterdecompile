# BetterDecompile

[![jsDelivr Stats](https://data.jsdelivr.com/v1/package/gh/jacklebeignet/betterdecompile/badge)](https://www.jsdelivr.com/package/gh/jacklebeignet/betterdecompile)

**A better decompiler for your executor!**

Adds a global `decompile()` to executors, backed by the
[lua.expert](https://lua.expert) API. It reads the script bytecode with the
executor's own functions and sends it to lua.expert.

This replaces an existing `decompile()`.

## Usage

Load **BetterDecompile** onto your executor:

```lua
loadstring(game:HttpGet("https://cdn.jsdelivr.net/gh/jacklebeignet/betterdecompile@refs/heads/main/betterdecompile.luau"))()
```

> [!TIP]
> If your executor supports an `autoexecute` folder, copy `betterdecompile.luau` into it. The executor runs it automatically on every launch, so `decompile()` is available without running the `loadstring` line manually.

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
