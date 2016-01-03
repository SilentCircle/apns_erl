

# Module apns_erl_feedback_session #
* [Description](#description)
* [Data Types](#types)
* [Function Index](#index)
* [Function Details](#functions)

APNS feedback service session.

Copyright (c) 2015 Silent Circle

__Behaviours:__ [`gen_fsm`](gen_fsm.md).

__Authors:__ Edwin Fine ([`efine@silentcircle.com`](mailto:efine@silentcircle.com)), Sebastien Merle.

<a name="description"></a>

## Description ##
Process configuration:



<dt><code>host</code>:</dt>




<dd>is hostname of the feedback service as a string.
</dd>




<dt><code>port</code>:</dt>




<dd><p>is the port of the feedback service as an integer.</p><p></p><p>Default value: <code>2196</code>.</p><p></p></dd>




<dt><code>bundle_seed_id</code>:</dt>




<dd>is the APNS bundle seed identifier as a binary.
</dd>




<dt><code>bundle_id</code>:</dt>




<dd>is the APNS bindle identifier as a binary.
</dd>




<dt><code>fake_token</code>:</dt>




<dd>is the fake token used to trigger checkpoints as a binary;
it will be ignored.
</dd>




<dt><code>retry_delay</code>:</dt>




<dd><p>is the reconnection delay in miliseconds the process will wait before
reconnecting to feeddback servers as an integer;</p><p></p><p>Default value: <code>3600000</code>.</p><p></p></dd>




<dt><code>close_timeout</code>:</dt>




<dd><p>is the maximum amount of time the session will wait for the feedback
server to close the SSL connection after shuting it down.</p><p></p><p>Default value: <code>5000</code>.</p><p></p></dd>




<dt><code>ssl_opts</code>:</dt>




<dd>is the property list of SSL options including the certificate file path.
</dd>




<a name="types"></a>

## Data Types ##




### <a name="type-fb_rec">fb_rec()</a> ###


<pre><code>
fb_rec() = {Timestamp::non_neg_integer(), Token::binary()}
</code></pre>




### <a name="type-feedback_handler">feedback_handler()</a> ###


<pre><code>
feedback_handler() = fun((TSTok::<a href="#type-fb_rec">fb_rec()</a>) -&gt; <a href="#type-fb_rec">fb_rec()</a>)
</code></pre>




### <a name="type-fsm_ref">fsm_ref()</a> ###


<pre><code>
fsm_ref() = atom() | pid()
</code></pre>




### <a name="type-option">option()</a> ###


<pre><code>
option() = {host, string()} | {port, pos_integer()} | {retry_delay, pos_integer()} | {close_timeout, pos_integer()} | {bundle_seed_id, binary()} | {bundle_id, binary()} | {ssl_opts, list()}
</code></pre>




### <a name="type-options">options()</a> ###


<pre><code>
options() = [<a href="#type-option">option()</a>]
</code></pre>




### <a name="type-state">state()</a> ###


<pre><code>
state() = #'?S'{}
</code></pre>

<a name="index"></a>

## Function Index ##


<table width="100%" border="1" cellspacing="0" cellpadding="2" summary="function index"><tr><td valign="top"><a href="#code_change-4">code_change/4</a></td><td></td></tr><tr><td valign="top"><a href="#connected-2">connected/2</a></td><td></td></tr><tr><td valign="top"><a href="#connected-3">connected/3</a></td><td></td></tr><tr><td valign="top"><a href="#connecting-2">connecting/2</a></td><td></td></tr><tr><td valign="top"><a href="#connecting-3">connecting/3</a></td><td></td></tr><tr><td valign="top"><a href="#default_feedback_handler-1">default_feedback_handler/1</a></td><td></td></tr><tr><td valign="top"><a href="#disconnecting-2">disconnecting/2</a></td><td></td></tr><tr><td valign="top"><a href="#disconnecting-3">disconnecting/3</a></td><td></td></tr><tr><td valign="top"><a href="#get_state-1">get_state/1</a></td><td></td></tr><tr><td valign="top"><a href="#handle_event-3">handle_event/3</a></td><td></td></tr><tr><td valign="top"><a href="#handle_info-3">handle_info/3</a></td><td></td></tr><tr><td valign="top"><a href="#handle_sync_event-4">handle_sync_event/4</a></td><td></td></tr><tr><td valign="top"><a href="#init-1">init/1</a></td><td></td></tr><tr><td valign="top"><a href="#process_feedback_packets-3">process_feedback_packets/3</a></td><td></td></tr><tr><td valign="top"><a href="#start-2">start/2</a></td><td>Start a named session as described by the options <code>Opts</code>.</td></tr><tr><td valign="top"><a href="#start_link-2">start_link/2</a></td><td>Start a named session as described by the options <code>Opts</code>.</td></tr><tr><td valign="top"><a href="#stop-1">stop/1</a></td><td>Stop session.</td></tr><tr><td valign="top"><a href="#terminate-3">terminate/3</a></td><td></td></tr></table>


<a name="functions"></a>

## Function Details ##

<a name="code_change-4"></a>

### code_change/4 ###

`code_change(OldVsn, StateName, State, Extra) -> any()`

<a name="connected-2"></a>

### connected/2 ###

`connected(Event, State) -> any()`

<a name="connected-3"></a>

### connected/3 ###

`connected(Event, From, State) -> any()`

<a name="connecting-2"></a>

### connecting/2 ###

`connecting(Event, State) -> any()`

<a name="connecting-3"></a>

### connecting/3 ###

`connecting(Event, From, State) -> any()`

<a name="default_feedback_handler-1"></a>

### default_feedback_handler/1 ###

<pre><code>
default_feedback_handler(TSTok) -&gt; TSTok
</code></pre>

<ul class="definitions"><li><code>TSTok = <a href="#type-fb_rec">fb_rec()</a></code></li></ul>

<a name="disconnecting-2"></a>

### disconnecting/2 ###

`disconnecting(Event, State) -> any()`

<a name="disconnecting-3"></a>

### disconnecting/3 ###

`disconnecting(Event, From, State) -> any()`

<a name="get_state-1"></a>

### get_state/1 ###

<pre><code>
get_state(FsmRef) -&gt; <a href="#type-state">state()</a>
</code></pre>

<ul class="definitions"><li><code>FsmRef = <a href="#type-fsm_ref">fsm_ref()</a></code></li></ul>

<a name="handle_event-3"></a>

### handle_event/3 ###

`handle_event(Event, StateName, State) -> any()`

<a name="handle_info-3"></a>

### handle_info/3 ###

`handle_info(Info, StateName, ?S) -> any()`

<a name="handle_sync_event-4"></a>

### handle_sync_event/4 ###

`handle_sync_event(Event, From, StateName, State) -> any()`

<a name="init-1"></a>

### init/1 ###

`init(X1) -> any()`

<a name="process_feedback_packets-3"></a>

### process_feedback_packets/3 ###

<pre><code>
process_feedback_packets(FBRecs, FBHandler, FakeToken) -&gt; ok
</code></pre>

<ul class="definitions"><li><code>FBRecs = [<a href="#type-fb_rec">fb_rec()</a>]</code></li><li><code>FBHandler = <a href="#type-feedback_handler">feedback_handler()</a></code></li><li><code>FakeToken = undefined | binary()</code></li></ul>

<a name="start-2"></a>

### start/2 ###

<pre><code>
start(Name, Opts) -&gt; {ok, Pid} | ignore | {error, Error}
</code></pre>

<ul class="definitions"><li><code>Name = atom()</code></li><li><code>Opts = <a href="#type-options">options()</a></code></li><li><code>Pid = pid()</code></li><li><code>Error = term()</code></li></ul>

Start a named session as described by the options `Opts`.  The name
`Name` is registered so that the session can be referenced using the name to
call functions like send/3. Note that this function is only used
for testing; see start_link/2.

<a name="start_link-2"></a>

### start_link/2 ###

<pre><code>
start_link(Name, Opts) -&gt; {ok, Pid} | ignore | {error, Error}
</code></pre>

<ul class="definitions"><li><code>Name = atom()</code></li><li><code>Opts = <a href="#type-options">options()</a></code></li><li><code>Pid = pid()</code></li><li><code>Error = term()</code></li></ul>

Start a named session as described by the options `Opts`.  The name
`Name` is registered so that the session can be referenced using the name to
call functions like send/3.

<a name="stop-1"></a>

### stop/1 ###

<pre><code>
stop(FsmRef) -&gt; ok
</code></pre>

<ul class="definitions"><li><code>FsmRef = <a href="#type-fsm_ref">fsm_ref()</a></code></li></ul>

Stop session.

<a name="terminate-3"></a>

### terminate/3 ###

`terminate(Reason, StateName, State) -> any()`

