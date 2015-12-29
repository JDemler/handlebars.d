module handlebars.d;
//TODO: Write test for writeLiteral(Object o)

import pegged.grammar;

import std.typetuple;
import std.stdio;
import std.string;
import std.conv;
import std.algorithm;
import std.traits;

version(Windows)
{
  const string FilePathDelimeter = "\\";
  //Actually: No Idea for Windows
  const string FilePathUp = "..\\";
}

version(Posix)
{
  const string FilePathDelimeter = "/";
  const string FilePathUp = "../";
}

mixin(grammar(`
  Handlebars:
    Token                   <- (HandlebarsToken / Cheese)*
    Cheese                  <- (!Opening  !Closing .)+
    HandlebarsToken         <- BracketToken / CommentToken / PartialToken / BasicToken / HelperToken

    BracketToken            <- IfBracketToken / EachBracketToken / WithBracketToken
    IfBracketToken          <- IfOpenBracket IfBracketBody IfCloseBracket
    EachBracketToken        <- EachOpenBracket BracketBody EachCloseBracket
    WithBracketToken        <- WithOpenBracket BracketBody WithCloseBracket

    HelperToken             <- :Opening HelperExpression :Closing

    BasicToken              <- :Opening BasicTokenExpression :Closing
    PartialToken            <  :Opening :PartialIdentifier PartialExpression :Closing
    CommentToken            <- LongCommentToken
                            /  ShortCommentToken
    ShortCommentToken       <  :Opening ShortCommentIdentifier :(!Closing .)* :Closing
    LongCommentToken        <  :Opening LongCommentIdentifier :(!LongCommentClose .)* :LongCommentClose
    ShortCommentIdentifier  <- "!"
    LongCommentIdentifier   <- "!--"
    LongCommentClose        <- "--" Closing

    IfOpenBracket           <  :Opening :OpeningBracketIdentifier IfIdentifier BracketTokenExpression :Closing
    IfCloseBracket          <- :Opening :ClosingBracketIdentifier IfIdentifier :Closing
    IfIdentifier            <- "if" / "unless"
    IfBracketBody           <- (ElseToken / HandlebarsToken / Cheese)*

    EachOpenBracket         <  :Opening :OpeningBracketIdentifier :EachIdentifier BracketTokenExpression :Closing
    EachCloseBracket        <- :Opening :ClosingBracketIdentifier EachIdentifier :Closing
    EachIdentifier          <- "each"

    WithOpenBracket         <  :Opening :OpeningBracketIdentifier :WithIdentifier BracketTokenExpression :Closing
    WithCloseBracket        <- :Opening :ClosingBracketIdentifier WithIdentifier :Closing
    WithIdentifier          <- "with"

    OpeningBracketToken     <  :Opening :OpeningBracketIdentifier BracketName BracketTokenExpression :Closing
    ClosingBracketToken     <  :Opening :ClosingBracketIdentifier BracketName :Closing
    OpeningBracketIdentifier<- "#"
    ClosingBracketIdentifier<- "/"

    BracketName             <- identifier
    BracketTokenExpression  <- Expression
    BracketBody             <- (HandlebarsToken / Cheese)*
    ElseToken               <- :Opening "else" :Closing

    PartialExpression       <  MemberName MemberName?

    HelperExpression        <  Name Expression

    BasicTokenExpression    <- Expression
    ThisIdentifier          <- "this"

    Expression              <- VariableExpression / ThisIdentifier / MemberName
    VariableExpression      <- IndexExpression / KeyExpression / LastExpression / FirstExpression
    IndexExpression         <- :VariableIdentifier "index"
    KeyExpression           <- :VariableIdentifier "key"
    LastExpression          <- :VariableIdentifier "last"
    FirstExpression         <- :VariableIdentifier "first"
    VariableIdentifier      <- "@"

    MemberName              <- PathedName / Name
    PathedName              <  PathUpName / PathDownName
    PathUpName              <  :PathUp MemberName
    PathDownName            <  Name :NameDelimiter MemberName
    PathUp                  <- "../"
    Name                    <- identifier
    NameDelimiter           <- "/" / "."

    PartialIdentifier       <- ">"

    Opening                 <- TripleOpening / DoubleOpening
    Closing                 <- TripleClosing / DoubleClosing
    DoubleOpening           <- "{{"
    DoubleClosing           <- "}}"
    TripleOpening           <- "{{{"
    TripleClosing           <- "}}}"`));

