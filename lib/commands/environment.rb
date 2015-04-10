require "commands/aws"

class Environment
  attr_reader :name, :key, :app

  def initialize(application_name, environment_name)
    @app  = application_name
    @name = environment_name
    key_name = "#{app}-#{name}"

    # pull in the app-specific DNA customisers
    #require_relative File.join(app_dir, "dna_customise")

    # if !dev?
    #   key_file = File.expand_path("../../hava/keys/#{key_name}.pem", __FILE__)
    #   key_file_exists = File.exist?(key_file)

    #   if keypair_exists?
    #     if key_file_exists
    #       @key = key_file
    #     else
    #       raise Exception.new("Environment's keypair already exists, please add environments key to keys/ directory") unless key_file_exists
    #     end
    #   else
    #     if key_file_exists
    #       puts "uploading key to aws"
    #       keyz = load_key(key_name)
    #       puts "derploaded: #{keyz}"
    #       puts key_name
    #     else
    #       puts "creating key yo"
    #       keyz = create_key(key_name)
    #       puts "derp: #{keyz}"
    #     end
    #     $ec2.import_key_pair(key_name: key_name, public_key_material: keyz)
    #     @key = key_file
    #   end

    #   puts key
    # end

    puts "keypath: #{File.join(Dir.pwd, "keys", "#{key_name}.pem")}"

    # Make connections
    SSHKit::Backend::Netssh.configure do |ssh|
      ssh.pty = true
      ssh.ssh_options = {
        keys: File.join(Dir.pwd, "keys", "#{key_name}.pem"),
        forward_agent: true,
        #proxy: Net::SSH::Proxy::Command.new("ssh NATIP -W %h:%p -oStrictHostKeyChecking=no"),
        user_known_hosts_file: "/dev/null"
      }
    end
    SSHKit.config.output_verbosity= Logger::DEBUG
  end

  def dev?
    name == "dev"
  end

  def keypair_exists?
    begin
      $ec2.describe_key_pairs(key_names: ["#{app}-#{name}"])
      true
    rescue Aws::EC2::Errors::InvalidKeyPairNotFound
      false
    end
  end

  def set_ssh_proxy
    ip = get_nat_ip

    puts "setting ssh proxy: ssh #{ip} -W %h:%p -oStrictHostKeyChecking=no"
    SSHKit::Backend::Netssh.configure do |ssh|
      ssh.ssh_options.merge!({ proxy: Net::SSH::Proxy::Command.new("ssh #{ip} -W %h:%p -oStrictHostKeyChecking=no") })
    end
  end

  def create_key(key_name)
    key_file = File.expand_path("../keys/#{key_name}.pem", __FILE__)
    key = SSHKey.generate(type: "RSA", bits: 2048)
    private_key = key.private_key

    File.open(key_file, "w") do |f|
      f.write(private_key)
    end

    File.chmod(0600, key_file)

    key.ssh_public_key
  end

  def load_key(key_name)
    key_file = File.expand_path("../keys/#{key_name}.pem", __FILE__)
    private_key = File.open(key_file).read
    key = SSHKey.new(private_key)

    puts key.inspect
    key.ssh_public_key
  end

  def app_dir
    File.join(__dir__, "/../hava", "apps", app)
  end

  def get_dna
    cf_json = File.open(File.join(app_dir, "dna.json")).read
    json = JSON.parse(cf_json)

    #puts JSON.pretty_generate(json)

    app_servers = get_app_servers.collect { |x| x[:instances].collect { |y| y[:private_ip_address] }.first }

    #puts app_servers.inspect

    # trans_db = get_trans_db
    # report_db = get_report_db
    # cache = get_cache

    # puts trans_db
    # puts report_db
    # puts cache

    customise_dna(json, name) # from the app's dna_customise.rb

    json
  end

  # {"system"=>{"hostname"=>"survey-dev.in.yarris.com",
  # "ip_address"=>"10.2.101.10",
  #"hosts"=>{"name"=>["survey-dev.in.yarris.com"], "alias"=>[["survey-dev"]], "ip_address"=>["10.2.101.10"]}},
  #"mongodb"=>{"install_method"=>"mongodb-org", "package_name"=>"mongodb-org", "FORTESTONLY_cluster_name"=>"surveyuat"}}
  def get_node_dna(private_ip)
    cf_json = File.open(File.join(app_dir, "dna.json")).read
    json = JSON.parse(cf_json)

    #json["system"] = system_dna(private_ip)

    # customise_node_dna(json, name, self) # from the app's dna_customise.rb

    json
  end

  # def system_dna(private_ip)
  #   node = instances_for_filter("private-ip-address", private_ip).first[:instances].first

  #   hostname = node["tags"].select { |x| x["key"] == "Name" }.first["value"]
  #   internal = "#{hostname}.in.arnie.com.au"

  #   system = {}
  #   system["name"] = hostname
  #   system["hostname"] = internal
  #   system["ip"] = private_ip
  #   system["hosts"] = [] if system["hosts"].nil?
  #   system["hosts"] << {
  #     "name" => internal,
  #     "ip" => private_ip
  #   }

  #   system
  # end

  def get_trans_db
    resp = $rds.describe_db_instances(db_instance_identifier: "#{app}-#{name}-transaction")

    trans = resp[:db_instances].first

    raise "Transaction DB endpoint details not available yet" if trans[:endpoint].nil?

    trans[:endpoint][:address]
  end

  def get_report_db
    resp = $rds.describe_db_instances(db_instance_identifier: "#{app}-#{name}-report")

    report = resp[:db_instances].first

    raise "Report DB endpoint details not available yet" if report[:endpoint].nil?

    report[:endpoint][:address]
  end

  def get_cache
    resp = $elasticache.describe_cache_clusters(cache_cluster_id: "#{app}-#{name}-cache", show_cache_node_info: true)

    cache = resp[:cache_clusters].first
    cache_node = cache[:cache_nodes].first

    raise "Cache endpoint details not available yet" if cache_node[:endpoint].nil?

    cache_node[:endpoint][:address]
  end

  def get_app_servers
    instances_for_role("app")
  end

  def create_stack
    cf_json = File.open(File.join(__dir__, "apps", "#{app}", "#{app}.json")).read
    json = JSON.parse(cf_json)

    begin
      resp = $cloudformation.describe_stacks(stack_name: "#{app}-#{name}")

      if resp[:stacks].any?
        puts "Stack already exists"

        stack = resp[:stacks].first

        puts stack[:stack_id]
        puts stack[:stack_name]
      end
    rescue Aws::CloudFormation::Errors::ValidationError => e
      puts "Creating new environment: #{app}-#{name}"
      resp = $cloudformation.create_stack(
        stack_name: "#{app}-#{name}",
        template_body: json.to_json,
        parameters: [{
          parameter_key: "EnvironmentName",
          parameter_value: name
        }],
        tags: [{
          key: "environment",
          value: "#{app}-#{name}"
        }])
    end
  end

  def update_stack
    cf_json = File.open(File.join(__dir__, "/../", "hava", "apps", "#{app}", "#{app}.json")).read
    json = JSON.parse(cf_json)

    $cloudformation.update_stack(
      stack_name: "#{app}-#{name}",
      template_body: json.to_json,
      parameters: [{
        parameter_key: "EnvironmentName",
        parameter_value: name
      }])
  end

  def wait_for_instances_created
    # Now we wait for the instances to be created...
    waiting = true
    while waiting do
      resp = $cloudformation.describe_stack_resources(stack_name: "#{app}-#{name}")
      instances = resp[:stack_resources].select { |x| x[:resource_type] == "AWS::EC2::Instance" }

      instances_count = instances.size
      instances_ready = 0 

      instances.each do |i|
        puts i[:logical_resource_id]
        puts i[:resource_status]

        instances_ready = instances_ready + 1 if i[:resource_status] == "CREATE_COMPLETE"
        puts instances_ready
      end

      break if instances_count == instances_ready
      sleep 5
    end
  end

  def destroy_stack
    begin
      resp = $cloudformation.describe_stacks(stack_name: "#{app}-#{name}")

      if resp[:stacks].any?
        puts "destroying environment!"

        stack = resp[:stacks].first

        $cloudformation.delete_stack(stack_name: stack[:stack_name])

        puts "done"
      end
    rescue Aws::CloudFormation::Errors::ValidationError
      puts "stack doesn't exist, yo!"
    end
  end

  # Returns an array of EC2 reservations based on the given filter name/value and state.
  def instances_for_filter(filter_name, filter_value, state = "running")
    $ec2.describe_instances(
      filters: [
        { name: filter_name, values: [filter_value] },
        { name: "tag:environment", values: ["#{app}-#{name}"] },
        { name: "instance-state-name", values: [state] }
      ])[:reservations]
  end

  # Returns an array of EC2 reservations based on the given role and state.
  def instances_for_role(role, state = "running")
    instances_for_filter("tag:role", role, state)
  end

  def get_nat_ip
    # Get NAT instance details
    nat = ""
    instances_for_role("nat").each do |res|
      res[:instances].each do |inst|
        nat << "ec2-user@#{inst[:network_interfaces].first[:association][:public_ip]}"
      end
    end

    nat
  end

  def get_instances(role)
    # Get App server details
    servers = []
    instances_for_role(role).each do |res|
      res[:instances].each do |inst|
        servers << "ubuntu@#{inst[:private_ip_address]}"
      end
    end

    servers
  end
end