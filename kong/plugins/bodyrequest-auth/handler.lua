local BasePlugin = require "kong.plugins.base_plugin"
local http = require "resty.http"
local cjson = require "cjson"
local kong = kong
local ExternalAuthHandler = BasePlugin:extend()

local priority_env_var = "BODYREQUEST_AUTH_PRIORITY"
local priority
if os.getenv(priority_env_var) then
    priority = tonumber(os.getenv(priority_env_var))
else
    priority = 900
end
kong.log.debug('BODYREQUEST_AUTH_PRIORITY: ' .. priority)

ExternalAuthHandler.PRIORITY = priority
ExternalAuthHandler.VERSION = "1.1.0"

function ExternalAuthHandler:new()
  ExternalAuthHandler.super.new(self, "bodyrequest-auth")
end

function ExternalAuthHandler:access(conf)
  ExternalAuthHandler.super.access(self)
  local client = http.new()
  client:set_timeouts(conf.connect_timeout, conf.send_timeout, conf.read_timeout)

  if conf.log_enabled then
    kong.log.warn("Login via body request")
    kong.log.warn("Url:    ", conf.url)
    kong.log.warn("Path:   ", conf.path)
    kong.log.warn("Method: ", conf.method)
  end

  -- Login
  local res, err = client:request_uri(
    conf.url, 
    {
      method = conf.method,
      path = conf.path,
      body = cjson.encode({
        [conf.username_key] = conf.username_value,
        [conf.password_key] = conf.password_value
      })
    }
  )

  -- Validate login response
  if not res then
    if conf.log_enabled then
      kong.log.warn("No response. Error: ", err)
    end
    return kong.response.exit(401, {message="Invalid authentication credentials"})
    --return kong.response.exit(401, {message=err})
  end

  if res.status ~= 200 then
    if conf.log_enabled then
      kong.log.warn("Got error status ", res.status, res.body)
    end

    return kong.response.exit(401, {message="Invalid authentication credentials"})
    --return kong.response.exit(401, {message=res.body})
  end

  -- Retrieve login token
  local token = cjson.decode(res.body)
  if conf.log_enabled then
    kong.log.warn("Login success. Token: " .. token[conf.json_token_key])
  end

  kong.service.request.set_header(conf.header_request, "Bearer " .. token[conf.json_token_key])
end

return ExternalAuthHandler
