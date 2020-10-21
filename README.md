# Dart/Flutter implementation of SAMCAS

Flutter/Dart SAMCAS implementation of the Jean-Jacques Dubray *SAM* methodology

## Description

*SAM* (State-Action-Model) is a software engineering pattern that helps manage the application state and reason about temporal aspects with precision and clarity.
In brief, it provides a robust pattern with which to organize complex state mutations found in modern applications.

This project implements the *SAM* methodology in Dart. The *SAM* pattern proposed
by [Jean-Jacques Dubray](https://www.infoq.com/profile/Jean~Jacques-Dubray)  is explained at [sam.js.org](https://sam.js.org/).

The Dart version of [SAMCAS](/docs/samcas/api/index.html) is a table driven approach to the *SAM* pattern and extends the *SAM* pattern
by including a simple signal protocol for child models to inform their parents of their state changes.

Embedded running samples are found within this document at [sample rocket app](#sample-application---rocket-launcher) and [sample missile app](#sample-application---missile-site).


## Implementation Structure of [SAMCAS](/docs/samcas/api/index.html)

The *SAM* pattern is implemented using four(4) primary classes:


#### 1. **SamModel** class ####
* An abstract class contains the volatile portion of the model that is subclassed to provide customization.

* All dynamic values that need to be tracked for efficient widget rendering use a [SamHot] map referenced by a user chosen symbolic name and accessed via public methods.

* Other non-tracked dynamic values are also stored in the subclassed instance as a normal Dart variable of the required type.


#### 2. **SamAction** class ####
* The readonly map to methods that define the processing logic for *action* and possible *signal* handlers as well as the processing logic for any *nap* processing
  of state changes that may have been defined.

* By convention the former are named the same as their *action* definition counterpart while the *nap* handlers are prefixed with 'nap'.

#### 3. **SamState** class ####
* The readonly table that defines all the permitted states and their transition logic and rules.

#### 4. **SamView** class ####
* The readonly table that maps the various states into the widget build logic.

* When provided, the special view called *defRender* is used if a specific state view does not exist.

The combination of these 4 classes linked together is referred to as the **"Model complex"** or **"SAM complex"** or **"complex"** internally and in this document.

The classes [SamAction](samcas/SamAction-class.html), [SamState](samcas/SamState-class.html) and [SamView](samcas/SamView-class.html) in combination are a pattern that controls
how the model is represented and how transitions from one state to another occur. For convenience, in this document and in the code references they are referred to as the **Trifecta**.

The reference pattern between the [SamModel](samcas/SamModel-class.html) instance and the *trifecta* follows a similar design paradigm
employed by Flutter with Widgets and Elements whereby the readonly Widget is a pattern for one or more Elements or RenderObjects. In the same way the
[SamModel](samcas/SamModel-class.html) instance knows where its *trifecta* is but the *trifecta* have no reference to any [SamModel](samcas/SamModel-class.html).

If there is a [SamModel](samcas/SamModel-class.html) parent/child relationship the child [SamModel](samcas/SamModel-class.html) will point to the parent and
the parent will have a list of its [SamModel](samcas/SamModel-class.html) children.

There are a number of secondary classes used internally but also referenced in building the working complexes. They are:

#### 1. **SamInject** class ####
* Used to inject a [SamModel](samcas/SamModel-class.html) into a widget structure.

#### 2. **SamFactory** class ####
* a disposable instance that is used to configure the *trifecta* instances of a *complex* and then
the *trifecta* is used to create one or more [SamModel](samcas/SamModel-class.html) instances.

* The [SamFactory](samcas/SamFactory-class.html)  needs to be subclassed and the method [formatTrifecta] provided
to implement the specific customization required.

#### 2. **SamWatch** class ####
* an instance created by the [SamModel.watch](samcas/SamModel-class.html#watch) method used to generate efficient
widget rendering for a portion of a [SamModel](samcas/SamModel-class.html)

* It is injected with the [SamModel.watch()] method.


## Design of SAMCAS

Dart has done many things right in their design of the language. In particular, combined with a good IDE such as Android Studio,
the programmer hints and language conciseness make software development a pleasant experience.

SAMCAS has been designed to complement this design and facilitate the detection of issues as early as possible in the development process.
For this reason the design of SAMCAS incorporates:

1. The states, actions and signals use [Enums](#samcas-sammodel-companion-enum) so that state transitions and actions applied to the model can be clearly seen during development.
2. Furthermore, the use of [Enums](#samcas-sammodel-companion-enum) allow for incorrect spelling to be detected during editing or by a compilation error.
2. The validation process that happens during model activation does further assert checking to make sure all states are defined and
can be rendered and that all actions have a processing capability.
3. The form input widgets such as *TextField* can be easily tied to the [SamModel](samcas/SamModel-class.html) values so that bidirectional updates are performed automatically.
3. The cyclic nature of the *SAM* methodology also makes it an excellent fit for the Flutter Widget rendering logic that creates the UI.
SAMCAS is designed to optimize the widgets that need to be rendered.  Built into SAMCAS, aided my the cyclic nature of *SAM*, is a simple but robust
change detection algorithm that renders only the changed widget elements.

It is expected that the apps using SAMCAS are running on devices with limited processing amd memory capacity. Therefore parts of the model complex can be shared.
The [sample missile app](#sample-application---missile-site) provided as an example uses these shared patterns extensively.

1. Interfaces efficiently with Flutter widget rendering logic.
2. Each state can have a widget tree or there can be a default rendering.
2. The [SamModel.watch] function allows volatile widgets to be updated efficiently when it detects model changes in the dependant variables that effect
the widget tree.
2. The invaluable [WidgetsBinding.instance.addPostFrameCallback] interface allows for post-render processing to synchronize with dependent variable tracking.

## SAMCAS SamModel Companion Enum

The Enum capabilities of Dart are rudimentary:  you can obtain the names of the entire list and their Enum type.
The following strategy was used to maximize the edit and debug run time validation.

1. The states, actions and signals of a [SamModel] are encoded into an Enum instance.
1. The Enum instance is by convention named with 2 upper case characters such as *RK*.  The name *SE* is reserved for the standard SAMCAS internal Enums.
2. States are prefixed with *ss* followed by a camel-case label such as *Launched*
3. Actions are prefixed with *sa* followed by a camel-case label such as *ResetLauncher*
4. Signals (when required) are prefixed with *sg* followed by a camel-case label such as *Launching*
5. The values of the Enum are passed to the [SamFactory] constructor so that the Enum can be associated
with the [SamModel] and is referred to as its companion Enum.
6. The Enum is validated at that time to ensure the prefix requirements are followed.

As an example, here is the Enum used by the [sample rocket app](#sample-application---rocket-launcher).

```
enum RK {
  // -------------- states ---------------
                 /// state: Ready for launch
  ssReady,
                 /// state: launched and spent
  ssLaunched,
                 /// state: Counting down
  ssCounting,
                 /// state: Launch was aborted
  ssAborted,
                 /// state: Countdown was paused.
  ssPaused,
                 /// state: Counting down, counter above 10. (Missile mode only)
  ssWaiting,
  // -------------- actions ---------------
                 /// action: Decrement counter
  saDecrement,
                 /// action: Pause counting
  saPause,
                 /// action: Abort launch
  saAbort,
                 /// action: Reset state to [RK.ssReady]
  saResetLauncher,
                 /// action: Start the counter
  saStartCtr,
                 /// action: Restart the counter after a [RK.saPause]
  saRestartCtr,
  // -------------- signals raised ---------------
                 /// signal: Rocket is aborting
  sgAborting,
                 /// signal: Rocket is launching
  sgLaunching,
                 /// signal: Rocket is pausing
  sgPausing,
                 /// signal: Rocket is counting
  sgCounting,
}
```

## Flutter State Management Candidate

State management within a Flutter application is a hot topic these days. There are already several implementations such as Providers, BLoC and GetX.
It is proposed that *SAM* methodology and the SAMCAS implementation offer a viable alternative for the following reasons.

* *SAM*'s cyclic nature avoids race conditions.

* *SAM* actions can easily translate into business logic that determine values and possible state changes. These can easily be isolated in the code base.

* The rendering logic that is a separate section then automatically and efficiently render the new state along with its values.

* The SAMCAS design will optimize the rendering logic for these model changes.


## License

**Copyright (c) 2020 Steve Pritchard of Rexcel Systems Inc.**

Released under the [The MIT License](https://opensource.org/licenses/MIT)

## Reference Resources ##

* Sam Methodology [sam.js.org](https://sam.js.org/)

* The [SAMCAS](/docs/samcas/api/index.html) library

* The [Rocket lib](/docs/rocket-lib/api/index.html) library

* The [Rocket App](/docs/rocket/api/index.html) a simple SAMCAS example

* The [Missile App](/docs/missile/api/index.html) a more complex SAMCAS example

## Source repository at GitHub ##

* [samcas-lib-dart](https://github.com/srp7474/samcas-lib-dart) SAMCAS library

* [rocket-lib-dart](https://github.com/srp7474/rocket-lib-dart) Rocket component

* [rocket-app-dart](https://github.com/srp7474/rocket-app-dart) Rocket app, needs SAMCAS library, Rocket component

* [missile-app-dart](https://github.com/srp7474/missile-app-dart) Missile App, needs SAMCAS library, Rocket component



## Sample Application - Rocket Launcher

<div>
<div style=float:left;width:220px;>

To the right is the web deployment of the Dart version of the Rocket launcher sample app
described at [sam.js.org](https://sam.js.org/).  It has been enhanced to give more state transitions
than the original example.

The Android and IPhone deployments are available at the Google Play Store and Apple Store respectively. Search for *SAMCAS*.

**Source Code**

[rocket-lib-dart](https://github.com/srp7474/rocket-lib-dart) Rocket component

[rocket-app-dart](https://github.com/srp7474/rocket-app-dart) Rocket app, needs SAMCAS library, Rocket component

[samcas-lib-dart](https://github.com/srp7474/samcas-lib-dart) SAMCAS library

**Reference**

Sam Methodology [sam.js.org](https://sam.js.org/)

The [SAMCAS](/docs/samcas/api/index.html) library

The [Rocket lib](/docs/rocket-lib/api/index.html) library

</div>

<iframe height=800 width=420 src=/web/rocket/web/index.html style=float:left;margin-left:10px;></iframe>

</div><div style=clear:left></div>

## Sample Application - Missile Site

<div>

<div style=float:left;width:220px;>

To the right is the web deployment of the Dart version of the Missile Site sample app that utilizes the Rocket launcher
model as a child model.

The Android and IPhone deployments are available at the Google Play Store and Apple Store respectively. Search for *SAMCAS*.


**Source Code**

[rocket-lib-dart](https://github.com/srp7474/rocket-lib-dart) Rocket component

[missile-app-dart](https://github.com/srp7474/rocket-app-dart) Rocket app, needs SAMCAS library, Rocket component

[samcas-lib-dart](https://github.com/srp7474/samcas-lib-dart) SAMCAS library

**Reference**

Sam Methodology [sam.js.org](https://sam.js.org/)

The [SAMCAS](/docs/samcas/api/index.html) library

The [Rocket lib](/docs/rocket-lib/api/index.html) library

</div>

<iframe height=800 width=420 src=/web/missile/web/index.html style=float:left;margin-left:10px;></iframe>

</div><div style=clear:left></div>



