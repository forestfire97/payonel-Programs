local shell = require("shell");
local fs =  require("filesystem");

local args = shell.parse(...);

if (#args == 0) then
  print "touch: missing operand";
  return 1;
end

local ec = 0;

for i = 1, #args do
  local path = shell.resolve(args[i]);
  local list, reason = fs.list(path);
    
  local f, reason = io.open(path, "w");
  if (not f) then
    print(reason);
    ec = ec + 1;
  else
    f:close();
  end
end

return ec;