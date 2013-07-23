# Simple yet effective script to ban any /24 network from which a brute-force ssh attack originates.
# Ack'ed that this isn't the most elegant approach; but not all systems yet support xtables & conntrack.

# Tailor the pattern to the system
PAT="invalid"

for ip in `grep -iP "$PAT" /var/log/secure* | grep -iPo "((1|2(?=[0-5]))?[0-9]{1,2}\.){3}" | sort -n | uniq | sed -nr "s/\.$/\.0\/24/p"`
do
  echo "Banning $ip..."
  if [[ `iptables -vL | grep -iP "$ip"` ]]
  then
    echo "Already banned."
  else 
    iptables -I INPUT -p tcp --dport 22 -s $ip -j DROP
    echo "Rule added."
  fi
done

