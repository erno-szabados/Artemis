MODULE HttpUrlTest;

IMPORT HttpUrl, Tests, DStrings;

VAR 
    ts : Tests.TestSet;

PROCEDURE TestParse*(): BOOLEAN;
VAR
  pass: BOOLEAN;
  url: HttpUrl.Url;
  raw: ARRAY 256 OF CHAR;
  ok: BOOLEAN;
  pathStr, queryStr, fragStr: ARRAY 256 OF CHAR;
  res: INTEGER;
BEGIN
  pass := TRUE;
  raw := "http://example.com:8080/path/to/resource?key1=value1&key2=value2#section";
  
  ok := HttpUrl.Parse(raw, url);
  Tests.ExpectedBool(TRUE, ok, "Parse basic URL", pass);
  
  IF ok THEN
    Tests.ExpectedString("http", url.scheme, "Scheme parsing", pass);
    Tests.ExpectedString("example.com", url.host, "Host parsing", pass);
    Tests.ExpectedInt(8080, url.port, "Port parsing", pass);
    
    (* Test path *)
    DStrings.ToChars(url.path, pathStr, res);
    Tests.ExpectedString("/path/to/resource", pathStr, "Path parsing", pass);
    
    (* Test query *)
    DStrings.ToChars(url.query, queryStr, res);
    Tests.ExpectedString("key1=value1&key2=value2", queryStr, "Query parsing", pass);
    
    (* Test fragment *)
    DStrings.ToChars(url.frag, fragStr, res);
    Tests.ExpectedString("section", fragStr, "Fragment parsing", pass)
  END;
  
  RETURN pass
END TestParse;

PROCEDURE TestParseSimple*(): BOOLEAN;
VAR
  pass: BOOLEAN;
  url: HttpUrl.Url;
  raw: ARRAY 256 OF CHAR;
  ok: BOOLEAN;
  pathStr: ARRAY 256 OF CHAR;
  res: INTEGER;
BEGIN
  pass := TRUE;
  raw := "https://example.com/simple";
  
  ok := HttpUrl.Parse(raw, url);
  Tests.ExpectedBool(TRUE, ok, "Parse simple URL", pass);
  
  IF ok THEN
    Tests.ExpectedString("https", url.scheme, "Simple scheme parsing", pass);
    Tests.ExpectedString("example.com", url.host, "Simple host parsing", pass);
    Tests.ExpectedInt(0, url.port, "Simple port parsing (default)", pass);
    
    DStrings.ToChars(url.path, pathStr, res);
    Tests.ExpectedString("/simple", pathStr, "Simple path parsing", pass)
  END;
  
  RETURN pass
END TestParseSimple;

PROCEDURE TestToString*(): BOOLEAN;
VAR
  pass: BOOLEAN;
  url: HttpUrl.Url;
  raw: ARRAY 256 OF CHAR;
  out: DStrings.String;
  buf: ARRAY 512 OF CHAR;
  res: INTEGER;
  ok: BOOLEAN;
BEGIN
  pass := TRUE;
  raw := "http://example.com:8080/foo?bar=baz#qux";
  NEW(url);
  ok := HttpUrl.Parse(raw, url);
  Tests.ExpectedBool(TRUE, ok, "Parse for ToString", pass);
  IF ok THEN
    ok := HttpUrl.ToString(url, out);
    Tests.ExpectedBool(TRUE, ok, "ToString returns ok", pass);
    DStrings.ToChars(out, buf, res);
    Tests.ExpectedString(raw, buf, "Round-trip ToString", pass);
  END;
  RETURN pass
END TestToString;

PROCEDURE TestGetParam*(): BOOLEAN;
VAR
  pass: BOOLEAN;
  url: HttpUrl.Url;
  raw: ARRAY 256 OF CHAR;
  value: DStrings.String;
  buf: ARRAY 128 OF CHAR;
  res: INTEGER;
  found: BOOLEAN;
BEGIN
  pass := TRUE;
  raw := "http://example.com/path?x=123&y=abc";
  NEW(url);
  IF HttpUrl.Parse(raw, url) THEN
    found := HttpUrl.GetParam(url, "x", value);
    Tests.ExpectedBool(TRUE, found, "GetParam x found", pass);
    IF found THEN DStrings.ToChars(value, buf, res); Tests.ExpectedString("123", buf, "GetParam x value", pass) END;
    found := HttpUrl.GetParam(url, "y", value);
    Tests.ExpectedBool(TRUE, found, "GetParam y found", pass);
    IF found THEN DStrings.ToChars(value, buf, res); Tests.ExpectedString("abc", buf, "GetParam y value", pass) END;
    found := HttpUrl.GetParam(url, "z", value);
    Tests.ExpectedBool(FALSE, found, "GetParam missing returns false", pass);
  ELSE
    Tests.ExpectedBool(FALSE, TRUE, "GetParam Parse failed", pass);
    pass := FALSE;
  END;
  RETURN pass
END TestGetParam;

PROCEDURE TestSetParam*(): BOOLEAN;
VAR
  pass: BOOLEAN;
  url: HttpUrl.Url;
  raw: ARRAY 256 OF CHAR;
  out: DStrings.String;
  buf: ARRAY 512 OF CHAR;
  res: INTEGER;
  ok: BOOLEAN;
BEGIN
  pass := TRUE;
  raw := "http://example.com/path";
  NEW(url);
  ok := HttpUrl.Parse(raw, url);
  Tests.ExpectedBool(TRUE, ok, "Parse for SetParam", pass);
  IF ok THEN
    ok := HttpUrl.SetParam(url, "foo", "bar");
    Tests.ExpectedBool(TRUE, ok, "SetParam new param", pass);
    ok := HttpUrl.ToString(url, out);
    Tests.ExpectedBool(TRUE, ok, "ToString after SetParam", pass);
    DStrings.ToChars(out, buf, res);
    Tests.ExpectedString("http://example.com/path?foo=bar", buf, "URL with new param", pass);
  END;
  RETURN pass
END TestSetParam;

BEGIN
  Tests.Init(ts, "HTTP URL Tests");
  Tests.Add(ts, TestParse);
  Tests.Add(ts, TestParseSimple);
  Tests.Add(ts, TestToString);
  Tests.Add(ts, TestGetParam);
  Tests.Add(ts, TestSetParam);
  ASSERT(Tests.Run(ts))
END HttpUrlTest.