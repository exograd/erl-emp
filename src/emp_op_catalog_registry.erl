%% Copyright (c) 2020-2021 Nicolas Martyanoff <khaelin@gmail.com>.
%%
%% Permission to use, copy, modify, and/or distribute this software for any
%% purpose with or without fee is hereby granted, provided that the above
%% copyright notice and this permission notice appear in all copies.
%%
%% THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
%% WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
%% MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY
%% SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
%% WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
%% ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF OR
%% IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.

-module(emp_op_catalog_registry).

-include_lib("kernel/include/logger.hrl").

-behaviour(gen_server).

-export([table_name/1, start_link/0, install_catalog/2, uninstall_catalog/1]).
-export([init/1, terminate/2, handle_call/3, handle_cast/2, handle_info/2]).

-type state() :: #{}.

-spec table_name(emp:op_catalog_name()) -> emp:op_table_name().
table_name(Name) ->
  Bin = <<"emp_op_catalog_", (atom_to_binary(Name))/binary>>,
  binary_to_atom(Bin).

-spec start_link() -> Result when
    Result :: {ok, pid()} | ignore | {error, term()}.
start_link() ->
  gen_server:start_link({local, ?MODULE}, ?MODULE, [], []).

-spec install_catalog(emp:op_catalog_name(), emp:op_catalog()) ->
        emp:op_table_name().
install_catalog(Name, Catalog) ->
  gen_server:call(?MODULE, {install_catalog, Name, Catalog}).

-spec uninstall_catalog(emp:op_catalog_name()) -> ok.
uninstall_catalog(Name) ->
  gen_server:call(?MODULE, {uninstall_catalog, Name}).

-spec init(list()) -> {ok, state()}.
init([]) ->
  logger:update_process_metadata(#{domain => [emp, op_catalog_registry]}),
  do_install_catalog(internal, emp_ops:internal_op_catalog()),
  State = #{},
  {ok, State}.

terminate(_Reason, _State) ->
  ok.

handle_call({install_catalog, Name, Catalog}, _From, State) ->
  TableName = do_install_catalog(Name, Catalog),
  {reply, TableName, State};

handle_call({uninstall_catalog, Name}, _From, State) ->
  ok = do_uninstall_catalog(Name),
  {reply, ok, State};

handle_call(Msg, From, State) ->
  ?LOG_WARNING("unhandled call ~p from ~p", [Msg, From]),
  {reply, unhandled, State}.

handle_cast(Msg, State) ->
  ?LOG_WARNING("unhandled cast ~p", [Msg]),
  {noreply, State}.

handle_info(Msg, State) ->
  ?LOG_WARNING("unhandled info ~p", [Msg]),
  {noreply, State}.

-spec do_install_catalog(emp:op_catalog_name(), emp:op_catalog()) ->
        emp:op_table_name().
do_install_catalog(Name, Catalog) ->
  TableName = table_name(Name),
  ets:new(TableName, [set,
                      named_table,
                      {read_concurrency, true}]),
  lists:foreach(fun (Pair) ->
                    ets:insert(TableName, Pair)
                end, maps:to_list(Catalog)),
  Name.

-spec do_uninstall_catalog(emp:op_catalog_name()) -> ok.
do_uninstall_catalog(Name) ->
  TableName = table_name(Name),
  ets:delete(TableName),
  ok.
