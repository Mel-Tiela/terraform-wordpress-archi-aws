
# Use Terraform to Deploy Wordpress in a Reliable AWS Architecture 

This architecture is designed using **IaC-Terraform** for the deployment of a WordPress application. It is designed following the recommendations of AWS’ *Well Architected framework* to provide a solution which is: 

- **Operational**: Architecture relies completely on code and integration with a version control system facilitates frequent,  small and reversibles changes.
- **Secured**: Security is applied at various layers of the architecture.  Application and data servers in private subnets and access controled with security groups and ACLs. 
- **Reliable**: The use of multi AZ and auto scaling instances makes it fault tolorant.  
*(Image of architecture in progress)*

## AWS Services Used and Why 
## [VPC,SUBNETS, EC2, NAT, IGW, ALB, Launch Templates, Auto Scaling Groups, AURORA]

- **Two public subnets in two availability zones** was used for resilience and fault tolerance
- **Four private subnets, two for the web application and two for the aurora database** distributed in two availability zones.  
This provides a layer of security for both the application server and data base as they are not reachable via the internet.  
- **AURORA** The choice of aurora is to benefit from its serverless feature, scalability and reliability with copies distribued in three availability zones.  
The separation of the application subnet from the data subnet is to avoid both services conflicting over resources which may cause the database to stop due to overloaded process on the web application. 
- **ALB** To ensure reliability and fault tolerance, I used an internet facing ALB associated with the the two public subnets to route traffic to the target group of EC2 instances (application server). 
Due to the health check feature of the ALB, traffic can be routed to the next healthy application server in the private subnet.
- **BASTION EC2** To be able to access both the data and application layer in private instances,  I mades use of EC2 instance in the public subnet to act as bastion. 
This instance is associated to an **IGW**
- **NAT** Used to connect to the instances via  the IGW to downlaod all the required packages for the application and database in the private subnet. 
- **Launch Templates and ASG** To scale the application servers and bastion server as need be,  I opted for a launch template associated to an auto sacling group. This facilitates modification and several instance configuration in a single spot. It equally facilitates the association of parameters such as iam role,  security groups and key pairs.     


### Steps to Run this Infrastructure 
1. Clone this repossitory
2. Add **terraform.tfvars** file to the root of parent directory and modify the default values.  
```
cidr_block = "<cidr-block-of-vpc>"
availability_zones = ["eu-south-1a", "eu-south-1b"]
environment = ["dev", "test", "production"]
instance_type      = "t3.micro"
key_name           = "wordpress-project"
workstation_ip = <Include your desktop IP Address>
```
3. Create an IAM profile and change the one in main.tf: 

```
aws configure --profile <your-profile-name>
AWS Access Key ID [None]: <your-iam-user-key-id>
AWS Secret Access Key [None]: <your-secret-ket> 
Region: <region to deploy the infrastructure>

In main.tf
provider "aws" {
    profile = "use-the-profile-name-created-above"    
}
``` 
4. Deploy the stack using the terraform commands: 

``` 
terraform init 
terraform plan
terraform apply
``` 
5. SSH into your application server using bastion server in public subnet. 
6. Configure wordpress database with the followinf commands 

```
# Set environment variable for aurora DB host
export MYSQL_HOST=<your-aurora-writer-endpoint> 
mysql --user=<aurora-master-username> --password=<aurora-master-pass> <db-name-aurora>
# Create another user for your db and grant priviledges 

CREATE USER <'name-of-user'> IDENTIFIED BY <'user-pasword'>;
GRANT ALL ON <db-name>.* TO <'user-name-creted-previous-command'>;
FLUSH PRIVILEGES;
Exit
```
7. Configure wp-config file as follows
```
cd /var/www/html/wordpress/
vim wp-config.php 
# Edit the database info using information of the db user created in step (5)
/** Database username */
define( 'DB_USER', 'db-username' );

/** Database password */
define( 'DB_PASSWORD', 'db-password' );

/** Database hostname */
define( 'DB_HOST', 'aurora-instance-endpoint' );

```
[Click on this link](https://link-url-here.org) and fill this section of the configuraion

```
define( 'AUTH_KEY',         '' );
define( 'SECURE_AUTH_KEY',  '' );
define( 'LOGGED_IN_KEY',    '' );
define( 'NONCE_KEY',        '' );
define( 'AUTH_SALT',        '' );
define( 'SECURE_AUTH_SALT', '' );
define( 'LOGGED_IN_SALT',   '' );
define( 'NONCE_SALT',       '' );

#Then restart the service
sudo systemctl restart apache2
```

8. Copy DNS of the application load balancer to browser

#### Next Steps: 
- **Elastic Memcache** Complete the architecture to include Elastic Cache Memcache to ease catching and avoid requesting from the database direct each time. 
- **Route 53** Custom DNS name for wordpress blog,  reliability and more complex routing policies
- **Cloudfront** For low latency distribution of content to users.  
- **WAF** Additional security layer for application and data layer. 
- Use terraform modules 