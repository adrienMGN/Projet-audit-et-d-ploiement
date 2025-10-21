#!/usr/bin/env ruby
require 'json'

def parse_df(output)
  regex = /^(\/dev\/\S+)\s+(\S+)\s+(\S+)\s+(\S+)\s+(\S+).*$/
  resultat = []

  `df -h`.each_line do |ligne|
    if ligne =~ regex
      partition  = $1
      taille     = $2
      utilise    = $3
      disponible = $4
      dispo_pct  = $5  # On ne met plus le %

      entree = {
        partition: partition,
        taille: taille,
        utilise: utilise,
        disponible: disponible,
        "dispo%" => dispo_pct  # clé spéciale en string
      }
      resultat << entree
    end
  end

  if output == "json"
    puts JSON.pretty_generate({ espace_disque_par_partition: resultat })
  else
    resultat.each do |entree|
      puts "Partition: #{entree[:partition]}, Taille: #{entree[:taille]}, Utilisé: #{entree[:utilise]}, Disponible: #{entree[:disponible]}, Dispo%: #{entree['dispo%']}"
    end
  end
end

output = "text"
# Exemple d'utilisation
parse_df("json")   # Retourne en JSON
parse_df(output)   # Affiche dans le terminal
