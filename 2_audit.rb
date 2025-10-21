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
  # débit réseau
  opt.on('-f', '--flux_min MIN') { |o| options[:flux_min] = o }
  # gestion des services 
  opt.on('-e', '--services "service1 service 2 ..." ') { |o| options[:services] = o }
end.parse!

############ VARIABLES OPTIONS ############

format = options[:output] || "text"
cpu_th = options[:cpu] || 5   # défaut 5%
mem_th = options[:memory] || 5   # défaut 5%
flux_min = options[:flux_min] || 2 # défaut 2KB
services_list = options[:services] ? options[:services].split(' ') : []

############ FONCTIONS ############
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
def uptime_avgload_memory_swapavailable(format)
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
def network_interfaces(format)
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
        "Interface" => iface,
        "MAC" => "N/A",
        "IPv4" => [],
        "IPv6" => []
      }
    end
    
    # Extraire les adresses IP de cette ligne
    parts.each do |part|
      case part
        # IPv4 avec CIDR
      when /^(\d{1,3}\.){3}\d{1,3}\/\d+$/
        if !interfaces_data[iface]["IPv4"].include?(part)
          interfaces_data[iface]["IPv4"] << part
        end
        # IPv4 sans CIDR
      when /^(\d{1,3}\.){3}\d{1,3}$/
        if !interfaces_data[iface]["IPv4"].include?(part)
          interfaces_data[iface]["IPv4"] << part
        end
      when /^([0-9a-f]{0,4}:){2,7}[0-9a-f]{0,4}\/\d+$/i
        if !interfaces_data[iface]["IPv6"].include?(part)
          interfaces_data[iface]["IPv6"] << part
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
          interfaces_data[iface]["MAC"] = part
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
      puts "Interface: #{data["Interface"]}"
      puts "  MAC: #{data["MAC"]}"
      
      if data["IPv4"].empty?
        puts "  IPv4: N/A"
      else
        data["IPv4"].each_with_index do |ip, index|
          if index == 0
            puts "  IPv4: #{ip}"
          else
            puts "  IPv4 (#{index + 1}): #{ip}"
          end
        end
      end
      
      if data["IPv6"].empty?
        puts "  IPv6: N/A"
      else
        data["IPv6"].each_with_index do |ip, index|
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

# 4
def users_humains(format)
  humains = `grep -E '^[^:]+:[^:]*:[0-9]{4,}:' /etc/passwd | cut -d: -f1`.split("\n")
  humains_up = `who | cut -d' ' -f1 | uniq`.split("\n")
  info = {
    "Humains" => humains,
    "Humains connectés" => humains_up
  }

  if format.downcase == "json"
    puts info.to_json
  else
    puts "\nUtilisateurs humains: #{humains}"
    puts "Humains connectés: #{humains_up}"
  end
end

#5

def espace_disque(format)
  regex = /^(\/dev\/\S+)\s+(\S+)\s+(\S+)\s+(\S+)\s+(\S+).*$/
  resultat = []

  `df -h`.each_line do |ligne|
    if ligne =~ regex
      partition  = $1
      taille     = $2
      utilise    = $3
      disponible = $4
      dispo_pct  = $5

      entree = {
        partition: partition,
        taille: taille,
        utilise: utilise,
        disponible: disponible,
        dispo_pct:dispo_pct
      }
      resultat << entree
    end
  end

  if format.downcase == "json"
    puts JSON.pretty_generate({ espace_disque_par_partition: resultat })
  else
    resultat.each do |entree|
      puts "Partition: #{entree[:partition]}, Taille: #{entree[:taille]}, Utilisé: #{entree[:utilise]}, Disponible: #{entree[:disponible]}, Dispo%: '#{entree[:dispo_pct]}%'"
    end
  end
end

