%%% ==========================================================================
%%% Copyright 2012-2016 Silent Circle
%%%
%%% Licensed under the Apache License, Version 2.0 (the "License");
%%% you may not use this file except in compliance with the License.
%%% You may obtain a copy of the License at
%%%
%%%     http://www.apache.org/licenses/LICENSE-2.0
%%%
%%% Unless required by applicable law or agreed to in writing, software
%%% distributed under the License is distributed on an "AS IS" BASIS,
%%% WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
%%% See the License for the specific language governing permissions and
%%% limitations under the License.
%%% ==========================================================================

%%%-------------------------------------------------------------------
%%% @author Edwin Fine <efine@silentcircle.com>
%%% @author Sebastien Merle <sebastien.merle@silentcircle-llc.com>
%%% @copyright (C) 2012,2013 Silent Circle LLC
%%% @doc
%%% APNS server session. There must be one session per App Bundle ID and
%%% certificate (Development or Production) combination. Sessions
%%% must have unique (i.e. they are registered) names within the node.
%%%
%%% When connecting or disconnecting, all the notifications received by the
%%% session are put in the input queue. When the connection is established,
%%% all the queued notifications are sent to the APNS server.
%%%
%%% When failing to connect, the delay between retries will grow exponentially
%%% up to a configurable maximum value. The delay is reset when successfully
%%% reconnecting.
%%%
%%% To ensure no error from the APNS server got lost when disconnecting,
%%% the session first shuts down the socket for writes and waits for the server
%%% to disconnect while handling for any error messages. If after some
%%% time the socket did not get closed, the session forces the disconnection.
%%% In any cases, if the history contains notifications at that point, they are
%%% put back into the input queue.
%%%
%%% When the session receives an error from APNS servers, it unregisters the
%%% token if relevent, puts back in the input queue all the notifications from
%%% the history received after the notification that generated the error,
%%% then the history is deleted and the session starts the disconnecting
%%% procedure explained earlier.
%%%
%%% If the session fail to send a notification to the server, it puts it
%%% back into the input queue and starts the disconnection procedure explained
%%% earlier.
%%%
%%% The session will periodically (max time / max history size) send a fake
%%% token to the APNS server to force a checkpoint where we are ensured all
%%% the notifications have been received and accepted.
%%%
%%% Process configuration:
%%% <dl>
%%% <dt>`host':</dt>
%%% <dd>is hostname of the APNS service as a string.
%%% </dd>
%%% <dt>`port':</dt>
%%% <dd>is the port of the APNS service as an integer.
%%%
%%%     Default value: `2195'.
%%%
%%% </dd>
%%% <dt>`bundle_seed_id':</dt>
%%% <dd>is the APNS bundle seed identifier as a binary.
%%% </dd>
%%% <dt>`bundle_id':</dt>
%%% <dd>is the APNS bindle identifier as a binary.
%%% </dd>
%%% <dt>`fake_token':</dt>
%%% <dd>is the fake token used to trigger checkpoints as a binary;
%%%     it is very important for this token to be invalid for the specified
%%%     APNS configuration or the session history could grow without limit.
%%%     In order to not send too suscpicious notifications to APNS the best
%%%     approach would be to use a real development environment token in
%%%     production and vise versa.
%%% </dd>
%%% <dt>`retry_delay':</dt>
%%% <dd>is the minimum time in milliseconds the session will wait before
%%%     reconnecting to APNS servers as an integer; when reconnecting multiple
%%%     times this value will be multiplied by 2 for every attempt.
%%%
%%%     Default value: `1000'.
%%%
%%% </dd>
%%% <dt>`retry_max':</dt>
%%% <dd>is the maximum amount of time in milliseconds that the session will wait
%%%     before reconnecting to the APNS servers.
%%%
%%%     Default value: `60000'.
%%%
%%% </dd>
%%% <dt>`checkpoint_period':</dt>
%%% <dd>is the maximum amount of time in milliseconds the session will stay
%%%     connected without doing any checkpoint.
%%%
%%%     Default value: `600000'.
%%%
%%% </dd>
%%% <dt>`checkpoint_max':</dt>
%%% <dd>is the maximum number of notifications after which a checkpoint is
%%%     triggered.
%%%
%%%     Default value: `10000'.
%%%
%%% </dd>
%%% <dt>`close_timeout':</dt>
%%% <dd>is the maximum amount of time the session will wait for the APNS server
%%%     to close the SSL connection after shutting it down.
%%%
%%%     Default value: `5000'.
%%%
%%% </dd>
%%% <dt>`disable_apns_cert_validation':</dt>
%%% <dd>`true' if APNS certificate validation against its bundle id
%%%     should be disabled, `false' if the validation should be done.
%%%     This option exists to allow for changes in APNS certificate layout
%%%     without having to change code.
%%%
%%%     Default value: `false'.
%%% </dd>
%%% <dt>`ssl_opts':</dt>
%%% <dd>is the property list of SSL options including the certificate file path.
%%% </dd>
%%% <dt>`feedback_enabled':</dt>
%%% <dd>is `true' if the feedback service should be started, `false'
%%%     otherwise. This allows servers to be configured so that zero
%%%     or one server connects to the feedback service. The feedback
%%%     service might be going away or become unnecessary with HTTP/2,
%%%     and in any case, having more than one server connect to the
%%%     feedback service risks losing data.
%%%
%%%     Default value: `false'.
%%%
%%% </dd>
%%% <dt>`feedback_host':</dt>
%%% <dd>Is the hostname of the feedback service; if not specified and
%%%     `host' starts with "gateway." it will be set by replacing it by
%%%     "feedback.", if not `host' will be used as-is.
%%% </dd>
%%% <dt>`feedback_port':</dt>
%%% <dd>is the port number of the feedback service.
%%%
%%%     Default value: `2196'.
%%%
%%% </dd>
%%% <dt>`feedback_retry_delay':</dt>
%%% <dd>is the delay in miliseconds the feedback session will wait between
%%%     reconnections.
%%%
%%%     Default value: `3600000'.
%%%
%%% </dd>
%%% </dl>
%%%
%%% Example:
%%% ```
%%%     [{host, "gateway.push.apple.com"},
%%%      {port, 2195},
%%%      {bundle_seed_id, <<"com.example.MyApp">>},
%%%      {bundle_id, <<"com.example.MyApp">>},
%%%      {fake_token, <<"XXXXXX">>},
%%%      {retry_delay, 1000},
%%%      {checkpoint_period, 60000},
%%%      {checkpoint_max, 10000},
%%%      {close_timeout, 5000},
%%%      {disable_apns_cert_validation, false},
%%%      {feedback_enabled, false},
%%%      {feedback_host, "feedback.push.apple.com"},
%%%      {feedback_port, 2196},
%%%      {feedback_retry_delay, 3600000},
%%%      {ssl_opts,
%%%       [{certfile, "/etc/somewhere/certs/com.example.MyApp.cert.pem"},
%%%        {keyfile, "/etc/somewhere/certs/com.example.MyApp.key.unencrypted.pem"}
%%%       ]}
%%%     ]
%%% '''
%%%
%%% @end
%%%-------------------------------------------------------------------
-module(apns_erl_session).

-behaviour(gen_fsm).


%%% ==========================================================================
%%% Includes
%%% ==========================================================================

-include_lib("lager/include/lager.hrl").
-include_lib("stdlib/include/ms_transform.hrl").


%%% ==========================================================================
%%% Exports
%%% ==========================================================================

%%% API Functions
-export([start/2,
         start_link/2,
         stop/1,
         send/3,
         send/4,
         send/5,
         async_send/3,
         async_send/4,
         async_send/5
     ]).

%%% Debugging Functions
-export([get_state/1]).

%%% Behaviour gen_fsm standard callbacks
-export([init/1,
         handle_event/3,
         handle_sync_event/4,
         handle_info/3,
         terminate/3,
         code_change/4]).

%%% Behaviour gen_fsm states callbacks
-export([connecting/2, connecting/3,
         connected/2, connected/3,
         disconnecting/2, disconnecting/3]).


%%% ==========================================================================
%%% Macros
%%% ==========================================================================

-define(S, ?MODULE).

%% Valid APNS priority values
-define(PRIO_IMMEDIATE,     10).
-define(PRIO_CONSERVE_POWER, 5).

-define(SEQ_MAX, 16#FFFFFFFF). % APNS supports 4 bytes
-define(DEFAULT_APNS_PORT, 2195).
-define(DEFAULT_RETRY_DELAY, 1000).
-define(DEFAULT_RETRY_MAX, 60*1000).
-define(DEFAULT_EXPIRY_TIME, 16#7FFFFFFF). % INT_MAX, 32 bits
-define(DEFAULT_CHECKPOINT_PERIOD, 10*60*1000).
-define(DEFAULT_CHECKPOINT_MAX, 10000).
-define(DEFAULT_CLOSE_TIMEOUT, 5000).
-define(DEFAULT_PRIO, ?PRIO_IMMEDIATE).

-define(CHECKPOINT_TIME_THRESHOLD, 1000).
-define(FAKE_EXPIRY_TIME, 16#7FFFFFFF).
-define(FAKE_PAYLOAD, <<"{\"aps\":{\"alert\":\"Notification\"}}">>).

-ifdef(namespaced_queues).
-type sc_queue() :: queue:queue().
-else.
-type sc_queue() :: queue().
-endif.

%%% ==========================================================================
%%% Records
%%% ==========================================================================

%%% Process state
-record(?S,
        {name               = undefined                  :: atom(),
         last_seq           = 0                          :: non_neg_integer(),
         host               = ""                         :: string(),
         port               = ?DEFAULT_APNS_PORT         :: non_neg_integer(),
         bundle_seed_id     = <<>>                       :: binary(),
         bundle_id          = <<>>                       :: binary(),
         ssl_opts           = []                         :: list(),
         sock               = undefined                  :: term(),
         feedback_name      = undefined                  :: atom(),
         feedback_enabled   = false                      :: boolean(),
         feedback_opts      = []                         :: list(),
         feedback_pid       = undefined                  :: pid() | undefined,
         retry_delay        = ?DEFAULT_RETRY_DELAY       :: non_neg_integer(),
         retry_max          = ?DEFAULT_RETRY_MAX         :: non_neg_integer(),
         retry_ref          = undefined                  :: reference() | undefined,
         retries            = 1                          :: non_neg_integer(),
         history            = undefined                  :: ets:tab() | undefined,
         history_size       = 0                          :: non_neg_integer(),
         fake_token         = <<>>                       :: binary(),
         queue              = undefined                  :: sc_queue() | undefined,
         stop_callers       = []                         :: list(),
         close_timeout      = ?DEFAULT_CLOSE_TIMEOUT     :: non_neg_integer(),
         close_ref          = undefined                  :: reference() | undefined,
         checkpoint_ref     = undefined                  :: reference() | undefined,
         checkpoint_seq     = undefined                  :: non_neg_integer() | undefined,
         checkpoint_period  = ?DEFAULT_CHECKPOINT_PERIOD :: non_neg_integer(),
         checkpoint_max     = ?DEFAULT_CHECKPOINT_MAX    :: non_neg_integer(),
         checkpoint_pending = false                      :: boolean(),
         checkpoint_time    = undefined                  :: erlang:timestamp() | undefined
        }).

%% Notification
-record(nf,
        {seq            = 0                      :: non_neg_integer(),
         expiry         = 0                      :: non_neg_integer(),
         token          = <<>>                   :: binary(),
         json           = <<>>                   :: binary(),
         from           = undefined              :: term(),
         prio           = ?DEFAULT_PRIO          :: non_neg_integer()
        }).

%% Note on prio field.
%%
%% Apple documentation states:
%%
%% The remote notification must trigger an alert, sound, or badge on the
%% device. It is an error to use this priority for a push that contains only
%% the content-available key.

%%% ==========================================================================
%%% Types
%%% ==========================================================================

-type state() :: #?S{}.

-type state_name() :: connecting | connected | disconnecting.

-type option() :: {host, string()} |
                  {port, non_neg_integer} |
                  {bundle_seed_id, binary()} |
                  {bundle_id, binary()} |
                  {ssl_opts, list()} |
                  {fake_token, binary()} |
                  {retry_delay, non_neg_integer()} |
                  {retry_max, pos_integer()} |
                  {checkpoint_period, non_neg_integer()} |
                  {checkpoint_max, non_neg_integer()} |
                  {close_timeout, non_neg_integer()} |
                  {feedback_enabled, boolean()} |
                  {feedback_host, string()} |
                  {feedback_port, non_neg_integer()} |
                  {feedback_retry_delay, non_neg_integer()}.

-type options() :: [option()].

-type fsm_ref() :: atom() | pid().
-type nf() :: #nf{}.
-type bstrtok() :: binary(). %% binary of string rep of APNS token.

%%% ==========================================================================
%%% API Functions
%%% ==========================================================================

%%--------------------------------------------------------------------
%% @doc Start a named session as described by the options `Opts'.  The name
%% `Name' is registered so that the session can be referenced using the name to
%% call functions like send/3. Note that this function is only used
%% for testing; see start_link/2.
%% @end
%%--------------------------------------------------------------------

-spec start(Name, Opts) -> {ok, Pid} | ignore | {error, Error}
    when Name :: atom(), Opts :: options(), Pid :: pid(), Error :: term().

start(Name, Opts) when is_atom(Name), is_list(Opts) ->
    gen_fsm:start({local, Name}, ?MODULE, [Name, Opts], []).


%%--------------------------------------------------------------------
%% @doc Start a named session as described by the options `Opts'.  The name
%% `Name' is registered so that the session can be referenced using the name to
%% call functions like send/3.
%% @end
%%--------------------------------------------------------------------

-spec start_link(Name, Opts) -> {ok, Pid} | ignore | {error, Error}
    when Name :: atom(), Opts :: options(), Pid :: pid(), Error :: term().

start_link(Name, Opts) when is_atom(Name), is_list(Opts) ->
    gen_fsm:start_link({local, Name}, ?MODULE, [Name, Opts], []).


%%--------------------------------------------------------------------
%% @doc Stop session.
%% @end
%%--------------------------------------------------------------------

-spec stop(FsmRef) -> ok
    when FsmRef :: fsm_ref().

stop(FsmRef) ->
    gen_fsm:sync_send_all_state_event(FsmRef, stop).


%%--------------------------------------------------------------------
%% @doc
%% @equiv async_send(FsmRef, 16#7FFFFFFF, Token, JSON)
%% @end
%%--------------------------------------------------------------------

-spec async_send(FsmRef, Token, JSON) -> ok
    when FsmRef :: fsm_ref(), Token :: binary(), JSON :: binary().

async_send(FsmRef, Token, JSON) when is_binary(Token), is_binary(JSON) ->
    async_send(FsmRef, ?DEFAULT_EXPIRY_TIME, Token, JSON).


%%--------------------------------------------------------------------
%% @doc Send a push notification asynchronously. See send/4 for details.
%% @end
%%--------------------------------------------------------------------

-spec async_send(FsmRef, Expiry, Token, JSON) -> ok
    when FsmRef :: fsm_ref(), Expiry :: non_neg_integer(),
         Token :: binary(), JSON :: binary().

async_send(FsmRef, Expiry, Token, JSON) ->
    async_send(FsmRef, Expiry, Token, JSON, ?DEFAULT_PRIO).

%%--------------------------------------------------------------------
%% @doc Send a push notification asynchronously. See send/5 for details.
%% @end
%%--------------------------------------------------------------------

-spec async_send(FsmRef, Expiry, Token, JSON, Prio) -> ok
    when FsmRef :: fsm_ref(), Expiry :: non_neg_integer(),
         Token :: binary(), JSON :: binary(), Prio :: non_neg_integer().

async_send(FsmRef, Expiry, Token, JSON, Prio) when is_integer(Expiry),
                                                   is_binary(Token),
                                                   is_binary(JSON),
                                                   is_integer(Prio) ->
    gen_fsm:send_event(FsmRef, {send, Expiry, Token, JSON, Prio}).



%%--------------------------------------------------------------------
%% @doc
%% @equiv send(FsmRef, 16#7FFFFFFF, Token, JSON)
%% @end
%%--------------------------------------------------------------------

-spec send(FsmRef, Token, JSON) -> {ok, undefined | Seq} | {error, Reason}
    when FsmRef :: fsm_ref(), Token :: binary(),
         JSON :: binary(), Seq :: non_neg_integer(), Reason :: term().

send(FsmRef, Token, JSON) when is_binary(Token), is_binary(JSON) ->
    send(FsmRef, ?DEFAULT_EXPIRY_TIME, Token, JSON).


%%--------------------------------------------------------------------
%% @doc Send a notification specified by APS `JSON' to `Token' via
%% `FsmRef'. Expire the notification after the epoch `Expiry'.
%% For JSON format, see
%% <a href="https://developer.apple.com/library/ios/#documentation/NetworkingInternet/Conceptual/RemoteNotificationsPG/">
%% Local and Push Notification Programming Guide
%% </a> (requires Apple Developer login).
%%
%% It the notification has been sent to an APNS server, the function returns
%% its sequence number, if it has been queued but could not be sent before
%% the default timeout (5000 ms) it returns undefined.
%% @end
%%--------------------------------------------------------------------

