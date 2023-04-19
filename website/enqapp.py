from flask import Flask, render_template, request, redirect
from pymysql import connections
import os
import boto3
from config import *

app = Flask(__name__)

# DBHOST = os.environ.get("DBHOST")
# DBPORT = os.environ.get("DBPORT")
# DBPORT = int(DBPORT)
# DBUSER = os.environ.get("DBUSER")
# DBPWD = os.environ.get("DBPWD")
# DATABASE = os.environ.get("DATABASE")

bucket= custombucket
region= customregion

db_conn = connections.Connection(
    host= customhost,
    port=3306,
    user= customuser,
    password= custompass,
    db= 'customerDB'
)
output = {}
table = 'enquiry';

create_table_cursor = db_conn.cursor()
create_table_cursor.execute("CREATE TABLE IF NOT EXISTS enquiry (enq_id VARCHAR(255), first_name VARCHAR(255), last_name VARCHAR(255), summary VARCHAR(255), location VARCHAR(255))")
db_conn.commit()

app=Flask(__name__,template_folder='template')

@app.route("/", methods=['GET', 'POST'])
def home():
    return render_template('AddEnq.html')

@app.route("/about", methods=['GET', 'POST'])
def about():
    return redirect('http://www.consultant2business.co.uk');
@app.route("/addenq", methods=['POST'])
def AddEnq():
    enq_id = request.form['enq_id']
    first_name = request.form['first_name']
    last_name = request.form['last_name']
    summary = request.form['summary']
    location = request.form['location']
    enq_image_file = request.files['enq_image_file']
  
    insert_sql = "INSERT INTO enquiry VALUES (%s, %s, %s, %s, %s)"
    cursor = db_conn.cursor()

    if enq_image_file.filename == "":
        return "Please select a file"

    try:
        
        cursor.execute(insert_sql,(enq_id, first_name, last_name, summary, location))
        db_conn.commit()
        enq_name = "" + first_name + " " + last_name
        # Uplaod image file in S3 #
        enq_image_file_name_in_s3 = "enq-id-"+str(enq_id) + "_image_file"
        s3 = boto3.resource('s3')

        
        
        try:
            print("Data inserted in MySQL RDS... uploading image to S3...")
            s3.Bucket(custombucket).put_object(Key=enq_image_file_name_in_s3, Body=enq_image_file)
            bucket_location = boto3.client('s3').get_bucket_location(Bucket=custombucket)
            s3_location = (bucket_location['LocationConstraint'])

            if s3_location is None:
                s3_location = ''
            else:
                s3_location = '-' + s3_location

            object_url = "https://s3{0}.amazonaws.com/{1}/{2}".format(
                s3_location,
                custombucket,
                enq_image_file_name_in_s3)

            # Save image file metadata in DynamoDB #
            print("Uploading to S3 success... saving metadata in dynamodb...")
        
            
            try:
                dynamodb_client = boto3.client('dynamodb', region_name='eu-west-2')
                dynamodb_client.put_item(
                 TableName='enquiry_image_table',
                    Item={
                     'enq_id': {
                          'S': enq_id
                      },
                      'image_url': {
                            'S': object_url
                        }
                    }
                )

            except Exception as e:
                program_msg = "Flask could not update DynamoDB table with S3 object URL"
                return str(e)
        
        except Exception as e:
            return str(e)

    finally:
        cursor.close()

    print("all modification done...")
    return render_template('AddEnqOutput.html', name=enq_name)

@app.route("/getenq", methods=['GET', 'POST'])
def GetEnq():
    return render_template("getenq.html")


@app.route("/fetchdata", methods=['GET','POST'])
def FetchData():
    enq_id = request.form['enq_id']

    output = {}
    select_sql = "SELECT enq_id, first_name, last_name, summary, location from enquiry where enq_id=%s"
    cursor = db_conn.cursor()

    try:
        cursor.execute(select_sql,(enq_id))
        result = cursor.fetchone()

        output["enq_id"] = result[0]
        print('EVERYTHING IS FINE TILL HERE')
        output["first_name"] = result[1]
        output["last_name"] = result[2]
        output["summary"] = result[3]
        output["location"] = result[4]
        print(output["enq_id"])
        dynamodb_client = boto3.client('dynamodb', region_name=customregion)
        try:
            response = dynamodb_client.get_item(
                TableName='enquiry_image_table',
                Key={
                    'enq_id': {
                        'S': str(enq_id)
                    }
                }
            )
            print(response)
            image_url = response['Item']['image_url']['S']
            print(image_url)

        except Exception as e:
            program_msg = "Flask could not update DynamoDB table with S3 object URL"
            return render_template('addenqerror.html', errmsg1=program_msg, errmsg2=e)

    except Exception as e:
        print(e)

    finally:
        cursor.close()

    return render_template("GetEnqOutput.html", id=output["enq_id"], fname=output["first_name"],
                           lname=output["last_name"], summary=output["summary"], location=output["location"],
                           image_url=image_url)

if __name__ == '__main__':
    app.run(debug=True)