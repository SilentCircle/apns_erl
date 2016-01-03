%%% ==========================================================================
%%% Copyright 2015 Silent Circle
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

%%% @author Edwin Fine <efine@silentcircle.com>
%%% @author Sebastien Merle
%%% @copyright 2015 Silent Circle
%%% @doc
%%% APNS feedback service session.
%%%
%%% Process configuration:
%%% <dl>
%%% <dt>`host':</dt>
%%% <dd>is hostname of the feedback service as a string.
%%% </dd>
%%% <dt>`port':</dt>
%%% <dd>is the port of the feedback service as an integer.
%%%
%%%     Default value: `2196'.
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
%%%     it will be ignored.
%%% </dd>
%%% <dt>`retry_delay':</dt>
%%% <dd>is the reconnection delay in miliseconds the process will wait before
%%%     reconnecting to feeddback servers as an integer;
%%%
%%%     Default value: `3600000'.
%%%
%%% </dd>
%%% <dt>`close_timeout':</dt>
%%% <dd>is the maximum amount of time the session will wait for the feedback
%%%     server to close the SSL connection after shuting it down.
%%%
%%%     Default value: `5000'.
%%%
%%% </dd>
%%% <dt>`ssl_opts':</dt>
%%% <dd>is the property list of SSL options including the certificate file path.
%%% </dd>
%%% </dl>
%%%
%%% @end
%%%-------------------------------------------------------------------

-module(apns_erl_feedback_session).

-behaviour(gen_fsm).


%%% ==========================================================================
%%% Includes
%%% ==========================================================================

-include_lib("lager/include/lager.hrl").


%%% ==========================================================================
%%% Exports
%%% ==========================================================================

%%% API Functions
-export([start/2,
         start_link/2,
         stop/1]).

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

%%% Handler functions
-export([default_feedback_handler/1,
         process_feedback_packets/3]).


%%% ==========================================================================
%%% Macros
%%% ==========================================================================

-define(S, ?MODULE).

-define(DEFAULT_FEEDBACK_PORT, 2196).
-define(DEFAULT_RETRY_DELAY, 60 * 60 * 1000). % 1 hour
-define(DEFAULT_CLOSE_TIMEOUT, 5000).


%%% ==========================================================================
%%% Records
%%% ==========================================================================

-type fb_rec() :: {Timestamp :: non_neg_integer(), Token :: binary()}.
-type feedback_handler() :: fun((TSTok :: fb_rec()) -> fb_rec()).

%%% Process state
-record(?S,
        {name           = undefined              :: atom(),
         host           = ""                     :: string(),
         port           = ?DEFAULT_FEEDBACK_PORT :: pos_integer(),
         bundle_seed_id = <<>>                   :: binary(),
         bundle_id      = <<>>                   :: binary(),
         ssl_opts       = []                     :: list(),
         sock           = undefined              :: term(),
         retry_ref      = undefined              :: reference() | undefined,
         retry_delay    = ?DEFAULT_RETRY_DELAY   :: non_neg_integer(),
         handler        = fun ?MODULE:default_feedback_handler/1 :: feedback_handler(),
         fake_token     = undefined              :: undefined | binary(),
         close_ref      = undefined              :: reference() | undefined,
         close_timeout = ?DEFAULT_CLOSE_TIMEOUT  :: undefined | non_neg_integer(),
         stop_callers  = []                      :: list()
        }).


%%% ==========================================================================
%%% Types
%%% ==========================================================================

-type state() :: #?S{}.
-type state_name() :: connecting | connected | disconnecting.
-type option() :: {host, string()} |
                  {port, pos_integer()} |
                  {retry_delay, pos_integer()} |
                  {close_timeout, pos_integer()} |
                  {bundle_seed_id, binary()} |
                  {bundle_id, binary()} |
                  {ssl_opts, list()}.
-type options() :: [option()].
-type fsm_ref() :: atom() | pid().

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


%%% ==========================================================================
%%% Debugging Functions
%%% ==========================================================================

-spec get_state(FsmRef) -> state() when
      FsmRef :: fsm_ref().
get_state(FsmRef) ->
    gen_fsm:sync_send_all_state_event(FsmRef, get_state).


%%% ==========================================================================
%%% Behaviour gen_fsm Standard Callbacks
%%% ==========================================================================

init([Name, Opts]) ->
    _ = lager:info("Feedback handler ~p started", [Name]),
    try
        bootstrap(init_state(Name, Opts))
    catch
        _What:Why ->
            {stop, {Why, erlang:get_stacktrace()}}
    end.


handle_event(Event, StateName, State) ->
    _ = lager:warning("Received unexpected event while ~p: ~p",
                      [StateName, Event]),
    continue(StateName, State).


handle_sync_event(stop, _From, connecting, State) ->
    stop(connecting, normal, ok, State);

