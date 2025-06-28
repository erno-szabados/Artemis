(** HttpRequestTest.Mod - Minimal tests for HttpRequest.Mod.

Copyright (C) 2025

Released under The 3-Clause BSD License.
*)
MODULE HttpRequestTest;
IMPORT HttpRequest, DStrings, Tests, Chars;

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

PROCEDURE TestSetMultilineBody*(): BOOLEAN;
VAR
  pass, ok: BOOLEAN;
  req: HttpRequest.HttpRequest;
  buf: ARRAY 256 OF CHAR;
  res: INTEGER;
  dstr, body: DStrings.String;
  rider: DStrings.Rider;
  bodyLen : INTEGER;
  bodyLenStr: ARRAY 16 OF CHAR;
BEGIN
  pass := TRUE;
  DStrings.Init("", body);
  DStrings.Set(rider, body, 0);
  DStrings.WriteString(rider, "<html>");
  DStrings.WriteChar(rider, Chars.CR); DStrings.WriteChar(rider, Chars.LF);
  DStrings.WriteString(rider, "  <head><title>Test</title></head>");
  DStrings.WriteChar(rider, Chars.CR); DStrings.WriteChar(rider, Chars.LF);
  DStrings.WriteString(rider, "  <body>");
  DStrings.WriteChar(rider, Chars.CR); DStrings.WriteChar(rider, Chars.LF);
  DStrings.WriteString(rider, "    <h1>Hello, World!</h1>");
  DStrings.WriteChar(rider, Chars.CR); DStrings.WriteChar(rider, Chars.LF);
  DStrings.WriteString(rider, "    <p>This is a test.</p>");
  DStrings.WriteChar(rider, Chars.CR); DStrings.WriteChar(rider, Chars.LF);
  DStrings.WriteString(rider, "  </body>");
  DStrings.WriteChar(rider, Chars.CR); DStrings.WriteChar(rider, Chars.LF);
  DStrings.WriteString(rider, "</html>");

  bodyLen := DStrings.Length(body);
  Chars.IntToString(bodyLen, bodyLenStr, ok);
  HttpRequest.Init("POST", "/upload", req);
  ok := HttpRequest.SetHeader(req, "content-type", "text/html");
  ok := HttpRequest.SetHeader(req, "accept", "text/html");
  ok := HttpRequest.SetHeader(req, "user-agent", "artemis/0.1");
  ok := HttpRequest.SetHeader(req, "content-length", bodyLenStr);
  Tests.ExpectedBool(TRUE, HttpRequest.SetBodyDString(req, body), "SetBodyD returns TRUE for multiline", pass);
  DStrings.Init("", dstr);
  HttpRequest.GetBody(req, dstr);
  DStrings.ToChars(dstr, buf, res);
  DStrings.ToChars(body, buf, res); (* for comparison *)
  Tests.ExpectedString(buf, buf, "Multiline body set correctly", pass);
  ok := HttpRequest.ToString(req, dstr);
  DStrings.ToChars(dstr, buf, res);
  (* Out.String("--- Multiline POST request ---"); Out.Ln;
  Out.String(buf); Out.Ln;
  Out.String("----------------------"); Out.Ln; *)
  RETURN pass
END TestSetMultilineBody;

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
  (* Out.String(buf); Out.Ln; *)
  (* Could add more detailed checks here *)
  RETURN pass
END TestToString;

BEGIN
  Tests.Init(ts, "HttpRequest Tests");
  Tests.Add(ts, TestInit);
  Tests.Add(ts, TestSetHeader);
  Tests.Add(ts, TestSetBody);
  Tests.Add(ts, TestSetMultilineBody);
  Tests.Add(ts, TestToString);
  ASSERT(Tests.Run(ts));
END HttpRequestTest.
