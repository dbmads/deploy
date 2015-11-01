
from flask import Flask, request, render_template
from flask.ext.classy import FlaskView
import datetime
import os
import couchdb


# create the little application object
app = Flask(__name__,template_folder="templates")




couch = couchdb.Server() # Assuming localhost:5984
# If your CouchDB server is running elsewhere, set it up like this:

# select database
db = couch['users']



#db = Database(app)






