# liste des utilisateurs humain (uid ⩾ 1000) existants, en distinguant ceux actuellement connectés.

echo -e '\nUtilisateurs humains:'
grep -E '^[^:]+:[^:]*:[0-9]{4,}:' /etc/passwd | cut -d: -f1
