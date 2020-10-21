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

/// The **samwig** library contains the classes and methods that build the widgets that interface with the
/// [samcas](../index.html) library.
///
/// The supplied widgets adapt based on the host platform and rely  on [PlatformProvider] being at the
/// root of the widget tree.
///
/// Note that it is not mandatory to use these, you can write your own as as long as the following protocols are adopted. Namely:
///
/// 1. Do not update [SamModel] directly. Instead, call [SamModel.present] with a proposal for a change using
/// [SE.sa_change] or some *action* you may write.
/// 2. The [WidgetsBinding.instance.addPostFrameCallback] callback is often useful to do post render processing.
///
library samwig;

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';
//import 'package:url_launcher/url_launcher.dart';
//import 'package:package_info/package_info.dart';
import 'package:flutter/gestures.dart';
import 'dart:developer' as dev;
import "samcas.dart";

/// Builds a broken message alert when a [SamModel] renders and is broken.
///
/// This is written as an Alert so it covers what is underneath.
Widget buildBrokenMsg (BuildContext context,SamModel sm,String brokenMsg) {
  return AlertDialog(
      title: Row(children:[
        const Text('Model '),
        Text('${sm.aaaName}',style:TextStyle(fontStyle:FontStyle.italic)),
        Text(' Broken'),
        Spacer(),
        FlatButton(
          onPressed: () {Navigator.of(context).pop();},
          textColor: Colors.black, child: const Text('X',style:TextStyle(fontSize:20,fontWeight:FontWeight.bold)),
        ),
        ]),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
             Text(brokenMsg,style:TextStyle(color:Colors.red,decoration:TextDecoration.lineThrough)),
        ],
      ),
  );
}

/// Return a choice of one value out of a given list.
///
/// The list is presented as a dialog and the user clicks on the item label and the [item] of type [T] is returned.
///
/// The [context] is used by the *showDialog* to give it context. It will switch between *Material* and *Cupertino* mode
/// based on the host platform.
///
/// The dialog is given the title [title] and shows the [labels]. When one is clicked the [item] at the appropriate index
/// of [items] is returned.
///
/// If the user closes the dialog with selecting a choice a value of `null` is returned.
Future<T> getChoiceValue<T>(BuildContext context,{@required String title,@required List<String>labels,@required List<T> values}) async {
  assert(labels.length == values.length);
  if (isMaterial(context)) {
    List<SimpleDialogOption>  list = [];
    for(int i=0;i < labels.length;i++) {
      list.add(SimpleDialogOption(onPressed:() {Navigator.pop(context,values[i]);},child:Text(labels[i])));
    }
    return await showDialog<T>(
        context: context,
        builder: (BuildContext context) {
          return SimpleDialog(
            title: Text(title),
            children: list
          );
        }
    );
  } else {
    List<CupertinoActionSheetAction>  list = [];
    for(int i=0;i < labels.length;i++) {
      list.add(CupertinoActionSheetAction(onPressed:() {Navigator.pop(context,values[i]);},child:Text(labels[i]),isDefaultAction: i == 0));
    }
    return await showCupertinoModalPopup<T>(
        context: context,
        builder: (BuildContext context) {
          return CupertinoActionSheet(
            title: Text(title),
            actions: list
          );
        });
  }
}

/// Return an TextField widget according to the host platform.
///
/// The returned widget will be a [PlatformTextField]. The optional 02[onFocus] callback is triggered as
/// the focus changes so that the underlying widgets can be modified if it is necessary to
/// allow space for the virtual keyboard popup.
///
/// The [sym] value is used in [SamHot] both to get the initial value from and to save the
/// updated value.
///
/// The [label], [width], [height] and [hint] are used to provide properties to the host platform
/// dependent widget used to hold the field.
///
/// When the value changes an [SE.sa_change] proposal with the new values is presented to the [SamModel] at [SamModel.present].
///
Widget inputBox(SamModel sm,{@required String sym,@required String label,double width = 200,double height = 50,String hint,FocusFunc onFocus}) {
  //log("buildInputBox $label");
  return ConstrainedBox(
    constraints: BoxConstraints.tight(Size(width, height)),
    child: Focus(
      onFocusChange:(hasFocus) {log("textField focus $hasFocus");if (onFocus != null) onFocus(hasFocus);},
      child:PlatformTextField(
      onChanged: (newValue) => sm.actionCall(SE.sa_change, {'value': newValue, 'sym': sym}),
      material: (_, __)  => MaterialTextFieldData(
        //autofocus:false,
        decoration: InputDecoration(
          alignLabelWithHint: true,
          labelText: label,
          hintText: hint,
          ),
      ),
      cupertino: (_, __) => CupertinoTextFieldData(
          placeholder:label,
        ),
      )
    )
  );
}

