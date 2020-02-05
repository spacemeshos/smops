kubectl config get-contexts -o name | grep 'miner\|mgmt' | xargs -I {} sh -c 'printf -v d "%-26s" " "; echo "${d// /-} {} ${d// /-}"; kubectl --context={} get deploy,statefulset -n default'
