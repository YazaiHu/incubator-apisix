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
local schema    = require('apisix.core.schema')
local setmetatable = setmetatable

local _M = {version = 0.3}
setmetatable(_M, {__index = schema})


local plugins_schema = {
    type = "object"
}


local id_schema = {
    anyOf = {
        {
            type = "string", minLength = 1, maxLength = 32,
            pattern = [[^[0-9]+$]]
        },
        {type = "integer", minimum = 1}
    }
}


local host_def_pat = "^\\*?[0-9a-zA-Z-.]+$"
local host_def = {
    type = "string",
    pattern = host_def_pat,
}
_M.host_def = host_def


local ipv4_def = "[0-9]{1,3}.[0-9]{1,3}.[0-9]{1,3}.[0-9]{1,3}"
local ipv6_def = "([a-fA-F0-9]{0,4}:){0,8}(:[a-fA-F0-9]{0,4}){0,8}"
                 .. "([a-fA-F0-9]{0,4})?"
local ip_def = {
    {pattern = "^" .. ipv4_def .. "$"},
    {pattern = "^" .. ipv4_def .. "/[0-9]{1,2}$"},
    {pattern = "^" .. ipv6_def .. "$"},
    {pattern = "^" .. ipv6_def .. "/[0-9]{1,3}$"},
}
_M.ip_def = ip_def


local remote_addr_def = {
    description = "client IP",
    type = "string",
    anyOf = ip_def,
}


-- todo: support all options
--   default value: https://github.com/Kong/lua-resty-healthcheck/
--   blob/master/lib/resty/healthcheck.lua#L1121
local health_checker = {
    type = "object",
    properties = {
        active = {
            type = "object",
            properties = {
                type = {
                    type = "string",
                    enum = {"http", "https", "tcp"},
                    default = "http"
                },
                timeout = {type = "integer", default = 1},
                concurrency = {type = "integer", default = 10},
                host = host_def,
                http_path = {type = "string", default = "/"},
                https_verify_certificate = {type = "boolean", default = true},
                healthy = {
                    type = "object",
                    properties = {
                        interval = {type = "integer", minimum = 1, default = 0},
                        http_statuses = {
                            type = "array",
                            minItems = 1,
                            items = {
                                type = "integer",
                                minimum = 200,
                                maximum = 599
                            },
                            uniqueItems = true,
                            default = {200, 302}
                        },
                        successes = {
                            type = "integer",
                            minimum = 1,
                            maximum = 254,
                            default = 2
                        }
                    }
                },
                unhealthy = {
                    type = "object",
                    properties = {
                        interval = {type = "integer", minimum = 1, default = 0},
                        http_statuses = {
                            type = "array",
                            minItems = 1,
                            items = {
                                type = "integer",
                                minimum = 200,
                                maximum = 599
                            },
                            uniqueItems = true,
                            default = {429, 404, 500, 501, 502, 503, 504, 505}
                        },
                        http_failures = {
                            type = "integer",
                            minimum = 1,
                            maximum = 254,
                            default = 5
                        },
                        tcp_failures = {
                            type = "integer",
                            minimum = 1,
                            maximum = 254,
                            default = 2
                        },
                        timeouts = {
                            type = "integer",
                            minimum = 1,
                            maximum = 254,
                            default = 3
                        }
                    }
                }
            }
        },
        passive = {
            type = "object",
            properties = {
                type = {
                    type = "string",
                    enum = {"http", "https", "tcp"},
                    default = "http"
                },
                healthy = {
                    type = "object",
                    properties = {
                        http_statuses = {
                            type = "array",
                            minItems = 1,
                            items = {
                                type = "integer",
                                minimum = 200,
                                maximum = 599,
                            },
                            uniqueItems = true,
                            default = {200, 201, 202, 203, 204, 205, 206, 207,
                                       208, 226, 300, 301, 302, 303, 304, 305,
                                       306, 307, 308}
                        },
                        successes = {
                            type = "integer",
                            minimum = 1,
                            maximum = 254,
                            default = 5
                        }
                    }
                },
                unhealthy = {
                    type = "object",
                    properties = {
                        http_statuses = {
                            type = "array",
                            minItems = 1,
                            items = {
                                type = "integer",
                                minimum = 200,
                                maximum = 599,
                            },
                            uniqueItems = true,
                            default = {429, 500, 503}
                        },
                        tcp_failures = {
                            type = "integer",
                            minimum = 1,
                            maximum = 254,
                            default = 2
                        },
                        timeouts = {
                            type = "integer",
                            minimum = 1,
                            maximum = 254,
                            default = 7
                        },
                        http_failures = {
                            type = "integer",
                            minimum = 1,
                            maximum = 254,
                            default = 5
                        },
                    }
                }
            }
        }
    }
}


