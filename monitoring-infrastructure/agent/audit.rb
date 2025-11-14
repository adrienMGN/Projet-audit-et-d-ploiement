#!/usr/bin/env ruby
# encoding: utf-8

# librairies utilisées
require 'json'
require 'optparse' # gère les options en ligne de commande

# Codes de couleur ANSI pour l'affichage coloré
class Colors
  RED = "\033[31m"
  GREEN = "\033[32m"
  YELLOW = "\033[33m"
  BLUE = "\033[34m"
  MAGENTA = "\033[35m"
  CYAN = "\033[36m"
  WHITE = "\033[37m"
  BOLD = "\033[1m"
  RESET = "\033[0m"
end

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

  opt.on('-p', '--file PATH', "Fichier de sortie pour JSON") do |p|
    options[:file] = p
  end
end.parse!

############ VARIABLES OPTIONS ############

format = options[:output] || "text"
cpu_th = options[:cpu] || 5   # défaut 5%
mem_th = options[:memory] || 5   # défaut 5%
flux_min = options[:flux_min] || 2 # défaut 2KB
services_list = options[:services] ? options[:services].split(' ') : []

# Si un fichier de sortie est spécifié, extraire le nom et l'ajuster pour /output/
if options[:file]
  # Extraire le nom du fichier sans le chemin
  file_name = File.basename(options[:file])
  # Créer le chemin complet vers /output/
  output_file_path = File.join('/output', file_name)
else
  # sinon pas de fichier de sortie (mode texte stdout)
  output_file_path = nil
end

######################## Execution distante ########################
# Configuration SSH pour exécuter les commandes sur la machine distante
HOST = ENV['TARGET_HOST'] || 'host.docker.internal' # adresse de la machine distante
USER = ENV['TARGET_USER'] || 'root' # utilisateur SSH 
KEY  = ENV['SSH_KEY_PATH'] || '/root/.ssh/id_rsa' # chemin vers la clé privée SSH dans le conteneur

# Fonction pour exécuter une commande distante via SSH
def run_remote(cmd)
  # -o options pour éviter les prompts d'authenticité de l'hôte
  ssh_cmd = "ssh -o StrictHostKeyChecking=no -i #{KEY} #{USER}@#{HOST} \"#{cmd}\" 2>/dev/null"
  result = `#{ssh_cmd}`
  return result.strip
end

############ FONCTIONS ############

# fonction export json avec header correspondant 
def export_json_to_file(data, file_path)
    File.open(file_path, 'w') do |file|
      # écrire les données JSON formatées dans le fichier avec la date
      file.write(JSON.pretty_generate(data))
      puts "Données JSON exportées vers: #{file_path}"
    end
end

# # Converti tout en bits pour le Grafana plus tard
def parse_value(value)
  return 0 if value.nil? || value.to_s.strip.empty?
  
  # Si c'est déjà un nombre
  return value.to_f if value.is_a?(Numeric)
  
  value_str = value.to_s.strip
  
  # Remplacer la virgule par un point (format européen)
  value_str = value_str.tr(',', '.')
  
  # Parser les différents formats
  case value_str
  when /^([\d.]+)\s*([KMGTP])i?B?$/i  # Ex: "227G", "2.0G", "290M"
    number = $1.to_f
    unit = $2.upcase
    
    multipliers = {
      'K' => 1024,
      'M' => 1024 ** 2,
      'G' => 1024 ** 3,
      'T' => 1024 ** 4,
      'P' => 1024 ** 5
    }
    
    return (number * multipliers[unit]).to_i
    
  when /^([\d.]+)%$/  # Pourcentage (ex: "10%")
    return $1.to_f
    
  when /^([\d.]+)\s*B$/i  # Bytes (ex: "0B")
    return $1.to_f.to_i
    
  else
    # Essayer de parser comme nombre simple
    return value_str.to_f
  end
end
# Fonction json to prom
# Remplace la fonction generate_prometheus_file par celle-ci :

