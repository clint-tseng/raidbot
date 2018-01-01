config = require(\config)
{ consume, wait, retrying } = require('./util')

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
reset-reactions = (message, emotes = []) ->
  <- message.clearReactions().then()
  message.react('\🌟')

# sends out the relevant messages when a new event is requested.
initiate-event = (channel, user) ->
  flash-message(channel, "Hello, @#{user.username}. Check your private messages for further instructions.")
  user.send('testing testing')

module.exports = { get-channel, nuke, print-splash }

