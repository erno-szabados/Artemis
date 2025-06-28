(** HttpResponseTest.Mod - Minimal tests for HttpResponse.Mod.

Copyright (C) 2025

Released under The 3-Clause BSD License.
*)
MODULE HttpResponseTest;
IMPORT HttpResponse, DStrings, Tests, Chars, Out;

VAR
  ts: Tests.TestSet;

PROCEDURE TestInit*(): BOOLEAN;
VAR
  pass: BOOLEAN;
  resp: HttpResponse.HttpResponse;
BEGIN
  pass := TRUE;
  NEW(resp);
  HttpResponse.Init(resp);
  Tests.ExpectedInt(0, HttpResponse.GetStatus(resp), "Default status code is 0", pass);
  Tests.ExpectedBool(FALSE, HttpResponse.IsOk(resp), "Default IsOk is FALSE", pass);
  RETURN pass
END TestInit;

PROCEDURE TestParseStub*(): BOOLEAN;
VAR
  pass, ok: BOOLEAN;
  resp: HttpResponse.HttpResponse;
  raw: ARRAY 128 OF CHAR;
  dstr, body: DStrings.String;
  rider: DStrings.Rider;
  res: INTEGER;
  buf: ARRAY 128 OF CHAR;
BEGIN
  pass := TRUE;
  NEW(resp);
  HttpResponse.Init(resp);
  DStrings.Init("", dstr);
  DStrings.Set(rider, dstr, 0);
  DStrings.WriteString(rider, "HTTP/1.1 200 OK");
  DStrings.WriteChar(rider, Chars.CR); DStrings.WriteChar(rider, Chars.LF);
  DStrings.WriteString(rider, "Content-Type: text/plain");
  DStrings.WriteChar(rider, Chars.CR); DStrings.WriteChar(rider, Chars.LF);
  DStrings.WriteChar(rider, Chars.CR); DStrings.WriteChar(rider, Chars.LF);
  DStrings.WriteString(rider, "Hello");
  DStrings.ToChars(dstr, raw, res);
  ok := HttpResponse.Parse(raw, resp);
  Tests.ExpectedBool(TRUE, ok, "Parse stub returns TRUE", pass);
  DStrings.Init("", body);
  HttpResponse.GetBody(resp, body);
  DStrings.ToChars(body, buf, res);
  Tests.ExpectedString("Hello", buf, "Body is 'Hello'", pass);
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
  NEW(resp);
  HttpResponse.Init(resp);
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

PROCEDURE TestParseHeader*(): BOOLEAN;
VAR
  pass, ok, found: BOOLEAN;
  resp: HttpResponse.HttpResponse;
  raw: ARRAY 128 OF CHAR;
  dstr, value, body: DStrings.String;
  rider: DStrings.Rider;
  res: INTEGER;
  buf: ARRAY 128 OF CHAR;
BEGIN
  pass := TRUE;
  NEW(resp);
  HttpResponse.Init(resp);
  DStrings.Init("", dstr);
  DStrings.Set(rider, dstr, 0);
  DStrings.WriteString(rider, "HTTP/1.1 200 OK");
  DStrings.WriteChar(rider, Chars.CR); DStrings.WriteChar(rider, Chars.LF);
  DStrings.WriteString(rider, "Content-Type: text/plain");
  DStrings.WriteChar(rider, Chars.CR); DStrings.WriteChar(rider, Chars.LF);
  DStrings.WriteString(rider, "X-Test: Artemis");
  DStrings.WriteChar(rider, Chars.CR); DStrings.WriteChar(rider, Chars.LF);
  DStrings.WriteChar(rider, Chars.CR); DStrings.WriteChar(rider, Chars.LF);
  DStrings.WriteString(rider, "Hello, world!");
  DStrings.ToChars(dstr, raw, res);
  Out.String("[TEST DEBUG] raw: "); Out.String(raw); Out.String(" len: "); Out.Int(res, 0); Out.Ln();
  ok := HttpResponse.Parse(raw, resp);
  Tests.ExpectedBool(TRUE, ok, "Parse returns TRUE for valid response with headers", pass);
  DStrings.Init("", value);
  found := HttpResponse.GetHeader(resp, "Content-Type", value);
  Tests.ExpectedBool(TRUE, found, "Content-Type header found", pass);
  DStrings.ToChars(value, raw, res);
  Tests.ExpectedString("text/plain", raw, "Content-Type value is 'text/plain'", pass);
  found := HttpResponse.GetHeader(resp, "X-Test", value);
  Tests.ExpectedBool(TRUE, found, "X-Test header found", pass);
  DStrings.ToChars(value, raw, res);
  Tests.ExpectedString("Artemis", raw, "X-Test value is 'Artemis'", pass);
  found := HttpResponse.GetHeader(resp, "Missing", value);
  Tests.ExpectedBool(FALSE, found, "Missing header not found", pass);
  DStrings.Init("", body);
  HttpResponse.GetBody(resp, body);
  DStrings.ToChars(body, buf, res);
  Tests.ExpectedString("Hello, world!", buf, "Body is 'Hello, world!'", pass);
  RETURN pass
END TestParseHeader;

BEGIN
  Tests.Init(ts, "HttpResponse Tests");
  Tests.Add(ts, TestInit);
  Tests.Add(ts, TestParseStub);
  Tests.Add(ts, TestParseStatusLine);
  Tests.Add(ts, TestParseHeader);
  ASSERT(Tests.Run(ts));
END HttpResponseTest.
