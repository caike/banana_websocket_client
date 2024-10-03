-module(sample_ws_handler).

-behaviour(banana_websocket_client).

-export([
         start_link/0,
         init/1,
         onconnect/2,
         ondisconnect/2,
         websocket_handle/3,
         websocket_info/3,
         websocket_terminate/3
        ]).

start_link() ->
    crypto:start(),
    ssl:start(),
    banana_websocket_client:start_link("wss://echo.websocket.org", ?MODULE, []).

init([]) ->
    {once, 2}.

onconnect(_WSReq, State) ->
    banana_websocket_client:cast(self(), {text, <<"message 1">>}),
    {ok, State}.

ondisconnect({remote, closed}, State) ->
    {reconnect, State}.

websocket_handle({pong, _}, _ConnState, State) ->
    {ok, State};
websocket_handle({text, Msg}, _ConnState, 5) ->
    io:format("Received msg ~p~n", [Msg]),
    {close, <<>>, "done"};
websocket_handle({text, Msg}, _ConnState, State) ->
    io:format("Received msg ~p~n", [Msg]),
    timer:sleep(1000),
    BinInt = list_to_binary(integer_to_list(State)),
    {reply, {text, <<"hello, this is message #", BinInt/binary >>}, State + 1}.

websocket_info(start, _ConnState, State) ->
    {reply, {text, <<"erlang message received">>}, State}.

websocket_terminate(Reason, _ConnState, State) ->
    io:format("Websocket closed in state ~p with reason ~p~n",
              [State, Reason]),
    ok.
