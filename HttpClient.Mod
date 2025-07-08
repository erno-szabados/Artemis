(** HttpClient.Mod - Nonblocking HTTP client state machine for Oberon-07

Copyright (C) 2025 Artemis Project Contributors

Released under The 3-Clause BSD License.
*)
MODULE HttpClient;

IMPORT DStrings, Convert := extConvert, Chars,
       HttpRequest, HttpHeader, HttpResponse, HttpUrl, 
       artSocket, SocketDStream, Collections, Dictionary, Log;

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
    error: INTEGER;
    reqStr: DStrings.String; (* Serialized request buffer *)
    reqBytesLeft: INTEGER;   (* Bytes left to send *)
    recvBuf: DStrings.String; (* Buffer for receiving response *)
    recvDone: BOOLEAN;        (* TRUE if response fully received *)
    logger : Log.Logger
  END;

  CopyHeaderState = RECORD (Dictionary.DictVisitorState)
    dest: HttpHeader.Header
  END;

(** Initializes a new HttpClient instance. *)
PROCEDURE Init*(VAR client: HttpClient);
BEGIN
  IF client = NIL THEN
    NEW(client);
  END;
  client.logger := Log.New(Log.DEBUG, Log.CONSOLE, "");
  client.state := Idle;
  client.socket := NIL;
  client.stream := NIL;
  client.req := NIL;
  HttpResponse.Init(client.resp, client.logger);
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
  HttpResponse.Init(client.resp, client.logger);
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

(* Visitor to copy each header field from headers to dest header *)
PROCEDURE CopyHeaderField(key: ARRAY OF CHAR; value: Collections.ItemPtr; VAR state: Collections.VisitorState): BOOLEAN;
VAR kstr, val: DStrings.String; ok : BOOLEAN;
BEGIN
  IF value IS DStrings.String THEN
    val := value(DStrings.String);
    DStrings.Init(key, kstr);
    ok := HttpHeader.SetDString(state(CopyHeaderState).dest, kstr, val)
  END;
  RETURN TRUE
END CopyHeaderField;

(* Initializes the request and sets headers/body. Returns TRUE on success, sets error otherwise. *)
PROCEDURE InitRequest(client: HttpClient; method: ARRAY OF CHAR; headers: HttpHeader.Header; body: DStrings.String): BOOLEAN;
  VAR ok, result: BOOLEAN; copyState: CopyHeaderState;
  
BEGIN
  HttpRequest.InitDString(method, client.url.path, client.req);
  IF client.req = NIL THEN
    client.state := Error;
    client.error := ErrRequestInit;
    result := FALSE
  ELSE
    IF headers # NIL THEN
      copyState.dest := client.req.headers;
      HttpHeader.Foreach(headers, CopyHeaderField, copyState)
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
        SocketDStream.Init(client.socket, client.stream, client.logger);
        result := TRUE
      END
    END
  END;
  RETURN result
END ConnectSocketAndStream;

(** Starts a new HTTP request. *)
PROCEDURE StartRequest*(client: HttpClient; method, url: ARRAY OF CHAR; headers: HttpHeader.Header; body: DStrings.String);
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



