# Optare Solutions - Kong Body request Auth

This plugin performs authentication via a request to an authentication endpoint that
* Receives the credentials in atributes of the body
* Return a token in an attribute of the response

The token is added to the request as Bearer Authentication.

![alt Plugin flow](doc/kong-bodyauth-flow.png)

## References

This project is losely based on https://github.com/be-humble/kong-ext-auth

## Setup plugin



Check plugin [schema](./kong/plugins/bodyrequest-auth/schema.lua) for detailed info.

Plugin logs depend on kong log level. If you want the plugin to show logs set KONG_LOG_LEVEL vat to debug:
```
- name: KONG_LOG_LEVEL
  value: debug
```

| Parameter | mandatory | default            | description                                                                                                                                                                                                                                                                                            |
| ---  |-----------|--------------------|--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| url | true      |                    | Host of the auth provider to request the access token.                                                                                                                                                                                                                                                 |
| path | true      |                    | Path to conform the complete url to request the access token.                                                                                                                                                                                                                                          |
| method | false     | GET                | Http method to request the access token.                                                                                                                                                                                                                                                               |
| username_key | false     | username           | Credentials.                                                                                                                                                                                                                                                                                           |
| username_value | true      |                    | Credentials.                                                                                                                                                                                                                                                                                           |
| password_key | false     | password           | Credentials.                                                                                                                                                                                                                                                                                           |
| password_value | true      |                    | Credentials.                                                                                                                                                                                                                                                                                           |
| json_token_key | false     | token              | Key where the token is in the auth provider response.                                                                                                                                                                                                                                                  |
| header_request | false     | Authorization      | Header where the token will be sent upstream.                                                                                                                                                                                                                                                          |
| connect_timeout | false     | 10000              | Auth REST client settings.                                                                                                                                                                                                                                                                             |
| send_timeout | false     | 60000              | Auth REST client settings.                                                                                                                                                                                                                                                                             |
| read_timeout | false     | 60000              | Auth REST client settings.                                                                                                                                                                                                                                                                             |
| refresh_url | false     |                    | Host of the auth provider to request the access a refreshToken. Required if the auth provider send a refreshToken in the response.                                                                                                                                                                     |
| refresh_path | false     | client_credentials | Path to conform the complete url to request the access token. Required if the auth provider send a refreshToken in the response.                                                                                                                                                                       |
| refresh_method | false     |                    | Http method to request the access token. Required if the auth provider send a refreshToken in the response.                                                                                                                                                                                            |                                                                                                                   |
| json_refresh_token_response_key | false     | refreshToken       | Key where the tokens is in the auth provider response.                                                                                                                                                                                                                                                 |
| json_refresh_token_request_key | false     | token              | Key where the refreshToken is in the auth provider request.                                                                                                                                                                                                                                            |
| json_expires_in_key | false     | expiresIn          | Key that indicates the token timeout.                                                                                                                                                                                                                                                                  |
| cache_enabled | false     | false              | Enable cache for tokens. Advanced feature.                                                                                                                                                                                                                                                             |
| cache_key | false     |                    | Key where the token is cached                                                                                                                                                                                                                                                                          |
| expiration_margin | false     | 5                  | Time before token expiration to request a new token using the refreshToken endpoint.                                                                                                                                                                                                                   |
| manual_timeout | false     | 0                  | Set a manual timeout for the cached token. Required if the auth provider does not indicate a timeout.                                                                                                                                                                                                  |
| timeout_test | false     | 0                  | It allows you to adjust the timeout indicated in the response by the auth provider for testing (If in the response the timeout is 3600 we can set this value to 3540 so that this value is subtracted from the value of the response and thus leave a timeout of 60s, which makes testing easier).     |

### Config using k8s

