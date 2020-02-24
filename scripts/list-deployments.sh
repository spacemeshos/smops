kubectl config get-contexts -o name | \
  grep 'miner\|mgmt' | \
  xargs -I {} sh -c 'printf -v d "%-26s" " "; echo "${d// /-} {} ${d// /-}"; kubectl --context={} get svc,deploy,pvc,statefulset -l app=miner,app=poet -n default'