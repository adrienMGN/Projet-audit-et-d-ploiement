#!/usr/bin/env ruby

# librairies utilisées
require 'json'
require 'optparse' # gère les options en ligne de commande

# gestion des paramètres
options = {}
OptionParser.new do |opt|
  opt.banner = "Usage: audit.rb [options]"
  opt.separator ""
  opt.separator "Options:"
  
  opt.on('-o', '--output FORMAT', "Format de sortie : text (par défaut) ou json") do |o|
    options[:output] = o
  end
  
  opt.on('-c', '--cpu_threshold THRESHOLD', Float, "Seuil d'utilisation CPU en % (par défaut : 5)") do |c|
    options[:cpu] = c
  end
  
  opt.on('-m', '--memory_threshold THRESHOLD', Float, "Seuil d'utilisation mémoire en % (par défaut : 5)") do |m|
    options[:memory] = m
  end
  
  opt.on('-f', '--flux_min MIN', Float, "Flux réseau minimum en KB (par défaut : 2)") do |f|
    options[:flux_min] = f
  end
  
  opt.on('-s', '--services "service1 service2"', "Liste de services à vérifier (séparés par des espaces)") do |s|
    options[:services] = s
  end
  
  opt.on('-h', '--help', "Afficher ce message d'aide") do
    puts opt
    exit
  end
end.parse!


############ VARIABLES OPTIONS ############

format = options[:output] || "text"
cpu_th = options[:cpu] || 5   # défaut 5%
mem_th = options[:memory] || 5   # défaut 5%
flux_min = options[:flux_min] || 2 # défaut 2KB
services_list = options[:services] ? options[:services].split(' ') : []
output_file = options[:file] # fichier de sortie pour JSON

############ FONCTIONS ############

# fonction export json avec header correspondant 
def export_json_to_file(data, file_path)
    File.open(file_path, 'w') do |file|
      file.write(JSON.pretty_generate(data))
      puts "Données JSON exportées vers: #{file_path}"
    end
end

# 1
def nom_distro(format)
  nodename = `uname --nodename`.strip
  distrib = `lsb_release -a 2>/dev/null | grep Description | cut -f2`.strip
  kernel_ver = `uname -r`.strip

  infos = {
    "Nom de la machine" => nodename,
    "Distribution" => distrib,
    "Version du kernel" => kernel_ver
  }

  if format.downcase == "json" && format != "json_silent"
    puts infos.to_json
  elsif format != "json_silent"
    puts "\nNom de la machine: #{nodename}"
    puts "Distribution: #{distrib}"
    puts "Version du kernel: #{kernel_ver}"
  end
  
  return infos
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

  if format.downcase == "json" && format != "json_silent"
    puts info.to_json
  elsif format != "json_silent"
    puts "\nUptime: #{uptime}"
    puts "Charge moyenne (1, 5, 15 min): #{load_avg}"
    puts "Mémoire utilisée | disponible: #{mem_used} | #{mem_dispo}"
    puts "Swap utilisé | disponible: #{swap_used} | #{swap_dispo}"
  end
  
  return info
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
    parts = line.split # split sur \s
    next if parts.length < 4 # ignore invalide (mini 4 parties)
    
    iface = parts[1] # Nom de l'interface
    
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
    parts = line.split # \s
    next if parts.length < 4
    
    iface = parts[1].gsub(':', '')  # Enlever les : du nom d'interface
    
    # Chercher l'adresse MAC dans la ligne
    parts.each do |part|
      # Adresse MAC
      if part =~ /^([0-9a-f]{2}:){5}[0-9a-f]{2}$/i
        if interfaces_data[iface]
          # Assigner l'adresse MAC tableau de l'interface interfaces_data[iface] contient pour chaque interface un tableau de données 
          interfaces_data[iface]["MAC"] = part
        end
        break
      end
    end
  end
  
  # .values pour obtenir un tableau des valeurs 
  result = interfaces_data.values
  
  if format.downcase == "json" && format != "json_silent"
    puts result.to_json
  elsif format != "json_silent"
    puts "\nInformations Réseau:"
    result.each do |data|
      puts "Interface: #{data["Interface"]}"
      puts "  MAC: #{data["MAC"]}"
      ### IPv4
      if data["IPv4"].empty?
        puts "  IPv4: N/A"
      else
        # each with_index pour numéroter les adresses si plusieurs 
        data["IPv4"].each_with_index do |ip, index|
          if index == 0 
            puts "  IPv4: #{ip}"
          else
            puts "  IPv4 (#{index + 1}): #{ip}"
          end
        end
      end
      # IPv6
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
  
  return result
end

