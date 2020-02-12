part of sliding_panel;

class _SlidingPanelState extends State<SlidingPanel> with TickerProviderStateMixin {
  _PanelScrollController _scrollController;
  _PanelMetadata _metadata;

  PanelController _controller;

  PanelState _oldPanelState;
  PanelState _currentPanelState;

  GlobalKey _keyHeader = GlobalKey();

  bool _toShowHeader = false;
  double _calculatedHeaderHeight = 0.0;

  GlobalKey _keyFooter = GlobalKey();

  bool _toShowFooter = false;
  double _calculatedFooterHeight = 0.0;

  GlobalKey _keyCollapsed = GlobalKey();

  GlobalKey _keyContent = GlobalKey();

  Orientation _screenOrientation;

  Color _appBarIconsColor = Colors.white;
  List<Widget> _panelContentItems = [];

  bool _shouldNotifyOnClose = true;
  bool _safeToPop = true;
  bool _shouldListenForPop = false;
  bool _isInitialBuild = true;

  // getters
  PanelHeaderWidget get header => widget.content.headerWidget;

  PanelFooterWidget get footer => widget.content.footerWidget;

  PanelCollapsedWidget get collapsed => widget.content.collapsedWidget;

  PanelSize get size => widget.size;

  PanelDecoration get decoration => widget.decoration;

  PanelAutoSizing get autoSizing => widget.autoSizing;

  bool get isModal => ((widget._isModal) && (widget._panelModalRoute != null));

  Map<PanelDraggingDirection, double> _getAllowedDraggingTill(Map<PanelDraggingDirection, double> allowedDraggingTill) {
    if ((widget.isTwoStatePanel) || (widget.snapping == PanelSnapping.disabled)) {
      return const {PanelDraggingDirection.ALLOW: 0.0};
    } else {
      if ((allowedDraggingTill == null) || (allowedDraggingTill.length == 0)) {
        return const {PanelDraggingDirection.ALLOW: 0.0};
      } else {
        if (allowedDraggingTill.containsKey(PanelDraggingDirection.UP)) {
          if (allowedDraggingTill[PanelDraggingDirection.UP] >= size.expandedHeight) {
            allowedDraggingTill.remove(PanelDraggingDirection.UP);
          }
        }
        if (allowedDraggingTill.containsKey(PanelDraggingDirection.DOWN)) {
          if (allowedDraggingTill[PanelDraggingDirection.DOWN] <= size.closedHeight) {
            allowedDraggingTill.remove(PanelDraggingDirection.DOWN);
          }
        }
        return allowedDraggingTill.length == 0 ? const {PanelDraggingDirection.ALLOW: 0.0} : allowedDraggingTill;
      }
    }
  }

  @override
  void initState() {
    super.initState();

    _panelContentItems = widget.content.panelContent;

    _metadata = _PanelMetadata(
      closedHeight: size.closedHeight,
      collapsedHeight: size.collapsedHeight,
      expandedHeight: size.expandedHeight,
      isTwoStatePanel: widget.isTwoStatePanel,
      snapping: widget.snapping,
      isDraggable: widget.isDraggable,
      isModal: isModal,
      animatedAppearing: widget.animatedAppearing,
      snappingTriggerPercentage: widget.snappingTriggerPercentage,
      dragMultiplier: widget.dragMultiplier._safeClamp(1.0, 5.0),
      initialPanelState: widget.initialState,
      allowedDraggingTill: _getAllowedDraggingTill(widget.allowedDraggingTill),
      listener: _panelHeightChangedListener,
    );

    _scrollController = _PanelScrollController(
      metadata: _metadata,
      panel: this,
    );

    _controller = PanelController().._control(this);

    if (widget.panelController == null) _controller._printError();

    widget?.panelController?._control(this);
  }

  void rebuild({VoidCallback then}) {
    if (autoSizing.headerSizeIsClosed || autoSizing.autoSizeCollapsed || autoSizing.autoSizeExpanded) {
      setState(() {});
      // refresh

      SchedulerBinding.instance.addPostFrameCallback((_) {
        _calculateHeights();

        _controller._updateDurations();
        widget?.panelController?._updateDurations();

        SchedulerBinding.instance.addPostFrameCallback(
              (_) => then?.call(),
        );
      });
    }
  }