-spec send(FsmRef, Expiry, Token, JSON) -> {ok, undefined | Seq} | {error, Reason}
    when FsmRef :: fsm_ref(), Expiry :: non_neg_integer(),
         Token :: binary(), JSON :: binary(),
         Seq :: non_neg_integer(), Reason :: term().

send(FsmRef, Expiry, Token, JSON) ->
    send(FsmRef, Expiry, Token, JSON, ?DEFAULT_PRIO).

%%--------------------------------------------------------------------
%% @doc Send a notification specified by APS `JSON' to `Token' via
%% `FsmRef'. Expire the notification after the epoch `Expiry'.
%% Set the priority to a valid value of `Prio' (currently 5 or 10,
%% 10 may not be used to push notifications without alert, badge or sound.
%%
%% See
%% <a href="https://developer.apple.com/library/ios/#documentation/NetworkingInternet/Conceptual/RemoteNotificationsPG/">
%% Local and Push Notification Programming Guide
%% </a>.
%%
%% If the notification has been sent to an APNS server, the function returns
%% its sequence number, if it has been queued but could not be sent before
%% the default timeout (5000 ms) it returns undefined.
%% @end
%%--------------------------------------------------------------------

-spec send(FsmRef, Expiry, Token, JSON, Prio) -> {ok, undefined | Seq} | {error, Reason}
    when FsmRef :: fsm_ref(), Expiry :: non_neg_integer(),
         Token :: binary(), JSON :: binary(), Prio :: non_neg_integer(),
         Seq :: non_neg_integer(), Reason :: term().

send(FsmRef, Expiry, Token, JSON, Prio) when is_integer(Expiry),
                                        is_binary(Token),
                                        is_binary(JSON),
                                        is_integer(Prio) ->
    try
        gen_fsm:sync_send_event(FsmRef, {send, Expiry, Token, JSON, Prio})
    catch
        exit:{timeout, _} -> {ok, undefined}
    end.



%%% ==========================================================================
%%% Debugging Functions
%%% ==========================================================================

get_state(FsmRef) ->
    gen_fsm:sync_send_all_state_event(FsmRef, get_state).


%%% ==========================================================================
%%% Behaviour gen_fsm Standard Functions
%%% ==========================================================================

init([Name, Opts]) ->
    lager:info("APNS session ~p started", [Name]),
    try
        process_flag(trap_exit, true),
        State = init_queue(init_history(init_state(Name, Opts))),
        bootstrap(start_feedback(State))
    catch
        _What:Why ->
            {stop, {Why, erlang:get_stacktrace()}}
    end.


handle_event(Event, StateName, State) ->
    lager:warning("Received unexpected event while ~p: ~p", [StateName, Event]),
    continue(StateName, State).


handle_sync_event(stop, _From, connecting, State) ->
    stop(connecting, normal, ok, State);

handle_sync_event(stop, From, disconnecting, #?S{stop_callers = L} = State) ->
    continue(disconnecting, State#?S{stop_callers = [From |L]});

handle_sync_event(stop, From, StateName, #?S{stop_callers = L} = State) ->
    next(StateName, disconnecting, State#?S{stop_callers = [From | L]});

handle_sync_event(get_state, _From, StateName, State) ->
    reply({ok, State}, StateName, State);

handle_sync_event(Event, {Pid, _Tag}, StateName, State) ->
    lager:warning("Received unexpected event from ~p while ~p: ~p",
                  [Pid, StateName, Event]),
    reply({error, invalid_event}, StateName, State).


handle_info({ssl, Socket, Data}, connected, #?S{sock = Socket} = State) ->
    case process_apns_resp(Data, State) of
        {continue, NewState} -> continue(connected, NewState);
        {disconnect, NewState} -> next(connected, disconnecting, NewState)
    end;

handle_info({ssl, Socket, Data}, disconnecting, #?S{sock = Socket} = State) ->
    case process_apns_resp(Data, State) of
        {continue, NewState} -> continue(disconnecting, NewState);
        {disconnect, NewState} -> continue(disconnecting, NewState)
    end;

handle_info({ssl, Socket, _Data}, StateName, State) ->
    lager:warning("Received data from unknown socket while ~p: ~p",
                  [StateName, Socket]),
    continue(StateName, State);

handle_info({ssl_closed, Socket}, StateName, #?S{sock = Socket} = State) ->
    lager:debug("SSL socket ~p closed by peer", [Socket]),
    handle_connection_closure(StateName, State);

handle_info({ssl_closed, Socket}, StateName, State) ->
    lager:warning("Received close message from the unknown socket ~p while ~p",
                  [Socket, StateName]),
    continue(StateName, State);

handle_info({ssl_error, Socket, Reason}, StateName, #?S{sock = Socket} = State) ->
    lager:error("SSL error on socket ~p while ~p: ~p",
                [Socket, StateName, Reason]),
    continue(StateName, State);

handle_info({ssl_error, Socket, Reason}, StateName, State) ->
    lager:warning("Received SSL error from the unknown socket ~p while ~p: ~p",
                  [Socket, StateName, Reason]),
    continue(StateName, State);

handle_info({'EXIT', Pid, Reason}, StateName, #?S{feedback_pid = Pid} = State) ->
    lager:error("APNS feedback handler died while ~p: ~p",
                [StateName, Reason]),
    continue(StateName, start_feedback(State#?S{feedback_pid = undefined}));

handle_info({'EXIT', Pid, Reason}, StateName, State) ->
    lager:error("Unknown process ~p died while ~p: ~p",
                [Pid, StateName, Reason]),
    continue(StateName, State);

handle_info(Info, StateName, State) ->
    lager:warning("Unexpected message received in state ~p: ~p",
                  [StateName, Info]),
    continue(StateName, State).


terminate(Reason, StateName, State) ->
    WaitingCallers = State#?S.stop_callers,
    % Mostly to know how many unconfirmed notifications we have:
    NewState = recover_history(State),
    lager:info("APNS session ~p terminated in state ~p with ~w queued "
               "notifications: ~p",
               [NewState#?S.name, StateName, queue_length(NewState), Reason]),
    % Notify all senders that the notifications will not be sent.
    _ = [failure_callback(N, terminated) || N <- queue:to_list(State#?S.queue)],
    % Cleanup all we can.
    terminate_queue(terminate_history(stop_feedback(NewState))),
    % Notify the process wanting us dead.
    _ = [gen_fsm:reply(C, ok) || C <- WaitingCallers],
    ok.


code_change(_OldVsn, StateName, State, _Extra) ->
    {ok, StateName, State}.


%%% ==========================================================================
%%% Behaviour gen_fsm State Functions
%%% ==========================================================================

%% -----------------------------------------------------------------
%% Connecting State
%% -----------------------------------------------------------------

connecting({send, Expiry, Token, JSON, Prio}, State) ->
    {Nf, NewState} = next_nf(Expiry, Token, JSON, Prio, undefined, State),
    continue(connecting, queue_notification(Nf, NewState));

connecting(connect, State) ->
    #?S{name = Name, host = Host, port = Port, ssl_opts = Opts} = State,
    lager:info("APNS session ~p connecting to ~s:~w", [Name, Host, Port]),
    case apns_connect(Host, Port, Opts) of
        {ok, Socket} ->
            lager:info("APNS session ~p connected to ~s:~w on SSL socket ~p",
                       [Name, Host, Port, Socket]),
            next(connecting, connected, State#?S{sock = Socket});
        {error, Reason} ->
            lager:error("APNS session ~p failed to connect to ~s:~w : ~p",
                        [Name, Host, Port, Reason]),
            next(connecting, connecting, State)
    end;

connecting(Event, State) ->
    handle_event(Event, connecting, State).


connecting({send, Expiry, Token, JSON, Prio}, From, State) ->
    {Nf, NewState} = next_nf(Expiry, Token, JSON, Prio, From, State),
    continue(connecting, queue_notification(Nf, NewState));

connecting(Event, From, State) ->
    handle_sync_event(Event, From, connecting, State).


%% -----------------------------------------------------------------
%% Connected State
%% -----------------------------------------------------------------

connected(checkpoint, State) ->
    continue(connected, maybe_checkpoint(State));

connected(flush, State) ->
    case flush_queued_notifications(State) of
        {ok, NewState} -> continue(connected, NewState);
        {error, NewState} -> next(connected, disconnecting, NewState)
    end;

connected({send, Expiry, Token, JSON, Prio}, State) ->
    case send_notification(Expiry, Token, JSON, Prio, undefined, State) of
        {ok, _Seq, NewState} ->
            continue(connected, NewState);
        {error, _Seq, NewState} ->
            next(connected, disconnecting, NewState)
    end;

connected(Event, State) ->
    handle_event(Event, connected, State).


connected({send, Expiry, Token, JSON, Prio}, From, State) ->
    case send_notification(Expiry, Token, JSON, Prio, From, State) of
        {ok, Seq, NewState} ->
            reply({ok, Seq}, connected, NewState);
        {error, _Seq, NewState} ->
            next(connected, disconnecting, NewState)
    end;

connected(Event, From, State) ->
    handle_sync_event(Event, From, connected, State).


%% -----------------------------------------------------------------
%% Disconnecting State
%% -----------------------------------------------------------------

disconnecting({send, Expiry, Token, JSON, Prio}, State) ->
    {Nf, NewState} = next_nf(Expiry, Token, JSON, Prio, undefined, State),
    continue(disconnecting, queue_notification(Nf, NewState));

disconnecting(disconnect, State) ->
    catch ssl:shutdown(State#?S.sock, write),
    continue(disconnecting, State);

disconnecting(timeout, State) ->
    lager:warning("APNS session ~p was forced to close the SSL socket ~p",
                  [State#?S.name, State#?S.sock]),
    handle_connection_closure(disconnecting, State);

disconnecting(Event, State) ->
    handle_event(Event, disconnecting, State).


disconnecting({send, Expiry, Token, JSON, Prio}, From, State) ->
    {Nf, NewState} = next_nf(Expiry, Token, JSON, Prio, From, State),
    continue(disconnecting, queue_notification(Nf, NewState));

disconnecting(Event, From, State) ->
    handle_sync_event(Event, From, disconnecting, State).


%%% ==========================================================================
%%% Internal Functions
%%% ==========================================================================

%% This returns {continue, State} when we expect APNS to disconnect us.
%% It only returns {disconnect, State} if we want to disconnect ourselves.
process_apns_resp(Data, State) ->
    #?S{name = Name, checkpoint_seq = CheckpointSeq} = State,
    case apns_decode_message(Data) of
        ok ->
            {continue, State};
        {error, Reason} ->
            lager:error("APNS session ~p failed decoding message: ~p",
                        [Name, Reason]),
            {disconnect, State};
        {bad_nf, invalid_token, CheckpointSeq} ->
            lager:info("APNS session ~p confirmed reception of checkpoint ~w",
                       [Name, CheckpointSeq]),
            {continue, recover_history_after(CheckpointSeq, State)};
        {bad_nf, Status, Seq} ->
            case {Status, history_get(Seq, State)} of
                {_, undefined} ->
                    lager:error("APNS session ~p received an error ~p for "
                                "the unknown notification ~w",
                                [Name, Status, Seq]),
                    {continue, State};
                {invalid_token, #nf{token = Token} = Nf} ->
                    lager:error("APNS session ~p has been notified that the "
                                "notification ~w with token ~s is invalid",
                                [Name, Seq, tok_s(Token)]),
                    apns_deregister_token(Token),
                    failure_callback(Nf, Status),
                    {continue, recover_history_after(Seq, State)};
                {shutdown, #nf{token = Token}} ->
                    lager:warning("APNS reported it is shutting down this "
                                  "connection so we need to disconnect and "
                                  "reconnect. The last notification delivered "
                                  "successfully is seq ~w with token ~s",
                                  [Seq, tok_s(Token)]),
                    %% We must disconnect and redeliver all notifications after Seq.
                    %% This isn't a failure, so no failure callback.
                    {disconnect, recover_history_after(Seq, State)};
                {_, #nf{} = Nf} ->
                    lager:error("APNS session ~p received error ~p for the "
                                "notification ~w", [Name, Status, Seq]),
                    failure_callback(Nf, Status),
                    {continue, recover_history_after(Seq, State)}
            end
    end.


flush_queued_notifications(#?S{queue = Queue} = State) ->
    Now = sc_util:posix_time(),
    case queue:out(Queue) of
        {empty, NewQueue} ->
            {ok, State#?S{queue = NewQueue}};
        {{value, #nf{expiry = Exp} = Nf}, NewQueue} when Exp > Now ->
            case send_notification(Nf, State#?S{queue = NewQueue}) of
                {error, _Seq, NewState} ->
                    {error, NewState};
                {ok, _Seq, NewState} ->
                    success_callback(Nf),
                    flush_queued_notifications(NewState)
            end;
        {{value, #nf{} = Nf}, NewQueue} ->
            lager:debug("Notification ~p with token ~s expired",
                        [Nf#nf.seq, tok_s(Nf)]),
            failure_callback(Nf, expired),
            flush_queued_notifications(State#?S{queue = NewQueue})
    end.


send_notification(Expiry, Token, JSON, Prio, From, State) ->
    {Nf, NewState} = next_nf(Expiry, Token, JSON, Prio, From, State),
    send_notification(Nf, NewState).


send_notification(#nf{seq = Seq} = Nf, State) ->
    case apns_send(State#?S.sock, Nf) of
        ok ->
            {ok, Seq, history_put(Nf, State)};
        {error, Reason} ->
            lager:error("APNS session ~p failed to send notification ~w with "
                        "token ~s: ~p",
                        [State#?S.name, Seq, tok_s(Nf), Reason]),
            {error, Seq, recover_notification(Nf, State)}
    end.


handle_connection_closure(StateName, State) ->
    catch ssl:close(State#?S.sock),
    case State#?S.stop_callers of
        [] -> next(StateName, connecting, State#?S{sock = undefined});
        _ -> stop(StateName, normal, State#?S{sock = undefined})
    end.


format(Tmpl, Args) ->
    iolist_to_binary(io_lib:format(Tmpl, Args)).


format_props(Props) ->
    iolist_to_binary(string:join([io_lib:format("~w=~p", [K, V])
                                  || {K, V} <- Props], ", ")).


%%% --------------------------------------------------------------------------
%%% State Machine Functions
%%% --------------------------------------------------------------------------

-compile({inline, [bootstrap/1,
                   continue/2,
                   next/3,
                   reply/3,
                   stop/3,
                   stop/4,
                   leave/2,
                   transition/3,
                   enter/2]}).


%% -----------------------------------------------------------------
%% Bootstraps the state machine.
%% -----------------------------------------------------------------

-spec bootstrap(State) -> {ok, StateName, State}
    when StateName :: state_name(), State ::state().

bootstrap(State) ->
    gen_fsm:send_event(self(), connect),
    {ok, connecting, State}.


%% -----------------------------------------------------------------
%% Stays in the same state without triggering any transition.
%% -----------------------------------------------------------------

-spec continue(StateName, State) -> {next_state, StateName, State}
    when StateName :: state_name(), State ::state().

continue(StateName, State) ->
    {next_state, StateName, State}.


%% -----------------------------------------------------------------
%% Changes the current state triggering corresponding transition.
%% -----------------------------------------------------------------

-spec next(FromStateName, ToStateName, State) -> {next_state, StateName, State}
    when FromStateName :: state_name(), ToStateName ::state_name(),
         StateName ::state_name(), State ::state().

next(From, To, State) ->
    {next_state, To, enter(To, transition(From, To, leave(From, State)))}.


%% -----------------------------------------------------------------
%% Replies without changing the current state or triggering any transition.
%% -----------------------------------------------------------------

-spec reply(Reply, StateName, State) -> {reply, Reply, StateName, State}
    when Reply :: term(), StateName :: state_name(), State ::state().

reply(Reply, StateName, State) ->
    {reply, Reply, StateName, State}.


%% -----------------------------------------------------------------
%% Stops the process without reply.
%% -----------------------------------------------------------------

-spec stop(StateName, Reason, State) -> {stop, Reason, State}
    when StateName :: state_name(), State ::state(), Reason :: term().

stop(_StateName, Reason, State) ->
    {stop, Reason, State}.


%% -----------------------------------------------------------------
%% Stops the process with a reply.
%% -----------------------------------------------------------------

-spec stop(StateName, Reason, Reply, State) -> {stop, Reason, Reply, State}
    when StateName :: state_name(), Reason ::term(),
         Reply :: term(), State ::state().

stop(_StateName, Reason, Reply, State) ->
    {stop, Reason, Reply, State}.


%% -----------------------------------------------------------------
%% Performs actions when leaving a state.
%% -----------------------------------------------------------------

-spec leave(StateName, State) -> State
    when StateName :: state_name(), State ::state().

leave(connecting, State) ->
    % Cancel any scheduled reconnection.
    cancel_reconnect(State);

leave(connected, State) ->
    % Reset any scheduled checkpoint.
    cancel_checkpoint(State);

leave(disconnecting, State) ->
    % Cleanup forced closure scheduled event.
    cancel_closure_timeout(State).


%% -----------------------------------------------------------------
%% Validate transitions and performs transition-specific actions.
%% -----------------------------------------------------------------

-spec transition(FromStateName, ToStateName, State) -> State
    when FromStateName :: state_name(), ToStateName ::state_name(), State ::state().

transition(connecting,    connecting,    State) -> State;
transition(connecting,    connected,     State) -> State;
transition(connected,     connecting,    State) -> State;
transition(connected,     disconnecting, State) -> State;
transition(disconnecting, connecting,    State) -> State.


%% -----------------------------------------------------------------
%% Performs actions when entering a state.
%% -----------------------------------------------------------------

-spec enter(StateName, State) -> State
    when StateName :: state_name(), State ::state().

enter(connecting, State) ->
    % Trigger the connection after an exponential delay.
    % If there is still notifications in the history we queue it back

    % NOTE: History should not be recovered after a disconnect
    % due to forcing a known bad token. History should be recovered
    % after the known bad token only. But if there was a disconnect for
    % some reason OTHER than a bad token....
    schedule_reconnect(recover_history(State));

enter(connected, State) ->
    % Trigger the flush of queued notifications
    gen_fsm:send_event(self(), flush),
    % Reset the exponential delay and schedule a checkpoint.
    schedule_checkpoint(reset_delay(State));

enter(disconnecting, State) ->
    % Trigger the disconnection when disconnecting.
    gen_fsm:send_event(self(), disconnect),
    % Schedule a timeout for forced socket closure.
    schedule_closure_timeout(State).


%%% --------------------------------------------------------------------------
%%% Option Validation Functions
%%% --------------------------------------------------------------------------

-compile({inline, [pv/2, pv/3, pv_req/2,
                   validate_list/2,
                   validate_binary/2,
                   validate_non_neg/2]}).


init_state(Name, Opts) ->
    BundleSeedId = validate_bundle_seed_id(Opts),
    BundleId = validate_bundle_id(Opts),
    SslOpts = validate_ssl_opts(Opts, BundleSeedId, BundleId),
    Host = validate_host(Opts),
    Port = validate_port(Opts),
    FakeToken = validate_fake_token(Opts),
    RetryDelay = validate_retry_delay(Opts),
    RetryMax = validate_retry_max(Opts),
    CheckpointPeriod = validate_checkpoint_period(Opts),
    CheckpointMax = validate_checkpoint_max(Opts),
    CloseTimeout = validate_close_timeout(Opts),
    FeedbackEnabled = feedback_enabled(Opts),
    FeedbackName = feedback_name(Name),
    FeedbackOpts = feedback_options(Opts),

    lager:debug("With options: host=~p, port=~w, "
                "retry_delay=~w, retry_max=~p, "
                "checkpoint_period=~w, checkpoint_max=~w, "
                "close_timeout=~p, fake_token=~p, "
                "bundle_seed_id=~p, bundle_id=~p",
                [Host, Port,
                 RetryDelay, RetryMax,
                 CheckpointPeriod, CheckpointMax,
                 CloseTimeout, FakeToken,
                 BundleSeedId, BundleId]),
    lager:debug("With SSL options: ~s", [format_props(SslOpts)]),

    #?S{name = Name,
        host = Host,
        port = Port,
        bundle_seed_id = BundleSeedId,
        bundle_id = BundleId,
        ssl_opts = SslOpts,
        fake_token = FakeToken,
        retry_delay = RetryDelay,
        retry_max = RetryMax,
        checkpoint_period = CheckpointPeriod,
        checkpoint_max = CheckpointMax,
        close_timeout = CloseTimeout,
        feedback_enabled = FeedbackEnabled,
        feedback_name = FeedbackName,
        feedback_opts = FeedbackOpts}.


-spec validate_ssl_opts(Opts, BundleSeedId, BundleId) -> Opts
    when Opts :: proplists:proplist(), BundleSeedId ::binary(),
         BundleId :: binary().

validate_ssl_opts(Opts, BundleSeedId, BundleId) ->
    SslOpts = pv_req(ssl_opts, Opts),
    DontValidateApnsCert = validate_boolean_opt(disable_apns_cert_validation,
                                                Opts, false),
    case pv(certfile, SslOpts) of
        undefined ->
            throw(missing_certfile_option);
        CertPath ->
            case file:read_file(CertPath) of
                {error, Reason} ->
                    throw({bad_cert_path, Reason});
                {ok, _Bin} when DontValidateApnsCert == true ->
                    SslOpts;
                {ok, Bin} ->
                    case apns_cert:validate(Bin, BundleSeedId, BundleId) of
                        ok -> SslOpts;
                        {_ErrorClass, _Reason} = Reason ->
                            throw({bad_cert, Reason})
                    end
            end
    end.

-spec validate_boolean_opt(Name, Opts, Default) -> Value
    when Name :: atom(), Opts :: proplists:proplist(),
         Default :: boolean(), Value :: boolean().

validate_boolean_opt(Name, Opts, Default) ->
    validate_boolean(Name, pv(Name, Opts, Default)).

-spec validate_boolean(Name, Value) -> Value
    when Name :: atom(), Value :: boolean().

validate_boolean(Name, Bool) ->
    case is_boolean(Bool) of
        true ->
            Bool;
        false ->
            throw({bad_options, {not_a_boolean, Name}})
    end.


-spec validate_list(Name, Value) -> Value
    when Name :: atom(), Value :: list().

validate_list(_Name, List) when is_list(List) -> List;

validate_list(Name, _Other) ->
    throw({bad_options, {not_a_list, Name}}).


-spec validate_binary(Name, Value) -> Value
    when Name :: atom(), Value :: binary().

validate_binary(_Name, Bin) when is_binary(Bin) -> Bin;

validate_binary(Name, _Other) ->
    throw({bad_options, {not_a_binary, Name}}).


-spec validate_non_neg(Name, Value) -> Value
    when Name :: atom(), Value :: non_neg_integer().

validate_non_neg(_Name, Int) when is_integer(Int), Int >= 0 -> Int;

validate_non_neg(Name, Int) when is_integer(Int) ->
    throw({bad_options, {negative_integer, Name}});

validate_non_neg(Name, _Other) ->
    throw({bad_options, {not_an_integer, Name}}).


validate_host(Opts) ->
    validate_list(host, pv_req(host, Opts)).


validate_port(Opts) ->
    validate_non_neg(port, pv(port, Opts, ?DEFAULT_APNS_PORT)).


validate_bundle_seed_id(Opts) ->
    validate_binary(bundle_seed_id, pv_req(bundle_seed_id, Opts)).


validate_bundle_id(Opts) ->
    validate_binary(bundle_id, pv_req(bundle_id, Opts)).


validate_fake_token(Opts) ->
    validate_binary(fake_token, pv_req(fake_token, Opts)).


validate_retry_delay(Opts) ->
    validate_non_neg(retry_delay, pv(retry_delay, Opts, ?DEFAULT_RETRY_DELAY)).


validate_retry_max(Opts) ->
    validate_non_neg(retry_max, pv(retry_max, Opts, ?DEFAULT_RETRY_MAX)).


validate_checkpoint_period(Opts) ->
    validate_non_neg(checkpoint_period, pv(checkpoint_period, Opts,
                                           ?DEFAULT_CHECKPOINT_PERIOD)).


validate_checkpoint_max(Opts) ->
    validate_non_neg(checkpoint_max, pv(checkpoint_max, Opts,
                                        ?DEFAULT_CHECKPOINT_MAX)).


validate_close_timeout(Opts) ->
    validate_non_neg(close_timeout, pv(close_timeout, Opts,
                                       ?DEFAULT_CLOSE_TIMEOUT)).


pv(Key, PL) ->
    proplists:get_value(Key, PL).


pv(Key, PL, Default) ->
    proplists:get_value(Key, PL, Default).


pv_req(Key, PL) ->
    case pv(Key, PL) of
        undefined ->
            throw({key_not_found, Key});
        Val ->
            Val
    end.


%%% --------------------------------------------------------------------------
%%% Notification Creation Functions
%%% --------------------------------------------------------------------------


incr_seq(Seq) when Seq > ?SEQ_MAX -> 0;

incr_seq(Seq) when is_integer(Seq) -> Seq + 1.


next_seq(State) ->
    #?S{last_seq = LastSeq} = State,
    NextSeq = incr_seq(LastSeq),
    {NextSeq, State#?S{last_seq = NextSeq}}.


next_nf(Expiry, Token, JSON, Prio, From, State) ->
    {NextSeq, NewState} = next_seq(State),
    {make_nf(NextSeq, Expiry, Token, JSON, Prio, From), NewState}.


next_fake_nf(State) ->
    #?S{fake_token = Token} = State,
    {Seq, NewState} = next_seq(State),
    {make_nf(Seq, ?FAKE_EXPIRY_TIME, Token,
             ?FAKE_PAYLOAD, ?DEFAULT_PRIO, undefined), NewState}.


make_nf(SeqNo, Expiry, Token, JSON, Prio, From) ->
    #nf{seq = SeqNo,
        expiry = Expiry,
        token = Token,
        json = JSON,
        prio = Prio,
        from = From}.


success_callback(#nf{from = undefined}) -> ok;

success_callback(#nf{seq = Seq, from = Caller}) ->
    gen_fsm:reply(Caller, {ok, Seq}).


failure_callback(#nf{from = undefined}, _Reason) -> ok;

failure_callback(#nf{from = Caller}, Reason) ->
    gen_fsm:reply(Caller, {error, Reason}).


%%% --------------------------------------------------------------------------
%%% History and Queue Managment Functions
%%% --------------------------------------------------------------------------

init_history(#?S{history = undefined} = State) ->
    Table = ets:new(apns_history, [ordered_set, private, {keypos, #nf.seq}]),
    State#?S{history = Table}.


terminate_history(#?S{history = Table} = State) when Table =/= undefined ->
    ets:delete(Table),
    State#?S{history = undefined}.


init_queue(#?S{queue = undefined} = State) ->
    State#?S{queue = queue:new()}.


terminate_queue(#?S{queue = Queue} = State) when Queue =/= undefined ->
    State#?S{queue = undefined}.


history_get(Seq, State) ->
    case ets:lookup(State#?S.history, Seq) of
        [] -> undefined;
        [Nf] -> Nf
    end.


history_put(Nf, #?S{history = Table, history_size = Size} = State) ->
    % When a notification is put in the history, the caller has been notified.
    ets:insert(Table, Nf#nf{from = undefined}),
    maybe_trigger_checkpoint(State#?S{history_size = Size + 1}).


queue_length(State) ->
    queue:len(State#?S.queue).


queue_notification(Nf, #?S{queue = Queue} = State) ->
    State#?S{queue = queue:in(Nf, Queue)}.


recover_notification(Nf, #?S{queue = Queue} = State) ->
    State#?S{queue = queue:in_r(Nf, Queue)}.


recover_history(#?S{history = Table, queue = Queue} = State) ->
    NewQueue = ets:foldr(fun queue:in_r/2, Queue, Table),
    ets:delete_all_objects(Table),
    State#?S{queue = NewQueue, history_size = 0}.


recover_history_after(Seq, #?S{history = Table, queue = Queue} = State) ->
    % The order is respected because get_after/2 gives a reversed list.
    Nfs = get_after(Seq, Table, []),
    NewQueue = lists:foldl(fun queue:in_r/2, Queue, Nfs),
    ets:delete_all_objects(Table),
    State#?S{queue = NewQueue, history_size = 0}.


get_after(Seq, Table, Acc) ->
    case ets:next(Table, Seq) of
        '$end_of_table' -> Acc;
        NextSeq ->
            case ets:lookup(Table, NextSeq) of
                [] -> get_after(NextSeq, Table, Acc);
                [Nf] -> get_after(NextSeq, Table, [Nf |Acc])
            end
    end.


%%% --------------------------------------------------------------------------
%%% Checkpoint Functions
%%% --------------------------------------------------------------------------

schedule_checkpoint(#?S{checkpoint_ref = Ref} = State) ->
    catch erlang:cancel_timer(Ref),
    NewRef = gen_fsm:send_event_after(State#?S.checkpoint_period, checkpoint),
    State#?S{checkpoint_ref = NewRef,
             checkpoint_pending = false,
             checkpoint_time = os:timestamp()}.


cancel_checkpoint(#?S{checkpoint_ref = Ref} = State) ->
    catch erlang:cancel_timer(Ref),
    State#?S{checkpoint_ref = undefined}.


maybe_trigger_checkpoint(#?S{history_size = Size,
                             checkpoint_pending = false,
                             checkpoint_max = Max} = State)
  when Size >= Max ->
    gen_fsm:send_event(self(), checkpoint),
    cancel_checkpoint(State#?S{checkpoint_pending = true});

maybe_trigger_checkpoint(State) ->
    State.


maybe_checkpoint(#?S{history_size = Size} = State) when Size > 0 ->
    % There is multiple source of checkpoints, timer based and trigger based,
    % and we realy don't want any race to result in fast successive checkpoints.
    Delta = timer:now_diff(os:timestamp(), State#?S.checkpoint_time),
    NewState = schedule_checkpoint(State),
    if Delta < ?CHECKPOINT_TIME_THRESHOLD ->
           % A race between checkpoint timeout and triggered checkpoint.
           NewState;
       true ->
           send_checkpoint(NewState)
    end;

maybe_checkpoint(State) ->
    % No notification since the last checkpoint
    schedule_checkpoint(State).


send_checkpoint(#?S{sock = Socket} = State) ->
    {FakeNf, NewState} = next_fake_nf(State),
    _ = apns_send(Socket, FakeNf),
    NewState#?S{checkpoint_seq = FakeNf#nf.seq}.


%%% --------------------------------------------------------------------------
%%% Reconnection Delay Functions
%%% --------------------------------------------------------------------------

schedule_reconnect(#?S{retry_ref = Ref} = State) ->
    catch erlang:cancel_timer(Ref),
    {Delay, NewState} = next_delay(State),
    lager:info("APNS session ~p will reconnect in ~w ms",
               [State#?S.name, Delay]),
    NewRef = gen_fsm:send_event_after(Delay, connect),
    NewState#?S{retry_ref = NewRef}.


cancel_reconnect(#?S{retry_ref = Ref} = State) ->
    catch erlang:cancel_timer(Ref),
    State#?S{retry_ref = undefined}.


next_delay(#?S{retries = 0} = State) ->
    {0, State#?S{retries = 1}};

next_delay(State) ->
    #?S{retries = Retries, retry_delay = RetryDelay,
        retry_max = RetryMax} = State,
    Delay = RetryDelay * trunc(math:pow(2, (Retries - 1))),
    {min(RetryMax, Delay), State#?S{retries = Retries + 1}}.


reset_delay(State) ->
    % Reset to 1 so the first reconnection is always done after the retry delay.
    State#?S{retries = 1}.


%%% --------------------------------------------------------------------------
%%% Socket Closure Timeout Functions
%%% --------------------------------------------------------------------------

schedule_closure_timeout(#?S{close_ref = Ref} = State) ->
    catch erlang:cancel_timer(Ref),
    NewRef = gen_fsm:send_event_after(State#?S.close_timeout, timeout),
    State#?S{close_ref = NewRef}.


cancel_closure_timeout(#?S{close_ref = Ref} = State) ->
    catch erlang:cancel_timer(Ref),
    State#?S{close_ref = undefined}.


%%% --------------------------------------------------------------------------
%%% APNS Feedback Functions
%%% --------------------------------------------------------------------------

start_feedback(#?S{feedback_enabled = false} = State) ->
    State;
start_feedback(#?S{feedback_pid = undefined} = State) ->
    #?S{feedback_name = Name, feedback_opts = Opts} = State,
    case apns_erl_feedback_session:start_link(Name, Opts) of
        {error, Reason} ->
            throw({feedback_error, Reason});
        {ok, Pid} ->
            State#?S{feedback_pid = Pid}
    end.


stop_feedback(#?S{feedback_enabled = false} = State) ->
    State#?S{feedback_pid = undefined};
stop_feedback(#?S{feedback_pid = Pid} = State) when is_pid(Pid) ->
    apns_erl_feedback_session:stop(Pid),
    State#?S{feedback_pid = undefined}.


feedback_enabled(Opts) ->
    validate_boolean_opt(feedback_enabled, Opts, false).

feedback_name(Name) ->
    list_to_atom("fb-" ++ atom_to_list(Name)).


feedback_options(Opts) ->
    feedback_fix_retry_delay(feedback_fix_port(feedback_fix_host(Opts))).


feedback_fix_host(Opts) ->
    case lists:keytake(feedback_host, 1, Opts) of
        {value, {feedback_host, Value}, NewOpts} ->
            Host = validate_list(feedback_host, Value),
            [{host, Host} |proplists:delete(host, NewOpts)];
        false ->
            Host = case validate_list(host, pv(host, Opts)) of
                       "gateway." ++ Rest -> "feedback." ++ Rest;
                       Other -> Other
                   end,
            [{host, Host} |proplists:delete(host, Opts)]
    end.


feedback_fix_port(Opts) ->
    case lists:keytake(feedback_port, 1, Opts) of
        false -> Opts;
        {value, {feedback_port, Value}, NewOpts} ->
            Port = validate_non_neg(feedback_port, Value),
            [{port, Port} |proplists:delete(port, NewOpts)]
    end.


feedback_fix_retry_delay(Opts) ->
    case lists:keytake(feedback_retry_delay, 1, Opts) of
        false -> Opts;
        {value, {feedback_retry_delay, Value}, NewOpts} ->
            Delay = validate_non_neg(feedback_retry_delay, Value),
            [{retry_delay, Delay} |proplists:delete(retry_delay, NewOpts)]
    end.


%%% --------------------------------------------------------------------------
%%% APNS Handling Functions
%%% --------------------------------------------------------------------------

apns_connect(Host, Port, SslOpts) ->
    try ssl:connect(Host, Port, SslOpts) of
        {error, _Reason} = Error -> Error;
        {ok, Socket} -> {ok, Socket}
    catch
        Class:Reason -> {error, {Class, Reason}}
    end.


apns_send(Sock, Nf) when Sock =/= undefined ->
    #nf{seq = Seq, expiry = Exp, token = Token, json = JSON, prio = Prio} = Nf,
    <<Packet/binary>> = apns_lib:encode_v2(Seq, Exp, Token, JSON, Prio),
    case ssl:send(Sock, Packet) of
        {error, _Reason} = Error -> Error;
        ok -> ok
    end.


apns_decode_message(Data) ->
    case apns_lib:decode_error_packet(Data) of
        {error, Reason} ->
            {error, format("Error decoding packet (~p)", [Reason])};
        Rec ->
            case apns_recs:'#is_record-'(apns_error, Rec) of
                true ->
                    apns_decode_record(Rec);
                false ->
                    {error, format("Expected error packet and got ~p", [Rec])}
            end
    end.


apns_decode_record(Rec) ->
    case apns_recs:'#get-apns_error'(status, Rec) of
        ok -> ok;
        _Error ->
            Props = apns_rec_to_props(apns_error, Rec),
            apns_decode_error(Props)
    end.


apns_rec_to_props(RecName, Rec) ->
    Fields = apns_recs:'#info-'(RecName),
    lists:zip(Fields, apns_recs:'#get-'(Fields, Rec)).


apns_decode_error(Props) ->
    Status = pv(status, Props),
    case pv(id, Props) of
        Seq when is_integer(Seq) ->
            {bad_nf, Status, Seq};
        Id ->
            {error, format("Invalid sequence ~p in APNS error ~p", [Id, Status])}
    end.


apns_deregister_token(Token) ->
    SvcTok = sc_push_reg_api:make_svc_tok(apns, Token),
    ok = sc_push_reg_api:deregister_svc_tok(SvcTok).

-spec tok_s(Token) -> BStr
    when Token :: nf() | binary() | string(), BStr :: bstrtok().
tok_s(#nf{token = Token}) ->
    tok_s(sc_util:to_bin(Token));
tok_s(Token) when is_list(Token) ->
    tok_s(sc_util:to_bin(Token));
tok_s(<<Token/binary>>) ->
    list_to_binary(sc_util:bitstring_to_hex(apns_lib:maybe_encode_token(Token))).

