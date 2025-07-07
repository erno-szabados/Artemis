(** HttpClient.Mod - Nonblocking HTTP client state machine for Oberon-07

Copyright (C) 2025 Artemis Project Contributors

Released under The 3-Clause BSD License.
*)
MODULE HttpClient;

IMPORT DStrings, HttpRequest, HttpResponse, HttpUrl, artSocket, SocketDStream, Log;

CONST
  Idle = 0;
  Connecting = 1;
  Sending = 2;
  Receiving = 3;
  Done = 4;
  Error = 5;

  MaxHostLen = 1024;

  (* Error codes for HttpClient.error *)
  ErrNone = 0;
  ErrUrlParse = 1;
  ErrRequestSerialization = 2;
  ErrSocketCreate = 3;
  ErrConnect = 4;
  ErrRequestInit = 5;
  ErrHostTruncate = 6;

TYPE
  HttpClient* = POINTER TO HttpClientDesc;
  HttpClientDesc* = RECORD
    state: INTEGER;
    socket: artSocket.Socket;
    stream: SocketDStream.SocketDStream; (* Buffered socket stream *)
    req: HttpRequest.HttpRequest;
    resp: HttpResponse.HttpResponse;
    url: HttpUrl.Url;
    error: INTEGER
  END;

(** Initializes a new HttpClient instance. *)
PROCEDURE Init*(VAR client: HttpClient);
BEGIN
  IF client = NIL THEN
    NEW(client);
  END;
  client.state := Idle;
  client.socket := NIL;
  client.stream := NIL;
  client.req := NIL;
  client.resp := NIL;
  client.url := NIL;
  client.error := 0
END Init;

(** Gets the current state of the client. *)
PROCEDURE GetState*(client: HttpClient): INTEGER;
VAR result: INTEGER;
BEGIN
  IF client # NIL THEN
    result := client.state
  ELSE
    result := Error
  END;
  RETURN result
END GetState;

(** Gets the last error code. *)
PROCEDURE GetError*(client: HttpClient): INTEGER;
VAR result: INTEGER;
BEGIN
  IF client # NIL THEN
    result := client.error
  ELSE
    result := Error
  END;
  RETURN result
END GetError;

(* Resets the client state and fields to defaults. *)
PROCEDURE ResetClient(VAR client: HttpClient);
BEGIN
  client.state := Idle;
  client.error := ErrNone;
  client.req := NIL;
  client.resp := NIL;
  client.url := NIL;
  client.socket := NIL;
  client.stream := NIL
END ResetClient;

(* Parses the URL and sets client.url. Returns TRUE on success, sets error otherwise. *)
PROCEDURE ParseAndSetUrl(client: HttpClient; url: ARRAY OF CHAR): BOOLEAN;
VAR ok, result: BOOLEAN;
BEGIN
  ok := HttpUrl.Parse(url, client.url);
  IF ~ok THEN
    client.state := Error;
    client.error := ErrUrlParse;
    result := FALSE
  ELSE
    result := TRUE
  END;
  RETURN result
END ParseAndSetUrl;

(* Initializes the request and sets headers/body. Returns TRUE on success, sets error otherwise. *)
PROCEDURE InitRequest(client: HttpClient; method: ARRAY OF CHAR; headers, body: DStrings.String): BOOLEAN;
VAR ok, result: BOOLEAN;
BEGIN
  HttpRequest.InitDString(method, client.url.path, client.req);
  IF client.req = NIL THEN
    client.state := Error;
    client.error := ErrRequestInit;
    result := FALSE
  ELSE
    IF headers # NIL THEN
      (* TODO: Copy headers from provided DStrings.String to request *)
    END;
    IF body # NIL THEN
      ok := HttpRequest.SetBodyDString(client.req, body);
      IF ~ok THEN
        client.state := Error;
        client.error := ErrRequestSerialization;
        result := FALSE
      ELSE
        result := TRUE
      END
    ELSE
      result := TRUE
    END
  END;
  RETURN result
END InitRequest;

(* Serializes the request to reqStr. Returns TRUE on success, sets error otherwise. *)
PROCEDURE SerializeRequest(client: HttpClient; VAR reqStr: DStrings.String): BOOLEAN;
VAR ok, result: BOOLEAN;
BEGIN
  ok := HttpRequest.ToString(client.req, reqStr);
  IF ~ok THEN
    client.state := Error;
    client.error := ErrRequestSerialization;
    result := FALSE
  ELSE
    result := TRUE
  END;
  RETURN result
END SerializeRequest;

