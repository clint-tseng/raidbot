service = require(\express)()
{ urlencoded } = require(\body-parser)
{ find } = require(\prelude-ls)
config = require(\config)
path = require(\path)
{ DateTime } = require(\luxon)

not-found = (response) -> response.status(404).send('there is nothing here.')

create-server = ({ on-create, on-delete }) ->
  service.use(urlencoded({ extended: true }))

  service.get('/create/:token', (request, response) ->
    token = global.create-tokens[request.params.token]
    return not-found(response) unless token? and token.expires > DateTime.local()
    response.status(200).sendFile(path.resolve("#__dirname/../static/create.html"))
  )

  service.post('/create/:token', (request, response) ->
    token = global.create-tokens[request.params.token]
    return not-found(response) unless token? # don't check time this time in case they're spanning the gap.

    data = request.body
    on-create(token, (data.join is \join), {
      type: data.type
      date: DateTime.fromISO("#{data.date}T#{data.time}", { zone: data.tz }).setZone(\UTC).toISO()
      commitment: data.commitment
      notes: data.notes
    })
    response.status(200).sendFile(path.resolve("#__dirname/../static/creating.html"))
  )

  service.get('/delete/:id/confirm', (request, response) ->
    return not-found(response) unless (global.state |> find (.id is request.params.id))?
    response.status(200).sendFile(path.resolve("#__dirname/../static/confirm-delete.html"))
  )

  service.get('/delete/:id/execute', (request, response) ->
    event = global.state |> find (.id is request.params.id)
    return not-found(response) unless event?

    on-delete(event)
    response.status(200).sendFile(path.resolve("#__dirname/../static/deleting.html"))
  )

  service.listen(config.get(\port))

module.exports = { create-server }

