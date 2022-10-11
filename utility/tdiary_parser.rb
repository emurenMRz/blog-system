#!/usr/local/bin/ruby

require 'json'

INIT = 0
HEADERS = 1
BODY = 2

class Diary
	attr_accessor :date, :title, :last_modified, :visible, :format, :articles

	def initialize(headers, articles)
		@date = headers[:Date]
		@title = headers[:Title]
		@last_modified = headers[:'Last-Modified'].to_i
		@visible = headers[:Visible] == 'true'
		@format = headers[:Format]

		@articles = articles
	end

	def to_json
		{
			:date => @date,
			:title => @title,
			:last_modified => @last_modified,
			:visible => @visible,
			:format => @format,
			:articles => @articles.map{|v| v.to_json},
		}
	end
end

class Article
	attr_accessor :subject, :tag, :body

	def initialize
		@subject = nil
		@tag = []
		@body = ''
	end

	def to_json
		{
			:subject => @subject,
			:tag => @tag,
			:body => @body,
		}
	end
end

class Comment
	attr_accessor :date, :name, :mail, :last_modified, :visible, :body
	
	def initialize(headers, body)
		@date = headers[:Date]
		@name = headers[:Name]
		@mail = headers[:Mail]
		@last_modified = headers[:'Last-Modified'].to_i
		@visible = headers[:Visible] == 'true'
		@body = body
	end
	
	def to_json
		{
			:date => @date,
			:name => @name,
			:mail => @mail,
			:last_modified => @last_modified,
			:visible => @visible,
			:body => @body,
		}
	end
end

def body_parser(format, body_lines)
	articles = []
	article = Article.new
	block_nest = []

	subject_format = format == 'Wiki' ? /^! / : format == 'GFM' ? /^# / : nil
	raise "Unsupport format: #{format}" if subject_format.nil?

	body_lines.each do |line|
		cutoff = line.strip
		if block_nest.empty? && subject_format.match?(cutoff)
			unless article.subject.nil?
				article.body.strip!
				articles.append article
				article = Article.new
			end
			m =  /^[!#] (?<tag>(\[.+?\])*)(?<subject>.+)$/.match cutoff
			article.tag = m[:tag].match(/\[(.+)\]/).to_a[1].split("][")
			article.subject = m[:subject]
		else
			if format == 'GFM'
				m = /^(?<block>```+)/.match cutoff
				unless m.nil?
					len = m[:block].length
					last = block_nest.last
					if last.nil? || last != len
						block_nest.append len
					else
						block_nest.pop
					end
				end
			end
			article.body += line
		end
	end

	article.body.strip!
	articles.append article
	
	articles
end

def daily(headers, body_lines)
	return Diary.new headers, body_parser(headers[:Format], body_lines) if headers.has_key? :Format
	return Comment.new headers, body_lines.join if headers.has_key? :Name

	pp headers
	pp body_lines.join
	raise 'Unsupport header format.'
end

def monthly(in_file_name)
	phase = INIT

	version = nil
	headers = {}
	body_lines = []

	data = []

	File.open(in_file_name) do |ifile|
		ifile.each_line do |line|
			case phase
			when INIT
				line.strip!
				raise 'Version is specificated already.' unless version.nil?
				if line == 'TDIARY2.01.00'
					version = line
					phase = HEADERS
				elsif version.nil?
					raise 'Version is not specificated or unsupported.'
				end

			when HEADERS
				line.strip!
				if line.empty?
					phase = BODY
					next
				end

				m = line.match(/^(?<name>.+): (?<value>.*)?$/)
				headers[m[:name].to_sym] = m[:value] unless m.nil?

			else
				if line.strip == '.'
					data.append(daily(headers, body_lines))
					headers.clear
					body_lines.clear
					phase = HEADERS
				else
					body_lines.append line
				end
			end
		end
	end

	data
end

#
# main
#

in_path = ARGV[0]
if File.directory?(in_path)
	puts "Target dir: #{in_path}"
	articles = []
	comments = []
	Dir.glob('**/*.td*', File::FNM_DOTMATCH, base: in_path) do |path|
		ext = File.extname(path)
		next if ext != '.td2' && ext != '.tdc'
		target_file = File.join(in_path, path)
		puts "...Next file: #{target_file}"
		if ext == '.td2'
			articles.concat monthly(target_file)
		else
			comments.concat monthly(target_file)
		end
	end
	out_path = "articles_and_comments.json"
	out_data = {
		:articles => articles.map{|v| v.to_json},
		:comments => comments.map{|v| v.to_json},
	}
else
	puts "Target file: #{in_path}"
	ext = File.extname(in_path)
	raise 'Unsupport file type.' if ext != '.td2' && ext != '.tdc'

	articles.concat monthly(in_path)

	out_path = (ext == '.td2' ? "articles" : "comments") + ".json"
	out_data = articles.map{|v| v.to_json}
end

File.open(out_path, 'w') do |ofile|
	JSON.dump out_data, ofile
end
