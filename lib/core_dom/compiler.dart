part of angular.core.dom;

@NgInjectableService()
class Compiler {
  final Profiler _perf;
  final Parser _parser;
  final Expando _expando;

  Compiler(this._perf, this._parser, this._expando);

  List<ElementBinder> _compileView(NodeCursor domCursor, NodeCursor templateCursor,
                ElementBinder useExistingElementBinder,
                DirectiveMap directives) {
    if (domCursor.nodeList().length == 0) return null;

    List<ElementBinder> elementBinders = null; // don't pre-create to create sparse tree and prevent GC pressure.

    do {
      ElementBinder declaredElementSelector = useExistingElementBinder == null
          ?  directives.selector(domCursor.nodeList()[0])
          : useExistingElementBinder;

      declaredElementSelector.offsetIndex = templateCursor.index;

      // TODO: move to ElementBinder
      var compileTransclusionCallback = (ElementBinder transclusionBinder) {
        DirectiveRef directiveRef = declaredElementSelector.template;
        return compileTransclusion(
            domCursor, templateCursor,
            directiveRef, transclusionBinder, directives);
      };

      var compileChildrenCallback = () {
        var childDirectivePositions = null;
        if (domCursor.descend()) {
          templateCursor.descend();

          childDirectivePositions =
            _compileView(domCursor, templateCursor, null, directives);

          domCursor.ascend();
          templateCursor.ascend();
        }
        return childDirectivePositions;
      };

      declaredElementSelector.walkDOM(compileTransclusionCallback, compileChildrenCallback);

      if (elementBinders == null) elementBinders = [];

      if (declaredElementSelector.isUseful()) {
        elementBinders.add(declaredElementSelector);
      }
    } while (templateCursor.microNext() && domCursor.microNext());

    return elementBinders;
  }

  ViewFactory compileTransclusion(
                      NodeCursor domCursor, NodeCursor templateCursor,
                      DirectiveRef directiveRef,
                      ElementBinder transcludedElementBinder,
                      DirectiveMap directives) {
    var anchorName = directiveRef.annotation.selector + (directiveRef.value != null ? '=' + directiveRef.value : '');
    var viewFactory;
    var views;

    var transcludeCursor = templateCursor.replaceWithAnchor(anchorName);
    var domCursorIndex = domCursor.index;
    var directivePositions =
        _compileView(domCursor, transcludeCursor, transcludedElementBinder, directives);
    if (directivePositions == null) directivePositions = [];

    viewFactory = new ViewFactory(transcludeCursor.elements, directivePositions, _perf, _expando);
    domCursor.index = domCursorIndex;

    if (domCursor.isInstance()) {
      domCursor.insertAnchorBefore(anchorName);
      views = [viewFactory(domCursor.nodeList())];
      domCursor.macroNext();
      templateCursor.macroNext();
      while (domCursor.isValid() && domCursor.isInstance()) {
        views.add(viewFactory(domCursor.nodeList()));
        domCursor.macroNext();
        templateCursor.remove();
      }
    } else {
      domCursor.replaceWithAnchor(anchorName);
    }

    return viewFactory;
  }

  ViewFactory call(List<dom.Node> elements, DirectiveMap directives) {
    var timerId;
    assert((timerId = _perf.startTimer('ng.compile', _html(elements))) != false);
    List<dom.Node> domElements = elements;
    List<dom.Node> templateElements = cloneElements(domElements);
    var elementBinders = _compileView(
        new NodeCursor(domElements), new NodeCursor(templateElements),
        null, directives);

    var viewFactory = new ViewFactory(templateElements,
        elementBinders == null ? [] : elementBinders, _perf, _expando);

    assert(_perf.stopTimer(timerId) != false);
    return viewFactory;
  }



}

