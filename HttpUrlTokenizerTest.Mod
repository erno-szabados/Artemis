MODULE HttpUrlTokenizerTest;

IMPORT HttpUrlTokenizer, Tests, DStrings;

VAR 
    ts : Tests.TestSet;

PROCEDURE TestBasicScheme*(): BOOLEAN;
VAR
    pass: BOOLEAN;
    tokenizer: HttpUrlTokenizer.Tokenizer;
    token: HttpUrlTokenizer.Token;
    value: ARRAY 64 OF CHAR;
    res: INTEGER;
BEGIN
    pass := TRUE;
    
    HttpUrlTokenizer.Init(tokenizer, "http:");
    
    HttpUrlTokenizer.NextToken(tokenizer, token);
    Tests.ExpectedInt(HttpUrlTokenizer.SchemeToken, token.type, "Scheme token type", pass);
    DStrings.ToChars(token.value, value, res);
    Tests.ExpectedString("http", value, "Scheme token value", pass);
    
    RETURN pass
END TestBasicScheme;

PROCEDURE TestSlashSlash*(): BOOLEAN;
VAR
    pass: BOOLEAN;
    tokenizer: HttpUrlTokenizer.Tokenizer;
    token: HttpUrlTokenizer.Token;
    value: ARRAY 64 OF CHAR;
    res: INTEGER;
BEGIN
    pass := TRUE;
    
    HttpUrlTokenizer.Init(tokenizer, "//example.com");
    
    HttpUrlTokenizer.NextToken(tokenizer, token);
    Tests.ExpectedInt(HttpUrlTokenizer.SlashSlashToken, token.type, "SlashSlash token type", pass);
    DStrings.ToChars(token.value, value, res);
    Tests.ExpectedString("//", value, "SlashSlash token value", pass);
    
    HttpUrlTokenizer.NextToken(tokenizer, token);
    Tests.ExpectedInt(HttpUrlTokenizer.HostToken, token.type, "Host token type", pass);
    DStrings.ToChars(token.value, value, res);
    Tests.ExpectedString("example.com", value, "Host token value", pass);
    
    RETURN pass
END TestSlashSlash;

PROCEDURE TestSimpleHost*(): BOOLEAN;
VAR
    pass: BOOLEAN;
    tokenizer: HttpUrlTokenizer.Tokenizer;
    token: HttpUrlTokenizer.Token;
    value: ARRAY 64 OF CHAR;
    res: INTEGER;
BEGIN
    pass := TRUE;
    
    HttpUrlTokenizer.Init(tokenizer, "example.com");
    
    HttpUrlTokenizer.NextToken(tokenizer, token);
    Tests.ExpectedInt(HttpUrlTokenizer.HostToken, token.type, "Simple host token type", pass);
    DStrings.ToChars(token.value, value, res);
    Tests.ExpectedString("example.com", value, "Simple host token value", pass);
    
    HttpUrlTokenizer.NextToken(tokenizer, token);
    Tests.ExpectedInt(HttpUrlTokenizer.EofToken, token.type, "EOF after host", pass);
    
    RETURN pass
END TestSimpleHost;

PROCEDURE TestPathOnly*(): BOOLEAN;
VAR
    pass: BOOLEAN;
    tokenizer: HttpUrlTokenizer.Tokenizer;
    token: HttpUrlTokenizer.Token;
    value: ARRAY 64 OF CHAR;
    res: INTEGER;
BEGIN
    pass := TRUE;
    
    HttpUrlTokenizer.Init(tokenizer, "/path/to/file");
    
    HttpUrlTokenizer.NextToken(tokenizer, token);
    Tests.ExpectedInt(HttpUrlTokenizer.PathToken, token.type, "Path only token type", pass);
    DStrings.ToChars(token.value, value, res);
    Tests.ExpectedString("/path/to/file", value, "Path only token value", pass);
    
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
    tokenizer: HttpUrlTokenizer.Tokenizer;
    token: HttpUrlTokenizer.Token;
    value: ARRAY 64 OF CHAR;
    res: INTEGER;
