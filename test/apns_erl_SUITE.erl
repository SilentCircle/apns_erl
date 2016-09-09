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

%%%----------------------------------------------------------------
%%% Purpose: Test suite for the 'apns_erl' module.
%%%-----------------------------------------------------------------

-module(apns_erl_SUITE).

-include_lib("common_test/include/ct.hrl").

-compile(export_all).

-define(assertMsg(Cond, Fmt, Args),
        case (Cond) of
        true ->
            ok;
        false ->
            ct:fail("Assertion failed: ~p~n" ++ Fmt, [??Cond] ++ Args)
    end
       ).

-define(assert(Cond), ?assertMsg((Cond), "", [])).

%%--------------------------------------------------------------------
%% COMMON TEST CALLBACK FUNCTIONS
%%--------------------------------------------------------------------

%%--------------------------------------------------------------------
%% Function: suite() -> Info
%%
%% Info = [tuple()]
%%   List of key/value pairs.
%%
%% Description: Returns list of tuples to set default properties
%%              for the suite.
%%
%% Note: The suite/0 function is only meant to be used to return
%% default data values, not perform any other operations.
%%--------------------------------------------------------------------
suite() -> [
        {timetrap, {seconds, 30}},
        {require, sessions}
        ].

%%--------------------------------------------------------------------
%% Function: init_per_suite(Config0) ->
%%               Config1 | {skip,Reason} | {skip_and_save,Reason,Config1}
%%
%% Config0 = Config1 = [tuple()]
%%   A list of key/value pairs, holding the test case configuration.
%% Reason = term()
%%   The reason for skipping the suite.
%%
%% Description: Initialization before the suite.
%%
%% Note: This function is free to add any key/value pairs to the Config
%% variable, but should NOT alter/remove any existing entries.
%%--------------------------------------------------------------------
init_per_suite(Config) ->
    lager:start(),
    % ct:get_config(sessions) -> [Session].
    % Session = [{name, atom()}, {certfile, string()}].
    Sessions = ct:get_config(sessions),
    ct:pal("Sessions: ~p~n", [Sessions]),
    [{sessions, Sessions} | Config].

%%--------------------------------------------------------------------
%% Function: end_per_suite(Config0) -> void() | {save_config,Config1}
%%
%% Config0 = Config1 = [tuple()]
%%   A list of key/value pairs, holding the test case configuration.
%%
%% Description: Cleanup after the suite.
%%--------------------------------------------------------------------
end_per_suite(Config) ->
    Config.

%%--------------------------------------------------------------------
%% Function: init_per_group(GroupName, Config0) ->
%%               Config1 | {skip,Reason} | {skip_and_save,Reason,Config1}
%%
%% GroupName = atom()
%%   Name of the test case group that is about to run.
%% Config0 = Config1 = [tuple()]
%%   A list of key/value pairs, holding configuration data for the group.
%% Reason = term()
%%   The reason for skipping all test cases and subgroups in the group.
%%
%% Description: Initialization before each test case group.
%%--------------------------------------------------------------------
init_per_group(session, Config) ->
    SessionStarter = fun() -> apns_erl_session_sup:start_link([]) end,
    start_group(SessionStarter, Config);
init_per_group(pre_started_session, Config) ->
    Sessions = value(sessions, Config),
    SessionStarter = fun() -> apns_erl_session_sup:start_link(Sessions) end,
    start_group(SessionStarter, Config);
init_per_group(_GroupName, Config) ->
    Badge = get_saved_value(badge, Config, 0),
    add_prop({badge, Badge}, Config).


%%--------------------------------------------------------------------
%% Function: end_per_group(GroupName, Config0) ->
%%               void() | {save_config,Config1}
%%
%% GroupName = atom()
%%   Name of the test case group that is finished.
%% Config0 = Config1 = [tuple()]
%%   A list of key/value pairs, holding configuration data for the group.
%%
%% Description: Cleanup after each test case group.
%%--------------------------------------------------------------------
end_per_group(session, Config) ->
    {_, OldConfig} = value(saved_config, Config),
    Badge = value(badge, OldConfig),
    SessSupPid = value(sess_sup_pid, Config),
    exit(SessSupPid, kill),
    ok = ssl:stop(),
    {save_config, new_prop(badge, Badge)};
