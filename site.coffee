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
    onDevAddr(message["data"]["devaddr"], message["data"])

onDevAddr = (action, data) ->
  switch action
    when '1' 
      playOrPause(data["on"], "Joulu 2014")
    when '2' 
      next()
    when '3' 
      setVolume(data["bri"])
    when '4' 
      volumeUp()
    when '5'
      volumeDown()
    when '6'
      news()
    
playOrPause = (startPlaying, playlist) ->
  if (startPlaying) 
    play(playlist)
  else 
    pause()
play = (playlist) ->
  sonos("favorite/#{playlist}")
  sonos("shuffle/on")
  sonos("play")
pause = -> sonos("pause")
setVolume = (volume) ->
  newVolume = Math.round(100/255 * volume)
  sonos("volume/#{newVolume}")
next = -> sonos("next")
volumeUp = -> sonos("volume/+10")
volumeDown = -> sonos("volume/-10")
news = -> newsUrl(playNews)

playNews = (url) ->
  encodedUri = encodeURIComponent(url)
  preset = JSON.stringify(
    {
      players: [ { roomName: "Living Room", volume: 25 } ],
      state: "play",
      uri: encodedUri,
      playMode: "NORMAL"
    })
  sonos("preset/" + preset)

newsUrl = (playInSonos) ->
  rsj.r2j('http://areena.yle.fi/api/search.rss?id=1492393&media=audio&ladattavat=1', (json) ->
    latest = JSON.parse(json)[0]
    url = latest.enclosures[0].url
    playInSonos(url))

sonos = (action) ->
  console.log action
  request.get("http://localhost:5005/#{action}")

socket = new WebSocket "wss://houm.herokuapp.com"
socket.on 'open', onSocketOpen
socket.on 'close', -> exit "Websocket closed"
socket.on 'error', -> exit "Websocket error"
socket.on 'ping', -> socket.pong()
socket.on 'message', onSocketMessage
