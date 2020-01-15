'use strict'

import { getTag } from '../../lib/imports/tags.coffee'
import colornames from 'css-color-names'

export default colorFromThingWithTags = (thing) ->
  getTag(thing, 'color') or do ->
    hash = SHA256 thing._id
    hue = parseInt(hash.substring(0, 4), 16) % (360 - 150)
    if hue > 30
        hue += 150
    saturation = ((parseInt(hash.substring(4, 6), 16)/ 255.0) ** 0.5) * 50 + 50
    lightness = ((parseInt(hash.substring(6, 8), 16) / 255.0) ** 0.5) * 50
    "hsl(#{hue}, #{saturation}%, #{lightness}%)"

numToHex = (num) -> ('0' + num.toString 16).slice -2

canvas = document.createElement 'canvas'
[canvas.height, canvas.width] = [1, 1]
ctx = canvas.getContext '2d'

export cssColorToHex = (color) ->
  return color if /^#[0-9a-fA-F]{6}$/.test color
  if m = color.match /^#([0-9a-fA-F])([0-9a-fA-F])([0-9a-fA-F])$/
    return "##{r}#{r}#{g}#{g}#{b}#{b}" if [x, r, g, b] = m
  ctx.fillStyle = 'white'
  ctx.fillRect 0, 0, 1, 1
  ctx.fillStyle = color
  ctx.fillRect 0, 0, 1, 1
  [r, g, b, a] = ctx.getImageData(0, 0, 1, 1).data
  "##{numToHex r}#{numToHex g}#{numToHex b}"

reversecolornames = {}
for name, color of colornames
  reversecolornames[color] = name
export hexToCssColor = (hex) -> reversecolornames[hex] or hex
