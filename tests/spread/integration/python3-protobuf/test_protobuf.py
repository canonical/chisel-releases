import json

from google.protobuf import __version__ as pb_version
from google.protobuf import json_format, proto_builder, text_format
from google.protobuf.internal import api_implementation
from google.protobuf import descriptor_pb2, duration_pb2, struct_pb2, timestamp_pb2

print("version", pb_version)
print("implementation", api_implementation.Type())

# --- well-known types: build, serialise, parse back -----------------------
ts = timestamp_pb2.Timestamp()
ts.FromJsonString("2026-04-23T17:07:15Z")
wire = ts.SerializeToString()
again = timestamp_pb2.Timestamp()
again.ParseFromString(wire)
assert again == ts, (again, ts)
assert again.ToJsonString() == "2026-04-23T17:07:15Z", again.ToJsonString()
print("timestamp seconds", again.seconds)

d = duration_pb2.Duration()
d.FromSeconds(90)
assert d.ToJsonString() == "90s", d.ToJsonString()

# --- Struct + json_format round trip -------------------------------------
s = struct_pb2.Struct()
s.update({"name": "chisel", "count": 3, "ok": True, "items": [1, 2]})
as_json = json.loads(json_format.MessageToJson(s))
assert as_json == {"name": "chisel", "count": 3, "ok": True, "items": [1, 2]}, as_json
back = json_format.Parse(json.dumps(as_json), struct_pb2.Struct())
assert back == s

# --- text_format round trip ----------------------------------------------
text = text_format.MessageToString(ts)
assert "seconds:" in text, text
parsed = text_format.Parse(text, timestamp_pb2.Timestamp())
assert parsed == ts

# --- runtime message construction (no protoc, no .proto file) ------------
Cls = proto_builder.MakeSimpleProtoClass(
    {"host": descriptor_pb2.FieldDescriptorProto.TYPE_STRING,
     "port": descriptor_pb2.FieldDescriptorProto.TYPE_INT32},
    full_name="chisel.Endpoint",
)
msg = Cls(host="example.invalid", port=8080)
rt = Cls()
rt.ParseFromString(msg.SerializeToString())
assert rt.host == "example.invalid" and rt.port == 8080, rt
print("built message", rt.host, rt.port)

# --- descriptors -----------------------------------------------------------
fields = [f.name for f in timestamp_pb2.Timestamp.DESCRIPTOR.fields]
assert fields == ["seconds", "nanos"], fields

fdp = descriptor_pb2.FileDescriptorProto()
fdp.name = "chisel.proto"
fdp.package = "chisel"
m = fdp.message_type.add()
m.name = "Thing"
f = m.field.add()
f.name = "label"
f.number = 1
f.type = descriptor_pb2.FieldDescriptorProto.TYPE_STRING
f.label = descriptor_pb2.FieldDescriptorProto.LABEL_OPTIONAL
rt = descriptor_pb2.FileDescriptorProto()
rt.ParseFromString(fdp.SerializeToString())
assert rt.message_type[0].field[0].name == "label", rt

# --- unknown field preservation -------------------------------------------
raw = Cls(host="a", port=1).SerializeToString()
other = timestamp_pb2.Timestamp()
other.ParseFromString(raw)
assert len(other.SerializeToString()) == len(raw), "unknown fields not preserved"

print("ALL-PROTOBUF-CHECKS-PASSED")
