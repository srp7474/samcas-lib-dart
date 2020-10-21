/* MIT License
Copyright (c) <2020> <Steve Pritchard of Rexcel Systems Inc.>

Permission is hereby granted, free of charge, to any person obtaining a copy of
this software and associated documentation files (the "Software"), to deal in
the Software without restriction, including without limitation the rights to use,
copy, modify, merge, publish, distribute, sublicense, and/or sell copies of
the Software, and to permit persons to whom the Software is furnished to do so,
subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies
or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED,
INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A
PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
*/

/// The **samcas** library contains the classes to implement the samcas functionality
/// described at [samcas](../index.html).
library samcas;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import "./samwig.dart";

const _bDebLog = false; // Make true in development to t/on logging

/// format of enum fields
final RegExp reWhat = RegExp(r"[A-Za-z]+[.]((ss)|(sa)|(sg))");


/// Internal SAM Enums
enum SE {
            // ------- actions --------
            /// action: change a sym value
  sa_change,
            /// action: check box has changed value
  sa_check,
            // -------- states ---------
            /// state: initial state of model before activation
  ss_virgin,
            /// state: model is not valid. [SamModel._whyBroken] gives the reason.
  ss_broken,
}

/// Signature of action request after present formatting
typedef ActionFunc =  void Function(SamModel sm,SamReq req);
/// Signature of check request passed from widget
typedef CheckFunc  =  void Function(SamModel sm,String sym,bool value);
/// Signature of label fetch callback for dynamic callbacks
typedef LabelFunc  =  String Function(SamModel sm,Object parms);
/// Signature of focus event callback when focus changes on widget
typedef FocusFunc  =  void Function(bool hasFocus);
/// Signature of build callback used by the [SamWatch] class
typedef BuildFunc  =  Widget Function(SamBuild sb);
/// Signature of a render function
typedef RenderFunc = Widget Function(SamModel sm);

/// Pre-compiled RegExp for the log source location processing.
final RegExp exp = RegExp("/(([A-Za-z_][A-Za-z0-9_-]*)[.]dart:[0-9]+:[0-9])");

/// Used to inject a SamModel instance into the widget tree.
///
/// It creates a [SamInject] instance that manages the lifecycle events of the widget tree.
Widget samInject(SamModel sm) {
  return SamInject(sm);
}


/// The actual widget instance that is injected by [samInject]  into the widget tree.
///
/// Since it is subclassed from StatefulWidget it creates a corresponding [SamInjectable]
/// instance to handle the actual rendering determined by the state of the SamModel instance.
/// When the [SamModel] state changes the [StatefulWidget.setState] method is called to trigger
/// a re-render of the widget tree.
class SamInject extends StatefulWidget{
  final SamModel sm;
  SamInject(this.sm,{Key key}) : super(key:key);
  @override
  SamInjectable createState() => SamInjectable(sm);
}

/// The state portion of the StatefulWidget used by [SamInject] to implement a
/// StatefulWidget.
class SamInjectable extends State<SamInject> {
  SamModel sm;
  Widget _wig;
  bool bDirty = false;
  bool bAllowSignal = false; // do not allow signals till first frame build completes
  BuildContext _context;
  SamInjectable(this.sm) {
    sm._si = this;
    if (sm._samState != "${SE.ss_virgin}") throw("$sm not in ${SE.ss_virgin} state at injection point");
    sm.activate();
  }
  void _emitModelWidgets(Widget wig) {
    this._wig = wig;
  }
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {/*log("postFrame for ${this.sm} called");*/bAllowSignal = true;});
  }

  @override
  Widget build(BuildContext context) {
    //log("build ${this.sm} called");
    this._context = context;
    if (_wig == null) return buildBrokenMsg(sm._si._context,sm,sm._whyBroken);
    return _wig;
  }
}


/// Builds the [SamModel] from the [SamFactory] that has formatted the [SamAction], [SamState] and [SamView] instances.
///
/// The [SamModel.makeModel] method is called to allow the SamModel instance to be customized.
SamModel buildSamModel(SamFactory sf,SamModel sm,{SamModel parent}) {
  sm._sa = sf._sa;
  sm._ss = sf._ss;
  sm._sv = sf._sv;
  sm._parent = parent;
  if (parent != null) {
    if (parent._kids == null) parent._kids = [];
    parent._kids.add(sm);
  }
  sm._enums = sf.enums;
  sm._enumTypes = sf.enumTypes;
  sm.makeModel(sf,sm._sa,sm._ss,sm._sv);
  return sm;
}

