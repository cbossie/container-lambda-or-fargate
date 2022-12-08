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

// Check for the AWS_LAMBDA_FUNCTION_NAME environment variable. If it is not there, then
// we will run as usual in a container. Otherwise, we will run as if in lambda
if (string.IsNullOrEmpty(Environment.GetEnvironmentVariable("AWS_LAMBDA_FUNCTION_NAME")))
{
    Console.Write("Lamdba Function Name Not Found - Running as Container");

    try
    {
        string contents = args.Length > 0 ? args[0] : "No container args supplied";

        await WriteToS3(s3Bucket, fileName, "Fargate", contents);
    }
    catch (Exception ex)
    {
        Console.WriteLine(ex.Message);
        Console.WriteLine(ex.StackTrace);
    }
}
else
{
    // Not in container - bootstrap the Lambda Runtime
    using var bootstrap = new LambdaBootstrap(LambdaFunction);
    await bootstrap.RunAsync();
}

// The official lambda handler.
async Task<InvocationResponse> LambdaFunction(InvocationRequest invocation)
{
    DefaultLambdaJsonSerializer serializer = new DefaultLambdaJsonSerializer();
    MemoryStream ResponseStream = new MemoryStream();
    Console.WriteLine("In Lambda Function");

    //Get the data as invocation data
    string input;
    try
    {
        input = JsonSerializer.Deserialize<string>(invocation.InputStream);
    }
    catch (Exception ex)
    {
        Console.Write("Unable to parse input to lambda - using default value");
        input = "No Lambda args supplied";
    }

    invocation.LambdaContext.Logger.LogLine("INVOKING");
    try
    {
        await WriteToS3(s3Bucket, fileName, "Lambda", input);
    }
    catch(Exception ex)
    {
        Console.WriteLine(ex.Message);
        Console.WriteLine(ex.StackTrace);
    }

    ResponseStream.SetLength(0);
    serializer.Serialize("Lambda Complete", ResponseStream);
    ResponseStream.Position = 0;    
    return new InvocationResponse(ResponseStream, false);
}

// Simple function that writes a string to S3. You can see that in the bucket, there will be 
// files starting with CONTAINER_ and files starting with LAMBDA_, so one container will put data
// from different runtimes
static async Task WriteToS3(string bucketName, string fileNamePrefix, string environment, string contents = "No contents")
{
    contents = contents ?? $"This data was written at {DateTime.Now} from {environment}";
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