  void jumpListViewToTop(){
    _scrollController.jumpTo(_scrollController.position.minScrollExtent);
  }

  void _calculateHeaderHeight() {
    final RenderBox boxHeader = _keyHeader?.currentContext?.findRenderObject() ?? null;

    // calculate header height
    if ((boxHeader?.size?.height ?? null) != null) {
      // header provided and size calculated.
      // so, this height has to be added to all other heights.

      final headerHeight = boxHeader.size.height;

      setState(() {
        _toShowHeader = true;

        _calculatedHeaderHeight = headerHeight;
      });
    } else {
      // no header given or size can't be determined.
      setState(() {
        _toShowHeader = false;
      });
    }
  }

  void _calculateFooterHeight() {
    final RenderBox boxFooter = _keyFooter?.currentContext?.findRenderObject() ?? null;

    // calculate footer height
    if ((boxFooter?.size?.height ?? null) != null) {
      // footer provided and size calculated.
      // so, this height has to be added to all other heights.

      final footerHeight = boxFooter.size.height;

      setState(() {
        _toShowFooter = true;

        _calculatedFooterHeight = footerHeight;
      });
    } else {
      // no footer given or size can't be determined.
      setState(() {
        _toShowFooter = false;
      });
    }
  }

  void _calculateHeights() {
    // take temporary variables.
    double _additionalHeight = 0.0;

    double _closedHeightTemp = _metadata.closedHeight;
    bool _closedHeightChanged = false;

    double _collapsedHeightTemp = _metadata.collapsedHeight;
    bool _collapsedHeightChanged = false;

    double _expandedHeightTemp = _metadata.expandedHeight;
    bool _expandedHeightChanged = false;

    // find all render boxes
    final RenderBox boxCollapsed = _keyCollapsed?.currentContext?.findRenderObject() ?? null;

    final RenderBox boxContent = _keyContent?.currentContext?.findRenderObject() ?? null;

    _calculateHeaderHeight();
    _calculateFooterHeight();
    if (_toShowHeader) {
      _additionalHeight += _calculatedHeaderHeight;
    }
    if (_toShowFooter) {
      _additionalHeight += _calculatedFooterHeight;
    }

    if (autoSizing.headerSizeIsClosed) {
      if (_closedHeightTemp < _calculatedHeaderHeight) {
        _closedHeightTemp = _calculatedHeaderHeight;
        _closedHeightChanged = true;
      }
    }

    // calculate collapsed widget height.
    if ((!_metadata.isTwoStatePanel) && (autoSizing.autoSizeCollapsed)) {
      // not for two-state panels, as they don't have this widget.

      if ((boxCollapsed?.size?.height ?? null) != null) {
        // collapsedWidget provided and size calculated.

        final colHeight = boxCollapsed.size.height;

        if (colHeight < _metadata.constrainedHeight) {
          // if it is less than screen's height.
          setState(() {
            if (_toShowHeader) {
              // add header height to collapsedHeight.
              _collapsedHeightTemp = colHeight + _additionalHeight;

              if (_additionalHeight > _collapsedHeightTemp) {
                // this should not happen.
                _collapsedHeightTemp = _additionalHeight;
              }
            } else {
              _collapsedHeightTemp = colHeight;
            }
            _collapsedHeightChanged = true;
          });
        }
      }
    }

    // calculate panel height
    if (((boxContent?.size?.height ?? null) != null) && (autoSizing.autoSizeExpanded)) {
      // panelContent provided and size calculated.

      final expHeight = boxContent.size.height;

      setState(() {
        if (expHeight < _collapsedHeightTemp) {
          // collapsedHeight is more than expanded, so add it to expandedHeight.
          // !!! this is not an ideal condition.

          if (_toShowHeader) {
            // set expanded in a manner that,
            // it should be less than screen height (otherwise, it should
            // be of screen's height).
            // and maximum of (it's actual height + header height) and
            // (collapsedHeight (which also includes header height))

            _expandedHeightTemp =
                min(_metadata.constrainedHeight, max(expHeight + _additionalHeight, _collapsedHeightTemp));
          } else {
            // set expanded to collapsed.
            _expandedHeightTemp = _collapsedHeightTemp;
          }
        } else {
          // select minimum of screen height / boxHeight including header & footer.
          _expandedHeightTemp = min(expHeight + _additionalHeight, _metadata.constrainedHeight);
        }
        _expandedHeightChanged = true;
      });
    }

    setState(() {
      if (_closedHeightChanged) {
        _metadata.closedHeight = _closedHeightTemp / _metadata.constrainedHeight;
      }

      if (_collapsedHeightChanged) {
        _metadata.collapsedHeight = _collapsedHeightTemp / _metadata.constrainedHeight;
      }

      if (_expandedHeightChanged) {
        if (_expandedHeightTemp > _metadata.constrainedHeight) {
          _expandedHeightTemp = _metadata.constrainedHeight;
        }

        if ((autoSizing.useMinExpanded) &&
            (_metadata.providedExpandedHeight != null) &&
            (_metadata.providedExpandedHeight > 0.0 && _metadata.providedExpandedHeight <= 1.0)) {
          double _height = min((_expandedHeightTemp / _metadata.constrainedHeight), _metadata.providedExpandedHeight);
          _metadata.expandedHeight = _height.isFinite ? _height : 0.0;
        } else {
          double _height = _expandedHeightTemp / _metadata.constrainedHeight;
          _metadata.expandedHeight = _height.isFinite ? _height : 0.0;
        }
      }
    });
  }

