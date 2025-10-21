#!/usr/bin/env ruby
require 'json'
require 'optparse'

# ==============================================================================
# SYSTEM AUDIT SCRIPT
# ==============================================================================
# This script performs a comprehensive system audit and displays information
# about the system's health, resources, and services.
#
# Usage: ./audit.rb [options]
#
# Options:
#   -o, --output FORMAT          Output format: 'text' (default) or 'json'
#   -c, --cpu_threshold VALUE    CPU usage threshold in % (default: 5)
#   -m, --memory_threshold VALUE Memory usage threshold in % (default: 5)
#   -f, --flux_min VALUE         Minimum network flux in KB (default: 2)
#   -s, --services "svc1 svc2"   Space-separated list of services to check
#   -h, --help                   Display this help message
#
# Examples:
#   ./audit.rb
#   ./audit.rb -o json
#   ./audit.rb -c 10 -m 20 -s "nginx apache2 mysql"
# ==============================================================================

# Parse command line options
options = {}
OptionParser.new do |opt|
  opt.banner = "Usage: audit.rb [options]"
  opt.separator ""
  opt.separator "Options:"
  
  opt.on('-o', '--output FORMAT', 'Output format: text (default) or json') do |o|
    options[:output] = o
  end
  
  opt.on('-c', '--cpu_threshold THRESHOLD', Float, 'CPU usage threshold in % (default: 5)') do |c|
    options[:cpu] = c
  end
  
  opt.on('-m', '--memory_threshold THRESHOLD', Float, 'Memory usage threshold in % (default: 5)') do |m|
    options[:memory] = m
  end
  
  opt.on('-f', '--flux_min MIN', Float, 'Minimum network flux in KB (default: 2)') do |f|
    options[:flux_min] = f
  end
  
  opt.on('-s', '--services "service1 service2"', 'Space-separated list of services to check') do |s|
    options[:services] = s
  end
  
  opt.on('-h', '--help', 'Display this help message') do
    puts opt
    exit
  end
end.parse!

# Configuration variables
OUTPUT_FORMAT = options[:output] || "text"
CPU_THRESHOLD = options[:cpu] || 5.0
MEMORY_THRESHOLD = options[:memory] || 5.0
FLUX_MIN = options[:flux_min] || 2.0
SERVICES_LIST = options[:services] ? options[:services].split(' ') : []

# Global results storage for JSON output
AUDIT_RESULTS = {}

# ==============================================================================
# HELPER FUNCTIONS
# ==============================================================================

# Color codes for terminal output
class Colors
  RESET = "\e[0m"
  BOLD = "\e[1m"
  
  # Text colors
  RED = "\e[31m"
  GREEN = "\e[32m"
  YELLOW = "\e[33m"
  BLUE = "\e[34m"
  MAGENTA = "\e[35m"
  CYAN = "\e[36m"
  WHITE = "\e[37m"
  
  # Bright colors
  BRIGHT_RED = "\e[91m"
  BRIGHT_GREEN = "\e[92m"
  BRIGHT_YELLOW = "\e[93m"
  BRIGHT_BLUE = "\e[94m"
  BRIGHT_MAGENTA = "\e[95m"
  BRIGHT_CYAN = "\e[96m"
  
  def self.colorize(text, color)
    "#{color}#{text}#{RESET}"
  end
end

def print_section_header(title)
  return if OUTPUT_FORMAT.downcase == "json"
  puts "\n" + Colors.colorize("=" * 80, Colors::CYAN)
  puts Colors.colorize("  #{title}", Colors::BOLD + Colors::BRIGHT_CYAN)
  puts Colors.colorize("=" * 80, Colors::CYAN)
end

def print_key_value(key, value, indent = 0)
  return if OUTPUT_FORMAT.downcase == "json"
  spaces = "  " * indent
  colored_key = Colors.colorize(key.ljust(30 - indent * 2), Colors::YELLOW)
  puts "#{spaces}#{colored_key}: #{value}"
end

def print_success(text)
  return if OUTPUT_FORMAT.downcase == "json"
  puts Colors.colorize(text, Colors::GREEN)
end

def print_warning(text)
  return if OUTPUT_FORMAT.downcase == "json"
  puts Colors.colorize(text, Colors::YELLOW)
end

def print_error(text)
  return if OUTPUT_FORMAT.downcase == "json"
  puts Colors.colorize(text, Colors::RED)
end