/// The factory used to create one or more [SamModel] instances using the [SamAction], [SamState] and [SamView] instances as patterns.
///
/// The totality of the [SamAction], [SamState], [SamView] and [SamModel] is referred to as the **Sam Complex**.
///
/// The [SamFactory] is used as a base class and the [SamFactory.formatTrifecta] method is supplied that is used to format (prepare)
/// the [SamAction], [SamState] and [SamView] instances.
///
/// This **prepared** factory can be used to make one or more [SamModel] instances using tha [SamModel.makeModel] method.
///
/// The SamFactory is designed to be disposable in that at the end of the build process for a complex
/// the pointers to the [SamFactory] are nullified. This means any data in the [SamFactory] instance needed beyond building the
/// complex should be migrated to the [SamModel] (or [SamAction] if that data is shareable).
///
/// The [SamFactory] must have a companion Enum as described at [Enums](../index.html#samcas-sammodel-companion-enum).
/// This is passed in with the constructor
abstract class SamFactory {
  /// Creates SamFactory extension and associates it with [enums].
  ///
  /// The [enums] represent the valid list of states, actions and signals that
  /// the [SamModel] uses. See [Enums](../../index.html#samcas-sammodel-companion-enum).
  SamFactory(this.enums) {
    enumTypes.add(enums[0].runtimeType);
    _sa = SamAction(this);
    _ss = SamState(this);
    _sv = SamView(this);
    formatTrifecta(_sa,_ss,_sv);
    _sa.sf = null; //release to release storage
    _ss.sf = null;
    _sv.sf = null;
  }
  /// Storage for valid names associated with model
  List enums;
  /// Storage for valid types associated with model.
  ///
  /// This will be [SE] plus the companion one supplied in [new SamFactory].
  List<Type> enumTypes = [];
  /// Abstract method that must be supplied to format the [SamAction], [SamState] and [SamView] instances.
  formatTrifecta(SamAction sa, SamState ss, SamView sv);
  SamAction _sa; //= SamAction(this.enums);
  SamState  _ss; //= SamState();
  SamView   _sv; //= SamView();
}



/// The Action Part of the Complex.
///
/// This contains the [SamAction.fnMap] table that maps the possible actions or signals to
/// the function that handles them.
///
/// The key to each [SamAction.fnMap] is a [SamModel._enums] entry.
///
/// In addition the [SamAction.fnMap] table is used to map the [SamState] nap option to the processing method.
///
class SamAction {
  SamFactory sf; // only populated during formatted
  /// Construct [SamAction], add SAMCAS internal actions.
  SamAction(this.sf){
    addAction(SE.sa_change,saChange);
    addAction(SE.sa_check,saCheck);
  }
  /// the function mapping table.
  Map<String,ActionFunc> fnMap = Map();
  void applyAction(SamModel sm,SamReq req) {
    log('applyAction ${req.action}');
  }

  /// Add a list of signals that are accepted.
  ///
  /// We do not map the signal as that is determined in the parent. We record the fact that
  /// ewe accept signals belonging to a certain [Enums](../../index.html#samcas-sammodel-companion-enum) type.
  void acceptSignals(List enums) {
    sf.enumTypes.add(enums[0].runtimeType);
  }

  /// Add an action mapping it from the action code to the handler.
  ///
  /// Assert validation is performed to ensure it is valid.
  ///
  /// Dart will ensure [func] is of type [ActionFunc].
  SamAction addAction(Object smAction,ActionFunc func) {
    assert(
      ((sf.enumTypes.length > 0) && ((sf.enumTypes.firstWhere((_) => (smAction.runtimeType == _),orElse:(() => null))) != null)) ||
      (smAction.runtimeType == SE.sa_change.runtimeType)
      ,"invalid action type ${smAction.runtimeType} value $smAction");
    assert(!(smAction is String));
    assert(!fnMap.containsKey("$smAction"),"$smAction already defined in action mapping table");
    //log("addAction $smAction type ${smAction.runtimeType} ${m.enums.runtimeType} ${(m.enums as List)[0].runtimeType}");
    fnMap["$smAction"] = func;
    return this;
  }

  /// The standard change handler to change a [sym] value in the [SamHot] table.
  ///
  /// This is used by widget handlers to change values within the model.
  ///
  /// It turns on the render request for the action so that the new value can be reflected.
  ///
  /// **Note** This is used by widgets such as TextField that have already updated the
  /// display. The render does not cause a new widget build cycle unless the state changes.
  void saChange(SamModel sm,SamReq req) {
    //log("sa-change called  sym=${req.stepParms.containsKey('actMap')}");
    String sym = req.stepParms['actMap']['sym'];
    var val = req.stepParms['actMap']['value'];
    if(_bDebLog)log("sa-change called  sym=$sym val=$val");
    sm.setHot(sym,val);
    req.render = true;
  }


  /// The standard check handler to change a [sym] value in the [SamHot] table.
  ///
  /// This is used by widget handlers to change values within the model.
  ///
  /// It turns on the render request for the action so that the new value can be reflected.
  ///
  /// **Note** This is used by widgets such as Checkbox where a Widget setState is required
  /// to trigger the appropriate update as the display does not change automatically when
  /// Checkbox is clicked.
  void saCheck(SamModel sm,SamReq req) {
    //log("sa-change called  sym=${req.stepParms.containsKey('actMap')}");
    String sym = req.stepParms['actMap']['sym'];
    bool val = req.stepParms['actMap']['value'];
    State state = req.stepParms['actMap']['atSrc'];
    CheckFunc execFunc = req.stepParms['actMap']['execFunc'];
    if(_bDebLog)log("sa-change called  sym=$sym val=$val");
    sm.setHot(sym,val);
    //req.render = true;
    // ignore: invalid_use_of_protected_member
    state.setState((){});
    if (execFunc != null) execFunc(sm,sym,val);
  }

}

