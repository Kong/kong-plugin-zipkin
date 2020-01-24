--[[
The internal data structure is modeled off the ZipKin Span JSON Structure
This makes it cheaper to convert to JSON for submission to the ZipKin HTTP api;
which Jaegar also implements.
You can find it documented in this OpenAPI spec:
https://github.com/openzipkin/zipkin-api/blob/7e33e977/zipkin2-api.yaml#L280
]]

local zipkin_span_context = require "kong.plugins.zipkin.span_context"

local span_methods = {}
local span_mt = {
  __index = span_methods,
}

local ngx_now = ngx.now
local math_random = math.random


local function new(parent, name, start_timestamp, sample_ratio)
  if parent ~= nil then
    if type(parent.context) == "function" then -- get the context instead of the span, if given a span
      parent = parent:context()
    end
  end

  if start_timestamp == nil then
    start_timestamp = ngx_now()
  end

  local context
  if parent then
    context = parent:child()
  else
    local should_sample = math_random() < sample_ratio
    context = zipkin_span_context.new(nil, nil, nil, should_sample)
  end

  return setmetatable({
    context_ = context,
    name = name,
    timestamp = start_timestamp,
    duration = nil,
    -- Avoid allocations until needed
    baggage = nil,
    tags = nil,
    logs = nil,
    n_logs = 0,
  }, span_mt)
end


function span_methods:context()
  return self.context_
end

function span_methods:finish(finish_timestamp)
  assert(self.duration == nil, "span already finished")
  if finish_timestamp == nil then
    self.duration = ngx_now() - self.timestamp
  else
    assert(type(finish_timestamp) == "number")
    local duration = finish_timestamp - self.timestamp
    assert(duration >= 0, "invalid finish timestamp")
    self.duration = duration
  end
  return true
end

function span_methods:set_tag(key, value)
  assert(type(key) == "string", "invalid tag key")
  if value ~= nil then -- Validate value
    local vt = type(value)
    assert(vt == "string" or vt == "number" or vt == "boolean",
      "invalid tag value (expected string, number, boolean or nil)")
  end
  local tags = self.tags
  if tags then
    tags[key] = value
  elseif value ~= nil then
    tags = {
      [key] = value
    }
    self.tags = tags
  end
  return true
end

function span_methods:get_tag(key)
  assert(type(key) == "string", "invalid tag key")
  local tags = self.tags
  if tags then
    return tags[key]
  else
    return nil
  end
end

function span_methods:each_tag()
  local tags = self.tags
  if tags == nil then return function() end end
  return next, tags
end

function span_methods:log(key, value, timestamp)
  assert(type(key) == "string", "invalid log key")
  -- `value` is allowed to be anything.
  if timestamp == nil then
    timestamp = ngx_now()
  else
    assert(type(timestamp) == "number", "invalid timestamp for log")
  end

  local log = {
    key = key,
    value = value,
    timestamp = timestamp,
  }

  local logs = self.logs
  if logs then
    local i = self.n_logs + 1
    logs[i] = log
    self.n_logs = i
  else
    logs = { log }
    self.logs = logs
    self.n_logs = 1
  end
  return true
end

return {
  new = new,
}
