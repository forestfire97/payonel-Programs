local shell = require("shell")
local buffer = require("buffer")
local process = require("process")
local psh = require("psh")
local tty = require("tty")

local H = {}

local _init_packet_timeout = 5

--[[

issues
1. `free` seems to only print when dmesg is running ... weird
2. `reboot` in the test run.lua script caused ocvm to crash...
3. `reset` works...should it? i may not be forwarding X (gpu) but i should block stuff probably, maybe

]]--

local parsers = {}

parsers[psh.api.init] = function(packet_label, packet_body)
  assert(packet_label == psh.api.init)
  return {
    command = packet_body[1] or "/bin/sh",
    timeout = packet_body[2] or _init_packet_timeout,
    X = packet_body[3] or false
  }
end

local function new_stream(socket, forward_gpu)
  local stream = {handle = socket}

  function stream:write(...)
    local buf = table.concat({...})
    return psh.push(self.handle, psh.api.io, {[1]=buf})
  end

  function stream:read(n)
    -- sh input sets the cursor, without sy,tails
    -- and then tty write expects it
    -- it's a dumb mistake, so we set sy and tails here to be safe
    local cursor = tty.window.cursor
    if cursor then
      cursor.sy = cursor.sy or 0
      cursor.tails = cursor.tails or {}
    end

    -- request 0 [stdin:0]
    psh.push(self.handle, psh.api.io, {[0]=n})

    while true do
     local eType, packet = psh.pull(self.handle)
     if not eType then
      return
     elseif eType == psh.api.io and packet[0] then
      return packet[0] -- stdin
     end
     -- else, handle the packet
    end
  end

  function stream:close()
    self.handle:close()
  end

  local bs = buffer.new("rw", stream)
  bs.tty = true
  bs:setvbuf("no")
  process.closeOnExit(bs)

  return bs
end

function H.run(socket)
  pcall(function()
    -- the socket connection hasn't proven it is for psh
    -- though it is using psh.sockets
    -- give it time to provide the init packet to establish a psh session
    local init_packet = parsers[psh.api.init](psh.pull(socket, _init_packet_timeout))
    local context = {socket = socket}
    context.command = init_packet.command
    context.timeout = init_packet.timeout

    local host_stream = new_stream(socket, context.X)
    io.input(host_stream)
    io.output(host_stream)
    io.error(host_stream)

    shell.getShell()(nil, context.command)

    host_stream:flush()

  end)
  socket:close()
end

return H
