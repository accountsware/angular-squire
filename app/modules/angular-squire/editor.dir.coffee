angular
    .module("angular-squire", [])
    .directive("squire", ->
        return {
            restrict: 'E'
            require: "ngModel"
            scope:
                height: '@height',
                width: '@width',
                body: '=body',
                placeholder: '@placeholder',
                editorClass: '@editorClass',
            replace: true
            transclude: true
            templateUrl: "/modules/angular-squire/editor.html"

            ### @ngInject ###
            controller: ($scope) ->
                editorVisible = true
                $scope.isEditorVisible = ->
                    return editorVisible

                $scope.editorVisibility = @editorVisibility = (vis) ->
                    if arguments.length == 1
                        editorVisible = vis
                        if vis
                            $scope.editor?.focus()
                    else
                        return editorVisible

            link: (scope, element, attrs, ngModel) ->
                editor = scope.editor = null

                LINK_DEFAULT = "http://"

                getLinkAtCursor = ->
                    return angular.element(editor.getSelection()
                        .commonAncestorContainer)
                        .closest("a")
                        .attr("href")

                scope.canRemoveLink = ->
                    href = getLinkAtCursor()
                    return href and href != LINK_DEFAULT

                scope.canAddLink = ->
                    return scope.data.link and scope.data.link != LINK_DEFAULT

                scope.data =
                    link: LINK_DEFAULT

                scope.$on('$destroy', ->
                    editor?.destroy()
                )
                scope.showPlaceholder = ->
                    return angular.element('<div>'+ngModel.$viewValue+'</div>')
                        .text().trim().length == 0  #it also gets hidden via css on focus

                scope.popoverHide = (e, name) ->
                    hide = ->
                        angular.element(e.target).closest(".popover-visible").removeClass("popover-visible")
                        scope.action(name)
                    if e.keyCode
                        hide() if e.keyCode == 13
                    else
                        hide()


                scope.popoverShow = (e) ->
                    linkElement = angular.element(e.currentTarget)

                    if angular.element(e.target).closest(".squire-popover").length
                        return
                    if linkElement.hasClass("popover-visible")
                        return

                    linkElement.addClass("popover-visible")
                    if />A\b/.test(editor.getPath()) or editor.hasFormat('A')
                        scope.data.link = getLinkAtCursor()
                    else
                        scope.data.link = LINK_DEFAULT
                    popover = element.find(".squire-popover").find("input").focus().end()
                    popover.css(left: -1 * (popover.width() / 2) + linkElement.width() / 2  + 2)
                    return

                updateModel = (value) ->
                    scope.$evalAsync(->
                        ngModel.$setViewValue(value)
                    )

                ngModel.$render = ->
                    editor.setHTML(ngModel.$viewValue || '')

                updateStylesToMatch = ->
                    doc = editor.getDocument()
                    head = doc.head

                    _.each(angular.element('link'), (el) ->
                        a = doc.createElement('link')
                        a.setAttribute('href',  el.href)
                        a.setAttribute('type',  'text/css')
                        a.setAttribute('rel',  'stylesheet')
                        head.appendChild(a)
                    )
                    doc.childNodes[0].className = "angular-squire-iframe "
                    if scope.editorClass
                        doc.childNodes[0].className += scope.editorClass


                iframe = element.find('iframe')
                menubar = element.find('.menu')

                iframeLoaded = ->
                    editor = scope.editor = new Squire(iframe[0].contentWindow.document)
                    editor.defaultBlockTag = 'P'

                    updateStylesToMatch()

                    editor.addEventListener("input", ->
                        updateModel(editor.getHTML())
                    )

                    editor.addEventListener("focus", ->
                        element.addClass('focus')
                        scope.editorVisibility(true)
                    )
                    editor.addEventListener("blur", ->
                        element.removeClass('focus')
                        updateModel(editor.getHTML())
                    )
                    editor.addEventListener("pathChange", ->
                        p = editor.getPath()
                        if />A\b/.test(p) or editor.hasFormat('A')
                            element.find('.add-link').addClass('active')
                        else
                            element.find('.add-link').removeClass('active')

                        menubar.attr("class", "menu "+p.replace(/>|\.|html|body|div/ig, ' ')
                            .toLowerCase())
                    )

                    #gimme some shortcuts
                    editor.alignRight = -> editor.setTextAlignment("right")
                    editor.alignCenter = -> editor.setTextAlignment("center")
                    editor.alignLeft = -> editor.setTextAlignment("left")
                    editor.alignJustify = -> editor.setTextAlignment("justify")

                    editor.makeHeading = ->
                        editor.setFontSize("2em")
                        editor.bold()
                if /WebKit\//.test(navigator.userAgent)
                    #chrome doesnt need to wait, and also doesnt fire
                    # the load event on iframes without a valid src
                    iframeLoaded()
                else
                    #firefox et al need to wait for the iframe to load before operating on it
                    iframe.on('load', iframeLoaded)

                Squire::testPresenceinSelection = (name, action, format, validation) ->
                    p = @getPath()
                    test = (validation.test(p) | @hasFormat(format))
                    return name is action and test


                scope.action = (action) ->
                    return unless editor

                    test =
                        value: action
                        testBold: editor.testPresenceinSelection("bold",
                            action, "B", (/>B\b/))
                        testItalic: editor.testPresenceinSelection("italic",
                            action, "I", (/>I\b/))
                        testUnderline: editor.testPresenceinSelection("underline",
                            action, "U", (/>U\b/))
                        testOrderedList: editor.testPresenceinSelection("makeOrderedList",
                            action, "OL", (/>OL\b/))
                        testUnorderedList: editor.testPresenceinSelection("makeUnorderedList",
                            action, "UL", (/>UL\b/))
                        testLink: editor.testPresenceinSelection("removeLink",
                            action, "A", (/>A\b/))
                        testQuote: editor.testPresenceinSelection("increaseQuoteLevel",
                            action, "blockquote", (/>blockquote\b/))
                        isNotValue: (a) ->
                            a is action and @value isnt ""


                    editor.removeBold()  if test.testBold
                    editor.removeItalic()  if test.testItalic
                    editor.removeUnderline()  if test.testUnderline
                    editor.removeList()  if test.testOrderedList
                    editor.removeList()  if test.testUnorderedList
                    editor.decreaseQuoteLevel()  if test.testQuote
                    if test.testLink
                        editor.removeLink()
                        editor.focus()
                    else if test.isNotValue("removeLink") then
                        # these will trigger popover, dont do anything
                    else if action == 'makeLink'
                        return unless scope.canAddLink()
                        node = angular.element(editor.getSelection().commonAncestorContainer)
                            .closest('a')[0]
                        if node
                            range = iframe[0].contentWindow.document.createRange()
                            range.selectNodeContents(node)
                            selection = iframe[0].contentWindow.getSelection()
                            selection.removeAllRanges()
                            selection.addRange(range)
                        editor.makeLink(scope.data.link, {
                            target: '_blank',
                            title: scope.data.link,
                            rel: "nofollow"
                        })
                        scope.data.link = LINK_DEFAULT
                        editor.focus()
                    else
                        editor[action]()
                        editor.focus()
        }
    ).directive("squireCover", ->
        return {
            restrict: 'E'
            replace: true
            transclude: true
            require: "^squire"
            template: """<ng-transclude ng-show="isCoverVisible()"
                             ng-click='hideCover()'
                             class="angular-squire-cover">
                         </ng-transclude>"""
            link: (scope, element, attrs, editorCtrl) ->
                showingCover = true
                scope.isCoverVisible = ->
                    return showingCover
                scope.hideCover = ->
                    showingCover = false
                    editorCtrl.editorVisibility(true)

                editorCtrl.editorVisibility(not showingCover)
                scope.$watch(->
                    editorCtrl.editorVisibility()
                , (val) ->
                    showingCover = not val
                )
        }
    ).directive("squireControls", ->
        return {
            restrict: 'E'
            scope: false
            replace: true
            transclude: true
            require: "^squire"
            template: """<ng-transclude ng-show="isControlsVisible()"
                             class="angular-squire-controls">
                         </ng-transclude>"""
            link: (scope, element, attrs, editorCtrl) ->
                scope.isControlsVisible = ->
                    return editorCtrl.editorVisibility()

        }
    )
