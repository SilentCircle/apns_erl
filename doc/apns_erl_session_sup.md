

# Module apns_erl_session_sup #
* [Function Index](#index)
* [Function Details](#functions)

__Behaviours:__ [`supervisor`](supervisor.md).

<a name="index"></a>

## Function Index ##


<table width="100%" border="1" cellspacing="0" cellpadding="2" summary="function index"><tr><td valign="top"><a href="#get_child_pid-1">get_child_pid/1</a></td><td></td></tr><tr><td valign="top"><a href="#init-1">init/1</a></td><td></td></tr><tr><td valign="top"><a href="#is_child_alive-1">is_child_alive/1</a></td><td></td></tr><tr><td valign="top"><a href="#start_child-2">start_child/2</a></td><td>Start a child session.</td></tr><tr><td valign="top"><a href="#start_link-1">start_link/1</a></td><td>(<em>Deprecated</em>.) <code>Sessions</code> is a list of sessions to start.</td></tr><tr><td valign="top"><a href="#stop_child-1">stop_child/1</a></td><td></td></tr></table>


<a name="functions"></a>

## Function Details ##

<a name="get_child_pid-1"></a>

### get_child_pid/1 ###

`get_child_pid(Name) -> any()`

<a name="init-1"></a>

### init/1 ###

`init(X1) -> any()`

<a name="is_child_alive-1"></a>

### is_child_alive/1 ###

`is_child_alive(Name) -> any()`

<a name="start_child-2"></a>

### start_child/2 ###

`start_child(Name, Opts) -> any()`

Start a child session.


### <a name="Parameters">Parameters</a> ###


* `Name` - Session name (atom)

* `Opts` - Options, see [`apns_erl_session`](apns_erl_session.md) for more details


<a name="start_link-1"></a>

### start_link/1 ###

`start_link(Sessions) -> any()`

__This function is deprecated:__

Use the HTTP/2 application, `apns_erlv3`.


### <a name="Example_for_APNS_Binary_API_(Deprecated)">Example for APNS Binary API (Deprecated)</a> ###

```
  Sessions = [
      [
          {name, 'apns-com.example.MyApp'},
          {config, [
              {host, "gateway.sandbox.push.apple.com"},
              {port, 2195},
              {bundle_seed_id, <<"com.example.MyApp">>},
              {bundle_id, <<"com.example.MyApp">>},
              {feedback_enabled, false},
              {fake_token, <<"XXXXXX">>},
              {retry_delay, 1000},
              {checkpoint_period, 60000},
              {checkpoint_max, 10000},
              {close_timeout, 5000},
              {disable_apns_cert_validation, false},
              {ssl_opts, [
                      {certfile, "/etc/somewhere/certs/com.example.MyApp.cert.pem"},
                      {keyfile, "/etc/somewhere/certs/com.example.MyApp.key.unencrypted.pem"},
                      {versions, ['tlsv1']} % Fix for SSL issue http://erlang.org/pipermail/erlang-questions/2015-June/084935.html
                  ]
              }
           ]}
      ] %, ...
  ].
```


`Sessions` is a list of sessions to start. Each session is a
proplist as shown.

<a name="stop_child-1"></a>

### stop_child/1 ###

`stop_child(Name) -> any()`