/// The request object used during the processing of a [SamModel.present] proposal.
///
/// The [SamReq] object is created by the [SamModel.present] method. It contains information
/// from the requestor.
///
/// In addition, defaults such as whether the render function should be activated
/// is set to defaults based on the request. These may be modified by the handlers of the request.
class SamReq {
                       /// Expected state of [SamModel]. The request is rejected if the [SamModel] state does not match.
  String expState;
                       /// A callback called if the request fails. The default is to terminate.
  Function rejector;
                       /// One of an action (*sa* prefix), state (*ss* prefix) or signal (*sg* prefix)
                       ///
                       /// Must come from the Enum related to the Model.
  Object what;
                       /// action or null for request
  String action;
                       /// state or null for request
  String state;
                       /// signal or null for request
  Object signal;
                       /// not null if request being rejected. Explains why.
  String reject;
                       /// true if request honors nap
  bool nap    = true;
                       /// true if request sends signal
  bool raise  = true;
                       /// true if request will cause render invocation
  bool render = true;
                       /// true if debug logs will be executed
  bool bLog   = false;
                       /// parameters passed in with request.
                       ///
                       /// format depends on request.
  Map  stepParms = Map();
                       /// parameters passed in with signal request.
                       ///
                       /// format depends on signal type.
  Map  signalParms;
  SamReq(this.expState,this.rejector,this.what,{bool nap,Map stepParms}) {
    if (nap != null) this.nap = nap;
    if (stepParms != null) {
      this.stepParms = stepParms;
    }
  }
}

/// Sym to value mapping table within [SamModel]
///
/// All fetching and setting of the symbolic values use this class so that the
/// fetching and setting can be easily tracked so that dependencies can be
/// readily determined.
///
/// Although the present examples make no use of it, computed values can be simulated
/// by creating a target value that is a function of one or more [sym]s in the [SamHot] table.
/// SAMCAS will automatically track the dependent variables used in computing target value.
/// When the target value is rendered it should be inside a [SamModel.watch] scope so that it is
/// refreshed when the dependent variables change in value.
class SamHot {
  Map<String,Object> _hotMap = {};
  /// return true if [SamHot] contains a key for [sym].
  bool has(String sym) => _hotMap.containsKey(sym);
  /// return the [SamHot] value for key [sym].
  Object get(String sym) => _hotMap[sym];
  /// set the [SamHot] key [sym] to [obj] value.
  void set(String sym,Object obj) {_hotMap[sym] = obj;}
  /// list all values for debugging
  String dump() {
    String s = "";
    String sep = "";
    _hotMap.forEach((String k,Object v){s += "$sep$k=$v"; sep = ",";});
    return s;
  }
}

/// The Model Part of the Complex.
///
/// It contains volatile information for the model including the [SamHot] class where watchable model values are maintained.
///
/// The related pattern instances ([SamAction], [SamState] and [SamView]) of the complex are readonly with a reference pointer from the model to them.
///
/// The [SamModel] is abstract because the implementor extends this class to incorporate customized fields and methods according
/// to the processing requirements. The design should be that even these fields should never be mutated outside of the [SamModel.present] scope
/// in order to maintain the design principles of SAM.
///
/// The [SamModel] is said to be activated once the [SamModel.activate] has been called.
abstract class SamModel {
  /// Singleton constructor used to create pattern instances
  SamModel();
  //Map<String,Function> actionLinkMap = Map();
  SamAction _sa;
  SamState  _ss;
  SamView   _sv;
  SamInjectable _si;

  /// get the parent [SamModel] or null
  SamModel  get parent => _parent;
  SamModel  _parent; // populated if parent exists

  /// The model name.
  ///
  /// For historical reasons it starts with *aaa* as this sorts first in the
  /// javascript console.log statements.
  String    aaaName = "noName";
  /// get the present State string.
  ///
  /// This will be the string value of the companion [Enums](../../index.html#samcas-sammodel-companion-enum) state value.
  String get samState => getHot("_samState");
  String    _samState = "${SE.ss_virgin}";

  RenderFunc   _prevRend;                    // used to test for render changes
  String       _whyBroken;                   // if broken why broken or null
  bool         _samBusy       = false;       // serialization lock. Assumes host is single threaded
  List<SamReq> _samQ          = List();      // list of queued preent requests
  SamHot       _hotMap        = SamHot();    // watched symbols
  List<SamBuild> _depBuilders = [];          // track builders for dependency determination
  Set<String>  _hitVars = Set();             // variables we have hit
  List         _enums;                       // Valid enum values for the companion Enum.
  List<Type>   _enumTypes;                   // Enum type associated with model. First primary, rest signals

  /// get the list of children of this [SamModel]
  List<SamModel> get kids => _kids;
  List<SamModel> _kids;


  /// The abstract method that must be populated that performs customization of the [SamModel].
  ///
  /// This occurs just before *activation* and can be used to populate values in the [SamHot]
  /// instance.
  void makeModel(covariant SamFactory sf,SamAction sa,SamState ss,SamView sv);

  /// returns the related [SamView] for the [SamModel]
  SamView view() {return _sv;}

  /// returns the current [DefState] for this [SamModel]
  DefState getDefState(String state) {return _ss.ssMap[state];}

  /// returns true if the current state of this [SamModel] is [testState]
  ///
  /// [testState] should be one of the [Enums](../../index.html#samcas-sammodel-companion-enum) *ss* values or
  /// a list of [Enums](../../index.html#samcas-sammodel-companion-enum) *ss* values.
  ///
  /// In the case of [testState] being a list, [isState] returns true when one in the matches the current state of [SamModel].
  bool isState(Object testState) {
    if (testState is List) {
      String s = "";
      testState.forEach((Object obj) {s += "/$obj";});
      return s.contains(getHot("_samState"));
    } else {
      return (getHot("_samState") == "$testState");
    }
  }

