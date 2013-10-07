#!/usr/bin/env node

var scli = require('rex-shell')
  , _ = require('underscore')._
  , optimist = require('optimist')
  , cp = require('child_process')
  , fs = require('fs')
  , os = require('os')
  , path = require('path')
  , package = require('./package.json')
  , config = package.config
  , procfile = fs.readFileSync('./procfile', { encoding : 'utf8' })
  , procs = {}
  // Create our Socket.io server
  , express = require('express')
  , app = express()
  , server = require('http').createServer(app)
  , io = require('socket.io').listen(server)
  , procfileConfig = {}

server.listen( config.port )

app.use( express.static( __dirname +"/web" ) )

app.get("/", function(req, res) {
  res.sendfile(__dirname +"/web/index.html")
})

io.sockets.on('connection', function(socket) {
  /**
   * Do all our awesomeness here!
   */
  scli("Socket Connected!")

  configure()

  socket.emit("config", procfileConfig)

  socket.on('event', function(data) {
    scli("Socket event!", data)
  })

  socket.on("disconnect", function() {
    scli("Socket disconnected!")
  })
})

/**
 * Below we have the configuration and process management functionality
 */
function configure() {
  scli("Configuring rex-foreman")

  var PROCS = procfile.split("\n")
    , NUM_PROCS = PROCS.length
    , PLATFORM = os.platform()
    , IS_MAC = ( PLATFORM == "darwin" )
    , IS_WINDOWS = ( PLATFORM == "win32" )
    , IS_LINUX = ( PLATFORM == "linux" )

  procfileConfig = {
    count : NUM_PROCS,
    platform : PLATFORM,
    is_mac : IS_MAC,
    is_linux : IS_LINUX,
    is_windows : IS_WINDOWS
  }

  _.each(procfile.split("\n"), function(proc, index) {

    var parts = proc.split(":")
      , name = parts[0].trim()
      , command = parts[1].trim()

    procs[name] = {
      command : command,
      dir : path.resolve( proc.dir || './' ),
      prefix : getColor(name+' | ')
    }

    scli( procs[name].prefix + "Process '"+name+"' created. \n\t" + scli.$.red(command) )
    
    var process = cp.spawn(command)

    process.stdout.on('data', function(data) {
      console.log(proc.prefix + ": " + data)    
    })
    process.stderr.on('data', function(data) {
      console.log(proc.prefix + " -- ERROR -- " + data)
      killProcesses()
    })
    procs[name].pid = process.pid
    procs[name].process = process

    scli("Proc '"+ name +"' ", procs[name])
  })
  
}

/*
scli("Platform: ", os.platform() )

// Pull all available non-black, non-reset colors from SuperCLI
var allColors =  _.omit( scli.$$, 't','k','K','w','W' ) 
var colorKeys = availableColors = _.keys( allColors )

var getColor = function(title) {
  var color = colorKeys[ _.random(colorKeys.length - 1) ]
  return allColors[color](title)
}

var killProcesses = function() {
  _.each(procs, function(proc) {
    proc.process.kill('SIGTERM')
  })
  process.exit(1)
}

scli("procfile", procfile)


// scli.success("All processes are now working!")
console.log("Working!")
*/