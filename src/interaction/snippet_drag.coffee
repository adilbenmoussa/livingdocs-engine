dom = require('./dom')
isSupported = require('../modules/feature_detection/is_supported')
config = require('../configuration/defaults')
css = config.css

module.exports = class SnippetDrag

  wiggleSpace = 0
  startAndEndOffset = 0

  constructor: ({ @snippetModel, snippetView }) ->
    @$view = snippetView.$html if snippetView
    @$highlightedContainer = {}


  # Called by DragBase
  start: ({ top, left }, event) ->
    @started = true
    @page.editableController.disableAll()
    @page.blurFocusedElement()
    @elemWindow = @page.window

    # placeholder below cursor
    @$placeholder = @createPlaceholder().css('pointer-events': 'none')
    @$dragBlocker = @page.$body.find('.dragBlocker')

    # drop marker
    @$dropMarker = $("<div class='#{ css.dropMarker }'>")

    @page.$body
      .append(@$dropMarker)
      .append(@$placeholder)
      .css('cursor', 'pointer')

    # mark dragged snippet
    @$view.addClass(css.dragged) if @$view?

    # position the placeholder
    @move({ top, left }, event)


  # Called by DragBase
  move: ({ top, left }, event) ->
    left = 2 if left < 2
    top = 2 if top < 2

    @$placeholder.css(top: "#{ top }px", left: "#{ left }px")
    @target = @findDropTarget({ top, left }, event)

    # @scrollIntoView(top, event)


  findDropTarget: ({ top, left, event }) ->
    eventPosition =
      clientX: event.clientX
      clientY: event.clientY
      pageX: event.pageX
      pageY: event.pageY

    { eventPosition, elem } = @getElemUnderCursor(eventPosition)
    return undefined unless elem?

    # return the same as last time if the cursor is above the dropMarker
    return @target if elem == @$dropMarker[0]

    coords = { left: eventPosition.pageX, top: eventPosition.pageY }
    target = dom.dropTarget(elem, coords) if elem?
    @undoMakeSpace()

    if target? && target.snippetView?.model != @snippetModel
      @$placeholder.removeClass(css.noDrop)
      @markDropPosition(target)

      # if target.containerName
      #   dom.maximizeContainerHeight(target.parent)
      #   $container = $(target.node)
      # else if target.snippetView
      #   dom.maximizeContainerHeight(target.snippetView)
      #   $container = target.snippetView.get$container()

      return target
    else
      @$dropMarker.hide()
      @removeContainerHighlight()

      if not target?
        @$placeholder.addClass(css.noDrop)
      else
        @$placeholder.removeClass(css.noDrop)

      return undefined


  markDropPosition: (target) ->
    switch target.target
      when 'snippet'
        @snippetPosition(target)
        @removeContainerHighlight()
      when 'container'
        @showMarkerAtBeginningOfContainer(target.node)
        @highlighContainer($(target.node))
      when 'root'
        @showMarkerAtBeginningOfContainer(target.node)
        @highlighContainer($(target.node))


  snippetPosition: (target) ->
    if target.position == 'before'
      before = target.snippetView.prev()

      if before?
        if before.model == @snippetModel
          target.position = 'after'
          return @snippetPosition(target)

        @showMarkerBetweenSnippets(before, target.snippetView)
      else
        @showMarkerAtBeginningOfContainer(target.snippetView.$elem[0].parentNode)
    else
      next = target.snippetView.next()
      if next?
        if next.model == @snippetModel
          target.position = 'before'
          return @snippetPosition(target)

        @showMarkerBetweenSnippets(target.snippetView, next)
      else
        @showMarkerAtEndOfContainer(target.snippetView.$elem[0].parentNode)


  showMarkerBetweenSnippets: (viewA, viewB) ->
    boxA = dom.getAbsoluteBoundingClientRect(viewA.$elem[0], @elemWindow)
    boxB = dom.getAbsoluteBoundingClientRect(viewB.$elem[0], @elemWindow)

    halfGap = if boxB.top > boxA.bottom
      (boxB.top - boxA.bottom) / 2
    else
      0

    @showMarker
      left: boxA.left
      top: boxA.bottom + halfGap
      width: boxA.width


  showMarkerAtBeginningOfContainer: (elem) ->
    return unless elem?

    @makeSpace(elem.firstChild, 'top')
    box = dom.getAbsoluteBoundingClientRect(elem, @elemWindow)
    @showMarker
      left: box.left
      top: box.top + startAndEndOffset
      width: box.width


  showMarkerAtEndOfContainer: (elem) ->
    return unless elem?

    @makeSpace(elem.lastChild, 'bottom')
    box = dom.getAbsoluteBoundingClientRect(elem, @elemWindow)
    @showMarker
      left: box.left
      top: box.bottom - startAndEndOffset
      width: box.width


  showMarker: ({ top, left, width }) ->
    if @iframeBox?
      left += @iframeBox.left
      top += @iframeBox.top

      $body = $(@iframeBox.window.document.body)
      top -= $body.scrollTop()
      left -= $body.scrollLeft()

    @$dropMarker
      .css
        left:  "#{ left }px"
        top:   "#{ top }px"
        width: "#{ width }px"
      .show()


  makeSpace: (node, position) ->
    return unless wiggleSpace && node?
    $node = $(node)
    @lastTransform = $node

    if position == 'top'
      $node.css(transform: "translate(0, #{ wiggleSpace }px)")
    else
      $node.css(transform: "translate(0, -#{ wiggleSpace }px)")


  undoMakeSpace: (node) ->
    if @lastTransform?
      @lastTransform.css(transform: '')
      @lastTransform = undefined


  highlighContainer: ($container) ->
    if $container[0] != @$highlightedContainer[0]
      @$highlightedContainer.removeClass?(css.containerHighlight)
      @$highlightedContainer = $container
      @$highlightedContainer.addClass?(css.containerHighlight)


  removeContainerHighlight: ->
    @$highlightedContainer.removeClass?(css.containerHighlight)
    @$highlightedContainer = {}


  # pageX, pageY: absolute positions (relative to the document)
  # clientX, clientY: fixed positions (relative to the viewport)
  getElemUnderCursor: (eventPosition) ->
    elem = undefined
    @unblock =>
      { clientX, clientY } = eventPosition
      elem = @page.document.elementFromPoint(clientX, clientY)
      if elem?.nodeName == 'IFRAME'
        { eventPosition, elem } = @findElemInIframe(elem, eventPosition)
        @elemWindow = @iframeBox.window
      else
        @iframeBox = undefined
        @elemWindow = @page.window

    { eventPosition, elem }


  findElemInIframe: (iframeElem, eventPosition) ->
    @iframeBox = box = iframeElem.getBoundingClientRect()
    @iframeBox.window = iframeElem.contentWindow
    document = iframeElem.contentDocument
    $body = $(document.body)

    eventPosition.clientX -= box.left
    eventPosition.clientY -= box.top
    eventPosition.pageX = eventPosition.clientX + $body.scrollLeft()
    eventPosition.pageY = eventPosition.clientY + $body.scrollTop()
    elem = document.elementFromPoint(eventPosition.clientX, eventPosition.clientY)

    { eventPosition, elem }


  # Remove elements under the cursor which could interfere
  # with document.elementFromPoint()
  unblock: (callback) ->

    # Pointer Events are a lot faster since the browser does not need
    # to repaint the whole screen. IE 9 and 10 do not support them.
    if isSupported('htmlPointerEvents')
      @$dragBlocker.css('pointer-events': 'none')
      callback()
      @$dragBlocker.css('pointer-events': 'auto')
    else
      @$dragBlocker.hide()
      @$placeholder.hide()
      callback()
      @$dragBlocker.show()
      @$placeholder.show()


  # Called by DragBase
  drop: ->
    if @target?
      @moveToTarget(@target)
      @page.snippetWasDropped.fire(@snippetModel)
    else
      #consider: maybe add a 'drop failed' effect


  # Move the snippet after a successful drop
  moveToTarget: (target) ->
    switch target.target
      when 'snippet'
        snippetView = target.snippetView
        if target.position == 'before'
          snippetView.model.before(@snippetModel)
        else
          snippetView.model.after(@snippetModel)
      when 'container'
        snippetModel = target.snippetView.model
        snippetModel.append(target.containerName, @snippetModel)
      when 'root'
        snippetTree = target.snippetTree
        snippetTree.prepend(@snippetModel)



  # Called by DragBase
  # Reset is always called after a drag ended.
  reset: ->
    if @started

      # undo DOM changes
      @undoMakeSpace()
      @removeContainerHighlight()
      @page.$body.css('cursor', '')
      @page.editableController.reenableAll()
      @$view.removeClass(css.dragged) if @$view?
      dom.restoreContainerHeight()

      # remove elements
      @$placeholder.remove()
      @$dropMarker.remove()


  createPlaceholder: ->
    numberOfDraggedElems = 1
    template = """
      <div class="#{ css.draggedPlaceholder }">
        <span class="#{ css.draggedPlaceholderCounter }">
          #{ numberOfDraggedElems }
        </span>
        Selected Item
      </div>
      """

    $placeholder = $(template)
      .css(position: "absolute")
