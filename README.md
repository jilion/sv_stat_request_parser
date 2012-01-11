More info about GIF stats params [here](https://github.com/jilion/sublimevideo.net/wiki/Live-Stats)

Please don't forget to add

``` ruby
gem 'useragent', :git => 'git://github.com/jilion/useragent.git'
```

to your Gemfile when using this gem.

### Deployement to http://gemfury.com/

``` bash
  bundle install
  rake build
  fury push pkg/stat_request_parser-X.Y.Z.gem
```