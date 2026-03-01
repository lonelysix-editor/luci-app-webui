module("luci.controller.rm502q", package.seeall)

local http = require "luci.http"
local json = require "luci.jsonc"
local modem = require "luci.model.rm502q"

function index()
  entry({"admin", "modem_manager"}, firstchild(), _("Modem Manager"), 60).dependent = false
  entry({"admin", "modem_manager", "ui"}, call("action_ui"), _("WebUI"), 1)

  local api = entry({"admin", "modem_manager", "api"}, firstchild(), _("API"), 10)
  api.leaf = false

  entry({"admin", "modem_manager", "api", "status"}, call("action_status")).leaf = true
  entry({"admin", "modem_manager", "api", "apn"}, call("action_apn")).leaf = true
  entry({"admin", "modem_manager", "api", "airplane"}, call("action_airplane")).leaf = true
  entry({"admin", "modem_manager", "api", "sms_list"}, call("action_sms_list")).leaf = true
  entry({"admin", "modem_manager", "api", "sms_send"}, call("action_sms_send")).leaf = true
  entry({"admin", "modem_manager", "api", "at"}, call("action_at")).leaf = true
end

local function write_json(data, code)
  http.status(code or 200, "OK")
  http.prepare_content("application/json")
  http.write(json.stringify(data or {}))
end

local function read_body()
  local body = http.content() or "{}"
  local obj = json.parse(body)
  return obj or {}
end

function action_ui()
  http.redirect("/index.html")
end

function action_status()
  write_json({ success = true, data = modem.get_overview() })
end

function action_apn()
  local req = read_body()
  local data, err = modem.set_apn(req.apn, req.username, req.password, req.auth)
  if not data then
    return write_json({ success = false, error = err }, 500)
  end
  write_json({ success = true, data = data })
end

function action_airplane()
  local req = read_body()
  local data, err = modem.airplane(req.enable)
  if not data then
    return write_json({ success = false, error = err }, 500)
  end
  write_json({ success = true, data = data })
end

function action_sms_list()
  write_json({ success = true, data = modem.list_sms() })
end

function action_sms_send()
  local req = read_body()
  local data, err = modem.send_sms(req.number, req.content)
  if not data then
    return write_json({ success = false, error = err }, 500)
  end
  write_json({ success = true, data = data })
end

function action_at()
  local req = read_body()
  local data, err = modem.at_debug(req.command)
  if not data then
    return write_json({ success = false, error = err }, 500)
  end
  write_json({ success = true, data = data })
end
