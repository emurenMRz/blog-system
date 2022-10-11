#!/usr/local/bin/ruby

require 'json'

data = JSON.parse(File.read(ARGV[0]))
File.open(ARGV[0], 'w') do |ofile|
	JSON.dump data, ofile
end
