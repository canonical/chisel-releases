#!/usr/bin/env ruby

require "rbconfig"

puts "== Ruby Smoke Test =="
puts "Ruby version: #{RUBY_VERSION}"
puts "Platform: #{RUBY_PLATFORM}"
puts "Default external encoding: #{Encoding.default_external}"
puts "Executable: #{RbConfig.ruby}"
puts "Current Dir: #{Dir.pwd}"

# === Require standard/core libraries (no RubyGems) ===
begin
  require "fileutils"
  require "tempfile"
  require "socket"
  require "json"
  require "digest"
  require "uri"
  require "net/http"
  require "timeout"
  puts "Libraries loaded successfully"
rescue LoadError => e
  puts "Libraries failed to load: #{e.message}"
  exit 1
end

# === Basic functionality checks ===

# Basic arithmetic & string
raise "Math error" unless 1 + 1 == 2
raise "String mismatch" unless "foo".upcase == "FOO"

# Tempfile check
tf = Tempfile.new("smoke_test")
tf.puts "Hello"
tf.rewind
raise "Tempfile error" unless tf.read.strip == "Hello"
puts "Successfully wrote text into file #{tf.path}"
tf.close
tf.unlink

# Digest check
digest = Digest::SHA256.hexdigest("test")
raise "Digest error" unless digest.size == 64

# URI parsing
uri = URI.parse("https://example.com/path?query=ruby")
raise "URI parse error" unless uri.host == "example.com"

# JSON encoding/decoding
json = JSON.generate({hello: "world"})
data = JSON.parse(json)
raise "JSON error" unless data["hello"] == "world"

# Time formatting
puts "Date: #{Time.now.strftime("%D")}"
raise "Time test failed" unless Time.now.strftime("%Y").to_i > 2023

# Networking
begin
  Timeout.timeout(10) do
    socket = TCPSocket.new("ubuntu.com", 80)
    socket.puts "GET / HTTP/1.0\r\n\r\n"
    response = socket.read
    socket.close
    raise "Socket error" unless response.include?("HTTP")
  end
rescue => e
  puts "Networking test skipped or failed: #{e.class}: #{e.message}"
  exit 1
end

puts "== End of tests =="

