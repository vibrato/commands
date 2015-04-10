require 'sshkit'
require 'sshkit/dsl'
require 'json'
require 'tempfile'
require 'rake'
require 'net/ssh/proxy/command'

SSHKit::Backend::Netssh.configure do |ssh|
  ssh.pty = true
  ssh.ssh_options = {
  	keys: File.join(Dir.pwd, "keys", "arnie-staging.pem"),
    forward_agent: true
  }
end

# output to stderr by default. that means we can we can easily seperate "puts"
# from ssh debugging info.
SSHKit.config.output = $stderr if ENV['STDERR']
SSHKit.config.output_verbosity = :debug if ENV['DEBUG']
SSHKit.config.format = :pretty
