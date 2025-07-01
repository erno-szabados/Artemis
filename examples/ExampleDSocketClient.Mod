(** ExampleDSocketClient.Mod - Minimal nonblocking TCP client using SocketDStream

Copyright (C) 2025 Artemis Project

Released under The 3-Clause BSD License.
See https://opensource.org/licenses/BSD-3-Clause

This example demonstrates a minimal TCP client using the SocketDStream module.
It connects to the ExampleSocketServer, sends a line of text, receives the capitalized response,
and logs all steps using the Log module. All I/O is performed using DStrings and SocketDStream.
*)
MODULE ExampleDSocketClient;

IMPORT artSocket, SocketDStream, DStrings, Chars, Log, In;

CONST
  SERVER_ADDR = "127.0.0.1";
  PORT = 12345;
  BUFSIZE = 256;

VAR
  sock: artSocket.Socket;
  stream: SocketDStream.SocketDStream;
  dstr: DStrings.String;
  bytesLeft, status: INTEGER;
  logger: Log.Logger;
  done: BOOLEAN;
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

BEGIN
  done := FALSE;
  logger := Log.New(Log.INFO, Log.CONSOLE, "");
  Log.Info(logger, "Starting DSocket client");

  In.Open;

  sock := artSocket.NewSocket();
  IF sock = NIL THEN
    Log.Error(logger, "Failed to create socket");
    Log.Close(logger);
    done := TRUE
  END;

  IF ~done THEN
    status := artSocket.Connect(sock, SERVER_ADDR, PORT);
    IF (status # artSocket.Ok) & (status # artSocket.InProgress) THEN
      LogErrorWithCode(logger, "Connect failed: ", status);
      artSocket.Close(sock);
      Log.Close(logger);
      done := TRUE
    END
  END;

  IF ~done THEN
    SocketDStream.Init(sock, stream);
    DStrings.Init("", dstr);
    In.Line(buf);
    DStrings.CopyChars(buf, dstr);
    LogInfoWithData(logger, "Sending: ", buf);
    DStrings.Set(stream.outRider, stream.outBuf, 0);
    DStrings.Copy(dstr, stream.outBuf);
    bytesLeft := DStrings.Length(stream.outBuf);
    REPEAT
      status := SocketDStream.WriteDString(stream, bytesLeft);
      IF (status = artSocket.WouldBlock) THEN
        (* Optionally yield or retry here *)
      ELSIF status # artSocket.Ok THEN
        LogErrorWithCode(logger, "Send failed: ", status);
        done := TRUE
      END
    UNTIL (bytesLeft = 0) OR done;
    IF ~done THEN LogInfoWithData(logger, "Sent: ", buf) END
  END;

  IF ~done THEN
    (* Read response loop *)
    DStrings.Init("", dstr);
    DStrings.Set(stream.inRider, stream.inBuf, 0);
    bytesLeft := 1;
    REPEAT
      status := SocketDStream.ReadDString(stream, bytesLeft);
      IF (status = artSocket.WouldBlock) THEN
        (* Optionally yield or sleep here *)
      ELSIF status # artSocket.Ok THEN
        LogErrorWithCode(logger, "Receive failed: ", status);
        done := TRUE
      END
    UNTIL (bytesLeft > 0) OR done;
    IF ~done THEN
      DStrings.ToChars(stream.inBuf, buf, bytesLeft);
      buf[bytesLeft] := 0X;
      LogInfoWithData(logger, "Received: ", buf)
    END
  END;

  IF sock # NIL THEN artSocket.Close(sock) END;
  Log.Info(logger, "DSocket client done");
  Log.Close(logger);
END ExampleDSocketClient.
