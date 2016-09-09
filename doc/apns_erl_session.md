

# Module apns_erl_session #
* [Description](#description)
* [Data Types](#types)
* [Function Index](#index)
* [Function Details](#functions)

APNS server session.

Copyright (c) (C) 2012,2013 Silent Circle LLC

__Behaviours:__ [`gen_fsm`](gen_fsm.md).

__Authors:__ Edwin Fine ([`efine@silentcircle.com`](mailto:efine@silentcircle.com)), Sebastien Merle ([`sebastien.merle@silentcircle-llc.com`](mailto:sebastien.merle@silentcircle-llc.com)).

<a name="description"></a>

## Description ##

There must be one session per App Bundle ID and
certificate (Development or Production) combination. Sessions
must have unique (i.e. they are registered) names within the node.

When connecting or disconnecting, all the notifications received by the
session are put in the input queue. When the connection is established,
all the queued notifications are sent to the APNS server.

When failing to connect, the delay between retries will grow exponentially
up to a configurable maximum value. The delay is reset when successfully
reconnecting.

To ensure no error from the APNS server got lost when disconnecting,
the session first shuts down the socket for writes and waits for the server
to disconnect while handling for any error messages. If after some
time the socket did not get closed, the session forces the disconnection.
In any cases, if the history contains notifications at that point, they are
put back into the input queue.

When the session receives an error from APNS servers, it unregisters the
token if relevent, puts back in the input queue all the notifications from
the history received after the notification that generated the error,
then the history is deleted and the session starts the disconnecting
procedure explained earlier.

If the session fail to send a notification to the server, it puts it
back into the input queue and starts the disconnection procedure explained
earlier.

The session will periodically (max time / max history size) send a fake
token to the APNS server to force a checkpoint where we are ensured all
the notifications have been received and accepted.

Process configuration:



<dt><code>host</code>:</dt>




<dd>is hostname of the APNS service as a string.
</dd>




<dt><code>port</code>:</dt>




<dd><p>is the port of the APNS service as an integer.</p><p></p><p>Default value: <code>2195</code>.</p><p></p></dd>




<dt><code>bundle_seed_id</code>:</dt>




<dd>is the APNS bundle seed identifier as a binary.
</dd>




<dt><code>bundle_id</code>:</dt>




<dd>is the APNS bindle identifier as a binary.
</dd>




<dt><code>fake_token</code>:</dt>




<dd>is the fake token used to trigger checkpoints as a binary;
it is very important for this token to be invalid for the specified
APNS configuration or the session history could grow without limit.
In order to not send too suscpicious notifications to APNS the best
approach would be to use a real development environment token in
production and vise versa.
</dd>




<dt><code>retry_delay</code>:</dt>




<dd><p>is the minimum time in milliseconds the session will wait before
reconnecting to APNS servers as an integer; when reconnecting multiple
times this value will be multiplied by 2 for every attempt.</p><p></p><p>Default value: <code>1000</code>.</p><p></p></dd>




<dt><code>retry_max</code>:</dt>




<dd><p>is the maximum amount of time in milliseconds that the session will wait
before reconnecting to the APNS servers.</p><p></p><p>Default value: <code>60000</code>.</p><p></p></dd>




<dt><code>checkpoint_period</code>:</dt>




<dd><p>is the maximum amount of time in milliseconds the session will stay
connected without doing any checkpoint.</p><p></p><p>Default value: <code>600000</code>.</p><p></p></dd>




<dt><code>checkpoint_max</code>:</dt>




<dd><p>is the maximum number of notifications after which a checkpoint is
triggered.</p><p></p><p>Default value: <code>10000</code>.</p><p></p></dd>




<dt><code>close_timeout</code>:</dt>




<dd><p>is the maximum amount of time the session will wait for the APNS server
to close the SSL connection after shutting it down.</p><p></p><p>Default value: <code>5000</code>.</p><p></p></dd>




<dt><code>disable_apns_cert_validation</code>:</dt>




<dd><p><code>true</code> if APNS certificate validation against its bundle id
should be disabled, <code>false</code> if the validation should be done.
This option exists to allow for changes in APNS certificate layout
without having to change code.</p><p></p>Default value: <code>false</code>.
</dd>




<dt><code>ssl_opts</code>:</dt>




<dd>is the property list of SSL options including the certificate file path.
</dd>




<dt><code>feedback_enabled</code>:</dt>




<dd><p>is <code>true</code> if the feedback service should be started, <code>false</code>
otherwise. This allows servers to be configured so that zero
or one server connects to the feedback service. The feedback
service might be going away or become unnecessary with HTTP/2,
and in any case, having more than one server connect to the
feedback service risks losing data.</p><p></p><p>Default value: <code>false</code>.</p><p></p></dd>




<dt><code>feedback_host</code>:</dt>




<dd>Is the hostname of the feedback service; if not specified and
<code>host</code> starts with "gateway." it will be set by replacing it by
"feedback.", if not <code>host</code> will be used as-is.
</dd>




<dt><code>feedback_port</code>:</dt>




<dd><p>is the port number of the feedback service.</p><p></p><p>Default value: <code>2196</code>.</p><p></p></dd>




<dt><code>feedback_retry_delay</code>:</dt>




<dd><p>is the delay in miliseconds the feedback session will wait between
reconnections.</p><p></p><p>Default value: <code>3600000</code>.</p><p></p></dd>



Example:

```
       [{host, "gateway.push.apple.com"},
        {port, 2195},
        {bundle_seed_id, <<"com.example.MyApp">>},
        {bundle_id, <<"com.example.MyApp">>},
        {fake_token, <<"XXXXXX">>},
        {retry_delay, 1000},
        {checkpoint_period, 60000},
        {checkpoint_max, 10000},
        {close_timeout, 5000},
        {disable_apns_cert_validation, false},
        {feedback_enabled, false},
        {feedback_host, "feedback.push.apple.com"},
        {feedback_port, 2196},
        {feedback_retry_delay, 3600000},
        {ssl_opts,
         [{certfile, "/etc/somewhere/certs/com.example.MyApp.cert.pem"},
          {keyfile, "/etc/somewhere/certs/com.example.MyApp.key.unencrypted.pem"}
         ]}
       ]
```


<a name="types"></a>

## Data Types ##




### <a name="type-fsm_ref">fsm_ref()</a> ###


<pre><code>
fsm_ref() = atom() | pid()
</code></pre>




### <a name="type-option">option()</a> ###


<pre><code>
option() = {host, string()} | {port, non_neg_integer} | {bundle_seed_id, binary()} | {bundle_id, binary()} | {ssl_opts, list()} | {fake_token, binary()} | {retry_delay, non_neg_integer()} | {retry_max, pos_integer()} | {checkpoint_period, non_neg_integer()} | {checkpoint_max, non_neg_integer()} | {close_timeout, non_neg_integer()} | {feedback_enabled, boolean()} | {feedback_host, string()} | {feedback_port, non_neg_integer()} | {feedback_retry_delay, non_neg_integer()}
</code></pre>




### <a name="type-options">options()</a> ###


<pre><code>
options() = [<a href="#type-option">option()</a>]
</code></pre>

<a name="index"></a>

## Function Index ##


<table width="100%" border="1" cellspacing="0" cellpadding="2" summary="function index"><tr><td valign="top"><a href="#async_send-3">async_send/3</a></td><td>Equivalent to <a href="#async_send-4"><tt>async_send(FsmRef, 2147483647, Token, JSON)</tt></a>.</td></tr><tr><td valign="top"><a href="#async_send-4">async_send/4</a></td><td>Send a push notification asynchronously.</td></tr><tr><td valign="top"><a href="#async_send-5">async_send/5</a></td><td>Send a push notification asynchronously.</td></tr><tr><td valign="top"><a href="#code_change-4">code_change/4</a></td><td></td></tr><tr><td valign="top"><a href="#connected-2">connected/2</a></td><td></td></tr><tr><td valign="top"><a href="#connected-3">connected/3</a></td><td></td></tr><tr><td valign="top"><a href="#connecting-2">connecting/2</a></td><td></td></tr><tr><td valign="top"><a href="#connecting-3">connecting/3</a></td><td></td></tr><tr><td valign="top"><a href="#disconnecting-2">disconnecting/2</a></td><td></td></tr><tr><td valign="top"><a href="#disconnecting-3">disconnecting/3</a></td><td></td></tr><tr><td valign="top"><a href="#get_state-1">get_state/1</a></td><td></td></tr><tr><td valign="top"><a href="#handle_event-3">handle_event/3</a></td><td></td></tr><tr><td valign="top"><a href="#handle_info-3">handle_info/3</a></td><td></td></tr><tr><td valign="top"><a href="#handle_sync_event-4">handle_sync_event/4</a></td><td></td></tr><tr><td valign="top"><a href="#init-1">init/1</a></td><td></td></tr><tr><td valign="top"><a href="#send-3">send/3</a></td><td>Equivalent to <a href="#send-4"><tt>send(FsmRef, 2147483647, Token, JSON)</tt></a>.</td></tr><tr><td valign="top"><a href="#send-4">send/4</a></td><td>Send a notification specified by APS <code>JSON</code> to <code>Token</code> via
<code>FsmRef</code>.</td></tr><tr><td valign="top"><a href="#send-5">send/5</a></td><td>Send a notification specified by APS <code>JSON</code> to <code>Token</code> via
<code>FsmRef</code>.</td></tr><tr><td valign="top"><a href="#start-2">start/2</a></td><td>Start a named session as described by the options <code>Opts</code>.</td></tr><tr><td valign="top"><a href="#start_link-2">start_link/2</a></td><td>Start a named session as described by the options <code>Opts</code>.</td></tr><tr><td valign="top"><a href="#stop-1">stop/1</a></td><td>Stop session.</td></tr><tr><td valign="top"><a href="#terminate-3">terminate/3</a></td><td></td></tr></table>


<a name="functions"></a>

## Function Details ##

<a name="async_send-3"></a>

### async_send/3 ###

<pre><code>
async_send(FsmRef, Token, JSON) -&gt; ok
</code></pre>

<ul class="definitions"><li><code>FsmRef = <a href="#type-fsm_ref">fsm_ref()</a></code></li><li><code>Token = binary()</code></li><li><code>JSON = binary()</code></li></ul>

Equivalent to [`async_send(FsmRef, 2147483647, Token, JSON)`](#async_send-4).

<a name="async_send-4"></a>

### async_send/4 ###

<pre><code>
async_send(FsmRef, Expiry, Token, JSON) -&gt; ok
</code></pre>

<ul class="definitions"><li><code>FsmRef = <a href="#type-fsm_ref">fsm_ref()</a></code></li><li><code>Expiry = non_neg_integer()</code></li><li><code>Token = binary()</code></li><li><code>JSON = binary()</code></li></ul>

Send a push notification asynchronously. See send/4 for details.

<a name="async_send-5"></a>

### async_send/5 ###

<pre><code>
async_send(FsmRef, Expiry, Token, JSON, Prio) -&gt; ok
</code></pre>

<ul class="definitions"><li><code>FsmRef = <a href="#type-fsm_ref">fsm_ref()</a></code></li><li><code>Expiry = non_neg_integer()</code></li><li><code>Token = binary()</code></li><li><code>JSON = binary()</code></li><li><code>Prio = non_neg_integer()</code></li></ul>

Send a push notification asynchronously. See send/5 for details.

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

<a name="disconnecting-2"></a>

### disconnecting/2 ###

`disconnecting(Event, State) -> any()`

<a name="disconnecting-3"></a>

### disconnecting/3 ###

`disconnecting(Event, From, State) -> any()`

<a name="get_state-1"></a>

### get_state/1 ###

`get_state(FsmRef) -> any()`

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

<a name="send-3"></a>

### send/3 ###

<pre><code>
send(FsmRef, Token, JSON) -&gt; {ok, undefined | Seq} | {error, Reason}
</code></pre>

<ul class="definitions"><li><code>FsmRef = <a href="#type-fsm_ref">fsm_ref()</a></code></li><li><code>Token = binary()</code></li><li><code>JSON = binary()</code></li><li><code>Seq = non_neg_integer()</code></li><li><code>Reason = term()</code></li></ul>

Equivalent to [`send(FsmRef, 2147483647, Token, JSON)`](#send-4).

<a name="send-4"></a>

### send/4 ###

<pre><code>
send(FsmRef, Expiry, Token, JSON) -&gt; {ok, undefined | Seq} | {error, Reason}
</code></pre>

<ul class="definitions"><li><code>FsmRef = <a href="#type-fsm_ref">fsm_ref()</a></code></li><li><code>Expiry = non_neg_integer()</code></li><li><code>Token = binary()</code></li><li><code>JSON = binary()</code></li><li><code>Seq = non_neg_integer()</code></li><li><code>Reason = term()</code></li></ul>

Send a notification specified by APS `JSON` to `Token` via
`FsmRef`. Expire the notification after the epoch `Expiry`.
For JSON format, see
[
Local and Push Notification Programming Guide
](https://developer.apple.com/library/ios/#documentation/NetworkingInternet/Conceptual/RemoteNotificationsPG/) (requires Apple Developer login).

It the notification has been sent to an APNS server, the function returns
its sequence number, if it has been queued but could not be sent before
the default timeout (5000 ms) it returns undefined.

<a name="send-5"></a>

### send/5 ###

<pre><code>
send(FsmRef, Expiry, Token, JSON, Prio) -&gt; {ok, undefined | Seq} | {error, Reason}
</code></pre>

<ul class="definitions"><li><code>FsmRef = <a href="#type-fsm_ref">fsm_ref()</a></code></li><li><code>Expiry = non_neg_integer()</code></li><li><code>Token = binary()</code></li><li><code>JSON = binary()</code></li><li><code>Prio = non_neg_integer()</code></li><li><code>Seq = non_neg_integer()</code></li><li><code>Reason = term()</code></li></ul>

Send a notification specified by APS `JSON` to `Token` via
`FsmRef`. Expire the notification after the epoch `Expiry`.
Set the priority to a valid value of `Prio` (currently 5 or 10,
10 may not be used to push notifications without alert, badge or sound.

See
[
Local and Push Notification Programming Guide
](https://developer.apple.com/library/ios/#documentation/NetworkingInternet/Conceptual/RemoteNotificationsPG/).

If the notification has been sent to an APNS server, the function returns
its sequence number, if it has been queued but could not be sent before
the default timeout (5000 ms) it returns undefined.

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

