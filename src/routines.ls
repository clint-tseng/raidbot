config = require(\config)
{ DateTime } = require(\luxon)
Discord = require(\discord.js)
{ values } = require(\prelude-ls)
{ consume, wait, retrying, in-parallel } = require('./util')

# get the calendar channel.
get-channel = (client) -> client.channels.find('id', config.get(\channel))

# fetch and delete all messages from the given channel.
nuke = (channel) ->
  (raw-messages) <- channel.fetchMessages().then()
  consume((.delete()), Array.from(raw-messages.values()))

# shows a message for a given time interval, then removes it.
flash-message = (channel, text, interval = 5) ->
  (message) <- channel.send(text).then()
  <- wait(interval)
  message.delete()

# prints all events in global state.
event-colors = {
  'Raid: Leviathan': '#e8a911',
  'Raid: Eater of Worlds': '#e8a911',
  'Prestige Raid: Leviathan': '#ff4220',
  'Prestige Raid: Eater of Worlds': '#ff4220',
  'Prestige Nightfall': '#a811e8',
  'Trials of the Nine': '#4693ff'
}
print-events = (channel) -> consume(print-event(channel), global.state)
print-event = (channel, event) -->
  # set up and send the event details.
  rich-embed = new Discord.RichEmbed()
  rich-embed.setTitle(event.type)
  start = DateTime.fromISO(event.date)
  eastern = start.setZone('America/New_York').toFormat('EEEE d MMM, h:mm a ZZZZ')
  pacific = start.setZone('America/Los_Angeles').toFormat('hh:mm a ZZZZ')
  rich-embed.addField(\Starts, "#eastern (#pacific)", true)
  rich-embed.addField(\Commitment, event.commitment, true) if event.commitment?
  rich-embed.addField(\Participants, event.members |> values |> (.join(', ')))
  rich-embed.setColor(event-colors[event.type])

  # send the message, return that promise, but simultaneously set up our reactions on it.
  (message) <- in-parallel(channel.send(rich-embed))
  reset-reactions(message, '\✅', '\❎')

# prints a basic set of instructions.
splash-message = 'Welcome to the calendar! The soonest events are at the bottom, and later ones are further up. Click on :white_check_mark: to join or :negative_squared_cross_mark: to leave an event, or :star2: below to create a new one.'
print-splash = (channel) ->
  (message) <- channel.send(splash-message).then()
  reset-reactions(message, '\🌟')
  (reaction, user) <- message.createReactionCollector()
  unless user.username is \raidbot
    reset-reactions(message, '\🌟')
    initiate-event(channel, user) if reaction.emoji.name is '\🌟'

# clears reactions then self-reacts with the given emote(s).
reset-reactions = (message, ...emotes) ->
  <- message.clearReactions().then()
  consume(message~react, emotes)

# sends out the relevant messages when a new event is requested.
initiate-event = (channel, user) ->
  flash-message(channel, "Hello, <@#{user.id}>. Check your private messages for further instructions.")
  user.send('testing testing')

module.exports = { get-channel, nuke, flash-message, print-events, print-splash }