/// Return a basic button widget adapted to the host platform.
///
/// The [label] is used as text on the button. A [SizedBox] wrapper should be
/// used to set the size if needed.
///
/// The [action] should be an action code from the [Enums](../index.html#samcas-sammodel-companion-enum)
/// list of action code that is the companion of [sm].
Widget button(SamModel sm,{@required Object action,@required String label}) {
  //assert(action.startsWith("sa"));
  return PlatformButton(
     onPressed: () => sm.actionCall(action),
     child: Text(label),
  );
}

/// Return a decorated button widget adapted to the host platform.
///
/// The [label] is used as text on the button and the [width] and [height] control the size.
///
/// The [action] should be an action code from the [Enums](../index.html#samcas-sammodel-companion-enum)
/// list of action code that is the companion of [sm].
Widget fancyButton(SamModel sm,{double width=140,@required Object action,@required String label,double height}) {
  return SizedBox(
    width: width,
    height: height,
    child: PlatformButton(
      material: (_, __)  => MaterialRaisedButtonData(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),),
      cupertinoFilled: (_, __) => CupertinoFilledButtonData(),
      padding:EdgeInsets.all(0.1),
      onPressed: (){sm.actionCall(action);},
      child: Text(label),
    ),
  );
}

/// Used to build a RichText paragraph as a widget.
///
/// This class mimics HTML specifications in a rudimentary way. The class has
/// several chained methods that builds [TextSpan] widgets formatted according to the
/// method type.
///
/// The [Para.emit()] method is used to obtain the widget tree.
class Para {
  /// default color of text
  Color color;
  List<TextSpan> _list = [];
  Para({this.color = Colors.black});
  /// Emits the widgets constructed with the formatting methods.
  ///
  /// This should be the last in the chain.
  Container emit() {
    return Container(
      margin:EdgeInsets.only(top:10),
      child: RichText(
        text:TextSpan(
            style:TextStyle(color:color),
            children:_list)
      ),
    );
  }

  /// Add a new paragraph containing [text] to the [Para] instance.
  ///
  /// allows chaining.
  Para p(String text) {
    this._list.add(TextSpan(text:text));
    return this;
  }
  /// Add a new section containing bold [text] to the [Para] instance.
  ///
  /// allows chaining.
  Para b(String text) {
    this._list.add(TextSpan(text:text,style:TextStyle(fontWeight:FontWeight.bold)));
    return this;
  }
  /// Add a new section containing italicized [text] to the [Para] instance.
  ///
  /// allows chaining.
  Para i(String text) {
    this._list.add(TextSpan(text:text,style:TextStyle(fontStyle:FontStyle.italic)));
    return this;
  }
  /// Add a new section containing an anchore link of [url] and label [text] to the [Para] instance.
  ///
  /// The [bold] flag can be set to *true* to make the anchor text bold.
  ///
  /// allows chaining.
  Para a(String text,String urlParm,{bool bold = false}) {
    this._list.add(
      TextSpan(
        text:text,
        style:TextStyle(color:Colors.blue,fontWeight:(bold?FontWeight.bold:FontWeight.normal)),
        //recognizer: TapGestureRecognizer()
        //..onTap = () async {
          //final url = urlParm;
          //if (await canLaunch(urlParm)) {
          //  await launch(
          //    url,
          //    //forceSafariVC: false,
          //  );
          //}
        //},
      )
    );
    return this;
  }
}