def colorize_status(status)
  case status.downcase
  when /active|running|enabled/
    Colors.colorize(status, Colors::GREEN)
  when /inactive|stopped|disabled/
    Colors.colorize(status, Colors::YELLOW)
  when /failed|error|not found/
    Colors.colorize(status, Colors::RED)
  else
    status
  end
end

# ==============================================================================
# AUDIT FUNCTIONS
# ==============================================================================

# 1. System Information
def get_system_info
  nodename = `uname --nodename`.strip
  distrib = `lsb_release -a 2>/dev/null | grep Description | cut -f2`.strip
  kernel_version = `uname -r`.strip

  result = {
    "hostname" => nodename,
    "distribution" => distrib,
    "kernel_version" => kernel_version
  }

  AUDIT_RESULTS["system_info"] = result

  if OUTPUT_FORMAT.downcase == "json"
    return
  end

  print_section_header("SYSTEM INFORMATION")
  print_key_value("Hostname", nodename)
  print_key_value("Distribution", distrib)
  print_key_value("Kernel Version", kernel_version)
end

# 2. System Status (Uptime, Load, Memory)
def get_system_status
  uptime = `uptime -p`.strip
  load_avg = `LANG=C uptime | grep -o 'load average:.*' | cut -d':' -f2`.strip
  mem_info = `LANG=C free -h | grep Mem: | tr -s ' ' | cut -d' ' -f3,4`.strip
  swap_info = `LANG=C free -h | grep Swap: | tr -s ' ' | cut -d' ' -f3,4`.strip

  mem_used, mem_available = mem_info.split(' ')
  swap_used, swap_available = swap_info.split(' ')

  result = {
    "uptime" => uptime,
    "load_average" => load_avg,
    "memory_used" => mem_used,
    "memory_available" => mem_available,
    "swap_used" => swap_used,
    "swap_available" => swap_available
  }

  AUDIT_RESULTS["system_status"] = result

  if OUTPUT_FORMAT.downcase == "json"
    return
  end

  print_section_header("SYSTEM STATUS")
  print_key_value("Uptime", uptime)
  print_key_value("Load Average (1, 5, 15 min)", load_avg)
  print_key_value("Memory Used / Available", "#{mem_used} / #{mem_available}")
  print_key_value("Swap Used / Available", "#{swap_used} / #{swap_available}")
end

# 3. Network Interfaces
def get_network_interfaces
  interfaces_output = `ip -o addr show`
  link_output = `ip -o link show`
  
  interfaces_data = {}
  
  # Process IP addresses
  interfaces_output.lines.each do |line|
    parts = line.split
    next if parts.length < 4
    
    iface = parts[1]
    
    if interfaces_data[iface].nil?
      interfaces_data[iface] = {
        "interface" => iface,
        "mac_address" => "N/A",
        "ipv4_addresses" => [],
        "ipv6_addresses" => []
      }
    end
    
    parts.each do |part|
      case part
      when /^(\d{1,3}\.){3}\d{1,3}(\/\d+)?$/
        interfaces_data[iface]["ipv4_addresses"] << part unless interfaces_data[iface]["ipv4_addresses"].include?(part)
      when /^([0-9a-f]{0,4}:){2,7}[0-9a-f]{0,4}\/\d+$/i
        interfaces_data[iface]["ipv6_addresses"] << part unless interfaces_data[iface]["ipv6_addresses"].include?(part)
      end
    end
  end
  
  # Process MAC addresses
  link_output.lines.each do |line|
    parts = line.split
    next if parts.length < 4
    
    iface = parts[1].gsub(':', '')
    
    parts.each do |part|
      if part =~ /^([0-9a-f]{2}:){5}[0-9a-f]{2}$/i
        interfaces_data[iface]["mac_address"] = part if interfaces_data[iface]
        break
      end
    end
  end
  
  result = interfaces_data.values
  AUDIT_RESULTS["network_interfaces"] = result

  if OUTPUT_FORMAT.downcase == "json"
    return
  end

  print_section_header("NETWORK INTERFACES")
  result.each do |data|
    puts "\n  #{Colors.colorize('Interface:', Colors::BRIGHT_BLUE)} #{Colors.colorize(data['interface'], Colors::BOLD)}"
    print_key_value("MAC Address", data["mac_address"], 1)
    
    if data["ipv4_addresses"].empty?
      print_key_value("IPv4", Colors.colorize("N/A", Colors::RED), 1)
    else
      data["ipv4_addresses"].each_with_index do |ip, index|
        label = index == 0 ? "IPv4" : "IPv4 (#{index + 1})"
        print_key_value(label, Colors.colorize(ip, Colors::GREEN), 1)
      end
    end
    
    if data["ipv6_addresses"].empty?
      print_key_value("IPv6", Colors.colorize("N/A", Colors::RED), 1)
    else
      data["ipv6_addresses"].each_with_index do |ip, index|
        label = index == 0 ? "IPv6" : "IPv6 (#{index + 1})"
        print_key_value(label, Colors.colorize(ip, Colors::GREEN), 1)
      end
    end
  end
