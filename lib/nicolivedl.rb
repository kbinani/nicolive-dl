require "net/http"
require "uri"
require "openssl"
require "rexml/document"
require "fileutils"

class NicoLiveDownloader
  attr_reader :user_session
  attr_reader :rtmp_url, :ticket, :content_default, :content_premium, :is_premium, :title, :offset_seconds

  def login(email, password)
    uri = URI.parse("https://secure.nicovideo.jp/secure/login?site=niconico")

    header = {"Content-Type" => "application/x-www-form-urlencoded"}
    req = Net::HTTP::Post.new(uri.request_uri, initheader = header)
    req.set_form_data({"mail" => email, "password" => password}, "&")

    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    res = http.start {|http| http.request(req) }
    @user_session = res.get_fields("set-cookie").select { |cookie|
      (not cookie.start_with?("user_session=deleted;")) and (cookie.start_with?("user_session="))
    }.map { |cookie|
      cookie.split("=")[1].split(";")[0]
    }.first

    unless @user_session.nil?
      cache_file = session_cache_file(email)
      print "Save login session to \"#{cache_file}\"? (Y/N):"
      answer = gets(1)
      if answer.downcase == "y"
        FileUtils.mkdir_p(File.dirname(cache_file))
        open(cache_file, "w") { |file|
          file.write(@user_session)
        }
      end
    end
  end

  def query_watchingreservation(lvid)
    token = get_watchingreservation_token(lvid)
    sleep(1)

    uri = URI.parse("http://live.nicovideo.jp/api/watchingreservation")
    header = {
      "Content-Type"        => "application/x-www-form-urlencoded; charset=UTF-8",
      "Cookie"              => "user_session=#{@user_session}",
      "Referer"             => "http://live.nicovideo.jp/watch/#{lvid}?ref=top&zroute=index",
      "User-Agent"          => "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_9_5) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/39.0.2171.95 Safari/537.36",
      "Origin"              => "http://live.nicovideo.jp",
      "Accept"              => "text/javascript, text/html, application/xml, text/xml, */*",
      "X-Requested-With"    => "XMLHttpRequest",
      "Host"                => "live.nicovideo.jp",
      "X-Prototype-Version" => "1.6.0.3",
    }
    vid = lvid
    if lvid.start_with?("lv")
      vid = lvid[2...lvid.length]
    end
    req = Net::HTTP::Post.new(uri.request_uri, initheader = header)
    data = {
      "mode" => "auto_register",
      "vid" => vid,
      "token" => token,
      "_" => "",
    }
    req.set_form_data(data, "&")

    http = Net::HTTP.new(uri.host, uri.port)
    res = http.start { |http| http.request(req) }
  end

  def get_watchingreservation_token(lvid)
    header = {
      "Cookie" => "user_session=#{@user_session}",
    }
    id = lvid
    if lvid.start_with?("lv")
      id = lvid[2...lvid.length]
    end
    host = "live.nicovideo.jp"
    path = "/api/watchingreservation?mode=watch_num&vid=#{id}&next_url=watch/#{lvid}?ref=top&zroute=index&analytic"

    result = ""
    Net::HTTP.start(host) { |http|
      res, = http.get(path, header)
      result = res.body
    }
    result = result.gsub("\n", "").gsub("\r", "")
    if result =~ /Nicolive\.TimeshiftActions\.confirmToWatch\((.*)\)/
      $1.split(",")[1].gsub("'", "").gsub(" ", "")
    else
      nil
    end
  end

  def query_watchingreservation_(lvid)
    header = {
      "Cookie" => "user_session=#{@user_session}",
      "Referer" => "http://live.nicovideo.jp/my",
    }
    id = lvid
    if lvid.start_with?("lv")
      id = lvid[2...lvid.length]
    end
    host = "live.nicovideo.jp"
    path = "/api/watchingreservation?mode=confirm_watch_my&vid=#{id}&next_url&analytic"

    Net::HTTP.start(host) { |http|
      res, = http.get(path, header)
    }

    header = {
      "Cookie" => "user_session=#{@user_session}",
      "Referer" => "http://#{host}#{path}",
    }
    Net::HTTP.start(host) { |http|
      res, = http.get("/watch/#{lvid}", header)
    }
  end

  def getplayerstatus(lvid)
    begin
      cookie = {"Cookie" => "user_session=#{@user_session}"}

      query_watchingreservation(lvid)

      xmlbody = ""
      Net::HTTP.start("watch.live.nicovideo.jp") { |http|
        res, = http.get "/api/getplayerstatus/#{lvid}", cookie
        xmlbody = res.body
      }

      xml = REXML::Document.new(xmlbody)
      @rtmp_url = xml.elements["getplayerstatus/rtmp/url"].first
      @ticket = xml.elements["getplayerstatus/rtmp/ticket"].first
      @is_premium = xml.elements["getplayerstatus/user/is_premium"].text.to_i
      @start_time = xml.elements["getplayerstatus/stream/start_time"].text.to_i
      @base_time = xml.elements["getplayerstatus/stream/base_time"].text.to_i

      quesheet_xpath = "getplayerstatus/stream/quesheet/que"

      publish_list = {}
      xml.elements.each(quesheet_xpath) { |que|
        if que.text.start_with?("/publish")
          vpos = que.attributes.get_attribute("vpos").to_s.to_i
          @offset_seconds = @start_time - @base_time - vpos / 100
          name, path = que.text.split("/publish")[1].split(" ")
          publish_list[name] = path.start_with?("/") ? path[1...path.length] : path
        end
      }

      content_default_name = nil
      content_premium_name = nil
      xml.elements.each(quesheet_xpath) { |que|
        if que.text.start_with?("/play case:")
          case_list = que.text.split("/play case:")[1].split(" ")[0].split(",")
          case_list.each { |c|
            if c.start_with?("default:rtmp:")
              content_default_name = c.split(":")[2]
            elsif c.start_with?("premium:rtmp:")
              content_premium_name = c.split(":")[2]
            end
          }
        elsif que.text.start_with?("/play rtmp:")
          content_name = que.text.split("/play ")[1].split(" ")[0].split(":")[1]
          content_premium_name = content_name
          content_default_name = content_name
        end
      }
      @content_default = publish_list[content_default_name]
      @content_premium = publish_list[content_premium_name]

      @title = xml.elements["getplayerstatus/stream/title"].first

      return true
    rescue => e
      p e
    end

    return false
  end

  def download(file)
    if file.nil?
      file = "#{@title}.flv"
    end
    content = @is_premium === 1 ? @content_premium : @content_default
    rtmpdump_bin = "#{File.dirname(__FILE__)}/../ext/rtmpdump/rtmpdump"
    command = "\"#{rtmpdump_bin}\" -r \"#{@rtmp_url}/mp4:#{content}\" -C S:\"#{@ticket}\" -R -o \"#{file}\""
    `#{command}`
  end

  def login_with_stored_session(email)
    cache_file = session_cache_file(email)

    cache_dir = File.dirname(cache_file)
    if File.exists?(cache_file)
      @user_session = open(cache_file, "r").read
      return true
    else
      return false
    end
  end

  def session_cache_file(email)
    homedir = ENV["HOME"]
    cache_dir = File.join(homedir, ".nicolive-dl", email)
    File.join(cache_dir, "session_cache")
  end
end
