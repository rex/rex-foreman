#
# Assume that var io = require("socket.io") has already been called
#
log = () ->
	console.log.apply console, arguments

class RexSocket
	constructor: () ->
		
	init: (SocketIOInstance) ->
		@io = SocketIOInstance
		@connect()

	connect: () ->
		@socket = @io.connect 'http://localhost:3009'

		@setup()

	setup: () ->
		@socket.on "config", (config) ->
			log "Server sent config!", config

			$menu = $ ".menu"
			tpl = $("#process_item").html()
			template = Handlebars.compile tpl

			_.each config.procs, (proc) ->
				parts = ( proc.split ":" )
				if parts.length == 2
					renderData = 
						name : parts[0].trim()
						command : parts[1].trim()
						active : true

					if renderData.name.charAt(0) == "#"
						renderData.name = (renderData.name.substr 1).trim()
						renderData.active = false

					$menu.append template( renderData )
				else
					renderData = {}

				log "Proc: ", renderData
		

window.RexSocket = new RexSocket