# 6 
def processes_usage(format, cpu_th, mem_th)
  # Processus au-dessus du seuil CPU
  cpu_processes = `ps -eo pid,user,comm,pcpu,pmem --sort=-pcpu | awk -v th="#{cpu_th}" 'NR==1{print;next} $4+0>th{printf "%s\t%s\t%s\t%s%%\t%s%%\\n",$1,$2,$3,$4,$5}'`.strip
  
  # Processus au-dessus du seuil MEM
  mem_processes = `ps -eo pid,user,comm,pcpu,pmem --sort=-pmem | awk -v th="#{mem_th}" 'NR==1{print;next} $5+0>th{printf "%s\t%s\t%s\t%s%%\t%s%%\\n",$1,$2,$3,$4,$5}'`.strip
  
  info = {
    "Seuil CPU" => "#{cpu_th}%",
    "Processus CPU " => cpu_processes.split("\n"),
    "Seuil Mémoire" => "#{mem_th}%",
    "Processus Mémoire " => mem_processes.split("\n")
  }
  
  if format.downcase == "json"
    puts info.to_json
  else
    puts "\nProcesses with CPU > #{cpu_th}%:"
    puts cpu_processes
    puts "\nProcesses with MEM > #{mem_th}%:"
    puts mem_processes
  end
end
#7
def analyser_nethogs(flux_min, format)
  resultat = []

  commande = `timeout 3 nethogs -t -a 2>/dev/null`

  commande.each_line do |ligne|
    colonnes = ligne.strip.split
    next if colonnes.size < 3 # ignore les lignes invalides

    interface = colonnes[0]
    envoye    = colonnes[1].to_f
    recu      = colonnes[2].to_f

    if (envoye + recu) >= flux_min
      entree = {
        interface: interface,
        envoye: envoye.to_s + "KB",
        recu: recu.to_s + "KB"
      }
      resultat << entree
    end
  end

  if format.downcase == 'json'
    puts JSON.pretty_generate({ flux_reseau: resultat })
  else
    resultat.each do |entree|
      puts "Interface: #{entree[:interface]}, Envoyé: #{entree[:envoye]} KB, Reçu: #{entree[:recu]} KB"
    end
  end
end

# 8
def services_status(format, services_list = [])
  if services_list.empty?
    # Services par défaut si aucun n'est spécifié
    default_services = ["sshd", "cron", "docker"]
    
    services_info = {}
    
    default_services.each do |service|
      service_file = "#{service}.service"
      
      # Vérifier si le service existe
      check_cmd = `systemctl list-unit-files | grep -q "^#{service_file}"`
      
      if $?.success?
        active_status = `systemctl is-active #{service}`.strip
        enabled_status = `systemctl is-enabled #{service} 2>/dev/null`.strip
        services_info[service] = "#{active_status} / #{enabled_status}"
      else
        services_info[service] = "non présent sur le système"
      end
    end
  else
    # Services spécifiés par l'utilisateur
    services_info = {}
    
    services_list.each do |service|
      service_file = "#{service}.service"
      
      # Vérifier si le service existe
      check_cmd = `systemctl list-unit-files | grep -q "^#{service_file}"`
      
      if $?.success?
        active_status = `systemctl is-active #{service}`.strip
        enabled_status = `systemctl is-enabled #{service} 2>/dev/null`.strip
        services_info[service] = "#{active_status} / #{enabled_status}"
      else
        services_info[service] = "non présent sur le système"
      end
    end
  end

  if format.downcase == "json"
    puts services_info.to_json
  else
    puts "\nÉtat des services:"
    services_info.each do |service, status|
      puts "#{service} : #{status}"
    end
  end
end

############ EXECUTION ############
puts nom_distro(format) #1
puts uptime_avgload_memory_swapavailable(format) #2
network_interfaces(format) #3
puts users_humains(format) #4
espace_disque(format) #5
puts processes_usage(format, cpu_th, mem_th) #6
analyser_nethogs(flux_min, format) #7
services_status(format, services_list) #8
