-module(ws_client).

-behaviour(banana_websocket_client).

-export([
         start_link/0,
         start_link/1,
         start_link/2,
         socket/1,
         socket/2,
         send_text/2,
         send_binary/2,
         send_ping/2,
         sync_send_text/2,
         sync_send_binary/2,
         sync_send_ping/2,
         recv/2,
         recv/1,
         stop/1
        ]).

-export([
         init/1,
         onconnect/2,
         ondisconnect/2,
         websocket_handle/3,
         websocket_info/3,
         websocket_terminate/3
        ]).

-record(state, {
          buffer = [] :: list(),
          waiting = undefined :: undefined | pid()
         }).

start_link() ->
    {ok, _} = start_link("ws://localhost:8080").

start_link(Url) ->
    {ok, _} = banana_websocket_client:start_link(Url, ?MODULE, [self()]).

start_link(Url, KeepAlive) ->
    {ok, _} = banana_websocket_client:start_link(Url, ?MODULE, [self()], [{keepalive, KeepAlive}]).

stop(Pid) ->
    Pid ! stop.

socket(Pid) ->
    socket(Pid, 5000).
socket(Pid, Timeout) ->
    Pid ! {gimme_socket, self()},
    receive
        {hav_socket, Pid, Sock} -> {ok, Sock}
    after Timeout ->
              {error, timeout}
    end.

send_text(Pid, Msg) ->
    banana_websocket_client:cast(Pid, {text, Msg}).

send_binary(Pid, Msg) ->
    banana_websocket_client:cast(Pid, {binary, Msg}).

send_ping(Pid, Msg) ->
    banana_websocket_client:cast(Pid, {ping, Msg}).

sync_send_text(Pid, Msg) ->
    banana_websocket_client:send(Pid, {text, Msg}).

sync_send_binary(Pid, Msg) ->
    banana_websocket_client:send(Pid, {binary, Msg}).

sync_send_ping(Pid, Msg) ->
    banana_websocket_client:send(Pid, {ping, Msg}).

recv(Pid) ->
    recv(Pid, 5000).

recv(Pid, Timeout) ->
    Pid ! {recv, self()},
    receive
        M -> M
    after
        Timeout -> error
    end.

init([Waiting]) ->
    {reconnect, #state{waiting=Waiting}}.

onconnect(_WSReq, State) ->
    State#state.waiting ! {ok, self()},
    {ok, State}.

ondisconnect(Reason, State) ->
    {close, Reason, State}.

websocket_handle({Type, Payload}=Frame, _, State = #state{waiting = undefined, buffer = Buffer}) ->
    ct:pal("Client added ~p to buffer of size ~p~n", [Type, byte_size(Payload)]),
    {ok, State#state{buffer = Buffer++[Frame]}};
websocket_handle({Type,Payload}=Frame, _, State = #state{waiting = From}) ->
    ct:pal("Client forwarded ~p of size ~p to ~p ~n", [Type, byte_size(Payload), From]),
    From ! Frame,
    {ok, State#state{waiting = undefined}}.

websocket_info({recv, From}, _, State = #state{buffer = []}) ->
    {ok, State#state{waiting = From}};
websocket_info({recv, From}, _, State = #state{buffer = [Top|Rest]}) ->
    ct:pal("Sending buffer hd to: ~p {Buffer: ~p}~n", [From, [Top|Rest]]),
    From ! Top,
    {ok, State#state{buffer = Rest}};
websocket_info({gimme_socket, Whom}, WSReq, State) ->
    Sock = websocket_req:socket(WSReq),
    Whom ! {hav_socket, self(), Sock},
    {ok, State};
websocket_info(stop, _, State) ->
    {close, <<>>, State}.

websocket_terminate(Close, _, State) ->
    ct:pal("Websocket closed with frame ~p and state ~p~n", [Close, State]),
    ok.
