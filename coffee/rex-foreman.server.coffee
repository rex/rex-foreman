#!/usr/bin/env node

cp = require "child_process"
fs = require "fs"
os = require "os"
path = require "path"
util = require "util"

scli = require "rex-shell"
_ = require "underscore"
optimist = require "optimist"
express = require "express"
http = require "http"
io = require "socket.io"

pkg = require "./package.json"
config = pkg.config

_.mixin "pad", (str, width) ->
	len = str.length
	while len < width
		str += " "
	str


class Process
	constructor : (Params) ->
		@name = Params.name
		@command = Params.command
		@dir = Params.dir or __dirname
		@prefix = _.pad("#{@name} ( #{@pid} )", 25)+" | "
		@pid = 0
		@process = null
		@output = []

	run : () ->


	onexception : () ->

	kill : () ->

class Rex
	constructor : (Params) ->
		unless Params then Params = {} 
		@ProcfilePath = Params.procfile or "./procfile"
		@procfile = fs.readFileSync @ProcfilePath,
			encoding : 'utf8'
		@procs = @procfile.split "\n"
		@num_procs = @procs.length

		@platform = os.platform()
		@is_mac = @platform == "darwin"
		@is_linux = @platform == "linux"
		@is_windows = @platform == "win32"

		@configure()

		@run()

		return this


	configure : () ->
		scli "Configuring rex-foreman"
		@app = express()
		@app.use express.static( __dirname+"/web" )
		@app.get "/", (req, res) ->
			res.sendfile __dirname +"/web/index.html"

		@server = http.createServer( @app )

	run : () ->
		scli "Running!"
		@io = io.listen( @server )

		@server.listen config.port

		@setupSockets()

	setupSockets : () ->
		rex = this

		@io.sockets.on "connection", (socket) ->
			scli "Socket Connected!"

			socket.emit "config",
				procs : rex.procs
				count : rex.num_procs
				platform : rex.platform
				is_mac : rex.is_mac
				is_linux : rex.is_linux
				is_windows : rex.is_windows

			socket.on "event", (data) ->
				scli "Socket Event!", data

			socket.on "disconnect", () ->
				scli "Socket Disconnected!"

		this


Rex_Foreman = new Rex()