template Alias(alias a)
{
  static if (__traits(compiles, { alias x = a; }))
    alias Alias = a;
  else static if (__traits(compiles, { enum x = a; }))
    enum Alias = a;
  else
    static assert(0, "Cannot alias " ~ a.stringof);
}
// types and tuples
template Alias(a...)
{
  alias Alias = a;
}

private string writeLiteral(int i)
{
  return to!string(i);
}

private string writeLiteral(string s)
{
  return s;
}

private string writeLiteral(Object o)
{
  return to!string(o);
}

private string appendChildren(int N)
{
  string result = "";
  foreach(i;0..N)
  {
    result ~= "result ~= toHtml!(p.children["~ to!string(i)~"]);";
  }
  return result;
}

private string parseTree(TModel, ParseTree p, string filePath = "hbs/")()
{

  template inner(TCurrentContext, string[] pathStack, int loopDepths, TContextStack ...)
  {
    /*pragma(msg, CurrentContext);
    pragma(msg, path);
    pragma(msg, Args);
    pragma(msg, "____________________________");*/
    string evaluateChildren(ParseTree p)()
    {
      //pragma(msg, p.name~" has "~to!string(p.matches.length)~" matches and "~to!string(p.children.length)~" children.");
      string result = "";
      static if (p.children!=null)
      {
        //pragma(msg, appendChildren(p.children.length));
        mixin(appendChildren(p.children.length));
      }
      return result;
    }

    string evaluateFileName(ParseTree p)()
      if (p.name == "Handlebars.MemberName" ||
          p.name == "Handlebars.PathedName")
    {
      return evaluateFileName!(p.children[0]);
    }

    string evaluateFileName(ParseTree p)()
      if (p.name == "Handlebars.Name")
    {
      return p.matches[0];
    }

    string evaluateFileName(ParseTree p)()
      if (p.name == "Handlebars.PathDownName")
    {
      return evaluateFileName!(p.children[0]) ~ FilePathDelimeter ~ evaluateFileName!(p.children[1]);
    }

    string evaluateFileName(ParseTree p)()
      if (p.name == "Handlebars.PathUpName")
    {
      return FilePathUp ~ evaluateFileName!(p.children[0]);
    }

    template getChildContext(TContext, ParseTree p)
      if (p.name == "Handlebars.MemberName" ||
          p.name == "Handlebars.PathedName" ||
          p.name == "Handlebars.BracketTokenExpression" ||
          p.name == "Handlebars.Expression")
    {
      alias getChildContext = getChildContext!(TContext, p.children[0]);
    }

    template getChildContext(TContext, ParseTree p)
      if (p.name == "Handlebars.Name")
    {
      alias getChildContext = Alias!(__traits(getMember, TContext, p.matches[0]));
    }

    template getChildContext(TContext, ParseTree p)
      if (p.name == "Handlebars.PathDownName")
    {
      alias childType = Alias!(__traits(getMember, TContext, p.matches[0]));
      alias getChildContext = getChildContext!(typeof(childType), p.children[1]);
    }


    string toHtml(ParseTree p)()
      if(p.name == "Handlebars" ||
         p.name == "Handlebars.Token" ||
         p.name == "Handlebars.HandlebarsToken" ||
         p.name == "Handlebars.PartialToken"    ||
         p.name == "Handlebars.MemberName"      ||
         p.name == "Handlebars.PathedName"      ||
         p.name == "Handlebars.BracketBody"     ||
         p.name == "Handlebars.IfBracketToken"  ||
         p.name == "Handlebars.BracketToken"    ||
         p.name == "Handlebars.IfBracketBody"     ||
         p.name == "Handlebars.BracketTokenExpression" ||
         p.name == "Handlebars.BasicTokenExpression"   ||
         p.name == "Handlebars.Expression"  ||
         p.name == "Handlebars.VariableExpression" ||
         p.name == "Handlebars.HelperToken"
        )
    {
      return evaluateChildren!(p);
    }

    string toHtml(ParseTree p)()
      if(p.name == "Handlebars.HelperExpression")
    {//result ~= helper!(typeof(model))(model)
      return "result ~= "~p.children[0].matches[0]~"!(typeof("~toHtml!(p.children[1])~"))("~toHtml!(p.children[1])~");";
    }

    string toHtml(ParseTree p)()
      if (p.name == "Handlebars.PartialExpression")
    {//result ~= renderHbs!("hbsContent", typeof(model))(model);
      enum file = import(filePath~evaluateFileName!(p.children[0])~".hbs");
      static if (p.children.length > 1)
      {
        alias childType = getChildContext!(TCurrentContext, p.children[1]);
        return "  result ~= renderHbs!(\""~file~"\", typeof("~toHtml!(p.children[1])~"))("~toHtml!(p.children[1]) ~");\n";
      } else
      {
        return "  result ~= renderHbs!(\""~file~"\", typeof("~pathStack[0]~"))("~pathStack[0]~");\n";
      }
    }

    string toHtml(ParseTree p)()
      if (p.name == "Handlebars.Cheese")
    {//result ~= `html`
      string result = "  result ~= `";
      foreach(match; p.matches)
        result ~= match.replace("`","\\`");
      return result ~ "`;\n";
    }

    string toHtml(ParseTree p)()
      if (p.name == "Handlebars.BasicToken")
    {//result ~= writeLiteral(model);
      string result = "  result ~= writeLiteral(";
      result ~= toHtml!(p.children[0]);
      result ~= ");\n";
      return result;
    }

    string toHtml(ParseTree p)()
      if (p.name == "Handlebars.ThisIdentifier")
    {
      static assert (pathStack[0]!="","Unkown Context for 'this'");
      return pathStack[0];
    }

    string toHtml(ParseTree p)()
      if (p.name == "Handlebars.PathDownName")
    {
      static assert(__traits(hasMember, TCurrentContext, p.matches[0]), "Type '"~__traits(identifier, TCurrentContext)~"' has no member named '"~ p.matches[0] ~ "'!");

      alias childType = Alias!(__traits(getMember, TCurrentContext, p.matches[0]));
      return (inner!(typeof(childType), (pathStack[0]~"."~p.matches[0]) ~ pathStack, loopDepths, TCurrentContext, TContextStack)).toHtml!(p.children[1]);
    }

    string toHtml(ParseTree p)()
      if (p.name == "Handlebars.PathUpName")
    {
      static assert (TContextStack.length > 0, "Tried to go up ('../') but found an empty type stack");

      return (inner!(TContextStack[0], pathStack[1..$], loopDepths, TContextStack[1..$])).toHtml!(p.children[0]);
    }

    string toHtml(ParseTree p)()
      if (p.name == "Handlebars.Name")
    {// model.MemberName
      static assert(__traits(hasMember, TCurrentContext, p.matches[0]), "Type '"~__traits(identifier, TCurrentContext)~"' has no member named '"~ p.matches[0] ~ "'!");
      static if (pathStack[$-1]=="")
      {
        return p.matches[0];
      }else
      {
        return pathStack[0]~"." ~ p.matches[0];
      }
    }

    string toHtml(ParseTree p)()
      if (p.name == "Handlebars.LastExpression")
    {
      static assert(loopDepths > 0, "Trying to call @last without beeing in a loop");
      return "last"~to!string(loopDepths-1);
    }

    string toHtml(ParseTree p)()
      if (p.name == "Handlebars.FirstExpression")
    {
      static assert(loopDepths > 0, "Trying to call @first without beeing in a loop");
      return "first"~to!string(loopDepths-1);
    }

    string toHtml(ParseTree p)()
      if (p.name == "Handlebars.IndexExpression")
    {
      static assert(loopDepths > 0, "Trying to call @index without beeing in a loop");
      return "index"~to!string(loopDepths-1);
    }

    string toHtml(ParseTree p)()
      if (p.name == "Handlebars.IfOpenBracket")
    {//Simple booleans for now...
      static assert(p.children.length==2,"Unacceptable IfBracket");
      static if (p.matches[0] == "if")
      {
        return "  if ("~toHtml!(p.children[1])~"){\n";
      } else
      {
        return "  if (!"~toHtml!(p.children[1])~"){\n";
      }
    }

    string toHtml(ParseTree p)()
      if (p.name == "Handlebars.EachBracketToken")
    {
      alias childType = getChildContext!(TCurrentContext, p.children[0].children[0]);
      string result = "";
      result ~= "  int index"~to!string(loopDepths)~" = 0;\n";
      result ~= "  bool last"~to!string(loopDepths)~" = false;\n";
      result ~= "  bool first"~to!string(loopDepths)~" = true;\n";

      //EachOpenBracket
      result ~= toHtml!(p.children[0]);
      result ~= "  last"~to!string(loopDepths)~" = index"~to!string(loopDepths)~" == ("~toHtml!(p.children[0].children[0])~".length -1);\n";

      //EachBodyToken
      result ~= inner!(typeof(childType[0]), ("item"~to!string(loopDepths)) ~ pathStack, (loopDepths+1), TCurrentContext, TContextStack).toHtml!(p.children[1]);
      result ~= "  index"~to!string(loopDepths)~"++;\n";
      result ~= "  first"~to!string(loopDepths)~" = false;\n";

      //EachCloseBracket
      result ~= toHtml!(p.children[2]);
      return result;
    }

    string toHtml(ParseTree p)()
      if (p.name == "Handlebars.EachOpenBracket")
    {
      return "  foreach(item"~to!string(loopDepths)~";"~toHtml!(p.children[0])~"){\n";
    }

    string toHtml(ParseTree p)()
      if (p.name == "Handlebars.WithBracketToken")
    {
      alias childType = getChildContext!(TCurrentContext, p.children[0].children[0]);
      string result = "";
      result ~= inner!(typeof(childType), toHtml!(p.children[0].children[0]) ~ pathStack, loopDepths, TCurrentContext, TContextStack).toHtml!(p.children[1]);
      return result;
    }

    string toHtml(ParseTree p)()
      if (p.name == "Handlebars.IfCloseBracket" ||
          p.name == "Handlebars.EachCloseBracket")
    {
      return "  }\n";
    }

    string toHtml(ParseTree p)()
      if (p.name == "Handlebars.ElseToken")
    {
      return "}else{";
    }

  }

  //pragma(msg, (inner!(ModelType,["model"])).toHtml!(p));
  enum fbody = (inner!(TModel,["model"],0)).toHtml!(p);
  return
"string toHtml(Model model)
{
  string result;
" ~ fbody ~"
  return  result; }";
}