end

# 4. User Information
def get_user_info
  human_users = `grep -E '^[^:]+:[^:]*:[0-9]{4,}:' /etc/passwd | cut -d: -f1`.split("\n")
  logged_users = `who | cut -d' ' -f1 | uniq`.split("\n")
  
  result = {
    "human_users" => human_users,
    "logged_in_users" => logged_users
  }

  AUDIT_RESULTS["user_info"] = result

  if OUTPUT_FORMAT.downcase == "json"
    return
  end

  print_section_header("USER INFORMATION")
  print_key_value("Human Users", human_users.join(", "))
  print_key_value("Logged In Users", logged_users.empty? ? "None" : logged_users.join(", "))
end

# 5. Disk Space
def get_disk_space
  regex = /^(\/dev\/\S+)\s+(\S+)\s+(\S+)\s+(\S+)\s+(\S+).*$/
  result = []

  `df -h`.each_line do |line|
    if line =~ regex
      entry = {
        "partition" => $1,
        "size" => $2,
        "used" => $3,
        "available" => $4,
        "use_percentage" => $5
      }
      result << entry
    end
  end

  AUDIT_RESULTS["disk_space"] = result

  if OUTPUT_FORMAT.downcase == "json"
    return
  end

  print_section_header("DISK SPACE")
  result.each do |entry|
    usage_percent = entry["use_percentage"].to_i
    color = case usage_percent
            when 0..70 then Colors::GREEN
            when 71..85 then Colors::YELLOW
            else Colors::RED
            end
    
    puts "\n  #{Colors.colorize('Partition:', Colors::BRIGHT_BLUE)} #{Colors.colorize(entry['partition'], Colors::BOLD)}"
    print_key_value("Size", entry["size"], 1)
    print_key_value("Used", entry["used"], 1)
    print_key_value("Available", entry["available"], 1)
    print_key_value("Usage", Colors.colorize(entry["use_percentage"], color), 1)
  end
end

# 6. Process Usage (CPU and Memory)
def get_process_usage(cpu_threshold, mem_threshold)
  cpu_processes = `ps -eo pid,user,comm,pcpu,pmem --sort=-pcpu | awk -v th="#{cpu_threshold}" 'NR==1{print;next} $4+0>th{printf "%s\t%s\t%s\t%s%%\t%s%%\\n",$1,$2,$3,$4,$5}'`.strip
  mem_processes = `ps -eo pid,user,comm,pcpu,pmem --sort=-pmem | awk -v th="#{mem_threshold}" 'NR==1{print;next} $5+0>th{printf "%s\t%s\t%s\t%s%%\t%s%%\\n",$1,$2,$3,$4,$5}'`.strip
  
  result = {
    "cpu_threshold" => "#{cpu_threshold}%",
    "high_cpu_processes" => cpu_processes.split("\n"),
    "memory_threshold" => "#{mem_threshold}%",
    "high_memory_processes" => mem_processes.split("\n")
  }
  
  AUDIT_RESULTS["process_usage"] = result

  if OUTPUT_FORMAT.downcase == "json"
    return
  end

  print_section_header("PROCESS USAGE")
  puts "\n  #{Colors.colorize("Processes with CPU > #{cpu_threshold}%:", Colors::BRIGHT_YELLOW)}"
  puts "  " + Colors.colorize("-" * 76, Colors::CYAN)
  cpu_processes.lines.each_with_index do |line, idx| 
    color = idx == 0 ? Colors::BOLD + Colors::WHITE : Colors::WHITE
    puts Colors.colorize("  #{line}", color)
  end
  
  puts "\n  #{Colors.colorize("Processes with Memory > #{mem_threshold}%:", Colors::BRIGHT_YELLOW)}"
  puts "  " + Colors.colorize("-" * 76, Colors::CYAN)
  mem_processes.lines.each_with_index do |line, idx|
    color = idx == 0 ? Colors::BOLD + Colors::WHITE : Colors::WHITE
    puts Colors.colorize("  #{line}", color)
  end
end

