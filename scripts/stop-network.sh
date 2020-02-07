kubectl config get-contexts -o name | \
  grep 'miner\|mgmt' | \
  xargs -n 1 -P 6 -I {} kubectl --context={} delete svc,deploy,pvc,statefulset -l provider!=kubernetes -n default