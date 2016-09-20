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

%%%-------------------------------------------------------------------
%%% @author Edwin Fine <efine@silentcircle.com>
%%% @copyright 2015 Silent Circle
%%% @doc
%%% APNS session supervisor.
%%% @end
%%%-------------------------------------------------------------------
-module(apns_erl_session_sup).

-behaviour(supervisor).

%% API
-export([
          start_link/1
        , start_child/2
        , stop_child/1
        , is_child_alive/1
        , get_child_pid/1
    ]).

%% Supervisor callbacks
-export([init/1]).

-include_lib("lager/include/lager.hrl").

-define(SERVER, ?MODULE).

%% ===================================================================
%% Types
%% ===================================================================
-type proplist() :: [proplists:property()].
-type session_props() :: proplist().
-type startlink_ret() :: {ok, pid()} |
                         ignore |
                         {error, startlink_err()}.
-type startlink_err() :: {already_started, pid()} |
                         {shutdown, term()}       |
                         term().
-type child() :: undefined | pid().
-type child_id() :: term(). % Not a pid().
-type mfargs() :: {M :: module(), F :: atom(), A :: [term()] | undefined}.
-type modules() :: [module()] | dynamic.
-type restart() :: permanent | transient | temporary.
-type shutdown() :: brutal_kill | timeout().
-type strategy() :: one_for_all |
                    one_for_one |
                    rest_for_one |
                    simple_one_for_one.
-type sup_ref() :: (Name :: atom())
                 | {Name :: atom(), Node :: node()}
                 | {global, Name :: atom()}
                 | {via, Module :: module(), Name :: any()}
                 | pid().
-type worker() :: worker | supervisor.
-type child_spec() :: {Id :: child_id(),
                       StartFunc :: mfargs(),
                       Restart :: restart(),
                       Shutdown :: shutdown(),
                       Type :: worker(),
                       Modules :: modules()}.
-type startchild_err() :: already_present
                          | {already_started, Child :: child()}
                          | term().
-type startchild_ret() :: {ok, Child :: child()}
                        | {ok, Child :: child(), Info :: term()}
                        | {error, startchild_err()}.

%% ===================================================================
%% API functions
%% ===================================================================

%%-------------------------------------------------------------------
%% @doc Start APNS sessions.
%%
%% `Sessions' is a list of proplists and looks like this:
%%
%% ```
%% [
%%     [
%%         {name, 'apns-com.example.Example'},
%%         {config, [
%%             {host, "gateway.sandbox.push.apple.com"},
%%             {port, 2195},
%%             {bundle_seed_id, <<"com.example.Example">>},
%%             {bundle_id, <<"com.example.Example">>},
%%             {fake_token, <<"XXXXXX">>},
%%             {retry_delay, 1000},
%%             {checkpoint_period, 60000},
%%             {checkpoint_max, 10000},
%%             {close_timeout, 5000},
%%             {ssl_opts, [
%%                     {certfile, "/etc/somewhere/certs/com.example.Example--DEV.cert.pem"},
%%                     {keyfile, "/etc/somewhere/certs/com.example.Example--DEV.key.unencrypted.pem"}
%%                 ]
%%             }
%%          ]}
%%     ] %, ...
%% ]
%% '''
%%
%% @end
%%-------------------------------------------------------------------

%%-------------------------------------------------------------------
-spec start_link(Sessions) -> startlink_ret() when
      Sessions :: [session_props()].
start_link(Sessions) when is_list(Sessions) ->
    case supervisor:start_link({local, ?SERVER}, ?MODULE, []) of
        {ok, _Pid} = Res ->
            % Start children
            _ = [{ok, _} = start_child(Opts) || Opts <- Sessions],
            Res;
        Error ->
            Error
    end.

%%-------------------------------------------------------------------
%% @doc Start a child session.
%%
%% == Parameters ==
%%
%% <ul>
%%  <li>`Name' - Session name (atom)</li>
%%  <li>`Opts' - Options, see {@link apns_erl_session} for more details</li>
%% </ul>
%%
%% @end
%%-------------------------------------------------------------------
-spec start_child(Name, Opts) -> Result when
      Name :: atom(), Opts :: proplist(), Result :: startchild_ret().
start_child(Name, Opts) when is_atom(Name), is_list(Opts) ->
    supervisor:start_child(?SERVER, [Name, Opts]).

%%-------------------------------------------------------------------
%% @doc Stop child session.
%% @end
%%-------------------------------------------------------------------
-spec stop_child(Name) -> Result when
      Name :: atom(), Result :: ok | {error, Error},
      Error :: not_found | simple_one_for_one.
stop_child(Name) when is_atom(Name) ->
    case get_child_pid(Name) of
        Pid when is_pid(Pid) ->
            supervisor:terminate_child(?SERVER, Pid);
        undefined ->
            {error, not_started}
    end.

%%-------------------------------------------------------------------
%% @doc Test if child is alive.
%% @end
%%-------------------------------------------------------------------
-spec is_child_alive(Name) -> boolean() when Name :: atom().
is_child_alive(Name) when is_atom(Name) ->
    get_child_pid(Name) =/= undefined.

%%-------------------------------------------------------------------
%% @doc Get a child's pid.
%% @end
%%-------------------------------------------------------------------
-spec get_child_pid(Name) -> pid() | undefined when Name :: atom().
get_child_pid(Name) when is_atom(Name) ->
    erlang:whereis(Name).

%% ===================================================================
%% Supervisor callbacks
%% ===================================================================

init([]) ->
    Session = {
        apns_erl_session,
        {apns_erl_session, start_link, []},
        transient,
        brutal_kill,
        worker,
        [apns_erl_session]
    },
    Children = [Session],
    MaxR = 20,
    MaxT = 20,
    RestartStrategy = {simple_one_for_one, MaxR, MaxT},
    {ok, {RestartStrategy, Children}}.

%%--------------------------------------------------------------------
%% Internal Functions
%%--------------------------------------------------------------------
start_child(Opts) ->
    _ = lager:info("Starting APNS session with opts: ~p", [Opts]),
    Name = sc_util:req_val(name, Opts),
    SessCfg = sc_util:req_val(config, Opts),
    start_child(Name, SessCfg).

