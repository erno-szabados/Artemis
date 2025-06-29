(** HttpClientTest.Mod - Minimal tests for HttpClient.Mod.

Copyright (C) 2025

Released under The 3-Clause BSD License.
*)
MODULE HttpClientTest;
IMPORT HttpClient, DStrings, Tests;

VAR
  ts: Tests.TestSet;

PROCEDURE TestInit*(): BOOLEAN;
VAR
  pass: BOOLEAN;
  client: HttpClient.HttpClient;
  state, err, outPos, inPos: INTEGER;
BEGIN
  pass := TRUE;
  HttpClient.Init(client);
  state := HttpClient.GetState(client);
  err := HttpClient.GetError(client);
  outPos := HttpClient.GetOutPos(client);
  inPos := HttpClient.GetInPos(client);
  Tests.ExpectedInt(0, state, "Client state is Idle after Init", pass);
  Tests.ExpectedBool(HttpClient.GetSocket(client) = NIL, TRUE, "Socket is NIL after Init", pass);
  Tests.ExpectedBool(HttpClient.GetRequest(client) = NIL, TRUE, "Request is NIL after Init", pass);
  Tests.ExpectedBool(HttpClient.GetResponsePtr(client) = NIL, TRUE, "Response is NIL after Init", pass);
  Tests.ExpectedBool(HttpClient.GetUrl(client) = NIL, TRUE, "URL is NIL after Init", pass);
  Tests.ExpectedInt(0, outPos, "outPos is 0 after Init", pass);
  Tests.ExpectedInt(0, inPos, "inPos is 0 after Init", pass);
  Tests.ExpectedInt(0, err, "error is 0 after Init", pass);
  RETURN pass
END TestInit;

BEGIN
  Tests.Init(ts, "HttpClient Tests");
  Tests.Add(ts, TestInit);
  ASSERT(Tests.Run(ts));
END HttpClientTest.