  /// Return the current [sym] value and track request for dependency determination.
  Object getHot(String sym) {
    for(SamBuild sb in _depBuilders) sb.depVars.add(sym);
    return _hotMap.get(sym);
  }

  /// Set a new [value] of [sym] in [SamHot] and record fact it changed for dependency notification.
  void setHot(String sym,Object value) {
    if (_hotMap.get(sym) != value) _hitVars.add(sym);
    _hotMap.set(sym,value);
  }

  /// return true if the [sym] has a value in the [SamHot] map.
  bool hasHot(String sym) {
    return _hotMap.has(sym);
  }

  /// list all samHot values for debugging
  String dumpSamHot() => _hotMap.dump();

  /// convenient debug representation of [SamModel]
  String toString() {return "$aaaName[$_samState]";}

  /// returns current BuildContext for [SamModel]
  ///
  /// This is only valid once the [SamModel] has been injected with method [samInject] into
  /// the widget tree.
  BuildContext getBuildContext() {
    assert(this._si != null);
    assert(this._si._context != null);
    return this._si._context;
  }

  /// Entry point for standard Form Widget actions such as a button press.
  ///
  /// It asserts there is an entry in the related [SamAction] map for the [action].
  ///
  /// For non-samcas standard actions the [SamState] definition must allow
  /// them to occur or ignore them (in which case they will be quietly discarded).
  ///
  /// If the action is valid and to be processed it presents the [action] as a proposal to [SamModel.present] along
  /// with any related parameters sent by the [action] requester.
  ///
  void actionCall(Object action,[Map actMap]) {
    if (_bDebLog) log("action call $this $action actMap=${actMap != null} ");
    assert(
    ((_enumTypes.firstWhere((_) => (action.runtimeType == _),orElse:(() => null))) != null) ||
        (action.runtimeType == SE.sa_change.runtimeType),
    "action $action not allowable type ${action.runtimeType}"
    );
    String fnStr = "$action";
    if (this._sa.fnMap.containsKey(fnStr)) {
      if (actMap == null) {
        this.present(this._samState, action);
      } else {
        this.present(this._samState,action,stepParms:{'actMap':actMap});
      }
    } else {
      if (_bDebLog) log("No action for $action in $this");
    }
  }

  /// Establish a watch scope and return a [SamWatch] widget.
  ///
  /// This is used to allow child portions of the Widget tree to be monitored
  /// so that the Widget rendering is more efficient. Any variable in [SamHot]
  /// that is read within this scope is watched for changes. If the value changes
  /// a Widget build function is triggered at this level (which will rebuild child
  /// widgets).
  ///
  /// This is useful for example in the [Rocket](../../rocket/index.html) sample application where the counter
  /// is updated.
  ///
  /// For form type widgets its requirement is variable. TextField widgets automatically update
  /// the field they represent and so it so not required. The Picker type widgets do not and therefore,
  /// if they do not cause a state change, a SamWatch may be required.
  ///
  /// The [samwig](../samwig/index.html) set of Widgets are designed and coded with this understanding in view.
  SamWatch watch(BuildFunc bf) {
    return SamWatch(bf,this);
  }

  /// Activate the [SamModel] after assert validation.
  ///
  /// It asserts that the following is true:
  ///
  /// 1. that the [SamModel] is not in the [SE.ss_broken] state.
  /// 1. that the [SamModel] is in the [SE.ss_virgin] state.
  /// 2. that at least one state has been defined in [SamState]
  /// 3. that all states in the [Enums](../../index.html#samcas-sammodel-companion-enum) have been defined.
  /// 3. that all actions in the [Enums](../../index.html#samcas-sammodel-companion-enum) have a handler
  /// 3. that all naps in the [SamState] definitions have a handler
  /// 3. that all *next*, *allow* and *ignore*  values the [SamState] definitions are valid (The compiler should also report this).
  ///
  /// It then moves the [SamModel] into the first [DefState] defined in the [SamState] by issuing a proposal
  /// to [SamModel.present] (which may execute a *nap* function).
  SamModel activate({bool bLog = false}) {
    if (_samState != "${SE.ss_virgin}") return broken("non-virgin activation prohibited");
    if (_ss.firstState == null) return broken("activation state not defined");
    if (_bDebLog) log("SamModel.activate invoked ${_ss.firstState}");
    _ss.ssMap['${SE.ss_virgin}'].next(_ss.firstState);
    //_ss.addState('${SE.ss_virgin}').next(_ss.firstState);
    // at this point all tables must be complete so we validate what we can
    String strErr = "";
    for(Object e in _enums) {
      RegExpMatch rem = reWhat.firstMatch("$e");
      if (rem == null) {
        strErr += "$e is not a correct format for the enums table\r\n";
      } else {
        String what = rem.group(1);
        bool bDefRender = _sv.svMap.containsKey("defRender");
        switch(what) {
          case "ss": if (!_ss.ssMap.containsKey("$e")) strErr += "$e not defined in state mapping table\r\n";
          if (!bDefRender && !_sv.svMap.containsKey("$e")) strErr += "$e not defined in view mapping table with no defRender\r\n";
          break;
          case "sa": if (!_sa.fnMap.containsKey("$e")) strErr += "$e not defined in action mapping table\r\n";
          break;
        }
        //log("validate $e ${e.runtimeType} $what $bDefRender");
      }
    }
    for(DefState ds in _ss.ssMap.values) {
      if (ds.strNap != null) {
        if (_sa.fnMap[ds.strNap] == null) {
          strErr += "${ds.strNap} has no processing function defined\r\n";
        } else {
          ds.fncNap = _sa.fnMap[ds.strNap];
        }
      }
      if (ds.strNext != null) {
        for(String str in ds.strNext.split("/")) {
          if (!_ss.ssMap.containsKey(str)) {
            strErr += "${ds.strState} next.$str function $str state not defined\r\n";
          }
        }
      }
      if (ds.strAllow != null) {
        for(String s in ds.strAllow.split("/")) {
          if (!_sa.fnMap.containsKey(s)) {
            strErr += "${ds.strState} allow.$s function $s not defined\r\n";
          }
        }
      }
      if (ds.strIgnore != null) {
        for(String s in ds.strIgnore.split("/")) {
          if (!_sa.fnMap.containsKey(s)) {
            strErr += "${ds.strState} ignore.$s function $s not defined\r\n";
          }
        }
      }
    }
    if (strErr.length > 0) {
      broken(strErr);
      return this;
    }
    this.present(this._samState,_ss.firstState,stepParms:{/*'bLog':true*/});
    return this;
  }

