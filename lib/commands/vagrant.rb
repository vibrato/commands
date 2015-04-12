# # Read the applications dna.json file for the chef.json parameter
# def get_dna(path)
#   json = File.open(File.expand_path("../../apps/#{path}", __FILE__), "r").read
#   JSON.parse(json)
# end

# def apply_cluster_dna(nodes)
#   name = "arnie-dev"
#   environment = "dev"

#   info = nodes.map { |n| {
#     name: n[:name],
#     ip: n[:ip]
#   }}

#   d = info.map { |n| {
#     name: n[:name],
#     ip: n[:ip],
#     hosts: info.map { |h| { name: h[:name], ip: h[:ip] }}.reject { |h| h[:ip] == n[:ip] }
#   }}

#   nodes.each_with_index do |node, i|
#     node[:dna] = d[i]

#     node[:arnie] = {
#       name: name,
#       environment: environment,
#       hostname: node[:name],
#       ip: node[:ip],
#       db: "10.1.1.14",
#       weblogic: {
#         admin: {
#           node: "#{name}-app-a"
#         },
#         managed: nodes.select { |x| x[:role] == "application" }.map { |x| x[:name] }
#       },
#       database: {
#         host: nodes.select { |x| x[:role] == "database" }.map { |x| x[:name] }.first
#       }
#     }
#   end

#   nodes
# end

# def apply_dna(nodes)
#   name = "arnie-dev"
#   environment = "dev"

#   info = nodes.map { |n| {
#     name: n[:name],
#     ip: n[:ip]
#   }}

#   d = info.map { |n| {
#     name: n[:name],
#     ip: n[:ip],
#     hosts: info.map { |h| { name: h[:name], ip: h[:ip] }}.reject { |h| h[:ip] == n[:ip] }
#   }}

#   nodes.each_with_index do |node, i|
#     node[:dna] = d[i]

#     node[:arnie] = {
#       name: name,
#       environment: environment,
#       hostname: node[:name],
#       ip: node[:ip],
#       db: "10.1.1.10",
#       weblogic: {
#         admin: {
#           node: "#{name}"
#         },
#         managed: ["#{name}"]
#       },
#       database: {
#         host: "10.1.1.10"
#       }
#     }
#   end

#   nodes
# end
