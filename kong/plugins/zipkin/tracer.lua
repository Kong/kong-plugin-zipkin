local ngx_now = ngx.now

local zipkin_span = require "kong.plugins.zipkin.span"
local zipkin_span_context = require "kong.plugins.zipkin.span_context"

local math_random = math.random

local tracer_methods = {}
local tracer_mt = {
  __index = tracer_methods,
}

local function new(sample_ratio)
  return setmetatable({
    sample_ratio = sample_ratio,
  }, tracer_mt)
end

function tracer_methods:start_span(parent, name, start_timestamp)
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
    local should_sample = math_random() < self.sample_ratio
    context = zipkin_span_context.new(nil, nil, nil, should_sample)
  end

  return zipkin_span.new(context, name, start_timestamp)
end

return {
  new = new,
}
