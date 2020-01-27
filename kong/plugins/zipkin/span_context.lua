--[[
Span contexts should be immutable
]]

local utils = require "kong.tools.utils"
local rand_bytes = utils.get_rand_bytes

-- For zipkin compat, use 128 bit trace ids
local function generate_trace_id()
  return rand_bytes(16)
end

-- For zipkin compat, use 64 bit span ids
local function generate_span_id()
  return rand_bytes(8)
end

local span_context_methods = {}
local span_context_mt = {
  __index = span_context_methods,
}

-- Public constructor
local function new(trace_id, span_id, parent_id, should_sample, baggage)
  if trace_id == nil then
    trace_id = generate_trace_id()
  else
    assert(type(trace_id) == "string", "invalid trace id")
  end
  if span_id == nil then
    span_id = generate_span_id()
  else
    assert(type(span_id) == "string", "invalid span id")
  end
  if parent_id ~= nil then
    assert(type(parent_id) == "string", "invalid parent id")
  end
  return setmetatable({
    trace_id = trace_id,
    span_id = span_id,
    parent_id = parent_id,
    should_sample = should_sample,
    baggage = baggage,
  }, span_context_mt)
end

function span_context_methods:child()
  return setmetatable({
    trace_id = self.trace_id,
    span_id = generate_span_id(),
    parent_id = self.span_id,
    -- If parent was sampled, sample the child
    should_sample = self.should_sample,
    baggage = self.baggage,
  }, span_context_mt)
end

function span_context_methods:each_baggage_item()
  local baggage = self.baggage
  if baggage == nil then return function() end end
  return next, baggage
end

return {
  new = new,
}