BEGIN
    pass := TRUE;
    HttpUrlTokenizer.Init(tokenizer, "https://example.com:8080/foo/bar?x=1&y=2#frag");

    HttpUrlTokenizer.NextToken(tokenizer, token);
    Tests.ExpectedInt(HttpUrlTokenizer.SchemeToken, token.type, "Scheme token type", pass);
    DStrings.ToChars(token.value, value, res);
    Tests.ExpectedString("https", value, "Scheme token value", pass);

    HttpUrlTokenizer.NextToken(tokenizer, token);
    Tests.ExpectedInt(HttpUrlTokenizer.SlashSlashToken, token.type, "SlashSlash token type", pass);
    DStrings.ToChars(token.value, value, res);
    Tests.ExpectedString("//", value, "SlashSlash token value", pass);

    HttpUrlTokenizer.NextToken(tokenizer, token);
    Tests.ExpectedInt(HttpUrlTokenizer.HostToken, token.type, "Host token type", pass);
    DStrings.ToChars(token.value, value, res);
    Tests.ExpectedString("example.com", value, "Host token value", pass);

    HttpUrlTokenizer.NextToken(tokenizer, token);
    Tests.ExpectedInt(HttpUrlTokenizer.PortToken, token.type, "Port token type", pass);
    DStrings.ToChars(token.value, value, res);
    Tests.ExpectedString("8080", value, "Port token value", pass);

    HttpUrlTokenizer.NextToken(tokenizer, token);
    Tests.ExpectedInt(HttpUrlTokenizer.PathToken, token.type, "Path token type", pass);
    DStrings.ToChars(token.value, value, res);
    Tests.ExpectedString("/foo/bar", value, "Path token value", pass);

    HttpUrlTokenizer.NextToken(tokenizer, token);
    Tests.ExpectedInt(HttpUrlTokenizer.QueryStartToken, token.type, "Query start token type", pass);
    DStrings.ToChars(token.value, value, res);
    Tests.ExpectedString("?", value, "Query start token value", pass);

    HttpUrlTokenizer.NextToken(tokenizer, token);
    Tests.ExpectedInt(HttpUrlTokenizer.QueryKeyToken, token.type, "Query key token type", pass);
    DStrings.ToChars(token.value, value, res);
    Tests.ExpectedString("x", value, "Query key token value", pass);

    HttpUrlTokenizer.NextToken(tokenizer, token);
    Tests.ExpectedInt(HttpUrlTokenizer.QueryEqualsToken, token.type, "Query equals token type", pass);
    DStrings.ToChars(token.value, value, res);
    Tests.ExpectedString("=", value, "Query equals token value", pass);

    HttpUrlTokenizer.NextToken(tokenizer, token);
    Tests.ExpectedInt(HttpUrlTokenizer.QueryValueToken, token.type, "Query value token type", pass);
    DStrings.ToChars(token.value, value, res);
    Tests.ExpectedString("1", value, "Query value token value", pass);

    HttpUrlTokenizer.NextToken(tokenizer, token);
    Tests.ExpectedInt(HttpUrlTokenizer.QuerySeparatorToken, token.type, "Query separator token type", pass);
    DStrings.ToChars(token.value, value, res);
    Tests.ExpectedString("&", value, "Query separator token value", pass);

    HttpUrlTokenizer.NextToken(tokenizer, token);
    Tests.ExpectedInt(HttpUrlTokenizer.QueryKeyToken, token.type, "Query key2 token type", pass);
    DStrings.ToChars(token.value, value, res);
    Tests.ExpectedString("y", value, "Query key2 token value", pass);

    HttpUrlTokenizer.NextToken(tokenizer, token);
    Tests.ExpectedInt(HttpUrlTokenizer.QueryEqualsToken, token.type, "Query equals2 token type", pass);
    DStrings.ToChars(token.value, value, res);
    Tests.ExpectedString("=", value, "Query equals2 token value", pass);

    HttpUrlTokenizer.NextToken(tokenizer, token);
    Tests.ExpectedInt(HttpUrlTokenizer.QueryValueToken, token.type, "Query value2 token type", pass);
    DStrings.ToChars(token.value, value, res);
    Tests.ExpectedString("2", value, "Query value2 token value", pass);

    HttpUrlTokenizer.NextToken(tokenizer, token);
    Tests.ExpectedInt(HttpUrlTokenizer.FragmentStartToken, token.type, "Fragment start token type", pass);
    DStrings.ToChars(token.value, value, res);
    Tests.ExpectedString("#", value, "Fragment start token value", pass);

    HttpUrlTokenizer.NextToken(tokenizer, token);
    Tests.ExpectedInt(HttpUrlTokenizer.FragmentToken, token.type, "Fragment token type", pass);
    DStrings.ToChars(token.value, value, res);
    Tests.ExpectedString("frag", value, "Fragment token value", pass);

    HttpUrlTokenizer.NextToken(tokenizer, token);
    Tests.ExpectedInt(HttpUrlTokenizer.EofToken, token.type, "EOF after full URL", pass);

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