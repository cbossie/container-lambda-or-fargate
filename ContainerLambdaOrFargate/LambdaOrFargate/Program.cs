using Amazon.Lambda.RuntimeSupport;
using Amazon.Lambda.Serialization.SystemTextJson;
using System.Collections;
using System.Text.Json;


if (string.IsNullOrEmpty(Environment.GetEnvironmentVariable("AWS_LAMBDA_FUNCTION_NAME")))
{
    var data = args.Length == 0 ? "Lamdba Function Name Not Found - Running as Container" : await ToUpperAsync(args[0]);


    Console.WriteLine($"ToUpper of args[0] = {data}");
}
else
{
    using var bootstrap = new LambdaBootstrap(LambdaFunction);
    await bootstrap.RunAsync();
}

static async Task<InvocationResponse> LambdaFunction(InvocationRequest invocation)
{
    DefaultLambdaJsonSerializer serializer = new DefaultLambdaJsonSerializer();
    MemoryStream ResponseStream = new MemoryStream();
    Console.WriteLine("IN LAMBDA!!");


    var input = JsonSerializer.Deserialize<string>(invocation.InputStream);
    invocation.LambdaContext.Logger.LogLine("INVOKING");
    foreach(var env in Environment.GetEnvironmentVariables().Keys)
    {
        invocation.LambdaContext.Logger.LogLine($"Key:{env}, Val:{Environment.GetEnvironmentVariable(env?.ToString())}");

    }

    ResponseStream.SetLength(0);

    serializer.Serialize(input.ToUpper(), ResponseStream);
    ResponseStream.Position = 0;

    
    return new InvocationResponse(ResponseStream, false);
}

 static async Task<string> ToUpperAsync(string str)
{
    return str?.ToUpper();
}