def generate_prometheus_file(data, prom_file_path)
  temp_file = prom_file_path + ".tmp" # fichier temporaire pour écriture atomique
  hostname = data.dig("system_info", "Nom de la machine") || "unknown" # Nom de la machine
  
  File.open(temp_file, 'w') do |f| 
    # 1. Load average - SANS TIMESTAMP
    load_avg = data.dig("resources", "Charge moyenne (1, 5, 15 min)") # Ex: "0.15, 0.10, 0.05"
    if load_avg
      loads = load_avg.split(',').map(&:strip)
      
      f.puts "# HELP node_load1 1-minute load average"
      f.puts "# TYPE node_load1 gauge"
      f.puts "node_load1{hostname=\"#{hostname}\"} #{loads[0]}"
      f.puts ""
      
      f.puts "# HELP node_load5 5-minute load average"
      f.puts "# TYPE node_load5 gauge"
      f.puts "node_load5{hostname=\"#{hostname}\"} #{loads[1]}"
      f.puts ""
      
      f.puts "# HELP node_load15 15-minute load average"
      f.puts "# TYPE node_load15 gauge"
      f.puts "node_load15{hostname=\"#{hostname}\"} #{loads[2]}"
      f.puts ""
    end

    # 2. Mémoire
    mem_used = parse_value(data.dig("resources", "Mémoire utilisée"))
    mem_available = parse_value(data.dig("resources", "Mémoire disponible"))
    mem_total = mem_used + mem_available

    f.puts "# HELP node_memory_MemTotal_bytes Total memory in bytes"
    f.puts "# TYPE node_memory_MemTotal_bytes gauge"
    f.puts "node_memory_MemTotal_bytes{hostname=\"#{hostname}\"} #{mem_total}"
    f.puts ""

    f.puts "# HELP node_memory_MemUsed_bytes Used memory in bytes"
    f.puts "# TYPE node_memory_MemUsed_bytes gauge"
    f.puts "node_memory_MemUsed_bytes{hostname=\"#{hostname}\"} #{mem_used}"
    f.puts ""

    f.puts "# HELP node_memory_MemAvailable_bytes Available memory in bytes"
    f.puts "# TYPE node_memory_MemAvailable_bytes gauge"
    f.puts "node_memory_MemAvailable_bytes{hostname=\"#{hostname}\"} #{mem_available}"
    f.puts ""

    mem_percent = mem_total > 0 ? (mem_used / mem_total * 100) : 0
    f.puts "# HELP node_memory_usage_percent Memory usage percentage"
    f.puts "# TYPE node_memory_usage_percent gauge"
    f.puts "node_memory_usage_percent{hostname=\"#{hostname}\"} #{mem_percent.round(2)}"
    f.puts ""

    # 3. Swap
    swap_used = parse_value(data.dig("resources", "Swap utilisé"))
    f.puts "# HELP node_swap_used_bytes Used swap in bytes"
    f.puts "# TYPE node_swap_used_bytes gauge"
    f.puts "node_swap_used_bytes{hostname=\"#{hostname}\"} #{swap_used}"
    f.puts ""

    # 4. Disque
    if data["disk_space"] && !data["disk_space"].empty?
      valid_disks = data["disk_space"].select do |disk|
        partition = disk[:partition] || disk["partition"]
        partition =~ /^\/dev\/(mapper|nvme|sd|vd)/  # Accepte aussi /dev/mapper
      end
      
      unless valid_disks.empty?
        # Size
        f.puts "# HELP node_filesystem_size_bytes Filesystem size in bytes"
        f.puts "# TYPE node_filesystem_size_bytes gauge"
        valid_disks.each do |disk|
          partition = disk[:partition] || disk["partition"]
          taille_raw = disk[:taille] || disk["taille"]
          total_bytes = parse_value(taille_raw)
          
          f.puts "node_filesystem_size_bytes{hostname=\"#{hostname}\",device=\"#{partition}\"} #{total_bytes}"
        end
        f.puts ""
        
        # Used
        f.puts "# HELP node_filesystem_used_bytes Filesystem used space in bytes"
        f.puts "# TYPE node_filesystem_used_bytes gauge"
        valid_disks.each do |disk|
          partition = disk[:partition] || disk["partition"]
          utilise_raw = disk[:utilise] || disk["utilise"]
          used_bytes = parse_value(utilise_raw)
          
          f.puts "node_filesystem_used_bytes{hostname=\"#{hostname}\",device=\"#{partition}\"} #{used_bytes}"
        end
        f.puts ""
        
        # Available
        f.puts "# HELP node_filesystem_avail_bytes Filesystem available space in bytes"
        f.puts "# TYPE node_filesystem_avail_bytes gauge"
        valid_disks.each do |disk|
          partition = disk[:partition] || disk["partition"]
          disponible_raw = disk[:disponible] || disk["disponible"]
          available_bytes = parse_value(disponible_raw)
          
          f.puts "node_filesystem_avail_bytes{hostname=\"#{hostname}\",device=\"#{partition}\"} #{available_bytes}"
        end
        f.puts ""
        
        # Usage percent
        f.puts "# HELP node_filesystem_usage_percent Filesystem usage percentage"
        f.puts "# TYPE node_filesystem_usage_percent gauge"
        valid_disks.each do |disk|
          partition = disk[:partition] || disk["partition"]
          usage_pct_raw = disk[:dispo_pct] || disk["dispo_pct"]
          usage_percent = parse_value(usage_pct_raw)  # Parse "10%" -> 10.0
          
          f.puts "node_filesystem_usage_percent{hostname=\"#{hostname}\",device=\"#{partition}\"} #{usage_percent}"
        end
        f.puts ""
      end
    end
    
    # 5. Services - HELP/TYPE UNE SEULE FOIS
    if data["services"] && !data["services"].empty?
      f.puts "# HELP node_service_status Service status (1=active, 0=inactive)"
      f.puts "# TYPE node_service_status gauge"
      data["services"].each do |service, status|
        is_active = status.include?("inactive") ? 0 : 1
        f.puts "node_service_status{hostname=\"#{hostname}\",service=\"#{service}\"} #{is_active}"
      end
      f.puts ""
    end

    # 6. Uptime
    uptime_str = data.dig("resources", "Uptime")
    if uptime_str
      uptime_seconds = 0
      uptime_seconds += $1.to_i * 24 * 3600 if uptime_str =~ /(\d+)\s+days?/
      uptime_seconds += $1.to_i * 3600 if uptime_str =~ /(\d+)\s+hours?/
      uptime_seconds += $1.to_i * 60 if uptime_str =~ /(\d+)\s+minutes?/
      
      f.puts "# HELP node_uptime_seconds System uptime in seconds"
      f.puts "# TYPE node_uptime_seconds counter"
      f.puts "node_uptime_seconds{hostname=\"#{hostname}\"} #{uptime_seconds}"
      f.puts ""
    end
  end
  
  # Renommer atomiquement
  File.rename(temp_file, prom_file_path)
  puts "✓ Fichier Prometheus généré: #{prom_file_path}"
