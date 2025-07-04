(** ExampleSocketServer.Mod - Minimal nonblocking TCP server example

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
  PORT = 12345;
  BUFSIZE = 256;

VAR
  serverSock, clientSock: artSocket.Socket;
  stream: SocketDStream.SocketDStream;
  dstr: DStrings.String;
  rider : DStrings.Rider;
  addr: ARRAY 16 OF CHAR;
  logger: Log.Logger;
  closed, done: BOOLEAN;

PROCEDURE LogErrorWithCode(logger: Log.Logger; msg: ARRAY OF CHAR; code: INTEGER);
VAR fullMsg, numStr: ARRAY 64 OF CHAR; ok: BOOLEAN;
BEGIN
  Chars.Copy(msg, fullMsg);
  Chars.IntToString(code, numStr, ok);
  Chars.Append(numStr, fullMsg);
  Log.Error(logger, fullMsg)
END LogErrorWithCode;

PROCEDURE LogInfoWithData(logger: Log.Logger; label: ARRAY OF CHAR; data: DStrings.String);
VAR msg: ARRAY 2*BUFSIZE OF CHAR; tmp: ARRAY BUFSIZE OF CHAR; truncated: INTEGER;
BEGIN
  Chars.Copy(label, msg);
  DStrings.ToChars(data, tmp, truncated);
  Chars.Append(tmp, msg);
  Log.Info(logger, msg)
END LogInfoWithData;

(* Accept a client connection, blocking until one is available or error *)
PROCEDURE AcceptClient(serverSock: artSocket.Socket; VAR clientSock: artSocket.Socket; logger: Log.Logger; VAR done: BOOLEAN);
VAR err: INTEGER;
BEGIN
  done := FALSE;
  clientSock := NIL;
  REPEAT
    clientSock := artSocket.Accept(serverSock, err);
    IF clientSock = NIL THEN
      IF err = artSocket.WouldBlock THEN
        artSleep.Millis(100);
      ELSE
        LogErrorWithCode(logger, "Accept failed: ", err);
        done := TRUE
      END
    END
  UNTIL (clientSock # NIL) OR done;
END AcceptClient;

(* Read a line from the client using SocketDStream, returns FALSE if connection closed or error *)
PROCEDURE ReadLine(stream: SocketDStream.SocketDStream; VAR dstr: DStrings.String; logger: Log.Logger; VAR closed: BOOLEAN): BOOLEAN;
VAR found: BOOLEAN; status: INTEGER; result: BOOLEAN;
BEGIN
  closed := FALSE;
  DStrings.Init("", dstr);
  result := FALSE;
  found := FALSE;
  WHILE ~found & ~closed DO
    status := SocketDStream.ReadUntil(stream, Chars.LF, dstr, found);
    IF status = artSocket.Ok THEN
      IF found THEN
        LogInfoWithData(logger, "Received: ", dstr);
        result := TRUE
      END
    ELSIF status = artSocket.WouldBlock THEN
      (* Partial read, wait for more data *)
      artSleep.Millis(100);
    ELSE
      LogErrorWithCode(logger, "Read failed: ", status);
      closed := TRUE;
      result := FALSE
    END
  END;
  RETURN result
END ReadLine;

(* Write a string to the client using SocketDStream *)
PROCEDURE WriteLine(stream: SocketDStream.SocketDStream; dstr: DStrings.String; logger: Log.Logger; VAR done: BOOLEAN);
VAR bytesLeft, status: INTEGER;
BEGIN
  bytesLeft := 0;
  done := FALSE;
  status := SocketDStream.SendDString(stream, dstr, bytesLeft);
  WHILE ((status = artSocket.Ok) OR (status = artSocket.WouldBlock)) & (bytesLeft > 0) & ~done DO
    status := SocketDStream.SendDString(stream, dstr, bytesLeft);
  END;
  IF (status = artSocket.Ok) OR (status = artSocket.WouldBlock) THEN
    LogInfoWithData(logger, "Sent: ", dstr)
  ELSE
    LogErrorWithCode(logger, "Write failed: ", status);
    done := TRUE
  END
END WriteLine;

BEGIN
  done := FALSE;
  logger := Log.New(Log.INFO, Log.CONSOLE, "");
  Log.Info(logger, "Starting server...");

  serverSock := artSocket.NewSocket();
  IF serverSock = NIL THEN
    Log.Error(logger, "Failed to create server socket");
    Log.Close(logger);
    done := TRUE
  END;

  IF ~done THEN
    addr := "127.0.0.1";
    IF artSocket.Bind(serverSock, addr, PORT) # artSocket.Ok THEN
      LogErrorWithCode(logger, "Bind failed: ", artSocket.Bind(serverSock, addr, PORT));
      artSocket.Close(serverSock);
      Log.Close(logger);
      done := TRUE
    END
  END;

  IF ~done THEN
    IF artSocket.Listen(serverSock, 1) # artSocket.Ok THEN
      LogErrorWithCode(logger, "Listen failed: ", artSocket.Listen(serverSock, 1));
      artSocket.Close(serverSock);
      Log.Close(logger);
      done := TRUE
    END
  END;

  IF ~done THEN
    Log.Info(logger, "Listening on port 12345");
    REPEAT
      AcceptClient(serverSock, clientSock, logger, done);
      IF ~done THEN
        Log.Info(logger, "Client connected");
        SocketDStream.Init(clientSock, stream);
        closed := FALSE;
        REPEAT
          IF ReadLine(stream, dstr, logger, closed) THEN
            DStrings.Set(rider, dstr, DStrings.Length(dstr));
            DStrings.WriteChar(rider, Chars.LF);
            WriteLine(stream, dstr, logger, done)
          END
        UNTIL closed OR done;
        IF clientSock # NIL THEN artSocket.Close(clientSock) END;
      END
    UNTIL FALSE
  END;
  IF serverSock # NIL THEN artSocket.Close(serverSock) END;
  Log.Info(logger, "Server shutdown");
  Log.Close(logger);
END ExampleSocketServer.
