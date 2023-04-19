import boto3
import json
ssm = boto3.client('ssm', region_name='eu-west-2')
password = ssm.get_parameter(Name='dbpassword', WithDecryption=True)
host = ssm.get_parameter(Name='dbhost', WithDecryption=True)
user = ssm.get_parameter(Name='dbuser', WithDecryption=True)
bucket = 'zehewebsitee'


customhost = host['Parameter']['Value']
customuser = user['Parameter']['Value']
custompass = password['Parameter']['Value']
customdb = "enquiry"
custombucket = "zehewebsitee"
customregion = "eu-west-2"