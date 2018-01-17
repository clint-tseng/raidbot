config = require(\config)
{ DateTime } = require(\luxon)
Discord = require(\discord.js)
{ any, filter, map, find-index, sort-by } = require(\prelude-ls)
uuid = require('uuid/v4')

types = require('./types')
{ consume, wait, retrying, in-parallel, or-else } = require('./util')


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

# generates a friendly date string for an event start.
date-for = (event) ->
  start = DateTime.fromISO(event.date)
  pacific = start.setZone('America/Los_Angeles').toFormat('EEEE d MMM, h:mm a ZZZZ')
  eastern = start.setZone('America/New_York').toFormat('h:mm a ZZZZ')
  "#pacific (#eastern)"

# creates the embed object that represents an event to discord.
embed-for = (event) ->
  rich-embed = new Discord.RichEmbed()
  rich-embed.setColor(types[event.type].color)
  rich-embed.setTitle(types[event.type].name)

  rich-embed.addField(\Starts, date-for(event), true)
  rich-embed.addField(\Commitment, "#{event.commitment} hour(s)", true) if event.commitment?
  rich-embed.addField(\Participants, event.members |> map((.nick)) |> (.join(', ')) |> or-else('(none)'))

  if event.overflow.length > 0
    rich-embed.addField(\Standby, event.overflow |> map((.nick)) |> (.join(', ')))

  if event.notes?
    rich-embed.addField(\Notes, event.notes)

  rich-embed

# prints all events in global state.
print-events = (channel) -> consume(print-event(channel), global.state |> sort-by((.date)) |> (.reverse()))
print-event = (channel, event) -->
  # send the message, return that promise, but simultaneously remember the sent
  # message (so we can edit it later) and set up interaction reactions.
  (message) <- in-parallel(channel.send(embed-for(event)))
  reset-reactions(message, '\✅', '\❎')

  # and set up reactions.
  (reaction, user) <- message.createReactionCollector()
  unless user.username is \raidbot
    reset-reactions(message, '\✅', '\❎')
    join-event(user, event, message) if reaction.emoji.name is '\✅'
    leave-event(user, event, message) if reaction.emoji.name is '\❎'

join-event = (user, event, message) ->
  # first check if the user is already joined. bail if so.
  return if any((.id is user.id), event.members ++ event.overflow)

  # now add the user to the appropriate bucket depending on event fullness.
  target = if event.members.length < types[event.type].capacity then event.members else event.overflow
  target.push({ id: user.id, nick: user.username })
  global.save-state()

  # now redraw the event, and let the user know they've joined the event.
  message.edit(embed-for(event))
  if target is event.members
    user.send("You have joined the event **#{types[event.type].name}** set for **#{date-for(event)}**. #{types[event.type].automessage}")
  else
    user.send("The event **#{types[event.type].name}** at **#{date-for(event)}** __***is full***__, but you are on the standby list. If somebody leaves, I will let you know.")

leave-event = (user, event, message) ->
  # first check if the user has not actually joined. bail if so.
  return unless any((.id is user.id), event.members ++ event.overflow)

  # remove the user from overflow if present.
  event.overflow.splice(idx, 1) if (idx = find-index((.id is user.id), event.overflow))?

  # remove the user from participants if present, and promote an overflow user if necessary.
  if (idx = find-index((.id is user.id), event.members))?
    event.members.splice(idx, 1)
    if event.overflow.length > 0
      promoted = event.overflow.shift()
      event.members.push(promoted)
      (promoted-user) <- client.fetchUser(promoted.id).then
      promoted-user.send("Congratulations! Someone has left the event **#{types[event.type].name}** and you are now in! Be ready at **#{date-for(event)}**. #{types[event.type].automessage}")

  # save, redraw the event, and let the user know.
  global.save-state()
  message.edit(embed-for(event))
  user.send("You have left the event **#{types[event.type].name}**.")

################################################################################
# SPLASH MESSAGING

# prints a basic set of instructions.
splash-message = 'Welcome to the calendar! There are no commands to learn, all scheduled events are already here. The soonest events are at the bottom, and later ones are further up. Click on :white_check_mark: to join or :negative_squared_cross_mark: to leave an event, or :star2: below to create a new one.'
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

  # create a reservation token, and send the user the link.
  token = uuid()
  global.create-tokens[token] = { id: token, expires: DateTime.local().plus({ hours: 6 }), user }
  user.send("To create a new event, follow this link (valid for 6 hours): #{config.get(\baseUrl)}/create/#token")

redraw-lock = \unlocked
redraw-calendar = (channel) ->
  if redraw-lock is \locked
    redraw-lock = \pending
  else
    redraw-lock = \locked
    nuke(channel).then(-> print-events(channel)).then(-> print-splash(channel)).then(->
      again = (redraw-lock is \pending)
      redraw-lock = \unlocked
      redraw-calendar(channel) if again
    )


################################################################################
# EVENT LIFECYCLE

create-event = (channel, token, join, event) -->
  # munge the given event slightly to tack on some details.
  event.id = uuid()
  event.members = if join is true then [{ id: token.user.id, nick: token.user.username }] else []
  event.overflow = []
  delete event.commitment unless event.commitment? and event.commitment isnt ''
  delete event.notes unless event.notes? and event.notes isnt ''

  # update and persist all relevant data.
  delete global.create-tokens[token.id]
  global.state.push(event)
  global.save-state()

  # redraw the calendar channel.
  redraw-calendar(channel)

  # and notify the user.
  create-message = "Your event **#{types[event.type].name}** for **#{date-for(event)}** has been created! If you wish to delete it, use this link: #{config.get(\baseUrl)}/delete/#{event.id}/confirm"
  token.user.send(create-message)

delete-event = (channel, event) -->
  # pull the event out from the global list; persist.
  idx = find-index((.id is event.id), global.state)
  global.state.splice(idx, 1)
  global.save-state()

  # redraw the calendar channel.
  redraw-calendar(channel)

  # and notify all joined users.
  removal-message = "The **#{types[event.type].name}** event you had joined, scheduled for #{date-for(event)}, has been cancelled."
  (event.members ++ event.overflow) |> consume((removed) -> client.fetchUser(removed.id).then((.send(removal-message))))


cull-tokens = ->
  now = DateTime.local()
  for id, { expires } of global.create-tokens when expires > now
    delete global[id]
  null

cull-events = (channel) -> ->
  # check for culling.
  line = DateTime.local().plus({ hours: 3 })
  survivors = global.state |> filter(({ date }) -> DateTime.fromISO(date) > line)
  return unless survivors.length < global.state.length

  # cull.
  global.state = survivors
  global.save-state()
  redraw-calendar(channel)

################################################################################
# EXPORTS

module.exports = { get-channel, nuke, flash-message, print-events, print-splash, redraw-calendar, create-event, delete-event, cull-tokens, cull-events }

