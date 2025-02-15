--
-- Licensed to the Apache Software Foundation (ASF) under one or more
-- contributor license agreements.  See the NOTICE file distributed with
-- this work for additional information regarding copyright ownership.
-- The ASF licenses this file to You under the Apache License, Version 2.0
-- (the "License"); you may not use this file except in compliance with
-- the License.  You may obtain a copy of the License at
--
--     http://www.apache.org/licenses/LICENSE-2.0
--
-- Unless required by applicable law or agreed to in writing, software
-- distributed under the License is distributed on an "AS IS" BASIS,
-- WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
-- See the License for the specific language governing permissions and
-- limitations under the License.
--
local core = require("apisix.core")
local schema_plugin = require("apisix.admin.plugins").check_schema
local tostring = tostring
local type = type


local _M = {
    version = 0.2,
}


local function check_conf(id, conf, need_id)
    if not conf then
        return nil, {error_msg = "missing configurations"}
    end

    id = id or conf.id
    if need_id and not id then
        return nil, {error_msg = "missing route id"}
    end

    if not need_id and id then
        return nil, {error_msg = "wrong route id, do not need it"}
    end

    if need_id and conf.id and tostring(conf.id) ~= tostring(id) then
        return nil, {error_msg = "wrong route id"}
    end

    core.log.info("schema: ", core.json.delay_encode(core.schema.route))
    core.log.info("conf  : ", core.json.delay_encode(conf))
    local ok, err = core.schema.check(core.schema.route, conf)
    if not ok then
        return nil, {error_msg = "invalid configuration: " .. err}
    end

    if conf.host and conf.hosts then
        return nil, {error_msg = "only one of host or hosts is allowed"}
    end

    if conf.remote_addr and conf.remote_addrs then
        return nil, {error_msg = "only one of remote_addr or remote_addrs is "
                                 .. "allowed"}
    end

    if conf.host and conf.hosts then
        return nil, {error_msg = "only one of host or hosts is allowed"}
    end

    local upstream_id = conf.upstream_id
    if upstream_id then
        local key = "/upstreams/" .. upstream_id
        local res, err = core.etcd.get(key)
        if not res then
            return nil, {error_msg = "failed to fetch upstream info by "
                                     .. "upstream id [" .. upstream_id .. "]: "
                                     .. err}
        end

        if res.status ~= 200 then
            return nil, {error_msg = "failed to fetch upstream info by "
                                     .. "upstream id [" .. upstream_id .. "], "
                                     .. "response code: " .. res.status}
        end
    end

    local service_id = conf.service_id
    if service_id then
        local key = "/services/" .. service_id
        local res, err = core.etcd.get(key)
        if not res then
            return nil, {error_msg = "failed to fetch service info by "
                                     .. "service id [" .. service_id .. "]: "
                                     .. err}
        end

        if res.status ~= 200 then
            return nil, {error_msg = "failed to fetch service info by "
                                     .. "service id [" .. service_id .. "], "
                                     .. "response code: " .. res.status}
        end
    end

    if conf.plugins then
        local ok, err = schema_plugin(conf.plugins)
        if not ok then
            return nil, {error_msg = err}
        end
    end

    return need_id and id or true
end


function _M.put(id, conf)
    local id, err = check_conf(id, conf, true)
    if not id then
        return 400, err
    end

    local key = "/routes/" .. id
    local res, err = core.etcd.set(key, conf)
    if not res then
        core.log.error("failed to put route[", key, "]: ", err)
        return 500, {error_msg = err}
    end

    return res.status, res.body
end


function _M.get(id)
    local key = "/routes"
    if id then
        key = key .. "/" .. id
    end

    local res, err = core.etcd.get(key)
    if not res then
        core.log.error("failed to get route[", key, "]: ", err)
        return 500, {error_msg = err}
    end

    return res.status, res.body
end


function _M.post(id, conf)
    local id, err = check_conf(id, conf, false)
    if not id then
        return 400, err
    end

    local key = "/routes"
    -- core.log.info("key: ", key)
    local res, err = core.etcd.push("/routes", conf)
    if not res then
        core.log.error("failed to post route[", key, "]: ", err)
        return 500, {error_msg = err}
    end

    return res.status, res.body
end


function _M.delete(id)
    if not id then
        return 400, {error_msg = "missing route id"}
    end

    local key = "/routes/" .. id
    -- core.log.info("key: ", key)
    local res, err = core.etcd.delete(key)
    if not res then
        core.log.error("failed to delete route[", key, "]: ", err)
        return 500, {error_msg = err}
    end

    return res.status, res.body
end


function _M.patch(id, conf, sub_path)
    if not id then
        return 400, {error_msg = "missing route id"}
    end

    if not sub_path then
        return 400, {error_msg = "missing sub-path"}
    end

    if not conf then
        return 400, {error_msg = "missing new configuration"}
    end

    local key = "/routes"
    if id then
        key = key .. "/" .. id
    end

    local res_old, err = core.etcd.get(key)
    if not res_old then
        core.log.error("failed to get route [", key, "]: ", err)
        return 500, {error_msg = err}
    end

    if res_old.status ~= 200 then
        return res_old.status, res_old.body
    end
    core.log.info("key: ", key, " old value: ",
                  core.json.delay_encode(res_old, true))

    local node_value = res_old.body.node.value
    local sub_value = node_value
    local sub_paths = core.utils.split_uri(sub_path)
    for i = 1, #sub_paths - 1 do
        local sub_name = sub_paths[i]
        if sub_value[sub_name] == nil then
            sub_value[sub_name] = {}
        end

        sub_value = sub_value[sub_name]

        if type(sub_value) ~= "table" then
            return 400, "invalid sub-path: /"
                        .. core.table.concat(sub_paths, 1, i)
        end
    end

    if type(sub_value) ~= "table" then
        return 400, "invalid sub-path: /" .. sub_path
    end

    local sub_name = sub_paths[#sub_paths]
    if sub_name and sub_name ~= "" then
        sub_value[sub_name] = conf
    else
        node_value = conf
    end
    core.log.info("new conf: ", core.json.delay_encode(node_value, true))

    local id, err = check_conf(id, node_value, true)
    if not id then
        return 400, err
    end

    -- TODO: this is not safe, we need to use compare-set
    local res, err = core.etcd.set(key, node_value)
    if not res then
        core.log.error("failed to set new route[", key, "]: ", err)
        return 500, {error_msg = err}
    end

    return res.status, res.body
end


return _M
