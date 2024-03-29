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
            log_enabled = {
              default = false,
              type = "boolean"
            }
          }
        }
      }
    }
  }
}
