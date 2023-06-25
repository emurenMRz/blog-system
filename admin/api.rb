#!/usr/local/bin/ruby

require 'json'
require 'sequel'
require_relative '../setting'
require_relative '../apicgi'
extend APICGI::Delegator

DB = Sequel.postgres DBName, :user => DBUser, :host => DBHost
DB.extension :pg_json
DB.wrap_json_primitives = true

def one_article(params)
	date = params[:date]
	date = "#{date[0..3]}-#{date[4..5]}-#{date[6..7]}"
	no = params[:no].to_i
	DB[:article].where(Sequel.lit("created_at::DATE=?", date)).where(:no => no)
end

# 
# article
# 

get '/article/:date/:no' do
	content_type :json
	JSON.dump one_article(params).first
end

post '/article' do
	insert_params = {}
	insert_params[:created_at] = params[:created_at] if params.has_key? :created_at
	insert_params[:title] = params[:title] if params.has_key? :title
	insert_params[:visible] = params[:visible] if params.has_key? :visible
	insert_params[:format] = params[:format] if params.has_key? :format
	insert_params[:tags] = params[:tags].to_json if params.has_key? :tags
	insert_params[:body] = params[:body] if params.has_key? :body

	row = DB[:article].where(Sequel.lit("created_at::DATE=?", params[:created_at])).order(Sequel.desc(:no)).first
	no = row.nil? ? 1 : row[:no].to_i + 1
	insert_params[:no] = no

	result = !DB[:article].insert(insert_params).nil?

	content_type :json
	%Q!{"result": #{result}, "no": #{no}}!
rescue => e
	STDERR.puts e.message

	content_type :json
	'{"result": false}'
end

put '/article/:date/:no' do
	udpate_params = {}
	udpate_params[:title] = params[:title] if params.has_key? :title
	udpate_params[:visible] = params[:visible] if params.has_key? :visible
	udpate_params[:format] = params[:format] if params.has_key? :format
	udpate_params[:tags] = params[:tags].to_json if params.has_key? :tags
	udpate_params[:body] = params[:body] if params.has_key? :body

	result = one_article(params).update(udpate_params) != 0

	content_type :json
	%Q!{"result": #{result}}!
rescue => e
	STDERR.puts e.message

	content_type :json
	'{"result": false}'
end

delete '/article/:date/:no' do
	one_article(params).delete

	content_type :json
	'{"result": true}'
rescue => e
	STDERR.puts e.message

	content_type :json
	'{"result": false}'
end

# 
# articles
# 

get '/articles/tag/:tag' do
	name = params[:tag].sub(/'/, %q{''})

	content_type :json
	JSON.dump DB[:article]
		.where(Sequel.lit(%Q{tags ?& array['#{name}']}))
		.order(Sequel.desc(:updated_at))
		.all
end

get '/articles/year' do
	t = DB[:article].select(Sequel.lit(%Q{to_char(created_at, 'yyyy') AS year}))

	content_type :json
	JSON.dump DB[t].group(:year).order(:year).select(:year, Sequel.lit(%Q{count(*)})).all
end

get '/articles/month' do
	t = DB[:article].select(Sequel.lit(%Q{to_char(created_at, 'yyyy-mm') AS month}))

	content_type :json
	JSON.dump DB[t].group(:month).order(:month).select(:month, Sequel.lit(%Q{count(*)})).all
end

get '/articles/views' do
	content_type :json
	JSON.dump DB[:article].where(Sequel.expr(:views) > 0).order(Sequel.desc(:views)).all
end

get '/articles/newly' do
	content_type :json
	JSON.dump DB[:article].order(Sequel.desc(:updated_at)).limit(10).all
end

get '/articles/:date' do
	date = params[:date]
	if date.length == 4
		begin_date = "#{date}-01-01"
		end_date = "#{date}-12-31"
		sql = DB[:article]
			.where(Sequel.expr(:created_at) >= begin_date)
			.where(Sequel.expr(:created_at) <= end_date)
			.order(:created_at, :no)
	elsif date.length == 6
		date = date.insert(4, '-') + "-01"
		sql = DB[:article]
			.where(Sequel.expr(:created_at) >= Sequel.lit("DATE_TRUNC('month', ?::DATE)", date))
			.where(Sequel.expr(:created_at) <= Sequel.lit("DATE_TRUNC('month', ?::DATE) + '1 months' + '-1 days'", date))
			.order(:created_at, :no)
	elsif date.length == 8
		date = "#{date[0..3]}-#{date[4..5]}-#{date[6..7]}"
		sql = DB[:article]
			.where(Sequel.lit("created_at::DATE=?", date))
			.order(:no)
	else
		raise "Unsupport date format: #{date}"
	end

	content_type :json
	JSON.dump sql.select(:no,:title,:visible,:format,:tags,:views,:created_at,:updated_at).all
end

# 
# comment
# 

get '/comment' do
	content_type :json
	JSON.dump DB[:comment].all
end

get '/comment/:id' do
	content_type :json
	JSON.dump DB[:comment].first(:id => params[:id])
end

put '/comment/:id' do
	sql = DB[:comment].where(:id => params[:id])
	new_state = !sql.select(:visible).all[:visible]
	sql.update(:visible => new_state)

	content_type :json
	%Q!{"result": true, "state": #{new_state}}!
rescue => e
	STDERR.puts e.message

	content_type :json
	'{"result": false}'
end

delete '/comment/:id' do
	DB[:comment].where(:id => params[:id]).delete

	content_type :json
	'{"result": true}'
rescue => e
	STDERR.puts e.message

	content_type :json
	'{"result": false}'
end

# 
# tags
# 

get "/tags" do
	content_type :json
	JSON.dump DB[:tag].order(Sequel.desc(:views)).select(:name).all.map{|v| v[:name]}
end

run!
