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
    {ok, App} = application:get_application(?MODULE),
    Opts = application:get_all_env(App),
    _ = lager:info("Starting app ~p with opts: ~p", [App, Opts]),
    Sessions = sc_util:req_val(sessions, Opts),
    Service = sc_util:req_val(service, Opts),
    case sc_push_svc_apns:start_link(Sessions) of
        {ok, _} = Res ->
            ok = sc_push_lib:register_service(Service),
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
    _ = try
        {ok, App} = application:get_application(?MODULE),
        Opts = application:get_all_env(App),
        Service = sc_util:req_val(service, Opts),
        SvcName = sc_util:req_val(name, Service),
        sc_push_lib:unregister_service(SvcName)
    catch
        Class:Reason ->
            lager:error("Unable to deregister apns service: ~p",
                        [{Class, Reason}])
    end,
    ok.