  void _panelHeightChangedListener() {
    if (mounted) setState(() {});

    widget?.onPanelSlide?.call(_metadata.currentHeight);

    _currentPanelState = _controller.currentState;

    if (_currentPanelState != _oldPanelState) {
      _oldPanelState = _currentPanelState;

      if (widget.onPanelStateChanged != null) {
        widget.onPanelStateChanged(_currentPanelState);
      }

      if ((_currentPanelState == PanelState.closed) && (widget.panelClosedOptions.detachDragging)) {
        if (widget.panelClosedOptions.resetScrolling)
          _scrollController.animateTo(0.0, duration: widget.duration, curve: widget.curve);

        if (_shouldNotifyOnClose) {
          if (widget.panelClosedOptions.sendResult != null)
            _controller.sendResult(result: widget.panelClosedOptions.sendResult);

          if (widget.panelClosedOptions.throwResult != null)
            _controller.throwResult(result: widget.panelClosedOptions.throwResult);
        }
        _shouldNotifyOnClose = true;
      }

      if (isModal && _shouldListenForPop) {
        // showModalSlidingPanel()
        if (_metadata.currentHeight == 0.0) {
          // panel really hidden (dismissed, or closed with 0.0)
          if (_safeToPop && Navigator.of(context).canPop()) {
            // canPop() used to ensure that the root route doesn't get popped.
            Navigator.of(context).pop();
          }
          _safeToPop = true;
        }
      }
    }
  }

