module handlebars.test.helper;

static string helperTest(T:string)(T t)
{
  return "string";
}

static string helperTest(T:int)(T t)
{
  return "int";
}

static string helperTest(T)(T t)
{
  return "unkown";
}
