MODULE HttpHeaderTest;

IMPORT HttpHeader, Tests, DStrings, Chars;

VAR
  ts : Tests.TestSet;

PROCEDURE TestInit*(): BOOLEAN;
VAR
  pass: BOOLEAN;
  h: HttpHeader.Header;
BEGIN
  pass := TRUE;
  HttpHeader.Init(h);
  Tests.ExpectedBool(h # NIL, TRUE, "Header initialized", pass);
  RETURN pass
END TestInit;

PROCEDURE TestSetGet*(): BOOLEAN;
VAR
  pass: BOOLEAN;
  h: HttpHeader.Header;
  value, expected: DStrings.String;
  ok: BOOLEAN;
BEGIN
  pass := TRUE;
  HttpHeader.Init(h);
  ok := HttpHeader.Set(h, "Content-Type", "text/plain");
  ok := HttpHeader.Get(h, "Content-Type", value);
  DStrings.Init("text/plain", expected);
  Tests.ExpectedBool(TRUE, ok, "Get after Set", pass);
  IF ok THEN
    Tests.ExpectedBool(DStrings.Equal(value, expected), TRUE, "Value matches", pass)
  END;
  RETURN pass
END TestSetGet;

PROCEDURE TestRemove*(): BOOLEAN;
VAR
  pass: BOOLEAN;
  h: HttpHeader.Header;
  value: DStrings.String;
  ok: BOOLEAN;
BEGIN
  pass := TRUE;
  HttpHeader.Init(h);
  ok := HttpHeader.Set(h, "X-Test", "foo");
  ok := HttpHeader.Remove(h, "X-Test");
  Tests.ExpectedBool(TRUE, ok, "Remove returns TRUE", pass);
  ok := HttpHeader.Get(h, "X-Test", value);
  Tests.ExpectedBool(FALSE, ok, "Get after Remove returns FALSE", pass);
  RETURN pass
END TestRemove;

PROCEDURE AppendCRLF(VAR s: DStrings.String);
VAR r: DStrings.Rider;
BEGIN
  DStrings.Set(r, s, DStrings.Length(s));
  DStrings.WriteChar(r, Chars.CR);
  DStrings.WriteChar(r, Chars.LF)
END AppendCRLF;

PROCEDURE TestToString*(): BOOLEAN;
VAR
  pass: BOOLEAN;
  h: HttpHeader.Header;
  out, expected: DStrings.String;
  ok: BOOLEAN;
  tmp: DStrings.String;
  r: DStrings.Rider;
  match: BOOLEAN;
BEGIN
  pass := TRUE;
  HttpHeader.Init(h);
  ok := HttpHeader.Set(h, "Content-Type", "text/plain");
  ok := HttpHeader.Set(h, "X-Test", "foo");
  ok := HttpHeader.ToString(h, out);
  (* The order of fields is not guaranteed, so check for both possible orderings, and expect uppercase keys *)
  DStrings.Init("CONTENT-TYPE: text/plain", expected); AppendCRLF(expected);
  DStrings.Init("X-TEST: foo", tmp); DStrings.Set(r, expected, DStrings.Length(expected)); DStrings.WriteDString(r, tmp); AppendCRLF(expected);
  match := DStrings.Equal(out, expected);
  IF ~match THEN
    DStrings.Init("X-TEST: foo", expected); AppendCRLF(expected);
    DStrings.Init("CONTENT-TYPE: text/plain", tmp); DStrings.Set(r, expected, DStrings.Length(expected)); DStrings.WriteDString(r, tmp); AppendCRLF(expected);
    match := DStrings.Equal(out, expected);
  END;
  IF ~match THEN
    Tests.ExpectedBool(TRUE, FALSE, "ToString output does not match any expected order", pass)
  ELSE
    Tests.ExpectedBool(TRUE, TRUE, "ToString output matches expected order (uppercase)", pass)
  END;

  RETURN pass
END TestToString;

PROCEDURE TestParse() : BOOLEAN;
VAR
  pass: BOOLEAN;
  h: HttpHeader.Header;
  rawHeaders: ARRAY 512 OF CHAR;
  value: DStrings.String;
  ok: BOOLEAN;
  rawStr: DStrings.String;
  r: DStrings.Rider;
  res: INTEGER;
  valueBuf: ARRAY 256 OF CHAR;
BEGIN
  pass := TRUE;
  
  (* Test parsing basic headers *)
  DStrings.Init("", rawStr);
  DStrings.Set(r, rawStr, 0);
  DStrings.WriteString(r, "Content-Type: text/html");
  DStrings.WriteChar(r, Chars.CR);
  DStrings.WriteChar(r, Chars.LF);
  DStrings.WriteString(r, "Content-Length: 1234");
  DStrings.WriteChar(r, Chars.CR);
  DStrings.WriteChar(r, Chars.LF);
  DStrings.WriteString(r, "X-Custom-Header: custom value");
  DStrings.WriteChar(r, Chars.CR);
  DStrings.WriteChar(r, Chars.LF);
  DStrings.ToChars(rawStr, rawHeaders, res);
  
  HttpHeader.Init(h);
  ok := HttpHeader.Parse(rawHeaders, h);
  Tests.ExpectedBool(TRUE, ok, "Parse should succeed", pass);
  
  (* Test retrieved values (case-insensitive) *)
  ok := HttpHeader.Get(h, "content-type", value);
  Tests.ExpectedBool(TRUE, ok, "Get content-type should succeed", pass);
  Chars.Clear(valueBuf);
  DStrings.ToChars(value, valueBuf, res);
  Tests.ExpectedString("text/html", valueBuf, "content-type value", pass);
  

  ok := HttpHeader.Get(h, "CONTENT-LENGTH", value);
  Tests.ExpectedBool(TRUE, ok, "Get CONTENT-LENGTH should succeed", pass);
  Chars.Clear(valueBuf);
  DStrings.ToChars(value, valueBuf, res);
  Tests.ExpectedString("1234", valueBuf, "content-length value", pass);
  

  ok := HttpHeader.Get(h, "x-custom-header", value);
  Tests.ExpectedBool(TRUE, ok, "Get x-custom-header should succeed", pass);
  Chars.Clear(valueBuf);
  DStrings.ToChars(value, valueBuf, res);
  Tests.ExpectedString("custom value", valueBuf, "custom header value", pass);
  
  (* Test parsing with whitespace *)
  DStrings.Init("", rawStr);
  DStrings.Set(r, rawStr, 0);
  DStrings.WriteString(r, "Header-With-Spaces:   value with spaces   ");
  DStrings.WriteChar(r, Chars.CR);
  DStrings.WriteChar(r, Chars.LF);
  DStrings.ToChars(rawStr, rawHeaders, res);
  
  HttpHeader.Init(h);
  ok := HttpHeader.Parse(rawHeaders, h);
  Tests.ExpectedBool(TRUE, ok, "Parse with spaces should succeed", pass);
  
  ok := HttpHeader.Get(h, "header-with-spaces", value);
  Tests.ExpectedBool(TRUE, ok, "Get header with spaces should succeed", pass);
  DStrings.ToChars(value, valueBuf, res);
  Tests.ExpectedString("value with spaces", valueBuf, "header value should be trimmed", pass);
  
  (* Test empty input *)
  rawHeaders := "";
  HttpHeader.Init(h);
  ok := HttpHeader.Parse(rawHeaders, h);
  Tests.ExpectedBool(TRUE, ok, "Parse empty input should succeed", pass);
  
  RETURN pass
END TestParse;

BEGIN
  Tests.Init(ts, "HTTP Header Tests");
  Tests.Add(ts, TestInit);
  Tests.Add(ts, TestSetGet);
  Tests.Add(ts, TestRemove);
  Tests.Add(ts, TestToString);
  Tests.Add(ts, TestParse);
  ASSERT(Tests.Run(ts))
END HttpHeaderTest.
