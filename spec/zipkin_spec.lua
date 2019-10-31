local TEST_TIMEOUT = 2

local cqueues = require "cqueues"
local helpers = require "spec.helpers"
local http_request = require "http.request"
local http_server = require "http.server"
local new_headers = require "http.headers".new
local cjson = require "cjson"


for _, strategy in helpers.each_strategy() do
describe("integration tests with mock zipkin server [#" .. strategy .. "]", function()
  local server

  local cb
  local proxy_port, proxy_host
  after_each(function()
    cb = nil
  end)

  local with_server do
    local function assert_loop(cq, timeout)
      local ok, err, _, thd = cq:loop(timeout)
      if not ok then
        if thd then
          err = debug.traceback(thd, err)
        end
        error(err, 2)
      end
    end

    with_server = function(server_cb, client_cb)
      cb = spy.new(server_cb)
      local cq = cqueues.new()
      cq:wrap(assert_loop, server)
      cq:wrap(client_cb)
      assert_loop(cq, TEST_TIMEOUT)
      return (cb:called())
    end
  end

  setup(function()
    -- create a mock zipkin server
    server = assert(http_server.listen {
      host = "127.0.0.1";
      port = 0;
      onstream = function(_, stream)
        local req_headers = assert(stream:get_headers())
        local res_headers = new_headers()
        res_headers:upsert(":status", "500")
        res_headers:upsert("connection", "close")
        assert(cb, "test has not set callback")
        local body = cb(req_headers, res_headers, stream)
        assert(stream:write_headers(res_headers, false))
        assert(stream:write_chunk(body or "", true))
      end;
    })
    assert(server:listen())
    local _, ip, port = server:localname()

    local bp = helpers.get_db_utils(strategy, { "services", "routes", "plugins" })

    -- enable zipkin plugin globally pointing to mock server
    bp.plugins:insert({
      name = "zipkin",
      config = {
        sample_ratio = 1,
        http_endpoint = string.format("http://%s:%d/api/v2/spans", ip, port),
      }
    })

    -- create service+route pointing at the zipkin server
    local service = bp.services:insert({
      name = "mock-zipkin",
      url = string.format("http://%s:%d", ip, port),
    })

    bp.routes:insert({
      service = { id = service.id },
      hosts = { "mock-zipkin-route" },
      preserve_host = true,
    })

    helpers.start_kong({
      database = strategy,
    })

    proxy_host = helpers.get_proxy_ip(false)
    proxy_port = helpers.get_proxy_port(false)
  end)


  teardown(function()
    server:close()
    helpers.stop_kong()
  end)

  it("vaguely works", function()
    assert.truthy(with_server(function(req_headers, res_headers, stream)
      if req_headers:get(":authority") == "mock-zipkin-route" then
        -- is the request itself
        res_headers:upsert(":status", "204")
      else
        local body = cjson.decode((assert(stream:get_body_as_string())))
        assert.same("table", type(body))
        assert.same("table", type(body[1]))
        for _, v in ipairs(body) do
          assert.same("string", type(v.traceId))
          assert.truthy(v.traceId:match("^%x+$"))
          assert.same("number", type(v.timestamp))
          assert.same("table", type(v.tags))
          assert.truthy(v.duration >= 0)
        end
        res_headers:upsert(":status", "204")
      end
    end, function()
      local req = http_request.new_from_uri("http://mock-zipkin-route/")
      req.host = proxy_host
      req.port = proxy_port
      assert(req:go())
    end))
  end)
  it("uses trace id from request", function()
    local trace_id = "1234567890abcdef"
    assert.truthy(with_server(function(_, res_headers, stream)
      local body = cjson.decode((assert(stream:get_body_as_string())))
      for _, v in ipairs(body) do
        assert.same(trace_id, v.traceId)
      end
      res_headers:upsert(":status", "204")
    end, function()
      local uri = string.format("http://%s:%d/", proxy_host, proxy_port)
      local req = http_request.new_from_uri(uri)
      req.headers:upsert("x-b3-traceid", trace_id)
      req.headers:upsert("x-b3-sampled", "1")
      assert(req:go())
    end))
  end)
  it("propagates b3 headers", function()
    local trace_id = "1234567890abcdef"
    assert.truthy(with_server(function(req_headers, res_headers, stream)
      if req_headers:get(":authority") == "mock-zipkin" then
        -- this is our proxied request
        assert.same(trace_id, req_headers:get("x-b3-traceid"))
        assert.same("1", req_headers:get("x-b3-sampled"))
      else
        -- we are playing role of zipkin server
        local body = cjson.decode((assert(stream:get_body_as_string())))
        for _, v in ipairs(body) do
          assert.same(trace_id, v.traceId)
        end
        res_headers:upsert(":status", "204")
      end
    end, function()
      local req = http_request.new_from_uri("http://mock-zipkin/")
      req.host = proxy_host
      req.port = proxy_port
      req.headers:upsert("x-b3-traceid", trace_id)
      req.headers:upsert("x-b3-sampled", "1")
      assert(req:go())
    end))
  end)
end)
end