  // temporary panel height listener that only calls setState()
  void _tempListener() {
    if (mounted) setState(() {});
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    _appBarIconsColor = (header.decoration.backgroundColor ?? Theme.of(context).canvasColor).computeLuminance() > 0.5
        ? Colors.black
        : Colors.white;

    final MediaQueryData queryData = MediaQuery.of(context);

    if (queryData.orientation != _screenOrientation) {
      // resolution / orientation changed

      _screenOrientation = queryData.orientation;

      double previousPosition = _controller.percentPosition(0.0, _metadata.expandedHeight);
      // panel may also be dismissed, thats why 0.0

      if (autoSizing.headerSizeIsClosed || autoSizing.autoSizeCollapsed || autoSizing.autoSizeExpanded) {
        SchedulerBinding.instance.addPostFrameCallback((x) {
          _calculateHeights();

          // update durations again
          _controller._updateDurations();
          widget?.panelController?._updateDurations();

          if (_isInitialBuild) {
            _isInitialBuild = false;

            _metadata._setInitialStateAgain();
            // set initial state, initially...
          } else {
            double nextPosition = _controller.getPercentToPanelPosition(previousPosition, forDismissed: true);

            _setPanelPosition(this,
                to: nextPosition,
                duration: _controller._getDuration(from: _metadata.currentHeight, to: nextPosition),
                shouldClamp: false);
          }
        });
      } else {
        SchedulerBinding.instance.addPostFrameCallback((x) {
          _calculateHeaderHeight();
          _calculateFooterHeight();

          // update durations again
          _controller._updateDurations();
          widget?.panelController?._updateDurations();

          if (_isInitialBuild) {
            _isInitialBuild = false;

            _metadata._setInitialStateAgain();
            // set initial state, initially...
          } else {
            double nextPosition = _controller.getPercentToPanelPosition(previousPosition, forDismissed: true);

            _setPanelPosition(this,
                to: nextPosition,
                duration: _controller._getDuration(from: _metadata.currentHeight, to: nextPosition),
                shouldClamp: false);
          }
        });
      }

      if (isModal) {
        // if the panel is a modal
        // i.e., from showModalSlidingPanel()

        SchedulerBinding.instance.addPostFrameCallback((_) async {
          if (mounted) {
            // decide the state in which the panel will open
            InitialPanelState decidedState = _decideInitStateForModal(metadata: _metadata);

            // animate the panel, wait for it
            switch (decidedState) {
              case InitialPanelState.dismissed:
                await _controller.expand();
                break;
              case InitialPanelState.closed:
                await _controller.close();
                break;
              case InitialPanelState.collapsed:
                await _controller.collapse();
                break;
              case InitialPanelState.expanded:
                await _controller.expand();
                break;
            }

            // start listening for panel changes
            _shouldListenForPop = true;

            widget._panelModalRoute.popped.then((_) {
              _safeToPop = false;
              // popped by parent, dismiss the panel
              if (mounted) _controller.dismiss();
            });
          }
        });
      } else {
        if (_metadata.animatedAppearing) {
          // animate the appearing of the panel
          // we need to prevent height listener from listening, otherwise
          // it would throw state changes to its listeners...
          SchedulerBinding.instance.addPostFrameCallback((_) async {
            // remove original listener
            _metadata._removeHeightListener(_panelHeightChangedListener);

            // add temporary listener
            _metadata._addHeightListener(_tempListener);

            // animate
            // animate the panel, wait for it
            switch (widget.initialState) {
              case InitialPanelState.dismissed:
                await _controller.dismiss();
                break;
              case InitialPanelState.closed:
                await _controller.close();
                break;
              case InitialPanelState.collapsed:
                if (_metadata.isTwoStatePanel)
                  await _controller.expand();
                else
                  await _controller.collapse();
                break;
              case InitialPanelState.expanded:
                await _controller.expand();
                break;
            }

            // remove temporary listener
            _metadata._removeHeightListener(_tempListener);

            // back to original
            _metadata._addHeightListener(_panelHeightChangedListener);
          });
        }
      }
    }
  }