  /// return [SamModel] after jamming it into [SE.ss_broken] state with *whyBroken* set to [err].
  SamModel broken(String err) {
    log("SamModel.broken: $err");
    _samState = "ss-broken";
    _whyBroken = err;
    //this._sr.emitWidgets(this._sv.brokenMsg(_whyBroken));
    return this;
  }

  /// a shortcut to create a proposal to flip the present [SamModel.samState] to [estrState].
  ///
  /// The value of [estrState] must be a state in [Enums](../../index.html#samcas-sammodel-companion-enum).
  ///
  /// If this [SamModel.samState] is already in [estrState] the request is quietly ignored.
  void flipState(Object estrState) {
    //String strState = "$estrState";
    if (!this.isState(estrState)) this.present(this._samState,estrState); // avoids onto self
  }


  /// Present a transition proposal to this [SamModel] model.
  ///
  /// This method is the linchpin of the whole system. Thank you Jean-Jacques Dubray.
  ///
  /// The sequence of the proposal processing is shown below. If there is a failure the
  /// [rejector] method is called. The default is to mark the model as [SE.ss_broken]
  /// after populating [SamModel.whyBroken] and forcing a render cycle.
  ///
  /// 1. The request is subjected to preliminary validation and rejected if it fails.
  /// 2. A [SamReq] instance is created for the proposal.
  /// 3. If the [SamModel] is *busy* the [SamReq] is queued and an immediate return is made to the proposer.
  /// 4. The [SamModel] is marked as *busy*.
  /// 5. If the [SamModel.samState] is not [expState], reject the proposal unless it is an *action* that can be ignored.
  /// 5. The [SamModel.takeStep] method is invoked with [SamReq] as a parameter. Note that any rendering of the outcome is done within *takeStep*.
  /// 6. If the state has changed and a *nap* exists for the new state, call the *nap* function.
  /// 7. If the state has changed raise a signal or weakSignal if they exist in [DefState] and conditions are valid.
  /// 5. Turn of the *busy* flag.
  /// 6. if there are queued [SamReq]s, dequeue the first and resume at step 4.
  /// 7. return to the proposal proposer.
  ///
  /// **It is assumed this function is serialized and never entered concurrently**. This holds true for Dart if Isolates
  /// are never employed. It is left as an exercise to the reader to see how a [SamModel] can work with Isolates
  /// in play. I suspect the *signal* capability would allow signaling between isolates but it may have to be
  /// tweaked as the signal presently passes the signaller (child) reference and knows its parents reference (read memory address for reference).
  ///

