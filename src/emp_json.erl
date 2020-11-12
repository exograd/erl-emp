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

-module(emp_json).

-export([intern_object_keys/1]).

-spec intern_object_keys(json:value()) -> json:value().
intern_object_keys(Value) when is_map(Value) ->
  maps:fold(fun
              (K, V, Acc) when is_atom(K) ->
                Acc#{K => V};
              (K, V, Acc) when is_binary(K) ->
                Acc#{binary_to_atom(K) => intern_object_keys(V)};
              (K, V, Acc) when is_list(K) ->
                Acc#{list_to_atom(K) => intern_object_keys(V)}
            end, #{}, Value);
intern_object_keys(Value) when is_list(Value) ->
  lists:map(fun intern_object_keys/1, Value);
intern_object_keys(Value) ->
  Value.