end
# 1
def nom_distro(format)
  nodename = run_remote("uname --nodename").strip
  distrib = run_remote("lsb_release -a 2>/dev/null | grep Description | cut -f2").strip
  kernel_ver = run_remote("uname -r").strip

  infos = {
    "Nom de la machine" => nodename,
    "Distribution" => distrib,
    "Version du kernel" => kernel_ver
  }

  if format.downcase == "json" && format != "json_silent"
    puts infos.to_json
  elsif format != "json_silent"
    puts "\n#{Colors::BOLD}#{Colors::CYAN}Nom de la machine:#{Colors::RESET} #{nodename}"
    puts "#{Colors::BOLD}#{Colors::CYAN}Distribution:#{Colors::RESET} #{distrib}"
    puts "#{Colors::BOLD}#{Colors::CYAN}Version du kernel:#{Colors::RESET} #{kernel_ver}"
  end
  
  return infos
end

# 2
def uptime_avgload_memory_swapavailable(format)
  uptime = run_remote("uptime -p").strip
  load_avg = run_remote("LANG=C uptime | grep -o 'load average:.*' | cut -d':' -f2").strip
  mem_info = run_remote("LANG=C free -h | grep Mem: | tr -s ' ' | cut -d' ' -f3,4").strip
  swap_info = run_remote("LANG=C free -h | grep Swap: | tr -s ' ' | cut -d' ' -f3,4").strip

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
    puts "\n#{Colors::BOLD}#{Colors::GREEN}Uptime:#{Colors::RESET} #{uptime}"
    puts "#{Colors::BOLD}#{Colors::GREEN}Charge moyenne (1, 5, 15 min):#{Colors::RESET} #{load_avg}"
    puts "#{Colors::BOLD}#{Colors::GREEN}Mémoire utilisée | disponible:#{Colors::RESET} #{mem_used} | #{mem_dispo}"
    puts "#{Colors::BOLD}#{Colors::GREEN}Swap utilisé | disponible:#{Colors::RESET} #{swap_used} | #{swap_dispo}"
  end
  
  return info
end