  void present(Object expState,Object what,{Map stepParms,Function rejector}){
    //log("present $this what=$what? cls=${expState.runtimeType}");
    if (rejector == null) rejector = defReject;
    SamReq req;
    if (expState is SamReq) {
      req = expState; //recursive dequeue
    } else {
      //log("asserting ${what.runtimeType} $_enumType ${SE.sa_change.runtimeType}");
      assert(
      ((_enumTypes.firstWhere((_) => (what.runtimeType == _),orElse:(() => null))) != null) ||
          (what.runtimeType == SE.sa_change.runtimeType),
      "what $what not allowable type ${what.runtimeType}"
      );
      req = SamReq("$expState",rejector,what,stepParms:stepParms);//,#what:what,#stepParms:stepParms,#rejector:rejector,#nap:true,#render:true,#raise:true,#bLog:false};
      if (req.stepParms != null) {
        if (req.stepParms.containsKey('nap') && (req.stepParms['nap'] is bool)) req.nap = req.stepParms['nap'];
        if (req.stepParms.containsKey('render') && (req.stepParms['render'] is bool)) req.render = req.stepParms['render'];
        if (req.stepParms.containsKey('raise') && (req.stepParms['raise'] is bool)) req.raise = req.stepParms['raise'];
        if (req.stepParms.containsKey('bLog') && (req.stepParms['bLog'] is bool)) req.bLog = req.stepParms['bLog'];
      }
      String isWhat = reWhat.firstMatch("$what")?.group(1) ?? "??";
      //log("process $isWhat $what");
      switch(isWhat) {
        case "sa": req.action  = "$what"; break;
        case "ss": req.state   = "$what"; break;
        case "sg": req.signal  =  what;   break;
        default: req.rejector(this,req,"what $what has no sa,ss or sg prefix"); return; // should never happen as reWhat does the work
      }
    }
    if (this._samBusy) {                // ------------ queue up to simplify --------
      this._samQ.add(req);
      return;
    }
    this._samBusy = true;
    if (req.bLog) log("present $this what=${req.state}/${req.action} nap=${req.nap} r=${req.render}");

    if (this._samState != req.expState) { // ------------- validate ------------
      var bIgnore = false;
      if ((req.action != null) && this._ss.ssMap.containsKey(this._samState)) {
        this._sa.applyAction(this,req);
        //var stepObj = this.state.stepMap[this.samState];
        //if ((stepObj.ignore) && (stepObj.ignore.indexOf(stepParms.action) >= 0)) bIgnore = true;
      }
      if (!bIgnore) {
        //console.log("reject %s",req.action);
        req.rejector(this,req,"concurrency error expect=${req.expState} have=${this._samState} req=${req.what}");
      } else {
        // silently ignore
      }
    } else {                            // validated OK. apply transformation
      String oldState = this._samState;
      this._ss.takeStep(this,req);
      if (req.reject != null) {
        req.rejector(this,req,req.reject);
      } else {
        if (req.render) this._sv.render(this,req);
      }
      if (this._samState != oldState) {
        DefState ds = this._ss.ssMap[this._samState];
        if (ds == null) {
          this.broken("reached undefined ${this._samState} $this");
          return;
        }
        if ((ds.fncNap != null) && (req.nap)) {
          ds.fncNap(this,req);
        }
        //var stepObj = this.state.stepMap[this.samState];
        //if (stepObj.nap && req.nap) stepObj.nap(this,req);
        if ((ds.objSignal != null) && req.raise /*&& (this._parent != null)*/) {
          //log('raiseSignal ${ds.strSignal} build par=${this._parent}');
          raiseSignal(ds.objSignal,req);
        }
        if ((ds.objWeakSignal != null) && req.raise && (this._parent != null)) raiseSignal(ds.objWeakSignal,req);
      }
    }
    this._samBusy = false;           // --------- dequeue, process remaining queue ---
    if (req.bLog) {
      //console.log("---- present.exit %s ",this.aaaName,{sm:this,req:req});
    }
    if (this._samQ.length > 0) {
      SamReq qReq = this._samQ.removeAt(0);
      if (qReq.bLog) log("Dequeue $qReq");
      this.present(qReq,null);
    }
    //log("present.done $this what=$what? cls=${expState.runtimeType}");
  }
  /// Raise a signal to a parent [SamModel].
  ///
  /// This validate the context (parent must exist for *signal*) and the parent
  /// must be in s state where it can accept signals (it has been activated and fully renedered the first time).
  ///
  /// The signal proposal is formatted and it is presented to the parent [SamModel.present] method.
  void raiseSignal(Object signal,SamReq req) {
    if (this._parent == null) throw("Expect model $this to have parent signal=$signal");
    if (!this._parent._si.bAllowSignal) return; // half-baked parent. Ignore request.;
    Map<String,Object> stepParms = (req.signalParms != null)?req.signalParms:{};
    stepParms['src']  = this;
    this._parent.present(this._parent._samState,signal,stepParms:stepParms);
  }

  /// A shortcut to call [SamModel.present] with [expState] set to this [SamModel.samState].
  void presentNow(Object what,{Map stepParms,Function rejector}) {
    this.present(this._samState,what,stepParms:stepParms,rejector:rejector);
  }

  /// A shortcut to jam [SamModel] into [SE.ss_broken] state with *whyBroken* set to [msg].
  void defReject(SamModel sm,Map req,String msg) {
    sm.broken(msg);
  }
}

/// The [DefState] defines the properties of a particular state.
///
/// It is stored in [SamState.ssMap] and is readonly once the model is activated.
///
/// The universe of states for a [SamModel] is derived by inspecting the [SamModel._enums] variable
/// during model activation. States with no entry in [SamState.ssMap] cause the [SE.ss_broken] state to be entered.
///
/// The [DefState] is said to be *entered* when the [SamModel] transitions into this [DefState]
/// from a different [DefState].
class DefState {
  DefState(this.objState) {strState = "$objState";}

                    /// Enum value of state from companion Enum
  Object objState;
                    /// String representation of state. Has *ss* prefix.
  String strState;
                    /// Valid states this state can transition to. Null implies terminal state.
  String strNext;
                    /// What actions this state allows.
  String strAllow;
                    /// What actions this state silently ignores.
  String strIgnore;
                    /// The next action process (nap) function to execute when state entered.
                    ///
                    /// First time populates [fncNap].
  String strNap;
                    /// non-null specifies nap function to execute wnen state entered.
  Function fncNap;
                    /// signal to emit assuming there is a parent. fails if no parent.
  Object objSignal;
                    /// signal to emit if there is a parent. ignored if not.
  Object objWeakSignal;