/// Returns a *DropDown* or *Picker* widget based on the host platform.
///
/// This widget is used to ask the user to select from a list of values.
///
/// On the *Material* platform it will be a drop-down list.
///
/// On the *Cupertino* platform it will be the Picker widget.
///
/// The [value] option if present will be used to set the initial value and assumes the [SamHot] value
/// has the same value. This can be guaranteed by specifying `initial:sm.getHot(sym)` and making sure
/// the [SamHot] value of [sym] has a value that is in the universe of *item* values described below.
///
/// The [label] parameter if present is added as a label to the widget.
///
/// The [valStr] string represents the universe of *items* to choose from. Each *item* is separated by a "/".
/// If the *item* has a ":", it is split on the ":" and the first part is treated as the item label and the
/// second part as the choice value.
///
/// Here is a complete call as an example used in [sample missile app](../index.html#sample-application---missile-site). In this
/// case the [sym] value is contained in a variable but it could be a literal.
///
/// ```genPlatformPicker(sm, symBanks, "0/1/2/3", value:"1",label:"   Banks: ")```
///
Widget genPlatformPicker(SamModel sm,String sym,String valStr,{Object value,String label}) {
  return PlatformWidget(
    material:(_,__) => _genDropdown(sm,sym,valStr,value:value,label:label),
    cupertino:(_,__) => _genPicker(sm,sym,valStr,value:value,label:label),
  );
}

// Assume value and what is shown are the same.
Widget _genPicker(SamModel sm,String sym,String valStr,{Object value,String label}) {
  if (!sm.hasHot(sym)) sm.setHot(sym,value);
  Text txtLab = Text(label,textAlign:TextAlign.center);
  List <String> list = valStr.split("/");
  int itemSel = 0;
  int ix = -1;
  List<String> vals = [];
  List<Widget> itemList  = list.map<Text>((String v) {
    ix += 1;
    if (value == v) itemSel = ix;
    vals.add(v);
    return Text(v);
  }).toList();

  SamWatch sw = sm.watch((SamBuild sb)=>
      ConstrainedBox(
          constraints: BoxConstraints.tight(Size(30, 35)),
          child:CupertinoPicker (
        //value:sm.getHot(sym),
        //hint:Text(' ')
          scrollController:FixedExtentScrollController(initialItem:itemSel),
          itemExtent:20,
        //diameterRatio:20,
          onSelectedItemChanged: (newValue){log("newValue $newValue ${vals[newValue]}");sm.actionCall(SE.sa_change,{'value':vals[newValue],'sym':sym});},
          children: itemList,
      ),
    )
  );
  if (txtLab != null) {
    return Row(mainAxisAlignment: MainAxisAlignment.center,children:[txtLab,sw]);
  } else {
    return sw;
  }
}

// Material dropDown button with optional label.
Widget _genDropdown(SamModel sm,String sym,String valStr,{Object value,String label}) {
  //log("genDropDown $sym $value ${sm.hotMap[sym]}");
  if (!sm.hasHot(sym)) sm.setHot(sym,value);
  Text txtLab = Text(label,textAlign:TextAlign.center);
  SamWatch sw = sm.watch((SamBuild sb)=>
    DropdownButton<String>(
        value:sm.getHot(sym),
        hint:Text(' '),
        onChanged: (newValue){sm.actionCall(SE.sa_change,{'value':newValue,'sym':sym});},
        items: _getItems(valStr),
      )
    );
  if (txtLab != null) {
    return Row(mainAxisAlignment: MainAxisAlignment.center,children:[txtLab,sw]);
  } else {
    return sw;
  }
}

List<DropdownMenuItem> _getItems(String str) {
  List <String>list = str.split("/");
  return
    list.map<DropdownMenuItem<String>>((
        String value) {
      String val = value;
      String txt = value;
      var parts = value.split(":");
      if (parts.length == 2) {
        val = parts[0];
        txt = parts[1];
      }
      return DropdownMenuItem<String>(value: val, child: Text(txt),);
    }).toList();
}

