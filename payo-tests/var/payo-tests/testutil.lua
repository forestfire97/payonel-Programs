local util = {};
local ser = require("serialization").serialize
local tutil = require("payo-lib/tableutil");
local shell = require("shell")
local fs = require("filesystem")

local mktmp = loadfile(shell.resolve('mktmp','lua'))
if (not mktmp) then
  io.stderr:write("testutils requires mktmp which could not be found\n")
  return false
end

util.asserts = 0
util.assert_max = 1
util.total_tests_run = 0
util.last_time = 0
util.timeout = 1

function util.bump(ok)
  local next_time = os.time()
  if next_time - util.last_time > util.timeout then
    util.last_time = next_time
    os.sleep(0)
    io.write('.')
  end

  util.total_tests_run = util.total_tests_run + 1
  if ok == true then return true end

  util.asserts = util.asserts + 1
  if util.asserts >= util.assert_max then
    io.stderr:write("Too many asserts\n",debug.traceback())
    os.exit(1)
  end
  return false
end

function util.load(lib)
  package.loaded[lib] = nil;
  local result = require(lib);

  if (not result) then
    error("failed to load library: " .. result);
    return nil; -- shouldn't happen after an error
  end
  return result;
end

util.broken_handler = {}
util.broken_handler.__index = function(table_, key_)
  return function(...) end
end

util.broken = {}
setmetatable(util.broken, util.broken_handler)

function util.assert(msg, expected, actual, detail)
  local etype = type(expected);
  local atype = type(actual);
  local detail_msg = detail and string.format(". detail: %s", ser(detail)) or ""

  if (etype ~= atype) then
    io.stderr:write(string.format("%s: mismatch type, %s vs %s. expected value: |%s|. %s\n", msg, etype, atype, ser(expected), detail_msg));
    return util.bump()
  end
  
  -- both same type

  if (etype == nil) then -- both nil
    return true;
  end

  local matching = true;
  if (etype == type({})) then
    if (not tutil.equal(expected, actual)) then
      matching = false;
    end
  elseif (expected ~= actual) then
    matching = false;
  end

  if (not matching) then
    io.stderr:write(string.format("%s: %s ~= %s. %s\n", msg, ser(actual), ser(expected), detail_msg));
  end

  return util.bump(matching)
end

function util.assert_files(file_a, file_b)
  util.bump(true)
  local path_a = shell.resolve(file_a)
  local path_b = shell.resolve(file_b)

  local a_data = io.lines(path_a, "*a")()
  local b_data = io.lines(path_b, "*a")()

  util.assert("path a missing", fs.exists(path_a), true)
  util.assert("path b missing", fs.exists(path_b), true)
  util.assert("path a is dir", fs.isDirectory(path_a), false, path_a)
  util.assert("path b is dir", fs.isDirectory(path_b), false, path_b)
  util.assert("content mismatch", a_data, b_data)
end

function util.assert_process_output(cmd, expected_output)
  util.bump(true)
  local piped_file = mktmp('-q')
  local full_cmd = cmd .. " > " .. piped_file
  os.execute(full_cmd)
  assert(fs.exists(piped_file))
  local piped_handle = io.open(piped_file)
  local piped_data = piped_handle:read("*a")
  piped_handle:close()
  fs.remove(piped_file)

  if (piped_data ~= expected_output) then
    io.stderr:write("failed command: ",full_cmd,"\n")
    io.stderr:write(string.format("lengths: %i, %i:", piped_data:len(), 
      expected_output:len()))
    io.stderr:write(string.format("%s", piped_data:gsub("\n", "\\n")))
    io.stderr:write("[does not equal]")
    io.stderr:write(string.format("%s\n", expected_output:gsub("\n", "\\n")))
    util.bump()
  end
end

return util;