local http = require 'resty.http'
local setmetatable = setmetatable
local tonumber = tonumber
local byte = string.byte
local type = type
local null = ngx.null
local base64 = ngx.encode_base64

local ok, new_tab = pcall(require, "table.new")
if not ok then
    new_tab = function (narr, nrec) return {} end
end

local _M = new_tab(0, 16)

_M._VERSION = '0.0.1'

local mt = { __index = _M }

local useragent = 'ngx_lua-EurekaClient/v' .. _M._VERSION

local function request(eurekaclient, method, path, query, body)
    local host = ('http://%s:%s'):format(
        eurekaclient.host,
        eurekaclient.port
    )
    local path = eurekaclient.uri .. path
    local headers = new_tab(0, 5)
    headers['User-Agent'] = useragent
    headers['Connection'] = 'Keep-Alive'
    headers['Accept'] = 'application/json'

    local auth = eurekaclient.auth
    if auth then
        headers['Authorization'] = auth
    end

    if body then
        headers['Content-Type'] = 'application/json'
    end

    local httpc = eurekaclient.httpc
    if not httpc then
        return nil, 'not initialized'
    end
    ngx.log(ngx.ALERT, 'method: ' .. method)
    ngx.log(ngx.ALERT, 'host: ' .. host)
    ngx.log(ngx.ALERT, 'path: ' .. path)
    if body then 
        ngx.log(ngx.ALERT, 'body:' .. body)
    end
    return httpc:request_uri(host, {
        version = 1.1,
        method = method,
        headers = headers,
        path = path,
        query = query,
        body = body,
    })
end

function _M.new(self, host, port, uri, auth)
    if not host or 'string' ~= type(host) or 1 > #host then
        return nil, 'host required'
    end
    local port = tonumber(port) or 80
    if not port or 1 > port or 65535 < port then
        return nil, 'wrong port number'
    end
    local uri = uri or '/eureka'
    if 'string' ~= type(uri) or byte(uri) ~= 47 then 
        return nil, 'wrong uri prefix'
    end
    local _auth
    if auth and 'table' == type(auth) and auth.username and auth.password then
        _auth = ('Basic %s'):format(
            base64(('%s:%s'):format(
                auth.username,
                auth.password
            ))
        )
    end
    local httpc, err = http.new()
    if not httpc then
        return nil, 'failed to init http client instance : ' .. err
    end
    return setmetatable({
        host = host,
        port = port,
        uri = uri,
        auth = _auth,
        httpc = httpc,
    }, mt)
end


function _M.heartBeat(self, appid, instanceid)
    if not appid or 'string' ~= type(appid) or 1 > #appid then
        return nil, 'appid required'
    end
    if not instanceid or 'string' ~= type(instanceid) or 1 > #instanceid then
        return nil, 'instanceid required'
    end
    local res, err = request(self, 'PUT', '/apps/' .. appid .. '/' .. instanceid)
    if not res then
        return nil, err
    end
    if 200 == res.status then
        return true, res.body
    elseif 404 == res.status then
        return null, res.body
    else
        return false, ('status is %d : %s'):format(res.status, res.body)
    end
end

function _M.register(self, appid, instancedata)
    if not appid or 'string' ~= type(appid) or 1 > #appid then
        return nil, 'appid required'
    end
    if not instancedata  then
        return nil, 'instancedata required'
    end
    local res, err = request(self, 'POST', '/apps/' .. appid, nil, instancedata)
    if not res then
        return nil, err
    end
    if 204 == res.status then
        return true, res.body
    else
        return false, ('status is %d : %s'):format(res.status, res.body)
    end
end

function _M.deRegister(self, appid, instanceid)
    if not appid or 'string' ~= type(appid) or 1 > #appid then
        return nil, 'appid required'
    end
    if not instanceid or 'string' ~= type(instanceid) or 1 > #instanceid then
        return nil, 'instanceid required'
    end
    local res, err = request(self, 'DELETE', '/apps/' .. appid .. '/' .. instanceid)
    if not res then
        return nil, err
    end
    if 200 == res.status then
        return true, res.body
    else
        return false, ('status is %d : %s'):format(res.status, res.body)
    end
end

return _M
