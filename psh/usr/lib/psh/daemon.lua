local event = require("event")
local thread = require("thread")
local sockets = require("psh.socket")

local daemon = {
  socket = false,
  thread = false,
}

function daemon.close()
  if daemon.socket then
    daemon.socket:close()
    daemon.socket = false
  end
end

local function daemon_thread_proc(port)
  local host = require("psh.host")
  while true do
    xpcall(function()
      event.pull("socket_request", port)
      thread.create(function()
        local client = daemon.socket:accept(0)
        if client then
          host.run(client)
        end
      end):detach()
    end, function(msg)
      event.onError("pshd thread caught an exception [%s] at:\n[%s]", msg, debug.traceback())
    end)
  end
end

function daemon.status()
  if daemon.thread then
    return daemon.thread:status()
  else
    return "stopped"
  end
end

function daemon.start(port, addr)
  if daemon.thread then
    local status = daemon.thread:status()
    if status == "running" then
      return -- already running
    elseif status == "suspended" then
      daemon.thread:resume()
    elseif status == "dead" then
      daemon.thread = nil
      return daemon.start(port, addr)
    end
  else
    daemon.close()
    local s, why = sockets.listen(port, addr)
    if not s then return nil, why end
    daemon.socket = s
    daemon.thread = thread.create(daemon_thread_proc, port):detach()
  end
  return daemon.thread:status() == "running"
end

function daemon.stop()
  if daemon.thread then
    if daemon.thread:status() ~= "dead" then
      daemon.thread:kill()
      daemon.thread:join()
      -- this is a hack because killed threads don't close their handles
      daemon.close()
      return true
    end
  end
end

return daemon
