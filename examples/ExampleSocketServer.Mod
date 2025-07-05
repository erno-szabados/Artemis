(** 
  ExampleSocketServer.Mod

  Copyright (C) 2025 Artemis Project

  Released under The 3-Clause BSD License.
  See https://opensource.org/licenses/BSD-3-Clause

  This example demonstrates a minimal TCP server using the artSocket module.
  It accepts a single client, reads a line of text and echoes it back.
  Logging is performed using the Log module.
 *)
MODULE ExampleSocketServer;

IMPORT artSleep, artSocket, Chars, Log, SocketDStream, DStrings;

CONST
  Port = 12345;
  BufSize = 256;
  SocketIntervalMs = 100;
  Localhost = "127.0.0.1";

  TYPE
  ServerDesc = RECORD 
    serverSock, clientSock: artSocket.Socket;
    stream: SocketDStream.SocketDStream;
    logger: Log.Logger;
    dstr: DStrings.String; 
    addr: ARRAY 16 OF CHAR;
    lastResult, done: BOOLEAN
END;

VAR
  server : ServerDesc;
  
(* 
  Log an error with the error code passed.

  @param logger - logger instance
  @param msg - error message
  @code - error code
 *)
PROCEDURE LogErrorWithCode(logger: Log.Logger; msg: ARRAY OF CHAR; code: INTEGER);
VAR fullMsg, numStr: ARRAY 64 OF CHAR; ok: BOOLEAN;
BEGIN
  Chars.Copy(msg, fullMsg);
  Chars.IntToString(code, numStr, ok);
  Chars.Append(numStr, fullMsg);
  Log.Error(logger, fullMsg)
END LogErrorWithCode;

(* 
  Log an info message with the passed dstring.
  
  @param logger - logger instance
  @param msg - info message 
  @param data - dstring to be logged 
 *)
PROCEDURE LogInfoWithData(logger: Log.Logger; msg: ARRAY OF CHAR; data: DStrings.String);
VAR fullMsg: ARRAY 2 * BufSize OF CHAR; tmp: ARRAY BufSize OF CHAR; truncated: INTEGER;
BEGIN
  Chars.Copy(msg, fullMsg);
  DStrings.ToChars(data, tmp, truncated);
  Chars.Append(tmp, fullMsg);
  Log.Info(logger, fullMsg)
END LogInfoWithData;

(* 
  Accept a client connection, blocking until one is available or error.

  @param serverSock - server socket
  @param clientSock - the new client socket
  @param logger - logger instance

  @return success - TRUE if client socket was created successfully, FALSE on error
  *)