end_per_group(pre_started_session, Config) ->
    {_, OldConfig} = value(saved_config, Config),
    Badge = value(badge, OldConfig),
    {save_config, new_prop(badge, Badge)};
end_per_group(_GroupName, Config) ->
    {_, OldConfig} = value(saved_config, Config),
    Badge = value(badge, OldConfig),
    {save_config, new_prop(badge, Badge)}.

%%--------------------------------------------------------------------
%% Function: init_per_testcase(TestCase, Config0) ->
%%               Config1 | {skip,Reason} | {skip_and_save,Reason,Config1}
%%
%% TestCase = atom()
%%   Name of the test case that is about to run.
%% Config0 = Config1 = [tuple()]
%%   A list of key/value pairs, holding the test case configuration.
%% Reason = term()
%%   The reason for skipping the test case.
%%
%% Description: Initialization before each test case.
%%
%% Note: This function is free to add any key/value pairs to the Config
%% variable, but should NOT alter/remove any existing entries.
%%--------------------------------------------------------------------
init_per_testcase(_Case, Config) ->
    Config.

%%--------------------------------------------------------------------
%% Function: end_per_testcase(TestCase, Config0) ->
%%               void() | {save_config,Config1} | {fail,Reason}
%%
%% TestCase = atom()
%%   Name of the test case that is finished.
%% Config0 = Config1 = [tuple()]
%%   A list of key/value pairs, holding the test case configuration.
%% Reason = term()
%%   The reason for failing the test case.
%%
%% Description: Cleanup after each test case.
%%--------------------------------------------------------------------
end_per_testcase(_Case, _Config) ->
    ok.

%%--------------------------------------------------------------------
%% Function: groups() -> [Group]
%%
%% Group = {GroupName,Properties,GroupsAndTestCases}
%% GroupName = atom()
%%   The name of the group.
%% Properties = [parallel | sequence | Shuffle | {RepeatType,N}]
%%   Group properties that may be combined.
%% GroupsAndTestCases = [Group | {group,GroupName} | TestCase]
%% TestCase = atom()
%%   The name of a test case.
%% Shuffle = shuffle | {shuffle,Seed}
%%   To get cases executed in random order.
%% Seed = {integer(),integer(),integer()}
%% RepeatType = repeat | repeat_until_all_ok | repeat_until_all_fail |
%%              repeat_until_any_ok | repeat_until_any_fail
%%   To get execution of cases repeated.
%% N = integer() | forever
%%
%% Description: Returns a list of test case group definitions.
%%--------------------------------------------------------------------
groups() ->
    [
        {
            session,
            [],
            [
                start_session_test,
                clear_badge_test,
                {group, clients},
                stop_session_test
            ]
            },
        {
            pre_started_session,
            [],
            [
                {group, clients}
            ]
            },
        {
            clients,
            [],
            [
                send_msg_test,
                send_msg_via_api_test,
                send_msg_sound_badge_test,
                send_msg_with_alert_proplist
            ]
            }
    ].

%%--------------------------------------------------------------------
%% Function: all() -> GroupsAndTestCases | {skip,Reason}
%%
%% GroupsAndTestCases = [{group,GroupName} | TestCase]
%% GroupName = atom()
%%   Name of a test case group.
%% TestCase = atom()
%%   Name of a test case.
%% Reason = term()
%%   The reason for skipping all groups and test cases.
%%
%% Description: Returns the list of groups and test cases that
%%              are to be executed.
%%--------------------------------------------------------------------
all() ->
    [
        {group, session},
        {group, pre_started_session}
    ].

%%--------------------------------------------------------------------
%% TEST CASES
%%--------------------------------------------------------------------

