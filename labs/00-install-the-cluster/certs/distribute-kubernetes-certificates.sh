for instance in worker-0 worker-1; do
  PUBLIC_IP_ADDRESS=$(az network public-ip show -g kubernetes-lab-00 \
    -n ${instance}-pip --query "ipAddress" -o tsv)

  scp -i ../ssh-keys/id_rsa_local -o StrictHostKeyChecking=no ca.pem ${instance}-key.pem ${instance}.pem kuberoot@${PUBLIC_IP_ADDRESS}:~/
done

for instance in controller-0 controller-1 controller-2; do
  PUBLIC_IP_ADDRESS=$(az network public-ip show -g kubernetes-lab-00 \
    -n ${instance}-pip --query "ipAddress" -o tsv)

  scp -i ../ssh-keys/id_rsa_local -o StrictHostKeyChecking=no ca.pem ca-key.pem kubernetes-key.pem kubernetes.pem \
    service-account-key.pem service-account.pem kuberoot@${PUBLIC_IP_ADDRESS}:~/
done