                    /// convenient String representation of [DefState] for debugging purposes.
  @override
  String toString() {
    String s = "$strState:";
    if (strNext != null) s+= "next($strNext)";
    if (strAllow != null) s+= "next($strAllow)";
    if (strNap != null) s+= "next($strNap)";
    return s;
  }
  /// populate the allowable states this [DefState] can transition to.
  ///
  /// The [elst] is a list of valid states for this [SamModel] according to
  /// the companion [SamModel._enums] value. If only one state is
  /// permitted the list notation is not required.
  ///
  /// Allows chaining.
  DefState next(Object elst) {
    this.strNext = makeStrList(elst);
    return this;
  }
  /// populate the allowable actions this [DefState] accepts.
  ///
  /// The [elst] is a list of valid actions for this [SamModel] according to
  /// the companion [SamModel._enums] value. If only one state is
  /// permitted the list notation is not required.
  ///
  /// Allows chaining.
  DefState allow(Object elst) {
    this.strAllow = makeStrList(elst);
    return this;
  }
  /// populate the allowable actions this [DefState] ignores.
  ///
  /// The [elst] is a list of valid actions for this [SamModel] according to
  /// the companion [SamModel._enums] value. If only one state is
  /// permitted the list notation is not required.
  ///
  /// Allows chaining.
  DefState ignore(Object elst) {
    this.strIgnore = makeStrList(elst);
    return this;
  }
  /// Indicate this [DefState] has a nap function.
  ///
  /// The [SamAction] must be populated with a nap function handler.
  ///
  /// Allows chaining.
  DefState nap() {
    this.strNap = this.strState;
    return this;
  }
  /// define the signal this [DefState] emits when it is entered and if [SamModel] has a parent.
  ///
  /// Allows chaining.
  DefState weakSignal(Object estr) {
    this.objWeakSignal = estr;
    return this;
  }
  /// define the signal this [DefState] emits when it is entered.
  ///
  /// Allows chaining.
  DefState signal(Object estr) {
    this.objSignal = estr;
    return this;
  }
  /// Internal method to convert a list of values from the
  /// companion [SamModel._enums] into a string representation.
  ///
  /// Multiple values are separated by a `/` character. Validation is
  /// performed later upon [SamModel] activation.
  String makeStrList(Object elst) {
    if (elst is List) {
      String s = "";
      String sep = "";
      for(Object o in elst) {
        s += "$sep$o";
        sep = "/";
      }
      return s;
    } else {
      return "$elst";
    }
  }
}

/// The State Part of the Complex.
class SamState {
  SamFactory sf; // only populated during formatted
  Map<String,DefState> ssMap = Map();
  Object firstState;
  SamState(this.sf) {
    ssMap['${SE.ss_virgin}'] = DefState("${SE.ss_virgin}");
  }
  DefState add(DefState ds) {
    assert((ssMap[ds.strState] == null),"state ${ds.strState} already assigned it parameters");
    assert((sf.enumTypes[0] == ds.objState.runtimeType),"invalid state ${ds.objState} type ${ds.objState.runtimeType} s/b  ${sf.enumTypes[0]}");
    assert((RegExp("[.]ss").hasMatch(ds.strState)),"States are prefixed with ss value. Invalid format ${ds.objState}}");
    ssMap[ds.strState] = ds;
    if (firstState == null) firstState = ds.objState;
    return ds;
  }
  DefState addState(Object str) {
    return add(DefState(str));
  }

  void takeStep(SamModel sm,SamReq req) {
    if (req.action != null) {
      String fnAct = req.action;
      ActionFunc func = sm._sa.fnMap[fnAct];
      if (func == null) {
        sm.broken("function $fnAct not defined, cannot take ${req.action} action");
        return;
      } else {
        func(sm, req);
      }
    } else if (req.signal != null) {
      String fnAct = "${req.signal}";
      ActionFunc func = sm._sa.fnMap[fnAct];
      if (func == null) {
        sm.broken("function $fnAct not defined, cannot take ${req.signal} signal");
        return;
      } else {
        func(sm, req);
      }
    } else {
      if (_bDebLog || req.bLog) log("takeStep $sm ${req.state}");
      DefState ds = ssMap[sm._samState];
      if ((ds.strNext == null) || (ds.strNext.indexOf(req.state) < 0)) {
        sm.broken("cannot step to $ds from ${sm._samState}");
        return;
      }
      ds = ssMap[req.state];
      if (ds == null) {
        sm.broken("lost DefState for ${req.state}");
        return;
      }
      sm._samState = req.state;
      sm.setHot("_samState",sm._samState); //update potential listeners.Assumes only place we change state
    }
  }

}
/// The View Part of the Complex.
class _SamRenderList {
  //Widget _wig;
  RenderFunc _rf;
  SamModel _sm;
  bool _bPartial = false;
  _SamRenderList(this._sm,this._rf) {
   //
    //_wig = SamTree(wig,key:wig.key);
    if (_sm._prevRend != _rf) {
      if (_bDebLog) log("render state DIFFER ${_sm._samState}");
      _sm._prevRend = _rf;
    } else {
      if (_bDebLog) log("render state same ${_sm._samState}");
      _bPartial = true;
    }
  }
}

// signature to find Widget in RenderObjects
class _SamTree extends Container {
  _SamTree(Widget widget,{Key key}) : super(key:key,child:widget) ;
}


