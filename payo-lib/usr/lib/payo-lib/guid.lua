

local util = {};

function util.toHex(n)
  if (type(n) ~= type(0)) then
    return nil, "toHex only converts numbers to strings"
  end

  local hexchars = "0123456789abcdef";
  local result = "";
  if (n < 0) then
    result = "-";
    n = -n;
  end

  while (n > 0) do
    local next = math.floor(n % 16);
    n = math.floor(n / 16);
    result = result .. hexchars:sub(next, next);
  end

  return result;
end

function util.next()
  -- e.g. 3c44c8a9-0613-46a2-ad33-97b6ba2e9d9a
  -- 8-4-4-4-12
  local sets = {8, 4, 4, 12};
  local result = "";

  local i;
  for _,set in ipairs(sets) do
    if (result:len() > 0) then
      result = result .. "-";
    end
    for i = 1,set do
      result = result .. util.toHex(math.random(0, 15));
    end
  end

  return result;
end

return util;
