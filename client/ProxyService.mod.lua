local HTTP = game:GetService('HttpService')
local _get = HTTP.GetAsync
local _post = HTTP.PostAsync
local _decode = HTTP.JSONDecode

local POST_METHODS = {'POST', 'PUT', 'PATCH'}
local GET_METHODS = {'GET', 'DELETE'}

local ProxyService = {}

local processBody = function (body)
  local pos, _, match = body:find('"""(.+)"""$')
  local data = _decode(HTTP, match)
  local res = {
    headers = data.headers,
    status = data.status,
    body = body:sub(1, pos - 1)
  }
  return res
end

local HTTPGet = function (...)
  local body = _get(HTTP, ...)
  return processBody(body)
end

local HTTPPost = function (...)
  local body = _post(HTTP, ...)
  return processBody(body)
end

local getHeaders = function (this, method, target, headers, overrideProto)
  local sendHeaders = headers or {}
  sendHeaders['proxy-access-key'] = this.accessKey
  sendHeaders['proxy-target'] = target
  if overrideProto then
    sendHeaders['proxy-target-override-proto'] = overrideProto
  end
  if method ~= 'GET' and method ~= 'POST' then
    sendHeaders['proxy-target-override-method'] = method
  end
  if headers then
    for header, value in next, headers do
      local headerLower = header:lower();
      if headerLower == 'user-agent' then
        sendHeaders['user-agent'] = nil
        sendHeaders['proxy-override-user-agent'] = value
      end
    end
  end
  return sendHeaders
end

local generatePostHandler = function (method)
  return function (self, target, path, data, contentType, compress, headers, overrideProto)
    local sendHeaders = getHeaders(self, method, target, headers, overrideProto)
    return HTTPPost(self.root .. path, data, contentType, compress, sendHeaders)
  end
end

local generateGetHandler = function (method)
  return function (self, target, path, nocache, headers, overrideProto)
    local sendHeaders = getHeaders(self, method, target, headers, overrideProto)
    return HTTPGet(self.root .. path, nocache, sendHeaders)
  end
end

local urlProcessor = function (callback)
  return function (self, url, ...)
    local _, endpos = url:find('://')
    local nextpos = url:find('/', endpos + 1) or #url + 1
    local target = url:sub(endpos + 1, nextpos - 1)
    local path = url:sub(nextpos)
    return callback(self, target, path, ...)
  end
end

local generateWithHandler = function (handler, method, _)
  ProxyService[method:sub(1,1):upper() .. method:sub(2):lower()] = urlProcessor(handler(method))
end

for _, method in next, POST_METHODS do
  generateWithHandler(generatePostHandler, method)
end
for _, method in next, GET_METHODS do
  generateWithHandler(generateGetHandler, method)
end

function ProxyService:New(root, accessKey)
  if root:sub(#root, #root) == '/' then
    root = root:sub(1, #root - 1)
  end
  if not root:find('^HTTP[s]?://') then
    error('Root must include HTTP:// or HTTPs:// at the beginning!')
  end
  self.root = root
  self.accessKey = accessKey
  return self
end

return ProxyService