string compileHbsFile(string fileName, ModelType, string folder = "hbs/")(ModelType model)
{
  pragma(msg, "Compiling Handlebars: " ~fileName);
  enum file = import(folder~fileName);
  return renderHbs!(file, ModelType, folder)(model);
}

string renderHbs(string file, ModelType, string filePath = "hbs/")(ModelType model)
{
  version(unittest)
  {
    import handlebars.test.helper;
  } else
  {
    import handlebars.helper;
  }
  enum hbsTree = Handlebars(file);
  alias Model = ModelType;
  //pragma(msg, "Compiling Handlebars...");
  //pragma(msg, parseTree!(T, hbsTree, filePath));
  mixin(parseTree!(ModelType, hbsTree, filePath));
  return(toHtml(model));
}

bool testHandlebars(string file, T)(T t, string expected)
{
  enum code = parseTree!(T, Handlebars(file));
  if (renderHbs!(file,T)(t) == expected)
    return true;
  writeln("Failed HBS Test!");
  writeln("-------------------------------------------------");
  writeln("Expected:\n"~expected);
  writeln("-------------------------------------------------");
  writeln("Got:\n"~renderHbs!(file,T)(t));
  writeln("-------------------------------------------------");
  writeln("Generated Code:\n"~code);
  return false;
}

