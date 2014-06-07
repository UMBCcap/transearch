# encoding: utf-8

require 'rubygems'
require 'sinatra'
require 'sinatra/config_file'
require 'json'
require 'net/http'

config_file './config/settings.yml.erb'

$BING_TOKEN_URL = URI.parse("https://datamarket.accesscontrol.windows.net/v2/OAuth2-13")
$TOKEN_EXPIRE = 599

helpers do
	def generate_url(l_term, r_term)
		l = "http://www.bing.com/search?q=#{l_term}"
		r = "http://www.baidu.com/s?wd=#{r_term}"
		{'left' => l, 'right' => r}
	end

	def get_bing_token
		if !$access_token.nil? && !$token_created_at.nil? && Time.now.to_i - $token_created_at < $TOKEN_EXPIRE
			return $access_token
		else
			puts "===== #{settings.class} #{settings.inspect}"
			
			
			client_id = settings.bing_client_id
			client_secret = settings.bing_client_secret
			res = Net::HTTP.post_form($BING_TOKEN_URL, {
				'grant_type' => 'client_credentials',
				'client_id' => client_id,
				'client_secret' => client_secret,
				'scope'=>'http://api.microsofttranslator.com'
			})

			if res.code == '200'
				res = JSON.parse(res.body)
				$access_token = res['access_token']
				$token_created_at = Time.now.to_i
			else
				logger.error "Failed to get bing token. client_id: #{client_id}, client_secret: #{client_secret}, code: #{res.code} body: #{res.body.inspect}"
			end

			return $access_token
		end
	end

	def detect_language(term)
		token = get_bing_token
		r_url = URI.parse("http://api.microsofttranslator.com/v2/Http.svc/Detect?text=#{URI.encode(term)}")
		req = Net::HTTP::Get.new(r_url)
		req["Authorization"] = "Bearer " + token
		res = Net::HTTP.start(r_url.hostname, r_url.port) {|http|
			http.request(req)
		}
		if res.code == '200'
			return res.body.match(/>(.+)</)[1]
		else
			# failed
			logger.error "Failed to request detect language. code: #{res.code} body: #{res.body.inspect}"
			return nil
		end
	end

	def translate(term, from, to)
		# URI.encode
		token = get_bing_token
		r_url = URI.parse("http://api.microsofttranslator.com/V2/Http.svc/Translate?from=#{from}&to=#{to}&contentType=text/plain&text=#{URI.encode(term)}")
		req = Net::HTTP::Get.new(r_url)
		req["Authorization"] = "Bearer " + token
		res = Net::HTTP.start(r_url.hostname, r_url.port) {|http|
			http.request(req)
		}
		if res.code == '200'
			return res.body.force_encoding("utf-8").match(/>(.+)</)[1]
		else
			# failed
			logger.error "Failed to request translate. code: #{res.code} body: #{res.body.inspect}"
			return term
		end
	end
end

get '/' do
  erb :index, locals: {active_nav: {'home'=>'active'}}
end

get '/about' do
  erb :about, locals: {active_nav: {'about'=>'active'}}
end

post '/translate' do
	content_type :json
	if params[:term] && !params[:term].empty?
		lang = detect_language(params[:term])
		if lang
			if lang != 'en'
				trans_term = translate(params[:term], lang, 'en')
				generate_url(trans_term, params[:term]).to_json
			else
				trans_term = translate(params[:term], lang, 'zh-CHS')
				generate_url(params[:term], trans_term).to_json
			end
		else # failed in language detection
			generate_url(params[:term], params[:term]).to_json
		end
	else
		status 404
	end
end
