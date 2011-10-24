require 'stat_request_parser/version'
require 'useragent'

module StatRequestParser

  GLOBAL_KEYS = [:t, :e, :h, :d]

  # Returns MongoDB incs for SiteStat & VideoStat collections
  #
  # { site: { t: 'ovjigy83', inc: {} }, videos: [{ t: 'ovjigy83', vt: 'abcd1234', inc: {} }, {}] }
  #
  def self.stat_incs(params, user_agent, hits = 1)
    incs = { videos: [] }
    if (params.keys & GLOBAL_KEYS) == GLOBAL_KEYS
      case params[:e]
      when 'l'
        bp = browser_and_platform_key(user_agent)

        # Site
        site = { inc: {} }
        # Site token
        site[:t] = params[:t]
        # Site Page Visits
        site[:inc]['pv.' + params[:h]] = hits
        # Browser + Plateform
        site[:inc]['bp.' + bp] = hits
        # Player Mode + Device hash
        params[:pm].uniq.each do |pm|
          site[:inc]['md.' + pm + '.' + params[:d]] = params[:pm].count(pm) * hits
        end
        incs[:site] = site

        # Videos
        params[:vt].each_with_index do |vt, i|
          video = { inc: {} }
          video[:t]  = params[:t]
          video[:vt] = vt
          # Video load
          video[:inc]['vl.' + params[:h]] = hits
          # Browser + Plateform
          video[:inc]['bp.' + bp] = hits
          # Player Mode + Device hash
          video[:inc]['md.' + params[:pm][i] + '.' + params[:d]] = hits
          incs[:videos] << video
        end
      end
    end
    incs
  end

  def self.incs_from_params_and_user_agent(params, user_agent, hits)
    incs   = {}
    params = Addressable::URI.parse(params).query_values || {}
    if params.key?('e') && params.key?('h')
      case params['e']
      when 'l' # Player load &  Video prepare
        unless params.key?('po') # video prepare only
          if params.key?('em') # embed
            # Page Visits embeds
            incs['pv.em'] = hits
          else
            # Page Visits
            incs['pv.' + params['h']] = hits
            # Browser + Plateform
            if %w[m e].include?(params['h'])
              incs['bp.' + browser_and_platform_key(user_agent)] = hits
            end
          end
        end
        # Player Mode + Device hash
        if %w[m e].include?(params['h']) && params.key?('pm') && params.key?('d')
          params['pm'].uniq.each do |pm|
            incs['md.' + pm + '.' + params['d']] = params['pm'].count(pm) * hits
          end
        end
      when 's' # Video start (play)
        # Video Views
        incs['vv.' + params['h']] = hits
      end
    end
    incs
  end

  def self.inc_and_json(params, user_agent)
    inc, json = {}, {}
    case params[:e]
    when 'l' # Player load &  Video prepare
      unless params.key?(:po) # video prepare only
        inc['pv.' + params[:h]] = 1 # Page Visits
        inc['bp.' + browser_and_platform_key(user_agent)] = 1 # Browser + Plateform
        json = { 'pv' => 1, 'bp' => { browser_and_platform_key(user_agent) => 1 } }
      end
      # Player Mode + Device hash
      if params.key?(:pm) && params.key?(:d)
        json['md'] = { 'h' => {}, 'f' => {} }
        params[:pm].uniq.each do |pm|
          inc['md.' + pm + '.' + params[:d]] = params[:pm].count(pm)
          json['md'][pm] = { params[:d] => params[:pm].count(pm) }
        end
      end
    when 's' # Video start (play)
      # Video Views
      inc['vv.' + params[:h]] = 1
      json = { 'vv' => 1 }
    end
    [inc, json]
  end


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

end
