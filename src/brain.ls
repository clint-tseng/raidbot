{ read-file } = require(\fs)
config = require(\config)
{ keys, values } = require(\prelude-ls)
{ get-channel, nuke, print-events, print-splash } = require('./routines')
client = new (require(\discord.js)).Client()

# load data.
(_, file) <- read-file("#__dirname/../data/events.json")
global.state = if file? then JSON.parse(file) else []

# log in and wait.
client.login(config.get(\token))
<- client.on(\ready)

# set up reactions.

# ensure initial channel status.
channel = get-channel(client)
nuke(channel)
  .then(-> print-events(channel))
  .then(-> print-splash(channel))
  .catch(console.error)

