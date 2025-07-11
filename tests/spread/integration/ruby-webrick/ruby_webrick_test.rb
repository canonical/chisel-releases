#!/usr/bin/env ruby

require 'webrick'

puts "✅ WEBrick module is available."

# Start a WEBrick server on a random available port
server = WEBrick::HTTPServer.new(
  Port: 0,               # Let the OS assign a free port
  Logger: WEBrick::Log.new($stderr, WEBrick::Log::FATAL),
  AccessLog: []
)

puts "✅ WEBrick server instantiated on port #{server.config[:Port]}."

# Schedule the server to shut down immediately
Thread.new { server.shutdown }

# Start the server (runs and immediately stops)
server.start

puts "✅ WEBrick server started and stopped cleanly."

