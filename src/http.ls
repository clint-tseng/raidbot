service = require(\express)()
{ urlencoded } = require(\body-parser)
config = require(\config)
path = require(\path)
{ DateTime } = require(\luxon)

not-found = (response) -> response.status(404).send('there is nothing here.')
squelch = (x) -> if !x? or x is '' then undefined else x

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
      commitment: squelch(data.commitment)
    })
    response.status(200).sendFile(path.resolve("#__dirname/../static/creating.html"))
  )

  service.delete('/delete/:token', (request, response) ->
    response.status(200).sendFile(path.resolve("#__dirname/../static/delete.html"))
  )

  service.listen(config.get(\port))

module.exports = { create-server }

