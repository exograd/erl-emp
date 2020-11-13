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

-module(emp_request).

-export([serialize/1, parse/2, definition/0]).

-export_type([parse_error_reason/0]).

-type parse_error_reason() :: {invalid_data, json:error()}
                            | {invalid_value, [jsv:value_error()]}
                            | {invalid_op, binary()}.

-spec serialize(emp:request()) -> iodata().
serialize(#{op := Op, data := Data}) ->
  Value = #{op => Op, data => Data},
  json:serialize(Value).

-spec parse(emp_proto:message(), emp_ops:op_table_name()) ->
        {ok, emp:request()} | {error, parse_error_reason()}.
parse(#{body := #{id := Id, data := Data}}, OpTableName) ->
  case json:parse(Data) of
    {ok, Value} ->
      case emp_jsv:validate(Value, definition()) of
        ok ->
          #{<<"op">> := OpName,
            <<"data">> := DataObject} = Value,
          case validate_data(OpName, DataObject, OpTableName) of
            ok ->
              Request = #{id => Id,
                          op => OpName,
                          data => emp_json:intern_object_keys(DataObject)},
              {ok, Request};
            {error, Reason} ->
              {error, Reason}
          end;
        {error, Errors} ->
          {error, {invalid_value, Errors}}
      end;
    {error, Error} ->
      {error, {invalid_data, Error}}
  end.

-spec validate_data(emp:op_name(), json:value(), emp_ops:op_table_name()) ->
        ok | {error, parse_error_reason()}.
validate_data(OpName, Value, OpTableName) ->
  case emp_ops:find_op(OpName, OpTableName) of
    {ok, #{input := InputDefinition}} ->
      case emp_jsv:validate(Value, InputDefinition) of
        ok ->
          ok;
        {error, Errors} ->
          {error, {invalid_value, Errors}}
      end;
    error ->
      {error, {invalid_op, OpName}}
  end.

-spec definition() -> jsv:definition().
definition() ->
  {object, #{members => #{op => string,
                          data => object},
             required => [op, data]}}.