PROCEDURE Step*(client: HttpClient): BOOLEAN;
VAR result: BOOLEAN;

  (* Handles the Connecting state. Returns TRUE if more work is needed. *)
  PROCEDURE HandleConnecting(client: HttpClient): BOOLEAN;
  VAR result: BOOLEAN;
  BEGIN
    (* No probing needed: just transition to Sending and let the send operation handle readiness. *)
    client.state := Sending;
    result := TRUE;
    RETURN result
  END HandleConnecting;

  (* Handles the Sending state. Returns TRUE if more work is needed. *)
  PROCEDURE HandleSending(client: HttpClient): BOOLEAN;
  VAR status: INTEGER; ok, result: BOOLEAN;
  BEGIN
    IF client.reqStr = NIL THEN
      ok := HttpRequest.ToString(client.req, client.reqStr);
      client.reqBytesLeft := DStrings.Length(client.reqStr)
    END;
    IF client.reqBytesLeft > 0 THEN
      status := SocketDStream.SendDString(client.stream, client.reqStr, client.reqBytesLeft);
      IF (status = artSocket.Ok) OR (status = artSocket.WouldBlock) THEN
        IF client.reqBytesLeft = 0 THEN
          client.state := Receiving;
          result := TRUE
        ELSE
          result := TRUE
        END
      ELSE
        client.state := Error;
        client.error := ErrRequestSerialization;
        result := FALSE
      END
    ELSE
      client.state := Receiving;
      result := TRUE
    END;
    RETURN result
  END HandleSending;
  
  (* Handles the Receiving state. Returns TRUE if more work is needed. *)
  PROCEDURE HandleReceiving(client: HttpClient): BOOLEAN;
  VAR status: INTEGER; 
      result: BOOLEAN;
      headerEnd: BOOLEAN;
      contentLen: INTEGER;
      delim : ARRAY 4 OF CHAR;
      delimStr : DStrings.String;
  
    (* Helper: Ensure the receive buffer is initialized *)
    PROCEDURE EnsureRecvBuf(client: HttpClient);
    BEGIN
      IF client.recvBuf = NIL THEN
        DStrings.Init("", client.recvBuf)
      END
    END EnsureRecvBuf;

    (* Helper: Log the current receive buffer for debugging *)
    PROCEDURE DebugLogRecvBuf(client: HttpClient);
    VAR debugBuf: ARRAY 1024 OF CHAR; truncated: INTEGER; ok : BOOLEAN;
    BEGIN
      DStrings.ToChars(client.recvBuf, debugBuf, truncated);
      Log.Debug(client.logger, debugBuf);
      Convert.IntToString(DStrings.Length(client.recvBuf), debugBuf, ok);
      Log.Debug(client.logger, "Length:");
      Log.Debug(client.logger, debugBuf)
    END DebugLogRecvBuf;

    (* Parses the response body after headers have been parsed.
        This procedure inspects the headers and reads the body accordingly.
        Returns TRUE if the body was successfully read, FALSE on error.
        The body is stored in client.resp.body. *)
    PROCEDURE ParseBody(client: HttpClient): BOOLEAN;
    VAR
      contentLen: INTEGER;
      bodyBuf: DStrings.String;
      status, bytesRead: INTEGER;
      result, ok: BOOLEAN;
      intBuf : ARRAY 16 OF CHAR;

    (* 
      Helper: Process Content-Length header (if exist).

      @param client - client descriptor
      @param contentLen - return the extracted content-length value (if found)

      @return TRUE if found and contentLen was set. 
    *)
      PROCEDURE ProcessContentLength(client: HttpClient; VAR contentLen: INTEGER): BOOLEAN;
      VAR contentLenStr: DStrings.String; intBuf: ARRAY 16 OF CHAR; truncated: INTEGER; ok, done, result: BOOLEAN;
      BEGIN
        ok := HttpHeader.Get(client.resp.headers, "Content-Length", contentLenStr);
        IF ok THEN
          DStrings.ToChars(contentLenStr, intBuf, truncated);
          Convert.StringToInt(intBuf, contentLen, done);
          result := done & (contentLen > 0)
        ELSE
          contentLen := 0;
          result := FALSE
        END;
        RETURN result
      END ProcessContentLength;

    BEGIN
      Log.Debug(client.logger, "Parsing body");
      
      DStrings.Init("", bodyBuf);
      result := FALSE;
      IF (client # NIL) & (client.resp # NIL) THEN
        IF ProcessContentLength(client, contentLen) THEN
          (* Read the specified amount of bytes. *)
          status := SocketDStream.ReadNBytes(client.stream, contentLen, bodyBuf, bytesRead);
          IF (status = artSocket.Ok) & (bytesRead = contentLen) THEN
            DStrings.Copy(bodyBuf, client.resp.body);
            result := TRUE
          END
        ELSE
          Log.Debug(client.logger, "Reading 1024 bytes");
          (* TODO: the right thing would be to read until socket is closed 
              (need to add this to SocketDStream). *)
          status := SocketDStream.ReadNBytes(client.stream, 1024, bodyBuf, bytesRead);
          IF bytesRead > 0 THEN
            DStrings.Copy(bodyBuf, client.resp.body);
            result := TRUE
          ELSE
            Convert.IntToString(status, intBuf, ok);
            Log.Error(client.logger, "Read failed. Status:");
            Log.Error(client.logger, intBuf);
          END
        END
      END;
      RETURN result

    END ParseBody;

  BEGIN
    EnsureRecvBuf(client);
    delim[0] := Chars.CR; delim[1] := Chars.LF; delim[2] := Chars.CR; delim[3] := Chars.LF;
    DStrings.Init(delim, delimStr);
    status := SocketDStream.ReadUntil(client.stream, delim, -1, client.recvBuf, headerEnd);
    IF (status = artSocket.Ok) OR (status = artSocket.WouldBlock) THEN
      IF headerEnd THEN
        DebugLogRecvBuf(client);
        contentLen := 0;
        IF HttpResponse.ParseResponseDString(client.recvBuf, client.resp) THEN
          result := ParseBody(client);
          client.state := Done;
          client.error := ErrNone
        ELSE
          Log.Error(client.logger, "Response parsing failed");
          client.state := Error;
          client.error := ErrRequestSerialization;
        END;
        result := FALSE
      ELSE
        result := TRUE
      END
    ELSE
      client.state := Error;
      client.error := ErrRequestSerialization;
      result := FALSE
    END;
    RETURN result
  END HandleReceiving;

BEGIN
  result := FALSE;
  IF client # NIL THEN
    CASE client.state OF
      Connecting:
        result := HandleConnecting(client)
      |
      Sending:
        result := HandleSending(client)
      |
      Receiving:
        result := HandleReceiving(client)
      |
      Done:
        result := FALSE
      |
      Error:
        result := FALSE
    END;
    (* If state is not a known value, result remains FALSE *)
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