# 3 
def network_interfaces(format)
  # Récupérer les informations des interfaces avec leurs adresses IP
  interfaces_output = run_remote("ip -o addr show")
  
  # Récupérer les adresses MAC avec ip link show
  link_output = run_remote("ip -o link show")

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
    puts "\n#{Colors::BOLD}#{Colors::MAGENTA}Informations Réseau:#{Colors::RESET}"
    result.each do |data|
      puts "#{Colors::YELLOW}Interface:#{Colors::RESET} #{data["Interface"]}"
      puts "  #{Colors::CYAN}MAC:#{Colors::RESET} #{data["MAC"]}"
      ### IPv4
      if data["IPv4"].empty?
        puts "  #{Colors::CYAN}IPv4:#{Colors::RESET} N/A"
      else
        # each with_index pour numéroter les adresses si plusieurs 
        data["IPv4"].each_with_index do |ip, index|
          if index == 0 
            puts "  #{Colors::CYAN}IPv4:#{Colors::RESET} #{ip}"
          else
            puts "  #{Colors::CYAN}IPv4 (#{index + 1}):#{Colors::RESET} #{ip}"
          end
        end
      end
      # IPv6
      if data["IPv6"].empty?
        puts "  #{Colors::CYAN}IPv6:#{Colors::RESET} N/A"
      else
        data["IPv6"].each_with_index do |ip, index|
          if index == 0
            puts "  #{Colors::CYAN}IPv6:#{Colors::RESET} #{ip}"
          else
            puts "  #{Colors::CYAN}IPv6 (#{index + 1}):#{Colors::RESET} #{ip}"
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
  
  humains = run_remote("grep -E '^[^:]+:[^:]*:[0-9]{4,}:' /etc/passwd | cut -d: -f1").split("\n").reject { |user| excluded_users.include?(user) }
  humains_up = run_remote("who | cut -d' ' -f1 | sort -u").split("\n")
  
  info = {
    "Humains" => humains,
    "Humains connectés" => humains_up
  }

  if format.downcase == "json" && format != "json_silent"
    puts info.to_json
  elsif format != "json_silent"
    puts "\n#{Colors::BOLD}#{Colors::BLUE}Utilisateurs humains:#{Colors::RESET} #{humains.empty? ? 'Aucun' : humains.join(', ')}"
    puts "#{Colors::BOLD}#{Colors::BLUE}Humains connectés:#{Colors::RESET} #{humains_up.empty? ? 'Aucun' : humains_up.join(', ')}\n\n"
  end
  
  return info
end

#5
def espace_disque(format)
  # cherche les partitions et les espaces disques /dev/... 
  regex = /^(\/dev\/\S+)\s+(\S+)\s+(\S+)\s+(\S+)\s+(\S+).*$/
  resultat = []

  run_remote("df -h").each_line do |ligne|
  ligne.force_encoding("UTF-8").encode!("UTF-8", invalid: :replace, undef: :replace)
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
        dispo_pct: dispo_pct
      }
      resultat << entree
    end
  end

  if format.downcase == "json" && format != "json_silent"
    puts JSON.pretty_generate({ espace_disque_par_partition: resultat })
  elsif format != "json_silent"
    puts "\n#{Colors::BOLD}#{Colors::YELLOW}Espace disque par partition:#{Colors::RESET}"
    resultat.each do |entree|
      puts "#{Colors::GREEN}Partition:#{Colors::RESET} #{entree[:partition]}, #{Colors::GREEN}Taille:#{Colors::RESET} #{entree[:taille]}, #{Colors::GREEN}Utilisé:#{Colors::RESET} #{entree[:utilise]}, #{Colors::GREEN}Disponible:#{Colors::RESET} #{entree[:disponible]}, #{Colors::GREEN}Dispo%:#{Colors::RESET} #{entree[:dispo_pct]}"
    end
  end
  
  return resultat
end

