from flask import request,render_template,sessions,jsonify,flash,redirect,url_for
from flask.ext.classy import FlaskView
import couchdb
from app import app ,db



#create a document and insert it into the db:
JS_SCRIPT =''

class IndexView(FlaskView):

    def get(self):
        return JS_SCRIPT
    def post(self):
        values = request.form.items()
        id = db.save(doc)
        return_js = {'id':id}
        return jsonify(return_js)

IndexView.register(app, route_base="/")

app.run(debug=True)
