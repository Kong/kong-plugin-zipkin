local resty_http = require "resty.http"
local to_hex = require "resty.string".to_hex
local cjson = require "cjson".new()
cjson.encode_number_precision(16)

local zipkin_reporter_methods = {}
local zipkin_reporter_mt = {
	__name = "kong.plugins.zipkin.reporter";
	__index = zipkin_reporter_methods;
}

local function new_zipkin_reporter(conf) -- lauacheck: ignore 212
	local http_endpoint = conf.http_endpoint
	assert(type(http_endpoint) == "string", "invalid http endpoint")
	return setmetatable({
		http_endpoint = http_endpoint;
		pending_spans = {};
		pending_spans_n = 0;
	}, zipkin_reporter_mt)
end

local span_kind_map = {
	client = "CLIENT";
	server = "SERVER";
	producer = "PRODUCER";
	consumer = "CONSUMER";
}
function zipkin_reporter_methods:report(span)
	local span_context = span.context
	local span_kind = span:get_tag "span.kind"
	local port = span:get_tag "peer.port"
	local zipkin_span = {
		traceId = to_hex(span_context.trace_id);
		name = span.name;
		parentId = span_context.parent_id and to_hex(span_context.parent_id) or nil;
		id = to_hex(span_context.span_id);
		kind = span_kind_map[span_kind];
		timestamp = span.timestamp * 1000000;
		duration = math.floor(span.duration * 1000000); -- zipkin wants integer
		-- TODO: shared?
		-- TODO: debug?
		localEndpoint = cjson.null, -- needs to be null; not the empty object
		-- TODO: localEndpoint from ngx.var.server_name/ngx.var.server_port?
		remoteEndpoint = port and {
			ipv4 = span:get_tag "peer.ipv4";
			ipv6 = span:get_tag "peer.ipv6";
			port = port; -- port is *not* optional
		} or cjson.null;
		tags = span.tags; -- XXX: not guaranteed by documented opentracing-lua API
		annotations = span.logs -- XXX: not guaranteed by documented opentracing-lua API to be in correct format
	}

	local i = self.pending_spans_n + 1
	self.pending_spans[i] = zipkin_span
	self.pending_spans_n = i
end

function zipkin_reporter_methods:flush()
	if self.pending_spans_n == 0 then
		return true
	end

	local pending_spans = cjson.encode(self.pending_spans)
	self.pending_spans = {}
	self.pending_spans_n = 0

	local httpc = resty_http.new()
	local res, err = httpc:request_uri(self.http_endpoint, {
		method = "POST";
		headers = {
			["content-type"] = "application/json";
		};
		body = pending_spans;
	})
	-- TODO: on failure, retry?
	if not res then
		return nil, "failed to request: " .. err
	elseif res.status < 200 or res.status >= 300 then
		return nil, "failed: " .. res.status .. " " .. res.reason
	end
	return true
end

return {
	new = new_zipkin_reporter;
}
