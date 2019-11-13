# todo-app-aks-demo

This app is based off of a tutorial available at [Java
Guides](http://www.javaguides.net/2018/09/mini-todo-management-project-using-spring-boot-springmvc-springsecurity-jsp-hibernate-mysql.html). It has been
modified from the original to use a custom login page, Redis Cache for session
management and Thymeleaf templates.

It uses Spring Boot to create a basic Todo App that has a Azure MySQL backend
and uses Redis cache for session management. It also has a very basic Spring
Security configuration that will evolve over time. As currently configured you
will also need to use an Azure KeyVault to store the datasource url and username
and password to MySQL and Redis and also set some environment variables.

This tutorial will "likely" run fine on a Windows workstation but was developed and tested on Mac/Linux.

## Common Installation Instructions

1.  Create Azure MySQL instance
```
az mysql server create -l <region>          \
    -g <resource-group> -n <db-server-name> \
    -u <username> -p <password>             \
    --sku GP_Gen5_2                         \
    --ssl-enforcement Disabled 
```
2.  Create a database in MySQL instance named __todo__
```
az mysql db create -n todo -g <resource-group> \
    --server-name <db-server-name> 
```
3.  Create Azure Cache for Redis service in Azure.  Must have 'notify-keyspace-events' set.  NOTE: This cannot be set on Basic plans.
```
 az redis create -g <resource-group> -l <region> \
    -n <redis-server-name> --sku Standard --vm-size c0 \
    --enable-non-ssl-port \
    --redis-configuration '{"notify-keyspace-events":"Egx"}'
```
4.  Create Azure keyvault
```
az keyvault create --name <your_keyvault_name>            \
                   --resource-group <your_resource_group> \
                   --location <location>                  \
                   --enabled-for-deployment true          \
                   --enabled-for-disk-encryption true     \
                   --enabled-for-template-deployment true \
                   --sku standard 
```
5. Create service principal
```
az ad sp create-for-rbac --name <your_azure_service_principal_name>
```
6. Set Permission for service principal on Keyvault
```
az keyvault set-policy --name <your_keyvault_name>   \
                       --secret-permission get list  \
                       --spn <your_sp_id_created_above>
```
7.  Set secrets for MySQL and Redis in Keyvault. Use the specific __name__ values given below. 
```
# Change the --value(s) to reflect your Azure MySQL connection information
az keyvault secret set --name spring-datasource-url                          \
                       --value jdbc:mysql://azure-instance-address:3306/todo \
                       --vault-name <your_keyvault_name>

az keyvault secret set --name spring-datasource-username           \
                       --value <mysql-username>                    \
                       --vault-name <your_keyvault_name>

az keyvault secret set --name spring-datasource-password           \
                       --value <password>                          \
                       --vault-name <your_keyvault_name>

az keyvault secret set --name spring-redis-host                    \
                       --value <redis host name>                   \
                       --vault-name <your_keyvault_name>

az keyvault secret set --name spring-redis-password                \
                       --value <password>                          \
                       --vault-name <your_keyvault_name>
```

## Running Application Locally
1.  Set ENVIRONMENT variables in terminal
```
KEYVAULT_URL=<yourkeyvault.address.here>
KEYVAULT_CLIENT_ID=<service.principal.id>
KEYVAULT_CLIENT_KEY=<service.principal.key>
```
2.  Run the following command from the same terminal
```
mvn clean package spring-boot:run
```
3.  Open a browser to http://localhost:8080

## Running as an Azure WebApp
If you would like to run this application in Azure as a WebApp the pom.xml
comes equipped with a dependency on the azure-webapp-maven-plugin. This plugin
will deploy the application directly to Azure if your Service Principal has
permissions to create AppService plans and WebApps. If your Service Principal
does not have permission you may need to modify the pom.xml to include your
preexisting AppService plan information. More information about the
__azure-webapp-maven-plugin__ configuration options can be found
[here](https://docs.microsoft.com/en-us/java/api/overview/azure/maven/docs/web-app-samples?view=azure-java-stable).

1. Set ENVIRONMENT variables in terminal for Keyvault
info 
``` 
KEYVAULT_URL=<yourkeyvault.address.here>
KEYVAULT_CLIENT_ID=<service.principal.id>
KEYVAULT_CLIENT_KEY=<service.principal.key> 
``` 

2.  Modify your Maven settings.xml file to include a
<serverId> section to authenticate with Azure. See [this
page](https://docs.microsoft.com/en-us/java/azure/spring-framework/deploy-containerized-spring-boot-java-app-with-maven-plugin?view=azure-java-stable#configure-maven-to-use-your-azure-service-principal) for more information about setting
this up.

3.  Modify the pom.xml file to include the <authentication> section in the
    Azure Webapp plugin using the info created in #2.
```
<authentication>
   <serverId>name-of-serverId-from-above</serverId>
</authentication>
```

4.  Run the following command from the same terminal
```
mvn clean package azure-webapp:deploy
```

5.  Open the Azure portal to determine the http://  address of your webapp and
    open your browser to this address


## Running in AKS
This repository can also be deployed to Azure Kubernetes Service (AKS) using the
provided Dockerfile and aks-deploy.yaml file included in the repository.  You
will need an AKS cluster with an Ingress controller installed and a Kubernetes account
that has the ability to create a namespace, deployments and Ingress routes.

You will also need a way to build Docker images.  You can do this natively using
a Docker client or you can use Azure Cloud Shell or even ACR tasks if you are
using an Azure Container Registry.  

1. Set ENVIRONMENT variables in terminal for Keyvault
info 
``` 
KEYVAULT_URL=<yourkeyvault.address.here>
KEYVAULT_CLIENT_ID=<service.principal.id>
KEYVAULT_CLIENT_KEY=<service.principal.key> 
```



2. Execute the following command to utilize the Environment variables in your
   build.  You will need to replace the registry-acct and container name information with your own
```
docker build --build-arg KEYVAULT_URL=${KEYVAULT_URL} \
    --build-arg CLIENT_ID=${KEYVAULT_CLIENT_ID} \
    --build-arg CLIENT_KEY=${KEYVAULT_CLIENT_KEY} \
    -t <registry-acct>/<container-name> .
```

3.  __Optional__: Test your container image locally if you have Docker to ensure it is working correctly. 
```
docker run --rm -p 8080:8080 \
    -e KEYVAULT_URL \
    -e KEYVAULT_CLIENT_ID \
    -e KEYVAULT_CLIENT_KEY \
    <registry-acct>/<container-name>:latest
```

4.  __Optional__:  Open your browser to http://localhost:8080 to access the running
    Docker container.

5.  At this point you should have a working container that can be published to
    a registry.  After logging into your registry you can run the following to
push your image.  __Note__:  It is a best practice to use versions with your
containers. I am __not__ in these examples so it is left as an exercise to do
so. In these examples 'latest' is created by default and used. 
```
docker push emcconne/todo-management-spring-boot
```

6.  Next, in order to deploy the application to AKS you will need to modify the
    included aks-deploy.yaml file but first we need to encode your Keyvault
information so it can be added the the aks-deploy.yaml file
```
echo -n '<your-keyvault-url>' | base64
aHR0cDovL3lvdXJrZXl2YXVsdC5pbmZv

echo -n '<your-client-id>' | base64
aHR0cDovL3lvdXJrZXl2YXVsdC5pbmZv

echo -n '<your-client-key>' | base64
aHR0cDovL3lvdXJrZXl2YXVsdC5pbmZv
```

7.  You will also need to know the public address of your AKS cluster.  This can
    typically be found by using something like the following:
```
K8S_RG=$(az resource show -o tsv \
    -n <aks-name> \
    -g <resource-group> \
    --resource-type Microsoft.ContainerService/managedClusters \
    --query properties.nodeResourceGroup)

PUBLIC_IP=$(az network public-ip list -g $K8S_RG -o json --query "[].ipAddress" -o tsv)

K8S_FQDN=$( az network public-ip list \
    --query "[?ipAddress!=null]|[?contains(ipAddress, '$PUBLIC_IP')].[dnsSettings.fqdn]" -o tsv )

echo $K8S_FQDN
```

8.  Once you have the FQDN of your AKS cluster and the base64 encoded
    information for your Keyvault you can modify the aks-deploy.yaml file to
include this information.  There is a section towards the top of the file that
creates Kubernetes secrets using the base64 encoded information and there is a
section at the bottom of the file that creates an Ingress rule that requires the
host name in 2 places.

9.  After modifying the file you can run to create the namespace and objects
    necessary to run the application in AKS.
```
kubectl apply -f ./aks-deploy.yaml
``
__Note__:  It should be noted that this Ingress rule establishes the application
at the root of the domain.  In many cases you will want to use a specific path
on the primary domain to direct traffic such as /todo.  This is not covered in
this HOWTO.



