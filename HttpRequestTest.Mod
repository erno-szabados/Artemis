(** HttpRequestTest.Mod - Minimal tests for HttpRequest.Mod.

Copyright (C) 2025

Released under The 3-Clause BSD License.
*)
MODULE HttpRequestTest;
IMPORT HttpRequest, DStrings, Tests, Out;

VAR
  ts: Tests.TestSet;

PROCEDURE TestInit*(): BOOLEAN;
VAR
  pass: BOOLEAN;
  req: HttpRequest.HttpRequest;
  method, url: ARRAY 32 OF CHAR;
  m, u: ARRAY 32 OF CHAR;
  res: INTEGER;
  dstr: DStrings.String;
BEGIN
  pass := TRUE;
  method := "GET";
  url := "/index.html";
  HttpRequest.Init(method, url, req);
  DStrings.Init("", dstr);
  HttpRequest.GetMethod(req, dstr);
  DStrings.ToChars(dstr, m, res);
  HttpRequest.GetUrl(req, dstr);
  DStrings.ToChars(dstr, u, res);
  Tests.ExpectedString(method, m, "Method initialized", pass);
  Tests.ExpectedString(url, u, "URL initialized", pass);
  RETURN pass
END TestInit;

PROCEDURE TestSetHeader*(): BOOLEAN;
VAR
  pass: BOOLEAN;
  req: HttpRequest.HttpRequest;
  value: DStrings.String;
  buf: ARRAY 64 OF CHAR;
  res: INTEGER;
BEGIN
  pass := TRUE;
  HttpRequest.Init("GET", "/", req);
  Tests.ExpectedBool(TRUE, HttpRequest.SetHeader(req, "Host", "example.com"), "SetHeader returns TRUE", pass);
  Tests.ExpectedBool(TRUE, HttpRequest.SetHeader(req, "User-Agent", "TestAgent"), "SetHeader returns TRUE", pass);
  DStrings.Init("", value);
  IF HttpRequest.GetHeader(req, "Host", value) THEN
    DStrings.ToChars(value, buf, res);
    Tests.ExpectedString("example.com", buf, "Host header value", pass)
  ELSE
    pass := FALSE
  END;
  IF HttpRequest.GetHeader(req, "User-Agent", value) THEN
    DStrings.ToChars(value, buf, res);
    Tests.ExpectedString("TestAgent", buf, "User-Agent header value", pass)
  ELSE
    pass := FALSE
  END;
  RETURN pass
END TestSetHeader;

PROCEDURE TestSetBody*(): BOOLEAN;
VAR
  pass: BOOLEAN;
  req: HttpRequest.HttpRequest;
  body: ARRAY 64 OF CHAR;
  buf: ARRAY 64 OF CHAR;
  res: INTEGER;
  dstr: DStrings.String;
BEGIN
  pass := TRUE;
  HttpRequest.Init("POST", "/submit", req);
  body := "test body";
  Tests.ExpectedBool(TRUE, HttpRequest.SetBody(req, body), "SetBody returns TRUE", pass);
  DStrings.Init("", dstr);
  HttpRequest.GetBody(req, dstr);
  DStrings.ToChars(dstr, buf, res);
  Tests.ExpectedString(body, buf, "Body set correctly", pass);
  RETURN pass
END TestSetBody;

PROCEDURE TestToString*(): BOOLEAN;
VAR
  ok, pass: BOOLEAN;
  req: HttpRequest.HttpRequest;
  out: DStrings.String;
  buf: ARRAY 256 OF CHAR;
  res: INTEGER;
BEGIN
  pass := TRUE;
  HttpRequest.Init("GET", "/", req);
  ok := HttpRequest.SetHeader(req, "Host", "example.com");
  ok := HttpRequest.SetBody(req, "");
  Tests.ExpectedBool(TRUE, HttpRequest.ToString(req, out), "ToString returns TRUE", pass);
  DStrings.ToChars(out, buf, res);
  Out.String(buf); Out.Ln;
  (* Could add more detailed checks here *)
  RETURN pass
END TestToString;

BEGIN
  Tests.Init(ts, "HttpRequest Tests");
  Tests.Add(ts, TestInit);
  Tests.Add(ts, TestSetHeader);
  Tests.Add(ts, TestSetBody);
  Tests.Add(ts, TestToString);
  ASSERT(Tests.Run(ts));
END HttpRequestTest.
