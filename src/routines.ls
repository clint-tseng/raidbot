config = require(\config)
{ DateTime } = require(\luxon)
Discord = require(\discord.js)
{ map } = require(\prelude-ls)

types = require('./types')
{ consume, wait, retrying, in-parallel } = require('./util')


################################################################################
# GENERAL UTIL

# get the calendar channel.
get-channel = (client) -> client.channels.find('id', config.get(\channel))

# fetch and delete all messages from the given channel.
nuke = (channel) ->
  (raw-messages) <- channel.fetchMessages().then()
  consume((.delete()), Array.from(raw-messages.values()))

# clears reactions then self-reacts with the given emote(s).
reset-reactions = (message, ...emotes) ->
  <- message.clearReactions().then()
  consume(message~react, emotes)

# shows a message for a given time interval, then removes it.
flash-message = (channel, text, interval = 5) ->
  (message) <- channel.send(text).then()
  <- wait(interval)
  message.delete()


################################################################################
# EVENT MESSAGING

# prints all events in global state.
print-events = (channel) -> consume(print-event(channel), global.state)
print-event = (channel, event) -->
  # set up and send the event details.
  rich-embed = new Discord.RichEmbed()
  rich-embed.setTitle(types[event.type].name)
  start = DateTime.fromISO(event.date)
  eastern = start.setZone('America/New_York').toFormat('EEEE d MMM, h:mm a ZZZZ')
  pacific = start.setZone('America/Los_Angeles').toFormat('hh:mm a ZZZZ')
  rich-embed.addField(\Starts, "#eastern (#pacific)", true)
  rich-embed.addField(\Commitment, event.commitment, true) if event.commitment?
  rich-embed.addField(\Participants, event.members |> map((.nick)) |> (.join(', ')))
  rich-embed.setColor(types[event.type].color)

  # send the message, return that promise, but simultaneously remember the sent
  # message (so we can edit it later) and set up interaction reactions.
  (message) <- in-parallel(channel.send(rich-embed))
  reset-reactions(message, '\✅', '\❎')

  # and set up reactions.
  (reaction, user) <- message.createReactionCollector()
  unless user.username is \raidbot
    reset-reactions(message, '\✅', '\❎')
    join-event(user, event, message) if reaction.emoji.name is '\✅'
    leave-event(user, event, message) if reaction.emoji.name is '\❎'

join-event = (user, event, message) ->
leave-event = (user, event, message) ->


################################################################################
# SPLASH MESSAGING

# prints a basic set of instructions.
splash-message = 'Welcome to the calendar! The soonest events are at the bottom, and later ones are further up. Click on :white_check_mark: to join or :negative_squared_cross_mark: to leave an event, or :star2: below to create a new one.'
print-splash = (channel) ->
  (message) <- channel.send(splash-message).then()
  reset-reactions(message, '\🌟')

  # trigger the event-creation process and reset reactions in case the user needs
  # to start it over again.
  (reaction, user) <- message.createReactionCollector()
  unless user.username is \raidbot
    reset-reactions(message, '\🌟')
    initiate-event(channel, user) if reaction.emoji.name is '\🌟'

# sends out the relevant messages when a new event is requested.
initiate-event = (channel, user) ->
  flash-message(channel, "Hello, <@#{user.id}>. Check your private messages for further instructions.")
  user.send('testing testing')


################################################################################
# EXPORTS

module.exports = { get-channel, nuke, flash-message, print-events, print-splash }

