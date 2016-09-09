%%% ==========================================================================
%%% Copyright 2015,2016 Silent Circle
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
%%% @copyright 2015 Silent Circle
%%% @doc Apple Push Notification Service (APNS) API.
%%%
%%% This is the API to the Apple Push Notification Service Provider.
%%%
%%% == Synopsis ==
%%%
%%% === Starting a session ===
%%%
%%% ```
%%% Opts = [
%%%             {host, "gateway.sandbox.push.apple.com"},
%%%             {port, 2195},
%%%             {bundle_seed_id, <<"com.example.Push">>},
%%%             {bundle_id, <<"com.example.Push">>},
%%%             {ssl_opts, [
%%%                 {certfile, "/somewhere/cert.pem"},
%%%                 {keyfile, "/somewhere/key.unencrypted.pem"}
%%%                 ]
%%%             }
%%%         ],
%%%
%%% {ok, Pid} = sc_push_svc_apns:start_session(my_push_tester, Opts).
%%% '''
%%%
%%% === Sending an alert via the API ===
%%%
%%% ```
%%% Notification = [{alert, Alert}, {token, <<"e7b300...a67b">>}],
%%% {ok, SeqNo} = sc_push_svc_apns:send(my_push_tester, Notification).
%%% '''
%%%
%%% === Sending an alert via a session (for testing only) ===
%%%
%%% ```
%%% JSON = get_json_payload(), % See APNS docs for format
%%% {ok, SeqNo} = apns_erl_session:send(my_push_tester, Token, JSON).
%%% '''
%%%
%%% === Stopping a session ===
%%%
%%% ```
%%% ok = sc_push_svc_apns:stop_session(my_push_tester).
%%% '''
-module(sc_push_svc_apns).
-behaviour(supervisor).

%%--------------------------------------------------------------------
%% Includes
%%--------------------------------------------------------------------
-include_lib("lager/include/lager.hrl").

%%-----------------------------------------------------------------------
%% Types
%%-----------------------------------------------------------------------

%%--------------------------------------------------------------------
%% Defines
%%--------------------------------------------------------------------

%%--------------------------------------------------------------------
%% Records
%%--------------------------------------------------------------------

%%--------------------------------------------------------------------
%% API
%%--------------------------------------------------------------------
-export([
    start_link/1,
    start_session/2,
    stop_session/1,
    send/2,
    send/3,
    async_send/2,
    async_send/3
    ]).

%% Supervisor callbacks
-export([init/1]).

-define(SERVER, ?MODULE).

%% Helper macro for declaring children of supervisor
-define(CHILD(I, Type, Timeout),
    {I, {I, start_link, []}, permanent, Timeout, Type, [I]}
).

-define(CHILD_ARGS(I, Args, Type, Timeout),
    {I, {I, start_link, Args}, permanent, Timeout, Type, [I]}
).

%% ===================================================================
%% API functions
%% ===================================================================
%%--------------------------------------------------------------------
%% @doc `Opts' is a list of proplists.
%% Each proplist is a session definition containing
%% name, mod, and config keys.
%% @end
%%--------------------------------------------------------------------
-spec start_link(Opts::list()) -> {ok, pid()} | {error, term()}.
start_link(Opts) when is_list(Opts) ->
    supervisor:start_link({local, ?SERVER}, ?MODULE, Opts).

