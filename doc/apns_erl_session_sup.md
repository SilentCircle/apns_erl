

# Module apns_erl_session_sup #
* [Description](#description)
* [Data Types](#types)
* [Function Index](#index)
* [Function Details](#functions)

APNS session supervisor.

Copyright (c) 2015 Silent Circle

__Behaviours:__ [`supervisor`](supervisor.md).

__Authors:__ Edwin Fine ([`efine@silentcircle.com`](mailto:efine@silentcircle.com)).

<a name="types"></a>

## Data Types ##




### <a name="type-child">child()</a> ###


<pre><code>
child() = undefined | pid()
</code></pre>




### <a name="type-proplist">proplist()</a> ###


<pre><code>
proplist() = [<a href="proplists.md#type-property">proplists:property()</a>]
</code></pre>




### <a name="type-session_props">session_props()</a> ###


<pre><code>
session_props() = <a href="#type-proplist">proplist()</a>
</code></pre>




### <a name="type-startchild_err">startchild_err()</a> ###


<pre><code>
startchild_err() = already_present | {already_started, Child::<a href="#type-child">child()</a>} | term()
</code></pre>




### <a name="type-startchild_ret">startchild_ret()</a> ###


<pre><code>
startchild_ret() = {ok, Child::<a href="#type-child">child()</a>} | {ok, Child::<a href="#type-child">child()</a>, Info::term()} | {error, <a href="#type-startchild_err">startchild_err()</a>}
</code></pre>




### <a name="type-startlink_err">startlink_err()</a> ###


<pre><code>
startlink_err() = {already_started, pid()} | {shutdown, term()} | term()
</code></pre>




### <a name="type-startlink_ret">startlink_ret()</a> ###


<pre><code>
startlink_ret() = {ok, pid()} | ignore | {error, <a href="#type-startlink_err">startlink_err()</a>}
</code></pre>

<a name="index"></a>

## Function Index ##


<table width="100%" border="1" cellspacing="0" cellpadding="2" summary="function index"><tr><td valign="top"><a href="#get_child_pid-1">get_child_pid/1</a></td><td>Get a child's pid.</td></tr><tr><td valign="top"><a href="#init-1">init/1</a></td><td></td></tr><tr><td valign="top"><a href="#is_child_alive-1">is_child_alive/1</a></td><td>Test if child is alive.</td></tr><tr><td valign="top"><a href="#start_child-2">start_child/2</a></td><td>Start a child session.</td></tr><tr><td valign="top"><a href="#start_link-1">start_link/1</a></td><td>Start APNS sessions.</td></tr><tr><td valign="top"><a href="#stop_child-1">stop_child/1</a></td><td>Stop child session.</td></tr></table>


<a name="functions"></a>

## Function Details ##

<a name="get_child_pid-1"></a>

### get_child_pid/1 ###

<pre><code>
get_child_pid(Name) -&gt; pid() | undefined
</code></pre>

<ul class="definitions"><li><code>Name = atom()</code></li></ul>

Get a child's pid.

<a name="init-1"></a>

### init/1 ###

`init(X1) -> any()`

<a name="is_child_alive-1"></a>

### is_child_alive/1 ###

<pre><code>
is_child_alive(Name) -&gt; boolean()
</code></pre>

<ul class="definitions"><li><code>Name = atom()</code></li></ul>

Test if child is alive.

<a name="start_child-2"></a>

### start_child/2 ###

<pre><code>
start_child(Name, Opts) -&gt; Result
</code></pre>

<ul class="definitions"><li><code>Name = atom()</code></li><li><code>Opts = <a href="#type-proplist">proplist()</a></code></li><li><code>Result = <a href="#type-startchild_ret">startchild_ret()</a></code></li></ul>

Start a child session.


### <a name="Parameters">Parameters</a> ###

* `Name` - Session name (atom)

* `Opts` - Options, see [`apns_erl_session`](apns_erl_session.md) for more details



<a name="start_link-1"></a>

### start_link/1 ###

<pre><code>
start_link(Sessions) -&gt; <a href="#type-startlink_ret">startlink_ret()</a>
</code></pre>

<ul class="definitions"><li><code>Sessions = [<a href="#type-session_props">session_props()</a>]</code></li></ul>

Start APNS sessions.

`Sessions` is a list of proplists and looks like this:

```
  [
      [
          {name, 'apns-com.example.Example'},
          {config, [
              {host, "gateway.sandbox.push.apple.com"},
              {port, 2195},
              {bundle_seed_id, <<"com.example.Example">>},
              {bundle_id, <<"com.example.Example">>},
              {fake_token, <<"XXXXXX">>},
              {retry_delay, 1000},
              {checkpoint_period, 60000},
              {checkpoint_max, 10000},
              {close_timeout, 5000},
              {ssl_opts, [
                      {certfile, "/etc/somewhere/certs/com.example.Example--DEV.cert.pem"},
                      {keyfile, "/etc/somewhere/certs/com.example.Example--DEV.key.unencrypted.pem"}
                  ]
              }
           ]}
      ] %, ...
  ]
```


<a name="stop_child-1"></a>

### stop_child/1 ###

<pre><code>
stop_child(Name) -&gt; Result
</code></pre>

<ul class="definitions"><li><code>Name = atom()</code></li><li><code>Result = ok | {error, Error}</code></li><li><code>Error = not_found | simple_one_for_one</code></li></ul>

Stop child session.

