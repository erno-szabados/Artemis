MODULE HttpUrlTokenizerTest;

IMPORT HttpUrlTokenizer, Tests, DStrings;

VAR 
    ts : Tests.TestSet;

(* Helper: Run a tokenizer test case with expected token types and values *)
PROCEDURE RunTokenizerCase(input: ARRAY OF CHAR; expectedTypes: ARRAY OF INTEGER; expectedValues: ARRAY OF ARRAY OF CHAR; testName: ARRAY OF CHAR; VAR pass: BOOLEAN);
VAR tokenizer: HttpUrlTokenizer.Tokenizer;
    token: HttpUrlTokenizer.Token;
    value: ARRAY 64 OF CHAR;
    res, i: INTEGER;
BEGIN
    HttpUrlTokenizer.Init(tokenizer, input);
    i := 0;
    WHILE i < LEN(expectedTypes) DO
        HttpUrlTokenizer.NextToken(tokenizer, token);
        Tests.ExpectedInt(expectedTypes[i], token.type, testName, pass);
        IF i < LEN(expectedValues) THEN
            DStrings.ToChars(token.value, value, res);
            Tests.ExpectedString(expectedValues[i], value, testName, pass)
        END;
        INC(i)
    END
END RunTokenizerCase;

PROCEDURE TestBasicScheme*(): BOOLEAN;
VAR pass: BOOLEAN;
    expectedTypes: ARRAY 2 OF INTEGER;
    expectedValues: ARRAY 2 OF ARRAY 32 OF CHAR;
BEGIN
    pass := TRUE;
    expectedTypes[0] := HttpUrlTokenizer.SchemeToken;
    expectedTypes[1] := HttpUrlTokenizer.EofToken;
    expectedValues[0] := "http";
    expectedValues[1] := "";
    RunTokenizerCase("http:", expectedTypes, expectedValues, "Basic scheme", pass);
    RETURN pass
END TestBasicScheme;

PROCEDURE TestSlashSlash*(): BOOLEAN;
VAR pass: BOOLEAN;
    expectedTypes: ARRAY 3 OF INTEGER;
    expectedValues: ARRAY 3 OF ARRAY 32 OF CHAR;
BEGIN
    pass := TRUE;
    expectedTypes[0] := HttpUrlTokenizer.SlashSlashToken;
    expectedTypes[1] := HttpUrlTokenizer.HostToken;
    expectedTypes[2] := HttpUrlTokenizer.EofToken;
    expectedValues[0] := "//";
    expectedValues[1] := "example.com";
    expectedValues[2] := "";
    RunTokenizerCase("//example.com", expectedTypes, expectedValues, "SlashSlash", pass);
    RETURN pass
END TestSlashSlash;

PROCEDURE TestSimpleHost*(): BOOLEAN;
VAR pass: BOOLEAN;
    expectedTypes: ARRAY 2 OF INTEGER;
    expectedValues: ARRAY 2 OF ARRAY 32 OF CHAR;
BEGIN
    pass := TRUE;
    expectedTypes[0] := HttpUrlTokenizer.HostToken;
    expectedTypes[1] := HttpUrlTokenizer.EofToken;
    expectedValues[0] := "example.com";
    expectedValues[1] := "";
    RunTokenizerCase("example.com", expectedTypes, expectedValues, "Simple host", pass);
    RETURN pass
END TestSimpleHost;

PROCEDURE TestPathOnly*(): BOOLEAN;
VAR pass: BOOLEAN;
    expectedTypes: ARRAY 1 OF INTEGER;
    expectedValues: ARRAY 1 OF ARRAY 32 OF CHAR;
BEGIN
    pass := TRUE;
    expectedTypes[0] := HttpUrlTokenizer.PathToken;
    expectedValues[0] := "/path/to/file";
    RunTokenizerCase("/path/to/file", expectedTypes, expectedValues, "Path only", pass);
    RETURN pass
END TestPathOnly;

PROCEDURE TestUtilityFunctions*(): BOOLEAN;
VAR
    pass: BOOLEAN;
    tokenizer: HttpUrlTokenizer.Tokenizer;
BEGIN
    pass := TRUE;
    
    HttpUrlTokenizer.Init(tokenizer, "http://example.com");
    
    Tests.ExpectedBool(FALSE, HttpUrlTokenizer.AtEof(tokenizer), "Not at EOF initially", pass);
    Tests.ExpectedInt(0, HttpUrlTokenizer.GetPos(tokenizer), "Initial position", pass);
    Tests.ExpectedInt(HttpUrlTokenizer.NoError, HttpUrlTokenizer.GetError(tokenizer), "No error initially", pass);
    
    RETURN pass
END TestUtilityFunctions;

PROCEDURE TestFullURL*(): BOOLEAN;
VAR pass: BOOLEAN;
    expectedTypes: ARRAY 16 OF INTEGER;
    expectedValues: ARRAY 16 OF ARRAY 32 OF CHAR;
BEGIN
    pass := TRUE;
    expectedTypes[0] := HttpUrlTokenizer.SchemeToken;
    expectedTypes[1] := HttpUrlTokenizer.SlashSlashToken;
    expectedTypes[2] := HttpUrlTokenizer.HostToken;
    expectedTypes[3] := HttpUrlTokenizer.PortToken;
    expectedTypes[4] := HttpUrlTokenizer.PathToken;
    expectedTypes[5] := HttpUrlTokenizer.QueryStartToken;
    expectedTypes[6] := HttpUrlTokenizer.QueryKeyToken;
    expectedTypes[7] := HttpUrlTokenizer.QueryEqualsToken;
    expectedTypes[8] := HttpUrlTokenizer.QueryValueToken;
    expectedTypes[9] := HttpUrlTokenizer.QuerySeparatorToken;
    expectedTypes[10] := HttpUrlTokenizer.QueryKeyToken;
    expectedTypes[11] := HttpUrlTokenizer.QueryEqualsToken;
    expectedTypes[12] := HttpUrlTokenizer.QueryValueToken;
    expectedTypes[13] := HttpUrlTokenizer.FragmentStartToken;
    expectedTypes[14] := HttpUrlTokenizer.FragmentToken;
    expectedTypes[15] := HttpUrlTokenizer.EofToken;
    expectedValues[0] := "https";
    expectedValues[1] := "//";
    expectedValues[2] := "example.com";
    expectedValues[3] := "8080";
    expectedValues[4] := "/foo/bar";
    expectedValues[5] := "?";
    expectedValues[6] := "x";
    expectedValues[7] := "=";
    expectedValues[8] := "1";
    expectedValues[9] := "&";
    expectedValues[10] := "y";
    expectedValues[11] := "=";
    expectedValues[12] := "2";
    expectedValues[13] := "#";
    expectedValues[14] := "frag";
    expectedValues[15] := "";
    RunTokenizerCase("https://example.com:8080/foo/bar?x=1&y=2#frag", expectedTypes, expectedValues, "Full URL", pass);
    RETURN pass
END TestFullURL;

BEGIN
  Tests.Init(ts, "HTTP URL Tokenizer Tests");
  Tests.Add(ts, TestBasicScheme);
  Tests.Add(ts, TestSlashSlash);
  Tests.Add(ts, TestSimpleHost);
  Tests.Add(ts, TestPathOnly);
  Tests.Add(ts, TestUtilityFunctions);
  Tests.Add(ts, TestFullURL);
  ASSERT(Tests.Run(ts))
END HttpUrlTokenizerTest.