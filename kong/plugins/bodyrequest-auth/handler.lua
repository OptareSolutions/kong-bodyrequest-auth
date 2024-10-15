local http = require "resty.http"
local cjson = require "cjson"
local kong = kong
local BodyRequestAuthHandler = {
  VERSION = "1.2.0"
}

local CACHE_TOKEN_KEY = "oauth_token"

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
    if conf.log_enabled then
      kong.log.info("Cache enabled")
    end
    tokenInfo = get_cache_token(conf)
    if not tokenInfo then
      if conf.log_enabled then
        kong.log.info("No token in cache. Call OAuth provider to update it")
      end
      tokenInfo = kong.cache:get(CACHE_TOKEN_KEY, nil, get_oauth_token, conf)
    end
  -- Get token without cache
  else
    tokenInfo = get_oauth_token(conf)
  end

  -- Final validation and set header
  if not tokenInfo then
    return kong.response.exit(401, {message="Invalid authentication credentials"})
  end

  if conf.log_enabled then
    kong.log.info("Login success.")
    kong.log.debug("Token: " .. cjson.encode(tokenInfo))
  end

  kong.service.request.set_header(conf.header_request, "Bearer " .. tokenInfo.token)
end


-------------
-- FUNCTIONS
-------------

-- Get token from cache
function get_cache_token(conf)
  local token = kong.cache:get(CACHE_TOKEN_KEY)
  -- If value in cache is nil we must invalidate it
  if not token or not token.expiration then
    kong.cache:invalidate(CACHE_TOKEN_KEY)
    return nil
  end

  local timeToRefeshToken = token.expiration + conf.expiration_margin

  if token.expiration and (token.expiration < os.time()) and (timeToRefeshToken > os.time())
  and conf.refresh_url and conf.refresh_path then
      if conf.log_enabled then
        kong.log.debug("Get new token using refresh token ", token.expiration)
      end
      local refreshToken = token.refreshToken
      kong.cache:invalidate(CACHE_TOKEN_KEY)

      token = kong.cache:get(CACHE_TOKEN_KEY, nil, get_refresh_oauth_token, conf, refreshToken)
      kong.log.debug("New expiration time is ", token.expiration)
  end

  if token.expiration and (token.expiration < os.time()) then
    -- Token is expired invalidate it
    if conf.log_enabled then
      kong.log.debug("Invalidate expired token: " .. cjson.encode(token))
    end
    kong.cache:invalidate(CACHE_TOKEN_KEY)
    return nil
  end

  return token
end

-- Get token from OAuth provider
function get_oauth_token(conf)
  local res, err = perform_login(conf)

  local error_message = validate_login(res, err, conf)
  if error_message then
    return nil;
  end

  return get_token_from_response(res, conf)
end

-- Login
function perform_login(conf)
  local client = http.new()
  client:set_timeouts(conf.connect_timeout, conf.send_timeout, conf.read_timeout)

  if conf.log_enabled then
    kong.log.warn("Login via body request")
    kong.log.warn("Url:    ", conf.url)
    kong.log.warn("Path:   ", conf.path)
    kong.log.warn("Method: ", conf.method)
  end

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
function validate_login(res, err, conf)
  if not res then
    if conf.log_enabled then
      kong.log.err("No response. Error: ", err)
    end
    return "No response from OAuth provider"
  end

  if res.status ~= 200 then
    if conf.log_enabled then
      kong.log.err("Got error status ", res.status, res.body)
    end
    return "Invalid authentication credentials"
  end
end

-- Extract token
function get_token_from_response(res, conf)
  local responseBody = cjson.decode(res.body)

  local expirationValue = nil
  local ttlValue = nil
  local refreshTokenValue = nil
  if responseBody[conf.json_expires_in_key] then
    expirationValue = os.time() + responseBody[conf.json_expires_in_key] - conf.expiration_margin - conf.time_out_test
    ttlValue = responseBody[conf.json_expires_in_key]
  elseif conf.manual_time_out and conf.manual_time_out > 0 then
      expirationValue = os.time() + conf.manual_time_out
      ttlValue = conf.manual_time_out
  else
    ttlValue = 0
  end

  if responseBody[conf.json_refresh_token_response_key] then
      refreshTokenValue = responseBody[conf.json_refresh_token_response_key]
  else
      refreshTokenValue = ""
  end

  if conf.log_enabled then
    kong.log.debug("Current time: ", os.time())
    kong.log.debug("Expiration time: ", expirationValue)
  end

  return {
    token = responseBody[conf.json_token_key],
    ttl = ttlValue,
    refreshToken = refreshTokenValue,
    expiration = expirationValue
  };
end

-- Get new token using refresh token from OAuth provider
function get_refresh_oauth_token(conf, refreshToken)
  local res, err = perform_login_with_refresh_token(conf, refreshToken)

  local error_message = validate_login(res, err, conf)
  if error_message then
    return nil;
  end

  return get_token_from_response(res, conf)
end

-- Login
function perform_login_with_refresh_token(conf, refreshToken)
  local client = http.new()
  client:set_timeouts(conf.connect_timeout, conf.send_timeout, conf.read_timeout)

  if conf.log_enabled then
    kong.log.warn("Login via body request with refresh token")
    kong.log.warn("Url:    ", conf.refresh_url)
    kong.log.warn("Path:   ", conf.refresh_path)
    kong.log.warn("Method: ", conf.refresh_method)
  end

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