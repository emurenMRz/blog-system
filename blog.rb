#!/usr/local/bin/ruby

require 'erb'
require 'hikidoc'
require 'commonmarker'
require 'sequel'
require_relative './setting'
require_relative './apicgi'
extend APICGI::Delegator

DB = Sequel.postgres DBName, :user => DBUser
DB.extension :pg_json
DB.wrap_json_primitives = true

Articles = DB[:article].where(:visible => true)
Comments = DB[:comment].where(:visible => true)

BasePath = File.join RootPath, '/index.rb'

def all_tags_link
	DB[:tag]
		.order(Sequel.desc(:views), :name)
		.select(:name)
		.all
		.map{|v| %Q!<a href="#{BasePath}/tag/#{v[:name]}"><span class="tag">#{v[:name]}</span></a>!}
		.join(" ");
end

def tag_list(tags); tags.map{|v| %Q!<span class="tag">#{v}</span>!}.join(" "); end
def tag_list_with_link(tags); tags.map{|v| %Q!<a href="#{BasePath}/tag/#{v}"><span class="tag">#{v}</span></a>!}.join(" "); end

def body_to_html(body, format)
	if format == "GFM"
		return CommonMarker.render_html(body, [:DEFAULT, :UNSAFE], [:autolink, :table])
	elsif format == "Wiki"
		return HikiDoc::to_html(body, level: 2, use_wiki_name: false, allow_bracket_inline_image: false).strip
			.gsub(%r!<span class="plugin">\{\{'(.+?)'\}\}</span>!m){CGI.unescapeHTML $1}
			.gsub(%r!<div class="plugin">\{\{'(.+?)'\}\}</div>!m){"<p>#{CGI.unescapeHTML($1)}</p>"}
	end
	return body.split("\n").map{|v| "#{v}<br>"}.join
end

#
# API
#

get '/' do
	# tDiary compatibility
	if params.has_key? :date
		date = params[:date]
		case date.length
		when 6; mode = 'monthly'
		when 8; mode = 'daily'
		else; mode = 'article'
		end
		redirect "#{BasePath}/#{mode}/#{date}"
	elsif params.has_key? :category
		redirect "#{BasePath}/tag/#{params[:category]}"
	end

	@list_of_articles = Articles.order(Sequel.desc(:updated_at)).limit(20).all

	content_type :html
	ERB.new(File.read('template.rhtml')).result
end

get '/newly/update' do
	@list_of_articles = Articles.order(Sequel.desc(:updated_at)).limit(20).all

	content_type :html
	ERB.new(File.read('template.rhtml')).result
end

get '/newly/post' do
	@list_of_articles = Articles.order(Sequel.desc(:created_at), :no).limit(20).all

	content_type :html
	ERB.new(File.read('template.rhtml')).result
end

get '/views' do
	@list_of_articles = Articles.order(Sequel.desc(:views), Sequel.desc(:created_at)).limit(20).all

	content_type :html
	ERB.new(File.read('template.rhtml')).result
end

get '/tag/:name' do
	tag = params[:name]
	name = tag.sub(/'/, %q{''})
	DB[:tag].where(:name => tag).update(:views => Sequel[:views] + 1) unless private_access?
	@list_of_articles = Articles
		.where(Sequel.lit(%Q{tags ?& array['#{name}']}))
		.order(Sequel.desc(:updated_at))
		.all

	content_type :html
	ERB.new(File.read('template.rhtml')).result
end

get '/daily/:date' do
	m = params[:date].match /^(?<year>[0-9]{4})(?<month>[0-9]{2})(?<date>[0-9]{2})/
	halt 400, "Unsupport date format: #{params[:date]}" if m.nil?

	date = "#{m[:year]}-#{m[:month]}-#{m[:date]}"
	@list_of_articles = Articles
		.where(Sequel.lit(%Q!created_at::DATE='#{date}'!))
		.order(:no)
		.all

	content_type :html
	ERB.new(File.read('template.rhtml')).result
end

get '/monthly/:month' do
	m = params[:month].match /^(?<year>[0-9]{4})(?<month>[0-9]{2})/
	halt 400, "Unsupport month format: #{params[:month]}" if m.nil?

	month = "#{m[:year]}-#{m[:month]}-01"
	@list_of_articles = Articles
		.where(Sequel.expr(:created_at) >= Sequel.lit(%Q!DATE_TRUNC('month', '#{month}'::DATE)!))
		.where(Sequel.expr(:created_at) <= Sequel.lit(%Q!DATE_TRUNC('month', '#{month}'::DATE) + '1 months' + '-1 days'!))
		.order(:created_at, :no)
		.all

	content_type :html
	ERB.new(File.read('template.rhtml')).result
end

get '/article/:id' do
	m = params[:id].match /^(?<year>[0-9]{4})(?<month>[0-9]{2})(?<date>[0-9]{2})p(?<parag>[0-9]+)/
	halt 400, "Unsupport id format: #{params[:id]}" if m.nil?

	date = "#{m[:year]}-#{m[:month]}-#{m[:date]}"
	no = m[:parag].to_i

	article = Articles.where(Sequel.lit(%Q!created_at::DATE='#{date}'!)).where(:no => no)
	article.update(:views => Sequel[:views] + 1) unless private_access?
	@article = article.first
		.merge({
			:comments => Comments.where(Sequel.lit(%Q!created_at::DATE='#{date}'!)).order(:created_at).all,
			:referer => nil
		})

	content_type :html
	ERB.new(File.read('template.rhtml')).result
end

run!
