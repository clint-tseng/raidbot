{ read-file } = require(\fs)
config = require(\config)
{ keys, values } = require(\prelude-ls)

{ get-channel, redraw-calendar, create-event, delete-event } = require('./routines')
{ create-server } = require('./http')

global.client = new (require(\discord.js)).Client()

# data operations (globals; load-state; save-state).
global.create-tokens = {}
(_, file) <- read-file("#__dirname/../data/events.json")
global.state = if file? then JSON.parse(file) else []
global.save-state = ->

# log in and wait.
client.login(config.get(\token))
<- client.on(\ready)
channel = get-channel(client)

# ensure initial channel status.
redraw-calendar(channel)

# start the http server.
create-server({ on-create: create-event(channel), on-delete: delete-event(channel) })