%%--------------------------------------------------------------------
%% @doc Start named session for specific host and certificate as
%% supplied in the proplist `Opts'.
%% @see apns_erl_session_sup:start_child/2.
%% @end
%%--------------------------------------------------------------------
-spec start_session(atom(), list()) -> {ok, pid()} | {error, already_started} |
    {error, Reason::term()}.
start_session(Name, Opts) when is_atom(Name), is_list(Opts) ->
    apns_erl_session_sup:start_child(Name, Opts).

%%--------------------------------------------------------------------
%% @doc Stop named session.
%% @end
%%--------------------------------------------------------------------
-spec stop_session(Name::atom()) -> ok | {error, Reason::term()}.
stop_session(Name) when is_atom(Name) ->
    apns_erl_session_sup:stop_child(Name).

%%--------------------------------------------------------------------
%% @doc Send a notification specified by proplist `Notification'
%% to `SvrRef'.
%%
%% Set the notification to expire in a very very long time.
%%
%% === Example ===
%% Send an alert with a sound and extra data
%% ```
%% Name = 'com.example.AppId',
%% Notification = [
%%    {alert, <<"Hello">>},
%%    {token, <<"ea3f...">>},
%%    {aps, [
%%      {sound, <<"bang">>},
%%      {extra, [{a, 1}]}]}
%% ],
%% sc_push_svc_apns:send(Name, Notification).
%% '''
%% @see send/3.
%% @end
%%--------------------------------------------------------------------
-type gen_proplist() :: sc_types:proplist(atom(), term()).
-spec send(term(), gen_proplist()) ->
    {ok, Ref::term()} | {error, Reason::term()}.
send(Name, Notification) when is_list(Notification) ->
    send(sync, Name, Notification, []).

%%--------------------------------------------------------------------
%% @doc Send a notification specified by proplist `Notification'
%% via `SvrRef' using options `Opts'.
%% Note that `Opts' currently has no supported actions.
%% @end
%%--------------------------------------------------------------------
-spec send(term(), gen_proplist(), gen_proplist()) ->
    {ok, Ref::term()} | {error, Reason::term()}.
send(Name, Notification, Opts) when is_list(Notification), is_list(Opts) ->
    send(sync, Name, Notification, Opts).

%%--------------------------------------------------------------------
%% @doc Asynchronously sends a notification specified by proplist `Notification'
%% to `SvrRef'; Same as {@link send/2} beside returning only 'ok' for success.
%% @end
%%--------------------------------------------------------------------
-spec async_send(term(), gen_proplist()) ->
    ok | {error, Reason::term()}.
async_send(Name, Notification) when is_list(Notification) ->
    send(async, Name, Notification, []).

%%--------------------------------------------------------------------
%% @doc Asynchronously sends a notification specified by proplist `Notification'
%% to `SvrRef'; Same as {@link send/3} beside returning only 'ok' for success.
%% @end
%%--------------------------------------------------------------------
-spec async_send(term(), gen_proplist(), gen_proplist()) ->
    ok | {error, Reason::term()}.
async_send(Name, Notification, Opts) when is_list(Notification), is_list(Opts) ->
    send(async, Name, Notification, Opts).

%% ===================================================================
%% Supervisor callbacks
%% ===================================================================

init(Opts) ->
    _ = lager:info("Starting service with opts: ~p", [Opts]),
    RestartStrategy    = one_for_one,
    MaxRestarts        = 10, % If there are more than this many restarts
    MaxTimeBetRestarts = 60, % In this many seconds, then terminate supervisor

    SupFlags = {RestartStrategy, MaxRestarts, MaxTimeBetRestarts},

    Children = [
        ?CHILD_ARGS(apns_erl_session_sup, [Opts], supervisor, infinity)
    ],

    {ok, {SupFlags, Children}}.

%%--------------------------------------------------------------------
%% Internal functions
%%--------------------------------------------------------------------
send(Mode, Name, Notification, Opts) when is_list(Notification), is_list(Opts) ->
    Token = sc_util:req_val(token, Notification),
    APS = make_aps(Notification),
    JSON = apns_json:make_notification(APS),
    case {Mode, sc_util:val(expiry, APS)} of
        {sync, undefined} ->
            apns_erl_session:send(Name, Token, JSON);
        {sync, Expiry} ->
            apns_erl_session:send(Name, Expiry, Token, JSON);
        {async, undefined} ->
            apns_erl_session:async_send(Name, Token, JSON);
        {async, Expiry} ->
            apns_erl_session:async_send(Name, Expiry, Token, JSON)
    end.

make_aps(Notification) ->
    APS0 = sc_util:val(aps, Notification, []),
    APSAlert = sc_util:val(alert, Notification, sc_util:val(alert, APS0, <<>>)),
    [{alert, APSAlert} | lists:keydelete(alert, 1, APS0)].

-ifdef(FUTURE_FUNCTIONALITY).

do_cb(Result, Opts) when is_list(Opts) ->
    case proplists:get_value(callback, Opts) of
        {Pid, Subscriptions} when is_list(Subscriptions) ->
            case lists:member(completion, Subscriptions) of
                true ->
                    {Ref, Msg} = get_ref_result(Result),
                    Pid ! {apns_erl, completion, Ref, Msg};
                false ->
                    ok
            end;
        _ ->
            ok
    end,
    ok.

get_ref_result({ok, Ref}) ->
    {Ref, ok};
get_ref_result({error, _Term} = Res) ->
    {undefined, Res}.

apply_override(OverrideProps, BaseProps) ->
    ReplaceEntry = fun({K, V}, Dict) -> gb_trees:enter(K, V, Dict) end,
    D = lists:foldl(ReplaceEntry, gb_trees:empty(), BaseProps ++ OverrideProps),
    gb_trees:to_list(D).

-endif.
