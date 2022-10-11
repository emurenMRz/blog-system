require 'uri'
require 'json'
require 'logger'

module APICGI
	class Halt < StandardError
		attr_reader :code, :description

		def initialize(code, description)
			super "#{code} #{description}"
			@code = code
			@description = description
		end
	end

	class Route
		attr_reader :path, :proc

		def initialize(path, proc)
			@path = "#{path.gsub(%r{:([^/]+)}, "(?<\\1>[^/?]+)")}$"
			@proc = proc
		end
	end

	module Delegator
		attr_reader :logger, :params
		attr_writer :logger
		
		@logger = nil
		
		@@mime_type = {
			:text => 'text/plain',
			:html => 'text/html',
			:json => 'application/json',
		}

		@@route = {
			:get => [],
			:post => [],
			:put => [],
			:patch => [],
			:delete => [],
		}

		@@mime = @@mime_type[:text]
		@@charset = 'UTF-8'

		@@response = {
			:'200' => 'OK',
			:'201' => 'CREATED',
			:'204' => 'NO CONTENT',

			:'303' => 'SEE OTHER',

			:'400' => 'BAD REQUEST',
			:'401' => 'UNAUTHORIZED',
			:'404' => 'NOT FOUND',
			:'405' => 'METHOD NOT ALLOWED',
			:'409' => 'CONFLICT',

			:'500' => 'INTERNAL SERVER ERROR',
			:'503' => 'SERVICE UNAVAILABLE',
		}.freeze

		def content_type(mime); @@mime = @@mime_type[mime]; end
		def charset(charset); @@charset = charset; end

		def get(path, &block); @@route[:get].append Route.new(path, block).freeze; end
		def post(path, &block); @@route[:post].append Route.new(path, block).freeze; end
		def put(path, &block); @@route[:put].append Route.new(path, block).freeze; end
		def patch(path, &block); @@route[:patch].append Route.new(path, block).freeze; end
		def delete(path, &block); @@route[:delete].append Route.new(path, block).freeze; end

		def response(body, code: 200, headers: nil)
			puts "Status: #{code} #{@@response[code.to_s.to_sym]}"
			puts "Content-Type: #{@@mime}; charset=#{@@charset}"
			puts "Content-Length: #{body.to_s.bytesize}"
			headers.each {|k, v| puts "#{k}: #{v}"} unless headers.nil?
			puts
			print body.to_s
		end

		def redirect(url, code: 301)
			puts "Status: #{code} #{@@response[code.to_s.to_sym]}"
			puts "Location: #{url}"
			puts
		end

		def halt(code, message = nil)
			message = @@response[code.to_s.to_sym] if message.nil?
			raise Halt.new code, message
		end

		def run!
			@logger = Logger.new(STDERR) if @logger.nil?
			halt 400, '' unless ENV.has_key?('REQUEST_METHOD')

			@params = request_params
			request_method = ENV['REQUEST_METHOD'].downcase.to_sym
			path_info = ENV['PATH_INFO']
			path_info = '/' if path_info.nil?
			path_info = URI.decode_www_form_component(path_info)

			@@route[request_method].each do |route|
				path_info.match(route.path) do |m|
					@params.update m.named_captures
					@params.transform_keys!(&:to_sym)
					response route.proc.call
					return
				end
			end
			halt 404
		rescue Halt => e
			@logger.error e.message
			puts "Status: #{e.message}"
			puts
		rescue => e
			msg = "400 #{e.message.gsub "\n", ''}"
			@logger.error msg
			puts "Status: #{msg}"
			puts
		end

		def remote_addr; ENV['REMOTE_ADDR']; end

		def private_access?;
			addr = remote_addr
			return false if addr.nil?
			return true if addr == '127.0.0.1'
			return true if addr == '::1'
			return true if addr.start_with? '196.168.'
			return true if addr.start_with? '10.'

			# IPv6 'fe80:*/10'
			ipv6 = addr.split(':')
			return ipv6[0].hex >> 6 == 0xfe80 >> 6 if ipv6.length >= 2

			# IPv4 '172.16.*.*/12'
			n = addr.split('.').map.with_index{|v, i| v.to_i << ((3 - i) * 8)}.sum
			return n >> 20 == (172 << 8) + 16
		end

		private

		def request_params
			params = {}

			query_string = ENV['QUERY_STRING']
			params.update URI.decode_www_form(query_string).to_h.transform_keys!(&:to_sym) unless query_string.nil?

			request_body = gets
			unless request_body.nil? || request_body.empty?
				request_body.chomp!
				content_type = ENV['CONTENT_TYPE']
				if content_type == 'application/json'
					params.update JSON.parse request_body, symbolize_names: true
				elsif content_type == 'application/x-www-form-urlencoded'
					params.update URI.decode_www_form(request_body).to_h.transform_keys!(&:to_sym)
				else
					halt 400, "Unsupport Content-Type: #{content_type}"
				end
			end

			params
		end
	end
end
