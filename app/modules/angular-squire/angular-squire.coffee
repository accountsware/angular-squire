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
                LINK_DEFAULT = "http://"
                IFRAME_CLASS = 'angular-squire-iframe'

                editor = scope.editor = null
                scope.data =
                    link: LINK_DEFAULT

                updateModel = (value) ->
                    scope.$evalAsync(->
                        ngModel.$setViewValue(value)
                        if ngModel.$isEmpty(value)
                            element.removeClass('squire-has-value')
                        else
                            element.addClass('squire-has-value')
                    )

                ngModel.$render = ->
                    editor?.setHTML(ngModel.$viewValue || '')

                ngModel.$isEmpty = (value) ->
                    if angular.isString(value)
                        return angular.element("<div>"+value+"</div>").text().trim().length == 0
                    else
                        return not value

                getLinkAtCursor = ->
                    return LINK_DEFAULT if not editor
                    return angular.element(editor.getSelection()
                        .commonAncestorContainer)
                        .closest("a")
                        .attr("href")

                scope.canRemoveLink = ->
                    href = getLinkAtCursor()
                    return href and href != LINK_DEFAULT

                scope.canAddLink = ->
                    return scope.data.link and scope.data.link != LINK_DEFAULT

                scope.$on('$destroy', ->
                    editor?.destroy()
                )
                scope.showPlaceholder = ->
                    return ngModel.$isEmpty(ngModel.$viewValue) # it also gets hidden via css on focus

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

                updateStylesToMatch = (doc) ->
                    head = doc.head
                    _.each(angular.element('link'), (el) ->
                        a = doc.createElement('link')
                        a.setAttribute('href',  el.href)
                        a.setAttribute('type',  'text/css')
                        a.setAttribute('rel',  'stylesheet')
                        head.appendChild(a)
                    )
                    doc.childNodes[0].className = IFRAME_CLASS + " "
                    if scope.editorClass
                        doc.childNodes[0].className += scope.editorClass


                iframe = element.find('iframe')
                menubar = element.find('.menu')
                haveInteraction = false

                iframeLoaded = ->
                    iframeDoc = iframe[0].contentWindow.document
                    updateStylesToMatch(iframeDoc)
                    ngModel.$setPristine()

                    editor = scope.editor = new Squire(iframeDoc)
                    editor.defaultBlockTag = 'P'

                    if scope.body
                        editor.setHTML(scope.body)
                        updateModel(scope.body)
                        haveInteraction = true

                    editor.addEventListener("input", ->
                        if haveInteraction
                            html = editor.getHTML()
                            updateModel(html)
                    )

                    editor.addEventListener("focus", ->
                        element.addClass('focus').triggerHandler('focus')
                        scope.editorVisibility(true)
                        haveInteraction = true
                    )
                    editor.addEventListener("blur", ->
                        element.removeClass('focus').triggerHandler('blur')
                        if ngModel.$pristine and not ngModel.$isEmpty(ngModel.$viewValue)
                            ngModel.$setTouched()
                        else
                            ngModel.$setPristine()
                        haveInteraction = true

                    )
                    editor.addEventListener("pathChange", ->
                        p = editor.getPath()
                        if />A\b/.test(p) or editor.hasFormat('A')
                            element.find('.add-link').addClass('active')
                        else
                            element.find('.add-link').removeClass('active')

                        menubar.attr("class", "menu "+
                            p.split("BODY")[1]?.replace(/>|\.|html|body|div/ig, ' ')
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

                ua = navigator.userAgent
                isChrome = /Chrome/.test(ua)
                isIE = /rv:11.0|IE/.test(ua)
                isFF = not isChrome and not isIE
                loaded = false
                iframe.on('load', ->
                    loaded = true
                )
                if isChrome
                    # chrome doesnt fire the load event on iframes without a valid src,
                    # and doesnt need to lazy load
                    iframeLoaded()
                else
                    element.one("mouseenter", ->
                        if isFF
                            #firefox needs to wait for the iframe to load before operating on it
                            if loaded
                                iframeLoaded()
                            else
                                iframe.on('load', iframeLoaded)
                        else
                            iframeLoaded()
                    )


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


                    if test.testBold or test.testItalic or test.testUnderline or
                    test.testOrderedList or test.testUnorderedList or test.testQuote or test.testLink
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