/// Return an on/off switch widget
///
/// This is used to create an on/off switch widget. When the switch changes value
/// the [changeExec] function if it exists will be called.
///
/// The [defValue] is the initial value and assumes it matches the [SamHot] [sym] setting.
/// This can be guaranteed by specifying `defValue:sm.getHot(sym)` and making sure
/// the [SamHot] value of [sym] in [sm] has a *true* or *false* value.
///
/// The [label] adds a label to the switch.
Widget genSwitch(SamModel sm,String sym,Object label,{bool defValue = false,CheckFunc changeExec}) {
  return _LabeledSwitch(sm,sym,label,defValue,changeExec);
}

class _LabeledSwitch extends StatefulWidget {
  _LabeledSwitch(this._sm,this._sym,this._label,this._defValue,this._changeExec,{Key key}) : super(key: key);
  final SamModel _sm;
  final String _sym;
  final Object _label;
  final bool   _defValue;
  final CheckFunc _changeExec;
  @override
  _LabeledSwitchState createState() => _LabeledSwitchState(this);
}

class _LabeledSwitchState extends State<_LabeledSwitch> {
  _LabeledSwitchState(this._lcb);
  final _LabeledSwitch _lcb;

  @override
  Widget build(BuildContext context) {
    final SamModel sm = _lcb._sm;
    if (!sm.hasHot(_lcb._sym)) sm.setHot(_lcb._sym,_lcb._defValue);
    String lab = "?";
    if (_lcb._label is String) {
      lab = _lcb._label;
    } else if (_lcb._label is Function) {
      LabelFunc func = _lcb._label;
      lab = func(sm,_lcb._sym);
    }
    return Row(
        children:[
          PlatformWidget(
            material:(_,__) =>
                Switch(
                  value: sm.getHot(_lcb._sym),
                  onChanged: (newValue){sm.actionCall(SE.sa_check,{'value':newValue,'sym':_lcb._sym,'atSrc':this,'execFunc':_lcb._changeExec,'bc':context});},
                ),
            cupertino:(_,__) =>
                CupertinoSwitch(
                  value: sm.getHot(_lcb._sym),
                  onChanged: (newValue){sm.actionCall(SE.sa_check,{'value':newValue,'sym':_lcb._sym,'atSrc':this,'execFunc':_lcb._changeExec,'bc':context});},
                ),
          ),
          Text(lab,style:TextStyle(fontSize:12.0)),
      //contentPadding:EdgeInsets.symmetric(horizontal:6.0,vertical:0.0),
      //title: Text(lab,style:TextStyle(fontSize:12.0)),
    ]);
  }
}


/// This class creates a utility *Logger* widget.
///
/// A *logger* window is often needed in an application. This class
/// creates such a window.
///
/// A line is added to the log by calling [Logger.addLogLine].
///
/// An example of [Logger] usage is found in [sample missile app](../index.html#sample-application---missile-site)
///
class Logger extends StatefulWidget {
  final SamModel _sm;
  final double _wid;
  final double _hgt;
  final String _logKey;
  /// Optional background color of window.
  final Color  color;
  /// Constructs a Logger instance.
  ///
  /// The Logger is constructed with the [SamHot] of [_sm] as the data pool, [_logKey] as [SamHot]s *sym* and with
  /// a size of ([_wid],[_hgt]); Optionally the background color can be set to [color];
  Logger(this._sm,this._logKey,this._wid,this._hgt,{Key key,this.color = Colors.limeAccent}) : super(key:key);

  /// Adds [msg] to the [Logger] messages.color
  ///
  /// If [msg] is a [Text] instance it is added as is. This can be used to add formatted text with font properties or color.
  ///
  /// Otherwise the [toString] value of [msg] is added.
  void addLogLine(var msg) {(_sm.getHot(_logKey) as _LoggerState).addLogLine(msg);}

  /// Creates the internal *State* portion of the [StatefulWidget].
  @override
  _LoggerState createState() => _LoggerState(_logKey,_sm,_wid,_hgt,color);
}

class _LoggerState extends State<Logger> {
  _LoggerState(String logKey,this.sm,this.wid,this.hgt,this.color) {
    sm.setHot(logKey,this);
  }
  final double wid;
  final double hgt;
  final Color  color;
  final ScrollController sc = ScrollController();
  SamModel sm;
  List<Text> logLines = [];