% t_1(doc) -> ["t/1 should return 0 on an empty list"];
% t_1(suite) -> [];
% t_1(Config) when is_list(Config)  ->
%     ?line 0 = t:foo([]),
%     ok.

start_session_test() ->
    [].

start_session_test(doc) ->
    ["sc_push_svc_apns:start_session/2 should start a named APNS session"];
start_session_test(suite) ->
    [];
start_session_test(Config) ->
    Badge = get_saved_value(badge, Config, 0),
    [
            begin
                {ok, Pid} = start_session(Session),
                ?assert(is_pid(Pid))
            end || Session <- value(sessions, Config)
    ],
    {save_config, new_prop(badge, Badge)}.

stop_session_test() ->
    [].

stop_session_test(doc) ->
    ["sc_push_svc_apns:stop_session/1 should stop a named APNS session"];
stop_session_test(suite) ->
    [];
stop_session_test(Config) ->
    Badge = get_saved_value(badge, Config, 0),
    [ok = stop_session(Session) || Session <- value(sessions, Config)],
    {save_config, new_prop(badge, Badge)}.

clear_badge_test(doc) ->
    ["sc_push_svc_apns:send/3 should clear the badge"];
clear_badge_test(suite) ->
    [];
clear_badge_test(Config) ->
    NewBadge = 0,
    [
        begin
            Opts = Session,
            Name = value(name, Opts),
            Token = sc_util:hex_to_bitstring(value(token, Opts)),
            JSON = props_to_aps_json(new_prop(badge, NewBadge)),
            {ok, SeqNo} = apns_erl_session:send(Name, Token, JSON),
            ct:pal("Sent notification via session, badge = ~p, seq no = ~p",
                   [NewBadge, SeqNo])
        end || Session <- value(sessions, Config)
    ],
    {save_config, new_prop(badge, NewBadge)}.

send_msg_test(doc) ->
    ["apns_erl_session:send/3 should send a message to APNS"];
send_msg_test(suite) ->
    [];
send_msg_test(Config) ->
    NewBadge = get_saved_value(badge, Config, 0) + 1,
    [
        begin
            Name = value(name, Session),
            Token = list_to_binary(value(token, Session)),
            Alert = "Testing svr '" ++ atom_to_list(Name) ++ "'",
            JSON = props_to_aps_json(make_aps_props(Alert, NewBadge)),
            {ok, SeqNo} = apns_erl_session:send(Name, Token, JSON),
            ct:pal("Sent notification via session, badge = ~p, seq no = ~p",
                   [NewBadge, SeqNo])
        end || Session <- value(sessions, Config)
    ],
    {save_config, new_prop(badge, NewBadge)}.

send_msg_via_api_test(doc) ->
    ["sc_push_svc_apns:send/3 should send a message to APNS"];
send_msg_via_api_test(suite) ->
    [];
send_msg_via_api_test(Config) ->
    NewBadge = get_saved_value(badge, Config, 0) + 1,
    [
        begin
            Opts = Session,
            Name = value(name, Opts),
            Alert = "Testing svr '" ++ atom_to_list(Name) ++ "'",
            Token = list_to_binary(value(token, Opts)),
            Notification = [{alert, Alert}, {token, Token},
                            {aps, [{badge, NewBadge}]}],
            {ok, SeqNo} = sc_push_svc_apns:send(Name, Notification),
            ct:pal("Sent notification via API, badge = ~p, seq no = ~p",
                   [NewBadge, SeqNo])
        end || Session <- value(sessions, Config)
    ],
    {save_config, new_prop(badge, NewBadge)}.

send_msg_sound_badge_test(doc) ->
    ["sc_push_svc_apns:send/3 should send a message, sound, and badge to APNS"];
send_msg_sound_badge_test(suite) ->
    [];
