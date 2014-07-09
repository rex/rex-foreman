#
# Assume that var io = require("socket.io") has already been called
#
Array.prototype.random = () ->
	return this[ Math.floor( Math.random() * this.length ) ]

log = () ->
	console.log.apply console, arguments

COLORS = ['green','red','blue','purple','teal']

error = (Proc, Msg) ->
	tpl = Handlebars.compile( $("#process_error").html() )
	$("#process_output_target").prepend tpl
		proc : Proc
		message : Msg

RexProcessView = Backbone.View.extend
	events : {}
	initialize : () ->
		@visible = true
		@model.on "change:pid", @updatePid, this
		@template = Handlebars.compile( $("#process_item").html() )
		@model.set "fullCommand", "#{@model.get('command')} #{@model.get('args').join(" ")}"

		this
	render : () ->
		rex = this
		name = @model.get 'name'
		visible = @visible

		# log "Rendering #{name} Process View", @model.toJSON()
		@$el.html( @template @model.toJSON() )
		# log "Finding checkboxes"
		this.$el.find(".ui.toggle.checkbox")
			.checkbox
				onEnable : () ->
					# log "Making #{name} visible from #{visible}"
					$("[data-rex-output][data-process=#{name}]").show()
					rex.visible = true
				onDisable : () ->
					# log "Making #{name} invisible from #{visible}"
					$("[data-rex-output][data-process=#{name}]").hide()
					rex.visible = false

		# log "Items Visible for #{name}: #{@visible}"

		this
	updatePid : () ->
		@$('div[data-pid]').text @model.get 'pid'

RexProcess = Backbone.Model.extend
	idAttribute : "name"
	template : () ->
	defaults : 
		name : ""
		pid : "NOT RUNNING"
		command : ""
		args : []
		active : false
		scrollback : []
		color : ""
	initialize : () ->
		@tpl_output = Handlebars.compile( $("#process_output").html() )
		@set "color", COLORS.random()
	output : (output) ->
		# log "Rendering Process Output",
			# proc : @toJSON()
			# output : output
		return @tpl_output
			proc : @toJSON()
			output : output

RexProcesses = Backbone.Collection.extend
	model : RexProcess
	render : () ->
		@each (model) ->
			$("#process_item_target").append( new RexProcessView({ model : model }).render().el )
		this

handlers =
	app : 
		connected : (config) ->
			# log "Connected! ", config

			window.RexSocket.config = config
			window.RexSocket.procs = config.procs

			$("#server_down").modal('hide')

			$target = $ "#process_item_target"
			$target.empty()

			_.each config.procs, (proc) ->
				window.RexSocket.processes.add( new RexProcess proc )

			window.RexSocket.processes.render()

			# log "UI Built, Booting Processes"

			window.RexSocket.socket.emit "app:boot"
		
		disconnected : () ->
			# log "Disconnected from the server socket!"

		boot : () ->

		exit : () ->

	process :
		start : (name, pid) ->
			window.RexSocket.processes.get( name ).set 'pid', pid
			# log "Process #{pid} started: ", name, window.RexSocket.processes.get( name ).toJSON()
			$("div[data-process-item=#{name}]")
				.addClass("active")
				.removeClass("dimmed")
				.find(".ui.toggle.checkbox")
					.checkbox('enable')
			$("div.item[data-process=#{name}]")
				.removeClass("dimmed")

		data : (name, output) ->
			# log "Process #{name} (STDOUT): ", output
			proc = window.RexSocket.procs[name]

			$("#process_output_target").prepend window.RexSocket.processes.get(name).output( output )

		error : (name, err) ->
			# log "Process #{name} (STDERR): ", err

		end : (name, code) ->
			# log "Process #{name} (END): ", code

		die : (name, code, signal) ->
			# log "Process #{name} (DIE): ", code, signal
			$("div[data-process-item=#{name}]")
				.removeClass("active")
				.addClass("dimmed")
				.find(".ui.toggle.checkbox")
					.checkbox 'disable'

			$("div.item[data-process=#{name}]")
				.addClass("dimmed")
			proc = window.RexSocket.processes.get(name)
			proc.set "pid", "NOT RUNNING"

			error proc.toJSON(), "Process #{name} has died! You should try restarting the process with the toggle to your left or by restarting the server."

		recover : () ->

	master :
		die : (word) ->
			# log "Master process is dying: #{word}"
			$("#server_down").modal 'show',
				closable : false

		recover : () ->

	event :
		exit : () ->

		exception : (err) ->
			# log "Exception sent up from server!", err

		sigterm : () ->

		sigkill : () ->

class RexSocket
	constructor: () ->
		@templates = {}
		@processes = {}
		
	init: (SocketIOInstance) ->
		@io = SocketIOInstance
		@connect()

		this

	connect: () ->
		@socket = @io.connect 'http://localhost:3009'

		@setup()

	setup: () ->
		# @compileTemplates()
		@processes = new RexProcesses

		@socket.on "connected", handlers.app.connected

		@socket.on "disconnect", handlers.app.disconnected

		@socket.on "process:start", handlers.process.start

		@socket.on "process:data", handlers.process.data

		@socket.on "process:error", handlers.process.error

		@socket.on "process:end", handlers.process.end

		@socket.on "process:die", handlers.process.die

		@socket.on "process:recover", handlers.process.recover

		@socket.on "master:die", handlers.master.die

		@socket.on "master:recover", handlers.master.recover

		@socket.on "event:exit", handlers.event.exit

		@socket.on "event:exception", handlers.event.exception

		@socket.on "event:sigterm", handlers.event.sigterm

		@socket.on "event:sigkill", handlers.event.sigkill
		

window.RexSocket = new RexSocket