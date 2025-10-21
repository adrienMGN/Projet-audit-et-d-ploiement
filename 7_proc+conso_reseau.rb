#!/usr/bin/env ruby
require 'json'

def analyser_nethogs(seuil: 2, duree: 5, sortie: 'texte')
  resultat = []

  commande = `timeout #{duree}  nethogs -t -a 2>/dev/null`

  commande.each_line do |ligne|
    colonnes = ligne.strip.split
    next if colonnes.size < 3 # ignore les lignes invalides

    interface = colonnes[0]
    envoye    = colonnes[1].to_f
    recu      = colonnes[2].to_f

    if (envoye + recu) >= seuil
      entree = {
        interface: interface,
        envoye: envoye.to_s + "KB",
        recu: recu.to_s + "KB"
      }
      resultat << entree
    end
  end

  if sortie == 'json'
    puts JSON.pretty_generate({ flux_reseau: resultat })
  else
    resultat.each do |entree|
      puts "Interface: #{entree[:interface]}, Envoyé: #{entree[:envoye]} KB, Reçu: #{entree[:recu]} KB"
    end
  end
end

# Exemple d'utilisation
analyser_nethogs(seuil: 2, duree: 2, sortie: 'json')   # JSON
#analyser_nethogs(seuil: 2, duree: 2, sortie: 'texte')  # Texte