  void addLogLine(var msg) {
    if (msg is Text) {
      logLines.add(msg);
    } else {
      logLines.add(Text("$msg"));
    }
    setState((){});
  }

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) => {sc.jumpTo(sc.position.maxScrollExtent)});
    return Container(
        decoration: BoxDecoration(
            color: color, border: Border.all(width: 2.0)),
        child: ConstrainedBox(
          constraints: BoxConstraints.expand(
            width: wid,
            //maxHeight:
            height: hgt,
          ),
          child: ListView.builder(
            controller:sc,
            //reverse:true,
            itemCount: logLines.length,
            itemBuilder: (BuildContext context, int index) => logLines[index]
          ),
        )
    );
  }
}


/// Callback used by [MeasuredSize]
typedef MeasureSizeCallback = void Function(Size size);
/// Report size of widget tree.
///
/// In some applications knowing the size of a widget tree is
/// required to determine layout strategies. This class, given a
/// widget tree will report the size of that tree. The [Offstage] widget
/// can be used to perform these calculations out of sight to the user.
///
/// The callback [MeasureSizeCallback] is called at the completion of the
/// rendering cycle.
///
/// It should be noted that this requires an extra widget tree build if the subsequent
/// builds are modified according to the [MeasuredSize] results.
///
/// An example of [MeasuredSize] usage is found in [sample missile app](../index.html#sample-application---missile-site)
///
// ignore: must_be_immutable
class MeasuredSize extends Builder {
  /// Constructs the [MeasuredSize] instance.
  ///
  /// The instance is constructed with a builder for the [child] widgets. At the completion of the build [callback] is called with the
  /// dimensions of the widget tree. If the widget tree is to be build offstage (hidden), the [offstage] flag should be set to *true*.
  MeasuredSize({Key key,@required this.child,@required this.callback,this.offstage=false}):super(key:key,builder:(context){ return child;});

  /// widget tree to build
  final Widget child;
  /// callback called at render completion
  final MeasureSizeCallback callback;
  /// true if build is hidden
  final offstage;
  BuildContext _saveContext;

  /// The build function used to intercept and measure the build cycle.
  @override
  Widget build(BuildContext context) {
    log("measuredSize build $context");
    _saveContext = context;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      log("measuredSize.post ${_saveContext.size} $offstage ${_saveContext.runtimeType}");
      if (offstage) {
        RenderObject ro = (_saveContext as Element).renderObject;
        bool bVisited = false;
        ro.visitChildren((_) {
          //log("measureSize.visitChildren ${_.runtimeType}");
          if (_ is RenderBox && !bVisited) {
            //log("visitChildren size ${_.hasSize} ${_.size} ${_.paintBounds}");
            bVisited = true;
            callback(_.size);
          }
        });
      } else {
        callback(_saveContext.size);
      }
    });
    return child;
  }
}

/// A logging function used during development.
///
/// When run on an Android or IPhone host in debug mode it will also
/// determine the location of the log function call and prefix this to the
/// logged message.
///
/// If the log function calls are wrapped in an *assert* statement they
/// will be removed when the app is deployed in production mode. For this reason the log
/// method call return *true*.
///
bool log(String msg) {
  StackTrace st = StackTrace.current;
  List<String> lines = "$st".split("\n");
  RegExpMatch rem = exp.firstMatch(lines[1]);
  if (rem != null) {
    dev.log("@${rem.group(1)} $msg");
  } else {
    dev.log("devlog $msg");
  }
  return true;
}

/// Return a Text widget populated with [text] optionally formatted with a [fontSize] and [fontWeight]
///
/// This is a convenience function.
Widget text(String text,{double fontSize,FontWeight fontWeight}) {
  return Text(text,
    style:
    TextStyle(fontSize: fontSize, fontWeight: fontWeight),
  );
}

/// Return a singleton widget [w] into a [Row] list
///
/// This is a convenience function.
Row row(Widget w) => Row(children:[w]);
