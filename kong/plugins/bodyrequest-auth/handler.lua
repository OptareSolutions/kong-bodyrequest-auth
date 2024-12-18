local http = require "resty.http"
local cjson = require "cjson"
local kong = kong
local BodyRequestAuthHandler = {
  VERSION = "2.0.0"
}

local CACHE_TOKEN_KEY = "body_request_plugin_token"

local priority_env_var = "BODYREQUEST_AUTH_PRIORITY"
local priority
if os.getenv(priority_env_var) then
  priority = tonumber(os.getenv(priority_env_var))
else
  priority = 900
end
kong.log.debug('BODYREQUEST_AUTH_PRIORITY: ' .. priority)

BodyRequestAuthHandler.PRIORITY = priority

function BodyRequestAuthHandler:access(conf)

  local tokenInfo = nil

  -- Get token with cache
  if conf.cache_enabled then
    kong.log.info("Cache enabled")
    tokenInfo = body_request_auth_get_cache_token(conf)
    if not tokenInfo then
      kong.log.debug("No token in cache. Call token provider to update it")
      tokenInfo = kong.cache:get(CACHE_TOKEN_KEY .. "_" .. conf.url .. "_" .. conf.path .. "_" .. conf.username_value, nil, body_request_auth_get_token, conf)
    end
  -- Get token without cache
  else
    tokenInfo = body_request_auth_get_token(conf)
  end

  -- Final validation and set header
  if not tokenInfo then
    return kong.response.exit(401, {message="Invalid authentication credentials"})
  end


  kong.log.info("Login success.")
  kong.log.debug("Token: " .. cjson.encode(tokenInfo))

  kong.service.request.set_header(conf.header_request, "Bearer " .. tokenInfo.token)
end


-------------
-- FUNCTIONS
-------------

-- Get token from cache
function body_request_auth_get_cache_token(conf)
  local token = kong.cache:get(CACHE_TOKEN_KEY .. "_" .. conf.url .. "_" .. conf.path .. "_" .. conf.username_value)
  -- If value in cache is nil we must invalidate it
  if not token or not token.expiration then
    kong.cache:invalidate(CACHE_TOKEN_KEY .. "_" .. conf.url .. "_" .. conf.path .. "_" .. conf.username_value)
    return nil
  end

  local timeToRefreshToken = token.expiration + conf.expiration_margin

  if (token.expiration < os.time()) and (timeToRefreshToken > os.time())
  and conf.refresh_url and conf.refresh_path then
      kong.log.debug("Get new token using refresh token ", token.expiration)
      local refreshToken = token.refreshToken
      kong.cache:invalidate(CACHE_TOKEN_KEY .. "_" .. conf.url .. "_" .. conf.path .. "_" .. conf.username_value)

      token = kong.cache:get(CACHE_TOKEN_KEY .. "_" .. conf.url .. "_" .. conf.path .. "_" .. conf.username_value, nil, body_request_auth_get_refresh_token, conf, refreshToken)
  end

  if (token.expiration < os.time()) then
    -- Token is expired invalidate it
    kong.log.debug("Invalidate expired token: " .. cjson.encode(token))
    kong.cache:invalidate(CACHE_TOKEN_KEY .. "_" .. conf.url .. "_" .. conf.path .. "_" .. conf.username_value)
    return nil
  end

  return token
end

-- Get token from provider
function body_request_auth_get_token(conf)
  local res, err = body_request_auth_perform_login(conf)

  local error_message = body_request_auth_validate_login(res, err, conf)
  if error_message then
    return nil;
  end

  return body_request_auth_get_token_from_response(res, conf)
end

-- Login
function body_request_auth_perform_login(conf)
  local client = http.new()
  client:set_timeouts(conf.connect_timeout, conf.send_timeout, conf.read_timeout)

  kong.log.debug("Login via body request")
  kong.log.debug("Url:    ", conf.url)
  kong.log.debug("Path:   ", conf.path)
  kong.log.debug("Method: ", conf.method)

  return client:request_uri(
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
end

-- Validate login response
function body_request_auth_validate_login(res, err, conf)
  if not res then
    kong.log.err("No response. Error: ", err)
    return "No response from token provider"
  end

  if res.status ~= 200 then
    kong.log.err("Got error status ", res.status, res.body)
    return "Invalid authentication credentials"
  end
end

-- Extract token
function body_request_auth_get_token_from_response(res, conf)
  local responseBody = cjson.decode(res.body)

  local expirationValue = nil
  local ttlValue = nil
  local refreshTokenValue = nil
  if responseBody[conf.json_expires_in_key] then
    expirationValue = os.time() + responseBody[conf.json_expires_in_key] - conf.expiration_margin - conf.timeout_test
    ttlValue = responseBody[conf.json_expires_in_key]
  elseif conf.manual_timeout and conf.manual_timeout > 0 then
      expirationValue = os.time() + conf.manual_timeout
      ttlValue = conf.manual_timeout
  else
    ttlValue = 0
  end

  if responseBody[conf.json_refresh_token_response_key] then
      refreshTokenValue = responseBody[conf.json_refresh_token_response_key]
  else
      refreshTokenValue = ""
  end

  kong.log.debug("Current time: ", os.time())
  kong.log.debug("Expiration time: ", expirationValue)

  return {
    token = responseBody[conf.json_token_key],
    ttl = ttlValue,
    refreshToken = refreshTokenValue,
    expiration = expirationValue
  };
end

-- Get new token using refresh token from provider
function body_request_auth_get_refresh_token(conf, refreshToken)
  local res, err = body_request_auth_perform_login_with_refresh_token(conf, refreshToken)

  local error_message = body_request_auth_validate_login(res, err, conf)
  if error_message then
    return nil;
  end

  return body_request_auth_get_token_from_response(res, conf)
end

-- Login
function body_request_auth_perform_login_with_refresh_token(conf, refreshToken)
  local client = http.new()
  client:set_timeouts(conf.connect_timeout, conf.send_timeout, conf.read_timeout)

  kong.log.debug("Login via body request with refresh token")
  kong.log.debug("Url:    ", conf.refresh_url)
  kong.log.debug("Path:   ", conf.refresh_path)
  kong.log.debug("Method: ", conf.refresh_method)

  return client:request_uri(
    conf.refresh_url,
    {
      method = conf.refresh_method,
      path = conf.refresh_path,
      body = cjson.encode({
        [conf.json_refresh_token_request_key] = refreshToken
      })
    }
  )
end

return BodyRequestAuthHandler