local unescape_uri = ngx.unescape_uri
local char = string.char


local baggage_mt = {
  __newindex = function()
    error("attempt to set immutable baggage", 2)
  end,
}


local function hex_to_char(c)
  return char(tonumber(c, 16))
end


local function from_hex(str)
  if str ~= nil then -- allow nil to pass through
    str = str:gsub("%x%x", hex_to_char)
  end
  return str
end


local function parse_jaeger_baggage_headers(headers)
  local baggage = {}
  for k, v in pairs(headers) do
    local baggage_key = k:match("^uberctx%-(.*)$")
    if baggage_key then
      baggage[baggage_key] = unescape_uri(v)
    end
  end
  setmetatable(baggage, baggage_mt)
  return baggage
end


local function parse_zipkin_b3_headers(headers)
  local warn = kong.log.warn
  -- X-B3-Sampled: if an upstream decided to sample this request, we do too.
  local should_sample = headers["x-b3-sampled"]
  if should_sample == "1" or should_sample == "true" then
    should_sample = true
  elseif should_sample == "0" or should_sample == "false" then
    should_sample = false
  elseif should_sample ~= nil then
    warn("x-b3-sampled header invalid; ignoring.")
    should_sample = nil
  end

  -- X-B3-Flags: if it equals '1' then it overrides sampling policy
  -- We still want to warn on invalid sample header, so do this after the above
  local debug = headers["x-b3-flags"]
  if debug == "1" then
    should_sample = true
  elseif debug ~= nil then
    warn("x-b3-flags header invalid; ignoring.")
  end

  local had_invalid_id = false

  local trace_id = headers["x-b3-traceid"]
  if trace_id and ((#trace_id ~= 16 and #trace_id ~= 32) or trace_id:match("%X")) then
    warn("x-b3-traceid header invalid; ignoring.")
    had_invalid_id = true
  end

  local parent_id = headers["x-b3-parentspanid"]
  if parent_id and (#parent_id ~= 16 or parent_id:match("%X")) then
    warn("x-b3-parentspanid header invalid; ignoring.")
    had_invalid_id = true
  end

  local span_id = headers["x-b3-spanid"]
  if span_id and (#span_id ~= 16 or span_id:match("%X")) then
    warn("x-b3-spanid header invalid; ignoring.")
    had_invalid_id = true
  end

  if trace_id == nil or had_invalid_id then
    return nil
  end

  trace_id = from_hex(trace_id)
  span_id = from_hex(span_id)
  parent_id = from_hex(parent_id)

  return trace_id, span_id, parent_id, should_sample
end


local function parse_http_req_headers(headers)
  local trace_id, span_id, parent_id, should_sample = parse_zipkin_b3_headers(headers)

  if not trace_id then
    return nil
  end

  local baggage = parse_jaeger_baggage_headers(headers)

  return trace_id, span_id, parent_id, should_sample, baggage
end


return parse_http_req_headers
