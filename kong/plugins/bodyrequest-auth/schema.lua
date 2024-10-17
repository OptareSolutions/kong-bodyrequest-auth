local typedefs = require "kong.db.schema.typedefs"

return {
  name = "bodyrequest-auth",
  fields = {
    {
      consumer = typedefs.no_consumer
    },
    {
      config = {
        type = "record",
        fields = {
          {
            url = typedefs.url({
              required = true
            })
          },
          {
            path = {
              required = true,
              type = "string"
            }
          },
          {
            method = {
              default = "GET",
              type = "string"
            }
          },
          {
            username_key = {
              default = "username",
              type = "string"
            }
          },
          {
            username_value = {
              required = true,
              type = "string"
            }
          },
          {
            password_key = {
              default = "password",
              type = "string"
            }
          },
          {
            password_value = {
              required = true,
              type = "string"
            }
          },
          {
            json_token_key = {
              default = "token",
              type = "string"
            }
          },
          {
            header_request = {
              default = "Authorization",
              type = "string"
            }
          },
          {
            connect_timeout = {
              default = 10000,
              type = "number"
            }
          },
          {
            send_timeout = {
              default = 60000,
              type = "number"
            }
          },
          {
            read_timeout = {
              default = 60000,
              type = "number"
            }
          },
          {
            refresh_url = typedefs.url({
              required = false
            })
          },
          {
            refresh_path = {
              required = false,
              type = "string"
            }
          },
          {
            refresh_method = {
              default = "GET",
              type = "string"
            }
          },
          {
            json_refresh_token_response_key = {
              default = "refreshToken",
              type = "string"
            }
          },
          {
            json_refresh_token_request_key = {
              default = "token",
              type = "string"
            }
          },
          {
            json_expires_in_key = {
              default = "expiresIn",
              type = "string"
            }
          },
          {
            cache_enabled = {
              default = false,
              type = "boolean"
            }
          },
          {
            expiration_margin = {
              default = 5,
              type = "number"
            }
          },
          {
            manual_timeout = {
              default = 0,
              type = "number"
            }
          },
            {
            timeout_test = {
              default = 0,
              type = "number"
            }
          }
        }
      }
    }
  }
}