# 4
def users_humains(format)
  # Filtrer les utilisateurs avec UID >= 1000 en excluant les comptes système connus
  excluded_users = ['nobody', 'nogroup', 'nfsnobody']
  humains = `grep -E '^[^:]+:[^:]*:[0-9]{4,}:' /etc/passwd | cut -d: -f1`.split("\n").reject { |user| excluded_users.include?(user) }
  humains_up = `who | cut -d' ' -f1 | uniq`.split("\n")
  info = {
    "Humains" => humains,
    "Humains connectés" => humains_up
  }

  if format.downcase == "json" && format != "json_silent"
    puts info.to_json
  elsif format != "json_silent"
    puts "\nUtilisateurs humains: #{humains}"
    puts "Humains connectés: #{humains_up}\n\n"
  end
  
  return info
end

#5
def espace_disque(format)
  # cherche les partitions et les espaces disques /dev/... espce disque 
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

  if format.downcase == "json" && format != "json_silent"
    puts JSON.pretty_generate({ espace_disque_par_partition: resultat })
  elsif format != "json_silent"
    resultat.each do |entree|
      puts "Partition: #{entree[:partition]}, Taille: #{entree[:taille]}, Utilisé: #{entree[:utilise]}, Disponible: #{entree[:disponible]}, Dispo%: '#{entree[:dispo_pct]}%'"
    end
  end
  
  return resultat
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
  
  if format.downcase == "json" && format != "json_silent"
    puts info.to_json
  elsif format != "json_silent"
    puts "\n Processus CPU > #{cpu_th}%:"
    puts cpu_processes
    puts "\nProcessus avec MEM > #{mem_th}%:"
    puts mem_processes
  end
  
  return info
end

#7
# nécessite de lancér le script avec les droits root pour nethogs
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

  if format.downcase == 'json' && format != "json_silent"
    puts JSON.pretty_generate({ flux_reseau: resultat })
  elsif format != "json_silent"
    puts "\nFlux Réseau (supérieur à #{flux_min} KB):"
    resultat.each do |entree|
      puts "Interface: #{entree[:interface]}, Envoyé: #{entree[:envoye]} KB, Reçu: #{entree[:recu]} KB"
    end
  end
  
  return resultat
end

# 8
def services_status(format, services_list = [])
  default_services = %w[sshd cron docker]
  to_check = services_list.empty? ? default_services : services_list
  services_info = {}

  to_check.each do |svc|
    unit = svc.end_with?('.service') ? svc : "#{svc}.service"

    # vérifier présence de l'unité
    exists = system("systemctl list-unit-files | grep -w -q \"^#{unit}\" 2>/dev/null")

    if exists
      # utiliser le nom court (sans .service) pour is-active/is-enabled est acceptable
      name_for_state = svc.sub(/\.service\z/, '')
      active_status = `systemctl is-active #{name_for_state} 2>/dev/null`.strip
      enabled_status = `systemctl is-enabled #{name_for_state} 2>/dev/null`.strip
      services_info[name_for_state] = "#{active_status} / #{enabled_status}"
    else
      services_info[svc.sub(/\.service\z/, '')] = "non présent sur le système"
    end
  end

  if format.downcase == "json" && format != "json_silent"
    puts JSON.pretty_generate(services_info)
  elsif format != "json_silent"
    puts "\nÉtat des services:"
    services_info.each { |service, status| puts "#{service} : #{status}" }
  end

  services_info
end

############ EXECUTION ############

### si pas lancer en root avertissement 
# uid = 0 pour root
if Process.uid != 0 then
  puts "##############################################################################"
  puts "\nAttention: l'analyse du trafic réseau nécessite les droits root pour nethogs.\n"
  puts 
  puts "##############################################################################"

end

### Mode avec JSON et fichier de sortie spécifié
if format.downcase == "json" && output_file
  # Mode JSON avec fichier de sortie - collecte toutes les données
  all_data = {
    # date audit
    "timestamp" => Time.now.strftime("%Y-%m-%d %H:%M:%S"),
    # json_silent pour éviter les affichages intermédiaires
    "system_info" => nom_distro("json_silent"),
    "resources" => uptime_avgload_memory_swapavailable("json_silent"),
    "network_interfaces" => network_interfaces("json_silent"),
    "users" => users_humains("json_silent"),
    "disk_space" => espace_disque("json_silent"),
    "processes" => processes_usage("json_silent", cpu_th, mem_th),
    "network_flux" => analyser_nethogs(flux_min, "json_silent"),
    "services" => services_status("json_silent", services_list)
  }
  export_json_to_file(all_data, output_file)
else
  # Mode texte stdout
  nom_distro(format) #1
  uptime_avgload_memory_swapavailable(format) #2
  network_interfaces(format) #3
  users_humains(format) #4
  espace_disque(format) #5
  processes_usage(format, cpu_th, mem_th) #6
  analyser_nethogs(flux_min, format) #7
  services_status(format, services_list) #8
end