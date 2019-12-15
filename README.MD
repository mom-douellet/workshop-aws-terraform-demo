# Démonstration rapide, terraform

## Objectif

Répéter le scénario de démontration effectué lors de la démonstration AWS Premiers Pas.

L'infrastructure ne fait pas de sens et est à titre de démonstration pour certains composants AWS.

## Procédure

1. Créer le fichier secrets.tfvars à partir de secrets.tfvars.template .
2. Modifier les variables selon celles fournies lors de la présentation.
3. Préparrer les informations AWS, créer le fichier suivant sous .aws/credentials:

```
[workshop-mom]
aws_access_key_id=AKIAWSDFDSFSF5NNN4
aws_secret_access_key=G5ftnZNOTAREALONEpMzCt5a+kLIi
```

4. Lancer terraform

```
terraform init
terraform validate
terraform plan -var-file=secrets.tfvars
terraform apply -var-file=secrets.tfvars
terraform destroy -var-file=secrets.tfvars
```