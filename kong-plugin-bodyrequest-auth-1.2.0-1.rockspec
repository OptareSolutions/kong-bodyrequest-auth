local plugin_name = "bodyrequest-auth"
local package_name = "kong-plugin-" .. plugin_name
local package_version = "1.2.0"
local rockspec_revision = "1"

local github_account_name = "OptareSolutions"
local github_repo_name = "kong-bodyrequest-auth"
local github_tag = version -- we should push a tag matching the version

package = package_name
version = package_version .. "-" .. rockspec_revision
supported_platforms = { "linux", "macosx" }
source = {
    url = "git://github.com/"..github_account_name.."/"..github_repo_name,
    tag = github_tag,
    dir = github_repo_name
}

description = {
  summary = "A Kong plugin for performing authentication to and endpoint by authenticating in an login API that requires username and password in a JSON body and injecting the received token in the Bearer header",
  homepage = "https://github.com/"..github_account_name.."/"..github_repo_name,
  license = "Apache 2.0",
}

dependencies = {
}

build = {
  type = "builtin",
  modules = {
    -- TODO: add any additional code files added to the plugin
    ["kong.plugins."..plugin_name..".handler"] = "kong/plugins/"..plugin_name.."/handler.lua",
    ["kong.plugins."..plugin_name..".schema"] = "kong/plugins/"..plugin_name.."/schema.lua",
  }
}
