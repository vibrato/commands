require "thor"
require "thor/group"
require "aws-sdk"
require "sshkey"

require "commands/aws"
require "commands/environment"
require "commands/ssh"

module Derp
  # See <http://stackoverflow.com/questions/5663519>
  class Commands < Thor
    class << self
      def subcommand_setup(name, usage, desc)
        namespace :"#{name}"
        @subcommand_usage = usage
        @subcommand_desc = desc
      end
 
      def banner(task, namespace=nil, subcommand=false)
        "#{basename} #{task.formatted_usage(self, true, true)}"
      end
 
      def register_to(klass)
        klass.register(self, @namespace, @subcommand_usage, @subcommand_desc)
      end
    end
  end

  class CLI < Thor
    #require_relative "../hava-api/hava.rb"

    #Hava.register_to(self)
  end
end

Derp::CLI.start
