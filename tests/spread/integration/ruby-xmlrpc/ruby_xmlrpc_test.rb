#!/usr/bin/env ruby

require 'xmlrpc/server'
require 'xmlrpc/client'
require 'thread'

# Run server in a new thread, otherwise the script blocks
server_thread = Thread.new do
  server = XMLRPC::Server.new(8080, '127.0.0.1')

  server.add_handler("sample.add") do |a, b|
    a + b
  end

  # trap to shutdown server on interrupt
  trap("INT") { server.shutdown }

  server.serve
end

# Give the server a moment to start
sleep 0.5

begin
  client = XMLRPC::Client.new("127.0.0.1", "/", 8080)
  result = client.call("sample.add", 2, 3)
  puts "2+3 - Client got result: #{result}\n"  # should print 5
rescue => e
  puts "Error during test: #{e.class}: #{e.message}"
ensure
  # Shutdown the server thread gracefully
  Thread.kill(server_thread)
  server_thread.join
end