# 6 
def processes_usage(format, cpu_th, mem_th)
  # Récupérer tous les processus
  all_processes = run_remote("ps -eo pid,user,comm,%cpu,%mem --sort=-%cpu").strip
  
  lines = all_processes.split("\n")
  header = lines.first
  
  # Filtrer les processus CPU
  cpu_lines = [header]
  lines.drop(1).each do |line|
    fields = line.split
    cpu_value = fields[3].to_f
    cpu_lines << line if cpu_value > cpu_th
  end
  cpu_processes = cpu_lines.join("\n")
  
  # Récupérer et filtrer les processus MEM
  all_processes_mem = run_remote("ps -eo pid,user,comm,%cpu,%mem --sort=-%mem").strip
  lines_mem = all_processes_mem.split("\n")
  
  mem_lines = [header]
  lines_mem.drop(1).each do |line|
    fields = line.split
    mem_value = fields[4].to_f
    mem_lines << line if mem_value > mem_th
  end
  mem_processes = mem_lines.join("\n")
  
  info = {
    "Seuil CPU" => "#{cpu_th}%",
    "Processus CPU" => cpu_processes.split("\n"),
    "Seuil Mémoire" => "#{mem_th}%",
    "Processus Mémoire" => mem_processes.split("\n")
  }
  
  if format.downcase == "json" && format != "json_silent"
    puts info.to_json
  elsif format != "json_silent"
    puts "\n#{Colors::BOLD}#{Colors::RED}Processus CPU > #{cpu_th}%:#{Colors::RESET}"
    if cpu_lines.length <= 1
      puts "  Aucun processus au-dessus du seuil"
    else
      puts cpu_processes
    end
    
    puts "\n#{Colors::BOLD}#{Colors::RED}Processus avec MEM > #{mem_th}%:#{Colors::RESET}"
    if mem_lines.length <= 1
      puts "  Aucun processus au-dessus du seuil"
    else
      puts mem_processes
    end
  end
  
  return info
end

#7
# nécessite de lancér le script avec les droits root pour nethogs
def analyser_nethogs(flux_min, format)
  resultat = []

  commande = run_remote("timeout 3 nethogs -t -a 2>/dev/null")

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
    puts "\n#{Colors::BOLD}#{Colors::CYAN}Flux Réseau (supérieur à #{flux_min} KB):#{Colors::RESET}"
    if resultat.empty?
      puts "  Aucun flux réseau détecté au-dessus du seuil"
    else
      resultat.each do |entree|
        puts "#{Colors::MAGENTA}Interface:#{Colors::RESET} #{entree[:interface]}, #{Colors::MAGENTA}Envoyé:#{Colors::RESET} #{entree[:envoye]}, #{Colors::MAGENTA}Reçu:#{Colors::RESET} #{entree[:recu]}"
      end
    end
  end
  
  return resultat
end

# 8
def services_status(format, services_list = [])
  # notation des services par défaut %w crée un tableau de chaînes
  default_services = %w[ssh cron docker]
  to_check = services_list.empty? ? default_services : services_list
  services_info = {}

  # boucle sur chaque service à vérifier
  to_check.each do |svc|
    # ajouter .service si pas déjà présent (traite unité systemd de type service)
    unit = svc.end_with?('.service') ? svc : "#{svc}.service"

    # vérifier présence de l'unité
    exists_check = run_remote("systemctl list-unit-files #{unit} 2>/dev/null | grep -q '#{unit}' && echo 'exists' || echo 'notfound'").strip

    if exists_check == "exists"
      # utiliser le nom court (sans .service) pour is-active/is-enabled
      name_for_state = svc.sub(/\.service\z/, '')
      active_status = run_remote("systemctl is-active #{name_for_state} 2>/dev/null").strip
      enabled_status = run_remote("systemctl is-enabled #{name_for_state} 2>/dev/null").strip
      services_info[name_for_state] = "#{active_status} / #{enabled_status}"
    else
      services_info[svc.sub(/\.service\z/, '')] = "non présent sur le système"
    end
  end

  if format.downcase == "json" && format != "json_silent"
    puts JSON.pretty_generate(services_info)
  elsif format != "json_silent"
    puts "\n#{Colors::BOLD}#{Colors::GREEN}État des services:#{Colors::RESET}"
    services_info.each { |service, status| puts "#{Colors::YELLOW}#{service}#{Colors::RESET} : #{status}" }
  end

  services_info
end

############ EXECUTION ############

### si pas lancer en root avertissement 
# uid = 0 pour root
if Process.uid != 0 then
  puts "#{Colors::RED}#{Colors::BOLD}###############################################################################{Colors::RESET}"
  puts "\n#{Colors::YELLOW}Attention: l'analyse du trafic réseau nécessite les droits root pour nethogs.#{Colors::RESET}\n"
  puts 
  puts "#{Colors::RED}#{Colors::BOLD}###############################################################################{Colors::RESET}"
end

### Mode avec JSON et fichier de sortie spécifié (si vaut nil alors mode texte stdout)
if format.downcase == "json" && output_file_path
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
  
  # Exporter le fichier JSON
  export_json_to_file(all_data, output_file_path)
  
  # Générer automatiquement le fichier Prometheus
  prom_file_path = output_file_path.sub(/\.json$/, '.prom')
  generate_prometheus_file(all_data, prom_file_path)
  
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
