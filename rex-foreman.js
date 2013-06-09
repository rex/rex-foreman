#!/usr/bin/env node

var scli = require('supercli')
  , _ = require('underscore')._
  , cp = require('child_process')
  , fs = require('fs')
  , os = require('os')
  , path = require('path')
  , package = require('./package.json')
  , optimist = require('optimist')
  , procfile = require('./procfile.json')
  , procs = {}
  ;

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

_.each(procfile, function(params, name) {
  
  var command = _.first( params.cmd.split(" ") )
  var args = _.rest( params.cmd.split(" ") )

  procs[name] = {
    command : command,
    args : args
  }
  
  // Make sure we set default values in case of empty properties
  procs[name] = {
    dir : path.resolve( params.dir || './' ),
    workers : params.workers || 1,
    prefix : getColor(name+' | ')
  }

  scli( procs[name].prefix + "Process '"+name+"' created. \n\t" + scli.$.red(command) )
  
  var process = cp.spawn(command, args, {
    cwd : procs[name].dir
  })
  process.stdout.on('data', function(data) {
    console.log(params.prefix + ": " + data)    
  })
  process.stderr.on('data', function(data) {
    console.log(params.prefix + " -- ERROR -- " + data)
    killProcesses()
  })
  procs[name].pid = process.pid
  procs[name].process = process

})

scli.success("All processes are now working!")
