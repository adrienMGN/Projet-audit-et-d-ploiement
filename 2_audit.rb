#!/usr/bin/env ruby
require 'json'
require 'optparse'

# gestion des paramètres
options = {}
OptionParser.new do |opt|
  # output text ou json
  opt.on('-o', '--output FORMAT') { |o| options[:output] = o }
  # seuil cpu
  opt.on('-c', '--CPU_THRESHOLD THRESHOLD') { |o| options[:cpu] = o }
  # seuil memoire
  opt.on('-m', '--MEMORY_THRESHOLD THRESHOLD') { |o| options[:memory] = o }
  # durée de la mesure 
  opt.on('-d', '--PROC_DURATION DURATION') { |o| options[:duration] = o }
  # débit réseau
  opt.on('-s', '--MIN_SPEED SPEED') { |o| options[:speed] = o }
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

puts nom_distro(format)
puts uptime_avgload_memory_swapavailable(format)

puts nom_distro
puts uptime_avgload_memory_swapavailable