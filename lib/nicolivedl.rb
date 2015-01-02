require "net/http"
require "uri"
require "openssl"
require "rexml/document"

class NicoLiveDownloader
  attr_reader :user_session
  attr_reader :rtmp_url, :ticket, :content_default, :content_premium, :is_premium

  def login(email, password)
    uri = URI.parse("https://secure.nicovideo.jp/secure/login?site=niconico")

    req = Net::HTTP::Post.new(uri.request_uri, initheader = {'Content-Type' =>'application/x-www-form-urlencoded'})
    req.set_form_data({'mail'=> email, 'password'=>password}, '&')

    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    res = http.start {|http| http.request(req) }
    @user_session = res.get_fields("set-cookie").select { |cookie|
      (not (cookie =~ /^user_session=deleted;/)) and (cookie =~ /^user_session=/)
    }.map { |cookie|
      cookie.split("=")[1].split(";")[0]
    }.first
  end

  def getplayerstatus(lvid)
    xmlbody = ""
    Net::HTTP.start("watch.live.nicovideo.jp") { |http|
      res, = http.get "/api/getplayerstatus/#{lvid}", {"Cookie" => "user_session=#{@user_session}"}
      xmlbody = res.body
    }
    xml = REXML::Document.new(xmlbody)
    @rtmp_url = xml.elements["getplayerstatus/rtmp/url"].first
    @ticket = xml.elements["getplayerstatus/rtmp/ticket"].first
    @is_premium = xml.elements["getplayerstatus/user/is_premium"].first.to_s.to_i

    quesheet_xpath = "getplayerstatus/stream/quesheet/que"

    publish_list = {}
    xml.elements.each(quesheet_xpath) { |que|
      if que.text.start_with?("/publish")
        name, path = que.text.split("/publish")[1].split(" ")
        publish_list[name] = path.start_with?("/") ? path[1...path.length] : path
      end
    }

    content_default_name = nil
    content_premium_name = nil
    xml.elements.each(quesheet_xpath) { |que|
      if que.text.start_with?("/play ")
        case_list = que.text.split("/play case:")[1].split(" ")[0].split(",")
        case_list.each { |c|
          if c.start_with?("default:rtmp:")
            content_default_name = c.split(":")[2]
          elsif c.start_with?("premium:rtmp:")
            content_premium_name = c.split(":")[2]
          end
        }
      end
    }
    @content_default = publish_list[content_default_name]
    @content_premium = publish_list[content_premium_name]
  end

  def download(file)
    content = @is_premium === 1 ? @content_premium : @content_default
    rtmpdump_bin = "#{File.dirname(__FILE__)}/../ext/rtmpdump/rtmpdump"
    command = "\"#{rtmpdump_bin}\" -r \"#{@rtmp_url}/mp4:#{content}\" -C S:\"#{@ticket}\" -R -o \"#{file}\""
    `#{command}`
  end
end
