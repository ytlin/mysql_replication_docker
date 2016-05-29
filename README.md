#slave and master images

base on images pritunl/archlinux

*master need env variable(default value): 
MYSQL_ROOT_PASSWORD(1234) , MYSQL_REPLICATION_PASSWORD(1234)


*slave nedd env variable(default value): 
MYSQL_ROOT_PASSWORD(1234) , MYSQL_REPLICATION_PASSWORD(1234) , MYSQL_MASTER_SERVICE_HOST(master)

set these env variable to what you want in .yaml below

#kubernetes .yaml:

###wordpress and mysql_master in one pod , 3 salve in seperated pods
use wordpress_mysql.yaml to create the Deployment of wordpress and mysql master, and then find the IP of the pod , and set the MYSQL-MASTER_SERVICE_HOST in the mysql_slave.yaml to correctly connect to master. Finally, create Depolyment of slave by mysql_slave.yaml.

this architecture is just for test and fun, Because  master and wordpress in one pod is not ideal , web server can't grow. So to solve this, I want to test another way below.

###master in one pod , wordpress and slave in many indivitual pods(web can scale too!)

....not yet


