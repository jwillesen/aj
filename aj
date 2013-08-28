#!/usr/bin/env ruby

require 'json'
require 'yaml'
require 'net/http'
#require 'faraday'
require 'hashie/mash'
require 'optparse'

ALLOWED_HTTP_METHODS = ['get', 'put', 'post', 'delete']

config_file_path = File.join(ENV['HOME'], ".ajconfig")
default_config = Hashie::Mash.new({
  port: 80,
  api_prefix: "/api/v1",
  http_method: "get",
  args: {},
  headers: {},
})

if File.exists?(config_file_path)
  $config = Hashie::Mash.new(YAML.load_file(config_file_path))
  $config = default_config.merge($config)
end

def set_config(sym)
  lambda { |v| $config.send("#{sym}=", v) }
end

def require_configs(*syms)
  missing_options = syms.reduce([]) do |result, sym|
    unless $config[sym]
      result << "--#{sym.to_s.gsub(/_/, '-')}"
    end
    result
  end
  raise "Missing options: #{missing_options.join(', ')}" unless missing_options.empty?
end

def parse_key_value_config(str)
  result = str.split('=')
  raise %{unable to parse #{str}} unless result.size == 2
  result
end

def read_body(filename)
  case filename
  when "-"
    $stdin.read
  else
    File.read(filename)
  end
end

opts = OptionParser.new do |opts|
  opts.on("-?", "--help") { puts opts; exit 1 }
  opts.on("--dump-config", "Dump resulting configuration and exit", &set_config(:dump_config))

  opts.on("-h", "--host HOST", "The host to connect to", &set_config(:host))
  opts.on("-p", "--port PORT", "The port to connect to", &set_config(:port))
  opts.on("--api-prefix PREFIX", "The API prefix (defaults to #{$config.api_prefix})", &set_config(:api_prefix))
  opts.on("-l", "--location LOC", "The api path to access (after the prefix)", &set_config(:location))
  opts.on("-u", "--user USER", "The user token to use. User's access token must be in .ajconfig", &set_config(:user))
  opts.on("-t", "--token TOKEN", "Specify the access token explicityly", &set_config(:token))
  opts.on("-m", "--http-method METHOD", "Specify the HTTP method (get (default), post, update, delete)", &set_config(:http_method))
  opts.on("--raw", "View the raw response instead of trying to parse it as JSON", &set_config(:raw))

  opts.on("-a", "--arg ASSIGNMENT", "Specify an argument to include in the url: --arg key=value. " + 
      "The same argument may be specified multiple times. All specified values will be sent.") do |v|
    key, value = parse_key_value_config(v)
    existing_value = $config.args[key]
    if existing_value
      $config.args[key] = Array(existing_value) << value
    else
      $config.args[key] = value
    end
  end

  opts.on("-H", "--header", "Specify a header to include in the request: --header key=value.") do |v|
    key, value = parse_key_value_config(v)
    $config.headers[key] = value
  end

  opts.on("-f", "--file-args FILE", "YAML format file to load command line arguments from.") do |v|
    file_config = Hashie::Mash.new(YAML.load_file(v))
    file_args = file_config.delete(:args) || {}
    config_args = $config.delete(:args) || {}
    merged_args = config_args.merge(file_args) do |key, old_val, new_val|
      Array(old_val) + Array(new_val)
    end

    $config.merge!(file_config)
    $config.args = merged_args
  end

  opts.on("-b", "--body FILE", "Specify the body of the request. " +
    "Reads the specified file. If the value is -, reads the body from stdin.") do |v|
    $config.body = v # gets read later
  end

end

begin
  opts.parse!

  if $config.dump_config
    puts YAML.dump($config.to_hash)
    exit 0
  end

  if $config.user && !$config.token
    saved_token = $config.tokens.send($config.user)
    raise "Unrecognized user: #{$config.user}" unless saved_token
    $config.token = saved_token
  end

  require_configs(:host, :port, :api_prefix, :location, :token, :http_method)

  $config.http_method.downcase!
  unless ALLOWED_HTTP_METHODS.include?($config.http_method)
    raise "Unrecognized method: #{$config.http_method}"
  end

  $config.body = read_body($config.body) if $config.body

rescue => e
  puts e.message
  puts e.backtrace
  exit 1
end

Net::HTTP.start($config.host, $config.port) do |http|
  url_path = "#{$config.api_prefix}/#{$config.location}"
  url_args = URI.encode_www_form($config.args)
  url_path = "#{url_path}?#{url_args}" unless url_args.empty?

  request = case $config.http_method
  when "get"
    Net::HTTP::Get
  when "post"
    Net::HTTP::Post
  when "put"
    Net::HTTP::Put
  when "delete"
    Net::HTTP::Delete
  end.new url_path

  request["Authorization"] = "Bearer #{$config.token}"
  $config.headers.each do |key, value|
    request[key] = value
  end
  #request.body = JSON.generate($config.body) if $config.body
  request.body = $config.body if $config.body
  puts "#{$config.http_method} #{request.path}"
  #puts JSON.pretty_generate($config.body) if $config.body
  puts $config.body if $config.body
  response = http.request request

  if $config.raw
    puts response.body
  else
    result_data = JSON.parse(response.body)
    puts JSON.pretty_generate(result_data)
  end
end
