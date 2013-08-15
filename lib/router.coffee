mu = require 'mu2'
path = require 'path'
os = require 'os'
fs = require 'fs'
nginxPath = path.resolve 'nginx'
pidpath = ''

buildOpts = (routingTable) ->
  options =
    worker_processes: os.cpus().length
    access_log: path.join(nginxPath, 'access.log')
    error_log: path.join(nginxPath, 'error.log')
    pidfile: path.join(pidpath, 'porternginx.pid')
  for name, data of routingTable

    options.server ?= []
    server =
      domain: data.domain
      name: name
    options.server.push server

    options.upstream ?= []
    upstream =
      name: name
      method: data.method ? "least_conn"
      routes: []
    for route in data.routes
      upstream.routes.push
        host: route.host
        port: route.port
    options.upstream.push upstream

  return options

writeFile = (routingTable, cb) ->
  options = buildOpts routingTable
  mustache = mu.compileAndRender(path.resolve(nginxPath, 'nginx.conf.mustache'), options)
  output = fs.createWriteStream path.resolve(nginxPath, './nginx.conf')
  mustache.pipe output
  mustache.on 'error', (err) ->
    cb err
  output.on 'error', (err) ->
    cb err
  output.on 'close', ->
    cb null

module.exports =
  writeFile: writeFile
  buildOpts: buildOpts
  pidpath: pidpath
