require 'stat_request_parser/version'
require 'useragent'
require 'active_support/core_ext/object/blank'

module StatRequestParser
  class BadParamsError < RuntimeError; end

  GLOBAL_KEYS = [:t, :e, :h, :d]

  # Returns MongoDB incs for SiteStat & VideoStat collections
  #
  # { site: { t: 'ovjigy83', inc: {} }, videos: [{ st: 'ovjigy83', u: 'abcd1234', inc: {} }, {...}] }
  #
  def self.stat_incs(params, user_agent, hits = 1)
    incs = { site: {}, videos: [] }
    if (params.keys & GLOBAL_KEYS).sort == GLOBAL_KEYS.sort
      # Site
      site = { t: params[:t], inc: {} }
      case params[:e]
      when 'l'
        unless params.key?(:po)
          # Site Page Visits (non-embed)
          site[:inc]['pv.' + params[:h]] = hits unless params.key?(:em)
          # Only for main & extra hostname
          if %w[m e].include?(params[:h])
            if params.key?(:em)
              # Site Page Visits (embed)
              site[:inc]['pv.em'] = hits if params.key?(:em)
            else
              # Browser + Plateform
              bp ||= browser_and_platform_key(user_agent)
              site[:inc]['bp.' + bp] = hits
              # Player Mode + Device hash
              params[:pm].uniq.each do |pm|
                site[:inc]['md.' + pm + '.' + params[:d]] = params[:pm].count(pm) * hits
              end
            end
          end
        end
        incs[:site] = site
        # Videos
        params[:vu].each_with_index do |u, i|
          if u.present?
            video = { st: params[:t], u: u, inc: {} }
            # Video load (non-embed)
            video[:inc]['vl.' + params[:h]] = hits unless params.key?(:em)
            # Only for main & extra hostname
            if %w[m e].include?(params[:h])
              if params.key?(:em)
                # Video load (embed)
                video[:inc]['vl.em'] = hits
              else
                # Browser + Plateform
                bp ||= browser_and_platform_key(user_agent)
                video[:inc]['bp.' + bp] = hits
                # Player Mode + Device hash
                video[:inc]['md.' + params[:pm][i] + '.' + params[:d]] = hits
              end
            end
            incs[:videos] << video
          end
        end
      when 's'
        video = { st: params[:t], u: params[:vu], n: params[:vn], inc: {} }
        unless params.key?(:em)
          # Site Video view
          site[:inc]['vv.' + params[:h]] = hits
          # Video view
          video[:inc]['vv.' + params[:h]] = hits
        end
        if %w[m e].include?(params[:h])
          if params.key?(:em)
            # Site Video view
            site[:inc]['vv.em'] = hits
            # Video view
            video[:inc]['vv.em'] = hits
          else
            # Video source view
            video[:inc]['vs.' + params[:vc]] = hits
          end
        end
        incs[:videos] << video
      end
      incs[:site] = site
    end
    incs
  rescue => error
    raise BadParamsError
  end

  # Convert StatRequestParser incs to json for Pusher
  #
  # { site: { id: ...}, videos: [ { id: ... u: } ]}
  #
  def self.convert_incs_to_json(incs, second)
    json = { site: {}, videos: [] }
    site = incs[:site]
    if site[:inc].present?
      json[:site] = { id: second }
      site[:inc].each do |key, value|
        case key
        when /^pv\./
          json[:site][:pv] = value
        when /^bp\./
          one_level_json_convert!(json[:site], key, value)
        when /^md\./
          double_level_json_convert!(json[:site], key, value)
        when /^vv\./
          json[:site][:vv] = value
        end
      end
    end
    incs[:videos].each do |video|
      if video[:inc].present?
        video_json = { id: second, u: video[:u] }
        video_json[:n] = video[:n] if video.key?(:n)
        video[:inc].each do |key, value|
          case key
          when /^vl\./
            video_json[:vl] = value
          when /^bp\./
            one_level_json_convert!(video_json, key, value)
          when /^md\./
            double_level_json_convert!(video_json, key, value)
          when /^vs\./
            one_level_json_convert!(video_json, key, value)
          when /^vv\./
            video_json[:vv] = value
          end
        end
        json[:videos] << video_json
      end
    end
    json
  end

private

  def self.browser_and_platform_key(user_agent)
    useragent    = UserAgent.parse(user_agent)
    browser_key  = SUPPORTED_BROWSER[useragent.browser] || "oth"
    platform_key = SUPPORTED_PLATEFORM[useragent.platform] || (useragent.mobile? ? "otm" : "otd")
    browser_key + '-' + platform_key
  end

  SUPPORTED_BROWSER = {
    "Firefox"           => "fir",
    "Chrome"            => "chr",
    "Internet Explorer" => "iex",
    "Safari"            => "saf",
    "Android"           => "and",
    "BlackBerry"        => "rim",
    "webOS"             => "weo",
    "Opera"             => "ope"
  }
  SUPPORTED_PLATEFORM = {
    "Windows"       => "win",
    "Macintosh"     => "osx",
    "iPad"          => "ipa",
    "iPhone"        => "iph",
    "iPod"          => "ipo",
    "Linux"         => "lin",
    "Android"       => "and",
    "BlackBerry"    => "rim",
    "webOS"         => "weo",
    "Windows Phone" => "wip"
  }


  def self.one_level_json_convert!(json, key, value)
    keys = key.split('.')
    json[keys[0].to_sym] = { keys[1] => value }
  end

  def self.double_level_json_convert!(json, key, value)
    keys = key.split('.')
    json[keys[0].to_sym] ||= {}
    json[keys[0].to_sym][keys[1]] ||= {}
    json[keys[0].to_sym][keys[1]].merge!(keys[2] => value)
  end

end