handle_sync_event(stop, From, connected, #?S{stop_callers = L} = State) ->
    next(connected, disconnecting, State#?S{stop_callers = [From |L]});

handle_sync_event(stop, From, disconnecting, #?S{stop_callers = L} = State) ->
    continue(disconnecting, State#?S{stop_callers = [From |L]});

handle_sync_event(get_state, _From, StateName, State) ->
    reply({ok, State}, StateName, State);

handle_sync_event(Event, {Pid, _Tag}, StateName, State) ->
    _ = lager:warning("Received unexpected event from ~p while ~p: ~p",
                      [Pid, StateName, Event]),
    reply({error, invalid_event}, StateName, State).


handle_info({ssl, Socket, Data}, StateName, #?S{sock = Socket} = State) ->
    %% The only data we expect is feedback data
    case apns_lib:decode_feedback_packet(Data) of
        [] -> ok;
        [{_,_}|_] = FBRecs ->
            FBHandler = State#?S.handler,
            FakeToken = State#?S.fake_token,
            process_feedback_packets(FBRecs, FBHandler, FakeToken)
    end,
    continue(StateName, State);


handle_info({ssl, Socket, _Data}, StateName, State) ->
    _ = lager:warning("Received data from unknown socket while ~p: ~p",
                      [StateName, Socket]),
    continue(StateName, State);

handle_info({ssl_closed, Socket}, StateName, #?S{sock = Socket} = State) ->
    _ = lager:debug("SSL socket ~p closed by peer", [Socket]),
    handle_connection_closure(StateName, State);

handle_info({ssl_closed, Socket}, StateName, State) ->
    _ = lager:warning("Received close message from unknown socket ~p while ~p",
                      [Socket, StateName]),
    continue(StateName, State);

handle_info({ssl_error, Socket, Reason}, StateName, #?S{sock = Socket} = State) ->
    _ = lager:error("SSL error on socket ~p while ~p: ~p",
                    [Socket, StateName, Reason]),
    continue(StateName, State);

handle_info({ssl_error, Socket, Reason}, StateName, State) ->
    _ = lager:warning("Received SSL error from unknown socket "
                      "~p while ~p: ~p", [Socket, StateName, Reason]),
    continue(StateName, State);

handle_info(Info, StateName, State) ->
    _ = lager:warning("Unexpected message received in state ~p: ~p",
                      [StateName, Info]),
    continue(StateName, State).


terminate(Reason, StateName, State) ->
    _ = lager:info("Feedback handler ~p terminated in state ~p: ~p",
                   [State#?S.name, StateName, Reason]),
    ok.


code_change(_OldVsn, StateName, State, _Extra) ->
    {ok, StateName, State}.


%%% ==========================================================================
%%% Behaviour gen_fsm State Functions
%%% ==========================================================================

%% -----------------------------------------------------------------
%% Connecting State
%% -----------------------------------------------------------------

connecting(connect, State) ->
    #?S{name = Name, host = Host, port = Port, ssl_opts = Opts} = State,
    _ = lager:info("Feedback handler ~p connecting to ~s:~w",
                   [Name, Host, Port]),
    case feedback_connect(Host, Port, Opts) of
        {ok, Socket} ->
            _ = lager:info("Feedback handler ~p connected to ~s:~w "
                           "on SSL socket ~p", [Name, Host, Port, Socket]),
            next(connecting, connected, State#?S{sock = Socket});
        {error, Reason} ->
            _ = lager:error("Feedback handler ~p failed to connect "
                            "to ~s:~w : ~p", [Name, Host, Port, Reason]),
            next(connecting, connecting, State)
    end;

connecting(Event, State) ->
    handle_event(Event, connecting, State).


connecting(Event, From, State) ->
    handle_sync_event(Event, From, connecting, State).


%% -----------------------------------------------------------------
%% Connected State
%% -----------------------------------------------------------------

connected(Event, State) ->
    handle_event(Event, connected, State).


connected(Event, From, State) ->
    handle_sync_event(Event, From, connected, State).


%% -----------------------------------------------------------------
%% Disconnecting State
%% -----------------------------------------------------------------

disconnecting(disconnect, State) ->
    catch ssl:shutdown(State#?S.sock, write),
    continue(disconnecting, State);

disconnecting(timeout, State) ->
    _ = lager:warning("Feedback handler ~p was forced to close SSL socket ~p",
                      [State#?S.name, State#?S.sock]),
    handle_connection_closure(disconnecting, State);

disconnecting(Event, State) ->
    handle_event(Event, disconnecting, State).


disconnecting(Event, From, State) ->
    handle_sync_event(Event, From, disconnecting, State).


%%% ==========================================================================
%%% Handler Functions
%%% ==========================================================================

-spec process_feedback_packets(FBRecs, FBHandler, FakeToken) -> 'ok' when
      FBRecs :: [fb_rec()], FBHandler :: feedback_handler(),
      FakeToken :: 'undefined' | binary().
process_feedback_packets(FBRecs, FBHandler, FakeToken)
  when is_list(FBRecs), is_function(FBHandler, 1) ->
    _ = spawn(fun() ->
                      process_fb_pkts_async(FBRecs, FBHandler, FakeToken)
              end),
    ok.

-spec process_fb_pkts_async(FBRecs, FBHandler, FakeToken) -> Result when
      FBRecs :: [fb_rec()], FBHandler :: feedback_handler(),
      FakeToken :: binary(), Result :: [fb_rec()] | {error, term()}.
process_fb_pkts_async(FBRecs, FBHandler, FakeToken)
  when is_list(FBRecs), is_function(FBHandler, 1) ->
    try
        % APNS reports tokens in binary format. The registration
        % API stores tokens as strings, so convert this to a
        % hexadecimal string.  Filter out the fake token that
        % is supposed to fail.
        lists:filtermap(fun({TS, Tok}) ->
                                case sc_util:bitstring_to_hex(Tok) of
                                    FakeToken ->
                                        ignore_token(FakeToken);
                                    HexTok ->
                                        {true, FBHandler({TS, HexTok})}
                                end
                        end, FBRecs)
    catch
        Class:Reason ->
            FuncInfo = func_to_string(FBHandler),
            _ = lager:error("Feedback handler crashed calling ~s"
                            " with recs: ~p, reason: ~p",
                            [FuncInfo, FBRecs, {Class, Reason}]),
            {error, {Class, Reason}}
    end.

-spec ignore_token(Tok) -> false when Tok :: any().
ignore_token(_Tok) ->
    _ = lager:debug("Ignoring checkpoint token.", []),
    false.


-spec default_feedback_handler(TSTok) -> TSTok when
      TSTok :: fb_rec().
default_feedback_handler({Timestamp, HexToken} = TSTok) ->
    _ = lager:info("[~p] Deregistering token ~s", [Timestamp, HexToken]),
    SvcTok = sc_push_reg_api:make_svc_tok(apns, HexToken),
    % Should only deregister if the timestamp of the registered
    % record is older than the timestamp sent to us by APNS.
    _ = case sc_push_reg_api:get_registration_info_by_svc_tok(SvcTok) of
        notfound -> % Nothing to do
            ok;
        Props ->
            ErlTs = pv(modified, Props, {0, 0, 0}),
            RegisteredTs = now_to_posix(ErlTs),
            case Timestamp > RegisteredTs of
                true ->
                    ok = sc_push_reg_api:deregister_svc_tok(SvcTok);
                false ->
                    lager:info("Registration is newer than feedback "
                               "(~B > ~B), will not deregister token ~s",
                               [RegisteredTs, Timestamp, HexToken])
            end
    end,
    TSTok.


%%% ==========================================================================
%%% Internal Functions
%%% ==========================================================================

feedback_connect(Host, Port, SslOpts) ->
    try ssl:connect(Host, Port, SslOpts) of
        {error, _Reason} = Error -> Error;
        {ok, Socket} -> {ok, Socket}
    catch
        Class:Reason -> {error, {Class, Reason}}
    end.

func_to_string(Fun) when is_function(Fun) ->
    Info = erlang:fun_info(Fun),
    atom_to_list(proplists:get_value(module, Info)) ++ ":" ++
    atom_to_list(proplists:get_value(function, Info)) ++ "/" ++
    integer_to_list(proplists:get_value(arity, Info)).

-compile({inline, [{now_to_posix, 1},
                   {bool_to_int, 1}]}).

now_to_posix({M, S, U}) ->
    M * 1000000 + S + bool_to_int(U >= 500000).

bool_to_int(true) -> 1;
bool_to_int(false) -> 0.


handle_connection_closure(StateName, State) ->
    catch ssl:close(State#?S.sock),
    case State#?S.stop_callers of
        [] -> next(StateName, connecting, State#?S{sock = undefined});
        _ -> stop(StateName, normal, State#?S{sock = undefined})
    end.


broadcast_reply(Callers, Result) ->
    _ = [gen_fsm:reply(C, Result) || C <- Callers],
    ok.


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

stop(_StateName, Reason, #?S{stop_callers = Callers} = State) ->
    % Reply to all the callers waiting for the session to stop.
    broadcast_reply(Callers, ok),
    {stop, Reason, State#?S{stop_callers = []}}.


%% -----------------------------------------------------------------
%% Stops the process with a reply.
%% -----------------------------------------------------------------

-spec stop(StateName, Reason, Reply, State) -> {stop, Reason, Reply, State}
    when StateName :: state_name(), Reason ::term(),
         Reply :: term(), State ::state().

stop(_StateName, Reason, Reply, #?S{stop_callers = Callers} = State) ->
    % Reply to all the callers waiting for the session to stop.
    broadcast_reply(Callers, ok),
    {stop, Reason, Reply, State#?S{stop_callers = []}}.


%% -----------------------------------------------------------------
%% Performs actions when leaving a state.
%% -----------------------------------------------------------------

-spec leave(StateName, State) -> State
    when StateName :: state_name(), State ::state().

leave(connecting, State) ->
    % Cancel any scheduled reconnection.
    cancel_reconnect(State);

leave(disconnecting, State) ->
    % Cleanup forced closure scheduled event.
    cancel_closure_timeout(State);

leave(_StateName, State) -> State.


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
    % Trigger the connection after a fixed amount of time.
    schedule_reconnect(State);

enter(disconnecting, State) ->
    % Trigger the disconnection when disconnecting.
    gen_fsm:send_event(self(), disconnect),
    % Schedule a timeout for forced socket closure.
    schedule_closure_timeout(State);

enter(_StateName, State) -> State.


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
    Host = validate_host(Opts),
    Port = validate_port(Opts),
    FakeToken = validate_fake_token(Opts),
    RetryDelay = validate_retry_delay(Opts),
    CloseTimeout = validate_close_timeout(Opts),

    % Ensure that we receive data as a binary
    SslOpts = [binary |validate_ssl_opts(Opts, BundleSeedId, BundleId)],

    _ = lager:debug("With options: host=~p, port=~w, "
                    "retry_delay=~w, close_timeout=~p, fake_token=~p, "
                    "bundle_seed_id=~p, bundle_id=~p",
                    [Host, Port, RetryDelay, CloseTimeout, FakeToken,
                     BundleSeedId, BundleId]),
    _ = lager:debug("With SSL options: ~s", [format_props(SslOpts)]),

    #?S{name = Name,
        host = Host,
        port = Port,
        bundle_seed_id = BundleSeedId,
        bundle_id = BundleId,
        ssl_opts = SslOpts,
        fake_token = FakeToken,
        retry_delay = RetryDelay,
        close_timeout = CloseTimeout}.


validate_ssl_opts(Opts, BundleSeedId, BundleId) ->
    SslOpts = pv_req(ssl_opts, Opts),
    case pv(certfile, SslOpts) of
        undefined ->
            throw(missing_cert_or_file_opt);
        CertPath ->
            case file:read_file(CertPath) of
                {error, Reason} ->
                    throw({bad_cert_path, Reason});
                {ok, Bin} ->
                    case apns_cert:validate(Bin, BundleSeedId, BundleId) of
                        ok -> SslOpts;
                        {_ErrorClass, _Reason} = Reason ->
                            throw({bad_cert, Reason})
                    end
            end
    end.


validate_list(_Name, List) when is_list(List) -> List;

validate_list(Name, _Other) ->
    throw({bad_options, {not_a_list, Name}}).


validate_binary(_Name, Bin) when is_binary(Bin) -> Bin;

validate_binary(Name, _Other) ->
    throw({bad_options, {not_a_binary, Name}}).


validate_non_neg(_Name, Int) when is_integer(Int), Int >= 0 -> Int;

validate_non_neg(Name, Int) when is_integer(Int) ->
    throw({bad_options, {negative_integer, Name}});

validate_non_neg(Name, _Other) ->
    throw({bad_options, {not_an_integer, Name}}).


validate_host(Opts) ->
    validate_list(host, pv_req(host, Opts)).


validate_port(Opts) ->
    validate_non_neg(port, pv(port, Opts, ?DEFAULT_FEEDBACK_PORT)).


validate_bundle_seed_id(Opts) ->
    validate_binary(bundle_seed_id, pv_req(bundle_seed_id, Opts)).


validate_bundle_id(Opts) ->
    validate_binary(bundle_id, pv_req(bundle_id, Opts)).


validate_fake_token(Opts) ->
    validate_binary(fake_token, pv_req(fake_token, Opts)).


validate_retry_delay(Opts) ->
    validate_non_neg(retry_delay, pv(retry_delay, Opts, ?DEFAULT_RETRY_DELAY)).


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
%%% Reconnection Delay Functions
%%% --------------------------------------------------------------------------

schedule_reconnect(#?S{retry_ref = Ref, retry_delay = Delay} = State) ->
    catch erlang:cancel_timer(Ref),
    _ = lager:info("Feedback handler ~p will reconnect in ~w ms",
                   [State#?S.name, Delay]),
    NewRef = gen_fsm:send_event_after(Delay, connect),
    State#?S{retry_ref = NewRef}.


cancel_reconnect(#?S{retry_ref = Ref} = State) ->
    catch erlang:cancel_timer(Ref),
    State#?S{retry_ref = undefined}.


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