unittest{
  //Simple Test
  struct S{
    string Member1;
    int Member2;
  }

  struct S2{
    bool Really;
    string[] Values;
    string Label;
    string Name;
    int Id;
    S child;
  }
  S2 s2;
  s2.Name = "Hans";
  s2.Label = "Name";
  const string hbs = "{{Name}}{{Label}}";
  assert(renderHbs!(hbs,typeof(s2))(s2)=="HansName");
}

unittest{
  class Test{
    string S1;
    string S2;
  }
  class Parent{
    int i;
    string S3;
    Test t;
  }
  Test t = new Test();
  t.S1 = "Urgh";
  t.S2 = "Argh";
  Parent p = new Parent();
  p.i = 10;
  p.S3 = "AHA";
  p.t = t;
  const string hbs = "{{i}} -> {{S3}} AND {{t.S1}} WIth {{t.S2}}";
  const string hbs2 = "{{S1}} < {{S2}}";
  assert(renderHbs!(hbs,typeof(p))(p)=="10 -> AHA AND Urgh WIth Argh");
  assert(renderHbs!(hbs2,typeof(t))(t)=="Urgh < Argh");
}

unittest{
  struct S{
    string Member1;
    int Member2;
  }

  struct S2{
    bool Really;
    string[] Values;
    string Label;
    string Name;
    int Id;
    S child;
  }
  class UberParent{
    S2 s2;
  }
  UberParent p = new UberParent();
  S2 s2 = { Id:10, Label:"Hans", Name:"PETER", child: {Member1:"It is also important to go to Mars!"}};
  p.s2 = s2;
  const string hbs = "{{s2.child.Member1}}";
  const string hbs2 = "{{s2.child/../Label}}";
  assert(renderHbs!(hbs,typeof(p))(p)=="It is also important to go to Mars!");
  assert(renderHbs!(hbs2,typeof(p))(p)=="Hans");
}

