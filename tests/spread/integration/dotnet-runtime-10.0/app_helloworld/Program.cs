using System.Buffers;
using System.Collections.Concurrent;
using System.Globalization;
using System.IO.Compression;
using System.Net.Security;
using System.Runtime.CompilerServices;
using System.Security.Cryptography;

if (args.Length == 0)
{
    Console.WriteLine("Hello, World!");
    return;
}

foreach (var name in args)
{
    try
    {
        Console.WriteLine($"{name}: ok {Run(name)}");
    }
    catch (Exception e)
    {
        Console.WriteLine($"{name}: FAIL {e.GetType().Name}: {e.Message}");
    }
}

// Each probe sits in its own method, so an assembly the rootfs lacks only
// fails the probe that needs it.
[MethodImpl(MethodImplOptions.NoInlining)]
static string Run(string name) => name switch
{
    "collections" => Collections(),
    "concurrent" => Concurrent(),
    "uri" => UriHost(),
    "memory" => Memory(),
    "crypto" => Crypto(),
    "compression" => Compression(),
    "culture" => Culture(),
    "timezone" => TimeZone(),
    "negotiate" => Negotiate(),
    "wait" => Wait(),
    "crash" => Crash(),
    _ => throw new ArgumentException($"unknown probe {name}"),
};

[MethodImpl(MethodImplOptions.NoInlining)]
static string Collections()
{
    var list = new LinkedList<int>();
    list.AddLast(1);
    list.AddFirst(0);
    return $"{list.Count}";
}

[MethodImpl(MethodImplOptions.NoInlining)]
static string Concurrent()
{
    var dict = new ConcurrentDictionary<string, int>();
    dict["a"] = 1;
    return $"{dict.Count}";
}

[MethodImpl(MethodImplOptions.NoInlining)]
static string UriHost() => new Uri("https://example.com/a?b=c").Host;

[MethodImpl(MethodImplOptions.NoInlining)]
static string Memory()
{
    var writer = new ArrayBufferWriter<byte>();
    writer.Write(new byte[] { 1, 2, 3 });
    return $"{writer.WrittenCount}";
}

[MethodImpl(MethodImplOptions.NoInlining)]
static string Crypto() => Convert.ToHexString(SHA256.HashData("abc"u8));

[MethodImpl(MethodImplOptions.NoInlining)]
static string Compression()
{
    var buffer = new MemoryStream();
    using (var gzip = new GZipStream(buffer, CompressionLevel.Fastest, leaveOpen: true))
    {
        gzip.Write("chisel chisel chisel"u8);
    }
    buffer.Position = 0;
    using var reader = new StreamReader(new GZipStream(buffer, CompressionMode.Decompress));
    return reader.ReadToEnd();
}

[MethodImpl(MethodImplOptions.NoInlining)]
static string Culture() => 1234.5.ToString("N1", new CultureInfo("de-DE"));

[MethodImpl(MethodImplOptions.NoInlining)]
static string TimeZone() => TimeZoneInfo.FindSystemTimeZoneById("Europe/Berlin").Id;

[MethodImpl(MethodImplOptions.NoInlining)]
static string Negotiate()
{
    using var auth = new NegotiateAuthentication(new NegotiateAuthenticationClientOptions
    {
        Package = "Negotiate",
        TargetName = "HTTP/example.invalid",
    });
    auth.GetOutgoingBlob(ReadOnlySpan<byte>.Empty, out var status);
    return $"{status}";
}

[MethodImpl(MethodImplOptions.NoInlining)]
static string Wait()
{
    Console.WriteLine($"pid {Environment.ProcessId}");
    Task.Delay(TimeSpan.FromSeconds(30)).Wait();
    return "done";
}

[MethodImpl(MethodImplOptions.NoInlining)]
static string Crash()
{
    Environment.FailFast("probe crash");
    return "unreachable";
}
