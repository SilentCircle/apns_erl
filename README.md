

# [DEPRECATED] Apple Push Notification Service SCPF service #

Copyright (c) 2015,2016 Silent Circle

__Version:__ 1.2.0

__Authors:__ Edwin Fine ([`efine@silentcircle.com`](mailto:efine@silentcircle.com)).

`apns_erl` is a Silent Circle Push Framework service provider for the binary (pre-HTTP/2) Apple Push Notification Service (APNS).

**NOTE**: This is deprecated in favor of the HTTP/2 service provider, `apns_erlv3`.


### <a name="Prerequisites_for_building">Prerequisites for building</a> ###

* Linux

* Erlang >= 18.3

* rebar3 >= 3.3.1

* GNU make >= 3.81 or later



### <a name="Building">Building</a> ###

```
git clone $REPO/apns_erl.git
cd apns_erl
make
```


### <a name="Running_test_cases">Running test cases</a> ###

Note: Common Test cases are permanently out of order because this is deprecated.

```
make ct
```

Output is in logs/index.html.


### <a name="Building_documentation">Building documentation</a> ###

Documentation uses `edown` to produce Markdown documents.

```
make docs
```
Output is in the doc directory.


## Modules ##


<table width="100%" border="0" summary="list of modules">
<tr><td><a href="http://github.com/SilentCircle/apns_erl/blob/master/doc/apns_erl_app.md" class="module">apns_erl_app</a></td></tr>
<tr><td><a href="http://github.com/SilentCircle/apns_erl/blob/master/doc/apns_erl_feedback_session.md" class="module">apns_erl_feedback_session</a></td></tr>
<tr><td><a href="http://github.com/SilentCircle/apns_erl/blob/master/doc/apns_erl_session.md" class="module">apns_erl_session</a></td></tr>
<tr><td><a href="http://github.com/SilentCircle/apns_erl/blob/master/doc/apns_erl_session_sup.md" class="module">apns_erl_session_sup</a></td></tr>
<tr><td><a href="http://github.com/SilentCircle/apns_erl/blob/master/doc/sc_push_svc_apns.md" class="module">sc_push_svc_apns</a></td></tr></table>

