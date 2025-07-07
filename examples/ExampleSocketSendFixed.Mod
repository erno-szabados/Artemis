(** ExampleSocketSendFixed.Mod - Minimal TCP server sending fixed-size, incrementing byte sequences

Copyright (C) 2025 Artemis Project Contributors
Released under The 3-Clause BSD License.
*)
MODULE ExampleSocketSendFixed;
IMPORT artSocket, artSleep, SocketDStream, DStrings, Log;

CONST
  Port = 12346;
  ChunkSize = 8;
  MaxChunks = 100;
  SocketIntervalMs = 100;
  Localhost = "127.0.0.1";

VAR
  serverSock, clientSock: artSocket.Socket;
  stream: SocketDStream.SocketDStream;
  logger: Log.Logger;
  chunk: DStrings.String;
  buf: ARRAY ChunkSize OF CHAR;
  status, bytesLeft, sentChunks: INTEGER;
  done: BOOLEAN;

PROCEDURE MakeChunk(n: INTEGER; VAR buf: ARRAY OF CHAR);
VAR k: INTEGER;
BEGIN
  FOR k := 0 TO LEN(buf)-1 DO
    buf[k] := CHR(ORD("A") + (n MOD 26))
  END;
END MakeChunk;

BEGIN
  logger := Log.New(Log.INFO, Log.CONSOLE, "");
  Log.Info(logger, "Starting ExampleSocketSendFixed server");
  done := FALSE;
  serverSock := NIL;
  clientSock := NIL;

  (* Initialization sequence with no early returns *)
  IF ~done THEN
    serverSock := artSocket.NewSocket();
    IF serverSock = NIL THEN
      Log.Error(logger, "Failed to create server socket");
      done := TRUE
    END
  END;
  IF ~done THEN
    IF artSocket.Bind(serverSock, Localhost, Port) # artSocket.Ok THEN
      Log.Error(logger, "Bind failed");
      artSocket.Close(serverSock);
      done := TRUE
    END
  END;
  IF ~done THEN
    IF artSocket.Listen(serverSock, 1) # artSocket.Ok THEN
      Log.Error(logger, "Listen failed");
      artSocket.Close(serverSock);
      done := TRUE
    END
  END;
  IF ~done THEN
    Log.Info(logger, "Listening on port 12346");
    REPEAT
      clientSock := artSocket.Accept(serverSock, status);
      IF clientSock = NIL THEN
        artSleep.Millis(SocketIntervalMs)
      END
    UNTIL clientSock # NIL;
    Log.Info(logger, "Client connected");
    SocketDStream.Init(clientSock, stream, logger);
    sentChunks := 0;
    WHILE (sentChunks < MaxChunks) & ~done DO
      MakeChunk(sentChunks, buf);
      DStrings.Init(buf, chunk);
      status := SocketDStream.SendDString(stream, chunk, bytesLeft);
      IF (status = artSocket.Ok) OR (status = artSocket.WouldBlock) THEN
        WHILE bytesLeft > 0 DO
          status := SocketDStream.SendDString(stream, chunk, bytesLeft);
          IF status # artSocket.Ok THEN
            artSleep.Millis(SocketIntervalMs)
          END
        END;
        sentChunks := sentChunks + 1;
        artSleep.Millis(200)
      ELSE
        Log.Error(logger, "Send failed");
        done := TRUE
      END
    END;
    Log.Info(logger, "Done sending. Closing sockets.");
    IF clientSock # NIL THEN artSocket.Close(clientSock) END;
    IF serverSock # NIL THEN artSocket.Close(serverSock) END;
    Log.Close(logger);
  END;
END ExampleSocketSendFixed.
