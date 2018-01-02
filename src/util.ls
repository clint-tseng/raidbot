consume = (proc, array) ->
  | array.length => new Promise((resolve, reject) -> consume-iter(proc, array, resolve, reject))
  | otherwise => Promise.resolve()
consume-iter = (proc, [head, ...tail], resolve, reject) ->
  next = if tail.length then (-> consume-iter(proc, tail, resolve, reject)) else resolve
  proc(head).then(next, reject)

wait = (interval, f_) --> set-timeout(f_, interval * 1000)

retrying = (f_, tries = 2) -> f_().catch(-> retrying(f_, tries - 1) if tries isnt 0)

in-parallel = (promise, f) ->
  promise.then(f)
  promise

or-else = (y, x) --> if x? and x isnt '' then x else y

module.exports = { consume, wait, retrying, in-parallel, or-else }

