#!/usr/local/bin/ruby

require 'date'
require 'erb'
require 'hikidoc'
require 'commonmarker'
require_relative '../apicgi'
extend APICGI::Delegator

def tag_list(tags); tags.map{|v| %Q!<span class="tag">#{v}</span>!}.join(" "); end

def body_to_html(body, format)
	return '' if body.nil?
	if format == "GFM"
		return CommonMarker.render_html(body, [:DEFAULT, :UNSAFE], [:autolink, :table])
	elsif format == "Wiki"
		return HikiDoc::to_html(body, level: 2, use_wiki_name: false, allow_bracket_inline_image: false).strip
			.gsub(%r!<span class="plugin">\{\{'(.+?)'\}\}</span>!m){CGI.unescapeHTML $1}
			.gsub(%r!<div class="plugin">\{\{'(.+?)'\}\}</div>!m){"<p>#{CGI.unescapeHTML($1)}</p>"}
	end
	return body.split("\n").map{|v| "#{v}<br>"}.join
end

post '/' do
	created_at = params.has_key?(:created_at) ? Date.parse(params[:created_at]) : Date.today

	@article = {
		:title => params[:title],
		:format => params[:format],
		:tags => params[:tags],
		:body => params[:body],
		:created_at => created_at,
		:updated_at => Date.today,
	}

	content_type :html
	ERB.new(DATA.read).result
end

run!

__END__
<div class="section">
	<header class="section-header">
		<div class="title"><%= @article[:title] %></div>
		<div class="section-metadata">
			<span class="timestamp created_at"><%= @article[:created_at].strftime("%Y-%m-%d") %></span>
			<span class="timestamp updated_at"><%= @article[:updated_at].strftime("%Y-%m-%d %H:%M:%S") %></span>
			<span class="tags"><%= tag_list @article[:tags] %></span>
		</div>
	</header>
	<div class="section-body"><%= body_to_html @article[:body], @article[:format] %></div>
</div>