(* Creates and connects the socket, initializes stream. Returns TRUE on success, sets error otherwise. *)
PROCEDURE ConnectSocketAndStream(client: HttpClient; host: DStrings.String; port: INTEGER): BOOLEAN;
VAR
  hostBuf: ARRAY MaxHostLen OF CHAR;
  truncated, status: INTEGER;
  logger: Log.Logger;
  result: BOOLEAN;
BEGIN
  client.socket := artSocket.NewSocket();
  IF client.socket = NIL THEN
    client.state := Error;
    client.error := ErrSocketCreate;
    result := FALSE
  ELSE
    DStrings.ToChars(host, hostBuf, truncated);
    IF truncated # 0 THEN
      client.state := Error;
      client.error := ErrHostTruncate;
      result := FALSE
    ELSE
      status := artSocket.Connect(client.socket, hostBuf, port);
      IF (status # artSocket.Ok) & (status # artSocket.InProgress) THEN
        client.state := Error;
        client.error := ErrConnect;
        result := FALSE
      ELSE
        logger := NIL; (* Optionally set a logger *)
        SocketDStream.Init(client.socket, client.stream, logger);
        result := TRUE
      END
    END
  END;
  RETURN result
END ConnectSocketAndStream;

(** Starts a new HTTP request. *)
PROCEDURE StartRequest*(client: HttpClient; method, url: ARRAY OF CHAR; headers, body: DStrings.String);
VAR
  reqStr: DStrings.String;
  ok, done: BOOLEAN;
BEGIN
  done := FALSE;
  IF client # NIL THEN
    ResetClient(client);
    ok := ParseAndSetUrl(client, url);
    IF ~ok THEN done := TRUE END;
    IF ~done THEN
      ok := InitRequest(client, method, headers, body);
      IF ~ok THEN done := TRUE END
    END;
    IF ~done THEN
      ok := SerializeRequest(client, reqStr);
      IF ~ok THEN done := TRUE END
    END;
    IF ~done THEN
      ok := ConnectSocketAndStream(client, client.url.host, client.url.port);
      IF ~ok THEN done := TRUE END
    END;
    IF ~done THEN
      client.state := Connecting;
      (* TODO: Store reqStr in client for sending in Step *)
    END
  END
END StartRequest;

(** Advances the state machine by one step. Returns TRUE if more work is needed, FALSE if done or error. *)
PROCEDURE Step*(client: HttpClient): BOOLEAN;
VAR result: BOOLEAN;
BEGIN
  IF client # NIL THEN
    (* Implementation to be filled in *)
    result := FALSE
  ELSE
    result := FALSE
  END;
  RETURN result
END Step;

(** Returns TRUE if the client is done (success or error). *)
PROCEDURE IsDone*(client: HttpClient): BOOLEAN;
VAR result: BOOLEAN;
BEGIN
  IF client # NIL THEN
    result := (client.state = Done) OR (client.state = Error)
  ELSE
    result := TRUE
  END;
  RETURN result
END IsDone;

(** Gets the socket. *)
PROCEDURE GetSocket*(client: HttpClient): artSocket.Socket;
VAR result: artSocket.Socket;
BEGIN
  IF client # NIL THEN
    result := client.socket
  ELSE
    result := NIL
  END;
  RETURN result
END GetSocket;

(** Gets the request. *)
PROCEDURE GetRequest*(client: HttpClient): HttpRequest.HttpRequest;
VAR result: HttpRequest.HttpRequest;
BEGIN
  IF client # NIL THEN
    result := client.req
  ELSE
    result := NIL
  END;
  RETURN result
END GetRequest;

(** Gets the response. *)
PROCEDURE GetResponsePtr*(client: HttpClient): HttpResponse.HttpResponse;
VAR result: HttpResponse.HttpResponse;
BEGIN
  IF client # NIL THEN
    result := client.resp
  ELSE
    result := NIL
  END;
  RETURN result
END GetResponsePtr;

(** Gets the URL. *)
PROCEDURE GetUrl*(client: HttpClient): HttpUrl.Url;
VAR result: HttpUrl.Url;
BEGIN
  IF client # NIL THEN
    result := client.url
  ELSE
    result := NIL
  END;
  RETURN result
END GetUrl;

(** Gets the parsed response if available. Returns TRUE if successful. *)
PROCEDURE GetResponse*(client: HttpClient; VAR resp: HttpResponse.HttpResponse): BOOLEAN;
VAR result: BOOLEAN;
BEGIN
  IF (client # NIL) & (client.state = Done) & (client.resp # NIL) THEN
    resp := client.resp;
    result := TRUE
  ELSE
    result := FALSE
  END;
  RETURN result
END GetResponse;

END HttpClient.
