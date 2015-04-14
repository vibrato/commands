require "commands/aws"

class Environment
  attr_reader :name, :key

  def initialize(name=nil)
    @name = name ? name : "development"

    sort_out_key

    # Make connections
    SSHKit::Backend::Netssh.configure do |ssh|
      ssh.pty = true
      ssh.ssh_options = {
        keys: File.join(Dir.pwd, "keys", "#{name}.pem"),
        forward_agent: true,
        proxy: nil,
        user_known_hosts_file: "/dev/null"
      }
    end
    SSHKit.config.output_verbosity= Logger::DEBUG

    # set_ssh_proxy if !dev?
  end

  def sort_out_key
    if !dev?
      key_file = "keys/#{name}.pem"
      key_file_exists = File.exist?(key_file)

      if keypair_exists?
        if key_file_exists
          puts "found existing ssh key"
          @key = key_file
        else
          raise Exception.new("Environment's keypair already exists, please add environments key to keys/ directory") unless key_file_exists
        end
      else
        if key_file_exists
          puts "uploading key to aws"
          keyz = load_key(name)
          puts "derploaded: #{keyz}"
          puts name
        else
          puts "creating key yo"
          keyz = create_key(name)
          puts "derp: #{keyz}"
        end
        $ec2.import_key_pair(key_name: name, public_key_material: keyz)
        @key = key_file
      end

      File.chmod(0600, key_file)
      puts `ssh-add #{key_file}`
      puts key
    end
  end

  def on(nodes, &blk)

    set_ssh_proxy

    details = nodes.collect { |node| "#{node.ssh_username}@#{node.address}" }

    # First do those that don't require a proxy
    SSHKit::DSL.on(details, {}, &blk)
  end

  def dev?
    name == "arnie-dev"
  end

  def keypair_exists?
    begin
      $ec2.describe_key_pairs(key_names: [name])
      true
    rescue Aws::EC2::Errors::InvalidKeyPairNotFound
      false
    end
  end

  def set_ssh_proxy
    ip = get_nat_ip

    puts " Setting ssh proxy: ssh #{ip} -W %h:%p -oStrictHostKeyChecking=no"
    SSHKit::Backend::Netssh.configure do |ssh|
      ssh.ssh_options.merge!({ proxy: Net::SSH::Proxy::Command.new("ssh #{ip} -W %h:%p -oStrictHostKeyChecking=no") })
    end
  end

  def create_key(key_name)

    puts " Creating a new SSH key"

    key_file = "keys/#{key_name}.pem"
    key = SSHKey.generate(type: "RSA", bits: 2048)
    private_key = key.private_key

    File.open(key_file, "w") do |f|
      f.write(private_key)
    end
    File.chmod(0600, key_file)

    key.ssh_public_key
  end

  def load_key(key_name)

    puts " Loading SSH key"

    key_file = "keys/#{key_name}.pem"
    private_key = File.open(key_file).read
    key = SSHKey.new(private_key)

    puts key.inspect
    key.ssh_public_key
  end

  def get(value, default)
    default
  end

  ##############################
  # # Custom DNA
  # def get_dna

  #   autoload :CustomDNA, './dna.rb'

  #   CustomDNA.new.dna(self)

  #   # cf_json = File.open(File.join(_dir, "dna.json")).read
  #   # json = JSON.parse(cf_json)

  #   # _servers = get__servers.collect { |x| x[:instances].collect { |y| y[:private_ip_address] }.first }

  #   # customise_dna(json, name) # from the 's dna_customise.rb

  #   # json
  # end

  ##############################
  # SSH Proxy

  # Get NAT instance details
  def get_nat_ip
    nat = ""
    instances_for_role("nat").each do |res|
      res[:instances].each do |inst|
        nat << "ec2-user@#{inst[:network_interfaces].first[:association][:public_ip]}"
      end
    end

    nat
  end

  # Get App server details
  def get_instances(role: nil, username: nil, bastion: nil)
    puts "getting instances for #{role}!"
    servers = []
    instances_for_role(role).each do |res|
      res[:instances].each do |inst|
        servers << "#{username}@#{inst[:private_ip_address]}" # Node.new(ssh_username: username, address: inst[:private_ip_address], bastion: bastion, details: inst)
      end
    end

    servers
  end

  def get_node_dna(private_ip)
    autoload :CustomDNA, "./apps/arnie/dna.rb"
    CustomDNA.new.dna(self, private_ip)
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

  def get_db(db_instance_identifier)
    resp = $rds.describe_db_instances(db_instance_identifier: db_instance_identifier)

    trans = resp[:db_instances].first

    raise "Transaction DB endpoint details not available yet" if trans[:endpoint].nil?

    trans[:endpoint][:address]
  end

  def get_cache(cache_cluster_id)
    resp = $elasticache.describe_cache_clusters(cache_cluster_id: cache_cluster_id, show_cache_node_info: true)

    cache = resp[:cache_clusters].first
    cache_node = cache[:cache_nodes].first

    raise "Cache endpoint details not available yet" if cache_node[:endpoint].nil?

    cache_node[:endpoint][:address]
  end

  def create_stack(template)
    cf_json = File.open(template).read
    json = JSON.parse(cf_json)

    begin
      resp = $cloudformation.describe_stacks(stack_name: name)

      if resp[:stacks].any?
        puts "Stack already exists"

        stack = resp[:stacks].first

        puts stack[:stack_id]
        puts stack[:stack_name]
      end
    rescue Aws::CloudFormation::Errors::ValidationError => e
      puts "Creating new environment:name"
      resp = $cloudformation.create_stack(
        stack_name: name,
        template_body: json.to_json,
        parameters: [{
          parameter_key: "EnvironmentName",
          parameter_value: name
        }],
        tags: [{
          key: "environment",
          value: name
        }])
    end
  end

  def update_stack(template)
    cf_json = File.open(template).read
    json = JSON.parse(cf_json)

    $cloudformation.update_stack(
      stack_name: name,
      template_body: json.to_json,
      parameters: [{
        parameter_key: "EnvironmentName",
        parameter_value: name
      }])
  end

  def wait_for_stack(name)
    puts name
    waiting = true
    while waiting do
      resp = $cloudformation.describe_stacks(stack_name: name)
      stack = resp[:stacks].first

      puts stack.stack_status

      break if stack.stack_status != "CREATE_IN_PROGRESS"
      sleep 20
    end
  end

  def wait_for_instances_created
    # Now we wait for the instances to be created...
    waiting = true
    while waiting do
      resp = $cloudformation.describe_stack_resources(stack_name: name)
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
      resp = $cloudformation.describe_stacks(stack_name: name)

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
        { name: "tag:environment", values: [name] },
        { name: "instance-state-name", values: [state] }
      ])[:reservations]
  end

  # Returns an array of EC2 reservations based on the given role and state.
  def instances_for_role(role, state = "running")
    instances_for_filter("tag:role", role, state)
  end
end
