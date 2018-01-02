{ read-file, write-file } = require(\fs)
config = require(\config)
{ debounce } = require(\underscore)

{ get-channel, redraw-calendar, create-event, delete-event } = require('./routines')
{ create-server } = require('./http')

global.client = new (require(\discord.js)).Client()
global.create-tokens = {}

# data operations (globals; load-state; save-state).
db-path = "#__dirname/../data/events.json"
(_, file) <- read-file(db-path)
global.state = if file? then JSON.parse(file) else []
global.save-state = debounce((-> write-file(db-path, JSON.stringify(global.state), (->))), 2500)

# log in and wait.
client.login(config.get(\token))
<- client.on(\ready)
channel = get-channel(client)

# ensure initial channel status.
redraw-calendar(channel)

# start the http server.
create-server({ on-create: create-event(channel), on-delete: delete-event(channel) })

