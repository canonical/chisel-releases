using System.Buffers;
using System.Collections.Concurrent;

// reach into System.Collections.Concurrent, System.Memory and System.Private.Uri
new ConcurrentDictionary<string, int>()["a"] = 1;
new ArrayBufferWriter<byte>().Write(new byte[] { 1 });
_ = new Uri("https://example.com/").Host;

Console.WriteLine("Hello, World!");
