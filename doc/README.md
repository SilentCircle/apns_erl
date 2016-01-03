

# Apple Push Notification Service SCPF service #

Copyright (c) 2015 Silent Circle

__Version:__ 1.1.3

__Authors:__ Edwin Fine ([`efine@silentcircle.com`](mailto:efine@silentcircle.com)).

__References__* See [Local and Push Notification Programming Guide](https://developer.apple.com/library/ios/#documentation/NetworkingInternet/Conceptual/RemoteNotificationsPG/) (requires Apple Developer login).

`apns_erl` is a Silent Circle Push Framework service provider for the Apple Push Notification Service (APNS).


### <a name="Prerequisites_for_building">Prerequisites for building</a> ###

* Linux or OS X

* Erlang >= R17

* rebar >= 2.0.0

* GNU make >= 3.81 or later



### <a name="Building">Building</a> ###

```
git clone $REPO/apns_erl.git
cd apns_erl
make
```


### <a name="Running_test_cases">Running test cases</a> ###

This will run dialyzer and Common Test. If this is a first run,
dialyzer will need to build a PLT, which could take some time.

Note: Common Test cases are temporarily out of order and are not actually
called.

```
make test
```

Output is in logs/index.html.


### <a name="Building_documentation">Building documentation</a> ###

```
make doc
```
Output is in the doc directory.


## Modules ##


<table width="100%" border="0" summary="list of modules">
<tr><td><a href="apns_erl_app.md" class="module">apns_erl_app</a></td></tr>
<tr><td><a href="apns_erl_feedback_session.md" class="module">apns_erl_feedback_session</a></td></tr>
<tr><td><a href="apns_erl_session.md" class="module">apns_erl_session</a></td></tr>
<tr><td><a href="apns_erl_session_sup.md" class="module">apns_erl_session_sup</a></td></tr>
<tr><td><a href="sc_push_svc_apns.md" class="module">sc_push_svc_apns</a></td></tr></table>