# 7. Network Traffic Analysis
def analyze_network_traffic(threshold)
  result = []
  command = `timeout 3 nethogs -t -a 2>/dev/null`

  command.each_line do |line|
    columns = line.strip.split
    next if columns.size < 3

    interface = columns[0]
    sent = columns[1].to_f
    received = columns[2].to_f

    if (sent + received) >= threshold
      entry = {
        "interface" => interface,
        "sent_kb" => sent,
        "received_kb" => received,
        "total_kb" => sent + received
      }
      result << entry
    end
  end

  AUDIT_RESULTS["network_traffic"] = {
    "threshold_kb" => threshold,
    "active_connections" => result
  }

  if OUTPUT_FORMAT.downcase == "json"
    return
  end

  print_section_header("NETWORK TRAFFIC (threshold: #{threshold} KB)")
  if result.empty?
    puts "  " + Colors.colorize("No connections exceeding threshold detected.", Colors::GREEN)
  else
    result.each do |entry|
      puts "\n  #{Colors.colorize('Interface:', Colors::BRIGHT_BLUE)} #{Colors.colorize(entry['interface'], Colors::BOLD)}"
      print_key_value("Sent", Colors.colorize("#{entry['sent_kb']} KB", Colors::YELLOW), 1)
      print_key_value("Received", Colors.colorize("#{entry['received_kb']} KB", Colors::YELLOW), 1)
      print_key_value("Total", Colors.colorize("#{entry['total_kb']} KB", Colors::BRIGHT_YELLOW), 1)
    end
  end
end

# 8. Services Status
def get_services_status(services_list)
  services_to_check = services_list.empty? ? ["sshd", "cron", "docker"] : services_list
  services_info = {}
  
  services_to_check.each do |service|
    service_file = "#{service}.service"
    check_cmd = `systemctl list-unit-files | grep -q "^#{service_file}"`
    
    if $?.success?
      active_status = `systemctl is-active #{service}`.strip
      enabled_status = `systemctl is-enabled #{service} 2>/dev/null`.strip
      services_info[service] = {
        "active" => active_status,
        "enabled" => enabled_status,
        "status" => "#{active_status} / #{enabled_status}"
      }
    else
      services_info[service] = {
        "active" => "not found",
        "enabled" => "not found",
        "status" => "not present on system"
      }
    end
  end

  AUDIT_RESULTS["services_status"] = services_info

  if OUTPUT_FORMAT.downcase == "json"
    return
  end

  print_section_header("SERVICES STATUS")
  services_info.each do |service, info|
    status_colored = colorize_status(info["status"])
    service_colored = Colors.colorize(service, Colors::BRIGHT_BLUE)
    print_key_value(service_colored, status_colored)
  end
end

# ==============================================================================
# MAIN EXECUTION
# ==============================================================================

begin
  get_system_info
  get_system_status
  get_network_interfaces
  get_user_info
  get_disk_space
  get_process_usage(CPU_THRESHOLD, MEMORY_THRESHOLD)
  analyze_network_traffic(FLUX_MIN)
  get_services_status(SERVICES_LIST)

  # Output JSON if requested
  if OUTPUT_FORMAT.downcase == "json"
    puts JSON.pretty_generate({
      "audit_date" => Time.now.strftime("%Y-%m-%d %H:%M:%S"),
      "parameters" => {
        "cpu_threshold" => CPU_THRESHOLD,
        "memory_threshold" => MEMORY_THRESHOLD,
        "network_flux_min" => FLUX_MIN,
        "services_checked" => SERVICES_LIST.empty? ? ["sshd", "cron", "docker"] : SERVICES_LIST
      },
      "results" => AUDIT_RESULTS
    })
  else
    puts "\n" + Colors.colorize("=" * 80, Colors::GREEN)
    puts Colors.colorize("  ✓ AUDIT COMPLETED SUCCESSFULLY", Colors::BOLD + Colors::BRIGHT_GREEN)
    puts Colors.colorize("=" * 80, Colors::GREEN)
    puts ""
  end

rescue => e
  if OUTPUT_FORMAT.downcase == "json"
    puts JSON.pretty_generate({
      "error" => e.message,
      "timestamp" => Time.now.strftime("%Y-%m-%d %H:%M:%S")
    })
  else
    puts "\n" + Colors.colorize("=" * 80, Colors::RED)
    puts Colors.colorize("  ✗ ERROR DURING AUDIT", Colors::BOLD + Colors::BRIGHT_RED)
    puts Colors.colorize("=" * 80, Colors::RED)
    puts Colors.colorize("  #{e.message}", Colors::RED)
    puts ""
  end
  exit 1
end