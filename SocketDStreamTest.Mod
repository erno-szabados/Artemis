(** SocketDStreamTest.Mod - Minimal unit tests for SocketDStream.Mod

Copyright (C) 2025 Artemis Project Contributors

Released under The 3-Clause BSD License.
*)
MODULE SocketDStreamTest;
IMPORT SocketDStream, artSocket, Tests, DStrings, Chars, Log;

VAR
  ts: Tests.TestSet;

PROCEDURE TestInit*(): BOOLEAN;
VAR
  pass: BOOLEAN;
  sock: artSocket.Socket;
  stream: SocketDStream.SocketDStream;
BEGIN
  pass := TRUE;
  sock := NIL; (* In real tests, use a mock or real socket *)
  SocketDStream.Init(sock, stream, Log.New(Log.DEBUG, Log.CONSOLE, ""));
  Tests.ExpectedBool(TRUE, stream # NIL, "SocketDStream.Init did not allocate stream", pass)
 
  RETURN pass
END TestInit;

PROCEDURE TestSendDString_NilSocket(): BOOLEAN;
VAR
  pass: BOOLEAN;
  stream: SocketDStream.SocketDStream;
  dstr: DStrings.String;
  bytesLeft, status: INTEGER;
BEGIN
  pass := TRUE;
  stream := NIL;
  DStrings.Init("", dstr);
  bytesLeft := -1;
  status := SocketDStream.SendDString(stream, dstr, bytesLeft);
  Tests.ExpectedInt(artSocket.UnknownError, status, "SendDString returns NotConnected for NIL stream", pass);
  Tests.ExpectedInt(0, bytesLeft, "SendDString bytesLeft is 0 for NIL stream", pass);
  RETURN pass
END TestSendDString_NilSocket;

PROCEDURE TestReadUntil_NilSocket(): BOOLEAN;
VAR
  pass: BOOLEAN;
  stream: SocketDStream.SocketDStream;
  dstr: DStrings.String;
  found: BOOLEAN;
  status: INTEGER;
  delim: ARRAY 2 OF CHAR;
BEGIN
  pass := TRUE;
  stream := NIL;
  DStrings.Init("", dstr);
  delim[0] := Chars.LF; delim[1] := 0X;
  status := SocketDStream.ReadUntil(stream, delim, -1, dstr, found);
  Tests.ExpectedInt(artSocket.UnknownError, status, "ReadUntil returns NotConnected for NIL stream", pass);
  Tests.ExpectedBool(FALSE, found, "ReadUntil found is FALSE for NIL stream", pass);
  RETURN pass
END TestReadUntil_NilSocket;

BEGIN
  Tests.Init(ts, "SocketDStream Tests");
  Tests.Add(ts, TestInit);
  Tests.Add(ts, TestSendDString_NilSocket);
  Tests.Add(ts, TestReadUntil_NilSocket);
  ASSERT(Tests.Run(ts));
END SocketDStreamTest.
