#!/usr/bin/env ruby

begin
    require 'net/telnet'
    puts "✅ ruby-net-telnet is available."
rescue LoadError => e
    puts "❌ ruby-net-telnet is NOT available: #{e}"
end
  
  
