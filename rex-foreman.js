#!/usr/bin/env node

var scli = require('supercli')
  , _ = require('underscore')._
  , cp = require('child_process')
  , fs = require('fs')
  , os = require('os')
  , path = require('path')
  , package = require('./package.json')
  , optimist = require('optimist')
  , procfile = fs.readFileSync(path.resolve(__dirname, 'procfile'), 'utf-8')
  ;

scli("Platform: ", os.platform() )

// Pull all available non-black, non-reset colors from SuperCLI
var allColors =  _.omit( scli.$$, 't','k','K','w','W' ) 
var colorKeys = availableColors = _.keys( allColors )

var getColor = function(title) {
  var color = colorKeys[ _.random(colorKeys.length - 1) ]
  return allColors[color](title)
}

var lines = procfile.split("\n")
var procs = {}

lines.forEach(function(line) {
  scli("Parsing line: '" + line + "'")
  var tmp = line.split(":")
  if(tmp[1]) {
    var commandString =  tmp[1].replace(/\r/g,"").toString().trim().split(" ")
    var title = tmp[0].toString().trim()
    scli("New Title: '" + title + "', Command String: ", commandString)

    procs[title] = {
      command : _.first(commandString),
      args : _.rest(commandString),
      prefix : getColor(title)
    }
  }
})

fs.writeFileSync('parsed.json', JSON.stringify(procs, null, 2))
scli.success("Parsed config written!")

_.each(procs, function(params, name) {
  console.log( params.prefix + ": " + name, params.args )

  /*
  var process = cp.spawn(command.command, command.args)
  process.stdout.on('data', function(data) {
    
  })
  */
})
scli("Available colors:", colorKeys)
