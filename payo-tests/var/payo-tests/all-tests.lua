local tests =
{
  "uuid-test.lua",
  "config-test.lua", 
  "argutil-test.lua",
  "text-test.lua",
  "transforms-test.lua",
  "shell-test.lua",
  "sh-test.lua",
  "slow-test.lua",
  "popen-test.lua",
  --"popm-test.lua", 
  "fs-test.lua",
  "cp-test.lua",
  "tty-test",
  "cursor-test",
  "ls-test",
};

local pwd = os.getenv("_"):gsub('[^/]*$','')
local total_tests_run = 0

for _,test in ipairs(tests) do
  package.loaded.testutil = nil
  os.setenv("PWD", "/var/payo-tests")
  local testutil = require('testutil')
  testutil.total_tests_run = 0

  io.write("Running test: " .. test)
  os.execute(pwd .. test)
  local tests_run = testutil.total_tests_run
  io.write(' [' .. tostring(tests_run) .. ']\n')

  total_tests_run = total_tests_run + tests_run
end

print("Total Tests Run", total_tests_run)
