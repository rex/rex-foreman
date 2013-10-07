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

pkg = require "../package.json"
config = pkg.config

scli.config.appName("Rex-Foreman")

Rex_Foreman = {}

pad = (str, width) ->
	len = str.length
	while len < width
		str += " "
	str

log = () ->
	console.log.apply console, arguments

handlers =
	app : 
		connect : (socket) ->
		
		disconnect : () ->
			scli "Socket Disconnected!"

		boot : () ->
			scli "Booting Processes"
			
			_.each Rex_Foreman.procs, (params, name) ->
				if params.active
					scli "Booting '#{name}'"
					Rex_Foreman.procs[ name ].process = new Process params
				else
					scli "Skipping Inactive Process #{name}"

			# scli "Rex Procs", Rex_Foreman.procs

		exit : () ->

	master :
		die : () ->

		recover : () ->

	event :
		exit : () ->

		exception : (err) ->

		sigterm : () ->

		sigkill : () ->

class Process
	constructor : (Params) ->
		scli "Creating Process #{Params.name}"
		@name = Params.name
		@command = Params.command
		@args = Params.args
		@dir = Params.dir or process.cwd()
		@pid = 0
		@worker = null
		@output = []

		if @run()
			scli "Process #{@name} created"
		else
			scli.error "Process #{@name} failed :("

		this

	setPrefix : () ->
		@prefix = pad("#{@name} ( #{@pid} )", 25)+" | "

	run : () ->
		proc = this

		@worker = worker = cp.spawn @command, @args, { cwd : @dir }

		@worker.stdout.setEncoding('utf8')
		@worker.stderr.setEncoding('utf8')

		@worker.stdout.on "data", (data) ->
			scli "Process data received, sending to client #{proc.name}", data
			Rex_Foreman.socket.emit "process:data", proc.name, data

		@worker.stderr.on "data", (data) ->
			scli "Process data received, sending to client #{proc.name}", data
			Rex_Foreman.socket.emit "process:data", proc.name, data

		@worker.on "error", (err) ->
			scli.error "Process error in #{proc.name}: #{err}", proc.worker
			Rex_Foreman.socket.emit "process:error", proc.name, err

		@worker.on "close", (code, signal) ->
			if code then scli "Closed Process: #{proc.name} with code #{code} and signal #{signal}"
			Rex_Foreman.socket.emit "process:die", proc.name, code, signal

		process.on "exit", () ->
			scli.error "Parent process dying, killing #{proc.name}"
			Rex_Foreman.socket.emit "process:die", proc.name
			proc.worker.kill "SIGTERM"

		# Successfully started process, let's send the process:start event
		@pid = @worker.pid
		Rex_Foreman.socket.emit "process:start", proc.name, @pid

	onexception : () ->

	kill : () ->



class Rex
	constructor : (Params) ->
		scli "Creating new Rex-Foreman instance"
		unless Params then Params = {} 

		@platform = os.platform()
		@is_mac = @platform == "darwin"
		@is_linux = @platform == "linux"
		@is_windows = @platform == "win32"

		scli "Your platform: #{@platform}"

		@ProcfilePath = Params.procfile or "./procfile"
		@procfile = fs.readFileSync @ProcfilePath,
			encoding : 'utf8'

		@parseProcfile()
		
		@num_procs = _.size @procs

		scli "Rex-Foreman will run #{@num_procs} processes", @procs
		scli "Configuring Rex-Foreman"

		@configure()

		scli "Configured. Running Rex-Foreman"

		@run()

		scli "Rex-Foreman running!"

		return this

	parseProcfile : () ->
		scli "Parsing procfile..."

		rex = this
		procfile = @procfile.split "\n"
		parsedProcs = {}

		try
			_.each procfile, (proc) ->
				if proc is "" then return 

				parts = proc.split(":")
				args = []
				active = true

				if parts.length >= 2
					name = parts[0].trim()
					fullCommand = proc.split(":").slice(1).join(":").trim().split(" ")
					command = fullCommand.shift()
					args = fullCommand
				else
					unless _.isString parts then rex.die "Invalid Procfile"
					command = parts

				if name.charAt(0) == "#"
					name = (name.substr 1).trim()
					active = false

				parsedProcs[name] = 
					name : name
					command : command
					active : active
					args : args

			rex.procs = parsedProcs

			scli "Procfile Parsed..."
			this
		catch err
			scli.error "Error parsing procfile: "
			scli.error err
			process.exit 1
			
			scli "Proc: ", renderData

	getConfig : () ->
		procs : @procs
		num_procs : @num_procs
		platform : @platform
		is_mac : @is_mac
		is_linux : @is_linux
		is_windows : @is_windows


	configure : () ->
		scli "Configuring Rex-Foreman"
		@app = express()
		dirpath = path.resolve( __dirname, "../web" )
		indexpath = path.resolve( __dirname, "../web/index.html" )

		log "Dirpath/Indexpath", dirpath, indexpath
		@app.use express.static( dirpath )
		@app.get "/", (req, res) ->
			res.sendfile indexpath

		@server = http.createServer( @app )

	die : (Msg) ->
		scli.error Msg
		process.exit 1

	run : () ->
		scli "Running!"
		@io = io.listen( @server )

		@server.listen config.port

		@parseProcfile()

		@setupSockets()

	setupSockets : () ->
		rex = this

		@io.sockets.on "connection", (socket) ->
			rex.socket = socket

			scli "Socket Connected!", Rex_Foreman.getConfig()

			process.on "exit", () ->
				scli.error "Parent process dying"
				socket.emit "master:die", "DEATH"
				rex.killAll()

			process.on "SIGINT", () ->
				if rex.readyToDie
					log "Suit yourself! Killing everything now!"
					rex.killAll()
					process.exit 0
				else
					rex.readyToDie = true
					log "Press Ctrl+C again to quit!"

				false

			process.on "SIGTERM", () ->
				log "SIGTERM Received!"
				rex.killAll()
				process.exit 0

			process.on "uncaughtException", (err) ->
				log "Exception Caught: ", err, err.stack
				false

			socket.emit "connected", Rex_Foreman.getConfig()

			socket.on "disconnect", handlers.app.disconnect

			socket.on "app:boot", handlers.app.boot

		this

	killAll : () ->
		log "Killing all processes"
		_.each @procs, (proc) ->
			if proc.worker and typeof proc.worker.kill != undefined
				scli "Killing process #{proc.name}", proc.worker
				proc.worker.kill "SIGKILL"
			else
				scli "Process #{proc.name} already dead"

		process.exit 0

	module.exports = 
		init : () ->
			Rex_Foreman = new Rex()
		version : () ->
			log "Version: #{pkg.version}"
			process.exit 0

			