unittest{
  //#if
  struct S{
    string Member1;
    int Member2;
  }

  struct S2{
    bool Really;
    string[] Values;
    string Label;
    string Name;
    int Id;
    S child;
  }

  const S2 s2false = { Really: false, Id:10, Label:"Hans", Name:"PETER", child: {Member1:"It is also important to go to Mars!"}};
  const S2 s2true = { Really: true, Id:10, Label:"Hans", Name:"PETER", child: {Member1:"It is also important to go to Mars!"}};
  const string hbs = "{{#if Really}}REALLYTRUE{{/if}}";
  const string hbs2 = "{{#if Really}}{{Label}}{{child.Member1}}{{/if}}";
  const string hbs3 = "{{#if child/../Really}}Pathed BracketExpression{{/if}}";
  const string hbs4 = "{{#if Really}}REALLYTRUE{{else}}REALLYFALSE{{/if}}";
  const string hbs5 = "{{#unless Really}}REALLYTRUE{{else}}REALLYFALSE{{/unless}}";
  assert(renderHbs!(hbs,typeof(s2true))(s2true)=="REALLYTRUE", "Simple #if: true");
  assert(renderHbs!(hbs,typeof(s2false))(s2false)=="", "Simple #if: false");

  assert(renderHbs!(hbs2,typeof(s2true))(s2true)=="HansIt is also important to go to Mars!", "#if with Children: true");
  assert(renderHbs!(hbs2,typeof(s2false))(s2false)=="", "#if with Children: false");

  assert(renderHbs!(hbs3,typeof(s2true))(s2true)=="Pathed BracketExpression", "Pathed #if: true");
  assert(renderHbs!(hbs3,typeof(s2false))(s2false)=="", "Pathed #if: false");

  assert(renderHbs!(hbs4,typeof(s2true))(s2true)=="REALLYTRUE", "Simple #if-else: true");
  assert(renderHbs!(hbs4,typeof(s2false))(s2false)=="REALLYFALSE", "Simple #if-else: false");

  assert(renderHbs!(hbs5,typeof(s2true))(s2true)=="REALLYFALSE", "Simple #unless-else: true");
  assert(renderHbs!(hbs5,typeof(s2false))(s2false)=="REALLYTRUE", "Simple #unless-else: false");
}

