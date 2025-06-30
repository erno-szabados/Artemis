(** SocketDStreamTest.Mod - Minimal unit tests for SocketDStream.Mod

Copyright (C) 2025 Artemis Project Contributors

Released under The 3-Clause BSD License.
*)
MODULE SocketDStreamTest;
IMPORT SocketDStream, artSocket, Tests;

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
  SocketDStream.Init(sock, stream);
  Tests.ExpectedBool(TRUE, stream # NIL, "SocketDStream.Init did not allocate stream", pass)
 
  RETURN pass
END TestInit;

PROCEDURE TestWriteDString_NilSocket(): BOOLEAN;
VAR
  pass: BOOLEAN;
  stream: SocketDStream.SocketDStream;
  bytesLeft, status: INTEGER;
BEGIN
  pass := TRUE;
  stream := NIL;
  bytesLeft := -1;
  status := SocketDStream.WriteDString(stream, bytesLeft);
  Tests.ExpectedInt(artSocket.NotConnected, status, "WriteDString returns NotConnected for NIL stream", pass);
  Tests.ExpectedInt(0, bytesLeft, "WriteDString bytesLeft is 0 for NIL stream", pass);
  RETURN pass
END TestWriteDString_NilSocket;

PROCEDURE TestReadDString_NilSocket(): BOOLEAN;
VAR
  pass: BOOLEAN;
  stream: SocketDStream.SocketDStream;
  bytesLeft, status: INTEGER;
BEGIN
  pass := TRUE;
  stream := NIL;
  bytesLeft := -1;
  status := SocketDStream.ReadDString(stream, bytesLeft);
  Tests.ExpectedInt(artSocket.NotConnected, status, "ReadDString returns NotConnected for NIL stream", pass);
  Tests.ExpectedInt(0, bytesLeft, "ReadDString bytesLeft is 0 for NIL stream", pass);
  RETURN pass
END TestReadDString_NilSocket;

BEGIN
  Tests.Init(ts, "SocketDStream Tests");
  Tests.Add(ts, TestInit);
  Tests.Add(ts, TestWriteDString_NilSocket);
  Tests.Add(ts, TestReadDString_NilSocket);
  ASSERT(Tests.Run(ts));
END SocketDStreamTest.
