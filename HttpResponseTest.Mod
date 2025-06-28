(** HttpResponseTest.Mod - Minimal tests for HttpResponse.Mod.

Copyright (C) 2025

Released under The 3-Clause BSD License.
*)
MODULE HttpResponseTest;
IMPORT HttpResponse, DStrings, Tests;

VAR
  ts: Tests.TestSet;

PROCEDURE TestInit*(): BOOLEAN;
VAR
  pass: BOOLEAN;
  resp: HttpResponse.HttpResponse;
BEGIN
  pass := TRUE;
  (* Just allocate and check default fields *)
  NEW(resp);
  Tests.ExpectedInt(0, HttpResponse.GetStatus(resp), "Default status code is 0", pass);
  Tests.ExpectedBool(FALSE, HttpResponse.IsOk(resp), "Default IsOk is FALSE", pass);
  RETURN pass
END TestInit;

PROCEDURE TestParseStub*(): BOOLEAN;
VAR
  pass, ok: BOOLEAN;
  resp: HttpResponse.HttpResponse;
  raw: ARRAY 128 OF CHAR;
BEGIN
  pass := TRUE;
  raw := "HTTP/1.1 200 OK\r\nContent-Type: text/plain\r\n\r\nHello";
  ok := HttpResponse.Parse(raw, resp);
  Tests.ExpectedBool(FALSE, ok, "Parse stub returns FALSE", pass);
  RETURN pass
END TestParseStub;

BEGIN
  Tests.Init(ts, "HttpResponse Tests");
  Tests.Add(ts, TestInit);
  Tests.Add(ts, TestParseStub);
  ASSERT(Tests.Run(ts));
END HttpResponseTest.