local upstream_schema = {
    type = "object",
    properties = {
        nodes = {
            description = "nodes of upstream",
            type = "object",
            patternProperties = {
                [".*"] = {
                    description = "weight of node",
                    type = "integer",
                    minimum = 0,
                }
            },
            minProperties = 1,
        },
        retries = {
            type = "integer",
            minimum = 1,
        },
        timeout = {
            type = "object",
            properties = {
                connect = {type = "number", minimum = 0},
                send = {type = "number", minimum = 0},
                read = {type = "number", minimum = 0},
            },
            required = {"connect", "send", "read"},
        },
        type = {
            description = "algorithms of load balancing",
            type = "string",
            enum = {"chash", "roundrobin"}
        },
        checks = health_checker,
        key = {
            description = "the key of chash for dynamic load balancing",
            type = "string",
            enum = {"remote_addr"},
        },
        desc = {type = "string", maxLength = 256},
        id = id_schema
    },
    required = {"nodes", "type"},
    additionalProperties = false,
}



local route = {
    type = "object",
    properties = {
        uri = {type = "string", minLength = 1, maxLength = 4096},
        desc = {type = "string", maxLength = 256},

        methods = {
            type = "array",
            items = {
                description = "HTTP method",
                type = "string",
                enum = {"GET", "POST", "PUT", "DELETE", "PATCH", "HEAD",
                        "OPTIONS", "CONNECT", "TRACE"}
            },
            uniqueItems = true,
        },
        host = host_def,
        hosts = {
            type = "array",
            items = host_def,
            uniqueItems = true,
        },
        remote_addr = remote_addr_def,
        remote_addrs = {
            type = "array",
            items = remote_addr_def,
            uniqueItems = true,
        },
        vars = {
            type = "array",
            items = {
                description = "Nginx builtin variable name and value",
                type = "array",
                items = {
                    maxItems = 3,
                    minItems = 2,
                    anyOf = {
                        {type = "string",},
                        {type = "number",},
                    }
                }
            }
        },

        plugins = plugins_schema,
        upstream = upstream_schema,

        service_id = id_schema,
        upstream_id = id_schema,
        service_protocol = {
            enum = {"grpc", "http"}
        },
        id = id_schema,
    },
    anyOf = {
        {required = {"plugins", "uri"}},
        {required = {"upstream", "uri"}},
        {required = {"upstream_id", "uri"}},
        {required = {"service_id", "uri"}},
    },
    additionalProperties = false,
}
_M.route = route


_M.service = {
    type = "object",
    properties = {
        id = id_schema,
        plugins = plugins_schema,
        upstream = upstream_schema,
        upstream_id = id_schema,
        desc = {type = "string", maxLength = 256},
    },
    anyOf = {
        {required = {"upstream"}},
        {required = {"upstream_id"}},
        {required = {"plugins"}},
    },
    additionalProperties = false,
}


_M.consumer = {
    type = "object",
    properties = {
        username = {
            type = "string", minLength = 1, maxLength = 32,
            pattern = [[^[a-zA-Z0-9_]+$]]
        },
        plugins = plugins_schema,
        desc = {type = "string", maxLength = 256}
    },
    required = {"username"},
    additionalProperties = false,
}


_M.upstream = upstream_schema


_M.ssl = {
    type = "object",
    properties = {
        cert = {
            type = "string", minLength = 128, maxLength = 64*1024
        },
        key = {
            type = "string", minLength = 128, maxLength = 64*1024
        },
        sni = {
            type = "string",
            pattern = [[^\*?[0-9a-zA-Z-.]+$]],
        }
    },
    required = {"sni", "key", "cert"},
    additionalProperties = false,
}


_M.proto = {
    type = "object",
    properties = {
        content = {
            type = "string", minLength = 1, maxLength = 4096
        }
    },
    required = {"content"},
    additionalProperties = false,
}


_M.global_rule = {
    type = "object",
    properties = {
        plugins = plugins_schema
    },
    required = {"plugins"},
    additionalProperties = false,
}


_M.stream_route = {
    type = "object",
    properties = {
        remote_addr = remote_addr_def,
        server_addr = {
            description = "server IP",
            type = "string",
            anyOf = ip_def,
        },
        server_port = {
            description = "server port",
            type = "integer",
        },
        upstream = upstream_schema,
        upstream_id = id_schema,
        plugins = plugins_schema,
    }
}


return _M
