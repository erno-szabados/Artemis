(** HttpResponseTest.Mod - Minimal tests for HttpResponse.Mod.

Copyright (C) 2025

Released under The 3-Clause BSD License.
*)
MODULE HttpResponseTest;
IMPORT HttpResponse, DStrings, Tests, Chars;

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

PROCEDURE TestParseStatusLine*(): BOOLEAN;
VAR
  pass, ok: BOOLEAN;
  resp: HttpResponse.HttpResponse;
  raw: ARRAY 64 OF CHAR;
  reason, version, dstr: DStrings.String;
  buf: ARRAY 64 OF CHAR;
  res: INTEGER;
  rider: DStrings.Rider;
BEGIN
  pass := TRUE;
  DStrings.Init("", dstr);
  DStrings.Set(rider, dstr, 0);
  DStrings.WriteString(rider, "HTTP/1.1 404 Not Found");
  DStrings.WriteChar(rider, Chars.CR); DStrings.WriteChar(rider, Chars.LF);
  DStrings.ToChars(dstr, raw, res);
  ok := HttpResponse.Parse(raw, resp);
  Tests.ExpectedBool(TRUE, ok, "Parse returns TRUE for valid status line", pass);
  Tests.ExpectedInt(404, HttpResponse.GetStatus(resp), "Status code is 404", pass);
  DStrings.Init("", reason); DStrings.Init("", version);
  HttpResponse.GetReason(resp, reason);
  HttpResponse.GetVersion(resp, version);
  DStrings.ToChars(reason, buf, res);
  Tests.ExpectedString("Not Found", buf, "Reason phrase is 'Not Found'", pass);
  DStrings.ToChars(version, buf, res);
  Tests.ExpectedString("HTTP/1.1", buf, "Version is 'HTTP/1.1'", pass);
  Tests.ExpectedBool(TRUE, HttpResponse.IsOk(resp), "IsOk is TRUE after parse", pass);
  RETURN pass
END TestParseStatusLine;

BEGIN
  Tests.Init(ts, "HttpResponse Tests");
  Tests.Add(ts, TestInit);
  Tests.Add(ts, TestParseStub);
  Tests.Add(ts, TestParseStatusLine);
  ASSERT(Tests.Run(ts));
END HttpResponseTest.