unittest{
  //#each
  struct S{
    string Member1;
    int Member2;
  }

  struct S2{
    bool Really;
    string[] Values;
    string Label;
    string Name;
    int Id;
    S child;
  }

  class EachTest{
    string[] Names;
    string[] Vals;
    S2[] s2s;
  }
  EachTest test = new EachTest();
  test.Names = ["Oans","Zwoa","Gsuffa"];
  test.Vals = ["SingleValue"];

   S2 s1 = { Id:1, Values:["Mercury","Venus","Earth","Mars"], Label:"Hans", Name:"PETER", child: {Member1:"It is also important to go to Mars!"}};
   S2 s2 = { Id:2, Values:["Jupiter","Saturn","Uranus","Neptun"], Label:"Waltraut", Name:"Meier", child: {Member1:"It is also important to go to Titan!"}};
  //s1.Values = ["Mercury","Venus","Earth","Mars"];
  //s2.Values = ["Jupiter","Saturn","Uranus","Neptun"];
  test.s2s ~= s1;
  test.s2s ~= s2;

  const string hbs = "{{#each s2s}}{{Id}}: {{Label}}{{/each}}";
  const string hbs2 = "{{#each Names}}{{this}}{{/each}}";
  const string hbs3 = "{{#each s2s}}{{Id}}:{{#each Values}}{{this}}{{/each}}\n{{/each}}";
  const string hbs4 = "{{#each s2s}}{{Id}}:{{#each Values}}{{../Id}}{{this}}{{/each}}\n{{/each}}";

  const string hbs5 = "{{#each s2s}}{{#if @last}}:LAST:{{else}}:NOTLAST:{{/if}}{{Label}}{{/each}}";
  const string hbs6 = "{{#each Vals}}{{#if @last}}LAST{{else}}NOTLAST{{/if}}{{this}}{{/each}}";

  const string hbs7 = "{{#each Names}}{{@index}}{{this}}{{/each}}";
  const string hbs8 = "{{#each Names}}{{#if @first}}f{{else}}!f{{/if}}{{#if @last}}l{{else}}!l{{/if}}{{@index}}{{this}}{{/each}}";

  const string hbs9 = "{{#each s2s}}{{@index}}{{#each Values}}{{@index}}{{this}}{{/each}}{{/each}}";

  assert(renderHbs!(hbs,typeof(test))(test)=="1: Hans2: Waltraut", "Simple #each over Array of structs");
  assert(renderHbs!(hbs2,typeof(test))(test)=="OansZwoaGsuffa", "Simple #each over Array of strings");
  assert(renderHbs!(hbs3,typeof(test))(test)=="1:MercuryVenusEarthMars\n2:JupiterSaturnUranusNeptun\n", "Nested #each");
  assert(renderHbs!(hbs4,typeof(test))(test)=="1:1Mercury1Venus1Earth1Mars\n2:2Jupiter2Saturn2Uranus2Neptun\n", "Nested #each with context change '../'");

  assert(renderHbs!(hbs5,typeof(test))(test)==":NOTLAST:Hans:LAST:Waltraut", "simple @last test");
  assert(renderHbs!(hbs6,typeof(test))(test)=="LASTSingleValue", "@last test with 1 value");

  assert(renderHbs!(hbs7,typeof(test))(test)=="0Oans1Zwoa2Gsuffa", "simple @index test");
  assert(renderHbs!(hbs8,typeof(test))(test)=="f!l0Oans!f!l1Zwoa!fl2Gsuffa", "@index, @last, @first test");

  assert(testHandlebars!(hbs9, typeof(test))(test, "00Mercury1Venus2Earth3Mars10Jupiter1Saturn2Uranus3Neptun"),"Nested #each with @index");
}

