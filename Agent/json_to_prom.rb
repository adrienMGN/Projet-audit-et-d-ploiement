#!/usr/bin/env ruby
# encoding: utf-8

require 'json'

if ARGV.length < 2
  puts "Usage: #{$0} <in.json> <out.prom>"
  exit 1
end

input_file = ARGV[0]
output_file = ARGV[1]
data = JSON.parse(File.read(input_file))

# Converti tout en bits pour le Grafana plus tard
def parse_value(value_str)
  return 0 if value_str.nil? || value_str.empty?
  
  case value_str
  when /^([\d.]+)Gi$/
    $1.to_f * 1024 * 1024 * 1024
  when /^([\d.]+)Mi$/
    $1.to_f * 1024 * 1024
  when /^([\d.]+)Ki$/
    $1.to_f * 1024
  when /^([\d.]+)G$/
    $1.to_f * 1000 * 1000 * 1000
  when /^([\d.]+)M$/
    $1.to_f * 1000 * 1000
  when /^([\d.]+)K$/
    $1.to_f * 1000
  when /^([\d.]+)B$/
    $1.to_f
  when /^([\d.]+)%$/
    $1.to_f
  else
    value_str.to_f
  end
end

metrics = []
hostname = data.dig("system_info", "Nom de la machine") || "unknown"

timestamp_ms = Time.now.to_i * 1000

# 1. load avg
load_avg = data.dig("resources", "Charge moyenne (1, 5, 15 min)")
if load_avg
  loads = load_avg.split(',').map(&:strip)
  metrics << "# HELP node_load1 1-minute load average"
  metrics << "# TYPE node_load1 gauge"
  metrics << "node_load1{hostname=\"#{hostname}\"} #{loads[0]} #{timestamp_ms}"
  
  metrics << "# HELP node_load5 5-minute load average"
  metrics << "# TYPE node_load5 gauge"
  metrics << "node_load5{hostname=\"#{hostname}\"} #{loads[1]} #{timestamp_ms}"
  
  metrics << "# HELP node_load15 15-minute load average"
  metrics << "# TYPE node_load15 gauge"
  metrics << "node_load15{hostname=\"#{hostname}\"} #{loads[2]} #{timestamp_ms}"
end

# 2. mémoire
mem_used = parse_value(data.dig("resources", "Mémoire utilisée"))
mem_available = parse_value(data.dig("resources", "Mémoire disponible"))
mem_total = mem_used + mem_available

metrics << "# HELP node_memory_MemTotal_bytes Total memory in bytes"
metrics << "# TYPE node_memory_MemTotal_bytes gauge"
metrics << "node_memory_MemTotal_bytes{hostname=\"#{hostname}\"} #{mem_total} #{timestamp_ms}"

metrics << "# HELP node_memory_MemUsed_bytes Used memory in bytes"
metrics << "# TYPE node_memory_MemUsed_bytes gauge"
metrics << "node_memory_MemUsed_bytes{hostname=\"#{hostname}\"} #{mem_used} #{timestamp_ms}"

metrics << "# HELP node_memory_MemAvailable_bytes Available memory in bytes"
metrics << "# TYPE node_memory_MemAvailable_bytes gauge"
metrics << "node_memory_MemAvailable_bytes{hostname=\"#{hostname}\"} #{mem_available} #{timestamp_ms}"

# memoire en pourcentage pour le grafana
mem_percent = mem_total > 0 ? (mem_used / mem_total * 100) : 0
metrics << "# HELP node_memory_usage_percent Memory usage percentage"
metrics << "# TYPE node_memory_usage_percent gauge"
metrics << "node_memory_usage_percent{hostname=\"#{hostname}\"} #{mem_percent.round(2)} #{timestamp_ms}"

# swap
swap_used = parse_value(data.dig("resources", "Swap utilisé"))
swap_available = parse_value(data.dig("resources", "Swap disponible"))

metrics << "# HELP node_swap_used_bytes Used swap in bytes"
metrics << "# TYPE node_swap_used_bytes gauge"
metrics << "node_swap_used_bytes{hostname=\"#{hostname}\"} #{swap_used} #{timestamp_ms}"

# 3. disque, on ignore les pertitions impertinentes comme les /dev/loop pour conteneurs
if data["disk_space"]
  data["disk_space"].each do |disk|
    partition = disk["partition"]

    next unless partition =~ /^\/dev\/(nvme|sd|vd)/
    
    total_bytes = parse_value(disk["taille"])
    used_bytes = parse_value(disk["utilise"])
    available_bytes = parse_value(disk["disponible"])
    usage_percent = parse_value(disk["dispo_pct"])
    
    partition_clean = partition.gsub(/[^\w\-]/, '_') # sanitize
    
    metrics << "# HELP node_filesystem_size_bytes Filesystem size in bytes"
    metrics << "# TYPE node_filesystem_size_bytes gauge"
    metrics << "node_filesystem_size_bytes{hostname=\"#{hostname}\",device=\"#{partition}\"} #{total_bytes} #{timestamp_ms}"
    
    metrics << "# HELP node_filesystem_avail_bytes Filesystem available space in bytes"
    metrics << "# TYPE node_filesystem_avail_bytes gauge"
    metrics << "node_filesystem_avail_bytes{hostname=\"#{hostname}\",device=\"#{partition}\"} #{available_bytes} #{timestamp_ms}"
    
    metrics << "# HELP node_filesystem_usage_percent Filesystem usage percentage"
    metrics << "# TYPE node_filesystem_usage_percent gauge"
    metrics << "node_filesystem_usage_percent{hostname=\"#{hostname}\",device=\"#{partition}\"} #{usage_percent} #{timestamp_ms}"
  end
end

# 4. services
if data["services"]
  data["services"].each do |service, status|
    # Extraire le statut (active/inactive)
    is_active = status.include?("active") ? 1 : 0
    
    metrics << "# HELP node_service_status Service status (1=active, 0=inactive)"
    metrics << "# TYPE node_service_status gauge"
    metrics << "node_service_status{hostname=\"#{hostname}\",service=\"#{service}\"} #{is_active} #{timestamp_ms}"
  end
end

# 5. uptime cpu
uptime_str = data.dig("resources", "Uptime")
if uptime_str
  # converti hms en secondes
  uptime_seconds = 0
  uptime_seconds += $1.to_i * 24 * 3600 if uptime_str =~ /(\d+)\s+days?/
  uptime_seconds += $1.to_i * 3600 if uptime_str =~ /(\d+)\s+hours?/
  uptime_seconds += $1.to_i * 60 if uptime_str =~ /(\d+)\s+minutes?/
  
  metrics << "# HELP node_uptime_seconds System uptime in seconds"
  metrics << "# TYPE node_uptime_seconds counter"
  metrics << "node_uptime_seconds{hostname=\"#{hostname}\"} #{uptime_seconds} #{timestamp_ms}"
end

begin
  File.write(output_file, metrics.join("\n") + "\n")
end
