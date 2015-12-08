d3 = require('d3')
differenceService = require('../charts/difference_service')
bulletService = require('../charts/bullet_service')
barService = require('../charts/bar_service')
module.exports =


  display: (dataAsString, $elem) ->
    value  = JSON.parse dataAsString
    if value?.data
      data = value.data
      size = value.size
    else
      data = value
      size =
        width: 960
        height: 500
    type = value.type

    $elem.addClass type
    $elem.empty()
    d3element = d3.select($elem[0])
    d3element.empty()

    switch type
      when 'difference' then differenceService.display data, size, d3element.append('svg')
      when 'bullet' then bulletService.display data, size, $elem
      when 'bar' then barService.display data, size, d3element.append('svg')