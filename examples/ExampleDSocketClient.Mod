(** ExampleDSocketClient.Mod - Minimal nonblocking TCP client using SocketDStream

Copyright (C) 2025 Artemis Project

Released under The 3-Clause BSD License.
See https://opensource.org/licenses/BSD-3-Clause

This example demonstrates a minimal TCP client using the SocketDStream module.
It connects to the ExampleSocketServer, sends a line of text, receives the capitalized response,
and logs all steps using the Log module. All I/O is performed using DStrings and SocketDStream.
*)
MODULE ExampleDSocketClient;

IMPORT artSocket, artSleep, SocketDStream, DStrings, Chars, Log, In;

CONST
  SERVER_ADDR = "127.0.0.1";
  PORT = 12345;
  BUFSIZE = 256;

VAR
  sock: artSocket.Socket;
  stream: SocketDStream.SocketDStream;
  logger: Log.Logger;
  recvResult: BOOLEAN;
  buf: ARRAY BUFSIZE OF CHAR;

PROCEDURE LogErrorWithCode(logger: Log.Logger; msg: ARRAY OF CHAR; code: INTEGER);
VAR fullMsg, numStr: ARRAY 64 OF CHAR; ok: BOOLEAN;
BEGIN
  Chars.Copy(msg, fullMsg);
  Chars.IntToString(code, numStr, ok);
  Chars.Append(numStr, fullMsg);
  Log.Error(logger, fullMsg)
END LogErrorWithCode;

PROCEDURE LogInfoWithData(logger: Log.Logger; label: ARRAY OF CHAR; data: ARRAY OF CHAR);
VAR msg: ARRAY 2*BUFSIZE OF CHAR;
BEGIN
  Chars.Copy(label, msg);
  Chars.Append(data, msg);
  Log.Info(logger, msg)
END LogInfoWithData;

PROCEDURE InitLogger(VAR logger: Log.Logger);
BEGIN
  logger := Log.New(Log.INFO, Log.CONSOLE, "");
  Log.Info(logger, "Starting DSocket client")
END InitLogger;

PROCEDURE OpenSocket(VAR sock: artSocket.Socket; logger: Log.Logger): BOOLEAN;
VAR ok: BOOLEAN;
BEGIN
  sock := artSocket.NewSocket();
  IF sock = NIL THEN
    Log.Error(logger, "Failed to create socket");
    Log.Close(logger);
    ok := FALSE
  ELSE
    ok := TRUE
  END;
  RETURN ok
END OpenSocket;

PROCEDURE ConnectToServer(sock: artSocket.Socket; logger: Log.Logger): BOOLEAN;
VAR status: INTEGER; ok: BOOLEAN;
BEGIN
  status := artSocket.Connect(sock, SERVER_ADDR, PORT);
  IF (status # artSocket.Ok) & (status # artSocket.InProgress) THEN
    LogErrorWithCode(logger, "Connect failed: ", status);
    artSocket.Close(sock);
    Log.Close(logger);
    ok := FALSE
  ELSE
    ok := TRUE
  END;
  RETURN ok
END ConnectToServer;

PROCEDURE SendLine(stream: SocketDStream.SocketDStream; logger: Log.Logger; buf: ARRAY OF CHAR): BOOLEAN;
VAR dstr: DStrings.String; bytesLeft, status: INTEGER; ok: BOOLEAN;
BEGIN
  DStrings.Init("", dstr);
  DStrings.CopyChars(buf, dstr);
  LogInfoWithData(logger, "Sending: ", buf);
  REPEAT
    status := SocketDStream.SendDString(stream, dstr, bytesLeft);
    IF (status = artSocket.WouldBlock) THEN
      artSleep.Millis(1000);
      Log.Info(logger, "Still waiting to send...")
    ELSIF status # artSocket.Ok THEN
      LogErrorWithCode(logger, "Send failed: ", status);
      ok := FALSE
    END
  UNTIL (bytesLeft = 0) OR (status # artSocket.Ok);
  IF status = artSocket.Ok THEN
    LogInfoWithData(logger, "Sent: ", buf);
    ok := TRUE
  END;
  RETURN ok
END SendLine;

PROCEDURE ReceiveResponse(stream: SocketDStream.SocketDStream; logger: Log.Logger; VAR buf: ARRAY OF CHAR): BOOLEAN;
VAR dstr: DStrings.String; bytesRead, status: INTEGER; ok, found: BOOLEAN;
  delim: ARRAY 1 OF CHAR;
BEGIN
  DStrings.Init("", dstr);
  delim[0] := Chars.LF; (* Use LF as delimiter *)
  found := FALSE;
  ok := TRUE;
  REPEAT
    status := SocketDStream.ReadUntil(stream, delim, dstr, found);
    IF (status = artSocket.WouldBlock) THEN
      artSleep.Millis(100)
    ELSIF status # artSocket.Ok THEN
      LogErrorWithCode(logger, "Receive failed: ", status);
      ok := FALSE
    END
  UNTIL found;
  IF (status = artSocket.Ok) & found THEN
    DStrings.ToChars(dstr, buf, bytesRead);
    (* buf[bytesRead] := 0X; *)
    LogInfoWithData(logger, "Received: ", buf);
    ok := TRUE
  END;
  RETURN ok
END ReceiveResponse;

PROCEDURE Cleanup(sock: artSocket.Socket; logger: Log.Logger);
BEGIN
  IF sock # NIL THEN artSocket.Close(sock) END;
  Log.Info(logger, "DSocket client done");
  Log.Close(logger)
END Cleanup;

BEGIN
  InitLogger(logger);
  In.Open;
  IF OpenSocket(sock, logger) THEN
    IF ConnectToServer(sock, logger) THEN
      SocketDStream.Init(sock, stream);
      In.Line(buf);
      Chars.Append(Chars.LF, buf);
      IF SendLine(stream, logger, buf) THEN
       recvResult := ReceiveResponse(stream, logger, buf)
      END
    END;
    Cleanup(sock, logger)
  END
END ExampleDSocketClient.
