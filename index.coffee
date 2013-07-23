server = require './lib/webserver.coffee'

server.listen process.env.PORT or 3000
