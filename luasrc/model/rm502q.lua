module("luci.model.rm502q", package.seeall)

local uci = require "luci.model.uci".cursor()

local M = {}

local function trim(s)
  if not s then return "" end
  return (s:gsub("^%s+", ""):gsub("%s+$", ""))
end

local function devnode()
  return uci:get("rm502q", "modem", "at_device") or "/dev/ttyUSB2"
end

local function run(cmd)
  local fp = io.popen(cmd .. " 2>/dev/null")
  if not fp then return "" end
  local out = fp:read("*a") or ""
  fp:close()
  return out
end

function M.send_at(cmd)
  if not cmd or cmd == "" then
    return nil, "empty command"
  end

  local escaped = cmd:gsub("'", [['"'"']])
  local out = run(string.format("/usr/bin/rm502q_ctl at '%s' '%s'", devnode(), escaped))

  if out == "" then
    return nil, "no response"
  end

  return trim(out)
end

local function find_value(text, pat)
  local v = text:match(pat)
  return v and trim(v) or ""
end

function M.get_overview()
  local csq = M.send_at("AT+CSQ") or ""
  local cops = M.send_at("AT+COPS?") or ""
  local creg = M.send_at("AT+CEREG?") or ""
  local nw = M.send_at("AT+QNWINFO") or ""

  local rssi = tonumber(csq:match("%+CSQ:%s*(%d+),")) or 99
  local signal_pct = 0
  if rssi >= 0 and rssi <= 31 then
    signal_pct = math.floor((rssi / 31) * 100)
  end

  return {
    signal = {
      rssi = rssi,
      percent = signal_pct
    },
    operator = find_value(cops, [[%+COPS:%s*[^,]*,[^,]*,"([^"]+)"]]),
    registered = creg:match(",%s*[15]") and true or false,
    network = find_value(nw, [[%+QNWINFO:%s*"([^"]+)"]]),
    raw = {
      csq = csq,
      cops = cops,
      creg = creg,
      qnwinfo = nw
    }
  }
end

function M.set_apn(apn, user, pass, auth)
  apn = apn or ""
  user = user or ""
  pass = pass or ""
  auth = tonumber(auth) or 0

  local cmd = string.format('AT+CGDCONT=1,"IPV4V6","%s"', apn)
  local r1 = M.send_at(cmd)
  local r2 = M.send_at(string.format('AT+QICSGP=1,1,"%s","%s","%s",%d', apn, user, pass, auth))

  if not r1 or not r2 then
    return nil, "failed to set apn"
  end

  return { cgdccont = r1, qicsgp = r2 }
end

function M.airplane(enable)
  local state = (enable and "4" or "1")
  local r = M.send_at("AT+CFUN=" .. state)
  if not r then
    return nil, "failed to set cfun"
  end
  return { cfun = state, response = r }
end

function M.send_sms(number, content)
  if not number or number == "" then
    return nil, "number required"
  end
  if not content or content == "" then
    return nil, "content required"
  end

  local payload = string.format('%s\x1A', content)
  local escaped = payload:gsub("'", [['"'"']])
  local cmd = string.format("/usr/bin/rm502q_ctl sms '%s' '%s' '%s'", devnode(), number, escaped)
  local out = run(cmd)

  if out == "" then
    return nil, "sms send failed"
  end

  return { response = trim(out) }
end

function M.list_sms()
  local r = M.send_at('AT+CMGL="ALL"') or ""
  local result = {}

  for header, body in r:gmatch("(%+CMGL:[^\n]+)\n([^\n]*)") do
    local idx, stat, number = header:match([[%+CMGL:%s*(%d+),"([^"]+)","([^"]*)]])
    result[#result + 1] = {
      index = tonumber(idx),
      status = stat,
      number = number,
      content = trim(body)
    }
  end

  return result
end

function M.at_debug(command)
  local data, err = M.send_at(command)
  if not data then
    return nil, err
  end
  return { command = command, response = data }
end

return M