Here is a sample:
```
apiVersion: configuration.konghq.com/v1
kind: KongPlugin
metadata:
  name: bodyrequest-auth-plugin
  namespace: test
config:
  url: https://authentication-host
  path: /my-authentication-api/v1/login
  method: POST
  json_token_key: my-token-id
  username_value: AAAA
  password_value: BBBB
plugin: bodyrequest-auth
```

#### Using secrets

As proposed in this discussion: https://discuss.konghq.com/t/kong-plugin-config-with-secret/6986/2

There is sensible information in the config (like provider credentials) so we can use a secret to store it.

Kong plugins in this version don't allow us to get each config property from a different source. So all the config must be stored in a secret
```
apiVersion: v1
kind: Secret
metadata:
  name: auth-test-secret
  namespace: test
stringData:
  bodyrequest-config: |
    url: https://authentication-host
    path: /my-authentication-api/v1/login
    method: POST
    json_token_key: my-token-id
    username_value: AAAA
    password_value: BBBB
type: Opaque
```

And we must use the secret as our config source:
```
apiVersion: configuration.konghq.com/v1
kind: KongPlugin
metadata:
  name: bodyrequest-auth-plugin
  namespace: test
configFrom:
  secretKeyRef:
    name: auth-test-secret
    key: bodyrequest-config
plugin: bodyrequest-auth
```

### Settings in kong

If we get this error when performing the login process:

```
"20: unable to get local issuer certificate"
```

We must add SSL certificate variables to our kong deployment

alpine based kong image:
```
KONG_LUA_SSL_TRUSTED_CERTIFICATE=/etc/ssl/cert.pem
KONG_LUA_SSL_VERIFY_DEPTH=2
```

centos based kong image:
```
KONG_LUA_SSL_TRUSTED_CERTIFICATE=/etc/pki/tls/cert.pem
KONG_LUA_SSL_VERIFY_DEPTH=2
```

For more information please refer to https://discuss.konghq.com/t/kong-log-error-about-certificate/6371/6

### Build Lua rock

In pongo shell
```
cd /kong-plugin/
luarocks make
luarocks pack kong-plugin-bodyrequest-auth 1.0.0
# Set propper version
```

## Priority
By default, the priority of the plugin is 900. You can change it using an environment variable:
```
BODYREQUEST_AUTH_PRIORITY=1000
```

## Test local

### Start pongo

Follow documentation
* https://konghq.com/blog/custom-lua-plugin-kong-gateway/
* https://github.com/Kong/kong-pongo

First time we must follow first link to prepare the env.

> NOTE: I found an issue working with Docker modules in windows. You might need to remove some lines from pongo file.

Next time we work with pongo we only need to execute:
```
PATH=$PATH:~/.local/bin
pongo run
```

Start/stop
```
pongo run

pongo down
```

### Access pongo shell

```
pongo shell
```

### In pongo cmd

```
kong migrations bootstrap --force
kong start

#check
curl -i http://localhost:8000/
```

Enable a service and route
```
curl -i -X POST \
    --url http://localhost:8001/services/ \
    --data 'name=example-service' \
    --data 'url=http://konghq.com'

curl -i -X POST \
    --url http://localhost:8001/services/example-service/routes \
    --data 'hosts[]=example.com'
```

Add plugin to service
```
curl -i -X POST \
    --url http://localhost:8001/services/example-service/plugins/ \
    --data 'name=bodyrequest-auth' \
    --data 'config.url=https://authentication-host' \
    --data 'config.path=/my-authentication-api/v1/login' \
    --data 'config.method=POST' \
    --data 'config.json_token_key=my-token-id' \
    --data 'config.username_value=AAAAAA' \
    --data 'config.password_value=BBBBBB'

#check
curl -i -H "Host: example.com" http://localhost:8000/
```

Remove plugin (to add it again with different config)
```
# Find plugin id
curl http://localhost:8001/plugins

# Delete by ID
curl -X DELETE http://localhost:8001/plugins/3fbfb590-c13f-4fa4-8901-619f96852e6f
```