  @override
  void didUpdateWidget(SlidingPanel oldWidget) {
    super.didUpdateWidget(oldWidget);

    _appBarIconsColor = (header.decoration.backgroundColor ?? Theme.of(context).canvasColor).computeLuminance() > 0.5
        ? Colors.black
        : Colors.white;

    _panelContentItems = widget.content.panelContent;

    if (autoSizing.useMinExpanded && _metadata.providedExpandedHeight != size.expandedHeight) {
      _metadata.providedExpandedHeight = size.expandedHeight;
      rebuild();
    }

    if (oldWidget.snapping != widget.snapping) {
      _metadata.snapping = widget.snapping;
    }

    if (oldWidget.isDraggable != widget.isDraggable) {
      _metadata.isDraggable = widget.isDraggable;
    }

    if (oldWidget.snappingTriggerPercentage != widget.snappingTriggerPercentage) {
      _metadata.snappingTriggerPercentage = widget.snappingTriggerPercentage;
    }

    if (oldWidget.duration != widget.duration) {
      _controller._updateDurations();
      widget?.panelController?._updateDurations();
    }

    if (oldWidget.dragMultiplier != widget.dragMultiplier) {
      _metadata.dragMultiplier = widget.dragMultiplier._safeClamp(1.0, 5.0);
    }

    if (oldWidget.isTwoStatePanel != widget.isTwoStatePanel) {
      if ((widget.isTwoStatePanel) && (_metadata.isCollapsed)) {
        _controller.expand();
      }
      _metadata.isTwoStatePanel = widget.isTwoStatePanel;
    }

    if ((!autoSizing.headerSizeIsClosed) && (!autoSizing.autoSizeCollapsed) && (!autoSizing.autoSizeExpanded)) {
      // no auto sizing is applied
      if (oldWidget.size.closedHeight != size.closedHeight) {
        if (_metadata.currentHeight < size.closedHeight) {
          // if current height of panel is less than new height
          // animate then set

          _controller.setAnimatedPanelPosition(size.closedHeight).then((_) {
            _metadata.closedHeight = size.closedHeight;
          });
        } else if ((_metadata.currentHeight > size.closedHeight) && (_metadata.isClosed)) {
          // if current height of panel is more than new height and panel is closed
          // set then animate

          _metadata.closedHeight = size.closedHeight;
          _controller.setAnimatedPanelPosition(size.closedHeight);
        } else {
          // just close the panel and set new value
          // set then animate

          _metadata.closedHeight = size.closedHeight;
          if ((!_metadata.isExpanded) && (!_metadata.isCollapsed)) {
            // if panel is neither collapsed nor expanded
            _controller.setAnimatedPanelPosition(size.closedHeight);
          }
        }
      }

      if (oldWidget.size.collapsedHeight != size.collapsedHeight) {
        if ((_metadata.currentHeight < size.collapsedHeight) && (!_metadata.isClosed)) {
          // if current height of panel is less than new height and panel is not closed
          // animate then set

          _controller.setAnimatedPanelPosition(size.collapsedHeight).then((_) {
            _metadata.collapsedHeight = size.collapsedHeight;
          });
        } else if ((_metadata.currentHeight > size.collapsedHeight) && (_metadata.isCollapsed)) {
          // if current height of panel is more than new height and panel is collapsed
          // set then animate

          _metadata.collapsedHeight = size.collapsedHeight;
          _controller.setAnimatedPanelPosition(size.collapsedHeight);
        } else {
          // set new value
          _metadata.collapsedHeight = size.collapsedHeight;
          if ((!_metadata.isExpanded) && (!_metadata.isClosed)) {
            // if panel is neither closed nor expanded
            _controller.setAnimatedPanelPosition(size.collapsedHeight);
          }
        }
      }

      if (oldWidget.size.expandedHeight != size.expandedHeight) {
        if ((_metadata.currentHeight < size.expandedHeight) && _metadata.isExpanded) {
          // if current height of panel is less than new height and panel is expanded
          // set then animate

          _metadata.expandedHeight = size.expandedHeight;
          _controller.setAnimatedPanelPosition(size.expandedHeight);
        } else if (_metadata.currentHeight > size.expandedHeight) {
          // if current height of panel is more than new height
          // animate then set

          _controller.setAnimatedPanelPosition(size.expandedHeight).then((_) {
            _metadata.expandedHeight = size.expandedHeight;
          });
        } else {
          // set new value
          _metadata.expandedHeight = size.expandedHeight;
          if ((!_metadata.isCollapsed) && (!_metadata.isClosed)) {
            // if panel is neither closed nor collapsed
            _controller.setAnimatedPanelPosition(size.expandedHeight);
          }
        }
      }
    }

    Map<PanelDraggingDirection, double> allowedDraggingTill = _getAllowedDraggingTill(widget.allowedDraggingTill);

    if (!(MapEquality().equals(oldWidget.allowedDraggingTill, allowedDraggingTill))) {
      _metadata.allowedDraggingTill = allowedDraggingTill;
    }

    // when something changes, calculate durations again
    _controller._updateDurations();
    widget?.panelController?._updateDurations();
  }

  @override
  void dispose() {
    _scrollController?.dispose();
    _PanelAnimation.clear();
    super.dispose();
  }

