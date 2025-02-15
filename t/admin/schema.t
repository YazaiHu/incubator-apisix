#
# Licensed to the Apache Software Foundation (ASF) under one or more
# contributor license agreements.  See the NOTICE file distributed with
# this work for additional information regarding copyright ownership.
# The ASF licenses this file to You under the Apache License, Version 2.0
# (the "License"); you may not use this file except in compliance with
# the License.  You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
use t::APISIX 'no_plan';

repeat_each(1);
no_long_string();
no_root_location();
no_shuffle();
log_level("info");

run_tests;

__DATA__

=== TEST 1: get route schema
--- request
GET /apisix/admin/schema/route
--- response_body eval
qr/"plugins":\{"type":"object"}/
--- no_error_log
[error]



=== TEST 2: get service schema
--- request
GET /apisix/admin/schema/service
--- response_body eval
qr/"required":\["upstream"\]/
--- no_error_log
[error]



=== TEST 3: get not exist schema
--- request
GET /apisix/admin/schema/noexits
--- error_code: 400
--- no_error_log
[error]



=== TEST 4: wrong method
--- request
PUT /apisix/admin/schema/service
--- error_code: 404
--- no_error_log
[error]



=== TEST 5: wrong method
--- request
POST /apisix/admin/schema/service
--- error_code: 404
--- no_error_log
[error]



=== TEST 6: ssl
--- config
location /t {
    content_by_lua_block {
        local t = require("lib.test_admin").test
        local code, body = t('/apisix/admin/schema/ssl',
            ngx.HTTP_GET,
            nil,
            {
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
            )

        ngx.status = code
        ngx.say(body)
    }
}
--- request
GET /t
--- response_body
passed
--- no_error_log
[error]



=== TEST 7: get plugin's schema
--- request
GET /apisix/admin/schema/plugins/limit-count
--- response_body eval
qr/"required":\["count","time_window","key","rejected_code"]/
--- no_error_log
[error]



=== TEST 8: get not exist plugin
--- request
GET /apisix/admin/schema/plugins/no-exist
--- error_code: 400
--- no_error_log
[error]
