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
%%% Application callbacks.
%%% @end
%%%-------------------------------------------------------------------
-module(apns_erl_app).

-behaviour(application).

%% Application callbacks
-export([start/2, stop/1]).

-include_lib("lager/include/lager.hrl").

%% ===================================================================
%% Application callbacks
%% ===================================================================
%%--------------------------------------------------------------------
%% @doc
%% This function is called whenever an application is started using
%% application:start/[1,2], and should start the processes of the
%% application. If the application is structured according to the OTP
%% design principles as a supervision tree, this means starting the
%% top supervisor of the tree.
%% @end
%%--------------------------------------------------------------------
-spec start(StartType, StartArgs) -> Result when
      StartType :: normal | {takeover, Node} | {failover, Node},
      StartArgs :: term(),
      Result :: {ok, Pid} |
                {ok, Pid, State} |
                {error, Reason},
      Node :: node(), Pid :: pid(), State :: term(), Reason :: term().
start(_StartType, _StartArgs) ->
    Cfg = get_config(),
    {App, Opts, Sessions, Service} = Cfg,
    _ = case check_config(Cfg) of
            true ->
                lager:info("Starting app ~p with opts: ~p", [App, Opts]);
            false ->
                lager:warning("No config found; starting inactive service")
        end,
    case sc_push_svc_apns:start_link(Sessions) of
        {ok, _} = Res ->
            register_service(Service),
            Res;
        Err ->
            Err
    end.

%%--------------------------------------------------------------------
%% @doc
%% This function is called whenever an application has stopped. It
%% is intended to be the opposite of Module:start/2 and should do
%% any necessary cleaning up. The return value is ignored.
%% @end
%%--------------------------------------------------------------------
-spec stop(State) -> 'ok' when State :: term().
stop(_State) ->
    {_App, _Opts, _Sessions, Service} = get_config(),
    _ = try
            unregister_service(Service)
        catch
            Class:Reason ->
                lager:error("Unable to deregister apns service: ~p",
                            [{Class, Reason}])
        end,
    ok.

%%--------------------------------------------------------------------
%% @doc Get sessions and service
%% @end
%%--------------------------------------------------------------------
get_config() ->
    case application:get_application(?MODULE) of
        {ok, App} ->
            Opts = application:get_all_env(App),
            Sessions = sc_util:val(sessions, Opts, []),
            Service = sc_util:val(service, Opts, undefined),
            {App, Opts, Sessions, Service};
        undefined ->
            lager:warning("No environment for ~p", [?MODULE]),
            {{error, undefined}, [], [], undefined}
    end.


%%--------------------------------------------------------------------
register_service(undefined) ->
    ok;
register_service(Service) ->
    ok = sc_push_lib:register_service(Service).

%%--------------------------------------------------------------------
unregister_service(undefined) ->
    ok;
unregister_service(Service) ->
    case sc_util:val(name, Service, undefined) of
        undefined ->
            ok;
        SvcName ->
            sc_push_lib:unregister_service(SvcName)
    end.

check_config({App, _Opts, Sessions, Service}) ->
    check_app(App) and
    check_sessions(Sessions) and
    check_service(Service).

check_app(App) ->
    maybe_do(fun() -> App /= {error, undefined} end,
             fun() -> lager:warning("No app found") end).

check_sessions(Sessions) ->
    maybe_do(fun() -> is_list(Sessions) andalso Sessions /= [] end,
             fun() -> lager:warning("No sessions found") end).

check_service(Service) ->
    maybe_do(fun() -> Service /= undefined end,
             fun() -> lager:warning("No service found") end).

maybe_do(Pred, Fun) when is_function(Pred, 0),
                         is_function(Fun, 0) ->
    case Pred() of
        true -> true;
        false -> _ = Fun(), false
    end.

