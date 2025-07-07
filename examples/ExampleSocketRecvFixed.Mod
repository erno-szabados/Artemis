(** ExampleSocketRecvFixed.Mod - Minimal TCP client receiving fixed-size, incrementing byte sequences

Copyright (C) 2025 Artemis Project Contributors
Released under The 3-Clause BSD License.
*)
MODULE ExampleSocketRecvFixed;
IMPORT artSocket, artSleep, SocketDStream, DStrings, Log;

CONST
  ServerAddr = "127.0.0.1";
  Port = 12346;
  ChunkSize = 8;
  MaxChunks = 100;
  SocketIntervalMs = 100;

VAR
  sock: artSocket.Socket;
  stream: SocketDStream.SocketDStream;
  logger: Log.Logger;
  chunk: DStrings.String;
  buf: ARRAY ChunkSize+1 OF CHAR;
  status, bytesRead, receivedChunks: INTEGER;
  done: BOOLEAN;

BEGIN
  logger := Log.New(Log.INFO, Log.CONSOLE, "");
  Log.Info(logger, "Starting ExampleSocketRecvFixed client");
  done := FALSE;
  sock := NIL;

  IF ~done THEN
    sock := artSocket.NewSocket();
    IF sock = NIL THEN
      Log.Error(logger, "Failed to create client socket");
      done := TRUE
    END
  END;
  IF ~done THEN
    status := artSocket.Connect(sock, ServerAddr, Port);
    IF (status # artSocket.Ok) & (status # artSocket.InProgress) THEN
      Log.Error(logger, "Connect failed");
      artSocket.Close(sock);
      done := TRUE
    END
  END;
  IF ~done THEN
    SocketDStream.Init(sock, stream, logger);
    receivedChunks := 0;
    WHILE (receivedChunks < MaxChunks) & ~done DO
      status := SocketDStream.ReadNBytes(stream, ChunkSize, chunk, bytesRead);
      IF (status = artSocket.Ok) & (bytesRead = ChunkSize) THEN
        DStrings.ToChars(chunk, buf, bytesRead);
        buf[ChunkSize] := 0X;
        Log.Info(logger, buf);
        receivedChunks := receivedChunks + 1
      ELSIF status = artSocket.WouldBlock THEN
        artSleep.Millis(SocketIntervalMs)
      ELSE
        Log.Error(logger, "Receive failed or connection closed");
        done := TRUE
      END
    END;
    Log.Info(logger, "Done receiving. Closing socket.");
    IF sock # NIL THEN artSocket.Close(sock) END;
    Log.Close(logger);
  END;
END ExampleSocketRecvFixed.
