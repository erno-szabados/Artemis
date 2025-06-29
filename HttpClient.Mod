(** HttpClient.Mod - Nonblocking HTTP client state machine for Oberon-07

Copyright (C) 2025 Artemis Project Contributors

Released under The 3-Clause BSD License.
*)
MODULE HttpClient;

IMPORT DStrings, HttpRequest, HttpResponse, HttpUrl, artSocket;

CONST
  Idle = 0;
  Connecting = 1;
  Sending = 2;
  Receiving = 3;
  Done = 4;
  Error = 5;

TYPE
  HttpClient* = POINTER TO HttpClientDesc;
  HttpClientDesc* = RECORD
    state: INTEGER;
    socket: artSocket.Socket;
    req: HttpRequest.HttpRequest;
    resp: HttpResponse.HttpResponse;
    url: HttpUrl.Url;
    outBuf: DStrings.String;
    inBuf: DStrings.String;
    outPos: INTEGER;
    inPos: INTEGER;
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
  client.req := NIL;
  client.resp := NIL;
  client.url := NIL;
  DStrings.Init("", client.outBuf);
  DStrings.Init("", client.inBuf);
  client.outPos := 0;
  client.inPos := 0;
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

(** Starts a new HTTP request. *)
PROCEDURE StartRequest*(client: HttpClient; method, url: ARRAY OF CHAR; headers, body: DStrings.String);
BEGIN
  IF client # NIL THEN
    (* Parse URL, build request, set up buffers, move to Connecting state *)
    (* Implementation to be filled in *)
  END;
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

(** Gets the outPos. *)
PROCEDURE GetOutPos*(client: HttpClient): INTEGER;
VAR result: INTEGER;
BEGIN
  IF client # NIL THEN
    result := client.outPos
  ELSE
    result := 0
  END;
  RETURN result
END GetOutPos;

(** Gets the inPos. *)
PROCEDURE GetInPos*(client: HttpClient): INTEGER;
VAR result: INTEGER;
BEGIN
  IF client # NIL THEN
    result := client.inPos
  ELSE
    result := 0
  END;
  RETURN result
END GetInPos;

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
