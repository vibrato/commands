class Node
  attr_reader :ssh_username, :address

  def initialize(ssh_username: nil, address: nil, bastion: nil, details: nil)
  	@ssh_username = ssh_username
  	@address = address
  	@bastion = bastion
  	@details = details
  end

  def derp
  	puts "DERRRRP"
  end
end