/// Builder used by [SamWatch] to build custom Widget tree.
///
/// The [SamHot] variables used by the widgets in the build tree are detected by
/// placing a marker in [SamModel._depBuilders] and using [WidgetsBinding.instance.addPostFrameCallback]
/// to determine when the build has completed.
///
/// Fortunately [WidgetsBinding.instance.addPostFrameCallback] creates a list of functions to run
/// when the builder completes so there can be many [SamBuild] instances in a single widget tree.
/// This is required because the [BuildFunc] completes before the widgets are fully rendered.
///
/// The [BuildFunc] is called to allow for the specific widgets to be rendered.
class SamBuild extends State<SamWatch> {
  Set<String> depVars;
  SamModel sm;
  BuildFunc bf;
  SamBuild(this.sm,this.bf);
  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) => {sm._depBuilders.remove(this)});
    //WidgetsBinding.instance.addPostFrameCallback((_) => {log("PostBuild1: depVars=${depVars.join("/")}")});
    depVars = Set();
    sm._depBuilders.add(this);
    Widget wig = bf(this);
    if (_bDebLog) log("SamBuild build ${wig?.runtimeType} depVars=${depVars.join("/")}");
    return wig;
  }
}
//typedef Widget SamBuilder(SamBuild sb);

/// The stateful widget used to trigger rebuilds for the [SamModel.watch] scenario.
///
/// The [BuildFunc] and [SamModel] is retained so that when a [SamHot] variable change
/// triggers the requirement for a rebuild, the setState can run with the correct context.
class SamWatch extends StatefulWidget{
  final SamModel sm;
  final BuildFunc bf;
  SamWatch(this.bf,this.sm,{Key key}) : super(key:key);
  @override
  SamBuild createState() => SamBuild(sm,bf);
}

/// The View Part of the Complex.
///
/// This contains the [SamView.svMap] table that maps the possible states into a Widget tree.
///
/// If the key *defRender* has a mapping it will be used when the [SamView.svMap] pam has
/// no key for a particular state.
///
class SamView {
  SamFactory sf; // only populated during formatted
  Map<String,RenderFunc> svMap = Map();
  SamView(this.sf);
  void addView(Object state,RenderFunc func) {
    assert(svMap["$state"] == null,"state $state already assigned to view");
    assert((state is String) || (sf.enumTypes[0] == state.runtimeType),"invalid view $state type ${state.runtimeType} s/b  ${sf.enumTypes[0]}");
    assert(!(state is String) || (state == "defRender"),"Only defRender can be a string, not $state");
    svMap["$state"] = func;
  }

  void render(SamModel sm,SamReq req) {
    _SamRenderList srl = getRender(sm,req);
    if (srl._rf != null) {
      if (!srl._bPartial) {
        Widget wig = _SamTree(srl._rf(sm));
        //_dumpWidgetTree(sm);
        sm._si._emitModelWidgets(wig);
        if (sm._si.bDirty) {
          // ignore: invalid_use_of_protected_member
          sm._si.setState(() {}); // trigger build action
        } else {
          sm._si.bDirty = true;
        }
        sm._hitVars = Set();
      } else {
        _smartUpdate(sm);
        sm._hitVars = Set();
      }
    }
  }

  void _smartUpdate(SamModel sm) {
    if (_bDebLog) log("smartUpdate $sm hasContext=${sm._si._context != null}");
    if (sm._si._context == null) return;
    Element samRoot;
    void visitor1(Element elem) {
      if (elem.widget is _SamTree) {
        samRoot = elem;
      } else {
        elem.visitChildren(visitor1);
      }
    }
    sm._si._context.visitChildElements(visitor1);
    if (samRoot != null) {
      void visitor2(Element elem) {
        Widget wig = elem.widget;
        if ((wig is SamWatch) && (elem is StatefulElement)) {
          SamBuild sb = elem.state;
          if (_bDebLog) log("smart update 3 ${elem.runtimeType} depVars=${sb.depVars?.join("/")} hitVars=${sm._hitVars?.join("/")}");
          bool bDirty = false;
          for(String sym in sm._hitVars) {
            if (sb.depVars.contains(sym)) {
              bDirty = true;
              break;
            }
          }
          // ignore: invalid_use_of_protected_member
          if (bDirty) elem.state.setState((){});
        }
        elem.visitChildren(visitor2);
      }
      samRoot.visitChildren(visitor2);
    }
  }

  /*// debugging aid
  void dumpWidgetTree(SamModel sm) {
    if (sm._si._context == null) return;
    Element samRoot;
    void visitor1(Element elem) {
      if (elem.widget is _SamTree) {
        samRoot = elem;
      } else {
        elem.visitChildren(visitor1);
      }
    }
    sm._si._context.visitChildElements(visitor1);
    if (samRoot != null) {
      void visitor2(Element elem) {
        //Widget wig = elem.widget;
        //if (wig is SamWatch) {
        //}
        elem.visitChildren(visitor2);
      }
      samRoot.visitChildren(visitor2);
    }
  }
  */


  /// returns a list that represents one or more widgets that deed to be rendered.
  _SamRenderList getRender(SamModel sm,SamReq req) {
    if (_bDebLog | req.bLog) log("render ${sm._samState}");
    if (sm._samState == "ss-broken") return _SamRenderList(sm,(sm) => brokenMsg(sm,sm._whyBroken));
    if (svMap.containsKey(sm._samState)) {
      return _SamRenderList(sm,svMap[sm._samState]);
    } else if (svMap.containsKey("defRender")) {
      return _SamRenderList(sm,svMap['defRender']);
    } else {
      return _SamRenderList(sm,(sm) => brokenMsg(sm,"state ${sm._samState} has no render view"));
    }
  }

  /// returns a Widget that displays the [SE.ss_broken] state.
  Widget brokenMsg(SamModel sm,String msg) {
    return buildBrokenMsg(sm._si._context,sm,msg);
  }

}