unittest{
  //#with

  struct S{
    string Member1;
    int Member2;
  }

  struct S2{
    bool Really;
    string[] Values;
    string Label;
    string Name;
    int Id;
    S child;
  }

  class UberParent{
    S2 s2;
  }
  UberParent p = new UberParent();
  S2 s2 = { Id:10, Label:"Hans", Name:"PETER", child: {Member1:"It is also important to go to Mars!", Member2: 1336}};
  p.s2 = s2;

  const string hbs = "{{#with s2}}{{Label}},{{Id}}{{/with}}";
  const string hbs2 = "{{#with s2}}{{#with child}}{{../Label}}{{/with}}{{/with}}";

  assert(renderHbs!(hbs,typeof(p))(p)=="Hans,10","Simple #With");
  assert(renderHbs!(hbs2,typeof(p))(p)=="Hans","Nested #With with UpPath");
}

unittest{
  //Partials
  struct S{
    string Member1;
    int Member2;
  }

  struct S2{
    bool Really;
    string[] Values;
    string Label;
    string Name;
    int Id;
    S child;
  }

  class UberParent{
    S2 s2;
  }
  UberParent p = new UberParent();
  S2 s2 = { Id:10, Label:"Hans", Name:"PETER", child: {Member1:"It is also important to go to Mars!", Member2: 1336}};
  S s = {Member1:"It is also important to go to Mars!", Member2: 1338};
  p.s2 = s2;
  const string hbs = "{{> test/SMember1 child}}";
  const string hbs2 = "{{> test/SMember2 s2.child}}";
  const string hbs3 = "{{> test/SMember1}}{{> test/SMember2}}";
  assert(renderHbs!(hbs,typeof(s2))(s2)=="It is also important to go to Mars!", "Simple Partial Call");
  assert(renderHbs!(hbs2,typeof(p))(p)=="1336", "Nested Partial Call");
  assert(testHandlebars!(hbs3, typeof(s))(s, "It is also important to go to Mars!1338"),"Partials in current context");
}


unittest{
  //Helper
  struct S{
    string Member1;
    int Member2;
  }

  S s = {Member1:"It is also important to go to Mars!", Member2: 1338};

  const string hbs = "{{helperTest Member1}},{{helperTest Member2}},{{helperTest this}}";
  assert(testHandlebars!(hbs, typeof(s))(s, "string,int,unkown"), "Basic Helper Test");
}

unittest{
  //escaped '"'
  struct S{
    string easy;
    string hard;
  }

  S s = {easy:"/mars?direct=true", hard:"`Utopia Planitia`"};

  const string hbs = `<a href="{{easy}}">Test</a>`;
  const string hbs2 = "{{hard}}";
  assert(testHandlebars!(hbs, typeof(s))(s, `<a href="/mars?direct=true">Test</a>`), "Basic Escaping Test");
  assert(testHandlebars!(hbs2, typeof(s))(s, "`Utopia Planitia`"), "Basic Escaping Test");
}




































