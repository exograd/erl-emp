%% Copyright (c) 2020 Nicolas Martyanoff <khaelin@gmail.com>.
%%
%% Permission to use, copy, modify, and/or distribute this software for any
%% purpose with or without fee is hereby granted, provided that the above
%% copyright notice and this permission notice appear in all copies.
%%
%% THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES WITH
%% REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF MERCHANTABILITY
%% AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY SPECIAL, DIRECT,
%% INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES WHATSOEVER RESULTING FROM
%% LOSS OF USE, DATA OR PROFITS, WHETHER IN AN ACTION OF CONTRACT, NEGLIGENCE OR
%% OTHER TORTIOUS ACTION, ARISING OUT OF OR IN CONNECTION WITH THE USE OR
%% PERFORMANCE OF THIS SOFTWARE.

-module(emp_ops).

-export([table_name/1, install_op_table/2, uninstall_op_table/1,
         find_op/2, all_ops/1, serialize_op/2,
         internal_op_table/0]).

-export_type([op_table_name/0]).

-type op_table_name() :: atom().

-spec table_name(atom()) -> emp:op_table_name().
table_name(Name) ->
  Bin = <<"emp_op_table_", (atom_to_binary(Name))/binary>>,
  binary_to_atom(Bin).

-spec install_op_table(Name :: atom(), emp:op_table()) -> ok.
install_op_table(Name, Ops) ->
  TableName = table_name(Name),
  Ops2 = maps:merge(Ops, internal_op_table()),
  ets:new(TableName, [set,
                      named_table,
                      {read_concurrency, true}]),
  lists:foreach(fun (Pair) ->
                    ets:insert(TableName, Pair)
                end, maps:to_list(Ops2)),
  ok.

-spec uninstall_op_table(Name :: atom()) -> ok.
uninstall_op_table(Name) ->
  TableName = table_name(Name),
  ets:delete(TableName),
  ok.

-spec find_op(emp:op_name(), emp_ops:op_table_name()) ->
        {ok, emp:op()} | error.
find_op(Name, OpTableName) ->
  case ets:whereis(OpTableName) of
    undefined ->
      error({missing_op_table, OpTableName});
    Ref ->
      case ets:lookup(Ref, Name) of
        [{_, Op}] -> {ok, Op};
        [] -> error
      end
  end.

-spec all_ops(emp_ops:op_table_name()) ->
        #{emp:op_name() => emp:op()}.
all_ops(OpTableName) ->
  maps:from_list(ets:tab2list(OpTableName)).

-spec serialize_op(emp:op_name(), emp:op()) -> json:value().
serialize_op(OpName, _Op) ->
  %% TODO
  #{name => OpName}.

-spec internal_op_table() -> emp:op_table().
internal_op_table() ->
  #{<<"$echo">> =>
      #{input => object,
        output => object},
   <<"$get_op">> =>
      #{input =>
          {object, #{members =>
                       #{op_name => string},
                     required =>
                       [op_name]}},
        output =>
          {object, #{members =>
                       #{op => {ref, emp, op}},
                     required =>
                       [op]}}},
   <<"$list_ops">> =>
      #{input =>
          object,
        output =>
          {object, #{members =>
                       #{ops => {ref, emp, ops}},
                     required =>
                       [ops]}}}}.