  Widget get _headerSliver => SlidingPanelSliverAppBar(
    title: Material(
      type: MaterialType.transparency,
      child: GestureDetector(
        onTap: () => header?.onTap?.call(),
        child: Container(
          key: _keyHeader,
          decoration: BoxDecoration(
            border: header.decoration.border,
            borderRadius: header.decoration.borderRadius,
            color: header.decoration.backgroundColor ?? Theme.of(context).canvasColor,
          ),
          padding: header.decoration.padding,
          margin: header.decoration.margin,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              header?.options?.leading ?? Container(),
              Expanded (
                child: header.headerContent,
              ),
            ],),
        ),
      ),
    ),
    shape: (header.decoration.borderRadius != null)
        ? RoundedRectangleBorder(borderRadius: header.decoration.borderRadius)
        : null,
    titleSpacing: 0,
    backgroundColor: header.decoration.backgroundColor ?? Theme.of(context).canvasColor,
    iconTheme: IconThemeData(color: _appBarIconsColor),
    automaticallyImplyLeading: false,
    titleHeight: _calculatedHeaderHeight,
    stretch: false,
    flexibleSpace: null,
    bottom: null,
    actionsIconTheme: null,
    expandedHeight: null,
    //
    primary: header.options.primary,
    centerTitle: header.options.centerTitle,
    elevation: header.options.elevation,
    forceElevated: header.options.forceElevated,
    pinned: header.options.alwaysOnTop,
    floating: header.options.floating,
    snap: header.options.floating,
    leading: null,
    actions: [
      for (var action in header?.options?.trailing ?? [])
        Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: header.options.iconsAlignment,
          children: <Widget>[Flexible(child: action)],
        ),
    ],
  );

  Widget get _collapsedWidget {
    double collapsedHeight = 0.0;
    if (collapsed.hideInExpandedOnly)
      collapsedHeight = _metadata.collapsedHeight * _metadata.constrainedHeight;
    else
      collapsedHeight = _metadata.closedHeight * _metadata.constrainedHeight;

    return Positioned(
      top: _calculatedHeaderHeight,
      width: _metadata.constrainedWidth -
          (decoration.margin == null ? 0 : decoration.margin.horizontal) -
          (decoration.padding == null ? 0 : decoration.padding.horizontal),
      child: Container(
        child: GestureDetector(
          onVerticalDragUpdate: (details) => _dragPanel(
            this,
            delta: details.primaryDelta,
            shouldListScroll: false,
            isGesture: true,
            dragFromBody: widget.backdropConfig.dragFromBody,
            scrollContentSuper: () {},
          ),
          onVerticalDragEnd: (details) => _onPanelDragEnd(this, -details.primaryVelocity),
          child: Container(
            height: collapsedHeight,
            child: Opacity(
              opacity: _getCollapsedOpacity(this),
              child: IgnorePointer(
                ignoring: collapsed.hideInExpandedOnly ? _metadata.isExpanded : _metadata.isCollapsed,
                child: collapsed.collapsedContent ?? Container(),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget get _footerWidget {
    double currentPixels = _metadata.currentHeight * _metadata.totalHeight;
    double totalSubFooter = _metadata.expandedHeight * _metadata.totalHeight - _calculatedFooterHeight;

    double footerHeight = max(currentPixels - totalSubFooter, 0.0);

    return GestureDetector(
      onVerticalDragUpdate: (details) => _dragPanel(
        this,
        delta: details.primaryDelta,
        shouldListScroll: false,
        isGesture: true,
        dragFromBody: widget.backdropConfig.dragFromBody,
        scrollContentSuper: () {},
      ),
      onVerticalDragEnd: (details) => _onPanelDragEnd(this, -details.primaryVelocity),
      child: Container(
          decoration: BoxDecoration(
            border: footer.decoration.border,
            borderRadius: footer.decoration.borderRadius,
            boxShadow: footer.decoration.boxShadows,
            color: footer.decoration.backgroundColor ?? Theme.of(context).canvasColor,
          ),
          padding: footer.decoration.padding,
          margin: footer.decoration.margin,
          height: footerHeight,
          child: footer.footerContent),
    );
  }

  Widget get _mainPanel {
    return Stack(
      alignment: Alignment.bottomCenter,
      children: <Widget>[
        Material(
          type: MaterialType.transparency,
          child: CustomScrollView(
            controller: _scrollController,
            slivers: <Widget>[
              // header
              if (header.headerContent != null)
                _headerSliver,

              // panel
              SliverOpacity(
                opacity: _getPanelOpacity(this),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    ..._panelContentItems,
                    SizedBox(
                      height: _calculatedFooterHeight,
                      // add footer's height, margin already included
                    ),
                  ]),
                ),
              ),
            ],
          ),
        ),

        // collapsedContent
        if (!_metadata.isTwoStatePanel)
          _collapsedWidget,

        // footer
        if (footer.footerContent != null)
          _footerWidget,
      ],
    );
  }

  Widget get _offStagedFooter => Offstage(
    child: Container(
      key: _keyFooter,
      margin: footer.decoration.margin,
      padding: footer.decoration.padding,
      decoration: BoxDecoration(
        border: footer.decoration.border,
      ),
      child: Container(
        child: footer.footerContent,
      ),
    ),
  );

  Widget get _offStagedContent => Offstage(
    child: Container(
      key: _keyContent,
//          margin: decoration.margin,
//          padding: decoration.padding,
      decoration: BoxDecoration(border: decoration.border),
      child: ListView(
        shrinkWrap: true,
        children: [
          ..._panelContentItems,
          SizedBox(
            // also add footer's margin, NOT padding
            height: (footer?.decoration?.margin?.vertical ?? 0),
          )
        ],
      ),
    ),
  );

  Widget get _offStagedCollapsed => Offstage(
    child: Container(
      key: _keyCollapsed,
      child: collapsed.collapsedContent,
    ),
  );

  Widget get _backdropShadow => GestureDetector(
    onVerticalDragUpdate: (details) => _dragPanel(
      this,
      delta: details.primaryDelta,
      shouldListScroll: false,
      isGesture: true,
      dragFromBody: widget.backdropConfig.dragFromBody,
      scrollContentSuper: () {},
    ),
    onVerticalDragEnd: (details) => _onPanelDragEnd(this, -details.primaryVelocity),
    onTap: () => _handleBackdropTap(this),
    child: Opacity(
      opacity: _getBackdropOpacityAmount(this),
      child: Container(
        height: _metadata.constrainedHeight,
        width: _metadata.constrainedWidth,
        // setting color null enables Gesture recognition when collapsed / closed
        color: _getBackdropColor(this),
      ),
    ),
  );

  Widget get _panelContent => Container(
    constraints: BoxConstraints(
      maxWidth: _screenOrientation == Orientation.portrait ? widget.maxWidth.portrait : widget.maxWidth.landscape,
    ),
    padding: decoration.padding,
    margin: decoration.margin,
    height: _metadata.currentHeight * _metadata.constrainedHeight,
    decoration: widget.renderPanelBackground
        ? BoxDecoration(
      border: decoration.border,
      borderRadius: decoration.borderRadius,
      boxShadow: decoration.boxShadows,
      color: decoration.backgroundColor ?? Theme.of(context).canvasColor,
    )
        : null,
    child: _mainPanel,
  );

  Widget get _body {
    return Stack(
      alignment: Alignment.bottomCenter,
      children: <Widget>[
        // for calculating the size.

        if (footer.footerContent != null)
          _offStagedFooter,
        // needed as we change footer's height

        Container(child: _offStagedContent),
        // needed becuase of sliver

        if ((!_metadata.isTwoStatePanel) && (collapsed.collapsedContent != null))
          _offStagedCollapsed,
        // needed as we change collapsedWidget's height

        // the body part
        if (widget.content.bodyContent != null)
          Positioned.fill(top: _getParallaxSlideAmount(this), child: widget.content.bodyContent),

        if (widget.backdropConfig.enabled)
          _backdropShadow
        else
          Container(),

        _panelContent,
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () => _decidePop(this),
      child: LayoutBuilder(
        builder: (context, BoxConstraints constraints) {
          _metadata.totalHeight = _metadata.expandedHeight * constraints.biggest.height;

          _metadata.constrainedHeight = constraints.biggest.height;
          _metadata.constrainedWidth = constraints.biggest.width;

          return _body;
        },
      ),
    );
  }
}