send_msg_sound_badge_test(Config) ->
    NewBadge = get_saved_value(badge, Config, 0) + 1,
    [
        begin
            Opts = Session,
            Name = value(name, Opts),
            Token = list_to_binary(value(token, Opts)),
            Alert = list_to_binary([<<"Hi, this is ">>, atom_to_list(Name),
                                    <<", would you like to play a game?">>]),
            Notification = [
                    {'alert', Alert},
                    {'token', Token},
                    {'aps', [
                            {'badge', NewBadge},
                            {'sound', <<"wopr">>}]}
                    ],

            {ok, SeqNo} = sc_push_svc_apns:send(Name, Notification),
            ct:pal("Sent notification via API, badge = ~p, seq no = ~p",
                   [NewBadge, SeqNo])
        end || Session <- value(sessions, Config)
    ],
    {save_config, new_prop(badge, NewBadge)}.

send_msg_with_alert_proplist(doc) ->
    ["sc_push_svc_apns:send/3 should send a message to APNS"];
send_msg_with_alert_proplist(suite) ->
    [];
send_msg_with_alert_proplist(Config) ->
    NewBadge = get_saved_value(badge, Config, 0) + 1,
    [
        begin
            Opts = Session,
            Name = value(name, Opts),
            Token = list_to_binary(value(token, Opts)),
            Alert = list_to_binary([<<"Testing svr '">>, atom_to_list(Name),
                                    <<"' with alert dict.">>]),
            Notification = [{alert, [{body, Alert}]}, {token, Token},
                            {aps, [{badge, NewBadge}]}],
            {ok, SeqNo} = sc_push_svc_apns:send(Name, Notification),
            ct:pal("Sent notification via API, badge = ~p, seq no = ~p",
                   [NewBadge, SeqNo])
        end || Session <- value(sessions, Config)
    ],
    {save_config, new_prop(badge, NewBadge)}.

%%====================================================================
%% Internal helper functions
%%====================================================================
start_session(Opts) when is_list(Opts) ->
    Name = value(name, Opts),
    Config = value(config, Opts),
    {ok, Cwd} = file:get_cwd(),
    ct:pal("Current directory is ~p~n", [Cwd]),
    ct:pal("Starting session ~p with Config ~p~n", [Name, Config]),
    sc_push_svc_apns:start_session(Name, Config).

stop_session(Opts) when is_list(Opts) ->
    Name = value(name, Opts),
    ct:pal("Stopping session ~p~n", [Name]),
    sc_push_svc_apns:stop_session(Name).

start_group(SessionStarter, Config) ->
    Badge = get_saved_value(badge, Config, 0),
    ok = ssl:start(),
    {ok, SessSupPid} = SessionStarter(),
    unlink(SessSupPid),
    add_props([{badge, Badge},
               {sess_sup_pid, SessSupPid}], Config).

get_saved_value(K, Config, Def) ->
    case ?config(saved_config, Config) of
        undefined ->
            proplists:get_value(K, Config, Def);
        {_, OldConfig} ->
            proplists:get_value(K, OldConfig, Def)
    end.

value(Key, Config) ->
    V = proplists:get_value(Key, Config),
    ?assertMsg(V =/= undefined, "Required key missing: ~p~n", [Key]),
    V.

value(Key, Config, Def) ->
    proplists:get_value(Key, Config, Def).

props_to_aps_json(ApsProps) when is_list(ApsProps) ->
    jsx:encode([{aps, ApsProps}]).

to_bin_prop(K, V) ->
    {sc_util:to_atom(K), sc_util:to_bin(V)}.

make_aps_props(Alert) ->
    new_prop(to_bin_prop(alert, Alert)).

make_aps_props(Alert, Badge) when is_integer(Badge) ->
    add_prop({badge, Badge}, make_aps_props(Alert)).

make_aps_props(Alert, Badge, Sound) when is_integer(Badge) ->
    add_prop(to_bin_prop(sound, Sound), make_aps_props(Alert, Badge)).

add_props(FromProps, ToProps) ->
    lists:foldl(fun(KV, Acc) -> add_prop(KV, Acc) end, ToProps, FromProps).

add_prop({K, _V} = KV, Props) ->
    lists:keystore(K, 1, Props, KV).

new_prop({_, _} = KV) ->
    [KV].

new_prop(K, V) ->
    new_prop({K, V}).

