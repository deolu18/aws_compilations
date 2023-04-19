# For Deployment

1. git clone <repo>
2. cd zehe 
3. bash iaac/create_env.sh iaac-website iaac/environment.yaml iaac/environment.json
4. bash copy.sh
5. bash iaac/create_servers.sh iaac-servers iaac/servers.yaml iaac/servers.json










sudo apt-get update
# For Sql-client
sudo apt-get install mysql-client

# For python and related frameworks

sudo apt-get install python3
sudo apt-get install python3-flask
sudo apt-get install python3-pymysql
sudo apt-get install python3-boto3

# for running application
sudo python3 enqapp.py
