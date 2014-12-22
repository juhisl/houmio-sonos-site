WebSocket = require('ws')
request = require('request')
rsj = require('rsj')

exit = (msg) ->
  console.log msg
  process.exit 1

sitekey = process.env.HORSELIGHTS_SITEKEY || exit "HORSELIGHTS_SITEKEY not defined"

onSocketOpen = ->
  console.log "Connected to wss://houm.herokuapp.com"
  pingId = setInterval ( -> socket.ping(null, {}, false) ), 3000
  publish = JSON.stringify { command: "publish", data: { sitekey: sitekey, vendor: "sonos" } }
  socket.send(publish)
  console.log "Sent message:", publish

onSocketMessage = (s) ->
  try
    message = JSON.parse s
    console.log "Received message: %j", message
    args = message["data"]["devaddr"].split(" ")
    action = args[0]
    args.shift()
    onAction(action, args, message["data"])

onAction = (action, args, data) ->
  switch action
    when "play-or-pause"
      playlist = args.join(" ")
      playOrPause(data["on"], playlist)
    when 'set-volume' 
      setVolume(data["bri"])
    when 'yle-uutiset'
      volume = args[0]
      args.shift()
      roomName = args.join(" ")
      newsUrl(playNews, volume, roomName)
    else
      sonos(action)
    
playOrPause = (startPlaying, playlist) ->
  if (startPlaying) 
    sonos(playlist)
    sonos("shuffle/on")
  else 
    sonos("pause")
setVolume = (volume) ->
  newVolume = Math.round(100/255 * volume)
  sonos("volume/#{newVolume}")

playNews = (url, volume, roomName) ->
  encodedUri = encodeURIComponent(url)
  preset = JSON.stringify(
    {
      players: [ { roomName: roomName, volume: volume } ],
      state: "play",
      uri: encodedUri,
      playMode: "NORMAL"
    })
  sonos("preset/" + preset)

newsUrl = (play, volume, roomName) ->
  rsj.r2j('http://areena.yle.fi/api/search.rss?id=1492393&media=audio&ladattavat=1', (json) ->
    latest = JSON.parse(json)[0]
    url = latest.enclosures[0].url
    play(url, volume, roomName))

sonos = (action) ->
  console.log action
  request.get("http://localhost:5005/#{action}")

socket = new WebSocket "wss://houm.herokuapp.com"
socket.on 'open', onSocketOpen
socket.on 'close', -> exit "Websocket closed"
socket.on 'error', -> exit "Websocket error"
socket.on 'ping', -> socket.pong()
socket.on 'message', onSocketMessage
