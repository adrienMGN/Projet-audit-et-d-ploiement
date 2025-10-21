#!/usr/bin/env ruby
require 'json'
require 'optparse'

# gestion des paramètres
options = {}
OptionParser.new do |opt|
  # output text ou json
  opt.on('-o', '--output FORMAT') { |o| options[:output] = o }
  # seuil cpu
  opt.on('-c', '--cpu_threshold THRESHOLD') { |o| options[:cpu] = o }
  # seuil memoire
  opt.on('-m', '--memory_threshold THRESHOLD') { |o| options[:memory] = o }
  # durée de la mesure 
  opt.on('-d', '--proc_duration DURATION') { |o| options[:duration] = o }
  # débit réseau
  opt.on('-s', '--min_speed SPEED') { |o| options[:speed] = o }
  # gestion des services 
  opt.on('-e', '--services "service1 service 2 ..." ') { |o| options[:services] = o }
end.parse!

format = options[:output] || "text"

# 1
def nom_distro(format = "text")
  nodename = `uname --nodename`.strip
  distrib = `lsb_release -a 2>/dev/null | grep Description | cut -f2`.strip
  kernel_ver = `uname -r`.strip

  infos = {
    "Nom de la machine" => nodename,
    "Distribution" => distrib,
    "Version du kernel" => kernel_ver
  }

  if format.downcase == "json"
    puts infos.to_json
  else
    puts "\nNom de la machine: #{nodename}"
    puts "Distribution: #{distrib}"
    puts "Version du kernel: #{kernel_ver}"
  end
end

# 2
def uptime_avgload_memory_swapavailable(format = "text")
  uptime = `uptime -p`.strip
  load_avg = `LANG=C uptime | grep -o 'load average:.*' | cut -d':' -f2`.strip
  mem_info = `LANG=C free -h | grep Mem: | tr -s ' ' | cut -d' ' -f3,4`.strip
  swap_info = `LANG=C free -h | grep Swap: | tr -s ' ' | cut -d' ' -f3,4`.strip

  mem_used, mem_dispo = mem_info.split(' ')
  swap_used, swap_dispo = swap_info.split(' ')

  info = {
    "Uptime" => uptime,
    "Charge moyenne (1, 5, 15 min)" => load_avg,
    "Mémoire utilisée" => mem_used,
    "Mémoire disponible" => mem_dispo,
    "Swap utilisé" => swap_used,
    "Swap disponible" => swap_dispo
  }

  if format.downcase == "json"
    puts info.to_json
  else
    puts "\nUptime: #{uptime}"
    puts "Charge moyenne (1, 5, 15 min): #{load_avg}"
    puts "Mémoire utilisée | disponible: #{mem_used} | #{mem_dispo}"
    puts "Swap utilisé | disponible: #{swap_used} | #{swap_dispo}"
  end
end

# 3 

def network(format = "text")
  # Récupérer les informations des interfaces avec leurs adresses IP
  interfaces_output = `ip -o addr show`
  
  # Récupérer les adresses MAC avec ip link show
  link_output = `ip -o link show`
  
  # Grouper par interface
  interfaces_data = {}
  
  # Traiter les adresses IP
  interfaces_output.lines.each do |line|
    parts = line.split
    next if parts.length < 4
    
    iface = parts[1]
    
    # Initialiser l'interface si pas encore présente
    if interfaces_data[iface] == nil
      interfaces_data[iface] = {
        interface: iface,
        mac: "N/A",
        ipv4: [],
        ipv6: []
      }
    end
    
    # Extraire les adresses IP de cette ligne
    parts.each do |part|
      case part
        # IPv4 avec CIDR
      when /^(\d{1,3}\.){3}\d{1,3}\/\d+$/
        if !interfaces_data[iface][:ipv4].include?(part)
          interfaces_data[iface][:ipv4] << part
        end
        # IPv4 sans CIDR
      when /^(\d{1,3}\.){3}\d{1,3}$/
        if !interfaces_data[iface][:ipv4].include?(part)
          interfaces_data[iface][:ipv4] << part
        end
      when /^([0-9a-f]{0,4}:){2,7}[0-9a-f]{0,4}\/\d+$/i
        if !interfaces_data[iface][:ipv6].include?(part)
          interfaces_data[iface][:ipv6] << part
        end
      end
    end
  end
  
  # Traiter les adresses MAC avec ip link
  link_output.lines.each do |line|
    parts = line.split
    next if parts.length < 4
    
    iface = parts[1].gsub(':', '')  # Enlever les : du nom d'interface
    
    # Chercher l'adresse MAC dans la ligne
    parts.each do |part|
      # Adresse MAC
      if part =~ /^([0-9a-f]{2}:){5}[0-9a-f]{2}$/i
        if interfaces_data[iface]
          interfaces_data[iface][:mac] = part
        end
        break
      end
    end
  end
  
  # Convertir en array pour la sortie
  result = interfaces_data.values
  
  if format.downcase == "json"
    puts result.to_json
  else
    puts "\nInformations Réseau:"
    result.each do |data|
      puts "Interface: #{data[:interface]}"
      puts "  MAC: #{data[:mac]}"
      
      if data[:ipv4].empty?
        puts "  IPv4: N/A"
      else
        data[:ipv4].each_with_index do |ip, index|
          if index == 0
            puts "  IPv4: #{ip}"
          else
            puts "  IPv4 (#{index + 1}): #{ip}"
          end
        end
      end
      
      if data[:ipv6].empty?
        puts "  IPv6: N/A"
      else
        data[:ipv6].each_with_index do |ip, index|
          if index == 0
            puts "  IPv6: #{ip}"
          else
            puts "  IPv6 (#{index + 1}): #{ip}"
          end
        end
      end
      puts
    end
  end
end



puts nom_distro(format)
puts uptime_avgload_memory_swapavailable(format)

network(format)