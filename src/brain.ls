config = require(\config)
{ keys, values } = require(\prelude-ls)
{ get-channel, nuke, print-splash } = require('./routines')
client = new (require(\discord.js)).Client()

# log in and wait.
client.login(config.get(\token))
<- client.on(\ready)

# set up reactions.

# ensure initial channel status.
channel = get-channel(client)
nuke(channel)
  #.then(print-events)
  .then(-> print-splash(channel))
  .catch(console.error)