PROCEDURE AcceptClient(serverSock: artSocket.Socket; VAR clientSock: artSocket.Socket; logger: Log.Logger) : BOOLEAN;
VAR socketStatus: INTEGER; success: BOOLEAN;
BEGIN
  success := TRUE;
  clientSock := NIL;

  REPEAT
    clientSock := artSocket.Accept(serverSock, socketStatus);
    IF clientSock = NIL THEN
      IF socketStatus = artSocket.WouldBlock THEN
        artSleep.Millis(SocketIntervalMs);
      ELSE
        LogErrorWithCode(logger, "Accept failed: ", socketStatus);
        success := FALSE
      END
    END
  UNTIL (clientSock # NIL) OR ~success;

  Log.Debug(logger, "Client accept finished");
  
  RETURN success
  
END AcceptClient;

(* 
  Read a line from the client using SocketDStream (until LF). 

  @param stream - stream descriptor
  @param dstr - string to write line read result
  @param logger - logger instance

  @returns TRUE on successful read, FALSE on error.
 *)
PROCEDURE ReadLine(stream: SocketDStream.SocketDStream; VAR dstr: DStrings.String; logger: Log.Logger): BOOLEAN;
VAR status: INTEGER; delimFound, socketError, ok: BOOLEAN;
BEGIN
  DStrings.Init("", dstr);
  ok := FALSE;
  socketError := FALSE;

  REPEAT
    (* Read until LF or socket error *)
    status := SocketDStream.ReadUntil(stream, Chars.LF, dstr, delimFound);

    IF status = artSocket.Ok THEN
      IF delimFound THEN
        LogInfoWithData(logger, "Received: ", dstr);
        ok := TRUE
      END
    ELSIF status = artSocket.WouldBlock THEN
      (* Partial read, wait for more data *)
      artSleep.Millis(SocketIntervalMs);
    ELSE
      (* Socket error, abort *)
      LogErrorWithCode(logger, "Read failed: ", status);
      socketError := TRUE
    END
  UNTIL delimFound OR socketError;

  RETURN ok
END ReadLine;

(* 
  Write a string to the client using SocketDStream. Does not return until data sent or an error occurs.
  
  @param stream - stream descriptor
  @param sstr - source string to be sent
  @param logger - logger instance
  
  @return TRUE on success, FALSE on error
*)
PROCEDURE WriteLine(stream: SocketDStream.SocketDStream; sstr: DStrings.String; logger: Log.Logger) : BOOLEAN;
VAR bytesLeft, status: INTEGER; ok : BOOLEAN;
BEGIN

  REPEAT 
    status := SocketDStream.SendDString(stream, sstr, bytesLeft);
    ok := (status = artSocket.Ok) OR (status = artSocket.WouldBlock);
    IF status = artSocket.WouldBlock THEN
      artSleep.Millis(100)
    END
  UNTIL ~ok OR (bytesLeft = 0);

  IF ok THEN
    LogInfoWithData(logger, "Sent: ", sstr)
  ELSE
    LogErrorWithCode(logger, "Write failed: ", status);
  END

  RETURN ok
END WriteLine;

BEGIN
  server.lastResult := TRUE;
  server.done := FALSE;
  server.stream := NIL;
  server.logger := Log.New(Log.INFO, Log.CONSOLE, "");
  Log.Info(server.logger, "Starting server");

  (* Create and validate socket *)
  server.serverSock := artSocket.NewSocket();
  IF server.serverSock = NIL THEN
    Log.Error(server.logger, "Failed to create server socket");
    server.lastResult := FALSE;
    server.done := TRUE
  END;

  (* Bind serfver socket to specified host:port *)
  IF ~server.done THEN
    server.addr := Localhost;

    IF artSocket.Bind(server.serverSock, server.addr, Port) # artSocket.Ok THEN
      LogErrorWithCode(server.logger, "Bind failed: ", artSocket.Bind(server.serverSock, server.addr, Port));
      artSocket.Close(server.serverSock);
      server.lastResult := FALSE;
      server.done := TRUE
    END
  END;

  (* Listen on socket *)
  IF ~server.done THEN
    IF artSocket.Listen(server.serverSock, 1) # artSocket.Ok THEN
      LogErrorWithCode(server.logger, "Listen failed: ", artSocket.Listen(server.serverSock, 1));
      artSocket.Close(server.serverSock);
      server.lastResult := FALSE;
      server.done := TRUE
    END
  END;

  IF ~server.done THEN
    Log.Info(server.logger, "Listening on port 12345");
    (* Forever *)
    REPEAT
      (* Block until an incoming connection or error *)
      server.done := ~AcceptClient(server.serverSock, server.clientSock, server.logger);
      
      (* Reinit stream with new client socket *)
      IF ~server.done THEN
        Log.Info(server.logger, "Client connected");
        SocketDStream.Init(server.clientSock, server.stream, server.logger);
        
        (* Keep reading *)
        REPEAT
          server.lastResult := ReadLine(server.stream, server.dstr, server.logger);
          IF server.lastResult THEN
            server.lastResult := WriteLine(server.stream, server.dstr, server.logger)
          ELSE
            Log.Error(server.logger, "Readline failed")
          END;
        UNTIL ~server.lastResult OR server.done;

        Log.Info(server.logger, "Message processed");

        IF server.clientSock # NIL THEN 
          artSocket.Close(server.clientSock);
          server.clientSock := NIL;
          Log.Info(server.logger, "Client socket closed")
        END;

      END

    UNTIL FALSE
  END;


  (* We will never get here - we don't have a signal handler so Ctrl-c will kill the server. *)
  IF server.serverSock # NIL THEN 
    artSocket.Close(server.serverSock);
    server.serverSock := NIL 
  END;


  Log.Info(server.logger, "Server shutdown");
  Log.Close(server.logger);
END ExampleSocketServer.
