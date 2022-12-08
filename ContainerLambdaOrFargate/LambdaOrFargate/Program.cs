using Amazon.Lambda.RuntimeSupport;
using Amazon.Lambda.Serialization.SystemTextJson;
using Amazon.Runtime.Internal.Auth;
using System.Collections;
using System.Text.Json;
using Amazon.S3.Model;
using Amazon.S3;
using Amazon.Runtime;

string s3Bucket = Environment.GetEnvironmentVariable("OUTPUT_BUCKET");
string fileName = Environment.GetEnvironmentVariable("FILE_NAME");

if (string.IsNullOrEmpty(Environment.GetEnvironmentVariable("AWS_LAMBDA_FUNCTION_NAME")))
{
    Console.Write("Lamdba Function Name Not Found - Running as Container");

    try
    {
        await WriteToS3(s3Bucket, fileName, "Fargate");
    }
    catch (Exception ex)
    {

        Console.WriteLine(ex.Message);
        Console.WriteLine(ex.StackTrace);
    }
    

}
else
{
    using var bootstrap = new LambdaBootstrap(LambdaFunction);
    await bootstrap.RunAsync();
}

async Task<InvocationResponse> LambdaFunction(InvocationRequest invocation)
{
    DefaultLambdaJsonSerializer serializer = new DefaultLambdaJsonSerializer();
    MemoryStream ResponseStream = new MemoryStream();
    Console.WriteLine("In Lambda Function");

    string output;


    invocation.LambdaContext.Logger.LogLine("INVOKING");
    foreach(var env in Environment.GetEnvironmentVariables().Keys)
    {
        invocation.LambdaContext.Logger.LogLine($"Key:{env}, Val:{Environment.GetEnvironmentVariable(env?.ToString())}");
        output = $"Lamdba Executed OK";
    }
    try
    {
        await WriteToS3(s3Bucket, fileName, "Lambda");
    }
    catch(Exception ex)
    {
        Console.WriteLine(ex.Message);
        Console.WriteLine(ex.StackTrace);
        output = $"Error: {ex.Message}";
    }

    ResponseStream.SetLength(0);
    serializer.Serialize("Lambda Complete", ResponseStream);
    ResponseStream.Position = 0;

    
    return new InvocationResponse(ResponseStream, false);
}

 static async Task<string> ToUpperAsync(string str)
{
    return str?.ToUpper();
}


static async Task WriteToS3(string bucketName, string fileNamePrefix, string environment)
{
    string contents = $"This data was written at {DateTime.Now} from {environment}";
    string fileName = $"{fileNamePrefix}{DateTime.Now:yyyyMMddTHHmmss}.txt";


    AmazonS3Client client = new AmazonS3Client();
    var req = new Amazon.S3.Model.PutObjectRequest
    { 
        BucketName = bucketName,
        Key= fileName,    
        ContentBody = contents        
    };

    await client.PutObjectAsync(req);
}



