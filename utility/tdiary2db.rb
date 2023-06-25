#!/usr/local/bin/ruby

require 'json'
require 'sequel'
require 'set'
require_relative '../setting'

#
# main
#

SRC = JSON.parse(File.read('./articles_and_comments.json'), symbolize_names: true)
raise "Unsupport format." unless SRC.has_key?(:articles)

DB = Sequel.postgres DBName, :user => DBUser, :host => DBHost
DB.extension :pg_json
DB.wrap_json_primitives = true

def to_date(date_str)
	m = date_str.match(/([0-9]{4})([0-9]{2})([0-9]{2})/)
	"#{m[1]}-#{m[2]}-#{m[3]}"
end

SRC[:articles].each do |article|
	if article[:title].nil?
		if article[:articles].length == 1
			section = article[:articles][0]
			next if section[:subject].nil?
			DB[:article].insert(
				:no => 1,
				:title => section[:subject],
				:visible => article[:visible],
				:format => article[:format],
				:tags => section[:tag].to_json,
				:body => section[:body],
				:created_at => to_date(article[:date]),
				:updated_at => Time.at(article[:last_modified]),
			)
		else
			article[:articles].each.with_index(1) do |section, index|
				next if section[:subject].nil?
				DB[:article].insert(
					:no => index,
					:title => section[:subject],
					:visible => article[:visible],
					:format => article[:format],
					:tags => section[:tag].to_json,
					:body => section[:body],
					:created_at => to_date(article[:date]),
					:updated_at => Time.at(article[:last_modified]),
				)
			end
		end
	else
		tag = []
		body = ''
		mark = article[:format] == 'Wiki' ? '! ' : '# '
		article[:articles].each do |section|
			tag.concat section[:tag]
			body += "#{mark}#{section[:subject]}\n#{section[:body]}\n"
		end
		DB[:article].insert(
			:no => 1,
			:title => article[:title],
			:visible => article[:visible],
			:format => article[:format],
			:tags => Set.new(tag).to_a.to_json,
			:body => body,
			:created_at => to_date(article[:date]),
			:updated_at => Time.at(article[:last_modified]),
		)
	end
rescue => e
	puts e
	pp article
end

SRC[:comments].each do |comment|
	m = comment[:date].match(/([0-9]{4})([0-9]{2})([0-9]{2})/)
	created_at = "#{m[1]}-#{m[2]}-#{m[3]}"

	DB[:comment].insert(
		:name => comment[:name],
		:mail => comment[:mail],
		:visible => comment[:visible],
		:body => comment[:body],
		:created_at => created_at,
	)
end
